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
    @Test func maskPropertyTransactionsCoalesceAndDiscardNoOpEdits() async throws {
        let image = solidImage(color: .systemBlue, size: NSSize(width: 96, height: 72))
        let mask = solidImage(color: .white, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.addLayer()
        let layerID = try #require(viewModel.document.selectedLayerID)
        try setMask(mask, for: layerID, in: viewModel)

        let initialUndoCount = viewModel.undoStack.count
        let initialHistoryCount = viewModel.document.history.count
        viewModel.beginSelectedLayerMaskDensityChange()
        viewModel.setSelectedLayerMaskDensity(0.8)
        viewModel.setSelectedLayerMaskDensity(0.55)
        viewModel.setSelectedLayerMaskDensity(0.35)
        viewModel.commitSelectedLayerMaskDensityChange()

        #expect(try #require(layer(layerID, in: viewModel)).maskDensity == 0.35)
        #expect(viewModel.undoStack.count == initialUndoCount + 1)
        #expect(viewModel.document.history.count == initialHistoryCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskDensity"))

        viewModel.undo()
        #expect(try #require(layer(layerID, in: viewModel)).maskDensity == 1)
        let undoCountBeforeNoOp = viewModel.undoStack.count
        let historyCountBeforeNoOp = viewModel.document.history.count
        let redoCountBeforeNoOp = viewModel.redoStack.count

        viewModel.beginSelectedLayerMaskDensityChange()
        viewModel.setSelectedLayerMaskDensity(1)
        viewModel.commitSelectedLayerMaskDensityChange()

        #expect(viewModel.undoStack.count == undoCountBeforeNoOp)
        #expect(viewModel.document.history.count == historyCountBeforeNoOp)
        #expect(viewModel.redoStack.count == redoCountBeforeNoOp)
        viewModel.redo()
        #expect(try #require(layer(layerID, in: viewModel)).maskDensity == 0.35)

        viewModel.beginSelectedLayerMaskFeatherChange()
        viewModel.setSelectedLayerMaskFeather(4)
        viewModel.setSelectedLayerMaskFeather(12)
        viewModel.commitSelectedLayerMaskFeatherChange()
        #expect(try #require(layer(layerID, in: viewModel)).maskFeather == 12)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskFeather"))

        viewModel.undo()
        #expect(try #require(layer(layerID, in: viewModel)).maskDensity == 0.35)
        #expect(try #require(layer(layerID, in: viewModel)).maskFeather == 0)
    }

    @Test func selectedLayersApplyBatchMaskDensityAndFeather() async throws {
        let image = solidImage(color: .systemBlue, size: NSSize(width: 96, height: 72))
        let mask = solidImage(color: .white, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let unmaskedID = try #require(viewModel.document.selectedLayerID)

        try setMask(mask, for: firstID, in: viewModel)
        try setMask(mask, for: secondID, in: viewModel)
        try setMask(mask, for: lockedID, in: viewModel)
        viewModel.toggleLayerLock(lockedID)

        viewModel.selectLayer(unmaskedID)
        viewModel.selectLayer(firstID, extendingSelection: true)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(lockedID, extendingSelection: true)

        #expect(viewModel.selectedLayerHasMask)
        #expect(viewModel.canEditSelectedLayerMaskProperties)

        viewModel.beginSelectedLayerMaskDensityChange()
        viewModel.setSelectedLayerMaskDensity(0.35)
        viewModel.commitSelectedLayerMaskDensityChange()
        viewModel.beginSelectedLayerMaskFeatherChange()
        viewModel.setSelectedLayerMaskFeather(12)
        viewModel.commitSelectedLayerMaskFeatherChange()

        let first = try #require(layer(firstID, in: viewModel))
        let second = try #require(layer(secondID, in: viewModel))
        let locked = try #require(layer(lockedID, in: viewModel))
        let unmasked = try #require(layer(unmaskedID, in: viewModel))

        #expect(first.maskDensity == 0.35)
        #expect(first.maskFeather == 12)
        #expect(second.maskDensity == 0.35)
        #expect(second.maskFeather == 12)
        #expect(locked.maskDensity == 1)
        #expect(locked.maskFeather == 0)
        #expect(unmasked.maskDensity == 1)
        #expect(unmasked.maskFeather == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskFeather"))

        viewModel.undo()
        #expect(try #require(layer(firstID, in: viewModel)).maskDensity == 0.35)
        #expect(try #require(layer(firstID, in: viewModel)).maskFeather == 0)
        #expect(try #require(layer(secondID, in: viewModel)).maskDensity == 0.35)
        #expect(try #require(layer(secondID, in: viewModel)).maskFeather == 0)

        viewModel.undo()
        #expect(try #require(layer(firstID, in: viewModel)).maskDensity == 1)
        #expect(try #require(layer(secondID, in: viewModel)).maskDensity == 1)
        #expect(try #require(layer(lockedID, in: viewModel)).maskDensity == 1)
        #expect(try #require(layer(unmaskedID, in: viewModel)).maskDensity == 1)

        viewModel.selectLayer(unmaskedID)
        #expect(!viewModel.selectedLayerHasMask)
        #expect(!viewModel.canEditSelectedLayerMaskProperties)
    }

    @Test func selectedLayersApplyBatchBlendIfAndSkipIneligibleLayers() async throws {
        let image = solidImage(color: .systemTeal, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(lockedID)
        viewModel.addLayerGroup()
        let groupID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(lockedID, extendingSelection: true)
        viewModel.selectLayer(groupID, extendingSelection: true)

        #expect(viewModel.canEditSelectedLayerBlendIf)
        viewModel.setSelectedLayerBlendIfSourceBlack(0.4)
        viewModel.setSelectedLayerBlendIfSourceWhite(0.3)
        viewModel.setSelectedLayerBlendIfUnderlyingWhite(0.7)
        viewModel.setSelectedLayerBlendIfUnderlyingBlack(0.8)
        viewModel.commitSelectedLayerBlendIfChange()

        let first = try #require(layer(firstID, in: viewModel))
        let second = try #require(layer(secondID, in: viewModel))
        let locked = try #require(layer(lockedID, in: viewModel))
        let group = try #require(layer(groupID, in: viewModel))

        #expect(first.blendIfSourceBlack == 0.4)
        #expect(first.blendIfSourceWhite == 0.4)
        #expect(first.blendIfUnderlyingBlack == 0.7)
        #expect(first.blendIfUnderlyingWhite == 0.7)
        #expect(second.blendIfSourceBlack == 0.4)
        #expect(second.blendIfSourceWhite == 0.4)
        #expect(second.blendIfUnderlyingBlack == 0.7)
        #expect(second.blendIfUnderlyingWhite == 0.7)
        #expect(locked.blendIfSourceBlack == 0)
        #expect(locked.blendIfSourceWhite == 1)
        #expect(group.blendIfUnderlyingBlack == 0)
        #expect(group.blendIfUnderlyingWhite == 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerBlendIf"))

        viewModel.selectLayer(groupID)
        #expect(!viewModel.canEditSelectedLayerBlendIf)
    }

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

    private func setMask(_ mask: NSImage, for id: UUID, in viewModel: ImageEditorViewModel) throws {
        let index = try #require(viewModel.document.layers.firstIndex { $0.id == id })
        viewModel.document.layers[index].mask = mask
        viewModel.document.layers[index].isMaskEnabled = true
        viewModel.document.layers[index].maskDensity = 1
        viewModel.document.layers[index].maskFeather = 0
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
