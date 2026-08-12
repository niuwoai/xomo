//
//  ImageEditorLayerDuplication.swift
//  veilpic
//
//  Created by Codex on 2026/7/13.
//

import Foundation

struct ImageEditorLayerDuplicationPlan {
    var layers: [ImageEditorLayer]
    var selectedLayerIDs: Set<UUID>
    var primarySelectionID: UUID?
    var duplicatedIDBySourceID: [UUID: UUID]
}

enum ImageEditorLayerHierarchyDuplication {
    static func duplicableRootIDs(
        in layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>
    ) -> Set<UUID> {
        let existingSelectedIDs = selectedIDs.intersection(Set(layers.map(\.id)))
        return Set(layers.compactMap { layer -> UUID? in
            guard existingSelectedIDs.contains(layer.id),
                  !hasSelectedGroupAncestor(
                    layer,
                    selectedIDs: existingSelectedIDs,
                    in: layers
                  )
            else { return nil }
            return layer.id
        })
    }

    static func duplicationPlan(
        layers: [ImageEditorLayer],
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?,
        duplicateName: (String) -> String,
        isEffectivelyVisible: (ImageEditorLayer) -> Bool
    ) -> ImageEditorLayerDuplicationPlan? {
        let rootIDs = duplicableRootIDs(in: layers, selectedIDs: selectedIDs)
        guard !rootIDs.isEmpty else { return nil }

        let existingSelectedIDs = selectedIDs.intersection(Set(layers.map(\.id)))
        let sourceIDsByRoot = sourceIDsByRoot(rootIDs, in: layers)
        let allSourceIDs = sourceIDsByRoot.values.reduce(into: Set<UUID>()) {
            $0.formUnion($1)
        }
        let duplicatedIDBySourceID = Dictionary(uniqueKeysWithValues: layers.compactMap { layer in
            allSourceIDs.contains(layer.id) ? (layer.id, UUID()) : nil
        })
        let clippingBaseIDs = clippingBaseIDs(
            in: layers,
            isEffectivelyVisible: isEffectivelyVisible
        )
        let clusters = duplicationClusters(
            layers: layers,
            rootIDs: rootIDs,
            sourceIDsByRoot: sourceIDsByRoot,
            clippingBaseIDs: clippingBaseIDs
        )
        let duplicatedLayersByBoundaryID = duplicatedLayersByBoundaryID(
            clusters: clusters,
            layers: layers,
            rootIDs: rootIDs,
            duplicatedIDBySourceID: duplicatedIDBySourceID,
            clippingBaseIDs: clippingBaseIDs,
            duplicateName: duplicateName
        )
        let nextLayers = interleaving(
            layers,
            with: duplicatedLayersByBoundaryID,
            additionalCapacity: allSourceIDs.count
        )

        let nextSelectionIDs = Set(existingSelectedIDs.compactMap { duplicatedIDBySourceID[$0] })
        let nextPrimarySelectionID = primarySelectionID.flatMap { duplicatedIDBySourceID[$0] }
            ?? nextLayers.reversed().first(where: { nextSelectionIDs.contains($0.id) })?.id
        return ImageEditorLayerDuplicationPlan(
            layers: nextLayers,
            selectedLayerIDs: nextSelectionIDs,
            primarySelectionID: nextPrimarySelectionID,
            duplicatedIDBySourceID: duplicatedIDBySourceID
        )
    }

    private struct DuplicationCluster {
        var sourceIDs: Set<UUID>
        var boundaryID: UUID
    }

    private static func sourceIDsByRoot(
        _ rootIDs: Set<UUID>,
        in layers: [ImageEditorLayer]
    ) -> [UUID: Set<UUID>] {
        Dictionary(uniqueKeysWithValues: rootIDs.map { rootID in
            let sourceIDs: Set<UUID>
            if layers.first(where: { $0.id == rootID })?.isGroup == true {
                sourceIDs = descendantIDs(of: rootID, in: layers).union([rootID])
            } else {
                sourceIDs = [rootID]
            }
            return (rootID, sourceIDs)
        })
    }

    private static func duplicatedLayersByBoundaryID(
        clusters: [DuplicationCluster],
        layers: [ImageEditorLayer],
        rootIDs: Set<UUID>,
        duplicatedIDBySourceID: [UUID: UUID],
        clippingBaseIDs: [UUID: UUID],
        duplicateName: (String) -> String
    ) -> [UUID: [ImageEditorLayer]] {
        var result: [UUID: [ImageEditorLayer]] = [:]
        for cluster in clusters {
            let sourceLayers = layers.filter { cluster.sourceIDs.contains($0.id) }
            let duplicates = duplicateLayers(
                sourceLayers,
                rootIDs: rootIDs,
                duplicatedIDBySourceID: duplicatedIDBySourceID,
                clippingBaseIDs: clippingBaseIDs,
                duplicateName: duplicateName
            )
            result[cluster.boundaryID, default: []].append(contentsOf: duplicates)
        }
        return result
    }

    private static func duplicateLayers(
        _ sourceLayers: [ImageEditorLayer],
        rootIDs: Set<UUID>,
        duplicatedIDBySourceID: [UUID: UUID],
        clippingBaseIDs: [UUID: UUID],
        duplicateName: (String) -> String
    ) -> [ImageEditorLayer] {
        var duplicates = sourceLayers.compactMap { source -> ImageEditorLayer? in
            guard let duplicateID = duplicatedIDBySourceID[source.id] else { return nil }
            var duplicate = source
            duplicate.id = duplicateID
            duplicate.linkedLayerIDs = []
            if rootIDs.contains(source.id) {
                duplicate.name = duplicateName(source.name)
            }
            if let groupID = source.groupID,
               let duplicatedGroupID = duplicatedIDBySourceID[groupID] {
                duplicate.groupID = duplicatedGroupID
            }
            if source.isClippingMask && clippingBaseIDs[source.id] == nil {
                duplicate.isClippingMask = false
            }
            return duplicate
        }
        for index in duplicates.indices {
            duplicates[index].linkedLayerIDs = Set(sourceLayers[index].linkedLayerIDs.compactMap {
                duplicatedIDBySourceID[$0]
            }).subtracting([duplicates[index].id])
        }
        return duplicates
    }

    private static func interleaving(
        _ layers: [ImageEditorLayer],
        with duplicatedLayersByBoundaryID: [UUID: [ImageEditorLayer]],
        additionalCapacity: Int
    ) -> [ImageEditorLayer] {
        var result: [ImageEditorLayer] = []
        result.reserveCapacity(layers.count + additionalCapacity)
        for layer in layers {
            result.append(layer)
            result.append(contentsOf: duplicatedLayersByBoundaryID[layer.id] ?? [])
        }
        return result
    }

    private static func duplicationClusters(
        layers: [ImageEditorLayer],
        rootIDs: Set<UUID>,
        sourceIDsByRoot: [UUID: Set<UUID>],
        clippingBaseIDs: [UUID: UUID]
    ) -> [DuplicationCluster] {
        var clusterRoots: [(parentID: UUID?, rootIDs: Set<UUID>)] = []
        for layer in layers where rootIDs.contains(layer.id) {
            if let index = clusterRoots.firstIndex(where: { $0.parentID == layer.groupID }) {
                clusterRoots[index].rootIDs.insert(layer.id)
            } else {
                clusterRoots.append((layer.groupID, [layer.id]))
            }
        }

        return clusterRoots.compactMap { cluster -> DuplicationCluster? in
            let sourceIDs = cluster.rootIDs.reduce(into: Set<UUID>()) { result, rootID in
                result.formUnion(sourceIDsByRoot[rootID] ?? [])
            }
            guard var boundaryIndex = layers.indices.last(where: {
                cluster.rootIDs.contains(layers[$0].id)
            }) else { return nil }

            for layer in layers where layer.isClippingMask {
                guard let baseID = clippingBaseIDs[layer.id], sourceIDs.contains(baseID),
                      let layerIndex = layers.firstIndex(where: { $0.id == layer.id })
                else { continue }
                boundaryIndex = max(boundaryIndex, layerIndex)
            }
            return DuplicationCluster(
                sourceIDs: sourceIDs,
                boundaryID: layers[boundaryIndex].id
            )
        }
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

    private static func hasSelectedGroupAncestor(
        _ layer: ImageEditorLayer,
        selectedIDs: Set<UUID>,
        in layers: [ImageEditorLayer]
    ) -> Bool {
        var parentID = layer.groupID
        var visitedIDs = Set<UUID>()
        while let candidateID = parentID, visitedIDs.insert(candidateID).inserted {
            guard let candidate = layers.first(where: { $0.id == candidateID && $0.isGroup }) else {
                return false
            }
            if selectedIDs.contains(candidateID) {
                return true
            }
            parentID = candidate.groupID
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
}
