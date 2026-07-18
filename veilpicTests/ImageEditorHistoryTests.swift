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
@Suite(.serialized)
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

    @Test
    func deletingSelectedHistoryStepTruncatesThatStepAndLaterOperations() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.foregroundColor = .systemPink
        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 34, y: 24)])
        let firstStrokeData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.foregroundColor = .systemGreen
        viewModel.drawBrush(points: [CGPoint(x: 40, y: 30), CGPoint(x: 72, y: 52)])
        let secondStrokeData = try #require(viewModel.currentImage.qingtuPNGData())
        let originalHistoryCount = viewModel.document.history.count
        let selectedEntry = try #require(viewModel.document.history.last)

        viewModel.selectHistoryEntry(selectedEntry.id)
        #expect(viewModel.canTruncateSelectedHistory)
        viewModel.truncateSelectedHistory()

        #expect(viewModel.currentImage.qingtuPNGData() == firstStrokeData)
        #expect(viewModel.document.history.count == originalHistoryCount - 1)
        #expect(viewModel.selectedHistoryEntryID == viewModel.document.history.last?.id)
        #expect(viewModel.canUndo)

        viewModel.undo()
        #expect(viewModel.currentImage.qingtuPNGData() == secondStrokeData)
        #expect(viewModel.document.history.count == originalHistoryCount)
    }

    @Test
    func historyQueryFiltersByLocalizedTitleWithoutChangingDocumentHistory() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let originalHistory = viewModel.document.history

        viewModel.addLayer()
        viewModel.historyQuery = "图层"

        #expect(viewModel.filteredHistoryEntries.count == 1)
        #expect(viewModel.filteredHistoryEntries.first?.title == L10n.text("imageEditor.history.layerNew"))
        #expect(viewModel.document.history.count == originalHistory.count + 1)

        viewModel.historyQuery = ""
        #expect(viewModel.filteredHistoryEntries.count == viewModel.document.history.count)
    }

    @Test
    func historyQueryFiltersNamedSnapshotsWithoutChangingSnapshotState() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.createHistorySnapshot()
        let snapshot = try #require(viewModel.namedHistorySnapshots.first)
        viewModel.renameHistorySnapshot(snapshot.id, to: "Clean Base")
        let originalSnapshotIDs = viewModel.namedHistorySnapshots.map(\.id)

        viewModel.historyQuery = "clean"
        #expect(viewModel.filteredHistorySnapshots.map(\.id) == originalSnapshotIDs)
        #expect(viewModel.filteredHistoryEntries.count == viewModel.document.history.count)

        viewModel.historyQuery = "missing"
        #expect(viewModel.filteredHistorySnapshots.isEmpty)
        #expect(viewModel.namedHistorySnapshots.map(\.id) == originalSnapshotIDs)
    }

    @Test
    func cropSelectsTheEntireNewCanvas() throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 3, width: 18, height: 16))

        viewModel.crop(to: CGRect(x: 20, y: 10, width: 60, height: 50))

        #expect(viewModel.document.canvasSize == CGSize(width: 60, height: 50))
        let selection = try #require(viewModel.document.selection)
        #expect(selection == .fullCanvas(size: CGSize(width: 60, height: 50)))
    }

    @Test
    func editorWindowResolvesEveryDeclaredMenuShortcut() {
        let command = NSEvent.ModifierFlags.command
        let option = NSEvent.ModifierFlags.option
        let shift = NSEvent.ModifierFlags.shift
        let cases: [(String, NSEvent.ModifierFlags, UInt16?, ImageEditorKeyboardShortcutAction)] = [
            ("o", command, nil, .openProject),
            ("s", command, nil, .saveProject),
            ("s", [command, option, shift], nil, .export),
            ("z", command, nil, .undo),
            ("z", option, nil, .undo),
            ("z", [command, option], nil, .undo),
            ("z", [command, shift], nil, .redo),
            ("x", command, nil, .cutSelectionClipboard),
            ("c", command, nil, .copySelectionClipboard),
            ("c", [command, shift], nil, .copyMergedClipboard),
            ("c", [command, option, shift], nil, .copySelectedLayersClipboard),
            ("v", command, nil, .pasteClipboardLayer),
            ("v", [command, shift], nil, .pasteClipboardIntoSelection),
            ("v", [command, option, shift], nil, .pasteClipboardInPlaceLayer),
            ("t", command, nil, .toggleTransformControls),
            ("", option, 51, .fillSelection),
            ("", command, 51, .fillSelectionBackground),
            ("", [], 51, .clearSelectionPixels),
            ("i", [command, option], nil, .resizeImage),
            ("c", [command, option], nil, .resizeCanvas),
            ("l", command, nil, .levels),
            ("m", command, nil, .curves),
            ("b", command, nil, .colorBalance),
            ("u", command, nil, .hueSaturation),
            ("u", [command, shift], nil, .desaturate),
            ("i", command, nil, .invertPixels),
            ("l", [command, shift], nil, .autoLevels),
            ("l", [command, option, shift], nil, .autoContrast),
            ("b", [command, shift], nil, .autoColor),
            ("n", [command, shift], nil, .newLayer),
            ("j", command, nil, .duplicateSelectionOrLayer),
            ("j", [command, shift], nil, .cutSelectionToLayer),
            ("g", command, nil, .groupSelectedLayer),
            ("g", [command, shift], nil, .ungroupSelectedLayers),
            ("e", command, nil, .mergeDown),
            ("e", [command, option, shift], nil, .stampVisible),
            ("e", [command, shift], nil, .mergeVisible),
            ("]", [command, shift], nil, .layerTop),
            ("]", command, nil, .layerUp),
            ("[", command, nil, .layerDown),
            ("[", [command, shift], nil, .layerBottom),
            ("a", command, nil, .selectAll),
            ("d", command, nil, .clearSelection),
            ("d", [command, shift], nil, .reselectSelection),
            ("i", [command, shift], nil, .invertSelection),
            ("d", [command, option], nil, .featherSelection),
            ("f", command, nil, .applyLastFilter),
            ("r", command, nil, .toggleRulers),
            (";", command, nil, .toggleGuides),
            (";", [command, shift], nil, .toggleGuideSnapping),
            (";", [command, option], nil, .toggleGuidesLocked),
            ("'", command, nil, .toggleGrid),
            ("=", [command, shift], nil, .zoomIn),
            ("-", command, nil, .zoomOut),
            ("+", option, nil, .zoomIn),
            ("=", option, nil, .zoomIn),
            ("-", option, nil, .zoomOut),
            ("1", command, nil, .actualPixels),
            ("0", command, nil, .fitOnScreen),
            ("", [], 48, .toggleWorkspaceChrome),
            ("", shift, 48, .toggleRightDock),
            ("", [], 96, .showBrushSummary),
            ("", [], 97, .showColorSummary),
            ("", [], 98, .showLayersPanel),
            ("", [], 100, .showInfoSummary),
        ]

        for (key, flags, keyCode, expected) in cases {
            #expect(
                ImageEditorKeyboardShortcutAction.resolve(
                    charactersIgnoringModifiers: key,
                    modifierFlags: flags,
                    keyCode: keyCode
                ) == expected
            )
        }

        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "s",
                modifierFlags: [shift, option],
                activeTool: .dodge
            ) == .toneRange(.shadows)
        )
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "m",
                modifierFlags: [shift, option],
                activeTool: .burn
            ) == .toneRange(.midtones)
        )
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "h",
                modifierFlags: [shift, option],
                activeTool: .move
            ) == nil
        )
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "s",
                modifierFlags: [shift, option],
                activeTool: .sponge
            ) == .spongeMode(.saturate)
        )
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "d",
                modifierFlags: [shift, option],
                activeTool: .sponge
            ) == .spongeMode(.desaturate)
        )

        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "a",
                modifierFlags: []
            ) == nil
        )
    }

    @Test
    func historyPanelUsesSearchFieldAndFilteredEntries() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("image-editor-history-search-field"))
        #expect(source.contains("image-editor-history-search-clear"))
        #expect(source.contains("ForEach(viewModel.filteredHistoryEntries)"))
        #expect(source.contains("ForEach(viewModel.filteredHistorySnapshots)"))
        #expect(source.contains("imageEditor.history.searchPlaceholder"))
    }

    private func testImage(color: NSColor, size: NSSize) -> NSImage {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(color.usingColorSpace(.deviceRGB)?.cgColor ?? NSColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        return NSImage(cgImage: context.makeImage()!, size: size)
    }
}
