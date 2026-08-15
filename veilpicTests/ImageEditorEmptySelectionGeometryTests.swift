//
//  ImageEditorEmptySelectionGeometryTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/15.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorEmptySelectionGeometryTests {
    @Test func emptySelectionRejectsEveryGeometryCommandWithoutChangingHistory() {
        let actions: [(String, (ImageEditorViewModel) -> Void)] = [
            ("expand", { $0.expandSelection(radius: 2) }),
            ("contract", { $0.contractSelection(radius: 2) }),
            ("feather", { $0.featherSelection(radius: 2) }),
            ("border", { $0.borderSelection(radius: 2) }),
            ("smooth", { $0.smoothSelection(radius: 2) }),
            ("fill holes", { $0.fillSelectionHoles() }),
            ("remove speckles", { $0.removeSelectionSpeckles(maximumArea: 2) }),
            ("move left", { $0.moveSelectionLeft() }),
            ("move right", { $0.moveSelectionRight() }),
            ("move up", { $0.moveSelectionUp() }),
            ("move down", { $0.moveSelectionDown() }),
            ("center horizontal", { $0.centerSelectionHorizontally() }),
            ("center vertical", { $0.centerSelectionVertically() }),
            ("center canvas", { $0.centerSelectionInCanvas() }),
            ("flip horizontal", { $0.flipSelectionHorizontal() }),
            ("flip vertical", { $0.flipSelectionVertical() }),
            ("rotate clockwise", { $0.rotateSelectionClockwise() }),
            ("rotate counterclockwise", { $0.rotateSelectionCounterclockwise() }),
            ("rotate 180", { $0.rotateSelection180() }),
            ("scale up", { $0.scaleSelectionUp() }),
            ("scale down", { $0.scaleSelectionDown() }),
            ("fit canvas", { $0.fitSelectionToCanvas() }),
        ]

        for (actionName, action) in actions {
            let viewModel = makeViewModel()
            viewModel.createRectSelection(
                from: CGPoint(x: 2, y: 2),
                to: CGPoint(x: 8, y: 7)
            )
            viewModel.undo()
            #expect(viewModel.canRedo, "\(actionName) setup must preserve a redo entry")

            let emptySelection = makeEmptySelection()
            viewModel.document.selection = emptySelection
            let history = viewModel.document.history
            let canUndo = viewModel.canUndo
            let canRedo = viewModel.canRedo

            #expect(!viewModel.canModifySelectionGeometry, "\(actionName) must be unavailable")
            action(viewModel)

            #expect(viewModel.document.selection == emptySelection, "\(actionName) changed the empty selection")
            #expect(viewModel.document.history == history, "\(actionName) added fake history")
            #expect(viewModel.canUndo == canUndo, "\(actionName) changed the undo stack")
            #expect(viewModel.canRedo == canRedo, "\(actionName) cleared the redo stack")
            #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
        }
    }

    @Test func invertedEmptySelectionCanStillModifyGeometry() {
        let viewModel = makeViewModel()
        var selection = makeEmptySelection()
        selection.isInverted = true
        viewModel.document.selection = selection
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canModifySelectionGeometry)
        viewModel.contractSelection(radius: 2)

        #expect(viewModel.document.selection != selection)
        #expect(viewModel.hasEffectiveSelectionPixels)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.canUndo)
    }

    @Test func emptySelectionCanStillBeInvertedIntoAFullCanvasSelection() {
        let viewModel = makeViewModel()
        viewModel.document.selection = makeEmptySelection()
        let historyCount = viewModel.document.history.count

        viewModel.invertSelection()

        #expect(viewModel.hasEffectiveSelectionPixels)
        #expect(viewModel.canModifySelectionGeometry)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionInverted"))
    }

    private func makeViewModel() -> ImageEditorViewModel {
        let canvasSize = CGSize(width: 24, height: 18)
        let image = NSImage.rendered(size: canvasSize) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        } ?? NSImage(size: canvasSize)
        return ImageEditorViewModel(
            sourceName: "empty-selection-geometry.png",
            image: image
        ) { _ in }
    }

    private func makeEmptySelection() -> ImageEditorSelection {
        let width = 24
        let height = 18
        return .raster(
            mask: ImageEditorSelectionMask(
                width: width,
                height: height,
                alpha: [UInt8](repeating: 0, count: width * height)
            ),
            bounds: CGRect(x: 0, y: 0, width: width, height: height)
        )
    }
}
