//
//  ImageEditorBrushStroke.swift
//  veilpic
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import Foundation

struct ImageEditorBrushStrokeSettings: Equatable {
    var diameter: CGFloat
    var hardness: CGFloat
    var opacity: CGFloat
    var flow: CGFloat
    var spacing: CGFloat

    var normalized: ImageEditorBrushStrokeSettings {
        ImageEditorBrushStrokeSettings(
            diameter: max(1, diameter),
            hardness: max(0, min(1, hardness)),
            opacity: max(0, min(1, opacity)),
            flow: max(0.01, min(1, flow)),
            spacing: max(0.01, min(2, spacing))
        )
    }
}

enum ImageEditorBrushStrokeKernel {
    static let bytesPerPixel = 4

    static func stampCenters(
        points: [CGPoint],
        diameter: CGFloat,
        spacing: CGFloat
    ) -> [CGPoint] {
        guard let first = points.first else { return [] }
        let step = max(0.5, max(1, diameter) * max(0.01, min(2, spacing)))
        var centers = [first]
        var distanceUntilNextStamp = step

        for (start, end) in zip(points, points.dropFirst()) {
            let deltaX = end.x - start.x
            let deltaY = end.y - start.y
            let segmentLength = hypot(deltaX, deltaY)
            guard segmentLength > 0.0001 else { continue }

            while distanceUntilNextStamp <= segmentLength {
                let progress = distanceUntilNextStamp / segmentLength
                centers.append(CGPoint(
                    x: start.x + deltaX * progress,
                    y: start.y + deltaY * progress
                ))
                distanceUntilNextStamp += step
            }
            distanceUntilNextStamp -= segmentLength
        }

        if let lastPoint = points.last,
           let lastCenter = centers.last,
           hypot(lastPoint.x - lastCenter.x, lastPoint.y - lastCenter.y) > step * 0.5 {
            centers.append(lastPoint)
        }
        return centers
    }

    static func coverage(
        width: Int,
        height: Int,
        centers: [CGPoint],
        settings: ImageEditorBrushStrokeSettings
    ) -> [UInt8] {
        guard width > 0, height > 0, !centers.isEmpty else { return [] }
        let settings = settings.normalized
        let radius = settings.diameter / 2
        let innerRadius = radius * settings.hardness
        var accumulated = [CGFloat](repeating: 0, count: width * height)

        for center in centers {
            let minX = max(0, Int(floor(center.x - radius - 1)))
            let maxX = min(width - 1, Int(ceil(center.x + radius + 1)))
            let minY = max(0, Int(floor(center.y - radius - 1)))
            let maxY = min(height - 1, Int(ceil(center.y + radius + 1)))
            guard minX <= maxX, minY <= maxY else { continue }

            for y in minY...maxY {
                for x in minX...maxX {
                    let distance = hypot(
                        CGFloat(x) + 0.5 - center.x,
                        CGFloat(y) + 0.5 - center.y
                    )
                    let stampCoverage = radialCoverage(
                        distance: distance,
                        innerRadius: innerRadius,
                        outerRadius: radius
                    )
                    guard stampCoverage > 0 else { continue }
                    let index = y * width + x
                    let deposited = stampCoverage * settings.flow
                    accumulated[index] = min(
                        settings.opacity,
                        accumulated[index] + (1 - accumulated[index]) * deposited
                    )
                }
            }
        }

        return accumulated.map { UInt8(($0 * 255).rounded()) }
    }

    static func composite(
        targetPixels: [UInt8],
        coverage: [UInt8],
        color: NSColor,
        erase: Bool
    ) -> [UInt8] {
        guard coverage.count * bytesPerPixel == targetPixels.count else { return targetPixels }
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        let sourceRed = rgb.redComponent
        let sourceGreen = rgb.greenComponent
        let sourceBlue = rgb.blueComponent
        let sourceColorAlpha = rgb.alphaComponent
        let sourceColors = [sourceRed, sourceGreen, sourceBlue]
        var output = targetPixels

        for index in coverage.indices where coverage[index] > 0 {
            let amount = CGFloat(coverage[index]) / 255
            let offset = index * bytesPerPixel
            if erase {
                let remaining = 1 - amount
                for channel in 0..<bytesPerPixel {
                    output[offset + channel] = byte(CGFloat(targetPixels[offset + channel]) / 255 * remaining)
                }
                continue
            }

            let sourceAlpha = amount * sourceColorAlpha
            let remaining = 1 - sourceAlpha
            let targetAlpha = CGFloat(targetPixels[offset + 3]) / 255
            for channel in 0..<3 {
                let targetPremultiplied = CGFloat(targetPixels[offset + channel]) / 255
                output[offset + channel] = byte(sourceColors[channel] * sourceAlpha + targetPremultiplied * remaining)
            }
            output[offset + 3] = byte(sourceAlpha + targetAlpha * remaining)
        }
        return output
    }

    private static func radialCoverage(
        distance: CGFloat,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) -> CGFloat {
        let antialiasedEdge = max(0, min(1, outerRadius + 0.5 - distance))
        guard antialiasedEdge > 0 else { return 0 }
        guard distance > innerRadius, innerRadius < outerRadius else { return antialiasedEdge }
        let linear = max(0, min(1, (outerRadius - distance) / (outerRadius - innerRadius)))
        let softened = linear * linear * (3 - 2 * linear)
        return min(antialiasedEdge, softened)
    }

    private static func byte(_ value: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, (value * 255).rounded())))
    }
}

extension NSImage {
    func withBrushStroke(
        points: [CGPoint],
        color: NSColor,
        settings: ImageEditorBrushStrokeSettings,
        erase: Bool
    ) -> NSImage? {
        guard !points.isEmpty else { return nil }
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        let bytesPerRow = pixelWidth * ImageEditorBrushStrokeKernel.bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * pixelHeight)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: &pixels,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        let normalized = settings.normalized
        let centers = ImageEditorBrushStrokeKernel.stampCenters(
            points: points,
            diameter: normalized.diameter,
            spacing: normalized.spacing
        )
        let strokeCoverage = ImageEditorBrushStrokeKernel.coverage(
            width: pixelWidth,
            height: pixelHeight,
            centers: centers,
            settings: normalized
        )
        var outputPixels = ImageEditorBrushStrokeKernel.composite(
            targetPixels: pixels,
            coverage: strokeCoverage,
            color: color,
            erase: erase
        )
        guard let outputContext = CGContext(
            data: &outputPixels,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let outputCGImage = outputContext.makeImage()
        else { return nil }

        let output = NSImage(size: size)
        output.addRepresentation(NSBitmapImageRep(cgImage: outputCGImage))
        return output
    }
}
