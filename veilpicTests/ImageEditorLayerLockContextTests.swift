import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerLockContextTests {
    @Test func selectedContextLocksSupportedPropertiesInOneTransactionAndRejectsNoOp() throws {
        let viewModel = makeViewModel()
        let first = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let second = try #require(viewModel.document.selectedLayer)
        viewModel.selectLayer(first.id)
        viewModel.selectLayer(second.id, extendingSelection: true)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canSetLayersLockFromContext(
            first.id,
            kind: .pixels,
            isLocked: true
        ))
        #expect(viewModel.setLayersLockFromContext(
            first.id,
            kind: .pixels,
            isLocked: true
        ))
        #expect(viewModel.document.layers.first { $0.id == first.id }?.locksPixels == true)
        #expect(viewModel.document.layers.first { $0.id == second.id }?.locksPixels == true)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.setSelectedLayersLabelColor(.red)
        viewModel.undo()
        let historyAfterUndo = viewModel.document.history
        #expect(viewModel.canRedo)
        #expect(!viewModel.canSetLayersLockFromContext(
            first.id,
            kind: .pixels,
            isLocked: true
        ))
        #expect(!viewModel.setLayersLockFromContext(
            first.id,
            kind: .pixels,
            isLocked: true
        ))
        #expect(viewModel.document.history == historyAfterUndo)
        #expect(viewModel.canRedo)

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == first.id }?.locksPixels == false)
        #expect(viewModel.document.layers.first { $0.id == second.id }?.locksPixels == false)
    }

    @Test func unselectedContextTargetsOnlyClickedLayerAndFullUnlockClearsEveryLock() throws {
        let viewModel = makeViewModel()
        let selected = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let outside = try #require(viewModel.document.selectedLayer)
        viewModel.selectLayer(selected.id)

        #expect(viewModel.setLayersLockFromContext(
            outside.id,
            kind: .position,
            isLocked: true
        ))
        #expect(viewModel.document.selectedLayerIDs == [outside.id])
        #expect(viewModel.document.layers.first { $0.id == outside.id }?.locksPosition == true)
        #expect(viewModel.document.layers.first { $0.id == selected.id }?.locksPosition == false)

        #expect(viewModel.setLayersLockFromContext(
            outside.id,
            kind: .pixels,
            isLocked: true
        ))
        #expect(viewModel.setLayersLockFromContext(
            outside.id,
            kind: .transparentPixels,
            isLocked: true
        ))
        #expect(viewModel.setLayersLockFromContext(
            outside.id,
            kind: .full,
            isLocked: true
        ))
        #expect(viewModel.setLayersLockFromContext(
            outside.id,
            kind: .full,
            isLocked: false
        ))
        let unlocked = try #require(viewModel.document.layers.first { $0.id == outside.id })
        #expect(!unlocked.isLocked)
        #expect(!unlocked.locksPixels)
        #expect(!unlocked.locksPosition)
        #expect(!unlocked.locksTransparentPixels)
    }

    @Test func unsupportedAndUnknownContextLocksAreAtomicNoOps() throws {
        let viewModel = makeViewModel()
        let selected = try #require(viewModel.document.selectedLayer)
        viewModel.groupSelectedLayer()
        let group = try #require(viewModel.document.selectedLayer)
        let layerIDsBefore = viewModel.document.layers.map(\.id)
        let selectedIDsBefore = viewModel.document.selectedLayerIDs
        let primaryIDBefore = viewModel.document.selectedLayerID
        let historyBefore = viewModel.document.history
        let canUndoBefore = viewModel.canUndo
        let canRedoBefore = viewModel.canRedo
        let unknownID = UUID()

        #expect(!viewModel.canSetLayersLockFromContext(
            group.id,
            kind: .transparentPixels,
            isLocked: true
        ))
        #expect(!viewModel.setLayersLockFromContext(
            group.id,
            kind: .transparentPixels,
            isLocked: true
        ))
        #expect(!viewModel.canSetLayersLockFromContext(
            unknownID,
            kind: .full,
            isLocked: true
        ))
        #expect(!viewModel.setLayersLockFromContext(
            unknownID,
            kind: .full,
            isLocked: true
        ))
        let unchangedGroup = try #require(
            viewModel.document.layers.first { $0.id == group.id }
        )
        #expect(!unchangedGroup.isLocked)
        #expect(!unchangedGroup.locksTransparentPixels)
        #expect(viewModel.document.layers.map(\.id) == layerIDsBefore)
        #expect(viewModel.document.selectedLayerIDs == selectedIDsBefore)
        #expect(viewModel.document.selectedLayerID == primaryIDBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canUndo == canUndoBefore)
        #expect(viewModel.canRedo == canRedoBefore)
        #expect(viewModel.document.layers.contains { $0.id == selected.id })
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "locks.png",
            image: NSImage.transparent(size: NSSize(width: 120, height: 90))
        ) { _ in }
    }
}
