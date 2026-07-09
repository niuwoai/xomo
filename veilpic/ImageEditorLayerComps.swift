//
//  ImageEditorLayerComps.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    var selectedLayerComp: ImageEditorLayerComp? {
        guard let selectedLayerCompID = document.selectedLayerCompID else { return nil }
        return document.layerComps.first { $0.id == selectedLayerCompID }
    }

    var canApplySelectedLayerComp: Bool {
        selectedLayerComp != nil
    }

    var canUpdateSelectedLayerComp: Bool {
        selectedLayerComp != nil
    }

    var canDuplicateSelectedLayerComp: Bool {
        selectedLayerComp != nil
    }

    var canDeleteSelectedLayerComp: Bool {
        selectedLayerComp != nil
    }

    var canSelectPreviousLayerComp: Bool {
        selectedLayerCompIndex.map { $0 > 0 } ?? false
    }

    var canSelectNextLayerComp: Bool {
        selectedLayerCompIndex.map { $0 < document.layerComps.count - 1 } ?? false
    }

    func addLayerComp(named proposedName: String? = nil) {
        let name = normalizedLayerCompName(proposedName, fallbackIndex: document.layerComps.count + 1)
        pushUndo()
        let comp = ImageEditorLayerComp.capture(name: name, document: document)
        document.layerComps.append(comp)
        document.selectedLayerCompID = comp.id
        appendHistory(L10n.text("imageEditor.history.layerCompNew"))
        statusText = L10n.format("imageEditor.status.layerCompSaved", comp.name)
    }

    func applyLayerComp(_ id: UUID) {
        guard let comp = document.layerComps.first(where: { $0.id == id }) else { return }
        let statesByLayerID = Dictionary(uniqueKeysWithValues: comp.layerStates.map { ($0.layerID, $0) })
        guard document.layers.contains(where: { statesByLayerID[$0.id] != nil }) else {
            statusText = L10n.text("imageEditor.status.layerCompNoMatchingLayers")
            return
        }

        pushUndo()
        let existingLayerIDs = Set(document.layers.map(\.id))
        let existingGroupIDs = Set(document.layers.filter(\.isGroup).map(\.id))
        for index in document.layers.indices {
            guard let state = statesByLayerID[document.layers[index].id] else { continue }
            document.layers[index].isVisible = state.isVisible
            document.layers[index].frame = state.frame
            document.layers[index].opacity = max(0, min(1, state.opacity))
            document.layers[index].fillOpacity = max(0, min(1, state.fillOpacity))
            document.layers[index].isMaskLinked = state.isMaskLinked
            document.layers[index].blendIfSourceBlack = max(0, min(1, state.blendIfSourceBlack))
            document.layers[index].blendIfSourceWhite = max(
                document.layers[index].blendIfSourceBlack,
                min(1, state.blendIfSourceWhite)
            )
            document.layers[index].blendIfUnderlyingBlack = max(0, min(1, state.blendIfUnderlyingBlack))
            document.layers[index].blendIfUnderlyingWhite = max(
                document.layers[index].blendIfUnderlyingBlack,
                min(1, state.blendIfUnderlyingWhite)
            )
            document.layers[index].isMaskEnabled = state.isMaskEnabled
            document.layers[index].maskDensity = max(0, min(1, state.maskDensity))
            document.layers[index].maskFeather = max(0, min(80, state.maskFeather))
            if state.hasMaskSnapshot {
                if let maskData = state.maskData {
                    if let mask = NSImage(data: maskData)?.normalizedBitmapImage() {
                        document.layers[index].mask = mask
                    }
                } else {
                    document.layers[index].mask = nil
                }
            }
            document.layers[index].isVectorMaskEnabled = state.isVectorMaskEnabled
            document.layers[index].style = state.style.layerStyle
            document.layers[index].blendMode = state.blendMode
            if let kind = state.kind {
                document.layers[index].kind = kind.layerKind
            }
            if let smartFilters = state.smartFilters {
                document.layers[index].smartFilters = smartFilters
            }
            if let adjustmentSettings = state.adjustmentSettings {
                document.layers[index].adjustmentSettings = adjustmentSettings.normalized()
            }
            if let filterSettings = state.filterSettings {
                document.layers[index].filterSettings = filterSettings.normalized()
            }
            if state.hasVectorMaskSnapshot {
                document.layers[index].vectorMask = state.vectorMask?.content
            }
            document.layers[index].linkedLayerIDs = state.linkedLayerIDs
                .intersection(existingLayerIDs)
                .subtracting([document.layers[index].id])
            if let groupID = state.groupID,
               groupID != document.layers[index].id,
               existingGroupIDs.contains(groupID) {
                document.layers[index].groupID = groupID
            } else {
                document.layers[index].groupID = nil
            }
            document.layers[index].isLocked = state.isLocked
            document.layers[index].locksPixels = state.locksPixels
            document.layers[index].locksPosition = state.locksPosition
            document.layers[index].locksTransparentPixels = state.locksTransparentPixels
            document.layers[index].isGroupExpanded = state.isGroupExpanded
            document.layers[index].isClippingMask = state.isClippingMask
            document.layers[index].labelColor = state.labelColor
        }
        restoreLayerOrder(from: comp.layerOrder)

        let existingIDs = Set(document.layers.map(\.id))
        document.selectedLayerID = comp.selectedLayerID.flatMap { existingIDs.contains($0) ? $0 : nil }
            ?? document.selectedLayerID.flatMap { existingIDs.contains($0) ? $0 : nil }
            ?? document.layers.last?.id
        document.selectedLayerIDs = comp.selectedLayerIDs.intersection(existingIDs)
        if let selectedLayerID = document.selectedLayerID {
            document.selectedLayerIDs.insert(selectedLayerID)
        }
        document.selectedLayerCompID = comp.id
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerCompApply"))
        statusText = L10n.format("imageEditor.status.layerCompApplied", comp.name)
    }

    func applySelectedLayerComp() {
        guard let selectedLayerComp else { return }
        applyLayerComp(selectedLayerComp.id)
    }

    func updateLayerComp(_ id: UUID) {
        guard let index = document.layerComps.firstIndex(where: { $0.id == id }) else { return }
        let name = document.layerComps[index].name
        pushUndo()
        var updated = ImageEditorLayerComp.capture(name: name, document: document)
        updated.id = id
        updated.createdAt = document.layerComps[index].createdAt
        document.layerComps[index] = updated
        document.selectedLayerCompID = id
        appendHistory(L10n.text("imageEditor.history.layerCompUpdate"))
        statusText = L10n.format("imageEditor.status.layerCompUpdated", name)
    }

    func updateSelectedLayerComp() {
        guard let selectedLayerComp else { return }
        updateLayerComp(selectedLayerComp.id)
    }

    func duplicateSelectedLayerComp() {
        guard let selectedLayerComp else { return }
        pushUndo()
        var duplicated = selectedLayerComp
        duplicated.id = UUID()
        duplicated.name = duplicateLayerCompName(for: selectedLayerComp.name)
        duplicated.createdAt = Date()
        if let selectedIndex = selectedLayerCompIndex {
            document.layerComps.insert(duplicated, at: selectedIndex + 1)
        } else {
            document.layerComps.append(duplicated)
        }
        document.selectedLayerCompID = duplicated.id
        appendHistory(L10n.text("imageEditor.history.layerCompDuplicate"))
        statusText = L10n.format("imageEditor.status.layerCompDuplicated", duplicated.name)
    }

    func renameLayerComp(_ id: UUID, to proposedName: String) {
        guard let index = document.layerComps.firstIndex(where: { $0.id == id }) else { return }
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerCompNameInvalid")
            return
        }
        guard document.layerComps[index].name != trimmedName else { return }
        pushUndo()
        document.layerComps[index].name = trimmedName
        document.selectedLayerCompID = id
        appendHistory(L10n.text("imageEditor.history.layerCompRename"))
        statusText = L10n.format("imageEditor.status.layerCompRenamed", trimmedName)
    }

    func deleteLayerComp(_ id: UUID) {
        guard let comp = document.layerComps.first(where: { $0.id == id }) else { return }
        pushUndo()
        document.layerComps.removeAll { $0.id == id }
        if document.selectedLayerCompID == id {
            document.selectedLayerCompID = document.layerComps.last?.id
        }
        appendHistory(L10n.text("imageEditor.history.layerCompDelete"))
        statusText = L10n.format("imageEditor.status.layerCompDeleted", comp.name)
    }

    func deleteSelectedLayerComp() {
        guard let selectedLayerComp else { return }
        deleteLayerComp(selectedLayerComp.id)
    }

    func selectLayerComp(_ id: UUID) {
        guard let comp = document.layerComps.first(where: { $0.id == id }) else { return }
        document.selectedLayerCompID = id
        statusText = L10n.format("imageEditor.status.layerCompSelected", comp.name)
    }

    func selectPreviousLayerComp() {
        guard canSelectPreviousLayerComp, let selectedLayerCompIndex else { return }
        selectLayerComp(document.layerComps[selectedLayerCompIndex - 1].id)
    }

    func selectNextLayerComp() {
        guard canSelectNextLayerComp, let selectedLayerCompIndex else { return }
        selectLayerComp(document.layerComps[selectedLayerCompIndex + 1].id)
    }

    func layerCompSummary(_ comp: ImageEditorLayerComp) -> String {
        L10n.format("imageEditor.layerComp.summary", comp.layerStates.count)
    }

    private func normalizedLayerCompName(_ proposedName: String?, fallbackIndex: Int) -> String {
        let trimmedName = (proposedName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return L10n.format("imageEditor.layerComp.defaultName", fallbackIndex)
        }
        return trimmedName
    }

    private var selectedLayerCompIndex: Int? {
        guard let selectedLayerCompID = document.selectedLayerCompID else { return nil }
        return document.layerComps.firstIndex { $0.id == selectedLayerCompID }
    }

    private func duplicateLayerCompName(for sourceName: String) -> String {
        let existingNames = Set(document.layerComps.map(\.name))
        let baseName = L10n.format("imageEditor.layerComp.copyName", sourceName)
        guard existingNames.contains(baseName) else { return baseName }

        var suffix = 2
        while true {
            let candidate = L10n.format("imageEditor.layerComp.copyNameIndexed", sourceName, suffix)
            if !existingNames.contains(candidate) {
                return candidate
            }
            suffix += 1
        }
    }

    private func restoreLayerOrder(from layerOrder: [UUID]) {
        let orderIndexByID = Dictionary(uniqueKeysWithValues: layerOrder.enumerated().map { ($0.element, $0.offset) })
        guard !orderIndexByID.isEmpty else { return }

        let capturedLayers = document.layers
            .filter { orderIndexByID[$0.id] != nil }
            .sorted { left, right in
                (orderIndexByID[left.id] ?? Int.max) < (orderIndexByID[right.id] ?? Int.max)
            }
        let uncapturedLayers = document.layers.filter { orderIndexByID[$0.id] == nil }
        document.layers = capturedLayers + uncapturedLayers
    }
}
