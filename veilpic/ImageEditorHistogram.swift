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

    func count(in bin: ImageEditorHistogramBin) -> Int {
        switch self {
        case .rgb, .luminance:
            return bin.luminanceCount
        case .red:
            return bin.redCount
        case .green:
            return bin.greenCount
        case .blue:
            return bin.blueCount
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

    func median(in summary: ImageEditorHistogramSummary) -> Double {
        switch self {
        case .rgb, .luminance:
            return summary.medianLuminance
        case .red:
            return summary.medianRed
        case .green:
            return summary.medianGreen
        case .blue:
            return summary.medianBlue
        }
    }

    func standardDeviation(in summary: ImageEditorHistogramSummary) -> Double {
        switch self {
        case .rgb, .luminance:
            return summary.standardDeviationLuminance
        case .red:
            return summary.standardDeviationRed
        case .green:
            return summary.standardDeviationGreen
        case .blue:
            return summary.standardDeviationBlue
        }
    }
}

struct ImageEditorHistogramBin: Equatable, Identifiable {
    let index: Int
    let red: Double
    let green: Double
    let blue: Double
    let luminance: Double
    let redCount: Int
    let greenCount: Int
    let blueCount: Int
    let luminanceCount: Int

    var id: Int { index }
}

struct ImageEditorHistogramProbe: Equatable {
    let lowerLevel: Int
    let upperLevel: Int
    let count: Int
    let percentile: Double
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
        medianRed: 0,
        medianGreen: 0,
        medianBlue: 0,
        medianLuminance: 0,
        standardDeviationRed: 0,
        standardDeviationGreen: 0,
        standardDeviationBlue: 0,
        standardDeviationLuminance: 0,
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
    let medianRed: Double
    let medianGreen: Double
    let medianBlue: Double
    let medianLuminance: Double
    let standardDeviationRed: Double
    let standardDeviationGreen: Double
    let standardDeviationBlue: Double
    let standardDeviationLuminance: Double
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

    func probe(
        channel: ImageEditorHistogramChannel,
        binIndex: Int
    ) -> ImageEditorHistogramProbe? {
        guard bins.indices.contains(binIndex) else { return nil }
        let lowerLevel = binIndex * 256 / bins.count
        let upperLevel = min(255, ((binIndex + 1) * 256 / bins.count) - 1)
        let cumulativeCount = bins[...binIndex].reduce(into: 0) { result, bin in
            result += channel.count(in: bin)
        }
        return ImageEditorHistogramProbe(
            lowerLevel: lowerLevel,
            upperLevel: upperLevel,
            count: channel.count(in: bins[binIndex]),
            percentile: pixelCount > 0
                ? Double(cumulativeCount) / Double(pixelCount)
                : 0
        )
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
        var redValueCounts = [Int](repeating: 0, count: 256)
        var greenValueCounts = [Int](repeating: 0, count: 256)
        var blueValueCounts = [Int](repeating: 0, count: 256)
        var luminanceValueCounts = [Int](repeating: 0, count: 256)
        var redTotal = 0
        var greenTotal = 0
        var blueTotal = 0
        var luminanceTotal = 0
        var redSquaredTotal = 0.0
        var greenSquaredTotal = 0.0
        var blueSquaredTotal = 0.0
        var luminanceSquaredTotal = 0.0
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
                redValueCounts[red] += 1
                greenValueCounts[green] += 1
                blueValueCounts[blue] += 1
                luminanceValueCounts[luminance] += 1
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
                redSquaredTotal += Double(red * red)
                greenSquaredTotal += Double(green * green)
                blueSquaredTotal += Double(blue * blue)
                luminanceSquaredTotal += Double(luminance * luminance)
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
                luminance: Double(luminanceBins[index]) / Double(peak),
                redCount: redBins[index],
                greenCount: greenBins[index],
                blueCount: blueBins[index],
                luminanceCount: luminanceBins[index]
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
                medianRed: 0,
                medianGreen: 0,
                medianBlue: 0,
                medianLuminance: 0,
                standardDeviationRed: 0,
                standardDeviationGreen: 0,
                standardDeviationBlue: 0,
                standardDeviationLuminance: 0,
                clippedShadowPixels: 0,
                clippedHighlightPixels: 0
            )
        }

        let averageRed = Double(redTotal) / Double(pixelCount)
        let averageGreen = Double(greenTotal) / Double(pixelCount)
        let averageBlue = Double(blueTotal) / Double(pixelCount)
        let averageLuminance = Double(luminanceTotal) / Double(pixelCount)
        return ImageEditorHistogramSummary(
            bins: bins,
            sampledPixelCount: sampledPixelCount,
            pixelCount: pixelCount,
            transparentPixelCount: transparentPixelCount,
            averageRed: averageRed,
            averageGreen: averageGreen,
            averageBlue: averageBlue,
            averageLuminance: averageLuminance,
            medianRed: histogramMedian(valueCounts: redValueCounts, pixelCount: pixelCount),
            medianGreen: histogramMedian(valueCounts: greenValueCounts, pixelCount: pixelCount),
            medianBlue: histogramMedian(valueCounts: blueValueCounts, pixelCount: pixelCount),
            medianLuminance: histogramMedian(valueCounts: luminanceValueCounts, pixelCount: pixelCount),
            standardDeviationRed: histogramStandardDeviation(
                squaredTotal: redSquaredTotal,
                average: averageRed,
                pixelCount: pixelCount
            ),
            standardDeviationGreen: histogramStandardDeviation(
                squaredTotal: greenSquaredTotal,
                average: averageGreen,
                pixelCount: pixelCount
            ),
            standardDeviationBlue: histogramStandardDeviation(
                squaredTotal: blueSquaredTotal,
                average: averageBlue,
                pixelCount: pixelCount
            ),
            standardDeviationLuminance: histogramStandardDeviation(
                squaredTotal: luminanceSquaredTotal,
                average: averageLuminance,
                pixelCount: pixelCount
            ),
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

    private func histogramMedian(valueCounts: [Int], pixelCount: Int) -> Double {
        guard pixelCount > 0 else { return 0 }
        let lowerRank = (pixelCount - 1) / 2
        let upperRank = pixelCount / 2
        var cumulativeCount = 0
        var lowerValue: Int?

        for (value, count) in valueCounts.enumerated() {
            cumulativeCount += count
            if lowerValue == nil, cumulativeCount > lowerRank {
                lowerValue = value
            }
            if cumulativeCount > upperRank {
                return Double((lowerValue ?? value) + value) / 2
            }
        }
        return 0
    }

    private func histogramStandardDeviation(
        squaredTotal: Double,
        average: Double,
        pixelCount: Int
    ) -> Double {
        guard pixelCount > 0 else { return 0 }
        let variance = max(0, squaredTotal / Double(pixelCount) - average * average)
        return sqrt(variance)
    }
}
