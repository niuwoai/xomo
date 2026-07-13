//
//  ImageEditorRasterizeStyleAndApplyMaskTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorRasterizeStyleAndApplyMaskTests {
    @Test func rasterizeLayerStyleBakesPreBlendAppearanceAndPreservesOuterCompositing() throws {
        let canvasSize = NSSize(width: 100, height: 72)
        let viewModel = makeViewModel(canvasSize: canvasSize)
        var base = ImageEditorLayer.blank(name: "Clip Base", size: canvasSize)
        base.image = solidImage(color: .white, size: canvasSize)
        var styled = ImageEditorLayer.shape(
            name: "Styled Badge",
            frame: CGRect(x: 20, y: 18, width: 48, height: 30),
            content: shapeContent(color: .systemGreen)
        )
        styled.mask = maskImage(
            size: styled.image.size,
            visibleRect: CGRect(x: 3, y: 2, width: 40, height: 25)
        )
        styled.vectorMask = triangularVectorMask(size: styled.image.size)
        styled.smartFilters = [ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.12)]
        styled.style.strokeEnabled = true
        styled.style.strokeWidth = 4
        styled.style.strokeColor = .white
        styled.style.shadowEnabled = true
        styled.style.shadowDistance = 5
        styled.style.shadowBlur = 4
        styled.fillOpacity = 0.68
        styled.opacity = 0.74
        styled.blendMode = .multiply
        styled.blendIfSourceBlack = 0.08
        styled.blendIfSourceWhite = 0.92
        styled.blendIfUnderlyingBlack = 0.12
        styled.blendIfUnderlyingWhite = 0.9
        styled.isClippingMask = true
        viewModel.document.layers = [base, styled]
        select(styled.id, in: viewModel)
        let expectedFrame = styled.renderedCompositingFrame(globalLightAngle: viewModel.document.globalLightAngle)
        let compositeBefore = viewModel.currentImage

        #expect(viewModel.canRasterizeSelectedLayers(.layerStyle))
        viewModel.rasterizeSelectedLayers(.layerStyle)

        let rasterized = try #require(viewModel.document.selectedLayer)
        #expect(rasterized.kind.isPixel)
        #expect(rasterized.name == "Styled Badge")
        #expect(rasterized.frame == expectedFrame)
        #expect(!rasterized.hasLayerEffects)
        #expect(rasterized.smartFilters.isEmpty)
        #expect(rasterized.mask == nil)
        #expect(rasterized.vectorMask == nil)
        #expect(rasterized.fillOpacity == 1)
        #expect(rasterized.blendIfSourceBlack == 0)
        #expect(rasterized.blendIfSourceWhite == 1)
        #expect(rasterized.opacity == 0.74)
        #expect(rasterized.blendMode == .multiply)
        #expect(rasterized.blendIfUnderlyingBlack == 0.12)
        #expect(rasterized.blendIfUnderlyingWhite == 0.9)
        #expect(rasterized.isClippingMask)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, compositeBefore) <= 8)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyleRasterize"))

        viewModel.undo()
        let restored = try #require(viewModel.document.selectedLayer)
        #expect(restored.isShape)
        #expect(restored.hasLayerEffects)
        #expect(restored.smartFilters.count == 1)
        #expect(restored.mask != nil)
        #expect(restored.vectorMask != nil)
        #expect(restored.fillOpacity == 0.68)
        #expect(restored.blendIfSourceBlack == 0.08)
    }

    @Test func rasterizeLayerStyleHandlesEditableSelectionInOneUndoAndSkipsLocks() throws {
        let viewModel = makeViewModel()
        var first = styledPixel(name: "First", color: .systemPink)
        var second = styledPixel(name: "Second", color: .systemGreen)
        var locked = styledPixel(name: "Locked", color: .systemBlue)
        let plain = ImageEditorLayer.blank(name: "Plain", size: canvasSize)
        first.style.strokeEnabled = true
        second.style.shadowEnabled = true
        locked.style.outerGlowEnabled = true
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked, plain]
        viewModel.document.selectedLayerID = second.id
        viewModel.document.selectedLayerIDs = [first.id, second.id, locked.id, plain.id]
        let historyCount = viewModel.document.history.count

        viewModel.rasterizeSelectedLayers(.layerStyle)

        #expect(viewModel.document.layers.first { $0.id == first.id }?.hasLayerEffects == false)
        #expect(viewModel.document.layers.first { $0.id == second.id }?.hasLayerEffects == false)
        #expect(viewModel.document.layers.first { $0.id == locked.id }?.hasLayerEffects == true)
        #expect(viewModel.document.layers.first { $0.id == plain.id }?.kind.isPixel == true)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyleRasterizeSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerStyleRasterizedSelected", 2))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == first.id }?.hasLayerEffects == true)
        #expect(viewModel.document.layers.first { $0.id == second.id }?.hasLayerEffects == true)
    }

    @Test func applyLayerMaskRemovesOnlyRasterMaskAndPreservesVectorMaskAndLayerAppearance() throws {
        let viewModel = makeViewModel()
        var shape = ImageEditorLayer.shape(
            name: "Masked Shape",
            frame: CGRect(x: 12, y: 10, width: 64, height: 42),
            content: shapeContent(color: .systemPink)
        )
        shape.mask = maskImage(
            size: shape.image.size,
            visibleRect: CGRect(x: 8, y: 4, width: 48, height: 32)
        )
        shape.vectorMask = triangularVectorMask(size: shape.image.size)
        shape.smartFilters = [ImageEditorSmartFilter(kind: .sharpen, intensity: 0.18)]
        shape.style.strokeEnabled = true
        shape.style.strokeWidth = 3
        shape.opacity = 0.82
        shape.fillOpacity = 0.76
        shape.blendMode = .screen
        shape.blendIfSourceBlack = 0.1
        shape.blendIfUnderlyingWhite = 0.88
        shape.isClippingMask = true
        viewModel.document.layers.append(shape)
        select(shape.id, in: viewModel)
        let compositeBefore = viewModel.currentImage

        #expect(viewModel.canApplyLayerMask)
        viewModel.applyLayerMask()

        let applied = try #require(viewModel.document.selectedLayer)
        #expect(applied.kind.isPixel)
        #expect(applied.mask == nil)
        #expect(applied.vectorMask != nil)
        #expect(applied.smartFilters.isEmpty)
        #expect(applied.hasLayerEffects)
        #expect(applied.name == "Masked Shape")
        #expect(applied.frame == shape.frame)
        #expect(applied.opacity == 0.82)
        #expect(applied.fillOpacity == 0.76)
        #expect(applied.blendMode == .screen)
        #expect(applied.blendIfSourceBlack == 0.1)
        #expect(applied.blendIfUnderlyingWhite == 0.88)
        #expect(applied.isClippingMask)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, compositeBefore) <= 8)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskApply"))
    }

    @Test func applyVectorMaskRemovesOnlyVectorMaskAndPreservesRasterMaskAndLayerAppearance() throws {
        let viewModel = makeViewModel()
        var layer = ImageEditorLayer.blank(name: "Dual Mask", size: canvasSize)
        layer.image = solidImage(color: .systemGreen, size: canvasSize)
        layer.mask = maskImage(
            size: canvasSize,
            visibleRect: CGRect(x: 6, y: 7, width: 72, height: 48)
        )
        layer.maskDensity = 0.72
        layer.maskFeather = 2
        layer.vectorMask = triangularVectorMask(size: canvasSize)
        layer.style.shadowEnabled = true
        layer.style.shadowBlur = 3
        layer.opacity = 0.84
        layer.blendMode = .multiply
        viewModel.document.layers.append(layer)
        select(layer.id, in: viewModel)
        viewModel.isEditingLayerMask = true
        let originalMask = try #require(layer.mask?.qingtuPNGData())
        let compositeBefore = viewModel.currentImage

        #expect(viewModel.canApplyVectorMask)
        viewModel.applyVectorMask()

        let applied = try #require(viewModel.document.selectedLayer)
        #expect(applied.kind.isPixel)
        #expect(applied.vectorMask == nil)
        #expect(applied.mask?.qingtuPNGData() == originalMask)
        #expect(applied.maskDensity == 0.72)
        #expect(applied.maskFeather == 2)
        #expect(viewModel.isEditingLayerMask)
        #expect(applied.hasLayerEffects)
        #expect(applied.opacity == 0.84)
        #expect(applied.blendMode == .multiply)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, compositeBefore) <= 8)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskApply"))

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.vectorMask != nil)
        #expect(viewModel.document.selectedLayer?.mask != nil)
    }

    @Test func applyingDisabledMasksRemovesOnlyTheRequestedInactiveMask() throws {
        let viewModel = makeViewModel()
        var layer = ImageEditorLayer.blank(name: "Disabled Masks", size: canvasSize)
        layer.image = solidImage(color: .systemOrange, size: canvasSize)
        layer.mask = maskImage(size: canvasSize, visibleRect: CGRect(x: 5, y: 5, width: 30, height: 25))
        layer.vectorMask = triangularVectorMask(size: canvasSize)
        layer.isMaskEnabled = false
        layer.isVectorMaskEnabled = false
        viewModel.document.layers = [layer]
        select(layer.id, in: viewModel)
        let contentBefore = try #require(layer.image.qingtuPNGData())

        viewModel.applyLayerMask()
        let rasterApplied = try #require(viewModel.document.selectedLayer)
        #expect(rasterApplied.mask == nil)
        #expect(rasterApplied.vectorMask != nil)
        #expect(rasterApplied.image.qingtuPNGData() == contentBefore)

        viewModel.applyVectorMask()
        let vectorApplied = try #require(viewModel.document.selectedLayer)
        #expect(vectorApplied.vectorMask == nil)
        #expect(vectorApplied.image.qingtuPNGData() == contentBefore)
    }

    @Test func applyingMasksIsUnavailableForSmartObjectsAndDoesNotMutateHistory() throws {
        let viewModel = makeViewModel()
        var smartObject = ImageEditorLayer.smartObject(
            name: "Protected Smart Object",
            image: solidImage(color: .systemBlue, size: NSSize(width: 36, height: 24)),
            sourceName: "protected.png"
        )
        smartObject.mask = maskImage(
            size: smartObject.image.size,
            visibleRect: CGRect(x: 4, y: 3, width: 24, height: 18)
        )
        smartObject.vectorMask = triangularVectorMask(size: smartObject.image.size)
        viewModel.document.layers = [smartObject]
        select(smartObject.id, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.canApplyLayerMask)
        #expect(!viewModel.canApplyVectorMask)
        viewModel.applyLayerMask()
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.document.selectedLayer?.isSmartObject == true)
        #expect(viewModel.document.selectedLayer?.mask != nil)
        viewModel.applyVectorMask()
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.document.selectedLayer?.vectorMask != nil)
    }

    private var canvasSize: NSSize { NSSize(width: 90, height: 64) }

    private func makeViewModel(canvasSize: NSSize? = nil) -> ImageEditorViewModel {
        let size = canvasSize ?? self.canvasSize
        return ImageEditorViewModel(
            sourceName: "rasterize-style-mask.png",
            image: solidImage(color: .black, size: size)
        ) { _ in }
    }

    private func select(_ id: UUID, in viewModel: ImageEditorViewModel) {
        viewModel.document.selectedLayerID = id
        viewModel.document.selectedLayerIDs = [id]
    }

    private func styledPixel(name: String, color: NSColor) -> ImageEditorLayer {
        var layer = ImageEditorLayer.blank(name: name, size: canvasSize)
        layer.image = solidImage(color: color, size: canvasSize)
        return layer
    }

    private func shapeContent(color: NSColor) -> ImageEditorShapeContent {
        ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: color,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 2,
            strokeOpacity: 1
        )
    }

    private func triangularVectorMask(size: NSSize) -> ImageEditorShapeContent {
        let points = [
            CGPoint(x: size.width * 0.12, y: size.height * 0.16),
            CGPoint(x: size.width * 0.88, y: size.height * 0.24),
            CGPoint(x: size.width * 0.5, y: size.height * 0.86)
        ]
        return ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: points,
            pathAnchors: points.map { ImageEditorPathAnchor(point: $0) },
            isPathClosed: true
        )
    }

    private func maskImage(size: NSSize, visibleRect: CGRect) -> NSImage {
        NSImage.rendered(size: size) { _ in
            NSColor.clear.setFill()
            CGRect(origin: .zero, size: size).fill()
            NSColor.white.setFill()
            visibleRect.fill()
        } ?? NSImage.transparent(size: size)
    }

    private func solidImage(color: NSColor, size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }
}
