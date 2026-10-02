import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPixelSelectionMoveTests {
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
        let originalNewPixel = try #require(pixel(originalPixels, x: 7, y: 3, width: 12))
        #expect(oldPixel == originalNewPixel)
        #expect(newPixel == originalOldPixel)

        viewModel.undo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 2, y: 2, width: 3, height: 3))
        let undoneImage = try #require(viewModel.document.layers.first { $0.id == layerID }?.image)
        #expect(imageEditorMaximumPixelDifference(undoneImage, originalImage) == 0)

        viewModel.redo()
        #expect(viewModel.document.selection?.bounds == CGRect(x: 6, y: 2, width: 3, height: 3))
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

    private func makeViewModel() -> ImageEditorViewModel {
        let image = NSImage.rendered(size: NSSize(width: 12, height: 8)) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            NSColor.systemRed.setFill()
            NSBezierPath(rect: CGRect(x: 2, y: 2, width: 3, height: 3)).fill()
        } ?? NSImage.transparent(size: NSSize(width: 12, height: 8))
        let viewModel = ImageEditorViewModel(sourceName: "pixel-move.png", image: image) { _ in }
        if let layerID = viewModel.document.selectedLayerID {
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
