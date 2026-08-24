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
    let importFile: () -> Void
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
            Button(L10n.text("imageEditor.action.canvasNew")) {
                actions?.createCanvas()
            }
            .keyboardShortcut("n", modifiers: [.command])
            .disabled(actions == nil)

            Button(L10n.text("imageEditor.action.canvasNewFromClipboard")) {
                actions?.createCanvasFromClipboard()
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
            .disabled(actions?.canCreateCanvasFromClipboard != true)

            Divider()

            Button(L10n.text("imageEditor.action.projectOpen")) {
                actions?.openProject()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(actions == nil)
        }

        CommandGroup(replacing: .saveItem) {
            Button(L10n.text("imageEditor.action.projectSave")) {
                actions?.saveProject()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(actions == nil)
        }

        CommandGroup(after: .saveItem) {
            Divider()
            Button(L10n.text("imageEditor.action.fileImport")) {
                actions?.importFile()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(actions == nil)
        }
    }
}
