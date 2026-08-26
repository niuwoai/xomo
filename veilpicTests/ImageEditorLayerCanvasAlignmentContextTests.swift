import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerCanvasAlignmentContextTests {
    @Test func unselectedContextAlignsOnlyClickedLayerAndUndoRestoresFrame() throws {
        let viewModel = makeViewModel()
        let selected = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let clicked = try #require(viewModel.document.selectedLayer)
        setFrame(CGRect(x: 34, y: 24, width: 20, height: 16), for: selected.id, in: viewModel)
        setFrame(CGRect(x: 58, y: 42, width: 30, height: 18), for: clicked.id, in: viewModel)
        viewModel.selectLayer(selected.id)
        let selectedFrame = frame(of: selected.id, in: viewModel)
        let clickedFrame = frame(of: clicked.id, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canAlignLayersFromContextToCanvas(
            clicked.id,
            alignment: .left
        ))
        #expect(viewModel.alignLayersFromContextToCanvas(
            clicked.id,
            alignment: .left
        ))
        #expect(frame(of: clicked.id, in: viewModel)?.minX == 0)
        #expect(frame(of: selected.id, in: viewModel) == selectedFrame)
        #expect(viewModel.document.selectedLayerIDs == [clicked.id])
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(frame(of: clicked.id, in: viewModel) == clickedFrame)
    }

    @Test func selectedContextAlignsEverySelectedLayerToCanvasCenter() throws {
        let viewModel = makeViewModel()
        let first = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let second = try #require(viewModel.document.selectedLayer)
        setFrame(CGRect(x: 10, y: 12, width: 20, height: 18), for: first.id, in: viewModel)
        setFrame(CGRect(x: 70, y: 48, width: 40, height: 24), for: second.id, in: viewModel)
        viewModel.selectLayer(first.id)
        viewModel.selectLayer(second.id, extendingSelection: true)

        #expect(viewModel.alignLayersFromContextToCanvas(
            first.id,
            alignment: .horizontalCenter
        ))
        #expect(frame(of: first.id, in: viewModel)?.midX == 80)
        #expect(frame(of: second.id, in: viewModel)?.midX == 80)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
    }

    @Test func boundaryLockedInvalidAndRepeatedAlignmentAreAtomicNoOps() throws {
        let viewModel = makeViewModel()
        let layer = try #require(viewModel.document.selectedLayer)
        setFrame(CGRect(x: 0, y: 20, width: 30, height: 18), for: layer.id, in: viewModel)
        viewModel.setSelectedLayersLabelColor(.purple)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        let frameBefore = frame(of: layer.id, in: viewModel)
        let unknownID = UUID()

        #expect(viewModel.canRedo)
        #expect(!viewModel.canAlignLayersFromContextToCanvas(
            layer.id,
            alignment: .left
        ))
        #expect(!viewModel.alignLayersFromContextToCanvas(
            layer.id,
            alignment: .left
        ))
        #expect(!viewModel.alignLayersFromContextToCanvas(
            unknownID,
            alignment: .right
        ))

        let index = try #require(
            viewModel.document.layers.firstIndex { $0.id == layer.id }
        )
        viewModel.document.layers[index].locksPosition = true
        #expect(!viewModel.canAlignLayersFromContextToCanvas(
            layer.id,
            alignment: .right
        ))
        #expect(!viewModel.alignLayersFromContextToCanvas(
            layer.id,
            alignment: .right
        ))
        #expect(frame(of: layer.id, in: viewModel) == frameBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "canvas-alignment-context.png",
            image: NSImage.transparent(size: NSSize(width: 160, height: 100))
        ) { _ in }
    }

    private func setFrame(
        _ frame: CGRect,
        for id: UUID,
        in viewModel: ImageEditorViewModel
    ) {
        guard let index = viewModel.document.layers.firstIndex(where: { $0.id == id }) else {
            return
        }
        viewModel.document.layers[index].frame = frame
    }

    private func frame(
        of id: UUID,
        in viewModel: ImageEditorViewModel
    ) -> CGRect? {
        viewModel.document.layers.first { $0.id == id }?.frame.standardized
    }
}
