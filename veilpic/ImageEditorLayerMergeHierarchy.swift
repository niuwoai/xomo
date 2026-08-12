//
//  ImageEditorLayerMergeHierarchy.swift
//  veilpic
//
//  Created by Codex on 2026/7/13.
//

import Foundation

enum ImageEditorLayerHierarchyMergeKind: Equatable {
    case down
    case group
    case selected
}

struct ImageEditorLayerMergeSourcePlan {
    var kind: ImageEditorLayerHierarchyMergeKind
    var sourceLayerIDs: Set<UUID>
    var insertionIndex: Int
    var parentGroupID: UUID?
    var retainedSelectionIDs: Set<UUID>
    var primarySourceLayerID: UUID
    var lowerSourceLayerID: UUID?
    var clippingBaseID: UUID?
}

struct ImageEditorLayerMergeResultPlan {
    var layers: [ImageEditorLayer]
    var selectedLayerIDs: Set<UUID>
    var primarySelectionID: UUID
}

enum ImageEditorLayerHierarchyMerge {
    static func mergeDownPlan(
        layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?,
        isEffectivelyLocked: (ImageEditorLayer) -> Bool,
        isEffectivelyPixelsLocked: (ImageEditorLayer) -> Bool,
        isEffectivelyVisible: (ImageEditorLayer) -> Bool
    ) -> ImageEditorLayerMergeSourcePlan? {
        let existingSelectedIDs = selectedIDs.intersection(Set(layers.map(\.id)))
        guard let primarySelectionID,
              existingSelectedIDs.contains(primarySelectionID),
              let primaryIndex = layers.firstIndex(where: { $0.id == primarySelectionID })
        else { return nil }

        let primaryLayer = layers[primaryIndex]
        if primaryLayer.isGroup {
            let sourceIDs = subtreeIDs(rootedAt: primaryLayer.id, in: layers)
            guard existingSelectedIDs.isSubset(of: sourceIDs),
                  isMergeableSubtree(
                    sourceIDs,
                    layers: layers,
                    isEffectivelyLocked: isEffectivelyLocked,
                    isEffectivelyVisible: isEffectivelyVisible
                  )
            else { return nil }
            return ImageEditorLayerMergeSourcePlan(
                kind: .group,
                sourceLayerIDs: sourceIDs,
                insertionIndex: sourceInsertionIndex(sourceIDs, in: layers),
                parentGroupID: primaryLayer.groupID,
                retainedSelectionIDs: existingSelectedIDs.subtracting(sourceIDs),
                primarySourceLayerID: primaryLayer.id,
                lowerSourceLayerID: nil,
                clippingBaseID: nil
            )
        }

        guard existingSelectedIDs == [primaryLayer.id],
              isEffectivelyVisible(primaryLayer),
              !isEffectivelyLocked(primaryLayer),
              !isEffectivelyPixelsLocked(primaryLayer),
              let lowerIndex = immediateLowerSiblingIndex(
                forLayerAt: primaryIndex,
                in: layers
              )
        else { return nil }

        let lowerLayer = layers[lowerIndex]
        guard lowerLayer.kind.isPixel,
              isEffectivelyVisible(lowerLayer),
              !isEffectivelyPixelsLocked(lowerLayer)
        else { return nil }

        let sourceIDs: Set<UUID> = [lowerLayer.id, primaryLayer.id]
        let clippingBaseIDs = clippingBaseIDs(
            in: layers,
            isEffectivelyVisible: isEffectivelyVisible
        )
        let preservedBaseID = lowerLayer.isClippingMask
            ? clippingBaseIDs[lowerLayer.id].flatMap { sourceIDs.contains($0) ? nil : $0 }
            : nil
        return ImageEditorLayerMergeSourcePlan(
            kind: .down,
            sourceLayerIDs: sourceIDs,
            insertionIndex: lowerIndex,
            parentGroupID: lowerLayer.groupID,
            retainedSelectionIDs: [],
            primarySourceLayerID: primaryLayer.id,
            lowerSourceLayerID: lowerLayer.id,
            clippingBaseID: preservedBaseID
        )
    }

    static func mergeSelectedPlan(
        layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?,
        isEffectivelyLocked: (ImageEditorLayer) -> Bool,
        isEffectivelyVisible: (ImageEditorLayer) -> Bool
    ) -> ImageEditorLayerMergeSourcePlan? {
        let existingSelectedIDs = selectedIDs.intersection(Set(layers.map(\.id)))
        let selectedRootIDs = hierarchyRootIDs(
            in: layers,
            selectedIDs: existingSelectedIDs
        )
        let sourceIDsByRoot = Dictionary(uniqueKeysWithValues: selectedRootIDs.map { rootID in
            (rootID, subtreeIDs(rootedAt: rootID, in: layers))
        })
        let mergeableRootIDs = Set(selectedRootIDs.filter { rootID in
            guard let sourceIDs = sourceIDsByRoot[rootID],
                  let root = layers.first(where: { $0.id == rootID }),
                  isEffectivelyVisible(root)
            else { return false }
            return isMergeableSubtree(
                sourceIDs,
                layers: layers,
                isEffectivelyLocked: isEffectivelyLocked,
                isEffectivelyVisible: isEffectivelyVisible
            )
        })
        guard let firstRoot = layers.first(where: { mergeableRootIDs.contains($0.id) }) else {
            return nil
        }
        let parentGroupID = firstRoot.groupID
        guard layers.allSatisfy({ layer in
            !mergeableRootIDs.contains(layer.id) || layer.groupID == parentGroupID
        }) else { return nil }

        let isSingleGroup = mergeableRootIDs.count == 1 && firstRoot.isGroup
        guard mergeableRootIDs.count >= 2 || isSingleGroup else { return nil }

        let sourceIDs = mergeableRootIDs.reduce(into: Set<UUID>()) { result, rootID in
            result.formUnion(sourceIDsByRoot[rootID] ?? [])
        }
        let primarySourceID = primarySelectionID.flatMap { selectedID in
            sourceIDs.contains(selectedID) ? selectedID : nil
        } ?? layers.reversed().first(where: { mergeableRootIDs.contains($0.id) })?.id
        guard let primarySourceID else { return nil }

        let clippingBaseIDs = clippingBaseIDs(
            in: layers,
            isEffectivelyVisible: isEffectivelyVisible
        )
        let preservedBaseID = commonExternalClippingBaseID(
            rootIDs: mergeableRootIDs,
            sourceIDs: sourceIDs,
            layers: layers,
            clippingBaseIDs: clippingBaseIDs
        )
        return ImageEditorLayerMergeSourcePlan(
            kind: isSingleGroup ? .group : .selected,
            sourceLayerIDs: sourceIDs,
            insertionIndex: sourceInsertionIndex(sourceIDs, in: layers),
            parentGroupID: parentGroupID,
            retainedSelectionIDs: existingSelectedIDs.subtracting(sourceIDs),
            primarySourceLayerID: primarySourceID,
            lowerSourceLayerID: nil,
            clippingBaseID: preservedBaseID
        )
    }

    static func applying(
        _ sourcePlan: ImageEditorLayerMergeSourcePlan,
        mergedLayer: ImageEditorLayer,
        to layers: [ImageEditorLayer],
        isEffectivelyVisible: (ImageEditorLayer) -> Bool
    ) -> ImageEditorLayerMergeResultPlan {
        let clippingBaseIDsBeforeMerge = clippingBaseIDs(
            in: layers,
            isEffectivelyVisible: isEffectivelyVisible
        )
        var mergedLayer = mergedLayer
        mergedLayer.groupID = sourcePlan.parentGroupID
        mergedLayer.isClippingMask = sourcePlan.clippingBaseID != nil
        mergedLayer.linkedLayerIDs = externalLinkedLayerIDs(
            sourceIDs: sourcePlan.sourceLayerIDs,
            layers: layers
        )

        var nextLayers: [ImageEditorLayer] = []
        nextLayers.reserveCapacity(layers.count - sourcePlan.sourceLayerIDs.count + 1)
        for (index, layer) in layers.enumerated() {
            if index == sourcePlan.insertionIndex {
                nextLayers.append(mergedLayer)
            }
            guard !sourcePlan.sourceLayerIDs.contains(layer.id) else { continue }
            nextLayers.append(layer)
        }

        replaceMergedLinks(
            in: &nextLayers,
            sourceIDs: sourcePlan.sourceLayerIDs,
            mergedLayerID: mergedLayer.id
        )
        preserveClippingBases(
            in: &nextLayers,
            sourcePlan: sourcePlan,
            clippingBaseIDsBeforeMerge: clippingBaseIDsBeforeMerge,
            mergedLayerID: mergedLayer.id,
            isEffectivelyVisible: isEffectivelyVisible
        )
        normalizeLinks(in: &nextLayers)

        let existingIDs = Set(nextLayers.map(\.id))
        let retainedSelectionIDs = sourcePlan.retainedSelectionIDs.intersection(existingIDs)
        return ImageEditorLayerMergeResultPlan(
            layers: nextLayers,
            selectedLayerIDs: retainedSelectionIDs.union([mergedLayer.id]),
            primarySelectionID: mergedLayer.id
        )
    }

    private static func hierarchyRootIDs(
        in layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>
    ) -> Set<UUID> {
        Set(layers.compactMap { layer -> UUID? in
            guard selectedIDs.contains(layer.id),
                  !hasSelectedAncestor(layer, selectedIDs: selectedIDs, layers: layers)
            else { return nil }
            return layer.id
        })
    }

    private static func hasSelectedAncestor(
        _ layer: ImageEditorLayer,
        selectedIDs: Set<UUID>,
        layers: [ImageEditorLayer]
    ) -> Bool {
        var parentID = layer.groupID
        var visitedIDs = Set<UUID>()
        while let currentID = parentID, visitedIDs.insert(currentID).inserted {
            if selectedIDs.contains(currentID) { return true }
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

    private static func isMergeableSubtree(
        _ sourceIDs: Set<UUID>,
        layers: [ImageEditorLayer],
        isEffectivelyLocked: (ImageEditorLayer) -> Bool,
        isEffectivelyVisible: (ImageEditorLayer) -> Bool
    ) -> Bool {
        let sourceLayers = layers.filter { sourceIDs.contains($0.id) }
        guard !sourceLayers.isEmpty,
              sourceLayers.allSatisfy({ !isEffectivelyLocked($0) })
        else { return false }
        return sourceLayers.contains { !$0.isGroup && isEffectivelyVisible($0) }
    }

    private static func immediateLowerSiblingIndex(
        forLayerAt index: Int,
        in layers: [ImageEditorLayer]
    ) -> Int? {
        guard layers.indices.contains(index), index > layers.startIndex else { return nil }
        let parentGroupID = layers[index].groupID
        return layers[..<index].indices.reversed().first { candidateIndex in
            layers[candidateIndex].groupID == parentGroupID
        }
    }

    private static func sourceInsertionIndex(
        _ sourceIDs: Set<UUID>,
        in layers: [ImageEditorLayer]
    ) -> Int {
        layers.firstIndex(where: { sourceIDs.contains($0.id) }) ?? layers.endIndex
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

    private static func commonExternalClippingBaseID(
        rootIDs: Set<UUID>,
        sourceIDs: Set<UUID>,
        layers: [ImageEditorLayer],
        clippingBaseIDs: [UUID: UUID]
    ) -> UUID? {
        let roots = layers.filter { rootIDs.contains($0.id) }
        guard !roots.isEmpty, roots.allSatisfy(\.isClippingMask) else { return nil }
        let baseIDs = Set(roots.compactMap { clippingBaseIDs[$0.id] })
        guard baseIDs.count == 1,
              let baseID = baseIDs.first,
              !sourceIDs.contains(baseID)
        else { return nil }
        return baseID
    }

    private static func externalLinkedLayerIDs(
        sourceIDs: Set<UUID>,
        layers: [ImageEditorLayer]
    ) -> Set<UUID> {
        layers.reduce(into: Set<UUID>()) { result, layer in
            guard sourceIDs.contains(layer.id) else { return }
            result.formUnion(layer.linkedLayerIDs.subtracting(sourceIDs))
        }
    }

    private static func replaceMergedLinks(
        in layers: inout [ImageEditorLayer],
        sourceIDs: Set<UUID>,
        mergedLayerID: UUID
    ) {
        for index in layers.indices where layers[index].id != mergedLayerID {
            let replacedSourceLink = !layers[index].linkedLayerIDs.intersection(sourceIDs).isEmpty
            layers[index].linkedLayerIDs.subtract(sourceIDs)
            if replacedSourceLink {
                layers[index].linkedLayerIDs.insert(mergedLayerID)
            }
        }
    }

    private static func preserveClippingBases(
        in layers: inout [ImageEditorLayer],
        sourcePlan: ImageEditorLayerMergeSourcePlan,
        clippingBaseIDsBeforeMerge: [UUID: UUID],
        mergedLayerID: UUID,
        isEffectivelyVisible: (ImageEditorLayer) -> Bool
    ) {
        for index in layers.indices where layers[index].isClippingMask {
            let layerID = layers[index].id
            let expectedBaseID: UUID?
            if layerID == mergedLayerID {
                expectedBaseID = sourcePlan.clippingBaseID
            } else if let originalBaseID = clippingBaseIDsBeforeMerge[layerID] {
                expectedBaseID = sourcePlan.sourceLayerIDs.contains(originalBaseID)
                    ? mergedLayerID
                    : originalBaseID
            } else {
                expectedBaseID = nil
            }
            let actualBaseID = clippingBaseIndex(
                forLayerAt: index,
                in: layers,
                isEffectivelyVisible: isEffectivelyVisible
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
