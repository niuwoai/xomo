//
//  ImageEditorMagicWand.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    func magicSelection(at point: CGPoint, tolerance: CGFloat? = nil) -> ImageEditorSelection? {
        let effectiveTolerance = max(0, min(1, tolerance ?? self.tolerance))
        guard let selection = document.compositedImage.contiguousMagicSelection(
            at: point,
            canvasSize: document.canvasSize,
            threshold: effectiveTolerance
        ) else {
            return fallbackMagicSelection(at: point)
        }
        return selection
    }

    private func fallbackMagicSelection(at point: CGPoint) -> ImageEditorSelection {
        let side = max(24, min(document.canvasSize.width, document.canvasSize.height) * 0.18)
        let rect = CGRect(
            x: point.x - side / 2,
            y: point.y - side / 2,
            width: side,
            height: side
        ).intersection(CGRect(origin: .zero, size: document.canvasSize))
        return .rectangle(rect)
    }
}

private struct MagicWandPixel: Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    func distance(to pixel: MagicWandPixel) -> CGFloat {
        let redDelta = red - pixel.red
        let greenDelta = green - pixel.green
        let blueDelta = blue - pixel.blue
        let alphaDelta = alpha - pixel.alpha
        return sqrt(redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta + alphaDelta * alphaDelta)
    }
}

private extension NSImage {
    func contiguousMagicSelection(at point: CGPoint, canvasSize: CGSize, threshold: CGFloat) -> ImageEditorSelection? {
        guard let bitmap = rgbaBitmap() else { return nil }
        let seedX = max(0, min(bitmap.width - 1, Int((point.x / max(size.width, 1)) * CGFloat(bitmap.width))))
        let seedY = max(0, min(bitmap.height - 1, Int((point.y / max(size.height, 1)) * CGFloat(bitmap.height))))
        let seedIndex = seedY * bitmap.width + seedX
        let seedPixel = bitmap.pixel(at: seedIndex)
        let clampedThreshold = max(0, min(1, threshold))

        var visited = [Bool](repeating: false, count: bitmap.width * bitmap.height)
        var alpha = [UInt8](repeating: 0, count: bitmap.width * bitmap.height)
        var queue = [Int]()
        queue.reserveCapacity(min(bitmap.width * bitmap.height, 65_536))
        queue.append(seedIndex)
        visited[seedIndex] = true

        var cursor = 0
        var minX = seedX
        var maxX = seedX
        var minY = seedY
        var maxY = seedY
        var selectedCount = 0

        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1

            let pixel = bitmap.pixel(at: index)
            guard pixel.distance(to: seedPixel) <= clampedThreshold else { continue }

            alpha[index] = 255
            selectedCount += 1
            let x = index % bitmap.width
            let y = index / bitmap.width
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)

            enqueueMagicNeighbor(x: x - 1, y: y, bitmap: bitmap, visited: &visited, queue: &queue)
            enqueueMagicNeighbor(x: x + 1, y: y, bitmap: bitmap, visited: &visited, queue: &queue)
            enqueueMagicNeighbor(x: x, y: y - 1, bitmap: bitmap, visited: &visited, queue: &queue)
            enqueueMagicNeighbor(x: x, y: y + 1, bitmap: bitmap, visited: &visited, queue: &queue)
        }

        guard selectedCount > 0 else { return nil }
        let bounds = CGRect(
            x: CGFloat(minX) / CGFloat(bitmap.width) * canvasSize.width,
            y: CGFloat(minY) / CGFloat(bitmap.height) * canvasSize.height,
            width: CGFloat(maxX - minX + 1) / CGFloat(bitmap.width) * canvasSize.width,
            height: CGFloat(maxY - minY + 1) / CGFloat(bitmap.height) * canvasSize.height
        )
        let mask = ImageEditorSelectionMask(width: bitmap.width, height: bitmap.height, alpha: alpha)
        return .raster(mask: mask, bounds: bounds)
    }

    private func enqueueMagicNeighbor(
        x: Int,
        y: Int,
        bitmap: MagicWandBitmap,
        visited: inout [Bool],
        queue: inout [Int]
    ) {
        guard x >= 0, y >= 0, x < bitmap.width, y < bitmap.height else { return }
        let index = y * bitmap.width + x
        guard !visited[index] else { return }
        visited[index] = true
        queue.append(index)
    }

    func rgbaBitmap() -> MagicWandBitmap? {
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
        return MagicWandBitmap(width: width, height: height, pixels: pixels)
    }
}

private struct MagicWandBitmap {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    func pixel(at index: Int) -> MagicWandPixel {
        let offset = index * 4
        return MagicWandPixel(
            red: CGFloat(pixels[offset]) / 255,
            green: CGFloat(pixels[offset + 1]) / 255,
            blue: CGFloat(pixels[offset + 2]) / 255,
            alpha: CGFloat(pixels[offset + 3]) / 255
        )
    }
}
