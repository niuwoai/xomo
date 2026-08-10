//
//  ImageEditorPaintBucket.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

extension NSImage {
    func withPaintBucketFill(
        at point: CGPoint,
        color: NSColor,
        opacity: CGFloat,
        tolerance: CGFloat,
        contiguous: Bool
    ) -> NSImage? {
        guard let bitmap = paintBucketBitmap() else { return nil }
        let seedX = max(0, min(bitmap.width - 1, Int((point.x / max(size.width, 1)) * CGFloat(bitmap.width))))
        let seedY = max(0, min(bitmap.height - 1, Int((point.y / max(size.height, 1)) * CGFloat(bitmap.height))))
        let seedIndex = seedY * bitmap.width + seedX
        let seedPixel = bitmap.pixel(at: seedIndex)
        let mask = contiguous
            ? bitmap.contiguousMask(seedIndex: seedIndex, seedPixel: seedPixel, tolerance: tolerance)
            : bitmap.matchingMask(seedPixel: seedPixel, tolerance: tolerance)

        guard mask.alpha.contains(where: { $0 > 0 }) else { return nil }
        return bitmap.filledImage(mask: mask, color: color, opacity: opacity, size: size)
    }

    private func paintBucketBitmap() -> PaintBucketBitmap? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
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
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return PaintBucketBitmap(width: width, height: height, pixels: pixels)
    }
}

private struct PaintBucketPixel {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    func distance(to pixel: PaintBucketPixel) -> CGFloat {
        let redDelta = red - pixel.red
        let greenDelta = green - pixel.green
        let blueDelta = blue - pixel.blue
        let alphaDelta = alpha - pixel.alpha
        return sqrt(redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta + alphaDelta * alphaDelta)
    }
}

private struct PaintBucketBitmap {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    func pixel(at index: Int) -> PaintBucketPixel {
        let offset = index * 4
        return PaintBucketPixel(
            red: CGFloat(pixels[offset]) / 255,
            green: CGFloat(pixels[offset + 1]) / 255,
            blue: CGFloat(pixels[offset + 2]) / 255,
            alpha: CGFloat(pixels[offset + 3]) / 255
        )
    }

    func contiguousMask(seedIndex: Int, seedPixel: PaintBucketPixel, tolerance: CGFloat) -> ImageEditorSelectionMask {
        let clampedTolerance = max(0, min(1, tolerance))
        var visited = [Bool](repeating: false, count: width * height)
        var alpha = [UInt8](repeating: 0, count: width * height)
        var queue = [Int]()
        queue.reserveCapacity(min(width * height, 65_536))
        queue.append(seedIndex)
        visited[seedIndex] = true

        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1

            guard pixel(at: index).distance(to: seedPixel) <= clampedTolerance else { continue }
            alpha[index] = UInt8.max

            let x = index % width
            let y = index / width
            enqueueNeighbor(x: x - 1, y: y, visited: &visited, queue: &queue)
            enqueueNeighbor(x: x + 1, y: y, visited: &visited, queue: &queue)
            enqueueNeighbor(x: x, y: y - 1, visited: &visited, queue: &queue)
            enqueueNeighbor(x: x, y: y + 1, visited: &visited, queue: &queue)
        }

        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }

    func matchingMask(seedPixel: PaintBucketPixel, tolerance: CGFloat) -> ImageEditorSelectionMask {
        let clampedTolerance = max(0, min(1, tolerance))
        let alpha = (0..<(width * height)).map { index in
            pixel(at: index).distance(to: seedPixel) <= clampedTolerance ? UInt8.max : 0
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }

    func filledImage(
        mask: ImageEditorSelectionMask,
        color: NSColor,
        opacity: CGFloat,
        size: CGSize
    ) -> NSImage? {
        guard mask.width == width,
              mask.height == height,
              mask.alpha.count == width * height,
              let rgb = color.usingColorSpace(.deviceRGB)
        else { return nil }

        let fillAlpha = max(0, min(1, opacity)) * rgb.alphaComponent
        let inverseFillAlpha = 1 - fillAlpha
        let fillRed = rgb.redComponent * fillAlpha
        let fillGreen = rgb.greenComponent * fillAlpha
        let fillBlue = rgb.blueComponent * fillAlpha
        var output = pixels

        for index in mask.alpha.indices where mask.alpha[index] > 0 {
            let offset = index * 4
            let sourceRed = CGFloat(pixels[offset]) / 255
            let sourceGreen = CGFloat(pixels[offset + 1]) / 255
            let sourceBlue = CGFloat(pixels[offset + 2]) / 255
            let sourceAlpha = CGFloat(pixels[offset + 3]) / 255
            output[offset] = byte(fillRed + sourceRed * inverseFillAlpha)
            output[offset + 1] = byte(fillGreen + sourceGreen * inverseFillAlpha)
            output[offset + 2] = byte(fillBlue + sourceBlue * inverseFillAlpha)
            output[offset + 3] = byte(fillAlpha + sourceAlpha * inverseFillAlpha)
        }

        guard let provider = CGDataProvider(data: Data(output) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return nil }
        return NSImage(cgImage: cgImage, size: size)
    }

    private func byte(_ value: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, Int((value * 255).rounded()))))
    }

    private func enqueueNeighbor(x: Int, y: Int, visited: inout [Bool], queue: inout [Int]) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let index = y * width + x
        guard !visited[index] else { return }
        visited[index] = true
        queue.append(index)
    }
}
