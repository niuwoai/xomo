import AppKit
import CoreImage
import Foundation
import simd

extension NSImage {
    func applyingEffectContour(
        _ contour: ImageEditorLayerEffectContour,
        range: CGFloat = 1
    ) -> NSImage? {
        let normalizedRange = max(0.01, min(1, range))
        guard contour != .linear || abs(normalizedRange - 1) > 0.0001 else { return self }
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = CGFloat(pixels[offset + 3]) / 255
                guard alpha > 0 else { continue }
                let rangedAlpha = min(1, alpha / normalizedRange)
                let mappedAlpha = contour.mappedAlpha(rangedAlpha)
                let multiplier = mappedAlpha / alpha
                pixels[offset] = Self.scaledByte(pixels[offset], multiplier: multiplier)
                pixels[offset + 1] = Self.scaledByte(pixels[offset + 1], multiplier: multiplier)
                pixels[offset + 2] = Self.scaledByte(pixels[offset + 2], multiplier: multiplier)
                pixels[offset + 3] = UInt8(max(0, min(255, (mappedAlpha * 255).rounded())))
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return nil }

        return NSImage(cgImage: output, size: size)
    }

    func invertedAlphaTinted(within mask: NSImage, color: NSColor) -> NSImage? {
        guard let effectCGImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let maskCGImage = mask.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        let width = max(1, effectCGImage.width)
        let height = max(1, effectCGImage.height)
        guard maskCGImage.width == width, maskCGImage.height == height else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var effectPixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        var maskPixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let effectContext = CGContext(
            data: &effectPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ),
              let maskContext = CGContext(
                data: &maskPixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
              )
        else { return nil }

        for context in [effectContext, maskContext] {
            context.interpolationQuality = .none
        }
        effectContext.draw(effectCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        maskContext.draw(maskCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let tint = color.usingColorSpace(.deviceRGB) ?? color
        let tintAlpha = max(0, min(1, tint.alphaComponent))
        var outputPixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let maskAlpha = CGFloat(maskPixels[offset + 3]) / 255
                guard maskAlpha > 0 else { continue }

                let effectAlpha = CGFloat(effectPixels[offset + 3]) / 255
                let outputAlpha = max(0, min(1, maskAlpha - min(maskAlpha, effectAlpha))) * tintAlpha
                guard outputAlpha > 0 else { continue }

                outputPixels[offset] = UInt8(max(0, min(255, (tint.redComponent * outputAlpha * 255).rounded())))
                outputPixels[offset + 1] = UInt8(max(0, min(255, (tint.greenComponent * outputAlpha * 255).rounded())))
                outputPixels[offset + 2] = UInt8(max(0, min(255, (tint.blueComponent * outputAlpha * 255).rounded())))
                outputPixels[offset + 3] = UInt8(max(0, min(255, (outputAlpha * 255).rounded())))
            }
        }

        guard let provider = CGDataProvider(data: Data(outputPixels) as CFData),
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

    func shadowNoised(amount: CGFloat) -> NSImage? {
        let normalizedAmount = max(0, min(1, amount))
        guard normalizedAmount > 0,
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return self }

        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = pixels[offset + 3]
                guard alpha > 0 else { continue }
                let noise = Self.stableNoise(x: x, y: y)
                let multiplier = 1 - normalizedAmount + normalizedAmount * noise
                let adjustedAlpha = CGFloat(alpha) * multiplier
                pixels[offset] = Self.scaledByte(pixels[offset], multiplier: multiplier)
                pixels[offset + 1] = Self.scaledByte(pixels[offset + 1], multiplier: multiplier)
                pixels[offset + 2] = Self.scaledByte(pixels[offset + 2], multiplier: multiplier)
                pixels[offset + 3] = UInt8(max(0, min(255, adjustedAlpha.rounded())))
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return nil }

        return NSImage(cgImage: output, size: size)
    }

    static func stableNoise(x: Int, y: Int) -> CGFloat {
        var value = UInt32(truncatingIfNeeded: x)
        value &*= 374_761_393
        value &+= UInt32(truncatingIfNeeded: y) &* 668_265_263
        value = (value ^ (value >> 13)) &* 1_274_126_177
        value ^= value >> 16
        return CGFloat(value & 0xff) / 255
    }

    static func scaledByte(_ value: UInt8, multiplier: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, (CGFloat(value) * multiplier).rounded())))
    }

    func outsideStrokeCanvas(fillImage: NSImage, width: Int, contentRect: CGRect, outputSize: CGSize) -> NSImage? {
        let maskImage = alphaTinted(color: .white)
        let strokeMask = NSImage.rendered(size: outputSize) { _ in
            drawExpandedAlpha(
                maskImage,
                width: width,
                contentRect: contentRect
            )
            draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: size),
                operation: .destinationOut,
                fraction: 1
            )
        }
        return NSImage.rendered(size: outputSize) { _ in
            fillImage.draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: CGRect(origin: .zero, size: fillImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            strokeMask?.draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: CGRect(origin: .zero, size: outputSize),
                operation: .destinationIn,
                fraction: 1
            )
        }
    }

    func insideStrokeCanvas(fillImage: NSImage, width: Int, contentRect: CGRect, outputSize: CGSize) -> NSImage? {
        let maskImage = alphaTinted(color: .white)
        let erodedImage = NSImage.rendered(size: outputSize) { _ in
            maskImage.draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: maskImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            applyErosionMask(
                maskImage,
                width: width,
                contentRect: contentRect
            )
        }
        let strokeMask = NSImage.rendered(size: outputSize) { _ in
            maskImage.draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: maskImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            erodedImage?.draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: CGRect(origin: .zero, size: outputSize),
                operation: .destinationOut,
                fraction: 1
            )
        }
        return NSImage.rendered(size: outputSize) { _ in
            fillImage.draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: CGRect(origin: .zero, size: fillImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            strokeMask?.draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: CGRect(origin: .zero, size: outputSize),
                operation: .destinationIn,
                fraction: 1
            )
        }
    }

    private func drawExpandedAlpha(_ image: NSImage, width: Int, contentRect: CGRect) {
        image.draw(
            in: contentRect,
            from: CGRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1
        )
        let directions = 24
        for radius in 1...max(1, width) {
            for step in 0..<directions {
                let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                image.draw(
                    in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                    from: CGRect(origin: .zero, size: image.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }
        }
    }

    private func applyErosionMask(_ maskImage: NSImage, width: Int, contentRect: CGRect) {
        let directions = 24
        for radius in 1...max(1, width) {
            for step in 0..<directions {
                let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                maskImage.draw(
                    in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                    from: CGRect(origin: .zero, size: maskImage.size),
                    operation: .destinationIn,
                    fraction: 1
                )
            }
        }
    }

    func compositedWithAlphaMask(_ mask: NSImage) -> NSImage? {
        NSImage.rendered(size: size) { rect in
            draw(
                in: rect,
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: rect,
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
    }

    func processedLayerMask(density: Double, feather: Double) -> NSImage? {
        let normalizedDensity = max(0, min(1, density))
        let normalizedFeather = max(0, min(80, feather))
        let featheredMask = normalizedFeather > 0 ? (blurred(radius: normalizedFeather) ?? self) : self
        guard normalizedDensity < 1 else { return featheredMask }
        guard let alpha = featheredMask.alphaPlane() else { return featheredMask }
        let adjustedAlpha = alpha.values.map { value -> UInt8 in
            let revealed = 255 - Double(255 - Int(value)) * normalizedDensity
            return UInt8(max(0, min(255, Int(revealed.rounded()))))
        }
        return NSImage.alphaMaskImage(width: alpha.width, height: alpha.height, alpha: adjustedAlpha)
    }

    func alphaPlane() -> (width: Int, height: Int, values: [UInt8])? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                alpha[y * width + x] = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
            }
        }
        return (width, height, alpha)
    }

    func withOpacity(_ opacity: CGFloat) -> NSImage? {
        let normalizedOpacity = max(0, min(1, opacity))
        return NSImage.rendered(size: size) { rect in
            draw(
                in: rect,
                from: CGRect(origin: .zero, size: size),
                operation: .sourceOver,
                fraction: normalizedOpacity
            )
        }
    }
}

extension NSImage {
    func grayscaleAlphaPreviewImage(targetSize: CGSize) -> NSImage? {
        guard let alpha = alphaPlane() else { return nil }
        return ImageEditorSelectionMask(
            width: alpha.width,
            height: alpha.height,
            alpha: alpha.values
        ).grayscalePreviewImage(targetSize: targetSize)
    }
}

struct ImageEditorTheme {
    static let window = NSColor(calibratedWhite: 0.11, alpha: 1)
    static let chrome = NSColor(calibratedRed: 0.105, green: 0.118, blue: 0.145, alpha: 1)
    static let panel = NSColor(calibratedWhite: 0.23, alpha: 1)
    static let panelRaised = NSColor(calibratedWhite: 0.29, alpha: 1)
    static let border = NSColor(calibratedWhite: 0.38, alpha: 1)
    static let selected = NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.78, alpha: 1)
    static let text = NSColor(calibratedWhite: 0.92, alpha: 1)
    static let mutedText = NSColor(calibratedWhite: 0.68, alpha: 1)
    static let menuText = NSColor(calibratedRed: 0.84, green: 0.88, blue: 0.94, alpha: 1)
    static let menuMutedText = NSColor(calibratedRed: 0.63, green: 0.68, blue: 0.77, alpha: 1)
    static let exportAccent = NSColor(calibratedRed: 0.18, green: 0.66, blue: 0.95, alpha: 1)
    static let exportAccentPressed = NSColor(calibratedRed: 0.12, green: 0.49, blue: 0.79, alpha: 1)
}
