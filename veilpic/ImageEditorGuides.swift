//
//  ImageEditorGuides.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    func addVerticalGuideAtCanvasCenter() {
        addGuide(.vertical, at: document.canvasSize.width / 2)
    }

    func addHorizontalGuideAtCanvasCenter() {
        addGuide(.horizontal, at: document.canvasSize.height / 2)
    }

    func addGuide(_ orientation: ImageEditorGuideOrientation, at position: CGFloat) {
        let clampedPosition = clampedGuidePosition(position, orientation: orientation)
        pushUndo()
        document.guides.append(
            ImageEditorGuide(
                orientation: orientation,
                position: clampedPosition
            )
        )
        document.areGuidesVisible = true
        document.areRulersVisible = true
        appendHistory(L10n.text("imageEditor.history.guideAdd"))
        statusText = L10n.text("imageEditor.status.guideAdded")
    }

    func deleteGuide(_ id: UUID) {
        guard let guide = document.guides.first(where: { $0.id == id }) else { return }
        pushUndo()
        document.guides.removeAll { $0.id == guide.id }
        appendHistory(L10n.text("imageEditor.history.guideDelete"))
        statusText = L10n.text("imageEditor.status.guideDeleted")
    }

    func clearGuides() {
        guard !document.guides.isEmpty else {
            statusText = L10n.text("imageEditor.status.noGuides")
            return
        }
        pushUndo()
        document.guides.removeAll()
        appendHistory(L10n.text("imageEditor.history.guidesClear"))
        statusText = L10n.text("imageEditor.status.guidesCleared")
    }

    func toggleGuidesVisible() {
        pushUndo()
        document.areGuidesVisible.toggle()
        appendHistory(L10n.text("imageEditor.history.guidesVisibility"))
        statusText = L10n.text(
            document.areGuidesVisible
                ? "imageEditor.status.guidesVisible"
                : "imageEditor.status.guidesHidden"
        )
    }

    func toggleRulersVisible() {
        pushUndo()
        document.areRulersVisible.toggle()
        appendHistory(L10n.text("imageEditor.history.rulersVisibility"))
        statusText = L10n.text(
            document.areRulersVisible
                ? "imageEditor.status.rulersVisible"
                : "imageEditor.status.rulersHidden"
        )
    }

    func toggleGuideSnapping() {
        pushUndo()
        document.isGuideSnappingEnabled.toggle()
        appendHistory(L10n.text("imageEditor.history.guidesSnapping"))
        statusText = L10n.text(
            document.isGuideSnappingEnabled
                ? "imageEditor.status.guidesSnappingOn"
                : "imageEditor.status.guidesSnappingOff"
        )
    }

    func toggleGridVisible() {
        pushUndo()
        document.isGridVisible.toggle()
        appendHistory(L10n.text("imageEditor.history.gridVisibility"))
        statusText = L10n.text(
            document.isGridVisible
                ? "imageEditor.status.gridVisible"
                : "imageEditor.status.gridHidden"
        )
    }

    func toggleGridSnapping() {
        pushUndo()
        document.isGridSnappingEnabled.toggle()
        if document.isGridSnappingEnabled {
            document.isGridVisible = true
        }
        appendHistory(L10n.text("imageEditor.history.gridSnapping"))
        statusText = L10n.text(
            document.isGridSnappingEnabled
                ? "imageEditor.status.gridSnappingOn"
                : "imageEditor.status.gridSnappingOff"
        )
    }

    var guideSummary: String {
        let verticalCount = document.guides.filter { $0.orientation == .vertical }.count
        let horizontalCount = document.guides.count - verticalCount
        return L10n.format("imageEditor.guides.summary", verticalCount, horizontalCount)
    }

    func beginMovingGuide(_ id: UUID) {
        guard movingGuideID == nil else { return }
        guard document.guides.contains(where: { $0.id == id }) else { return }
        pushUndo()
        movingGuideID = id
        movingGuideDidChange = false
    }

    func moveGuide(_ id: UUID, to position: CGFloat) {
        guard movingGuideID == id,
              let index = document.guides.firstIndex(where: { $0.id == id })
        else { return }
        let guide = document.guides[index]
        let clampedPosition = clampedGuidePosition(position, orientation: guide.orientation)
        guard abs(document.guides[index].position - clampedPosition) >= 0.1 else { return }
        document.guides[index].position = clampedPosition
        document.areGuidesVisible = true
        movingGuideDidChange = true
        statusText = L10n.text("imageEditor.status.guideMoved")
    }

    func finishMovingGuide() {
        guard movingGuideID != nil else { return }
        if movingGuideDidChange {
            appendHistory(L10n.text("imageEditor.history.guideMove"))
        } else {
            _ = undoStack.popLast()
            updateStatus()
        }
        movingGuideID = nil
        movingGuideDidChange = false
    }

    func snappedMoveDelta(_ delta: CGSize, movingLayerIDs: Set<UUID>) -> CGSize {
        guard document.isGuideSnappingEnabled || document.isGridSnappingEnabled,
              abs(delta.width) >= 0.1 || abs(delta.height) >= 0.1
        else { return delta }

        let indices = document.layers.indices.filter { movingLayerIDs.contains(document.layers[$0].id) }
        guard let currentFrame = transformFrame(for: Array(indices)) else { return delta }
        let proposedFrame = currentFrame.offsetBy(dx: delta.width, dy: delta.height)
        let threshold = max(1, 8 / max(zoom, 0.01))
        let snapGuides = guideSnapPositions(excluding: movingLayerIDs)
        guard !snapGuides.vertical.isEmpty || !snapGuides.horizontal.isEmpty else { return delta }
        let correctionX = guideCorrection(
            candidates: [proposedFrame.minX, proposedFrame.midX, proposedFrame.maxX],
            guides: snapGuides.vertical,
            threshold: threshold
        )
        let correctionY = guideCorrection(
            candidates: [proposedFrame.minY, proposedFrame.midY, proposedFrame.maxY],
            guides: snapGuides.horizontal,
            threshold: threshold
        )
        return CGSize(width: delta.width + correctionX, height: delta.height + correctionY)
    }

    func snappedResizeFrame(
        _ frame: CGRect,
        originalFrame: CGRect,
        handle: ImageEditorLayerResizeHandle,
        preservingAspectRatio: Bool
    ) -> CGRect {
        guard document.isGuideSnappingEnabled || document.isGridSnappingEnabled,
              !preservingAspectRatio
        else { return frame }

        let minimumSize: CGFloat = 4
        var snappedFrame = frame.standardized
        let threshold = max(1, 8 / max(zoom, 0.01))
        let snapGuides = guideSnapPositions(excluding: resizingLayerIDs)
        guard !snapGuides.vertical.isEmpty || !snapGuides.horizontal.isEmpty else { return frame }

        if handle.affectsWidth {
            let leftHandle = handle == .left || handle == .topLeft || handle == .bottomLeft
            let candidates: [(ImageEditorGuideSnapAnchor, CGFloat)] = leftHandle
                ? [(.minimum, snappedFrame.minX), (.middle, snappedFrame.midX)]
                : [(.maximum, snappedFrame.maxX), (.middle, snappedFrame.midX)]

            if let snap = bestGuideSnap(candidates: candidates, guides: snapGuides.vertical, threshold: threshold) {
                snappedFrame = resizeFrame(
                    snappedFrame,
                    applying: snap,
                    orientation: .vertical,
                    movesMinimumEdge: leftHandle,
                    minimumSize: minimumSize
                )
            }
        }

        if handle.affectsHeight {
            let bottomHandle = handle == .bottom || handle == .bottomLeft || handle == .bottomRight
            let candidates: [(ImageEditorGuideSnapAnchor, CGFloat)] = bottomHandle
                ? [(.minimum, snappedFrame.minY), (.middle, snappedFrame.midY)]
                : [(.maximum, snappedFrame.maxY), (.middle, snappedFrame.midY)]

            if let snap = bestGuideSnap(candidates: candidates, guides: snapGuides.horizontal, threshold: threshold) {
                snappedFrame = resizeFrame(
                    snappedFrame,
                    applying: snap,
                    orientation: .horizontal,
                    movesMinimumEdge: bottomHandle,
                    minimumSize: minimumSize
                )
            }
        }

        guard snappedFrame.width >= minimumSize,
              snappedFrame.height >= minimumSize,
              snappedFrame.isFinite
        else { return frame }

        return snappedFrame
    }

    func scaledGuides(scaleX: CGFloat, scaleY: CGFloat, targetCanvasSize: CGSize) -> [ImageEditorGuide] {
        document.guides.map { guide in
            var updated = guide
            switch guide.orientation {
            case .vertical:
                updated.position = clampedGuidePosition(
                    guide.position * scaleX,
                    orientation: .vertical,
                    canvasSize: targetCanvasSize
                )
            case .horizontal:
                updated.position = clampedGuidePosition(
                    guide.position * scaleY,
                    orientation: .horizontal,
                    canvasSize: targetCanvasSize
                )
            }
            return updated
        }
    }

    func offsetGuides(by offset: CGSize, targetCanvasSize: CGSize) -> [ImageEditorGuide] {
        document.guides.map { guide in
            var updated = guide
            switch guide.orientation {
            case .vertical:
                updated.position = clampedGuidePosition(
                    guide.position + offset.width,
                    orientation: .vertical,
                    canvasSize: targetCanvasSize
                )
            case .horizontal:
                updated.position = clampedGuidePosition(
                    guide.position + offset.height,
                    orientation: .horizontal,
                    canvasSize: targetCanvasSize
                )
            }
            return updated
        }
    }

    private func clampedGuidePosition(_ position: CGFloat, orientation: ImageEditorGuideOrientation) -> CGFloat {
        clampedGuidePosition(position, orientation: orientation, canvasSize: document.canvasSize)
    }

    private func clampedGuidePosition(
        _ position: CGFloat,
        orientation: ImageEditorGuideOrientation,
        canvasSize: CGSize
    ) -> CGFloat {
        let upperBound: CGFloat
        switch orientation {
        case .horizontal:
            upperBound = canvasSize.height
        case .vertical:
            upperBound = canvasSize.width
        }
        return min(max(0, position.rounded()), max(0, upperBound.rounded()))
    }

    private func guideCorrection(candidates: [CGFloat], guides: [CGFloat], threshold: CGFloat) -> CGFloat {
        var bestCorrection: CGFloat = 0
        var bestDistance = threshold

        for candidate in candidates {
            for guide in guides {
                let correction = guide - candidate
                let distance = abs(correction)
                if distance <= bestDistance {
                    bestDistance = distance
                    bestCorrection = correction
                }
            }
        }

        return bestCorrection
    }

    private func guideSnapPositions(excluding excludedLayerIDs: Set<UUID>) -> ImageEditorGuideSnapPositions {
        var vertical: [CGFloat] = []
        var horizontal: [CGFloat] = []

        if document.isGuideSnappingEnabled {
            vertical.append(contentsOf: document.guides.filter { $0.orientation == .vertical }.map(\.position))
            horizontal.append(contentsOf: document.guides.filter { $0.orientation == .horizontal }.map(\.position))

            for layer in document.layers {
                guard !excludedLayerIDs.contains(layer.id),
                      !layer.isGroup,
                      !layer.isAdjustment,
                      !layer.isFilter,
                      document.isEffectivelyVisible(layer)
                else { continue }

                let frame = layer.frame.standardized
                guard frame.width > 0.1, frame.height > 0.1 else { continue }
                vertical.append(contentsOf: [frame.minX, frame.midX, frame.maxX])
                horizontal.append(contentsOf: [frame.minY, frame.midY, frame.maxY])
            }
        }

        if document.isGridSnappingEnabled {
            vertical.append(contentsOf: gridSnapPositions(limit: document.canvasSize.width))
            horizontal.append(contentsOf: gridSnapPositions(limit: document.canvasSize.height))
        }

        return ImageEditorGuideSnapPositions(
            vertical: uniqueRoundedPositions(vertical),
            horizontal: uniqueRoundedPositions(horizontal)
        )
    }

    private func gridSnapPositions(limit: CGFloat) -> [CGFloat] {
        let spacing = max(4, min(512, document.gridSpacing))
        guard limit > 0 else { return [0] }
        let lineCount = Int((limit / spacing).rounded(.up))
        return (0...lineCount).map { index in
            min(limit, CGFloat(index) * spacing)
        }
    }

    private func uniqueRoundedPositions(_ positions: [CGFloat]) -> [CGFloat] {
        Array(Set(positions.map { $0.rounded() })).sorted()
    }

    private func bestGuideSnap(
        candidates: [(ImageEditorGuideSnapAnchor, CGFloat)],
        guides: [CGFloat],
        threshold: CGFloat
    ) -> ImageEditorGuideSnap? {
        var bestSnap: ImageEditorGuideSnap?
        var bestDistance = threshold

        for candidate in candidates {
            for guide in guides {
                let correction = guide - candidate.1
                let distance = abs(correction)
                if distance <= bestDistance {
                    bestDistance = distance
                    bestSnap = ImageEditorGuideSnap(anchor: candidate.0, correction: correction)
                }
            }
        }

        return bestSnap
    }

    private func resizeFrame(
        _ frame: CGRect,
        applying snap: ImageEditorGuideSnap,
        orientation: ImageEditorGuideOrientation,
        movesMinimumEdge: Bool,
        minimumSize: CGFloat
    ) -> CGRect {
        var minX = frame.minX
        var maxX = frame.maxX
        var minY = frame.minY
        var maxY = frame.maxY

        switch orientation {
        case .vertical:
            let edgeCorrection = snap.anchor == .middle ? snap.correction * 2 : snap.correction
            if movesMinimumEdge {
                minX = min(maxX - minimumSize, minX + edgeCorrection)
            } else {
                maxX = max(minX + minimumSize, maxX + edgeCorrection)
            }
        case .horizontal:
            let edgeCorrection = snap.anchor == .middle ? snap.correction * 2 : snap.correction
            if movesMinimumEdge {
                minY = min(maxY - minimumSize, minY + edgeCorrection)
            } else {
                maxY = max(minY + minimumSize, maxY + edgeCorrection)
            }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

private enum ImageEditorGuideSnapAnchor {
    case minimum
    case middle
    case maximum
}

private struct ImageEditorGuideSnap {
    var anchor: ImageEditorGuideSnapAnchor
    var correction: CGFloat
}

private struct ImageEditorGuideSnapPositions {
    var vertical: [CGFloat]
    var horizontal: [CGFloat]
}

private extension CGRect {
    var isFinite: Bool {
        minX.isFinite && minY.isFinite && width.isFinite && height.isFinite
    }
}
