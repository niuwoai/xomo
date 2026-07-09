//
//  ImageEditorHistoryTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorHistoryTests {
    @Test
    func clearHistoryKeepsCurrentStateAndDropsUndoRedoSnapshots() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 16
        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 70, y: 50)])
        let paintedData = try #require(viewModel.currentImage.qingtuPNGData())
        let paintedLayerFrame = try #require(viewModel.document.selectedLayer?.frame)

        viewModel.undo()
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(viewModel.canUndo)
        #expect(viewModel.document.history.count > 1)

        viewModel.clearHistoryStates()

        let clearedData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(clearedData == paintedData)
        #expect(viewModel.document.selectedLayer?.frame == paintedLayerFrame)
        #expect(viewModel.document.history.count == 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.currentState"))
        #expect(!viewModel.canUndo)
        #expect(!viewModel.canRedo)
        #expect(viewModel.historySnapshots.count == 1)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.historyCleared"))
    }

    @Test
    func namedHistorySnapshotsRestoreDocumentStateAndSurviveHistoryClear() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let cleanData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.createHistorySnapshot()
        let snapshot = try #require(viewModel.namedHistorySnapshots.first)
        #expect(snapshot.name == L10n.format("imageEditor.history.snapshotName", 1))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.historySnapshotCreated", snapshot.name))

        viewModel.renameHistorySnapshot(snapshot.id, to: "Clean Base")
        let renamedSnapshot = try #require(viewModel.namedHistorySnapshots.first)
        #expect(renamedSnapshot.name == "Clean Base")

        viewModel.clearHistoryStates()
        #expect(viewModel.namedHistorySnapshots.count == 1)

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 16
        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 70, y: 50)])
        let paintedData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(paintedData != cleanData)

        viewModel.restoreHistorySnapshot(renamedSnapshot.id)

        let restoredData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(restoredData == cleanData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.snapshotRestore"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.historySnapshotRestored", "Clean Base"))
        #expect(viewModel.canUndo)

        viewModel.undo()
        let undoneData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(undoneData == paintedData)

        viewModel.deleteHistorySnapshot(renamedSnapshot.id)
        #expect(viewModel.namedHistorySnapshots.isEmpty)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.historySnapshotDeleted", "Clean Base"))
    }

    private func testImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}
