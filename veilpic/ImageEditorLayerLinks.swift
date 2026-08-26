//
//  ImageEditorLayerLinks.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import Foundation

@MainActor
extension ImageEditorViewModel {
    var canLinkSelectedLayers: Bool {
        linkSelectionNeedsChange(selectedLayerIDs)
    }

    var canUnlinkSelectedLayers: Bool {
        selectedLayerIDs.contains(where: isLayerLinked)
    }

    var canSelectLinkedLayers: Bool {
        selectedLayerIDs.contains(where: isLayerLinked)
    }

    var canUnlinkAllLayers: Bool {
        document.layers.contains { isLayerLinked($0.id) }
    }

    var selectedLayerIDs: Set<UUID> {
        document.selectedLayerIDs
    }

    func canLinkLayersFromContext(_ clickedLayerID: UUID) -> Bool {
        linkSelectionNeedsChange(layerContextSelectionIDs(for: clickedLayerID))
    }

    func canSelectLinkedLayersFromContext(_ clickedLayerID: UUID) -> Bool {
        isLayerLinked(clickedLayerID)
    }

    func canUnlinkLayersFromContext(_ clickedLayerID: UUID) -> Bool {
        layerContextSelectionIDs(for: clickedLayerID).contains(where: isLayerLinked)
    }

    func isLayerLinked(_ id: UUID) -> Bool {
        guard let layer = layer(with: id) else { return false }
        let existingIDs = Set(document.layers.map(\.id))
        return !layer.linkedLayerIDs
            .intersection(existingIDs)
            .subtracting([id])
            .isEmpty
    }

    func linkSelectedLayers() {
        _ = linkLayers(selectedIDs: selectedLayerIDs)
    }

    @discardableResult
    func linkLayersFromContext(_ clickedLayerID: UUID) -> Bool {
        let contextIDs = layerContextSelectionIDs(for: clickedLayerID)
        guard !contextIDs.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }
        prepareLayerContextSelection(for: clickedLayerID)
        return linkLayers(selectedIDs: contextIDs)
    }

    @discardableResult
    private func linkLayers(selectedIDs requestedIDs: Set<UUID>) -> Bool {
        let selectedIDs = requestedIDs.intersection(Set(document.layers.map(\.id)))
        guard selectedIDs.count >= 2 else {
            statusText = L10n.text("imageEditor.status.layerLinkNeedsSelection")
            return false
        }
        guard linkSelectionNeedsChange(selectedIDs) else {
            statusText = L10n.text("imageEditor.status.layerAlreadyLinked")
            return false
        }

        pushUndo()
        for index in document.layers.indices where selectedIDs.contains(document.layers[index].id) {
            let id = document.layers[index].id
            document.layers[index].linkedLayerIDs.formUnion(selectedIDs.subtracting([id]))
        }
        normalizeLayerLinks()
        appendHistory(L10n.text("imageEditor.history.layerLink"))
        return true
    }

    func unlinkSelectedLayers() {
        _ = unlinkLayers(selectedIDs: selectedLayerIDs)
    }

    @discardableResult
    func unlinkLayersFromContext(_ clickedLayerID: UUID) -> Bool {
        let contextIDs = layerContextSelectionIDs(for: clickedLayerID)
        guard !contextIDs.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }
        prepareLayerContextSelection(for: clickedLayerID)
        return unlinkLayers(selectedIDs: contextIDs)
    }

    @discardableResult
    private func unlinkLayers(selectedIDs requestedIDs: Set<UUID>) -> Bool {
        let selectedIDs = requestedIDs.intersection(Set(document.layers.map(\.id)))
        guard !selectedIDs.isEmpty else { return false }
        guard selectedIDs.contains(where: isLayerLinked) else {
            statusText = L10n.text("imageEditor.status.layerNoLinks")
            return false
        }

        pushUndo()
        for index in document.layers.indices {
            if selectedIDs.contains(document.layers[index].id) {
                document.layers[index].linkedLayerIDs.removeAll()
            } else {
                document.layers[index].linkedLayerIDs.subtract(selectedIDs)
            }
        }
        normalizeLayerLinks()
        appendHistory(L10n.text("imageEditor.history.layerUnlink"))
        return true
    }

    func unlinkAllLayers() {
        guard canUnlinkAllLayers else {
            statusText = L10n.text("imageEditor.status.layerNoLinks")
            return
        }

        pushUndo()
        for index in document.layers.indices {
            document.layers[index].linkedLayerIDs.removeAll()
        }
        appendHistory(L10n.text("imageEditor.history.layerUnlinkAll"))
    }

    func selectLinkedLayers() {
        let selectedIDs = selectedLayerIDs.intersection(Set(document.layers.map(\.id)))
        _ = selectLinkedLayers(startingFrom: selectedIDs)
    }

    @discardableResult
    func selectLinkedLayersFromContext(_ clickedLayerID: UUID) -> Bool {
        guard document.layers.contains(where: { $0.id == clickedLayerID }) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }
        return selectLinkedLayers(startingFrom: [clickedLayerID])
    }

    @discardableResult
    private func selectLinkedLayers(startingFrom selectedIDs: Set<UUID>) -> Bool {
        let linkedIDs = linkedTransformLayerIDs(startingFrom: selectedIDs)
        guard linkedIDs.count > selectedIDs.count else {
            statusText = L10n.text("imageEditor.status.layerNoLinks")
            return false
        }

        document.selectedLayerIDs = linkedIDs
        document.selectedLayerID = document.layers.reversed().first { linkedIDs.contains($0.id) }?.id
        isEditingLayerMask = false
        updateStatus()
        return true
    }

    func linkedTransformLayerIDs(startingFrom baseIDs: Set<UUID>) -> Set<UUID> {
        let existingIDs = Set(document.layers.map(\.id))
        var visited = Set<UUID>()
        var queue = Array(baseIDs.intersection(existingIDs))

        while let id = queue.popLast() {
            guard !visited.contains(id) else { continue }
            visited.insert(id)
            guard let layer = layer(with: id) else { continue }
            for linkedID in layer.linkedLayerIDs where existingIDs.contains(linkedID) && !visited.contains(linkedID) {
                queue.append(linkedID)
            }
        }

        return visited
    }

    private func layer(with id: UUID) -> ImageEditorLayer? {
        document.layers.first { $0.id == id }
    }

    func normalizeLayerLinks() {
        let existingIDs = Set(document.layers.map(\.id))
        for index in document.layers.indices {
            let id = document.layers[index].id
            document.layers[index].linkedLayerIDs = document.layers[index].linkedLayerIDs
                .intersection(existingIDs)
                .subtracting([id])
        }

        for index in document.layers.indices {
            let id = document.layers[index].id
            let linkedIDs = document.layers[index].linkedLayerIDs
            for linkedID in linkedIDs {
                guard let linkedIndex = document.layers.firstIndex(where: { $0.id == linkedID }) else { continue }
                document.layers[linkedIndex].linkedLayerIDs.insert(id)
            }
        }
    }

    private func linkSelectionNeedsChange(_ requestedIDs: Set<UUID>) -> Bool {
        let existingIDs = Set(document.layers.map(\.id))
        let selectedIDs = requestedIDs.intersection(existingIDs)
        guard selectedIDs.count >= 2 else { return false }
        return selectedIDs.contains { id in
            guard let layer = layer(with: id) else { return false }
            return !selectedIDs.subtracting([id]).isSubset(of: layer.linkedLayerIDs)
        }
    }
}
