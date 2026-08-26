import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerOrderingContextTests {
    @Test func unselectedContextMovesClickedLayerToTopAndUndoRestoresOrder() {
        let viewModel = makeViewModel()
        let bottom = layer("Bottom", in: viewModel)
        let middle = layer("Middle", in: viewModel)
        let top = layer("Top", in: viewModel)
        viewModel.document.layers = [bottom, middle, top]
        select(top.id, in: viewModel)
        let originalOrder = viewModel.document.layers.map(\.id)
        let historyCount = viewModel.document.history.count
        let visibleIDs = viewModel.visibleLayerRows.map(\.id)

        #expect(viewModel.canMoveLayersFromContext(
            bottom.id,
            action: .top,
            visibleRowIDs: visibleIDs
        ))
        #expect(viewModel.moveLayersFromContext(
            bottom.id,
            action: .top,
            visibleRowIDs: visibleIDs
        ))
        #expect(viewModel.visibleLayerRows.map(\.id) == [bottom.id, top.id, middle.id])
        #expect(viewModel.document.selectedLayerIDs == [bottom.id])
        #expect(viewModel.document.selectedLayerID == bottom.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalOrder)
    }

    @Test func selectedContextMovesWholeNoncontiguousSelectionOneStep() {
        let viewModel = makeViewModel()
        let bottom = layer("Bottom", in: viewModel)
        let lower = layer("Lower", in: viewModel)
        let upper = layer("Upper", in: viewModel)
        let top = layer("Top", in: viewModel)
        viewModel.document.layers = [bottom, lower, upper, top]
        viewModel.document.selectedLayerIDs = [bottom.id, upper.id]
        viewModel.document.selectedLayerID = upper.id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.moveLayersFromContext(
            upper.id,
            action: .up,
            visibleRowIDs: viewModel.visibleLayerRows.map(\.id)
        ))
        #expect(viewModel.visibleLayerRows.map(\.id) == [
            upper.id,
            top.id,
            bottom.id,
            lower.id
        ])
        #expect(viewModel.document.selectedLayerIDs == [bottom.id, upper.id])
        #expect(viewModel.document.history.count == historyCount + 1)
    }

    @Test func filteredBoundaryRepeatLockedAndInvalidContextsAreAtomicNoOps() throws {
        let viewModel = makeViewModel()
        let matchBottom = layer("Match Bottom", in: viewModel)
        let reference = layer("Reference", in: viewModel)
        let matchMiddle = layer("Match Middle", in: viewModel)
        let matchTop = layer("Match Top", in: viewModel)
        viewModel.document.layers = [matchBottom, reference, matchMiddle, matchTop]
        select(matchTop.id, in: viewModel)
        let filteredIDs = viewModel.visibleLayerRows(matching: "Match").map(\.id)

        #expect(viewModel.moveLayersFromContext(
            matchBottom.id,
            action: .top,
            visibleRowIDs: filteredIDs
        ))
        #expect(viewModel.visibleLayerRows(matching: "Match").map(\.id) == [
            matchBottom.id,
            matchTop.id,
            matchMiddle.id
        ])

        viewModel.setSelectedLayersLabelColor(.orange)
        viewModel.undo()
        let historyAfterUndo = viewModel.document.history
        #expect(viewModel.canRedo)
        #expect(!viewModel.canMoveLayersFromContext(
            matchBottom.id,
            action: .top,
            visibleRowIDs: viewModel.visibleLayerRows(matching: "Match").map(\.id)
        ))
        #expect(!viewModel.moveLayersFromContext(
            matchBottom.id,
            action: .top,
            visibleRowIDs: viewModel.visibleLayerRows(matching: "Match").map(\.id)
        ))

        let lockedIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == matchMiddle.id }
        )
        viewModel.document.layers[lockedIndex].isLocked = true
        #expect(!viewModel.canMoveLayersFromContext(
            matchMiddle.id,
            action: .bottom,
            visibleRowIDs: viewModel.visibleLayerRows.map(\.id)
        ))
        #expect(!viewModel.moveLayersFromContext(
            UUID(),
            action: .down,
            visibleRowIDs: viewModel.visibleLayerRows.map(\.id)
        ))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 160, height: 100)
        return ImageEditorViewModel(
            sourceName: "ordering-context.png",
            image: NSImage.transparent(size: size)
        ) { _ in }
    }

    private func layer(
        _ name: String,
        in viewModel: ImageEditorViewModel
    ) -> ImageEditorLayer {
        ImageEditorLayer.blank(name: name, size: viewModel.document.canvasSize)
    }

    private func select(_ id: UUID, in viewModel: ImageEditorViewModel) {
        viewModel.document.selectedLayerIDs = [id]
        viewModel.document.selectedLayerID = id
    }
}
