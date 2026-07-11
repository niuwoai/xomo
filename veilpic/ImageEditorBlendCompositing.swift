//
//  ImageEditorBlendCompositing.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

extension NSImage {
    func applyingBlendIfSourceRange(black: Double, white: Double) -> NSImage? {
        let lower = max(0, min(1, black))
        let upper = max(0, min(1, white))
        guard lower > 0 || upper < 1 else { return self }
        let targetSize = size
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        let width = max(1, Int(targetSize.width.rounded()))
        let height = max(1, Int(targetSize.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        guard var pixels = rgbaPixels(width: width, height: height, targetSize: targetSize) else { return nil }

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = Double(pixels[offset + 3]) / 255
                guard alpha > 0 else { continue }

                let red = Self.unpremultiplied(pixels[offset], alpha: alpha)
                let green = Self.unpremultiplied(pixels[offset + 1], alpha: alpha)
                let blue = Self.unpremultiplied(pixels[offset + 2], alpha: alpha)
                let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                let rangeAlpha = Self.blendIfAlpha(luminance: luminance, black: lower, white: upper)
                guard rangeAlpha < 1 else { continue }

                let nextAlpha = alpha * rangeAlpha
                pixels[offset] = Self.byte(red * nextAlpha)
                pixels[offset + 1] = Self.byte(green * nextAlpha)
                pixels[offset + 2] = Self.byte(blue * nextAlpha)
                pixels[offset + 3] = Self.byte(nextAlpha)
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
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

    func applyingBlendIfUnderlyingRange(black: Double, white: Double, backdrop: NSImage) -> NSImage? {
        let lower = max(0, min(1, black))
        let upper = max(0, min(1, white))
        guard lower > 0 || upper < 1 else { return self }
        let targetSize = size
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        let width = max(1, Int(targetSize.width.rounded()))
        let height = max(1, Int(targetSize.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        guard var pixels = rgbaPixels(width: width, height: height, targetSize: targetSize),
              let backdropPixels = backdrop.rgbaPixels(width: width, height: height, targetSize: targetSize)
        else { return nil }

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = Double(pixels[offset + 3]) / 255
                guard alpha > 0 else { continue }

                let backdropAlpha = Double(backdropPixels[offset + 3]) / 255
                guard backdropAlpha > 0 else {
                    pixels[offset] = 0
                    pixels[offset + 1] = 0
                    pixels[offset + 2] = 0
                    pixels[offset + 3] = 0
                    continue
                }

                let red = Self.unpremultiplied(pixels[offset], alpha: alpha)
                let green = Self.unpremultiplied(pixels[offset + 1], alpha: alpha)
                let blue = Self.unpremultiplied(pixels[offset + 2], alpha: alpha)
                let backdropRed = Self.unpremultiplied(backdropPixels[offset], alpha: backdropAlpha)
                let backdropGreen = Self.unpremultiplied(backdropPixels[offset + 1], alpha: backdropAlpha)
                let backdropBlue = Self.unpremultiplied(backdropPixels[offset + 2], alpha: backdropAlpha)
                let luminance = 0.2126 * backdropRed + 0.7152 * backdropGreen + 0.0722 * backdropBlue
                let rangeAlpha = Self.blendIfAlpha(luminance: luminance, black: lower, white: upper)
                guard rangeAlpha < 1 else { continue }

                let nextAlpha = alpha * rangeAlpha
                pixels[offset] = Self.byte(red * nextAlpha)
                pixels[offset + 1] = Self.byte(green * nextAlpha)
                pixels[offset + 2] = Self.byte(blue * nextAlpha)
                pixels[offset + 3] = Self.byte(nextAlpha)
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
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

    func blended(
        with overlay: NSImage,
        mode: ImageEditorBlendMode,
        opacity: Double
    ) -> NSImage? {
        let targetSize = size
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        let width = max(1, Int(targetSize.width.rounded()))
        let height = max(1, Int(targetSize.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let sourceOpacity = max(0, min(1, opacity))
        guard sourceOpacity > 0 else { return self }

        guard let basePixels = rgbaPixels(width: width, height: height, targetSize: targetSize),
              let overlayPixels = overlay.rgbaPixels(width: width, height: height, targetSize: targetSize)
        else { return nil }

        var outputPixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let baseAlpha = Double(basePixels[offset + 3]) / 255
                let originalOverlayAlpha = Double(overlayPixels[offset + 3]) / 255
                let effectiveOverlayAlpha = originalOverlayAlpha * sourceOpacity
                let overlayAlpha = mode == .dissolve
                    ? Self.dissolvedAlpha(x: x, y: y, probability: effectiveOverlayAlpha)
                    : effectiveOverlayAlpha
                let outputAlpha = overlayAlpha + baseAlpha * (1 - overlayAlpha)

                guard outputAlpha > 0 else {
                    outputPixels[offset] = 0
                    outputPixels[offset + 1] = 0
                    outputPixels[offset + 2] = 0
                    outputPixels[offset + 3] = 0
                    continue
                }

                let baseRed = Self.unpremultiplied(basePixels[offset], alpha: baseAlpha)
                let baseGreen = Self.unpremultiplied(basePixels[offset + 1], alpha: baseAlpha)
                let baseBlue = Self.unpremultiplied(basePixels[offset + 2], alpha: baseAlpha)
                let overlayRed = Self.unpremultiplied(overlayPixels[offset], alpha: originalOverlayAlpha)
                let overlayGreen = Self.unpremultiplied(overlayPixels[offset + 1], alpha: originalOverlayAlpha)
                let overlayBlue = Self.unpremultiplied(overlayPixels[offset + 2], alpha: originalOverlayAlpha)

                let blended = mode.blend(
                    baseRed: baseRed,
                    baseGreen: baseGreen,
                    baseBlue: baseBlue,
                    overlayRed: overlayRed,
                    overlayGreen: overlayGreen,
                    overlayBlue: overlayBlue
                )
                let compositedRed = overlayAlpha * ((1 - baseAlpha) * overlayRed + baseAlpha * blended.red)
                    + baseAlpha * baseRed * (1 - overlayAlpha)
                let compositedGreen = overlayAlpha * ((1 - baseAlpha) * overlayGreen + baseAlpha * blended.green)
                    + baseAlpha * baseGreen * (1 - overlayAlpha)
                let compositedBlue = overlayAlpha * ((1 - baseAlpha) * overlayBlue + baseAlpha * blended.blue)
                    + baseAlpha * baseBlue * (1 - overlayAlpha)

                outputPixels[offset] = Self.byte(compositedRed)
                outputPixels[offset + 1] = Self.byte(compositedGreen)
                outputPixels[offset + 2] = Self.byte(compositedBlue)
                outputPixels[offset + 3] = Self.byte(outputAlpha)
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

    private func rgbaPixels(width: Int, height: Int, targetSize: CGSize) -> [UInt8]? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let sourceCGImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
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
        context.draw(sourceCGImage, in: CGRect(origin: .zero, size: targetSize))
        return pixels
    }

    private static func unpremultiplied(_ byte: UInt8, alpha: Double) -> Double {
        guard alpha > 0 else { return 0 }
        return max(0, min(1, Double(byte) / 255 / alpha))
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, (value * 255).rounded())))
    }

    private static func blendIfAlpha(luminance: Double, black: Double, white: Double) -> Double {
        if black >= white {
            return luminance >= white ? 1 : 0
        }
        if luminance < black || luminance > white {
            return 0
        }
        return 1
    }

    private static func dissolvedAlpha(x: Int, y: Int, probability: Double) -> Double {
        if probability <= 0 { return 0 }
        if probability >= 1 { return 1 }
        let sample = Double(dissolveHash(x: x, y: y) & 0xffff) / 65_535
        return sample < probability ? 1 : 0
    }

    private static func dissolveHash(x: Int, y: Int) -> UInt64 {
        var value = UInt64(truncatingIfNeeded: x)
            &* 0x9E37_79B9_7F4A_7C15
            &+ UInt64(truncatingIfNeeded: y)
            &* 0xBF58_476D_1CE4_E5B9
            &+ 0x94D0_49BB_1331_11EB
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return value
    }
}

extension ImageEditorBlendMode {
    func blend(
        baseRed: Double,
        baseGreen: Double,
        baseBlue: Double,
        overlayRed: Double,
        overlayGreen: Double,
        overlayBlue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        switch self {
        case .darkerColor:
            return Self.luminance(red: overlayRed, green: overlayGreen, blue: overlayBlue)
                < Self.luminance(red: baseRed, green: baseGreen, blue: baseBlue)
                ? (overlayRed, overlayGreen, overlayBlue)
                : (baseRed, baseGreen, baseBlue)
        case .lighterColor:
            return Self.luminance(red: overlayRed, green: overlayGreen, blue: overlayBlue)
                > Self.luminance(red: baseRed, green: baseGreen, blue: baseBlue)
                ? (overlayRed, overlayGreen, overlayBlue)
                : (baseRed, baseGreen, baseBlue)
        case .hue, .saturation, .color, .luminosity:
            return hslBlend(
                baseRed: baseRed,
                baseGreen: baseGreen,
                baseBlue: baseBlue,
                overlayRed: overlayRed,
                overlayGreen: overlayGreen,
                overlayBlue: overlayBlue
            )
        case .passThrough, .normal, .dissolve, .multiply, .screen, .overlay, .darken, .lighten, .colorDodge,
             .colorBurn, .linearDodge, .linearBurn, .subtract, .divide, .softLight, .hardLight, .vividLight,
             .linearLight, .pinLight, .hardMix, .difference, .exclusion:
            return (
                Self.blendChannel(mode: self, base: baseRed, overlay: overlayRed),
                Self.blendChannel(mode: self, base: baseGreen, overlay: overlayGreen),
                Self.blendChannel(mode: self, base: baseBlue, overlay: overlayBlue)
            )
        }
    }

    private static func blendChannel(mode: ImageEditorBlendMode, base: Double, overlay: Double) -> Double {
        switch mode {
        case .passThrough, .normal, .dissolve:
            return overlay
        case .multiply:
            return base * overlay
        case .screen:
            return 1 - (1 - base) * (1 - overlay)
        case .overlay:
            return base < 0.5 ? 2 * base * overlay : 1 - 2 * (1 - base) * (1 - overlay)
        case .darken:
            return min(base, overlay)
        case .lighten:
            return max(base, overlay)
        case .colorDodge:
            return colorDodge(base: base, overlay: overlay)
        case .colorBurn:
            return colorBurn(base: base, overlay: overlay)
        case .linearDodge:
            return clamp(base + overlay)
        case .linearBurn:
            return clamp(base + overlay - 1)
        case .subtract:
            return clamp(base - overlay)
        case .divide:
            guard overlay > 0 else { return 1 }
            return clamp(base / overlay)
        case .softLight:
            if overlay <= 0.5 {
                return base - (1 - 2 * overlay) * base * (1 - base)
            } else {
                let d = base <= 0.25
                    ? ((16 * base - 12) * base + 4) * base
                    : sqrt(base)
                return base + (2 * overlay - 1) * (d - base)
            }
        case .hardLight:
            return overlay < 0.5 ? 2 * base * overlay : 1 - 2 * (1 - base) * (1 - overlay)
        case .vividLight:
            return overlay < 0.5
                ? colorBurn(base: base, overlay: 2 * overlay)
                : colorDodge(base: base, overlay: 2 * overlay - 1)
        case .linearLight:
            return clamp(base + 2 * overlay - 1)
        case .pinLight:
            return overlay < 0.5 ? min(base, 2 * overlay) : max(base, 2 * overlay - 1)
        case .hardMix:
            return blendChannel(mode: .vividLight, base: base, overlay: overlay) < 0.5 ? 0 : 1
        case .difference:
            return abs(base - overlay)
        case .exclusion:
            return base + overlay - 2 * base * overlay
        case .darkerColor, .lighterColor, .hue, .saturation, .color, .luminosity:
            return overlay
        }
    }

    private func hslBlend(
        baseRed: Double,
        baseGreen: Double,
        baseBlue: Double,
        overlayRed: Double,
        overlayGreen: Double,
        overlayBlue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let base = Self.hsl(red: baseRed, green: baseGreen, blue: baseBlue)
        let overlay = Self.hsl(red: overlayRed, green: overlayGreen, blue: overlayBlue)
        switch self {
        case .hue:
            return Self.rgb(hue: overlay.hue, saturation: base.saturation, lightness: base.lightness)
        case .saturation:
            return Self.rgb(hue: base.hue, saturation: overlay.saturation, lightness: base.lightness)
        case .color:
            return Self.rgb(hue: overlay.hue, saturation: overlay.saturation, lightness: base.lightness)
        case .luminosity:
            return Self.rgb(hue: base.hue, saturation: base.saturation, lightness: overlay.lightness)
        case .passThrough, .normal, .dissolve, .multiply, .screen, .overlay, .darken, .lighten,
             .darkerColor, .lighterColor, .colorDodge, .colorBurn, .linearDodge, .linearBurn, .subtract, .divide,
             .softLight, .hardLight, .vividLight, .linearLight, .pinLight, .hardMix, .difference, .exclusion:
            return (overlayRed, overlayGreen, overlayBlue)
        }
    }

    private static func luminance(red: Double, green: Double, blue: Double) -> Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    private static func colorDodge(base: Double, overlay: Double) -> Double {
        guard overlay < 1 else { return 1 }
        return clamp(base / (1 - overlay))
    }

    private static func colorBurn(base: Double, overlay: Double) -> Double {
        guard overlay > 0 else { return 0 }
        return 1 - clamp((1 - base) / overlay)
    }

    private static func hsl(red: Double, green: Double, blue: Double) -> (hue: Double, saturation: Double, lightness: Double) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let lightness = (maxValue + minValue) / 2
        guard maxValue != minValue else {
            return (0, 0, lightness)
        }

        let delta = maxValue - minValue
        let saturation = lightness > 0.5
            ? delta / (2 - maxValue - minValue)
            : delta / (maxValue + minValue)
        let hue: Double
        if maxValue == red {
            hue = ((green - blue) / delta + (green < blue ? 6 : 0)) / 6
        } else if maxValue == green {
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
        var value = t
        if value < 0 { value += 1 }
        if value > 1 { value -= 1 }
        if value < 1 / 6 { return p + (q - p) * 6 * value }
        if value < 1 / 2 { return q }
        if value < 2 / 3 { return p + (q - p) * (2 / 3 - value) * 6 }
        return p
    }

    private static func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}
