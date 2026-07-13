//
//  ImageEditorLayerGrouping.swift
//  veilpic
//
//  Created by Codex on 2026/7/13.
//

import Foundation

struct ImageEditorLayerGroupingPlan {
    var layers: [ImageEditorLayer]
    var selectedLayerIDs: Set<UUID>
    var primarySelectionID: UUID?
}

enum ImageEditorLayerHierarchyGrouping {
    static func groupableRootIDs(
        in layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        isEffectivelyLocked: (ImageEditorLayer) -> Bool
    ) -> Set<UUID>? {
        let existingSelectedIDs = selectedIDs.intersection(Set(layers.map(\.id)))
        let rootIDs = Set(layers.compactMap { layer -> UUID? in
            guard existingSelectedIDs.contains(layer.id),
                  !isEffectivelyLocked(layer)
            else { return nil }
            return layer.id
        })
        guard !rootIDs.isEmpty else { return nil }

        var parentIDs = Set<UUID?>()
        for layer in layers where rootIDs.contains(layer.id) {
            parentIDs.insert(effectiveGroupingParentID(
                for: layer,
                selectedEditableIDs: rootIDs,
                in: layers
            ))
        }
        guard parentIDs.count == 1 else { return nil }
        return rootIDs
    }

    static func groupingPlan(
        layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        group: ImageEditorLayer,
        isEffectivelyLocked: (ImageEditorLayer) -> Bool
    ) -> ImageEditorLayerGroupingPlan? {
        guard let rootIDs = groupableRootIDs(
            in: layers,
            selectedIDs: selectedIDs,
            isEffectivelyLocked: isEffectivelyLocked
        ) else { return nil }

        let movingBlockIDs = rootIDs.reduce(into: rootIDs) { result, rootID in
            guard layers.first(where: { $0.id == rootID })?.isGroup == true else { return }
            result.formUnion(descendantIDs(of: rootID, in: layers))
        }
        guard let topRootIndex = layers.indices.last(where: { rootIDs.contains(layers[$0].id) }) else {
            return nil
        }

        var movingLayers = layers.filter { movingBlockIDs.contains($0.id) }
        for index in movingLayers.indices where rootIDs.contains(movingLayers[index].id) {
            movingLayers[index].groupID = group.id
        }

        var newGroup = group
        newGroup.groupID = layers.first(where: { rootIDs.contains($0.id) }).flatMap { layer in
            effectiveGroupingParentID(
                for: layer,
                selectedEditableIDs: rootIDs,
                in: layers
            )
        }
        newGroup.isGroupExpanded = true

        let insertionIndex = layers.indices.filter { index in
            index < topRootIndex && !movingBlockIDs.contains(layers[index].id)
        }.count
        var remainingLayers = layers.filter { !movingBlockIDs.contains($0.id) }
        remainingLayers.insert(contentsOf: movingLayers + [newGroup], at: insertionIndex)

        var nextSelectionIDs = selectedIDs.subtracting(rootIDs)
        nextSelectionIDs.formIntersection(Set(remainingLayers.map(\.id)))
        nextSelectionIDs.insert(newGroup.id)
        return ImageEditorLayerGroupingPlan(
            layers: remainingLayers,
            selectedLayerIDs: nextSelectionIDs,
            primarySelectionID: newGroup.id
        )
    }

    static func ungroupableGroupIDs(
        in layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        isEffectivelyLocked: (ImageEditorLayer) -> Bool
    ) -> Set<UUID> {
        Set(layers.compactMap { layer -> UUID? in
            guard selectedIDs.contains(layer.id), layer.isGroup, !isEffectivelyLocked(layer) else {
                return nil
            }
            return layer.id
        })
    }

    static func ungroupingPlan(
        layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?,
        isEffectivelyLocked: (ImageEditorLayer) -> Bool
    ) -> ImageEditorLayerGroupingPlan? {
        let groupIDs = ungroupableGroupIDs(
            in: layers,
            selectedIDs: selectedIDs,
            isEffectivelyLocked: isEffectivelyLocked
        )
        guard !groupIDs.isEmpty else { return nil }

        let memberIDs = Set(layers.compactMap { layer -> UUID? in
            layer.groupID.map(groupIDs.contains) == true ? layer.id : nil
        })
        let replacementParents = groupReplacementParents(forRemoving: groupIDs, in: layers)
        var nextLayers = layers
        for index in nextLayers.indices {
            guard let groupID = nextLayers[index].groupID, groupIDs.contains(groupID) else { continue }
            nextLayers[index].groupID = replacementParents[groupID] ?? nil
        }
        nextLayers.removeAll { groupIDs.contains($0.id) }

        let remainingIDs = Set(nextLayers.map(\.id))
        var nextSelectionIDs = selectedIDs.intersection(remainingIDs)
        nextSelectionIDs.formUnion(memberIDs.intersection(remainingIDs))
        let nextPrimarySelectionID = primarySelectionID.flatMap { id in
            nextSelectionIDs.contains(id) ? id : nil
        } ?? nextLayers.reversed().first(where: { nextSelectionIDs.contains($0.id) })?.id

        return ImageEditorLayerGroupingPlan(
            layers: nextLayers,
            selectedLayerIDs: nextSelectionIDs,
            primarySelectionID: nextPrimarySelectionID
        )
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

    private static func effectiveGroupingParentID(
        for layer: ImageEditorLayer,
        selectedEditableIDs: Set<UUID>,
        in layers: [ImageEditorLayer]
    ) -> UUID? {
        var parentID = layer.groupID
        var visitedIDs = Set<UUID>()
        while let candidateID = parentID,
              selectedEditableIDs.contains(candidateID),
              visitedIDs.insert(candidateID).inserted,
              let candidate = layers.first(where: { $0.id == candidateID && $0.isGroup }) {
            parentID = candidate.groupID
        }
        return parentID
    }

    private static func groupReplacementParents(
        forRemoving groupIDs: Set<UUID>,
        in layers: [ImageEditorLayer]
    ) -> [UUID: UUID?] {
        var replacements: [UUID: UUID?] = [:]
        for groupID in groupIDs {
            var parentID = layers.first { $0.id == groupID }?.groupID
            var visitedIDs = Set<UUID>([groupID])
            while let candidateID = parentID,
                  groupIDs.contains(candidateID),
                  visitedIDs.insert(candidateID).inserted {
                parentID = layers.first { $0.id == candidateID }?.groupID
            }
            replacements[groupID] = parentID
        }
        return replacements
    }
}
