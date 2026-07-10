//
//  ImageEditorChannels.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit

enum ImageEditorChannelPreview: String, CaseIterable, Identifiable {
    case composite
    case red
    case green
    case blue
    case alpha

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.channel.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .composite:
            "circle.grid.cross"
        case .red:
            "r.circle"
        case .green:
            "g.circle"
        case .blue:
            "b.circle"
        case .alpha:
            "a.circle"
        }
    }
}

enum ImageEditorLayerPanelTab: String, CaseIterable, Identifiable {
    case layers
    case channels
    case comps

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.panelTab.\(rawValue)")
    }
}

@MainActor
extension ImageEditorViewModel {
    var canSaveSelectionAsAlphaChannel: Bool {
        guard let mask = document.selection?.rasterizedMask(canvasSize: document.canvasSize) else { return false }
        return mask.selectedBounds(in: document.canvasSize) != nil
    }

    var canCreateBlankAlphaChannel: Bool {
        document.canvasSize.width > 0 && document.canvasSize.height > 0
    }

    var canSaveSelectedLayerMaskAsAlphaChannel: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return layer.mask != nil
    }

    var canSaveSelectedLayerTransparencyAsAlphaChannel: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return !layer.isGroup && !layer.isAdjustment && !layer.isFilter
    }

    var canSaveSelectedChannelAsAlphaChannel: Bool {
        // This value is read while SwiftUI builds the Select menu. Rendering a full
        // composite image here can recursively trigger more menu layout work.
        document.canvasSize.width > 0 && document.canvasSize.height > 0
    }

    var canApplyAlphaChannelToSelectedLayerMask: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return !document.isEffectivelyLocked(layer)
    }

    var selectedAlphaChannel: ImageEditorAlphaChannel? {
        guard let selectedAlphaChannelID else { return nil }
        return document.alphaChannels.first { $0.id == selectedAlphaChannelID }
    }

    var previewedAlphaChannel: ImageEditorAlphaChannel? {
        guard let previewedAlphaChannelID else { return nil }
        return document.alphaChannels.first { $0.id == previewedAlphaChannelID }
    }

    var channelPreviewTitle: String {
        previewedAlphaChannel?.name ?? selectedChannelPreview.title
    }

    var canLoadSelectedAlphaChannelSelection: Bool {
        selectedAlphaChannel != nil
    }

    var canUpdateSelectedAlphaChannelFromSelection: Bool {
        selectedAlphaChannel != nil && canSaveSelectionAsAlphaChannel
    }

    var canAddSelectionToSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil && canSaveSelectionAsAlphaChannel
    }

    var canSubtractSelectionFromSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil && canSaveSelectionAsAlphaChannel
    }

    var canIntersectSelectionWithSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil && canSaveSelectionAsAlphaChannel
    }

    var canApplySelectedAlphaChannelToLayerMask: Bool {
        selectedAlphaChannel != nil && canApplyAlphaChannelToSelectedLayerMask
    }

    var canCreateLayerFromSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canDuplicateSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canInvertSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canFillSelectedAlphaChannelWhite: Bool {
        selectedAlphaChannel != nil
    }

    var canClearSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canThresholdSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canFeatherSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canExpandSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canContractSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canSmoothSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canFillHolesSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canRemoveSpecklesSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canFlipSelectedAlphaChannelHorizontal: Bool {
        selectedAlphaChannel != nil
    }

    var canFlipSelectedAlphaChannelVertical: Bool {
        selectedAlphaChannel != nil
    }

    var canRotateSelectedAlphaChannelClockwise: Bool {
        selectedAlphaChannel != nil
    }

    var canRotateSelectedAlphaChannelCounterclockwise: Bool {
        selectedAlphaChannel != nil
    }

    var canRotateSelectedAlphaChannel180: Bool {
        selectedAlphaChannel != nil
    }

    var canScaleSelectedAlphaChannelUp: Bool {
        selectedAlphaChannel != nil
    }

    var canScaleSelectedAlphaChannelDown: Bool {
        selectedAlphaChannel != nil
    }

    var canFitSelectedAlphaChannelToCanvas: Bool {
        selectedAlphaChannel != nil
    }

    var canMoveSelectedAlphaChannelLeft: Bool {
        selectedAlphaChannel != nil
    }

    var canMoveSelectedAlphaChannelRight: Bool {
        selectedAlphaChannel != nil
    }

    var canMoveSelectedAlphaChannelUp: Bool {
        selectedAlphaChannel != nil
    }

    var canMoveSelectedAlphaChannelDown: Bool {
        selectedAlphaChannel != nil
    }

    var canDeleteSelectedAlphaChannel: Bool {
        selectedAlphaChannel != nil
    }

    var canSelectPreviousAlphaChannel: Bool {
        guard let index = selectedAlphaChannelIndex else { return false }
        return index > 0
    }

    var canSelectNextAlphaChannel: Bool {
        guard let index = selectedAlphaChannelIndex else { return false }
        return index < document.alphaChannels.count - 1
    }

    func loadSelectionFromChannel(_ channel: ImageEditorChannelPreview) {
        guard let selection = currentImage.channelSelection(channel, canvasSize: document.canvasSize) else {
            statusText = L10n.format("imageEditor.status.channelSelectionEmpty", channel.title)
            return
        }

        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.selectionFromChannel")
        if document.selection != nil {
            statusText = L10n.format("imageEditor.status.channelSelection", channel.title)
        }
    }

    func saveSelectionAsAlphaChannel() {
        guard let mask = document.selection?.rasterizedMask(canvasSize: document.canvasSize),
              mask.selectedBounds(in: document.canvasSize) != nil
        else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }

        pushUndo()
        let nextIndex = document.alphaChannels.count + 1
        let channel = ImageEditorAlphaChannel(
            name: L10n.format("imageEditor.channel.alphaChannelName", nextIndex),
            mask: mask
        )
        document.alphaChannels.append(channel)
        selectedAlphaChannelID = channel.id
        appendHistory(L10n.text("imageEditor.history.alphaChannelSave"))
        statusText = L10n.text("imageEditor.status.alphaChannelSaved")
    }

    func createBlankAlphaChannel() {
        guard canCreateBlankAlphaChannel else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let width = max(1, Int(document.canvasSize.width.rounded()))
        let height = max(1, Int(document.canvasSize.height.rounded()))
        let nextIndex = document.alphaChannels.count + 1
        let channel = ImageEditorAlphaChannel(
            name: L10n.format("imageEditor.channel.alphaChannelName", nextIndex),
            mask: ImageEditorSelectionMask(width: width, height: height, alpha: [UInt8](repeating: 0, count: width * height))
        )

        pushUndo()
        document.alphaChannels.append(channel)
        selectedAlphaChannelID = channel.id
        previewedAlphaChannelID = channel.id
        appendHistory(L10n.text("imageEditor.history.alphaChannelBlank"))
        statusText = L10n.format("imageEditor.status.alphaChannelBlank", channel.name)
    }

    func saveSelectedLayerMaskAsAlphaChannel() {
        guard let layer = document.selectedLayer,
              let mask = layer.mask,
              let alphaMask = alphaChannelMask(fromLayerMask: mask, layer: layer),
              alphaMask.selectedBounds(in: document.canvasSize) != nil
        else {
            statusText = L10n.text("imageEditor.status.alphaChannelFromMaskFailed")
            return
        }

        pushUndo()
        let nextIndex = document.alphaChannels.count + 1
        let channel = ImageEditorAlphaChannel(
            name: L10n.format("imageEditor.channel.alphaChannelFromMaskName", nextIndex),
            mask: alphaMask
        )
        document.alphaChannels.append(channel)
        selectedAlphaChannelID = channel.id
        appendHistory(L10n.text("imageEditor.history.alphaChannelFromMask"))
        statusText = L10n.text("imageEditor.status.alphaChannelFromMask")
    }

    func saveSelectedLayerTransparencyAsAlphaChannel() {
        guard canSaveSelectedLayerTransparencyAsAlphaChannel,
              let index = document.selectedLayerIndex,
              let alphaMask = alphaChannelMaskFromLayerTransparency(at: index),
              alphaMask.selectedBounds(in: document.canvasSize) != nil
        else {
            statusText = L10n.text("imageEditor.status.alphaChannelFromTransparencyFailed")
            return
        }

        pushUndo()
        let nextIndex = document.alphaChannels.count + 1
        let channel = ImageEditorAlphaChannel(
            name: L10n.format("imageEditor.channel.alphaChannelFromTransparencyName", nextIndex),
            mask: alphaMask
        )
        document.alphaChannels.append(channel)
        selectedAlphaChannelID = channel.id
        previewedAlphaChannelID = channel.id
        appendHistory(L10n.text("imageEditor.history.alphaChannelFromTransparency"))
        statusText = L10n.text("imageEditor.status.alphaChannelFromTransparency")
    }

    func saveSelectedChannelAsAlphaChannel() {
        saveChannelAsAlphaChannel(selectedChannelPreview)
    }

    func saveChannelAsAlphaChannel(_ channelPreview: ImageEditorChannelPreview) {
        guard let mask = currentImage.channelSelectionMask(channelPreview),
              mask.selectedBounds(in: document.canvasSize) != nil
        else {
            statusText = L10n.format("imageEditor.status.channelSelectionEmpty", channelPreview.title)
            return
        }

        pushUndo()
        let channel = ImageEditorAlphaChannel(
            name: uniqueAlphaChannelName(
                L10n.format("imageEditor.channel.alphaChannelFromChannelName", channelPreview.title)
            ),
            mask: mask
        )
        document.alphaChannels.append(channel)
        selectedAlphaChannelID = channel.id
        appendHistory(L10n.text("imageEditor.history.alphaChannelFromChannel"))
        statusText = L10n.format("imageEditor.status.alphaChannelFromChannel", channelPreview.title)
    }

    func selectAlphaChannel(_ id: UUID) {
        guard let channel = document.alphaChannels.first(where: { $0.id == id }) else { return }
        selectedAlphaChannelID = channel.id
        previewedAlphaChannelID = channel.id
        statusText = L10n.format("imageEditor.status.alphaChannelSelected", channel.name)
    }

    func loadSelectionFromSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        loadSelectionFromAlphaChannel(selectedAlphaChannelID)
    }

    func updateSelectedAlphaChannelFromSelection() {
        guard let selectedAlphaChannelID else { return }
        updateAlphaChannelFromSelection(selectedAlphaChannelID)
    }

    func addSelectionToSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        addSelectionToAlphaChannel(selectedAlphaChannelID)
    }

    func subtractSelectionFromSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        subtractSelectionFromAlphaChannel(selectedAlphaChannelID)
    }

    func intersectSelectionWithSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        intersectSelectionWithAlphaChannel(selectedAlphaChannelID)
    }

    func applySelectedAlphaChannelToSelectedLayerMask() {
        guard let selectedAlphaChannelID else { return }
        applyAlphaChannelToSelectedLayerMask(selectedAlphaChannelID)
    }

    func createLayerFromSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        createLayerFromAlphaChannel(selectedAlphaChannelID)
    }

    func duplicateSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        duplicateAlphaChannel(selectedAlphaChannelID)
    }

    func invertSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        invertAlphaChannel(selectedAlphaChannelID)
    }

    func fillSelectedAlphaChannelWhite() {
        guard let selectedAlphaChannelID else { return }
        fillAlphaChannelWhite(selectedAlphaChannelID)
    }

    func clearSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        clearAlphaChannel(selectedAlphaChannelID)
    }

    func thresholdSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        thresholdAlphaChannel(selectedAlphaChannelID)
    }

    func featherSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        featherAlphaChannel(selectedAlphaChannelID)
    }

    func expandSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        expandAlphaChannel(selectedAlphaChannelID)
    }

    func contractSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        contractAlphaChannel(selectedAlphaChannelID)
    }

    func smoothSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        smoothAlphaChannel(selectedAlphaChannelID)
    }

    func fillHolesSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        fillHolesAlphaChannel(selectedAlphaChannelID)
    }

    func removeSpecklesSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        removeSpecklesAlphaChannel(selectedAlphaChannelID)
    }

    func flipSelectedAlphaChannelHorizontal() {
        guard let selectedAlphaChannelID else { return }
        flipAlphaChannelHorizontal(selectedAlphaChannelID)
    }

    func flipSelectedAlphaChannelVertical() {
        guard let selectedAlphaChannelID else { return }
        flipAlphaChannelVertical(selectedAlphaChannelID)
    }

    func rotateSelectedAlphaChannelClockwise() {
        guard let selectedAlphaChannelID else { return }
        rotateAlphaChannelClockwise(selectedAlphaChannelID)
    }

    func rotateSelectedAlphaChannelCounterclockwise() {
        guard let selectedAlphaChannelID else { return }
        rotateAlphaChannelCounterclockwise(selectedAlphaChannelID)
    }

    func rotateSelectedAlphaChannel180() {
        guard let selectedAlphaChannelID else { return }
        rotateAlphaChannel180(selectedAlphaChannelID)
    }

    func scaleSelectedAlphaChannelUp() {
        guard let selectedAlphaChannelID else { return }
        scaleAlphaChannelUp(selectedAlphaChannelID)
    }

    func scaleSelectedAlphaChannelDown() {
        guard let selectedAlphaChannelID else { return }
        scaleAlphaChannelDown(selectedAlphaChannelID)
    }

    func fitSelectedAlphaChannelToCanvas() {
        guard let selectedAlphaChannelID else { return }
        fitAlphaChannelToCanvas(selectedAlphaChannelID)
    }

    func moveSelectedAlphaChannelLeft() {
        guard let selectedAlphaChannelID else { return }
        moveAlphaChannelLeft(selectedAlphaChannelID)
    }

    func moveSelectedAlphaChannelRight() {
        guard let selectedAlphaChannelID else { return }
        moveAlphaChannelRight(selectedAlphaChannelID)
    }

    func moveSelectedAlphaChannelUp() {
        guard let selectedAlphaChannelID else { return }
        moveAlphaChannelUp(selectedAlphaChannelID)
    }

    func moveSelectedAlphaChannelDown() {
        guard let selectedAlphaChannelID else { return }
        moveAlphaChannelDown(selectedAlphaChannelID)
    }

    func deleteSelectedAlphaChannel() {
        guard let selectedAlphaChannelID else { return }
        deleteAlphaChannel(selectedAlphaChannelID)
    }

    func selectPreviousAlphaChannel() {
        guard canSelectPreviousAlphaChannel,
              let index = selectedAlphaChannelIndex
        else { return }
        selectAlphaChannel(document.alphaChannels[index - 1].id)
    }

    func selectNextAlphaChannel() {
        guard canSelectNextAlphaChannel,
              let index = selectedAlphaChannelIndex
        else { return }
        selectAlphaChannel(document.alphaChannels[index + 1].id)
    }

    func renameAlphaChannel(_ id: UUID, to proposedName: String) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusText = L10n.text("imageEditor.status.alphaChannelNameInvalid")
            return
        }
        guard document.alphaChannels[index].name != trimmedName else { return }

        pushUndo()
        document.alphaChannels[index].name = trimmedName
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelRename"))
        statusText = L10n.text("imageEditor.status.alphaChannelRenamed")
    }

    func duplicateAlphaChannel(_ id: UUID) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }

        var duplicatedChannel = document.alphaChannels[index]
        duplicatedChannel.id = UUID()
        duplicatedChannel.name = uniqueAlphaChannelName(
            L10n.format("imageEditor.channel.alphaChannelCopyName", duplicatedChannel.name)
        )

        pushUndo()
        document.alphaChannels.insert(duplicatedChannel, at: index + 1)
        selectedAlphaChannelID = duplicatedChannel.id
        previewedAlphaChannelID = duplicatedChannel.id
        appendHistory(L10n.text("imageEditor.history.alphaChannelDuplicate"))
        statusText = L10n.format("imageEditor.status.alphaChannelDuplicated", duplicatedChannel.name)
    }

    func invertAlphaChannel(_ id: UUID) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }

        pushUndo()
        document.alphaChannels[index].mask.alpha = document.alphaChannels[index].mask.alpha.map { UInt8.max - $0 }
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelInvert"))
        statusText = L10n.format("imageEditor.status.alphaChannelInverted", document.alphaChannels[index].name)
    }

    func fillAlphaChannelWhite(_ id: UUID) {
        replaceAlphaChannelAlpha(
            id,
            with: UInt8.max,
            historyKey: "imageEditor.history.alphaChannelFillWhite",
            statusKey: "imageEditor.status.alphaChannelFilledWhite"
        )
    }

    func clearAlphaChannel(_ id: UUID) {
        replaceAlphaChannelAlpha(
            id,
            with: 0,
            historyKey: "imageEditor.history.alphaChannelClear",
            statusKey: "imageEditor.status.alphaChannelCleared"
        )
    }

    func thresholdAlphaChannel(_ id: UUID, cutoff: UInt8 = 127) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }

        pushUndo()
        document.alphaChannels[index].mask.alpha = document.alphaChannels[index].mask.alpha.map {
            $0 > cutoff ? UInt8.max : 0
        }
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelThreshold"))
        statusText = L10n.format("imageEditor.status.alphaChannelThresholded", document.alphaChannels[index].name)
    }

    func featherAlphaChannel(_ id: UUID, radius: Int? = nil) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        let effectiveRadius = max(1, min(64, radius ?? Int(selectionModifyAmount.rounded())))
        guard let featheredMask = document.alphaChannels[index].mask.feathered(by: effectiveRadius) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = featheredMask
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelFeather"))
        statusText = L10n.format(
            "imageEditor.status.alphaChannelFeathered",
            document.alphaChannels[index].name,
            effectiveRadius
        )
    }

    func expandAlphaChannel(_ id: UUID, radius: Int? = nil) {
        morphAlphaChannel(
            id,
            radius: radius,
            historyKey: "imageEditor.history.alphaChannelExpand",
            statusKey: "imageEditor.status.alphaChannelExpanded"
        ) { mask, effectiveRadius in
            mask.expanded(by: effectiveRadius)
        }
    }

    func contractAlphaChannel(_ id: UUID, radius: Int? = nil) {
        morphAlphaChannel(
            id,
            radius: radius,
            historyKey: "imageEditor.history.alphaChannelContract",
            statusKey: "imageEditor.status.alphaChannelContracted"
        ) { mask, effectiveRadius in
            mask.contracted(by: effectiveRadius)
        }
    }

    func smoothAlphaChannel(_ id: UUID, radius: Int? = nil) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        let effectiveRadius = max(1, min(16, radius ?? Int(selectionModifyAmount.rounded())))
        guard let smoothedMask = document.alphaChannels[index].mask.smoothed(by: effectiveRadius) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = smoothedMask
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelSmooth"))
        statusText = L10n.format(
            "imageEditor.status.alphaChannelSmoothed",
            document.alphaChannels[index].name,
            effectiveRadius
        )
    }

    func fillHolesAlphaChannel(_ id: UUID) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        guard let filledMask = document.alphaChannels[index].mask.filledHoles() else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = filledMask
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelFillHoles"))
        statusText = L10n.format(
            "imageEditor.status.alphaChannelFilledHoles",
            document.alphaChannels[index].name
        )
    }

    func removeSpecklesAlphaChannel(_ id: UUID, maximumArea: Int? = nil) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        let effectiveMaximumArea = max(1, min(64, maximumArea ?? Int(selectionModifyAmount.rounded())))
        guard let cleanedMask = document.alphaChannels[index].mask.removedSpeckles(maximumArea: effectiveMaximumArea) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = cleanedMask
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelRemoveSpeckles"))
        statusText = L10n.format(
            "imageEditor.status.alphaChannelSpecklesRemoved",
            document.alphaChannels[index].name,
            effectiveMaximumArea
        )
    }

    func flipAlphaChannelHorizontal(_ id: UUID) {
        flipAlphaChannel(
            id,
            horizontal: true,
            historyKey: "imageEditor.history.alphaChannelFlipHorizontal",
            statusKey: "imageEditor.status.alphaChannelFlippedHorizontal"
        )
    }

    func flipAlphaChannelVertical(_ id: UUID) {
        flipAlphaChannel(
            id,
            horizontal: false,
            historyKey: "imageEditor.history.alphaChannelFlipVertical",
            statusKey: "imageEditor.status.alphaChannelFlippedVertical"
        )
    }

    private func flipAlphaChannel(_ id: UUID, horizontal: Bool, historyKey: String, statusKey: String) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        guard let flippedMask = document.alphaChannels[index].mask.flipped(horizontal: horizontal) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = flippedMask
        selectedAlphaChannelID = id
        appendHistory(L10n.text(historyKey))
        statusText = L10n.format(statusKey, document.alphaChannels[index].name)
    }

    func rotateAlphaChannelClockwise(_ id: UUID) {
        rotateAlphaChannel(
            id,
            clockwiseTurns: 1,
            historyKey: "imageEditor.history.alphaChannelRotateClockwise",
            statusKey: "imageEditor.status.alphaChannelRotatedClockwise"
        )
    }

    func rotateAlphaChannelCounterclockwise(_ id: UUID) {
        rotateAlphaChannel(
            id,
            clockwiseTurns: -1,
            historyKey: "imageEditor.history.alphaChannelRotateCounterclockwise",
            statusKey: "imageEditor.status.alphaChannelRotatedCounterclockwise"
        )
    }

    func rotateAlphaChannel180(_ id: UUID) {
        rotateAlphaChannel(
            id,
            clockwiseTurns: 2,
            historyKey: "imageEditor.history.alphaChannelRotate180",
            statusKey: "imageEditor.status.alphaChannelRotated180"
        )
    }

    func scaleAlphaChannelUp(_ id: UUID) {
        scaleAlphaChannel(
            id,
            factor: 2,
            historyKey: "imageEditor.history.alphaChannelScaleUp",
            statusKey: "imageEditor.status.alphaChannelScaledUp"
        )
    }

    func scaleAlphaChannelDown(_ id: UUID) {
        scaleAlphaChannel(
            id,
            factor: 0.5,
            historyKey: "imageEditor.history.alphaChannelScaleDown",
            statusKey: "imageEditor.status.alphaChannelScaledDown"
        )
    }

    func moveAlphaChannelLeft(_ id: UUID) {
        moveAlphaChannel(id, by: CGSize(width: -alphaChannelMoveAmount, height: 0))
    }

    func moveAlphaChannelRight(_ id: UUID) {
        moveAlphaChannel(id, by: CGSize(width: alphaChannelMoveAmount, height: 0))
    }

    func moveAlphaChannelUp(_ id: UUID) {
        moveAlphaChannel(id, by: CGSize(width: 0, height: alphaChannelMoveAmount))
    }

    func moveAlphaChannelDown(_ id: UUID) {
        moveAlphaChannel(id, by: CGSize(width: 0, height: -alphaChannelMoveAmount))
    }

    func fitAlphaChannelToCanvas(_ id: UUID) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        guard let fittedMask = document.alphaChannels[index].mask.fittedToCanvas() else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = fittedMask
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelFitCanvas"))
        statusText = L10n.format(
            "imageEditor.status.alphaChannelFitCanvas",
            document.alphaChannels[index].name
        )
    }

    private func rotateAlphaChannel(_ id: UUID, clockwiseTurns: Int, historyKey: String, statusKey: String) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        guard let rotatedMask = document.alphaChannels[index].mask.rotatedQuarterTurns(clockwiseTurns) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = rotatedMask
        selectedAlphaChannelID = id
        appendHistory(L10n.text(historyKey))
        statusText = L10n.format(statusKey, document.alphaChannels[index].name)
    }

    private func scaleAlphaChannel(_ id: UUID, factor: CGFloat, historyKey: String, statusKey: String) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        guard let scaledMask = document.alphaChannels[index].mask.scaled(by: factor) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = scaledMask
        selectedAlphaChannelID = id
        appendHistory(L10n.text(historyKey))
        statusText = L10n.format(statusKey, document.alphaChannels[index].name)
    }

    private var alphaChannelMoveAmount: CGFloat {
        CGFloat(max(1, min(512, Int(selectionModifyAmount.rounded()))))
    }

    private func moveAlphaChannel(_ id: UUID, by delta: CGSize) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        guard let movedMask = document.alphaChannels[index].mask.translated(by: delta, canvasSize: document.canvasSize) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = movedMask
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelMove"))
        statusText = L10n.format(
            "imageEditor.status.alphaChannelMoved",
            document.alphaChannels[index].name,
            Int(delta.width.rounded()),
            Int(delta.height.rounded())
        )
    }

    private func morphAlphaChannel(
        _ id: UUID,
        radius: Int?,
        historyKey: String,
        statusKey: String,
        transform: (ImageEditorSelectionMask, Int) -> ImageEditorSelectionMask?
    ) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        let effectiveRadius = max(1, min(64, radius ?? Int(selectionModifyAmount.rounded())))
        guard let outputMask = transform(document.alphaChannels[index].mask, effectiveRadius) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = outputMask
        selectedAlphaChannelID = id
        appendHistory(L10n.text(historyKey))
        statusText = L10n.format(statusKey, document.alphaChannels[index].name, effectiveRadius)
    }

    func updateAlphaChannelFromSelection(_ id: UUID) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        guard let mask = document.selection?.rasterizedMask(canvasSize: document.canvasSize),
              mask.selectedBounds(in: document.canvasSize) != nil
        else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = mask
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelUpdate"))
        statusText = L10n.format("imageEditor.status.alphaChannelUpdated", document.alphaChannels[index].name)
    }

    func addSelectionToAlphaChannel(_ id: UUID) {
        combineAlphaChannelWithCurrentSelection(
            id,
            mode: .add,
            historyKey: "imageEditor.history.alphaChannelSelectionAdd",
            statusKey: "imageEditor.status.alphaChannelSelectionAdded"
        )
    }

    func subtractSelectionFromAlphaChannel(_ id: UUID) {
        combineAlphaChannelWithCurrentSelection(
            id,
            mode: .subtract,
            historyKey: "imageEditor.history.alphaChannelSelectionSubtract",
            statusKey: "imageEditor.status.alphaChannelSelectionSubtracted"
        )
    }

    func intersectSelectionWithAlphaChannel(_ id: UUID) {
        combineAlphaChannelWithCurrentSelection(
            id,
            mode: .intersect,
            historyKey: "imageEditor.history.alphaChannelSelectionIntersect",
            statusKey: "imageEditor.status.alphaChannelSelectionIntersected"
        )
    }

    private func replaceAlphaChannelAlpha(
        _ id: UUID,
        with value: UInt8,
        historyKey: String,
        statusKey: String
    ) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        let mask = document.alphaChannels[index].mask
        let count = max(0, mask.width * mask.height)

        pushUndo()
        document.alphaChannels[index].mask.alpha = [UInt8](repeating: value, count: count)
        selectedAlphaChannelID = id
        appendHistory(L10n.text(historyKey))
        statusText = L10n.format(statusKey, document.alphaChannels[index].name)
    }

    private func combineAlphaChannelWithCurrentSelection(
        _ id: UUID,
        mode: ImageEditorSelectionMode,
        historyKey: String,
        statusKey: String
    ) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }
        guard let selectionMask = document.selection?.rasterizedMask(canvasSize: document.canvasSize),
              selectionMask.selectedBounds(in: document.canvasSize) != nil
        else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        guard let outputMask = document.alphaChannels[index].mask.combined(with: selectionMask, mode: mode) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.alphaChannels[index].mask = outputMask
        selectedAlphaChannelID = id
        appendHistory(L10n.text(historyKey))
        statusText = L10n.format(statusKey, document.alphaChannels[index].name)
    }

    func applyAlphaChannelToSelectedLayerMask(_ id: UUID) {
        guard canApplyAlphaChannelToSelectedLayerMask,
              let layerIndex = document.selectedLayerIndex,
              let channel = document.alphaChannels.first(where: { $0.id == id }),
              let mask = layerMask(fromAlphaChannel: channel, layer: document.layers[layerIndex])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[layerIndex].mask = mask
        document.layers[layerIndex].isMaskEnabled = true
        document.layers[layerIndex].isMaskLinked = true
        document.layers[layerIndex].maskDensity = 1
        document.layers[layerIndex].maskFeather = 0
        isEditingLayerMask = true
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelApplyToMask"))
        statusText = L10n.format("imageEditor.status.alphaChannelApplyToMask", channel.name)
    }

    func createLayerFromAlphaChannel(_ id: UUID) {
        guard let channel = document.alphaChannels.first(where: { $0.id == id }) else { return }

        var layer = ImageEditorLayer.blank(
            name: L10n.format("imageEditor.layer.alphaChannelName", channel.name),
            size: document.canvasSize
        )
        layer.image = channel.mask.grayscalePreviewImage(targetSize: document.canvasSize)
        let insertionContext = alphaChannelLayerInsertionContext()
        layer.groupID = insertionContext.parentGroupID

        pushUndo()
        document.layers.insert(layer, at: insertionContext.index)
        expandAlphaChannelLayerParentIfNeeded(insertionContext.parentGroupID)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        selectedAlphaChannelID = id
        appendHistory(L10n.text("imageEditor.history.alphaChannelLayer"))
        statusText = L10n.format("imageEditor.status.alphaChannelLayer", channel.name)
    }

    func loadSelectionFromAlphaChannel(_ id: UUID) {
        guard let channel = document.alphaChannels.first(where: { $0.id == id }),
              let bounds = channel.mask.selectedBounds(in: document.canvasSize)
        else {
            statusText = L10n.text("imageEditor.status.alphaChannelSelectionEmpty")
            return
        }

        let selection = ImageEditorSelection.raster(mask: channel.mask, bounds: bounds)
        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.alphaChannelLoad")
        if document.selection != nil {
            selectedAlphaChannelID = id
            statusText = L10n.format("imageEditor.status.alphaChannelLoaded", channel.name)
        }
    }

    func deleteAlphaChannel(_ id: UUID) {
        guard let index = document.alphaChannels.firstIndex(where: { $0.id == id }) else { return }

        pushUndo()
        document.alphaChannels.remove(at: index)
        if selectedAlphaChannelID == id {
            if document.alphaChannels.isEmpty {
                selectedAlphaChannelID = nil
            } else {
                selectedAlphaChannelID = document.alphaChannels[min(index, document.alphaChannels.count - 1)].id
            }
        }
        if previewedAlphaChannelID == id {
            previewedAlphaChannelID = selectedAlphaChannelID
        }
        appendHistory(L10n.text("imageEditor.history.alphaChannelDelete"))
        statusText = L10n.text("imageEditor.status.alphaChannelDeleted")
    }

    func alphaChannelPreviewImage(_ channel: ImageEditorAlphaChannel) -> NSImage {
        cachedAlphaChannelPreviewImage(channel)
    }

    private var selectedAlphaChannelIndex: Int? {
        guard let selectedAlphaChannelID else { return nil }
        return document.alphaChannels.firstIndex { $0.id == selectedAlphaChannelID }
    }

    private struct AlphaChannelLayerInsertionContext {
        var parentGroupID: UUID?
        var index: Int
    }

    private func alphaChannelLayerInsertionContext() -> AlphaChannelLayerInsertionContext {
        guard let selectedLayerID = document.selectedLayerID,
              let selectedIndex = document.layers.firstIndex(where: { $0.id == selectedLayerID })
        else {
            return AlphaChannelLayerInsertionContext(parentGroupID: nil, index: document.layers.count)
        }

        let selectedLayer = document.layers[selectedIndex]
        if selectedLayer.isGroup {
            return AlphaChannelLayerInsertionContext(parentGroupID: selectedLayer.id, index: selectedIndex)
        }

        return AlphaChannelLayerInsertionContext(
            parentGroupID: selectedLayer.groupID,
            index: min(selectedIndex + 1, document.layers.count)
        )
    }

    private func expandAlphaChannelLayerParentIfNeeded(_ groupID: UUID?) {
        guard let groupID,
              let groupIndex = document.layers.firstIndex(where: { $0.id == groupID && $0.isGroup })
        else { return }
        document.layers[groupIndex].isGroupExpanded = true
    }

    private func uniqueAlphaChannelName(_ baseName: String) -> String {
        let existingNames = Set(document.alphaChannels.map(\.name))
        guard existingNames.contains(baseName) else { return baseName }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)") {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }

    private func layerMask(fromAlphaChannel channel: ImageEditorAlphaChannel, layer: ImageEditorLayer) -> NSImage? {
        guard let canvasMask = NSImage.selectionMaskImage(channel.mask, inverted: false, targetSize: document.canvasSize) else {
            return nil
        }

        if layer.isGroup {
            return canvasMask
        }

        guard layer.image.size.width > 0,
              layer.image.size.height > 0,
              layer.frame.width > 0,
              layer.frame.height > 0
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

    private func alphaChannelMaskFromLayerTransparency(at index: Int) -> ImageEditorSelectionMask? {
        guard document.layers.indices.contains(index) else { return nil }
        let layer = document.layers[index]
        guard let image = NSImage.rendered(size: document.canvasSize, actions: { _ in
            if layer.isClippingMask,
               let clippedImage = document.clippedCompositingImage(forLayerAt: index) {
                clippedImage.draw(
                    in: CGRect(origin: .zero, size: document.canvasSize),
                    from: CGRect(origin: .zero, size: document.canvasSize),
                    operation: .sourceOver,
                    fraction: 1
                )
            } else {
                let compositingImage = layer.renderedCompositingImage(globalLightAngle: document.globalLightAngle)
                compositingImage.draw(
                    in: layer.renderedCompositingFrame(globalLightAngle: document.globalLightAngle),
                    from: CGRect(origin: .zero, size: compositingImage.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }
        }) else { return nil }

        return image.alphaMask(
            width: max(1, Int(document.canvasSize.width.rounded())),
            height: max(1, Int(document.canvasSize.height.rounded()))
        )
    }

    private func alphaChannelMask(fromLayerMask mask: NSImage, layer: ImageEditorLayer) -> ImageEditorSelectionMask? {
        let canvasMask: NSImage?
        if layer.isGroup {
            canvasMask = mask.resized(to: document.canvasSize)
        } else {
            canvasMask = NSImage.rendered(size: document.canvasSize) { _ in
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
        return canvasMask?.alphaMask(width: max(1, Int(document.canvasSize.width.rounded())), height: max(1, Int(document.canvasSize.height.rounded())))
    }
}

extension NSImage {
    func channelPreview(_ channel: ImageEditorChannelPreview) -> NSImage {
        guard channel != .composite,
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return self
        }

        let width = cgImage.width
        let height = cgImage.height
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
        ) else {
            return self
        }

        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let value: UInt8
                switch channel {
                case .composite:
                    value = 0
                case .red:
                    value = pixels[offset]
                case .green:
                    value = pixels[offset + 1]
                case .blue:
                    value = pixels[offset + 2]
                case .alpha:
                    value = pixels[offset + 3]
                }
                pixels[offset] = value
                pixels[offset + 1] = value
                pixels[offset + 2] = value
                pixels[offset + 3] = UInt8.max
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else {
            return self
        }

        return NSImage(cgImage: output, size: size)
    }

    func channelSelection(_ channel: ImageEditorChannelPreview, canvasSize: CGSize) -> ImageEditorSelection? {
        guard let mask = channelSelectionMask(channel),
              let bounds = mask.selectedBounds(in: canvasSize)
        else { return nil }
        return .raster(mask: mask, bounds: bounds)
    }

    func channelSelectionMask(_ channel: ImageEditorChannelPreview) -> ImageEditorSelectionMask? {
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
        ) else {
            return nil
        }

        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let value: UInt8
                switch channel {
                case .composite:
                    value = Self.luminance(red: pixels[offset], green: pixels[offset + 1], blue: pixels[offset + 2])
                case .red:
                    value = pixels[offset]
                case .green:
                    value = pixels[offset + 1]
                case .blue:
                    value = pixels[offset + 2]
                case .alpha:
                    value = pixels[offset + 3]
                }
                alpha[y * width + x] = value
            }
        }

        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }

    private static func luminance(red: UInt8, green: UInt8, blue: UInt8) -> UInt8 {
        let value = 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
        return UInt8(max(0, min(255, value.rounded())))
    }
}

extension ImageEditorSelectionMask {
    func grayscalePreviewImage(targetSize: CGSize) -> NSImage {
        guard width > 0, height > 0, alpha.count == width * height else {
            return NSImage(size: targetSize)
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let alphaValue = alpha[y * width + x]
                let offset = y * bytesPerRow + x * bytesPerPixel
                pixels[offset] = alphaValue
                pixels[offset + 1] = alphaValue
                pixels[offset + 2] = alphaValue
                pixels[offset + 3] = UInt8.max
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else {
            return NSImage(size: targetSize)
        }

        return NSImage(cgImage: output, size: targetSize)
    }
}

extension NSImage {
    func alphaMask(width: Int, height: Int) -> ImageEditorSelectionMask? {
        guard width > 0,
              height > 0,
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

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
                alpha[y * width + x] = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }
}
