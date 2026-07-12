//
//  ImageEditorSelectionBoolean.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

extension ImageEditorSelection {
    static func fullCanvas(size: CGSize) -> ImageEditorSelection {
        rectangle(CGRect(origin: .zero, size: size))
    }

    static func combined(
        current: ImageEditorSelection?,
        candidate: ImageEditorSelection,
        mode: ImageEditorSelectionMode,
        canvasSize: CGSize
    ) -> ImageEditorSelection? {
        guard let current else {
            switch mode {
            case .replace, .add:
                return candidate
            case .subtract, .intersect:
                return nil
            }
        }

        guard mode != .replace else { return candidate }
        guard let currentMask = current.rasterizedMask(canvasSize: canvasSize),
              let candidateMask = candidate.rasterizedMask(canvasSize: canvasSize),
              let outputMask = currentMask.combined(with: candidateMask, mode: mode),
              let bounds = outputMask.selectedBounds(in: canvasSize)
        else { return nil }

        return .raster(mask: outputMask, bounds: bounds)
    }

    func rasterizedMask(canvasSize: CGSize) -> ImageEditorSelectionMask? {
        let width = max(1, Int(canvasSize.width.rounded()))
        let height = max(1, Int(canvasSize.height.rounded()))

        if let rasterMask,
           let image = NSImage.selectionMaskImage(
            rasterMask,
            inverted: isInverted,
            targetSize: CGSize(width: width, height: height)
           ) {
            return image.alphaPlaneMask(width: width, height: height)
        }

        let image = NSImage.rendered(size: CGSize(width: width, height: height)) { rect in
            let selectionPath = self.path()
            if isInverted {
                NSColor.white.setFill()
                rect.fill()
                guard let context = NSGraphicsContext.current?.cgContext else { return }
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setFill()
                selectionPath.fill()
                context.restoreGState()
            } else {
                NSColor.white.setFill()
                selectionPath.fill()
            }
        }
        return image?.alphaPlaneMask(width: width, height: height)
    }

    func quickMaskOverlayImage(
        canvasSize: CGSize,
        color: NSColor = .systemRed,
        opacity: CGFloat = 0.5,
        target: ImageEditorQuickMaskOverlayTarget = .maskedAreas
    ) -> NSImage? {
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              mask.alpha.count == mask.width * mask.height,
              let rgb = color.usingColorSpace(.deviceRGB)
        else { return nil }

        let clampedOpacity = max(0, min(1, opacity))
        let bytesPerPixel = 4
        let bytesPerRow = mask.width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * mask.height)

        for index in mask.alpha.indices {
            let sourceAlpha = target == .maskedAreas
                ? UInt8.max - mask.alpha[index]
                : mask.alpha[index]
            let overlayAlpha = CGFloat(sourceAlpha) / CGFloat(UInt8.max) * clampedOpacity
            let alphaByte = UInt8((overlayAlpha * CGFloat(UInt8.max)).rounded())
            let offset = index * bytesPerPixel
            pixels[offset] = UInt8((rgb.redComponent * CGFloat(alphaByte)).rounded())
            pixels[offset + 1] = UInt8((rgb.greenComponent * CGFloat(alphaByte)).rounded())
            pixels[offset + 2] = UInt8((rgb.blueComponent * CGFloat(alphaByte)).rounded())
            pixels[offset + 3] = alphaByte
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: mask.width,
                height: mask.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return nil }

        let image = NSImage(size: canvasSize)
        image.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        return image
    }

    func expanded(by radius: Int, canvasSize: CGSize) -> ImageEditorSelection? {
        guard radius > 0 else { return self }
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.expanded(by: radius)
        else { return self }
        guard let bounds = outputMask.selectedBounds(in: canvasSize) else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }

    func contracted(by radius: Int, canvasSize: CGSize) -> ImageEditorSelection? {
        guard radius > 0 else { return self }
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.contracted(by: radius)
        else { return self }
        guard let bounds = outputMask.selectedBounds(in: canvasSize) else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }

    func feathered(by radius: Int, canvasSize: CGSize) -> ImageEditorSelection? {
        guard radius > 0 else { return self }
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.feathered(by: radius)
        else { return self }
        guard let bounds = outputMask.selectedBounds(in: canvasSize) else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }

    func bordered(by radius: Int, canvasSize: CGSize) -> ImageEditorSelection? {
        guard radius > 0 else { return self }
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.bordered(by: radius)
        else { return self }
        guard let bounds = outputMask.selectedBounds(in: canvasSize) else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }

    func smoothed(by radius: Int, canvasSize: CGSize) -> ImageEditorSelection? {
        guard radius > 0 else { return self }
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.smoothed(by: radius)
        else { return self }
        guard let bounds = outputMask.selectedBounds(in: canvasSize) else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }

    func filledHoles(canvasSize: CGSize) -> ImageEditorSelection? {
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.filledHoles(),
              let bounds = outputMask.selectedBounds(in: canvasSize)
        else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }

    func removedSpeckles(maximumArea: Int, canvasSize: CGSize) -> ImageEditorSelection? {
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.removedSpeckles(maximumArea: maximumArea),
              let bounds = outputMask.selectedBounds(in: canvasSize)
        else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }

    func translated(by delta: CGSize, canvasSize: CGSize) -> ImageEditorSelection? {
        guard abs(delta.width) > 0.01 || abs(delta.height) > 0.01 else { return self }
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.translated(by: delta, canvasSize: canvasSize),
              let bounds = outputMask.selectedBounds(in: canvasSize)
        else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }

    func flipped(horizontal: Bool, canvasSize: CGSize) -> ImageEditorSelection? {
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.flipped(horizontal: horizontal),
              let bounds = outputMask.selectedBounds(in: canvasSize)
        else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }

    func rotatedQuarterTurns(clockwiseTurns: Int, canvasSize: CGSize) -> ImageEditorSelection? {
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.rotatedQuarterTurns(clockwiseTurns),
              let bounds = outputMask.selectedBounds(in: canvasSize)
        else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }

    func scaled(by factor: CGFloat, canvasSize: CGSize) -> ImageEditorSelection? {
        guard factor > 0 else { return self }
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.scaled(by: factor),
              let bounds = outputMask.selectedBounds(in: canvasSize)
        else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }

    func fittedToCanvas(canvasSize: CGSize) -> ImageEditorSelection? {
        guard let mask = rasterizedMask(canvasSize: canvasSize),
              let outputMask = mask.fittedToCanvas(),
              let bounds = outputMask.selectedBounds(in: canvasSize)
        else { return nil }
        return .raster(mask: outputMask, bounds: bounds)
    }
}

extension ImageEditorSelectionMask {
    func paintedByQuickMaskStroke(
        points: [CGPoint],
        canvasSize: CGSize,
        diameter: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat = 1,
        flow: CGFloat = 1,
        spacing: CGFloat = 0.25,
        reveal: Bool
    ) -> ImageEditorSelectionMask? {
        paintedByQuickMaskStroke(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            canvasSize: canvasSize,
            diameter: diameter,
            opacity: opacity,
            hardness: hardness,
            flow: flow,
            spacing: spacing,
            reveal: reveal
        )
    }

    func paintedByQuickMaskStroke(
        samples: [ImageEditorBrushStrokeSample],
        canvasSize: CGSize,
        diameter: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat = 1,
        flow: CGFloat = 1,
        spacing: CGFloat = 0.25,
        pressureControlsSize: Bool = false,
        pressureControlsFlow: Bool = false,
        pressureSensitivity: CGFloat = 0.5,
        reveal: Bool
    ) -> ImageEditorSelectionMask? {
        guard width > 0,
              height > 0,
              alpha.count == width * height,
              canvasSize.width > 0,
              canvasSize.height > 0,
              !samples.isEmpty,
              let coverage = quickMaskStrokeCoverage(
                samples: samples,
                canvasSize: canvasSize,
                diameter: diameter,
                opacity: opacity,
                hardness: hardness,
                flow: flow,
                spacing: spacing,
                pressureControlsSize: pressureControlsSize,
                pressureControlsFlow: pressureControlsFlow,
                pressureSensitivity: pressureSensitivity
              )
        else { return nil }

        var output = alpha
        for index in output.indices where coverage[index] > 0 {
            let current = CGFloat(alpha[index]) / CGFloat(UInt8.max)
            let amount = CGFloat(coverage[index]) / CGFloat(UInt8.max)
            let updated = reveal
                ? current + (1 - current) * amount
                : current * (1 - amount)
            output[index] = UInt8((max(0, min(1, updated)) * CGFloat(UInt8.max)).rounded())
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: output)
    }

    private func quickMaskStrokeCoverage(
        samples: [ImageEditorBrushStrokeSample],
        canvasSize: CGSize,
        diameter: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        flow: CGFloat,
        spacing: CGFloat,
        pressureControlsSize: Bool,
        pressureControlsFlow: Bool,
        pressureSensitivity: CGFloat
    ) -> [UInt8]? {
        guard !samples.isEmpty else { return nil }
        let scaleX = CGFloat(width) / canvasSize.width
        let scaleY = CGFloat(height) / canvasSize.height
        let scaledSamples = samples.map {
            ImageEditorBrushStrokeSample(
                point: CGPoint(x: $0.point.x * scaleX, y: $0.point.y * scaleY),
                pressure: $0.pressure
            )
        }
        let scaledDiameter = max(1, diameter * (scaleX + scaleY) / 2)
        let settings = ImageEditorBrushStrokeSettings(
            diameter: scaledDiameter,
            hardness: hardness,
            opacity: opacity,
            flow: flow,
            spacing: spacing,
            pressureControlsSize: pressureControlsSize,
            pressureControlsFlow: pressureControlsFlow,
            pressureSensitivity: pressureSensitivity
        )
        return ImageEditorBrushStrokeKernel.coverage(
            width: width,
            height: height,
            stamps: ImageEditorBrushStrokeKernel.stampSamples(
                samples: scaledSamples,
                diameter: scaledDiameter,
                spacing: spacing
            ),
            settings: settings
        )
    }

    func combined(with other: ImageEditorSelectionMask, mode: ImageEditorSelectionMode) -> ImageEditorSelectionMask? {
        guard width == other.width, height == other.height, alpha.count == other.alpha.count else { return nil }

        var output = [UInt8](repeating: 0, count: alpha.count)
        for index in alpha.indices {
            let current = alpha[index]
            let candidate = other.alpha[index]
            switch mode {
            case .replace:
                output[index] = candidate
            case .add:
                output[index] = max(current, candidate)
            case .subtract:
                output[index] = min(current, UInt8.max - candidate)
            case .intersect:
                output[index] = min(current, candidate)
            }
        }

        return ImageEditorSelectionMask(width: width, height: height, alpha: output)
    }

    func expanded(by radius: Int) -> ImageEditorSelectionMask? {
        morphed(by: radius, expanding: true)
    }

    func contracted(by radius: Int) -> ImageEditorSelectionMask? {
        morphed(by: radius, expanding: false)
    }

    func feathered(by radius: Int) -> ImageEditorSelectionMask? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        let radius = max(1, radius)
        let horizontal = boxBlurred(alpha, radius: radius, horizontal: true)
        let vertical = boxBlurred(horizontal, radius: radius, horizontal: false)
        return ImageEditorSelectionMask(width: width, height: height, alpha: vertical)
    }

    func bordered(by radius: Int) -> ImageEditorSelectionMask? {
        guard let expanded = expanded(by: radius),
              let contracted = contracted(by: radius),
              expanded.alpha.count == contracted.alpha.count
        else { return nil }

        var output = [UInt8](repeating: 0, count: alpha.count)
        for index in output.indices {
            output[index] = expanded.alpha[index] > contracted.alpha[index] ? UInt8.max : 0
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: output)
    }

    func smoothed(by radius: Int) -> ImageEditorSelectionMask? {
        let radius = max(1, min(16, radius))
        guard let opened = contracted(by: radius)?.expanded(by: radius),
              let closed = opened.expanded(by: radius)?.contracted(by: radius)
        else { return nil }
        return closed
    }

    func filledHoles() -> ImageEditorSelectionMask? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        var outside = [Bool](repeating: false, count: alpha.count)
        var queue: [Int] = []
        queue.reserveCapacity(alpha.count)

        func enqueueIfBackground(_ index: Int) {
            guard alpha.indices.contains(index), alpha[index] == 0, !outside[index] else { return }
            outside[index] = true
            queue.append(index)
        }

        for x in 0..<width {
            enqueueIfBackground(x)
            enqueueIfBackground((height - 1) * width + x)
        }
        for y in 0..<height {
            enqueueIfBackground(y * width)
            enqueueIfBackground(y * width + width - 1)
        }

        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1
            let x = index % width
            let y = index / width
            if x > 0 { enqueueIfBackground(index - 1) }
            if x + 1 < width { enqueueIfBackground(index + 1) }
            if y > 0 { enqueueIfBackground(index - width) }
            if y + 1 < height { enqueueIfBackground(index + width) }
        }

        var output = alpha
        var didFillHole = false
        for index in output.indices where output[index] == 0 && !outside[index] {
            output[index] = UInt8.max
            didFillHole = true
        }
        guard didFillHole else { return self }
        return ImageEditorSelectionMask(width: width, height: height, alpha: output)
    }

    func removedSpeckles(maximumArea: Int) -> ImageEditorSelectionMask? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        let maximumArea = max(1, maximumArea)
        var output = alpha
        var visited = [Bool](repeating: false, count: alpha.count)
        var queue: [Int] = []
        var component: [Int] = []
        queue.reserveCapacity(min(alpha.count, maximumArea + 1))
        component.reserveCapacity(min(alpha.count, maximumArea + 1))
        var didRemoveSpeckle = false

        func enqueueIfSelected(_ index: Int) {
            guard alpha[index] > 0, !visited[index] else { return }
            visited[index] = true
            queue.append(index)
        }

        for startIndex in alpha.indices {
            guard alpha[startIndex] > 0, !visited[startIndex] else { continue }
            queue.removeAll(keepingCapacity: true)
            component.removeAll(keepingCapacity: true)
            visited[startIndex] = true
            queue.append(startIndex)

            var cursor = 0
            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                component.append(index)

                let x = index % width
                let y = index / width
                if x > 0 { enqueueIfSelected(index - 1) }
                if x + 1 < width { enqueueIfSelected(index + 1) }
                if y > 0 { enqueueIfSelected(index - width) }
                if y + 1 < height { enqueueIfSelected(index + width) }
            }

            guard component.count <= maximumArea else { continue }
            for index in component {
                output[index] = 0
            }
            didRemoveSpeckle = true
        }

        guard didRemoveSpeckle else { return self }
        return ImageEditorSelectionMask(width: width, height: height, alpha: output)
    }

    func translated(by delta: CGSize, canvasSize: CGSize) -> ImageEditorSelectionMask? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        let dx = Int(((delta.width / max(canvasSize.width, 1)) * CGFloat(width)).rounded(.toNearestOrAwayFromZero))
        let dy = Int(((delta.height / max(canvasSize.height, 1)) * CGFloat(height)).rounded(.toNearestOrAwayFromZero))
        guard dx != 0 || dy != 0 else { return self }

        var output = [UInt8](repeating: 0, count: alpha.count)
        for y in 0..<height {
            for x in 0..<width {
                let sourceX = x - dx
                let sourceY = y - dy
                guard sourceX >= 0, sourceY >= 0, sourceX < width, sourceY < height else { continue }
                output[y * width + x] = alpha[sourceY * width + sourceX]
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: output)
    }

    func flipped(horizontal: Bool) -> ImageEditorSelectionMask? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        guard let selectedBounds = selectedPixelBounds() else { return nil }

        var output = [UInt8](repeating: 0, count: alpha.count)
        for y in selectedBounds.minY...selectedBounds.maxY {
            for x in selectedBounds.minX...selectedBounds.maxX {
                let sourceIndex = y * width + x
                guard alpha[sourceIndex] > 0 else { continue }
                let targetX = horizontal ? selectedBounds.maxX - (x - selectedBounds.minX) : x
                let targetY = horizontal ? y : selectedBounds.maxY - (y - selectedBounds.minY)
                output[targetY * width + targetX] = alpha[sourceIndex]
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: output)
    }

    func rotatedQuarterTurns(_ clockwiseTurns: Int) -> ImageEditorSelectionMask? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        guard let selectedBounds = selectedPixelBounds() else { return nil }

        let turns = ((clockwiseTurns % 4) + 4) % 4
        guard turns != 0 else { return self }

        let selectionWidth = selectedBounds.maxX - selectedBounds.minX + 1
        let selectionHeight = selectedBounds.maxY - selectedBounds.minY + 1
        var output = [UInt8](repeating: 0, count: alpha.count)

        for y in selectedBounds.minY...selectedBounds.maxY {
            for x in selectedBounds.minX...selectedBounds.maxX {
                let sourceIndex = y * width + x
                let sourceAlpha = alpha[sourceIndex]
                guard sourceAlpha > 0 else { continue }

                let localX = x - selectedBounds.minX
                let localY = y - selectedBounds.minY
                let target: (x: Int, y: Int)
                switch turns {
                case 1:
                    target = (
                        selectedBounds.minX + selectionHeight - 1 - localY,
                        selectedBounds.minY + localX
                    )
                case 2:
                    target = (
                        selectedBounds.minX + selectionWidth - 1 - localX,
                        selectedBounds.minY + selectionHeight - 1 - localY
                    )
                default:
                    target = (
                        selectedBounds.minX + localY,
                        selectedBounds.minY + selectionWidth - 1 - localX
                    )
                }

                guard target.x >= 0, target.y >= 0, target.x < width, target.y < height else { continue }
                output[target.y * width + target.x] = sourceAlpha
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: output)
    }

    func scaled(by factor: CGFloat) -> ImageEditorSelectionMask? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        guard let selectedBounds = selectedPixelBounds() else { return nil }
        guard factor > 0 else { return self }

        let selectionWidth = selectedBounds.maxX - selectedBounds.minX + 1
        let selectionHeight = selectedBounds.maxY - selectedBounds.minY + 1
        let targetWidth = max(1, Int((CGFloat(selectionWidth) * factor).rounded(.toNearestOrAwayFromZero)))
        let targetHeight = max(1, Int((CGFloat(selectionHeight) * factor).rounded(.toNearestOrAwayFromZero)))
        let centerX = CGFloat(selectedBounds.minX + selectedBounds.maxX) / 2
        let centerY = CGFloat(selectedBounds.minY + selectedBounds.maxY) / 2
        let targetMinX = Int((centerX - CGFloat(targetWidth - 1) / 2).rounded(.toNearestOrAwayFromZero))
        let targetMinY = Int((centerY - CGFloat(targetHeight - 1) / 2).rounded(.toNearestOrAwayFromZero))

        return scaledSelection(
            from: selectedBounds,
            to: (targetMinX, targetMinY, targetMinX + targetWidth - 1, targetMinY + targetHeight - 1)
        )
    }

    func fittedToCanvas() -> ImageEditorSelectionMask? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        guard let selectedBounds = selectedPixelBounds() else { return nil }
        return scaledSelection(from: selectedBounds, to: (0, 0, width - 1, height - 1))
    }

    func selectedBounds(in canvasSize: CGSize) -> CGRect? {
        guard let bounds = selectedPixelBounds() else { return nil }
        let scaleX = canvasSize.width / CGFloat(width)
        let scaleY = canvasSize.height / CGFloat(height)
        return CGRect(
            x: CGFloat(bounds.minX) * scaleX,
            y: CGFloat(bounds.minY) * scaleY,
            width: CGFloat(bounds.maxX - bounds.minX + 1) * scaleX,
            height: CGFloat(bounds.maxY - bounds.minY + 1) * scaleY
        )
    }

    private func selectedPixelBounds() -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                guard alpha[y * width + x] > 0 else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return (minX, minY, maxX, maxY)
    }

    private func scaledSelection(
        from sourceBounds: (minX: Int, minY: Int, maxX: Int, maxY: Int),
        to targetBounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)
    ) -> ImageEditorSelectionMask? {
        let sourceWidth = sourceBounds.maxX - sourceBounds.minX + 1
        let sourceHeight = sourceBounds.maxY - sourceBounds.minY + 1
        let targetWidth = targetBounds.maxX - targetBounds.minX + 1
        let targetHeight = targetBounds.maxY - targetBounds.minY + 1
        guard sourceWidth > 0, sourceHeight > 0, targetWidth > 0, targetHeight > 0 else { return nil }

        var output = [UInt8](repeating: 0, count: alpha.count)
        let clippedMinX = max(0, targetBounds.minX)
        let clippedMinY = max(0, targetBounds.minY)
        let clippedMaxX = min(width - 1, targetBounds.maxX)
        let clippedMaxY = min(height - 1, targetBounds.maxY)
        guard clippedMaxX >= clippedMinX, clippedMaxY >= clippedMinY else { return nil }

        for targetY in clippedMinY...clippedMaxY {
            for targetX in clippedMinX...clippedMaxX {
                let localTargetX = CGFloat(targetX - targetBounds.minX) + 0.5
                let localTargetY = CGFloat(targetY - targetBounds.minY) + 0.5
                let sourceX = sourceBounds.minX + min(
                    sourceWidth - 1,
                    max(0, Int(((localTargetX / CGFloat(targetWidth)) * CGFloat(sourceWidth)).rounded(.down)))
                )
                let sourceY = sourceBounds.minY + min(
                    sourceHeight - 1,
                    max(0, Int(((localTargetY / CGFloat(targetHeight)) * CGFloat(sourceHeight)).rounded(.down)))
                )
                let sourceAlpha = alpha[sourceY * width + sourceX]
                guard sourceAlpha > 0 else { continue }
                output[targetY * width + targetX] = sourceAlpha
            }
        }

        return ImageEditorSelectionMask(width: width, height: height, alpha: output)
    }

    private func morphed(by radius: Int, expanding: Bool) -> ImageEditorSelectionMask? {
        guard width > 0, height > 0, alpha.count == width * height else { return nil }
        let radius = max(1, radius)
        let integralWidth = width + 1
        var integral = [Int](repeating: 0, count: integralWidth * (height + 1))

        for y in 0..<height {
            var rowSum = 0
            for x in 0..<width {
                if alpha[y * width + x] > 0 {
                    rowSum += 1
                }
                integral[(y + 1) * integralWidth + x + 1] = integral[y * integralWidth + x + 1] + rowSum
            }
        }

        let kernelSide = radius * 2 + 1
        let kernelArea = kernelSide * kernelSide
        var output = [UInt8](repeating: 0, count: alpha.count)
        for y in 0..<height {
            for x in 0..<width {
                let minX = max(0, x - radius)
                let minY = max(0, y - radius)
                let maxX = min(width - 1, x + radius)
                let maxY = min(height - 1, y + radius)
                let selectedCount = integral[(maxY + 1) * integralWidth + maxX + 1]
                    - integral[minY * integralWidth + maxX + 1]
                    - integral[(maxY + 1) * integralWidth + minX]
                    + integral[minY * integralWidth + minX]
                if expanding {
                    output[y * width + x] = selectedCount > 0 ? UInt8.max : 0
                } else {
                    output[y * width + x] = selectedCount == kernelArea ? UInt8.max : 0
                }
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: output)
    }

    private func boxBlurred(_ source: [UInt8], radius: Int, horizontal: Bool) -> [UInt8] {
        let diameter = radius * 2 + 1
        var output = [UInt8](repeating: 0, count: source.count)

        if horizontal {
            for y in 0..<height {
                var sum = 0
                for sampleX in 0...min(width - 1, radius) {
                    sum += Int(source[y * width + sampleX])
                }
                for x in 0..<width {
                    if x > 0 {
                        let removeX = x - radius - 1
                        if removeX >= 0 {
                            sum -= Int(source[y * width + removeX])
                        }
                        let addX = x + radius
                        if addX < width {
                            sum += Int(source[y * width + addX])
                        }
                    }
                    output[y * width + x] = UInt8(max(0, min(255, sum / diameter)))
                }
            }
        } else {
            for x in 0..<width {
                var sum = 0
                for sampleY in 0...min(height - 1, radius) {
                    sum += Int(source[sampleY * width + x])
                }
                for y in 0..<height {
                    if y > 0 {
                        let removeY = y - radius - 1
                        if removeY >= 0 {
                            sum -= Int(source[removeY * width + x])
                        }
                        let addY = y + radius
                        if addY < height {
                            sum += Int(source[addY * width + x])
                        }
                    }
                    output[y * width + x] = UInt8(max(0, min(255, sum / diameter)))
                }
            }
        }

        return output
    }
}

private extension NSImage {
    func alphaPlaneMask(width: Int, height: Int) -> ImageEditorSelectionMask? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
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

        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                alpha[y * width + x] = pixels[offset + 3]
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }
}
