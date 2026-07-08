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
        guard selectedLayerCount == 1,
              hasSelection,
              let layer = document.selectedLayer
        else { return false }
        return !isEditingLayerMask
            && !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && !layer.isText
            && !document.isEffectivelyPixelsLocked(layer)
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

    func fillSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard canEditSelectionPixels,
              let index = document.selectedLayerIndex,
              let output = document.layers[index].image.filled(
                selection: selection,
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                color: foregroundColor,
                opacity: opacity,
                feather: feather
              )
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].image = output.normalizedBitmapImage()
        appendHistory(L10n.text("imageEditor.history.selectionFill"))
        statusText = L10n.text("imageEditor.status.selectionFilled")
    }

    func strokeSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard canEditSelectionPixels,
              let index = document.selectedLayerIndex,
              let output = document.layers[index].image.stroked(
                selection: selection,
                layerFrame: document.layers[index].frame,
                canvasSize: document.canvasSize,
                color: foregroundColor,
                width: max(1, brushSize),
                opacity: opacity,
                feather: feather
              )
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].image = output.normalizedBitmapImage()
        appendHistory(L10n.text("imageEditor.history.selectionStroke"))
        statusText = L10n.text("imageEditor.status.selectionStroked")
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
        guard canEditSelectionPixels,
              let index = document.selectedLayerIndex,
              let output = document.layers[index].image.cleared(
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
        document.layers[index].image = output.normalizedBitmapImage()
        appendHistory(L10n.text("imageEditor.history.selectionClearPixels"))
        statusText = L10n.text("imageEditor.status.selectionPixelsCleared")
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
