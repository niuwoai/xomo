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
    var canMergeVisibleLayers: Bool {
        mergeVisibleLayerIDs.count > 1
    }

    var canMergeSelectedLayers: Bool {
        let sourceIDs = selectedMergeLayerIDs
        guard !sourceIDs.isEmpty else { return false }
        let selectedRootCount = document.selectedLayerIDs.count
        let renderableCount = document.layers.filter { layer in
            sourceIDs.contains(layer.id) && document.shouldComposite(layer)
        }.count
        guard selectedRootCount > 1 || renderableCount > 1 else { return false }
        guard renderableCount > 0 else { return false }
        return document.layers
            .filter { sourceIDs.contains($0.id) }
            .allSatisfy { !document.isEffectivelyLocked($0) }
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
        let sourceIDs = selectedMergeLayerIDs
        guard canMergeSelectedLayers,
              let insertionIndex = selectedMergeInsertionIndex(fallbackSourceIDs: sourceIDs)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        var mergedLayer = flattenedLayer(
            name: L10n.text("imageEditor.layer.selectedMergedName"),
            image: document.compositedImage(includingOnly: sourceIDs)
        )
        mergedLayer.groupID = selectedMergeParentGroupID(removing: sourceIDs)

        var mergedWasInserted = false
        var nextLayers: [ImageEditorLayer] = []
        for (index, layer) in document.layers.enumerated() {
            if index == insertionIndex {
                nextLayers.append(mergedLayer)
                mergedWasInserted = true
            }
            guard !sourceIDs.contains(layer.id) else { continue }
            nextLayers.append(layer)
        }

        if !mergedWasInserted {
            nextLayers.append(mergedLayer)
        }

        document.layers = nextLayers
        normalizeClippingMasksAfterLayerMerge()
        document.selectedLayerID = mergedLayer.id
        document.selectedLayerIDs = [mergedLayer.id]
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

    private var selectedMergeLayerIDs: Set<UUID> {
        var sourceIDs = document.selectedLayerIDs
        let selectedGroupIDs = document.layers
            .filter { sourceIDs.contains($0.id) && $0.isGroup }
            .map(\.id)

        for groupID in selectedGroupIDs {
            for layer in document.layers where document.ancestorGroups(for: layer).contains(where: { $0.id == groupID }) {
                sourceIDs.insert(layer.id)
            }
        }

        return sourceIDs
    }

    private func selectedMergeInsertionIndex(fallbackSourceIDs sourceIDs: Set<UUID>) -> Int? {
        document.layers.firstIndex { document.selectedLayerIDs.contains($0.id) }
            ?? document.layers.firstIndex { sourceIDs.contains($0.id) }
    }

    private func selectedMergeParentGroupID(removing sourceIDs: Set<UUID>) -> UUID? {
        let selectedRoots = document.layers.filter { document.selectedLayerIDs.contains($0.id) }
        let parentIDs = Set(selectedRoots.map(\.groupID))
        guard parentIDs.count == 1,
              let parentID = parentIDs.first ?? nil,
              !sourceIDs.contains(parentID)
        else { return nil }
        return parentID
    }

    private func flattenedLayer(name: String, image: NSImage) -> ImageEditorLayer {
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

    private func normalizeClippingMasksAfterLayerMerge() {
        for index in document.layers.indices where document.layers[index].isClippingMask {
            if document.clippingBaseIndex(forLayerAt: index) == nil {
                document.layers[index].isClippingMask = false
            }
        }
    }
}
