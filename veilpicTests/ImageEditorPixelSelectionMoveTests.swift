import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPixelSelectionMoveTests {
    @Test func shiftConstrainsPixelSelectionMoveToTheDominantAxis() {
        #expect(ImageEditorPixelSelectionMoveConstraint.delta(
            from: CGSize(width: 7.4, height: 3.2),
            modifierFlags: [.shift],
            canvasSize: CGSize(width: 12, height: 8)
        ) == CGSize(width: 7, height: 0))
        #expect(ImageEditorPixelSelectionMoveConstraint.delta(
            from: CGSize(width: -2.3, height: 6.6),
            modifierFlags: [.shift],
            canvasSize: CGSize(width: 12, height: 8)
        ) == CGSize(width: 0, height: 7))
        #expect(ImageEditorPixelSelectionMoveConstraint.delta(
            from: CGSize(width: 4.6, height: -3.4),
            modifierFlags: [],
            canvasSize: CGSize(width: 12, height: 8)
        ) == CGSize(width: 5, height: -3))
    }

    @Test func shiftConstrainedPixelMoveUsesOneUndoableHorizontalDelta() throws {
        let viewModel = makeViewModel()
        let layerID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 3, height: 3))
        let originalImage = try #require(viewModel.document.selectedLayer?.image)
        let originalUndoCount = viewModel.undoStack.count

        #expect(viewModel.beginPixelSelectionMove(at: CGPoint(x: 3, y: 3)))
        viewModel.updatePixelSelectionMove(
            by: CGSize(width: 6, height: 2),
            modifierFlags: [.shift]
        )
        viewModel.finishPixelSelectionMove()

        #expect(viewModel.document.selection?.bounds == CGRect(x: 8, y: 2, width: 3, height: 3))
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        let movedImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        let movedPixels = try #require(imageEditorRGBABytes(movedImage, width: 12, height: 8))
        let originalPixels = try #require(imageEditorRGBABytes(originalImage, width: 12, height: 8))
        #expect(try pixel(movedPixels, x: 9, y: 3, width: 12) == pixel(originalPixels, x: 3, y: 3, width: 12))

        viewModel.undo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 2, y: 2, width: 3, height: 3))
        viewModel.redo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 8, y: 2, width: 3, height: 3))
    }

    @Test func moveToolArrowNudgeMovesPixelsAndMarqueeAsOneUndoStep() throws {
        let viewModel = makeViewModel()
        viewModel.selectedTool = .move
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 3, height: 3))
        let layerID = try #require(viewModel.document.selectedLayerID)
        let originalImage = try #require(viewModel.document.selectedLayer?.image)
        let originalPixels = try #require(imageEditorRGBABytes(originalImage, width: 12, height: 8))
        let originalUndoCount = viewModel.undoStack.count

        viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: 1, height: 0))

        #expect(viewModel.document.selection?.bounds == CGRect(x: 3, y: 2, width: 3, height: 3))
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionPixelsMove"))
        let movedImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        let movedPixels = try #require(imageEditorRGBABytes(movedImage, width: 12, height: 8))
        #expect(try pixel(movedPixels, x: 3, y: 3, width: 12) == pixel(originalPixels, x: 2, y: 3, width: 12))
        #expect(pixel(movedPixels, x: 2, y: 3, width: 12)?.last == 0)

        viewModel.undo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 2, y: 2, width: 3, height: 3))
        let undoneImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        #expect(imageEditorMaximumPixelDifference(undoneImage, originalImage) == 0)
        viewModel.redo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 3, y: 2, width: 3, height: 3))
    }

    @Test func optionArrowNudgeMovesSelectedPixelsFiveCanvasPixels() throws {
        let viewModel = makeViewModel()
        viewModel.selectedTool = .move
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 3, height: 3))
        let layerID = try #require(viewModel.document.selectedLayerID)
        let originalImage = try #require(viewModel.document.selectedLayer?.image)
        let originalPixels = try #require(imageEditorRGBABytes(originalImage, width: 12, height: 8))
        let originalUndoCount = viewModel.undoStack.count
        let delta = try #require(ImageEditorArrowNudge.delta(for: 124, modifierFlags: [.option]))

        viewModel.nudgeSelectionOrSelectedLayer(by: delta)

        #expect(delta == CGSize(width: 5, height: 0))
        #expect(viewModel.document.selection?.bounds == CGRect(x: 7, y: 2, width: 3, height: 3))
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        let movedImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        let movedPixels = try #require(imageEditorRGBABytes(movedImage, width: 12, height: 8))
        #expect(pixel(movedPixels, x: 7, y: 2, width: 12) == pixel(originalPixels, x: 2, y: 2, width: 12))

        viewModel.undo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 2, y: 2, width: 3, height: 3))
        let undoneImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        #expect(imageEditorMaximumPixelDifference(undoneImage, originalImage) == 0)
    }

    @Test func shiftArrowNudgeMovesSelectedPixelsTenCanvasPixels() throws {
        let viewModel = makeViewModel(size: NSSize(width: 32, height: 16))
        viewModel.selectedTool = .move
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 3, height: 3))
        let layerID = try #require(viewModel.document.selectedLayerID)
        let originalImage = try #require(viewModel.document.selectedLayer?.image)
        let originalPixels = try #require(imageEditorRGBABytes(originalImage, width: 32, height: 16))
        let originalUndoCount = viewModel.undoStack.count
        let delta = try #require(ImageEditorArrowNudge.delta(for: 124, modifierFlags: [.shift]))

        viewModel.nudgeSelectionOrSelectedLayer(by: delta)

        #expect(delta == CGSize(width: 10, height: 0))
        #expect(viewModel.document.selection?.bounds == CGRect(x: 12, y: 2, width: 3, height: 3))
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        let movedImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        let movedPixels = try #require(imageEditorRGBABytes(movedImage, width: 32, height: 16))
        #expect(pixel(movedPixels, x: 12, y: 2, width: 32) == pixel(originalPixels, x: 2, y: 2, width: 32))

        viewModel.undo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 2, y: 2, width: 3, height: 3))
        let undoneImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        #expect(imageEditorMaximumPixelDifference(undoneImage, originalImage) == 0)
    }

    @Test func marqueeArrowNudgeMovesOnlySelectionBoundary() throws {
        let viewModel = makeViewModel()
        viewModel.selectedTool = .marquee
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 3, height: 3))
        let layerID = try #require(viewModel.document.selectedLayerID)
        let originalImage = try #require(viewModel.document.selectedLayer?.image)

        viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: 1, height: 0))

        #expect(viewModel.document.selection?.bounds == CGRect(x: 3, y: 2, width: 3, height: 3))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionMove"))
        let movedImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        #expect(imageEditorMaximumPixelDifference(movedImage, originalImage) == 0)
    }

    @Test func draggingActivePixelSelectionMovesPixelsAndMarqueeAsOneUndoStep() throws {
        let viewModel = makeViewModel()
        let layerID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 3, height: 3))
        let originalImage = try #require(viewModel.document.selectedLayer?.image)
        let originalUndoCount = viewModel.undoStack.count

        #expect(viewModel.beginPixelSelectionMove(at: CGPoint(x: 3, y: 3)))
        viewModel.updatePixelSelectionMove(by: CGSize(width: 4, height: 0))
        viewModel.finishPixelSelectionMove()

        let movedSelection = try #require(viewModel.document.selection)
        #expect(movedSelection.bounds == CGRect(x: 6, y: 2, width: 3, height: 3))
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionPixelsMove"))

        let movedImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        let movedPixels = try #require(imageEditorRGBABytes(movedImage, width: 12, height: 8))
        let originalPixels = try #require(imageEditorRGBABytes(originalImage, width: 12, height: 8))
        let oldPixel = try #require(pixel(movedPixels, x: 3, y: 3, width: 12))
        let newPixel = try #require(pixel(movedPixels, x: 7, y: 3, width: 12))
        let originalOldPixel = try #require(pixel(originalPixels, x: 3, y: 3, width: 12))
        #expect(oldPixel.last == 0)
        #expect(newPixel == originalOldPixel)

        viewModel.undo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 2, y: 2, width: 3, height: 3))
        let undoneImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        #expect(imageEditorMaximumPixelDifference(undoneImage, originalImage) == 0)

        viewModel.redo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 6, y: 2, width: 3, height: 3))
    }

    @Test func switchingToolCommitsPixelMoveAndLeavesUndoOwnershipClean() throws {
        let viewModel = makeViewModel()
        let layerID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 3, height: 3))
        let originalImage = try #require(viewModel.document.selectedLayer?.image)
        let originalPixels = try #require(imageEditorRGBABytes(originalImage, width: 12, height: 8))
        let originalUndoCount = viewModel.undoStack.count
        let originalHistoryCount = viewModel.document.history.count

        #expect(viewModel.beginPixelSelectionMove(at: CGPoint(x: 3, y: 3)))
        viewModel.updatePixelSelectionMove(by: CGSize(width: 4, height: 0))
        let previewImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        let previewPixels = try #require(imageEditorRGBABytes(previewImage, width: 12, height: 8))

        viewModel.selectTool(.brush)

        #expect(viewModel.selectedTool == .brush)
        #expect(viewModel.pixelSelectionMoveTransaction.map { _ in true } == nil)
        #expect(viewModel.document.selection?.bounds == CGRect(x: 6, y: 2, width: 3, height: 3))
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)
        let committedImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        let committedPixels = try #require(imageEditorRGBABytes(committedImage, width: 12, height: 8))
        #expect(committedPixels == previewPixels)

        viewModel.undo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 2, y: 2, width: 3, height: 3))
        let undoneImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        #expect(imageEditorMaximumPixelDifference(undoneImage, originalImage) == 0)
        viewModel.redo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 6, y: 2, width: 3, height: 3))
        let redoneImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        let redonePixels = try #require(imageEditorRGBABytes(redoneImage, width: 12, height: 8))
        #expect(redonePixels == previewPixels)
        #expect(originalPixels != previewPixels)
    }

    @Test func switchingSidebarModeCommitsPixelMoveAsOneUndoableEdit() throws {
        let viewModel = makeViewModel()
        viewModel.selectedTool = .move
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 3, height: 3))
        let originalUndoCount = viewModel.undoStack.count
        let originalHistoryCount = viewModel.document.history.count

        #expect(viewModel.beginPixelSelectionMove(at: CGPoint(x: 3, y: 3)))
        viewModel.updatePixelSelectionMove(by: CGSize(width: 4, height: 0))
        viewModel.selectLeftSidebarTab(.components)

        #expect(viewModel.selectedLeftSidebarTab == .components)
        #expect(viewModel.pixelSelectionMoveTransaction.map { _ in true } == nil)
        #expect(viewModel.document.selection?.bounds == CGRect(x: 6, y: 2, width: 3, height: 3))
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)
        viewModel.undo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 2, y: 2, width: 3, height: 3))
        viewModel.redo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 6, y: 2, width: 3, height: 3))

        viewModel.selectLeftSidebarTab(.tools)
        #expect(viewModel.beginPixelSelectionMove(at: CGPoint(x: 7, y: 3)))
        viewModel.updatePixelSelectionMove(by: CGSize(width: -1, height: 0))
        viewModel.selectLeftSidebarTab(.components)
        #expect(viewModel.pixelSelectionMoveTransaction.map { _ in true } == nil)
        #expect(viewModel.document.selection?.bounds == CGRect(x: 5, y: 2, width: 3, height: 3))
    }

    @Test func zeroDistanceAndCancelledPixelMovesDoNotCommitHistoryOrUndo() throws {
        let viewModel = makeViewModel()
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 3, height: 3))
        let originalDocument = viewModel.document
        let layerID = try #require(viewModel.document.selectedLayerID)
        let originalImage = try #require(viewModel.document.selectedLayer?.image)
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        #expect(viewModel.beginPixelSelectionMove(at: CGPoint(x: 3, y: 3)))
        viewModel.updatePixelSelectionMove(by: .zero)
        viewModel.finishPixelSelectionMove()
        #expect(viewModel.document.selection == originalDocument.selection)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)

        #expect(viewModel.beginPixelSelectionMove(at: CGPoint(x: 3, y: 3)))
        viewModel.updatePixelSelectionMove(by: CGSize(width: 2, height: 0))
        viewModel.cancelPixelSelectionMove()
        #expect(viewModel.document.selection == originalDocument.selection)
        let cancelledImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        #expect(imageEditorMaximumPixelDifference(cancelledImage, originalImage) == 0)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
    }

    @Test func pixelMoveRequiresToolModeAndPointerInsideSelection() throws {
        let viewModel = makeViewModel()
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 3, height: 3))

        #expect(viewModel.canBeginPixelSelectionMove(at: CGPoint(x: 3, y: 3)))
        #expect(!viewModel.canBeginPixelSelectionMove(at: CGPoint(x: 7, y: 3)))

        viewModel.selectedLeftSidebarTab = .components
        #expect(!viewModel.canBeginPixelSelectionMove(at: CGPoint(x: 3, y: 3)))
    }

    private func makeViewModel(size: NSSize = NSSize(width: 12, height: 8)) -> ImageEditorViewModel {
        let image = NSImage.rendered(size: size) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            NSColor.systemRed.setFill()
            NSBezierPath(rect: CGRect(x: 2, y: 2, width: 3, height: 3)).fill()
        } ?? NSImage.transparent(size: NSSize(width: 12, height: 8))
        let viewModel = ImageEditorViewModel(sourceName: "pixel-move.png", image: image) { _ in }
        if let layerID = viewModel.document.layers.first?.id {
            viewModel.selectLayer(layerID)
            viewModel.convertBackgroundToLayer()
        }
        return viewModel
    }

    private func pixel(_ pixels: [UInt8], x: Int, y: Int, width: Int) -> [UInt8]? {
        let offset = (y * width + x) * 4
        guard offset >= 0, offset + 4 <= pixels.count else { return nil }
        return Array(pixels[offset..<(offset + 4)])
    }
}
