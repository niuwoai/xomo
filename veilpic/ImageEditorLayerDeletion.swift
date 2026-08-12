//
//  ImageEditorLayerDeletion.swift
//  veilpic
//
//  Created by Codex on 2026/7/13.
//

import Foundation

struct ImageEditorLayerDeletionPlan {
    var layers: [ImageEditorLayer]
    var selectedLayerIDs: Set<UUID>
    var primarySelectionID: UUID?
}

enum ImageEditorLayerHierarchyDeletion {
    static func deletableLayerIDs(
        in layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        isEffectivelyLocked: (ImageEditorLayer) -> Bool
    ) -> Set<UUID> {
        let rootIDs = deletableRootIDs(
            in: layers,
            selectedIDs: selectedIDs,
            isEffectivelyLocked: isEffectivelyLocked
        )
        return rootIDs.reduce(into: rootIDs) { result, rootID in
            guard layers.first(where: { $0.id == rootID })?.isGroup == true else { return }
            result.formUnion(descendantIDs(of: rootID, in: layers))
        }
    }

    static func deletionPlan(
        layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?,
        visibleLayerIDs: [UUID],
        isEffectivelyLocked: (ImageEditorLayer) -> Bool,
        isEffectivelyVisible: (ImageEditorLayer) -> Bool
    ) -> ImageEditorLayerDeletionPlan? {
        let deletionIDs = deletableLayerIDs(
            in: layers,
            selectedIDs: selectedIDs,
            isEffectivelyLocked: isEffectivelyLocked
        )
        guard !deletionIDs.isEmpty, layers.count > deletionIDs.count else { return nil }

        let clippingBaseIDs = clippingBaseIDs(
            in: layers,
            isEffectivelyVisible: isEffectivelyVisible
        )
        var nextLayers = layers.filter { !deletionIDs.contains($0.id) }
        clearClippingMasksWhoseBaseWasDeleted(
            in: &nextLayers,
            deletionIDs: deletionIDs,
            clippingBaseIDs: clippingBaseIDs
        )
        normalizeLinks(in: &nextLayers)

        let selection = selectionAfterDeletion(
            remainingLayers: nextLayers,
            selectedIDs: selectedIDs,
            primarySelectionID: primarySelectionID,
            deletionIDs: deletionIDs,
            visibleLayerIDs: visibleLayerIDs
        )
        return ImageEditorLayerDeletionPlan(
            layers: nextLayers,
            selectedLayerIDs: selection.ids,
            primarySelectionID: selection.primaryID
        )
    }

    private static func deletableRootIDs(
        in layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        isEffectivelyLocked: (ImageEditorLayer) -> Bool
    ) -> Set<UUID> {
        let existingSelectedIDs = selectedIDs.intersection(Set(layers.map(\.id)))
        let editableSelectedGroupIDs = Set(layers.compactMap { layer -> UUID? in
            guard existingSelectedIDs.contains(layer.id),
                  layer.isGroup,
                  !isEffectivelyLocked(layer)
            else { return nil }
            return layer.id
        })
        return Set(layers.compactMap { layer -> UUID? in
            guard existingSelectedIDs.contains(layer.id),
                  !isEffectivelyLocked(layer),
                  !hasAncestor(layer, in: editableSelectedGroupIDs, layers: layers)
            else { return nil }
            return layer.id
        })
    }

    private static func hasAncestor(
        _ layer: ImageEditorLayer,
        in candidateIDs: Set<UUID>,
        layers: [ImageEditorLayer]
    ) -> Bool {
        var parentID = layer.groupID
        var visitedIDs = Set<UUID>()
        while let currentID = parentID, visitedIDs.insert(currentID).inserted {
            if candidateIDs.contains(currentID) { return true }
            guard let parent = layers.first(where: { $0.id == currentID && $0.isGroup }) else {
                return false
            }
            parentID = parent.groupID
        }
        return false
    }

    private static func descendantIDs(
        of groupID: UUID,
        in layers: [ImageEditorLayer]
    ) -> Set<UUID> {
        var result = Set<UUID>()
        var pendingGroupIDs = [groupID]
        while let currentGroupID = pendingGroupIDs.popLast() {
            for layer in layers where layer.groupID == currentGroupID && !result.contains(layer.id) {
                result.insert(layer.id)
                if layer.isGroup {
                    pendingGroupIDs.append(layer.id)
                }
            }
        }
        return result
    }

    private static func clippingBaseIDs(
        in layers: [ImageEditorLayer],
        isEffectivelyVisible _: (ImageEditorLayer) -> Bool
    ) -> [UUID: UUID] {
        var result: [UUID: UUID] = [:]
        for index in layers.indices where layers[index].isClippingMask {
            let layer = layers[index]
            guard let baseIndex = layers[..<index].indices.reversed().first(where: { candidateIndex in
                let candidate = layers[candidateIndex]
                return !candidate.isGroup
                    && !candidate.isAdjustment
                    && !candidate.isFilter
                    && !candidate.isClippingMask
                    && candidate.groupID == layer.groupID
            }) else { continue }
            result[layer.id] = layers[baseIndex].id
        }
        return result
    }

    private static func clearClippingMasksWhoseBaseWasDeleted(
        in layers: inout [ImageEditorLayer],
        deletionIDs: Set<UUID>,
        clippingBaseIDs: [UUID: UUID]
    ) {
        for index in layers.indices where layers[index].isClippingMask {
            guard let originalBaseID = clippingBaseIDs[layers[index].id],
                  deletionIDs.contains(originalBaseID)
            else { continue }
            layers[index].isClippingMask = false
        }
    }

    private static func normalizeLinks(in layers: inout [ImageEditorLayer]) {
        let existingIDs = Set(layers.map(\.id))
        for index in layers.indices {
            layers[index].linkedLayerIDs = layers[index].linkedLayerIDs
                .intersection(existingIDs)
                .subtracting([layers[index].id])
        }
        let indexByID = Dictionary(uniqueKeysWithValues: layers.indices.map { (layers[$0].id, $0) })
        for index in layers.indices {
            let sourceID = layers[index].id
            for linkedID in layers[index].linkedLayerIDs {
                guard let linkedIndex = indexByID[linkedID] else { continue }
                layers[linkedIndex].linkedLayerIDs.insert(sourceID)
            }
        }
    }

    private struct SelectionResult {
        var ids: Set<UUID>
        var primaryID: UUID?
    }

    private static func selectionAfterDeletion(
        remainingLayers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?,
        deletionIDs: Set<UUID>,
        visibleLayerIDs: [UUID]
    ) -> SelectionResult {
        let remainingIDs = Set(remainingLayers.map(\.id))
        let visibleRemainingIDs = visibleLayerIDs.filter(remainingIDs.contains)
        let visibleRemainingIDSet = Set(visibleRemainingIDs)
        let survivingSelection = selectedIDs
            .intersection(remainingIDs)
            .intersection(visibleRemainingIDSet)
        if !survivingSelection.isEmpty {
            let primaryID = primarySelectionID.flatMap { id in
                survivingSelection.contains(id) ? id : nil
            } ?? visibleRemainingIDs.first(where: survivingSelection.contains)
            return SelectionResult(ids: survivingSelection, primaryID: primaryID)
        }

        let fallbackID = visibleFallbackID(
            primarySelectionID: primarySelectionID,
            deletionIDs: deletionIDs,
            visibleLayerIDs: visibleLayerIDs,
            remainingIDs: remainingIDs
        ) ?? remainingLayers.last?.id
        return SelectionResult(
            ids: fallbackID.map { Set([$0]) } ?? [],
            primaryID: fallbackID
        )
    }

    private static func visibleFallbackID(
        primarySelectionID: UUID?,
        deletionIDs: Set<UUID>,
        visibleLayerIDs: [UUID],
        remainingIDs: Set<UUID>
    ) -> UUID? {
        let anchorIndex = primarySelectionID.flatMap(visibleLayerIDs.firstIndex)
            ?? visibleLayerIDs.indices.last(where: { deletionIDs.contains(visibleLayerIDs[$0]) })
        guard let anchorIndex else {
            return visibleLayerIDs.first(where: remainingIDs.contains)
        }

        let belowStart = visibleLayerIDs.index(after: anchorIndex)
        if belowStart < visibleLayerIDs.endIndex,
           let belowID = visibleLayerIDs[belowStart...].first(where: remainingIDs.contains) {
            return belowID
        }
        if anchorIndex > visibleLayerIDs.startIndex {
            return visibleLayerIDs[..<anchorIndex].reversed().first(where: remainingIDs.contains)
        }
        return nil
    }
}
