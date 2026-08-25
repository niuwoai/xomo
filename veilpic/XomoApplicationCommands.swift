//
//  XomoApplicationCommands.swift
//  veilpic
//
//  Created by Codex on 2026/8/24.
//

import SwiftUI

struct XomoFileCommandActions {
    let createCanvas: () -> Void
    let createCanvasFromClipboard: () -> Void
    let canCreateCanvasFromClipboard: Bool
    let openProject: () -> Void
    let saveProject: () -> Void
    let showPSDCompatibilityReport: () -> Void
    let canShowPSDCompatibilityReport: Bool
    let importFile: () -> Void
    let placeEmbeddedSmartObject: () -> Void
    let importFigmaLink: () -> Void
    let export: () -> Void
    let exportSelection: () -> Void
    let canExportSelection: Bool
    let createSlice: () -> Void
    let canCreateSlice: Bool
    let createHotspot: () -> Void
    let canCreateHotspot: Bool
    let exportHotspotHTML: () -> Void
    let canExportHotspotHTML: Bool
    let exportSelectedLayers: () -> Void
    let canExportSelectedLayers: Bool
    let apply: () -> Void
    let cancel: () -> Void
}

enum XomoFileMenuItem: CaseIterable, Hashable {
    case createCanvas
    case createCanvasFromClipboard
    case openProject
    case saveProject
    case psdCompatibilityReport
    case importExportDivider
    case importFile
    case placeEmbeddedSmartObject
    case importFigmaLink
    case export
    case exportSelection
    case createSlice
    case createHotspot
    case exportHotspotHTML
    case exportSelectedLayers
    case completionDivider
    case apply
    case cancel
}

private struct XomoFileCommandActionsKey: FocusedValueKey {
    typealias Value = XomoFileCommandActions
}

extension FocusedValues {
    var xomoFileCommandActions: XomoFileCommandActions? {
        get { self[XomoFileCommandActionsKey.self] }
        set { self[XomoFileCommandActionsKey.self] = newValue }
    }
}

struct XomoFileCommands: Commands {
    @FocusedValue(\.xomoFileCommandActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            XomoFileMenuItems(actions: actions)
        }

        CommandGroup(replacing: .saveItem) {
            EmptyView()
        }
    }
}

struct XomoEditCommandActions {
    let undo: () -> Void
    let canUndo: Bool
    let redo: () -> Void
    let canRedo: Bool
    let createHistorySnapshot: () -> Void
    let restoreSelectedHistorySnapshot: () -> Void
    let canRestoreSelectedHistorySnapshot: Bool
    let duplicateSelectedHistorySnapshot: () -> Void
    let canDuplicateSelectedHistorySnapshot: Bool
    let deleteSelectedHistorySnapshot: () -> Void
    let canDeleteSelectedHistorySnapshot: Bool
    let selectPreviousHistorySnapshot: () -> Void
    let canSelectPreviousHistorySnapshot: Bool
    let selectNextHistorySnapshot: () -> Void
    let canSelectNextHistorySnapshot: Bool
    let clearHistory: () -> Void
    let cutSelection: () -> Void
    let canCutSelection: Bool
    let copySelection: () -> Void
    let canCopySelection: Bool
    let copyMerged: () -> Void
    let canCopyMerged: Bool
    let copySelectedLayers: () -> Void
    let canCopySelectedLayers: Bool
    let pasteAsLayer: () -> Void
    let canPasteAsLayer: Bool
    let pasteIntoSelection: () -> Void
    let canPasteIntoSelection: Bool
    let pasteInPlace: () -> Void
    let canPasteInPlace: Bool
    let toggleFreeTransform: () -> Void
    let presentFillDialog: () -> Void
    let canPresentFillDialog: Bool
    let fillSelection: () -> Void
    let canFillSelection: Bool
    let fillSelectionWithBackground: () -> Void
    let fillSelectionFromHistory: () -> Void
    let canFillSelectionFromHistory: Bool
    let contentAwareFill: () -> Void
    let canEditSelectionPixels: Bool
    let strokeSelection: () -> Void
    let copySelectionToLayer: () -> Void
    let canCopySelectionToLayer: Bool
    let copyMergedToLayer: () -> Void
    let canCopyMergedToLayer: Bool
    let cutSelectionToLayer: () -> Void
    let canCutSelectionToLayer: Bool
    let deleteSelectedObject: () -> Void
    let canDeleteSelectedObject: Bool
}

private struct XomoEditCommandActionsKey: FocusedValueKey {
    typealias Value = XomoEditCommandActions
}

extension FocusedValues {
    var xomoEditCommandActions: XomoEditCommandActions? {
        get { self[XomoEditCommandActionsKey.self] }
        set { self[XomoEditCommandActionsKey.self] = newValue }
    }
}

struct XomoEditCommands: Commands {
    @FocusedValue(\.xomoEditCommandActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            XomoEditMenuItems(actions: actions)
        }
        CommandGroup(replacing: .pasteboard) {
            EmptyView()
        }
        CommandGroup(replacing: .textEditing) {
            EmptyView()
        }
        CommandGroup(replacing: .textFormatting) {
            EmptyView()
        }
    }
}

struct XomoEditMenuItems: View {
    let actions: XomoEditCommandActions?

    var body: some View {
        Button(L10n.text("imageEditor.action.undo")) {
            actions?.undo()
        }
        .keyboardShortcut("z", modifiers: [.command])
        .disabled(actions?.canUndo != true)
        Button(L10n.text("imageEditor.action.redo")) {
            actions?.redo()
        }
        .keyboardShortcut("z", modifiers: [.command, .shift])
        .disabled(actions?.canRedo != true)
        Divider()
        historySnapshotMenu
        Button(L10n.text("imageEditor.action.historyClear")) {
            actions?.clearHistory()
        }
        .disabled(actions == nil)
        Divider()
        Button(L10n.text("imageEditor.action.cutSelectionClipboard")) {
            actions?.cutSelection()
        }
        .keyboardShortcut("x", modifiers: [.command])
        .disabled(actions?.canCutSelection != true)
        Button(L10n.text("imageEditor.action.copySelectionClipboard")) {
            actions?.copySelection()
        }
        .keyboardShortcut("c", modifiers: [.command])
        .disabled(actions?.canCopySelection != true)
        Button(L10n.text("imageEditor.action.copyMergedClipboard")) {
            actions?.copyMerged()
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])
        .disabled(actions?.canCopyMerged != true)
        Button(L10n.text("imageEditor.action.copySelectedLayersClipboard")) {
            actions?.copySelectedLayers()
        }
        .keyboardShortcut("c", modifiers: [.command, .option, .shift])
        .disabled(actions?.canCopySelectedLayers != true)
        Button(L10n.text("imageEditor.action.pasteClipboardLayer")) {
            actions?.pasteAsLayer()
        }
        .keyboardShortcut("v", modifiers: [.command])
        .disabled(actions?.canPasteAsLayer != true)
        Button(L10n.text("imageEditor.action.pasteClipboardIntoSelection")) {
            actions?.pasteIntoSelection()
        }
        .keyboardShortcut("v", modifiers: [.command, .shift])
        .disabled(actions?.canPasteIntoSelection != true)
        Button(L10n.text("imageEditor.action.pasteClipboardInPlaceLayer")) {
            actions?.pasteInPlace()
        }
        .keyboardShortcut("v", modifiers: [.command, .option, .shift])
        .disabled(actions?.canPasteInPlace != true)
        Button(L10n.text("imageEditor.action.freeTransform")) {
            actions?.toggleFreeTransform()
        }
        .keyboardShortcut("t", modifiers: [.command])
        .disabled(actions == nil)
        Divider()
        Button(L10n.text("imageEditor.action.fillDialog")) {
            actions?.presentFillDialog()
        }
        .keyboardShortcut(KeyEquivalent("\u{F708}"), modifiers: [.shift])
        .disabled(actions?.canPresentFillDialog != true)
        Button(L10n.text("imageEditor.action.fillSelection")) {
            actions?.fillSelection()
        }
        .keyboardShortcut(.delete, modifiers: [.option])
        .disabled(actions?.canFillSelection != true)
        Button(L10n.text("imageEditor.action.fillSelectionBackground")) {
            actions?.fillSelectionWithBackground()
        }
        .keyboardShortcut(.delete, modifiers: [.command])
        .disabled(actions?.canFillSelection != true)
        Button(L10n.text("imageEditor.action.fillSelectionHistory")) {
            actions?.fillSelectionFromHistory()
        }
        .keyboardShortcut(.delete, modifiers: [.command, .option])
        .disabled(actions?.canFillSelectionFromHistory != true)
        Button(L10n.text("imageEditor.action.contentAwareFillSelection")) {
            actions?.contentAwareFill()
        }
        .disabled(actions?.canEditSelectionPixels != true)
        Button(L10n.text("imageEditor.action.strokeSelection")) {
            actions?.strokeSelection()
        }
        .disabled(actions?.canEditSelectionPixels != true)
        Button(L10n.text("imageEditor.action.selectionCopyLayer")) {
            actions?.copySelectionToLayer()
        }
        .disabled(actions?.canCopySelectionToLayer != true)
        Button(L10n.text("imageEditor.action.selectionCopyMergedLayer")) {
            actions?.copyMergedToLayer()
        }
        .disabled(actions?.canCopyMergedToLayer != true)
        Button(L10n.text("imageEditor.action.selectionCutLayer")) {
            actions?.cutSelectionToLayer()
        }
        .disabled(actions?.canCutSelectionToLayer != true)
        Button(L10n.text("imageEditor.action.deleteSelectedObject")) {
            actions?.deleteSelectedObject()
        }
        .keyboardShortcut(.delete, modifiers: [])
        .disabled(actions?.canDeleteSelectedObject != true)
    }

    private var historySnapshotMenu: some View {
        Menu(L10n.text("imageEditor.menu.edit.historySnapshots")) {
            Button(L10n.text("imageEditor.action.historySnapshotCreate")) {
                actions?.createHistorySnapshot()
            }
            .disabled(actions == nil)
            Divider()
            Button(L10n.text("imageEditor.action.historySnapshotRestoreSelected")) {
                actions?.restoreSelectedHistorySnapshot()
            }
            .disabled(actions?.canRestoreSelectedHistorySnapshot != true)
            Button(L10n.text("imageEditor.action.historySnapshotDuplicate")) {
                actions?.duplicateSelectedHistorySnapshot()
            }
            .disabled(actions?.canDuplicateSelectedHistorySnapshot != true)
            Button(L10n.text("imageEditor.action.historySnapshotDeleteSelected")) {
                actions?.deleteSelectedHistorySnapshot()
            }
            .disabled(actions?.canDeleteSelectedHistorySnapshot != true)
            Divider()
            Button(L10n.text("imageEditor.action.historySnapshotPrevious")) {
                actions?.selectPreviousHistorySnapshot()
            }
            .disabled(actions?.canSelectPreviousHistorySnapshot != true)
            Button(L10n.text("imageEditor.action.historySnapshotNext")) {
                actions?.selectNextHistorySnapshot()
            }
            .disabled(actions?.canSelectNextHistorySnapshot != true)
        }
    }
}

struct XomoFileMenuItems: View {
    let actions: XomoFileCommandActions?

    var body: some View {
        ForEach(XomoFileMenuItem.allCases, id: \.self) { item in
            menuItem(item)
        }
    }

    @ViewBuilder
    private func menuItem(_ item: XomoFileMenuItem) -> some View {
        switch item {
        case .createCanvas:
            Button(L10n.text("imageEditor.action.canvasNew")) {
                actions?.createCanvas()
            }
            .keyboardShortcut("n", modifiers: [.command])
            .disabled(actions == nil)
        case .createCanvasFromClipboard:
            Button(L10n.text("imageEditor.action.canvasNewFromClipboard")) {
                actions?.createCanvasFromClipboard()
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
            .disabled(actions?.canCreateCanvasFromClipboard != true)
        case .openProject:
            Button(L10n.text("imageEditor.action.projectOpen")) {
                actions?.openProject()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(actions == nil)
        case .saveProject:
            Button(L10n.text("imageEditor.action.projectSave")) {
                actions?.saveProject()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(actions == nil)
        case .psdCompatibilityReport:
            Button(L10n.text("imageEditor.action.psdCompatibilityReport")) {
                actions?.showPSDCompatibilityReport()
            }
            .disabled(actions?.canShowPSDCompatibilityReport != true)
        case .importExportDivider, .completionDivider:
            Divider()
        case .importFile:
            Button(L10n.text("imageEditor.action.fileImport")) {
                actions?.importFile()
            }
            .disabled(actions == nil)
        case .placeEmbeddedSmartObject:
            Button(L10n.text("imageEditor.action.placeEmbeddedSmartObject")) {
                actions?.placeEmbeddedSmartObject()
            }
            .disabled(actions == nil)
        case .importFigmaLink:
            Button(L10n.text("imageEditor.action.figmaLinkImport")) {
                actions?.importFigmaLink()
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            .disabled(actions == nil)
        case .export:
            Button(L10n.text("imageEditor.action.export")) {
                actions?.export()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift, .option])
            .disabled(actions == nil)
        case .exportSelection:
            Button(L10n.text("imageEditor.action.exportSelection")) {
                actions?.exportSelection()
            }
            .keyboardShortcut("e", modifiers: [.command, .option])
            .disabled(actions?.canExportSelection != true)
        case .createSlice:
            Button(L10n.text("imageEditor.action.sliceCreate")) {
                actions?.createSlice()
            }
            .keyboardShortcut("k", modifiers: [.command, .option])
            .disabled(actions?.canCreateSlice != true)
        case .createHotspot:
            Button(L10n.text("imageEditor.action.hotspotCreate")) {
                actions?.createHotspot()
            }
            .keyboardShortcut("h", modifiers: [.command, .option])
            .disabled(actions?.canCreateHotspot != true)
        case .exportHotspotHTML:
            Button(L10n.text("imageEditor.action.hotspotHTMLExport")) {
                actions?.exportHotspotHTML()
            }
            .keyboardShortcut("h", modifiers: [.command, .option, .shift])
            .disabled(actions?.canExportHotspotHTML != true)
        case .exportSelectedLayers:
            Button(L10n.text("imageEditor.action.exportLayers")) {
                actions?.exportSelectedLayers()
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
            .disabled(actions?.canExportSelectedLayers != true)
        case .apply:
            Button(L10n.text("imageEditor.action.apply")) {
                actions?.apply()
            }
            .disabled(actions == nil)
        case .cancel:
            Button(L10n.text("imageEditor.action.cancel")) {
                actions?.cancel()
            }
            .disabled(actions == nil)
        }
    }
}
