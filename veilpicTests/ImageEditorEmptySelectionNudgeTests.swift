import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorEmptySelectionNudgeTests {
    @Test func emptyPixelSelectionLetsArrowNudgeFallThroughToSelectedLayer() throws {
        let canvasSize = CGSize(width: 80, height: 60)
        let image = try #require(NSImage.rendered(size: canvasSize) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        })
        let viewModel = ImageEditorViewModel(
            sourceName: "empty-selection-nudge",
            image: image
        ) { _ in }
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(backgroundID)
        viewModel.convertBackgroundToLayer()
        let selectedLayerID = try #require(viewModel.document.selectedLayerID)
        let originalFrame = try #require(viewModel.document.selectedLayer?.frame)
        let emptySelection = ImageEditorSelection.raster(
            mask: ImageEditorSelectionMask(
                width: Int(canvasSize.width),
                height: Int(canvasSize.height),
                alpha: [UInt8](
                    repeating: 0,
                    count: Int(canvasSize.width * canvasSize.height)
                )
            ),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )
        viewModel.document.selection = emptySelection
        let originalUndoCount = viewModel.undoStack.count

        viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: 5, height: -2))

        let movedLayer = try #require(
            viewModel.document.layers.first { $0.id == selectedLayerID }
        )
        #expect(movedLayer.frame.origin.x == originalFrame.origin.x + 5)
        #expect(movedLayer.frame.origin.y == originalFrame.origin.y - 2)
        #expect(viewModel.document.selection == emptySelection)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
    }
}
