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
        selectedLayerIDs.intersection(Set(document.layers.map(\.id))).count >= 2
    }

    var canUnlinkSelectedLayers: Bool {
        selectedLayerIDs.contains(where: isLayerLinked)
    }

    var selectedLayerIDs: Set<UUID> {
        document.selectedLayerIDs
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
        let selectedIDs = selectedLayerIDs.intersection(Set(document.layers.map(\.id)))
        guard selectedIDs.count >= 2 else {
            statusText = L10n.text("imageEditor.status.layerLinkNeedsSelection")
            return
        }

        pushUndo()
        for index in document.layers.indices where selectedIDs.contains(document.layers[index].id) {
            let id = document.layers[index].id
            document.layers[index].linkedLayerIDs.formUnion(selectedIDs.subtracting([id]))
        }
        normalizeLayerLinks()
        appendHistory(L10n.text("imageEditor.history.layerLink"))
    }

    func unlinkSelectedLayers() {
        let selectedIDs = selectedLayerIDs.intersection(Set(document.layers.map(\.id)))
        guard !selectedIDs.isEmpty else { return }
        guard selectedIDs.contains(where: isLayerLinked) else {
            statusText = L10n.text("imageEditor.status.layerNoLinks")
            return
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
}
