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

    private func flattenedLayer(name: String, image: NSImage) -> ImageEditorLayer {
        var layer = ImageEditorLayer.blank(name: name, size: document.canvasSize)
        layer.image = image.normalizedBitmapImage()
        layer.frame = CGRect(origin: .zero, size: document.canvasSize)
        layer.opacity = 1
        layer.blendMode = .normal
        layer.isVisible = true
        layer.isLocked = false
        layer.mask = nil
        layer.style = ImageEditorLayerStyle()
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
