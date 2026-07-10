//
//  ImageEditorSelectionEditCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    var canEditSelectionPixels: Bool {
        !editableSelectionPixelLayerIndices().isEmpty
    }

    var canCopySelectionToNewLayer: Bool {
        guard selectedLayerCount == 1,
              hasSelection,
              let layer = document.selectedLayer
        else { return false }
        return !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && !document.isEffectivelyPixelsLocked(layer)
    }

    var canCutSelectionToNewLayer: Bool {
        canEditSelectionPixels
    }

    var canCopySelectionToClipboard: Bool {
        canCopySelectionToNewLayer
    }

    var canCopyMergedToClipboard: Bool {
        document.canvasSize.width > 0 && document.canvasSize.height > 0
    }

    var canCopyMergedToNewLayer: Bool {
        canCopyMergedToClipboard
    }

    func fillSelection() {
        fillSelection(with: foregroundColor)
    }

    func fillSelectionWithBackgroundColor() {
        fillSelection(with: backgroundColor)
    }

    private func fillSelection(with color: NSColor) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        applySelectionPixelEdit(
            historyKey: "imageEditor.history.selectionFill",
            selectedHistoryKey: "imageEditor.history.selectionFillSelected",
            statusKey: "imageEditor.status.selectionFilled",
            selectedStatusKey: "imageEditor.status.selectionFilledSelected"
        ) { layer in
            guard let output = layer.image.filled(
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                color: color,
                opacity: opacity,
                feather: feather
            ) else { return nil }
            return document.isEffectivelyTransparencyLocked(layer)
                ? (output.preservingAlpha(from: layer.image) ?? output)
                : output
        }
    }

    func strokeSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        applySelectionPixelEdit(
            historyKey: "imageEditor.history.selectionStroke",
            selectedHistoryKey: "imageEditor.history.selectionStrokeSelected",
            statusKey: "imageEditor.status.selectionStroked",
            selectedStatusKey: "imageEditor.status.selectionStrokedSelected"
        ) { layer in
            guard let output = layer.image.stroked(
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                color: foregroundColor,
                width: max(1, brushSize),
                opacity: opacity,
                feather: feather
            ) else { return nil }
            return document.isEffectivelyTransparencyLocked(layer)
                ? (output.preservingAlpha(from: layer.image) ?? output)
                : output
        }
    }

    func contentAwareFillSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        applySelectionPixelEdit(
            historyKey: "imageEditor.history.selectionContentAwareFill",
            selectedHistoryKey: "imageEditor.history.selectionContentAwareFillSelected",
            statusKey: "imageEditor.status.selectionContentAwareFilled",
            selectedStatusKey: "imageEditor.status.selectionContentAwareFilledSelected"
        ) { layer in
            guard let output = layer.image.contentAwareFilled(
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                feather: feather
            ) else { return nil }
            return document.isEffectivelyTransparencyLocked(layer)
                ? (output.preservingAlpha(from: layer.image) ?? output)
                : output
        }
    }

    func patchSelection(from start: CGPoint?, to end: CGPoint?) {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard let start, let end else { return }
        let offset = CGSize(width: end.x - start.x, height: end.y - start.y)
        guard hypot(offset.width, offset.height) >= 1 else { return }
        guard canEditSelectionPixels,
              let index = document.selectedLayerIndex,
              let output = document.layers[index].image.patched(
                selection: selection,
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                offsetInCanvas: offset,
                opacity: opacity,
                feather: feather
              )
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        let layer = document.layers[index]
        let protectedOutput = document.isEffectivelyTransparencyLocked(layer)
            ? (output.preservingAlpha(from: layer.image) ?? output)
            : output
        document.layers[index].image = protectedOutput.normalizedBitmapImage()
        appendHistory(L10n.text("imageEditor.history.selectionPatch"))
        statusText = L10n.text("imageEditor.status.selectionPatched")
    }

    func copySelectionToNewLayer() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard canCopySelectionToNewLayer,
              let index = document.selectedLayerIndex,
              let clippedImage = document.layers[index].visibleImage.copied(
                selection: selection,
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                feather: feather
              )
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        let sourceLayer = document.layers[index]
        var layer = ImageEditorLayer.blank(
            name: L10n.format("imageEditor.layer.selectionCopyName", sourceLayer.name),
            size: clippedImage.size
        )
        layer.image = clippedImage.normalizedBitmapImage()
        layer.frame = sourceLayer.frame
        layer.opacity = sourceLayer.opacity
        layer.fillOpacity = sourceLayer.fillOpacity
        layer.blendMode = sourceLayer.blendMode
        layer.groupID = sourceLayer.groupID
        document.layers.insert(layer, at: index + 1)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.selectionCopyLayer"))
        statusText = L10n.text("imageEditor.status.selectionCopiedToLayer")
    }

    func clearSelectionPixels() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        applySelectionPixelEdit(
            historyKey: "imageEditor.history.selectionClearPixels",
            selectedHistoryKey: "imageEditor.history.selectionClearPixelsSelected",
            statusKey: "imageEditor.status.selectionPixelsCleared",
            selectedStatusKey: "imageEditor.status.selectionPixelsClearedSelected"
        ) { layer in
            layer.image.cleared(
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                feather: feather
            )
        }
    }

    func cutSelectionToNewLayer() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard canCutSelectionToNewLayer,
              let index = document.selectedLayerIndex,
              let clippedImage = document.layers[index].visibleImage.copied(
                selection: selection,
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                feather: feather
              ),
              let clearedImage = document.layers[index].image.cleared(
                selection: selection,
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                feather: feather
              )
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].image = clearedImage.normalizedBitmapImage()
        let sourceLayer = document.layers[index]
        var layer = ImageEditorLayer.blank(
            name: L10n.format("imageEditor.layer.selectionCutName", sourceLayer.name),
            size: clippedImage.size
        )
        layer.image = clippedImage.normalizedBitmapImage()
        layer.frame = sourceLayer.frame
        layer.opacity = sourceLayer.opacity
        layer.fillOpacity = sourceLayer.fillOpacity
        layer.blendMode = sourceLayer.blendMode
        layer.groupID = sourceLayer.groupID
        document.layers.insert(layer, at: index + 1)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.selectionCutLayer"))
        statusText = L10n.text("imageEditor.status.selectionCutToLayer")
    }

    func copySelectionToClipboard() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard canCopySelectionToClipboard,
              let layer = document.selectedLayer,
              let clippedImage = layer.visibleImage.copied(
                selection: selection,
                layerFrame: layer.frame,
                canvasSize: document.canvasSize,
                feather: feather
              )
        else {
            statusText = L10n.text("imageEditor.status.selectionCopyToClipboardFailed")
            return
        }

        let didCopy = ClipboardImageWriter.copy(
            clippedImage.normalizedBitmapImage(),
            preferredFileName: "\(layer.name)-selection.png"
        )
        statusText = didCopy
            ? L10n.text("imageEditor.status.selectionCopiedToClipboard")
            : L10n.text("imageEditor.status.selectionCopyToClipboardFailed")
    }

    func copyMergedToClipboard() {
        guard canCopyMergedToClipboard else {
            statusText = L10n.text("imageEditor.status.copyMergedToClipboardFailed")
            return
        }

        let mergedImage: NSImage
        if let selection = document.selection {
            guard let clippedImage = document.compositedImage.copied(
                selection: selection,
                layerFrame: CGRect(origin: .zero, size: document.canvasSize),
                canvasSize: document.canvasSize,
                feather: feather
            ) else {
                statusText = L10n.text("imageEditor.status.copyMergedToClipboardFailed")
                return
            }
            mergedImage = clippedImage
        } else {
            mergedImage = document.compositedImage
        }

        let didCopy = ClipboardImageWriter.copy(
            mergedImage.normalizedBitmapImage(),
            preferredFileName: "\(document.sourceName)-merged.png"
        )
        statusText = didCopy
            ? L10n.text("imageEditor.status.copyMergedToClipboard")
            : L10n.text("imageEditor.status.copyMergedToClipboardFailed")
    }

    func copyMergedToNewLayer() {
        guard canCopyMergedToNewLayer else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let mergedImage: NSImage
        let layerNameKey: String
        if let selection = document.selection {
            guard let clippedImage = document.compositedImage.copied(
                selection: selection,
                layerFrame: CGRect(origin: .zero, size: document.canvasSize),
                canvasSize: document.canvasSize,
                feather: feather
            ) else {
                statusText = L10n.text("imageEditor.status.operationFailed")
                return
            }
            mergedImage = clippedImage
            layerNameKey = "imageEditor.layer.mergedSelectionCopyName"
        } else {
            mergedImage = document.compositedImage
            layerNameKey = "imageEditor.layer.mergedCopyName"
        }

        pushUndo()
        var layer = ImageEditorLayer.blank(
            name: L10n.text(layerNameKey),
            size: document.canvasSize
        )
        layer.image = mergedImage.normalizedBitmapImage()
        layer.frame = CGRect(origin: .zero, size: document.canvasSize)
        layer.opacity = 1
        layer.fillOpacity = 1
        layer.blendMode = .normal
        layer.groupID = nil
        layer.isClippingMask = false
        document.layers.append(layer)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.selectionCopyMergedLayer"))
        statusText = L10n.text("imageEditor.status.selectionCopiedMergedToLayer")
    }

    private func editableSelectionPixelLayerIndices() -> [Int] {
        guard hasSelection, !isEditingLayerMask else { return [] }
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && layer.kind.isPixel
                && !document.isEffectivelyPixelsLocked(layer)
        }
    }

    private func applySelectionPixelEdit(
        historyKey: String,
        selectedHistoryKey: String,
        statusKey: String,
        selectedStatusKey: String,
        render: (ImageEditorLayer) -> NSImage?
    ) {
        let edits = editableSelectionPixelLayerIndices().compactMap { index -> (Int, NSImage)? in
            guard let output = render(document.layers[index]) else { return nil }
            return (index, output.normalizedBitmapImage())
        }
        guard !edits.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for (index, image) in edits {
            document.layers[index].image = image
        }
        appendHistory(L10n.text(edits.count == 1 ? historyKey : selectedHistoryKey))
        statusText = edits.count == 1
            ? L10n.text(statusKey)
            : L10n.format(selectedStatusKey, edits.count)
    }
}

private extension NSImage {
    func filled(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        color: NSColor,
        opacity: CGFloat,
        feather: CGFloat
    ) -> NSImage? {
        guard let selectionMask = selection.layerMask(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            feather: feather
        ) else { return nil }

        return NSImage.rendered(size: size) { rect in
            draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            let fill = NSImage.rendered(size: size) { fillRect in
                color.withAlphaComponent(opacity).setFill()
                fillRect.fill()
                selectionMask.draw(
                    in: fillRect,
                    from: CGRect(origin: .zero, size: selectionMask.size),
                    operation: .destinationIn,
                    fraction: 1
                )
            }
            fill?.draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1)
        }
    }

    func stroked(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        color: NSColor,
        width: CGFloat,
        opacity: CGFloat,
        feather: CGFloat
    ) -> NSImage? {
        guard let stroke = selection.layerStroke(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            color: color,
            width: width,
            opacity: opacity,
            feather: feather
        ) else { return nil }

        return NSImage.rendered(size: size) { rect in
            draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            stroke.draw(in: rect, from: CGRect(origin: .zero, size: stroke.size), operation: .sourceOver, fraction: 1)
        }
    }

    func copied(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        feather: CGFloat
    ) -> NSImage? {
        guard let selectionMask = selection.layerMask(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            feather: feather
        ) else { return nil }

        return NSImage.rendered(size: size) { rect in
            draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            selectionMask.draw(
                in: rect,
                from: CGRect(origin: .zero, size: selectionMask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
    }

    func contentAwareFilled(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        feather: CGFloat
    ) -> NSImage? {
        guard let selectionMask = selection.layerMask(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            feather: feather
        ) else { return nil }

        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard var pixels = rgbaPixels(width: width, height: height),
              let mask = selectionMask.alphaMask(width: width, height: height)
        else { return nil }

        let selectedAlpha = mask.alpha
        guard selectedAlpha.contains(where: { $0 > 0 }) else { return nil }
        guard let fallback = contentAwareFallbackColor(pixels: pixels, mask: selectedAlpha, width: width, height: height) else {
            return nil
        }

        let sourcePixels = pixels
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let maxRadius = max(8, min(48, max(width, height) / 4))

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let maskAlpha = CGFloat(selectedAlpha[pixelIndex]) / 255
                guard maskAlpha > 0 else { continue }

                let replacement = contentAwareColor(
                    x: x,
                    y: y,
                    pixels: sourcePixels,
                    mask: selectedAlpha,
                    width: width,
                    height: height,
                    maxRadius: maxRadius,
                    fallback: fallback
                )
                let offset = y * bytesPerRow + x * bytesPerPixel
                let inverseAlpha = 1 - maskAlpha
                pixels[offset] = blendedByte(original: pixels[offset], replacement: replacement.red, alpha: maskAlpha, inverseAlpha: inverseAlpha)
                pixels[offset + 1] = blendedByte(original: pixels[offset + 1], replacement: replacement.green, alpha: maskAlpha, inverseAlpha: inverseAlpha)
                pixels[offset + 2] = blendedByte(original: pixels[offset + 2], replacement: replacement.blue, alpha: maskAlpha, inverseAlpha: inverseAlpha)
                pixels[offset + 3] = blendedByte(original: pixels[offset + 3], replacement: replacement.alpha, alpha: maskAlpha, inverseAlpha: inverseAlpha)
            }
        }

        return NSImage.rgbaImage(width: width, height: height, pixels: pixels, size: size)
    }

    func patched(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        offsetInCanvas: CGSize,
        opacity: CGFloat,
        feather: CGFloat
    ) -> NSImage? {
        guard layerFrame.width > 0,
              layerFrame.height > 0,
              let selectionMask = selection.layerMask(
                layerFrame: layerFrame,
                layerSize: size,
                canvasSize: canvasSize,
                feather: feather
              )
        else { return nil }

        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard var pixels = rgbaPixels(width: width, height: height),
              let mask = selectionMask.alphaMask(width: width, height: height)
        else { return nil }

        let selectedAlpha = mask.alpha
        guard selectedAlpha.contains(where: { $0 > 0 }) else { return nil }
        let sourcePixels = pixels
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let sourceDeltaX = Int((offsetInCanvas.width * CGFloat(width) / layerFrame.width).rounded())
        let sourceDeltaY = Int((offsetInCanvas.height * CGFloat(height) / layerFrame.height).rounded())
        let normalizedOpacity = max(0, min(1, opacity))

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let maskAlpha = CGFloat(selectedAlpha[pixelIndex]) / 255 * normalizedOpacity
                guard maskAlpha > 0 else { continue }

                let sourceX = x + sourceDeltaX
                let sourceY = y + sourceDeltaY
                guard sourceX >= 0,
                      sourceX < width,
                      sourceY >= 0,
                      sourceY < height
                else { continue }

                let offset = y * bytesPerRow + x * bytesPerPixel
                let sourceOffset = sourceY * bytesPerRow + sourceX * bytesPerPixel
                let inverseAlpha = 1 - maskAlpha
                pixels[offset] = blendedByte(original: pixels[offset], replacement: CGFloat(sourcePixels[sourceOffset]), alpha: maskAlpha, inverseAlpha: inverseAlpha)
                pixels[offset + 1] = blendedByte(original: pixels[offset + 1], replacement: CGFloat(sourcePixels[sourceOffset + 1]), alpha: maskAlpha, inverseAlpha: inverseAlpha)
                pixels[offset + 2] = blendedByte(original: pixels[offset + 2], replacement: CGFloat(sourcePixels[sourceOffset + 2]), alpha: maskAlpha, inverseAlpha: inverseAlpha)
                pixels[offset + 3] = blendedByte(original: pixels[offset + 3], replacement: CGFloat(sourcePixels[sourceOffset + 3]), alpha: maskAlpha, inverseAlpha: inverseAlpha)
            }
        }

        return NSImage.rgbaImage(width: width, height: height, pixels: pixels, size: size)
    }

    func cleared(
        selection: ImageEditorSelection,
        layerFrame: CGRect,
        canvasSize: CGSize,
        feather: CGFloat
    ) -> NSImage? {
        guard let selectionMask = selection.layerMask(
            layerFrame: layerFrame,
            layerSize: size,
            canvasSize: canvasSize,
            feather: feather
        ) else { return nil }

        return NSImage.rendered(size: size) { rect in
            draw(in: rect, from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            selectionMask.draw(
                in: rect,
                from: CGRect(origin: .zero, size: selectionMask.size),
                operation: .destinationOut,
                fraction: 1
            )
        }
    }

    private func contentAwareFallbackColor(
        pixels: [UInt8],
        mask: [UInt8],
        width: Int,
        height: Int
    ) -> ContentAwareColor? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var count: CGFloat = 0

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard mask[pixelIndex] == 0,
                      pixels[offset + 3] > 0
                else { continue }
                red += CGFloat(pixels[offset])
                green += CGFloat(pixels[offset + 1])
                blue += CGFloat(pixels[offset + 2])
                alpha += CGFloat(pixels[offset + 3])
                count += 1
            }
        }

        guard count > 0 else { return nil }
        return ContentAwareColor(red: red / count, green: green / count, blue: blue / count, alpha: alpha / count)
    }

    private func contentAwareColor(
        x: Int,
        y: Int,
        pixels: [UInt8],
        mask: [UInt8],
        width: Int,
        height: Int,
        maxRadius: Int,
        fallback: ContentAwareColor
    ) -> ContentAwareColor {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var weightTotal: CGFloat = 0
        var sampleCount = 0

        for radius in 1...maxRadius {
            let minX = max(0, x - radius)
            let maxX = min(width - 1, x + radius)
            let minY = max(0, y - radius)
            let maxY = min(height - 1, y + radius)

            for sampleY in minY...maxY {
                for sampleX in minX...maxX {
                    guard sampleX == minX || sampleX == maxX || sampleY == minY || sampleY == maxY else { continue }
                    let sampleIndex = sampleY * width + sampleX
                    let offset = sampleY * bytesPerRow + sampleX * bytesPerPixel
                    guard mask[sampleIndex] == 0,
                          pixels[offset + 3] > 0
                    else { continue }

                    let dx = CGFloat(sampleX - x)
                    let dy = CGFloat(sampleY - y)
                    let weight = 1 / max(1, dx * dx + dy * dy)
                    red += CGFloat(pixels[offset]) * weight
                    green += CGFloat(pixels[offset + 1]) * weight
                    blue += CGFloat(pixels[offset + 2]) * weight
                    alpha += CGFloat(pixels[offset + 3]) * weight
                    weightTotal += weight
                    sampleCount += 1
                }
            }

            if sampleCount >= 12 {
                break
            }
        }

        guard weightTotal > 0 else { return fallback }
        return ContentAwareColor(red: red / weightTotal, green: green / weightTotal, blue: blue / weightTotal, alpha: alpha / weightTotal)
    }

    private func rgbaPixels(width: Int, height: Int) -> [UInt8]? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
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
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private func blendedByte(original: UInt8, replacement: CGFloat, alpha: CGFloat, inverseAlpha: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, (CGFloat(original) * inverseAlpha + replacement * alpha).rounded())))
    }
}

private struct ContentAwareColor {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
}

private extension NSImage {
    static func rgbaImage(width: Int, height: Int, pixels: [UInt8], size: CGSize) -> NSImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        guard pixels.count == bytesPerRow * height,
              let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
                width: width,
                height: height,
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

        return NSImage(cgImage: output, size: size)
    }
}

private extension ImageEditorSelection {
    func layerMask(layerFrame: CGRect, layerSize: CGSize, canvasSize: CGSize, feather: CGFloat) -> NSImage? {
        guard layerSize.width > 0,
              layerSize.height > 0,
              layerFrame.width > 0,
              layerFrame.height > 0,
              let canvasMask = canvasMask(size: canvasSize, feather: feather)
        else { return nil }

        return NSImage.rendered(size: layerSize) { _ in
            canvasMask.draw(
                in: CGRect(origin: .zero, size: layerSize),
                from: layerFrame,
                operation: .copy,
                fraction: 1
            )
        }
    }

    func layerStroke(
        layerFrame: CGRect,
        layerSize: CGSize,
        canvasSize: CGSize,
        color: NSColor,
        width: CGFloat,
        opacity: CGFloat,
        feather: CGFloat
    ) -> NSImage? {
        guard layerSize.width > 0,
              layerSize.height > 0,
              layerFrame.width > 0,
              layerFrame.height > 0,
              let canvasStroke = canvasStroke(size: canvasSize, color: color, width: width, opacity: opacity, feather: feather)
        else { return nil }

        return NSImage.rendered(size: layerSize) { _ in
            canvasStroke.draw(
                in: CGRect(origin: .zero, size: layerSize),
                from: layerFrame,
                operation: .copy,
                fraction: 1
            )
        }
    }

    func canvasMask(size: CGSize, feather: CGFloat) -> NSImage? {
        if let rasterMask,
           let image = NSImage.selectionMaskImage(rasterMask, inverted: isInverted, targetSize: size) {
            guard feather > 0 else { return image }
            return image.blurred(radius: feather) ?? image
        }

        let hardMask = NSImage.rendered(size: size) { rect in
            let maskPath = self.path()
            if isInverted {
                NSColor.white.setFill()
                rect.fill()
                guard let context = NSGraphicsContext.current?.cgContext else { return }
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setFill()
                maskPath.fill()
                context.restoreGState()
            } else {
                NSColor.white.setFill()
                maskPath.fill()
            }
        }
        guard let hardMask, feather > 0 else { return hardMask }
        return hardMask.blurred(radius: feather) ?? hardMask
    }

    func canvasStroke(size: CGSize, color: NSColor, width: CGFloat, opacity: CGFloat, feather: CGFloat) -> NSImage? {
        let strokeImage = NSImage.rendered(size: size) { _ in
            let strokePath = self.path()
            strokePath.lineJoinStyle = .miter
            strokePath.lineCapStyle = .butt
            strokePath.lineWidth = max(1, width)
            color.withAlphaComponent(opacity).setStroke()
            strokePath.stroke()
        }
        guard let strokeImage, feather > 0 else { return strokeImage }
        return strokeImage.blurred(radius: feather) ?? strokeImage
    }
}
