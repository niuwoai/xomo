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
        document.areExtrasVisible = true
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

    func toggleExtrasVisible() {
        pushUndo()
        document.areExtrasVisible.toggle()
        appendHistory(L10n.text("imageEditor.history.extrasVisibility"))
        statusText = L10n.text(
            document.areExtrasVisible
                ? "imageEditor.status.extrasVisible"
                : "imageEditor.status.extrasHidden"
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

    func toggleGuidesLocked() {
        pushUndo()
        document.areGuidesLocked.toggle()
        appendHistory(L10n.text("imageEditor.history.guidesLocking"))
        statusText = L10n.text(
            document.areGuidesLocked
                ? "imageEditor.status.guidesLocked"
                : "imageEditor.status.guidesUnlocked"
        )
    }

    func toggleSelectionEdgesVisible() {
        pushUndo()
        document.areSelectionEdgesVisible.toggle()
        appendHistory(L10n.text("imageEditor.history.selectionEdgesVisibility"))
        statusText = L10n.text(
            document.areSelectionEdgesVisible
                ? "imageEditor.status.selectionEdgesVisible"
                : "imageEditor.status.selectionEdgesHidden"
        )
    }

    func toggleTransformControlsVisible() {
        pushUndo()
        document.areTransformControlsVisible.toggle()
        appendHistory(L10n.text("imageEditor.history.transformControlsVisibility"))
        statusText = L10n.text(
            document.areTransformControlsVisible
                ? "imageEditor.status.transformControlsVisible"
                : "imageEditor.status.transformControlsHidden"
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
            document.areExtrasVisible = true
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
        guard !document.areGuidesLocked else {
            statusText = L10n.text("imageEditor.status.guidesLocked")
            return
        }
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
            _ = discardLastUndoSnapshot()
            updateStatus()
        }
        movingGuideID = nil
        movingGuideDidChange = false
    }

    func snappedMoveDelta(_ delta: CGSize, movingLayerIDs: Set<UUID>) -> CGSize {
        guard document.isGuideSnappingEnabled || document.isGridSnappingEnabled,
              abs(delta.width) >= 0.1 || abs(delta.height) >= 0.1
        else {
            activeAlignmentGuides = []
            return delta
        }

        let indices = document.layers.indices.filter { movingLayerIDs.contains(document.layers[$0].id) }
        guard let currentFrame = movingObjectPreviewFrame ?? transformFrame(for: Array(indices)) else {
            activeAlignmentGuides = []
            return delta
        }
        let proposedFrame = currentFrame.offsetBy(dx: delta.width, dy: delta.height)
        let threshold = max(1, 8 / max(zoom, 0.01))
        let snapGuides = guideSnapPositions(excluding: movingLayerIDs)
        guard !snapGuides.vertical.isEmpty || !snapGuides.horizontal.isEmpty else {
            activeAlignmentGuides = []
            return delta
        }
        let horizontalSnap = nearestMoveAlignment(
            candidates: [proposedFrame.minX, proposedFrame.midX, proposedFrame.maxX],
            positions: snapGuides.vertical,
            threshold: threshold
        )
        let verticalSnap = nearestMoveAlignment(
            candidates: [proposedFrame.minY, proposedFrame.midY, proposedFrame.maxY],
            positions: snapGuides.horizontal,
            threshold: threshold
        )
        activeAlignmentGuides = [
            horizontalSnap.map { ImageEditorAlignmentGuide(orientation: .vertical, position: $0.position) },
            verticalSnap.map { ImageEditorAlignmentGuide(orientation: .horizontal, position: $0.position) }
        ].compactMap { $0 }
        return CGSize(
            width: delta.width + (horizontalSnap?.correction ?? 0),
            height: delta.height + (verticalSnap?.correction ?? 0)
        )
    }

    func snappedResizeFrame(
        _ frame: CGRect,
        originalFrame: CGRect,
        handle: ImageEditorLayerResizeHandle,
        preservingAspectRatio: Bool,
        resizingFromCenter: Bool = false
    ) -> CGRect {
        guard document.isGuideSnappingEnabled || document.isGridSnappingEnabled,
              !preservingAspectRatio
        else {
            activeAlignmentGuides = []
            return frame
        }

        let minimumSize: CGFloat = 4
        var snappedFrame = frame.standardized
        var alignmentGuides: [ImageEditorAlignmentGuide] = []
        let threshold = max(1, 8 / max(zoom, 0.01))
        let snapGuides = guideSnapPositions(excluding: resizingLayerIDs)
        guard !snapGuides.vertical.isEmpty || !snapGuides.horizontal.isEmpty else {
            activeAlignmentGuides = []
            return frame
        }

        if handle.affectsWidth {
            let leftHandle = handle == .left || handle == .topLeft || handle == .bottomLeft
            let candidates: [(ImageEditorGuideSnapAnchor, CGFloat)] = leftHandle
                ? [(.minimum, snappedFrame.minX)]
                : [(.maximum, snappedFrame.maxX)]
            let resolvedCandidates = resizingFromCenter
                ? candidates
                : candidates + [(.middle, snappedFrame.midX)]

            if let snap = bestGuideSnap(candidates: resolvedCandidates, guides: snapGuides.vertical, threshold: threshold) {
                snappedFrame = resizeFrame(
                    snappedFrame,
                    applying: snap,
                    orientation: .vertical,
                    movesMinimumEdge: leftHandle,
                    minimumSize: minimumSize,
                    resizingFromCenter: resizingFromCenter
                )
                alignmentGuides.append(
                    ImageEditorAlignmentGuide(orientation: .vertical, position: snap.position)
                )
            }
        }

        if handle.affectsHeight {
            let bottomHandle = handle == .bottom || handle == .bottomLeft || handle == .bottomRight
            let candidates: [(ImageEditorGuideSnapAnchor, CGFloat)] = bottomHandle
                ? [(.minimum, snappedFrame.minY)]
                : [(.maximum, snappedFrame.maxY)]
            let resolvedCandidates = resizingFromCenter
                ? candidates
                : candidates + [(.middle, snappedFrame.midY)]

            if let snap = bestGuideSnap(candidates: resolvedCandidates, guides: snapGuides.horizontal, threshold: threshold) {
                snappedFrame = resizeFrame(
                    snappedFrame,
                    applying: snap,
                    orientation: .horizontal,
                    movesMinimumEdge: bottomHandle,
                    minimumSize: minimumSize,
                    resizingFromCenter: resizingFromCenter
                )
                alignmentGuides.append(
                    ImageEditorAlignmentGuide(orientation: .horizontal, position: snap.position)
                )
            }
        }

        guard snappedFrame.width >= minimumSize,
              snappedFrame.height >= minimumSize,
              snappedFrame.isFinite
        else {
            activeAlignmentGuides = []
            return frame
        }

        activeAlignmentGuides = alignmentGuides
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
        document.guides.compactMap { guide in
            var updated = guide
            let position: CGFloat
            let upperBound: CGFloat
            switch guide.orientation {
            case .vertical:
                position = guide.position + offset.width
                upperBound = targetCanvasSize.width
            case .horizontal:
                position = guide.position + offset.height
                upperBound = targetCanvasSize.height
            }
            guard position >= 0, position <= upperBound else { return nil }
            updated.position = position.rounded()
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

    private func nearestMoveAlignment(
        candidates: [CGFloat],
        positions: [CGFloat],
        threshold: CGFloat
    ) -> ImageEditorMoveAlignment? {
        var bestAlignment: ImageEditorMoveAlignment?
        var bestDistance = threshold

        for candidate in candidates {
            for position in positions {
                let correction = position - candidate
                let distance = abs(correction)
                if (bestAlignment == nil && distance <= threshold) || distance < bestDistance {
                    bestDistance = distance
                    bestAlignment = ImageEditorMoveAlignment(position: position, correction: correction)
                }
            }
        }

        return bestAlignment
    }

    private func guideSnapPositions(excluding excludedLayerIDs: Set<UUID>) -> ImageEditorGuideSnapPositions {
        var vertical: [CGFloat] = []
        var horizontal: [CGFloat] = []

        if document.isGuideSnappingEnabled {
            vertical.append(contentsOf: document.guides.filter { $0.orientation == .vertical }.map(\.position))
            horizontal.append(contentsOf: document.guides.filter { $0.orientation == .horizontal }.map(\.position))

            // Sketch/Figma-style smart guides apply to every editable object:
            // snap edges and center lines to the artboard as well as to other
            // layers. Components and ordinary Photoshop layers therefore use
            // the same predictable alignment behavior.
            vertical.append(contentsOf: [
                0,
                document.canvasSize.width * 0.5,
                document.canvasSize.width
            ])
            horizontal.append(contentsOf: [
                0,
                document.canvasSize.height * 0.5,
                document.canvasSize.height
            ])

            let excludedGroupIDs = Set(document.layers.compactMap { layer in
                excludedLayerIDs.contains(layer.id) && layer.isGroup ? layer.id : nil
            })
            let componentGroupFrames = xomoComponentGuideFrames(excluding: excludedGroupIDs)
            for frame in componentGroupFrames.values {
                vertical.append(contentsOf: [frame.minX, frame.midX, frame.maxX])
                horizontal.append(contentsOf: [frame.minY, frame.midY, frame.maxY])
            }

            for layer in document.layers {
                guard !excludedLayerIDs.contains(layer.id),
                      !excludedGroupIDs.contains(layer.groupID ?? UUID()),
                      componentGroupFrames[layer.groupID ?? UUID()] == nil,
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

    private func xomoComponentGuideFrames(excluding excludedGroupIDs: Set<UUID>) -> [UUID: CGRect] {
        document.layers.reduce(into: [:]) { frames, layer in
            guard let groupID = layer.groupID,
                  !excludedGroupIDs.contains(groupID),
                  document.isEffectivelyVisible(layer),
                  let group = document.layers.first(where: { $0.id == groupID }),
                  group.xomoComponentInstance != nil
            else { return }

            let frame = layer.frame.standardized
            guard frame.width > 0.1, frame.height > 0.1 else { return }
            frames[groupID] = frames[groupID]?.union(frame) ?? frame
        }
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
                if (bestSnap == nil && distance <= threshold) || distance < bestDistance {
                    bestDistance = distance
                    bestSnap = ImageEditorGuideSnap(
                        anchor: candidate.0,
                        position: guide,
                        correction: correction
                    )
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
        minimumSize: CGFloat,
        resizingFromCenter: Bool
    ) -> CGRect {
        var minX = frame.minX
        var maxX = frame.maxX
        var minY = frame.minY
        var maxY = frame.maxY

        switch orientation {
        case .vertical:
            let edgeCorrection = snap.anchor == .middle ? snap.correction * 2 : snap.correction
            if resizingFromCenter {
                let centerX = frame.midX
                if movesMinimumEdge {
                    minX = min(centerX - minimumSize / 2, minX + edgeCorrection)
                    maxX = centerX + (centerX - minX)
                } else {
                    maxX = max(centerX + minimumSize / 2, maxX + edgeCorrection)
                    minX = centerX - (maxX - centerX)
                }
            } else if movesMinimumEdge {
                minX = min(maxX - minimumSize, minX + edgeCorrection)
            } else {
                maxX = max(minX + minimumSize, maxX + edgeCorrection)
            }
        case .horizontal:
            let edgeCorrection = snap.anchor == .middle ? snap.correction * 2 : snap.correction
            if resizingFromCenter {
                let centerY = frame.midY
                if movesMinimumEdge {
                    minY = min(centerY - minimumSize / 2, minY + edgeCorrection)
                    maxY = centerY + (centerY - minY)
                } else {
                    maxY = max(centerY + minimumSize / 2, maxY + edgeCorrection)
                    minY = centerY - (maxY - centerY)
                }
            } else if movesMinimumEdge {
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
    var position: CGFloat
    var correction: CGFloat
}

private struct ImageEditorGuideSnapPositions {
    var vertical: [CGFloat]
    var horizontal: [CGFloat]
}

struct ImageEditorAlignmentGuide: Identifiable, Equatable {
    let orientation: ImageEditorGuideOrientation
    let position: CGFloat

    var id: String { "\(orientation.rawValue)-\(position.rounded())" }
}

private struct ImageEditorMoveAlignment {
    let position: CGFloat
    let correction: CGFloat
}

private extension CGRect {
    var isFinite: Bool {
        minX.isFinite && minY.isFinite && width.isFinite && height.isFinite
    }
}
