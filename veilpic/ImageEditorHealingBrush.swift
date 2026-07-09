//
//  ImageEditorHealingBrush.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

extension NSImage {
    func withHealingBrush(points: [CGPoint], width: CGFloat, opacity: CGFloat) -> NSImage? {
        guard points.count > 1 else { return nil }
        guard let mask = healingStrokeMask(points: points, width: width) else { return nil }

        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = pixelWidth * bytesPerPixel
        guard var sourcePixels = healingRGBAPixels(width: pixelWidth, height: pixelHeight, bytesPerRow: bytesPerRow),
              let maskPixels = mask.healingRGBAPixels(width: pixelWidth, height: pixelHeight, bytesPerRow: bytesPerRow)
        else {
            return nil
        }

        let maskAlpha = maskPixels.enumerated().compactMap { index, value -> UInt8? in
            index % bytesPerPixel == 3 ? value : nil
        }
        let sampleOffsets = HealingBrushSampler.offsets(for: width)
        let clampedOpacity = max(0, min(1, opacity))

        for y in 0..<pixelHeight {
            for x in 0..<pixelWidth {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let strength = CGFloat(maskPixels[offset + 3]) / 255 * clampedOpacity
                guard strength > 0 else { continue }

                guard let sample = HealingBrushSampler.averageColor(
                    aroundX: x,
                    y: y,
                    pixels: sourcePixels,
                    maskAlpha: maskAlpha,
                    width: pixelWidth,
                    height: pixelHeight,
                    bytesPerRow: bytesPerRow,
                    offsets: sampleOffsets
                ) else {
                    continue
                }

                sourcePixels[offset] = HealingBrushSampler.blend(sourcePixels[offset], toward: sample.red, strength: strength)
                sourcePixels[offset + 1] = HealingBrushSampler.blend(sourcePixels[offset + 1], toward: sample.green, strength: strength)
                sourcePixels[offset + 2] = HealingBrushSampler.blend(sourcePixels[offset + 2], toward: sample.blue, strength: strength)
            }
        }

        return NSImage.healingImage(
            pixels: sourcePixels,
            width: pixelWidth,
            height: pixelHeight,
            bytesPerRow: bytesPerRow,
            size: size
        )
    }

    private func healingStrokeMask(points: [CGPoint], width: CGFloat) -> NSImage? {
        guard let first = points.first else { return nil }
        let path = NSBezierPath()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = max(1, width)
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: point)
        }

        return NSImage.rendered(size: size) { _ in
            NSColor.white.setStroke()
            path.stroke()
        }
    }

    private func healingRGBAPixels(width: Int, height: Int, bytesPerRow: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return nil
        }

        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private static func healingImage(
        pixels: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int,
        size: CGSize
    ) -> NSImage? {
        var outputPixels = pixels
        guard let context = CGContext(
            data: &outputPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgImage = context.makeImage()
        else {
            return nil
        }

        let image = NSImage(size: size)
        image.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return image
    }
}

private struct HealingBrushColor {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
}

private enum HealingBrushSampler {
    static func offsets(for brushWidth: CGFloat) -> [CGPoint] {
        let innerRadius = max(2, Int((brushWidth * 0.55).rounded()))
        let outerRadius = max(innerRadius + 2, Int((brushWidth * 1.45).rounded()))
        let step = max(1, outerRadius / 18)
        var offsets: [CGPoint] = []

        for y in stride(from: -outerRadius, through: outerRadius, by: step) {
            for x in stride(from: -outerRadius, through: outerRadius, by: step) {
                let distanceSquared = x * x + y * y
                guard distanceSquared >= innerRadius * innerRadius,
                      distanceSquared <= outerRadius * outerRadius
                else {
                    continue
                }
                offsets.append(CGPoint(x: x, y: y))
            }
        }

        return offsets
    }

    static func averageColor(
        aroundX x: Int,
        y: Int,
        pixels: [UInt8],
        maskAlpha: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int,
        offsets: [CGPoint]
    ) -> HealingBrushColor? {
        var redTotal = 0
        var greenTotal = 0
        var blueTotal = 0
        var count = 0

        for offset in offsets {
            let sampleX = x + Int(offset.x)
            let sampleY = y + Int(offset.y)
            guard sampleX >= 0, sampleY >= 0, sampleX < width, sampleY < height else { continue }
            let maskIndex = sampleY * width + sampleX
            guard maskAlpha[maskIndex] == 0 else { continue }

            let pixelOffset = sampleY * bytesPerRow + sampleX * 4
            redTotal += Int(pixels[pixelOffset])
            greenTotal += Int(pixels[pixelOffset + 1])
            blueTotal += Int(pixels[pixelOffset + 2])
            count += 1
        }

        guard count > 0 else { return nil }
        return HealingBrushColor(
            red: UInt8(redTotal / count),
            green: UInt8(greenTotal / count),
            blue: UInt8(blueTotal / count)
        )
    }

    static func blend(_ source: UInt8, toward target: UInt8, strength: CGFloat) -> UInt8 {
        let sourceValue = CGFloat(source)
        let targetValue = CGFloat(target)
        let blended = sourceValue + (targetValue - sourceValue) * max(0, min(1, strength))
        return UInt8(max(0, min(255, blended.rounded())))
    }
}
