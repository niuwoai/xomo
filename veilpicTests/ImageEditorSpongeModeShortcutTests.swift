//
//  ImageEditorSpongeModeShortcutTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/19.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSpongeModeShortcutTests {
    private let modifiers: NSEvent.ModifierFlags = [.shift, .option]

    @Test func resolvesPhotoshopSpongeModeKeys() {
        #expect(resolve("s", tool: .sponge) == .saturate)
        #expect(resolve("D", tool: .sponge) == .desaturate)
        #expect(ImageEditorSpongeModeShortcut.displayLabel(for: .saturate) == "⇧⌥S")
        #expect(ImageEditorSpongeModeShortcut.displayLabel(for: .desaturate) == "⇧⌥D")
    }

    @Test func rejectsSpongeModeKeysOutsideSpongeOrWithDifferentModifiers() {
        #expect(resolve("s", tool: .dodge) == nil)
        #expect(resolve("d", tool: .move) == nil)
        #expect(resolve("x", tool: .sponge) == nil)
        #expect(ImageEditorSpongeModeShortcut.resolve(
            charactersIgnoringModifiers: "s",
            modifierFlags: [.shift],
            activeTool: .sponge
        ) == nil)
        #expect(ImageEditorSpongeModeShortcut.resolve(
            charactersIgnoringModifiers: "d",
            modifierFlags: [.command, .shift, .option],
            activeTool: .sponge
        ) == nil)
    }

    @Test func editorActionKeepsSpongeModeShortcutsOutOfTextInput() {
        let action = ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "d",
            modifierFlags: modifiers,
            activeTool: .sponge
        )

        #expect(action == .spongeMode(.desaturate))
        #expect(action?.isBlockedByTextInput == true)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "s",
            modifierFlags: modifiers,
            activeTool: .dodge
        ) == .toneRange(.shadows))
    }

    @Test func viewModelAppliesModeAndReportsTheStandardShortcut() {
        let viewModel = makeViewModel()
        viewModel.selectTool(.sponge)

        #expect(viewModel.applySpongeModeShortcut(.desaturate))
        #expect(viewModel.spongeMode == .desaturate)
        #expect(viewModel.statusText.contains(ImageEditorSpongeMode.desaturate.title))
        #expect(viewModel.statusText.contains("⇧⌥D"))

        #expect(viewModel.applySpongeModeShortcut(.saturate))
        #expect(viewModel.spongeMode == .saturate)
        #expect(viewModel.statusText.contains("⇧⌥S"))
    }

    @Test func componentLibraryDoesNotInheritThePreviousSpongeShortcut() {
        let viewModel = makeViewModel()
        viewModel.selectTool(.sponge)
        viewModel.spongeMode = .saturate
        viewModel.selectLeftSidebarTab(.components)

        #expect(viewModel.canvasInteractionTool == .move)
        #expect(!viewModel.applySpongeModeShortcut(.desaturate))
        #expect(viewModel.spongeMode == .saturate)
    }

    private func resolve(_ key: String, tool: ImageEditorTool?) -> ImageEditorSpongeMode? {
        ImageEditorSpongeModeShortcut.resolve(
            charactersIgnoringModifiers: key,
            modifierFlags: modifiers,
            activeTool: tool
        )
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "Sponge Mode Shortcuts",
            image: NSImage.transparent(size: CGSize(width: 32, height: 24)),
            onApply: { _ in }
        )
    }
}
