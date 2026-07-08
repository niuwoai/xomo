//
//  ImageEditorAdjustments.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

extension NSImage {
    func adjusted(
        kind: ImageEditorAdjustment,
        amount: Double,
        settings: ImageEditorAdjustmentSettings = ImageEditorAdjustmentSettings()
    ) -> NSImage? {
        let clamped = max(-1, min(1, amount))
        switch kind {
        case .threshold:
            return thresholded(amount: clamped)
        case .levels:
            return leveled(settings: settings)
        case .curves:
            return curved(settings: settings)
        case .colorBalance:
            return colorBalanced(settings: settings)
        case .brightness, .contrast, .saturation, .exposure, .hue, .invert, .blur, .sharpen:
            return coreImageAdjusted(kind: kind, amount: clamped)
        }
    }

    func applyingAdjustment(
        kind: ImageEditorAdjustment,
        amount: Double,
        settings: ImageEditorAdjustmentSettings = ImageEditorAdjustmentSettings(),
        mask: NSImage?
    ) -> NSImage? {
        guard let adjusted = adjusted(kind: kind, amount: amount, settings: settings) else { return nil }
        guard let mask else { return adjusted }
        let maskedAdjusted = NSImage.rendered(size: size) { _ in
            adjusted.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: adjusted.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
        guard let maskedAdjusted else { return adjusted }
        return NSImage.rendered(size: size) { _ in
            draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
            maskedAdjusted.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: maskedAdjusted.size),
                operation: .sourceOver,
                fraction: 1
            )
        } ?? adjusted
    }

    func preservingAlpha(from source: NSImage) -> NSImage? {
        let targetSize = source.size
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        let width = max(1, Int(targetSize.width.rounded()))
        let height = max(1, Int(targetSize.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        func pixels(for image: NSImage) -> [UInt8]? {
            var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let context = CGContext(
                    data: &pixels,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else { return nil }

            context.interpolationQuality = .none
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
            return pixels
        }

        guard var outputPixels = pixels(for: self),
              let sourcePixels = pixels(for: source)
        else { return nil }

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let sourceAlpha = sourcePixels[offset + 3]
                let editedAlpha = outputPixels[offset + 3]

                guard sourceAlpha > 0 else {
                    outputPixels[offset] = 0
                    outputPixels[offset + 1] = 0
                    outputPixels[offset + 2] = 0
                    outputPixels[offset + 3] = 0
                    continue
                }

                guard editedAlpha > 0 else {
                    outputPixels[offset] = sourcePixels[offset]
                    outputPixels[offset + 1] = sourcePixels[offset + 1]
                    outputPixels[offset + 2] = sourcePixels[offset + 2]
                    outputPixels[offset + 3] = sourceAlpha
                    continue
                }

                let sourceA = Double(sourceAlpha) / 255
                let editedA = Double(editedAlpha) / 255
                outputPixels[offset] = Self.byte(Double(outputPixels[offset]) / 255 / editedA * sourceA)
                outputPixels[offset + 1] = Self.byte(Double(outputPixels[offset + 1]) / 255 / editedA * sourceA)
                outputPixels[offset + 2] = Self.byte(Double(outputPixels[offset + 2]) / 255 / editedA * sourceA)
                outputPixels[offset + 3] = sourceAlpha
            }
        }

        guard let provider = CGDataProvider(data: Data(outputPixels) as CFData),
              let image = CGImage(
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

        return NSImage(cgImage: image, size: targetSize)
    }

    private func coreImageAdjusted(kind: ImageEditorAdjustment, amount: Double) -> NSImage? {
        guard let ciImage = ciImageForEditing() else { return nil }
        let output: CIImage?

        switch kind {
        case .brightness:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.brightness = Float(amount)
            output = filter.outputImage
        case .contrast:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.contrast = Float(1 + amount)
            output = filter.outputImage
        case .saturation:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.saturation = Float(max(0, 1 + amount))
            output = filter.outputImage
        case .exposure:
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = ciImage
            filter.ev = Float(amount * 2)
            output = filter.outputImage
        case .hue:
            let filter = CIFilter.hueAdjust()
            filter.inputImage = ciImage
            filter.angle = Float(amount * .pi)
            output = filter.outputImage
        case .invert:
            let filter = CIFilter.colorInvert()
            filter.inputImage = ciImage
            output = filter.outputImage
        case .blur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = ciImage.clampedToExtent()
            filter.radius = Float(max(0, amount) * 18)
            output = filter.outputImage?.cropped(to: ciImage.extent)
        case .sharpen:
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = ciImage
            filter.sharpness = Float(max(0, amount) * 1.5)
            output = filter.outputImage
        case .threshold, .levels, .curves, .colorBalance:
            return nil
        }

        guard let output,
              let cgImage = ImageEditorImageProcessing.ciContext.createCGImage(output, from: ciImage.extent)
        else { return nil }
        return NSImage(cgImage: cgImage, size: size)
    }

    private func thresholded(amount: Double) -> NSImage? {
        pixelMapped { red, green, blue, alpha in
            let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
            let threshold = 0.5 + amount * 0.49
            let output = luminance >= threshold ? 1.0 : 0.0
            return (output, output, output, alpha)
        }
    }

    private func leveled(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let settings = settings.normalized()
        let range = max(0.01, settings.levelsWhitePoint - settings.levelsBlackPoint)
        let inverseGamma = 1 / settings.levelsGamma
        return pixelMapped { red, green, blue, alpha in
            (
                Self.mapLevel(red, black: settings.levelsBlackPoint, range: range, inverseGamma: inverseGamma),
                Self.mapLevel(green, black: settings.levelsBlackPoint, range: range, inverseGamma: inverseGamma),
                Self.mapLevel(blue, black: settings.levelsBlackPoint, range: range, inverseGamma: inverseGamma),
                alpha
            )
        }
    }

    private func curved(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let curve = Self.curveControlPoints(for: settings.normalized())
        return pixelMapped { red, green, blue, alpha in
            (
                Self.mapCurve(red, points: curve),
                Self.mapCurve(green, points: curve),
                Self.mapCurve(blue, points: curve),
                alpha
            )
        }
    }

    private func colorBalanced(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let settings = settings.normalized()
        return pixelMapped { red, green, blue, alpha in
            let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
            let shadowWeight = max(0, min(1, (0.55 - luminance) / 0.55))
            let highlightWeight = max(0, min(1, (luminance - 0.45) / 0.55))
            let midtoneWeight = max(0, 1 - abs(luminance - 0.5) / 0.5)

            var outputRed = red
            var outputGreen = green
            var outputBlue = blue
            Self.applyColorBalance(
                cyanRed: settings.colorBalanceShadowsCyanRed,
                magentaGreen: settings.colorBalanceShadowsMagentaGreen,
                yellowBlue: settings.colorBalanceShadowsYellowBlue,
                weight: shadowWeight,
                red: &outputRed,
                green: &outputGreen,
                blue: &outputBlue
            )
            Self.applyColorBalance(
                cyanRed: settings.colorBalanceMidtonesCyanRed,
                magentaGreen: settings.colorBalanceMidtonesMagentaGreen,
                yellowBlue: settings.colorBalanceMidtonesYellowBlue,
                weight: midtoneWeight,
                red: &outputRed,
                green: &outputGreen,
                blue: &outputBlue
            )
            Self.applyColorBalance(
                cyanRed: settings.colorBalanceHighlightsCyanRed,
                magentaGreen: settings.colorBalanceHighlightsMagentaGreen,
                yellowBlue: settings.colorBalanceHighlightsYellowBlue,
                weight: highlightWeight,
                red: &outputRed,
                green: &outputGreen,
                blue: &outputBlue
            )
            return (outputRed, outputGreen, outputBlue, alpha)
        }
    }

    private static func mapLevel(_ value: Double, black: Double, range: Double, inverseGamma: Double) -> Double {
        let normalized = max(0, min(1, (value - black) / range))
        return pow(normalized, inverseGamma)
    }

    private static func curveControlPoints(for settings: ImageEditorAdjustmentSettings) -> [(Double, Double)] {
        [
            (0, 0),
            (0.25, max(0, min(1, 0.25 + settings.curvesShadows * 0.25))),
            (0.5, max(0, min(1, 0.5 + settings.curvesMidtones * 0.35))),
            (0.75, max(0, min(1, 0.75 + settings.curvesHighlights * 0.25))),
            (1, 1)
        ]
    }

    private static func mapCurve(_ value: Double, points: [(Double, Double)]) -> Double {
        let input = max(0, min(1, value))
        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            guard input >= start.0 && input <= end.0 else { continue }
            let span = max(0.001, end.0 - start.0)
            let t = max(0, min(1, (input - start.0) / span))
            let smooth = t * t * (3 - 2 * t)
            return start.1 + (end.1 - start.1) * smooth
        }
        return input
    }

    private static func applyColorBalance(
        cyanRed: Double,
        magentaGreen: Double,
        yellowBlue: Double,
        weight: Double,
        red: inout Double,
        green: inout Double,
        blue: inout Double
    ) {
        let strength = max(0, min(1, weight)) * 0.28
        red += cyanRed * strength
        green += magentaGreen * strength
        blue += yellowBlue * strength
    }

    private func pixelMapped(
        _ transform: (_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) -> (Double, Double, Double, Double)
    ) -> NSImage? {
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
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let (red, green, blue, alpha) = transform(
                    Double(pixels[offset]) / 255,
                    Double(pixels[offset + 1]) / 255,
                    Double(pixels[offset + 2]) / 255,
                    Double(pixels[offset + 3]) / 255
                )
                pixels[offset] = Self.byte(red)
                pixels[offset + 1] = Self.byte(green)
                pixels[offset + 2] = Self.byte(blue)
                pixels[offset + 3] = Self.byte(alpha)
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

    private static func byte(_ value: Double) -> UInt8 {
        UInt8((max(0, min(1, value)) * 255).rounded())
    }
}
