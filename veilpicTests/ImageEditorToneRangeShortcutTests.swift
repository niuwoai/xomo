//
//  ImageEditorToneRangeShortcutTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/19.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorToneRangeShortcutTests {
    private let modifiers: NSEvent.ModifierFlags = [.shift, .option]

    @Test func resolvesPhotoshopRangeKeysForDodgeAndBurn() {
        for tool in [ImageEditorTool.dodge, .burn] {
            #expect(resolve("s", tool: tool) == .shadows)
            #expect(resolve("M", tool: tool) == .midtones)
            #expect(resolve("h", tool: tool) == .highlights)
        }
    }

    @Test func rejectsRangeKeysOutsideToneBrushesOrWithDifferentModifiers() {
        #expect(resolve("s", tool: .move) == nil)
        #expect(resolve("m", tool: nil) == nil)
        #expect(resolve("x", tool: .dodge) == nil)
        #expect(ImageEditorToneRangeShortcut.resolve(
            charactersIgnoringModifiers: "h",
            modifierFlags: [.shift],
            activeTool: .burn
        ) == nil)
        #expect(ImageEditorToneRangeShortcut.resolve(
            charactersIgnoringModifiers: "h",
            modifierFlags: [.command, .shift, .option],
            activeTool: .burn
        ) == nil)
    }

    @Test func editorActionKeepsToneRangeShortcutsOutOfTextInput() {
        let action = ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "s",
            modifierFlags: modifiers,
            activeTool: .dodge
        )

        #expect(action == .toneRange(.shadows))
        #expect(action?.isBlockedByTextInput == true)
        #expect(!ImageEditorKeyboardShortcutAction.openProject.isBlockedByTextInput)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "s",
            modifierFlags: modifiers,
            activeTool: .move
        ) == nil)
    }

    @Test func viewModelAppliesRangeAndReportsTheStandardShortcut() {
        let viewModel = makeViewModel()
        viewModel.selectTool(.dodge)

        #expect(viewModel.applyToneRangeShortcut(.shadows))
        #expect(viewModel.toneRange == .shadows)
        #expect(viewModel.statusText.contains(ImageEditorToneRange.shadows.title))
        #expect(viewModel.statusText.contains("⇧⌥S"))

        viewModel.selectTool(.burn)
        #expect(viewModel.applyToneRangeShortcut(.highlights))
        #expect(viewModel.toneRange == .highlights)
        #expect(viewModel.statusText.contains("⇧⌥H"))
    }

    @Test func componentLibraryDoesNotInheritThePreviousToneBrushShortcut() {
        let viewModel = makeViewModel()
        viewModel.selectTool(.dodge)
        viewModel.toneRange = .midtones
        viewModel.selectLeftSidebarTab(.components)

        #expect(viewModel.canvasInteractionTool == .move)
        #expect(!viewModel.applyToneRangeShortcut(.shadows))
        #expect(viewModel.toneRange == .midtones)
    }

    private func resolve(_ key: String, tool: ImageEditorTool?) -> ImageEditorToneRange? {
        ImageEditorToneRangeShortcut.resolve(
            charactersIgnoringModifiers: key,
            modifierFlags: modifiers,
            activeTool: tool
        )
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "Tone Range Shortcuts",
            image: NSImage.transparent(size: CGSize(width: 32, height: 24)),
            onApply: { _ in }
        )
    }
}
