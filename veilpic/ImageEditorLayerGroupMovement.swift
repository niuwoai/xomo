//
//  ImageEditorLayerGroupMovement.swift
//  veilpic
//
//  Created by Codex on 2026/7/13.
//

import Foundation

struct ImageEditorLayerGroupMovementPlan {
    var layers: [ImageEditorLayer]
    var selectedLayerIDs: Set<UUID>
    var primarySelectionID: UUID?
    var targetGroupID: UUID?
}

enum ImageEditorLayerHierarchyMovement {
    static func moveIntoGroupPlan(
        layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?,
        isEffectivelyLocked: (ImageEditorLayer) -> Bool
    ) -> ImageEditorLayerGroupMovementPlan? {
        let rootIDs = movableRootIDs(
            in: layers,
            selectedIDs: selectedIDs,
            isEffectivelyLocked: isEffectivelyLocked
        )
        guard let destinationGroupID = targetGroupID(
            for: rootIDs,
            in: layers,
            isEffectivelyLocked: isEffectivelyLocked
        ) else { return nil }

        let movingBlockIDs = movingBlockIDs(for: rootIDs, in: layers)
        var movingLayers = layers.filter { movingBlockIDs.contains($0.id) }
        for index in movingLayers.indices where rootIDs.contains(movingLayers[index].id) {
            movingLayers[index].groupID = destinationGroupID
        }

        var nextLayers = layers.filter { !movingBlockIDs.contains($0.id) }
        guard let targetIndex = nextLayers.firstIndex(where: { $0.id == destinationGroupID }) else {
            return nil
        }
        nextLayers.insert(contentsOf: movingLayers, at: targetIndex)
        if let expandedTargetIndex = nextLayers.firstIndex(where: { $0.id == destinationGroupID }) {
            nextLayers[expandedTargetIndex].isGroupExpanded = true
        }
        guard hierarchyDiffers(layers, nextLayers) else { return nil }

        return plan(
            layers: nextLayers,
            selectedIDs: selectedIDs,
            primarySelectionID: primarySelectionID,
            targetGroupID: destinationGroupID
        )
    }

    static func moveOutOfGroupsPlan(
        layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?,
        isEffectivelyLocked: (ImageEditorLayer) -> Bool
    ) -> ImageEditorLayerGroupMovementPlan? {
        let rootIDs = movableRootIDs(
            in: layers,
            selectedIDs: selectedIDs,
            isEffectivelyLocked: isEffectivelyLocked
        )
        guard !rootIDs.isEmpty else { return nil }

        let rootParentIDs = Dictionary(uniqueKeysWithValues: rootIDs.compactMap { rootID -> (UUID, UUID)? in
            guard let parentID = layers.first(where: { $0.id == rootID })?.groupID,
                  layers.contains(where: { $0.id == parentID && $0.isGroup })
            else { return nil }
            return (rootID, parentID)
        })
        guard rootParentIDs.count == rootIDs.count else { return nil }

        let replacementParentIDs: [UUID: UUID?] = Dictionary(uniqueKeysWithValues: rootParentIDs.map { rootID, parentID in
            let replacementParentID = layers.first(where: { $0.id == parentID })?.groupID ?? nil
            return (rootID, replacementParentID)
        })
        let blockIDsByRoot = Dictionary(uniqueKeysWithValues: rootIDs.map { rootID in
            let rootBlockIDs: Set<UUID>
            if layers.first(where: { $0.id == rootID })?.isGroup == true {
                rootBlockIDs = descendantIDs(of: rootID, in: layers).union([rootID])
            } else {
                rootBlockIDs = [rootID]
            }
            return (rootID, rootBlockIDs)
        })
        let allMovingBlockIDs = blockIDsByRoot.values.reduce(into: Set<UUID>()) {
            $0.formUnion($1)
        }

        var movingLayers = layers.filter { allMovingBlockIDs.contains($0.id) }
        for index in movingLayers.indices where rootIDs.contains(movingLayers[index].id) {
            movingLayers[index].groupID = replacementParentIDs[movingLayers[index].id] ?? nil
        }
        var nextLayers = layers.filter { !allMovingBlockIDs.contains($0.id) }

        let orderedParentIDs = Set(rootParentIDs.values).sorted { leftID, rightID in
            let leftIndex = layers.firstIndex(where: { $0.id == leftID }) ?? layers.endIndex
            let rightIndex = layers.firstIndex(where: { $0.id == rightID }) ?? layers.endIndex
            return leftIndex < rightIndex
        }
        for parentID in orderedParentIDs {
            let rootsForParent = Set(rootParentIDs.compactMap { rootID, candidateParentID in
                candidateParentID == parentID ? rootID : nil
            })
            let blockIDsForParent = rootsForParent.reduce(into: Set<UUID>()) { result, rootID in
                result.formUnion(blockIDsByRoot[rootID] ?? [])
            }
            let layersForParent = movingLayers.filter { blockIDsForParent.contains($0.id) }
            guard let parentIndex = nextLayers.firstIndex(where: { $0.id == parentID }) else {
                return nil
            }
            nextLayers.insert(contentsOf: layersForParent, at: parentIndex + 1)
        }
        guard hierarchyDiffers(layers, nextLayers) else { return nil }

        return plan(
            layers: nextLayers,
            selectedIDs: selectedIDs,
            primarySelectionID: primarySelectionID,
            targetGroupID: nil
        )
    }

    private static func targetGroupID(
        for rootIDs: Set<UUID>,
        in layers: [ImageEditorLayer],
        isEffectivelyLocked: (ImageEditorLayer) -> Bool
    ) -> UUID? {
        guard !rootIDs.isEmpty,
              let firstRoot = layers.first(where: { rootIDs.contains($0.id) }),
              let highestRootIndex = layers.indices.last(where: { rootIDs.contains(layers[$0].id) })
        else { return nil }

        let parentID = firstRoot.groupID
        guard layers.allSatisfy({ !rootIDs.contains($0.id) || $0.groupID == parentID }) else {
            return nil
        }
        let movingIDs = movingBlockIDs(for: rootIDs, in: layers)
        guard highestRootIndex + 1 < layers.endIndex else { return nil }

        for candidateIndex in (highestRootIndex + 1)..<layers.endIndex {
            let candidate = layers[candidateIndex]
            guard candidate.isGroup,
                  candidate.groupID == parentID,
                  !movingIDs.contains(candidate.id),
                  !isEffectivelyLocked(candidate)
            else { continue }
            return candidate.id
        }
        return nil
    }

    private static func movableRootIDs(
        in layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        isEffectivelyLocked: (ImageEditorLayer) -> Bool
    ) -> Set<UUID> {
        let existingSelectedIDs = selectedIDs.intersection(Set(layers.map(\.id)))
        let selectedGroupIDs = Set(layers.compactMap { layer -> UUID? in
            existingSelectedIDs.contains(layer.id) && layer.isGroup ? layer.id : nil
        })
        let selectedDescendantIDs = selectedGroupIDs.reduce(into: Set<UUID>()) { result, groupID in
            result.formUnion(descendantIDs(of: groupID, in: layers))
        }
        return Set(layers.compactMap { layer -> UUID? in
            guard existingSelectedIDs.contains(layer.id),
                  !selectedDescendantIDs.contains(layer.id),
                  !isEffectivelyLocked(layer)
            else { return nil }
            return layer.id
        })
    }

    private static func movingBlockIDs(
        for rootIDs: Set<UUID>,
        in layers: [ImageEditorLayer]
    ) -> Set<UUID> {
        rootIDs.reduce(into: rootIDs) { result, rootID in
            guard layers.first(where: { $0.id == rootID })?.isGroup == true else { return }
            result.formUnion(descendantIDs(of: rootID, in: layers))
        }
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

    private static func plan(
        layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?,
        targetGroupID: UUID?
    ) -> ImageEditorLayerGroupMovementPlan {
        let existingIDs = Set(layers.map(\.id))
        let nextSelectionIDs = selectedIDs.intersection(existingIDs)
        let nextPrimarySelectionID = primarySelectionID.flatMap { id in
            nextSelectionIDs.contains(id) ? id : nil
        } ?? layers.reversed().first(where: { nextSelectionIDs.contains($0.id) })?.id
        return ImageEditorLayerGroupMovementPlan(
            layers: layers,
            selectedLayerIDs: nextSelectionIDs,
            primarySelectionID: nextPrimarySelectionID,
            targetGroupID: targetGroupID
        )
    }

    private static func hierarchyDiffers(
        _ lhs: [ImageEditorLayer],
        _ rhs: [ImageEditorLayer]
    ) -> Bool {
        guard lhs.map(\.id) == rhs.map(\.id) else { return true }
        return zip(lhs, rhs).contains { left, right in
            left.groupID != right.groupID || left.isGroupExpanded != right.isGroupExpanded
        }
    }
}
