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
        guard clamped > 0 else { return self }
        if kind == .addNoise {
            return addingDeterministicNoise(intensity: clamped, settings: settings)
        }
        if kind == .median {
            return medianDenoised(intensity: clamped)
        }
        if kind == .unsharpMask {
            return unsharpMasked(intensity: clamped, settings: settings)
        }
        if kind == .highPass {
            return highPassed(intensity: clamped, settings: settings)
        }
        if kind == .emboss {
            return embossed(intensity: clamped, settings: settings)
        }
        if kind == .findEdges {
            return findingEdges(intensity: clamped)
        }
        if kind == .minimum {
            return morphologyFiltered(intensity: clamped, settings: settings, useMaximum: false)
        }
        if kind == .maximum {
            return morphologyFiltered(intensity: clamped, settings: settings, useMaximum: true)
        }
        if kind == .oilPaint {
            return oilPainted(intensity: clamped, settings: settings)
        }
        if kind == .vignette {
            return vignetted(intensity: clamped, settings: settings)
        }
        if kind == .offset {
            return offset(intensity: clamped, settings: settings)
        }
        if kind == .wave {
            return waved(intensity: clamped, settings: settings)
        }
        if kind == .ripple {
            return rippled(intensity: clamped, settings: settings)
        }
        if kind == .pinch {
            return pinched(intensity: clamped, settings: settings)
        }
        if kind == .spherize {
            return spherized(intensity: clamped, settings: settings)
        }
        if kind == .lensCorrection {
            return lensCorrected(intensity: clamped, settings: settings)
        }
        if kind == .liquifyPush {
            return liquifyPushed(intensity: clamped, settings: settings)
        }
        if kind == .liquifyTwirl {
            return liquifyTwirled(intensity: clamped, settings: settings)
        }
        if kind == .liquifyPuckerBloat {
            return liquifyBulged(intensity: clamped, settings: settings)
        }

        guard let ciImage = ciImageForEditing() else { return nil }
        let output: CIImage?

        switch kind {
        case .gaussianBlur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = ciImage.clampedToExtent()
            let radius = settings.normalized().gaussianBlurRadius ?? clamped * 18
            filter.radius = Float(max(0, min(256, radius)))
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
            filter.scale = Float(settings.normalized().pixelateCellSize ?? (2 + clamped * 32))
            output = filter.outputImage?.cropped(to: ciImage.extent)
        case .motionBlur:
            let filter = CIFilter.motionBlur()
            filter.inputImage = ciImage.clampedToExtent()
            let normalized = settings.normalized()
            filter.radius = Float(normalized.motionBlurDistance ?? (clamped * 28))
            filter.angle = Float((normalized.motionBlurAngleDegrees ?? 0) * .pi / 180)
            output = filter.outputImage?.cropped(to: ciImage.extent)
        case .addNoise:
            return addingDeterministicNoise(intensity: clamped, settings: settings)
        case .median:
            return medianDenoised(intensity: clamped)
        case .unsharpMask:
            return unsharpMasked(intensity: clamped, settings: settings)
        case .highPass:
            return highPassed(intensity: clamped, settings: settings)
        case .emboss:
            return embossed(intensity: clamped, settings: settings)
        case .findEdges:
            return findingEdges(intensity: clamped)
        case .minimum:
            return morphologyFiltered(intensity: clamped, settings: settings, useMaximum: false)
        case .maximum:
            return morphologyFiltered(intensity: clamped, settings: settings, useMaximum: true)
        case .oilPaint:
            return oilPainted(intensity: clamped, settings: settings)
        case .vignette:
            return vignetted(intensity: clamped, settings: settings)
        case .offset:
            return offset(intensity: clamped, settings: settings)
        case .wave:
            return waved(intensity: clamped, settings: settings)
        case .ripple:
            return rippled(intensity: clamped, settings: settings)
        case .pinch:
            return pinched(intensity: clamped, settings: settings)
        case .spherize:
            return spherized(intensity: clamped, settings: settings)
        case .lensCorrection:
            return lensCorrected(intensity: clamped, settings: settings)
        case .liquifyPush:
            return liquifyPushed(intensity: clamped, settings: settings)
        case .liquifyTwirl:
            return liquifyTwirled(intensity: clamped, settings: settings)
        case .liquifyPuckerBloat:
            return liquifyBulged(intensity: clamped, settings: settings)
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
        mask: NSImage?,
        opacity: Double = 1,
        blendMode: ImageEditorBlendMode = .normal
    ) -> NSImage? {
        guard intensity > 0 else { return self }
        let normalizedOpacity = max(0, min(1, opacity))
        guard normalizedOpacity > 0 else { return self }
        guard let filtered = filtered(kind: kind, intensity: intensity, settings: settings) else { return nil }
        let normalizedBlendMode = blendMode == .passThrough ? ImageEditorBlendMode.normal : blendMode
        guard mask != nil || normalizedOpacity < 1 || normalizedBlendMode != .normal else { return filtered }
        return blendingEditedImage(
            filtered,
            with: mask,
            opacity: normalizedOpacity,
            blendMode: normalizedBlendMode
        ) ?? self
    }

    func blendingEditedImage(
        _ edited: NSImage,
        with mask: NSImage?,
        opacity: Double,
        blendMode: ImageEditorBlendMode = .normal
    ) -> NSImage? {
        guard let source = filterRGBAPlane(),
              let edited = edited.filterRGBAPlane(),
              source.width == edited.width,
              source.height == edited.height
        else { return nil }

        let maskAlpha: [UInt8]
        if let mask {
            guard let alpha = mask.filterAlphaPlane(width: source.width, height: source.height) else { return nil }
            maskAlpha = alpha
        } else {
            maskAlpha = [UInt8](repeating: .max, count: source.width * source.height)
        }

        var output = source.values
        for pixelIndex in maskAlpha.indices {
            var weight = Double(maskAlpha[pixelIndex]) / 255 * opacity
            guard weight > 0 else { continue }
            let byteOffset = pixelIndex * 4
            if blendMode == .dissolve {
                let x = pixelIndex % source.width
                let y = pixelIndex / source.width
                weight = Self.filterDissolveSample(x: x, y: y) < weight ? 1 : 0
                guard weight > 0 else { continue }
            }
            if blendMode != .normal && blendMode != .dissolve {
                let sourceAlpha = Double(source.values[byteOffset + 3]) / 255
                let editedAlpha = Double(edited.values[byteOffset + 3]) / 255
                let baseRed = Self.filterUnpremultiplied(source.values[byteOffset], alpha: sourceAlpha)
                let baseGreen = Self.filterUnpremultiplied(source.values[byteOffset + 1], alpha: sourceAlpha)
                let baseBlue = Self.filterUnpremultiplied(source.values[byteOffset + 2], alpha: sourceAlpha)
                let editedRed = Self.filterUnpremultiplied(edited.values[byteOffset], alpha: editedAlpha)
                let editedGreen = Self.filterUnpremultiplied(edited.values[byteOffset + 1], alpha: editedAlpha)
                let editedBlue = Self.filterUnpremultiplied(edited.values[byteOffset + 2], alpha: editedAlpha)
                let blended = blendMode.blend(
                    baseRed: baseRed,
                    baseGreen: baseGreen,
                    baseBlue: baseBlue,
                    overlayRed: editedRed,
                    overlayGreen: editedGreen,
                    overlayBlue: editedBlue
                )
                // Result blend modes change the filtered color, not the
                // source layer's coverage. Some Core Image filters return an
                // opaque working image even when their input is translucent;
                // using that working alpha here would silently fill the
                // transparent portion of the layer.
                let target = [
                    blended.red * sourceAlpha * 255,
                    blended.green * sourceAlpha * 255,
                    blended.blue * sourceAlpha * 255,
                    sourceAlpha * 255
                ]
                for component in 0..<4 {
                    let sourceValue = Double(source.values[byteOffset + component])
                    output[byteOffset + component] = UInt8(
                        max(0, min(255, (sourceValue + (target[component] - sourceValue) * weight).rounded()))
                    )
                }
                continue
            }
            for component in 0..<4 {
                let sourceValue = Double(source.values[byteOffset + component])
                let editedValue = Double(edited.values[byteOffset + component])
                output[byteOffset + component] = UInt8(
                    max(0, min(255, (sourceValue + (editedValue - sourceValue) * weight).rounded()))
                )
            }
        }
        return Self.filterRGBAImage(
            width: source.width,
            height: source.height,
            values: output,
            displaySize: size
        )
    }

    private static func filterUnpremultiplied(_ value: UInt8, alpha: Double) -> Double {
        guard alpha > 0 else { return 0 }
        return max(0, min(1, Double(value) / 255 / alpha))
    }

    private static func filterDissolveSample(x: Int, y: Int) -> Double {
        let xMultiplier: UInt64 = 0x9E37_79B9_7F4A_7C15
        let yMultiplier: UInt64 = 0xBF58_476D_1CE4_E5B9
        var value = UInt64(truncatingIfNeeded: x) &* xMultiplier
        value &+= UInt64(truncatingIfNeeded: y) &* yMultiplier
        value &+= 0x94D0_49BB_1331_11EB
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value & 0xFFFF) / 65_535
    }

    private func filterAlphaPlane(width: Int, height: Int) -> [UInt8]? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
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
        for pixelIndex in alpha.indices {
            alpha[pixelIndex] = pixels[pixelIndex * bytesPerPixel + 3]
        }
        return alpha
    }

    private func filterRGBAPlane() -> (width: Int, height: Int, values: [UInt8])? {
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
        return (width, height, pixels)
    }

    private static func filterRGBAImage(
        width: Int,
        height: Int,
        values: [UInt8],
        displaySize: CGSize
    ) -> NSImage? {
        guard values.count == width * height * 4,
              let provider = CGDataProvider(data: Data(values) as CFData),
              let image = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              )
        else { return nil }
        return NSImage(cgImage: image, size: displaySize)
    }

    private func addingDeterministicNoise(
        intensity: Double,
        settings: ImageEditorFilterSettings
    ) -> NSImage? {
        let amount = max(0, min(1, intensity)) * 0.45
        let normalized = settings.normalized()
        let monochromatic = normalized.addNoiseMonochromatic ?? true
        let distribution = normalized.addNoiseDistribution ?? .uniform
        return pixelMappedByCoordinate { x, y, red, green, blue, alpha in
            let redNoise = Self.coordinateNoise(
                x: x,
                y: y,
                channel: 0,
                distribution: distribution
            ) * amount * alpha
            let greenNoise = monochromatic
                ? redNoise
                : Self.coordinateNoise(
                    x: x,
                    y: y,
                    channel: 1,
                    distribution: distribution
                ) * amount * alpha
            let blueNoise = monochromatic
                ? redNoise
                : Self.coordinateNoise(
                    x: x,
                    y: y,
                    channel: 2,
                    distribution: distribution
                ) * amount * alpha
            return (
                Self.premultipliedChannel(red + redNoise, alpha: alpha),
                Self.premultipliedChannel(green + greenNoise, alpha: alpha),
                Self.premultipliedChannel(blue + blueNoise, alpha: alpha),
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

    private func highPassed(
        intensity: Double,
        settings: ImageEditorFilterSettings
    ) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        let radius = max(
            1,
            Int(
                (settings.normalized().highPassRadius ?? (1 + clampedIntensity * 9))
                    .rounded()
            )
        )
        let contrast = 1.4 + clampedIntensity * 2.4
        guard let source = filterRGBAPlane() else { return nil }
        let width = source.width
        let height = source.height
        let integralWidth = width + 1
        let integralCount = integralWidth * (height + 1)
        var redIntegral = [Int64](repeating: 0, count: integralCount)
        var greenIntegral = [Int64](repeating: 0, count: integralCount)
        var blueIntegral = [Int64](repeating: 0, count: integralCount)

        for y in 0..<height {
            var rowRed: Int64 = 0
            var rowGreen: Int64 = 0
            var rowBlue: Int64 = 0
            for x in 0..<width {
                let sourceOffset = (y * width + x) * 4
                rowRed += Int64(source.values[sourceOffset])
                rowGreen += Int64(source.values[sourceOffset + 1])
                rowBlue += Int64(source.values[sourceOffset + 2])
                let integralOffset = (y + 1) * integralWidth + x + 1
                let previousRowOffset = y * integralWidth + x + 1
                redIntegral[integralOffset] = redIntegral[previousRowOffset] + rowRed
                greenIntegral[integralOffset] = greenIntegral[previousRowOffset] + rowGreen
                blueIntegral[integralOffset] = blueIntegral[previousRowOffset] + rowBlue
            }
        }

        func average(
            _ integral: [Int64],
            minX: Int,
            minY: Int,
            maxX: Int,
            maxY: Int
        ) -> Double {
            let bottomRight = integral[(maxY + 1) * integralWidth + maxX + 1]
            let topRight = integral[minY * integralWidth + maxX + 1]
            let bottomLeft = integral[(maxY + 1) * integralWidth + minX]
            let topLeft = integral[minY * integralWidth + minX]
            let count = Double((maxX - minX + 1) * (maxY - minY + 1))
            return Double(bottomRight - topRight - bottomLeft + topLeft) / count / 255
        }

        var output = source.values
        for y in 0..<height {
            let minY = max(0, y - radius)
            let maxY = min(height - 1, y + radius)
            for x in 0..<width {
                let minX = max(0, x - radius)
                let maxX = min(width - 1, x + radius)
                let offset = (y * width + x) * 4
                let alpha = Double(source.values[offset + 3]) / 255
                let neutral = 0.5 * alpha
                let red = Double(source.values[offset]) / 255
                let green = Double(source.values[offset + 1]) / 255
                let blue = Double(source.values[offset + 2]) / 255
                output[offset] = Self.byte(Self.premultipliedChannel(
                    neutral + (red - average(redIntegral, minX: minX, minY: minY, maxX: maxX, maxY: maxY)) * contrast,
                    alpha: alpha
                ))
                output[offset + 1] = Self.byte(Self.premultipliedChannel(
                    neutral + (green - average(greenIntegral, minX: minX, minY: minY, maxX: maxX, maxY: maxY)) * contrast,
                    alpha: alpha
                ))
                output[offset + 2] = Self.byte(Self.premultipliedChannel(
                    neutral + (blue - average(blueIntegral, minX: minX, minY: minY, maxX: maxX, maxY: maxY)) * contrast,
                    alpha: alpha
                ))
            }
        }
        return Self.filterRGBAImage(
            width: width,
            height: height,
            values: output,
            displaySize: size
        )
    }

    private func embossed(intensity: Double, settings: ImageEditorFilterSettings) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        let strength = 1.2 + clampedIntensity * 2.6
        let normalizedSettings = settings.normalized()
        guard normalizedSettings.embossAngleDegrees != nil || normalizedSettings.embossHeight != nil else {
            return legacyEmbossed(strength: strength)
        }
        let angle = (normalizedSettings.embossAngleDegrees ?? 135) * .pi / 180
        let height = normalizedSettings.embossHeight ?? 3
        let sampleX = cos(angle) * height
        let sampleY = -sin(angle) * height
        return pixelMappedFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let offset = y * bytesPerRow + x * bytesPerPixel
            let alpha = Double(pixels[offset + 3]) / 255
            let shadow = Self.sampledLuminance(
                x: Double(x) - sampleX,
                y: Double(y) - sampleY,
                width: width,
                height: height,
                pixels: pixels,
                bytesPerRow: bytesPerRow,
                bytesPerPixel: bytesPerPixel
            )
            let highlight = Self.sampledLuminance(
                x: Double(x) + sampleX,
                y: Double(y) + sampleY,
                width: width,
                height: height,
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

    private func legacyEmbossed(strength: Double) -> NSImage? {
        pixelMappedFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
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

    private func morphologyFiltered(
        intensity: Double,
        settings: ImageEditorFilterSettings,
        useMaximum: Bool
    ) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        let radius = max(
            1,
            Int(
                (settings.normalized().morphologyRadius ?? (1 + clampedIntensity * 4))
                    .rounded()
            )
        )
        guard let source = filterRGBAPlane() else { return nil }
        let width = source.width
        let height = source.height
        var horizontal = source.values
        var output = source.values

        for y in 0..<height {
            for component in 0..<3 {
                Self.writeSlidingExtrema(
                    source: source.values,
                    sourceStart: y * width * 4 + component,
                    sourceStride: 4,
                    count: width,
                    radius: radius,
                    useMaximum: useMaximum,
                    destination: &horizontal,
                    destinationStart: y * width * 4 + component,
                    destinationStride: 4
                )
            }
        }
        for x in 0..<width {
            for component in 0..<3 {
                Self.writeSlidingExtrema(
                    source: horizontal,
                    sourceStart: x * 4 + component,
                    sourceStride: width * 4,
                    count: height,
                    radius: radius,
                    useMaximum: useMaximum,
                    destination: &output,
                    destinationStart: x * 4 + component,
                    destinationStride: width * 4
                )
            }
        }
        for pixelIndex in 0..<(width * height) {
            let offset = pixelIndex * 4
            let alpha = source.values[offset + 3]
            output[offset] = min(output[offset], alpha)
            output[offset + 1] = min(output[offset + 1], alpha)
            output[offset + 2] = min(output[offset + 2], alpha)
        }
        return Self.filterRGBAImage(
            width: width,
            height: height,
            values: output,
            displaySize: size
        )
    }

    private static func writeSlidingExtrema(
        source: [UInt8],
        sourceStart: Int,
        sourceStride: Int,
        count: Int,
        radius: Int,
        useMaximum: Bool,
        destination: inout [UInt8],
        destinationStart: Int,
        destinationStride: Int
    ) {
        guard count > 0 else { return }
        var deque = [Int](repeating: 0, count: count)
        var head = 0
        var tail = 0
        var nextIndex = 0

        func value(at index: Int) -> UInt8 {
            source[sourceStart + index * sourceStride]
        }
        func isPreferred(_ candidate: UInt8, over current: UInt8) -> Bool {
            useMaximum ? candidate >= current : candidate <= current
        }

        for index in 0..<count {
            let right = min(count - 1, index + radius)
            while nextIndex <= right {
                let candidate = value(at: nextIndex)
                while tail > head, isPreferred(candidate, over: value(at: deque[tail - 1])) {
                    tail -= 1
                }
                deque[tail] = nextIndex
                tail += 1
                nextIndex += 1
            }

            let left = max(0, index - radius)
            while tail > head, deque[head] < left {
                head += 1
            }
            destination[destinationStart + index * destinationStride] = value(at: deque[head])
        }
    }

    private func oilPainted(
        intensity: Double,
        settings: ImageEditorFilterSettings
    ) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        let normalizedSettings = settings.normalized()
        let radius = max(
            1,
            Int((normalizedSettings.oilPaintRadius ?? (1 + clampedIntensity * 5)).rounded())
        )
        let bucketCount = max(
            6,
            Int((normalizedSettings.oilPaintTonalLevels ?? (18 - clampedIntensity * 10)).rounded())
        )
        let stylization = (normalizedSettings.oilPaintStylization ?? 10) / 10
        let cleanliness = (normalizedSettings.oilPaintCleanliness ?? 0) / 10
        let bristleDetail = (normalizedSettings.oilPaintBristleDetail ?? 0) / 10
        let shine = (normalizedSettings.oilPaintShine ?? 0) / 10
        let lightingAngleDegrees = normalizedSettings.oilPaintLightingAngleDegrees ?? 135
        let lightingOffset: (x: Double, y: Double)
        if abs(lightingAngleDegrees - 135) < 0.000_001 {
            lightingOffset = (1, -1)
        } else {
            let radians = lightingAngleDegrees * .pi / 180
            lightingOffset = (
                -cos(radians) * sqrt(2),
                -sin(radians) * sqrt(2)
            )
        }
        if stylization <= 0 {
            return self
        }
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
            guard let dominantIndex = buckets.indices.max(by: { buckets[$0].count < buckets[$1].count }) else {
                return (
                    Double(pixels[offset]) / 255,
                    Double(pixels[offset + 1]) / 255,
                    Double(pixels[offset + 2]) / 255,
                    alpha
                )
            }
            let dominant = buckets[dominantIndex]
            guard dominant.count > 0 else {
                return (
                    Double(pixels[offset]) / 255,
                    Double(pixels[offset + 1]) / 255,
                    Double(pixels[offset + 2]) / 255,
                    alpha
                )
            }
            let count = Double(dominant.count)
            let dominantRed = dominant.red / count
            let dominantGreen = dominant.green / count
            let dominantBlue = dominant.blue / count
            let cleanedColor: (red: Double, green: Double, blue: Double)
            if cleanliness <= 0 {
                cleanedColor = (dominantRed, dominantGreen, dominantBlue)
            } else {
                let cleanRange = max(0, dominantIndex - 1)...min(bucketCount - 1, dominantIndex + 1)
                let clean = cleanRange.reduce(
                    into: (count: 0, red: 0.0, green: 0.0, blue: 0.0)
                ) { result, index in
                    result.count += buckets[index].count
                    result.red += buckets[index].red
                    result.green += buckets[index].green
                    result.blue += buckets[index].blue
                }
                let cleanCount = Double(clean.count)
                let cleanRed = cleanCount > 0 ? clean.red / cleanCount : dominantRed
                let cleanGreen = cleanCount > 0 ? clean.green / cleanCount : dominantGreen
                let cleanBlue = cleanCount > 0 ? clean.blue / cleanCount : dominantBlue
                cleanedColor = (
                    dominantRed + (cleanRed - dominantRed) * cleanliness,
                    dominantGreen + (cleanGreen - dominantGreen) * cleanliness,
                    dominantBlue + (cleanBlue - dominantBlue) * cleanliness
                )
            }
            let sourceRed = Double(pixels[offset]) / 255
            let sourceGreen = Double(pixels[offset + 1]) / 255
            let sourceBlue = Double(pixels[offset + 2]) / 255
            var detailedColor = cleanedColor
            if bristleDetail > 0 {
                var detailCount = 0.0
                var detailRed = 0.0
                var detailGreen = 0.0
                var detailBlue = 0.0
                for detailY in max(0, y - 1)...min(height - 1, y + 1) {
                    for detailX in max(0, x - 1)...min(width - 1, x + 1) {
                        let detailOffset = detailY * bytesPerRow + detailX * bytesPerPixel
                        detailCount += 1
                        detailRed += Double(pixels[detailOffset]) / 255
                        detailGreen += Double(pixels[detailOffset + 1]) / 255
                        detailBlue += Double(pixels[detailOffset + 2]) / 255
                    }
                }
                detailedColor = (
                    cleanedColor.red + (sourceRed - detailRed / detailCount) * bristleDetail,
                    cleanedColor.green + (sourceGreen - detailGreen / detailCount) * bristleDetail,
                    cleanedColor.blue + (sourceBlue - detailBlue / detailCount) * bristleDetail
                )
            }
            var litColor = detailedColor
            if shine > 0 {
                let light = Self.samplePixel(
                    x: Double(x) + lightingOffset.x,
                    y: Double(y) + lightingOffset.y,
                    width: width,
                    height: height,
                    pixels: pixels,
                    bytesPerRow: bytesPerRow,
                    bytesPerPixel: bytesPerPixel
                )
                let shadow = Self.samplePixel(
                    x: Double(x) - lightingOffset.x,
                    y: Double(y) - lightingOffset.y,
                    width: width,
                    height: height,
                    pixels: pixels,
                    bytesPerRow: bytesPerRow,
                    bytesPerPixel: bytesPerPixel
                )
                let lightLuminance = light.0 * 0.299 + light.1 * 0.587 + light.2 * 0.114
                let shadowLuminance = shadow.0 * 0.299 + shadow.1 * 0.587 + shadow.2 * 0.114
                let relief = (lightLuminance - shadowLuminance) * shine * 0.5
                litColor = (
                    detailedColor.red + relief,
                    detailedColor.green + relief,
                    detailedColor.blue + relief
                )
            }
            let paintedRed = Self.premultipliedChannel(
                litColor.red,
                alpha: alpha
            )
            let paintedGreen = Self.premultipliedChannel(
                litColor.green,
                alpha: alpha
            )
            let paintedBlue = Self.premultipliedChannel(
                litColor.blue,
                alpha: alpha
            )
            if stylization >= 1 {
                return (paintedRed, paintedGreen, paintedBlue, alpha)
            }
            return (
                sourceRed + (paintedRed - sourceRed) * stylization,
                sourceGreen + (paintedGreen - sourceGreen) * stylization,
                sourceBlue + (paintedBlue - sourceBlue) * stylization,
                alpha
            )
        }
    }

    private func vignetted(
        intensity: Double,
        settings: ImageEditorFilterSettings
    ) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        guard clampedIntensity > 0 else { return self }
        let strength = 0.85 * clampedIntensity
        let featherStart = settings.normalized().vignetteMidpoint ?? 0.28
        return pixelMappedFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let offset = y * bytesPerRow + x * bytesPerPixel
            let alpha = Double(pixels[offset + 3]) / 255
            let centerX = Double(max(width - 1, 1)) / 2
            let centerY = Double(max(height - 1, 1)) / 2
            let normalizedX = (Double(x) - centerX) / max(centerX, 1)
            let normalizedY = (Double(y) - centerY) / max(centerY, 1)
            let radialDistance = min(1, hypot(normalizedX, normalizedY) / sqrt(2))
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

    private func offset(intensity: Double, settings: ImageEditorFilterSettings) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        guard clampedIntensity > 0 else { return self }
        let normalizedSettings = settings.normalized()
        return pixelSampledFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let shiftX = normalizedSettings.offsetX * Double(width) * 0.5 * clampedIntensity
            let shiftY = normalizedSettings.offsetY * Double(height) * 0.5 * clampedIntensity
            let sourceX = Double(x) - shiftX
            let sourceY = Double(y) - shiftY
            switch normalizedSettings.offsetUndefinedAreaMode {
            case .wrapAround:
                return Self.wrappedSamplePixel(
                    x: sourceX,
                    y: sourceY,
                    width: width,
                    height: height,
                    pixels: pixels,
                    bytesPerRow: bytesPerRow,
                    bytesPerPixel: bytesPerPixel
                )
            case .repeatEdgePixels:
                return Self.samplePixel(
                    x: sourceX,
                    y: sourceY,
                    width: width,
                    height: height,
                    pixels: pixels,
                    bytesPerRow: bytesPerRow,
                    bytesPerPixel: bytesPerPixel
                )
            case .transparent:
                return Self.transparentSamplePixel(
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
    }

    private func waved(intensity: Double, settings: ImageEditorFilterSettings) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        guard clampedIntensity > 0 else { return self }
        let normalizedSettings = settings.normalized()
        return pixelSampledFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let cycles = 1 + normalizedSettings.waveFrequency * 5
            let maxShift = min(Double(width), Double(height)) * 0.18 * clampedIntensity
            let phase = Double(y) / Double(max(height - 1, 1)) * cycles * Double.pi * 2
            let sourceX = Double(x) - sin(phase) * normalizedSettings.waveAmplitude * maxShift
            return Self.samplePixel(
                x: sourceX,
                y: Double(y),
                width: width,
                height: height,
                pixels: pixels,
                bytesPerRow: bytesPerRow,
                bytesPerPixel: bytesPerPixel
            )
        }
    }

    private func rippled(intensity: Double, settings: ImageEditorFilterSettings) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        guard clampedIntensity > 0 else { return self }
        let normalizedSettings = settings.normalized()
        return pixelSampledFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let centerX = Double(max(width - 1, 1)) / 2
            let centerY = Double(max(height - 1, 1)) / 2
            let dx = Double(x) - centerX
            let dy = Double(y) - centerY
            let distance = hypot(dx, dy)
            guard distance > 0.001 else {
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

            let radius = max(1, min(Double(width), Double(height)) * 0.5)
            let cycles = 2 + normalizedSettings.rippleFrequency * 6
            let amplitude = min(Double(width), Double(height)) * 0.12 * normalizedSettings.rippleAmount * clampedIntensity
            let displacement = sin(distance / radius * cycles * Double.pi * 2) * amplitude
            let sourceDistance = max(0, distance + displacement)
            let sourceX = centerX + dx / distance * sourceDistance
            let sourceY = centerY + dy / distance * sourceDistance
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

    private func pinched(intensity: Double, settings: ImageEditorFilterSettings) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        guard clampedIntensity > 0 else { return self }
        let normalizedSettings = settings.normalized()
        return pixelSampledFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let centerX = Double(max(width - 1, 1)) / 2
            let centerY = Double(max(height - 1, 1)) / 2
            let dx = Double(x) - centerX
            let dy = Double(y) - centerY
            let distance = hypot(dx, dy)
            guard distance > 0.001 else {
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

            let radius = max(1, min(Double(width), Double(height)) * 0.5)
            let normalizedDistance = min(1, distance / radius)
            let falloff = pow(1 - normalizedDistance, 2)
            let scale = max(0.05, 1 + normalizedSettings.pinchAmount * clampedIntensity * falloff * 0.9)
            let sourceDistance = min(radius, distance * scale)
            let sourceX = centerX + dx / distance * sourceDistance
            let sourceY = centerY + dy / distance * sourceDistance
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

    private func spherized(intensity: Double, settings: ImageEditorFilterSettings) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        guard clampedIntensity > 0 else { return self }
        let normalizedSettings = settings.normalized()
        return pixelSampledFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let centerX = Double(max(width - 1, 1)) / 2
            let centerY = Double(max(height - 1, 1)) / 2
            let dx = Double(x) - centerX
            let dy = Double(y) - centerY
            let distance = hypot(dx, dy)
            guard distance > 0.001 else {
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

            let radius = max(1, min(Double(width), Double(height)) * 0.5)
            let normalizedDistance = min(1, distance / radius)
            guard normalizedDistance < 1 else {
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

            let amount = normalizedSettings.spherizeAmount * clampedIntensity
            let sphereDistance = 1 - sqrt(max(0, 1 - normalizedDistance))
            let inverseDistance = sqrt(max(0, 2 * normalizedDistance - normalizedDistance * normalizedDistance))
            let targetDistance = amount >= 0 ? sphereDistance : inverseDistance
            let sourceDistance = radius * (normalizedDistance + abs(amount) * (targetDistance - normalizedDistance))
            let sourceX = centerX + dx / distance * sourceDistance
            let sourceY = centerY + dy / distance * sourceDistance
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

    private func lensCorrected(intensity: Double, settings: ImageEditorFilterSettings) -> NSImage? {
        let clampedIntensity = max(0, min(1, intensity))
        guard clampedIntensity > 0 else { return self }
        let distortion = settings.normalized().lensDistortion * clampedIntensity
        guard abs(distortion) > 0.000_1 else { return self }

        return pixelSampledFromBuffer { x, y, width, height, pixels, bytesPerRow, bytesPerPixel in
            let centerX = Double(max(width - 1, 1)) / 2
            let centerY = Double(max(height - 1, 1)) / 2
            let halfWidth = max(centerX, 1)
            let halfHeight = max(centerY, 1)
            let normalizedX = (Double(x) - centerX) / halfWidth
            let normalizedY = (Double(y) - centerY) / halfHeight
            let radiusSquared = normalizedX * normalizedX + normalizedY * normalizedY
            let radialScale = max(0.25, 1 + distortion * radiusSquared * 0.55)
            let sourceX = centerX + normalizedX * halfWidth * radialScale
            let sourceY = centerY + normalizedY * halfHeight * radialScale

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

    private func liquifyTwirled(intensity: Double, settings: ImageEditorFilterSettings) -> NSImage? {
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
            guard distance < radius, distance > 0.001 else {
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
            let twist = normalizedSettings.liquifyTwirlAngle * Double.pi * 1.5 * clampedIntensity * falloff
            let sourceAngle = atan2(dy, dx) - twist
            let sourceX = centerX + cos(sourceAngle) * distance
            let sourceY = centerY + sin(sourceAngle) * distance
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

    private func liquifyBulged(intensity: Double, settings: ImageEditorFilterSettings) -> NSImage? {
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
            guard distance < radius, distance > 0.001 else {
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
            let amount = normalizedSettings.liquifyBulgeAmount * clampedIntensity
            let scale = max(0.18, 1 - amount * falloff * 0.78)
            let sourceX = centerX + dx * scale
            let sourceY = centerY + dy * scale
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

    private static func coordinateNoise(x: Int, y: Int, channel: Int) -> Double {
        let xMultiplier: UInt64 = 0x9E3779B185EBCA87
        let yMultiplier: UInt64 = 0xC2B2AE3D27D4EB4F
        let channelMultiplier: UInt64 = 0x165667B19E3779F9
        let avalancheMultiplier: UInt64 = 0xFF51AFD7ED558CCD
        var value = UInt64(x + 1) &* xMultiplier
        value ^= UInt64(y + 1) &* yMultiplier
        value ^= UInt64(channel) &* channelMultiplier
        value ^= value >> 33
        value = value &* avalancheMultiplier
        value ^= value >> 33
        let unit = Double(value & 0xFFFF) / 65_535
        return unit * 2 - 1
    }

    private static func coordinateNoise(
        x: Int,
        y: Int,
        channel: Int,
        distribution: ImageEditorAddNoiseDistribution
    ) -> Double {
        guard distribution == .gaussian else {
            return coordinateNoise(x: x, y: y, channel: channel)
        }
        let firstChannel = channel * 2 + 17
        let secondChannel = firstChannel + 1
        let firstUnit = max(
            1.0 / 65_536,
            (coordinateNoise(x: x, y: y, channel: firstChannel) + 1) / 2
        )
        let secondUnit = (coordinateNoise(x: x, y: y, channel: secondChannel) + 1) / 2
        let standardNormal = sqrt(-2 * log(firstUnit)) * cos(2 * Double.pi * secondUnit)
        return max(-1, min(1, standardNormal / 3))
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

    private static func sampledLuminance(
        x: Double,
        y: Double,
        width: Int,
        height: Int,
        pixels: [UInt8],
        bytesPerRow: Int,
        bytesPerPixel: Int
    ) -> Double {
        let sample = samplePixel(
            x: x,
            y: y,
            width: width,
            height: height,
            pixels: pixels,
            bytesPerRow: bytesPerRow,
            bytesPerPixel: bytesPerPixel
        )
        return sample.0 * 0.299 + sample.1 * 0.587 + sample.2 * 0.114
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

    private static func wrappedSamplePixel(
        x: Double,
        y: Double,
        width: Int,
        height: Int,
        pixels: [UInt8],
        bytesPerRow: Int,
        bytesPerPixel: Int
    ) -> (Double, Double, Double, Double) {
        let wrappedX = wrappedCoordinate(x, limit: width)
        let wrappedY = wrappedCoordinate(y, limit: height)
        let x0 = Int(floor(wrappedX))
        let y0 = Int(floor(wrappedY))
        let x1 = (x0 + 1) % width
        let y1 = (y0 + 1) % height
        let tx = wrappedX - Double(x0)
        let ty = wrappedY - Double(y0)
        let topLeft = pixelComponents(x: x0, y: y0, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
        let topRight = pixelComponents(x: x1, y: y0, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
        let bottomLeft = pixelComponents(x: x0, y: y1, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
        let bottomRight = pixelComponents(x: x1, y: y1, pixels: pixels, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel)
        let top = mix(topLeft, topRight, tx)
        let bottom = mix(bottomLeft, bottomRight, tx)
        return mix(top, bottom, ty)
    }

    private static func transparentSamplePixel(
        x: Double,
        y: Double,
        width: Int,
        height: Int,
        pixels: [UInt8],
        bytesPerRow: Int,
        bytesPerPixel: Int
    ) -> (Double, Double, Double, Double) {
        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let x1 = x0 + 1
        let y1 = y0 + 1
        let tx = x - Double(x0)
        let ty = y - Double(y0)
        let clear = (0.0, 0.0, 0.0, 0.0)
        func sample(_ sampleX: Int, _ sampleY: Int) -> (Double, Double, Double, Double) {
            guard (0..<width).contains(sampleX), (0..<height).contains(sampleY) else {
                return clear
            }
            return pixelComponents(
                x: sampleX,
                y: sampleY,
                pixels: pixels,
                bytesPerRow: bytesPerRow,
                bytesPerPixel: bytesPerPixel
            )
        }
        let top = mix(sample(x0, y0), sample(x1, y0), tx)
        let bottom = mix(sample(x0, y1), sample(x1, y1), tx)
        return mix(top, bottom, ty)
    }

    private static func wrappedCoordinate(_ value: Double, limit: Int) -> Double {
        let length = Double(max(limit, 1))
        let remainder = value.truncatingRemainder(dividingBy: length)
        return remainder >= 0 ? remainder : remainder + length
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
