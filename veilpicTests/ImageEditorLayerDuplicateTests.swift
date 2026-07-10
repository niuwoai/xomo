//
//  ImageEditorLayerDuplicateTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/10.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerDuplicateTests {
    @Test func imageEditorDuplicatesSelectedLinkedLayersWithInternalDuplicateLinks() async throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .black, size: NSSize(width: 28, height: 20))
        ) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.linkSelectedLayers()

        #expect(layer(firstID, in: viewModel)?.linkedLayerIDs == Set([secondID]))
        #expect(layer(secondID, in: viewModel)?.linkedLayerIDs == Set([firstID]))

        viewModel.duplicateSelectedLayer()

        let duplicatedIDs = viewModel.document.selectedLayerIDs
        #expect(duplicatedIDs.count == 2)
        #expect(!duplicatedIDs.contains(firstID))
        #expect(!duplicatedIDs.contains(secondID))

        let duplicatedLayers = viewModel.document.layers.filter { duplicatedIDs.contains($0.id) }
        #expect(duplicatedLayers.count == 2)
        for duplicatedLayer in duplicatedLayers {
            #expect(duplicatedLayer.linkedLayerIDs.count == 1)
            #expect(duplicatedLayer.linkedLayerIDs.isSubset(of: duplicatedIDs))
            #expect(!duplicatedLayer.linkedLayerIDs.contains(firstID))
            #expect(!duplicatedLayer.linkedLayerIDs.contains(secondID))
        }

        #expect(layer(firstID, in: viewModel)?.linkedLayerIDs == Set([secondID]))
        #expect(layer(secondID, in: viewModel)?.linkedLayerIDs == Set([firstID]))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDuplicate"))
    }

    @Test func imageEditorDropsLinksToUnselectedOriginalsWhenDuplicatingSingleLinkedLayer() async throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .black, size: NSSize(width: 28, height: 20))
        ) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.linkSelectedLayers()

        viewModel.selectLayer(firstID)
        viewModel.duplicateSelectedLayer()

        let duplicatedID = try #require(viewModel.document.selectedLayerID)
        let duplicatedLayer = try #require(layer(duplicatedID, in: viewModel))
        #expect(duplicatedLayer.linkedLayerIDs.isEmpty)
        #expect(layer(firstID, in: viewModel)?.linkedLayerIDs == Set([secondID]))
        #expect(layer(secondID, in: viewModel)?.linkedLayerIDs == Set([firstID]))
    }

    private func layer(_ id: UUID, in viewModel: ImageEditorViewModel) -> ImageEditorLayer? {
        viewModel.document.layers.first { $0.id == id }
    }

    private func solidImage(color: NSColor, size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }
}
