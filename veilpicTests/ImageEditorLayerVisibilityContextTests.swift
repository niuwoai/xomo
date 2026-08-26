import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerVisibilityContextTests {
    @Test func selectedContextShowsMixedSelectionOnceAndPreservesRedoOnRepeat() throws {
        let viewModel = makeViewModel()
        let first = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let second = try #require(viewModel.document.selectedLayer)
        let firstIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == first.id }
        )
        viewModel.document.layers[firstIndex].isVisible = false
        viewModel.selectLayer(first.id)
        viewModel.selectLayer(second.id, extendingSelection: true)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canSetLayersVisibilityFromContext(
            second.id,
            isVisible: true
        ))
        #expect(viewModel.setLayersVisibilityFromContext(
            second.id,
            isVisible: true
        ))
        #expect(layer(first.id, in: viewModel)?.isVisible == true)
        #expect(layer(second.id, in: viewModel)?.isVisible == true)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.setSelectedLayersLabelColor(.red)
        viewModel.undo()
        let historyAfterUndo = viewModel.document.history
        #expect(viewModel.canRedo)
        #expect(!viewModel.canSetLayersVisibilityFromContext(
            first.id,
            isVisible: true
        ))
        #expect(!viewModel.setLayersVisibilityFromContext(
            first.id,
            isVisible: true
        ))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)

        viewModel.undo()
        #expect(layer(first.id, in: viewModel)?.isVisible == false)
        #expect(layer(second.id, in: viewModel)?.isVisible == true)
    }

    @Test func unselectedContextHidesOnlyClickedLayerAndBecomesItsSelection() throws {
        let viewModel = makeViewModel()
        let selected = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let clicked = try #require(viewModel.document.selectedLayer)
        viewModel.selectLayer(selected.id)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.setLayersVisibilityFromContext(
            clicked.id,
            isVisible: false
        ))
        #expect(viewModel.document.selectedLayerIDs == [clicked.id])
        #expect(viewModel.document.selectedLayerID == clicked.id)
        #expect(layer(clicked.id, in: viewModel)?.isVisible == false)
        #expect(layer(selected.id, in: viewModel)?.isVisible == true)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(layer(clicked.id, in: viewModel)?.isVisible == true)
        #expect(layer(selected.id, in: viewModel)?.isVisible == true)
    }

    @Test func unknownContextVisibilityIsAnAtomicNoOp() {
        let viewModel = makeViewModel()
        let layerIDsBefore = viewModel.document.layers.map(\.id)
        let selectedIDsBefore = viewModel.document.selectedLayerIDs
        let primaryIDBefore = viewModel.document.selectedLayerID
        let historyBefore = viewModel.document.history
        let canUndoBefore = viewModel.canUndo
        let canRedoBefore = viewModel.canRedo
        let unknownID = UUID()

        #expect(!viewModel.canSetLayersVisibilityFromContext(
            unknownID,
            isVisible: false
        ))
        #expect(!viewModel.setLayersVisibilityFromContext(
            unknownID,
            isVisible: false
        ))
        #expect(viewModel.document.layers.map(\.id) == layerIDsBefore)
        #expect(viewModel.document.selectedLayerIDs == selectedIDsBefore)
        #expect(viewModel.document.selectedLayerID == primaryIDBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canUndo == canUndoBefore)
        #expect(viewModel.canRedo == canRedoBefore)
    }

    private func layer(
        _ id: UUID,
        in viewModel: ImageEditorViewModel
    ) -> ImageEditorLayer? {
        viewModel.document.layers.first { $0.id == id }
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "visibility.png",
            image: NSImage.transparent(size: NSSize(width: 120, height: 90))
        ) { _ in }
    }
}
