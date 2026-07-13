//
//  ImageEditorLayerMerge.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    var mergeDownActionTitleKey: String {
        document.selectedLayer?.isGroup == true
            ? "imageEditor.action.layerMergeGroup"
            : "imageEditor.action.layerMergeDown"
    }

    var canMergeVisibleLayers: Bool {
        mergeVisibleLayerIDs.count > 1
    }

    var canMergeSelectedLayers: Bool {
        hierarchyMergeSelectedPlan != nil
    }

    var canFlattenImage: Bool {
        document.layers.contains { layer in
            document.shouldComposite(layer)
        }
    }

    func mergeVisibleLayers() {
        let sourceIDs = mergeVisibleLayerIDs
        guard sourceIDs.count > 1 else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        let flattenedImage = document.compositedImage
        var mergedLayer = flattenedLayer(
            name: L10n.text("imageEditor.layer.visibleMergedName"),
            image: flattenedImage
        )
        let firstSourceIndex = document.layers.firstIndex { sourceIDs.contains($0.id) } ?? 0
        let sourceIDSet = Set(sourceIDs)
        var mergedWasInserted = false
        var nextLayers: [ImageEditorLayer] = []

        for (index, layer) in document.layers.enumerated() {
            if index == firstSourceIndex {
                nextLayers.append(mergedLayer)
                mergedWasInserted = true
            }
            guard !sourceIDSet.contains(layer.id) else { continue }
            nextLayers.append(layer)
        }

        if !mergedWasInserted {
            nextLayers.append(mergedLayer)
        }

        nextLayers = removingEmptyVisibleGroups(from: nextLayers)
        if let index = nextLayers.firstIndex(where: { $0.id == mergedLayer.id }) {
            mergedLayer = nextLayers[index]
        }
        document.layers = nextLayers
        document.selectedLayerID = mergedLayer.id
        document.selectedLayerIDs = [mergedLayer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMergeVisible"))
        statusText = L10n.text("imageEditor.status.layerMergeVisible")
    }

    func mergeSelectedLayers() {
        guard let sourcePlan = hierarchyMergeSelectedPlan else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let mergedLayer = flattenedLayer(
            name: L10n.text("imageEditor.layer.selectedMergedName"),
            image: document.compositedImage(includingOnly: sourcePlan.sourceLayerIDs)
        )
        let resultPlan = ImageEditorLayerHierarchyMerge.applying(
            sourcePlan,
            mergedLayer: mergedLayer,
            to: document.layers,
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        )
        pushUndo()
        document.layers = resultPlan.layers
        document.selectedLayerID = resultPlan.primarySelectionID
        document.selectedLayerIDs = resultPlan.selectedLayerIDs
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMergeSelected"))
        statusText = L10n.text("imageEditor.status.layerMergeSelected")
    }

    func flattenImage() {
        guard canFlattenImage else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        let flattened = flattenedLayer(
            name: L10n.text("imageEditor.layer.flattenedName"),
            image: document.compositedImage
        )
        document.layers = [flattened]
        document.selectedLayerID = flattened.id
        document.selectedLayerIDs = [flattened.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerFlatten"))
        statusText = L10n.text("imageEditor.status.layerFlattened")
    }

    private var mergeVisibleLayerIDs: [UUID] {
        document.layers
            .filter { layer in document.shouldComposite(layer) }
            .map(\.id)
    }

    var hierarchyMergeDownPlan: ImageEditorLayerMergeSourcePlan? {
        ImageEditorLayerHierarchyMerge.mergeDownPlan(
            layers: document.layers,
            selectedIDs: document.selectedLayerIDs,
            primarySelectionID: document.selectedLayerID,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) },
            isEffectivelyPixelsLocked: { document.isEffectivelyPixelsLocked($0) },
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        )
    }

    var hierarchyMergeSelectedPlan: ImageEditorLayerMergeSourcePlan? {
        ImageEditorLayerHierarchyMerge.mergeSelectedPlan(
            layers: document.layers,
            selectedIDs: document.selectedLayerIDs,
            primarySelectionID: document.selectedLayerID,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) },
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        )
    }

    func applyHierarchyMerge(
        _ sourcePlan: ImageEditorLayerMergeSourcePlan,
        mergedLayer: ImageEditorLayer,
        historyKey: String,
        statusKey: String? = nil
    ) {
        let resultPlan = ImageEditorLayerHierarchyMerge.applying(
            sourcePlan,
            mergedLayer: mergedLayer,
            to: document.layers,
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        )
        pushUndo()
        document.layers = resultPlan.layers
        document.selectedLayerID = resultPlan.primarySelectionID
        document.selectedLayerIDs = resultPlan.selectedLayerIDs
        isEditingLayerMask = false
        appendHistory(L10n.text(historyKey))
        if let statusKey {
            statusText = L10n.text(statusKey)
        }
    }

    func flattenedLayer(name: String, image: NSImage) -> ImageEditorLayer {
        var layer = ImageEditorLayer.blank(name: name, size: document.canvasSize)
        layer.image = image.normalizedBitmapImage()
        layer.frame = CGRect(origin: .zero, size: document.canvasSize)
        layer.opacity = 1
        layer.fillOpacity = 1
        layer.blendMode = .normal
        layer.isVisible = true
        layer.isLocked = false
        layer.mask = nil
        layer.vectorMask = nil
        layer.isVectorMaskEnabled = true
        layer.style = ImageEditorLayerStyle()
        layer.smartFilters = []
        layer.kind = .pixel
        layer.groupID = nil
        layer.isClippingMask = false
        return layer
    }

    private func removingEmptyVisibleGroups(from layers: [ImageEditorLayer]) -> [ImageEditorLayer] {
        layers.filter { layer in
            guard layer.isGroup,
                  layer.isVisible,
                  !layers.contains(where: { $0.groupID == layer.id })
            else { return true }
            return false
        }
    }

}
