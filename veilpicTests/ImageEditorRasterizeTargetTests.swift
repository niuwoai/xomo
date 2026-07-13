//
//  ImageEditorRasterizeTargetTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorRasterizeTargetTests {
    @Test func typeRasterizationPreservesNameMasksEffectsFiltersClippingAndUndo() throws {
        let viewModel = makeViewModel()
        let baseIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[baseIndex].image = solidImage(color: .systemGreen, size: canvasSize)
        viewModel.textValue = "Editable"
        viewModel.textSize = 26
        viewModel.foregroundColor = .white
        viewModel.addText(at: CGPoint(x: 16, y: 18))

        let textIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[textIndex].name = "Headline"
        viewModel.document.layers[textIndex].mask = solidImage(
            color: .white,
            size: viewModel.document.layers[textIndex].image.size
        )
        viewModel.document.layers[textIndex].style.strokeEnabled = true
        viewModel.document.layers[textIndex].style.strokeWidth = 3
        viewModel.document.layers[textIndex].smartFilters = [
            ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.12)
        ]
        viewModel.document.layers[textIndex].isClippingMask = true
        let source = viewModel.document.layers[textIndex]
        let sourceMask = try #require(source.mask?.qingtuPNGData())
        let compositeBefore = viewModel.currentImage

        #expect(viewModel.canRasterizeSelectedLayers(.type))
        #expect(!viewModel.canRasterizeSelectedLayers(.shape))
        viewModel.rasterizeSelectedLayers(.type)

        let rasterized = try #require(viewModel.document.selectedLayer)
        #expect(rasterized.kind.isPixel)
        #expect(rasterized.name == "Headline")
        #expect(rasterized.frame == source.frame)
        #expect(rasterized.mask?.qingtuPNGData() == sourceMask)
        #expect(rasterized.hasLayerEffects)
        #expect(rasterized.smartFilters.count == 1)
        #expect(rasterized.isClippingMask)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, compositeBefore) <= 8)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRasterize"))

        viewModel.undo()
        let restored = try #require(viewModel.document.selectedLayer)
        #expect(restored.isText)
        #expect(restored.name == "Headline")
        #expect(restored.hasLayerEffects)
        #expect(restored.smartFilters.count == 1)
        #expect(restored.isClippingMask)
    }

    @Test func shapeRasterizationOnlyConvertsShapeContentAndKeepsOtherLayerData() throws {
        let viewModel = makeViewModel()
        var shape = ImageEditorLayer.shape(
            name: "Badge",
            frame: CGRect(x: 18, y: 16, width: 54, height: 34),
            content: shapeContent(kind: .ellipse, color: .systemPink)
        )
        shape.mask = solidImage(color: .white, size: shape.image.size)
        shape.style.shadowEnabled = true
        shape.style.shadowBlur = 4
        shape.vectorMask = triangularVectorMask(size: shape.image.size)
        shape.isClippingMask = true
        viewModel.document.layers.append(shape)
        select(shape.id, in: viewModel)
        let compositeBefore = viewModel.currentImage

        #expect(viewModel.canRasterizeSelectedLayers(.shape))
        viewModel.rasterizeSelectedLayers(.shape)

        let rasterized = try #require(viewModel.document.selectedLayer)
        #expect(rasterized.kind.isPixel)
        #expect(rasterized.name == "Badge")
        #expect(rasterized.mask != nil)
        #expect(rasterized.vectorMask != nil)
        #expect(rasterized.hasLayerEffects)
        #expect(rasterized.isClippingMask)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, compositeBefore) <= 8)
    }

    @Test func fillContentRasterizationLeavesAnEditableVectorMaskOnShapeLayers() throws {
        let viewModel = makeViewModel()
        var shape = ImageEditorLayer.shape(
            name: "Card",
            frame: CGRect(x: 14, y: 12, width: 62, height: 42),
            content: shapeContent(kind: .rectangle, color: .systemBlue)
        )
        shape.style.strokeEnabled = true
        shape.style.strokeWidth = 4
        shape.style.strokeColor = .white
        viewModel.document.layers.append(shape)
        select(shape.id, in: viewModel)
        let compositeBefore = viewModel.currentImage

        #expect(viewModel.canRasterizeSelectedLayers(.fillContent))
        viewModel.rasterizeSelectedLayers(.fillContent)

        let rasterized = try #require(viewModel.document.selectedLayer)
        let vectorMask = try #require(rasterized.vectorMask)
        #expect(rasterized.kind.isPixel)
        #expect(vectorMask.kind == .path)
        #expect(vectorMask.isPathClosed)
        #expect(vectorMask.editablePathAnchors.count >= 3)
        #expect(rasterized.hasLayerEffects)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, compositeBefore) <= 8)
        #expect(viewModel.canRasterizeSelectedLayers(.vectorMask))

        viewModel.rasterizeSelectedLayers(.vectorMask)
        let maskRasterized = try #require(viewModel.document.selectedLayer)
        #expect(maskRasterized.vectorMask == nil)
        #expect(maskRasterized.mask != nil)
        #expect(maskRasterized.kind.isPixel)
    }

    @Test func fillContentRasterizationHandlesGeneratedLayersInOneUndoAndSkipsLocks() throws {
        let viewModel = makeViewModel()
        var solid = ImageEditorLayer.solidColorFill(
            name: "Solid",
            size: canvasSize,
            content: ImageEditorSolidColorFillContent(red: 0.9, green: 0.1, blue: 0.2)
        )
        let pattern = ImageEditorLayer.patternFill(
            name: "Pattern",
            size: canvasSize,
            content: ImageEditorPatternFillContent(kind: .diagonalStripes, scale: 12)
        )
        var lockedGradient = ImageEditorLayer.gradientFill(
            name: "Locked Gradient",
            size: canvasSize,
            content: ImageEditorGradientFillContent(preset: .sunset)
        )
        solid.vectorMask = triangularVectorMask(size: canvasSize)
        lockedGradient.isLocked = true
        viewModel.document.layers = [solid, pattern, lockedGradient]
        viewModel.document.selectedLayerID = pattern.id
        viewModel.document.selectedLayerIDs = [solid.id, pattern.id, lockedGradient.id]
        let historyCount = viewModel.document.history.count

        viewModel.rasterizeSelectedLayers(.fillContent)

        let rasterizedSolid = try #require(viewModel.document.layers.first { $0.id == solid.id })
        let rasterizedPattern = try #require(viewModel.document.layers.first { $0.id == pattern.id })
        let skippedGradient = try #require(viewModel.document.layers.first { $0.id == lockedGradient.id })
        #expect(rasterizedSolid.kind.isPixel)
        #expect(rasterizedSolid.vectorMask != nil)
        #expect(rasterizedSolid.name == "Solid")
        #expect(rasterizedPattern.kind.isPixel)
        #expect(rasterizedPattern.name == "Pattern")
        #expect(skippedGradient.isGradientFill)
        #expect(skippedGradient.isLocked)
        #expect(viewModel.document.selectedLayerIDs == Set([solid.id, pattern.id, lockedGradient.id]))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRasterizeSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerRasterizedSelected", 2))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == solid.id }?.isSolidColorFill == true)
        #expect(viewModel.document.layers.first { $0.id == pattern.id }?.isPatternFill == true)
    }

    @Test func smartObjectRasterizationBakesTransformAndFiltersButPreservesLayerProperties() throws {
        let viewModel = makeViewModel()
        var smartObject = ImageEditorLayer.smartObject(
            name: "Placed Logo",
            image: solidImage(color: .systemPink, size: NSSize(width: 24, height: 16)),
            sourceName: "logo.png"
        )
        smartObject.frame = CGRect(x: 20, y: 14, width: 60, height: 40)
        smartObject.mask = solidImage(color: .white, size: smartObject.image.size)
        smartObject.vectorMask = triangularVectorMask(size: smartObject.image.size)
        smartObject.smartFilters = [ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.2)]
        smartObject.style.strokeEnabled = true
        smartObject.style.strokeWidth = 3
        smartObject.isClippingMask = true
        viewModel.document.layers.append(smartObject)
        select(smartObject.id, in: viewModel)
        let compositeBefore = viewModel.currentImage

        #expect(viewModel.canRasterizeSelectedLayers(.smartObject))
        viewModel.rasterizeSelectedLayers(.smartObject)

        let rasterized = try #require(viewModel.document.selectedLayer)
        #expect(rasterized.kind.isPixel)
        #expect(rasterized.image.size == NSSize(width: 60, height: 40))
        #expect(rasterized.frame == smartObject.frame)
        #expect(rasterized.smartFilters.isEmpty)
        #expect(rasterized.mask?.size == rasterized.image.size)
        #expect(rasterized.vectorMask != nil)
        #expect(rasterized.hasLayerEffects)
        #expect(rasterized.isClippingMask)
        #expect(rasterized.name == "Placed Logo")
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, compositeBefore) <= 20)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.isSmartObject == true)
        #expect(viewModel.document.selectedLayer?.smartFilters.count == 1)
    }

    @Test func layerRasterizationIgnoresPixelStylesButConvertsVectorDataAndPreservesClipping() throws {
        let viewModel = makeViewModel()
        var styledPixel = ImageEditorLayer.blank(name: "Styled Pixel", size: canvasSize)
        styledPixel.image = solidImage(color: .systemGreen, size: canvasSize)
        styledPixel.style.shadowEnabled = true
        viewModel.document.layers = [styledPixel]
        select(styledPixel.id, in: viewModel)

        #expect(!viewModel.canRasterizeSelectedLayers(.layer))
        let historyCount = viewModel.document.history.count
        viewModel.rasterizeSelectedLayers(.layer)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))

        viewModel.document.layers[0].vectorMask = triangularVectorMask(size: canvasSize)
        viewModel.document.layers[0].isClippingMask = true
        let compositeBefore = viewModel.currentImage
        #expect(viewModel.canRasterizeSelectedLayers(.layer))

        viewModel.rasterizeSelectedLayers(.layer)

        let rasterized = try #require(viewModel.document.selectedLayer)
        #expect(rasterized.kind.isPixel)
        #expect(rasterized.vectorMask == nil)
        #expect(rasterized.mask != nil)
        #expect(rasterized.hasLayerEffects)
        #expect(rasterized.isClippingMask)
        #expect(rasterized.name == "Styled Pixel")
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, compositeBefore) <= 8)
    }

    @Test func vectorMaskRasterizationRefusesToDiscardADisabledRasterMask() throws {
        let viewModel = makeViewModel()
        let index = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[index].isLocked = false
        viewModel.document.layers[index].mask = solidImage(color: .white, size: canvasSize)
        viewModel.document.layers[index].isMaskEnabled = false
        viewModel.document.layers[index].vectorMask = triangularVectorMask(size: canvasSize)
        let originalMask = try #require(viewModel.document.layers[index].mask?.qingtuPNGData())
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.canRasterizeSelectedLayers(.vectorMask))
        viewModel.rasterizeSelectedLayers(.vectorMask)

        let unchanged = try #require(viewModel.document.selectedLayer)
        #expect(unchanged.vectorMask != nil)
        #expect(unchanged.mask?.qingtuPNGData() == originalMask)
        #expect(!unchanged.isMaskEnabled)
        #expect(viewModel.document.history.count == historyCount)
    }

    private var canvasSize: NSSize {
        NSSize(width: 100, height: 72)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "rasterize-targets.png",
            image: solidImage(color: .black, size: canvasSize)
        ) { _ in }
    }

    private func select(_ id: UUID, in viewModel: ImageEditorViewModel) {
        viewModel.document.selectedLayerID = id
        viewModel.document.selectedLayerIDs = [id]
    }

    private func shapeContent(kind: ImageEditorShapeKind, color: NSColor) -> ImageEditorShapeContent {
        ImageEditorShapeContent(
            kind: kind,
            fillColor: color,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 2,
            strokeOpacity: 1
        )
    }

    private func triangularVectorMask(size: NSSize) -> ImageEditorShapeContent {
        let points = [
            CGPoint(x: size.width * 0.15, y: size.height * 0.16),
            CGPoint(x: size.width * 0.86, y: size.height * 0.22),
            CGPoint(x: size.width * 0.52, y: size.height * 0.84)
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

    private func solidImage(color: NSColor, size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }
}
