//
//  ImageEditorViewModel.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UniformTypeIdentifiers

private enum ImageEditorImageProcessing {
    static let ciContext = CIContext(options: nil)
}

@MainActor
final class ImageEditorViewModel: ObservableObject {
    @Published var document: ImageEditorDocument
    @Published var selectedTool: ImageEditorTool = .move
    @Published var zoom: CGFloat = 1
    @Published var canvasOffset: CGSize = .zero
    @Published var brushSize: CGFloat = 18
    @Published var opacity: CGFloat = 1
    @Published var hardness: CGFloat = 0.8
    @Published var feather: CGFloat = 0
    @Published var foregroundColor: NSColor = .systemRed
    @Published var backgroundColor: NSColor = .clear
    @Published var statusText: String = ""
    @Published var pointerText: String = "X: 0 Y: 0"
    @Published var textValue: String = ""
    @Published var textSize: Double = 32
    @Published var selectedAdjustment: ImageEditorAdjustment = .brightness
    @Published var adjustmentValue: Double = 0
    @Published var selectedFilter: ImageEditorFilter = .gaussianBlur
    @Published var filterIntensity: Double = 0.5
    @Published var isEditingLayerMask: Bool = false
    @Published var exportSettings = ImageEditorExportSettings()
    @Published var isExportSheetPresented = false

    var undoStack: [ImageEditorDocument] = []
    private var redoStack: [ImageEditorDocument] = []
    private var historySnapshots: [UUID: ImageEditorDocument] = [:]
    var movingLayerIDs = Set<UUID>()
    var movingLayerDidChange = false
    var resizingLayerIDs = Set<UUID>()
    var resizingOriginalFrames: [UUID: CGRect] = [:]
    var resizingOriginalTransformFrame: CGRect?
    var resizingLayerDidChange = false
    var rotatingLayerIDs = Set<UUID>()
    var rotatingOriginalLayers: [UUID: ImageEditorLayer] = [:]
    var rotatingOriginalTransformFrame: CGRect?
    var rotatingStartAngleDegrees: CGFloat = 0
    var rotatingLayerDidChange = false
    private let onApply: (NSImage) -> Void

    init(sourceName: String, image: NSImage, onApply: @escaping (NSImage) -> Void) {
        document = ImageEditorDocument(sourceName: sourceName, image: image.normalizedBitmapImage())
        self.onApply = onApply
        recordCurrentHistorySnapshot()
        updateStatus()
    }

    var currentImage: NSImage {
        document.compositedImage
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    var zoomText: String {
        "\(Int((zoom * 100).rounded()))%"
    }

    var sizeText: String {
        let size = document.canvasSize
        return "\(Int(size.width.rounded())) x \(Int(size.height.rounded())) px"
    }

    var selectedLayerOpacity: Double {
        guard let layer = document.selectedLayer else { return 1 }
        return layer.opacity
    }

    var selectedLayerBlendMode: ImageEditorBlendMode {
        guard let layer = document.selectedLayer else { return .normal }
        return layer.blendMode
    }

    var selectedLayerName: String {
        document.selectedLayer?.name ?? ""
    }

    var selectedLayerGeometryText: String {
        guard let layer = document.selectedLayer else { return "W 0 H 0" }
        guard !layer.isGroup else { return L10n.text("imageEditor.properties.groupLayer") }
        if let adjustment = layer.adjustment {
            return L10n.format("imageEditor.properties.adjustmentLayerValue", adjustment.kind.title, Int((adjustment.amount * 100).rounded()))
        }
        if let filter = layer.filter {
            return L10n.format("imageEditor.properties.filterLayerValue", filter.kind.title, Int((filter.intensity * 100).rounded()))
        }
        if let textContent = layer.textContent {
            return L10n.format("imageEditor.properties.textLayerValue", textContent.text, Int(textContent.fontSize.rounded()))
        }
        return "X \(Int(layer.frame.minX.rounded()))  Y \(Int(layer.frame.minY.rounded()))  W \(Int(layer.frame.width.rounded()))  H \(Int(layer.frame.height.rounded()))"
    }

    var selectedLayerIsGroup: Bool {
        document.selectedLayer?.isGroup == true
    }

    var selectedLayerIsAdjustment: Bool {
        document.selectedLayer?.isAdjustment == true
    }

    var selectedLayerIsFilter: Bool {
        document.selectedLayer?.isFilter == true
    }

    var selectedLayerIsText: Bool {
        document.selectedLayer?.isText == true
    }

    var selectedLayerCount: Int {
        selectedLayerIndices.count
    }

    var hasMultiLayerSelection: Bool {
        selectedLayerCount > 1
    }

    var selectedLayerIsClippingMask: Bool {
        document.selectedLayer?.isClippingMask == true
    }

    var selectedLayerHasMask: Bool {
        guard let layer = document.selectedLayer, !layer.isGroup else { return false }
        return layer.mask != nil
    }

    var selectedLayerHasStroke: Bool {
        document.selectedLayer?.style.strokeEnabled == true
    }

    var selectedLayerHasShadow: Bool {
        document.selectedLayer?.style.shadowEnabled == true
    }

    var selectedLayerStrokeWidth: Double {
        Double(document.selectedLayer?.style.strokeWidth ?? 3)
    }

    var selectedLayerShadowOpacity: Double {
        Double(document.selectedLayer?.style.shadowOpacity ?? 0.35)
    }

    var selectedLayerShadowBlur: Double {
        Double(document.selectedLayer?.style.shadowBlur ?? 8)
    }

    var selectedLayerShadowOffsetX: Double {
        Double(document.selectedLayer?.style.shadowOffset.width ?? 7)
    }

    var selectedLayerShadowOffsetY: Double {
        Double(document.selectedLayer?.style.shadowOffset.height ?? -7)
    }

    var canAddLayerMask: Bool {
        guard let layer = document.selectedLayer else { return false }
        return !layer.isGroup && !document.isEffectivelyLocked(layer) && layer.mask == nil
    }

    var canDeleteLayerMask: Bool {
        guard let layer = document.selectedLayer else { return false }
        return !layer.isGroup && !document.isEffectivelyLocked(layer) && layer.mask != nil
    }

    var selection: ImageEditorSelection? {
        document.selection
    }

    var hasSelection: Bool {
        document.selection != nil
    }

    var canDeleteLayer: Bool {
        let deletionIDs = deletionIDsForCurrentSelection()
        return !deletionIDs.isEmpty && document.layers.count - deletionIDs.count >= 1
    }

    var canMergeSelectedLayerDown: Bool {
        guard selectedLayerCount == 1,
              let index = document.selectedLayerIndex,
              index > 0
        else { return false }
        let layer = document.layers[index]
        let lower = document.layers[index - 1]
        if layer.isAdjustment {
            return !lower.isGroup
                && !lower.isAdjustment
                && !lower.isFilter
                && !document.isEffectivelyLocked(layer)
                && !document.isEffectivelyLocked(lower)
        }
        if layer.isFilter {
            return !lower.isGroup
                && !lower.isAdjustment
                && !lower.isFilter
                && !document.isEffectivelyLocked(layer)
                && !document.isEffectivelyLocked(lower)
        }
        return !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && !lower.isGroup
            && !lower.isAdjustment
            && !lower.isFilter
            && !document.isEffectivelyLocked(layer)
            && !document.isEffectivelyLocked(lower)
    }

    var canStampVisibleLayers: Bool {
        document.layers.contains { layer in
            document.shouldComposite(layer)
        }
    }

    var canGroupSelectedLayer: Bool {
        let indices = selectedLayerIndices
        guard !indices.isEmpty else { return false }
        return indices.allSatisfy { index in
            let layer = document.layers[index]
            return !layer.isGroup && layer.groupID == nil && !document.isEffectivelyLocked(layer)
        }
    }

    var canMoveSelectedLayerUp: Bool {
        canMoveSelectedLayers(direction: 1)
    }

    var canMoveSelectedLayerDown: Bool {
        canMoveSelectedLayers(direction: -1)
    }

    var canMoveSelectedLayerToTop: Bool {
        canMoveSelectedLayers(to: .top)
    }

    var canMoveSelectedLayerToBottom: Bool {
        canMoveSelectedLayers(to: .bottom)
    }

    var canToggleSelectedLayerClippingMask: Bool {
        guard let index = document.selectedLayerIndex else { return false }
        let layer = document.layers[index]
        guard !layer.isGroup, !layer.isAdjustment, !layer.isFilter, !document.isEffectivelyLocked(layer) else { return false }
        if layer.isClippingMask { return true }
        return clippingBaseExists(below: index, groupID: layer.groupID)
    }

    var colorText: String {
        let color = foregroundColor.usingColorSpace(.deviceRGB) ?? foregroundColor
        return "R \(Int((color.redComponent * 255).rounded()))  G \(Int((color.greenComponent * 255).rounded()))  B \(Int((color.blueComponent * 255).rounded()))"
    }

    func selectTool(_ tool: ImageEditorTool) {
        selectedTool = tool
        if !tool.isImplemented {
            statusText = L10n.text("imageEditor.status.toolSoon")
        } else {
            updateStatus()
        }
    }

    func zoomIn() {
        zoom = min(zoom * 1.2, 8)
    }

    func zoomOut() {
        zoom = max(zoom / 1.2, 0.08)
    }

    func fitZoom() {
        zoom = 1
        canvasOffset = .zero
    }

    func nudgeCanvas(by translation: CGSize) {
        canvasOffset.width += translation.width
        canvasOffset.height += translation.height
    }

    func updatePointer(_ point: CGPoint?) {
        guard let point else {
            pointerText = "X: 0 Y: 0"
            return
        }
        pointerText = "X: \(Int(point.x.rounded())) Y: \(Int(point.y.rounded()))"
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(document)
        document = previous
        ensureSelectedLayer()
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        updateStatus()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(document)
        document = next
        ensureSelectedLayer()
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        updateStatus()
    }

    func restoreHistoryEntry(_ id: UUID) {
        guard let snapshot = historySnapshots[id],
              document.history.last?.id != id
        else { return }
        pushUndo()
        document = snapshot
        ensureSelectedLayer()
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        appendHistory(L10n.text("imageEditor.history.revert"))
    }

    func applyAndClose(close: () -> Void) {
        onApply(document.compositedImage)
        close()
    }

    func clearSelection() {
        guard document.selection != nil else { return }
        pushUndo()
        document.selection = nil
        appendHistory(L10n.text("imageEditor.history.selectionCleared"))
    }

    func invertSelection() {
        guard document.selection != nil else { return }
        pushUndo()
        document.selection?.isInverted.toggle()
        appendHistory(L10n.text("imageEditor.history.selectionInverted"))
        statusText = L10n.text("imageEditor.status.selectionInverted")
    }

    func createRectSelection(from start: CGPoint, to end: CGPoint) {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ).intersection(CGRect(origin: .zero, size: document.canvasSize))
        guard rect.width > 2, rect.height > 2 else { return }
        pushUndo()
        document.selection = .rectangle(rect)
        appendHistory(L10n.text("imageEditor.history.selection"))
        statusText = L10n.text("imageEditor.status.selectionCreated")
    }

    func createLassoSelection(points: [CGPoint]) {
        let boundedPoints = points.filter { point in
            CGRect(origin: .zero, size: document.canvasSize).contains(point)
        }
        guard let selection = ImageEditorSelection.polygon(boundedPoints) else { return }
        pushUndo()
        document.selection = selection
        appendHistory(L10n.text("imageEditor.history.selection"))
        statusText = L10n.text("imageEditor.status.selectionCreated")
    }

    func createMagicSelection(at point: CGPoint?) {
        guard let point,
              let selection = magicSelection(at: point)
        else { return }
        pushUndo()
        document.selection = selection
        appendHistory(L10n.text("imageEditor.history.magicSelection"))
        statusText = L10n.text("imageEditor.status.selectionCreated")
    }

    func isLayerSelected(_ id: UUID) -> Bool {
        document.selectedLayerIDs.contains(id)
    }

    func isPrimaryLayer(_ id: UUID) -> Bool {
        document.selectedLayerID == id
    }

    func selectLayer(_ id: UUID, editingMask: Bool = false, extendingSelection: Bool = false) {
        guard document.layers.contains(where: { $0.id == id }) else { return }
        if extendingSelection && !editingMask {
            if document.selectedLayerIDs.contains(id), document.selectedLayerIDs.count > 1 {
                document.selectedLayerIDs.remove(id)
                if document.selectedLayerID == id {
                    document.selectedLayerID = topmostSelectedLayerID()
                }
            } else {
                document.selectedLayerIDs.insert(id)
                document.selectedLayerID = id
            }
            isEditingLayerMask = false
            syncAdjustmentControlsFromSelection()
            syncFilterControlsFromSelection()
            syncTextControlsFromSelection()
            return
        }

        document.selectedLayerID = id
        document.selectedLayerIDs = [id]
        isEditingLayerMask = editingMask && (document.selectedLayer?.mask != nil)
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
    }

    func addLayer() {
        pushUndo()
        let layerNumber = document.layers.count
        let layer = ImageEditorLayer.blank(
            name: L10n.format("imageEditor.layer.newName", layerNumber),
            size: document.canvasSize
        )
        document.layers.append(layer)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        appendHistory(L10n.text("imageEditor.history.layerNew"))
    }

    func addLayerGroup() {
        pushUndo()
        let groupNumber = document.layers.filter(\.isGroup).count + 1
        let group = ImageEditorLayer.group(
            name: L10n.format("imageEditor.layer.groupName", groupNumber),
            size: document.canvasSize
        )
        document.layers.append(group)
        document.selectedLayerID = group.id
        document.selectedLayerIDs = [group.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerGroupNew"))
    }

    func groupSelectedLayer() {
        let indices = selectedLayerIndices
        guard canGroupSelectedLayer, let insertionIndex = indices.last else { return }
        pushUndo()
        let groupNumber = document.layers.filter(\.isGroup).count + 1
        let group = ImageEditorLayer.group(
            name: L10n.format("imageEditor.layer.groupName", groupNumber),
            size: document.canvasSize
        )
        for index in indices {
            document.layers[index].groupID = group.id
        }
        document.layers.insert(group, at: insertionIndex + 1)
        document.selectedLayerID = group.id
        document.selectedLayerIDs = [group.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerGroupSelected"))
    }

    func duplicateSelectedLayer() {
        let indices = selectedLayerIndices
        guard !indices.isEmpty else { return }
        pushUndo()
        var insertedIDs: [UUID] = []
        var offset = 0
        for index in indices {
            var layer = document.layers[index + offset]
            layer.id = UUID()
            layer.name = L10n.format("imageEditor.layer.copyName", layer.name)
            document.layers.insert(layer, at: index + offset + 1)
            insertedIDs.append(layer.id)
            offset += 1
        }
        document.selectedLayerID = insertedIDs.last
        document.selectedLayerIDs = Set(insertedIDs)
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerDuplicate"))
    }

    func renameSelectedLayer(to proposedName: String) {
        guard let index = document.selectedLayerIndex else { return }
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerNameInvalid")
            return
        }
        guard document.layers[index].name != trimmedName else { return }
        pushUndo()
        document.layers[index].name = trimmedName
        appendHistory(L10n.text("imageEditor.history.layerRename"))
        statusText = L10n.text("imageEditor.status.layerRenamed")
    }

    func deleteSelectedLayer() {
        let deletionIDs = deletionIDsForCurrentSelection()
        guard canDeleteLayer, !deletionIDs.isEmpty else { return }
        let fallbackIndex = document.selectedLayerIndex ?? 0
        pushUndo()
        document.layers.removeAll { deletionIDs.contains($0.id) }
        let nextIndex = min(max(0, fallbackIndex - 1), max(0, document.layers.count - 1))
        document.selectedLayerID = document.layers.indices.contains(nextIndex)
            ? document.layers[nextIndex].id
            : document.layers.last?.id
        document.selectedLayerIDs = document.selectedLayerID.map { Set([$0]) } ?? []
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerDelete"))
    }

    func moveSelectedLayerUp() {
        moveSelectedLayers(direction: 1)
    }

    func moveSelectedLayerDown() {
        moveSelectedLayers(direction: -1)
    }

    func moveSelectedLayerToTop() {
        moveSelectedLayers(to: .top)
    }

    func moveSelectedLayerToBottom() {
        moveSelectedLayers(to: .bottom)
    }

    func toggleLayerVisibility(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        document.layers[index].isVisible.toggle()
        appendHistory(L10n.text("imageEditor.history.layerVisibility"))
    }

    func toggleLayerLock(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        document.layers[index].isLocked.toggle()
        if document.layers[index].isLocked, document.layers[index].id == document.selectedLayerID {
            isEditingLayerMask = false
        }
        appendHistory(L10n.text("imageEditor.history.layerLock"))
    }

    func setSelectedLayerOpacity(_ opacity: Double) {
        guard let index = document.selectedLayerIndex else { return }
        document.layers[index].opacity = max(0, min(1, opacity))
        updateStatus()
    }

    func setSelectedLayerBlendMode(_ blendMode: ImageEditorBlendMode) {
        guard let index = document.selectedLayerIndex,
              !document.layers[index].isGroup,
              !document.layers[index].isAdjustment,
              !document.layers[index].isFilter,
              document.layers[index].blendMode != blendMode
        else { return }
        pushUndo()
        document.layers[index].blendMode = blendMode
        appendHistory(L10n.text("imageEditor.history.layerBlendMode"))
    }

    func commitSelectedLayerOpacityChange() {
        appendHistory(L10n.text("imageEditor.history.layerOpacity"))
    }

    func toggleSelectedLayerStroke() {
        guard let index = document.selectedLayerIndex else { return }
        guard !document.layers[index].isGroup,
              !document.layers[index].isAdjustment,
              !document.layers[index].isFilter,
              !document.isEffectivelyLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        document.layers[index].style.strokeEnabled.toggle()
        appendHistory(L10n.text("imageEditor.history.layerStroke"))
    }

    func toggleSelectedLayerShadow() {
        guard let index = document.selectedLayerIndex else { return }
        guard !document.layers[index].isGroup,
              !document.layers[index].isAdjustment,
              !document.layers[index].isFilter,
              !document.isEffectivelyLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        document.layers[index].style.shadowEnabled.toggle()
        appendHistory(L10n.text("imageEditor.history.layerShadow"))
    }

    func toggleSelectedLayerClippingMask() {
        guard let index = document.selectedLayerIndex else { return }
        guard canToggleSelectedLayerClippingMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].isClippingMask.toggle()
        appendHistory(L10n.text("imageEditor.history.layerClippingMask"))
    }

    func setSelectedLayerStrokeWidth(_ width: Double) {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeWidth = max(1, min(24, CGFloat(width)))
        }
    }

    func setSelectedLayerShadowOpacity(_ opacity: Double) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    func setSelectedLayerShadowBlur(_ blur: Double) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowBlur = max(0, min(30, CGFloat(blur)))
        }
    }

    func setSelectedLayerShadowOffsetX(_ offset: Double) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowOffset.width = max(-40, min(40, CGFloat(offset)))
        }
    }

    func setSelectedLayerShadowOffsetY(_ offset: Double) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowOffset.height = max(-40, min(40, CGFloat(offset)))
        }
    }

    func mergeSelectedLayerDown() {
        guard canMergeSelectedLayerDown, let index = document.selectedLayerIndex else { return }
        pushUndo()
        if document.layers[index].isAdjustment {
            guard let merged = mergedAdjustmentLayer(lowerIndex: index - 1, adjustmentIndex: index) else { return }
            document.layers[index - 1] = merged
            document.layers.remove(at: index)
            document.selectedLayerID = merged.id
            document.selectedLayerIDs = [merged.id]
            isEditingLayerMask = false
            appendHistory(L10n.text("imageEditor.history.layerMergeDown"))
            return
        }
        if document.layers[index].isFilter {
            guard let merged = mergedFilterLayer(lowerIndex: index - 1, filterIndex: index) else { return }
            document.layers[index - 1] = merged
            document.layers.remove(at: index)
            document.selectedLayerID = merged.id
            document.selectedLayerIDs = [merged.id]
            isEditingLayerMask = false
            appendHistory(L10n.text("imageEditor.history.layerMergeDown"))
            return
        }
        guard let merged = mergedLayer(lowerIndex: index - 1, upperIndex: index) else { return }
        document.layers[index - 1] = merged
        document.layers.remove(at: index)
        document.selectedLayerID = merged.id
        document.selectedLayerIDs = [merged.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMergeDown"))
    }

    func stampVisibleLayers() {
        guard canStampVisibleLayers else { return }
        pushUndo()
        var layer = ImageEditorLayer.blank(
            name: L10n.text("imageEditor.layer.visibleStampName"),
            size: document.canvasSize
        )
        layer.image = document.compositedImage
        layer.frame = CGRect(origin: .zero, size: document.canvasSize)
        layer.opacity = 1
        layer.blendMode = .normal
        layer.groupID = nil
        layer.isClippingMask = false
        document.layers.append(layer)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerStampVisible"))
    }

    func addLayerMask() {
        guard canAddLayerMask, let index = document.selectedLayerIndex else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        document.layers[index].mask = NSImage.opaqueMask(size: document.layers[index].image.size)
        isEditingLayerMask = true
        appendHistory(L10n.text("imageEditor.history.layerMaskAdd"))
    }

    func deleteLayerMask() {
        guard canDeleteLayerMask, let index = document.selectedLayerIndex else { return }
        pushUndo()
        document.layers[index].mask = nil
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMaskDelete"))
    }

    func editLayerPixels() {
        isEditingLayerMask = false
        statusText = L10n.text("imageEditor.status.editingLayer")
    }

    func editLayerMask() {
        guard selectedLayerHasMask else {
            statusText = L10n.text("imageEditor.status.noLayerMask")
            return
        }
        isEditingLayerMask = true
        statusText = L10n.text("imageEditor.status.editingMask")
    }

    func rotateClockwise() {
        transformCanvas(historyTitle: L10n.text("imageEditor.history.rotate")) { layer, canvasSize in
            guard let rotated = layer.image.rotatedClockwise() else { return nil }
            var output = layer
            output.image = rotated
            output.frame = CGRect(
                x: canvasSize.height - layer.frame.maxY,
                y: layer.frame.minX,
                width: layer.frame.height,
                height: layer.frame.width
            )
            if let mask = layer.mask {
                output.mask = mask.rotatedClockwise()
            }
            return output
        } canvasSize: { size in
            CGSize(width: size.height, height: size.width)
        }
    }

    func flipHorizontal() {
        transformCanvas(historyTitle: L10n.text("imageEditor.history.flipHorizontal")) { layer, canvasSize in
            guard let flipped = layer.image.flipped(horizontal: true) else { return nil }
            var output = layer
            output.image = flipped
            output.frame = CGRect(
                x: canvasSize.width - layer.frame.maxX,
                y: layer.frame.minY,
                width: layer.frame.width,
                height: layer.frame.height
            )
            if let mask = layer.mask {
                output.mask = mask.flipped(horizontal: true)
            }
            return output
        } canvasSize: { $0 }
    }

    func flipVertical() {
        transformCanvas(historyTitle: L10n.text("imageEditor.history.flipVertical")) { layer, canvasSize in
            guard let flipped = layer.image.flipped(horizontal: false) else { return nil }
            var output = layer
            output.image = flipped
            output.frame = CGRect(
                x: layer.frame.minX,
                y: canvasSize.height - layer.frame.maxY,
                width: layer.frame.width,
                height: layer.frame.height
            )
            if let mask = layer.mask {
                output.mask = mask.flipped(horizontal: false)
            }
            return output
        } canvasSize: { $0 }
    }

    func cropCenter() {
        let size = document.canvasSize
        let cropRect = CGRect(
            x: size.width * 0.08,
            y: size.height * 0.08,
            width: size.width * 0.84,
            height: size.height * 0.84
        )
        crop(to: cropRect)
    }

    func crop(to rect: CGRect) {
        guard rect.width > 8, rect.height > 8 else { return }
        pushUndo()
        let bounded = rect.intersection(CGRect(origin: .zero, size: document.canvasSize))
        guard bounded.width > 8, bounded.height > 8 else { return }
        for index in document.layers.indices {
            let layer = document.layers[index]
            let shiftedFrame = CGRect(
                x: layer.frame.minX - bounded.minX,
                y: layer.frame.minY - bounded.minY,
                width: layer.frame.width,
                height: layer.frame.height
            )
            document.layers[index].frame = shiftedFrame
        }
        document.canvasSize = bounded.size
        appendHistory(L10n.text("imageEditor.history.crop"))
    }

    func addGradient() {
        transformSelectedLayer(historyTitle: L10n.text("imageEditor.history.gradient")) { image in
            image.withLinearGradientOverlay(start: foregroundColor, end: backgroundColor, opacity: opacity)
        }
    }

    func addText(at point: CGPoint? = nil) {
        let text = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusText = L10n.text("imageEditor.status.textEmpty")
            return
        }
        let targetPoint = point ?? CGPoint(x: document.canvasSize.width * 0.12, y: document.canvasSize.height * 0.16)
        let content = ImageEditorTextContent(
            text: text,
            color: foregroundColor,
            fontSize: CGFloat(clampedTextSize(textSize)),
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding)
        )
        pushUndo()
        var layer = ImageEditorLayer.text(
            name: L10n.format("imageEditor.layer.textName", textLayerNameFragment(text)),
            origin: targetPoint,
            content: content
        )
        layer.opacity = Double(opacity)
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerTextNew"))
    }

    func updateSelectedTextLayer() {
        let text = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusText = L10n.text("imageEditor.status.textEmpty")
            return
        }
        guard let index = document.selectedLayerIndex,
              var content = document.layers[index].textContent,
              !document.isEffectivelyLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        content.text = text
        content.color = foregroundColor
        content.fontSize = CGFloat(clampedTextSize(textSize))
        content.point = CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding)
        let layerSize = content.layerSize()
        if let mask = document.layers[index].mask, mask.size != layerSize {
            document.layers[index].mask = mask.resized(to: layerSize)
        }
        document.layers[index].image = NSImage.transparent(size: layerSize)
        document.layers[index].frame.size = layerSize
        document.layers[index].kind = .text(content)
        document.layers[index].name = L10n.format("imageEditor.layer.textName", textLayerNameFragment(text))
        appendHistory(L10n.text("imageEditor.history.layerTextUpdate"))
    }

    func drawBrush(points: [CGPoint], erase: Bool = false) {
        guard points.count > 1 else { return }
        if isEditingLayerMask {
            paintSelectedLayerMask(points: points, reveal: erase)
            return
        }
        transformSelectedLayer(historyTitle: erase ? L10n.text("imageEditor.history.erase") : L10n.text("imageEditor.history.brush")) { image in
            image.withStroke(points: points, color: foregroundColor, width: brushSize, opacity: opacity, erase: erase)
        }
    }

    func drawShape(from start: CGPoint, to end: CGPoint, ellipse: Bool) {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        guard rect.width > 3, rect.height > 3 else { return }
        transformSelectedLayer(historyTitle: ellipse ? L10n.text("imageEditor.history.ellipse") : L10n.text("imageEditor.history.rectangle")) { image in
            image.withShape(rect: rect, color: foregroundColor, width: max(2, brushSize * 0.35), opacity: opacity, ellipse: ellipse)
        }
    }

    func sampleColor(at point: CGPoint) {
        guard let color = document.compositedImage.color(at: point) else { return }
        foregroundColor = color
        statusText = L10n.text("imageEditor.status.colorSampled")
    }

    func applyAdjustment() {
        let title = selectedAdjustment.title
        guard let output = adjustedImage(kind: selectedAdjustment, amount: adjustmentValue) else {
            statusText = L10n.text("imageEditor.status.adjustmentFailed")
            return
        }
        replaceSelectedLayerImage(output, historyTitle: title)
        adjustmentValue = 0
    }

    func addAdjustmentLayer() {
        pushUndo()
        let layer = ImageEditorLayer.adjustment(
            name: L10n.format("imageEditor.layer.adjustmentName", selectedAdjustment.title),
            size: document.canvasSize,
            kind: selectedAdjustment,
            amount: adjustmentValue
        )
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    func updateSelectedAdjustmentLayer() {
        guard let index = document.selectedLayerIndex,
              document.layers[index].isAdjustment,
              !document.isEffectivelyLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].kind = .adjustment(selectedAdjustment, adjustmentValue)
        document.layers[index].name = L10n.format("imageEditor.layer.adjustmentName", selectedAdjustment.title)
        appendHistory(L10n.text("imageEditor.history.layerAdjustmentUpdate"))
    }

    func addFilterLayer() {
        pushUndo()
        let layer = ImageEditorLayer.filter(
            name: L10n.format("imageEditor.layer.filterName", selectedFilter.title),
            size: document.canvasSize,
            kind: selectedFilter,
            intensity: filterIntensity
        )
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerFilterNew"))
    }

    func updateSelectedFilterLayer() {
        guard let index = document.selectedLayerIndex,
              document.layers[index].isFilter,
              !document.isEffectivelyLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].kind = .filter(selectedFilter, filterIntensity)
        document.layers[index].name = L10n.format("imageEditor.layer.filterName", selectedFilter.title)
        appendHistory(L10n.text("imageEditor.history.layerFilterUpdate"))
    }

    private func transformSelectedLayer(historyTitle: String, transform: (NSImage) -> NSImage?) {
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        guard let output = transform(layer.image) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        replaceSelectedLayerImage(output, historyTitle: historyTitle)
    }

    private func transformCanvas(
        historyTitle: String,
        transform: (ImageEditorLayer, CGSize) -> ImageEditorLayer?,
        canvasSize newCanvasSize: (CGSize) -> CGSize
    ) {
        let originalCanvasSize = document.canvasSize
        let transformedLayers = document.layers.compactMap { transform($0, originalCanvasSize) }
        guard transformedLayers.count == document.layers.count else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.canvasSize = newCanvasSize(originalCanvasSize)
        document.layers = transformedLayers
        appendHistory(historyTitle)
    }

    private func replaceSelectedLayerImage(_ image: NSImage, historyTitle: String) {
        guard let index = document.selectedLayerIndex else { return }
        pushUndo()
        let normalized = image.normalizedBitmapImage()
        let output = clippedToSelection(original: document.layers[index].image, output: normalized)
        document.layers[index].image = normalized
        document.layers[index].image = output
        document.layers[index].frame = CGRect(origin: .zero, size: output.size)
        appendHistory(historyTitle)
    }

    #if DEBUG
    func replaceSelectedLayerImageForTesting(_ image: NSImage, historyTitle: String) {
        replaceSelectedLayerImage(image, historyTitle: historyTitle)
    }
    #endif

    private func paintSelectedLayerMask(points: [CGPoint], reveal: Bool) {
        guard let index = document.selectedLayerIndex else { return }
        guard !document.isEffectivelyLocked(document.layers[index]) else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        guard let mask = document.layers[index].mask else {
            statusText = L10n.text("imageEditor.status.noLayerMask")
            isEditingLayerMask = false
            return
        }
        guard let updated = mask.withMaskStroke(points: points, width: brushSize, opacity: opacity, reveal: reveal) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].mask = clippedToSelection(original: mask, output: updated)
        appendHistory(reveal ? L10n.text("imageEditor.history.layerMaskReveal") : L10n.text("imageEditor.history.layerMaskHide"))
    }

    private func clippedToSelection(original: NSImage, output: NSImage) -> NSImage {
        guard let selection = document.selection else { return output }
        guard let mask = selectionMask(for: selection, size: original.size) else { return output }
        let maskedOutput = NSImage.rendered(size: original.size) { _ in
            output.draw(
                in: CGRect(origin: .zero, size: output.size),
                from: CGRect(origin: .zero, size: output.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: original.size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
        guard let maskedOutput else { return output }
        return NSImage.rendered(size: original.size) { _ in
            original.draw(
                in: CGRect(origin: .zero, size: original.size),
                from: CGRect(origin: .zero, size: original.size),
                operation: .copy,
                fraction: 1
            )
            maskedOutput.draw(
                in: CGRect(origin: .zero, size: original.size),
                from: CGRect(origin: .zero, size: maskedOutput.size),
                operation: .sourceOver,
                fraction: 1
            )
        } ?? output
    }

    private func selectionMask(for selection: ImageEditorSelection, size: CGSize) -> NSImage? {
        if let rasterMask = selection.rasterMask,
           let image = NSImage.selectionMaskImage(
            rasterMask,
            inverted: selection.isInverted,
            targetSize: size
           ) {
            guard feather > 0 else { return image }
            return image.blurred(radius: feather) ?? image
        }
        let hardMask = NSImage.rendered(size: size) { rect in
            let path = selection.path()
            if selection.isInverted {
                NSColor.white.setFill()
                rect.fill()
                guard let context = NSGraphicsContext.current?.cgContext else { return }
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setFill()
                path.fill()
                context.restoreGState()
            } else {
                NSColor.white.setFill()
                path.fill()
            }
        }
        guard let hardMask, feather > 0 else { return hardMask }
        return hardMask.blurred(radius: feather) ?? hardMask
    }

    private func adjustedImage(kind: ImageEditorAdjustment, amount: Double) -> NSImage? {
        guard let layer = editableSelectedLayer() else { return nil }
        return layer.image.adjusted(kind: kind, amount: amount)
    }

    private func editableSelectedLayer() -> ImageEditorLayer? {
        guard let index = document.selectedLayerIndex else { return nil }
        let layer = document.layers[index]
        return layer.isGroup || layer.isAdjustment || layer.isFilter || layer.isText || document.isEffectivelyLocked(layer) ? nil : layer
    }

    private func updateSelectedLayerStyle(_ mutate: (inout ImageEditorLayerStyle) -> Void) {
        guard let index = document.selectedLayerIndex else { return }
        guard !document.layers[index].isGroup,
              !document.layers[index].isAdjustment,
              !document.layers[index].isFilter,
              !document.isEffectivelyLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        mutate(&document.layers[index].style)
        appendHistory(L10n.text("imageEditor.history.layerStyle"))
    }

    private func groupMemberIndices(for groupID: UUID) -> [Int] {
        document.layers.indices.filter { document.layers[$0].groupID == groupID }
    }

    private var selectedLayerIndices: [Int] {
        document.layers.indices.filter { document.selectedLayerIDs.contains(document.layers[$0].id) }
    }

    private func topmostSelectedLayerID() -> UUID? {
        document.layers.reversed().first { document.selectedLayerIDs.contains($0.id) }?.id
    }

    private enum LayerStackBoundary {
        case top
        case bottom
    }

    private func deletionIDsForCurrentSelection() -> Set<UUID> {
        var deletionIDs = Set<UUID>()
        for index in selectedLayerIndices {
            let layer = document.layers[index]
            if layer.isGroup {
                guard !layer.isLocked else { continue }
                deletionIDs.insert(layer.id)
                document.layers
                    .filter { $0.groupID == layer.id }
                    .forEach { deletionIDs.insert($0.id) }
            } else if !document.isEffectivelyLocked(layer) {
                deletionIDs.insert(layer.id)
            }
        }
        return deletionIDs
    }

    private func canMoveSelectedLayers(direction: Int) -> Bool {
        let selectedIDs = document.selectedLayerIDs
        guard !selectedIDs.isEmpty else { return false }
        for index in document.layers.indices where selectedIDs.contains(document.layers[index].id) {
            let targetIndex = index + direction
            guard document.layers.indices.contains(targetIndex) else { continue }
            if !selectedIDs.contains(document.layers[targetIndex].id) {
                return true
            }
        }
        return false
    }

    private func moveSelectedLayers(direction: Int) {
        guard direction == 1 || direction == -1, canMoveSelectedLayers(direction: direction) else { return }
        pushUndo()
        let selectedIDs = document.selectedLayerIDs
        let indices: [Int] = direction > 0
            ? Array(document.layers.indices.reversed())
            : Array(document.layers.indices)
        for index in indices where selectedIDs.contains(document.layers[index].id) {
            let targetIndex = index + direction
            guard document.layers.indices.contains(targetIndex),
                  !selectedIDs.contains(document.layers[targetIndex].id)
            else { continue }
            document.layers.swapAt(index, targetIndex)
        }
        appendHistory(L10n.text("imageEditor.history.layerMove"))
    }

    private func canMoveSelectedLayers(to boundary: LayerStackBoundary) -> Bool {
        guard !document.selectedLayerIDs.isEmpty else { return false }
        return reorderedLayers(movingSelectionTo: boundary).map(\.id) != document.layers.map(\.id)
    }

    private func moveSelectedLayers(to boundary: LayerStackBoundary) {
        guard canMoveSelectedLayers(to: boundary) else { return }
        pushUndo()
        document.layers = reorderedLayers(movingSelectionTo: boundary)
        let historyKey = boundary == .top
            ? "imageEditor.history.layerMoveToTop"
            : "imageEditor.history.layerMoveToBottom"
        appendHistory(L10n.text(historyKey))
    }

    private func reorderedLayers(movingSelectionTo boundary: LayerStackBoundary) -> [ImageEditorLayer] {
        let selectedIDs = document.selectedLayerIDs
        let selectedLayers = document.layers.filter { selectedIDs.contains($0.id) }
        let remainingLayers = document.layers.filter { !selectedIDs.contains($0.id) }
        switch boundary {
        case .top:
            return remainingLayers + selectedLayers
        case .bottom:
            return selectedLayers + remainingLayers
        }
    }

    private func clippingBaseExists(below index: Int, groupID: UUID?) -> Bool {
        document.hasClippingBase(below: index, groupID: groupID)
    }

    private func magicSelection(at point: CGPoint) -> ImageEditorSelection? {
        let image = document.compositedImage
        guard let targetColor = image.color(at: point),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let provider = cgImage.dataProvider,
              let data = provider.data,
              let bytes = CFDataGetBytePtr(data)
        else {
            return fallbackMagicSelection(at: point)
        }

        let target = rgbaComponents(targetColor)
        let threshold: CGFloat = 0.22
        let bytesPerPixel = max(1, cgImage.bitsPerPixel / 8)
        var selectedBounds: CGRect?
        let sampleStep = max(1, min(cgImage.width, cgImage.height) / 220)

        var y = 0
        while y < cgImage.height {
            var x = 0
            while x < cgImage.width {
                let offset = y * cgImage.bytesPerRow + x * bytesPerPixel
                if offset + 2 < CFDataGetLength(data) {
                    let sampled = (
                        r: CGFloat(bytes[offset]) / 255,
                        g: CGFloat(bytes[offset + 1]) / 255,
                        b: CGFloat(bytes[offset + 2]) / 255,
                        a: bytesPerPixel > 3 ? CGFloat(bytes[offset + 3]) / 255 : 1
                    )
                    if colorDistance(sampled, target) <= threshold {
                        let imagePoint = CGPoint(
                            x: CGFloat(x) / CGFloat(cgImage.width) * image.size.width,
                            y: image.size.height - CGFloat(y) / CGFloat(cgImage.height) * image.size.height
                        )
                        let rect = CGRect(origin: imagePoint, size: CGSize(width: CGFloat(sampleStep), height: CGFloat(sampleStep)))
                        selectedBounds = selectedBounds?.union(rect) ?? rect
                    }
                }
                x += sampleStep
            }
            y += sampleStep
        }

        guard let selectedBounds,
              selectedBounds.width > 2,
              selectedBounds.height > 2
        else {
            return fallbackMagicSelection(at: point)
        }
        return .rectangle(selectedBounds.intersection(CGRect(origin: .zero, size: document.canvasSize)))
    }

    private func fallbackMagicSelection(at point: CGPoint) -> ImageEditorSelection {
        let side = max(24, min(document.canvasSize.width, document.canvasSize.height) * 0.18)
        let rect = CGRect(
            x: point.x - side / 2,
            y: point.y - side / 2,
            width: side,
            height: side
        ).intersection(CGRect(origin: .zero, size: document.canvasSize))
        return .rectangle(rect)
    }

    private func rgbaComponents(_ color: NSColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        return (rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent)
    }

    private func colorDistance(
        _ lhs: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat),
        _ rhs: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)
    ) -> CGFloat {
        let red = lhs.r - rhs.r
        let green = lhs.g - rhs.g
        let blue = lhs.b - rhs.b
        let alpha = lhs.a - rhs.a
        return sqrt(red * red + green * green + blue * blue + alpha * alpha)
    }

    private func mergedAdjustmentLayer(lowerIndex: Int, adjustmentIndex: Int) -> ImageEditorLayer? {
        guard document.layers.indices.contains(lowerIndex),
              document.layers.indices.contains(adjustmentIndex),
              let adjustment = document.layers[adjustmentIndex].adjustment
        else { return nil }
        let lower = document.layers[lowerIndex]
        let adjustmentLayer = document.layers[adjustmentIndex]
        let canvasSize = document.canvasSize
        guard let renderedLower = NSImage.rendered(size: canvasSize, actions: { _ in
            drawMergedLayer(at: lowerIndex)
        }),
              let adjustedImage = renderedLower.applyingAdjustment(
                kind: adjustment.kind,
                amount: adjustment.amount * adjustmentLayer.opacity,
                mask: adjustmentLayer.mask
              )
        else { return nil }

        var merged = lower
        merged.id = UUID()
        merged.name = L10n.format("imageEditor.layer.mergedName", lower.name)
        merged.image = adjustedImage
        merged.frame = CGRect(origin: .zero, size: canvasSize)
        merged.opacity = 1
        merged.blendMode = .normal
        merged.isVisible = lower.isVisible || adjustmentLayer.isVisible
        merged.isLocked = false
        merged.mask = nil
        merged.style = ImageEditorLayerStyle()
        merged.kind = .pixel
        merged.isClippingMask = false
        return merged
    }

    private func mergedFilterLayer(lowerIndex: Int, filterIndex: Int) -> ImageEditorLayer? {
        guard document.layers.indices.contains(lowerIndex),
              document.layers.indices.contains(filterIndex),
              let filter = document.layers[filterIndex].filter
        else { return nil }
        let lower = document.layers[lowerIndex]
        let filterLayer = document.layers[filterIndex]
        let canvasSize = document.canvasSize
        guard let renderedLower = NSImage.rendered(size: canvasSize, actions: { _ in
            drawMergedLayer(at: lowerIndex)
        }),
              let filteredImage = renderedLower.applyingFilter(
                kind: filter.kind,
                intensity: filter.intensity * filterLayer.opacity,
                mask: filterLayer.mask
              )
        else { return nil }

        var merged = lower
        merged.id = UUID()
        merged.name = L10n.format("imageEditor.layer.mergedName", lower.name)
        merged.image = filteredImage
        merged.frame = CGRect(origin: .zero, size: canvasSize)
        merged.opacity = 1
        merged.blendMode = .normal
        merged.isVisible = lower.isVisible || filterLayer.isVisible
        merged.isLocked = false
        merged.mask = nil
        merged.style = ImageEditorLayerStyle()
        merged.kind = .pixel
        merged.isClippingMask = false
        return merged
    }

    private func mergedLayer(lowerIndex: Int, upperIndex: Int) -> ImageEditorLayer? {
        guard document.layers.indices.contains(lowerIndex),
              document.layers.indices.contains(upperIndex)
        else { return nil }
        let lower = document.layers[lowerIndex]
        let upper = document.layers[upperIndex]
        let canvasSize = document.canvasSize
        guard let image = NSImage.rendered(size: canvasSize, actions: { _ in
            drawMergedLayer(at: lowerIndex)
            drawMergedLayer(at: upperIndex)
        }) else { return nil }

        var merged = lower
        merged.id = UUID()
        merged.name = L10n.format("imageEditor.layer.mergedName", lower.name)
        merged.image = image
        merged.frame = CGRect(origin: .zero, size: canvasSize)
        merged.opacity = 1
        merged.blendMode = .normal
        merged.isVisible = lower.isVisible || upper.isVisible
        merged.isLocked = false
        merged.mask = nil
        merged.style = ImageEditorLayerStyle()
        merged.kind = .pixel
        merged.isClippingMask = false
        return merged
    }

    private func drawMergedLayer(at index: Int) {
        let layer = document.layers[index]
        if layer.isClippingMask,
           let clippedImage = document.clippedCompositingImage(forLayerAt: index) {
            clippedImage.draw(
                in: CGRect(origin: .zero, size: document.canvasSize),
                from: CGRect(origin: .zero, size: document.canvasSize),
                operation: layer.blendMode.operation,
                fraction: layer.opacity
            )
            return
        }

        let image = layer.compositingImage
        image.draw(
            in: layer.compositingFrame,
            from: CGRect(origin: .zero, size: image.size),
            operation: layer.blendMode.operation,
            fraction: layer.opacity
        )
    }

    func pushUndo() {
        undoStack.append(document)
        redoStack.removeAll()
    }

    func appendHistory(_ title: String) {
        let entry = ImageEditorHistoryEntry(title: title)
        document.history.append(entry)
        historySnapshots[entry.id] = document
        updateStatus()
    }

    private func recordCurrentHistorySnapshot() {
        guard let entry = document.history.last else { return }
        historySnapshots[entry.id] = document
    }

    private func ensureSelectedLayer() {
        let existingIDs = Set(document.layers.map(\.id))
        document.selectedLayerIDs = document.selectedLayerIDs.intersection(existingIDs)
        if let selectedLayerID = document.selectedLayerID,
           existingIDs.contains(selectedLayerID) {
            document.selectedLayerIDs.insert(selectedLayerID)
            if document.selectedLayer?.mask == nil {
                isEditingLayerMask = false
            }
            return
        }
        document.selectedLayerID = topmostSelectedLayerID() ?? document.layers.last?.id
        document.selectedLayerIDs = document.selectedLayerID.map { Set([$0]) } ?? []
        isEditingLayerMask = false
    }

    private func syncAdjustmentControlsFromSelection() {
        guard let adjustment = document.selectedLayer?.adjustment else { return }
        selectedAdjustment = adjustment.kind
        adjustmentValue = adjustment.amount
    }

    private func syncFilterControlsFromSelection() {
        guard let filter = document.selectedLayer?.filter else { return }
        selectedFilter = filter.kind
        filterIntensity = filter.intensity
    }

    private func syncTextControlsFromSelection() {
        guard let content = document.selectedLayer?.textContent else { return }
        textValue = content.text
        textSize = Double(content.fontSize)
        foregroundColor = content.color
    }

    private func clampedTextSize(_ size: Double) -> Double {
        max(6, min(240, size))
    }

    private func textLayerNameFragment(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(trimmed.prefix(18))
        return prefix.isEmpty ? L10n.text("imageEditor.layer.textFallbackName") : prefix
    }

    func updateStatus() {
        statusText = L10n.format("imageEditor.status.ready", sizeText, zoomText)
    }

}

extension NSImage {
    func normalizedBitmapImage() -> NSImage {
        let targetSize = size.width > 0 && size.height > 0 ? size : CGSize(width: 1, height: 1)
        let image = NSImage(size: targetSize)
        image.lockFocus()
        draw(in: CGRect(origin: .zero, size: targetSize), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        image.unlockFocus()
        return image
    }

    func rotatedClockwise() -> NSImage? {
        let outputSize = CGSize(width: size.height, height: size.width)
        return rendered(size: outputSize) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.translateBy(x: outputSize.width, y: 0)
            context.rotate(by: .pi / 2)
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            _ = rect
        }
    }

    func rotated(degrees: CGFloat) -> NSImage? {
        let radians = degrees * .pi / 180
        let sine = abs(sin(radians))
        let cosine = abs(cos(radians))
        let outputSize = CGSize(
            width: max(1, size.width * cosine + size.height * sine),
            height: max(1, size.width * sine + size.height * cosine)
        )

        return rendered(size: outputSize) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.rotate(by: radians)
            draw(
                in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
        }
    }

    func flipped(horizontal: Bool) -> NSImage? {
        rendered(size: size) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            if horizontal {
                context.translateBy(x: size.width, y: 0)
                context.scaleBy(x: -1, y: 1)
            } else {
                context.translateBy(x: 0, y: size.height)
                context.scaleBy(x: 1, y: -1)
            }
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        }
    }

    func cropped(to rect: CGRect) -> NSImage? {
        let bounded = rect.intersection(CGRect(origin: .zero, size: size))
        guard bounded.width > 0, bounded.height > 0 else { return nil }
        return rendered(size: bounded.size) { _ in
            draw(
                in: CGRect(x: -bounded.minX, y: -bounded.minY, width: size.width, height: size.height),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
        }
    }

    func withStroke(points: [CGPoint], color: NSColor, width: CGFloat, opacity: CGFloat, erase: Bool) -> NSImage? {
        rendered(size: size) { _ in
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            guard let first = points.first else { return }
            let path = NSBezierPath()
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.lineWidth = width
            path.move(to: first)
            for point in points.dropFirst() {
                path.line(to: point)
            }
            if erase, let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setStroke()
                path.stroke()
                context.restoreGState()
            } else {
                color.withAlphaComponent(opacity).setStroke()
                path.stroke()
            }
        }
    }

    func withMaskStroke(points: [CGPoint], width: CGFloat, opacity: CGFloat, reveal: Bool) -> NSImage? {
        rendered(size: size) { _ in
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            guard let first = points.first else { return }
            let path = NSBezierPath()
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.lineWidth = width
            path.move(to: first)
            for point in points.dropFirst() {
                path.line(to: point)
            }
            if reveal {
                NSColor.white.withAlphaComponent(opacity).setStroke()
                path.stroke()
            } else if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setStroke()
                path.stroke()
                context.restoreGState()
            }
        }
    }

    func withShape(rect: CGRect, color: NSColor, width: CGFloat, opacity: CGFloat, ellipse: Bool) -> NSImage? {
        rendered(size: size) { _ in
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            let path = ellipse ? NSBezierPath(ovalIn: rect) : NSBezierPath(rect: rect)
            path.lineWidth = width
            color.withAlphaComponent(opacity).setStroke()
            path.stroke()
        }
    }

    func withText(_ text: String, at point: CGPoint, color: NSColor, opacity: CGFloat) -> NSImage? {
        rendered(size: size) { _ in
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(18, min(size.width, size.height) * 0.055), weight: .semibold),
                .foregroundColor: color.withAlphaComponent(opacity)
            ]
            text.draw(at: point, withAttributes: attributes)
        }
    }

    func withLinearGradientOverlay(start: NSColor, end: NSColor, opacity: CGFloat) -> NSImage? {
        rendered(size: size) { _ in
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            guard let context = NSGraphicsContext.current?.cgContext,
                  let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        start.withAlphaComponent(opacity * 0.45).cgColor,
                        end.withAlphaComponent(opacity * 0.45).cgColor
                    ] as CFArray,
                    locations: nil
                  )
            else { return }
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height),
                end: CGPoint(x: size.width, y: 0),
                options: []
            )
        }
    }

    func alphaTinted(color: NSColor) -> NSImage {
        rendered(size: size) { rect in
            color.setFill()
            rect.fill()
            draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: size),
                operation: .destinationIn,
                fraction: 1
            )
        } ?? NSImage(size: size)
    }

    func blurred(radius: CGFloat) -> NSImage? {
        guard radius > 0 else { return self }
        guard let ciImage = ciImageForEditing() else { return nil }
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = ciImage.clampedToExtent()
        filter.radius = Float(radius)
        guard let output = filter.outputImage?.cropped(to: ciImage.extent),
              let cgImage = CIContext(options: nil).createCGImage(output, from: ciImage.extent)
        else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: size)
    }

    func resized(to targetSize: CGSize) -> NSImage? {
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        return rendered(size: targetSize) { _ in
            draw(
                in: CGRect(origin: .zero, size: targetSize),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
        }
    }

    func color(at point: CGPoint) -> NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let x = max(0, min(cgImage.width - 1, Int((point.x / max(size.width, 1)) * CGFloat(cgImage.width))))
        let y = max(0, min(cgImage.height - 1, Int((point.y / max(size.height, 1)) * CGFloat(cgImage.height))))
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * cgImage.height)
        guard let context = CGContext(
            data: &pixels,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(cgImage.height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        let offset = y * bytesPerRow + x * bytesPerPixel
        return NSColor(
            calibratedRed: CGFloat(pixels[offset]) / 255,
            green: CGFloat(pixels[offset + 1]) / 255,
            blue: CGFloat(pixels[offset + 2]) / 255,
            alpha: CGFloat(pixels[offset + 3]) / 255
        )
    }

    func ciImageForEditing() -> CIImage? {
        if let tiffRepresentation {
            return CIImage(data: tiffRepresentation)
        }
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return CIImage(cgImage: cgImage)
    }

    func filtered(kind: ImageEditorFilter, intensity: Double) -> NSImage? {
        guard let ciImage = ciImageForEditing() else { return nil }
        let clamped = max(0, min(1, intensity))
        let output: CIImage?

        switch kind {
        case .gaussianBlur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = ciImage.clampedToExtent()
            filter.radius = Float(clamped * 18)
            output = filter.outputImage?.cropped(to: ciImage.extent)
        case .sharpen:
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = ciImage
            filter.sharpness = Float(clamped * 1.5)
            output = filter.outputImage
        }

        guard let output,
              let cgImage = ImageEditorImageProcessing.ciContext.createCGImage(output, from: ciImage.extent)
        else { return nil }
        return NSImage(cgImage: cgImage, size: size)
    }

    func adjusted(kind: ImageEditorAdjustment, amount: Double) -> NSImage? {
        guard let ciImage = ciImageForEditing() else { return nil }
        let clamped = max(-1, min(1, amount))
        let output: CIImage?

        switch kind {
        case .brightness:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.brightness = Float(clamped)
            output = filter.outputImage
        case .contrast:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.contrast = Float(1 + clamped)
            output = filter.outputImage
        case .saturation:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.saturation = Float(max(0, 1 + clamped))
            output = filter.outputImage
        case .blur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = ciImage.clampedToExtent()
            filter.radius = Float(max(0, clamped) * 18)
            output = filter.outputImage?.cropped(to: ciImage.extent)
        case .sharpen:
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = ciImage
            filter.sharpness = Float(max(0, clamped) * 1.5)
            output = filter.outputImage
        }

        guard let output,
              let cgImage = ImageEditorImageProcessing.ciContext.createCGImage(output, from: ciImage.extent)
        else { return nil }
        return NSImage(cgImage: cgImage, size: size)
    }

    func applyingAdjustment(kind: ImageEditorAdjustment, amount: Double, mask: NSImage?) -> NSImage? {
        guard let adjusted = adjusted(kind: kind, amount: amount) else { return nil }
        guard let mask else { return adjusted }
        let maskedAdjusted = NSImage.rendered(size: size) { _ in
            adjusted.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: adjusted.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
        guard let maskedAdjusted else { return adjusted }
        return NSImage.rendered(size: size) { _ in
            draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
            maskedAdjusted.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: maskedAdjusted.size),
                operation: .sourceOver,
                fraction: 1
            )
        } ?? adjusted
    }

    func applyingFilter(kind: ImageEditorFilter, intensity: Double, mask: NSImage?) -> NSImage? {
        guard let filtered = filtered(kind: kind, intensity: intensity) else { return nil }
        guard let mask else { return filtered }
        let maskedFiltered = NSImage.rendered(size: size) { _ in
            filtered.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: filtered.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
        guard let maskedFiltered else { return filtered }
        return NSImage.rendered(size: size) { _ in
            draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
            maskedFiltered.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: maskedFiltered.size),
                operation: .sourceOver,
                fraction: 1
            )
        } ?? filtered
    }

    static func rendered(size outputSize: CGSize, actions: (CGRect) -> Void) -> NSImage? {
        guard outputSize.width > 0, outputSize.height > 0 else { return nil }
        let image = NSImage(size: outputSize)
        image.lockFocus()
        let rect = CGRect(origin: .zero, size: outputSize)
        let context = NSGraphicsContext.current
        context?.saveGraphicsState()
        NSColor.clear.setFill()
        rect.fill()
        actions(rect)
        context?.restoreGraphicsState()
        image.unlockFocus()
        return image
    }

    static func transparent(size outputSize: CGSize) -> NSImage {
        rendered(size: outputSize) { rect in
            NSColor.clear.setFill()
            rect.fill()
        } ?? NSImage(size: outputSize)
    }

    static func opaqueMask(size outputSize: CGSize) -> NSImage {
        rendered(size: outputSize) { rect in
            NSColor.white.setFill()
            rect.fill()
        } ?? NSImage(size: outputSize)
    }

    func thumbnailImage(targetSize: CGSize) -> NSImage {
        let scale = min(targetSize.width / max(size.width, 1), targetSize.height / max(size.height, 1))
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        return Self.rendered(size: targetSize) { rect in
            NSColor.clear.setFill()
            rect.fill()
            draw(
                in: CGRect(
                    x: (targetSize.width - drawSize.width) / 2,
                    y: (targetSize.height - drawSize.height) / 2,
                    width: drawSize.width,
                    height: drawSize.height
                ),
                from: CGRect(origin: .zero, size: size),
                operation: .sourceOver,
                fraction: 1
            )
        } ?? NSImage(size: targetSize)
    }

    private func rendered(size outputSize: CGSize, actions: (CGRect) -> Void) -> NSImage? {
        Self.rendered(size: outputSize, actions: actions)
    }
}
