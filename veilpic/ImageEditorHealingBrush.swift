//
//  ImageEditorHealingBrush.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

enum ImageEditorHealingBrushMode: String, CaseIterable, Identifiable {
    case source
    case spot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .source:
            L10n.text("imageEditor.healingMode.source")
        case .spot:
            L10n.text("imageEditor.healingMode.spot")
        }
    }
}

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
        withHealingBrush(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            sourceOffset: sourceOffset,
            sourceImage: sourceImage,
            targetContextImage: targetContextImage,
            width: width,
            opacity: opacity,
            hardness: hardness,
            pressureControlsSize: false,
            pressureSensitivity: 0.5
        )
    }

    func withHealingBrush(
        samples: [ImageEditorBrushStrokeSample],
        sourceOffset: CGSize,
        sourceImage: NSImage,
        targetContextImage: NSImage,
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> NSImage? {
        guard !samples.isEmpty else { return nil }
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

        let maskAlpha = retouchStrokeAlpha(
            width: pixelWidth,
            height: pixelHeight,
            samples: samples,
            diameter: width,
            hardness: hardness,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        )
        let effectiveDiameter = retouchMaximumDiameter(
            samples: samples,
            diameter: width,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        )
        let strokePoints = samples.map(\.point)
        let maskBounds = ImageEditorHealingBrushKernel.strokeBounds(
            width: pixelWidth,
            height: pixelHeight,
            points: strokePoints,
            diameter: effectiveDiameter
        )
        let outputPixels = ImageEditorHealingBrushKernel.heal(
            targetPixels: targetPixels,
            targetContextPixels: targetContextPixels,
            sourcePixels: sourcePixels,
            maskAlpha: maskAlpha,
            maskBounds: maskBounds,
            width: pixelWidth,
            height: pixelHeight,
            sourceOffset: sourceOffset,
            destinationReference: ImageEditorHealingBrushKernel.strokeCenter(strokePoints),
            brushDiameter: effectiveDiameter,
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

    func withSpotHealingBrush(
        points: [CGPoint],
        sourceImage: NSImage,
        targetContextImage: NSImage,
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat
    ) -> NSImage? {
        withSpotHealingBrush(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            sourceImage: sourceImage,
            targetContextImage: targetContextImage,
            width: width,
            opacity: opacity,
            hardness: hardness,
            pressureControlsSize: false,
            pressureSensitivity: 0.5
        )
    }

    func withSpotHealingBrush(
        samples: [ImageEditorBrushStrokeSample],
        sourceImage: NSImage,
        targetContextImage: NSImage,
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> NSImage? {
        guard !samples.isEmpty else { return nil }
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

        let points = samples.map(\.point)
        let destinationReference = ImageEditorHealingBrushKernel.strokeCenter(points)
        let effectiveDiameter = retouchMaximumDiameter(
            samples: samples,
            diameter: width,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        )
        guard let sourceOffset = ImageEditorHealingBrushKernel.spotSourceOffset(
            pixels: sourcePixels,
            targetContextPixels: targetContextPixels,
            width: pixelWidth,
            height: pixelHeight,
            points: points,
            destinationReference: destinationReference,
            brushDiameter: effectiveDiameter
        ) else { return nil }
        let maskAlpha = retouchStrokeAlpha(
            width: pixelWidth,
            height: pixelHeight,
            samples: samples,
            diameter: width,
            hardness: hardness,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        )
        let outputPixels = ImageEditorHealingBrushKernel.heal(
            targetPixels: targetPixels,
            targetContextPixels: targetContextPixels,
            sourcePixels: sourcePixels,
            maskAlpha: maskAlpha,
            maskBounds: ImageEditorHealingBrushKernel.strokeBounds(
                width: pixelWidth,
                height: pixelHeight,
                points: points,
                diameter: effectiveDiameter
            ),
            width: pixelWidth,
            height: pixelHeight,
            sourceOffset: sourceOffset,
            destinationReference: destinationReference,
            brushDiameter: effectiveDiameter,
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

    private func retouchMaximumDiameter(
        samples: [ImageEditorBrushStrokeSample],
        diameter: CGFloat,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> CGFloat {
        guard pressureControlsSize, samples.contains(where: { $0.pressure != nil }) else {
            return max(1, diameter)
        }
        let maximumScale = samples.map {
            ImageEditorBrushStrokeKernel.mappedPressure(
                $0.pressure ?? 1,
                sensitivity: pressureSensitivity
            )
        }.max() ?? 1
        return max(1, diameter * maximumScale)
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
    typealias MaskBounds = (minX: Int, maxX: Int, minY: Int, maxY: Int)
    private typealias PointBounds = (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat)

    static func strokeBounds(
        width: Int,
        height: Int,
        points: [CGPoint],
        diameter: CGFloat
    ) -> MaskBounds? {
        guard width > 0,
              height > 0,
              diameter.isFinite,
              let pointsBounds = pointBounds(points)
        else { return nil }

        let radius = max(0.5, diameter / 2)
        let canvasMaxX = CGFloat(width - 1)
        let canvasMaxY = CGFloat(height - 1)
        let clippedMinX = max(0, floor(pointsBounds.minX - radius))
        let clippedMaxX = min(canvasMaxX, ceil(pointsBounds.maxX + radius))
        let clippedMinY = max(0, floor(pointsBounds.minY - radius))
        let clippedMaxY = min(canvasMaxY, ceil(pointsBounds.maxY + radius))

        guard clippedMinX <= clippedMaxX, clippedMinY <= clippedMaxY else { return nil }
        return (
            Int(clippedMinX),
            Int(clippedMaxX),
            Int(clippedMinY),
            Int(clippedMaxY)
        )
    }

    private static func pointBounds(_ points: [CGPoint]) -> PointBounds? {
        guard let first = points.first, first.x.isFinite, first.y.isFinite else { return nil }
        var bounds: PointBounds = (first.x, first.x, first.y, first.y)
        for point in points.dropFirst() {
            guard point.x.isFinite, point.y.isFinite else { return nil }
            bounds.minX = min(bounds.minX, point.x)
            bounds.maxX = max(bounds.maxX, point.x)
            bounds.minY = min(bounds.minY, point.y)
            bounds.maxY = max(bounds.maxY, point.y)
        }
        return bounds
    }

    static func spotSourceOffset(
        pixels: [UInt8],
        targetContextPixels: [UInt8],
        width: Int,
        height: Int,
        points: [CGPoint],
        destinationReference: CGPoint,
        brushDiameter: CGFloat
    ) -> CGSize? {
        guard pixels.count == width * height * bytesPerPixel,
              targetContextPixels.count == pixels.count,
              !points.isEmpty
        else { return nil }

        let radius = max(1, brushDiameter / 2)
        let referenceRadius = max(2, Int((brushDiameter * 0.9).rounded()))
        let targetReference = averageColor(
            pixels: targetContextPixels,
            width: width,
            height: height,
            center: destinationReference,
            innerRadius: max(1, Int((brushDiameter * 0.55).rounded())),
            outerRadius: referenceRadius
        )
        let primaryDistance = max(brushDiameter * 1.5, brushDiameter + 4)
        let distances = [primaryDistance, primaryDistance * 1.75]
        let directions = [
            CGVector(dx: -1, dy: 0),
            CGVector(dx: 1, dy: 0),
            CGVector(dx: 0, dy: -1),
            CGVector(dx: 0, dy: 1),
            CGVector(dx: -0.707, dy: -0.707),
            CGVector(dx: 0.707, dy: -0.707),
            CGVector(dx: -0.707, dy: 0.707),
            CGVector(dx: 0.707, dy: 0.707)
        ]
        var best: (offset: CGSize, score: CGFloat)?
        var hasLegalPreferredCandidate = false

        for distance in distances {
            for direction in directions {
                let offset = CGSize(
                    width: (direction.dx * distance).rounded(),
                    height: (direction.dy * distance).rounded()
                )
                guard shiftedStrokeFits(
                    points: points,
                    offset: offset,
                    radius: radius,
                    width: width,
                    height: height
                ) else { continue }
                hasLegalPreferredCandidate = true
                let sourceCenter = CGPoint(
                    x: destinationReference.x + offset.width,
                    y: destinationReference.y + offset.height
                )
                guard let sourceReference = averageColor(
                    pixels: pixels,
                    width: width,
                    height: height,
                    center: sourceCenter,
                    innerRadius: 0,
                    outerRadius: max(1, Int((brushDiameter * 0.45).rounded()))
                ) else { continue }
                let score = colorDistance(sourceReference, targetReference)
                if best == nil || score < best!.score {
                    best = (offset, score)
                }
            }
        }

        if let best { return best.offset }
        guard !hasLegalPreferredCandidate else { return nil }

        // A large brush or a small canvas can make every preferred source
        // distance invalid. Clamp those same candidates to the intersection
        // of the legal source-offset ranges, keeping the source in bounds.
        let inset = radius + 1
        var minimumOffsetX = -CGFloat.infinity
        var maximumOffsetX = CGFloat.infinity
        var minimumOffsetY = -CGFloat.infinity
        var maximumOffsetY = CGFloat.infinity
        for point in points {
            minimumOffsetX = max(minimumOffsetX, inset - point.x)
            maximumOffsetX = min(maximumOffsetX, CGFloat(width) - inset - point.x)
            minimumOffsetY = max(minimumOffsetY, inset - point.y)
            maximumOffsetY = min(maximumOffsetY, CGFloat(height) - inset - point.y)
        }
        guard minimumOffsetX <= maximumOffsetX,
              minimumOffsetY <= maximumOffsetY
        else { return nil }

        for direction in directions {
            let requestedOffset = CGSize(
                width: direction.dx * primaryDistance,
                height: direction.dy * primaryDistance
            )
            let clampedOffset = CGSize(
                width: min(max(requestedOffset.width, minimumOffsetX), maximumOffsetX),
                height: min(max(requestedOffset.height, minimumOffsetY), maximumOffsetY)
            )
            let offset = CGSize(
                width: clampedOffset.width.rounded(),
                height: clampedOffset.height.rounded()
            )
            guard (abs(offset.width) > 0.0001 || abs(offset.height) > 0.0001),
                  shiftedStrokeFits(
                      points: points,
                      offset: offset,
                      radius: radius,
                      width: width,
                      height: height
                  )
            else { continue }
            let sourceCenter = CGPoint(
                x: destinationReference.x + offset.width,
                y: destinationReference.y + offset.height
            )
            guard let sourceReference = averageColor(
                pixels: pixels,
                width: width,
                height: height,
                center: sourceCenter,
                innerRadius: 0,
                outerRadius: max(1, Int((brushDiameter * 0.45).rounded()))
            ) else { continue }
            let score = colorDistance(sourceReference, targetReference)
            if best == nil || score < best!.score {
                best = (offset, score)
            }
        }
        return best?.offset
    }

    private static func shiftedStrokeFits(
        points: [CGPoint],
        offset: CGSize,
        radius: CGFloat,
        width: Int,
        height: Int
    ) -> Bool {
        let inset = radius + 1
        return points.allSatisfy { point in
            let x = point.x + offset.width
            let y = point.y + offset.height
            return x >= inset && y >= inset
                && x <= CGFloat(width) - inset
                && y <= CGFloat(height) - inset
        }
    }

    private static func colorDistance(
        _ lhs: ImageEditorHealingBrushColor,
        _ rhs: ImageEditorHealingBrushColor?
    ) -> CGFloat {
        guard let rhs else { return 0 }
        let red = lhs.red - rhs.red
        let green = lhs.green - rhs.green
        let blue = lhs.blue - rhs.blue
        return red * red + green * green + blue * blue
    }

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
        maskBounds: MaskBounds?,
        width: Int,
        height: Int,
        sourceOffset: CGSize,
        destinationReference: CGPoint,
        brushDiameter: CGFloat,
        opacity: CGFloat
    ) -> [UInt8] {
        guard width > 0,
              height > 0,
              targetPixels.count == width * height * bytesPerPixel,
              targetContextPixels.count == targetPixels.count,
              sourcePixels.count == targetPixels.count,
              maskAlpha.count == width * height
        else { return targetPixels }

        guard let maskBounds,
              maskBounds.minX >= 0,
              maskBounds.minY >= 0,
              maskBounds.maxX < width,
              maskBounds.maxY < height,
              maskBounds.minX <= maskBounds.maxX,
              maskBounds.minY <= maskBounds.maxY
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

        for y in maskBounds.minY...maskBounds.maxY {
            for x in maskBounds.minX...maskBounds.maxX {
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
