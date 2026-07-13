//
//  ImageEditorVisibleLayerOrderingTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorVisibleLayerOrderingTests {
    @Test func filteredMoveSkipsHiddenRowsAndUndoRestoresExactOrder() {
        let viewModel = makeViewModel()
        let matchBottom = layer("Match Bottom", in: viewModel)
        let hiddenLow = layer("Reference Low", in: viewModel)
        let matchMiddle = layer("Match Middle", in: viewModel)
        let hiddenHigh = layer("Reference High", in: viewModel)
        let matchTop = layer("Match Top", in: viewModel)
        viewModel.document.layers = [matchBottom, hiddenLow, matchMiddle, hiddenHigh, matchTop]
        select(matchBottom.id, in: viewModel)
        let originalOrder = viewModel.document.layers.map(\.id)
        let filteredIDs = viewModel.visibleLayerRows(matching: "Match").map(\.id)

        #expect(filteredIDs == [matchTop.id, matchMiddle.id, matchBottom.id])
        #expect(viewModel.canMoveSelectedLayerUp(inVisibleOrder: filteredIDs))

        viewModel.moveSelectedLayerUp(inVisibleOrder: filteredIDs)

        #expect(viewModel.visibleLayerRows(matching: "Match").map(\.id) == [
            matchTop.id,
            matchBottom.id,
            matchMiddle.id
        ])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMove"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerReordered"))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalOrder)
    }

    @Test func collapsedGroupMovesAsOneVisibleSubtree() {
        let viewModel = makeViewModel()
        let bottom = layer("Bottom", in: viewModel)
        var group = ImageEditorLayer.group(name: "Collapsed", size: viewModel.document.canvasSize)
        var lowChild = layer("Low Child", in: viewModel)
        var highChild = layer("High Child", in: viewModel)
        let top = layer("Top", in: viewModel)
        lowChild.groupID = group.id
        highChild.groupID = group.id
        group.isGroupExpanded = false
        viewModel.document.layers = [bottom, lowChild, highChild, group, top]
        select(group.id, in: viewModel)
        let originalOrder = viewModel.document.layers.map(\.id)
        let visibleIDs = viewModel.visibleLayerRows.map(\.id)

        #expect(visibleIDs == [top.id, group.id, bottom.id])
        viewModel.moveSelectedLayerDown(inVisibleOrder: visibleIDs)

        #expect(viewModel.visibleLayerRows.map(\.id) == [top.id, bottom.id, group.id])
        #expect(viewModel.document.layers.map(\.id) == [
            lowChild.id,
            highChild.id,
            group.id,
            bottom.id,
            top.id
        ])
        #expect(viewModel.document.layers.first { $0.id == lowChild.id }?.groupID == group.id)
        #expect(viewModel.document.layers.first { $0.id == highChild.id }?.groupID == group.id)
        #expect(!viewModel.canMoveSelectedLayerDown(inVisibleOrder: viewModel.visibleLayerRows.map(\.id)))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalOrder)
    }

    @Test func crossingExpandedGroupHeaderEntersAndLeavesTheGroup() {
        let viewModel = makeViewModel()
        var group = ImageEditorLayer.group(name: "Expanded", size: viewModel.document.canvasSize)
        var child = layer("Child", in: viewModel)
        let source = layer("Source", in: viewModel)
        child.groupID = group.id
        group.isGroupExpanded = true
        viewModel.document.layers = [child, group, source]
        select(source.id, in: viewModel)

        viewModel.moveSelectedLayerDown(inVisibleOrder: viewModel.visibleLayerRows.map(\.id))

        #expect(viewModel.visibleLayerRows.map(\.id) == [group.id, source.id, child.id])
        #expect(viewModel.document.layers.first { $0.id == source.id }?.groupID == group.id)

        viewModel.moveSelectedLayerUp(inVisibleOrder: viewModel.visibleLayerRows.map(\.id))

        #expect(viewModel.visibleLayerRows.map(\.id) == [source.id, group.id, child.id])
        #expect(viewModel.document.layers.first { $0.id == source.id }?.groupID == nil)

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == source.id }?.groupID == group.id)
        #expect(viewModel.visibleLayerRows.map(\.id) == [group.id, source.id, child.id])
    }

    @Test func noncontiguousSelectionMovesOneVisibleStepWithSingleHistoryEntry() {
        let viewModel = makeViewModel()
        let bottom = layer("Bottom", in: viewModel)
        let lowerSelected = layer("Lower Selected", in: viewModel)
        let upper = layer("Upper", in: viewModel)
        let topSelected = layer("Top Selected", in: viewModel)
        viewModel.document.layers = [bottom, lowerSelected, upper, topSelected]
        viewModel.document.selectedLayerIDs = [bottom.id, upper.id]
        viewModel.document.selectedLayerID = upper.id
        let originalOrder = viewModel.document.layers.map(\.id)
        let historyCount = viewModel.document.history.count

        viewModel.moveSelectedLayerUp(inVisibleOrder: viewModel.visibleLayerRows.map(\.id))

        #expect(viewModel.visibleLayerRows.map(\.id) == [upper.id, topSelected.id, bottom.id, lowerSelected.id])
        #expect(viewModel.document.selectedLayerIDs == [bottom.id, upper.id])
        #expect(viewModel.document.selectedLayerID == upper.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalOrder)
    }

    @Test func filteredTopAndBottomCommandsUseOneUndoStepEach() {
        let viewModel = makeViewModel()
        let matchBottom = layer("Match Bottom", in: viewModel)
        let hiddenLow = layer("Reference Low", in: viewModel)
        let matchMiddle = layer("Match Middle", in: viewModel)
        let hiddenHigh = layer("Reference High", in: viewModel)
        let matchTop = layer("Match Top", in: viewModel)
        viewModel.document.layers = [matchBottom, hiddenLow, matchMiddle, hiddenHigh, matchTop]
        select(matchBottom.id, in: viewModel)
        let filteredIDs = viewModel.visibleLayerRows(matching: "Match").map(\.id)
        let historyCount = viewModel.document.history.count

        viewModel.moveSelectedLayerToTop(inVisibleOrder: filteredIDs)

        #expect(viewModel.visibleLayerRows(matching: "Match").map(\.id) == [
            matchBottom.id,
            matchTop.id,
            matchMiddle.id
        ])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMoveToTop"))

        viewModel.moveSelectedLayerToBottom(
            inVisibleOrder: viewModel.visibleLayerRows(matching: "Match").map(\.id)
        )

        #expect(viewModel.visibleLayerRows(matching: "Match").map(\.id) == [
            matchTop.id,
            matchMiddle.id,
            matchBottom.id
        ])
        #expect(viewModel.document.history.count == historyCount + 2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMoveToBottom"))
    }

    @Test func panelAndMenuPassTheFilteredVisibleOrder() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let panel = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        let menu = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )

        #expect(panel.contains("moveSelectedLayerUp(inVisibleOrder: filteredVisibleLayerRowIDs)"))
        #expect(panel.contains("moveSelectedLayerDown(inVisibleOrder: filteredVisibleLayerRowIDs)"))
        #expect(menu.contains("moveSelectedLayerToTop(inVisibleOrder: filteredVisibleLayerRowIDs)"))
        #expect(menu.contains("moveSelectedLayerToBottom(inVisibleOrder: filteredVisibleLayerRowIDs)"))
    }

    private func makeViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 160, height: 100)
        return ImageEditorViewModel(
            sourceName: "visible-layer-order.png",
            image: NSImage.transparent(size: size)
        ) { _ in }
    }

    private func layer(_ name: String, in viewModel: ImageEditorViewModel) -> ImageEditorLayer {
        ImageEditorLayer.blank(name: name, size: viewModel.document.canvasSize)
    }

    private func select(_ layerID: UUID, in viewModel: ImageEditorViewModel) {
        viewModel.document.selectedLayerID = layerID
        viewModel.document.selectedLayerIDs = [layerID]
    }
}
