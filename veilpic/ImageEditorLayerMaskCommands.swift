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

    var selectedHistoryKey: String {
        switch self {
        case .reveal:
            "imageEditor.history.layerMaskRevealSelectionSelected"
        case .hide:
            "imageEditor.history.layerMaskHideSelectionFromMaskSelected"
        case .intersect:
            "imageEditor.history.layerMaskIntersectSelectionSelected"
        }
    }

    var selectedStatusKey: String {
        switch self {
        case .reveal:
            "imageEditor.status.layerMaskRevealSelectionSelected"
        case .hide:
            "imageEditor.status.layerMaskHideSelectionFromMaskSelected"
        case .intersect:
            "imageEditor.status.layerMaskIntersectSelectionSelected"
        }
    }
}

@MainActor
extension ImageEditorViewModel {
    var canCreateLayerMaskFromSelection: Bool {
        guard let selection = document.selection else { return false }
        return !layerMaskCreationOperations(selection, hidingSelection: false).isEmpty
    }

    var canCreateVectorMaskFromSelection: Bool {
        guard let selection = document.selection else { return false }
        return !vectorMaskCreationOperations(selection).isEmpty
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
        !layerMaskToggleEnabledIndices().isEmpty
    }

    var canToggleLayerMaskLinked: Bool {
        !layerMaskToggleLinkedIndices().isEmpty
    }

    var canToggleVectorMaskEnabled: Bool {
        !vectorMaskToggleEnabledIndices().isEmpty
    }

    var canDeleteVectorMask: Bool {
        !vectorMaskDeleteIndices().isEmpty
    }

    var canRasterizeSelectedVectorMask: Bool {
        !vectorMaskRasterizeOperations().isEmpty
    }

    var canLoadSelectionFromLayerMask: Bool {
        !layerMaskSelections().isEmpty
    }

    var canCombineLayerMaskWithSelection: Bool {
        guard let selection = document.selection else { return false }
        return !layerMaskSelectionCombinationOperations(selection, combination: .reveal).isEmpty
    }

    var canLoadSelectionFromVectorMask: Bool {
        !vectorMaskSelections().isEmpty
    }

    func addLayerMaskFromSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let operations = layerMaskCreationOperations(selection, hidingSelection: false)
        guard !operations.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for operation in operations {
            document.layers[operation.index].mask = operation.mask
            document.layers[operation.index].isMaskEnabled = true
            document.layers[operation.index].isMaskLinked = true
            document.layers[operation.index].maskDensity = 1
            document.layers[operation.index].maskFeather = 0
        }
        isEditingLayerMask = true

        if operations.count == 1 {
            appendHistory(L10n.text("imageEditor.history.layerMaskFromSelection"))
            statusText = L10n.text("imageEditor.status.layerMaskFromSelection")
        } else {
            appendHistory(L10n.text("imageEditor.history.layerMaskFromSelectionSelected"))
            statusText = L10n.format("imageEditor.status.layerMaskFromSelectionSelected", operations.count)
        }
    }

    func addVectorMaskFromSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let operations = vectorMaskCreationOperations(selection)
        guard !operations.isEmpty else {
            statusText = L10n.text("imageEditor.status.vectorMaskFromSelectionFailed")
            return
        }

        pushUndo()
        for operation in operations {
            document.layers[operation.index].vectorMask = operation.vectorMask
            document.layers[operation.index].isVectorMaskEnabled = true
        }
        isEditingLayerMask = false

        if operations.count == 1 {
            appendHistory(L10n.text("imageEditor.history.vectorMaskFromSelection"))
            statusText = L10n.text("imageEditor.status.vectorMaskFromSelection")
        } else {
            appendHistory(L10n.text("imageEditor.history.vectorMaskFromSelectionSelected"))
            statusText = L10n.format("imageEditor.status.vectorMaskFromSelectionSelected", operations.count)
        }
    }

    func addLayerMaskHidingAll() {
        let indices = layerMaskAddIndices
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        pushUndo()
        for index in indices {
            document.layers[index].mask = NSImage.transparent(size: maskSize(for: document.layers[index]))
            document.layers[index].isMaskEnabled = true
            document.layers[index].isMaskLinked = true
            document.layers[index].isVectorMaskEnabled = true
            document.layers[index].maskDensity = 1
            document.layers[index].maskFeather = 0
        }
        isEditingLayerMask = true

        if indices.count == 1 {
            appendHistory(L10n.text("imageEditor.history.layerMaskHideAll"))
            statusText = L10n.text("imageEditor.status.layerMaskHideAll")
        } else {
            appendHistory(L10n.text("imageEditor.history.layerMaskHideAllSelected"))
            statusText = L10n.format("imageEditor.status.layerMaskHideAllSelected", indices.count)
        }
    }

    func addLayerMaskHidingSelection() {
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        let operations = layerMaskCreationOperations(selection, hidingSelection: true)
        guard !operations.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for operation in operations {
            document.layers[operation.index].mask = operation.mask
            document.layers[operation.index].isMaskEnabled = true
            document.layers[operation.index].isMaskLinked = true
            document.layers[operation.index].maskDensity = 1
            document.layers[operation.index].maskFeather = 0
        }
        isEditingLayerMask = true

        if operations.count == 1 {
            appendHistory(L10n.text("imageEditor.history.layerMaskHideSelection"))
            statusText = L10n.text("imageEditor.status.layerMaskHideSelection")
        } else {
            appendHistory(L10n.text("imageEditor.history.layerMaskHideSelectionSelected"))
            statusText = L10n.format("imageEditor.status.layerMaskHideSelectionSelected", operations.count)
        }
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
        let operations = vectorMaskRasterizeOperations()
        guard !operations.isEmpty else {
            statusText = L10n.text("imageEditor.status.vectorMaskRasterizeFailed")
            return
        }

        pushUndo()
        for operation in operations {
            document.layers[operation.index].mask = operation.mask
            document.layers[operation.index].vectorMask = nil
            document.layers[operation.index].isMaskEnabled = true
            document.layers[operation.index].isMaskLinked = true
            document.layers[operation.index].isVectorMaskEnabled = true
            document.layers[operation.index].maskDensity = 1
            document.layers[operation.index].maskFeather = 0
        }
        isEditingLayerMask = true

        if operations.count == 1 {
            appendHistory(L10n.text("imageEditor.history.vectorMaskRasterize"))
            statusText = L10n.text("imageEditor.status.vectorMaskRasterized")
        } else {
            appendHistory(L10n.text("imageEditor.history.vectorMaskRasterizeSelected"))
            statusText = L10n.format("imageEditor.status.vectorMaskRasterizedSelected", operations.count)
        }
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
        let selections = layerMaskSelections()
        guard let selection = combinedMaskSelections(selections) else {
            statusText = L10n.text("imageEditor.status.layerMaskSelectionFailed")
            return
        }

        let historyKey = selections.count == 1
            ? "imageEditor.history.selectionFromLayerMask"
            : "imageEditor.history.selectionFromSelectedLayerMasks"
        applyMaskSelection(selection, historyKey: historyKey)
        if document.selection != nil {
            statusText = selections.count == 1
                ? L10n.text("imageEditor.status.layerMaskSelection")
                : L10n.format("imageEditor.status.layerMaskSelectionSelected", selections.count)
        }
    }

    func loadSelectionFromVectorMask() {
        let selections = vectorMaskSelections()
        guard let selection = combinedMaskSelections(selections) else {
            statusText = L10n.text("imageEditor.status.vectorMaskSelectionFailed")
            return
        }

        let historyKey = selections.count == 1
            ? "imageEditor.history.selectionFromVectorMask"
            : "imageEditor.history.selectionFromSelectedVectorMasks"
        applyMaskSelection(selection, historyKey: historyKey)
        if document.selection != nil {
            statusText = selections.count == 1
                ? L10n.text("imageEditor.status.vectorMaskSelection")
                : L10n.format("imageEditor.status.vectorMaskSelectionSelected", selections.count)
        }
    }

    func toggleLayerMaskEnabled() {
        let indices = layerMaskToggleEnabledIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let enablesMasks = !indices.contains { document.layers[$0].isMaskEnabled }
        let changedIndices = indices.filter { document.layers[$0].isMaskEnabled != enablesMasks }
        pushUndo()
        for index in changedIndices {
            document.layers[index].isMaskEnabled = enablesMasks
        }

        if indices.count == 1 {
            appendHistory(
                enablesMasks
                    ? L10n.text("imageEditor.history.layerMaskEnable")
                    : L10n.text("imageEditor.history.layerMaskDisable")
            )
            statusText = enablesMasks
                ? L10n.text("imageEditor.status.layerMaskEnabled")
                : L10n.text("imageEditor.status.layerMaskDisabled")
        } else {
            appendHistory(
                enablesMasks
                    ? L10n.text("imageEditor.history.layerMaskEnableSelected")
                    : L10n.text("imageEditor.history.layerMaskDisableSelected")
            )
            statusText = enablesMasks
                ? L10n.format("imageEditor.status.layerMaskEnabledSelected", changedIndices.count)
                : L10n.format("imageEditor.status.layerMaskDisabledSelected", changedIndices.count)
        }
    }

    func toggleLayerMaskLinked() {
        let indices = layerMaskToggleLinkedIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let linksMasks = !indices.contains { document.layers[$0].isMaskLinked }
        let changedIndices = indices.filter { document.layers[$0].isMaskLinked != linksMasks }
        pushUndo()
        for index in changedIndices {
            document.layers[index].isMaskLinked = linksMasks
        }

        if indices.count == 1 {
            appendHistory(
                linksMasks
                    ? L10n.text("imageEditor.history.layerMaskLink")
                    : L10n.text("imageEditor.history.layerMaskUnlink")
            )
            statusText = linksMasks
                ? L10n.text("imageEditor.status.layerMaskLinked")
                : L10n.text("imageEditor.status.layerMaskUnlinked")
        } else {
            appendHistory(
                linksMasks
                    ? L10n.text("imageEditor.history.layerMaskLinkSelected")
                    : L10n.text("imageEditor.history.layerMaskUnlinkSelected")
            )
            statusText = linksMasks
                ? L10n.format("imageEditor.status.layerMaskLinkedSelected", changedIndices.count)
                : L10n.format("imageEditor.status.layerMaskUnlinkedSelected", changedIndices.count)
        }
    }

    func toggleVectorMaskEnabled() {
        let indices = vectorMaskToggleEnabledIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let enablesMasks = !indices.contains { document.layers[$0].isVectorMaskEnabled }
        let changedIndices = indices.filter { document.layers[$0].isVectorMaskEnabled != enablesMasks }
        pushUndo()
        for index in changedIndices {
            document.layers[index].isVectorMaskEnabled = enablesMasks
        }

        if indices.count == 1 {
            appendHistory(
                enablesMasks
                    ? L10n.text("imageEditor.history.vectorMaskEnable")
                    : L10n.text("imageEditor.history.vectorMaskDisable")
            )
            statusText = enablesMasks
                ? L10n.text("imageEditor.status.vectorMaskEnabled")
                : L10n.text("imageEditor.status.vectorMaskDisabled")
        } else {
            appendHistory(
                enablesMasks
                    ? L10n.text("imageEditor.history.vectorMaskEnableSelected")
                    : L10n.text("imageEditor.history.vectorMaskDisableSelected")
            )
            statusText = enablesMasks
                ? L10n.format("imageEditor.status.vectorMaskEnabledSelected", changedIndices.count)
                : L10n.format("imageEditor.status.vectorMaskDisabledSelected", changedIndices.count)
        }
    }

    func deleteVectorMask() {
        let indices = vectorMaskDeleteIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in indices {
            document.layers[index].vectorMask = nil
            document.layers[index].isVectorMaskEnabled = true
        }

        if indices.count == 1 {
            appendHistory(L10n.text("imageEditor.history.vectorMaskDelete"))
            statusText = L10n.text("imageEditor.status.vectorMaskDeleted")
        } else {
            appendHistory(L10n.text("imageEditor.history.vectorMaskDeleteSelected"))
            statusText = L10n.format("imageEditor.status.vectorMaskDeletedSelected", indices.count)
        }
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

    private func layerMaskToggleEnabledIndices() -> [Int] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
                && layer.mask != nil
        }
    }

    private func layerMaskToggleLinkedIndices() -> [Int] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
                && (layer.mask != nil || layer.vectorMask != nil)
        }
    }

    private func vectorMaskToggleEnabledIndices() -> [Int] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
                && layer.vectorMask != nil
        }
    }

    private func vectorMaskDeleteIndices() -> [Int] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
                && layer.vectorMask != nil
        }
    }

    private func vectorMaskRasterizeOperations() -> [(index: Int, mask: NSImage)] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.compactMap { index in
            let layer = document.layers[index]
            guard selectedIDs.contains(layer.id),
                  canRasterizeVectorMask(layer),
                  let vectorMask = layer.vectorMask,
                  let vectorMaskImage = renderedVectorMask(vectorMask, layer: layer)
            else { return nil }
            return (index, (layer.effectiveMask ?? vectorMaskImage).normalizedBitmapImage())
        }
    }

    private func canRasterizeVectorMask(_ layer: ImageEditorLayer) -> Bool {
        guard let vectorMask = layer.vectorMask else { return false }
        return !document.isEffectivelyLocked(layer)
            && layer.isVectorMaskEnabled
            && vectorMask.kind == .path
            && vectorMask.isPathClosed
            && vectorMask.editablePathAnchors.count >= 3
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
        guard let selection = document.selection else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let operations = layerMaskSelectionCombinationOperations(selection, combination: combination)
        guard !operations.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for operation in operations {
            document.layers[operation.index].mask = operation.mask
        }
        isEditingLayerMask = true

        if operations.count == 1 {
            appendHistory(L10n.text(combination.historyKey))
            statusText = L10n.text(combination.statusKey)
        } else {
            appendHistory(L10n.text(combination.selectedHistoryKey))
            statusText = L10n.format(combination.selectedStatusKey, operations.count)
        }
    }

    private func layerMaskSelectionCombinationOperations(
        _ selection: ImageEditorSelection,
        combination: ImageEditorLayerMaskSelectionCombination
    ) -> [(index: Int, mask: NSImage)] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.compactMap { index in
            let layer = document.layers[index]
            guard selectedIDs.contains(layer.id),
                  !document.isEffectivelyLocked(layer),
                  let mask = layer.mask,
                  let selectionMask = selectionMaskForLayer(selection, layer: layer),
                  let output = mask.combinedAlphaMask(with: selectionMask, combination: combination)
            else { return nil }
            return (index, output)
        }
    }

    private func layerMaskCreationOperations(
        _ selection: ImageEditorSelection,
        hidingSelection: Bool
    ) -> [(index: Int, mask: NSImage)] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.compactMap { index in
            let layer = document.layers[index]
            guard selectedIDs.contains(layer.id),
                  !document.isEffectivelyLocked(layer),
                  layer.mask == nil,
                  let selectionMask = selectionMaskForLayer(selection, layer: layer)
            else { return nil }
            let mask = hidingSelection ? selectionMask.invertedAlphaMask() : selectionMask
            guard let mask else { return nil }
            return (index, mask)
        }
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

    private func layerMaskSelections() -> [ImageEditorSelection] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.compactMap { layer in
            guard selectedIDs.contains(layer.id),
                  let mask = layer.mask
            else { return nil }
            return selectionFromLayerMask(mask, layer: layer)
        }
    }

    private func vectorMaskSelections() -> [ImageEditorSelection] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.compactMap { layer in
            guard selectedIDs.contains(layer.id),
                  let vectorMask = layer.vectorMask,
                  vectorMask.kind == .path,
                  vectorMask.isPathClosed,
                  vectorMask.editablePathAnchors.count >= 3
            else { return nil }
            return selectionFromVectorMask(vectorMask, layer: layer)
        }
    }

    private func combinedMaskSelections(
        _ selections: [ImageEditorSelection]
    ) -> ImageEditorSelection? {
        selections.reduce(nil) { current, candidate in
            ImageEditorSelection.combined(
                current: current,
                candidate: candidate,
                mode: .add,
                canvasSize: document.canvasSize
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
                NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: document.canvasSize.height) {
                    guard let context = NSGraphicsContext.current?.cgContext else { return }
                    context.saveGState()
                    context.setBlendMode(.clear)
                    NSColor.clear.setFill()
                    path.fill()
                    context.restoreGState()
                }
            } else {
                NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: document.canvasSize.height) {
                    NSColor.white.setFill()
                    path.fill()
                }
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

    private func vectorMaskCreationOperations(
        _ selection: ImageEditorSelection
    ) -> [(index: Int, vectorMask: ImageEditorShapeContent)] {
        guard !selection.isInverted, selection.points.count >= 3 else { return [] }
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.compactMap { index in
            let layer = document.layers[index]
            guard selectedIDs.contains(layer.id),
                  !document.isEffectivelyLocked(layer),
                  layer.vectorMask == nil,
                  let vectorMask = vectorMaskContent(from: selection, layer: layer)
            else { return nil }
            return (index, vectorMask)
        }
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
