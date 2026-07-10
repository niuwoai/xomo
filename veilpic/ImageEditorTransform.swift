//
//  ImageEditorTransform.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    var selectedLayerTransformFrame: CGRect? {
        guard !isEditingLayerMask else { return nil }
        return transformFrame(for: selectedTransformableLayerIndices)
    }

    var canResizeSelectedLayer: Bool {
        let indices = selectedTransformableLayerIndices
        guard !indices.isEmpty, selectedLayerTransformFrame != nil else { return false }
        return indices.allSatisfy { !document.isEffectivelyPositionLocked(document.layers[$0]) }
    }

    var canRotateSelectedLayer: Bool {
        canResizeSelectedLayer
    }

    var canFlipSelectedLayer: Bool {
        canResizeSelectedLayer
    }

    var canFitSelectedLayerToCanvas: Bool {
        canResizeSelectedLayer
    }

    var canFitSelectedLayerToSelection: Bool {
        canResizeSelectedLayer && hasSelection
    }

    var canTrimSelectedLayerTransparentPixels: Bool {
        guard let layer = document.selectedLayer,
              !isEditingLayerMask,
              !layer.isGroup,
              !layer.isAdjustment,
              !layer.isFilter,
              layer.kind.isPixel
        else { return false }
        return document.isEffectivelyVisible(layer)
            && !document.isEffectivelyPixelsLocked(layer)
            && !document.isEffectivelyPositionLocked(layer)
    }

    func beginMovingSelectedLayer() {
        guard movingLayerIDs.isEmpty else { return }
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        movingLayerIDs = Set(indices.map { document.layers[$0].id })
        movingLayerDidChange = false
    }

    func moveSelectedLayer(by delta: CGSize) {
        guard !movingLayerIDs.isEmpty else { return }
        guard abs(delta.width) >= 0.1 || abs(delta.height) >= 0.1 else { return }
        let adjustedDelta = snappedMoveDelta(delta, movingLayerIDs: movingLayerIDs)
        guard abs(adjustedDelta.width) >= 0.1 || abs(adjustedDelta.height) >= 0.1 else { return }
        for index in document.layers.indices where movingLayerIDs.contains(document.layers[index].id) {
            let originalFrame = document.layers[index].frame.standardized
            document.layers[index].frame.origin.x += adjustedDelta.width
            document.layers[index].frame.origin.y += adjustedDelta.height
            if !document.layers[index].isMaskLinked {
                if let mask = document.layers[index].mask,
                   let shiftedMask = mask.offsetMask(
                    by: CGSize(width: -adjustedDelta.width, height: -adjustedDelta.height)
                   ) {
                    document.layers[index].mask = shiftedMask
                }
                if let vectorMask = document.layers[index].vectorMask {
                    let localDelta = CGSize(
                        width: -adjustedDelta.width / max(originalFrame.width, 1)
                            * max(document.layers[index].image.size.width, 1),
                        height: -adjustedDelta.height / max(originalFrame.height, 1)
                            * max(document.layers[index].image.size.height, 1)
                    )
                    document.layers[index].vectorMask = vectorMask.offsetPath(by: localDelta)
                }
            }
        }
        movingLayerDidChange = true
        statusText = L10n.text("imageEditor.status.layerMoved")
    }

    func nudgeSelectionOrSelectedLayer(by delta: CGSize) {
        if hasSelection {
            nudgeSelection(by: delta)
            return
        }

        beginMovingSelectedLayer()
        moveSelectedLayer(by: delta)
        finishMovingSelectedLayer()
    }

    func finishMovingSelectedLayer() {
        guard !movingLayerIDs.isEmpty else { return }
        if movingLayerDidChange {
            appendHistory(L10n.text("imageEditor.history.layerTranslate"))
        } else {
            _ = undoStack.popLast()
            updateStatus()
        }
        movingLayerIDs = []
        movingLayerDidChange = false
    }

    func beginResizingSelectedLayer(handle: ImageEditorLayerResizeHandle) {
        guard resizingLayerIDs.isEmpty else { return }
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        _ = handle
        pushUndo()
        resizingLayerIDs = Set(indices.map { document.layers[$0].id })
        resizingOriginalFrames = indices.reduce(into: [:]) { frames, index in
            frames[document.layers[index].id] = document.layers[index].frame.standardized
        }
        resizingOriginalTransformFrame = transformFrame
        resizingLayerDidChange = false
    }

    func resizeSelectedLayer(
        to point: CGPoint,
        handle: ImageEditorLayerResizeHandle,
        preservingAspectRatio: Bool = false
    ) {
        guard !resizingLayerIDs.isEmpty,
              let originalFrame = resizingOriginalTransformFrame
        else { return }
        let resizedFrame = frameByDragging(
            handle: handle,
            from: originalFrame,
            to: point,
            preservingAspectRatio: preservingAspectRatio
        )
        let snappedFrame = snappedResizeFrame(
            resizedFrame,
            originalFrame: originalFrame,
            handle: handle,
            preservingAspectRatio: preservingAspectRatio
        )
        guard applyResizedTransformFrame(snappedFrame, originalTransformFrame: originalFrame) else { return }
        resizingLayerDidChange = true
        statusText = L10n.text("imageEditor.status.layerResized")
    }

    func finishResizingSelectedLayer() {
        guard !resizingLayerIDs.isEmpty else { return }
        if resizingLayerDidChange {
            appendHistory(L10n.text("imageEditor.history.layerResize"))
        } else {
            _ = undoStack.popLast()
            updateStatus()
        }
        resizingLayerIDs = []
        resizingOriginalFrames = [:]
        resizingOriginalTransformFrame = nil
        resizingLayerDidChange = false
    }

    func beginRotatingSelectedLayer(from point: CGPoint) {
        guard rotatingLayerIDs.isEmpty else { return }
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        rotatingLayerIDs = Set(indices.map { document.layers[$0].id })
        rotatingOriginalLayers = indices.reduce(into: [:]) { layers, index in
            layers[document.layers[index].id] = document.layers[index]
        }
        rotatingOriginalTransformFrame = transformFrame
        rotatingStartAngleDegrees = layerRotationAngle(from: transformFrame, to: point)
        rotatingLayerDidChange = false
    }

    func rotateSelectedLayer(
        to point: CGPoint,
        snappingToStep: Bool = false
    ) {
        guard !rotatingLayerIDs.isEmpty,
              let transformFrame = rotatingOriginalTransformFrame
        else { return }

        let currentAngle = layerRotationAngle(from: transformFrame, to: point)
        var degrees = normalizedRotationDelta(currentAngle - rotatingStartAngleDegrees)
        if snappingToStep {
            degrees = (degrees / 15).rounded() * 15
        }
        guard applyRotation(degrees: degrees, from: rotatingOriginalLayers, around: transformFrame) else { return }
        rotatingLayerDidChange = rotatingLayerDidChange || abs(degrees) > 0.1
        statusText = L10n.text("imageEditor.status.layerRotated")
    }

    func finishRotatingSelectedLayer() {
        guard !rotatingLayerIDs.isEmpty else { return }
        if rotatingLayerDidChange {
            appendHistory(L10n.text("imageEditor.history.layerRotate"))
        } else {
            _ = undoStack.popLast()
            updateStatus()
        }
        rotatingLayerIDs = []
        rotatingOriginalLayers = [:]
        rotatingOriginalTransformFrame = nil
        rotatingStartAngleDegrees = 0
        rotatingLayerDidChange = false
    }

    func scaleSelectedLayer(by factor: CGFloat) {
        guard factor > 0 else { return }
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        let originalFrames = indices.reduce(into: [:]) { frames, index in
            frames[document.layers[index].id] = document.layers[index].frame.standardized
        }
        let scaledSize = CGSize(
            width: max(1, transformFrame.width * factor),
            height: max(1, transformFrame.height * factor)
        )
        let scaledFrame = CGRect(
            x: transformFrame.midX - scaledSize.width / 2,
            y: transformFrame.midY - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        pushUndo()
        guard applyResizedTransformFrame(
            scaledFrame,
            originalTransformFrame: transformFrame,
            originalFrames: originalFrames
        ) else {
            _ = undoStack.popLast()
            updateStatus()
            return
        }
        appendHistory(L10n.text("imageEditor.history.layerScale"))
    }

    func rotateSelectedLayer(degrees: CGFloat) {
        guard abs(degrees) > 0.01 else { return }
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        pushUndo()
        let originalLayers = indices.reduce(into: [:]) { layers, index in
            layers[document.layers[index].id] = document.layers[index]
        }
        guard applyRotation(degrees: degrees, from: originalLayers, around: transformFrame) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        statusText = L10n.text("imageEditor.status.layerRotated")
        appendHistory(L10n.text("imageEditor.history.layerRotate"))
    }

    func rotateSelectedLayerLeft90() {
        rotateSelectedLayer(degrees: -90)
    }

    func rotateSelectedLayerRight90() {
        rotateSelectedLayer(degrees: 90)
    }

    func rotateSelectedLayer180() {
        rotateSelectedLayer(degrees: 180)
    }

    func flipSelectedLayerHorizontal() {
        flipSelectedLayer(
            horizontal: true,
            historyTitle: L10n.text("imageEditor.history.layerFlipHorizontal"),
            status: L10n.text("imageEditor.status.layerFlipHorizontal")
        )
    }

    func flipSelectedLayerVertical() {
        flipSelectedLayer(
            horizontal: false,
            historyTitle: L10n.text("imageEditor.history.layerFlipVertical"),
            status: L10n.text("imageEditor.status.layerFlipVertical")
        )
    }

    func fitSelectedLayerToCanvas() {
        transformSelectedLayer(
            to: CGRect(origin: .zero, size: document.canvasSize),
            mode: .fit,
            historyTitle: L10n.text("imageEditor.history.layerFitCanvas"),
            status: L10n.text("imageEditor.status.layerFitCanvas")
        )
    }

    func fillSelectedLayerToCanvas() {
        transformSelectedLayer(
            to: CGRect(origin: .zero, size: document.canvasSize),
            mode: .fill,
            historyTitle: L10n.text("imageEditor.history.layerFillCanvas"),
            status: L10n.text("imageEditor.status.layerFillCanvas")
        )
    }

    func fitSelectedLayerToSelection() {
        guard let targetBounds = selectionTargetBounds() else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        transformSelectedLayer(
            to: targetBounds,
            mode: .fit,
            historyTitle: L10n.text("imageEditor.history.layerFitSelection"),
            status: L10n.text("imageEditor.status.layerFitSelection")
        )
    }

    func fillSelectedLayerToSelection() {
        guard let targetBounds = selectionTargetBounds() else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        transformSelectedLayer(
            to: targetBounds,
            mode: .fill,
            historyTitle: L10n.text("imageEditor.history.layerFillSelection"),
            status: L10n.text("imageEditor.status.layerFillSelection")
        )
    }

    func trimSelectedLayerTransparentPixels() {
        guard canTrimSelectedLayerTransparentPixels,
              let layerID = document.selectedLayerID,
              let index = document.layers.firstIndex(where: { $0.id == layerID })
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        let layer = document.layers[index]
        guard let alphaBounds = layer.image.nonTransparentPixelBounds() else {
            statusText = L10n.text("imageEditor.status.layerTrimEmpty")
            return
        }

        let imageBounds = CGRect(origin: .zero, size: layer.image.size)
        guard !alphaBounds.isApproximatelyEqual(to: imageBounds) else {
            statusText = L10n.text("imageEditor.status.layerTrimNoTransparentPixels")
            return
        }

        guard let croppedImage = layer.image.cropped(to: alphaBounds) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        var trimmedLayer = layer
        trimmedLayer.image = croppedImage.normalizedBitmapImage()
        trimmedLayer.mask = trimmedLayer.mask?.cropped(to: alphaBounds)?.normalizedBitmapImage()
        if let vectorMask = trimmedLayer.vectorMask {
            trimmedLayer.vectorMask = vectorMask.offsetPath(
                by: CGSize(width: -alphaBounds.minX, height: -alphaBounds.minY)
            )
        }
        trimmedLayer.frame = layer.frame.frameMappingLocalRect(alphaBounds, imageSize: layer.image.size)

        pushUndo()
        document.layers[index] = trimmedLayer
        statusText = L10n.text("imageEditor.status.layerTrimTransparentPixels")
        appendHistory(L10n.text("imageEditor.history.layerTrimTransparentPixels"))
    }

    var selectedTransformableLayerIndices: [Int] {
        let baseLayerIDs = layerIDsExpandingGroups(document.selectedLayerIDs)
        let transformLayerIDs = linkedTransformLayerIDs(startingFrom: baseLayerIDs)
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return transformLayerIDs.contains(layer.id)
                && !layer.isGroup
                && !layer.isAdjustment
                && !layer.isFilter
                && document.isEffectivelyVisible(layer)
        }
    }

    func editableTransformLayerIndices() -> [Int] {
        let indices = selectedTransformableLayerIndices
        guard !indices.isEmpty,
              indices.allSatisfy({ !document.isEffectivelyPositionLocked(document.layers[$0]) })
        else { return [] }
        return indices
    }

    func transformFrame(for indices: [Int]) -> CGRect? {
        indices
            .map { document.layers[$0].frame.standardized }
            .reduce(nil) { bounds, frame in
                bounds?.union(frame) ?? frame
            }
    }

    func applyRotation(
        degrees: CGFloat,
        from originalLayers: [UUID: ImageEditorLayer],
        around transformFrame: CGRect
    ) -> Bool {
        let center = CGPoint(x: transformFrame.midX, y: transformFrame.midY)
        let radians = degrees * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        var rotatedLayers: [UUID: ImageEditorLayer] = [:]

        for (id, originalLayer) in originalLayers {
            var rotatedLayer = originalLayer
            let originalFrame = originalLayer.frame.standardized
            let originalCenter = CGPoint(x: originalFrame.midX, y: originalFrame.midY)
            let rotatedCenter: CGPoint
            if abs(degrees) <= 0.01 {
                rotatedCenter = originalCenter
            } else {
                let offset = CGPoint(x: originalCenter.x - center.x, y: originalCenter.y - center.y)
                rotatedCenter = CGPoint(
                    x: center.x + offset.x * cosine - offset.y * sine,
                    y: center.y + offset.x * sine + offset.y * cosine
                )
                guard let rotatedImage = originalLayer.image.rotated(degrees: degrees) else {
                    statusText = L10n.text("imageEditor.status.operationFailed")
                    return false
                }
                rotatedLayer.image = rotatedImage
                if originalLayer.isMaskLinked {
                    rotatedLayer.mask = originalLayer.mask?.rotated(degrees: degrees)
                }
            }
            rotatedLayer.frame = CGRect(
                x: rotatedCenter.x - rotatedLayer.image.size.width / 2,
                y: rotatedCenter.y - rotatedLayer.image.size.height / 2,
                width: rotatedLayer.image.size.width,
                height: rotatedLayer.image.size.height
            )
            rotatedLayers[id] = rotatedLayer
        }

        for index in document.layers.indices {
            let id = document.layers[index].id
            if let rotatedLayer = rotatedLayers[id] {
                document.layers[index] = rotatedLayer
            }
        }
        return true
    }

    func applyResizedTransformFrame(
        _ targetFrame: CGRect,
        originalTransformFrame: CGRect,
        originalFrames: [UUID: CGRect]? = nil
    ) -> Bool {
        guard originalTransformFrame.width > 0.1,
              originalTransformFrame.height > 0.1
        else { return false }
        let scaleX = targetFrame.width / originalTransformFrame.width
        let scaleY = targetFrame.height / originalTransformFrame.height
        let sourceFrames = originalFrames ?? resizingOriginalFrames
        var changed = false

        for index in document.layers.indices {
            let id = document.layers[index].id
            guard let originalFrame = sourceFrames[id] else { continue }
            let resizedFrame = CGRect(
                x: targetFrame.minX + (originalFrame.minX - originalTransformFrame.minX) * scaleX,
                y: targetFrame.minY + (originalFrame.minY - originalTransformFrame.minY) * scaleY,
                width: max(1, originalFrame.width * scaleX),
                height: max(1, originalFrame.height * scaleY)
            )
            changed = changed
                || abs(resizedFrame.width - document.layers[index].frame.width) >= 0.1
                || abs(resizedFrame.height - document.layers[index].frame.height) >= 0.1
                || abs(resizedFrame.minX - document.layers[index].frame.minX) >= 0.1
                || abs(resizedFrame.minY - document.layers[index].frame.minY) >= 0.1
            document.layers[index].frame = resizedFrame
        }

        return changed
    }

    private func flipSelectedLayer(horizontal: Bool, historyTitle: String, status: String) {
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        pushUndo()
        let originalLayers = indices.reduce(into: [:]) { layers, index in
            layers[document.layers[index].id] = document.layers[index]
        }
        guard applyFlip(horizontal: horizontal, from: originalLayers, around: transformFrame) else {
            _ = undoStack.popLast()
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        statusText = status
        appendHistory(historyTitle)
    }

    private func applyFlip(
        horizontal: Bool,
        from originalLayers: [UUID: ImageEditorLayer],
        around transformFrame: CGRect
    ) -> Bool {
        let bounds = transformFrame.standardized
        var flippedLayers: [UUID: ImageEditorLayer] = [:]

        for (id, originalLayer) in originalLayers {
            guard let flippedImage = originalLayer.image.flipped(horizontal: horizontal) else {
                return false
            }

            let originalFrame = originalLayer.frame.standardized
            var flippedLayer = originalLayer
            flippedLayer.image = flippedImage
            if originalLayer.isMaskLinked {
                flippedLayer.mask = originalLayer.mask?.flipped(horizontal: horizontal)
            }

            if horizontal {
                flippedLayer.frame = CGRect(
                    x: bounds.minX + (bounds.maxX - originalFrame.maxX),
                    y: originalFrame.minY,
                    width: originalFrame.width,
                    height: originalFrame.height
                )
            } else {
                flippedLayer.frame = CGRect(
                    x: originalFrame.minX,
                    y: bounds.minY + (bounds.maxY - originalFrame.maxY),
                    width: originalFrame.width,
                    height: originalFrame.height
                )
            }
            flippedLayers[id] = flippedLayer
        }

        for index in document.layers.indices {
            let id = document.layers[index].id
            if let flippedLayer = flippedLayers[id] {
                document.layers[index] = flippedLayer
            }
        }
        return true
    }

    private func transformSelectedLayer(
        to targetBounds: CGRect,
        mode: ImageEditorLayerFitMode,
        historyTitle: String,
        status: String
    ) {
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        let boundedTarget = targetBounds.standardized
        guard boundedTarget.width > 0.1, boundedTarget.height > 0.1 else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let originalFrames = indices.reduce(into: [:]) { frames, index in
            frames[document.layers[index].id] = document.layers[index].frame.standardized
        }
        let targetFrame = fittedTransformFrame(for: transformFrame, in: boundedTarget, mode: mode)

        pushUndo()
        guard applyResizedTransformFrame(
            targetFrame,
            originalTransformFrame: transformFrame,
            originalFrames: originalFrames
        ) else {
            _ = undoStack.popLast()
            updateStatus()
            return
        }

        statusText = status
        appendHistory(historyTitle)
    }

    private func selectionTargetBounds() -> CGRect? {
        guard let selection = document.selection else { return nil }
        let canvasRect = CGRect(origin: .zero, size: document.canvasSize)
        let bounds = selection.bounds.standardized.intersection(canvasRect)
        guard !bounds.isNull, bounds.width > 0.1, bounds.height > 0.1 else { return nil }
        return bounds
    }

    private func fittedTransformFrame(
        for sourceFrame: CGRect,
        in targetBounds: CGRect,
        mode: ImageEditorLayerFitMode
    ) -> CGRect {
        let scaleX = targetBounds.width / max(sourceFrame.width, 1)
        let scaleY = targetBounds.height / max(sourceFrame.height, 1)
        let scale = mode == .fit ? min(scaleX, scaleY) : max(scaleX, scaleY)
        let outputSize = CGSize(
            width: max(1, sourceFrame.width * scale),
            height: max(1, sourceFrame.height * scale)
        )
        return CGRect(
            x: targetBounds.midX - outputSize.width / 2,
            y: targetBounds.midY - outputSize.height / 2,
            width: outputSize.width,
            height: outputSize.height
        )
    }

    func layerRotationAngle(from frame: CGRect, to point: CGPoint) -> CGFloat {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return atan2(point.y - center.y, point.x - center.x) * 180 / .pi
    }

    func normalizedRotationDelta(_ degrees: CGFloat) -> CGFloat {
        var normalized = degrees.truncatingRemainder(dividingBy: 360)
        if normalized > 180 {
            normalized -= 360
        } else if normalized < -180 {
            normalized += 360
        }
        return normalized
    }

    func frameByDragging(
        handle: ImageEditorLayerResizeHandle,
        from originalFrame: CGRect,
        to point: CGPoint,
        preservingAspectRatio: Bool
    ) -> CGRect {
        let minimumSize: CGFloat = 4
        var minX = originalFrame.minX
        var maxX = originalFrame.maxX
        var minY = originalFrame.minY
        var maxY = originalFrame.maxY

        switch handle {
        case .topLeft:
            minX = min(point.x, originalFrame.maxX - minimumSize)
            maxY = max(point.y, originalFrame.minY + minimumSize)
        case .top:
            maxY = max(point.y, originalFrame.minY + minimumSize)
        case .topRight:
            maxX = max(point.x, originalFrame.minX + minimumSize)
            maxY = max(point.y, originalFrame.minY + minimumSize)
        case .left:
            minX = min(point.x, originalFrame.maxX - minimumSize)
        case .right:
            maxX = max(point.x, originalFrame.minX + minimumSize)
        case .bottomLeft:
            minX = min(point.x, originalFrame.maxX - minimumSize)
            minY = min(point.y, originalFrame.maxY - minimumSize)
        case .bottom:
            minY = min(point.y, originalFrame.maxY - minimumSize)
        case .bottomRight:
            maxX = max(point.x, originalFrame.minX + minimumSize)
            minY = min(point.y, originalFrame.maxY - minimumSize)
        }

        let unconstrainedFrame = CGRect(
            x: minX,
            y: minY,
            width: max(minimumSize, maxX - minX),
            height: max(minimumSize, maxY - minY)
        )
        guard preservingAspectRatio else { return unconstrainedFrame }
        return aspectConstrainedFrame(
            unconstrainedFrame,
            originalFrame: originalFrame,
            handle: handle,
            minimumSize: minimumSize
        )
    }

    func aspectConstrainedFrame(
        _ frame: CGRect,
        originalFrame: CGRect,
        handle: ImageEditorLayerResizeHandle,
        minimumSize: CGFloat
    ) -> CGRect {
        let aspectRatio = max(originalFrame.width, minimumSize) / max(originalFrame.height, minimumSize)
        let horizontalScale = frame.width / max(originalFrame.width, minimumSize)
        let verticalScale = frame.height / max(originalFrame.height, minimumSize)
        let scale = max(minimumSize / max(originalFrame.width, minimumSize), minimumSize / max(originalFrame.height, minimumSize), horizontalScale, verticalScale)
        var width = max(minimumSize, originalFrame.width * scale)
        var height = max(minimumSize, width / max(aspectRatio, 0.0001))

        if !handle.affectsWidth {
            height = frame.height
            width = max(minimumSize, height * aspectRatio)
        } else if !handle.affectsHeight {
            width = frame.width
            height = max(minimumSize, width / max(aspectRatio, 0.0001))
        }

        switch handle {
        case .topLeft:
            return CGRect(x: originalFrame.maxX - width, y: originalFrame.minY, width: width, height: height)
        case .top:
            return CGRect(x: originalFrame.midX - width / 2, y: originalFrame.minY, width: width, height: height)
        case .topRight:
            return CGRect(x: originalFrame.minX, y: originalFrame.minY, width: width, height: height)
        case .left:
            return CGRect(x: originalFrame.maxX - width, y: originalFrame.midY - height / 2, width: width, height: height)
        case .right:
            return CGRect(x: originalFrame.minX, y: originalFrame.midY - height / 2, width: width, height: height)
        case .bottomLeft:
            return CGRect(x: originalFrame.maxX - width, y: originalFrame.maxY - height, width: width, height: height)
        case .bottom:
            return CGRect(x: originalFrame.midX - width / 2, y: originalFrame.maxY - height, width: width, height: height)
        case .bottomRight:
            return CGRect(x: originalFrame.minX, y: originalFrame.maxY - height, width: width, height: height)
        }
    }
}

private enum ImageEditorLayerFitMode {
    case fit
    case fill
}

private extension CGRect {
    func frameMappingLocalRect(_ localRect: CGRect, imageSize: CGSize) -> CGRect {
        let sourceWidth = max(imageSize.width, 1)
        let sourceHeight = max(imageSize.height, 1)
        let standardizedFrame = standardized
        return CGRect(
            x: standardizedFrame.minX + localRect.minX / sourceWidth * standardizedFrame.width,
            y: standardizedFrame.minY + localRect.minY / sourceHeight * standardizedFrame.height,
            width: max(1, localRect.width / sourceWidth * standardizedFrame.width),
            height: max(1, localRect.height / sourceHeight * standardizedFrame.height)
        )
    }

    func isApproximatelyEqual(to other: CGRect, tolerance: CGFloat = 0.01) -> Bool {
        abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}

extension NSImage {
    func nonTransparentPixelBounds(alphaThreshold: UInt8 = 0) -> CGRect? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

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
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
                guard alpha > alphaThreshold else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        let scaleX = size.width / CGFloat(width)
        let scaleY = size.height / CGFloat(height)
        return CGRect(
            x: CGFloat(minX) * scaleX,
            y: CGFloat(minY) * scaleY,
            width: CGFloat(maxX - minX + 1) * scaleX,
            height: CGFloat(maxY - minY + 1) * scaleY
        )
    }
}

private extension ImageEditorShapeContent {
    func offsetPath(by delta: CGSize) -> ImageEditorShapeContent {
        guard kind == .path else { return self }
        var content = self
        content.pathAnchors = editablePathAnchors.map { anchor in
            ImageEditorPathAnchor(
                point: anchor.point.offset(by: delta),
                inControl: anchor.inControl?.offset(by: delta),
                outControl: anchor.outControl?.offset(by: delta)
            )
        }
        content.pathPoints = content.pathAnchors.map(\.point)
        content.pathSubpaths = editablePathSubpaths.map { subpath in
            subpath.map { anchor in
                ImageEditorPathAnchor(
                    point: anchor.point.offset(by: delta),
                    inControl: anchor.inControl?.offset(by: delta),
                    outControl: anchor.outControl?.offset(by: delta)
                )
            }
        }
        return content
    }
}

private extension CGPoint {
    func offset(by delta: CGSize) -> CGPoint {
        CGPoint(x: x + delta.width, y: y + delta.height)
    }
}
