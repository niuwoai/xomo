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
        tolerance: CGFloat
    ) -> NSImage? {
        guard let bitmap = paintBucketBitmap() else { return nil }
        let seedX = max(0, min(bitmap.width - 1, Int((point.x / max(size.width, 1)) * CGFloat(bitmap.width))))
        let seedY = max(0, min(bitmap.height - 1, Int((point.y / max(size.height, 1)) * CGFloat(bitmap.height))))
        let seedIndex = seedY * bitmap.width + seedX
        let seedPixel = bitmap.pixel(at: seedIndex)
        let mask = bitmap.contiguousMask(seedIndex: seedIndex, seedPixel: seedPixel, tolerance: tolerance)

        guard mask.alpha.contains(where: { $0 > 0 }),
              let maskImage = NSImage.selectionMaskImage(mask, inverted: false, targetSize: size)
        else { return nil }

        return NSImage.rendered(size: size) { rect in
            draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            let fillImage = NSImage.rendered(size: size) { fillRect in
                color.withAlphaComponent(max(0, min(1, opacity))).setFill()
                fillRect.fill()
                maskImage.draw(
                    in: fillRect,
                    from: CGRect(origin: .zero, size: maskImage.size),
                    operation: .destinationIn,
                    fraction: 1
                )
            }
            fillImage?.draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1)
        }
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
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
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

    private func enqueueNeighbor(x: Int, y: Int, visited: inout [Bool], queue: inout [Int]) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let index = y * width + x
        guard !visited[index] else { return }
        visited[index] = true
        queue.append(index)
    }
}
