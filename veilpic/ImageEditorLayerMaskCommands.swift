//
//  ImageEditorLayerMaskCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

enum ImageEditorLayerMaskContextAction: String, CaseIterable, Identifiable {
    case revealAll
    case hideAll
    case revealSelection
    case hideSelection
    case revealSelectionOnMask
    case hideSelectionOnMask
    case intersectSelectionOnMask
    case loadSelection
    case edit
    case toggleEnabled
    case toggleLinked
    case invert
    case copyToSelected
    case apply
    case delete

    var id: String { rawValue }

    static let creationActions: [Self] = [
        .revealAll,
        .hideAll,
        .revealSelection,
        .hideSelection
    ]

    static let managementActions: [Self] = [
        .edit,
        .toggleEnabled,
        .toggleLinked,
        .invert,
        .copyToSelected,
        .apply,
        .delete
    ]

    static let selectionActions: [Self] = [
        .revealSelectionOnMask,
        .hideSelectionOnMask,
        .intersectSelectionOnMask,
        .loadSelection
    ]

    var actionTitleKey: String {
        switch self {
        case .revealAll: "imageEditor.action.layerMaskAdd"
        case .hideAll: "imageEditor.action.layerMaskHideAll"
        case .revealSelection: "imageEditor.action.layerMaskFromSelection"
        case .hideSelection: "imageEditor.action.layerMaskHideSelection"
        case .revealSelectionOnMask: "imageEditor.action.layerMaskRevealSelection"
        case .hideSelectionOnMask: "imageEditor.action.layerMaskHideSelectionFromMask"
        case .intersectSelectionOnMask: "imageEditor.action.layerMaskIntersectSelection"
        case .loadSelection: "imageEditor.action.layerMaskLoadSelection"
        case .edit: "imageEditor.action.layerMaskEdit"
        case .toggleEnabled: "imageEditor.action.layerMaskToggle"
        case .toggleLinked: "imageEditor.action.layerMaskLinkToggle"
        case .invert: "imageEditor.action.layerMaskInvert"
        case .copyToSelected: "imageEditor.action.layerMaskCopyToSelected"
        case .apply: "imageEditor.action.layerMaskApply"
        case .delete: "imageEditor.action.layerMaskDelete"
        }
    }

    var systemImage: String {
        switch self {
        case .revealAll: "circle.dashed"
        case .hideAll: "circle.fill"
        case .revealSelection: "circle.lefthalf.filled"
        case .hideSelection: "circle.dashed.inset.filled"
        case .revealSelectionOnMask: "rectangle.dashed.badge.plus"
        case .hideSelectionOnMask: "rectangle.dashed.badge.minus"
        case .intersectSelectionOnMask: "rectangle.intersection.angled"
        case .loadSelection: "selection.pin.in.out"
        case .edit: "paintbrush"
        case .toggleEnabled: "circle.slash"
        case .toggleLinked: "link"
        case .invert: "arrow.triangle.2.circlepath"
        case .copyToSelected: "doc.on.doc"
        case .apply: "checkmark.square"
        case .delete: "xmark.square"
        }
    }
}

enum ImageEditorVectorMaskContextAction: String, CaseIterable, Identifiable {
    case createFromSelection
    case toggleEnabled
    case toggleLinked
    case invert
    case editPath
    case loadSelection
    case copyToSelected
    case apply
    case rasterize
    case delete

    var id: String { rawValue }

    var actionTitleKey: String {
        switch self {
        case .createFromSelection: "imageEditor.action.vectorMaskFromSelection"
        case .toggleEnabled: "imageEditor.action.vectorMaskToggle"
        case .toggleLinked: "imageEditor.action.vectorMaskLinkToggle"
        case .invert: "imageEditor.action.vectorMaskInvert"
        case .editPath: "imageEditor.action.vectorMaskEditPath"
        case .loadSelection: "imageEditor.action.vectorMaskLoadSelection"
        case .copyToSelected: "imageEditor.action.vectorMaskCopyToSelected"
        case .apply: "imageEditor.action.vectorMaskApply"
        case .rasterize: "imageEditor.action.vectorMaskRasterize"
        case .delete: "imageEditor.action.vectorMaskDelete"
        }
    }

    var systemImage: String {
        switch self {
        case .createFromSelection: "point.topleft.down.curvedto.point.bottomright.up"
        case .toggleEnabled: "circle.slash"
        case .toggleLinked: "link"
        case .invert: "arrow.triangle.2.circlepath"
        case .editPath: "point.3.filled.connected.trianglepath.dotted"
        case .loadSelection: "rectangle.dashed"
        case .copyToSelected: "doc.on.doc"
        case .apply: "checkmark.square"
        case .rasterize: "square.grid.3x3"
        case .delete: "xmark.square"
        }
    }
}

fileprivate extension ImageEditorLayerMaskContextAction {
    var layerMaskSelectionCombination: ImageEditorLayerMaskSelectionCombination? {
        switch self {
        case .revealSelectionOnMask: .reveal
        case .hideSelectionOnMask: .hide
        case .intersectSelectionOnMask: .intersect
        default: nil
        }
    }
}

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

fileprivate enum ImageEditorMaskApplicationTarget: Equatable {
    case raster
    case vector
}

@MainActor
extension ImageEditorViewModel {
    func canPerformLayerMaskActionFromContext(
        _ clickedLayerID: UUID,
        action: ImageEditorLayerMaskContextAction
    ) -> Bool {
        let selectedIDs = layerContextSelectionIDs(for: clickedLayerID)
        guard !selectedIDs.isEmpty else { return false }
        switch action {
        case .revealAll, .hideAll:
            return !layerMaskAddIndices(selectedIDs: selectedIDs).isEmpty
        case .revealSelection, .hideSelection:
            guard let selection = document.selection else { return false }
            return !layerMaskCreationOperations(
                selection,
                hidingSelection: action == .hideSelection,
                selectedIDs: selectedIDs
            ).isEmpty
        case .revealSelectionOnMask, .hideSelectionOnMask, .intersectSelectionOnMask:
            guard let selection = document.selection,
                  let combination = action.layerMaskSelectionCombination
            else { return false }
            let operations = layerMaskSelectionCombinationOperations(
                selection,
                combination: combination,
                selectedIDs: selectedIDs
            )
            return operations.contains { operation in
                document.layers[operation.index].mask?.hasEquivalentAlphaMask(
                    to: operation.mask
                ) != true
            }
        case .loadSelection:
            return canLoadSelectionFromLayerMask(
                layerID: clickedLayerID,
                mode: selectionMode
            )
        case .edit:
            return document.layers.contains {
                $0.id == clickedLayerID && $0.mask != nil
            }
        case .toggleEnabled, .delete:
            return document.layers.contains { layer in
                selectedIDs.contains(layer.id)
                    && !document.isEffectivelyLocked(layer)
                    && layer.mask != nil
            }
        case .invert:
            return document.layers.contains { layer in
                selectedIDs.contains(layer.id)
                    && !document.isEffectivelyLocked(layer)
                    && layer.mask?.invertedAlphaMask() != nil
            }
        case .copyToSelected:
            return layerMaskCopyOperations(
                sourceID: clickedLayerID,
                selectedIDs: selectedIDs
            )?.operations.isEmpty == false
        case .toggleLinked:
            return document.layers.contains { layer in
                selectedIDs.contains(layer.id)
                    && !document.isEffectivelyLocked(layer)
                    && (layer.mask != nil || layer.vectorMask != nil)
            }
        case .apply:
            return !maskApplyIndices(
                target: .raster,
                selectedIDs: selectedIDs
            ).isEmpty
        }
    }

    @discardableResult
    func performLayerMaskActionFromContext(
        _ clickedLayerID: UUID,
        action: ImageEditorLayerMaskContextAction
    ) -> Bool {
        guard canPerformLayerMaskActionFromContext(
            clickedLayerID,
            action: action
        ) else { return false }
        prepareLayerContextSelection(for: clickedLayerID)
        switch action {
        case .revealAll:
            addLayerMask()
        case .hideAll:
            addLayerMaskHidingAll()
        case .revealSelection:
            addLayerMaskFromSelection()
        case .hideSelection:
            addLayerMaskHidingSelection()
        case .revealSelectionOnMask:
            revealSelectionOnLayerMask()
        case .hideSelectionOnMask:
            hideSelectionOnLayerMask()
        case .intersectSelectionOnMask:
            intersectLayerMaskWithSelection()
        case .loadSelection:
            return loadSelectionFromLayerMask(
                layerID: clickedLayerID,
                mode: selectionMode
            )
        case .edit:
            document.selectedLayerID = clickedLayerID
            editLayerMask()
        case .toggleEnabled:
            toggleLayerMaskEnabled()
        case .toggleLinked:
            toggleLayerMaskLinked()
        case .invert:
            invertLayerMask()
        case .copyToSelected:
            document.selectedLayerID = clickedLayerID
            copyLayerMaskToSelectedLayers()
        case .apply:
            applyLayerMask()
        case .delete:
            deleteLayerMask()
        }
        return true
    }

    private func canLoadSelectionFromLayerMask(
        layerID: UUID,
        mode: ImageEditorSelectionMode
    ) -> Bool {
        guard let layer = document.layers.first(where: { $0.id == layerID }),
              let mask = layer.mask,
              let candidate = selectionFromLayerMask(mask, layer: layer)
        else { return false }
        let existing = document.selection
        guard existing != nil || mode == .replace || mode == .add else {
            return false
        }
        let next = ImageEditorSelection.combined(
            current: existing,
            candidate: candidate,
            mode: mode,
            canvasSize: document.canvasSize
        )
        return !selectionsAreEquivalent(next, existing)
    }

    func canPerformVectorMaskActionFromContext(
        _ clickedLayerID: UUID,
        action: ImageEditorVectorMaskContextAction
    ) -> Bool {
        let selectedIDs = layerContextSelectionIDs(for: clickedLayerID)
        guard !selectedIDs.isEmpty else { return false }
        switch action {
        case .createFromSelection:
            guard let selection = document.selection else { return false }
            return !vectorMaskCreationOperations(
                selection,
                selectedIDs: selectedIDs
            ).isEmpty
        case .toggleEnabled:
            return !vectorMaskToggleEnabledIndices(
                selectedIDs: selectedIDs
            ).isEmpty
        case .toggleLinked:
            return !vectorMaskToggleLinkedIndices(
                selectedIDs: selectedIDs
            ).isEmpty
        case .invert:
            return !vectorMaskInvertIndices(
                selectedIDs: selectedIDs
            ).isEmpty
        case .editPath:
            guard let layer = document.layers.first(where: { $0.id == clickedLayerID }),
                  let vectorMask = layer.vectorMask
            else { return false }
            return !document.isEffectivelyLocked(layer)
                && vectorMask.kind == .path
                && vectorMask.isPathClosed
                && vectorMask.editablePathAnchors.count >= 3
        case .loadSelection:
            return canLoadSelectionFromVectorMask(
                layerID: clickedLayerID,
                mode: selectionMode
            )
        case .copyToSelected:
            return vectorMaskCopyOperations(
                sourceID: clickedLayerID,
                selectedIDs: selectedIDs
            )?.operations.isEmpty == false
        case .apply:
            return !maskApplyIndices(
                target: .vector,
                selectedIDs: selectedIDs
            ).isEmpty
        case .rasterize:
            return !vectorMaskRasterizeOperations(
                selectedIDs: selectedIDs
            ).isEmpty
        case .delete:
            return !vectorMaskDeleteIndices(
                selectedIDs: selectedIDs
            ).isEmpty
        }
    }

    @discardableResult
    func performVectorMaskActionFromContext(
        _ clickedLayerID: UUID,
        action: ImageEditorVectorMaskContextAction
    ) -> Bool {
        guard canPerformVectorMaskActionFromContext(
            clickedLayerID,
            action: action
        ) else { return false }
        prepareLayerContextSelection(for: clickedLayerID)
        switch action {
        case .createFromSelection:
            addVectorMaskFromSelection()
        case .toggleEnabled:
            toggleVectorMaskEnabled()
        case .toggleLinked:
            toggleVectorMaskLinked()
        case .invert:
            invertVectorMask()
        case .editPath:
            selectLayer(clickedLayerID)
            editSelectedVectorMaskAsPath()
        case .loadSelection:
            return loadSelectionFromVectorMask(
                layerID: clickedLayerID,
                mode: selectionMode
            )
        case .copyToSelected:
            document.selectedLayerID = clickedLayerID
            copyVectorMaskToSelectedLayers()
        case .apply:
            applyVectorMask()
        case .rasterize:
            rasterizeSelectedVectorMask()
        case .delete:
            deleteVectorMask()
        }
        return true
    }

    private func canLoadSelectionFromVectorMask(
        layerID: UUID,
        mode: ImageEditorSelectionMode
    ) -> Bool {
        guard let layer = document.layers.first(where: { $0.id == layerID }),
              let vectorMask = layer.vectorMask,
              vectorMask.kind == .path,
              vectorMask.isPathClosed,
              vectorMask.editablePathAnchors.count >= 3,
              let candidate = selectionFromVectorMask(vectorMask, layer: layer)
        else { return false }
        let existing = document.selection
        guard existing != nil || mode == .replace || mode == .add else {
            return false
        }
        let next = ImageEditorSelection.combined(
            current: existing,
            candidate: candidate,
            mode: mode,
            canvasSize: document.canvasSize
        )
        return !selectionsAreEquivalent(next, existing)
    }

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
        !maskApplyIndices(target: .raster).isEmpty
    }

    var canApplyVectorMask: Bool {
        !maskApplyIndices(target: .vector).isEmpty
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

    var canToggleVectorMaskLinked: Bool {
        !vectorMaskToggleLinkedIndices().isEmpty
    }

    var canInvertVectorMask: Bool {
        !vectorMaskInvertIndices().isEmpty
    }

    var canDeleteVectorMask: Bool {
        !vectorMaskDeleteIndices().isEmpty
    }

    var canRasterizeSelectedVectorMask: Bool {
        !vectorMaskRasterizeOperations(selectedIDs: selectedLayerIDsForVectorMaskRasterization).isEmpty
    }

    func canRasterizeVectorMasks(selectedIDs: Set<UUID>) -> Bool {
        !vectorMaskRasterizeOperations(selectedIDs: selectedIDs).isEmpty
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
            document.layers[operation.index].isVectorMaskInverted = false
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
              let plan = layerMaskCopyOperations(
                sourceID: sourceID,
                selectedIDs: document.selectedLayerIDs
              )
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        guard !plan.operations.isEmpty else {
            isEditingLayerMask = false
            statusText = L10n.text("imageEditor.status.layerMaskCopyUnchanged")
            return
        }

        let sourceLayer = document.layers[plan.sourceIndex]
        pushUndo()
        for operation in plan.operations {
            let index = operation.index
            document.layers[index].mask = operation.mask
            document.layers[index].isMaskEnabled = sourceLayer.isMaskEnabled
            document.layers[index].isMaskLinked = sourceLayer.isMaskLinked
            document.layers[index].maskDensity = sourceLayer.maskDensity
            document.layers[index].maskFeather = sourceLayer.maskFeather
        }
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMaskCopy"))
        statusText = L10n.format("imageEditor.status.layerMaskCopied", plan.operations.count)
    }

    func copyVectorMaskToSelectedLayers() {
        guard let sourceID = document.selectedLayerID,
              let plan = vectorMaskCopyOperations(
                sourceID: sourceID,
                selectedIDs: document.selectedLayerIDs
              )
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        guard !plan.operations.isEmpty else {
            isEditingLayerMask = false
            statusText = L10n.text("imageEditor.status.vectorMaskCopyUnchanged")
            return
        }

        let sourceLayer = document.layers[plan.sourceIndex]
        pushUndo()
        for operation in plan.operations {
            let index = operation.index
            document.layers[index].vectorMask = operation.mask
            document.layers[index].isVectorMaskEnabled = sourceLayer.isVectorMaskEnabled
            document.layers[index].isVectorMaskInverted = sourceLayer.isVectorMaskInverted
            document.layers[index].isMaskLinked = sourceLayer.isMaskLinked
        }
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.vectorMaskCopy"))
        statusText = L10n.format("imageEditor.status.vectorMaskCopied", plan.operations.count)
    }

    func rasterizeSelectedVectorMask() {
        let operations = vectorMaskRasterizeOperations(
            selectedIDs: selectedLayerIDsForVectorMaskRasterization
        )
        guard !operations.isEmpty else {
            statusText = L10n.text("imageEditor.status.vectorMaskRasterizeFailed")
            return
        }

        pushUndo()
        for operation in operations {
            document.layers[operation.index].mask = operation.mask
            document.layers[operation.index].vectorMask = nil
            document.layers[operation.index].isMaskEnabled = true
            document.layers[operation.index].isVectorMaskEnabled = true
            document.layers[operation.index].isVectorMaskInverted = false
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
        applyMasks(target: .raster)
    }

    func applyVectorMask() {
        applyMasks(target: .vector)
    }

    private func applyMasks(target: ImageEditorMaskApplicationTarget) {
        let operations = maskApplyIndices(target: target).compactMap { index -> (index: Int, layer: ImageEditorLayer)? in
            guard let layer = layerByApplyingMask(at: index, target: target) else { return nil }
            return (index, layer)
        }
        guard !operations.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let indices = operations.map(\.index)
        pushUndo()
        for operation in operations {
            document.layers[operation.index] = operation.layer
        }
        if target == .raster || document.selectedLayer?.mask == nil {
            isEditingLayerMask = false
        }

        if target == .raster {
            if indices.count == 1 {
                appendHistory(L10n.text("imageEditor.history.layerMaskApply"))
                statusText = L10n.text("imageEditor.status.layerMaskApplied")
            } else {
                appendHistory(L10n.text("imageEditor.history.layerMaskApplySelected"))
                statusText = L10n.format("imageEditor.status.layerMaskAppliedSelected", indices.count)
            }
        } else {
            if indices.count == 1 {
                appendHistory(L10n.text("imageEditor.history.vectorMaskApply"))
                statusText = L10n.text("imageEditor.status.vectorMaskApplied")
            } else {
                appendHistory(L10n.text("imageEditor.history.vectorMaskApplySelected"))
                statusText = L10n.format("imageEditor.status.vectorMaskAppliedSelected", indices.count)
            }
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
        let didApplySelection = applySelectionCandidate(selection, replaceHistoryKey: historyKey)
        if didApplySelection, document.selection != nil {
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
        let didApplySelection = applySelectionCandidate(selection, replaceHistoryKey: historyKey)
        if didApplySelection, document.selection != nil {
            statusText = selections.count == 1
                ? L10n.text("imageEditor.status.vectorMaskSelection")
                : L10n.format("imageEditor.status.vectorMaskSelectionSelected", selections.count)
        }
    }

    @discardableResult
    func loadSelectionFromLayerMask(
        layerID: UUID,
        mode: ImageEditorSelectionMode
    ) -> Bool {
        guard let layer = document.layers.first(where: { $0.id == layerID }),
              let mask = layer.mask,
              let selection = selectionFromLayerMask(mask, layer: layer)
        else {
            statusText = L10n.text("imageEditor.status.layerMaskSelectionFailed")
            return false
        }

        let didApplySelection = applySelectionCandidate(
            selection,
            replaceHistoryKey: "imageEditor.history.selectionFromLayerMask",
            mode: mode
        )
        if didApplySelection, document.selection != nil {
            statusText = L10n.text("imageEditor.status.layerMaskSelection")
        }
        return didApplySelection
    }

    @discardableResult
    func loadSelectionFromVectorMask(
        layerID: UUID,
        mode: ImageEditorSelectionMode
    ) -> Bool {
        guard let layer = document.layers.first(where: { $0.id == layerID }),
              let vectorMask = layer.vectorMask,
              vectorMask.kind == .path,
              vectorMask.isPathClosed,
              vectorMask.editablePathAnchors.count >= 3,
              let selection = selectionFromVectorMask(vectorMask, layer: layer)
        else {
            statusText = L10n.text("imageEditor.status.vectorMaskSelectionFailed")
            return false
        }

        let didApplySelection = applySelectionCandidate(
            selection,
            replaceHistoryKey: "imageEditor.history.selectionFromVectorMask",
            mode: mode
        )
        if didApplySelection, document.selection != nil {
            statusText = L10n.text("imageEditor.status.vectorMaskSelection")
        }
        return didApplySelection
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

    @discardableResult
    func toggleLayerMaskEnabled(layerID: UUID) -> Bool {
        guard let index = document.layers.firstIndex(where: { $0.id == layerID }),
              !document.isEffectivelyLocked(document.layers[index]),
              document.layers[index].mask != nil
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }

        pushUndo()
        document.layers[index].isMaskEnabled.toggle()
        let isEnabled = document.layers[index].isMaskEnabled
        appendHistory(L10n.text(
            isEnabled
                ? "imageEditor.history.layerMaskEnable"
                : "imageEditor.history.layerMaskDisable"
        ))
        statusText = L10n.text(
            isEnabled
                ? "imageEditor.status.layerMaskEnabled"
                : "imageEditor.status.layerMaskDisabled"
        )
        return true
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

    @discardableResult
    func toggleLayerMaskLinked(layerID: UUID) -> Bool {
        guard let index = document.layers.firstIndex(where: { $0.id == layerID }),
              !document.isEffectivelyLocked(document.layers[index]),
              document.layers[index].mask != nil || document.layers[index].vectorMask != nil
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }

        pushUndo()
        document.layers[index].isMaskLinked.toggle()
        let isLinked = document.layers[index].isMaskLinked
        appendHistory(L10n.text(
            isLinked
                ? "imageEditor.history.layerMaskLink"
                : "imageEditor.history.layerMaskUnlink"
        ))
        statusText = L10n.text(
            isLinked
                ? "imageEditor.status.layerMaskLinked"
                : "imageEditor.status.layerMaskUnlinked"
        )
        return true
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

    func toggleVectorMaskLinked() {
        let indices = vectorMaskToggleLinkedIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let linksMasks = !indices.contains { document.layers[$0].isMaskLinked }
        let changedIndices = indices.filter {
            document.layers[$0].isMaskLinked != linksMasks
        }
        pushUndo()
        for index in changedIndices {
            document.layers[index].isMaskLinked = linksMasks
        }

        if indices.count == 1 {
            appendHistory(L10n.text(
                linksMasks
                    ? "imageEditor.history.vectorMaskLink"
                    : "imageEditor.history.vectorMaskUnlink"
            ))
            statusText = L10n.text(
                linksMasks
                    ? "imageEditor.status.vectorMaskLinked"
                    : "imageEditor.status.vectorMaskUnlinked"
            )
        } else {
            appendHistory(L10n.text(
                linksMasks
                    ? "imageEditor.history.vectorMaskLinkSelected"
                    : "imageEditor.history.vectorMaskUnlinkSelected"
            ))
            statusText = L10n.format(
                linksMasks
                    ? "imageEditor.status.vectorMaskLinkedSelected"
                    : "imageEditor.status.vectorMaskUnlinkedSelected",
                changedIndices.count
            )
        }
    }

    func invertVectorMask() {
        let indices = vectorMaskInvertIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in indices {
            document.layers[index].isVectorMaskInverted.toggle()
        }

        if indices.count == 1 {
            appendHistory(L10n.text("imageEditor.history.vectorMaskInvert"))
            statusText = L10n.text("imageEditor.status.vectorMaskInverted")
        } else {
            appendHistory(L10n.text("imageEditor.history.vectorMaskInvertSelected"))
            statusText = L10n.format(
                "imageEditor.status.vectorMaskInvertedSelected",
                indices.count
            )
        }
    }

    @discardableResult
    func toggleVectorMaskEnabled(layerID: UUID) -> Bool {
        guard let index = document.layers.firstIndex(where: { $0.id == layerID }),
              !document.isEffectivelyLocked(document.layers[index]),
              document.layers[index].vectorMask != nil
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }

        pushUndo()
        document.layers[index].isVectorMaskEnabled.toggle()
        let isEnabled = document.layers[index].isVectorMaskEnabled
        appendHistory(L10n.text(
            isEnabled
                ? "imageEditor.history.vectorMaskEnable"
                : "imageEditor.history.vectorMaskDisable"
        ))
        statusText = L10n.text(
            isEnabled
                ? "imageEditor.status.vectorMaskEnabled"
                : "imageEditor.status.vectorMaskDisabled"
        )
        return true
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
            document.layers[index].isVectorMaskInverted = false
        }

        if indices.count == 1 {
            appendHistory(L10n.text("imageEditor.history.vectorMaskDelete"))
            statusText = L10n.text("imageEditor.status.vectorMaskDeleted")
        } else {
            appendHistory(L10n.text("imageEditor.history.vectorMaskDeleteSelected"))
            statusText = L10n.format("imageEditor.status.vectorMaskDeletedSelected", indices.count)
        }
    }

    private func maskApplyIndices(
        target: ImageEditorMaskApplicationTarget,
        selectedIDs explicitSelectedIDs: Set<UUID>? = nil
    ) -> [Int] {
        let selectedIDs = explicitSelectedIDs ?? (document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs)
        return document.layers.indices.filter { index in
            selectedIDs.contains(document.layers[index].id)
                && canApplyMask(to: document.layers[index], target: target)
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

    private func vectorMaskToggleEnabledIndices(
        selectedIDs explicitSelectedIDs: Set<UUID>? = nil
    ) -> [Int] {
        let selectedIDs = explicitSelectedIDs ?? (document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs)
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
                && layer.vectorMask != nil
        }
    }

    private func vectorMaskToggleLinkedIndices(
        selectedIDs explicitSelectedIDs: Set<UUID>? = nil
    ) -> [Int] {
        vectorMaskEditableIndices(selectedIDs: explicitSelectedIDs)
    }

    private func vectorMaskInvertIndices(
        selectedIDs explicitSelectedIDs: Set<UUID>? = nil
    ) -> [Int] {
        vectorMaskEditableIndices(selectedIDs: explicitSelectedIDs)
    }

    private func vectorMaskEditableIndices(
        selectedIDs explicitSelectedIDs: Set<UUID>? = nil
    ) -> [Int] {
        let selectedIDs = explicitSelectedIDs ?? (document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs)
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
                && layer.vectorMask != nil
        }
    }

    private func vectorMaskDeleteIndices(
        selectedIDs explicitSelectedIDs: Set<UUID>? = nil
    ) -> [Int] {
        let selectedIDs = explicitSelectedIDs ?? (document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs)
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
                && layer.vectorMask != nil
        }
    }

    private var selectedLayerIDsForVectorMaskRasterization: Set<UUID> {
        document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
    }

    private func vectorMaskRasterizeOperations(
        selectedIDs: Set<UUID>
    ) -> [(index: Int, mask: NSImage)] {
        return document.layers.indices.compactMap { index in
            let layer = document.layers[index]
            guard selectedIDs.contains(layer.id),
                  canRasterizeVectorMask(layer) else { return nil }
            // Bake at the same sampling density used by the preview, without
            // replacing source pixels, frame, style or the user's link state.
            let renderingLayer = layer.highResolutionMaskRenderingLayer()?.layer ?? layer
            guard let vectorMask = renderingLayer.vectorMask,
                  let vectorMaskImage = renderedVectorMask(vectorMask, layer: renderingLayer)
            else { return nil }
            return (index, (renderingLayer.effectiveMask ?? vectorMaskImage).normalizedBitmapImage())
        }
    }

    private func canRasterizeVectorMask(_ layer: ImageEditorLayer) -> Bool {
        guard let vectorMask = layer.vectorMask else { return false }
        return !document.isEffectivelyLocked(layer)
            && layer.isVectorMaskEnabled
            && (layer.mask == nil || layer.isMaskEnabled)
            && vectorMask.kind == .path
            && vectorMask.isPathClosed
            && vectorMask.editablePathAnchors.count >= 3
    }

    private func canApplyMask(
        to layer: ImageEditorLayer,
        target: ImageEditorMaskApplicationTarget
    ) -> Bool {
        guard !layer.isGroup,
              !layer.isAdjustment,
              !layer.isFilter,
              !layer.isSmartObject,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }

        switch target {
        case .raster:
            return layer.mask != nil
        case .vector:
            guard let vectorMask = layer.vectorMask else { return false }
            return !layer.isVectorMaskEnabled
                || renderedVectorMask(vectorMask, layer: layer) != nil
        }
    }

    private func layerByApplyingMask(at index: Int, target: ImageEditorMaskApplicationTarget) -> ImageEditorLayer? {
        let originalLayer = document.layers[index]
        let shouldBakeMask = target == .raster ? originalLayer.isMaskEnabled : originalLayer.isVectorMaskEnabled
        // Applying a mask must preserve the same detail as the preview. Retain
        // the promoted local coordinates/style for any mask that remains live.
        var layer = shouldBakeMask
            ? (originalLayer.highResolutionMaskRenderingLayer()?.layer ?? originalLayer)
            : originalLayer
        let mask: NSImage?
        switch target {
        case .raster:
            mask = layer.effectiveRasterMask
        case .vector:
            mask = shouldBakeMask
                ? layer.vectorMask.flatMap { renderedVectorMask($0, layer: layer) }
                : nil
        }

        if shouldBakeMask {
            guard let mask else { return nil }
            let sourceImage = layer.contentImage
            guard let bakedImage = sourceImage.applyingAlphaMask(mask) else { return nil }
            layer.image = bakedImage.normalizedBitmapImage()
            layer.kind = .pixel
            layer.smartFilters = []
            layer.xomoFigmaImageFill = nil
            layer.xomoFigmaImageFillSourceImage = nil
        }

        if target == .raster {
            layer.mask = nil
            layer.isMaskEnabled = true
            layer.maskDensity = 1
            layer.maskFeather = 0
        } else {
            layer.vectorMask = nil
            layer.isVectorMaskEnabled = true
            layer.isVectorMaskInverted = false
        }
        return layer
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

        let changedOperations = operations.filter { operation in
            document.layers[operation.index].mask?.hasEquivalentAlphaMask(to: operation.mask) != true
        }
        guard !changedOperations.isEmpty else {
            isEditingLayerMask = true
            statusText = L10n.text("imageEditor.status.layerMaskSelectionUnchanged")
            return
        }

        pushUndo()
        for operation in changedOperations {
            document.layers[operation.index].mask = operation.mask
        }
        isEditingLayerMask = true

        if changedOperations.count == 1 {
            appendHistory(L10n.text(combination.historyKey))
            statusText = L10n.text(combination.statusKey)
        } else {
            appendHistory(L10n.text(combination.selectedHistoryKey))
            statusText = L10n.format(combination.selectedStatusKey, changedOperations.count)
        }
    }

    private func layerMaskSelectionCombinationOperations(
        _ selection: ImageEditorSelection,
        combination: ImageEditorLayerMaskSelectionCombination,
        selectedIDs explicitSelectedIDs: Set<UUID>? = nil
    ) -> [(index: Int, mask: NSImage)] {
        guard selection.effectiveSelectedBounds(in: document.canvasSize) != nil else {
            return []
        }
        let selectedIDs = explicitSelectedIDs ?? (document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs)
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
        hidingSelection: Bool,
        selectedIDs explicitSelectedIDs: Set<UUID>? = nil
    ) -> [(index: Int, mask: NSImage)] {
        guard selection.effectiveSelectedBounds(in: document.canvasSize) != nil else {
            return []
        }
        let selectedIDs = explicitSelectedIDs ?? (document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs)
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

    private func layerMaskAddIndices(selectedIDs: Set<UUID>) -> [Int] {
        document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
                && layer.mask == nil
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
              let outputSize = ImageEditorMaskSampling.bitmapSize(CGSize(
                width: max(layer.image.size.width, layer.frame.width, layer.mask?.size.width ?? 0),
                height: max(layer.image.size.height, layer.frame.height, layer.mask?.size.height ?? 0)
              )),
              let canvasMask = canvasSelectionMask(for: selection)
        else { return nil }

        // Selection coordinates are top-left canvas pixels. AppKit crops in
        // bottom-left coordinates; retain canvas detail when the source is small.
        let sourceRect = CGRect(x: layer.frame.minX, y: document.canvasSize.height - layer.frame.maxY,
                                width: layer.frame.width, height: layer.frame.height)
        return NSImage.rendered(size: outputSize) { _ in
            canvasMask.draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: sourceRect,
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
        _ selection: ImageEditorSelection,
        selectedIDs explicitSelectedIDs: Set<UUID>? = nil
    ) -> [(index: Int, vectorMask: ImageEditorShapeContent)] {
        guard !selection.isInverted, selection.points.count >= 3 else { return [] }
        let selectedIDs = explicitSelectedIDs ?? (document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs)
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

    private func layerMaskCopyOperations(
        sourceID: UUID,
        selectedIDs: Set<UUID>
    ) -> (sourceIndex: Int, operations: [(index: Int, mask: NSImage)])? {
        guard let sourceIndex = document.layers.firstIndex(where: { $0.id == sourceID }),
              let sourceMask = document.layers[sourceIndex].mask
        else { return nil }
        let sourceLayer = document.layers[sourceIndex]
        let targetIndices = layerMaskCopyTargetIndices(
            sourceID: sourceID,
            selectedIDs: selectedIDs
        )
        let operations = targetIndices.compactMap { index -> (index: Int, mask: NSImage)? in
            let targetLayer = document.layers[index]
            let targetSize = maskSize(for: targetLayer)
            let targetMask = (sourceMask.resized(to: targetSize) ?? sourceMask).normalizedBitmapImage()
            let isEquivalent = targetLayer.mask?.hasEquivalentAlphaMask(to: targetMask) == true
                && targetLayer.isMaskEnabled == sourceLayer.isMaskEnabled
                && targetLayer.isMaskLinked == sourceLayer.isMaskLinked
                && targetLayer.maskDensity == sourceLayer.maskDensity
                && targetLayer.maskFeather == sourceLayer.maskFeather
            return isEquivalent ? nil : (index, targetMask)
        }
        return (sourceIndex, operations)
    }

    private func layerMaskCopyTargetIndices(
        sourceID: UUID,
        selectedIDs explicitSelectedIDs: Set<UUID>? = nil
    ) -> [Int] {
        let selectedIDs = explicitSelectedIDs ?? document.selectedLayerIDs
        let targetIDs = selectedIDs.subtracting([sourceID])
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return targetIDs.contains(layer.id) && !document.isEffectivelyLocked(layer)
        }
    }

    private func vectorMaskCopyOperations(
        sourceID: UUID,
        selectedIDs: Set<UUID>
    ) -> (
        sourceIndex: Int,
        operations: [(index: Int, mask: ImageEditorShapeContent)]
    )? {
        guard let sourceIndex = document.layers.firstIndex(where: { $0.id == sourceID }),
              let sourceMask = document.layers[sourceIndex].vectorMask
        else { return nil }
        let targetIndices = layerMaskCopyTargetIndices(
            sourceID: sourceID,
            selectedIDs: selectedIDs
        )
        guard !targetIndices.isEmpty else { return nil }

        let sourceLayer = document.layers[sourceIndex]
        let sourceSize = maskSize(for: sourceLayer)
        let operations = targetIndices.compactMap { index -> (
            index: Int,
            mask: ImageEditorShapeContent
        )? in
            let targetLayer = document.layers[index]
            let targetSize = maskSize(for: targetLayer)
            let targetMask = scaledVectorMask(
                sourceMask,
                from: sourceSize,
                to: targetSize
            )
            let isEquivalent = targetLayer.vectorMask.map {
                ImageEditorProjectShapeContent(content: $0)
                    == ImageEditorProjectShapeContent(content: targetMask)
            } == true
                && targetLayer.isVectorMaskEnabled == sourceLayer.isVectorMaskEnabled
                && targetLayer.isVectorMaskInverted == sourceLayer.isVectorMaskInverted
                && targetLayer.isMaskLinked == sourceLayer.isMaskLinked
            return isEquivalent ? nil : (index, targetMask)
        }
        return (sourceIndex, operations)
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
        let size = maskSize(for: layer)
        return vectorMask
            .normalized(size: size)
            .renderedVectorMask(size: size, inverted: layer.isVectorMaskInverted)
    }

    func canvasMaskImage(fromLayerMask mask: NSImage, layer: ImageEditorLayer) -> NSImage? {
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
                in: CGRect(x: layer.frame.minX, y: document.canvasSize.height - layer.frame.maxY,
                           width: layer.frame.width, height: layer.frame.height),
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
