//
//  ImageEditorLayerVisibilityContext.swift
//  veilpic
//
//  Created by Codex on 2026/8/27.
//

import Foundation

extension ImageEditorViewModel {
    func canIsolateLayersFromContext(_ clickedLayerID: UUID) -> Bool {
        let contextIDs = layerContextSelectionIDs(for: clickedLayerID)
        let visibleIDs = isolatedLayerVisibilityIDs(for: contextIDs)
        guard !visibleIDs.isEmpty else { return false }
        return document.layers.contains { layer in
            layer.isVisible != visibleIDs.contains(layer.id)
        }
    }

    func canShowAllLayersFromContext(_ clickedLayerID: UUID) -> Bool {
        !layerContextSelectionIDs(for: clickedLayerID).isEmpty && canShowAllLayers
    }

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

    @discardableResult
    func isolateLayersFromContext(_ clickedLayerID: UUID) -> Bool {
        guard canIsolateLayersFromContext(clickedLayerID) else { return false }
        prepareLayerContextSelection(for: clickedLayerID)
        isolateSelectedLayers()
        return true
    }

    @discardableResult
    func showAllLayersFromContext(_ clickedLayerID: UUID) -> Bool {
        guard canShowAllLayersFromContext(clickedLayerID) else { return false }
        showAllLayers()
        return true
    }
}
