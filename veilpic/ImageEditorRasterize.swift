//
//  ImageEditorRasterize.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit

@MainActor
extension ImageEditorViewModel {
    var canRasterizeSelectedLayer: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              !layer.isGroup,
              !layer.isAdjustment,
              !layer.isFilter,
              !layer.isClippingMask,
              !document.isEffectivelyLocked(layer)
        else { return false }
        return layer.isText || layer.mask != nil || layer.hasLayerEffects
    }

    func rasterizeSelectedLayer() {
        guard canRasterizeSelectedLayer,
              let index = document.selectedLayerIndex
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let source = document.layers[index]
        pushUndo()
        document.layers[index].name = L10n.format("imageEditor.layer.rasterizedName", source.name)
        document.layers[index].image = source.compositingImage.normalizedBitmapImage()
        document.layers[index].frame = source.compositingFrame
        document.layers[index].mask = nil
        document.layers[index].style = ImageEditorLayerStyle()
        document.layers[index].kind = .pixel
        document.layers[index].isClippingMask = false
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerRasterize"))
        statusText = L10n.text("imageEditor.status.layerRasterized")
    }
}
