//
//  ImageEditorGlowTechnique.swift
//  veilpic
//
//  Photoshop-style glow expansion algorithms.
//

import AppKit
import Foundation

enum ImageEditorGlowTechnique: String, CaseIterable, Identifiable, Codable {
    case softer
    case precise

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.glowTechnique.\(rawValue)")
    }
}

extension NSImage {
    /// Builds a contour-following outer glow without blurring the source mask.
    /// A two-pass chamfer distance field keeps the work linear in pixel count,
    /// while still following corners and alpha silhouettes more closely than a
    /// Gaussian blur. The source is expected to be a single-color tinted mask.
    func preciseOuterGlow(radius: CGFloat) -> NSImage? {
        guard radius > 0,
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return self }

        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let farDistance = Float(width + height + 1)
        let diagonal = Float(2).squareRoot()
        var distances = [Float](repeating: farDistance, count: width * height)
        var strongestOffset = 0
        var strongestAlpha: UInt8 = 0

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = pixels[offset + 3]
                if alpha > 0 {
                    distances[pixelIndex] = 0
                    if alpha > strongestAlpha {
                        strongestAlpha = alpha
                        strongestOffset = offset
                    }
                }
            }
        }
        guard strongestAlpha > 0 else { return self }

        func relax(_ current: inout Float, _ neighbor: Float, _ weight: Float) {
            current = min(current, neighbor + weight)
        }

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                guard distances[index] > 0 else { continue }
                var distance = distances[index]
                if x > 0 { relax(&distance, distances[index - 1], 1) }
                if y > 0 {
                    relax(&distance, distances[index - width], 1)
                    if x > 0 { relax(&distance, distances[index - width - 1], diagonal) }
                    if x + 1 < width { relax(&distance, distances[index - width + 1], diagonal) }
                }
                distances[index] = distance
            }
        }

        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in stride(from: width - 1, through: 0, by: -1) {
                let index = y * width + x
                guard distances[index] > 0 else { continue }
                var distance = distances[index]
                if x + 1 < width { relax(&distance, distances[index + 1], 1) }
                if y + 1 < height {
                    relax(&distance, distances[index + width], 1)
                    if x > 0 { relax(&distance, distances[index + width - 1], diagonal) }
                    if x + 1 < width { relax(&distance, distances[index + width + 1], diagonal) }
                }
                distances[index] = distance
            }
        }

        let normalizedRadius = max(1, Float(radius))
        let strongestAlphaFloat = CGFloat(strongestAlpha)
        let tintRed = CGFloat(pixels[strongestOffset]) / strongestAlphaFloat
        let tintGreen = CGFloat(pixels[strongestOffset + 1]) / strongestAlphaFloat
        let tintBlue = CGFloat(pixels[strongestOffset + 2]) / strongestAlphaFloat

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let distance = distances[index]
                guard distance > 0, distance <= normalizedRadius else { continue }

                let falloff = pow(CGFloat(1 - distance / normalizedRadius), 1.35)
                let alpha = UInt8(max(0, min(255, (strongestAlphaFloat * falloff).rounded())))
                let offset = y * bytesPerRow + x * bytesPerPixel
                pixels[offset] = UInt8(max(0, min(255, (tintRed * CGFloat(alpha)).rounded())))
                pixels[offset + 1] = UInt8(max(0, min(255, (tintGreen * CGFloat(alpha)).rounded())))
                pixels[offset + 2] = UInt8(max(0, min(255, (tintBlue * CGFloat(alpha)).rounded())))
                pixels[offset + 3] = alpha
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              )
        else { return nil }

        return NSImage(cgImage: output, size: size)
    }

    /// Builds a shape-aware inner glow from the alpha silhouette. Edge glows
    /// fade inward from every contour, while center glows use the same distance
    /// field in reverse so irregular shapes do not collapse into a rectangular
    /// radial gradient.
    func preciseInnerGlow(radius: CGFloat, source: ImageEditorInnerGlowSource) -> NSImage? {
        guard radius > 0,
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return self }

        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let farDistance = Float(width + height + 1)
        let diagonal = Float(2).squareRoot()
        var distances = [Float](repeating: farDistance, count: width * height)
        var strongestOffset = 0
        var strongestAlpha: UInt8 = 0

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = pixels[offset + 3]
                if alpha == 0 {
                    distances[pixelIndex] = 0
                } else if alpha > strongestAlpha {
                    strongestAlpha = alpha
                    strongestOffset = offset
                }
            }
        }
        guard strongestAlpha > 0 else { return self }

        func relax(_ current: inout Float, _ neighbor: Float, _ weight: Float) {
            current = min(current, neighbor + weight)
        }

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                guard distances[index] > 0 else { continue }
                var distance = distances[index]
                if x > 0 { relax(&distance, distances[index - 1], 1) }
                if y > 0 {
                    relax(&distance, distances[index - width], 1)
                    if x > 0 { relax(&distance, distances[index - width - 1], diagonal) }
                    if x + 1 < width { relax(&distance, distances[index - width + 1], diagonal) }
                }
                distances[index] = distance
            }
        }

        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in stride(from: width - 1, through: 0, by: -1) {
                let index = y * width + x
                guard distances[index] > 0 else { continue }
                var distance = distances[index]
                if x + 1 < width { relax(&distance, distances[index + 1], 1) }
                if y + 1 < height {
                    relax(&distance, distances[index + width], 1)
                    if x > 0 { relax(&distance, distances[index + width - 1], diagonal) }
                    if x + 1 < width { relax(&distance, distances[index + width + 1], diagonal) }
                }
                distances[index] = distance
            }
        }

        let normalizedRadius = max(1, Float(radius))
        let strongestAlphaFloat = CGFloat(strongestAlpha)
        let tintRed = CGFloat(pixels[strongestOffset]) / strongestAlphaFloat
        let tintGreen = CGFloat(pixels[strongestOffset + 1]) / strongestAlphaFloat
        let tintBlue = CGFloat(pixels[strongestOffset + 2]) / strongestAlphaFloat

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let offset = y * bytesPerRow + x * bytesPerPixel
                let originalAlpha = pixels[offset + 3]
                guard originalAlpha > 0 else {
                    pixels[offset] = 0
                    pixels[offset + 1] = 0
                    pixels[offset + 2] = 0
                    pixels[offset + 3] = 0
                    continue
                }

                let horizontalBoundary = min(x + 1, width - x)
                let verticalBoundary = min(y + 1, height - y)
                let boundaryDistance = Float(min(horizontalBoundary, verticalBoundary))
                let distance = max(0, min(distances[index], boundaryDistance) - 1)
                let progress = max(0, min(1, distance / normalizedRadius))
                let strength: CGFloat
                switch source {
                case .edge:
                    strength = pow(CGFloat(1 - progress), 1.35)
                case .center:
                    strength = pow(CGFloat(progress), 0.85)
                }
                let alpha = UInt8(max(0, min(255, (strongestAlphaFloat * strength).rounded())))
                pixels[offset] = UInt8(max(0, min(255, (tintRed * CGFloat(alpha)).rounded())))
                pixels[offset + 1] = UInt8(max(0, min(255, (tintGreen * CGFloat(alpha)).rounded())))
                pixels[offset + 2] = UInt8(max(0, min(255, (tintBlue * CGFloat(alpha)).rounded())))
                pixels[offset + 3] = alpha
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              )
        else { return nil }

        return NSImage(cgImage: output, size: size)
    }
}
