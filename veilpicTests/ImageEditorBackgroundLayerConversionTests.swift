//
//  ImageEditorBackgroundLayerConversionTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorBackgroundLayerConversionTests {
    @Test func regularLayerCannotBecomeBackgroundUntilTheExistingBackgroundIsConverted() throws {
        let viewModel = makeViewModel()
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalHistoryCount = viewModel.document.history.count

        #expect(!viewModel.canConvertSelectedLayerToBackground)
        viewModel.convertSelectedLayerToBackground()

        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))

        let backgroundID = try #require(viewModel.document.layers.first?.id)
        let regularLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.selectLayer(backgroundID)
        viewModel.convertBackgroundToLayer()
        viewModel.selectLayer(regularLayerID)

        #expect(viewModel.canConvertSelectedLayerToBackground)
    }

    @Test func backgroundToLayerUnlocksEveryLockWithoutChangingIdentityPixelsOrLinks() throws {
        let viewModel = makeViewModel()
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        let linkedID = try #require(viewModel.document.layers.last?.id)
        viewModel.document.layers[0].locksPixels = true
        viewModel.document.layers[0].locksPosition = true
        viewModel.document.layers[0].locksTransparentPixels = true
        viewModel.document.layers[0].labelColor = .blue
        viewModel.document.layers[0].linkedLayerIDs = [linkedID]
        viewModel.document.layers[1].linkedLayerIDs = [backgroundID]
        let originalPixels = try #require(viewModel.document.layers[0].image.qingtuPNGData())
        viewModel.selectLayer(backgroundID)

        viewModel.convertBackgroundToLayer()

        let layer = try #require(viewModel.document.selectedLayer)
        #expect(layer.id == backgroundID)
        #expect(layer.name == L10n.text("imageEditor.layer.unlockedBackground"))
        #expect(!layer.isLocked)
        #expect(!layer.locksPixels)
        #expect(!layer.locksPosition)
        #expect(!layer.locksTransparentPixels)
        #expect(layer.labelColor == .blue)
        #expect(layer.linkedLayerIDs == [linkedID])
        #expect(try #require(layer.image.qingtuPNGData()) == originalPixels)
        #expect(viewModel.document.layers[1].linkedLayerIDs == [backgroundID])
        #expect(viewModel.document.selectedLayerIDs == [backgroundID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFromBackground"))

        viewModel.undo()
        let restored = try #require(viewModel.document.layers.first)
        #expect(restored.id == backgroundID)
        #expect(restored.isLocked)
        #expect(restored.locksPixels)
        #expect(restored.locksPosition)
        #expect(restored.locksTransparentPixels)
    }

    @Test func layerToBackgroundBakesOpacityAndFillsTransparentCanvasWithTheBackgroundColor() throws {
        let viewModel = makeViewModelWithoutBackground()
        var source = ImageEditorLayer.blank(
            name: "Half Red",
            size: NSSize(width: 20, height: 20)
        )
        source.image = solidImage(color: .systemRed, size: source.image.size)
        source.frame = CGRect(x: 10, y: 12, width: 20, height: 20)
        source.opacity = 0.5
        source.labelColor = .orange
        viewModel.backgroundColor = .systemBlue
        viewModel.document.layers.append(source)
        select(source.id, in: viewModel)

        viewModel.convertSelectedLayerToBackground()

        let background = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.first?.id == source.id)
        #expect(background.id == source.id)
        #expect(background.name == L10n.text("imageEditor.layer.background"))
        #expect(background.kind.isPixel)
        #expect(background.isLocked)
        #expect(background.opacity == 1)
        #expect(background.fillOpacity == 1)
        #expect(background.blendMode == .normal)
        #expect(background.frame == CGRect(origin: .zero, size: viewModel.document.canvasSize))
        #expect(background.labelColor == .orange)
        let outside = try color(at: CGPoint(x: 2, y: 2), in: background.image)
        let inside = try color(at: CGPoint(x: 15, y: 18), in: background.image)
        #expect(outside.blueComponent > 0.75)
        #expect(outside.redComponent < 0.25)
        #expect(inside.redComponent > 0.35)
        #expect(inside.blueComponent > 0.35)
        #expect(inside.alphaComponent > 0.99)

        viewModel.undo()
        let restored = try #require(viewModel.document.layers.first { $0.id == source.id })
        #expect(restored.name == "Half Red")
        #expect(restored.opacity == 0.5)
        #expect(!restored.isLocked)
        #expect(restored.frame == source.frame)
    }

    @Test func nestedLayerBecomesTheRootBackgroundWithoutDisturbingTheRemainingGroup() throws {
        let viewModel = makeViewModelWithoutBackground()
        let retainedRoot = viewModel.document.layers[0]
        var sibling = pixelLayer("Sibling", color: .systemGreen, in: viewModel)
        var source = pixelLayer("Nested Source", color: .systemRed, in: viewModel)
        let group = ImageEditorLayer.group(name: "Group", size: viewModel.document.canvasSize)
        let upperRoot = pixelLayer("Upper Root", color: .systemBlue, in: viewModel)
        sibling.groupID = group.id
        source.groupID = group.id
        viewModel.document.layers = [retainedRoot, sibling, source, group, upperRoot]
        select(source.id, in: viewModel)

        viewModel.convertSelectedLayerToBackground()

        let background = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.map(\.id) == [source.id, retainedRoot.id, sibling.id, group.id, upperRoot.id])
        #expect(background.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == sibling.id }?.groupID == group.id)
        #expect(viewModel.document.layers.contains { $0.id == group.id && $0.isGroup })
    }

    @Test func layerToBackgroundClearsLinksOnBothSidesAndReleasesAnOrphanedClip() throws {
        let viewModel = makeViewModelWithoutBackground()
        var source = pixelLayer("Base", color: .systemRed, in: viewModel)
        var clip = pixelLayer("Clip", color: .systemGreen, in: viewModel)
        let group = ImageEditorLayer.group(name: "Group", size: viewModel.document.canvasSize)
        var linkedRoot = pixelLayer("Linked", color: .systemBlue, in: viewModel)
        source.groupID = group.id
        clip.groupID = group.id
        clip.isClippingMask = true
        source.linkedLayerIDs = [linkedRoot.id]
        linkedRoot.linkedLayerIDs = [source.id]
        viewModel.document.layers = [source, clip, group, linkedRoot]
        select(source.id, in: viewModel)

        viewModel.convertSelectedLayerToBackground()

        let background = try #require(viewModel.document.selectedLayer)
        let survivingClip = try #require(viewModel.document.layers.first { $0.id == clip.id })
        let survivingLinked = try #require(viewModel.document.layers.first { $0.id == linkedRoot.id })
        #expect(background.linkedLayerIDs.isEmpty)
        #expect(survivingLinked.linkedLayerIDs.isEmpty)
        #expect(!survivingClip.isClippingMask)
        #expect(survivingClip.groupID == group.id)
    }

    @Test func hiddenLayerRemainsHiddenWhenItBecomesTheBackground() throws {
        let viewModel = makeViewModelWithoutBackground()
        var source = pixelLayer("Hidden", color: .systemRed, in: viewModel)
        source.isVisible = false
        viewModel.document.layers.append(source)
        select(source.id, in: viewModel)

        viewModel.convertSelectedLayerToBackground()

        let background = try #require(viewModel.document.selectedLayer)
        #expect(!background.isVisible)
        #expect(background.isLocked)
        #expect(viewModel.canConvertBackgroundToLayer)
    }

    @Test func nonPixelLayerBecomesAPlainBackgroundWithItsAppearanceBaked() throws {
        let viewModel = makeViewModelWithoutBackground()
        var shape = ImageEditorLayer.shape(
            name: "Vector",
            frame: CGRect(x: 14, y: 16, width: 36, height: 24),
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: .systemPink,
                fillOpacity: 1,
                strokeColor: .white,
                strokeWidth: 4,
                strokeOpacity: 1
            )
        )
        shape.style.shadowEnabled = true
        shape.style.shadowOpacity = 0.6
        shape.style.shadowBlur = 3
        viewModel.document.layers.append(shape)
        select(shape.id, in: viewModel)

        viewModel.convertSelectedLayerToBackground()

        let background = try #require(viewModel.document.selectedLayer)
        #expect(background.kind.isPixel)
        #expect(background.mask == nil)
        #expect(background.vectorMask == nil)
        #expect(!background.hasLayerEffects)
        #expect(background.smartFilters.isEmpty)
        #expect(background.frame == CGRect(origin: .zero, size: viewModel.document.canvasSize))
        let shapePixel = try color(at: CGPoint(x: 30, y: 28), in: background.image)
        #expect(shapePixel.redComponent > 0.7)
        #expect(shapePixel.alphaComponent > 0.99)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "background-conversion.png",
            image: solidImage(color: .black, size: NSSize(width: 96, height: 72))
        ) { _ in }
    }

    private func makeViewModelWithoutBackground() -> ImageEditorViewModel {
        let viewModel = makeViewModel()
        let backgroundID = viewModel.document.layers[0].id
        viewModel.selectLayer(backgroundID)
        viewModel.convertBackgroundToLayer()
        return viewModel
    }

    private func pixelLayer(
        _ name: String,
        color: NSColor,
        in viewModel: ImageEditorViewModel
    ) -> ImageEditorLayer {
        var layer = ImageEditorLayer.blank(name: name, size: viewModel.document.canvasSize)
        layer.image = solidImage(color: color, size: viewModel.document.canvasSize)
        return layer
    }

    private func select(_ id: UUID, in viewModel: ImageEditorViewModel) {
        viewModel.document.selectedLayerID = id
        viewModel.document.selectedLayerIDs = [id]
    }

    private func color(at point: CGPoint, in image: NSImage) throws -> NSColor {
        try #require(image.color(at: point)?.usingColorSpace(.deviceRGB))
    }

    private func solidImage(color: NSColor, size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage(size: size)
    }
}
