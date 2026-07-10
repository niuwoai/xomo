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
        !rasterizableSelectedLayerIndices().isEmpty
    }

    func rasterizeSelectedLayer() {
        let indices = rasterizableSelectedLayerIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in indices {
            rasterizeLayer(at: index)
        }
        isEditingLayerMask = false

        if indices.count == 1 {
            appendHistory(L10n.text("imageEditor.history.layerRasterize"))
            statusText = L10n.text("imageEditor.status.layerRasterized")
        } else {
            appendHistory(L10n.text("imageEditor.history.layerRasterizeSelected"))
            statusText = L10n.format("imageEditor.status.layerRasterizedSelected", indices.count)
        }
    }

    private func rasterizableSelectedLayerIndices() -> [Int] {
        document.layers.indices.filter { index in
            document.selectedLayerIDs.contains(document.layers[index].id)
                && isLayerRasterizable(document.layers[index])
        }
    }

    private func isLayerRasterizable(_ layer: ImageEditorLayer) -> Bool {
        guard !layer.isGroup,
              !layer.isAdjustment,
              !layer.isFilter,
              !layer.isClippingMask,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }

        return layer.isText
            || layer.isShape
            || layer.isSmartObject
            || layer.hasSmartFilters
            || layer.mask != nil
            || layer.vectorMask != nil
            || layer.hasLayerEffects
    }

    private func rasterizeLayer(at index: Int) {
        let source = document.layers[index]
        document.layers[index].name = L10n.format("imageEditor.layer.rasterizedName", source.name)
        document.layers[index].image = source
            .renderedCompositingImage(globalLightAngle: document.globalLightAngle)
            .normalizedBitmapImage()
        document.layers[index].frame = source.renderedCompositingFrame(globalLightAngle: document.globalLightAngle)
        document.layers[index].mask = nil
        document.layers[index].vectorMask = nil
        document.layers[index].isVectorMaskEnabled = true
        document.layers[index].style = ImageEditorLayerStyle()
        document.layers[index].smartFilters = []
        document.layers[index].fillOpacity = 1
        document.layers[index].kind = .pixel
        document.layers[index].isClippingMask = false
    }
}
