//
//  ImageEditorMagicWand.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

enum ImageEditorQuickSelectionSampling {
    static func points(
        from inputPoints: [CGPoint],
        within canvasBounds: CGRect,
        minimumDistance: CGFloat,
        maximumCount: Int
    ) -> [CGPoint] {
        guard maximumCount > 0 else { return [] }
        let validPoints = inputPoints.filter { point in
            point.x.isFinite && point.y.isFinite && canvasBounds.contains(point)
        }
        guard !validPoints.isEmpty else { return [] }

        let minimumDistance = max(0, minimumDistance.isFinite ? minimumDistance : 0)
        var spacedPoints: [CGPoint] = []
        for point in validPoints {
            let isFarEnough = spacedPoints.last.map {
                hypot(point.x - $0.x, point.y - $0.y) >= minimumDistance
            } ?? true
            if isFarEnough {
                spacedPoints.append(point)
            }
        }

        guard spacedPoints.count > maximumCount else { return spacedPoints }
        guard maximumCount > 1 else { return [spacedPoints[0]] }

        var segmentLengths: [CGFloat] = []
        segmentLengths.reserveCapacity(spacedPoints.count - 1)
        var totalLength: CGFloat = 0
        for index in 1..<spacedPoints.count {
            let previous = spacedPoints[index - 1]
            let current = spacedPoints[index]
            let length = hypot(current.x - previous.x, current.y - previous.y)
            segmentLengths.append(length)
            totalLength += length
        }
        guard totalLength.isFinite, totalLength > 0 else { return [spacedPoints[0]] }

        var samples = [spacedPoints[0]]
        samples.reserveCapacity(maximumCount)
        var segmentIndex = 0
        var segmentStartDistance: CGFloat = 0
        for sampleIndex in 1..<(maximumCount - 1) {
            let targetDistance = totalLength * CGFloat(sampleIndex) / CGFloat(maximumCount - 1)
            while segmentIndex < segmentLengths.count - 1,
                  segmentStartDistance + segmentLengths[segmentIndex] < targetDistance {
                segmentStartDistance += segmentLengths[segmentIndex]
                segmentIndex += 1
            }

            let segmentLength = segmentLengths[segmentIndex]
            let segmentProgress = segmentLength > 0
                ? (targetDistance - segmentStartDistance) / segmentLength
                : 0
            let start = spacedPoints[segmentIndex]
            let end = spacedPoints[segmentIndex + 1]
            samples.append(CGPoint(
                x: start.x + (end.x - start.x) * segmentProgress,
                y: start.y + (end.y - start.y) * segmentProgress
            ))
        }
        samples.append(spacedPoints[spacedPoints.count - 1])
        return samples
    }
}

@MainActor
extension ImageEditorViewModel {
    func magicSelection(
        at point: CGPoint,
        tolerance: CGFloat? = nil,
        contiguous: Bool? = nil,
        samplingImage: NSImage? = nil
    ) -> ImageEditorSelection? {
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        guard point.x.isFinite,
              point.y.isFinite,
              canvasBounds.contains(point)
        else { return nil }
        let effectiveTolerance = max(0, min(1, tolerance ?? self.tolerance))
        let image = samplingImage ?? document.compositedImage
        guard let selection = image.magicSelection(
            at: point,
            canvasSize: document.canvasSize,
            threshold: effectiveTolerance,
            contiguous: contiguous ?? isMagicWandContiguous
        ) else { return nil }
        return selection
    }

    func quickSelectionCandidates(
        at points: [CGPoint],
        tolerance: CGFloat? = nil
    ) -> [ImageEditorSelection] {
        let canvasSize = document.canvasSize
        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        let image = document.compositedImage
        guard let bitmap = image.rgbaBitmap() else { return [] }
        let threshold = max(0, min(1, tolerance ?? self.tolerance))

        return points.compactMap { point in
            guard point.x.isFinite,
                  point.y.isFinite,
                  canvasBounds.contains(point)
            else { return nil }
            return image.magicSelection(
                at: point,
                canvasSize: canvasSize,
                threshold: threshold,
                contiguous: true,
                bitmap: bitmap
            )
        }
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

fileprivate extension NSImage {
    func magicSelection(
        at point: CGPoint,
        canvasSize: CGSize,
        threshold: CGFloat,
        contiguous: Bool
    ) -> ImageEditorSelection? {
        guard let bitmap = rgbaBitmap() else { return nil }
        return magicSelection(
            at: point,
            canvasSize: canvasSize,
            threshold: threshold,
            contiguous: contiguous,
            bitmap: bitmap
        )
    }

    func magicSelection(
        at point: CGPoint,
        canvasSize: CGSize,
        threshold: CGFloat,
        contiguous: Bool,
        bitmap: MagicWandBitmap
    ) -> ImageEditorSelection? {
        let seedX = max(0, min(bitmap.width - 1, Int((point.x / max(size.width, 1)) * CGFloat(bitmap.width))))
        let seedY = max(0, min(bitmap.height - 1, Int((point.y / max(size.height, 1)) * CGFloat(bitmap.height))))
        let seedIndex = seedY * bitmap.width + seedX
        let seedPixel = bitmap.pixel(at: seedIndex)
        let clampedThreshold = max(0, min(1, threshold))

        var alpha = [UInt8](repeating: 0, count: bitmap.width * bitmap.height)
        var minX = seedX
        var maxX = seedX
        var minY = seedY
        var maxY = seedY
        var selectedCount = 0

        func select(_ index: Int) {
            alpha[index] = 255
            selectedCount += 1
            let x = index % bitmap.width
            let y = index / bitmap.width
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }

        if contiguous {
            var visited = [Bool](repeating: false, count: bitmap.width * bitmap.height)
            var queue = [Int]()
            queue.reserveCapacity(min(bitmap.width * bitmap.height, 65_536))
            queue.append(seedIndex)
            visited[seedIndex] = true

            var cursor = 0
            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                guard bitmap.pixel(at: index).distance(to: seedPixel) <= clampedThreshold else { continue }
                select(index)

                let x = index % bitmap.width
                let y = index / bitmap.width
                enqueueMagicNeighbor(x: x - 1, y: y, bitmap: bitmap, visited: &visited, queue: &queue)
                enqueueMagicNeighbor(x: x + 1, y: y, bitmap: bitmap, visited: &visited, queue: &queue)
                enqueueMagicNeighbor(x: x, y: y - 1, bitmap: bitmap, visited: &visited, queue: &queue)
                enqueueMagicNeighbor(x: x, y: y + 1, bitmap: bitmap, visited: &visited, queue: &queue)
            }
        } else {
            for index in 0..<(bitmap.width * bitmap.height)
            where bitmap.pixel(at: index).distance(to: seedPixel) <= clampedThreshold {
                select(index)
            }
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
