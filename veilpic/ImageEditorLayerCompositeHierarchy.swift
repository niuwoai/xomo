//
//  ImageEditorLayerCompositeHierarchy.swift
//  veilpic
//
//  Created by Codex on 2026/7/13.
//

import Foundation

struct ImageEditorLayerStampPlan {
    var sourceLayerIDs: Set<UUID>
    var parentGroupID: UUID?
    var insertionIndex: Int
}

struct ImageEditorLayerCompositeResultPlan {
    var layers: [ImageEditorLayer]
    var primarySelectionID: UUID
}

enum ImageEditorLayerCompositeHierarchy {
    static func visibleSourceIDs(
        in layers: [ImageEditorLayer],
        isEffectivelyVisible: (ImageEditorLayer) -> Bool
    ) -> Set<UUID> {
        Set(layers.compactMap { layer in
            guard !layer.isGroup, isEffectivelyVisible(layer) else { return nil }
            return layer.id
        })
    }

    static func stampVisiblePlan(
        layers: [ImageEditorLayer],
        sourceLayerIDs: Set<UUID>
    ) -> ImageEditorLayerStampPlan? {
        guard !sourceLayerIDs.isEmpty else { return nil }
        return ImageEditorLayerStampPlan(
            sourceLayerIDs: sourceLayerIDs,
            parentGroupID: nil,
            insertionIndex: insertionIndexAboveTopmostRoot(
                containing: sourceLayerIDs,
                in: layers
            )
        )
    }

    static func stampSelectedPlan(
        layers: [ImageEditorLayer],
        selectedLayerIDs: Set<UUID>
    ) -> ImageEditorLayerStampPlan? {
        let existingSelectedIDs = selectedLayerIDs.intersection(Set(layers.map(\.id)))
        let selectedRootIDs = hierarchyRootIDs(
            in: layers,
            selectedLayerIDs: existingSelectedIDs
        )
        let selectedRoots = layers.enumerated().filter { selectedRootIDs.contains($0.element.id) }
        guard let firstRoot = selectedRoots.first else { return nil }

        let sourceLayerIDs = selectedRootIDs.reduce(into: Set<UUID>()) { result, rootID in
            result.formUnion(subtreeIDs(rootedAt: rootID, in: layers))
        }
        let sharesParent = selectedRoots.dropFirst().allSatisfy {
            $0.element.groupID == firstRoot.element.groupID
        }
        if sharesParent {
            return ImageEditorLayerStampPlan(
                sourceLayerIDs: sourceLayerIDs,
                parentGroupID: firstRoot.element.groupID,
                insertionIndex: min(
                    (selectedRoots.map(\.offset).max() ?? layers.endIndex) + 1,
                    layers.endIndex
                )
            )
        }

        return ImageEditorLayerStampPlan(
            sourceLayerIDs: sourceLayerIDs,
            parentGroupID: nil,
            insertionIndex: insertionIndexAboveTopmostRoot(
                containing: sourceLayerIDs,
                in: layers
            )
        )
    }

    static func applyingMergeVisible(
        layers: [ImageEditorLayer],
        sourceLayerIDs: Set<UUID>,
        mergedLayer: ImageEditorLayer,
        isEffectivelyVisible: (ImageEditorLayer) -> Bool
    ) -> ImageEditorLayerCompositeResultPlan? {
        guard sourceLayerIDs.count > 1 else { return nil }
        let anchorIndex = topmostRootIndex(
            containing: sourceLayerIDs,
            in: layers
        ) ?? layers.endIndex
        let removedLayerIDs = recursivelyRemovedLayerIDs(
            from: layers,
            sourceLayerIDs: sourceLayerIDs,
            isEffectivelyVisible: isEffectivelyVisible
        )
        let clippingBaseIDsBeforeMerge = clippingBaseIDs(
            in: layers,
            isEffectivelyVisible: isEffectivelyVisible
        )

        var mergedLayer = mergedLayer
        mergedLayer.groupID = nil
        mergedLayer.isClippingMask = false
        mergedLayer.linkedLayerIDs = externalLinkedLayerIDs(
            removedLayerIDs: removedLayerIDs,
            layers: layers
        )

        var nextLayers: [ImageEditorLayer] = []
        nextLayers.reserveCapacity(layers.count - removedLayerIDs.count + 1)
        var inserted = false
        for (index, layer) in layers.enumerated() {
            if !removedLayerIDs.contains(layer.id) {
                nextLayers.append(layer)
            }
            if index == anchorIndex {
                nextLayers.append(mergedLayer)
                inserted = true
            }
        }
        if !inserted {
            nextLayers.append(mergedLayer)
        }

        replaceMergedLinks(
            in: &nextLayers,
            removedLayerIDs: removedLayerIDs,
            mergedLayerID: mergedLayer.id
        )
        preserveClippingBases(
            in: &nextLayers,
            removedLayerIDs: removedLayerIDs,
            clippingBaseIDsBeforeMerge: clippingBaseIDsBeforeMerge,
            mergedLayerID: mergedLayer.id,
            isEffectivelyVisibleBeforeMerge: isEffectivelyVisible
        )
        normalizeLinks(in: &nextLayers)

        return ImageEditorLayerCompositeResultPlan(
            layers: nextLayers,
            primarySelectionID: mergedLayer.id
        )
    }

    private static func hierarchyRootIDs(
        in layers: [ImageEditorLayer],
        selectedLayerIDs: Set<UUID>
    ) -> Set<UUID> {
        Set(layers.compactMap { layer in
            guard selectedLayerIDs.contains(layer.id),
                  !hasSelectedAncestor(
                    layer,
                    selectedLayerIDs: selectedLayerIDs,
                    layers: layers
                  )
            else { return nil }
            return layer.id
        })
    }

    private static func hasSelectedAncestor(
        _ layer: ImageEditorLayer,
        selectedLayerIDs: Set<UUID>,
        layers: [ImageEditorLayer]
    ) -> Bool {
        var parentID = layer.groupID
        var visitedIDs = Set<UUID>()
        while let currentID = parentID, visitedIDs.insert(currentID).inserted {
            if selectedLayerIDs.contains(currentID) { return true }
            parentID = layers.first(where: { $0.id == currentID && $0.isGroup })?.groupID
        }
        return false
    }

    private static func subtreeIDs(
        rootedAt rootID: UUID,
        in layers: [ImageEditorLayer]
    ) -> Set<UUID> {
        guard layers.first(where: { $0.id == rootID })?.isGroup == true else {
            return [rootID]
        }
        var result: Set<UUID> = [rootID]
        var pendingGroupIDs = [rootID]
        while let groupID = pendingGroupIDs.popLast() {
            for layer in layers where layer.groupID == groupID && !result.contains(layer.id) {
                result.insert(layer.id)
                if layer.isGroup {
                    pendingGroupIDs.append(layer.id)
                }
            }
        }
        return result
    }

    private static func insertionIndexAboveTopmostRoot(
        containing layerIDs: Set<UUID>,
        in layers: [ImageEditorLayer]
    ) -> Int {
        guard let rootIndex = topmostRootIndex(containing: layerIDs, in: layers) else {
            return layers.endIndex
        }
        return min(rootIndex + 1, layers.endIndex)
    }

    private static func topmostRootIndex(
        containing layerIDs: Set<UUID>,
        in layers: [ImageEditorLayer]
    ) -> Int? {
        let indexByID = Dictionary(uniqueKeysWithValues: layers.indices.map { (layers[$0].id, $0) })
        let rootIDs = Set(layerIDs.compactMap { layerID in
            topLevelRootID(for: layerID, layers: layers)
        })
        return rootIDs.compactMap { indexByID[$0] }.max()
    }

    private static func topLevelRootID(
        for layerID: UUID,
        layers: [ImageEditorLayer]
    ) -> UUID? {
        guard var layer = layers.first(where: { $0.id == layerID }) else { return nil }
        var visitedIDs: Set<UUID> = [layer.id]
        while let parentID = layer.groupID,
              visitedIDs.insert(parentID).inserted,
              let parent = layers.first(where: { $0.id == parentID && $0.isGroup }) {
            layer = parent
        }
        return layer.id
    }

    private static func recursivelyRemovedLayerIDs(
        from layers: [ImageEditorLayer],
        sourceLayerIDs: Set<UUID>,
        isEffectivelyVisible: (ImageEditorLayer) -> Bool
    ) -> Set<UUID> {
        var removedLayerIDs = sourceLayerIDs
        var removedAnotherGroup = true
        while removedAnotherGroup {
            removedAnotherGroup = false
            for group in layers where group.isGroup && !removedLayerIDs.contains(group.id) {
                guard isEffectivelyVisible(group) else { continue }
                let hasRemainingChild = layers.contains { layer in
                    layer.groupID == group.id && !removedLayerIDs.contains(layer.id)
                }
                if !hasRemainingChild {
                    removedLayerIDs.insert(group.id)
                    removedAnotherGroup = true
                }
            }
        }
        return removedLayerIDs
    }

    private static func clippingBaseIDs(
        in layers: [ImageEditorLayer],
        isEffectivelyVisible: (ImageEditorLayer) -> Bool
    ) -> [UUID: UUID] {
        var result: [UUID: UUID] = [:]
        for index in layers.indices where layers[index].isClippingMask {
            guard let baseIndex = clippingBaseIndex(
                forLayerAt: index,
                in: layers,
                isEffectivelyVisible: isEffectivelyVisible
            ) else { continue }
            result[layers[index].id] = layers[baseIndex].id
        }
        return result
    }

    private static func clippingBaseIndex(
        forLayerAt index: Int,
        in layers: [ImageEditorLayer],
        isEffectivelyVisible _: (ImageEditorLayer) -> Bool
    ) -> Int? {
        guard layers.indices.contains(index), layers[index].isClippingMask else { return nil }
        let layer = layers[index]
        return layers[..<index].indices.reversed().first { candidateIndex in
            let candidate = layers[candidateIndex]
            return !candidate.isGroup
                && !candidate.isAdjustment
                && !candidate.isFilter
                && !candidate.isClippingMask
                && candidate.groupID == layer.groupID
        }
    }

    private static func externalLinkedLayerIDs(
        removedLayerIDs: Set<UUID>,
        layers: [ImageEditorLayer]
    ) -> Set<UUID> {
        layers.reduce(into: Set<UUID>()) { result, layer in
            guard removedLayerIDs.contains(layer.id) else { return }
            result.formUnion(layer.linkedLayerIDs.subtracting(removedLayerIDs))
        }
    }

    private static func replaceMergedLinks(
        in layers: inout [ImageEditorLayer],
        removedLayerIDs: Set<UUID>,
        mergedLayerID: UUID
    ) {
        for index in layers.indices where layers[index].id != mergedLayerID {
            let replacedRemovedLink = !layers[index].linkedLayerIDs.intersection(removedLayerIDs).isEmpty
            layers[index].linkedLayerIDs.subtract(removedLayerIDs)
            if replacedRemovedLink {
                layers[index].linkedLayerIDs.insert(mergedLayerID)
            }
        }
    }

    private static func preserveClippingBases(
        in layers: inout [ImageEditorLayer],
        removedLayerIDs: Set<UUID>,
        clippingBaseIDsBeforeMerge: [UUID: UUID],
        mergedLayerID: UUID,
        isEffectivelyVisibleBeforeMerge: (ImageEditorLayer) -> Bool
    ) {
        for index in layers.indices where layers[index].isClippingMask {
            let layerID = layers[index].id
            let expectedBaseID = clippingBaseIDsBeforeMerge[layerID].map { originalBaseID in
                removedLayerIDs.contains(originalBaseID) ? mergedLayerID : originalBaseID
            }
            let actualBaseID = clippingBaseIndex(
                forLayerAt: index,
                in: layers,
                isEffectivelyVisible: isEffectivelyVisibleBeforeMerge
            ).map { layers[$0].id }
            if expectedBaseID == nil || actualBaseID != expectedBaseID {
                layers[index].isClippingMask = false
            }
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
}
