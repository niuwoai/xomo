//
//  ImageEditorPathCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import CoreGraphics

private struct ImageEditorPathSegmentHit {
    let layerID: UUID
    let subpathIndex: Int
    let startAnchorIndex: Int
    let endAnchorIndex: Int
    let parameter: CGFloat
    let distance: CGFloat
}

private enum ImageEditorPenPathInsertionHit {
    case control(ImageEditorPenPathControlHit)
    case segment(ImageEditorPathSegmentHit)
}

private struct ImageEditorPenPathControlHit {
    let layerID: UUID
    let subpathIndex: Int
    let anchorIndex: Int
    let role: ImageEditorPathControlRole
}

struct ImageEditorPenAnchorConversionTarget: Equatable {
    let layerID: UUID
    let subpathIndex: Int
    let anchorIndex: Int
    let anchorPoint: CGPoint
    let isBlocked: Bool
}

private struct ImageEditorPenPathContinuationHit {
    let layerID: UUID
    let subpathIndex: Int
    let anchorIndex: Int
}

struct ImageEditorPenPathJoinTarget: Equatable {
    let layerID: UUID
    let endpointIndex: Int
    let anchorPoint: CGPoint
    let isBlocked: Bool
}

enum ImageEditorPenPathSegmentInsertionState: Equatable {
    case none
    case available
    case blocked
}

enum ImageEditorPenAnchorDeletionState: Equatable {
    case none
    case selectionOnly
    case available
    case blocked
}

enum ImageEditorPenPathContinuationState: Equatable {
    case none
    case available
    case blocked
}

enum ImageEditorDirectPathAnchorState: Equatable {
    case none
    case available
    case blocked
    case occluded
}

struct ImageEditorPathSelectionTarget: Equatable {
    let layerID: UUID
    let isBlocked: Bool
}

extension ImageEditorViewModel {
    /// Photoshop's Path Selection tool selects an editable path by its
    /// rendered geometry, rather than by the layer's rectangular bounds.
    /// Closed paths use their fill as the primary hit area; open paths and
    /// strokes use a small, canvas-space tolerance around sampled segments.
    func pathSelectionTarget(at point: CGPoint?) -> ImageEditorPathSelectionTarget? {
        guard let point, point.x.isFinite, point.y.isFinite else { return nil }
        for layer in document.layers.reversed() {
            guard !layer.isGroup,
                  document.isEffectivelyVisible(layer),
                  let content = layer.shapeContent,
                  content.kind == .path,
                  pathLayerContains(point: point, content: content, layer: layer)
            else { continue }
            return ImageEditorPathSelectionTarget(
                layerID: layer.id,
                isBlocked: document.isEffectivelyPositionLocked(layer)
            )
        }
        return nil
    }

    @discardableResult
    func selectPathLayer(at point: CGPoint, extendingSelection: Bool = false) -> Bool {
        guard let target = pathSelectionTarget(at: point), !target.isBlocked else { return false }
        selectLayer(target.layerID, extendingSelection: extendingSelection)
        statusText = L10n.format(
            "imageEditor.status.pathSelected",
            document.selectedLayerIDs.count
        )
        return true
    }

    /// Starts an Illustrator/Photoshop-style direct-selection drag on the
    /// nearest visible path anchor or control handle, switching to its path
    /// layer before the existing anchor transaction begins.
    func directPathAnchorState(at point: CGPoint?) -> ImageEditorDirectPathAnchorState {
        guard let hit = penPathInsertionHit(at: point) else { return .none }
        switch hit {
        case .control(let control):
            guard let layer = document.layers.first(where: { $0.id == control.layerID }) else {
                return .none
            }
            return document.isEffectivelyPixelsLocked(layer)
                || document.isEffectivelyPositionLocked(layer)
                ? .blocked
                : .available
        case .segment(let segment):
            guard let layer = document.layers.first(where: { $0.id == segment.layerID }) else {
                return .none
            }
            return document.isEffectivelyPixelsLocked(layer)
                || document.isEffectivelyPositionLocked(layer)
                ? .blocked
                : .occluded
        }
    }

    @discardableResult
    func beginDirectPathAnchorMove(
        at point: CGPoint?,
        constrainedToAngleIncrement: Bool = false,
        preservingSmoothness: Bool = false
    ) -> Bool {
        guard let point,
              case .control(let hit) = penPathInsertionHit(at: point),
              let layer = document.layers.first(where: { $0.id == hit.layerID }),
              !document.isEffectivelyPixelsLocked(layer),
              !document.isEffectivelyPositionLocked(layer)
        else { return false }

        selectLayer(layer.id)
        selectedPathSubpathIndex = hit.subpathIndex
        selectedPathAnchorIndex = hit.anchorIndex
        selectedPathControlRole = hit.role
        statusText = L10n.format(
            "imageEditor.status.pathAnchorSelected",
            hit.anchorIndex + 1
        )
        return beginMovingPathAnchor(
            at: point,
            constrainedToAngleIncrement: constrainedToAngleIncrement,
            preservingSmoothness: preservingSmoothness
        )
    }

    private func pathLayerContains(
        point: CGPoint,
        content: ImageEditorShapeContent,
        layer: ImageEditorLayer
    ) -> Bool {
        let imageSize = layer.image.size
        let localPoint = CGPoint(
            x: (point.x - layer.frame.minX) / max(layer.frame.width, 1) * max(imageSize.width, 1),
            y: (point.y - layer.frame.minY) / max(layer.frame.height, 1) * max(imageSize.height, 1)
        )
        if content.isPathClosed,
           content.fillOpacity > 0.001,
           content.pathBezierPath().contains(localPoint) {
            return true
        }

        let scale = min(
            layer.frame.width / max(imageSize.width, 1),
            layer.frame.height / max(imageSize.height, 1)
        )
        let tolerance = max(8, content.strokeWidth * max(scale, 0.01) / 2 + 4)
        return pathDistanceToPoint(point, content: content, layer: layer) <= tolerance
    }

    private func pathDistanceToPoint(
        _ point: CGPoint,
        content: ImageEditorShapeContent,
        layer: ImageEditorLayer
    ) -> CGFloat {
        var minimum = CGFloat.greatestFiniteMagnitude
        for anchors in content.allEditablePathSubpaths where anchors.count >= 2 {
            for index in anchors.indices.dropFirst() {
                minimum = min(
                    minimum,
                    cubicPathDistance(
                        from: anchors[index - 1],
                        to: anchors[index],
                        point: point,
                        layer: layer
                    )
                )
            }
            if content.isPathClosed {
                minimum = min(
                    minimum,
                    cubicPathDistance(
                        from: anchors[anchors.count - 1],
                        to: anchors[0],
                        point: point,
                        layer: layer
                    )
                )
            }
        }
        return minimum
    }

    private func cubicPathDistance(
        from first: ImageEditorPathAnchor,
        to second: ImageEditorPathAnchor,
        point: CGPoint,
        layer: ImageEditorLayer
    ) -> CGFloat {
        let start = localToCanvasPoint(first.point, layer: layer)
        let end = localToCanvasPoint(second.point, layer: layer)
        let control1 = localToCanvasPoint(first.outControl ?? first.point, layer: layer)
        let control2 = localToCanvasPoint(second.inControl ?? second.point, layer: layer)
        var minimum = CGFloat.greatestFiniteMagnitude
        var previous = start
        for step in 1...24 {
            let t = CGFloat(step) / 24
            let inverse = 1 - t
            let current = CGPoint(
                x: inverse * inverse * inverse * start.x
                    + 3 * inverse * inverse * t * control1.x
                    + 3 * inverse * t * t * control2.x
                    + t * t * t * end.x,
                y: inverse * inverse * inverse * start.y
                    + 3 * inverse * inverse * t * control1.y
                    + 3 * inverse * t * t * control2.y
                    + t * t * t * end.y
            )
            minimum = min(minimum, distanceFromPoint(point, toSegmentFrom: previous, to: current))
            previous = current
        }
        return minimum
    }

    private func distanceFromPoint(_ point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let vector = CGSize(width: end.x - start.x, height: end.y - start.y)
        let lengthSquared = vector.width * vector.width + vector.height * vector.height
        guard lengthSquared > 0.001 else { return hypot(point.x - start.x, point.y - start.y) }
        let projection = ((point.x - start.x) * vector.width + (point.y - start.y) * vector.height) / lengthSquared
        let factor = max(0, min(1, projection))
        let nearest = CGPoint(x: start.x + vector.width * factor, y: start.y + vector.height * factor)
        return hypot(point.x - nearest.x, point.y - nearest.y)
    }

    func isPenCloseCandidate(at point: CGPoint?) -> Bool {
        guard pendingPenPathPoints.count >= 3,
              let point,
              let first = pendingPenPathPoints.first
        else { return false }
        return distance(from: point, to: first) <= penCloseDistance
    }

    func penPathContinuationState(at point: CGPoint?) -> ImageEditorPenPathContinuationState {
        guard pendingPenPathAnchors.isEmpty,
              let hit = penPathContinuationHit(at: point),
              let layer = document.layers.first(where: { $0.id == hit.layerID })
        else { return .none }
        return document.isEffectivelyPixelsLocked(layer)
            || document.isEffectivelyPositionLocked(layer)
            ? .blocked
            : .available
    }

    func penPathJoinState(at point: CGPoint?) -> ImageEditorPenPathContinuationState {
        guard let target = penPathJoinTarget(at: point) else { return .none }
        return target.isBlocked ? .blocked : .available
    }

    func penPathJoinTarget(at point: CGPoint?) -> ImageEditorPenPathJoinTarget? {
        guard !pendingPenPathAnchors.isEmpty,
              let hit = penPathJoinEndpointHit(at: point),
              let layer = document.layers.first(where: { $0.id == hit.layerID }),
              let content = layer.shapeContent,
              let anchors = content.allEditablePathSubpaths.first,
              anchors.indices.contains(hit.anchorIndex)
        else { return nil }
        return ImageEditorPenPathJoinTarget(
            layerID: hit.layerID,
            endpointIndex: hit.anchorIndex,
            anchorPoint: canvasPoint(anchors[hit.anchorIndex].point, layer: layer),
            isBlocked: document.isEffectivelyPixelsLocked(layer)
                || document.isEffectivelyPositionLocked(layer)
        )
    }

    @discardableResult
    func beginPenPathContinuation(at point: CGPoint?) -> Bool {
        guard let hit = penPathContinuationHit(at: point),
              let layerIndex = document.layers.firstIndex(where: { $0.id == hit.layerID }),
              !document.isEffectivelyPixelsLocked(document.layers[layerIndex]),
              !document.isEffectivelyPositionLocked(document.layers[layerIndex]),
              let content = document.layers[layerIndex].shapeContent,
              content.allEditablePathSubpaths.indices.contains(hit.subpathIndex)
        else { return false }
        var anchors = canvasAnchors(
            for: content.allEditablePathSubpaths[hit.subpathIndex],
            layer: document.layers[layerIndex]
        )
        if hit.anchorIndex == 0 {
            anchors = anchors.reversed().map { anchor in
                ImageEditorPathAnchor(
                    point: anchor.point,
                    inControl: anchor.outControl,
                    outControl: anchor.inControl
                )
            }
        }
        selectLayer(hit.layerID)
        pendingPenContinuationLayerID = hit.layerID
        pendingPenContinuationSubpathIndex = hit.subpathIndex
        pendingPenContinuationInitialAnchorCount = anchors.count
        pendingPenPathAnchors = anchors
        undonePendingPenPathAnchors = []
        selectedPathSubpathIndex = hit.subpathIndex
        selectedPathAnchorIndex = nil
        statusText = L10n.format("imageEditor.status.penPointAdded", anchors.count)
        return true
    }

    /// Starts a drag from the same topmost visible open-path endpoint that
    /// owns Pen continuation. This keeps press-drag consistent with a short
    /// continuation click even when another layer was selected beforehand.
    @discardableResult
    func beginMovingPenPathContinuationAnchor(
        at point: CGPoint?,
        constrainedToAngleIncrement: Bool = false,
        preservingSmoothness: Bool = false
    ) -> Bool {
        guard let hit = penPathContinuationHit(at: point),
              let layer = document.layers.first(where: { $0.id == hit.layerID }),
              !document.isEffectivelyPixelsLocked(layer),
              !document.isEffectivelyPositionLocked(layer)
        else { return false }
        selectLayer(hit.layerID)
        selectedPathSubpathIndex = hit.subpathIndex
        selectedPathAnchorIndex = hit.anchorIndex
        selectedPathControlRole = .anchor
        return beginMovingPathAnchor(
            at: point,
            constrainedToAngleIncrement: constrainedToAngleIncrement,
            preservingSmoothness: preservingSmoothness
        )
    }

    /// Lets Pen select and edit the topmost visible anchor under the pointer.
    /// Handles remain editable only on the already-selected path because
    /// unselected-path handles are not visible interaction targets.
    @discardableResult
    func beginMovingPenPathAnchor(
        at point: CGPoint?,
        constrainedToAngleIncrement: Bool = false,
        preservingSmoothness: Bool = false
    ) -> Bool {
        guard let hit = penPathControlHit(at: point),
              let layer = document.layers.first(where: { $0.id == hit.layerID }),
              !document.isEffectivelyPixelsLocked(layer),
              !document.isEffectivelyPositionLocked(layer)
        else { return false }
        selectLayer(hit.layerID)
        selectedPathSubpathIndex = hit.subpathIndex
        selectedPathAnchorIndex = hit.anchorIndex
        selectedPathControlRole = hit.role
        return beginMovingPathAnchor(
            at: point,
            constrainedToAngleIncrement: constrainedToAngleIncrement,
            preservingSmoothness: preservingSmoothness
        )
    }

    func addPenPoint(_ point: CGPoint?) {
        addPenPoint(
            point,
            symmetricControlDrag: nil,
            constrainedToAngleIncrement: false
        )
    }

    func addPenPoint(
        _ point: CGPoint?,
        constrainedToAngleIncrement: Bool
    ) {
        addPenPoint(
            point,
            symmetricControlDrag: nil,
            constrainedToAngleIncrement: constrainedToAngleIncrement
        )
    }

    func addPenPoint(
        _ point: CGPoint?,
        symmetricControlDrag: CGSize?,
        constrainedToAngleIncrement: Bool
    ) {
        guard let point else { return }
        if isPenCloseCandidate(at: point) {
            finishPenPath(closed: true)
            return
        }
        if joinPendingPenPath(at: point, symmetricControlDrag: symmetricControlDrag) {
            return
        }
        let resolvedPoint: CGPoint
        if constrainedToAngleIncrement, let previousPoint = pendingPenPathPoints.last {
            resolvedPoint = ImageEditorPenPointGeometry.constrainedPoint(
                from: previousPoint,
                toward: point,
                canvasSize: document.canvasSize
            )
        } else {
            resolvedPoint = point
        }
        let controls = symmetricControlDrag.flatMap {
            ImageEditorPenPointGeometry.symmetricControls(
                anchor: resolvedPoint,
                drag: $0,
                canvasSize: document.canvasSize
            )
        }
        undonePendingPenPathAnchors = []
        pendingPenPathAnchors.append(ImageEditorPathAnchor(
            point: resolvedPoint,
            inControl: controls?.inControl,
            outControl: controls?.outControl
        ))
        statusText = L10n.format("imageEditor.status.penPointAdded", pendingPenPathAnchors.count)
    }

    func pendingPenPreviewPoint(
        at point: CGPoint?,
        constrainedToAngleIncrement: Bool
    ) -> CGPoint? {
        guard let point, let previousPoint = pendingPenPathPoints.last else { return nil }
        if isPenCloseCandidate(at: point) {
            return pendingPenPathPoints.first
        }
        if let joinTarget = penPathJoinTarget(at: point) {
            return joinTarget.anchorPoint
        }
        guard constrainedToAngleIncrement else { return point }
        return ImageEditorPenPointGeometry.constrainedPoint(
            from: previousPoint,
            toward: point,
            canvasSize: document.canvasSize
        )
    }

    @discardableResult
    func undoPendingPenPoint() -> Bool {
        guard pendingPenPathAnchors.count > pendingPenContinuationInitialAnchorCount,
              let anchor = pendingPenPathAnchors.popLast()
        else { return false }
        undonePendingPenPathAnchors.append(anchor)
        statusText = pendingPenPathAnchors.isEmpty
            ? L10n.text("imageEditor.status.penReady")
            : L10n.format("imageEditor.status.penPointAdded", pendingPenPathAnchors.count)
        return true
    }

    @discardableResult
    func redoPendingPenPoint() -> Bool {
        guard let anchor = undonePendingPenPathAnchors.popLast() else { return false }
        pendingPenPathAnchors.append(anchor)
        statusText = L10n.format("imageEditor.status.penPointAdded", pendingPenPathAnchors.count)
        return true
    }

    @discardableResult
    func deletePendingPenPointIfNeeded() -> Bool {
        guard hasPendingPenPathTransaction else { return false }
        _ = undoPendingPenPoint()
        return true
    }

    @discardableResult
    func finishPendingPenPathFromKeyboard() -> Bool {
        guard hasPendingPenPathTransaction else { return false }
        finishPenPath(closed: false)
        return true
    }

    @discardableResult
    func beginMovingPathAnchor(
        at point: CGPoint?,
        constrainedToAngleIncrement: Bool = false,
        preservingSmoothness: Bool = false
    ) -> Bool {
        guard let point else { return false }
        if hasActivePathAnchorMoveTransaction {
            _ = cancelMovingPathAnchor()
        }
        guard selectNearestPathAnchor(at: point) else { return false }
        guard let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path
        else { return false }
        movingPathAnchorOriginalLayerID = layer.id
        movingPathAnchorOriginalCanvasSubpaths = content.allEditablePathSubpaths.map {
            canvasAnchors(for: $0, layer: layer)
        }
        movingPathAnchorOriginalFrame = layer.frame
        beginPathAnchorMoveUndoTransaction()
        moveSelectedPathAnchor(
            to: point,
            constrainedToAngleIncrement: constrainedToAngleIncrement,
            preservingSmoothness: preservingSmoothness
        )
        return true
    }

    func moveSelectedPathAnchor(
        to point: CGPoint?,
        constrainedToAngleIncrement: Bool = false,
        preservingSmoothness: Bool = false
    ) {
        guard hasActivePathAnchorMoveTransaction else { return }
        applySelectedPathAnchorMove(to: point,
            constrainedToAngleIncrement: constrainedToAngleIncrement,
            preservingSmoothness: preservingSmoothness)
    }

    private func applySelectedPathAnchorMove(
        to point: CGPoint?,
        constrainedToAngleIncrement: Bool = false,
        preservingSmoothness: Bool = false
    ) {
        guard let point,
              let index = selectedPathAnchorIndex,
              let layerIndex = document.selectedLayerIndex,
              let shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path,
              shapeContent.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex].indices.contains(index),
              !document.isEffectivelyPixelsLocked(document.layers[layerIndex])
        else { return }

        let layer = document.layers[layerIndex]
        var canvasAnchors = canvasAnchors(
            for: shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex],
            layer: layer
        )
        let constraintOrigin: CGPoint = {
            guard constrainedToAngleIncrement else { return point }
            switch selectedPathControlRole {
            case .anchor:
                guard movingPathAnchorOriginalCanvasSubpaths.indices.contains(selectedPathSubpathIndex),
                      movingPathAnchorOriginalCanvasSubpaths[selectedPathSubpathIndex].indices.contains(index)
                else { return canvasAnchors[index].point }
                return movingPathAnchorOriginalCanvasSubpaths[selectedPathSubpathIndex][index].point
            case .inHandle, .outHandle:
                return canvasAnchors[index].point
            }
        }()
        let proposedPoint = constrainedToAngleIncrement
            ? ImageEditorPenPointGeometry.constrainedPoint(
                from: constraintOrigin,
                toward: point,
                canvasSize: document.canvasSize
            )
            : point
        let boundedPoint = CGPoint(
            x: max(0, min(document.canvasSize.width, proposedPoint.x)),
            y: max(0, min(document.canvasSize.height, proposedPoint.y))
        )
        let originalAnchor: ImageEditorPathAnchor? = {
            guard movingPathAnchorOriginalCanvasSubpaths.indices.contains(selectedPathSubpathIndex),
                  movingPathAnchorOriginalCanvasSubpaths[selectedPathSubpathIndex].indices.contains(index)
            else { return nil }
            return movingPathAnchorOriginalCanvasSubpaths[selectedPathSubpathIndex][index]
        }()
        let shouldPreserveSmoothness = preservingSmoothness
            && originalAnchor.map(ImageEditorPenPointGeometry.isSmoothAnchor) == true
        switch selectedPathControlRole {
        case .anchor:
            let current = canvasAnchors[index].point
            guard current != boundedPoint else { return }
            let delta = CGSize(width: boundedPoint.x - current.x, height: boundedPoint.y - current.y)
            canvasAnchors[index].point = boundedPoint
            if let inControl = canvasAnchors[index].inControl {
                canvasAnchors[index].inControl = CGPoint(x: inControl.x + delta.width, y: inControl.y + delta.height)
            }
            if let outControl = canvasAnchors[index].outControl {
                canvasAnchors[index].outControl = CGPoint(x: outControl.x + delta.width, y: outControl.y + delta.height)
            }
        case .inHandle:
            var updatedAnchor = canvasAnchors[index]
            updatedAnchor.inControl = boundedPoint
            if shouldPreserveSmoothness,
               let originalOutControl = originalAnchor?.outControl {
                updatedAnchor.outControl = ImageEditorPenPointGeometry.oppositeControl(
                    anchor: updatedAnchor.point,
                    movedControl: boundedPoint,
                    preferredLength: hypot(
                        originalOutControl.x - updatedAnchor.point.x,
                        originalOutControl.y - updatedAnchor.point.y
                    ),
                    canvasSize: document.canvasSize
                )
            }
            guard !pathPointsMatch(canvasAnchors[index].inControl, updatedAnchor.inControl)
                    || !pathPointsMatch(canvasAnchors[index].outControl, updatedAnchor.outControl)
            else { return }
            canvasAnchors[index] = updatedAnchor
        case .outHandle:
            var updatedAnchor = canvasAnchors[index]
            updatedAnchor.outControl = boundedPoint
            if shouldPreserveSmoothness,
               let originalInControl = originalAnchor?.inControl {
                updatedAnchor.inControl = ImageEditorPenPointGeometry.oppositeControl(
                    anchor: updatedAnchor.point,
                    movedControl: boundedPoint,
                    preferredLength: hypot(
                        originalInControl.x - updatedAnchor.point.x,
                        originalInControl.y - updatedAnchor.point.y
                    ),
                    canvasSize: document.canvasSize
                )
            }
            guard !pathPointsMatch(canvasAnchors[index].inControl, updatedAnchor.inControl)
                    || !pathPointsMatch(canvasAnchors[index].outControl, updatedAnchor.outControl)
            else { return }
            canvasAnchors[index] = updatedAnchor
        }
        updatePathLayer(
            at: layerIndex,
            shapeContent: shapeContent,
            canvasAnchors: canvasAnchors,
            editingSubpathIndex: selectedPathSubpathIndex
        )
    }

    func finishMovingPathAnchor() {
        guard movingPathAnchorOriginalLayerID != nil else { return }
        let didChange = movingPathAnchorTransactionHasFinalChange
        finishPathAnchorMoveUndoTransaction(didChange: didChange)
        resetMovingPathAnchorTransaction()
        guard didChange else {
            updateStatus()
            return
        }
        appendHistory(L10n.text("imageEditor.history.pathAnchorMove"))
        statusText = L10n.text("imageEditor.status.pathAnchorMoved")
    }

    @discardableResult
    func cancelMovingPathAnchor() -> Bool {
        guard movingPathAnchorOriginalLayerID != nil,
              cancelPathAnchorMoveUndoTransaction()
        else { return false }
        resetMovingPathAnchorTransaction()
        updateStatus()
        return true
    }

    /// A discrete inspector or automation command must not inherit the
    /// temporary geometry and private Undo snapshot owned by a pointer drag.
    /// The first command cancels that drag; a later command can then edit the
    /// restored path as an independent transaction.
    @discardableResult
    func cancelPathAnchorDragBeforeDiscreteCommand() -> Bool {
        cancelMovingPathAnchor()
    }

    func setSelectedPathAnchorX(_ x: CGFloat) {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard let point = selectedPathAnchorCanvasPoint else { return }
        setSelectedPathAnchorPosition(CGPoint(x: x, y: point.y))
    }

    func setSelectedPathAnchorY(_ y: CGFloat) {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard let point = selectedPathAnchorCanvasPoint else { return }
        setSelectedPathAnchorPosition(CGPoint(x: point.x, y: y))
    }

    /// Keyboard nudges move the selected anchor with the same one-step
    /// History semantics as dragging it on the canvas.
    func nudgeSelectedPathAnchor(by delta: CGSize) {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard let point = selectedPathAnchorCanvasPoint else { return }
        setSelectedPathAnchorPosition(
            CGPoint(x: point.x + delta.width, y: point.y + delta.height)
        )
    }

    func selectNextPathAnchor() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              !pathAnchorReferences(for: content).isEmpty
        else { return }
        let references = pathAnchorReferences(for: content)
        let currentIndex = currentPathAnchorReferenceIndex(in: references) ?? -1
        let nextReference = references[(currentIndex + 1) % references.count]
        selectedPathSubpathIndex = nextReference.subpathIndex
        selectedPathAnchorIndex = nextReference.anchorIndex
        selectedPathControlRole = .anchor
    }

    func selectPreviousPathAnchor() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              !pathAnchorReferences(for: content).isEmpty
        else { return }
        let references = pathAnchorReferences(for: content)
        let currentIndex = currentPathAnchorReferenceIndex(in: references) ?? 0
        let previousReference = references[(currentIndex - 1 + references.count) % references.count]
        selectedPathSubpathIndex = previousReference.subpathIndex
        selectedPathAnchorIndex = previousReference.anchorIndex
        selectedPathControlRole = .anchor
    }

    var canSelectAdjacentPathSubpath: Bool {
        guard selectedLayerCount == 1,
              let content = document.selectedLayer?.shapeContent,
              content.kind == .path
        else { return false }
        return content.allEditablePathSubpaths.count > 1
    }

    func selectNextPathSubpath() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        selectAdjacentPathSubpath(offset: 1)
    }

    func selectPreviousPathSubpath() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        selectAdjacentPathSubpath(offset: -1)
    }

    func smoothSelectedPathAnchor() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard let index = selectedPathAnchorIndex,
              let layerIndex = document.selectedLayerIndex,
              let shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path,
              shapeContent.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex].indices.contains(index),
              !document.isEffectivelyPixelsLocked(document.layers[layerIndex])
        else { return }
        var canvasAnchors = canvasAnchors(
            for: shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex],
            layer: document.layers[layerIndex]
        )
        let anchor = canvasAnchors[index].point
        let previousPoint = neighboringPathPoint(before: index, in: canvasAnchors, closed: shapeContent.isPathClosed) ?? anchor
        let nextPoint = neighboringPathPoint(after: index, in: canvasAnchors, closed: shapeContent.isPathClosed) ?? anchor
        let vector = CGSize(width: nextPoint.x - previousPoint.x, height: nextPoint.y - previousPoint.y)
        guard hypot(vector.width, vector.height) > 1 else { return }
        let scale: CGFloat = 1 / 6
        let nextInControl = clampedCanvasPoint(
            CGPoint(x: anchor.x - vector.width * scale, y: anchor.y - vector.height * scale)
        )
        let nextOutControl = clampedCanvasPoint(
            CGPoint(x: anchor.x + vector.width * scale, y: anchor.y + vector.height * scale)
        )
        guard !pathPointsMatch(canvasAnchors[index].inControl, nextInControl)
                || !pathPointsMatch(canvasAnchors[index].outControl, nextOutControl)
        else { return }
        canvasAnchors[index].inControl = nextInControl
        canvasAnchors[index].outControl = nextOutControl

        pushUndo()
        updatePathLayer(
            at: layerIndex,
            shapeContent: shapeContent,
            canvasAnchors: canvasAnchors,
            editingSubpathIndex: selectedPathSubpathIndex
        )
        selectedPathControlRole = .outHandle
        appendHistory(L10n.text("imageEditor.history.pathHandlesUpdate"))
        statusText = L10n.text("imageEditor.status.pathHandlesSmoothed")
    }

    var canSymmetrizeSelectedPathAnchorHandles: Bool {
        guard let index = selectedPathAnchorIndex,
              selectedLayerCount == 1,
              let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              content.allEditablePathSubpaths[selectedPathSubpathIndex].indices.contains(index),
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        let anchors = content.allEditablePathSubpaths[selectedPathSubpathIndex]
        let anchor = anchors[index]
        if anchor.inControl != nil || anchor.outControl != nil {
            return true
        }
        return neighboringPathPoint(before: index, in: anchors, closed: content.isPathClosed) != nil
            && neighboringPathPoint(after: index, in: anchors, closed: content.isPathClosed) != nil
    }

    func symmetrizeSelectedPathAnchorHandles() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard canSymmetrizeSelectedPathAnchorHandles,
              let index = selectedPathAnchorIndex,
              let layerIndex = document.selectedLayerIndex,
              let shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        guard shapeContent.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex].indices.contains(index)
        else { return }

        var canvasAnchors = canvasAnchors(
            for: shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex],
            layer: document.layers[layerIndex]
        )
        guard let target = symmetricPathControls(
            at: index,
            in: canvasAnchors,
            closed: shapeContent.isPathClosed,
            selectedRole: selectedPathControlRole
        ) else { return }
        guard !pathPointsMatch(canvasAnchors[index].inControl, target.inControl)
                || !pathPointsMatch(canvasAnchors[index].outControl, target.outControl)
        else { return }
        canvasAnchors[index].inControl = target.inControl
        canvasAnchors[index].outControl = target.outControl

        pushUndo()
        updatePathLayer(
            at: layerIndex,
            shapeContent: shapeContent,
            canvasAnchors: canvasAnchors,
            editingSubpathIndex: selectedPathSubpathIndex
        )
        selectedPathControlRole = .outHandle
        appendHistory(L10n.text("imageEditor.history.pathHandlesSymmetric"))
        statusText = L10n.text("imageEditor.status.pathHandlesSymmetric")
    }

    var canMoveSelectedPathSubpath: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              !content.allEditablePathSubpaths[selectedPathSubpathIndex].isEmpty,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        return true
    }

    var canDuplicateSelectedPathSubpath: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              !content.allEditablePathSubpaths[selectedPathSubpathIndex].isEmpty,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        return true
    }

    var selectedPathComponentOperation: ImageEditorPathComponentOperation? {
        guard selectedLayerCount == 1,
              let content = document.selectedLayer?.shapeContent,
              content.kind == .path,
              content.isPathClosed,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex)
        else { return nil }
        let operation = content.resolvedPathComponentOperations[selectedPathSubpathIndex]
        return selectedPathSubpathIndex == 0 && operation == .continuePrevious ? .exclude : operation
    }

    var canChangeSelectedPathComponentOperation: Bool {
        guard let layer = document.selectedLayer,
              selectedPathComponentOperation != nil,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        return true
    }

    func canSetSelectedPathComponentOperation(_ operation: ImageEditorPathComponentOperation) -> Bool {
        canChangeSelectedPathComponentOperation
            && !(selectedPathSubpathIndex == 0 && operation == .continuePrevious)
    }

    func setSelectedPathComponentOperation(_ operation: ImageEditorPathComponentOperation) {
        guard !cancelPathAnchorDragBeforeDiscreteCommand(),
              canSetSelectedPathComponentOperation(operation),
              let layerIndex = document.selectedLayerIndex,
              var content = document.layers[layerIndex].shapeContent,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex)
        else { return }
        guard let currentOperation = selectedPathComponentOperation else { return }
        guard currentOperation != operation else { return }

        var operations = content.resolvedPathComponentOperations
        operations[selectedPathSubpathIndex] = operation
        content.pathComponentOperations = operations

        pushUndo()
        document.layers[layerIndex].kind = .shape(content)
        appendHistory(L10n.text("imageEditor.history.pathComponentOperation"))
        statusText = L10n.text("imageEditor.status.pathComponentOperation")
    }

    func nudgeSelectedPathSubpath(dx: CGFloat, dy: CGFloat) {
        moveSelectedPathSubpath(by: CGSize(width: dx, height: dy))
    }

    func moveSelectedPathSubpath(by delta: CGSize) {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard canMoveSelectedPathSubpath,
              delta != .zero,
              let layerIndex = document.selectedLayerIndex,
              let shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex)
        else { return }

        let layer = document.layers[layerIndex]
        var canvasAnchors = canvasAnchors(
            for: shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex],
            layer: layer
        )
        let bounds = pathBounds(canvasAnchors)
        let boundedDelta = CGSize(
            width: min(max(delta.width, -bounds.minX), document.canvasSize.width - bounds.maxX),
            height: min(max(delta.height, -bounds.minY), document.canvasSize.height - bounds.maxY)
        )
        guard boundedDelta != .zero else { return }

        canvasAnchors = canvasAnchors.map { anchor in
            offsetPathAnchor(anchor, by: boundedDelta)
        }

        pushUndo()
        updatePathLayer(
            at: layerIndex,
            shapeContent: shapeContent,
            canvasAnchors: canvasAnchors,
            editingSubpathIndex: selectedPathSubpathIndex
        )
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathSubpathMove"))
        statusText = L10n.text("imageEditor.status.pathSubpathMoved")
    }

    var canMoveSelectedPathSubpathEarlier: Bool {
        canReorderSelectedPathSubpath(by: -1)
    }

    var canMoveSelectedPathSubpathLater: Bool {
        canReorderSelectedPathSubpath(by: 1)
    }

    private func canReorderSelectedPathSubpath(by offset: Int) -> Bool {
        guard abs(offset) == 1,
              canMoveSelectedPathSubpath,
              let content = document.selectedLayer?.shapeContent
        else { return false }
        let targetIndex = selectedPathSubpathIndex + offset
        guard content.allEditablePathSubpaths.indices.contains(targetIndex) else { return false }

        var operations = content.resolvedPathComponentOperations
        operations.swapAt(selectedPathSubpathIndex, targetIndex)
        return operations.first != .continuePrevious
    }

    func reorderSelectedPathSubpath(by offset: Int) {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard canReorderSelectedPathSubpath(by: offset),
              let layerIndex = document.selectedLayerIndex,
              let content = document.layers[layerIndex].shapeContent
        else { return }

        let targetIndex = selectedPathSubpathIndex + offset
        let layer = document.layers[layerIndex]
        let reordered = reorderedPathSubpaths(
            from: selectedPathSubpathIndex,
            to: targetIndex,
            content: content,
            layer: layer
        )

        pushUndo()
        updatePathLayer(at: layerIndex, shapeContent: reordered.content, canvasSubpaths: reordered.subpaths)
        selectedPathSubpathIndex = targetIndex
        appendHistory(L10n.text("imageEditor.history.pathSubpathReorder"))
        statusText = L10n.text("imageEditor.status.pathSubpathReordered")
    }

    private func reorderedPathSubpaths(
        from sourceIndex: Int,
        to targetIndex: Int,
        content: ImageEditorShapeContent,
        layer: ImageEditorLayer
    ) -> (content: ImageEditorShapeContent, subpaths: [[ImageEditorPathAnchor]]) {
        var canvasSubpaths = content.allEditablePathSubpaths.map { subpath in
            canvasAnchors(for: subpath, layer: layer)
        }
        var updatedContent = content
        if !content.pathComponentOperations.isEmpty {
            var operations = content.resolvedPathComponentOperations
            operations.swapAt(sourceIndex, targetIndex)
            updatedContent.pathComponentOperations = operations
        }
        canvasSubpaths.swapAt(sourceIndex, targetIndex)
        return (updatedContent, canvasSubpaths)
    }

    func duplicateSelectedPathSubpath() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard canDuplicateSelectedPathSubpath,
              let layerIndex = document.selectedLayerIndex,
              let shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path,
              shapeContent.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let layer = document.layers[layerIndex]
        var canvasSubpaths = shapeContent.allEditablePathSubpaths.map { subpath in
            canvasAnchors(for: subpath, layer: layer)
        }
        guard canvasSubpaths.indices.contains(selectedPathSubpathIndex) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let sourceAnchors = canvasSubpaths[selectedPathSubpathIndex]
        let offset = duplicatePathSubpathOffset(for: sourceAnchors)
        let duplicatedAnchors = sourceAnchors.map { anchor in
            offsetPathAnchor(anchor, by: offset)
        }
        let insertionIndex = selectedPathSubpathIndex + 1
        var updatedShapeContent = shapeContent
        var operations = shapeContent.resolvedPathComponentOperations
        operations.insert(operations[selectedPathSubpathIndex], at: insertionIndex)
        updatedShapeContent.pathComponentOperations = operations

        pushUndo()
        canvasSubpaths.insert(duplicatedAnchors, at: insertionIndex)
        updatePathLayer(at: layerIndex, shapeContent: updatedShapeContent, canvasSubpaths: canvasSubpaths)
        selectedPathSubpathIndex = insertionIndex
        selectedPathAnchorIndex = duplicatedAnchors.isEmpty ? nil : 0
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathSubpathDuplicate"))
        statusText = L10n.text("imageEditor.status.pathSubpathDuplicated")
    }

    func clearSelectedPathAnchorHandles() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard let index = selectedPathAnchorIndex,
              let layerIndex = document.selectedLayerIndex,
              let shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path,
              shapeContent.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex].indices.contains(index),
              !document.isEffectivelyPixelsLocked(document.layers[layerIndex])
        else { return }
        var canvasAnchors = canvasAnchors(
            for: shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex],
            layer: document.layers[layerIndex]
        )
        guard canvasAnchors[index].inControl != nil || canvasAnchors[index].outControl != nil else { return }
        canvasAnchors[index].inControl = nil
        canvasAnchors[index].outControl = nil

        pushUndo()
        updatePathLayer(
            at: layerIndex,
            shapeContent: shapeContent,
            canvasAnchors: canvasAnchors,
            editingSubpathIndex: selectedPathSubpathIndex
        )
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathHandlesUpdate"))
        statusText = L10n.text("imageEditor.status.pathHandlesCleared")
    }

    func isPenCornerConversionCandidate(at point: CGPoint?) -> Bool {
        penCornerConversionAnchorPoint(at: point) != nil
    }

    func penAnchorDeletionState(at point: CGPoint?) -> ImageEditorPenAnchorDeletionState {
        guard pendingPenPathAnchors.isEmpty,
              let hit = penPathControlHit(at: point),
              hit.role == .anchor,
              let layer = document.layers.first(where: { $0.id == hit.layerID }),
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.indices.contains(hit.subpathIndex),
              content.allEditablePathSubpaths[hit.subpathIndex].indices.contains(hit.anchorIndex)
        else { return .none }
        let anchors = content.allEditablePathSubpaths[hit.subpathIndex]
        if !content.isPathClosed,
           content.allEditablePathSubpaths.count == 1,
           hit.anchorIndex == 0 || hit.anchorIndex == anchors.count - 1 {
            return .none
        }
        if document.isEffectivelyPixelsLocked(layer)
            || document.isEffectivelyPositionLocked(layer) {
            return .blocked
        }
        let count = anchors.count
        let canDelete = content.isPathClosed ? count >= 3 : count > 2
        return canDelete ? .available : .selectionOnly
    }

    func finishPenAnchorInteraction(
        deletionState: ImageEditorPenAnchorDeletionState,
        shouldDelete: Bool
    ) {
        if deletionState == .available, shouldDelete {
            _ = cancelMovingPathAnchor()
            deleteSelectedPathAnchor()
        } else if deletionState == .blocked {
            _ = cancelMovingPathAnchor()
        } else {
            finishMovingPathAnchor()
        }
    }

    func isPenPathSegmentInsertionCandidate(at point: CGPoint?) -> Bool {
        penPathSegmentInsertionState(at: point) != .none
    }

    func isPenPathSegmentInsertionBlocked(at point: CGPoint?) -> Bool {
        penPathSegmentInsertionState(at: point) == .blocked
    }

    func penPathSegmentInsertionState(
        at point: CGPoint?
    ) -> ImageEditorPenPathSegmentInsertionState {
        guard let hit = penPathSegmentHit(at: point),
              let layer = document.layers.first(where: { $0.id == hit.layerID })
        else { return .none }
        return document.isEffectivelyPixelsLocked(layer)
            || document.isEffectivelyPositionLocked(layer)
            ? .blocked
            : .available
    }

    /// Inserts an anchor at the pointer's actual position on the nearest
    /// topmost visible path segment. Returning true means that path consumed
    /// the click, including its controls and locked segments, so Pen cannot
    /// accidentally edit through it or begin a new path on top of it.
    @discardableResult
    func insertPathAnchor(at point: CGPoint?) -> Bool {
        guard let target = penPathInsertionHit(at: point) else { return false }
        guard case .segment(let hit) = target else { return true }
        guard let layerIndex = document.layers.firstIndex(where: { $0.id == hit.layerID }),
              let shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path,
              shapeContent.allEditablePathSubpaths.indices.contains(hit.subpathIndex)
        else { return false }

        guard !document.isEffectivelyPixelsLocked(document.layers[layerIndex]),
              !document.isEffectivelyPositionLocked(document.layers[layerIndex])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return true
        }
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return true }
        selectLayer(hit.layerID)
        selectedPathSubpathIndex = hit.subpathIndex
        selectedPathAnchorIndex = hit.startAnchorIndex
        selectedPathControlRole = .anchor

        var canvasAnchors = canvasAnchors(
            for: shapeContent.allEditablePathSubpaths[hit.subpathIndex],
            layer: document.layers[layerIndex]
        )
        guard canvasAnchors.indices.contains(hit.startAnchorIndex),
              canvasAnchors.indices.contains(hit.endAnchorIndex)
        else { return true }
        let split = splitPathSegment(
            from: canvasAnchors[hit.startAnchorIndex],
            to: canvasAnchors[hit.endAnchorIndex],
            at: hit.parameter
        )
        canvasAnchors[hit.startAnchorIndex] = split.start
        canvasAnchors[hit.endAnchorIndex] = split.end
        let insertionIndex = hit.startAnchorIndex + 1
        canvasAnchors.insert(split.inserted, at: insertionIndex)

        pushUndo()
        updatePathLayer(
            at: layerIndex,
            shapeContent: shapeContent,
            canvasAnchors: canvasAnchors,
            editingSubpathIndex: hit.subpathIndex
        )
        selectedPathAnchorIndex = insertionIndex
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathAnchorInsert"))
        statusText = L10n.text("imageEditor.status.pathAnchorInserted")
        return true
    }

    func penCornerConversionAnchorPoint(at point: CGPoint?) -> CGPoint? {
        penAnchorConversionTarget(at: point)?.anchorPoint
    }

    func isPenCornerConversionBlocked(at point: CGPoint?) -> Bool {
        penAnchorConversionTarget(at: point)?.isBlocked == true
    }

    func penAnchorConversionTarget(
        at point: CGPoint?
    ) -> ImageEditorPenAnchorConversionTarget? {
        guard pendingPenPathAnchors.isEmpty,
              let hit = penPathControlHit(at: point),
              hit.role == .anchor,
              let layer = document.layers.first(where: { $0.id == hit.layerID }),
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.indices.contains(hit.subpathIndex),
              content.allEditablePathSubpaths[hit.subpathIndex].indices.contains(hit.anchorIndex)
        else { return nil }
        return ImageEditorPenAnchorConversionTarget(
            layerID: hit.layerID,
            subpathIndex: hit.subpathIndex,
            anchorIndex: hit.anchorIndex,
            anchorPoint: canvasPoint(
                content.allEditablePathSubpaths[hit.subpathIndex][hit.anchorIndex].point,
                layer: layer
            ),
            isBlocked: document.isEffectivelyPixelsLocked(layer)
        )
    }

    var isMovingSmoothPathControlHandle: Bool {
        guard selectedPathControlRole != .anchor,
              movingPathAnchorOriginalCanvasSubpaths.indices.contains(selectedPathSubpathIndex),
              let index = selectedPathAnchorIndex,
              movingPathAnchorOriginalCanvasSubpaths[selectedPathSubpathIndex].indices.contains(index)
        else { return false }
        return ImageEditorPenPointGeometry.isSmoothAnchor(
            movingPathAnchorOriginalCanvasSubpaths[selectedPathSubpathIndex][index]
        )
    }

    func isSmoothPathControlHandle(
        at point: CGPoint?,
        includingUnselectedPaths: Bool
    ) -> Bool {
        guard let point else { return false }
        let layers = includingUnselectedPaths
            ? Array(document.layers.reversed())
            : document.selectedLayer.map { [$0] } ?? []
        for layer in layers {
            guard !layer.isGroup,
                  document.isEffectivelyVisible(layer),
                  !document.isEffectivelyPixelsLocked(layer),
                  !document.isEffectivelyPositionLocked(layer),
                  let content = layer.shapeContent,
                  content.kind == .path
            else { continue }
            let nearest = pathControlCandidates(for: content, layer: layer)
                .map { candidate in
                    (candidate: candidate, distance: distance(from: point, to: candidate.point))
                }
                .min { lhs, rhs in lhs.distance < rhs.distance }
            guard let nearest, nearest.distance <= pathAnchorHitDistance else { continue }
            guard nearest.candidate.role != .anchor,
                  content.allEditablePathSubpaths.indices.contains(nearest.candidate.subpathIndex),
                  content.allEditablePathSubpaths[nearest.candidate.subpathIndex].indices.contains(
                    nearest.candidate.index
                  )
            else { return false }
            return ImageEditorPenPointGeometry.isSmoothAnchor(
                content.allEditablePathSubpaths[nearest.candidate.subpathIndex][nearest.candidate.index]
            )
        }
        return false
    }

    /// Option-click temporarily turns the Pen into Photoshop's Convert Point
    /// action. Returning true means the existing anchor consumed the pointer
    /// sequence, including an already-corner or locked anchor, so the same
    /// click can never fall through and append a new path point.
    @discardableResult
    func convertPathAnchorToCorner(at point: CGPoint?) -> Bool {
        convertPathAnchor(at: point, symmetricControlDrag: nil)
    }

    /// A short Option-click clears both handles; an Option-drag supplies a
    /// new equal-and-opposite vector and turns the same anchor into a smooth
    /// point. Both forms remain one atomic path-history command.
    @discardableResult
    func convertPathAnchor(
        at point: CGPoint?,
        symmetricControlDrag: CGSize?
    ) -> Bool {
        guard let target = penAnchorConversionTarget(at: point) else { return false }
        return convertPathAnchor(target: target, symmetricControlDrag: symmetricControlDrag)
    }

    @discardableResult
    func convertPathAnchor(
        target: ImageEditorPenAnchorConversionTarget,
        symmetricControlDrag: CGSize?
    ) -> Bool {
        guard pendingPenPathAnchors.isEmpty,
              let layerIndex = document.layers.firstIndex(where: { $0.id == target.layerID }),
              let shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path,
              shapeContent.allEditablePathSubpaths.indices.contains(target.subpathIndex),
              shapeContent.allEditablePathSubpaths[target.subpathIndex].indices.contains(
                target.anchorIndex
              )
        else { return false }
        guard !document.isEffectivelyPixelsLocked(document.layers[layerIndex]) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return true
        }
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return true }
        selectLayer(target.layerID)
        selectedPathSubpathIndex = target.subpathIndex
        selectedPathAnchorIndex = target.anchorIndex
        selectedPathControlRole = .anchor

        var canvasAnchors = canvasAnchors(
            for: shapeContent.allEditablePathSubpaths[target.subpathIndex],
            layer: document.layers[layerIndex]
        )
        let targetControls = symmetricControlDrag.flatMap {
            ImageEditorPenPointGeometry.symmetricControls(
                anchor: canvasAnchors[target.anchorIndex].point,
                drag: $0,
                canvasSize: document.canvasSize
            )
        }
        let targetInControl = targetControls?.inControl
        let targetOutControl = targetControls?.outControl
        guard !pathPointsMatch(
            canvasAnchors[target.anchorIndex].inControl,
            targetInControl
        ) || !pathPointsMatch(
            canvasAnchors[target.anchorIndex].outControl,
            targetOutControl
        ) else {
            statusText = L10n.format(
                "imageEditor.status.pathAnchorSelected",
                target.anchorIndex + 1
            )
            return true
        }
        canvasAnchors[target.anchorIndex].inControl = targetInControl
        canvasAnchors[target.anchorIndex].outControl = targetOutControl

        pushUndo()
        updatePathLayer(
            at: layerIndex,
            shapeContent: shapeContent,
            canvasAnchors: canvasAnchors,
            editingSubpathIndex: target.subpathIndex
        )
        appendHistory(L10n.text("imageEditor.history.pathHandlesUpdate"))
        statusText = L10n.text(
            targetControls == nil
                ? "imageEditor.status.pathHandlesCleared"
                : "imageEditor.status.pathHandlesSmoothed"
        )
        return true
    }

    var canLoadSelectionFromSelectedPath: Bool {
        guard selectedLayerCount == 1,
              let content = document.selectedLayer?.shapeContent,
              content.kind == .path,
              content.isPathClosed,
              content.editablePathAnchors.count >= 3
        else { return false }
        return true
    }

    var canCreatePathFromSelection: Bool {
        guard let selection = document.selection,
              !selection.isInverted
        else { return false }
        if let mask = selection.rasterMask {
            return mask.alpha.contains { $0 > 0 }
        }
        return selection.points.count >= 3
    }

    var canApplySelectedPathAsVectorMask: Bool {
        guard selectedLayerCount == 1,
              let sourceIndex = document.selectedLayerIndex,
              let sourceContent = document.layers[sourceIndex].shapeContent,
              sourceContent.kind == .path,
              sourceContent.isPathClosed,
              sourceContent.editablePathAnchors.count >= 3,
              let targetIndex = vectorMaskTargetIndex(below: sourceIndex)
        else { return false }
        let targetLayer = document.layers[targetIndex]
        return !targetLayer.isGroup && !document.isEffectivelyLocked(targetLayer)
    }

    var canApplySelectedPathAsLayerMask: Bool {
        guard selectedLayerCount == 1,
              let sourceIndex = document.selectedLayerIndex,
              let sourceContent = document.layers[sourceIndex].shapeContent,
              sourceContent.kind == .path,
              sourceContent.isPathClosed,
              sourceContent.editablePathAnchors.count >= 3,
              let targetIndex = pathLayerMaskTargetIndex(below: sourceIndex)
        else { return false }
        let targetLayer = document.layers[targetIndex]
        return !document.isEffectivelyLocked(targetLayer) && targetLayer.mask == nil
    }

    var canEditSelectedVectorMaskAsPath: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              let vectorMask = layer.vectorMask,
              vectorMask.kind == .path,
              vectorMask.isPathClosed,
              vectorMask.editablePathAnchors.count >= 3
        else { return false }
        return !document.isEffectivelyLocked(layer)
    }

    var canDeleteSelectedPathAnchor: Bool {
        guard let index = selectedPathAnchorIndex,
              selectedLayerCount == 1,
              let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              content.allEditablePathSubpaths[selectedPathSubpathIndex].indices.contains(index),
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        let anchorCount = content.allEditablePathSubpaths[selectedPathSubpathIndex].count
        return content.isPathClosed ? anchorCount >= 3 : anchorCount > 2
    }

    var canDeleteSelectedPathSubpath: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.count > 1,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        return true
    }

    var canInsertPathAnchorAfterSelection: Bool {
        guard let index = selectedPathAnchorIndex,
              selectedLayerCount == 1,
              let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              content.allEditablePathSubpaths[selectedPathSubpathIndex].indices.contains(index),
              content.allEditablePathSubpaths[selectedPathSubpathIndex].count >= 2,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        return content.isPathClosed || index + 1 < content.allEditablePathSubpaths[selectedPathSubpathIndex].count
    }

    var selectedPathIsClosed: Bool {
        guard selectedLayerCount == 1,
              let content = document.selectedLayer?.shapeContent,
              content.kind == .path
        else { return false }
        return content.isPathClosed
    }

    var canToggleSelectedPathClosed: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              content.allEditablePathSubpaths[selectedPathSubpathIndex].count >= 2,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        return content.isPathClosed || content.allEditablePathSubpaths[selectedPathSubpathIndex].count >= 3
    }

    var canReverseSelectedPathDirection: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              content.allEditablePathSubpaths[selectedPathSubpathIndex].count >= 2,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        return true
    }

    var canStrokeSelectedPathToPixelLayer: Bool {
        guard selectedLayerCount == 1,
              let sourceIndex = document.selectedLayerIndex,
              let sourceContent = document.layers[sourceIndex].shapeContent,
              sourceContent.kind == .path,
              sourceContent.editablePathAnchors.count >= 2,
              let targetIndex = pathPixelTargetIndex(below: sourceIndex)
        else { return false }
        return !document.isEffectivelyPixelsLocked(document.layers[targetIndex])
    }

    var canFillSelectedPathToPixelLayer: Bool {
        guard selectedLayerCount == 1,
              let sourceIndex = document.selectedLayerIndex,
              let sourceContent = document.layers[sourceIndex].shapeContent,
              sourceContent.kind == .path,
              sourceContent.isPathClosed,
              sourceContent.editablePathAnchors.count >= 3,
              let targetIndex = pathPixelTargetIndex(below: sourceIndex)
        else { return false }
        return !document.isEffectivelyPixelsLocked(document.layers[targetIndex])
    }

    func applySelectedPathAsVectorMask() {
        guard canApplySelectedPathAsVectorMask,
              let sourceIndex = document.selectedLayerIndex,
              let sourceContent = document.layers[sourceIndex].shapeContent,
              let targetIndex = vectorMaskTargetIndex(below: sourceIndex),
              let vectorMask = vectorMaskContent(from: sourceContent, sourceLayer: document.layers[sourceIndex], targetLayer: document.layers[targetIndex])
        else {
            statusText = L10n.text("imageEditor.status.pathVectorMaskFailed")
            return
        }

        let targetID = document.layers[targetIndex].id
        let preservesImportedInversion = document.layers[sourceIndex].isVectorMaskInverted
        pushUndo()
        document.layers[targetIndex].vectorMask = vectorMask
        document.layers[targetIndex].isVectorMaskEnabled = true
        document.layers[targetIndex].isVectorMaskInverted = preservesImportedInversion
        document.layers.remove(at: sourceIndex)
        document.selectedLayerID = targetID
        document.selectedLayerIDs = [targetID]
        selectedPathSubpathIndex = 0
        selectedPathAnchorIndex = nil
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathVectorMask"))
        statusText = L10n.text("imageEditor.status.pathVectorMask")
    }

    func applySelectedPathAsLayerMask() {
        guard canApplySelectedPathAsLayerMask,
              let sourceIndex = document.selectedLayerIndex,
              let sourceContent = document.layers[sourceIndex].shapeContent,
              let targetIndex = pathLayerMaskTargetIndex(below: sourceIndex),
              let mask = layerMaskContent(from: sourceContent, sourceLayer: document.layers[sourceIndex], targetLayer: document.layers[targetIndex])
        else {
            statusText = L10n.text("imageEditor.status.pathLayerMaskFailed")
            return
        }

        pushUndo()
        document.layers[targetIndex].mask = mask.normalizedBitmapImage()
        document.layers[targetIndex].isMaskEnabled = true
        document.layers[targetIndex].isMaskLinked = true
        document.layers[targetIndex].maskDensity = 1
        document.layers[targetIndex].maskFeather = 0
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.pathLayerMask"))
        statusText = L10n.text("imageEditor.status.pathLayerMask")
    }

    func editSelectedVectorMaskAsPath() {
        guard canEditSelectedVectorMaskAsPath,
              let targetIndex = document.selectedLayerIndex,
              let vectorMask = document.layers[targetIndex].vectorMask,
              let pathLayer = vectorMaskPathLayer(from: vectorMask, targetLayer: document.layers[targetIndex])
        else {
            statusText = L10n.text("imageEditor.status.vectorMaskEditFailed")
            return
        }

        let insertionIndex = min(targetIndex + 1, document.layers.count)
        pushUndo()
        document.layers[targetIndex].vectorMask = nil
        document.layers[targetIndex].isVectorMaskEnabled = true
        document.layers[targetIndex].isVectorMaskInverted = false
        document.layers.insert(pathLayer, at: insertionIndex)
        document.selectedLayerID = pathLayer.id
        document.selectedLayerIDs = [pathLayer.id]
        selectedPathSubpathIndex = 0
        selectedPathAnchorIndex = 0
        selectedPathControlRole = .anchor
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.vectorMaskEditPath"))
        statusText = L10n.text("imageEditor.status.vectorMaskEditPath")
    }

    func loadSelectionFromSelectedPath() {
        guard canLoadSelectionFromSelectedPath,
              let layer = document.selectedLayer,
              let content = layer.shapeContent,
              let selection = pathSelection(from: content, layer: layer)
        else {
            statusText = L10n.text("imageEditor.status.pathSelectionFailed")
            return
        }

        applyPathSelection(
            selection,
            replaceHistoryKey: "imageEditor.history.selectionFromPath",
            successStatus: L10n.text("imageEditor.status.selectionFromPath")
        )
    }

    @discardableResult
    func applyPathSelection(
        _ selection: ImageEditorSelection,
        replaceHistoryKey: String,
        successStatus: String
    ) -> Bool {
        let didChange = applySelectionCandidate(
            selection,
            replaceHistoryKey: replaceHistoryKey
        )
        if didChange, document.selection != nil {
            statusText = successStatus
        }
        return didChange
    }

    func createPathFromSelection() {
        guard canCreatePathFromSelection,
              let selection = document.selection,
              let pathLayer = pathLayer(from: selection)
        else {
            statusText = L10n.text("imageEditor.status.pathFromSelectionFailed")
            return
        }

        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        pushUndo()
        document.layers.insert(pathLayer, at: insertionIndex)
        document.selectedLayerID = pathLayer.id
        document.selectedLayerIDs = [pathLayer.id]
        selectedPathSubpathIndex = 0
        selectedPathAnchorIndex = 0
        selectedPathControlRole = .anchor
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.pathFromSelection"))
        let contourCount = pathLayer.shapeContent?.allEditablePathSubpaths.count ?? 1
        statusText = contourCount == 1
            ? L10n.text("imageEditor.status.pathFromSelection")
            : L10n.format("imageEditor.status.pathContoursFromSelection", contourCount)
    }

    func deleteSelectedPathAnchor() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard canDeleteSelectedPathAnchor,
              let index = selectedPathAnchorIndex,
              let layerIndex = document.selectedLayerIndex,
              var shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path,
              shapeContent.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex].indices.contains(index)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        var canvasAnchors = canvasAnchors(
            for: shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex],
            layer: document.layers[layerIndex]
        )
        canvasAnchors.remove(at: index)
        if shapeContent.isPathClosed && canvasAnchors.count < 3 {
            shapeContent.isPathClosed = false
            shapeContent.fillOpacity = 0
        }

        pushUndo()
        updatePathLayer(
            at: layerIndex,
            shapeContent: shapeContent,
            canvasAnchors: canvasAnchors,
            editingSubpathIndex: selectedPathSubpathIndex
        )
        if canvasAnchors.isEmpty {
            selectedPathAnchorIndex = nil
        } else {
            selectedPathAnchorIndex = min(index, canvasAnchors.count - 1)
        }
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathAnchorDelete"))
        statusText = L10n.text("imageEditor.status.pathAnchorDeleted")
    }

    func deleteSelectedPathSubpath() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard canDeleteSelectedPathSubpath,
              let layerIndex = document.selectedLayerIndex,
              let shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let layer = document.layers[layerIndex]
        var canvasSubpaths = shapeContent.allEditablePathSubpaths.map { subpath in
            canvasAnchors(for: subpath, layer: layer)
        }
        guard canvasSubpaths.indices.contains(selectedPathSubpathIndex) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let deletedIndex = selectedPathSubpathIndex
        canvasSubpaths.remove(at: deletedIndex)
        guard !canvasSubpaths.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        var updatedShapeContent = shapeContent
        var operations = shapeContent.resolvedPathComponentOperations
        operations.remove(at: deletedIndex)
        updatedShapeContent.pathComponentOperations = operations

        pushUndo()
        updatePathLayer(at: layerIndex, shapeContent: updatedShapeContent, canvasSubpaths: canvasSubpaths)
        selectedPathSubpathIndex = min(deletedIndex, canvasSubpaths.count - 1)
        selectedPathAnchorIndex = canvasSubpaths[selectedPathSubpathIndex].isEmpty ? nil : 0
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathSubpathDelete"))
        statusText = L10n.text("imageEditor.status.pathSubpathDeleted")
    }

    func insertPathAnchorAfterSelection() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard canInsertPathAnchorAfterSelection,
              let index = selectedPathAnchorIndex,
              let layerIndex = document.selectedLayerIndex,
              let shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path,
              shapeContent.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex].indices.contains(index),
              let nextIndex = nextPathAnchorIndex(
                after: index,
                count: shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex].count,
                closed: shapeContent.isPathClosed
              )
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        var canvasAnchors = canvasAnchors(
            for: shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex],
            layer: document.layers[layerIndex]
        )
        let insertedAnchor = splitPathSegment(from: canvasAnchors[index], to: canvasAnchors[nextIndex])
        canvasAnchors[index] = insertedAnchor.start
        canvasAnchors[nextIndex] = insertedAnchor.end
        let insertionIndex = index + 1
        canvasAnchors.insert(insertedAnchor.inserted, at: insertionIndex)

        pushUndo()
        updatePathLayer(
            at: layerIndex,
            shapeContent: shapeContent,
            canvasAnchors: canvasAnchors,
            editingSubpathIndex: selectedPathSubpathIndex
        )
        selectedPathAnchorIndex = insertionIndex
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathAnchorInsert"))
        statusText = L10n.text("imageEditor.status.pathAnchorInserted")
    }

    func toggleSelectedPathClosed() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard canToggleSelectedPathClosed,
              let layerIndex = document.selectedLayerIndex,
              var shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let closingPath = !shapeContent.isPathClosed
        shapeContent.isPathClosed = closingPath
        if closingPath {
            if shapeContent.fillOpacity <= 0 {
                shapeContent.fillOpacity = min(1, max(0.15, opacity))
            }
        } else {
            shapeContent.fillOpacity = 0
        }

        let canvasAnchors = canvasAnchors(for: shapeContent, layer: document.layers[layerIndex])
        pushUndo()
        updatePathLayer(at: layerIndex, shapeContent: shapeContent, canvasAnchors: canvasAnchors)
        if selectedPathAnchorIndex == nil, !canvasAnchors.isEmpty {
            selectedPathSubpathIndex = 0
            selectedPathAnchorIndex = 0
        }
        selectedPathControlRole = .anchor
        appendHistory(L10n.text(closingPath ? "imageEditor.history.pathClose" : "imageEditor.history.pathOpen"))
        statusText = L10n.text(closingPath ? "imageEditor.status.pathClosed" : "imageEditor.status.pathOpened")
    }

    func reverseSelectedPathDirection() {
        guard !cancelPathAnchorDragBeforeDiscreteCommand() else { return }
        guard canReverseSelectedPathDirection,
              let layerIndex = document.selectedLayerIndex,
              let shapeContent = document.layers[layerIndex].shapeContent,
              shapeContent.kind == .path,
              shapeContent.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let canvasAnchors = canvasAnchors(
            for: shapeContent.allEditablePathSubpaths[selectedPathSubpathIndex],
            layer: document.layers[layerIndex]
        )
        let reversedAnchors = canvasAnchors.reversed().map(reversePathAnchorDirection)
        let previousSelectedIndex = selectedPathAnchorIndex

        pushUndo()
        updatePathLayer(
            at: layerIndex,
            shapeContent: shapeContent,
            canvasAnchors: reversedAnchors,
            editingSubpathIndex: selectedPathSubpathIndex
        )
        if let previousSelectedIndex,
           canvasAnchors.indices.contains(previousSelectedIndex) {
            selectedPathAnchorIndex = canvasAnchors.count - 1 - previousSelectedIndex
        }
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathReverse"))
        statusText = L10n.text("imageEditor.status.pathReversed")
    }

    func strokeSelectedPathToPixelLayer() {
        guard canStrokeSelectedPathToPixelLayer,
              let sourceIndex = document.selectedLayerIndex,
              let sourceContent = document.layers[sourceIndex].shapeContent,
              let targetIndex = pathPixelTargetIndex(below: sourceIndex),
              let strokedImage = pathStrokeImage(
                from: sourceContent,
                sourceLayer: document.layers[sourceIndex],
                targetLayer: document.layers[targetIndex]
              )
        else {
            statusText = L10n.text("imageEditor.status.pathStrokeFailed")
            return
        }

        applyPathRenderedImage(
            strokedImage,
            targetIndex: targetIndex,
            historyKey: "imageEditor.history.pathStroke",
            successStatus: L10n.text("imageEditor.status.pathStroked")
        )
    }

    func fillSelectedPathToPixelLayer() {
        guard canFillSelectedPathToPixelLayer,
              let sourceIndex = document.selectedLayerIndex,
              let sourceContent = document.layers[sourceIndex].shapeContent,
              let targetIndex = pathPixelTargetIndex(below: sourceIndex),
              let filledImage = pathFillImage(
                from: sourceContent,
                sourceLayer: document.layers[sourceIndex],
                targetLayer: document.layers[targetIndex]
              )
        else {
            statusText = L10n.text("imageEditor.status.pathFillFailed")
            return
        }

        applyPathRenderedImage(
            filledImage,
            targetIndex: targetIndex,
            historyKey: "imageEditor.history.pathFill",
            successStatus: L10n.text("imageEditor.status.pathFilled")
        )
    }

    @discardableResult
    func applyPathRenderedImage(
        _ image: NSImage,
        targetIndex: Int,
        historyKey: String,
        successStatus: String
    ) -> Bool {
        guard document.layers.indices.contains(targetIndex) else { return false }
        pushUndo()
        let targetLayer = document.layers[targetIndex]
        let output = document.isEffectivelyTransparencyLocked(targetLayer)
            ? (image.preservingAlpha(from: targetLayer.image) ?? image)
            : image
        document.layers[targetIndex].image = output.normalizedBitmapImage()
        appendHistory(L10n.text(historyKey))
        statusText = successStatus
        return true
    }


    func finishPenPath(closed: Bool) {
        guard canFinishPenPath else {
            statusText = L10n.text("imageEditor.status.penNeedsPoints")
            return
        }
        let anchors = pendingPenPathAnchors
        if pendingPenContinuationLayerID != nil {
            guard finishPenPathContinuation(anchors: anchors, closed: closed) else {
                statusText = L10n.text("imageEditor.status.operationFailed")
                return
            }
            clearPendingPenPath()
            return
        }
        clearPendingPenPath()
        addPathLayer(anchors: anchors, closed: closed)
    }

    @discardableResult
    func cancelPenPath() -> Bool {
        guard hasPendingPenPathTransaction else { return false }
        clearPendingPenPath()
        statusText = L10n.text("imageEditor.status.penCancelled")
        return true
    }

    private func finishPenPathContinuation(
        anchors: [ImageEditorPathAnchor],
        closed: Bool
    ) -> Bool {
        guard let layerID = pendingPenContinuationLayerID,
              let subpathIndex = pendingPenContinuationSubpathIndex,
              anchors.count > pendingPenContinuationInitialAnchorCount,
              let layerIndex = document.layers.firstIndex(where: { $0.id == layerID }),
              var content = document.layers[layerIndex].shapeContent,
              content.kind == .path
        else { return false }
        pushUndo()
        content.isPathClosed = closed
        updatePathLayer(
            at: layerIndex,
            shapeContent: content,
            canvasAnchors: anchors,
            editingSubpathIndex: subpathIndex
        )
        document.selectedLayerID = layerID
        document.selectedLayerIDs = [layerID]
        selectedPathSubpathIndex = subpathIndex
        selectedPathAnchorIndex = closed ? 0 : anchors.count - 1
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathAnchorInsert"))
        statusText = closed
            ? L10n.text("imageEditor.status.penClosed")
            : L10n.text("imageEditor.status.penOpen")
        return true
    }

    @discardableResult
    private func joinPendingPenPath(
        at point: CGPoint,
        symmetricControlDrag: CGSize?
    ) -> Bool {
        guard let target = penPathJoinTarget(at: point) else { return false }
        guard !target.isBlocked else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return true
        }
        guard let targetIndex = document.layers.firstIndex(where: { $0.id == target.layerID }),
              let targetContent = document.layers[targetIndex].shapeContent,
              targetContent.kind == .path,
              !targetContent.isPathClosed,
              targetContent.allEditablePathSubpaths.count == 1,
              let targetLocalAnchors = targetContent.allEditablePathSubpaths.first,
              targetLocalAnchors.count >= 2,
              target.endpointIndex == 0 || target.endpointIndex == targetLocalAnchors.count - 1
        else { return false }

        var targetAnchors = canvasAnchors(
            for: targetLocalAnchors,
            layer: document.layers[targetIndex]
        )
        if target.endpointIndex == targetAnchors.count - 1 {
            targetAnchors = targetAnchors.reversed().map(reversedPathAnchor)
        }
        if let controls = symmetricControlDrag.flatMap({
            ImageEditorPenPointGeometry.symmetricControls(
                anchor: targetAnchors[0].point,
                drag: $0,
                canvasSize: document.canvasSize
            )
        }) {
            targetAnchors[0].inControl = controls.inControl
            targetAnchors[0].outControl = controls.outControl
        }
        let joined = combinedPathAnchors(
            pending: pendingPenPathAnchors,
            target: targetAnchors
        )

        guard let sourceLayerID = pendingPenContinuationLayerID else {
            pushUndo()
            updatePathLayer(
                at: targetIndex,
                shapeContent: targetContent,
                canvasAnchors: joined.anchors,
                editingSubpathIndex: 0
            )
            document.selectedLayerID = target.layerID
            document.selectedLayerIDs = [target.layerID]
            selectedPathSubpathIndex = 0
            selectedPathAnchorIndex = joined.connectionIndex
            selectedPathControlRole = .anchor
            appendHistory(L10n.text("imageEditor.history.pathJoin"))
            statusText = L10n.text("imageEditor.status.pathJoined")
            clearPendingPenPath()
            return true
        }

        guard sourceLayerID != target.layerID,
              let sourceIndex = document.layers.firstIndex(where: { $0.id == sourceLayerID }),
              var sourceContent = document.layers[sourceIndex].shapeContent,
              sourceContent.kind == .path,
              !sourceContent.isPathClosed
        else { return false }

        let targetLinkedIDs = document.layers[targetIndex].linkedLayerIDs
        pushUndo()
        document.layers.remove(at: targetIndex)
        for index in document.layers.indices {
            if document.layers[index].linkedLayerIDs.remove(target.layerID) != nil,
               document.layers[index].id != sourceLayerID {
                document.layers[index].linkedLayerIDs.insert(sourceLayerID)
            }
        }
        guard let updatedSourceIndex = document.layers.firstIndex(where: { $0.id == sourceLayerID }) else {
            return false
        }
        document.layers[updatedSourceIndex].linkedLayerIDs.formUnion(
            targetLinkedIDs.subtracting([sourceLayerID, target.layerID])
        )
        sourceContent.isPathClosed = false
        updatePathLayer(
            at: updatedSourceIndex,
            shapeContent: sourceContent,
            canvasAnchors: joined.anchors,
            editingSubpathIndex: pendingPenContinuationSubpathIndex ?? 0
        )
        normalizeClippingMasks()
        document.selectedLayerID = sourceLayerID
        document.selectedLayerIDs = [sourceLayerID]
        selectedPathSubpathIndex = pendingPenContinuationSubpathIndex ?? 0
        selectedPathAnchorIndex = joined.connectionIndex
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathJoin"))
        statusText = L10n.text("imageEditor.status.pathJoined")
        clearPendingPenPath()
        return true
    }

    private func clearPendingPenPath() {
        pendingPenPathAnchors = []
        undonePendingPenPathAnchors = []
        pendingPenContinuationLayerID = nil
        pendingPenContinuationSubpathIndex = nil
        pendingPenContinuationInitialAnchorCount = 0
    }

    private func reversedPathAnchor(_ anchor: ImageEditorPathAnchor) -> ImageEditorPathAnchor {
        ImageEditorPathAnchor(
            point: anchor.point,
            inControl: anchor.outControl,
            outControl: anchor.inControl
        )
    }

    private func combinedPathAnchors(
        pending: [ImageEditorPathAnchor],
        target: [ImageEditorPathAnchor]
    ) -> (anchors: [ImageEditorPathAnchor], connectionIndex: Int) {
        var anchors = pending
        let joinsAtSamePoint = anchors.last.map {
            distance(from: $0.point, to: target[0].point) <= 0.000_001
        } ?? false
        if joinsAtSamePoint, let pendingEndpoint = anchors.popLast() {
            anchors.append(ImageEditorPathAnchor(
                point: target[0].point,
                inControl: target[0].inControl ?? pendingEndpoint.inControl,
                outControl: target[0].outControl ?? pendingEndpoint.outControl
            ))
            anchors.append(contentsOf: target.dropFirst())
            return (anchors, max(0, pending.count - 1))
        }
        let connectionIndex = anchors.count
        anchors.append(contentsOf: target)
        return (anchors, connectionIndex)
    }

    private func addPathLayer(anchors: [ImageEditorPathAnchor], closed: Bool) {
        guard anchors.count >= 2 else { return }
        let strokeWidth = max(1, min(96, brushSize * 0.35))
        let bounds = pathBounds(anchors)
        let padding = ceil(strokeWidth / 2 + 3)
        let frame = CGRect(
            x: bounds.minX - padding,
            y: bounds.minY - padding,
            width: max(1, bounds.width + padding * 2),
            height: max(1, bounds.height + padding * 2)
        )
        let localAnchors = anchors.map { anchor in
            ImageEditorPathAnchor(
                point: CGPoint(x: anchor.point.x - frame.minX, y: anchor.point.y - frame.minY),
                inControl: anchor.inControl.map {
                    CGPoint(x: $0.x - frame.minX, y: $0.y - frame.minY)
                },
                outControl: anchor.outControl.map {
                    CGPoint(x: $0.x - frame.minX, y: $0.y - frame.minY)
                }
            )
        }
        let localPoints = localAnchors.map(\.point)
        let content = ImageEditorShapeContent(
            kind: .path,
            fillColor: foregroundColor,
            fillOpacity: closed ? opacity : 0,
            strokeColor: foregroundColor,
            strokeWidth: strokeWidth,
            strokeOpacity: min(1, max(0.15, opacity)),
            pathPoints: localPoints,
            pathAnchors: localAnchors,
            isPathClosed: closed
        )
        pushUndo()
        var layer = ImageEditorLayer.shape(
            name: L10n.format("imageEditor.layer.shapeName", ImageEditorShapeKind.path.title),
            frame: frame,
            content: content
        )
        layer.opacity = 1
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        selectedPathSubpathIndex = 0
        selectedPathAnchorIndex = closed ? 0 : nil
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerShapeNew"))
        statusText = closed
            ? L10n.text("imageEditor.status.penClosed")
            : L10n.text("imageEditor.status.penOpen")
    }

    private func updatePathLayer(
        at layerIndex: Int,
        shapeContent: ImageEditorShapeContent,
        canvasAnchors: [ImageEditorPathAnchor],
        editingSubpathIndex: Int = 0
    ) {
        guard !canvasAnchors.isEmpty else { return }
        let layer = document.layers[layerIndex]
        var canvasSubpaths = shapeContent.allEditablePathSubpaths.map { subpath in
            self.canvasAnchors(for: subpath, layer: layer)
        }
        if canvasSubpaths.indices.contains(editingSubpathIndex) {
            canvasSubpaths[editingSubpathIndex] = canvasAnchors
        } else if canvasSubpaths.isEmpty {
            canvasSubpaths = [canvasAnchors]
        } else {
            canvasSubpaths[0] = canvasAnchors
        }
        updatePathLayer(at: layerIndex, shapeContent: shapeContent, canvasSubpaths: canvasSubpaths)
    }

    private func updatePathLayer(
        at layerIndex: Int,
        shapeContent: ImageEditorShapeContent,
        canvasSubpaths: [[ImageEditorPathAnchor]]
    ) {
        guard !canvasSubpaths.isEmpty else { return }
        let strokeWidth = max(ImageEditorShapeContent.minimumStrokeWidth, shapeContent.strokeWidth)
        let allCanvasAnchors = canvasSubpaths.flatMap { $0 }
        let bounds = pathBounds(allCanvasAnchors)
        let padding = ceil(strokeWidth / 2 + 3)
        let minX = max(0, bounds.minX - padding)
        let minY = max(0, bounds.minY - padding)
        let maxX = min(document.canvasSize.width, bounds.maxX + padding)
        let maxY = min(document.canvasSize.height, bounds.maxY + padding)
        let frame = CGRect(
            x: minX,
            y: minY,
            width: max(1, maxX - minX),
            height: max(1, maxY - minY)
        )
        var updatedContent = shapeContent
        let localSubpaths = canvasSubpaths.map { subpath in
            localAnchors(from: subpath, frame: frame)
        }
        updatedContent.pathAnchors = localSubpaths.first ?? []
        updatedContent.pathPoints = updatedContent.pathAnchors.map(\.point)
        updatedContent.pathSubpaths = Array(localSubpaths.dropFirst())
        document.layers[layerIndex].frame = frame
        document.layers[layerIndex].image = NSImage.transparent(size: frame.size)
        if let mask = document.layers[layerIndex].mask, mask.size != frame.size {
            document.layers[layerIndex].mask = mask.resized(to: frame.size)
        }
        document.layers[layerIndex].kind = .shape(updatedContent.normalized(size: frame.size))
    }

    private func localAnchors(from canvasAnchors: [ImageEditorPathAnchor], frame: CGRect) -> [ImageEditorPathAnchor] {
        canvasAnchors.map { anchor in
            ImageEditorPathAnchor(
                point: CGPoint(x: anchor.point.x - frame.minX, y: anchor.point.y - frame.minY),
                inControl: anchor.inControl.map { CGPoint(x: $0.x - frame.minX, y: $0.y - frame.minY) },
                outControl: anchor.outControl.map { CGPoint(x: $0.x - frame.minX, y: $0.y - frame.minY) }
            )
        }
    }

    private var penCloseDistance: CGFloat {
        max(8, min(24, brushSize * 0.5))
    }

    private var pathAnchorHitDistance: CGFloat {
        max(8, min(22, brushSize * 0.45))
    }

    private func penPathContinuationHit(
        at point: CGPoint?
    ) -> ImageEditorPenPathContinuationHit? {
        guard let hit = penPathControlHit(at: point),
              hit.role == .anchor,
              let layer = document.layers.first(where: { $0.id == hit.layerID }),
              let content = layer.shapeContent,
              content.kind == .path,
              !content.isPathClosed,
              content.allEditablePathSubpaths.count == 1,
              let anchors = content.allEditablePathSubpaths.first,
              anchors.count >= 2,
              hit.subpathIndex == 0,
              hit.anchorIndex == 0 || hit.anchorIndex == anchors.count - 1
        else { return nil }
        return ImageEditorPenPathContinuationHit(
            layerID: hit.layerID,
            subpathIndex: hit.subpathIndex,
            anchorIndex: hit.anchorIndex
        )
    }

    private func penPathJoinEndpointHit(
        at point: CGPoint?
    ) -> ImageEditorPenPathContinuationHit? {
        guard !pendingPenPathAnchors.isEmpty,
              let point,
              point.x.isFinite,
              point.y.isFinite
        else { return nil }
        let sourceLayerID = pendingPenContinuationLayerID

        for layer in document.layers.reversed() {
            guard !layer.isGroup,
                  document.isEffectivelyVisible(layer),
                  let content = layer.shapeContent,
                  content.kind == .path
            else { continue }

            let controls = pathControlCandidates(for: content, layer: layer).filter {
                layer.id == sourceLayerID || $0.role == .anchor
            }
            let nearestControl = controls.map { candidate in
                (candidate: candidate, distance: distance(from: point, to: candidate.point))
            }.min { lhs, rhs in lhs.distance < rhs.distance }
            if let nearestControl, nearestControl.distance <= pathAnchorHitDistance {
                guard layer.id != sourceLayerID,
                      nearestControl.candidate.role == .anchor,
                      !content.isPathClosed,
                      content.allEditablePathSubpaths.count == 1,
                      let anchors = content.allEditablePathSubpaths.first,
                      anchors.count >= 2,
                      nearestControl.candidate.subpathIndex == 0,
                      (nearestControl.candidate.index == 0
                        || nearestControl.candidate.index == anchors.count - 1)
                else { return nil }
                return ImageEditorPenPathContinuationHit(
                    layerID: layer.id,
                    subpathIndex: 0,
                    anchorIndex: nearestControl.candidate.index
                )
            }

            for localAnchors in content.allEditablePathSubpaths where localAnchors.count >= 2 {
                let anchors = canvasAnchors(for: localAnchors, layer: layer)
                let segmentCount = content.isPathClosed ? anchors.count : anchors.count - 1
                for startIndex in 0..<segmentCount {
                    let endIndex = (startIndex + 1) % anchors.count
                    let candidate = nearestPointOnCubicPath(
                        from: anchors[startIndex],
                        to: anchors[endIndex],
                        point: point
                    )
                    if candidate.parameter > 0.02,
                       candidate.parameter < 0.98,
                       candidate.distance <= pathAnchorHitDistance {
                        return nil
                    }
                }
            }
        }
        return nil
    }

    private func duplicatePathSubpathOffset(for anchors: [ImageEditorPathAnchor]) -> CGSize {
        let bounds = pathBounds(anchors)
        let preferredOffset: CGFloat = 8
        let right = min(preferredOffset, max(0, document.canvasSize.width - bounds.maxX))
        let down = min(preferredOffset, max(0, document.canvasSize.height - bounds.maxY))
        if right > 0 || down > 0 {
            return CGSize(width: right, height: down)
        }
        return CGSize(
            width: max(-preferredOffset, -bounds.minX),
            height: max(-preferredOffset, -bounds.minY)
        )
    }

    private func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }

    private func selectNearestPathAnchor(at point: CGPoint) -> Bool {
        guard let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path
        else { return false }
        let candidates = pathControlCandidates(for: content, layer: layer)
        let nearest = candidates.map { candidate in
            (candidate: candidate, distance: distance(from: point, to: candidate.point))
        }.min { lhs, rhs in
            lhs.distance < rhs.distance
        }
        guard let nearest,
              nearest.distance <= pathAnchorHitDistance
        else { return false }
        selectedPathSubpathIndex = nearest.candidate.subpathIndex
        selectedPathAnchorIndex = nearest.candidate.index
        selectedPathControlRole = nearest.candidate.role
        statusText = L10n.format("imageEditor.status.pathAnchorSelected", nearest.candidate.index + 1)
        return true
    }

    private func nearestPathAnchorReference(
        at point: CGPoint,
        content: ImageEditorShapeContent,
        layer: ImageEditorLayer
    ) -> (subpathIndex: Int, anchorIndex: Int)? {
        let nearest = pathControlCandidates(for: content, layer: layer)
            .filter { $0.role == .anchor }
            .map { candidate in
                (candidate: candidate, distance: distance(from: point, to: candidate.point))
            }
            .min { lhs, rhs in lhs.distance < rhs.distance }
        guard let nearest, nearest.distance <= pathAnchorHitDistance else { return nil }
        return (
            subpathIndex: nearest.candidate.subpathIndex,
            anchorIndex: nearest.candidate.index
        )
    }

    private func penPathSegmentHit(at point: CGPoint?) -> ImageEditorPathSegmentHit? {
        guard case .segment(let hit) = penPathInsertionHit(at: point) else { return nil }
        return hit
    }

    private func penPathControlHit(at point: CGPoint?) -> ImageEditorPenPathControlHit? {
        guard case .control(let hit) = penPathInsertionHit(at: point) else { return nil }
        return hit
    }

    private func penPathInsertionHit(at point: CGPoint?) -> ImageEditorPenPathInsertionHit? {
        guard pendingPenPathAnchors.isEmpty,
              let point,
              point.x.isFinite,
              point.y.isFinite
        else { return nil }

        for layer in document.layers.reversed() {
            guard !layer.isGroup,
                  document.isEffectivelyVisible(layer),
                  let content = layer.shapeContent,
                  content.kind == .path
            else { continue }

            let controls = pathControlCandidates(for: content, layer: layer).filter {
                layer.id == document.selectedLayerID || $0.role == .anchor
            }
            let nearestControl = controls.map { candidate in
                (candidate: candidate, distance: distance(from: point, to: candidate.point))
            }.min { lhs, rhs in lhs.distance < rhs.distance }
            if let nearestControl, nearestControl.distance <= pathAnchorHitDistance {
                return .control(ImageEditorPenPathControlHit(
                    layerID: layer.id,
                    subpathIndex: nearestControl.candidate.subpathIndex,
                    anchorIndex: nearestControl.candidate.index,
                    role: nearestControl.candidate.role
                ))
            }

            var nearest: ImageEditorPathSegmentHit?
            for (subpathIndex, localAnchors) in content.allEditablePathSubpaths.enumerated()
                where localAnchors.count >= 2 {
                let anchors = canvasAnchors(for: localAnchors, layer: layer)
                let segmentCount = content.isPathClosed ? anchors.count : anchors.count - 1
                for startIndex in 0..<segmentCount {
                    let endIndex = (startIndex + 1) % anchors.count
                    let candidate = nearestPointOnCubicPath(
                        from: anchors[startIndex],
                        to: anchors[endIndex],
                        point: point
                    )
                    guard candidate.parameter > 0.02,
                          candidate.parameter < 0.98,
                          candidate.distance <= pathAnchorHitDistance
                    else { continue }
                    if candidate.distance < (nearest?.distance ?? .greatestFiniteMagnitude) {
                        nearest = ImageEditorPathSegmentHit(
                            layerID: layer.id,
                            subpathIndex: subpathIndex,
                            startAnchorIndex: startIndex,
                            endAnchorIndex: endIndex,
                            parameter: candidate.parameter,
                            distance: candidate.distance
                        )
                    }
                }
            }
            if let nearest {
                return .segment(nearest)
            }
        }
        return nil
    }

    private func nearestPointOnCubicPath(
        from start: ImageEditorPathAnchor,
        to end: ImageEditorPathAnchor,
        point: CGPoint
    ) -> (parameter: CGFloat, point: CGPoint, distance: CGFloat) {
        if start.outControl == nil, end.inControl == nil {
            let vector = CGVector(
                dx: end.point.x - start.point.x,
                dy: end.point.y - start.point.y
            )
            let lengthSquared = vector.dx * vector.dx + vector.dy * vector.dy
            guard lengthSquared > 0.000_001 else {
                return (0, start.point, distance(from: point, to: start.point))
            }
            let projection = (
                (point.x - start.point.x) * vector.dx
                    + (point.y - start.point.y) * vector.dy
            ) / lengthSquared
            let parameter = min(1, max(0, projection))
            let nearestPoint = interpolatedPoint(start.point, end.point, at: parameter)
            return (parameter, nearestPoint, distance(from: point, to: nearestPoint))
        }

        let sampleCount = 48
        var bestParameter: CGFloat = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for step in 0...sampleCount {
            let parameter = CGFloat(step) / CGFloat(sampleCount)
            let candidate = cubicPoint(from: start, to: end, parameter: parameter)
            let candidateDistance = distance(from: point, to: candidate)
            if candidateDistance < bestDistance {
                bestParameter = parameter
                bestDistance = candidateDistance
            }
        }

        var lower = max(0, bestParameter - 1 / CGFloat(sampleCount))
        var upper = min(1, bestParameter + 1 / CGFloat(sampleCount))
        for _ in 0..<12 {
            let first = lower + (upper - lower) / 3
            let second = upper - (upper - lower) / 3
            let firstDistance = distance(
                from: point,
                to: cubicPoint(from: start, to: end, parameter: first)
            )
            let secondDistance = distance(
                from: point,
                to: cubicPoint(from: start, to: end, parameter: second)
            )
            if firstDistance <= secondDistance {
                upper = second
            } else {
                lower = first
            }
        }
        let parameter = (lower + upper) / 2
        let nearestPoint = cubicPoint(from: start, to: end, parameter: parameter)
        return (parameter, nearestPoint, distance(from: point, to: nearestPoint))
    }

    private func cubicPoint(
        from start: ImageEditorPathAnchor,
        to end: ImageEditorPathAnchor,
        parameter: CGFloat
    ) -> CGPoint {
        let inverse = 1 - parameter
        let control1 = start.outControl ?? start.point
        let control2 = end.inControl ?? end.point
        return CGPoint(
            x: inverse * inverse * inverse * start.point.x
                + 3 * inverse * inverse * parameter * control1.x
                + 3 * inverse * parameter * parameter * control2.x
                + parameter * parameter * parameter * end.point.x,
            y: inverse * inverse * inverse * start.point.y
                + 3 * inverse * inverse * parameter * control1.y
                + 3 * inverse * parameter * parameter * control2.y
                + parameter * parameter * parameter * end.point.y
        )
    }

    private func setSelectedPathAnchorPosition(_ point: CGPoint) {
        let boundedPoint = clampedCanvasPoint(point)
        guard !pathPointsMatch(selectedPathAnchorCanvasPoint, boundedPoint) else { return }
        pushUndo()
        selectedPathControlRole = .anchor
        applySelectedPathAnchorMove(to: boundedPoint)
        appendHistory(L10n.text("imageEditor.history.pathAnchorMove"))
        statusText = L10n.text("imageEditor.status.pathAnchorMoved")
    }

    private func pointsBoundingRect(_ points: [CGPoint]) -> CGRect {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max()
        else { return CGRect(origin: .zero, size: CGSize(width: 1, height: 1)) }
        return CGRect(
            x: minX,
            y: minY,
            width: max(1, maxX - minX),
            height: max(1, maxY - minY)
        )
    }

    private func canvasAnchors(for content: ImageEditorShapeContent, layer: ImageEditorLayer) -> [ImageEditorPathAnchor] {
        canvasAnchors(for: content.editablePathAnchors, layer: layer)
    }

    private func canvasAnchors(for anchors: [ImageEditorPathAnchor], layer: ImageEditorLayer) -> [ImageEditorPathAnchor] {
        anchors.map { anchor in
            ImageEditorPathAnchor(
                point: canvasPoint(anchor.point, layer: layer),
                inControl: anchor.inControl.map { canvasPoint($0, layer: layer) },
                outControl: anchor.outControl.map { canvasPoint($0, layer: layer) }
            )
        }
    }

    private func canvasPoint(_ localPoint: CGPoint, layer: ImageEditorLayer) -> CGPoint {
        localToCanvasPoint(localPoint, layer: layer)
    }

    private func clampedCanvasPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: max(0, min(document.canvasSize.width, point.x)),
            y: max(0, min(document.canvasSize.height, point.y))
        )
    }

    private func pathBounds(_ anchors: [ImageEditorPathAnchor]) -> CGRect {
        let points = anchors.flatMap { anchor in
            [anchor.point, anchor.inControl, anchor.outControl].compactMap { $0 }
        }
        return pointsBoundingRect(points)
    }

    private func pathControlCandidates(
        for content: ImageEditorShapeContent,
        layer: ImageEditorLayer
    ) -> [(subpathIndex: Int, index: Int, role: ImageEditorPathControlRole, point: CGPoint)] {
        content.allEditablePathSubpaths.enumerated().flatMap { subpathIndex, anchors in
            anchors.enumerated().flatMap { index, anchor in
                var candidates: [(subpathIndex: Int, index: Int, role: ImageEditorPathControlRole, point: CGPoint)] = [
                    (
                        subpathIndex: subpathIndex,
                        index: index,
                        role: .anchor,
                        point: canvasPoint(anchor.point, layer: layer)
                    )
                ]
                if let inControl = anchor.inControl {
                    candidates.append((
                        subpathIndex: subpathIndex,
                        index: index,
                        role: .inHandle,
                        point: canvasPoint(inControl, layer: layer)
                    ))
                }
                if let outControl = anchor.outControl {
                    candidates.append((
                        subpathIndex: subpathIndex,
                        index: index,
                        role: .outHandle,
                        point: canvasPoint(outControl, layer: layer)
                    ))
                }
                return candidates
            }
        }
    }

    private func pathAnchorReferences(
        for content: ImageEditorShapeContent
    ) -> [(subpathIndex: Int, anchorIndex: Int)] {
        content.allEditablePathSubpaths.enumerated().flatMap { subpathIndex, anchors in
            anchors.indices.map { anchorIndex in
                (subpathIndex: subpathIndex, anchorIndex: anchorIndex)
            }
        }
    }

    private func currentPathAnchorReferenceIndex(
        in references: [(subpathIndex: Int, anchorIndex: Int)]
    ) -> Int? {
        guard let selectedPathAnchorIndex else { return nil }
        return references.firstIndex {
            $0.subpathIndex == selectedPathSubpathIndex && $0.anchorIndex == selectedPathAnchorIndex
        }
    }

    private func selectAdjacentPathSubpath(offset: Int) {
        guard let content = document.selectedLayer?.shapeContent,
              content.kind == .path
        else { return }
        let subpaths = content.allEditablePathSubpaths
        guard subpaths.count > 1 else { return }
        let currentIndex = subpaths.indices.contains(selectedPathSubpathIndex) ? selectedPathSubpathIndex : 0
        let nextIndex = (currentIndex + offset + subpaths.count) % subpaths.count
        selectedPathSubpathIndex = nextIndex
        selectedPathAnchorIndex = subpaths[nextIndex].isEmpty ? nil : 0
        selectedPathControlRole = .anchor
        statusText = L10n.format("imageEditor.status.pathSubpathSelected", nextIndex + 1, subpaths.count)
    }

    private func pathPixelTargetIndex(below sourceIndex: Int) -> Int? {
        guard document.layers.indices.contains(sourceIndex) else { return nil }
        let sourceGroupID = document.layers[sourceIndex].groupID
        return document.layers[..<sourceIndex].indices.reversed().first { candidateIndex in
            let candidate = document.layers[candidateIndex]
            return candidate.kind.isPixel && candidate.groupID == sourceGroupID
        }
    }

    private func vectorMaskTargetIndex(below sourceIndex: Int) -> Int? {
        guard document.layers.indices.contains(sourceIndex) else { return nil }
        let sourceGroupID = document.layers[sourceIndex].groupID
        return document.layers[..<sourceIndex].indices.reversed().first { candidateIndex in
            let candidate = document.layers[candidateIndex]
            return !candidate.isGroup && candidate.groupID == sourceGroupID
        }
    }

    private func pathLayerMaskTargetIndex(below sourceIndex: Int) -> Int? {
        guard document.layers.indices.contains(sourceIndex) else { return nil }
        let sourceGroupID = document.layers[sourceIndex].groupID
        return document.layers[..<sourceIndex].indices.reversed().first { candidateIndex in
            let candidate = document.layers[candidateIndex]
            return candidate.groupID == sourceGroupID
                && !document.isEffectivelyLocked(candidate)
                && candidate.mask == nil
        }
    }

    private func vectorMaskContent(
        from sourceContent: ImageEditorShapeContent,
        sourceLayer: ImageEditorLayer,
        targetLayer: ImageEditorLayer
    ) -> ImageEditorShapeContent? {
        guard sourceContent.kind == .path,
              sourceContent.isPathClosed,
              sourceContent.editablePathAnchors.count >= 3
        else { return nil }
        let subpaths = pathTargetSubpaths(
            from: sourceContent,
            sourceLayer: sourceLayer,
            targetLayer: targetLayer
        )
        guard let anchors = subpaths.first else { return nil }
        return ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: anchors.map(\.point),
            pathAnchors: anchors,
            pathSubpaths: Array(subpaths.dropFirst()),
            pathComponentOperations: sourceContent.pathComponentOperations,
            pathStartsWithAllPixels: sourceContent.pathStartsWithAllPixels,
            isPathClosed: true
        ).normalized(size: maskSize(for: targetLayer))
    }

    private func vectorMaskPathLayer(
        from vectorMask: ImageEditorShapeContent,
        targetLayer: ImageEditorLayer
    ) -> ImageEditorLayer? {
        guard vectorMask.kind == .path,
              vectorMask.isPathClosed,
              vectorMask.editablePathAnchors.count >= 3
        else { return nil }
        let normalizedMask = vectorMask.normalized(size: maskSize(for: targetLayer))
        let canvasSubpaths = normalizedMask.allEditablePathSubpaths.map { anchors in
            anchors.map { anchor in
                ImageEditorPathAnchor(
                    point: localToCanvasPoint(anchor.point, layer: targetLayer),
                    inControl: anchor.inControl.map { localToCanvasPoint($0, layer: targetLayer) },
                    outControl: anchor.outControl.map { localToCanvasPoint($0, layer: targetLayer) }
                )
            }
        }
        let canvasAnchors = canvasSubpaths.flatMap { $0 }
        let strokeWidth = max(ImageEditorShapeContent.minimumStrokeWidth, vectorMask.strokeWidth)
        let bounds = pathBounds(canvasAnchors)
        let padding = ceil(strokeWidth / 2 + 3)
        let frame = CGRect(
            x: max(0, bounds.minX - padding),
            y: max(0, bounds.minY - padding),
            width: max(1, min(document.canvasSize.width, bounds.maxX + padding) - max(0, bounds.minX - padding)),
            height: max(1, min(document.canvasSize.height, bounds.maxY + padding) - max(0, bounds.minY - padding))
        )
        let localSubpaths = canvasSubpaths.map { subpath in
            subpath.map { anchor in
                ImageEditorPathAnchor(
                    point: CGPoint(x: anchor.point.x - frame.minX, y: anchor.point.y - frame.minY),
                    inControl: anchor.inControl.map { CGPoint(x: $0.x - frame.minX, y: $0.y - frame.minY) },
                    outControl: anchor.outControl.map { CGPoint(x: $0.x - frame.minX, y: $0.y - frame.minY) }
                )
            }
        }
        guard let localAnchors = localSubpaths.first else { return nil }
        let content = ImageEditorShapeContent(
            kind: .path,
            fillColor: foregroundColor,
            fillOpacity: 0.18,
            strokeColor: foregroundColor,
            strokeWidth: max(ImageEditorShapeContent.minimumStrokeWidth, min(96, strokeWidth)),
            strokeOpacity: 1,
            pathPoints: localAnchors.map(\.point),
            pathAnchors: localAnchors,
            pathSubpaths: Array(localSubpaths.dropFirst()),
            pathComponentOperations: normalizedMask.pathComponentOperations,
            pathStartsWithAllPixels: normalizedMask.pathStartsWithAllPixels,
            isPathClosed: true
        )
        var layer = ImageEditorLayer.shape(
            name: L10n.text("imageEditor.layer.vectorMaskPathName"),
            frame: frame,
            content: content
        )
        layer.opacity = 1
        layer.groupID = targetLayer.groupID
        layer.isVectorMaskInverted = targetLayer.isVectorMaskInverted
        return layer
    }

    private func pathLayer(from selection: ImageEditorSelection) -> ImageEditorLayer? {
        let canvasSubpaths: [[CGPoint]]
        if let rasterMask = selection.rasterMask,
           let pointLoops = rasterSelectionOutlinePointLoops(from: rasterMask) {
            canvasSubpaths = pointLoops
        } else {
            canvasSubpaths = [selection.points.map(clampedCanvasPoint)]
        }

        let canvasPoints = canvasSubpaths.flatMap { $0 }
        guard let primaryCanvasPoints = canvasSubpaths.first,
              primaryCanvasPoints.count >= 3,
              !canvasPoints.isEmpty
        else { return nil }
        let strokeWidth = max(1, min(96, brushSize * 0.35))
        let bounds = pointsBoundingRect(canvasPoints)
        let padding = ceil(strokeWidth / 2 + 3)
        let minX = max(0, bounds.minX - padding)
        let minY = max(0, bounds.minY - padding)
        let maxX = min(document.canvasSize.width, bounds.maxX + padding)
        let maxY = min(document.canvasSize.height, bounds.maxY + padding)
        let frame = CGRect(
            x: minX,
            y: minY,
            width: max(1, maxX - minX),
            height: max(1, maxY - minY)
        )
        let localSubpaths = canvasSubpaths.map { points in
            points.map { point in
                ImageEditorPathAnchor(point: CGPoint(x: point.x - frame.minX, y: point.y - frame.minY))
            }
        }
        guard let primaryAnchors = localSubpaths.first else { return nil }
        let content = ImageEditorShapeContent(
            kind: .path,
            fillColor: foregroundColor,
            fillOpacity: 0,
            strokeColor: foregroundColor,
            strokeWidth: strokeWidth,
            strokeOpacity: min(1, max(0.35, opacity)),
            pathPoints: primaryAnchors.map(\.point),
            pathAnchors: primaryAnchors,
            pathSubpaths: Array(localSubpaths.dropFirst()),
            isPathClosed: true
        )
        var layer = ImageEditorLayer.shape(
            name: L10n.text("imageEditor.layer.selectionPathName"),
            frame: frame,
            content: content
        )
        layer.opacity = 1
        layer.groupID = document.selectedLayer?.groupID
        return layer
    }

    private func rasterSelectionOutlinePointLoops(from mask: ImageEditorSelectionMask) -> [[CGPoint]]? {
        guard mask.width > 0,
              mask.height > 0,
              mask.alpha.count == mask.width * mask.height
        else { return nil }

        let edges = rasterSelectionBoundaryEdges(from: mask)
        guard !edges.isEmpty else { return nil }
        let loops = rasterSelectionBoundaryLoops(from: edges)
        let scaleX = document.canvasSize.width / CGFloat(mask.width)
        let scaleY = document.canvasSize.height / CGFloat(mask.height)
        let outlineLoops = loops
            .filter { signedPolygonArea($0) > 0 }
            .sorted { polygonArea($0) > polygonArea($1) }
            .compactMap { loop -> [CGPoint]? in
                let simplified = simplifiedOrthogonalLoop(loop)
                guard simplified.count >= 3 else { return nil }
                return simplified.map { point in
                    clampedCanvasPoint(CGPoint(x: CGFloat(point.x) * scaleX, y: CGFloat(point.y) * scaleY))
                }
            }
        return outlineLoops.isEmpty ? nil : outlineLoops
    }

    private func rasterSelectionBoundaryEdges(from mask: ImageEditorSelectionMask) -> [ImageEditorRasterBoundaryPoint: [ImageEditorRasterBoundaryPoint]] {
        var edges: [ImageEditorRasterBoundaryPoint: [ImageEditorRasterBoundaryPoint]] = [:]

        func selected(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, x < mask.width, y >= 0, y < mask.height else { return false }
            return mask.alpha[y * mask.width + x] > 0
        }

        func addEdge(from start: ImageEditorRasterBoundaryPoint, to end: ImageEditorRasterBoundaryPoint) {
            edges[start, default: []].append(end)
        }

        for y in 0..<mask.height {
            for x in 0..<mask.width where selected(x, y) {
                if !selected(x, y - 1) {
                    addEdge(from: ImageEditorRasterBoundaryPoint(x: x, y: y), to: ImageEditorRasterBoundaryPoint(x: x + 1, y: y))
                }
                if !selected(x + 1, y) {
                    addEdge(from: ImageEditorRasterBoundaryPoint(x: x + 1, y: y), to: ImageEditorRasterBoundaryPoint(x: x + 1, y: y + 1))
                }
                if !selected(x, y + 1) {
                    addEdge(from: ImageEditorRasterBoundaryPoint(x: x + 1, y: y + 1), to: ImageEditorRasterBoundaryPoint(x: x, y: y + 1))
                }
                if !selected(x - 1, y) {
                    addEdge(from: ImageEditorRasterBoundaryPoint(x: x, y: y + 1), to: ImageEditorRasterBoundaryPoint(x: x, y: y))
                }
            }
        }

        return edges
    }

    private func rasterSelectionBoundaryLoops(
        from edges: [ImageEditorRasterBoundaryPoint: [ImageEditorRasterBoundaryPoint]]
    ) -> [[ImageEditorRasterBoundaryPoint]] {
        var remaining = Set(edges.flatMap { start, ends in
            ends.map { ImageEditorRasterBoundaryEdge(start: start, end: $0) }
        })
        var loops: [[ImageEditorRasterBoundaryPoint]] = []

        while let firstEdge = remaining.first {
            remaining.remove(firstEdge)
            var loop = [firstEdge.start, firstEdge.end]
            var current = firstEdge.end

            while current != firstEdge.start {
                guard let next = edges[current]?.first(where: { candidate in
                    remaining.contains(ImageEditorRasterBoundaryEdge(start: current, end: candidate))
                }) else { break }
                remaining.remove(ImageEditorRasterBoundaryEdge(start: current, end: next))
                loop.append(next)
                current = next
            }

            if loop.count >= 4, loop.last == loop.first {
                loop.removeLast()
                loops.append(loop)
            }
        }

        return loops
    }

    private func simplifiedOrthogonalLoop(_ points: [ImageEditorRasterBoundaryPoint]) -> [ImageEditorRasterBoundaryPoint] {
        guard points.count > 2 else { return points }
        var output: [ImageEditorRasterBoundaryPoint] = []
        for index in points.indices {
            let previous = points[(index - 1 + points.count) % points.count]
            let current = points[index]
            let next = points[(index + 1) % points.count]
            let previousDelta = ImageEditorRasterBoundaryPoint(x: current.x - previous.x, y: current.y - previous.y)
            let nextDelta = ImageEditorRasterBoundaryPoint(x: next.x - current.x, y: next.y - current.y)
            if previousDelta != nextDelta {
                output.append(current)
            }
        }
        return output
    }

    private func polygonArea(_ points: [ImageEditorRasterBoundaryPoint]) -> CGFloat {
        abs(signedPolygonArea(points))
    }

    private func signedPolygonArea(_ points: [ImageEditorRasterBoundaryPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var area: CGFloat = 0
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            area += CGFloat(current.x * next.y - next.x * current.y)
        }
        return area / 2
    }

    private func layerMaskContent(
        from sourceContent: ImageEditorShapeContent,
        sourceLayer: ImageEditorLayer,
        targetLayer: ImageEditorLayer
    ) -> NSImage? {
        guard sourceContent.kind == .path,
              sourceContent.isPathClosed,
              sourceContent.editablePathAnchors.count >= 3
        else { return nil }

        let targetSubpaths = pathTargetSubpaths(
            from: sourceContent,
            sourceLayer: sourceLayer,
            targetLayer: targetLayer
        )
        guard let targetAnchors = targetSubpaths.first else { return nil }
        let maskContent = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: targetAnchors.map(\.point),
            pathAnchors: targetAnchors,
            pathSubpaths: Array(targetSubpaths.dropFirst()),
            pathComponentOperations: sourceContent.pathComponentOperations,
            pathStartsWithAllPixels: sourceContent.pathStartsWithAllPixels,
            isPathClosed: true
        )
        return maskContent.renderedVectorMask(size: maskSize(for: targetLayer), inverted: false)
    }

    private func pathFillImage(
        from sourceContent: ImageEditorShapeContent,
        sourceLayer: ImageEditorLayer,
        targetLayer: ImageEditorLayer
    ) -> NSImage? {
        guard sourceContent.kind == .path,
              sourceContent.isPathClosed,
              sourceContent.editablePathAnchors.count >= 3
        else { return nil }
        let targetSubpaths = pathTargetSubpaths(
            from: sourceContent,
            sourceLayer: sourceLayer,
            targetLayer: targetLayer
        )
        return pathFillImage(from: targetSubpaths, targetLayer: targetLayer)
    }

    func pathFillImage(
        from savedPath: ImageEditorSavedPath,
        targetLayer: ImageEditorLayer
    ) -> NSImage? {
        guard savedPath.isClosed else { return nil }
        let targetSubpaths = savedPath.subpaths.map { anchors in
            anchors.map { pathTargetAnchor($0, targetLayer: targetLayer) }
        }
        return pathFillImage(from: targetSubpaths, targetLayer: targetLayer)
    }

    private func pathFillImage(
        from targetSubpaths: [[ImageEditorPathAnchor]],
        targetLayer: ImageEditorLayer
    ) -> NSImage? {
        guard let targetAnchors = targetSubpaths.first,
              targetAnchors.count >= 3
        else { return nil }
        let fillContent = ImageEditorShapeContent(
            kind: .path,
            fillColor: foregroundColor,
            fillOpacity: opacity,
            strokeColor: foregroundColor,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: targetAnchors.map(\.point),
            pathAnchors: targetAnchors,
            pathSubpaths: Array(targetSubpaths.dropFirst()),
            isPathClosed: true
        )
        let path = fillContent.pathBezierPath()
        return NSImage.rendered(size: targetLayer.image.size) { rect in
            targetLayer.image.draw(
                in: rect,
                from: CGRect(origin: .zero, size: targetLayer.image.size),
                operation: .copy,
                fraction: 1
            )
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: targetLayer.image.size.height) {
                foregroundColor.withAlphaComponent(max(0, min(1, opacity))).setFill()
                path.fill()
            }
        }
    }

    private func pathStrokeImage(
        from sourceContent: ImageEditorShapeContent,
        sourceLayer: ImageEditorLayer,
        targetLayer: ImageEditorLayer
    ) -> NSImage? {
        guard sourceContent.kind == .path,
              sourceContent.editablePathAnchors.count >= 2
        else { return nil }
        let targetSubpaths = pathTargetSubpaths(
            from: sourceContent,
            sourceLayer: sourceLayer,
            targetLayer: targetLayer
        )
        return pathStrokeImage(
            from: targetSubpaths,
            isClosed: sourceContent.isPathClosed,
            targetLayer: targetLayer
        )
    }

    func pathStrokeImage(
        from savedPath: ImageEditorSavedPath,
        targetLayer: ImageEditorLayer
    ) -> NSImage? {
        let targetSubpaths = savedPath.subpaths.map { anchors in
            anchors.map { pathTargetAnchor($0, targetLayer: targetLayer) }
        }
        return pathStrokeImage(
            from: targetSubpaths,
            isClosed: savedPath.isClosed,
            targetLayer: targetLayer
        )
    }

    private func pathStrokeImage(
        from targetSubpaths: [[ImageEditorPathAnchor]],
        isClosed: Bool,
        targetLayer: ImageEditorLayer
    ) -> NSImage? {
        guard let targetAnchors = targetSubpaths.first,
              targetAnchors.count >= 2
        else { return nil }
        let localStrokeWidth = pathStrokeWidth(for: targetLayer)
        let strokeContent = ImageEditorShapeContent(
            kind: .path,
            fillColor: foregroundColor,
            fillOpacity: 0,
            strokeColor: foregroundColor,
            strokeWidth: localStrokeWidth,
            strokeOpacity: opacity,
            pathPoints: targetAnchors.map(\.point),
            pathAnchors: targetAnchors,
            pathSubpaths: Array(targetSubpaths.dropFirst()),
            isPathClosed: isClosed
        )
        let path = strokeContent.pathBezierPath()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = localStrokeWidth
        return NSImage.rendered(size: targetLayer.image.size) { rect in
            targetLayer.image.draw(
                in: rect,
                from: CGRect(origin: .zero, size: targetLayer.image.size),
                operation: .copy,
                fraction: 1
            )
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: targetLayer.image.size.height) {
                foregroundColor.withAlphaComponent(max(0, min(1, opacity))).setStroke()
                path.stroke()
            }
        }
    }

    private func pathTargetSubpaths(
        from sourceContent: ImageEditorShapeContent,
        sourceLayer: ImageEditorLayer,
        targetLayer: ImageEditorLayer
    ) -> [[ImageEditorPathAnchor]] {
        sourceContent.allEditablePathSubpaths.map { anchors in
            anchors.map { anchor in
                pathTargetAnchor(anchor, sourceLayer: sourceLayer, targetLayer: targetLayer)
            }
        }.filter { !$0.isEmpty }
    }

    private func pathTargetAnchor(
        _ anchor: ImageEditorPathAnchor,
        sourceLayer: ImageEditorLayer,
        targetLayer: ImageEditorLayer
    ) -> ImageEditorPathAnchor {
        ImageEditorPathAnchor(
            point: canvasToLocalPoint(localToCanvasPoint(anchor.point, layer: sourceLayer), layer: targetLayer),
            inControl: anchor.inControl.map { canvasToLocalPoint(localToCanvasPoint($0, layer: sourceLayer), layer: targetLayer) },
            outControl: anchor.outControl.map { canvasToLocalPoint(localToCanvasPoint($0, layer: sourceLayer), layer: targetLayer) }
        )
    }

    private func pathTargetAnchor(
        _ anchor: ImageEditorPathAnchor,
        targetLayer: ImageEditorLayer
    ) -> ImageEditorPathAnchor {
        ImageEditorPathAnchor(
            point: canvasToLocalPoint(anchor.point, layer: targetLayer),
            inControl: anchor.inControl.map { canvasToLocalPoint($0, layer: targetLayer) },
            outControl: anchor.outControl.map { canvasToLocalPoint($0, layer: targetLayer) }
        )
    }

    private func pathStrokeWidth(for targetLayer: ImageEditorLayer) -> CGFloat {
        let xScale = targetLayer.image.size.width / max(targetLayer.frame.width, 1)
        let yScale = targetLayer.image.size.height / max(targetLayer.frame.height, 1)
        return max(1, brushSize * (xScale + yScale) / 2)
    }

    private func localToCanvasPoint(_ localPoint: CGPoint, layer: ImageEditorLayer) -> CGPoint {
        CGPoint(
            x: layer.frame.minX + localPoint.x / max(layer.image.size.width, 1) * layer.frame.width,
            y: layer.frame.minY + localPoint.y / max(layer.image.size.height, 1) * layer.frame.height
        )
    }

    private func canvasToLocalPoint(_ canvasPoint: CGPoint, layer: ImageEditorLayer) -> CGPoint {
        CGPoint(
            x: (canvasPoint.x - layer.frame.minX) / max(layer.frame.width, 1) * layer.image.size.width,
            y: (canvasPoint.y - layer.frame.minY) / max(layer.frame.height, 1) * layer.image.size.height
        )
    }

    private func neighboringPathPoint(
        before index: Int,
        in anchors: [ImageEditorPathAnchor],
        closed: Bool
    ) -> CGPoint? {
        if index > 0 {
            return anchors[index - 1].point
        }
        return closed ? anchors.last?.point : nil
    }

    private func neighboringPathPoint(
        after index: Int,
        in anchors: [ImageEditorPathAnchor],
        closed: Bool
    ) -> CGPoint? {
        if index + 1 < anchors.count {
            return anchors[index + 1].point
        }
        return closed ? anchors.first?.point : nil
    }

    private func nextPathAnchorIndex(after index: Int, count: Int, closed: Bool) -> Int? {
        guard count >= 2, index >= 0, index < count else { return nil }
        if index + 1 < count {
            return index + 1
        }
        return closed ? 0 : nil
    }

    private func splitPathSegment(
        from start: ImageEditorPathAnchor,
        to end: ImageEditorPathAnchor,
        at parameter: CGFloat = 0.5
    ) -> (start: ImageEditorPathAnchor, inserted: ImageEditorPathAnchor, end: ImageEditorPathAnchor) {
        var updatedStart = start
        var updatedEnd = end
        let parameter = min(1, max(0, parameter))
        let segmentHasCurve = start.outControl != nil || end.inControl != nil
        guard segmentHasCurve else {
            return (
                updatedStart,
                ImageEditorPathAnchor(point: interpolatedPoint(start.point, end.point, at: parameter)),
                updatedEnd
            )
        }

        let p0 = start.point
        let p1 = start.outControl ?? p0
        let p2 = end.inControl ?? end.point
        let p3 = end.point
        let q0 = interpolatedPoint(p0, p1, at: parameter)
        let q1 = interpolatedPoint(p1, p2, at: parameter)
        let q2 = interpolatedPoint(p2, p3, at: parameter)
        let r0 = interpolatedPoint(q0, q1, at: parameter)
        let r1 = interpolatedPoint(q1, q2, at: parameter)
        let splitPoint = interpolatedPoint(r0, r1, at: parameter)

        updatedStart.outControl = q0
        updatedEnd.inControl = q2
        let inserted = ImageEditorPathAnchor(
            point: splitPoint,
            inControl: r0,
            outControl: r1
        )
        return (updatedStart, inserted, updatedEnd)
    }

    private func interpolatedPoint(_ first: CGPoint, _ second: CGPoint, at parameter: CGFloat) -> CGPoint {
        CGPoint(
            x: first.x + (second.x - first.x) * parameter,
            y: first.y + (second.y - first.y) * parameter
        )
    }

    private func symmetricHandleVector(
        for anchor: ImageEditorPathAnchor,
        selectedRole: ImageEditorPathControlRole,
        previousPoint: CGPoint?,
        nextPoint: CGPoint?
    ) -> CGSize? {
        switch selectedRole {
        case .inHandle:
            if let inControl = anchor.inControl {
                return vector(from: inControl, to: anchor.point)
            }
        case .outHandle:
            if let outControl = anchor.outControl {
                return vector(from: anchor.point, to: outControl)
            }
        case .anchor:
            break
        }

        if let outControl = anchor.outControl {
            return vector(from: anchor.point, to: outControl)
        }
        if let inControl = anchor.inControl {
            return vector(from: inControl, to: anchor.point)
        }
        guard let previousPoint,
              let nextPoint
        else { return nil }
        let direction = vector(from: previousPoint, to: nextPoint)
        guard hypot(direction.width, direction.height) > 1 else { return nil }
        return CGSize(width: direction.width / 6, height: direction.height / 6)
    }

    private func symmetricPathControls(
        at index: Int,
        in anchors: [ImageEditorPathAnchor],
        closed: Bool,
        selectedRole: ImageEditorPathControlRole
    ) -> (inControl: CGPoint, outControl: CGPoint)? {
        guard anchors.indices.contains(index) else { return nil }
        let anchor = anchors[index]
        guard let vector = symmetricHandleVector(
            for: anchor,
            selectedRole: selectedRole,
            previousPoint: neighboringPathPoint(before: index, in: anchors, closed: closed),
            nextPoint: neighboringPathPoint(after: index, in: anchors, closed: closed)
        ) else { return nil }
        let scale = symmetricHandleScale(anchor: anchor.point, vector: vector)
        let boundedVector = CGSize(width: vector.width * scale, height: vector.height * scale)
        return (
            inControl: clampedCanvasPoint(
                CGPoint(x: anchor.point.x - boundedVector.width, y: anchor.point.y - boundedVector.height)
            ),
            outControl: clampedCanvasPoint(
                CGPoint(x: anchor.point.x + boundedVector.width, y: anchor.point.y + boundedVector.height)
            )
        )
    }

    private func symmetricHandleScale(anchor: CGPoint, vector: CGSize) -> CGFloat {
        var scale: CGFloat = 1

        func constrain(origin: CGFloat, delta: CGFloat, upperBound: CGFloat) {
            let magnitude = abs(delta)
            guard magnitude > 0 else { return }
            let positiveDistance = delta > 0 ? upperBound - origin : origin
            let negativeDistance = delta > 0 ? origin : upperBound - origin
            scale = min(
                scale,
                max(0, positiveDistance / magnitude),
                max(0, negativeDistance / magnitude)
            )
        }

        constrain(origin: anchor.x, delta: vector.width, upperBound: document.canvasSize.width)
        constrain(origin: anchor.y, delta: vector.height, upperBound: document.canvasSize.height)
        return scale
    }

    private func pathPointsMatch(_ lhs: CGPoint?, _ rhs: CGPoint?, epsilon: CGFloat = 0.000_001) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return abs(lhs.x - rhs.x) <= epsilon && abs(lhs.y - rhs.y) <= epsilon
        default:
            return false
        }
    }

    private var movingPathAnchorTransactionHasFinalChange: Bool {
        guard let layerID = movingPathAnchorOriginalLayerID,
              let layer = document.layers.first(where: { $0.id == layerID }),
              let content = layer.shapeContent,
              content.kind == .path,
              pathRectsMatch(layer.frame, movingPathAnchorOriginalFrame)
        else { return true }
        let currentSubpaths = content.allEditablePathSubpaths.map {
            canvasAnchors(for: $0, layer: layer)
        }
        return !pathSubpathsMatch(currentSubpaths, movingPathAnchorOriginalCanvasSubpaths)
    }

    private func pathSubpathsMatch(
        _ lhs: [[ImageEditorPathAnchor]],
        _ rhs: [[ImageEditorPathAnchor]]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { lhsSubpath, rhsSubpath in
            guard lhsSubpath.count == rhsSubpath.count else { return false }
            return zip(lhsSubpath, rhsSubpath).allSatisfy { lhsAnchor, rhsAnchor in
                pathPointsMatch(lhsAnchor.point, rhsAnchor.point)
                    && pathPointsMatch(lhsAnchor.inControl, rhsAnchor.inControl)
                    && pathPointsMatch(lhsAnchor.outControl, rhsAnchor.outControl)
            }
        }
    }

    private func pathRectsMatch(_ lhs: CGRect, _ rhs: CGRect?, epsilon: CGFloat = 0.000_001) -> Bool {
        guard let rhs else { return false }
        return abs(lhs.minX - rhs.minX) <= epsilon
            && abs(lhs.minY - rhs.minY) <= epsilon
            && abs(lhs.width - rhs.width) <= epsilon
            && abs(lhs.height - rhs.height) <= epsilon
    }

    private func resetMovingPathAnchorTransaction() {
        movingPathAnchorOriginalLayerID = nil
        movingPathAnchorOriginalCanvasSubpaths = []
        movingPathAnchorOriginalFrame = nil
    }

    private func vector(from start: CGPoint, to end: CGPoint) -> CGSize {
        CGSize(width: end.x - start.x, height: end.y - start.y)
    }

    private func reversePathAnchorDirection(_ anchor: ImageEditorPathAnchor) -> ImageEditorPathAnchor {
        ImageEditorPathAnchor(
            point: anchor.point,
            inControl: anchor.outControl,
            outControl: anchor.inControl
        )
    }

    private func offsetPathAnchor(_ anchor: ImageEditorPathAnchor, by delta: CGSize) -> ImageEditorPathAnchor {
        ImageEditorPathAnchor(
            point: CGPoint(x: anchor.point.x + delta.width, y: anchor.point.y + delta.height),
            inControl: anchor.inControl.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) },
            outControl: anchor.outControl.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
        )
    }

    func pathSelection(from savedPath: ImageEditorSavedPath) -> ImageEditorSelection? {
        guard savedPath.isClosed,
              let primarySubpath = savedPath.subpaths.first,
              primarySubpath.count >= 3
        else { return nil }
        let content = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 0,
            strokeOpacity: 0,
            pathPoints: primarySubpath.map(\.point),
            pathAnchors: primarySubpath,
            pathSubpaths: Array(savedPath.subpaths.dropFirst()),
            isPathClosed: true
        )
        return pathSelection(from: content, translation: .zero)
    }

    private func pathSelection(from content: ImageEditorShapeContent, layer: ImageEditorLayer) -> ImageEditorSelection? {
        pathSelection(from: content, translation: layer.frame.origin)
    }

    private func pathSelection(
        from content: ImageEditorShapeContent,
        translation: CGPoint
    ) -> ImageEditorSelection? {
        guard content.kind == .path,
              content.isPathClosed,
              content.editablePathAnchors.count >= 3
        else { return nil }

        let width = max(1, Int(document.canvasSize.width.rounded()))
        let height = max(1, Int(document.canvasSize.height.rounded()))
        let canvasSize = CGSize(width: width, height: height)
        let path = content.pathBezierPath()
        let transform = AffineTransform(translationByX: translation.x, byY: translation.y)
        path.transform(using: transform)

        guard let maskImage = NSImage.rendered(size: canvasSize, actions: { _ in
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: canvasSize.height) {
                NSColor.white.setFill()
                path.fill()
            }
        }),
            let mask = maskImage.pathAlphaMask(width: width, height: height),
            let bounds = mask.selectedBounds(in: document.canvasSize)
        else { return nil }
        return .raster(mask: mask, bounds: bounds)
    }
}

enum ImageEditorPenPointGeometry {
    private static let angleIncrement = CGFloat.pi / 4

    static func constrainedPoint(
        from origin: CGPoint,
        toward proposedPoint: CGPoint,
        canvasSize: CGSize
    ) -> CGPoint {
        let delta = CGVector(
            dx: proposedPoint.x - origin.x,
            dy: proposedPoint.y - origin.y
        )
        let length = hypot(delta.dx, delta.dy)
        guard length > 0.000_001 else { return origin }

        let rawAngle = atan2(delta.dy, delta.dx)
        let angle = (rawAngle / angleIncrement).rounded() * angleIncrement
        let direction = CGVector(dx: cos(angle), dy: sin(angle))
        let horizontalLimit = availableDistance(
            from: origin.x,
            direction: direction.dx,
            upperBound: canvasSize.width
        )
        let verticalLimit = availableDistance(
            from: origin.y,
            direction: direction.dy,
            upperBound: canvasSize.height
        )
        let boundedLength = min(length, min(horizontalLimit, verticalLimit))
        return CGPoint(
            x: min(max(0, origin.x + direction.dx * boundedLength), canvasSize.width),
            y: min(max(0, origin.y + direction.dy * boundedLength), canvasSize.height)
        )
    }

    static func symmetricControls(
        anchor: CGPoint,
        drag: CGSize,
        canvasSize: CGSize
    ) -> (inControl: CGPoint, outControl: CGPoint)? {
        guard hypot(drag.width, drag.height) > 0.000_001 else { return nil }
        var scale: CGFloat = 1
        if abs(drag.width) > 0.000_001 {
            scale = min(
                scale,
                anchor.x / abs(drag.width),
                max(0, canvasSize.width - anchor.x) / abs(drag.width)
            )
        }
        if abs(drag.height) > 0.000_001 {
            scale = min(
                scale,
                anchor.y / abs(drag.height),
                max(0, canvasSize.height - anchor.y) / abs(drag.height)
            )
        }
        let boundedDrag = CGSize(width: drag.width * scale, height: drag.height * scale)
        return (
            inControl: CGPoint(
                x: anchor.x - boundedDrag.width,
                y: anchor.y - boundedDrag.height
            ),
            outControl: CGPoint(
                x: anchor.x + boundedDrag.width,
                y: anchor.y + boundedDrag.height
            )
        )
    }

    static func isSmoothAnchor(_ anchor: ImageEditorPathAnchor) -> Bool {
        guard let inControl = anchor.inControl,
              let outControl = anchor.outControl
        else { return false }
        let incoming = CGVector(
            dx: inControl.x - anchor.point.x,
            dy: inControl.y - anchor.point.y
        )
        let outgoing = CGVector(
            dx: outControl.x - anchor.point.x,
            dy: outControl.y - anchor.point.y
        )
        let incomingLength = hypot(incoming.dx, incoming.dy)
        let outgoingLength = hypot(outgoing.dx, outgoing.dy)
        guard incomingLength > 0.000_001, outgoingLength > 0.000_001 else { return false }
        let normalizedCross = abs(incoming.dx * outgoing.dy - incoming.dy * outgoing.dx)
            / (incomingLength * outgoingLength)
        let dot = incoming.dx * outgoing.dx + incoming.dy * outgoing.dy
        return normalizedCross <= 0.001 && dot < 0
    }

    static func oppositeControl(
        anchor: CGPoint,
        movedControl: CGPoint,
        preferredLength: CGFloat,
        canvasSize: CGSize
    ) -> CGPoint? {
        let vector = CGVector(
            dx: anchor.x - movedControl.x,
            dy: anchor.y - movedControl.y
        )
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.000_001, preferredLength > 0.000_001 else { return nil }
        let direction = CGVector(dx: vector.dx / length, dy: vector.dy / length)
        let horizontalLimit = availableDistance(
            from: anchor.x,
            direction: direction.dx,
            upperBound: canvasSize.width
        )
        let verticalLimit = availableDistance(
            from: anchor.y,
            direction: direction.dy,
            upperBound: canvasSize.height
        )
        let boundedLength = min(preferredLength, horizontalLimit, verticalLimit)
        return CGPoint(
            x: min(max(0, anchor.x + direction.dx * boundedLength), canvasSize.width),
            y: min(max(0, anchor.y + direction.dy * boundedLength), canvasSize.height)
        )
    }

    private static func availableDistance(
        from origin: CGFloat,
        direction: CGFloat,
        upperBound: CGFloat
    ) -> CGFloat {
        guard abs(direction) > 0.000_001 else { return .greatestFiniteMagnitude }
        if direction > 0 {
            return max(0, upperBound - origin) / direction
        }
        return max(0, origin) / -direction
    }
}

private struct ImageEditorRasterBoundaryPoint: Hashable {
    var x: Int
    var y: Int
}

private struct ImageEditorRasterBoundaryEdge: Hashable {
    var start: ImageEditorRasterBoundaryPoint
    var end: ImageEditorRasterBoundaryPoint
}

private extension NSImage {
    func pathAlphaMask(width: Int, height: Int) -> ImageEditorSelectionMask? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                alpha[y * width + x] = pixels[offset + 3]
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }
}
