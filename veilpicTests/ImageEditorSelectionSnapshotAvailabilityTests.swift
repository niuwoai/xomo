//
//  ImageEditorSelectionSnapshotAvailabilityTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/15.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionSnapshotAvailabilityTests {
    @Test func emptySelectionCannotOverwriteSavedSelection() throws {
        let canvasSize = CGSize(width: 24, height: 18)
        let viewModel = makeViewModel(canvasSize: canvasSize)
        let savedSelection = ImageEditorSelection.rectangle(
            CGRect(x: 3, y: 4, width: 8, height: 6)
        )
        viewModel.document.savedSelection = savedSelection
        viewModel.document.selection = emptySelection(canvasSize: canvasSize)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.hasSelection)
        #expect(!viewModel.hasEffectiveSelectionPixels)
        viewModel.saveCurrentSelection()

        #expect(viewModel.document.savedSelection == savedSelection)
        #expect(viewModel.document.history.count == historyCount)
        #expect(!viewModel.canUndo)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.noSelection"))
    }

    @Test func emptySavedSelectionCannotBeRestored() throws {
        let canvasSize = CGSize(width: 24, height: 18)
        let viewModel = makeViewModel(canvasSize: canvasSize)
        viewModel.document.savedSelection = emptySelection(canvasSize: canvasSize)
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.hasSavedSelection)
        viewModel.restoreSavedSelection()

        #expect(viewModel.document.selection == nil)
        #expect(viewModel.document.history.count == historyCount)
        #expect(!viewModel.canUndo)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.noSavedSelection"))
    }

    @Test func clearedEmptySelectionDoesNotCreateAReselectableSnapshot() throws {
        let canvasSize = CGSize(width: 24, height: 18)
        let viewModel = makeViewModel(canvasSize: canvasSize)
        viewModel.document.selection = emptySelection(canvasSize: canvasSize)

        viewModel.clearSelection()
        let historyCount = viewModel.document.history.count

        #expect(viewModel.document.selection == nil)
        #expect(!viewModel.canReselectSelection)
        viewModel.reselectSelection()

        #expect(viewModel.document.selection == nil)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.noReselectSelection"))
    }

    @Test func invertedEmptyMaskRemainsAnEffectiveFullCanvasSnapshot() throws {
        let canvasSize = CGSize(width: 24, height: 18)
        let viewModel = makeViewModel(canvasSize: canvasSize)
        var selection = emptySelection(canvasSize: canvasSize)
        selection.isInverted = true
        viewModel.document.selection = selection

        #expect(viewModel.hasEffectiveSelectionPixels)
        viewModel.saveCurrentSelection()
        #expect(viewModel.hasSavedSelection)

        viewModel.clearSelection()
        #expect(viewModel.canReselectSelection)
        viewModel.restoreSavedSelection()
        #expect(viewModel.document.selection == selection)
    }

    private func makeViewModel(canvasSize: CGSize) -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "selection-snapshot.png",
            image: NSImage.rendered(size: canvasSize) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
            } ?? NSImage(size: canvasSize)
        ) { _ in }
    }

    private func emptySelection(canvasSize: CGSize) -> ImageEditorSelection {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        return ImageEditorSelection.raster(
            mask: ImageEditorSelectionMask(
                width: width,
                height: height,
                alpha: [UInt8](repeating: 0, count: width * height)
            ),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )
    }
}
