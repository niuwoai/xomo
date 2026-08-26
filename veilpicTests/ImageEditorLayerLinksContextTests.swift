//
//  ImageEditorLayerLinksContextTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/27.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerLinksContextTests {
    @Test func contextLinkPreservesMultiSelectionAndRejectsAnAlreadyLinkedNoOp() throws {
        let fixture = try makeFixture(layerCount: 3)
        let viewModel = fixture.viewModel
        let firstID = fixture.layerIDs[0]
        let secondID = fixture.layerIDs[1]
        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        let historyBeforeLink = viewModel.document.history.count

        #expect(viewModel.canLinkLayersFromContext(firstID))
        #expect(viewModel.linkLayersFromContext(firstID))
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID])
        #expect(viewModel.isLayerLinked(firstID))
        #expect(viewModel.isLayerLinked(secondID))
        #expect(viewModel.document.history.count == historyBeforeLink + 1)

        viewModel.addLayer()
        viewModel.undo()
        #expect(viewModel.canRedo)
        let historyBeforeNoOp = viewModel.document.history.count
        let undoCountBeforeNoOp = viewModel.undoStack.count

        #expect(!viewModel.canLinkSelectedLayers)
        #expect(!viewModel.canLinkLayersFromContext(firstID))
        #expect(!viewModel.linkLayersFromContext(firstID))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerAlreadyLinked"))
        #expect(viewModel.document.history.count == historyBeforeNoOp)
        #expect(viewModel.undoStack.count == undoCountBeforeNoOp)
        #expect(viewModel.canRedo)
        #expect(viewModel.isLayerLinked(firstID))
        #expect(viewModel.isLayerLinked(secondID))
    }

    @Test func contextSelectLinkedUsesClickedRowAndUnlinkTargetsItsContext() throws {
        let fixture = try makeFixture(layerCount: 4)
        let viewModel = fixture.viewModel
        let firstID = fixture.layerIDs[0]
        let secondID = fixture.layerIDs[1]
        let thirdID = fixture.layerIDs[2]
        let unlinkedID = fixture.layerIDs[3]

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        #expect(viewModel.linkLayersFromContext(firstID))
        viewModel.selectLayer(secondID)
        viewModel.selectLayer(thirdID, extendingSelection: true)
        #expect(viewModel.linkLayersFromContext(secondID))

        viewModel.selectLayer(unlinkedID)
        viewModel.selectLayer(firstID, extendingSelection: true)
        let historyBeforeSelection = viewModel.document.history.count
        let undoCountBeforeSelection = viewModel.undoStack.count
        #expect(viewModel.canSelectLinkedLayersFromContext(firstID))
        #expect(viewModel.selectLinkedLayersFromContext(firstID))
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, thirdID])
        #expect(!viewModel.document.selectedLayerIDs.contains(unlinkedID))
        #expect(viewModel.document.history.count == historyBeforeSelection)
        #expect(viewModel.undoStack.count == undoCountBeforeSelection)

        viewModel.selectLayer(unlinkedID)
        #expect(viewModel.canUnlinkLayersFromContext(secondID))
        #expect(viewModel.unlinkLayersFromContext(secondID))
        #expect(viewModel.document.selectedLayerIDs == [secondID])
        #expect(!viewModel.isLayerLinked(firstID))
        #expect(!viewModel.isLayerLinked(secondID))
        #expect(!viewModel.isLayerLinked(thirdID))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerUnlink"))

        let invalidID = UUID()
        let selectionBeforeInvalidActions = viewModel.document.selectedLayerIDs
        let historyBeforeInvalidActions = viewModel.document.history.count
        #expect(!viewModel.canLinkLayersFromContext(invalidID))
        #expect(!viewModel.canSelectLinkedLayersFromContext(invalidID))
        #expect(!viewModel.canUnlinkLayersFromContext(invalidID))
        #expect(!viewModel.linkLayersFromContext(invalidID))
        #expect(!viewModel.selectLinkedLayersFromContext(invalidID))
        #expect(!viewModel.unlinkLayersFromContext(invalidID))
        #expect(viewModel.document.selectedLayerIDs == selectionBeforeInvalidActions)
        #expect(viewModel.document.history.count == historyBeforeInvalidActions)
    }

    private func makeFixture(layerCount: Int) throws -> (viewModel: ImageEditorViewModel, layerIDs: [UUID]) {
        let canvasSize = NSSize(width: 96, height: 72)
        let viewModel = ImageEditorViewModel(
            sourceName: "links-context.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        var layerIDs = [try #require(viewModel.document.selectedLayerID)]
        for _ in 1..<layerCount {
            viewModel.addLayer()
            layerIDs.append(try #require(viewModel.document.selectedLayerID))
        }
        return (viewModel, layerIDs)
    }
}
