//
//  ImageEditorLayerMaskCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

fileprivate enum ImageEditorLayerMaskSelectionCombination {
    case reveal
    case hide
    case intersect

    var historyKey: String {
        switch self {
        case .reveal:
            "imageEditor.history.layerMaskRevealSelection"
        case .hide:
            "imageEditor.history.layerMaskHideSelectionFromMask"
        case .intersect:
            "imageEditor.history.layerMaskIntersectSelection"
        }
    }

    var statusKey: String {
        switch self {
        case .reveal:
            "imageEditor.status.layerMaskRevealSelection"
        case .hide:
            "imageEditor.status.layerMaskHideSelectionFromMask"
        case .intersect:
            "imageEditor.status.layerMaskIntersectSelection"
        }
    }
}

@MainActor
extension ImageEditorViewModel {
    var canCreateLayerMaskFromSelection: Bool {
        guard selectedLayerCount == 1,
              hasSelection,
              let layer = document.selectedLayer
        else { return false }
        return !document.isEffectivelyLocked(layer) && layer.mask == nil
    }

    var canCreateVectorMaskFromSelection: Bool {
        guard selectedLayerCount == 1,
              let selection = document.selection,
              !selection.isInverted,
              let layer = document.selectedLayer
        else { return false }
        return !document.isEffectivelyLocked(layer)
            && layer.vectorMask == nil
            && selection.points.count >= 3
    }

    var canCopyLayerMaskToSelectedLayers: Bool {
        guard let sourceID = document.selectedLayerID,
              document.layers.contains(where: { $0.id == sourceID && $0.mask != nil })
        else { return false }
        return !layerMaskCopyTargetIndices(sourceID: sourceID).isEmpty
    }

    var canCopyVectorMaskToSelectedLayers: Bool {
        guard let sourceID = document.selectedLayerID,
              document.layers.contains(where: { $0.id == sourceID && $0.vectorMask != nil })
        else { return false }
        return !layerMaskCopyTargetIndices(sourceID: sourceID).isEmpty
    }

    var canApplyLayerMask: Bool {
        !layerMaskApplyIndices().isEmpty
    }

    var canInvertLayerMask: Bool {
        !layerMaskInvertIndices().isEmpty
    }

    var canToggleLayerMaskEnabled: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return !document.isEffectivelyLocked(layer) && layer.mask != nil
    }

    var canToggleLayerMaskLinked: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return !document.isEffectivelyLocked(layer) && (layer.mask != nil || layer.vectorMask != nil)
    }

    var canToggleVectorMaskEnabled: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return !document.isEffectivelyLocked(layer) && layer.vectorMask != nil
    }

    var canDeleteVectorMask: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return !document.isEffectivelyLocked(layer) && layer.vectorMask != nil
    }

    var canRasterizeSelectedVectorMask: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              let vectorMask = layer.vectorMask
        else { return false }
        return !document.isEffectivelyLocked(layer)
            && layer.isVectorMaskEnabled
            && vectorMask.kind == .path
            && vectorMask.isPathClosed
            && vectorMask.editablePathAnchors.count >= 3
    }

    var canLoadSelectionFromLayerMask: Bool {
        selectedLayerCount == 1 && document.selectedLayer?.mask != nil
    }

    var canCombineLayerMaskWithSelection: Bool {
        guard selectedLayerCount == 1,
              hasSelection,
              let layer = document.selectedLayer
        else { return false }
        return !document.isEffectivelyLocked(layer) && layer.mask != nil
    }

    var canLoadSelectionFromVectorMask: Bool {
        guard selectedLayerCount == 1,
              let vectorMask = document.selectedLayer?.vectorMask
        else { return false }
        return vectorMask.kind == .path
            && vectorMask.isPathClosed
            && vectorMask.editablePathAnchors.count >= 3
    }

    func addLayerMaskFromSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard canCreateLayerMaskFromSelection,
              let index = document.selectedLayerIndex,
              let mask = selectionMaskForLayer(selection, layer: document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].mask = mask
        document.layers[index].isMaskEnabled = true
        document.layers[index].isMaskLinked = true
        document.layers[index].maskDensity = 1
        document.layers[index].maskFeather = 0
        isEditingLayerMask = true
        appendHistory(L10n.text("imageEditor.history.layerMaskFromSelection"))
        statusText = L10n.text("imageEditor.status.layerMaskFromSelection")
    }

    func addVectorMaskFromSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard canCreateVectorMaskFromSelection,
              let index = document.selectedLayerIndex,
              let vectorMask = vectorMaskContent(from: selection, layer: document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.vectorMaskFromSelectionFailed")
            return
        }

        pushUndo()
        document.layers[index].vectorMask = vectorMask
        document.layers[index].isVectorMaskEnabled = true
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.vectorMaskFromSelection"))
        statusText = L10n.text("imageEditor.status.vectorMaskFromSelection")
    }

    func addLayerMaskHidingAll() {
        guard canAddLayerMask,
              let index = document.selectedLayerIndex
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        pushUndo()
        document.layers[index].mask = NSImage.transparent(size: maskSize(for: document.layers[index]))
        document.layers[index].isMaskEnabled = true
        document.layers[index].isMaskLinked = true
        document.layers[index].isVectorMaskEnabled = true
        document.layers[index].maskDensity = 1
        document.layers[index].maskFeather = 0
        isEditingLayerMask = true
        appendHistory(L10n.text("imageEditor.history.layerMaskHideAll"))
        statusText = L10n.text("imageEditor.status.layerMaskHideAll")
    }

    func addLayerMaskHidingSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard canCreateLayerMaskFromSelection,
              let index = document.selectedLayerIndex,
              let selectionMask = selectionMaskForLayer(selection, layer: document.layers[index]),
              let invertedMask = selectionMask.invertedAlphaMask()
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].mask = invertedMask
        document.layers[index].isMaskEnabled = true
        document.layers[index].isMaskLinked = true
        document.layers[index].maskDensity = 1
        document.layers[index].maskFeather = 0
        isEditingLayerMask = true
        appendHistory(L10n.text("imageEditor.history.layerMaskHideSelection"))
        statusText = L10n.text("imageEditor.status.layerMaskHideSelection")
    }

    func copyLayerMaskToSelectedLayers() {
        guard canCopyLayerMaskToSelectedLayers,
              let sourceID = document.selectedLayerID,
              let sourceIndex = document.layers.firstIndex(where: { $0.id == sourceID }),
              let sourceMask = document.layers[sourceIndex].mask
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let targetIndices = layerMaskCopyTargetIndices(sourceID: sourceID)
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let sourceLayer = document.layers[sourceIndex]
        pushUndo()
        for index in targetIndices {
            let targetSize = maskSize(for: document.layers[index])
            document.layers[index].mask = (sourceMask.resized(to: targetSize) ?? sourceMask).normalizedBitmapImage()
            document.layers[index].isMaskEnabled = sourceLayer.isMaskEnabled
            document.layers[index].isMaskLinked = sourceLayer.isMaskLinked
            document.layers[index].maskDensity = sourceLayer.maskDensity
            document.layers[index].maskFeather = sourceLayer.maskFeather
        }
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMaskCopy"))
        statusText = L10n.format("imageEditor.status.layerMaskCopied", targetIndices.count)
    }

    func copyVectorMaskToSelectedLayers() {
        guard canCopyVectorMaskToSelectedLayers,
              let sourceID = document.selectedLayerID,
              let sourceIndex = document.layers.firstIndex(where: { $0.id == sourceID }),
              let sourceMask = document.layers[sourceIndex].vectorMask
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let sourceLayer = document.layers[sourceIndex]
        let sourceSize = maskSize(for: sourceLayer)
        let targetIndices = layerMaskCopyTargetIndices(sourceID: sourceID)
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in targetIndices {
            let targetSize = maskSize(for: document.layers[index])
            document.layers[index].vectorMask = scaledVectorMask(sourceMask, from: sourceSize, to: targetSize)
            document.layers[index].isVectorMaskEnabled = sourceLayer.isVectorMaskEnabled
            document.layers[index].isMaskLinked = sourceLayer.isMaskLinked
        }
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.vectorMaskCopy"))
        statusText = L10n.format("imageEditor.status.vectorMaskCopied", targetIndices.count)
    }

    func rasterizeSelectedVectorMask() {
        guard canRasterizeSelectedVectorMask,
              let index = document.selectedLayerIndex,
              let vectorMask = document.layers[index].vectorMask,
              let vectorMaskImage = renderedVectorMask(vectorMask, layer: document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.vectorMaskRasterizeFailed")
            return
        }

        let layer = document.layers[index]
        let outputMask = layer.effectiveMask ?? vectorMaskImage

        pushUndo()
        document.layers[index].mask = outputMask.normalizedBitmapImage()
        document.layers[index].vectorMask = nil
        document.layers[index].isMaskEnabled = true
        document.layers[index].isMaskLinked = true
        document.layers[index].isVectorMaskEnabled = true
        document.layers[index].maskDensity = 1
        document.layers[index].maskFeather = 0
        isEditingLayerMask = true
        appendHistory(L10n.text("imageEditor.history.vectorMaskRasterize"))
        statusText = L10n.text("imageEditor.status.vectorMaskRasterized")
    }

    func applyLayerMask() {
        let indices = layerMaskApplyIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in indices {
            applyLayerMask(at: index)
        }
        isEditingLayerMask = false

        if indices.count == 1 {
            appendHistory(L10n.text("imageEditor.history.layerMaskApply"))
            statusText = L10n.text("imageEditor.status.layerMaskApplied")
        } else {
            appendHistory(L10n.text("imageEditor.history.layerMaskApplySelected"))
            statusText = L10n.format("imageEditor.status.layerMaskAppliedSelected", indices.count)
        }
    }

    func invertLayerMask() {
        let indices = layerMaskInvertIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in indices {
            guard let mask = document.layers[index].mask,
                  let inverted = mask.invertedAlphaMask()
            else { continue }
            document.layers[index].mask = inverted
        }
        isEditingLayerMask = true

        if indices.count == 1 {
            appendHistory(L10n.text("imageEditor.history.layerMaskInvert"))
            statusText = L10n.text("imageEditor.status.layerMaskInverted")
        } else {
            appendHistory(L10n.text("imageEditor.history.layerMaskInvertSelected"))
            statusText = L10n.format("imageEditor.status.layerMaskInvertedSelected", indices.count)
        }
    }

    func revealSelectionOnLayerMask() {
        combineLayerMaskWithSelection(.reveal)
    }

    func hideSelectionOnLayerMask() {
        combineLayerMaskWithSelection(.hide)
    }

    func intersectLayerMaskWithSelection() {
        combineLayerMaskWithSelection(.intersect)
    }

    func loadSelectionFromLayerMask() {
        guard canLoadSelectionFromLayerMask,
              let layer = document.selectedLayer,
              let mask = layer.mask,
              let selection = selectionFromLayerMask(mask, layer: layer)
        else {
            statusText = L10n.text("imageEditor.status.layerMaskSelectionFailed")
            return
        }

        applyMaskSelection(selection, historyKey: "imageEditor.history.selectionFromLayerMask")
        if document.selection != nil {
            statusText = L10n.text("imageEditor.status.layerMaskSelection")
        }
    }

    func loadSelectionFromVectorMask() {
        guard canLoadSelectionFromVectorMask,
              let layer = document.selectedLayer,
              let vectorMask = layer.vectorMask,
              let selection = selectionFromVectorMask(vectorMask, layer: layer)
        else {
            statusText = L10n.text("imageEditor.status.vectorMaskSelectionFailed")
            return
        }

        applyMaskSelection(selection, historyKey: "imageEditor.history.selectionFromVectorMask")
        if document.selection != nil {
            statusText = L10n.text("imageEditor.status.vectorMaskSelection")
        }
    }

    func toggleLayerMaskEnabled() {
        guard canToggleLayerMaskEnabled,
              let index = document.selectedLayerIndex
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].isMaskEnabled.toggle()
        appendHistory(
            document.layers[index].isMaskEnabled
                ? L10n.text("imageEditor.history.layerMaskEnable")
                : L10n.text("imageEditor.history.layerMaskDisable")
        )
        statusText = document.layers[index].isMaskEnabled
            ? L10n.text("imageEditor.status.layerMaskEnabled")
            : L10n.text("imageEditor.status.layerMaskDisabled")
    }

    func toggleLayerMaskLinked() {
        guard canToggleLayerMaskLinked,
              let index = document.selectedLayerIndex
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].isMaskLinked.toggle()
        appendHistory(
            document.layers[index].isMaskLinked
                ? L10n.text("imageEditor.history.layerMaskLink")
                : L10n.text("imageEditor.history.layerMaskUnlink")
        )
        statusText = document.layers[index].isMaskLinked
            ? L10n.text("imageEditor.status.layerMaskLinked")
            : L10n.text("imageEditor.status.layerMaskUnlinked")
    }

    func toggleVectorMaskEnabled() {
        guard canToggleVectorMaskEnabled,
              let index = document.selectedLayerIndex
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].isVectorMaskEnabled.toggle()
        appendHistory(
            document.layers[index].isVectorMaskEnabled
                ? L10n.text("imageEditor.history.vectorMaskEnable")
                : L10n.text("imageEditor.history.vectorMaskDisable")
        )
        statusText = document.layers[index].isVectorMaskEnabled
            ? L10n.text("imageEditor.status.vectorMaskEnabled")
            : L10n.text("imageEditor.status.vectorMaskDisabled")
    }

    func deleteVectorMask() {
        guard canDeleteVectorMask,
              let index = document.selectedLayerIndex
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].vectorMask = nil
        document.layers[index].isVectorMaskEnabled = true
        appendHistory(L10n.text("imageEditor.history.vectorMaskDelete"))
        statusText = L10n.text("imageEditor.status.vectorMaskDeleted")
    }

    private func layerMaskApplyIndices() -> [Int] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            selectedIDs.contains(document.layers[index].id)
                && canApplyMask(to: document.layers[index])
        }
    }

    private func layerMaskInvertIndices() -> [Int] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
                && layer.mask?.invertedAlphaMask() != nil
        }
    }

    private func canApplyMask(to layer: ImageEditorLayer) -> Bool {
        !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && !document.isEffectivelyPixelsLocked(layer)
            && (layer.mask != nil || layer.vectorMask != nil)
    }

    private func applyLayerMask(at index: Int) {
        let sourceImage = document.layers[index].contentImage
        let output = document.layers[index].effectiveMask.flatMap { sourceImage.applyingAlphaMask($0) } ?? sourceImage

        document.layers[index].image = output.normalizedBitmapImage()
        document.layers[index].mask = nil
        document.layers[index].vectorMask = nil
        document.layers[index].isMaskEnabled = true
        document.layers[index].isMaskLinked = true
        document.layers[index].isVectorMaskEnabled = true
        document.layers[index].maskDensity = 1
        document.layers[index].maskFeather = 0
        if document.layers[index].isText {
            document.layers[index].kind = .pixel
        }
    }

    private func combineLayerMaskWithSelection(_ combination: ImageEditorLayerMaskSelectionCombination) {
        guard canCombineLayerMaskWithSelection,
              let selection = document.selection,
              let index = document.selectedLayerIndex,
              let mask = document.layers[index].mask,
              let selectionMask = selectionMaskForLayer(selection, layer: document.layers[index]),
              let output = mask.combinedAlphaMask(with: selectionMask, combination: combination)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].mask = output
        isEditingLayerMask = true
        appendHistory(L10n.text(combination.historyKey))
        statusText = L10n.text(combination.statusKey)
    }

    private func selectionMaskForLayer(_ selection: ImageEditorSelection, layer: ImageEditorLayer) -> NSImage? {
        if layer.isGroup {
            return canvasSelectionMask(for: selection)
        }

        guard layer.image.size.width > 0,
              layer.image.size.height > 0,
              layer.frame.width > 0,
              layer.frame.height > 0,
              let canvasMask = canvasSelectionMask(for: selection)
        else { return nil }

        return NSImage.rendered(size: layer.image.size) { _ in
            canvasMask.draw(
                in: CGRect(origin: .zero, size: layer.image.size),
                from: layer.frame,
                operation: .copy,
                fraction: 1
            )
        }
    }

    private func canvasSelectionMask(for selection: ImageEditorSelection) -> NSImage? {
        if let rasterMask = selection.rasterMask,
           let image = NSImage.selectionMaskImage(
            rasterMask,
            inverted: selection.isInverted,
            targetSize: document.canvasSize
           ) {
            guard feather > 0 else { return image }
            return image.blurred(radius: feather) ?? image
        }

        let hardMask = NSImage.rendered(size: document.canvasSize) { rect in
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

    private func vectorMaskContent(from selection: ImageEditorSelection, layer: ImageEditorLayer) -> ImageEditorShapeContent? {
        guard !selection.isInverted,
              selection.points.count >= 3
        else { return nil }
        let anchors = selection.points.map { point in
            ImageEditorPathAnchor(point: canvasToMaskPoint(point, layer: layer))
        }
        return ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: anchors.map(\.point),
            pathAnchors: anchors,
            isPathClosed: true
        ).normalized(size: maskSize(for: layer))
    }

    private func canvasToMaskPoint(_ point: CGPoint, layer: ImageEditorLayer) -> CGPoint {
        guard !layer.isGroup else { return point }
        guard layer.frame.width != 0,
              layer.frame.height != 0,
              layer.image.size.width > 0,
              layer.image.size.height > 0
        else { return .zero }
        return CGPoint(
            x: (point.x - layer.frame.minX) / layer.frame.width * layer.image.size.width,
            y: (point.y - layer.frame.minY) / layer.frame.height * layer.image.size.height
        )
    }

    private func applyMaskSelection(_ selection: ImageEditorSelection, historyKey: String) {
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
        let appliedHistoryKey = selectionMode == .replace ? historyKey : selectionMode.historyKey
        appendHistory(L10n.text(appliedHistoryKey))
        if nextSelection == nil {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
        }
    }

    private func layerMaskCopyTargetIndices(sourceID: UUID) -> [Int] {
        let targetIDs = document.selectedLayerIDs.subtracting([sourceID])
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return targetIDs.contains(layer.id) && !document.isEffectivelyLocked(layer)
        }
    }

    private func scaledVectorMask(
        _ vectorMask: ImageEditorShapeContent,
        from sourceSize: CGSize,
        to targetSize: CGSize
    ) -> ImageEditorShapeContent {
        let scaleX = max(1, targetSize.width) / max(1, sourceSize.width)
        let scaleY = max(1, targetSize.height) / max(1, sourceSize.height)

        func scalePoint(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }

        var output = vectorMask
        output.pathPoints = vectorMask.pathPoints.map(scalePoint)
        output.pathAnchors = vectorMask.pathAnchors.map { anchor in
            ImageEditorPathAnchor(
                point: scalePoint(anchor.point),
                inControl: anchor.inControl.map(scalePoint),
                outControl: anchor.outControl.map(scalePoint)
            )
        }
        output.pathSubpaths = vectorMask.pathSubpaths.map { subpath in
            subpath.map { anchor in
                ImageEditorPathAnchor(
                    point: scalePoint(anchor.point),
                    inControl: anchor.inControl.map(scalePoint),
                    outControl: anchor.outControl.map(scalePoint)
                )
            }
        }
        return output.normalized(size: targetSize)
    }

    private func selectionFromLayerMask(_ mask: NSImage, layer: ImageEditorLayer) -> ImageEditorSelection? {
        guard let canvasMask = canvasMaskImage(fromLayerMask: mask, layer: layer),
              let selectionMask = maskSelection(fromCanvasMask: canvasMask),
              let bounds = selectionMask.selectedBounds(in: document.canvasSize)
        else { return nil }
        return .raster(mask: selectionMask, bounds: bounds)
    }

    private func selectionFromVectorMask(_ vectorMask: ImageEditorShapeContent, layer: ImageEditorLayer) -> ImageEditorSelection? {
        guard let maskImage = renderedVectorMask(vectorMask, layer: layer) else { return nil }
        return selectionFromLayerMask(maskImage, layer: layer)
    }

    private func renderedVectorMask(_ vectorMask: ImageEditorShapeContent, layer: ImageEditorLayer) -> NSImage? {
        guard vectorMask.kind == .path,
              vectorMask.isPathClosed,
              vectorMask.editablePathAnchors.count >= 3
        else { return nil }
        return NSImage.rendered(size: maskSize(for: layer)) { _ in
            NSColor.white.setFill()
            vectorMask.normalized(size: maskSize(for: layer)).pathBezierPath().fill()
        }
    }

    private func canvasMaskImage(fromLayerMask mask: NSImage, layer: ImageEditorLayer) -> NSImage? {
        if layer.isGroup {
            return mask.resized(to: document.canvasSize)
        }

        guard layer.image.size.width > 0,
              layer.image.size.height > 0,
              layer.frame.width > 0,
              layer.frame.height > 0
        else { return nil }

        return NSImage.rendered(size: document.canvasSize) { _ in
            NSColor.clear.setFill()
            CGRect(origin: .zero, size: document.canvasSize).fill()
            mask.draw(
                in: layer.frame,
                from: CGRect(origin: .zero, size: mask.size),
                operation: .copy,
                fraction: 1
            )
        }
    }

    private func maskSelection(fromCanvasMask canvasMask: NSImage) -> ImageEditorSelectionMask? {
        canvasMask.alphaMask(
            width: max(1, Int(document.canvasSize.width.rounded())),
            height: max(1, Int(document.canvasSize.height.rounded()))
        )
    }
}

extension NSImage {
    func offsetMask(by delta: CGSize) -> NSImage? {
        NSImage.rendered(size: size) { rect in
            NSColor.clear.setFill()
            rect.fill()
            draw(
                in: rect.offsetBy(dx: delta.width, dy: delta.height),
                from: CGRect(origin: .zero, size: size),
                operation: .sourceOver,
                fraction: 1
            )
        }
    }
}

extension NSImage {
    func applyingAlphaMask(_ mask: NSImage) -> NSImage? {
        NSImage.rendered(size: size) { _ in
            draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: size),
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
    }

    func invertedAlphaMask() -> NSImage? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
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

        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                alpha[y * width + x] = UInt8.max - pixels[offset + 3]
            }
        }
        return NSImage.alphaMaskImage(width: width, height: height, alpha: alpha)
    }

    fileprivate func combinedAlphaMask(
        with selectionMask: NSImage,
        combination: ImageEditorLayerMaskSelectionCombination
    ) -> NSImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard let currentMask = alphaMask(width: width, height: height),
              let selectedMask = selectionMask.alphaMask(width: width, height: height),
              currentMask.alpha.count == selectedMask.alpha.count
        else { return nil }

        var output = [UInt8](repeating: 0, count: currentMask.alpha.count)
        for index in output.indices {
            let current = currentMask.alpha[index]
            let selected = selectedMask.alpha[index]
            switch combination {
            case .reveal:
                output[index] = max(current, selected)
            case .hide:
                output[index] = min(current, UInt8.max - selected)
            case .intersect:
                output[index] = min(current, selected)
            }
        }

        return NSImage.alphaMaskImage(width: width, height: height, alpha: output)
    }
}
