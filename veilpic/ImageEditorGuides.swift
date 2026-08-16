//
//  ImageEditorGuides.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

enum ImageEditorObjectDistanceInspectionPolicy {
    static func shouldShow(
        sidebarTab: XomoLeftSidebarTab,
        selectedTool: ImageEditorTool,
        modifierFlags: NSEvent.ModifierFlags,
        hasActiveInteraction: Bool
    ) -> Bool {
        guard modifierFlags.contains(.option), !hasActiveInteraction else { return false }
        switch sidebarTab {
        case .components:
            return true
        case .tools:
            return selectedTool == .move
        }
    }
}

enum ImageEditorObjectDistanceInspectionTargetResolver {
    static func frame(
        hoveredObjectFrame: CGRect?,
        canvasSize: CGSize
    ) -> CGRect? {
        if let hoveredObjectFrame {
            let frame = hoveredObjectFrame.standardized
            guard frame.minX.isFinite,
                  frame.minY.isFinite,
                  frame.maxX.isFinite,
                  frame.maxY.isFinite,
                  frame.width > 0,
                  frame.height > 0
            else { return nil }
            return frame
        }
        guard canvasSize.width.isFinite,
              canvasSize.height.isFinite,
              canvasSize.width > 0,
              canvasSize.height > 0
        else { return nil }
        return CGRect(origin: .zero, size: canvasSize)
    }
}

enum ImageEditorObjectDistanceMeasurement {
    static func guides(from sourceFrame: CGRect, to targetFrame: CGRect) -> [ImageEditorSpacingGuide] {
        let source = sourceFrame.standardized
        let target = targetFrame.standardized
        guard source.width > 0, source.height > 0, target.width > 0, target.height > 0 else {
            return []
        }
        if source != target {
            if source.contains(target) {
                return paddingGuides(outer: source, inner: target)
            }
            if target.contains(source) {
                return paddingGuides(outer: target, inner: source)
            }
        }

        let overlapX = overlap(source.minX...source.maxX, target.minX...target.maxX)
        let overlapY = overlap(source.minY...source.maxY, target.minY...target.maxY)
        let horizontalGap: (left: CGRect, right: CGRect)?
        if source.maxX <= target.minX {
            horizontalGap = (source, target)
        } else if target.maxX <= source.minX {
            horizontalGap = (target, source)
        } else {
            horizontalGap = nil
        }
        let verticalGap: (upper: CGRect, lower: CGRect)?
        if source.maxY <= target.minY {
            verticalGap = (source, target)
        } else if target.maxY <= source.minY {
            verticalGap = (target, source)
        } else {
            verticalGap = nil
        }

        var guides: [ImageEditorSpacingGuide] = []
        if let horizontalGap {
            let crossPosition = overlapY.map { midpoint(of: $0) }
                ?? (horizontalGap.left.maxY <= horizontalGap.right.minY
                    ? horizontalGap.left.maxY
                    : horizontalGap.left.minY)
            guides.append(
                ImageEditorSpacingGuide(
                    orientation: .horizontal,
                    start: CGPoint(x: horizontalGap.left.maxX, y: crossPosition),
                    end: CGPoint(x: horizontalGap.right.minX, y: crossPosition)
                )
            )
        }

        if let verticalGap,
           let crossPosition = overlapX.map({ midpoint(of: $0) }) ?? horizontalGap?.right.minX {
            guides.append(
                ImageEditorSpacingGuide(
                    orientation: .vertical,
                    start: CGPoint(x: crossPosition, y: verticalGap.upper.maxY),
                    end: CGPoint(x: crossPosition, y: verticalGap.lower.minY)
                )
            )
        }
        return guides
    }

    private static func paddingGuides(outer: CGRect, inner: CGRect) -> [ImageEditorSpacingGuide] {
        [
            ImageEditorSpacingGuide(
                orientation: .horizontal,
                start: CGPoint(x: outer.minX, y: inner.midY),
                end: CGPoint(x: inner.minX, y: inner.midY)
            ),
            ImageEditorSpacingGuide(
                orientation: .horizontal,
                start: CGPoint(x: inner.maxX, y: inner.midY),
                end: CGPoint(x: outer.maxX, y: inner.midY)
            ),
            ImageEditorSpacingGuide(
                orientation: .vertical,
                start: CGPoint(x: inner.midX, y: outer.minY),
                end: CGPoint(x: inner.midX, y: inner.minY)
            ),
            ImageEditorSpacingGuide(
                orientation: .vertical,
                start: CGPoint(x: inner.midX, y: inner.maxY),
                end: CGPoint(x: inner.midX, y: outer.maxY)
            )
        ]
    }

    private static func midpoint(of range: ClosedRange<CGFloat>) -> CGFloat {
        (range.lowerBound + range.upperBound) / 2
    }

    private static func overlap(
        _ lhs: ClosedRange<CGFloat>,
        _ rhs: ClosedRange<CGFloat>
    ) -> ClosedRange<CGFloat>? {
        let lowerBound = max(lhs.lowerBound, rhs.lowerBound)
        let upperBound = min(lhs.upperBound, rhs.upperBound)
        guard lowerBound <= upperBound else { return nil }
        return lowerBound...upperBound
    }
}

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
            activeSpacingGuides = []
            return delta
        }

        let indices = document.layers.indices.filter { movingLayerIDs.contains(document.layers[$0].id) }
        guard let currentFrame = movingObjectPreviewFrame ?? transformFrame(for: Array(indices)) else {
            activeAlignmentGuides = []
            activeSpacingGuides = []
            return delta
        }
        let proposedFrame = currentFrame.offsetBy(dx: delta.width, dy: delta.height)
        let threshold = max(1, 8 / max(zoom, 0.01))
        let snapGuides = guideSnapPositions(excluding: movingLayerIDs)
        let peerFrames = document.isGuideSnappingEnabled
            ? smartGuideObjectFrames(excluding: movingLayerIDs)
            : []
        guard !snapGuides.vertical.isEmpty || !snapGuides.horizontal.isEmpty || peerFrames.count >= 2 else {
            activeAlignmentGuides = []
            activeSpacingGuides = []
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
        let horizontalSpacingSnap = nearestEqualSpacing(
            for: proposedFrame,
            among: peerFrames,
            orientation: .horizontal,
            threshold: threshold
        )
        let verticalSpacingSnap = nearestEqualSpacing(
            for: proposedFrame,
            among: peerFrames,
            orientation: .vertical,
            threshold: threshold
        )
        let useHorizontalSpacing = shouldPreferSpacing(
            horizontalSpacingSnap,
            over: horizontalSnap
        )
        let useVerticalSpacing = shouldPreferSpacing(
            verticalSpacingSnap,
            over: verticalSnap
        )
        let horizontalCorrection = (
            useHorizontalSpacing
                ? horizontalSpacingSnap?.correction
                : horizontalSnap?.correction
        ) ?? 0
        let verticalCorrection = (
            useVerticalSpacing
                ? verticalSpacingSnap?.correction
                : verticalSnap?.correction
        ) ?? 0
        activeAlignmentGuides = [
            useHorizontalSpacing ? nil : horizontalSnap.map {
                ImageEditorAlignmentGuide(orientation: .vertical, position: $0.position)
            },
            useVerticalSpacing ? nil : verticalSnap.map {
                ImageEditorAlignmentGuide(orientation: .horizontal, position: $0.position)
            }
        ].compactMap { $0 }
        activeSpacingGuides = [
            useHorizontalSpacing
                ? horizontalSpacingSnap?.guides.map {
                    $0.offsetBy(dx: 0, dy: verticalCorrection)
                }
                : nil,
            useVerticalSpacing
                ? verticalSpacingSnap?.guides.map {
                    $0.offsetBy(dx: horizontalCorrection, dy: 0)
                }
                : nil
        ].compactMap { $0 }.flatMap { $0 }
        return CGSize(
            width: delta.width + horizontalCorrection,
            height: delta.height + verticalCorrection
        )
    }

    func snappedResizeFrame(
        _ frame: CGRect,
        originalFrame: CGRect,
        handle: ImageEditorLayerResizeHandle,
        preservingAspectRatio: Bool,
        resizingFromCenter: Bool = false
    ) -> CGRect {
        activeSpacingGuides = []
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
            let edgeSnap = bestGuideSnap(
                candidates: candidates,
                guides: snapGuides.vertical,
                threshold: threshold
            )
            let centerSnap = resizingFromCenter
                ? nil
                : bestGuideSnap(
                    candidates: [(.middle, snappedFrame.midX)],
                    guides: snapGuides.vertical,
                    threshold: threshold
                )

            if let snap = edgeSnap ?? centerSnap {
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
            let edgeSnap = bestGuideSnap(
                candidates: candidates,
                guides: snapGuides.horizontal,
                threshold: threshold
            )
            let centerSnap = resizingFromCenter
                ? nil
                : bestGuideSnap(
                    candidates: [(.middle, snappedFrame.midY)],
                    guides: snapGuides.horizontal,
                    threshold: threshold
                )

            if let snap = edgeSnap ?? centerSnap {
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

            for frame in smartGuideObjectFrames(excluding: excludedLayerIDs) {
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

    private func smartGuideObjectFrames(excluding excludedLayerIDs: Set<UUID>) -> [CGRect] {
        let excludedGroupIDs = Set(document.layers.compactMap { layer in
            excludedLayerIDs.contains(layer.id) && layer.isGroup ? layer.id : nil
        })
        let componentGroupFrames = xomoComponentGuideFrames(excluding: excludedGroupIDs)
        var frames = Array(componentGroupFrames.values)

        for layer in document.layers {
            let belongsToExcludedGroup = layer.groupID.map(excludedGroupIDs.contains) ?? false
            let belongsToComponent = layer.groupID.map { componentGroupFrames[$0] != nil } ?? false
            guard !excludedLayerIDs.contains(layer.id),
                  !belongsToExcludedGroup,
                  !belongsToComponent,
                  !layer.isGroup,
                  !layer.isAdjustment,
                  !layer.isFilter,
                  document.isEffectivelyVisible(layer)
            else { continue }

            let frame = layer.frame.standardized
            guard frame.width > 0.1, frame.height > 0.1 else { continue }
            frames.append(frame)
        }
        return frames
    }

    private func nearestEqualSpacing(
        for proposedFrame: CGRect,
        among peerFrames: [CGRect],
        orientation: ImageEditorGuideOrientation,
        threshold: CGFloat
    ) -> ImageEditorEqualSpacingSnap? {
        let relevantFrames: [CGRect]
        switch orientation {
        case .horizontal:
            relevantFrames = peerFrames.filter {
                rangesOverlap(proposedFrame.minY...proposedFrame.maxY, $0.minY...$0.maxY)
            }
        case .vertical:
            relevantFrames = peerFrames.filter {
                rangesOverlap(proposedFrame.minX...proposedFrame.maxX, $0.minX...$0.maxX)
            }
        }
        let sortedFrames: [CGRect]
        switch orientation {
        case .horizontal:
            sortedFrames = relevantFrames.sorted { $0.minX < $1.minX }
        case .vertical:
            sortedFrames = relevantFrames.sorted { $0.minY < $1.minY }
        }
        guard sortedFrames.count >= 2 else { return nil }

        var bestSnap: ImageEditorEqualSpacingSnap?
        for index in 0..<(sortedFrames.count - 1) {
            let before = sortedFrames[index]
            let after = sortedFrames[index + 1]
            let candidates = [
                equalSpacingSnap(
                    for: proposedFrame,
                    between: before,
                    and: after,
                    orientation: orientation
                ),
                repeatedSpacingSnap(
                    for: proposedFrame,
                    beside: before,
                    and: after,
                    placement: .before,
                    orientation: orientation
                ),
                repeatedSpacingSnap(
                    for: proposedFrame,
                    beside: before,
                    and: after,
                    placement: .after,
                    orientation: orientation
                )
            ].compactMap { $0 }
            for candidate in candidates where abs(candidate.correction) <= threshold {
                if bestSnap == nil || abs(candidate.correction) < abs(bestSnap?.correction ?? .greatestFiniteMagnitude) {
                    bestSnap = candidate
                }
            }
        }
        return bestSnap
    }

    private func equalSpacingSnap(
        for proposedFrame: CGRect,
        between before: CGRect,
        and after: CGRect,
        orientation: ImageEditorGuideOrientation
    ) -> ImageEditorEqualSpacingSnap? {
        switch orientation {
        case .horizontal:
            guard rangesOverlap(proposedFrame.minY...proposedFrame.maxY, before.minY...before.maxY),
                  rangesOverlap(proposedFrame.minY...proposedFrame.maxY, after.minY...after.maxY)
            else { return nil }
            let availableSpace = after.minX - before.maxX - proposedFrame.width
            guard availableSpace >= 0 else { return nil }
            let spacing = availableSpace / 2
            let correction = before.maxX + spacing - proposedFrame.minX
            let snappedFrame = proposedFrame.offsetBy(dx: correction, dy: 0)
            let crossPosition = proposedFrame.midY
            return ImageEditorEqualSpacingSnap(
                correction: correction,
                guides: [
                    ImageEditorSpacingGuide(
                        orientation: .horizontal,
                        start: CGPoint(x: before.maxX, y: crossPosition),
                        end: CGPoint(x: snappedFrame.minX, y: crossPosition)
                    ),
                    ImageEditorSpacingGuide(
                        orientation: .horizontal,
                        start: CGPoint(x: snappedFrame.maxX, y: crossPosition),
                        end: CGPoint(x: after.minX, y: crossPosition)
                    )
                ]
            )
        case .vertical:
            guard rangesOverlap(proposedFrame.minX...proposedFrame.maxX, before.minX...before.maxX),
                  rangesOverlap(proposedFrame.minX...proposedFrame.maxX, after.minX...after.maxX)
            else { return nil }
            let availableSpace = after.minY - before.maxY - proposedFrame.height
            guard availableSpace >= 0 else { return nil }
            let spacing = availableSpace / 2
            let correction = before.maxY + spacing - proposedFrame.minY
            let snappedFrame = proposedFrame.offsetBy(dx: 0, dy: correction)
            let crossPosition = proposedFrame.midX
            return ImageEditorEqualSpacingSnap(
                correction: correction,
                guides: [
                    ImageEditorSpacingGuide(
                        orientation: .vertical,
                        start: CGPoint(x: crossPosition, y: before.maxY),
                        end: CGPoint(x: crossPosition, y: snappedFrame.minY)
                    ),
                    ImageEditorSpacingGuide(
                        orientation: .vertical,
                        start: CGPoint(x: crossPosition, y: snappedFrame.maxY),
                        end: CGPoint(x: crossPosition, y: after.minY)
                    )
                ]
            )
        }
    }

    private func repeatedSpacingSnap(
        for proposedFrame: CGRect,
        beside before: CGRect,
        and after: CGRect,
        placement: ImageEditorEqualSpacingPlacement,
        orientation: ImageEditorGuideOrientation
    ) -> ImageEditorEqualSpacingSnap? {
        switch orientation {
        case .horizontal:
            guard rangesOverlap(proposedFrame.minY...proposedFrame.maxY, before.minY...before.maxY),
                  rangesOverlap(proposedFrame.minY...proposedFrame.maxY, after.minY...after.maxY)
            else { return nil }
            let spacing = after.minX - before.maxX
            guard spacing >= 0 else { return nil }
            let targetMinX: CGFloat
            switch placement {
            case .before:
                targetMinX = before.minX - spacing - proposedFrame.width
            case .after:
                targetMinX = after.maxX + spacing
            }
            let correction = targetMinX - proposedFrame.minX
            let snappedFrame = proposedFrame.offsetBy(dx: correction, dy: 0)
            let crossPosition = proposedFrame.midY
            let repeatedGuide: ImageEditorSpacingGuide
            switch placement {
            case .before:
                repeatedGuide = ImageEditorSpacingGuide(
                    orientation: .horizontal,
                    start: CGPoint(x: snappedFrame.maxX, y: crossPosition),
                    end: CGPoint(x: before.minX, y: crossPosition)
                )
            case .after:
                repeatedGuide = ImageEditorSpacingGuide(
                    orientation: .horizontal,
                    start: CGPoint(x: after.maxX, y: crossPosition),
                    end: CGPoint(x: snappedFrame.minX, y: crossPosition)
                )
            }
            return ImageEditorEqualSpacingSnap(
                correction: correction,
                guides: [
                    ImageEditorSpacingGuide(
                        orientation: .horizontal,
                        start: CGPoint(x: before.maxX, y: crossPosition),
                        end: CGPoint(x: after.minX, y: crossPosition)
                    ),
                    repeatedGuide
                ]
            )
        case .vertical:
            guard rangesOverlap(proposedFrame.minX...proposedFrame.maxX, before.minX...before.maxX),
                  rangesOverlap(proposedFrame.minX...proposedFrame.maxX, after.minX...after.maxX)
            else { return nil }
            let spacing = after.minY - before.maxY
            guard spacing >= 0 else { return nil }
            let targetMinY: CGFloat
            switch placement {
            case .before:
                targetMinY = before.minY - spacing - proposedFrame.height
            case .after:
                targetMinY = after.maxY + spacing
            }
            let correction = targetMinY - proposedFrame.minY
            let snappedFrame = proposedFrame.offsetBy(dx: 0, dy: correction)
            let crossPosition = proposedFrame.midX
            let repeatedGuide: ImageEditorSpacingGuide
            switch placement {
            case .before:
                repeatedGuide = ImageEditorSpacingGuide(
                    orientation: .vertical,
                    start: CGPoint(x: crossPosition, y: snappedFrame.maxY),
                    end: CGPoint(x: crossPosition, y: before.minY)
                )
            case .after:
                repeatedGuide = ImageEditorSpacingGuide(
                    orientation: .vertical,
                    start: CGPoint(x: crossPosition, y: after.maxY),
                    end: CGPoint(x: crossPosition, y: snappedFrame.minY)
                )
            }
            return ImageEditorEqualSpacingSnap(
                correction: correction,
                guides: [
                    ImageEditorSpacingGuide(
                        orientation: .vertical,
                        start: CGPoint(x: crossPosition, y: before.maxY),
                        end: CGPoint(x: crossPosition, y: after.minY)
                    ),
                    repeatedGuide
                ]
            )
        }
    }

    private func shouldPreferSpacing(
        _ spacing: ImageEditorEqualSpacingSnap?,
        over alignment: ImageEditorMoveAlignment?
    ) -> Bool {
        guard let spacing else { return false }
        guard let alignment else { return true }
        return abs(spacing.correction) < abs(alignment.correction)
    }

    private func rangesOverlap(_ lhs: ClosedRange<CGFloat>, _ rhs: ClosedRange<CGFloat>) -> Bool {
        lhs.overlaps(rhs)
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

struct ImageEditorSpacingGuide: Identifiable, Equatable {
    let orientation: ImageEditorGuideOrientation
    let start: CGPoint
    let end: CGPoint

    var id: String {
        "\(orientation.rawValue)-\(start.x)-\(start.y)-\(end.x)-\(end.y)"
    }

    var distance: CGFloat {
        switch orientation {
        case .horizontal:
            return abs(end.x - start.x)
        case .vertical:
            return abs(end.y - start.y)
        }
    }

    func distanceText(locale: Locale = .current) -> String {
        guard distance.isFinite else { return "0" }
        let tenths = Int((max(0, distance) * 10).rounded())
        let whole = tenths / 10
        let fraction = tenths % 10
        guard fraction != 0 else { return "\(whole)" }
        return "\(whole)\(locale.decimalSeparator ?? ".")\(fraction)"
    }

    func offsetBy(dx: CGFloat, dy: CGFloat) -> ImageEditorSpacingGuide {
        ImageEditorSpacingGuide(
            orientation: orientation,
            start: CGPoint(x: start.x + dx, y: start.y + dy),
            end: CGPoint(x: end.x + dx, y: end.y + dy)
        )
    }
}

private struct ImageEditorMoveAlignment {
    let position: CGFloat
    let correction: CGFloat
}

private struct ImageEditorEqualSpacingSnap {
    let correction: CGFloat
    let guides: [ImageEditorSpacingGuide]
}

private enum ImageEditorEqualSpacingPlacement {
    case before
    case after
}

private extension CGRect {
    var isFinite: Bool {
        minX.isFinite && minY.isFinite && width.isFinite && height.isFinite
    }
}
