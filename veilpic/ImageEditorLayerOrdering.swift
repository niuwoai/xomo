//
//  ImageEditorLayerOrdering.swift
//  veilpic
//
//  Created by Codex on 2026/7/13.
//

import Foundation

private enum ImageEditorLayerStackDirection {
    case up
    case down
}

private enum ImageEditorLayerStackBoundary {
    case top
    case bottom
}

private struct ImageEditorVisibleLayerMove {
    var sourceIDs: Set<UUID>
    var target: ImageEditorLayerDropTarget
}

private struct ImageEditorLayerMovePlan {
    var layers: [ImageEditorLayer]
    var rootSourceIDs: Set<UUID>
    var movingBlockIDs: Set<UUID>
}

@MainActor
extension ImageEditorViewModel {
    func canMoveSelectedLayerUp(inVisibleOrder visibleRowIDs: [UUID]) -> Bool {
        reorderedLayers(
            moving: .up,
            toBoundary: nil,
            visibleRowIDs: visibleRowIDs
        ) != nil
    }

    func canMoveSelectedLayerDown(inVisibleOrder visibleRowIDs: [UUID]) -> Bool {
        reorderedLayers(
            moving: .down,
            toBoundary: nil,
            visibleRowIDs: visibleRowIDs
        ) != nil
    }

    func canMoveSelectedLayerToTop(inVisibleOrder visibleRowIDs: [UUID]) -> Bool {
        reorderedLayers(
            moving: .up,
            toBoundary: .top,
            visibleRowIDs: visibleRowIDs
        ) != nil
    }

    func canMoveSelectedLayerToBottom(inVisibleOrder visibleRowIDs: [UUID]) -> Bool {
        reorderedLayers(
            moving: .down,
            toBoundary: .bottom,
            visibleRowIDs: visibleRowIDs
        ) != nil
    }

    func moveSelectedLayerUp() {
        moveSelectedLayerUp(inVisibleOrder: visibleLayerRows.map(\.id))
    }

    func moveSelectedLayerDown() {
        moveSelectedLayerDown(inVisibleOrder: visibleLayerRows.map(\.id))
    }

    func moveSelectedLayerToTop() {
        moveSelectedLayerToTop(inVisibleOrder: visibleLayerRows.map(\.id))
    }

    func moveSelectedLayerToBottom() {
        moveSelectedLayerToBottom(inVisibleOrder: visibleLayerRows.map(\.id))
    }

    func moveSelectedLayerUp(inVisibleOrder visibleRowIDs: [UUID]) {
        moveSelectedLayers(
            direction: .up,
            boundary: nil,
            visibleRowIDs: visibleRowIDs,
            historyKey: "imageEditor.history.layerMove"
        )
    }

    func moveSelectedLayerDown(inVisibleOrder visibleRowIDs: [UUID]) {
        moveSelectedLayers(
            direction: .down,
            boundary: nil,
            visibleRowIDs: visibleRowIDs,
            historyKey: "imageEditor.history.layerMove"
        )
    }

    func moveSelectedLayerToTop(inVisibleOrder visibleRowIDs: [UUID]) {
        moveSelectedLayers(
            direction: .up,
            boundary: .top,
            visibleRowIDs: visibleRowIDs,
            historyKey: "imageEditor.history.layerMoveToTop"
        )
    }

    func moveSelectedLayerToBottom(inVisibleOrder visibleRowIDs: [UUID]) {
        moveSelectedLayers(
            direction: .down,
            boundary: .bottom,
            visibleRowIDs: visibleRowIDs,
            historyKey: "imageEditor.history.layerMoveToBottom"
        )
    }

    @discardableResult
    func moveLayerIDs(_ sourceIDs: Set<UUID>, toDropTarget target: ImageEditorLayerDropTarget) -> Bool {
        guard let plan = layerMovePlan(
            sourceIDs: sourceIDs,
            target: target,
            layers: document.layers
        ) else { return false }

        pushUndo()
        document.layers = plan.layers
        normalizeClippingMasks()

        let retainedSelectionIDs = sourceIDs.intersection(plan.movingBlockIDs)
        document.selectedLayerIDs = retainedSelectionIDs.isEmpty
            ? plan.rootSourceIDs
            : retainedSelectionIDs
        if document.selectedLayerID.map({ document.selectedLayerIDs.contains($0) }) != true {
            document.selectedLayerID = document.layers.reversed().first {
                document.selectedLayerIDs.contains($0.id)
            }?.id
        }
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerReorder"))
        statusText = L10n.text("imageEditor.status.layerReordered")
        return true
    }

    private func moveSelectedLayers(
        direction: ImageEditorLayerStackDirection,
        boundary: ImageEditorLayerStackBoundary?,
        visibleRowIDs: [UUID],
        historyKey: String
    ) {
        guard let layers = reorderedLayers(
            moving: direction,
            toBoundary: boundary,
            visibleRowIDs: visibleRowIDs
        ) else { return }

        pushUndo()
        document.layers = layers
        normalizeClippingMasks()
        appendHistory(L10n.text(historyKey))
        statusText = L10n.text("imageEditor.status.layerReordered")
    }

    private func reorderedLayers(
        moving direction: ImageEditorLayerStackDirection,
        toBoundary boundary: ImageEditorLayerStackBoundary?,
        visibleRowIDs: [UUID]
    ) -> [ImageEditorLayer]? {
        let initiallyVisibleIDs = Set(orderingVisibleLayerIDs(in: document.layers))
        let allowedVisibleIDs = Set(visibleRowIDs).intersection(initiallyVisibleIDs)
        guard !allowedVisibleIDs.isEmpty else { return nil }

        let originalLayers = document.layers
        var workingLayers = originalLayers
        let passLimit = boundary == nil ? 1 : max(1, allowedVisibleIDs.count)

        for _ in 0..<passLimit {
            let currentVisibleIDs = orderingVisibleLayerIDs(in: workingLayers).filter {
                allowedVisibleIDs.contains($0)
            }
            let operations = visibleLayerMoveOperations(
                direction: direction,
                visibleRowIDs: currentVisibleIDs,
                layers: workingLayers
            )
            var changedThisPass = false
            for operation in operations {
                guard let plan = layerMovePlan(
                    sourceIDs: operation.sourceIDs,
                    target: operation.target,
                    layers: workingLayers
                ) else { continue }
                workingLayers = plan.layers
                changedThisPass = true
            }
            if !changedThisPass || boundary == nil {
                break
            }
        }

        return layerOrderOrParentsDiffer(originalLayers, workingLayers)
            ? workingLayers
            : nil
    }

    private func visibleLayerMoveOperations(
        direction: ImageEditorLayerStackDirection,
        visibleRowIDs: [UUID],
        layers: [ImageEditorLayer]
    ) -> [ImageEditorVisibleLayerMove] {
        let visibleIDSet = Set(visibleRowIDs)
        let selectedVisibleIDs = document.selectedLayerIDs.intersection(visibleIDSet)
        let rootSourceIDs = orderingMovableRootLayerIDs(
            for: selectedVisibleIDs,
            layers: layers
        )
        guard !rootSourceIDs.isEmpty else { return [] }

        let movingBlockIDs = orderingMovingBlockIDs(
            for: rootSourceIDs,
            layers: layers
        )
        let ranges = contiguousMovingRanges(
            visibleRowIDs: visibleRowIDs,
            movingBlockIDs: movingBlockIDs
        )
        let orderedRanges = direction == .up ? ranges : Array(ranges.reversed())

        return orderedRanges.compactMap { range in
            let targetIndex = direction == .up ? range.lowerBound - 1 : range.upperBound
            guard visibleRowIDs.indices.contains(targetIndex) else { return nil }
            let sourceIDs = rootSourceIDs.intersection(Set(visibleRowIDs[range]))
            guard !sourceIDs.isEmpty else { return nil }

            let targetID = visibleRowIDs[targetIndex]
            guard let targetLayer = layers.first(where: { $0.id == targetID }) else { return nil }
            let placement: ImageEditorLayerDropPlacement
            if direction == .up {
                placement = .above
            } else if targetLayer.isGroup && targetLayer.isGroupExpanded {
                placement = .insideGroup
            } else {
                placement = .below
            }
            return ImageEditorVisibleLayerMove(
                sourceIDs: sourceIDs,
                target: ImageEditorLayerDropTarget(layerID: targetID, placement: placement)
            )
        }
    }

    private func contiguousMovingRanges(
        visibleRowIDs: [UUID],
        movingBlockIDs: Set<UUID>
    ) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var rangeStart: Int?
        for index in visibleRowIDs.indices {
            if movingBlockIDs.contains(visibleRowIDs[index]) {
                rangeStart = rangeStart ?? index
            } else if let start = rangeStart {
                ranges.append(start..<index)
                rangeStart = nil
            }
        }
        if let start = rangeStart {
            ranges.append(start..<visibleRowIDs.count)
        }
        return ranges
    }

    private func layerMovePlan(
        sourceIDs: Set<UUID>,
        target: ImageEditorLayerDropTarget,
        layers: [ImageEditorLayer]
    ) -> ImageEditorLayerMovePlan? {
        guard let targetLayer = layers.first(where: { $0.id == target.layerID }) else { return nil }
        guard target.placement != .insideGroup || targetLayer.isGroup else { return nil }

        let rootSourceIDs = orderingMovableRootLayerIDs(for: sourceIDs, layers: layers)
        guard !rootSourceIDs.isEmpty else { return nil }

        let movingBlockIDs = orderingMovingBlockIDs(for: rootSourceIDs, layers: layers)
        guard !movingBlockIDs.contains(target.layerID) else { return nil }

        let nextParentID = target.placement == .insideGroup ? target.layerID : targetLayer.groupID
        guard orderingCanMoveRoots(rootSourceIDs, toParent: nextParentID, layers: layers) else { return nil }

        var movingLayers = layers.filter { movingBlockIDs.contains($0.id) }
        for index in movingLayers.indices where rootSourceIDs.contains(movingLayers[index].id) {
            movingLayers[index].groupID = nextParentID
        }

        var remainingLayers = layers.filter { !movingBlockIDs.contains($0.id) }
        guard let targetIndex = remainingLayers.firstIndex(where: { $0.id == target.layerID }) else { return nil }
        let insertionIndex = target.placement == .above ? targetIndex + 1 : targetIndex
        remainingLayers.insert(contentsOf: movingLayers, at: insertionIndex)
        if let nextParentID,
           let groupIndex = remainingLayers.firstIndex(where: { $0.id == nextParentID && $0.isGroup }) {
            remainingLayers[groupIndex].isGroupExpanded = true
        }

        guard layerOrderOrParentsDiffer(layers, remainingLayers) else { return nil }
        return ImageEditorLayerMovePlan(
            layers: remainingLayers,
            rootSourceIDs: rootSourceIDs,
            movingBlockIDs: movingBlockIDs
        )
    }

    private func orderingMovableRootLayerIDs(
        for sourceIDs: Set<UUID>,
        layers: [ImageEditorLayer]
    ) -> Set<UUID> {
        let existingSourceIDs = sourceIDs.filter { id in layers.contains { $0.id == id } }
        let selectedGroupIDs = Set(layers.compactMap { layer in
            existingSourceIDs.contains(layer.id) && layer.isGroup ? layer.id : nil
        })
        let descendantIDs = selectedGroupIDs.reduce(into: Set<UUID>()) { result, groupID in
            result.formUnion(orderingDescendantIDs(for: groupID, layers: layers))
        }
        return Set(layers.compactMap { layer in
            guard existingSourceIDs.contains(layer.id),
                  !descendantIDs.contains(layer.id),
                  !orderingIsEffectivelyLocked(layer, layers: layers)
            else { return nil }
            return layer.id
        })
    }

    private func orderingMovingBlockIDs(
        for rootSourceIDs: Set<UUID>,
        layers: [ImageEditorLayer]
    ) -> Set<UUID> {
        rootSourceIDs.reduce(into: rootSourceIDs) { result, layerID in
            guard layers.first(where: { $0.id == layerID })?.isGroup == true else { return }
            result.formUnion(orderingDescendantIDs(for: layerID, layers: layers))
        }
    }

    private func orderingCanMoveRoots(
        _ rootSourceIDs: Set<UUID>,
        toParent parentID: UUID?,
        layers: [ImageEditorLayer]
    ) -> Bool {
        guard let parentID else { return true }
        guard let parent = layers.first(where: { $0.id == parentID && $0.isGroup }),
              !orderingIsEffectivelyLocked(parent, layers: layers)
        else { return false }

        return rootSourceIDs.allSatisfy { rootID in
            guard let root = layers.first(where: { $0.id == rootID }), rootID != parentID else { return false }
            return !root.isGroup || !orderingDescendantIDs(for: rootID, layers: layers).contains(parentID)
        }
    }

    private func orderingDescendantIDs(
        for groupID: UUID,
        layers: [ImageEditorLayer]
    ) -> Set<UUID> {
        var descendantIDs = Set<UUID>()
        var pendingGroupIDs = [groupID]
        while let currentGroupID = pendingGroupIDs.popLast() {
            for layer in layers where layer.groupID == currentGroupID && !descendantIDs.contains(layer.id) {
                descendantIDs.insert(layer.id)
                if layer.isGroup {
                    pendingGroupIDs.append(layer.id)
                }
            }
        }
        return descendantIDs
    }

    private func orderingIsEffectivelyLocked(
        _ layer: ImageEditorLayer,
        layers: [ImageEditorLayer]
    ) -> Bool {
        if layer.isLocked { return true }
        var parentID = layer.groupID
        var visitedIDs = Set<UUID>()
        while let currentParentID = parentID, visitedIDs.insert(currentParentID).inserted {
            guard let parent = layers.first(where: { $0.id == currentParentID }) else { break }
            if parent.isLocked { return true }
            parentID = parent.groupID
        }
        return false
    }

    private func orderingVisibleLayerIDs(in layers: [ImageEditorLayer]) -> [UUID] {
        layers.reversed().compactMap { layer in
            orderingAncestorsAreExpanded(for: layer, layers: layers) ? layer.id : nil
        }
    }

    private func orderingAncestorsAreExpanded(
        for layer: ImageEditorLayer,
        layers: [ImageEditorLayer]
    ) -> Bool {
        var parentID = layer.groupID
        var visitedIDs = Set<UUID>()
        while let currentParentID = parentID, visitedIDs.insert(currentParentID).inserted {
            guard let parent = layers.first(where: { $0.id == currentParentID }) else { return false }
            if !parent.isGroupExpanded { return false }
            parentID = parent.groupID
        }
        return true
    }

    private func layerOrderOrParentsDiffer(
        _ lhs: [ImageEditorLayer],
        _ rhs: [ImageEditorLayer]
    ) -> Bool {
        guard lhs.map(\.id) == rhs.map(\.id) else { return true }
        return zip(lhs, rhs).contains { left, right in
            left.groupID != right.groupID || left.isGroupExpanded != right.isGroupExpanded
        }
    }
}
