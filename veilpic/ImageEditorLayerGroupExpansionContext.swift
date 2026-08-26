//
//  ImageEditorLayerGroupExpansionContext.swift
//  veilpic
//
//  Created by Codex on 2026/8/27.
//

import Foundation

extension ImageEditorViewModel {
    func canSetLayerGroupsExpansionFromContext(
        _ clickedLayerID: UUID,
        expanded: Bool
    ) -> Bool {
        let contextIDs = layerContextSelectionIDs(for: clickedLayerID)
        let branchIDs = layerGroupBranchIDs(for: contextIDs)
        return document.layers.contains { layer in
            branchIDs.contains(layer.id)
                && layer.isGroup
                && layer.isGroupExpanded != expanded
        }
    }

    @discardableResult
    func setLayerGroupsExpansionFromContext(
        _ clickedLayerID: UUID,
        expanded: Bool
    ) -> Bool {
        guard canSetLayerGroupsExpansionFromContext(
            clickedLayerID,
            expanded: expanded
        ) else { return false }
        prepareLayerContextSelection(for: clickedLayerID)
        if expanded {
            expandSelectedLayerGroups()
        } else {
            collapseSelectedLayerGroups()
        }
        return true
    }
}
