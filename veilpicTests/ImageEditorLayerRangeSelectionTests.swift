//
//  ImageEditorLayerRangeSelectionTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerRangeSelectionTests {
    @Test func shiftRangeSelectsEveryVisibleLayerBetweenAnchorAndTarget() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectLayer(fixture.layers[1].id)

        viewModel.selectLayerRange(
            to: fixture.layers[4].id,
            among: fixture.layers.map(\.id)
        )

        #expect(viewModel.document.selectedLayerIDs == Set(fixture.layers[1...4].map(\.id)))
        #expect(viewModel.document.selectedLayerID == fixture.layers[4].id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerRangeSelected", 4))
    }

    @Test func shiftRangeWorksInReverseAndPreservesItsOriginalAnchor() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectLayer(fixture.layers[4].id)

        viewModel.selectLayerRange(
            to: fixture.layers[2].id,
            among: fixture.layers.map(\.id)
        )
        viewModel.selectLayerRange(
            to: fixture.layers[1].id,
            among: fixture.layers.map(\.id)
        )

        #expect(viewModel.document.selectedLayerIDs == Set(fixture.layers[1...4].map(\.id)))
        #expect(viewModel.document.selectedLayerID == fixture.layers[1].id)
    }

    @Test func commandShiftAddsRangeToExistingDisjointSelection() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectLayer(fixture.layers[0].id)
        viewModel.selectLayer(fixture.layers[2].id, extendingSelection: true)

        viewModel.selectLayerRange(
            to: fixture.layers[4].id,
            among: fixture.layers.map(\.id),
            addingToSelection: true
        )

        #expect(viewModel.document.selectedLayerIDs == Set([
            fixture.layers[0].id,
            fixture.layers[2].id,
            fixture.layers[3].id,
            fixture.layers[4].id
        ]))
        #expect(viewModel.document.selectedLayerID == fixture.layers[4].id)
    }

    @Test func rangeUsesOnlyRowsCurrentlyVisibleInFilteredOrCollapsedPanel() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let panelRows = [fixture.layers[4].id, fixture.layers[2].id, fixture.layers[0].id]
        viewModel.selectLayer(fixture.layers[2].id)

        viewModel.selectLayerRange(to: fixture.layers[0].id, among: panelRows)

        #expect(viewModel.document.selectedLayerIDs == Set([
            fixture.layers[2].id,
            fixture.layers[0].id
        ]))
        #expect(!viewModel.document.selectedLayerIDs.contains(fixture.layers[1].id))
        #expect(!viewModel.document.selectedLayerIDs.contains(fixture.layers[3].id))
    }

    @Test func clearingSelectionAlsoClearsTheRangeAnchor() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectLayer(fixture.layers[1].id)
        viewModel.clearLayerSelection()

        viewModel.selectLayerRange(
            to: fixture.layers[4].id,
            among: fixture.layers.map(\.id)
        )

        #expect(viewModel.document.selectedLayerIDs == [fixture.layers[4].id])
        #expect(viewModel.document.selectedLayerID == fixture.layers[4].id)
    }

    @Test func layerPanelMapsShiftAndCommandToDifferentSelectionBehaviors() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )

        #expect(source.contains("if flags.contains(.shift)"))
        #expect(source.contains("viewModel.selectLayerRange("))
        #expect(source.contains("addingToSelection: flags.contains(.command)"))
        #expect(source.contains("extendingSelection: flags.contains(.command)"))
        #expect(!source.contains("flags.contains(.command) || flags.contains(.shift)"))
    }

    private struct Fixture {
        let viewModel: ImageEditorViewModel
        let layers: [ImageEditorLayer]
    }

    private func makeFixture() -> Fixture {
        let canvasSize = CGSize(width: 120, height: 80)
        let viewModel = ImageEditorViewModel(
            sourceName: "layer-range.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        let layers = (1...5).map { index in
            ImageEditorLayer.blank(name: "Layer \(index)", size: canvasSize)
        }
        viewModel.document.layers = layers
        viewModel.document.selectedLayerID = layers[0].id
        viewModel.document.selectedLayerIDs = [layers[0].id]
        return Fixture(viewModel: viewModel, layers: layers)
    }
}
