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
