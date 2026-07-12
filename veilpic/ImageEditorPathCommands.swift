//
//  ImageEditorPathCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import CoreGraphics

extension ImageEditorViewModel {
    func isPenCloseCandidate(at point: CGPoint?) -> Bool {
        guard pendingPenPathPoints.count >= 3,
              let point,
              let first = pendingPenPathPoints.first
        else { return false }
        return distance(from: point, to: first) <= penCloseDistance
    }

    func addPenPoint(_ point: CGPoint?) {
        guard let point else { return }
        if isPenCloseCandidate(at: point) {
            finishPenPath(closed: true)
            return
        }
        pendingPenPathPoints.append(point)
        statusText = L10n.format("imageEditor.status.penPointAdded", pendingPenPathPoints.count)
    }

    @discardableResult
    func beginMovingPathAnchor(at point: CGPoint?) -> Bool {
        guard let point,
              selectNearestPathAnchor(at: point)
        else { return false }
        pushUndo()
        movingPathAnchorDidChange = false
        moveSelectedPathAnchor(to: point)
        return true
    }

    func moveSelectedPathAnchor(to point: CGPoint?) {
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
        let boundedPoint = CGPoint(
            x: max(0, min(document.canvasSize.width, point.x)),
            y: max(0, min(document.canvasSize.height, point.y))
        )
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
            guard canvasAnchors[index].inControl != boundedPoint else { return }
            canvasAnchors[index].inControl = boundedPoint
        case .outHandle:
            guard canvasAnchors[index].outControl != boundedPoint else { return }
            canvasAnchors[index].outControl = boundedPoint
        }
        updatePathLayer(
            at: layerIndex,
            shapeContent: shapeContent,
            canvasAnchors: canvasAnchors,
            editingSubpathIndex: selectedPathSubpathIndex
        )
        movingPathAnchorDidChange = true
    }

    func finishMovingPathAnchor() {
        guard movingPathAnchorDidChange else { return }
        movingPathAnchorDidChange = false
        appendHistory(L10n.text("imageEditor.history.pathAnchorMove"))
        statusText = L10n.text("imageEditor.status.pathAnchorMoved")
    }

    func setSelectedPathAnchorX(_ x: CGFloat) {
        guard let point = selectedPathAnchorCanvasPoint else { return }
        setSelectedPathAnchorPosition(CGPoint(x: x, y: point.y))
    }

    func setSelectedPathAnchorY(_ y: CGFloat) {
        guard let point = selectedPathAnchorCanvasPoint else { return }
        setSelectedPathAnchorPosition(CGPoint(x: point.x, y: y))
    }

    func selectNextPathAnchor() {
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
        selectAdjacentPathSubpath(offset: 1)
    }

    func selectPreviousPathSubpath() {
        selectAdjacentPathSubpath(offset: -1)
    }

    func smoothSelectedPathAnchor() {
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
        canvasAnchors[index].inControl = clampedCanvasPoint(
            CGPoint(x: anchor.x - vector.width * scale, y: anchor.y - vector.height * scale)
        )
        canvasAnchors[index].outControl = clampedCanvasPoint(
            CGPoint(x: anchor.x + vector.width * scale, y: anchor.y + vector.height * scale)
        )

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
        let anchorPoint = canvasAnchors[index].point
        guard let primaryVector = symmetricHandleVector(
            for: canvasAnchors[index],
            selectedRole: selectedPathControlRole,
            previousPoint: neighboringPathPoint(before: index, in: canvasAnchors, closed: shapeContent.isPathClosed),
            nextPoint: neighboringPathPoint(after: index, in: canvasAnchors, closed: shapeContent.isPathClosed)
        )
        else { return }

        canvasAnchors[index].inControl = clampedCanvasPoint(
            CGPoint(x: anchorPoint.x - primaryVector.width, y: anchorPoint.y - primaryVector.height)
        )
        canvasAnchors[index].outControl = clampedCanvasPoint(
            CGPoint(x: anchorPoint.x + primaryVector.width, y: anchorPoint.y + primaryVector.height)
        )

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

    func nudgeSelectedPathSubpath(dx: CGFloat, dy: CGFloat) {
        moveSelectedPathSubpath(by: CGSize(width: dx, height: dy))
    }

    func moveSelectedPathSubpath(by delta: CGSize) {
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

    func duplicateSelectedPathSubpath() {
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

        pushUndo()
        canvasSubpaths.insert(duplicatedAnchors, at: insertionIndex)
        updatePathLayer(at: layerIndex, shapeContent: shapeContent, canvasSubpaths: canvasSubpaths)
        selectedPathSubpathIndex = insertionIndex
        selectedPathAnchorIndex = duplicatedAnchors.isEmpty ? nil : 0
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathSubpathDuplicate"))
        statusText = L10n.text("imageEditor.status.pathSubpathDuplicated")
    }

    func clearSelectedPathAnchorHandles() {
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
        pushUndo()
        document.layers[targetIndex].vectorMask = vectorMask
        document.layers[targetIndex].isVectorMaskEnabled = true
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

        let nextSelection = ImageEditorSelection.combined(
            current: document.selection,
            candidate: selection,
            mode: selectionMode,
            canvasSize: document.canvasSize
        )
        guard document.selection != nil || selectionMode == .replace || selectionMode == .add else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }

        pushUndo()
        document.selection = nextSelection
        let historyKey = selectionMode == .replace ? "imageEditor.history.selectionFromPath" : selectionMode.historyKey
        appendHistory(L10n.text(historyKey))
        statusText = nextSelection == nil
            ? L10n.text("imageEditor.status.selectionEmpty")
            : L10n.text("imageEditor.status.selectionFromPath")
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

        pushUndo()
        updatePathLayer(at: layerIndex, shapeContent: shapeContent, canvasSubpaths: canvasSubpaths)
        selectedPathSubpathIndex = min(deletedIndex, canvasSubpaths.count - 1)
        selectedPathAnchorIndex = canvasSubpaths[selectedPathSubpathIndex].isEmpty ? nil : 0
        selectedPathControlRole = .anchor
        appendHistory(L10n.text("imageEditor.history.pathSubpathDelete"))
        statusText = L10n.text("imageEditor.status.pathSubpathDeleted")
    }

    func insertPathAnchorAfterSelection() {
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

        pushUndo()
        let targetLayer = document.layers[targetIndex]
        let output = document.isEffectivelyTransparencyLocked(targetLayer)
            ? (strokedImage.preservingAlpha(from: targetLayer.image) ?? strokedImage)
            : strokedImage
        document.layers[targetIndex].image = output.normalizedBitmapImage()
        appendHistory(L10n.text("imageEditor.history.pathStroke"))
        statusText = L10n.text("imageEditor.status.pathStroked")
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

        pushUndo()
        let targetLayer = document.layers[targetIndex]
        let output = document.isEffectivelyTransparencyLocked(targetLayer)
            ? (filledImage.preservingAlpha(from: targetLayer.image) ?? filledImage)
            : filledImage
        document.layers[targetIndex].image = output.normalizedBitmapImage()
        appendHistory(L10n.text("imageEditor.history.pathFill"))
        statusText = L10n.text("imageEditor.status.pathFilled")
    }


    func finishPenPath(closed: Bool) {
        guard canFinishPenPath else {
            statusText = L10n.text("imageEditor.status.penNeedsPoints")
            return
        }
        let points = pendingPenPathPoints
        pendingPenPathPoints = []
        addPathLayer(points: points, closed: closed)
    }

    func cancelPenPath() {
        guard !pendingPenPathPoints.isEmpty else { return }
        pendingPenPathPoints = []
        statusText = L10n.text("imageEditor.status.penCancelled")
    }

    private func addPathLayer(points: [CGPoint], closed: Bool) {
        guard points.count >= 2 else { return }
        let strokeWidth = max(1, min(96, brushSize * 0.35))
        let bounds = pointsBoundingRect(points)
        let padding = ceil(strokeWidth / 2 + 3)
        let frame = CGRect(
            x: bounds.minX - padding,
            y: bounds.minY - padding,
            width: max(1, bounds.width + padding * 2),
            height: max(1, bounds.height + padding * 2)
        )
        let localPoints = points.map { point in
            CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        }
        let localAnchors = localPoints.map { ImageEditorPathAnchor(point: $0) }
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

    private func setSelectedPathAnchorPosition(_ point: CGPoint) {
        pushUndo()
        selectedPathControlRole = .anchor
        moveSelectedPathAnchor(to: point)
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
            strokeWidth: max(1, min(96, strokeWidth)),
            strokeOpacity: 1,
            pathPoints: localAnchors.map(\.point),
            pathAnchors: localAnchors,
            pathSubpaths: Array(localSubpaths.dropFirst()),
            isPathClosed: true
        )
        var layer = ImageEditorLayer.shape(
            name: L10n.text("imageEditor.layer.vectorMaskPathName"),
            frame: frame,
            content: content
        )
        layer.opacity = 1
        layer.groupID = targetLayer.groupID
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
            isPathClosed: true
        )
        return NSImage.rendered(size: maskSize(for: targetLayer)) { _ in
            NSColor.white.setFill()
            maskContent.pathBezierPath().fill()
        }
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
        guard let targetAnchors = targetSubpaths.first else { return nil }
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
        guard let targetAnchors = targetSubpaths.first else { return nil }
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
            isPathClosed: sourceContent.isPathClosed
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
        to end: ImageEditorPathAnchor
    ) -> (start: ImageEditorPathAnchor, inserted: ImageEditorPathAnchor, end: ImageEditorPathAnchor) {
        var updatedStart = start
        var updatedEnd = end
        let segmentHasCurve = start.outControl != nil || end.inControl != nil
        guard segmentHasCurve else {
            return (
                updatedStart,
                ImageEditorPathAnchor(point: midpoint(start.point, end.point)),
                updatedEnd
            )
        }

        let p0 = start.point
        let p1 = start.outControl ?? p0
        let p2 = end.inControl ?? end.point
        let p3 = end.point
        let q0 = midpoint(p0, p1)
        let q1 = midpoint(p1, p2)
        let q2 = midpoint(p2, p3)
        let r0 = midpoint(q0, q1)
        let r1 = midpoint(q1, q2)
        let splitPoint = midpoint(r0, r1)

        updatedStart.outControl = q0
        updatedEnd.inControl = q2
        let inserted = ImageEditorPathAnchor(
            point: splitPoint,
            inControl: r0,
            outControl: r1
        )
        return (updatedStart, inserted, updatedEnd)
    }

    private func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
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

    private func pathSelection(from content: ImageEditorShapeContent, layer: ImageEditorLayer) -> ImageEditorSelection? {
        guard content.kind == .path,
              content.isPathClosed,
              content.editablePathAnchors.count >= 3
        else { return nil }

        let width = max(1, Int(document.canvasSize.width.rounded()))
        let height = max(1, Int(document.canvasSize.height.rounded()))
        let canvasSize = CGSize(width: width, height: height)
        let path = content.pathBezierPath()
        let transform = AffineTransform(translationByX: layer.frame.minX, byY: layer.frame.minY)
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
