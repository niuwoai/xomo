//
//  ImageEditorHealingBrush.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

extension NSImage {
    func withHealingBrush(
        points: [CGPoint],
        sourceOffset: CGSize,
        sourceImage: NSImage,
        targetContextImage: NSImage,
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat
    ) -> NSImage? {
        guard !points.isEmpty else { return nil }
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        let bytesPerRow = pixelWidth * ImageEditorHealingBrushKernel.bytesPerPixel
        guard let targetPixels = healingRGBAPixels(
            width: pixelWidth,
            height: pixelHeight,
            bytesPerRow: bytesPerRow
        ),
        let sourcePixels = sourceImage.healingRGBAPixels(
            width: pixelWidth,
            height: pixelHeight,
            bytesPerRow: bytesPerRow
        ),
        let targetContextPixels = targetContextImage.healingRGBAPixels(
            width: pixelWidth,
            height: pixelHeight,
            bytesPerRow: bytesPerRow
        ) else { return nil }

        let maskAlpha = ImageEditorHealingBrushKernel.strokeAlpha(
            width: pixelWidth,
            height: pixelHeight,
            points: points,
            diameter: width,
            hardness: hardness
        )
        let outputPixels = ImageEditorHealingBrushKernel.heal(
            targetPixels: targetPixels,
            targetContextPixels: targetContextPixels,
            sourcePixels: sourcePixels,
            maskAlpha: maskAlpha,
            width: pixelWidth,
            height: pixelHeight,
            sourceOffset: sourceOffset,
            destinationReference: ImageEditorHealingBrushKernel.strokeCenter(points),
            brushDiameter: width,
            opacity: opacity
        )
        return NSImage.healingImage(
            pixels: outputPixels,
            width: pixelWidth,
            height: pixelHeight,
            bytesPerRow: bytesPerRow,
            size: size
        )
    }

    fileprivate func healingRGBAPixels(width: Int, height: Int, bytesPerRow: Int) -> [UInt8]? {
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
        else { return nil }
        context.interpolationQuality = .none
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
        else { return nil }

        let image = NSImage(size: size)
        image.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return image
    }
}

struct ImageEditorHealingBrushColor: Equatable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
}

enum ImageEditorHealingBrushKernel {
    static let bytesPerPixel = 4

    static func strokeMaskImage(
        size: CGSize,
        points: [CGPoint],
        diameter: CGFloat,
        hardness: CGFloat
    ) -> NSImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let alpha = strokeAlpha(
            width: width,
            height: height,
            points: points,
            diameter: diameter,
            hardness: hardness
        )
        guard alpha.count == width * height else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        for (index, value) in alpha.enumerated() {
            let offset = index * bytesPerPixel
            pixels[offset] = value
            pixels[offset + 1] = value
            pixels[offset + 2] = value
            pixels[offset + 3] = value
        }
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgImage = context.makeImage()
        else { return nil }

        let image = NSImage(size: size)
        image.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return image
    }

    static func strokeAlpha(
        width: Int,
        height: Int,
        points: [CGPoint],
        diameter: CGFloat,
        hardness: CGFloat
    ) -> [UInt8] {
        guard width > 0, height > 0, !points.isEmpty else { return [] }
        let radius = max(0.5, diameter / 2)
        let innerRadius = radius * max(0, min(1, hardness))
        var alpha = [UInt8](repeating: 0, count: width * height)

        if points.count == 1, let point = points.first {
            applyStrokeSegment(
                to: &alpha,
                width: width,
                height: height,
                start: point,
                end: point,
                radius: radius,
                innerRadius: innerRadius
            )
            return alpha
        }

        for (start, end) in zip(points, points.dropFirst()) {
            applyStrokeSegment(
                to: &alpha,
                width: width,
                height: height,
                start: start,
                end: end,
                radius: radius,
                innerRadius: innerRadius
            )
        }
        return alpha
    }

    private static func applyStrokeSegment(
        to alpha: inout [UInt8],
        width: Int,
        height: Int,
        start: CGPoint,
        end: CGPoint,
        radius: CGFloat,
        innerRadius: CGFloat
    ) {
        let minX = max(0, Int(floor(min(start.x, end.x) - radius)))
        let maxX = min(width - 1, Int(ceil(max(start.x, end.x) + radius)))
        let minY = max(0, Int(floor(min(start.y, end.y) - radius)))
        let maxY = min(height - 1, Int(ceil(max(start.y, end.y) + radius)))
        guard minX <= maxX, minY <= maxY else { return }

        for y in minY...maxY {
            for x in minX...maxX {
                let distance = distanceToSegment(
                    point: CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5),
                    start: start,
                    end: end
                )
                let coverage = softCoverage(
                    distance: distance,
                    innerRadius: innerRadius,
                    outerRadius: radius
                )
                let index = y * width + x
                alpha[index] = max(alpha[index], UInt8((coverage * 255).rounded()))
            }
        }
    }

    static func heal(
        targetPixels: [UInt8],
        targetContextPixels: [UInt8],
        sourcePixels: [UInt8],
        maskAlpha: [UInt8],
        width: Int,
        height: Int,
        sourceOffset: CGSize,
        destinationReference: CGPoint,
        brushDiameter: CGFloat,
        opacity: CGFloat
    ) -> [UInt8] {
        guard targetPixels.count == width * height * bytesPerPixel,
              targetContextPixels.count == targetPixels.count,
              sourcePixels.count == targetPixels.count,
              maskAlpha.count == width * height
        else { return targetPixels }

        let sourceStart = CGPoint(
            x: destinationReference.x + sourceOffset.width,
            y: destinationReference.y + sourceOffset.height
        )
        let referenceRadius = max(2, Int((brushDiameter * 0.9).rounded()))
        let targetReference = averageColor(
            pixels: targetContextPixels,
            width: width,
            height: height,
            center: destinationReference,
            innerRadius: max(1, Int((brushDiameter * 0.55).rounded())),
            outerRadius: referenceRadius
        )
        let sourceReference = averageColor(
            pixels: sourcePixels,
            width: width,
            height: height,
            center: sourceStart,
            innerRadius: max(1, Int((brushDiameter * 0.55).rounded())),
            outerRadius: referenceRadius
        )
        let colorDelta = ImageEditorHealingBrushColor(
            red: (targetReference?.red ?? 0) - (sourceReference?.red ?? 0),
            green: (targetReference?.green ?? 0) - (sourceReference?.green ?? 0),
            blue: (targetReference?.blue ?? 0) - (sourceReference?.blue ?? 0)
        )

        let clampedOpacity = max(0, min(1, opacity))
        let offsetX = Int(sourceOffset.width.rounded())
        let offsetY = Int(sourceOffset.height.rounded())
        var output = targetPixels

        for y in 0..<height {
            for x in 0..<width {
                let maskIndex = y * width + x
                let strength = CGFloat(maskAlpha[maskIndex]) / 255 * clampedOpacity
                guard strength > 0 else { continue }
                let sourceX = x + offsetX
                let sourceY = y + offsetY
                guard sourceX >= 0, sourceY >= 0, sourceX < width, sourceY < height else { continue }

                let targetOffset = maskIndex * bytesPerPixel
                let sourcePixelOffset = (sourceY * width + sourceX) * bytesPerPixel
                let sourceAlpha = CGFloat(sourcePixels[sourcePixelOffset + 3]) / 255
                guard sourceAlpha > 0 else { continue }
                let effectiveSourceAlpha = sourceAlpha * strength
                let targetAlpha = CGFloat(targetPixels[targetOffset + 3]) / 255
                let remainingTarget = 1 - effectiveSourceAlpha
                let outputAlpha = effectiveSourceAlpha + targetAlpha * remainingTarget

                for channel in 0..<3 {
                    let sourcePremultiplied = CGFloat(sourcePixels[sourcePixelOffset + channel]) / 255
                    let sourceStraight = sourcePremultiplied / max(sourceAlpha, 0.0001)
                    let delta: CGFloat
                    switch channel {
                    case 0: delta = colorDelta.red
                    case 1: delta = colorDelta.green
                    default: delta = colorDelta.blue
                    }
                    let adjustedSource = max(0, min(1, sourceStraight + delta))
                    let targetPremultiplied = CGFloat(targetPixels[targetOffset + channel]) / 255
                    let outputPremultiplied = adjustedSource * effectiveSourceAlpha
                        + targetPremultiplied * remainingTarget
                    output[targetOffset + channel] = byte(outputPremultiplied)
                }
                output[targetOffset + 3] = byte(outputAlpha)
            }
        }
        return output
    }

    static func strokeCenter(_ points: [CGPoint]) -> CGPoint {
        guard let first = points.first else { return .zero }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
    }

    static func averageColor(
        pixels: [UInt8],
        width: Int,
        height: Int,
        center: CGPoint,
        innerRadius: Int,
        outerRadius: Int
    ) -> ImageEditorHealingBrushColor? {
        let centerX = Int(center.x.rounded())
        let centerY = Int(center.y.rounded())
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var weight: CGFloat = 0
        let innerSquared = innerRadius * innerRadius
        let outerSquared = outerRadius * outerRadius

        for yOffset in -outerRadius...outerRadius {
            for xOffset in -outerRadius...outerRadius {
                let distanceSquared = xOffset * xOffset + yOffset * yOffset
                guard distanceSquared >= innerSquared, distanceSquared <= outerSquared else { continue }
                let x = centerX + xOffset
                let y = centerY + yOffset
                guard x >= 0, y >= 0, x < width, y < height else { continue }
                let offset = (y * width + x) * bytesPerPixel
                let alpha = CGFloat(pixels[offset + 3]) / 255
                guard alpha > 0 else { continue }
                red += CGFloat(pixels[offset]) / 255 / alpha
                green += CGFloat(pixels[offset + 1]) / 255 / alpha
                blue += CGFloat(pixels[offset + 2]) / 255 / alpha
                weight += 1
            }
        }
        guard weight > 0 else { return nil }
        return ImageEditorHealingBrushColor(
            red: red / weight,
            green: green / weight,
            blue: blue / weight
        )
    }

    private static func softCoverage(
        distance: CGFloat,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) -> CGFloat {
        guard distance < outerRadius else { return 0 }
        guard distance > innerRadius else { return 1 }
        let span = max(0.0001, outerRadius - innerRadius)
        let linear = max(0, min(1, (outerRadius - distance) / span))
        return linear * linear * (3 - 2 * linear)
    }

    private static func distanceToSegment(
        point: CGPoint,
        start: CGPoint,
        end: CGPoint
    ) -> CGFloat {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let lengthSquared = deltaX * deltaX + deltaY * deltaY
        guard lengthSquared > 0.0001 else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let projection = ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) / lengthSquared
        let clamped = max(0, min(1, projection))
        let nearest = CGPoint(x: start.x + deltaX * clamped, y: start.y + deltaY * clamped)
        return hypot(point.x - nearest.x, point.y - nearest.y)
    }

    private static func byte(_ value: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, (value * 255).rounded())))
    }
}
