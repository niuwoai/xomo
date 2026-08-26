//
//  ImageEditorLayerVisibilityContext.swift
//  veilpic
//
//  Created by Codex on 2026/8/27.
//

import Foundation

extension ImageEditorViewModel {
    func canSetLayersVisibilityFromContext(
        _ clickedLayerID: UUID,
        isVisible: Bool
    ) -> Bool {
        let contextIDs = layerContextSelectionIDs(for: clickedLayerID)
        guard !contextIDs.isEmpty else { return false }
        return document.layers.contains { layer in
            contextIDs.contains(layer.id) && layer.isVisible != isVisible
        }
    }

    @discardableResult
    func setLayersVisibilityFromContext(
        _ clickedLayerID: UUID,
        isVisible: Bool
    ) -> Bool {
        guard canSetLayersVisibilityFromContext(
            clickedLayerID,
            isVisible: isVisible
        ) else { return false }
        prepareLayerContextSelection(for: clickedLayerID)
        if isVisible {
            showSelectedLayers()
        } else {
            hideSelectedLayers()
        }
        return true
    }
}
