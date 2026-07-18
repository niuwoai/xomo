//
//  ImageEditorToneBrush.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

enum ImageEditorSpongeMode: String, CaseIterable, Identifiable {
    case saturate
    case desaturate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saturate:
            L10n.text("imageEditor.spongeMode.saturate")
        case .desaturate:
            L10n.text("imageEditor.spongeMode.desaturate")
        }
    }
}

extension NSImage {
    func withToneBrush(
        points: [CGPoint],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        burn: Bool
    ) -> NSImage? {
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        let maskAlpha = ImageEditorHealingBrushKernel.strokeAlpha(
            width: pixelWidth,
            height: pixelHeight,
            points: points,
            diameter: width,
            hardness: hardness
        )
        guard maskAlpha.count == pixelWidth * pixelHeight else { return nil }
        return toneAdjusted(maskAlpha: maskAlpha, opacity: opacity, burn: burn)
    }

    func withSpongeBrush(
        points: [CGPoint],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        mode: ImageEditorSpongeMode
    ) -> NSImage? {
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        let maskAlpha = ImageEditorHealingBrushKernel.strokeAlpha(
            width: pixelWidth,
            height: pixelHeight,
            points: points,
            diameter: width,
            hardness: hardness
        )
        guard maskAlpha.count == pixelWidth * pixelHeight else { return nil }
        return saturationAdjusted(maskAlpha: maskAlpha, opacity: opacity, mode: mode)
    }

    func withBlurBrush(
        points: [CGPoint],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        radius: CGFloat
    ) -> NSImage? {
        guard let blurredSource = blurred(radius: max(0.5, radius)) else { return nil }
        return mixingBrushSource(
            blurredSource,
            points: points,
            width: width,
            opacity: opacity,
            hardness: hardness
        )
    }

    func withSharpenBrush(
        points: [CGPoint],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        intensity: CGFloat
    ) -> NSImage? {
        guard let sharpenedSource = filtered(kind: .sharpen, intensity: Double(max(0.1, min(1, intensity)))) else { return nil }
        return mixingBrushSource(
            sharpenedSource,
            points: points,
            width: width,
            opacity: opacity,
            hardness: hardness
        )
    }

    func withSmudgeBrush(points: [CGPoint], width: CGFloat, opacity: CGFloat) -> NSImage? {
        guard points.count > 1 else { return nil }
        var output = self
        let clampedOpacity = max(0, min(1, opacity)) * 0.86
        let lineWidth = max(1, width)

        for segmentIndex in 1..<points.count {
            let previous = points[segmentIndex - 1]
            let current = points[segmentIndex]
            let delta = CGSize(width: current.x - previous.x, height: current.y - previous.y)
            guard abs(delta.width) > 0.1 || abs(delta.height) > 0.1 else { continue }

            let sourceSnapshot = output
            let path = NSBezierPath()
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.lineWidth = lineWidth
            path.move(to: previous)
            path.line(to: current)

            guard let strokeMask = NSImage.rendered(size: size, actions: { _ in
                NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                    NSColor.white.setStroke()
                    path.stroke()
                }
            }),
            let shiftedSource = NSImage.rendered(size: size, actions: { _ in
                sourceSnapshot.draw(
                    in: CGRect(x: delta.width, y: -delta.height, width: size.width, height: size.height),
                    from: CGRect(origin: .zero, size: sourceSnapshot.size),
                    operation: .copy,
                    fraction: 1
                )
            }),
            let clippedSource = NSImage.rendered(size: size, actions: { rect in
                shiftedSource.draw(
                    in: rect,
                    from: CGRect(origin: .zero, size: shiftedSource.size),
                    operation: .copy,
                    fraction: 1
                )
                strokeMask.draw(
                    in: rect,
                    from: CGRect(origin: .zero, size: strokeMask.size),
                    operation: .destinationIn,
                    fraction: 1
                )
            }),
            let nextOutput = NSImage.rendered(size: size, actions: { rect in
                output.draw(
                    in: rect,
                    from: CGRect(origin: .zero, size: output.size),
                    operation: .copy,
                    fraction: 1
                )
                clippedSource.draw(
                    in: rect,
                    from: CGRect(origin: .zero, size: clippedSource.size),
                    operation: .sourceOver,
                    fraction: clampedOpacity
                )
            }) else {
                return nil
            }
            output = nextOutput
        }

        return output
    }

    private func mixingBrushSource(
        _ brushSource: NSImage,
        points: [CGPoint],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat
    ) -> NSImage? {
        guard let strokeMask = ImageEditorHealingBrushKernel.strokeMaskImage(
            size: size,
            points: points,
            diameter: width,
            hardness: hardness
        ) else { return nil }

        guard let clippedBlur = NSImage.rendered(size: size, actions: { _ in
            brushSource.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: brushSource.size),
                operation: .copy,
                fraction: 1
            )
            strokeMask.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: strokeMask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }) else {
            return nil
        }

        return NSImage.rendered(size: size, actions: { _ in
            draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
            clippedBlur.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: clippedBlur.size),
                operation: .sourceOver,
                fraction: max(0, min(1, opacity))
            )
        })
    }

    private func toneAdjusted(maskAlpha: [UInt8], opacity: CGFloat, burn: Bool) -> NSImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        guard var sourcePixels = rgbaPixels(width: width, height: height, bytesPerRow: bytesPerRow),
              maskAlpha.count == width * height
        else {
            return nil
        }

        let clampedOpacity = max(0, min(1, opacity))
        let effectScale: CGFloat = 0.72
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let maskIndex = y * width + x
                let maskStrength = CGFloat(maskAlpha[maskIndex]) / 255
                let strength = clampedOpacity * maskStrength * effectScale
                guard strength > 0 else { continue }

                for channel in 0..<3 {
                    let value = CGFloat(sourcePixels[offset + channel])
                    let adjusted = burn
                        ? value * (1 - strength)
                        : value + (255 - value) * strength
                    sourcePixels[offset + channel] = UInt8(max(0, min(255, adjusted.rounded())))
                }
            }
        }

        return NSImage.fromRGBA(
            pixels: sourcePixels,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            size: size
        )
    }

    private func saturationAdjusted(
        maskAlpha: [UInt8],
        opacity: CGFloat,
        mode: ImageEditorSpongeMode
    ) -> NSImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        guard var sourcePixels = rgbaPixels(width: width, height: height, bytesPerRow: bytesPerRow),
              maskAlpha.count == width * height
        else { return nil }

        let clampedOpacity = max(0, min(1, opacity))
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let maskIndex = y * width + x
                let strength = CGFloat(maskAlpha[maskIndex]) / 255 * clampedOpacity * 0.9
                guard strength > 0 else { continue }

                let red = CGFloat(sourcePixels[offset])
                let green = CGFloat(sourcePixels[offset + 1])
                let blue = CGFloat(sourcePixels[offset + 2])
                let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
                let multiplier = mode == .saturate ? 1 + strength : 1 - strength
                sourcePixels[offset] = UInt8(max(0, min(255, (luminance + (red - luminance) * multiplier).rounded())))
                sourcePixels[offset + 1] = UInt8(max(0, min(255, (luminance + (green - luminance) * multiplier).rounded())))
                sourcePixels[offset + 2] = UInt8(max(0, min(255, (luminance + (blue - luminance) * multiplier).rounded())))
            }
        }

        return NSImage.fromRGBA(
            pixels: sourcePixels,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            size: size
        )
    }

    private func rgbaPixels(width: Int, height: Int, bytesPerRow: Int) -> [UInt8]? {
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
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private static func fromRGBA(
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
        return NSImage(cgImage: cgImage, size: size)
    }
}
