import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerVisibilityFocusContextTests {
    @Test func unselectedChildContextIsolationKeepsItsAncestorAndHidesSibling() throws {
        let viewModel = makeViewModel()
        let background = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let firstChild = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let secondChild = try #require(viewModel.document.selectedLayer)
        viewModel.selectLayer(firstChild.id)
        viewModel.selectLayer(secondChild.id, extendingSelection: true)
        viewModel.groupSelectedLayer()
        let group = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let outside = try #require(viewModel.document.selectedLayer)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canIsolateLayersFromContext(firstChild.id))
        #expect(viewModel.isolateLayersFromContext(firstChild.id))
        #expect(viewModel.document.selectedLayerIDs == [firstChild.id])
        #expect(isVisible(firstChild.id, in: viewModel))
        #expect(isVisible(group.id, in: viewModel))
        #expect(!isVisible(secondChild.id, in: viewModel))
        #expect(!isVisible(background.id, in: viewModel))
        #expect(!isVisible(outside.id, in: viewModel))
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.allSatisfy { $0.isVisible })
    }

    @Test func selectedGroupContextIsolationIncludesDescendantsAndRepeatPreservesRedo() throws {
        let viewModel = makeViewModel()
        let background = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let firstChild = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let secondChild = try #require(viewModel.document.selectedLayer)
        viewModel.selectLayer(firstChild.id)
        viewModel.selectLayer(secondChild.id, extendingSelection: true)
        viewModel.groupSelectedLayer()
        let group = try #require(viewModel.document.selectedLayer)

        #expect(viewModel.isolateLayersFromContext(group.id))
        #expect(isVisible(group.id, in: viewModel))
        #expect(isVisible(firstChild.id, in: viewModel))
        #expect(isVisible(secondChild.id, in: viewModel))
        #expect(!isVisible(background.id, in: viewModel))

        viewModel.setSelectedLayersLabelColor(.blue)
        viewModel.undo()
        let historyAfterUndo = viewModel.document.history
        #expect(viewModel.canRedo)
        #expect(!viewModel.canIsolateLayersFromContext(group.id))
        #expect(!viewModel.isolateLayersFromContext(group.id))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)
    }

    @Test func isolatingSelectedClippingLayerKeepsItsBaseVisibleAndUndoable() throws {
        let viewModel = makeViewModel()
        let base = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let clipped = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let unrelated = try #require(viewModel.document.selectedLayer)
        let clippedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == clipped.id })
        viewModel.document.layers[clippedIndex].isClippingMask = true
        viewModel.selectLayer(clipped.id)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.isolatedLayerVisibilityIDs(for: [clipped.id]).contains(base.id))
        viewModel.isolateSelectedLayers()

        #expect(isVisible(base.id, in: viewModel))
        #expect(isVisible(clipped.id, in: viewModel))
        #expect(!isVisible(unrelated.id, in: viewModel))
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        let restoredVisibility = viewModel.document.layers.map { $0.isVisible }
        #expect(restoredVisibility.allSatisfy { $0 })
    }

    @Test func isolatingGroupPreservesHiddenDescendantVisibility() throws {
        let viewModel = makeViewModel()
        let firstChild = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let hiddenChild = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let outside = try #require(viewModel.document.selectedLayer)
        viewModel.selectLayer(firstChild.id)
        viewModel.selectLayer(hiddenChild.id, extendingSelection: true)
        viewModel.groupSelectedLayer()
        let group = try #require(viewModel.document.selectedLayer)
        let hiddenIndex = try #require(viewModel.document.layers.firstIndex { $0.id == hiddenChild.id })
        viewModel.document.layers[hiddenIndex].isVisible = false
        viewModel.selectLayer(group.id)

        #expect(viewModel.isolateLayersFromContext(group.id))

        #expect(isVisible(group.id, in: viewModel))
        #expect(isVisible(firstChild.id, in: viewModel))
        #expect(!isVisible(hiddenChild.id, in: viewModel))
        #expect(!isVisible(outside.id, in: viewModel))

        viewModel.setSelectedLayersLabelColor(.blue)
        viewModel.undo()
        let historyAfterUndo = viewModel.document.history
        #expect(viewModel.canRedo)
        #expect(!viewModel.canIsolateSelectedLayers)
        #expect(!viewModel.canIsolateLayersFromContext(group.id))
        #expect(!viewModel.isolateLayersFromContext(group.id))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)

        viewModel.undo()
        #expect(!isVisible(hiddenChild.id, in: viewModel))
        #expect(isVisible(outside.id, in: viewModel))
    }

    @Test func showAllFromContextIsGlobalKeepsSelectionAndRejectsInvalidOrRepeat() throws {
        let viewModel = makeViewModel()
        let first = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let second = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.isolateLayersFromContext(second.id))
        let selectedIDsBefore = viewModel.document.selectedLayerIDs
        let primaryIDBefore = viewModel.document.selectedLayerID
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canShowAllLayersFromContext(first.id))
        #expect(viewModel.showAllLayersFromContext(first.id))
        #expect(viewModel.document.layers.allSatisfy { $0.isVisible })
        #expect(viewModel.document.selectedLayerIDs == selectedIDsBefore)
        #expect(viewModel.document.selectedLayerID == primaryIDBefore)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.setSelectedLayersLabelColor(.green)
        viewModel.undo()
        let historyAfterUndo = viewModel.document.history
        let unknownID = UUID()
        #expect(viewModel.canRedo)
        #expect(!viewModel.canShowAllLayersFromContext(first.id))
        #expect(!viewModel.showAllLayersFromContext(first.id))
        #expect(!viewModel.canShowAllLayersFromContext(unknownID))
        #expect(!viewModel.showAllLayersFromContext(unknownID))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)
    }

    private func isVisible(
        _ id: UUID,
        in viewModel: ImageEditorViewModel
    ) -> Bool {
        viewModel.document.layers.first { $0.id == id }?.isVisible == true
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "focus.png",
            image: NSImage.transparent(size: NSSize(width: 120, height: 90))
        ) { _ in }
    }
}
