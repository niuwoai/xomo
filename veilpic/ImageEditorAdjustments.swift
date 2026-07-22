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
        case .posterize:
            return posterized(levels: amount)
        case .levels:
            return leveled(settings: settings)
        case .curves:
            return curved(settings: settings)
        case .colorBalance:
            return colorBalanced(settings: settings)
        case .hueSaturation:
            return hueSaturated(settings: settings)
        case .brightnessContrast:
            return brightnessContrasted(settings: settings)
        case .exposure:
            return exposureAdjusted(amount: clamped, settings: settings)
        case .shadowsHighlights:
            return shadowsHighlighted(settings: settings)
        case .vibrance:
            return vibranced(amount: clamped, settings: settings)
        case .blackWhite:
            return blackWhite(settings: settings)
        case .channelMixer:
            return channelMixed(settings: settings)
        case .photoFilter:
            return photoFiltered(settings: settings)
        case .colorLookup:
            return colorLookuped(settings: settings)
        case .selectiveColor:
            return selectiveColored(settings: settings)
        case .gradientMap:
            return gradientMapped(settings: settings)
        case .brightness, .contrast, .saturation, .hue, .invert, .blur, .sharpen:
            return coreImageAdjusted(kind: kind, amount: clamped)
        }
    }

    func applyingAdjustment(
        kind: ImageEditorAdjustment,
        amount: Double,
        settings: ImageEditorAdjustmentSettings = ImageEditorAdjustmentSettings(),
        mask: NSImage?,
        opacity: Double = 1
    ) -> NSImage? {
        let normalizedOpacity = max(0, min(1, opacity))
        guard normalizedOpacity > 0 else { return self }
        guard let adjusted = adjusted(kind: kind, amount: amount, settings: settings) else { return nil }
        guard mask != nil || normalizedOpacity < 1 else { return adjusted }
        return blendingEditedImage(adjusted, with: mask, opacity: normalizedOpacity) ?? self
    }

    func autoLeveled() -> NSImage? {
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

        var minimum = [UInt8](repeating: UInt8.max, count: 3)
        var maximum = [UInt8](repeating: 0, count: 3)
        var hasVisiblePixels = false

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard pixels[offset + 3] > 0 else { continue }
                hasVisiblePixels = true
                for channel in 0..<3 {
                    minimum[channel] = min(minimum[channel], pixels[offset + channel])
                    maximum[channel] = max(maximum[channel], pixels[offset + channel])
                }
            }
        }

        guard hasVisiblePixels else { return self }

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard pixels[offset + 3] > 0 else { continue }
                for channel in 0..<3 {
                    let low = Int(minimum[channel])
                    let high = Int(maximum[channel])
                    guard high > low else { continue }
                    let value = max(0, min(255, Int(pixels[offset + channel]) - low))
                    pixels[offset + channel] = UInt8((Double(value) / Double(high - low) * 255).rounded())
                }
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

    func autoContrasted() -> NSImage? {
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

        var minimum = 1.0
        var maximum = 0.0
        var hasVisiblePixels = false

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard pixels[offset + 3] > 0 else { continue }
                hasVisiblePixels = true
                let luminance = Self.luminosity(
                    red: Double(pixels[offset]) / 255,
                    green: Double(pixels[offset + 1]) / 255,
                    blue: Double(pixels[offset + 2]) / 255
                )
                minimum = min(minimum, luminance)
                maximum = max(maximum, luminance)
            }
        }

        guard hasVisiblePixels, maximum > minimum else { return self }

        let range = maximum - minimum
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard pixels[offset + 3] > 0 else { continue }
                for channel in 0..<3 {
                    let value = Double(pixels[offset + channel]) / 255
                    pixels[offset + channel] = Self.byte((value - minimum) / range)
                }
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

    func autoColored() -> NSImage? {
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

        var totals = [Double](repeating: 0, count: 3)
        var visiblePixelCount = 0.0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard pixels[offset + 3] > 0 else { continue }
                visiblePixelCount += 1
                for channel in 0..<3 {
                    totals[channel] += Double(pixels[offset + channel]) / 255
                }
            }
        }

        guard visiblePixelCount > 0 else { return self }

        let averages = totals.map { $0 / visiblePixelCount }
        let targetAverage = max(0.001, (averages[0] + averages[1] + averages[2]) / 3)
        let scales = averages.map { average in
            guard average > 0.001 else { return 1.0 }
            return max(0.25, min(4, targetAverage / average))
        }

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard pixels[offset + 3] > 0 else { continue }
                for channel in 0..<3 {
                    pixels[offset + channel] = Self.byte(Double(pixels[offset + channel]) / 255 * scales[channel])
                }
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
        case .hue:
            let filter = CIFilter.hueAdjust()
            filter.inputImage = ciImage
            filter.angle = Float(amount * .pi)
            output = filter.outputImage
        case .invert:
            return pixelMapped { red, green, blue, alpha in
                (1 - red, 1 - green, 1 - blue, alpha)
            }
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
        case .threshold, .posterize, .levels, .curves, .colorBalance, .hueSaturation, .brightnessContrast, .exposure, .shadowsHighlights, .vibrance, .blackWhite, .channelMixer, .photoFilter, .colorLookup, .selectiveColor, .gradientMap:
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

    private func posterized(levels: Double) -> NSImage? {
        let levels = Self.posterizeLevelCount(from: levels)
        let denominator = Double(levels - 1)
        return pixelMapped { red, green, blue, alpha in
            (
                Self.posterizeChannel(red, denominator: denominator),
                Self.posterizeChannel(green, denominator: denominator),
                Self.posterizeChannel(blue, denominator: denominator),
                alpha
            )
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

    private func hueSaturated(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let settings = settings.normalized()
        return pixelMapped { red, green, blue, alpha in
            let hsl = Self.hsl(red: red, green: green, blue: blue)
            let hueShift = settings.hueSaturationHue / 360
            let hue = settings.hueSaturationColorize
                ? Self.wrapUnit(hueShift)
                : Self.wrapUnit(hsl.hue + hueShift)
            let saturation = settings.hueSaturationColorize
                ? max(0, min(1, 0.5 + settings.hueSaturationSaturation * 0.5))
                : Self.adjustedSaturation(hsl.saturation, amount: settings.hueSaturationSaturation)
            let lightness = Self.adjustedLightness(hsl.lightness, amount: settings.hueSaturationLightness)
            let output = Self.rgb(hue: hue, saturation: saturation, lightness: lightness)
            return (output.red, output.green, output.blue, alpha)
        }
    }

    private func brightnessContrasted(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let settings = settings.normalized()
        let brightness = settings.brightnessContrastBrightness
        let contrast = 1 + settings.brightnessContrastContrast
        return pixelMapped { red, green, blue, alpha in
            (
                Self.mapBrightnessContrast(red, brightness: brightness, contrast: contrast),
                Self.mapBrightnessContrast(green, brightness: brightness, contrast: contrast),
                Self.mapBrightnessContrast(blue, brightness: brightness, contrast: contrast),
                alpha
            )
        }
    }

    private func exposureAdjusted(amount: Double, settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let rawSettings = settings
        var settings = settings.normalized()
        if rawSettings.exposureEV == 0,
           rawSettings.exposureOffset == 0,
           rawSettings.exposureGamma == 1 {
            settings.exposureEV = max(-5, min(5, amount * 2))
        }
        let exposureScale = pow(2, settings.exposureEV)
        let inverseGamma = 1 / settings.exposureGamma
        return pixelMapped { red, green, blue, alpha in
            (
                Self.mapExposure(red, scale: exposureScale, offset: settings.exposureOffset, inverseGamma: inverseGamma),
                Self.mapExposure(green, scale: exposureScale, offset: settings.exposureOffset, inverseGamma: inverseGamma),
                Self.mapExposure(blue, scale: exposureScale, offset: settings.exposureOffset, inverseGamma: inverseGamma),
                alpha
            )
        }
    }

    private func shadowsHighlighted(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let settings = settings.normalized()
        return pixelMapped { red, green, blue, alpha in
            let luminance = Self.luminosity(red: red, green: green, blue: blue)
            let shadowWeight = 1 - Self.smoothStep(edge0: 0.08, edge1: 0.68, value: luminance)
            let highlightWeight = Self.smoothStep(edge0: 0.32, edge1: 0.92, value: luminance)
            let shadowLift = settings.shadowsHighlightsShadows * shadowWeight * 0.78
            let highlightRecover = settings.shadowsHighlightsHighlights * highlightWeight * 0.58

            func mapped(_ channel: Double) -> Double {
                let lifted = channel + (1 - channel) * shadowLift
                return lifted * (1 - highlightRecover)
            }

            return (
                mapped(red),
                mapped(green),
                mapped(blue),
                alpha
            )
        }
    }

    private func vibranced(amount: Double, settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let rawSettings = settings
        var settings = settings.normalized()
        if rawSettings.vibranceAmount == 0,
           rawSettings.vibranceSaturation == 0 {
            settings.vibranceAmount = max(-1, min(1, amount))
        }
        let strength = settings.vibranceAmount
        let saturationAmount = settings.vibranceSaturation
        return pixelMapped { red, green, blue, alpha in
            let hsl = Self.hsl(red: red, green: green, blue: blue)
            guard hsl.saturation > 0.0001 else {
                return (red, green, blue, alpha)
            }

            let delta: Double
            if strength >= 0 {
                delta = strength * (1 - hsl.saturation) * 0.80
            } else {
                delta = strength * (0.35 + hsl.saturation * 0.65)
            }
            let vibranceSaturation = max(0, min(1, hsl.saturation + delta))
            let saturation = Self.adjustedSaturation(vibranceSaturation, amount: saturationAmount)
            let output = Self.rgb(hue: hsl.hue, saturation: saturation, lightness: hsl.lightness)
            return (output.red, output.green, output.blue, alpha)
        }
    }

    private func blackWhite(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let settings = settings.normalized()
        return pixelMapped { red, green, blue, alpha in
            let hueMix = Self.blackWhiteHueMix(red: red, green: green, blue: blue, settings: settings)
            let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
            let maximum = max(red, green, blue)
            let minimum = min(red, green, blue)
            let saturation = maximum > 0 ? (maximum - minimum) / maximum : 0
            let chromaGray = max(0, min(1, maximum * hueMix))
            let output = luminance * (1 - saturation) + chromaGray * saturation
            return (output, output, output, alpha)
        }
    }

    private func channelMixed(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let settings = settings.normalized()
        return pixelMapped { red, green, blue, alpha in
            if settings.channelMixerMonochrome {
                let gray = red * settings.channelMixerMonoRed
                    + green * settings.channelMixerMonoGreen
                    + blue * settings.channelMixerMonoBlue
                    + settings.channelMixerMonoConstant
                return (gray, gray, gray, alpha)
            }

            let outputRed = red * settings.channelMixerRedRed
                + green * settings.channelMixerRedGreen
                + blue * settings.channelMixerRedBlue
                + settings.channelMixerRedConstant
            let outputGreen = red * settings.channelMixerGreenRed
                + green * settings.channelMixerGreenGreen
                + blue * settings.channelMixerGreenBlue
                + settings.channelMixerGreenConstant
            let outputBlue = red * settings.channelMixerBlueRed
                + green * settings.channelMixerBlueGreen
                + blue * settings.channelMixerBlueBlue
                + settings.channelMixerBlueConstant
            return (outputRed, outputGreen, outputBlue, alpha)
        }
    }

    private func photoFiltered(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let settings = settings.normalized()
        let filterColor = Self.photoFilterColor(settings: settings)
        return pixelMapped { red, green, blue, alpha in
            let density = settings.photoFilterDensity
            var outputRed = red * (1 - density) + filterColor.red * density
            var outputGreen = green * (1 - density) + filterColor.green * density
            var outputBlue = blue * (1 - density) + filterColor.blue * density

            if settings.photoFilterPreserveLuminosity {
                let sourceLuminosity = Self.luminosity(red: red, green: green, blue: blue)
                let outputLuminosity = max(0.0001, Self.luminosity(red: outputRed, green: outputGreen, blue: outputBlue))
                let scale = sourceLuminosity / outputLuminosity
                outputRed *= scale
                outputGreen *= scale
                outputBlue *= scale
            }

            return (outputRed, outputGreen, outputBlue, alpha)
        }
    }

    private func selectiveColored(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let settings = settings.normalized()
        let selectiveSettings = settings.selectiveColorSettings
        return pixelMapped { red, green, blue, alpha in
            var cmyk = Self.cmyk(red: red, green: green, blue: blue)
            for range in ImageEditorSelectiveColorRange.allCases {
                let weight = Self.selectiveColorWeight(red: red, green: green, blue: blue, range: range)
                guard weight > 0.001 else { continue }
                let values = selectiveSettings.values(for: range)
                Self.applySelectiveColor(values: values, method: settings.selectiveColorMethod, weight: weight, cmyk: &cmyk)
            }
            let output = Self.rgb(cyan: cmyk.cyan, magenta: cmyk.magenta, yellow: cmyk.yellow, black: cmyk.black)
            return (output.red, output.green, output.blue, alpha)
        }
    }

    private func gradientMapped(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let settings = settings.normalized()
        let stops = Self.gradientMapStops(settings: settings)
        return pixelMappedByCoordinate { x, y, red, green, blue, alpha in
            let baseLuminance = settings.gradientMapReverse
                ? 1 - Self.luminosity(red: red, green: green, blue: blue)
                : Self.luminosity(red: red, green: green, blue: blue)
            let luminance = settings.gradientMapDither
                ? Self.ditheredGradientMapPosition(baseLuminance, x: x, y: y)
                : baseLuminance
            let output = Self.gradientColor(at: luminance, stops: stops)
            return (output.red, output.green, output.blue, alpha)
        }
    }

    private func colorLookuped(settings: ImageEditorAdjustmentSettings) -> NSImage? {
        let settings = settings.normalized()
        return pixelMapped { red, green, blue, alpha in
            let output = Self.colorLookupColor(
                settings: settings,
                red: red,
                green: green,
                blue: blue
            )
            return (output.red, output.green, output.blue, alpha)
        }
    }

    private static func mapLevel(_ value: Double, black: Double, range: Double, inverseGamma: Double) -> Double {
        let normalized = max(0, min(1, (value - black) / range))
        return pow(normalized, inverseGamma)
    }

    private static func mapExposure(_ value: Double, scale: Double, offset: Double, inverseGamma: Double) -> Double {
        let exposed = max(0, min(1, value * scale + offset))
        return max(0, min(1, pow(exposed, inverseGamma)))
    }

    private static func mapBrightnessContrast(_ value: Double, brightness: Double, contrast: Double) -> Double {
        max(0, min(1, (value - 0.5) * contrast + 0.5 + brightness))
    }

    private static func photoFilterColor(settings: ImageEditorAdjustmentSettings) -> (red: Double, green: Double, blue: Double) {
        if settings.photoFilterPreset == .custom {
            return (
                settings.photoFilterCustomRed,
                settings.photoFilterCustomGreen,
                settings.photoFilterCustomBlue
            )
        }
        return settings.photoFilterPreset.rgb
    }

    private static func colorLookupColor(
        settings: ImageEditorAdjustmentSettings,
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        switch settings.colorLookupPreset {
        case .filmStock:
            return colorLookupTone(
                red: red,
                green: green,
                blue: blue,
                contrast: 1.16,
                saturation: 1.08,
                redBias: 0.025,
                greenBias: 0.012,
                blueBias: -0.018
            )
        case .crispWarm:
            return colorLookupTone(
                red: red,
                green: green,
                blue: blue,
                contrast: 1.10,
                saturation: 1.18,
                redBias: 0.055,
                greenBias: 0.020,
                blueBias: -0.055
            )
        case .tealOrange:
            let luminance = luminosity(red: red, green: green, blue: blue)
            let shadowWeight = 1 - smoothStep(edge0: 0.20, edge1: 0.68, value: luminance)
            let highlightWeight = smoothStep(edge0: 0.36, edge1: 0.92, value: luminance)
            return colorLookupTone(
                red: red + highlightWeight * 0.075 - shadowWeight * 0.040,
                green: green + shadowWeight * 0.045,
                blue: blue + shadowWeight * 0.090 - highlightWeight * 0.060,
                contrast: 1.12,
                saturation: 1.18,
                redBias: 0,
                greenBias: 0,
                blueBias: 0
            )
        case .bleachBypass:
            let luminance = luminosity(red: red, green: green, blue: blue)
            let mutedRed = red * 0.50 + luminance * 0.50
            let mutedGreen = green * 0.50 + luminance * 0.50
            let mutedBlue = blue * 0.50 + luminance * 0.50
            return colorLookupTone(
                red: mutedRed,
                green: mutedGreen,
                blue: mutedBlue,
                contrast: 1.28,
                saturation: 0.88,
                redBias: 0.010,
                greenBias: 0.006,
                blueBias: -0.006
            )
        case .moonlight:
            return colorLookupTone(
                red: red,
                green: green,
                blue: blue,
                contrast: 1.08,
                saturation: 0.82,
                redBias: -0.065,
                greenBias: -0.020,
                blueBias: 0.105
            )
        case .customCube:
            guard settings.colorLookupCube.isValid else { return (red, green, blue) }
            return colorLookupCubeColor(
                cube: settings.colorLookupCube,
                red: red,
                green: green,
                blue: blue
            )
        }
    }

    private static func colorLookupCubeColor(
        cube: ImageEditorColorLookupCube,
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let dimension = cube.dimension
        let scale = Double(dimension - 1)
        let redPosition = max(0, min(1, red)) * scale
        let greenPosition = max(0, min(1, green)) * scale
        let bluePosition = max(0, min(1, blue)) * scale

        let r0 = Int(floor(redPosition))
        let g0 = Int(floor(greenPosition))
        let b0 = Int(floor(bluePosition))
        let r1 = min(dimension - 1, r0 + 1)
        let g1 = min(dimension - 1, g0 + 1)
        let b1 = min(dimension - 1, b0 + 1)
        let rt = redPosition - Double(r0)
        let gt = greenPosition - Double(g0)
        let bt = bluePosition - Double(b0)

        let c000 = colorLookupCubeValue(cube: cube, red: r0, green: g0, blue: b0)
        let c100 = colorLookupCubeValue(cube: cube, red: r1, green: g0, blue: b0)
        let c010 = colorLookupCubeValue(cube: cube, red: r0, green: g1, blue: b0)
        let c110 = colorLookupCubeValue(cube: cube, red: r1, green: g1, blue: b0)
        let c001 = colorLookupCubeValue(cube: cube, red: r0, green: g0, blue: b1)
        let c101 = colorLookupCubeValue(cube: cube, red: r1, green: g0, blue: b1)
        let c011 = colorLookupCubeValue(cube: cube, red: r0, green: g1, blue: b1)
        let c111 = colorLookupCubeValue(cube: cube, red: r1, green: g1, blue: b1)

        let c00 = mix(c000, c100, amount: rt)
        let c10 = mix(c010, c110, amount: rt)
        let c01 = mix(c001, c101, amount: rt)
        let c11 = mix(c011, c111, amount: rt)
        let c0 = mix(c00, c10, amount: gt)
        let c1 = mix(c01, c11, amount: gt)
        return mix(c0, c1, amount: bt)
    }

    private static func colorLookupCubeValue(
        cube: ImageEditorColorLookupCube,
        red: Int,
        green: Int,
        blue: Int
    ) -> (red: Double, green: Double, blue: Double) {
        let index = ((red * cube.dimension + green) * cube.dimension + blue) * 3
        guard index + 2 < cube.values.count else { return (0, 0, 0) }
        return (cube.values[index], cube.values[index + 1], cube.values[index + 2])
    }

    private static func mix(
        _ first: (red: Double, green: Double, blue: Double),
        _ second: (red: Double, green: Double, blue: Double),
        amount: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let amount = max(0, min(1, amount))
        return (
            first.red + (second.red - first.red) * amount,
            first.green + (second.green - first.green) * amount,
            first.blue + (second.blue - first.blue) * amount
        )
    }

    private static func colorLookupTone(
        red: Double,
        green: Double,
        blue: Double,
        contrast: Double,
        saturation: Double,
        redBias: Double,
        greenBias: Double,
        blueBias: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let contrastedRed = mapBrightnessContrast(red, brightness: 0, contrast: contrast)
        let contrastedGreen = mapBrightnessContrast(green, brightness: 0, contrast: contrast)
        let contrastedBlue = mapBrightnessContrast(blue, brightness: 0, contrast: contrast)
        let hslColor = hsl(red: contrastedRed, green: contrastedGreen, blue: contrastedBlue)
        let saturated = rgb(
            hue: hslColor.hue,
            saturation: max(0, min(1, hslColor.saturation * saturation)),
            lightness: hslColor.lightness
        )
        return (
            max(0, min(1, saturated.red + redBias)),
            max(0, min(1, saturated.green + greenBias)),
            max(0, min(1, saturated.blue + blueBias))
        )
    }

    private static func gradientMapStops(settings: ImageEditorAdjustmentSettings) -> [(position: Double, red: Double, green: Double, blue: Double)] {
        switch settings.gradientMapPreset {
        case .blackWhite:
            return [(0, 0, 0, 0), (1, 1, 1, 1)]
        case .sepia:
            return [(0, 0.10, 0.06, 0.02), (0.58, 0.62, 0.39, 0.18), (1, 1.0, 0.88, 0.58)]
        case .blueOrange:
            return [(0, 0.02, 0.08, 0.20), (0.52, 0.33, 0.40, 0.50), (1, 1.0, 0.58, 0.16)]
        case .purpleTeal:
            return [(0, 0.18, 0.04, 0.30), (0.50, 0.16, 0.56, 0.55), (1, 0.84, 1.0, 0.86)]
        case .custom:
            return [
                (0, settings.gradientMapShadowRed, settings.gradientMapShadowGreen, settings.gradientMapShadowBlue),
                (1, settings.gradientMapHighlightRed, settings.gradientMapHighlightGreen, settings.gradientMapHighlightBlue)
            ]
        }
    }

    private static func gradientColor(
        at position: Double,
        stops: [(position: Double, red: Double, green: Double, blue: Double)]
    ) -> (red: Double, green: Double, blue: Double) {
        let position = max(0, min(1, position))
        guard let first = stops.first else { return (position, position, position) }
        guard let last = stops.last else { return (first.red, first.green, first.blue) }
        if position <= first.position {
            return (first.red, first.green, first.blue)
        }
        if position >= last.position {
            return (last.red, last.green, last.blue)
        }
        for index in 0..<(stops.count - 1) {
            let start = stops[index]
            let end = stops[index + 1]
            guard position >= start.position && position <= end.position else { continue }
            let span = max(0.0001, end.position - start.position)
            let t = (position - start.position) / span
            return (
                start.red + (end.red - start.red) * t,
                start.green + (end.green - start.green) * t,
                start.blue + (end.blue - start.blue) * t
            )
        }
        return (last.red, last.green, last.blue)
    }

    private static func ditheredGradientMapPosition(_ position: Double, x: Int, y: Int) -> Double {
        let bayer4x4 = [
            [0, 8, 2, 10],
            [12, 4, 14, 6],
            [3, 11, 1, 9],
            [15, 7, 13, 5]
        ]
        let threshold = (Double(bayer4x4[y & 3][x & 3]) + 0.5) / 16
        let offset = (threshold - 0.5) / 96
        return max(0, min(1, position + offset))
    }

    private static func luminosity(red: Double, green: Double, blue: Double) -> Double {
        red * 0.2126 + green * 0.7152 + blue * 0.0722
    }

    private static func cmyk(red: Double, green: Double, blue: Double) -> (cyan: Double, magenta: Double, yellow: Double, black: Double) {
        let black = 1 - max(red, green, blue)
        guard black < 0.999 else {
            return (0, 0, 0, 1)
        }
        let scale = max(0.0001, 1 - black)
        return (
            (1 - red - black) / scale,
            (1 - green - black) / scale,
            (1 - blue - black) / scale,
            black
        )
    }

    private static func rgb(cyan: Double, magenta: Double, yellow: Double, black: Double) -> (red: Double, green: Double, blue: Double) {
        let cyan = max(0, min(1, cyan))
        let magenta = max(0, min(1, magenta))
        let yellow = max(0, min(1, yellow))
        let black = max(0, min(1, black))
        return (
            (1 - cyan) * (1 - black),
            (1 - magenta) * (1 - black),
            (1 - yellow) * (1 - black)
        )
    }

    private static func applySelectiveColor(
        values: ImageEditorSelectiveColorValues,
        method: ImageEditorSelectiveColorMethod,
        weight: Double,
        cmyk: inout (cyan: Double, magenta: Double, yellow: Double, black: Double)
    ) {
        cmyk.cyan = adjustedInk(cmyk.cyan, adjustment: values.cyan, method: method, weight: weight)
        cmyk.magenta = adjustedInk(cmyk.magenta, adjustment: values.magenta, method: method, weight: weight)
        cmyk.yellow = adjustedInk(cmyk.yellow, adjustment: values.yellow, method: method, weight: weight)
        cmyk.black = adjustedInk(cmyk.black, adjustment: values.black, method: method, weight: weight)
    }

    private static func adjustedInk(
        _ component: Double,
        adjustment: Double,
        method: ImageEditorSelectiveColorMethod,
        weight: Double
    ) -> Double {
        let adjustment = max(-1, min(1, adjustment))
        let weight = max(0, min(1, weight))
        switch method {
        case .absolute:
            return max(0, min(1, component + adjustment * weight))
        case .relative:
            if adjustment >= 0 {
                return max(0, min(1, component + (1 - component) * adjustment * weight))
            }
            return max(0, min(1, component + component * adjustment * weight))
        }
    }

    private static func selectiveColorWeight(
        red: Double,
        green: Double,
        blue: Double,
        range: ImageEditorSelectiveColorRange
    ) -> Double {
        let hsl = hsl(red: red, green: green, blue: blue)
        let luminance = luminosity(red: red, green: green, blue: blue)
        let saturation = hsl.saturation
        switch range {
        case .reds:
            return chromaticWeight(hue: hsl.hue, center: 0, saturation: saturation)
        case .yellows:
            return chromaticWeight(hue: hsl.hue, center: 1.0 / 6.0, saturation: saturation)
        case .greens:
            return chromaticWeight(hue: hsl.hue, center: 2.0 / 6.0, saturation: saturation)
        case .cyans:
            return chromaticWeight(hue: hsl.hue, center: 3.0 / 6.0, saturation: saturation)
        case .blues:
            return chromaticWeight(hue: hsl.hue, center: 4.0 / 6.0, saturation: saturation)
        case .magentas:
            return chromaticWeight(hue: hsl.hue, center: 5.0 / 6.0, saturation: saturation)
        case .whites:
            return smoothStep(edge0: 0.62, edge1: 0.90, value: luminance) * max(0, 1 - saturation * 1.35)
        case .neutrals:
            let midtone = 1 - smoothStep(edge0: 0.48, edge1: 0.92, value: abs(luminance - 0.5) * 2)
            return max(0, midtone * (1 - saturation * 0.65))
        case .blacks:
            return (1 - smoothStep(edge0: 0.12, edge1: 0.42, value: luminance)) * max(0.2, 1 - saturation * 0.45)
        }
    }

    private static func chromaticWeight(hue: Double, center: Double, saturation: Double) -> Double {
        let distance = min(abs(hue - center), 1 - abs(hue - center))
        let hueWeight = 1 - smoothStep(edge0: 0.055, edge1: 0.17, value: distance)
        return hueWeight * smoothStep(edge0: 0.05, edge1: 0.28, value: saturation)
    }

    private static func smoothStep(edge0: Double, edge1: Double, value: Double) -> Double {
        guard edge0 != edge1 else { return value >= edge1 ? 1 : 0 }
        let t = max(0, min(1, (value - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    static func posterizeLevelCount(from amount: Double) -> Int {
        let fallback = amount > 0 ? amount : 4
        return max(2, min(32, Int(fallback.rounded())))
    }

    private static func posterizeChannel(_ value: Double, denominator: Double) -> Double {
        guard denominator > 0 else { return value }
        return (max(0, min(1, value)) * denominator).rounded() / denominator
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

    private static func blackWhiteHueMix(
        red: Double,
        green: Double,
        blue: Double,
        settings: ImageEditorAdjustmentSettings
    ) -> Double {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        guard delta > 0.0001 else {
            return (settings.blackWhiteReds + settings.blackWhiteGreens + settings.blackWhiteBlues) / 3
        }

        let hue: Double
        if maximum == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) * 60
        } else if maximum == green {
            hue = ((blue - red) / delta + 2) * 60
        } else {
            hue = ((red - green) / delta + 4) * 60
        }
        let normalizedHue = hue < 0 ? hue + 360 : hue
        let stops: [(Double, Double)] = [
            (0, settings.blackWhiteReds),
            (60, settings.blackWhiteYellows),
            (120, settings.blackWhiteGreens),
            (180, settings.blackWhiteCyans),
            (240, settings.blackWhiteBlues),
            (300, settings.blackWhiteMagentas),
            (360, settings.blackWhiteReds)
        ]
        for index in 0..<(stops.count - 1) {
            let start = stops[index]
            let end = stops[index + 1]
            guard normalizedHue >= start.0 && normalizedHue <= end.0 else { continue }
            let t = (normalizedHue - start.0) / max(1, end.0 - start.0)
            return start.1 + (end.1 - start.1) * t
        }
        return settings.blackWhiteReds
    }

    private static func hsl(red: Double, green: Double, blue: Double) -> (hue: Double, saturation: Double, lightness: Double) {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        let lightness = (maximum + minimum) / 2
        guard delta > 0.0001 else {
            return (0, 0, lightness)
        }

        let saturation = lightness > 0.5
            ? delta / max(0.0001, 2 - maximum - minimum)
            : delta / max(0.0001, maximum + minimum)
        let hue: Double
        if maximum == red {
            hue = ((green - blue) / delta + (green < blue ? 6 : 0)) / 6
        } else if maximum == green {
            hue = ((blue - red) / delta + 2) / 6
        } else {
            hue = ((red - green) / delta + 4) / 6
        }
        return (hue, saturation, lightness)
    }

    private static func rgb(hue: Double, saturation: Double, lightness: Double) -> (red: Double, green: Double, blue: Double) {
        guard saturation > 0 else {
            return (lightness, lightness, lightness)
        }
        let q = lightness < 0.5
            ? lightness * (1 + saturation)
            : lightness + saturation - lightness * saturation
        let p = 2 * lightness - q
        return (
            hueChannel(p: p, q: q, t: hue + 1 / 3),
            hueChannel(p: p, q: q, t: hue),
            hueChannel(p: p, q: q, t: hue - 1 / 3)
        )
    }

    private static func hueChannel(p: Double, q: Double, t: Double) -> Double {
        let wrapped = wrapUnit(t)
        if wrapped < 1 / 6 {
            return p + (q - p) * 6 * wrapped
        }
        if wrapped < 1 / 2 {
            return q
        }
        if wrapped < 2 / 3 {
            return p + (q - p) * (2 / 3 - wrapped) * 6
        }
        return p
    }

    private static func adjustedSaturation(_ saturation: Double, amount: Double) -> Double {
        let clamped = max(-1, min(1, amount))
        if clamped >= 0 {
            return max(0, min(1, saturation + (1 - saturation) * clamped))
        }
        return max(0, min(1, saturation * (1 + clamped)))
    }

    private static func adjustedLightness(_ lightness: Double, amount: Double) -> Double {
        let clamped = max(-1, min(1, amount))
        if clamped >= 0 {
            return max(0, min(1, lightness + (1 - lightness) * clamped))
        }
        return max(0, min(1, lightness * (1 + clamped)))
    }

    private static func wrapUnit(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 1)
        return wrapped < 0 ? wrapped + 1 : wrapped
    }

    private func pixelMapped(
        _ transform: (_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) -> (Double, Double, Double, Double)
    ) -> NSImage? {
        pixelMappedByCoordinate { _, _, red, green, blue, alpha in
            transform(red, green, blue, alpha)
        }
    }

    private func pixelMappedByCoordinate(
        _ transform: (_ x: Int, _ y: Int, _ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) -> (Double, Double, Double, Double)
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

    private static func byte(_ value: Double) -> UInt8 {
        UInt8((max(0, min(1, value)) * 255).rounded())
    }
}
