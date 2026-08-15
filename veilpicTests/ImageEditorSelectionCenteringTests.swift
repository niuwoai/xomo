//
//  ImageEditorSelectionCenteringTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/15.
//

import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSelectionCenteringTests {
    @Test
    func centeringRasterSelectionUsesSelectedPixelsInsteadOfStoredBounds() throws {
        let canvasSize = CGSize(width: 100, height: 80)
        let viewModel = ImageEditorViewModel(
            sourceName: "center-raster-selection.png",
            image: testImage(size: canvasSize)
        ) { _ in }
        viewModel.document.selection = .raster(
            mask: rectangularMask(
                canvasSize: canvasSize,
                rect: CGRect(x: 10, y: 8, width: 20, height: 10)
            ),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )

        viewModel.centerSelectionHorizontally()

        #expect(viewModel.document.selection?.effectiveSelectedBounds(in: canvasSize) == CGRect(x: 40, y: 8, width: 20, height: 10))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionCenterHorizontal"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionCenteredHorizontal"))

        viewModel.centerSelectionVertically()

        #expect(viewModel.document.selection?.effectiveSelectedBounds(in: canvasSize) == CGRect(x: 40, y: 35, width: 20, height: 10))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionCenterVertical"))
        viewModel.undo()
        #expect(viewModel.document.selection?.effectiveSelectedBounds(in: canvasSize) == CGRect(x: 40, y: 8, width: 20, height: 10))
    }

    @Test
    func centeringEmptyAndInvertedSelectionsDoesNotPolluteHistory() {
        let canvasSize = CGSize(width: 100, height: 80)
        let viewModel = ImageEditorViewModel(
            sourceName: "center-selection-boundaries.png",
            image: testImage(size: canvasSize)
        ) { _ in }
        let emptyMask = ImageEditorSelectionMask(
            width: Int(canvasSize.width),
            height: Int(canvasSize.height),
            alpha: [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        )
        let emptySelection = ImageEditorSelection.raster(
            mask: emptyMask,
            bounds: CGRect(origin: .zero, size: canvasSize)
        )
        viewModel.document.selection = emptySelection
        let initialHistoryCount = viewModel.document.history.count
        let initialUndoCount = viewModel.undoStack.count

        viewModel.centerSelectionInCanvas()

        #expect(viewModel.document.selection == emptySelection)
        #expect(viewModel.document.history.count == initialHistoryCount)
        #expect(viewModel.undoStack.count == initialUndoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))

        var invertedSelection = ImageEditorSelection.rectangle(
            CGRect(x: 8, y: 6, width: 20, height: 12)
        )
        invertedSelection.isInverted = true
        viewModel.document.selection = invertedSelection
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.centerSelectionInCanvas()

        #expect(viewModel.document.selection == invertedSelection)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionUnchanged"))
    }

    private func rectangularMask(
        canvasSize: CGSize,
        rect: CGRect
    ) -> ImageEditorSelectionMask {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        var alpha = [UInt8](repeating: 0, count: width * height)
        let bounds = rect.standardized.integral.intersection(
            CGRect(origin: .zero, size: canvasSize)
        )
        for y in Int(bounds.minY)..<Int(bounds.maxY) {
            for x in Int(bounds.minX)..<Int(bounds.maxX) {
                alpha[y * width + x] = UInt8.max
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }

    private func testImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        } ?? NSImage(size: size)
    }
}
