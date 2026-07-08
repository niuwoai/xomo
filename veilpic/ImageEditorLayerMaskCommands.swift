//
//  ImageEditorLayerMaskCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    var canCreateLayerMaskFromSelection: Bool {
        guard selectedLayerCount == 1,
              hasSelection,
              let layer = document.selectedLayer
        else { return false }
        return !layer.isGroup && !document.isEffectivelyLocked(layer) && layer.mask == nil
    }

    var canApplyLayerMask: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && !document.isEffectivelyLocked(layer)
            && layer.mask != nil
    }

    var canInvertLayerMask: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return !layer.isGroup && !document.isEffectivelyLocked(layer) && layer.mask != nil
    }

    func addLayerMaskFromSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard canCreateLayerMaskFromSelection,
              let index = document.selectedLayerIndex,
              let mask = selectionMaskForLayer(selection, layer: document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].mask = mask
        isEditingLayerMask = true
        appendHistory(L10n.text("imageEditor.history.layerMaskFromSelection"))
        statusText = L10n.text("imageEditor.status.layerMaskFromSelection")
    }

    func applyLayerMask() {
        guard canApplyLayerMask,
              let index = document.selectedLayerIndex,
              let mask = document.layers[index].mask,
              let output = document.layers[index].contentImage.applyingAlphaMask(mask)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].image = output.normalizedBitmapImage()
        document.layers[index].mask = nil
        if document.layers[index].isText {
            document.layers[index].kind = .pixel
        }
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMaskApply"))
        statusText = L10n.text("imageEditor.status.layerMaskApplied")
    }

    func invertLayerMask() {
        guard canInvertLayerMask,
              let index = document.selectedLayerIndex,
              let mask = document.layers[index].mask,
              let inverted = mask.invertedAlphaMask()
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].mask = inverted
        isEditingLayerMask = true
        appendHistory(L10n.text("imageEditor.history.layerMaskInvert"))
        statusText = L10n.text("imageEditor.status.layerMaskInverted")
    }

    private func selectionMaskForLayer(_ selection: ImageEditorSelection, layer: ImageEditorLayer) -> NSImage? {
        guard layer.image.size.width > 0,
              layer.image.size.height > 0,
              layer.frame.width > 0,
              layer.frame.height > 0,
              let canvasMask = canvasSelectionMask(for: selection)
        else { return nil }

        return NSImage.rendered(size: layer.image.size) { _ in
            canvasMask.draw(
                in: CGRect(origin: .zero, size: layer.image.size),
                from: layer.frame,
                operation: .copy,
                fraction: 1
            )
        }
    }

    private func canvasSelectionMask(for selection: ImageEditorSelection) -> NSImage? {
        if let rasterMask = selection.rasterMask,
           let image = NSImage.selectionMaskImage(
            rasterMask,
            inverted: selection.isInverted,
            targetSize: document.canvasSize
           ) {
            guard feather > 0 else { return image }
            return image.blurred(radius: feather) ?? image
        }

        let hardMask = NSImage.rendered(size: document.canvasSize) { rect in
            let path = selection.path()
            if selection.isInverted {
                NSColor.white.setFill()
                rect.fill()
                guard let context = NSGraphicsContext.current?.cgContext else { return }
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setFill()
                path.fill()
                context.restoreGState()
            } else {
                NSColor.white.setFill()
                path.fill()
            }
        }
        guard let hardMask, feather > 0 else { return hardMask }
        return hardMask.blurred(radius: feather) ?? hardMask
    }
}

extension NSImage {
    func applyingAlphaMask(_ mask: NSImage) -> NSImage? {
        NSImage.rendered(size: size) { _ in
            draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
    }

    func invertedAlphaMask() -> NSImage? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
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

        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                alpha[y * width + x] = UInt8.max - pixels[offset + 3]
            }
        }
        return NSImage.alphaMaskImage(width: width, height: height, alpha: alpha)
    }
}
