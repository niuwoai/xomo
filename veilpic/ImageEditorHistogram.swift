//
//  ImageEditorHistogram.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import CoreGraphics

enum ImageEditorHistogramSource: String, CaseIterable, Identifiable {
    case composite
    case selectedLayer
    case selection

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.histogram.source.\(rawValue)")
    }

    var shortTitle: String {
        L10n.text("imageEditor.histogram.source.\(rawValue).short")
    }
}

enum ImageEditorHistogramChannel: String, CaseIterable, Identifiable {
    case rgb
    case luminance
    case red
    case green
    case blue

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.histogram.channel.\(rawValue)")
    }

    var shortTitle: String {
        L10n.text("imageEditor.histogram.channel.\(rawValue).short")
    }

    func value(in bin: ImageEditorHistogramBin) -> Double {
        switch self {
        case .rgb:
            return max(bin.red, bin.green, bin.blue)
        case .luminance:
            return bin.luminance
        case .red:
            return bin.red
        case .green:
            return bin.green
        case .blue:
            return bin.blue
        }
    }

    func average(in summary: ImageEditorHistogramSummary) -> Double {
        switch self {
        case .rgb, .luminance:
            return summary.averageLuminance
        case .red:
            return summary.averageRed
        case .green:
            return summary.averageGreen
        case .blue:
            return summary.averageBlue
        }
    }
}

struct ImageEditorHistogramBin: Equatable, Identifiable {
    let index: Int
    let red: Double
    let green: Double
    let blue: Double
    let luminance: Double

    var id: Int { index }
}

struct ImageEditorHistogramSummary: Equatable {
    static let empty = ImageEditorHistogramSummary(
        bins: [],
        sampledPixelCount: 0,
        pixelCount: 0,
        transparentPixelCount: 0,
        averageRed: 0,
        averageGreen: 0,
        averageBlue: 0,
        averageLuminance: 0,
        clippedShadowPixels: 0,
        clippedHighlightPixels: 0
    )

    let bins: [ImageEditorHistogramBin]
    let sampledPixelCount: Int
    let pixelCount: Int
    let transparentPixelCount: Int
    let averageRed: Double
    let averageGreen: Double
    let averageBlue: Double
    let averageLuminance: Double
    let clippedShadowPixels: Int
    let clippedHighlightPixels: Int

    var clippedShadowRatio: Double {
        guard pixelCount > 0 else { return 0 }
        return Double(clippedShadowPixels) / Double(pixelCount)
    }

    var clippedHighlightRatio: Double {
        guard pixelCount > 0 else { return 0 }
        return Double(clippedHighlightPixels) / Double(pixelCount)
    }
}

extension NSImage {
    func histogramSummary(binCount: Int = 32, maximumSampleEdge: Int = 128) -> ImageEditorHistogramSummary {
        guard binCount > 0,
              maximumSampleEdge > 0,
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return .empty }

        let sourceWidth = max(cgImage.width, 1)
        let sourceHeight = max(cgImage.height, 1)
        let scale = min(1, CGFloat(maximumSampleEdge) / CGFloat(max(sourceWidth, sourceHeight)))
        let sampleWidth = max(1, Int((CGFloat(sourceWidth) * scale).rounded()))
        let sampleHeight = max(1, Int((CGFloat(sourceHeight) * scale).rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * sampleHeight)

        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .empty }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var redBins = [Int](repeating: 0, count: binCount)
        var greenBins = [Int](repeating: 0, count: binCount)
        var blueBins = [Int](repeating: 0, count: binCount)
        var luminanceBins = [Int](repeating: 0, count: binCount)
        var redTotal = 0
        var greenTotal = 0
        var blueTotal = 0
        var luminanceTotal = 0
        var clippedShadowPixels = 0
        var clippedHighlightPixels = 0
        let sampledPixelCount = sampleWidth * sampleHeight
        var pixelCount = 0
        var transparentPixelCount = 0

        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = Int(pixels[offset + 3])
                guard alpha > 0 else {
                    transparentPixelCount += 1
                    continue
                }

                let red = histogramUnpremultipliedChannel(Int(pixels[offset]), alpha: alpha)
                let green = histogramUnpremultipliedChannel(Int(pixels[offset + 1]), alpha: alpha)
                let blue = histogramUnpremultipliedChannel(Int(pixels[offset + 2]), alpha: alpha)
                let luminance = Int((0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)).rounded())

                pixelCount += 1
                redBins[histogramBinIndex(for: red, binCount: binCount)] += 1
                greenBins[histogramBinIndex(for: green, binCount: binCount)] += 1
                blueBins[histogramBinIndex(for: blue, binCount: binCount)] += 1
                luminanceBins[histogramBinIndex(for: luminance, binCount: binCount)] += 1
                if luminance <= 0 {
                    clippedShadowPixels += 1
                }
                if luminance >= 255 {
                    clippedHighlightPixels += 1
                }
                redTotal += red
                greenTotal += green
                blueTotal += blue
                luminanceTotal += luminance
            }
        }

        let peak = max(
            redBins.max() ?? 0,
            greenBins.max() ?? 0,
            blueBins.max() ?? 0,
            luminanceBins.max() ?? 0,
            1
        )
        let bins = (0..<binCount).map { index in
            ImageEditorHistogramBin(
                index: index,
                red: Double(redBins[index]) / Double(peak),
                green: Double(greenBins[index]) / Double(peak),
                blue: Double(blueBins[index]) / Double(peak),
                luminance: Double(luminanceBins[index]) / Double(peak)
            )
        }

        guard pixelCount > 0 else {
            return ImageEditorHistogramSummary(
                bins: bins,
                sampledPixelCount: sampledPixelCount,
                pixelCount: 0,
                transparentPixelCount: transparentPixelCount,
                averageRed: 0,
                averageGreen: 0,
                averageBlue: 0,
                averageLuminance: 0,
                clippedShadowPixels: 0,
                clippedHighlightPixels: 0
            )
        }

        return ImageEditorHistogramSummary(
            bins: bins,
            sampledPixelCount: sampledPixelCount,
            pixelCount: pixelCount,
            transparentPixelCount: transparentPixelCount,
            averageRed: Double(redTotal) / Double(pixelCount),
            averageGreen: Double(greenTotal) / Double(pixelCount),
            averageBlue: Double(blueTotal) / Double(pixelCount),
            averageLuminance: Double(luminanceTotal) / Double(pixelCount),
            clippedShadowPixels: clippedShadowPixels,
            clippedHighlightPixels: clippedHighlightPixels
        )
    }

    private func histogramBinIndex(for value: Int, binCount: Int) -> Int {
        min(binCount - 1, max(0, (value * binCount) / 256))
    }

    private func histogramUnpremultipliedChannel(_ value: Int, alpha: Int) -> Int {
        guard alpha < 255 else { return value }
        return min(255, (value * 255 + alpha / 2) / alpha)
    }
}
