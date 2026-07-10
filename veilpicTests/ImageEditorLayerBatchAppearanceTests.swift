//
//  ImageEditorLayerBatchAppearanceTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/10.
//

import Testing
@testable import musepic
import AppKit

@MainActor
@Suite(.serialized)
struct ImageEditorLayerBatchAppearanceTests {
    @Test func selectedLayersApplyBatchOpacityFillAndBlendMode() async throws {
        let image = solidImage(color: .systemBlue, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.toggleLayerLock(secondID)
        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.setSelectedLayerOpacity(0.35)
        viewModel.commitSelectedLayerOpacityChange()

        #expect(try #require(layer(firstID, in: viewModel)).opacity == 0.35)
        #expect(try #require(layer(secondID, in: viewModel)).opacity == 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerOpacity"))

        viewModel.toggleLayerLock(secondID)
        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        #expect(viewModel.canEditSelectedLayerFillOpacity)
        viewModel.setSelectedLayerFillOpacity(0.45)
        viewModel.commitSelectedLayerFillOpacityChange()

        #expect(try #require(layer(firstID, in: viewModel)).fillOpacity == 0.45)
        #expect(try #require(layer(secondID, in: viewModel)).fillOpacity == 0.45)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFillOpacity"))

        viewModel.setSelectedLayerBlendMode(.multiply)
        #expect(try #require(layer(firstID, in: viewModel)).blendMode == .multiply)
        #expect(try #require(layer(secondID, in: viewModel)).blendMode == .multiply)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerBlendMode"))

        viewModel.undo()
        #expect(try #require(layer(firstID, in: viewModel)).blendMode == .normal)
        #expect(try #require(layer(secondID, in: viewModel)).blendMode == .normal)

        viewModel.addLayerGroup()
        let groupID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.selectedLayerBlendModes.contains(.passThrough))
        viewModel.setSelectedLayerBlendMode(.normal)
        #expect(try #require(layer(groupID, in: viewModel)).blendMode == .normal)

        viewModel.selectLayer(groupID)
        viewModel.selectLayer(firstID, extendingSelection: true)
        #expect(!viewModel.selectedLayerBlendModes.contains(.passThrough))
        viewModel.setSelectedLayerBlendMode(.passThrough)

        #expect(try #require(layer(groupID, in: viewModel)).blendMode == .passThrough)
        #expect(try #require(layer(firstID, in: viewModel)).blendMode == .normal)
    }

    private func layer(_ id: UUID, in viewModel: ImageEditorViewModel) -> ImageEditorLayer? {
        viewModel.document.layers.first { $0.id == id }
    }

    private func solidImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}
