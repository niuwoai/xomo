//
//  ImageEditorLayerRowBatchPropertyTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerRowBatchPropertyTests {
    @Test func selectedRowVisibilityUnifiesMixedSelectionAndUndoRestoresEveryLayer() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let thirdID = fixture.layers[2].id
        viewModel.document.layers[1].isVisible = false
        select([firstID, secondID], primary: firstID, in: viewModel)

        viewModel.toggleLayerVisibility(firstID, applyingToSelection: true)

        #expect(!(try layer(firstID, in: viewModel)).isVisible)
        #expect(!(try layer(secondID, in: viewModel)).isVisible)
        #expect(try layer(thirdID, in: viewModel).isVisible)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerHideSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerHideSelected", 2))

        viewModel.undo()
        #expect(try layer(firstID, in: viewModel).isVisible)
        #expect(!(try layer(secondID, in: viewModel)).isVisible)

        viewModel.toggleLayerVisibility(secondID, applyingToSelection: true)
        #expect(try layer(firstID, in: viewModel).isVisible)
        #expect(try layer(secondID, in: viewModel).isVisible)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerShowSelected"))
    }

    @Test func selectedRowFullLockUnifiesMixedSelectionWithoutClearingFineLocks() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        viewModel.document.layers[1].isLocked = true
        viewModel.document.layers[1].locksPixels = true
        select([firstID, secondID], primary: firstID, in: viewModel)

        viewModel.toggleLayerLock(firstID, applyingToSelection: true)

        #expect(try layer(firstID, in: viewModel).isLocked)
        #expect(try layer(secondID, in: viewModel).isLocked)
        #expect(try layer(secondID, in: viewModel).locksPixels)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerLockSelected"))

        viewModel.undo()
        #expect(!(try layer(firstID, in: viewModel)).isLocked)
        #expect(try layer(secondID, in: viewModel).isLocked)
        #expect(try layer(secondID, in: viewModel).locksPixels)

        viewModel.toggleLayerLock(secondID, applyingToSelection: true)
        #expect(!(try layer(firstID, in: viewModel)).isLocked)
        #expect(!(try layer(secondID, in: viewModel)).isLocked)
        #expect(try layer(secondID, in: viewModel).locksPixels)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerUnlockSelected"))
    }

    @Test func selectedRowFineLocksApplyOnceToAllEligibleSelectedLayers() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        select([firstID, secondID], primary: firstID, in: viewModel)

        viewModel.toggleLayerPixelsLock(firstID, applyingToSelection: true)
        #expect(try layer(firstID, in: viewModel).locksPixels)
        #expect(try layer(secondID, in: viewModel).locksPixels)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerPixelsLockSelected"))

        viewModel.toggleLayerPositionLock(firstID, applyingToSelection: true)
        #expect(try layer(firstID, in: viewModel).locksPosition)
        #expect(try layer(secondID, in: viewModel).locksPosition)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerPositionLockSelected"))

        viewModel.toggleLayerTransparentPixelsLock(firstID, applyingToSelection: true)
        #expect(try layer(firstID, in: viewModel).locksTransparentPixels)
        #expect(try layer(secondID, in: viewModel).locksTransparentPixels)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTransparentPixelsLockSelected"))

        viewModel.undo()
        #expect(!(try layer(firstID, in: viewModel)).locksTransparentPixels)
        #expect(!(try layer(secondID, in: viewModel)).locksTransparentPixels)
        #expect(try layer(firstID, in: viewModel).locksPosition)
    }

    @Test func transparentPixelBatchSkipsIneligibleSelectedTextLayer() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let pixelID = fixture.layers[0].id
        let textLayer = ImageEditorLayer.text(
            name: "Title",
            origin: CGPoint(x: 8, y: 8),
            content: ImageEditorTextContent(
                text: "Title",
                color: .white,
                fontSize: 18,
                point: CGPoint(x: 8, y: 8)
            )
        )
        viewModel.document.layers.append(textLayer)
        select([pixelID, textLayer.id], primary: pixelID, in: viewModel)

        viewModel.toggleLayerTransparentPixelsLock(pixelID, applyingToSelection: true)

        #expect(try layer(pixelID, in: viewModel).locksTransparentPixels)
        #expect(!(try layer(textLayer.id, in: viewModel)).locksTransparentPixels)
        #expect(viewModel.document.selectedLayerIDs == [pixelID, textLayer.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTransparentPixelsLockSelected"))
    }

    @Test func clickingUnselectedRowChangesOnlyThatRowAndKeepsSelection() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let thirdID = fixture.layers[2].id
        select([firstID, secondID], primary: secondID, in: viewModel)

        viewModel.toggleLayerVisibility(thirdID, applyingToSelection: true)
        viewModel.toggleLayerLock(thirdID, applyingToSelection: true)

        #expect(try layer(firstID, in: viewModel).isVisible)
        #expect(try layer(secondID, in: viewModel).isVisible)
        #expect(!(try layer(thirdID, in: viewModel)).isVisible)
        #expect(!(try layer(firstID, in: viewModel)).isLocked)
        #expect(!(try layer(secondID, in: viewModel)).isLocked)
        #expect(try layer(thirdID, in: viewModel).isLocked)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerLock"))
    }

    @Test func layerPanelRoutesEveryRowPropertyControlThroughSelectionAwareMode() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )

        #expect(source.contains("toggleLayerVisibility(layer.id, applyingToSelection: true)"))
        #expect(source.contains("toggleLayerLock(layer.id, applyingToSelection: true)"))
        #expect(source.contains("toggleLayerPixelsLock(layer.id, applyingToSelection: true)"))
        #expect(source.contains("toggleLayerPositionLock(layer.id, applyingToSelection: true)"))
        #expect(source.contains("toggleLayerTransparentPixelsLock(layer.id, applyingToSelection: true)"))
    }

    private struct Fixture {
        let viewModel: ImageEditorViewModel
        let layers: [ImageEditorLayer]
    }

    private func makeFixture() -> Fixture {
        let canvasSize = CGSize(width: 100, height: 80)
        let viewModel = ImageEditorViewModel(
            sourceName: "row-batch.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        let layers = (1...3).map { index in
            ImageEditorLayer.blank(name: "Layer \(index)", size: canvasSize)
        }
        viewModel.document.layers = layers
        viewModel.document.selectedLayerID = layers[0].id
        viewModel.document.selectedLayerIDs = [layers[0].id]
        return Fixture(viewModel: viewModel, layers: layers)
    }

    private func select(
        _ ids: Set<UUID>,
        primary: UUID,
        in viewModel: ImageEditorViewModel
    ) {
        viewModel.document.selectedLayerIDs = ids
        viewModel.document.selectedLayerID = primary
    }

    private func layer(_ id: UUID, in viewModel: ImageEditorViewModel) throws -> ImageEditorLayer {
        try #require(viewModel.document.layers.first { $0.id == id })
    }
}
