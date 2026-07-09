//
//  ImageEditorFilters.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

extension NSImage {
    func ciImageForEditing() -> CIImage? {
        if let tiffRepresentation {
            return CIImage(data: tiffRepresentation)
        }
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return CIImage(cgImage: cgImage)
    }

    func filtered(
        kind: ImageEditorFilter,
        intensity: Double,
        settings: ImageEditorFilterSettings = ImageEditorFilterSettings()
    ) -> NSImage? {
        let clamped = max(0, min(1, intensity))
        if kind == .addNoise {
            return addingDeterministicNoise(intensity: clamped)
        }
        if kind == .median {
            return medianDenoised(intensity: clamped)
        }
        if kind == .unsharpMask {
            return unsharpMasked(intensity: clamped, settings: settings)
        }
        if kind == .highPass {
            return highPassed(intensity: clamped)
        }
        if kind == .emboss {
            return embossed(intensity: clamped)
        }
        if kind == .findEdges {
            return findingEdges(intensity: clamped)
        }
        if kind == .minimum {
            return morphologyFiltered(intensity: clamped, useMaximum: false)
        }
        if kind == .maximum {
            return morphologyFiltered(intensity: clamped, useMaximum: true)
        }
        if kind == .oilPaint {
            return oilPainted(intensity: clamped)
        }
        if kind == .vignette {
            return vignetted(intensity: clamped)
        }
        if kind == .liquifyPush {
            return liquifyPushed(intensity: clamped, settings: settings)
        }

        guard let ciImage = ciImageForEditing() else { return nil }
        let output: CIImage?

        switch kind {
        case .gaussianBlur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = ciImage.clampedToExtent()
            filter.radius = Float(clamped * 18)
            output = filter.outputImage?.cropped(to: ciImage.extent)
        case .sharpen:
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = ciImage
            filter.sharpness = Float(clamped * 1.5)
            output = filter.outputImage
        case .pixelate:
            let filter = CIFilter.pixellate()
            filter.inputImage = ciImage
            filter.center = CGPoint(x: size.width / 2, y: size.height / 2)
            filter.scale = Float(2 + clamped * 32)
            output = filter.outputImage?.cropped(to: ciImage.extent)
        case .motionBlur:
            let filter = CIFilter.motionBlur()
            filter.inputImage = ciImage.clampedToExtent()
            filter.radius = Float(clamped * 28)
            filter.angle = 0
            output = filter.outputImage?.cropped(to: ciImage.extent)
        case .addNoise:
            return addingDeterministicNoise(intensity: clamped)
        case .median:
            return medianDenoised(intensity: clamped)
        case .unsharpMask:
            return unsharpMasked(intensity: clamped, settings: settings)
        case .highPass:
            return highPassed(intensity: clamped)
        case .emboss:
            return embossed(intensity: clamped)
        case .findEdges:
            return findingEdges(intensity: clamped)
        case .minimum:
            return morphologyFiltered(intensity: clamped, useMaximum: false)
        case .maximum:
            return morphologyFiltered(intensity: clamped, useMaximum: true)
        case .oilPaint:
            return oilPainted(intensity: clamped)
        case .vignette:
            return vignetted(intensity: clamped)
        case .liquifyPush:
            return liquifyPushed(intensity: clamped, settings: settings)
        }

        guard let output,
              let cgImage = ImageEditorImageProcessing.ciContext.createCGImage(output, from: ciImage.extent)
        else { return nil }
        return NSImage(cgImage: cgImage, size: size)
    }

    func applyingFilter(
        kind: ImageEditorFilter,
        intensity: Double,
        settings: ImageEditorFilterSettings = ImageEditorFilterSettings(),
        mask: NSImage?
    ) -> NSImage? {
        guard let filtered = filtered(kind: kind, intensity: intensity, settings: settings) else { return nil }
        guard let mask else { return filtered }
        let maskedFiltered = NSImage.rendered(size: size) { _ in
            filtered.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: filtered.size),
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
        guard let maskedFiltered else { return filtered }
        return NSImage.rendered(size: size) { _ in
            draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
            maskedFiltered.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: maskedFiltered.size),
                operation: .sourceOver,
                fraction: 1
            )
        } ?? filtered
    }

    private func addingDeterministicNoise(intensity: Double) -> NSImage? {
        let amount = max(0, min(1, intensity)) * 0.45
        return pixelMappedByCoordinate { x, y, red, green, blue, alpha in
            let noise = Self.coordinateNoise(x: x, y: y) * amount * alpha
            return (
                Self.premultipliedChannel(red + noise, alpha: alpha),
                Self.premultipliedChannel(green + noise, alpha: alpha),
                Self.premultipliedChannel(blue + noise, alpha: alpha),
                alpha
            )
        }
    }

    private func pixelMappedByCoordinate(
        _ transform: (
            _ x: Int,
            _ y: Int,
            _ red: Double,
            _ green: Double,
            _ blue: Double,
            _ alpha: Double
        ) -> (Double, Double, Double, Double)
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
                    x,
                    y,
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

    private func medianDenoised(intensity: Double) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        guard clampedIntensity > 0 else { return self }
        return pixelMappedFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let radius = clampedIntensity < 0.5 ? 1 : 2
            let offset = y * bytesPerRow + x * bytesPerPixel
            var reds: [Double] = []
            var greens: [Double] = []
            var blues: [Double] = []
            let capacity = (radius * 2 + 1) * (radius * 2 + 1)
            reds.reserveCapacity(capacity)
            greens.reserveCapacity(capacity)
            blues.reserveCapacity(capacity)

            for sampleY in max(0, y - radius)...min(height - 1, y + radius) {
                for sampleX in max(0, x - radius)...min(width - 1, x + radius) {
                    let sampleOffset = sampleY * bytesPerRow + sampleX * bytesPerPixel
                    reds.append(Double(pixels[sampleOffset]) / 255)
                    greens.append(Double(pixels[sampleOffset + 1]) / 255)
                    blues.append(Double(pixels[sampleOffset + 2]) / 255)
                }
            }

            let alpha = Double(pixels[offset + 3]) / 255
            let red = Double(pixels[offset]) / 255
            let green = Double(pixels[offset + 1]) / 255
            let blue = Double(pixels[offset + 2]) / 255
            let medianRed = Self.medianValue(reds)
            let medianGreen = Self.medianValue(greens)
            let medianBlue = Self.medianValue(blues)
            return (
                Self.premultipliedChannel(red + (medianRed - red) * clampedIntensity, alpha: alpha),
                Self.premultipliedChannel(green + (medianGreen - green) * clampedIntensity, alpha: alpha),
                Self.premultipliedChannel(blue + (medianBlue - blue) * clampedIntensity, alpha: alpha),
                alpha
            )
        }
    }

    private func unsharpMasked(intensity: Double, settings: ImageEditorFilterSettings) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        let normalizedSettings = settings.normalized()
        guard clampedIntensity > 0 else { return self }
        return pixelMappedFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let radius = max(1, Int(normalizedSettings.unsharpRadius.rounded()))
            let amount = 0.6 + clampedIntensity * 1.8
            let offset = y * bytesPerRow + x * bytesPerPixel
            let alpha = Double(pixels[offset + 3]) / 255
            let red = Double(pixels[offset]) / 255
            let green = Double(pixels[offset + 1]) / 255
            let blue = Double(pixels[offset + 2]) / 255
            let blurred = Self.averageColor(
                x: x,
                y: y,
                radius: radius,
                width: width,
                height: height,
                pixels: pixels,
                bytesPerRow: bytesPerRow,
                bytesPerPixel: bytesPerPixel
            )
            let edgeDelta = max(
                abs(red - blurred.red),
                abs(green - blurred.green),
                abs(blue - blurred.blue)
            )
            guard edgeDelta >= normalizedSettings.unsharpThreshold else {
                return (red, green, blue, alpha)
            }
            return (
                Self.premultipliedChannel(red + (red - blurred.red) * amount, alpha: alpha),
                Self.premultipliedChannel(green + (green - blurred.green) * amount, alpha: alpha),
                Self.premultipliedChannel(blue + (blue - blurred.blue) * amount, alpha: alpha),
                alpha
            )
        }
    }

    private func highPassed(intensity: Double) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        let radius = max(1, Int((1 + clampedIntensity * 9).rounded()))
        let contrast = 1.4 + clampedIntensity * 2.4
        return pixelMappedFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let offset = y * bytesPerRow + x * bytesPerPixel
            let alpha = Double(pixels[offset + 3]) / 255
            let red = Double(pixels[offset]) / 255
            let green = Double(pixels[offset + 1]) / 255
            let blue = Double(pixels[offset + 2]) / 255
            let blurred = Self.averageColor(
                x: x,
                y: y,
                radius: radius,
                width: width,
                height: height,
                pixels: pixels,
                bytesPerRow: bytesPerRow,
                bytesPerPixel: bytesPerPixel
            )
            let neutral = 0.5 * alpha
            return (
                Self.premultipliedChannel(neutral + (red - blurred.red) * contrast, alpha: alpha),
                Self.premultipliedChannel(neutral + (green - blurred.green) * contrast, alpha: alpha),
                Self.premultipliedChannel(neutral + (blue - blurred.blue) * contrast, alpha: alpha),
                alpha
            )
        }
    }

    private func embossed(intensity: Double) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        let strength = 1.2 + clampedIntensity * 2.6
        return pixelMappedFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let offset = y * bytesPerRow + x * bytesPerPixel
            let alpha = Double(pixels[offset + 3]) / 255
            let shadow = Self.luminance(
                x: max(0, x - 1),
                y: max(0, y - 1),
                pixels: pixels,
                bytesPerRow: bytesPerRow,
                bytesPerPixel: bytesPerPixel
            )
            let highlight = Self.luminance(
                x: min(width - 1, x + 1),
                y: min(height - 1, y + 1),
                pixels: pixels,
                bytesPerRow: bytesPerRow,
                bytesPerPixel: bytesPerPixel
            )
            let relief = (highlight - shadow) * strength
            let value = 0.5 * alpha + relief
            return (
                Self.premultipliedChannel(value, alpha: alpha),
                Self.premultipliedChannel(value, alpha: alpha),
                Self.premultipliedChannel(value, alpha: alpha),
                alpha
            )
        }
    }

    private func findingEdges(intensity: Double) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        let strength = 1.2 + clampedIntensity * 3.4
        return pixelMappedFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let offset = y * bytesPerRow + x * bytesPerPixel
            let alpha = Double(pixels[offset + 3]) / 255
            let left = max(0, x - 1)
            let right = min(width - 1, x + 1)
            let top = max(0, y - 1)
            let bottom = min(height - 1, y + 1)
            let topLeft = Self.luminance(x: left, y: top, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
            let topCenter = Self.luminance(x: x, y: top, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
            let topRight = Self.luminance(x: right, y: top, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
            let middleLeft = Self.luminance(x: left, y: y, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
            let middleRight = Self.luminance(x: right, y: y, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
            let bottomLeft = Self.luminance(x: left, y: bottom, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
            let bottomCenter = Self.luminance(x: x, y: bottom, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
            let bottomRight = Self.luminance(x: right, y: bottom, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
            let horizontal = -topLeft - 2 * middleLeft - bottomLeft + topRight + 2 * middleRight + bottomRight
            let vertical = -topLeft - 2 * topCenter - topRight + bottomLeft + 2 * bottomCenter + bottomRight
            let edge = min(1, hypot(horizontal, vertical) * strength)
            let value = alpha * (1 - edge)
            return (
                Self.premultipliedChannel(value, alpha: alpha),
                Self.premultipliedChannel(value, alpha: alpha),
                Self.premultipliedChannel(value, alpha: alpha),
                alpha
            )
        }
    }

    private func morphologyFiltered(intensity: Double, useMaximum: Bool) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        let radius = max(1, Int((1 + clampedIntensity * 4).rounded()))
        return pixelMappedFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let offset = y * bytesPerRow + x * bytesPerPixel
            let alpha = Double(pixels[offset + 3]) / 255
            var red = useMaximum ? 0.0 : 1.0
            var green = useMaximum ? 0.0 : 1.0
            var blue = useMaximum ? 0.0 : 1.0
            for sampleY in max(0, y - radius)...min(height - 1, y + radius) {
                for sampleX in max(0, x - radius)...min(width - 1, x + radius) {
                    let sampleOffset = sampleY * bytesPerRow + sampleX * bytesPerPixel
                    let sampleRed = Double(pixels[sampleOffset]) / 255
                    let sampleGreen = Double(pixels[sampleOffset + 1]) / 255
                    let sampleBlue = Double(pixels[sampleOffset + 2]) / 255
                    red = useMaximum ? max(red, sampleRed) : min(red, sampleRed)
                    green = useMaximum ? max(green, sampleGreen) : min(green, sampleGreen)
                    blue = useMaximum ? max(blue, sampleBlue) : min(blue, sampleBlue)
                }
            }
            return (
                Self.premultipliedChannel(red, alpha: alpha),
                Self.premultipliedChannel(green, alpha: alpha),
                Self.premultipliedChannel(blue, alpha: alpha),
                alpha
            )
        }
    }

    private func oilPainted(intensity: Double) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        let radius = max(1, Int((1 + clampedIntensity * 5).rounded()))
        let bucketCount = max(6, Int((18 - clampedIntensity * 10).rounded()))
        return pixelMappedFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let offset = y * bytesPerRow + x * bytesPerPixel
            let alpha = Double(pixels[offset + 3]) / 255
            var buckets = Array(
                repeating: (count: 0, red: 0.0, green: 0.0, blue: 0.0),
                count: bucketCount
            )
            for sampleY in max(0, y - radius)...min(height - 1, y + radius) {
                for sampleX in max(0, x - radius)...min(width - 1, x + radius) {
                    let sampleOffset = sampleY * bytesPerRow + sampleX * bytesPerPixel
                    let sampleRed = Double(pixels[sampleOffset]) / 255
                    let sampleGreen = Double(pixels[sampleOffset + 1]) / 255
                    let sampleBlue = Double(pixels[sampleOffset + 2]) / 255
                    let luminance = sampleRed * 0.299 + sampleGreen * 0.587 + sampleBlue * 0.114
                    let bucketIndex = min(bucketCount - 1, max(0, Int((luminance * Double(bucketCount - 1)).rounded())))
                    buckets[bucketIndex].count += 1
                    buckets[bucketIndex].red += sampleRed
                    buckets[bucketIndex].green += sampleGreen
                    buckets[bucketIndex].blue += sampleBlue
                }
            }
            guard let dominant = buckets.max(by: { $0.count < $1.count }),
                  dominant.count > 0
            else {
                return (
                    Double(pixels[offset]) / 255,
                    Double(pixels[offset + 1]) / 255,
                    Double(pixels[offset + 2]) / 255,
                    alpha
                )
            }
            let count = Double(dominant.count)
            return (
                Self.premultipliedChannel(dominant.red / count, alpha: alpha),
                Self.premultipliedChannel(dominant.green / count, alpha: alpha),
                Self.premultipliedChannel(dominant.blue / count, alpha: alpha),
                alpha
            )
        }
    }

    private func vignetted(intensity: Double) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        guard clampedIntensity > 0 else { return self }
        let strength = 0.85 * clampedIntensity
        return pixelMappedFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let offset = y * bytesPerRow + x * bytesPerPixel
            let alpha = Double(pixels[offset + 3]) / 255
            let centerX = Double(max(width - 1, 1)) / 2
            let centerY = Double(max(height - 1, 1)) / 2
            let normalizedX = (Double(x) - centerX) / max(centerX, 1)
            let normalizedY = (Double(y) - centerY) / max(centerY, 1)
            let radialDistance = min(1, hypot(normalizedX, normalizedY) / sqrt(2))
            let featherStart = 0.28
            let feather = max(0, min(1, (radialDistance - featherStart) / (1 - featherStart)))
            let falloff = pow(feather, 1.8)
            let factor = 1 - falloff * strength
            return (
                Self.premultipliedChannel(Double(pixels[offset]) / 255 * factor, alpha: alpha),
                Self.premultipliedChannel(Double(pixels[offset + 1]) / 255 * factor, alpha: alpha),
                Self.premultipliedChannel(Double(pixels[offset + 2]) / 255 * factor, alpha: alpha),
                alpha
            )
        }
    }

    private func liquifyPushed(intensity: Double, settings: ImageEditorFilterSettings) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        guard clampedIntensity > 0 else { return self }
        let normalizedSettings = settings.normalized()
        return pixelSampledFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let centerX = Double(max(width - 1, 1)) / 2
            let centerY = Double(max(height - 1, 1)) / 2
            let radius = max(2, min(Double(width), Double(height)) * 0.45)
            let dx = Double(x) - centerX
            let dy = Double(y) - centerY
            let distance = hypot(dx, dy)
            guard distance < radius else {
                return Self.samplePixel(
                    x: Double(x),
                    y: Double(y),
                    width: width,
                    height: height,
                    pixels: pixels,
                    bytesPerRow: bytesPerRow,
                    bytesPerPixel: bytesPerPixel
                )
            }

            let falloff = pow(1 - distance / radius, 2)
            let maxShift = radius * 0.42 * clampedIntensity
            let sourceX = Double(x) - normalizedSettings.liquifyPushX * maxShift * falloff
            let sourceY = Double(y) - normalizedSettings.liquifyPushY * maxShift * falloff
            return Self.samplePixel(
                x: sourceX,
                y: sourceY,
                width: width,
                height: height,
                pixels: pixels,
                bytesPerRow: bytesPerRow,
                bytesPerPixel: bytesPerPixel
            )
        }
    }

    private func pixelMappedFromBuffer(
        _ transform: (
            _ x: Int,
            _ y: Int,
            _ width: Int,
            _ height: Int,
            _ pixels: [UInt8],
            _ bytesPerRow: Int,
            _ bytesPerPixel: Int
        ) -> (Double, Double, Double, Double)
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

        let sourcePixels = pixels
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let (red, green, blue, alpha) = transform(
                    x,
                    y,
                    width,
                    height,
                    sourcePixels,
                    bytesPerRow,
                    bytesPerPixel
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

    private func pixelSampledFromBuffer(
        _ transform: (
            _ x: Int,
            _ y: Int,
            _ width: Int,
            _ height: Int,
            _ pixels: [UInt8],
            _ bytesPerRow: Int,
            _ bytesPerPixel: Int
        ) -> (Double, Double, Double, Double)
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

        let sourcePixels = pixels
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let (red, green, blue, alpha) = transform(
                    x,
                    y,
                    width,
                    height,
                    sourcePixels,
                    bytesPerRow,
                    bytesPerPixel
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

    private static func coordinateNoise(x: Int, y: Int) -> Double {
        let xMultiplier: UInt64 = 0x9E3779B185EBCA87
        let yMultiplier: UInt64 = 0xC2B2AE3D27D4EB4F
        let avalancheMultiplier: UInt64 = 0xFF51AFD7ED558CCD
        var value = UInt64(x + 1) &* xMultiplier
        value ^= UInt64(y + 1) &* yMultiplier
        value ^= value >> 33
        value = value &* avalancheMultiplier
        value ^= value >> 33
        let unit = Double(value & 0xFFFF) / 65_535
        return unit * 2 - 1
    }

    private static func premultipliedChannel(_ value: Double, alpha: Double) -> Double {
        min(max(0, alpha), max(0, min(1, value)))
    }

    private static func medianValue(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private static func averageColor(
        x: Int,
        y: Int,
        radius: Int,
        width: Int,
        height: Int,
        pixels: [UInt8],
        bytesPerRow: Int,
        bytesPerPixel: Int
    ) -> (red: Double, green: Double, blue: Double) {
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var count = 0.0
        for sampleY in max(0, y - radius)...min(height - 1, y + radius) {
            for sampleX in max(0, x - radius)...min(width - 1, x + radius) {
                let sampleOffset = sampleY * bytesPerRow + sampleX * bytesPerPixel
                red += Double(pixels[sampleOffset]) / 255
                green += Double(pixels[sampleOffset + 1]) / 255
                blue += Double(pixels[sampleOffset + 2]) / 255
                count += 1
            }
        }
        guard count > 0 else { return (0, 0, 0) }
        return (red / count, green / count, blue / count)
    }

    private static func luminance(
        x: Int,
        y: Int,
        pixels: [UInt8],
        bytesPerRow: Int,
        bytesPerPixel: Int
    ) -> Double {
        let offset = y * bytesPerRow + x * bytesPerPixel
        let red = Double(pixels[offset]) / 255
        let green = Double(pixels[offset + 1]) / 255
        let blue = Double(pixels[offset + 2]) / 255
        return red * 0.299 + green * 0.587 + blue * 0.114
    }

    private static func samplePixel(
        x: Double,
        y: Double,
        width: Int,
        height: Int,
        pixels: [UInt8],
        bytesPerRow: Int,
        bytesPerPixel: Int
    ) -> (Double, Double, Double, Double) {
        let clampedX = max(0, min(Double(width - 1), x))
        let clampedY = max(0, min(Double(height - 1), y))
        let x0 = Int(floor(clampedX))
        let y0 = Int(floor(clampedY))
        let x1 = min(width - 1, x0 + 1)
        let y1 = min(height - 1, y0 + 1)
        let tx = clampedX - Double(x0)
        let ty = clampedY - Double(y0)
        let topLeft = pixelComponents(x: x0, y: y0, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
        let topRight = pixelComponents(x: x1, y: y0, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
        let bottomLeft = pixelComponents(x: x0, y: y1, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
        let bottomRight = pixelComponents(x: x1, y: y1, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
        let top = mix(topLeft, topRight, tx)
        let bottom = mix(bottomLeft, bottomRight, tx)
        return mix(top, bottom, ty)
    }

    private static func pixelComponents(
        x: Int,
        y: Int,
        pixels: [UInt8],
        bytesPerRow: Int,
        bytesPerPixel: Int
    ) -> (Double, Double, Double, Double) {
        let offset = y * bytesPerRow + x * bytesPerPixel
        return (
            Double(pixels[offset]) / 255,
            Double(pixels[offset + 1]) / 255,
            Double(pixels[offset + 2]) / 255,
            Double(pixels[offset + 3]) / 255
        )
    }

    private static func mix(
        _ left: (Double, Double, Double, Double),
        _ right: (Double, Double, Double, Double),
        _ amount: Double
    ) -> (Double, Double, Double, Double) {
        let inverse = 1 - amount
        return (
            left.0 * inverse + right.0 * amount,
            left.1 * inverse + right.1 * amount,
            left.2 * inverse + right.2 * amount,
            left.3 * inverse + right.3 * amount
        )
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8((max(0, min(1, value)) * 255).rounded())
    }
}
