//
//  ImageEditorHistogram.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import CoreGraphics

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
        pixelCount: 0,
        averageRed: 0,
        averageGreen: 0,
        averageBlue: 0,
        averageLuminance: 0
    )

    let bins: [ImageEditorHistogramBin]
    let pixelCount: Int
    let averageRed: Double
    let averageGreen: Double
    let averageBlue: Double
    let averageLuminance: Double
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
        let pixelCount = sampleWidth * sampleHeight

        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                let luminance = Int((0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)).rounded())

                redBins[histogramBinIndex(for: red, binCount: binCount)] += 1
                greenBins[histogramBinIndex(for: green, binCount: binCount)] += 1
                blueBins[histogramBinIndex(for: blue, binCount: binCount)] += 1
                luminanceBins[histogramBinIndex(for: luminance, binCount: binCount)] += 1
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

        return ImageEditorHistogramSummary(
            bins: bins,
            pixelCount: pixelCount,
            averageRed: Double(redTotal) / Double(pixelCount),
            averageGreen: Double(greenTotal) / Double(pixelCount),
            averageBlue: Double(blueTotal) / Double(pixelCount),
            averageLuminance: Double(luminanceTotal) / Double(pixelCount)
        )
    }

    private func histogramBinIndex(for value: Int, binCount: Int) -> Int {
        min(binCount - 1, max(0, (value * binCount) / 256))
    }
}
