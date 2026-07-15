import AppKit
import CoreGraphics
import Foundation

enum XomoFigmaImageFilterBaker {
    private static let bytesPerPixel = 4

    static func apply(_ filters: XomoFigmaPlanImageFilters, to image: NSImage) -> NSImage {
        guard !filters.isIdentity,
              let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return image }

        let width = max(1, source.width)
        let height = max(1, source.height)
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
        ) else { return image }

        context.interpolationQuality = .none
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        for row in 0..<height {
            for column in 0..<width {
                let offset = row * bytesPerRow + column * bytesPerPixel
                apply(filters, to: &pixels, at: offset)
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
        else { return image }
        return NSImage(cgImage: output, size: image.size)
    }

    private static func apply(
        _ filters: XomoFigmaPlanImageFilters,
        to pixels: inout [UInt8],
        at offset: Int
    ) {
        let alpha = Double(pixels[offset + 3]) / 255
        guard alpha > 0 else { return }
        var red = Double(pixels[offset]) / 255 / alpha
        var green = Double(pixels[offset + 1]) / 255 / alpha
        var blue = Double(pixels[offset + 2]) / 255 / alpha

        let exposureScale = pow(2, filters.exposure * 2)
        red *= exposureScale
        green *= exposureScale
        blue *= exposureScale

        let contrast = 1 + filters.contrast
        red = (red - 0.5) * contrast + 0.5
        green = (green - 0.5) * contrast + 0.5
        blue = (blue - 0.5) * contrast + 0.5

        let luminance = luminosity(red: red, green: green, blue: blue)
        let saturation = 1 + filters.saturation
        red = luminance + (red - luminance) * saturation
        green = luminance + (green - luminance) * saturation
        blue = luminance + (blue - luminance) * saturation

        red += filters.temperature * 0.12 + filters.tint * 0.06
        green -= filters.tint * 0.10
        blue -= filters.temperature * 0.12 - filters.tint * 0.06

        let adjustedLuminance = luminosity(red: red, green: green, blue: blue)
        let shadowWeight = 1 - smoothStep(edge0: 0.05, edge1: 0.65, value: adjustedLuminance)
        let highlightWeight = smoothStep(edge0: 0.35, edge1: 0.95, value: adjustedLuminance)
        red = tonalChannel(
            red,
            shadows: filters.shadows,
            highlights: filters.highlights,
            shadowWeight: shadowWeight,
            highlightWeight: highlightWeight
        )
        green = tonalChannel(
            green,
            shadows: filters.shadows,
            highlights: filters.highlights,
            shadowWeight: shadowWeight,
            highlightWeight: highlightWeight
        )
        blue = tonalChannel(
            blue,
            shadows: filters.shadows,
            highlights: filters.highlights,
            shadowWeight: shadowWeight,
            highlightWeight: highlightWeight
        )

        pixels[offset] = byte(red * alpha)
        pixels[offset + 1] = byte(green * alpha)
        pixels[offset + 2] = byte(blue * alpha)
    }

    private static func tonalChannel(
        _ value: Double,
        shadows: Double,
        highlights: Double,
        shadowWeight: Double,
        highlightWeight: Double
    ) -> Double {
        var output = value
        if shadows >= 0 {
            output += (1 - output) * shadows * shadowWeight * 0.65
        } else {
            output *= 1 + shadows * shadowWeight * 0.65
        }
        if highlights >= 0 {
            output += (1 - output) * highlights * highlightWeight * 0.65
        } else {
            output *= 1 + highlights * highlightWeight * 0.65
        }
        return output
    }

    private static func luminosity(red: Double, green: Double, blue: Double) -> Double {
        red * 0.2126 + green * 0.7152 + blue * 0.0722
    }

    private static func smoothStep(edge0: Double, edge1: Double, value: Double) -> Double {
        let position = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return position * position * (3 - 2 * position)
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8((min(max(value, 0), 1) * 255).rounded())
    }
}
