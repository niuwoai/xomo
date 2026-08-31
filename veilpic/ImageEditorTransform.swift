//
//  ImageEditorTransform.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

enum ImageEditorLayerTransformContextAction: String, CaseIterable, Identifiable {
    case rotateLeft90
    case rotateRight90
    case rotate180
    case flipHorizontal
    case flipVertical
    case fitCanvas
    case fillCanvas
    case fitSelection
    case fillSelection
    case trimTransparentPixels

    var id: String { rawValue }

    static let directionalActions: [Self] = [
        .rotateLeft90,
        .rotateRight90,
        .rotate180,
        .flipHorizontal,
        .flipVertical
    ]

    static let canvasSizingActions: [Self] = [
        .fitCanvas,
        .fillCanvas
    ]

    static let selectionSizingActions: [Self] = [
        .fitSelection,
        .fillSelection
    ]

    static let pixelContentActions: [Self] = [
        .trimTransparentPixels
    ]

    var actionTitleKey: String {
        switch self {
        case .rotateLeft90: "imageEditor.action.layerRotate90Left"
        case .rotateRight90: "imageEditor.action.layerRotate90Right"
        case .rotate180: "imageEditor.action.layerRotate180"
        case .flipHorizontal: "imageEditor.action.layerFlipHorizontal"
        case .flipVertical: "imageEditor.action.layerFlipVertical"
        case .fitCanvas: "imageEditor.action.layerFitCanvas"
        case .fillCanvas: "imageEditor.action.layerFillCanvas"
        case .fitSelection: "imageEditor.action.layerFitSelection"
        case .fillSelection: "imageEditor.action.layerFillSelection"
        case .trimTransparentPixels: "imageEditor.action.layerTrimTransparentPixels"
        }
    }

    var systemImage: String {
        switch self {
        case .rotateLeft90: "rotate.left"
        case .rotateRight90: "rotate.right"
        case .rotate180: "arrow.triangle.2.circlepath"
        case .flipHorizontal: "arrow.left.and.right"
        case .flipVertical: "arrow.up.and.down"
        case .fitCanvas: "arrow.down.right.and.arrow.up.left"
        case .fillCanvas: "arrow.up.left.and.arrow.down.right"
        case .fitSelection: "rectangle.dashed"
        case .fillSelection: "rectangle.fill"
        case .trimTransparentPixels: "crop"
        }
    }
}

@MainActor
extension ImageEditorViewModel {
    var isResizingSelectedLayer: Bool {
        !resizingLayerIDs.isEmpty
    }

    var selectedLayerTransformFrame: CGRect? {
        guard !isEditingLayerMask else { return nil }
        if selectedXomoObjectKind != nil {
            return selectedXomoObjectFrame
        }
        return transformFrame(for: selectedTransformableLayerIndices)
    }

    var movingObjectPreviewDelta: CGSize? {
        guard let originalFrame = movingOriginalTransformFrame?.standardized,
              let previewFrame = movingObjectPreviewFrame?.standardized,
              !originalFrame.isNull,
              !previewFrame.isNull
        else { return nil }
        return CGSize(
            width: previewFrame.minX - originalFrame.minX,
            height: previewFrame.minY - originalFrame.minY
        )
    }

    var resizingObjectPreviewDelta: CGSize? {
        guard isResizingSelectedLayer,
              let originalFrame = resizingOriginalTransformFrame?.standardized,
              let previewFrame = selectedLayerTransformFrame?.standardized,
              !originalFrame.isNull,
              !previewFrame.isNull
        else { return nil }
        return CGSize(
            width: previewFrame.width - originalFrame.width,
            height: previewFrame.height - originalFrame.height
        )
    }

    var resizingObjectPreviewScalePercent: CGSize? {
        guard let originalFrame = resizingOriginalTransformFrame?.standardized,
              let previewFrame = selectedLayerTransformFrame?.standardized,
              originalFrame.width > 0,
              originalFrame.height > 0
        else { return nil }
        return CGSize(
            width: previewFrame.width / originalFrame.width * 100,
            height: previewFrame.height / originalFrame.height * 100
        )
    }

    var activeTransformOriginalFrame: CGRect? {
        if movingObjectPreviewFrame != nil {
            return movingOriginalTransformFrame?.standardized
        }
        if isResizingSelectedLayer {
            return resizingOriginalTransformFrame?.standardized
        }
        if rotatingPreviewDegrees != nil {
            return rotatingOriginalTransformFrame?.standardized
        }
        return nil
    }

    var selectedObjectBoundsInfoText: String {
        guard let frame = (movingObjectPreviewFrame ?? selectedLayerTransformFrame)?
            .standardized,
              !frame.isNull,
              !frame.isEmpty
        else {
            return L10n.text("imageEditor.info.object.empty")
        }
        let arguments: [CVarArg] = [
            geometryInfoValue(frame.minX),
            geometryInfoValue(frame.minY),
            geometryInfoValue(frame.width),
            geometryInfoValue(frame.height)
        ]
        let previewDelta = movingObjectPreviewDelta
        let resizeDelta = resizingObjectPreviewDelta
        let previewArguments: [CVarArg]
        if let delta = previewDelta {
            previewArguments = arguments + [
                geometryInfoValue(delta.width),
                geometryInfoValue(delta.height)
            ]
        } else if let delta = resizeDelta {
            previewArguments = arguments + [
                geometryInfoValue(delta.width),
                geometryInfoValue(delta.height)
            ]
        } else if let degrees = rotatingPreviewDegrees {
            previewArguments = arguments + [
                geometryInfoValue(degrees)
            ]
        } else {
            previewArguments = arguments
        }
        if document.selectedLayerIDs.count > 1 {
            let multipleArguments: [CVarArg] = [document.selectedLayerIDs.count]
            let localizationKey: String
            if previewDelta != nil {
                localizationKey = "imageEditor.info.objects.bounds.preview"
            } else if resizeDelta != nil {
                localizationKey = "imageEditor.info.objects.bounds.resize"
            } else if rotatingPreviewDegrees != nil {
                localizationKey = "imageEditor.info.objects.bounds.rotation"
            } else {
                localizationKey = "imageEditor.info.objects.bounds"
            }
            return String(
                format: L10n.text(localizationKey),
                locale: Locale.current,
                arguments: multipleArguments + previewArguments
            )
        }
        let localizationKey: String
        if previewDelta != nil {
            localizationKey = "imageEditor.info.object.bounds.preview"
        } else if resizeDelta != nil {
            localizationKey = "imageEditor.info.object.bounds.resize"
        } else if rotatingPreviewDegrees != nil {
            localizationKey = "imageEditor.info.object.bounds.rotation"
        } else {
            localizationKey = "imageEditor.info.object.bounds"
        }
        return String(
            format: L10n.text(localizationKey),
            locale: Locale.current,
            arguments: previewArguments
        )
    }

    private func geometryInfoValue(_ value: CGFloat) -> String {
        let integerValue = value.rounded()
        guard abs(value - integerValue) >= 0.005 else {
            return String(Int(integerValue))
        }
        return String(format: "%.1f", locale: Locale.current, Double(value))
    }

    var canMoveSelectedLayer: Bool {
        let indices = selectedTransformableLayerIndices
        guard !indices.isEmpty, selectedLayerTransformFrame != nil else { return false }
        return indices.allSatisfy { !document.isEffectivelyPositionLocked(document.layers[$0]) }
    }

    var canResizeSelectedLayer: Bool {
        guard canMoveSelectedLayer else { return false }
        return selectedTransformableLayerIndices.allSatisfy {
            !document.isEffectivelyPixelsLocked(document.layers[$0])
        }
    }

    var selectedLayerTransformX: Double {
        Double(selectedLayerTransformFrame?.minX ?? 0)
    }

    var selectedLayerTransformY: Double {
        Double(selectedLayerTransformFrame?.minY ?? 0)
    }

    var selectedLayerTransformWidth: Double {
        Double(selectedLayerTransformFrame?.width ?? 0)
    }

    var selectedLayerTransformHeight: Double {
        Double(selectedLayerTransformFrame?.height ?? 0)
    }

    /// Applies an inspector edit as one atomic transform, preserving the
    /// existing multi-layer/component scaling behavior and undo semantics.
    func setSelectedLayerTransform(
        x: Double? = nil,
        y: Double? = nil,
        width: Double? = nil,
        height: Double? = nil,
        preservingAspectRatio: Bool = false
    ) {
        guard movingLayerIDs.isEmpty, resizingLayerIDs.isEmpty, rotatingLayerIDs.isEmpty,
              [x, y, width, height].compactMap({ $0 }).allSatisfy(\.isFinite)
        else { return }
        let changesSize = width != nil || height != nil
        guard (changesSize ? canResizeSelectedLayer : canMoveSelectedLayer),
              let currentFrame = selectedLayerTransformFrame
        else { return }

        if !changesSize {
            setSelectedLayerPosition(x: x, y: y, currentFrame: currentFrame)
            return
        }

        let currentWidth = max(currentFrame.width, 0.1)
        let currentHeight = max(currentFrame.height, 0.1)
        var targetWidth = CGFloat(width ?? Double(currentFrame.width))
        var targetHeight = CGFloat(height ?? Double(currentFrame.height))
        if preservingAspectRatio {
            if width != nil, height == nil {
                targetHeight = currentHeight * (targetWidth / currentWidth)
            } else if height != nil, width == nil {
                targetWidth = currentWidth * (targetHeight / currentHeight)
            }
        }

        let targetFrame = CGRect(
            x: CGFloat(x ?? Double(currentFrame.minX)),
            y: CGFloat(y ?? Double(currentFrame.minY)),
            width: max(1, targetWidth),
            height: max(1, targetHeight)
        )
        let originalFrames = transformFramesIncludingGroups(for: editableTransformLayerIndices())
        commitResizedTransformFrame(
            targetFrame,
            originalTransformFrame: currentFrame,
            originalFrames: originalFrames,
            historyTitle: L10n.text("imageEditor.history.layerTransformInspector")
        )
    }

    private func setSelectedLayerPosition(x: Double?, y: Double?, currentFrame: CGRect) {
        let delta = CGSize(
            width: CGFloat(x ?? Double(currentFrame.minX)) - currentFrame.minX,
            height: CGFloat(y ?? Double(currentFrame.minY)) - currentFrame.minY
        )
        guard delta.width.isFinite, delta.height.isFinite, delta != .zero else { return }
        let ids = selectedTransformLayerIDsIncludingGroups(for: editableTransformLayerIndices())
        guard !ids.isEmpty else { return }
        pushUndo()
        translateLayers(ids, by: delta)
        appendHistory(L10n.text("imageEditor.history.layerTransformInspector"))
    }

    var canRotateSelectedLayer: Bool {
        canResizeSelectedLayer
    }

    /// Photoshop-style transform reference point. Store it in normalized
    /// selection coordinates so it follows lightweight move/resize previews,
    /// while still allowing a point outside the selection bounds.
    var selectedLayerTransformReferencePoint: CGPoint? {
        guard let frame = movingObjectPreviewFrame ?? selectedLayerTransformFrame else { return nil }
        if !rotatingLayerIDs.isEmpty, let rotatingReferencePoint {
            return rotatingReferencePoint
        }
        let selectedIDs = Set(selectedTransformableLayerIndices.map { document.layers[$0].id })
        guard selectedIDs == transformReferenceLayerIDs,
              let unitPoint = transformReferenceUnitPoint
        else {
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        return CGPoint(
            x: frame.minX + unitPoint.x * frame.width,
            y: frame.minY + unitPoint.y * frame.height
        )
    }

    var hasCustomTransformReferencePoint: Bool {
        let selectedIDs = Set(selectedTransformableLayerIndices.map { document.layers[$0].id })
        return !selectedIDs.isEmpty
            && selectedIDs == transformReferenceLayerIDs
            && transformReferenceUnitPoint != nil
    }

    func setSelectedLayerTransformReferencePoint(_ point: CGPoint) {
        guard let frame = movingObjectPreviewFrame ?? selectedLayerTransformFrame,
              frame.width > 0.1,
              frame.height > 0.1
        else { return }
        transformReferenceLayerIDs = Set(
            selectedTransformableLayerIndices.map { document.layers[$0].id }
        )
        transformReferenceUnitPoint = CGPoint(
            x: (point.x - frame.minX) / frame.width,
            y: (point.y - frame.minY) / frame.height
        )
    }

    func beginSelectedLayerTransformReferencePointDrag() {
        guard !isTransformReferencePointDragActive else { return }
        isTransformReferencePointDragActive = true
        transformReferenceDragOriginalUnitPoint = transformReferenceUnitPoint
        transformReferenceDragOriginalLayerIDs = transformReferenceLayerIDs
    }

    func finishSelectedLayerTransformReferencePointDrag() {
        isTransformReferencePointDragActive = false
        transformReferenceDragOriginalUnitPoint = nil
        transformReferenceDragOriginalLayerIDs = []
    }

    @discardableResult
    func cancelSelectedLayerTransformReferencePointDrag() -> Bool {
        guard isTransformReferencePointDragActive else { return false }
        transformReferenceUnitPoint = transformReferenceDragOriginalUnitPoint
        transformReferenceLayerIDs = transformReferenceDragOriginalLayerIDs
        finishSelectedLayerTransformReferencePointDrag()
        return true
    }

    @discardableResult
    func resetSelectedLayerTransformReferencePoint() -> Bool {
        let hadCustomReferencePoint = hasCustomTransformReferencePoint
        finishSelectedLayerTransformReferencePointDrag()
        guard hadCustomReferencePoint else { return false }
        clearSelectedLayerTransformReferencePoint()
        return true
    }

    func clearSelectedLayerTransformReferencePoint() {
        transformReferenceLayerIDs = []
        transformReferenceUnitPoint = nil
    }

    var canFlipSelectedLayer: Bool {
        canResizeSelectedLayer
    }

    func canTransformLayersFromContext(
        _ clickedLayerID: UUID,
        action: ImageEditorLayerTransformContextAction
    ) -> Bool {
        guard !isEditingLayerMask else { return false }
        let selectedIDs = layerContextSelectionIDs(for: clickedLayerID)
        if action == .trimTransparentPixels {
            return transparentPixelTrimBounds(for: selectedIDs) != nil
        }
        let indices = editableTransformLayerIndices(for: selectedIDs)
        guard !indices.isEmpty,
              indices.allSatisfy({
                  !document.isEffectivelyPixelsLocked(document.layers[$0])
              })
        else { return false }
        guard let transformFrame = transformFrame(
            for: indices,
            selectedIDs: selectedIDs
        ) else { return false }
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        switch action {
        case .fitCanvas:
            return !fittedTransformFrame(
                for: transformFrame,
                in: canvasBounds,
                mode: .fit
            ).isApproximatelyEqual(to: transformFrame)
        case .fillCanvas:
            return !fittedTransformFrame(
                for: transformFrame,
                in: canvasBounds,
                mode: .fill
            ).isApproximatelyEqual(to: transformFrame)
        case .fitSelection:
            guard let selectionBounds = selectionTargetBounds() else { return false }
            return !fittedTransformFrame(
                for: transformFrame,
                in: selectionBounds,
                mode: .fit
            ).isApproximatelyEqual(to: transformFrame)
        case .fillSelection:
            guard let selectionBounds = selectionTargetBounds() else { return false }
            return !fittedTransformFrame(
                for: transformFrame,
                in: selectionBounds,
                mode: .fill
            ).isApproximatelyEqual(to: transformFrame)
        case .rotateLeft90, .rotateRight90, .rotate180, .flipHorizontal, .flipVertical:
            return true
        case .trimTransparentPixels:
            return false
        }
    }

    @discardableResult
    func transformLayersFromContext(
        _ clickedLayerID: UUID,
        action: ImageEditorLayerTransformContextAction
    ) -> Bool {
        guard canTransformLayersFromContext(clickedLayerID, action: action) else {
            return false
        }
        prepareLayerContextSelection(for: clickedLayerID)
        switch action {
        case .rotateLeft90:
            return rotateSelectedLayerLeft90()
        case .rotateRight90:
            return rotateSelectedLayerRight90()
        case .rotate180:
            return rotateSelectedLayer180()
        case .flipHorizontal:
            return flipSelectedLayerHorizontal()
        case .flipVertical:
            return flipSelectedLayerVertical()
        case .fitCanvas:
            return fitSelectedLayerToCanvas()
        case .fillCanvas:
            return fillSelectedLayerToCanvas()
        case .fitSelection:
            return fitSelectedLayerToSelection()
        case .fillSelection:
            return fillSelectedLayerToSelection()
        case .trimTransparentPixels:
            return trimSelectedLayersTransparentPixels()
        }
    }

    var canFitSelectedLayerToCanvas: Bool {
        canResizeSelectedLayer
    }

    var canFitSelectedLayerToSelection: Bool {
        canResizeSelectedLayer && selectionTargetBounds() != nil
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

    @discardableResult
    func beginMovingSelectedLayer() -> Bool {
        guard movingLayerIDs.isEmpty else { return false }
        movingLayerWasDuplicated = false
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = selectedXomoObjectFrame ?? transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        pushUndo()
        movingLayerIDs = selectedTransformLayerIDsIncludingGroups(for: indices)
        movingLayerDidChange = false
        movingOriginalTransformFrame = transformFrame
        movingObjectPreviewFrame = transformFrame
        activeAlignmentGuides = []
        activeSpacingGuides = []
        return true
    }

    var hasActiveLayerMoveTransaction: Bool {
        !movingLayerIDs.isEmpty
    }

    /// Starts an Option-drag as one undoable duplicate-and-move transaction.
    /// The duplication snapshot is captured before the clone is inserted so
    /// undo removes both the movement and the newly created layer tree.
    @discardableResult
    func beginDuplicatingSelectedLayerForMove() -> Bool {
        guard movingLayerIDs.isEmpty,
              !editableTransformLayerIndices().isEmpty,
              let plan = ImageEditorLayerHierarchyDuplication.duplicationPlan(
                  layers: document.layers,
                  selectedIDs: document.selectedLayerIDs,
                  primarySelectionID: document.selectedLayerID,
                  duplicateName: { L10n.format("imageEditor.layer.copyName", $0) },
                  isEffectivelyVisible: { document.isEffectivelyVisible($0) }
              )
        else { return false }

        pushUndo()
        document.layers = plan.layers
        normalizeLayerLinks()
        document.selectedLayerIDs = plan.selectedLayerIDs
        document.selectedLayerID = plan.primarySelectionID
        syncLayerSelectionAnchorToPrimarySelection()
        isEditingLayerMask = false

        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = selectedXomoObjectFrame ?? transformFrame(for: indices)
        else {
            _ = discardLastUndoSnapshot()
            return false
        }

        movingLayerIDs = selectedTransformLayerIDsIncludingGroups(for: indices)
        movingLayerWasDuplicated = true
        movingLayerDidChange = false
        movingOriginalTransformFrame = transformFrame
        movingObjectPreviewFrame = transformFrame
        activeAlignmentGuides = []
        activeSpacingGuides = []
        return true
    }

    func moveSelectedLayer(
        by delta: CGSize,
        snapping: Bool = false,
        constrainingTo axis: ImageEditorObjectDragAxis? = nil
    ) {
        guard !movingLayerIDs.isEmpty else { return }
        guard abs(delta.width) >= 0.1 || abs(delta.height) >= 0.1 else { return }
        let snappedDelta = snapping ? snappedMoveDelta(delta, movingLayerIDs: movingLayerIDs) : delta
        let adjustedDelta = ImageEditorObjectDragConstraint.constrainedDelta(snappedDelta, to: axis)
        if let axis {
            let discardedCorrection = CGSize(
                width: adjustedDelta.width - snappedDelta.width,
                height: adjustedDelta.height - snappedDelta.height
            )
            activeSpacingGuides = activeSpacingGuides.map { guide in
                switch guide.orientation {
                case .horizontal:
                    return guide.offsetBy(dx: 0, dy: discardedCorrection.height)
                case .vertical:
                    return guide.offsetBy(dx: discardedCorrection.width, dy: 0)
                }
            }
            activeAlignmentGuides.removeAll { guide in
                switch axis {
                case .horizontal:
                    return guide.orientation == .horizontal
                case .vertical:
                    return guide.orientation == .vertical
                }
            }
            activeSpacingGuides.removeAll { guide in
                switch axis {
                case .horizontal:
                    return guide.orientation == .vertical
                case .vertical:
                    return guide.orientation == .horizontal
                }
            }
        }
        guard abs(adjustedDelta.width) >= 0.1 || abs(adjustedDelta.height) >= 0.1 else { return }
        movingObjectPreviewFrame = movingObjectPreviewFrame?.offsetBy(dx: adjustedDelta.width, dy: adjustedDelta.height)
        movingLayerDidChange = true
        // Keep the drag path lightweight: the preview frame is the only
        // per-pointer update. Updating the status bar for every mouse event
        // invalidates more of the SwiftUI tree and makes component dragging
        // feel sticky on macOS 13.
    }

    func nudgeSelectionOrSelectedLayer(by delta: CGSize) {
        // A pointer drag already owns the transform transaction. Letting an
        // arrow-key nudge reuse it would finish the mouse drag immediately,
        // leaving later pointer samples attached to a transaction that no
        // longer exists. The next nudge after mouse-up remains available.
        guard movingLayerIDs.isEmpty else { return }
        if hasActivePathAnchorMoveTransaction {
            _ = cancelMovingPathAnchor()
            return
        }

        // The component library is an object-editing mode. When a component
        // is selected there, arrow keys must move the object even if an old
        // pixel selection is still present in the document.
        if hasSelectedXomoObject, canvasInteractionTool == .move {
            beginMovingSelectedLayer()
            moveSelectedLayer(by: delta)
            finishMovingSelectedLayer()
            return
        }

        if hasEffectiveSelectionPixels {
            nudgeSelection(by: delta)
            return
        }

        if selectedTool == .pen || selectedTool == .directSelection,
           canEditSelectedPathAnchors,
           selectedPathAnchorIndex != nil {
            nudgeSelectedPathAnchor(by: delta)
            return
        }

        beginMovingSelectedLayer()
        moveSelectedLayer(by: delta)
        finishMovingSelectedLayer()
    }

    func finishMovingSelectedLayer() {
        guard !movingLayerIDs.isEmpty else { return }
        if movingLayerDidChange,
           let originalTransformFrame = movingOriginalTransformFrame,
           let previewFrame = movingObjectPreviewFrame {
            translateLayers(
                movingLayerIDs,
                by: CGSize(
                    width: previewFrame.minX - originalTransformFrame.minX,
                    height: previewFrame.minY - originalTransformFrame.minY
                )
            )
            appendHistory(L10n.text(
                movingLayerWasDuplicated
                    ? "imageEditor.history.layerDuplicate"
                    : "imageEditor.history.layerTranslate"
            ))
        } else if movingLayerWasDuplicated {
            appendHistory(L10n.text("imageEditor.history.layerDuplicate"))
        } else {
            _ = discardLastUndoSnapshot()
            updateStatus()
        }
        resetMovingSelectedLayerState()
    }

    /// Escape cancels the preview transaction used by component and layer
    /// dragging. Ordinary moves only need to discard their pending undo
    /// snapshot; Option-drag has already inserted a duplicate, so it restores
    /// the pre-drag document before clearing the transaction state.
    @discardableResult
    func cancelMovingSelectedLayer() -> Bool {
        guard !movingLayerIDs.isEmpty else { return false }
        let originalDocument = movingLayerWasDuplicated ? undoStack.last : nil
        _ = discardLastUndoSnapshot()
        if let originalDocument {
            document = originalDocument
        }
        resetMovingSelectedLayerState()
        updateStatus()
        return true
    }

    private func resetMovingSelectedLayerState() {
        movingLayerIDs = []
        movingLayerWasDuplicated = false
        movingLayerDidChange = false
        movingOriginalTransformFrame = nil
        movingObjectPreviewFrame = nil
        activeAlignmentGuides = []
        activeSpacingGuides = []
    }

    private func selectedTransformLayerIDsIncludingGroups(for indices: [Int]) -> Set<UUID> {
        var ids = Set(indices.map { document.layers[$0].id })
        let expandedIDs = transformLayerIDsExpandingLinkedGroups(startingFrom: document.selectedLayerIDs)
        for layer in document.layers where layer.isGroup && expandedIDs.contains(layer.id) {
            guard !document.isEffectivelyPositionLocked(layer) else { continue }
            ids.insert(layer.id)
        }
        return ids
    }

    private func transformFramesIncludingGroups(for indices: [Int]) -> [UUID: CGRect] {
        let ids = selectedTransformLayerIDsIncludingGroups(for: indices)
        return document.layers.reduce(into: [:]) { frames, layer in
            if ids.contains(layer.id) { frames[layer.id] = layer.frame.standardized }
        }
    }

    private func transformLayersIncludingGroups(for indices: [Int]) -> [UUID: ImageEditorLayer] {
        let ids = selectedTransformLayerIDsIncludingGroups(for: indices)
        return document.layers.reduce(into: [:]) { layers, layer in
            if ids.contains(layer.id) { layers[layer.id] = layer }
        }
    }

    private func translateLayers(_ layerIDs: Set<UUID>, by delta: CGSize) {
        var nextDocument = document
        for index in nextDocument.layers.indices where layerIDs.contains(nextDocument.layers[index].id) {
            let originalFrame = nextDocument.layers[index].frame.standardized
            nextDocument.layers[index].frame.origin.x += delta.width
            nextDocument.layers[index].frame.origin.y += delta.height
            if nextDocument.layers[index].isGroup {
                nextDocument.layers[index].translateLinkedGroupMasks(by: delta)
                continue
            }
            nextDocument.layers[index].compensateUnlinkedLocalMasks(by: delta, originalFrame: originalFrame)
        }
        document = nextDocument
    }

    func beginResizingSelectedLayer(handle: ImageEditorLayerResizeHandle) {
        guard resizingLayerIDs.isEmpty, canResizeSelectedLayer else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = selectedXomoObjectFrame ?? transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        _ = handle
        pushUndo()
        resizingOriginalFrames = transformFramesIncludingGroups(for: indices)
        resizingLayerIDs = Set(resizingOriginalFrames.keys)
        resizingOriginalParagraphTextContents = [:]
        if resizingLayerIDs.count == 1,
           let index = indices.first,
           let content = document.layers[index].textContent,
           content.layoutMode == .paragraph {
            resizingOriginalParagraphTextContents[document.layers[index].id] = content
        }
        resizingOriginalTransformFrame = transformFrame
        resizingLayerDidChange = false
        activeAlignmentGuides = []
        activeSpacingGuides = []
    }

    func resizeSelectedLayer(
        to point: CGPoint,
        handle: ImageEditorLayerResizeHandle,
        preservingAspectRatio: Bool = false,
        resizingFromCenter: Bool = false
    ) {
        guard !resizingLayerIDs.isEmpty,
              let originalFrame = resizingOriginalTransformFrame
        else { return }
        let resizesParagraphTextBox = resizingOriginalParagraphTextContents.count == 1
        let shouldPreserveAspectRatio = preservingAspectRatio && !resizesParagraphTextBox
        let resizedFrame = frameByDragging(
            handle: handle,
            from: originalFrame,
            to: point,
            preservingAspectRatio: shouldPreserveAspectRatio,
            resizingFromCenter: resizingFromCenter
        )
        let snappedFrame = snappedResizeFrame(
            resizedFrame,
            originalFrame: originalFrame,
            handle: handle,
            preservingAspectRatio: shouldPreserveAspectRatio,
            resizingFromCenter: resizingFromCenter
        )
        let changed: Bool
        if resizesParagraphTextBox {
            let normalizedFrame = ImageEditorTextBoxGeometry.normalizedResizeFrame(
                snappedFrame,
                originalFrame: originalFrame,
                handle: handle,
                resizingFromCenter: resizingFromCenter
            )
            changed = applyResizedParagraphTextBoxFrame(normalizedFrame)
        } else {
            changed = applyResizedTransformFrame(snappedFrame, originalTransformFrame: originalFrame)
        }
        guard changed else { return }
        resizingLayerDidChange = true
        statusText = L10n.text(
            resizesParagraphTextBox
                ? "imageEditor.status.textBoxResized"
                : "imageEditor.status.layerResized"
        )
    }

    func finishResizingSelectedLayer() {
        guard !resizingLayerIDs.isEmpty else { return }
        if resizingLayerDidChange {
            appendHistory(L10n.text(
                resizingOriginalParagraphTextContents.isEmpty
                    ? "imageEditor.history.layerResize"
                    : "imageEditor.history.textBoxResize"
            ))
        } else {
            _ = discardLastUndoSnapshot()
            updateStatus()
        }
        resetResizingSelectedLayerState()
    }

    private func resetResizingSelectedLayerState() {
        resizingLayerIDs = []
        resizingOriginalFrames = [:]
        resizingOriginalParagraphTextContents = [:]
        resizingOriginalTransformFrame = nil
        resizingLayerDidChange = false
        activeAlignmentGuides = []
        activeSpacingGuides = []
    }

    func beginRotatingSelectedLayer(from point: CGPoint) {
        guard rotatingLayerIDs.isEmpty, canRotateSelectedLayer else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        rotatingOriginalLayers = transformLayersIncludingGroups(for: indices)
        rotatingLayerIDs = Set(rotatingOriginalLayers.keys)
        rotatingOriginalTransformFrame = transformFrame
        rotatingReferenceWasCustom = hasCustomTransformReferencePoint
        rotatingReferencePoint = selectedLayerTransformReferencePoint
            ?? CGPoint(x: transformFrame.midX, y: transformFrame.midY)
        rotatingStartAngleDegrees = layerRotationAngle(
            around: rotatingReferencePoint ?? CGPoint(x: transformFrame.midX, y: transformFrame.midY),
            to: point
        )
        rotatingLayerDidChange = false
        rotatingPreviewDegrees = 0
        activeAlignmentGuides = []
        activeSpacingGuides = []
    }

    func rotateSelectedLayer(
        to point: CGPoint,
        snappingToStep: Bool = false
    ) {
        guard !rotatingLayerIDs.isEmpty,
              let transformFrame = rotatingOriginalTransformFrame
        else { return }

        let referencePoint = rotatingReferencePoint
            ?? CGPoint(x: transformFrame.midX, y: transformFrame.midY)
        let currentAngle = layerRotationAngle(around: referencePoint, to: point)
        var degrees = normalizedRotationDelta(currentAngle - rotatingStartAngleDegrees)
        if snappingToStep {
            degrees = (degrees / 15).rounded() * 15
        }
        guard applyRotation(degrees: degrees, from: rotatingOriginalLayers, around: referencePoint) else { return }
        rotatingPreviewDegrees = degrees
        rotatingLayerDidChange = rotatingLayerDidChange || abs(degrees) > 0.1
        statusText = L10n.text("imageEditor.status.layerRotated")
    }

    func finishRotatingSelectedLayer() {
        guard !rotatingLayerIDs.isEmpty else { return }
        let referencePoint = rotatingReferencePoint
        let shouldPreserveReferencePoint = rotatingReferenceWasCustom
        if rotatingLayerDidChange {
            appendHistory(L10n.text("imageEditor.history.layerRotate"))
        } else {
            _ = discardLastUndoSnapshot()
            updateStatus()
        }
        resetRotatingSelectedLayerState()
        if shouldPreserveReferencePoint, let referencePoint {
            setSelectedLayerTransformReferencePoint(referencePoint)
        }
    }

    /// Restores the exact pre-transform document snapshot. Keeping this as a
    /// transaction-level cancel avoids lossy inverse resize/rotation math and
    /// gives Escape the same semantics for pixels, text boxes, groups and UI
    /// components.
    @discardableResult
    func cancelTransformingSelectedLayer() -> Bool {
        guard !resizingLayerIDs.isEmpty || !rotatingLayerIDs.isEmpty,
              let originalDocument = undoStack.last
        else { return false }
        _ = discardLastUndoSnapshot()
        document = originalDocument
        resetResizingSelectedLayerState()
        resetRotatingSelectedLayerState()
        updateStatus()
        return true
    }

    private func resetRotatingSelectedLayerState() {
        rotatingLayerIDs = []
        rotatingOriginalLayers = [:]
        rotatingOriginalTransformFrame = nil
        rotatingReferencePoint = nil
        rotatingReferenceWasCustom = false
        rotatingStartAngleDegrees = 0
        rotatingLayerDidChange = false
        rotatingPreviewDegrees = nil
        activeAlignmentGuides = []
        activeSpacingGuides = []
    }

    func scaleSelectedLayer(by factor: CGFloat) {
        guard factor > 0 else { return }
        guard canResizeSelectedLayer else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        let originalFrames = transformFramesIncludingGroups(for: indices)
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

        commitResizedTransformFrame(
            scaledFrame,
            originalTransformFrame: transformFrame,
            originalFrames: originalFrames,
            historyTitle: L10n.text("imageEditor.history.layerScale")
        )
    }

    @discardableResult
    func rotateSelectedLayer(degrees: CGFloat) -> Bool {
        guard degrees.isFinite, abs(degrees) > 0.01 else { return false }
        guard canRotateSelectedLayer else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }

        pushUndo()
        let shouldPreserveReferencePoint = hasCustomTransformReferencePoint
        let originalLayers = transformLayersIncludingGroups(for: indices)
        let referencePoint = selectedLayerTransformReferencePoint
            ?? CGPoint(x: transformFrame.midX, y: transformFrame.midY)
        guard applyRotation(degrees: degrees, from: originalLayers, around: referencePoint) else {
            _ = discardLastUndoSnapshot()
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }
        if shouldPreserveReferencePoint {
            setSelectedLayerTransformReferencePoint(referencePoint)
        }
        appendHistory(L10n.text("imageEditor.history.layerRotate"))
        statusText = L10n.text("imageEditor.status.layerRotated")
        return true
    }

    @discardableResult
    func rotateSelectedLayerLeft90() -> Bool {
        rotateSelectedLayer(degrees: -90)
    }

    @discardableResult
    func rotateSelectedLayerRight90() -> Bool {
        rotateSelectedLayer(degrees: 90)
    }

    @discardableResult
    func rotateSelectedLayer180() -> Bool {
        rotateSelectedLayer(degrees: 180)
    }

    @discardableResult
    func flipSelectedLayerHorizontal() -> Bool {
        flipSelectedLayer(
            horizontal: true,
            historyTitle: L10n.text("imageEditor.history.layerFlipHorizontal"),
            status: L10n.text("imageEditor.status.layerFlipHorizontal")
        )
    }

    @discardableResult
    func flipSelectedLayerVertical() -> Bool {
        flipSelectedLayer(
            horizontal: false,
            historyTitle: L10n.text("imageEditor.history.layerFlipVertical"),
            status: L10n.text("imageEditor.status.layerFlipVertical")
        )
    }

    @discardableResult
    func fitSelectedLayerToCanvas() -> Bool {
        transformSelectedLayer(
            to: CGRect(origin: .zero, size: document.canvasSize),
            mode: .fit,
            historyTitle: L10n.text("imageEditor.history.layerFitCanvas"),
            status: L10n.text("imageEditor.status.layerFitCanvas")
        )
    }

    @discardableResult
    func fillSelectedLayerToCanvas() -> Bool {
        transformSelectedLayer(
            to: CGRect(origin: .zero, size: document.canvasSize),
            mode: .fill,
            historyTitle: L10n.text("imageEditor.history.layerFillCanvas"),
            status: L10n.text("imageEditor.status.layerFillCanvas")
        )
    }

    @discardableResult
    func fitSelectedLayerToSelection() -> Bool {
        guard let targetBounds = selectionTargetBounds() else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return false
        }
        return transformSelectedLayer(
            to: targetBounds,
            mode: .fit,
            historyTitle: L10n.text("imageEditor.history.layerFitSelection"),
            status: L10n.text("imageEditor.status.layerFitSelection")
        )
    }

    @discardableResult
    func fillSelectedLayerToSelection() -> Bool {
        guard let targetBounds = selectionTargetBounds() else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return false
        }
        return transformSelectedLayer(
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

        guard let trimmedLayer = layerTrimmingTransparentPixels(
            layer,
            to: alphaBounds
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index] = trimmedLayer
        appendHistory(L10n.text("imageEditor.history.layerTrimTransparentPixels"))
        statusText = L10n.text("imageEditor.status.layerTrimTransparentPixels")
    }

    @discardableResult
    private func trimSelectedLayersTransparentPixels() -> Bool {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        guard let trimBounds = transparentPixelTrimBounds(for: selectedIDs) else {
            return false
        }

        var trimmedLayers: [UUID: ImageEditorLayer] = [:]
        for (layerID, alphaBounds) in trimBounds {
            guard let layer = document.layers.first(where: { $0.id == layerID }),
                  let trimmedLayer = layerTrimmingTransparentPixels(
                      layer,
                      to: alphaBounds
                  )
            else {
                statusText = L10n.text("imageEditor.status.operationFailed")
                return false
            }
            trimmedLayers[layerID] = trimmedLayer
        }

        pushUndo()
        for index in document.layers.indices {
            let layerID = document.layers[index].id
            if let trimmedLayer = trimmedLayers[layerID] {
                document.layers[index] = trimmedLayer
            }
        }
        appendHistory(L10n.text("imageEditor.history.layerTrimTransparentPixels"))
        statusText = L10n.text("imageEditor.status.layerTrimTransparentPixels")
        return true
    }

    private func transparentPixelTrimBounds(
        for selectedIDs: Set<UUID>
    ) -> [UUID: CGRect]? {
        guard !selectedIDs.isEmpty else { return nil }
        var result: [UUID: CGRect] = [:]
        for layerID in selectedIDs {
            guard let layer = document.layers.first(where: { $0.id == layerID }),
                  isLayerEligibleForTransparentPixelTrim(layer),
                  let alphaBounds = layer.image.nonTransparentPixelBounds()
            else { return nil }
            let imageBounds = CGRect(origin: .zero, size: layer.image.size)
            if !alphaBounds.isApproximatelyEqual(to: imageBounds) {
                result[layerID] = alphaBounds
            }
        }
        return result.isEmpty ? nil : result
    }

    private func isLayerEligibleForTransparentPixelTrim(
        _ layer: ImageEditorLayer
    ) -> Bool {
        !isEditingLayerMask
            && !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && layer.kind.isPixel
            && document.isEffectivelyVisible(layer)
            && !document.isEffectivelyPixelsLocked(layer)
            && !document.isEffectivelyPositionLocked(layer)
    }

    private func layerTrimmingTransparentPixels(
        _ layer: ImageEditorLayer,
        to alphaBounds: CGRect
    ) -> ImageEditorLayer? {
        guard let croppedImage = layer.image.cropped(to: alphaBounds) else {
            return nil
        }
        var trimmedLayer = layer
        trimmedLayer.image = croppedImage.normalizedBitmapImage()
        trimmedLayer.mask = trimmedLayer.mask?
            .cropped(to: alphaBounds)?
            .normalizedBitmapImage()
        if let vectorMask = trimmedLayer.vectorMask {
            trimmedLayer.vectorMask = vectorMask.offsetPath(
                by: CGSize(width: -alphaBounds.minX, height: -alphaBounds.minY)
            )
        }
        trimmedLayer.frame = layer.frame.frameMappingLocalRect(
            alphaBounds,
            imageSize: layer.image.size
        )
        return trimmedLayer
    }

    var selectedTransformableLayerIndices: [Int] {
        transformableLayerIndices(for: document.selectedLayerIDs)
    }

    func transformableLayerIndices(for selectedIDs: Set<UUID>) -> [Int] {
        let transformLayerIDs = transformLayerIDsExpandingLinkedGroups(
            startingFrom: selectedIDs
        )
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return transformLayerIDs.contains(layer.id)
                && !layer.isGroup
                && !layer.isAdjustment
                && !layer.isFilter
        }
    }

    private func transformLayerIDsExpandingLinkedGroups(
        startingFrom selectedIDs: Set<UUID>
    ) -> Set<UUID> {
        var expandedIDs = layerIDsExpandingGroups(selectedIDs)
        while true {
            let linkedIDs = linkedTransformLayerIDs(startingFrom: expandedIDs)
            let nextIDs = layerIDsExpandingGroups(linkedIDs)
            guard nextIDs != expandedIDs else { return nextIDs }
            expandedIDs = nextIDs
        }
    }

    func editableTransformLayerIndices() -> [Int] {
        editableTransformLayerIndices(for: document.selectedLayerIDs)
    }

    func editableTransformLayerIndices(for selectedIDs: Set<UUID>) -> [Int] {
        let indices = transformableLayerIndices(for: selectedIDs)
        guard !indices.isEmpty,
              indices.allSatisfy({ !document.isEffectivelyPositionLocked(document.layers[$0]) })
        else { return [] }
        return indices
    }

    func transformFrame(for indices: [Int]) -> CGRect? {
        transformFrame(for: indices, selectedIDs: document.selectedLayerIDs)
    }

    func transformFrame(
        for indices: [Int],
        selectedIDs: Set<UUID>
    ) -> CGRect? {
        let shouldUseLayerFrameFallback = selectedIDs.contains { selectedID in
            document.layers.contains { $0.id == selectedID && $0.isGroup }
        } || indices.contains { index in
            let layer = document.layers[index]
            return layer.isSolidColorFill
                || layer.isPatternFill
                || layer.isGradientFill
                || layer.isShape
                || layer.isSmartObject
        }
        return indices
            .compactMap { index in
                transformContentFrame(forLayerAt: index)
                    ?? (shouldUseLayerFrameFallback ? document.layers[index].frame.standardized : nil)
            }
            .reduce(nil) { bounds, frame in
                bounds?.union(frame) ?? frame
            }
    }

    private func transformContentFrame(forLayerAt index: Int) -> CGRect? {
        let layer = document.layers[index]
        if layer.textContent != nil {
            return layer.frame.standardized
        }
        if let cached = cachedLayerTransformContentFrames[layer.id] {
            return cached
        }
        if cachedEmptyTransformLayerIDs.contains(layer.id) {
            return nil
        }
        let transformImage = layer.textContent == nil ? layer.image : layer.contentImage
        guard let localBounds = transformImage.nonTransparentPixelBounds(alphaThreshold: 0) else {
            cachedEmptyTransformLayerIDs.insert(layer.id)
            return nil
        }
        let contentFrame = layer.frame.frameMappingLocalRect(localBounds, imageSize: transformImage.size)
        cachedLayerTransformContentFrames[layer.id] = contentFrame
        return contentFrame
    }

    private func applyResizedParagraphTextBoxFrame(_ targetFrame: CGRect) -> Bool {
        guard let entry = resizingOriginalParagraphTextContents.first,
              let index = document.layers.firstIndex(where: { $0.id == entry.key })
        else { return false }
        let currentFrame = document.layers[index].frame.standardized
        guard abs(targetFrame.width - currentFrame.width) >= 0.1
                || abs(targetFrame.height - currentFrame.height) >= 0.1
                || abs(targetFrame.minX - currentFrame.minX) >= 0.1
                || abs(targetFrame.minY - currentFrame.minY) >= 0.1
        else { return false }

        var content = entry.value
        let contentSize = ImageEditorTextBoxGeometry.contentSize(for: targetFrame)
        content.boxWidth = contentSize.width
        content.boxHeight = contentSize.height
        if let mask = document.layers[index].mask, mask.size != targetFrame.size {
            document.layers[index].mask = mask.resized(to: targetFrame.size)
        }
        document.layers[index].image = NSImage.transparent(size: targetFrame.size)
        document.layers[index].frame = targetFrame
        document.layers[index].kind = .text(content)
        textBoxWidth = Double(content.boxWidth)
        textBoxHeight = Double(content.boxHeight)
        return true
    }

    func applyRotation(
        degrees: CGFloat,
        from originalLayers: [UUID: ImageEditorLayer],
        around center: CGPoint
    ) -> Bool {
        guard degrees.isFinite, center.x.isFinite, center.y.isFinite else { return false }
        let radians = degrees * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        var rotatedLayers: [UUID: ImageEditorLayer] = [:]

        for (id, originalLayer) in originalLayers {
            if abs(degrees) <= 0.01 {
                rotatedLayers[id] = originalLayer
                continue
            }
            if originalLayer.isGroup {
                guard let rotated = originalLayer.rotatingGroup(degrees: degrees, around: center) else {
                    statusText = L10n.text("imageEditor.status.operationFailed")
                    return false
                }
                rotatedLayers[id] = rotated
                continue
            }
            if originalLayer.kind.isPixel {
                guard let rotated = originalLayer.rotatingRaster(degrees: degrees, around: center) else {
                    statusText = L10n.text("imageEditor.status.operationFailed")
                    return false
                }
                rotatedLayers[id] = rotated
                continue
            }
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

        applyTransformedLayers(rotatedLayers)
        return true
    }

    func applyResizedTransformFrame(
        _ targetFrame: CGRect,
        originalTransformFrame: CGRect,
        originalFrames: [UUID: CGRect]? = nil
    ) -> Bool {
        let frames = resizedLayerFrameChanges(
            targetFrame, originalTransformFrame: originalTransformFrame,
            originalFrames: originalFrames ?? resizingOriginalFrames
        )
        // The undo snapshot is also the source used by transform cancellation.
        // Reuse it for every preview, never resample a previously clipped mask.
        let originalLayers = originalFrames == nil ? (undoStack.last?.layers ?? []) : document.layers
        guard let layers = resizedLayerChanges(
            frames, originalLayers: originalLayers,
            originalTransformFrame: originalTransformFrame, targetFrame: targetFrame
        ) else { return false }
        applyTransformedLayers(layers)
        return !frames.isEmpty
    }

    @discardableResult
    private func commitResizedTransformFrame(
        _ targetFrame: CGRect,
        originalTransformFrame: CGRect,
        originalFrames: [UUID: CGRect],
        historyTitle: String
    ) -> Bool {
        let frames = resizedLayerFrameChanges(
            targetFrame, originalTransformFrame: originalTransformFrame, originalFrames: originalFrames
        )
        // Do not invalidate redo until there is an actual, fully computed edit.
        guard !frames.isEmpty,
              let layers = resizedLayerChanges(
                  frames, originalLayers: document.layers,
                  originalTransformFrame: originalTransformFrame, targetFrame: targetFrame
              ) else { return false }
        pushUndo()
        applyTransformedLayers(layers)
        appendHistory(historyTitle)
        return true
    }

    private func applyTransformedLayers(_ layers: [UUID: ImageEditorLayer]) {
        guard !layers.isEmpty else { return }
        var nextDocument = document
        for index in nextDocument.layers.indices {
            if let layer = layers[nextDocument.layers[index].id] {
                nextDocument.layers[index] = layer
            }
        }
        document = nextDocument
    }

    private func resizedLayerFrameChanges(
        _ targetFrame: CGRect,
        originalTransformFrame: CGRect,
        originalFrames: [UUID: CGRect]
    ) -> [UUID: CGRect] {
        guard originalTransformFrame.width > 0.1,
              originalTransformFrame.height > 0.1
        else { return [:] }
        let scaleX = targetFrame.width / originalTransformFrame.width
        let scaleY = targetFrame.height / originalTransformFrame.height
        guard scaleX.isFinite, scaleY.isFinite else { return [:] }
        var frames: [UUID: CGRect] = [:]

        for layer in document.layers {
            guard let originalFrame = originalFrames[layer.id] else { continue }
            let resizedFrame = CGRect(
                x: targetFrame.minX + (originalFrame.minX - originalTransformFrame.minX) * scaleX,
                y: targetFrame.minY + (originalFrame.minY - originalTransformFrame.minY) * scaleY,
                width: max(1, originalFrame.width * scaleX),
                height: max(1, originalFrame.height * scaleY)
            )
            guard [resizedFrame.minX, resizedFrame.minY, resizedFrame.maxX, resizedFrame.maxY,
                   resizedFrame.width, resizedFrame.height].allSatisfy(\.isFinite)
            else { return [:] }
            if resizedFrame != layer.frame {
                frames[layer.id] = resizedFrame
            }
        }

        return frames
    }

    private func flipSelectedLayer(
        horizontal: Bool,
        historyTitle: String,
        status: String
    ) -> Bool {
        guard canFlipSelectedLayer else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }

        pushUndo()
        let originalLayers = indices.reduce(into: [:]) { layers, index in
            layers[document.layers[index].id] = document.layers[index]
        }
        guard applyFlip(horizontal: horizontal, from: originalLayers, around: transformFrame) else {
            _ = discardLastUndoSnapshot()
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }

        appendHistory(historyTitle)
        statusText = status
        return true
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

    @discardableResult
    private func transformSelectedLayer(
        to targetBounds: CGRect,
        mode: ImageEditorLayerFitMode,
        historyTitle: String,
        status: String
    ) -> Bool {
        guard canResizeSelectedLayer else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty,
              let transformFrame = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }

        let boundedTarget = targetBounds.standardized
        guard boundedTarget.width > 0.1, boundedTarget.height > 0.1 else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }

        let originalFrames = transformFramesIncludingGroups(for: indices)
        let targetFrame = fittedTransformFrame(for: transformFrame, in: boundedTarget, mode: mode)

        guard commitResizedTransformFrame(
            targetFrame,
            originalTransformFrame: transformFrame,
            originalFrames: originalFrames,
            historyTitle: historyTitle
        ) else {
            return false
        }

        statusText = status
        return true
    }

    private func selectionTargetBounds() -> CGRect? {
        guard let selection = document.selection else { return nil }
        guard let selectedBounds = selection.effectiveSelectedBounds(in: document.canvasSize) else { return nil }
        let bounds = selectedBounds.standardized
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
        layerRotationAngle(around: CGPoint(x: frame.midX, y: frame.midY), to: point)
    }

    func layerRotationAngle(around referencePoint: CGPoint, to point: CGPoint) -> CGFloat {
        atan2(point.y - referencePoint.y, point.x - referencePoint.x) * 180 / .pi
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
        preservingAspectRatio: Bool,
        resizingFromCenter: Bool = false
    ) -> CGRect {
        let minimumSize: CGFloat = 4
        var minX = originalFrame.minX
        var maxX = originalFrame.maxX
        var minY = originalFrame.minY
        var maxY = originalFrame.maxY

        if resizingFromCenter {
            if handle.affectsWidth {
                let halfWidth: CGFloat
                switch handle {
                case .topLeft, .left, .bottomLeft:
                    halfWidth = max(minimumSize / 2, originalFrame.midX - point.x)
                case .topRight, .right, .bottomRight:
                    halfWidth = max(minimumSize / 2, point.x - originalFrame.midX)
                case .top, .bottom:
                    halfWidth = originalFrame.width / 2
                }
                minX = originalFrame.midX - halfWidth
                maxX = originalFrame.midX + halfWidth
            }
            if handle.affectsHeight {
                let halfHeight: CGFloat
                switch handle {
                case .topLeft, .top, .topRight:
                    halfHeight = max(minimumSize / 2, point.y - originalFrame.midY)
                case .bottomLeft, .bottom, .bottomRight:
                    halfHeight = max(minimumSize / 2, originalFrame.midY - point.y)
                case .left, .right:
                    halfHeight = originalFrame.height / 2
                }
                minY = originalFrame.midY - halfHeight
                maxY = originalFrame.midY + halfHeight
            }
        } else {
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
            minimumSize: minimumSize,
            resizingFromCenter: resizingFromCenter
        )
    }

    func aspectConstrainedFrame(
        _ frame: CGRect,
        originalFrame: CGRect,
        handle: ImageEditorLayerResizeHandle,
        minimumSize: CGFloat,
        resizingFromCenter: Bool = false
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

        if resizingFromCenter {
            return CGRect(
                x: originalFrame.midX - width / 2,
                y: originalFrame.midY - height / 2,
                width: width,
                height: height
            )
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

extension ImageEditorLayer {
    /// Keep an unlinked leaf mask stationary in canvas coordinates while its
    /// image moves. Bitmap drawing and vector paths have opposite Y axes.
    mutating func compensateUnlinkedLocalMasks(by delta: CGSize, originalFrame: CGRect) {
        guard !isGroup, !isMaskLinked,
              delta.width.isFinite, delta.height.isFinite,
              delta != .zero else { return }
        let normalizedDelta = CGSize(
            width: delta.width / max(originalFrame.width, 1),
            height: delta.height / max(originalFrame.height, 1)
        )
        if let mask,
           let shiftedMask = mask.offsetMask(by: CGSize(
               width: -normalizedDelta.width * mask.size.width,
               height: normalizedDelta.height * mask.size.height
           )) {
            self.mask = shiftedMask
        }
        if let vectorMask {
            self.vectorMask = vectorMask.offsetPath(by: CGSize(
                width: -normalizedDelta.width * max(image.size.width, 1),
                height: -normalizedDelta.height * max(image.size.height, 1)
            ))
        }
    }

    /// Group masks are canvas-sized, unlike leaf masks in local coordinates.
    /// Unlinked group masks already stay fixed when the group's frame moves.
    mutating func translateLinkedGroupMasks(by delta: CGSize) {
        guard isGroup, isMaskLinked,
              delta.width.isFinite, delta.height.isFinite,
              delta != .zero else { return }
        if let mask,
           let shiftedMask = mask.offsetMask(by: CGSize(width: delta.width, height: -delta.height)) {
            // Bitmap drawing is bottom-left; document/path coordinates are top-left.
            self.mask = shiftedMask
        }
        if let vectorMask {
            self.vectorMask = vectorMask.offsetPath(by: delta)
        }
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
