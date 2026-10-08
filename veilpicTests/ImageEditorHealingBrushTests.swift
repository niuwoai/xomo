//
//  ImageEditorHealingBrushTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorHealingBrushTests {
    @Test func healingKernelTouchesOnlyPixelsCoveredByItsMask() throws {
        let width = 5
        let height = 5
        var targetPixels = [UInt8](repeating: 0, count: width * height * 4)
        for pixelIndex in 0..<(width * height) {
            targetPixels[pixelIndex * 4 + 3] = 255
        }
        let sourcePixels = [UInt8](repeating: 255, count: width * height * 4)
        let maskBounds = try #require(ImageEditorHealingBrushKernel.strokeBounds(
            width: width,
            height: height,
            points: [CGPoint(x: 2, y: 2)],
            diameter: 1
        ))
        let maskWidth = maskBounds.maxX - maskBounds.minX + 1
        var maskPixels = [UInt8](repeating: 0, count: maskWidth * (maskBounds.maxY - maskBounds.minY + 1))
        maskPixels[(2 - maskBounds.minY) * maskWidth + 2 - maskBounds.minX] = 255
        let mask = try #require(ImageEditorHealingBrushKernel.StrokeMask(
            bounds: maskBounds,
            pixels: maskPixels
        ))
        var expected = [UInt8](repeating: 0, count: width * height * 4)
        for pixelIndex in 0..<(width * height) {
            expected[pixelIndex * 4 + 3] = 255
        }
        let touchedPixel = (2 * width + 2) * ImageEditorHealingBrushKernel.bytesPerPixel
        expected[touchedPixel] = 255
        expected[touchedPixel + 1] = 255
        expected[touchedPixel + 2] = 255

        ImageEditorHealingBrushKernel.heal(
            targetPixels: &targetPixels,
            targetContextPixels: sourcePixels,
            sourcePixels: sourcePixels,
            mask: mask,
            width: width,
            height: height,
            sourceOffset: .zero,
            destinationReference: CGPoint(x: 2, y: 2),
            brushDiameter: 1,
            opacity: 1
        )

        #expect(targetPixels == expected)
    }

    @Test func healingKernelLeavesPixelsUnchangedForAnEmptyMask() throws {
        let width = 5
        let height = 5
        var targetPixels = [UInt8](repeating: 0, count: width * height * 4)
        for pixelIndex in 0..<(width * height) {
            let pixelOffset = pixelIndex * 4
            targetPixels[pixelOffset] = 40
            targetPixels[pixelOffset + 1] = 80
            targetPixels[pixelOffset + 2] = 120
            targetPixels[pixelOffset + 3] = 255
        }
        let bounds = try #require(ImageEditorHealingBrushKernel.strokeBounds(
            width: width,
            height: height,
            points: [CGPoint(x: 2, y: 2)],
            diameter: 1
        ))
        var untouched = targetPixels
        let contextPixels = Array(targetPixels)
        let emptyMask = try #require(ImageEditorHealingBrushKernel.StrokeMask(
            bounds: bounds,
            pixels: [UInt8](
                repeating: 0,
                count: (bounds.maxX - bounds.minX + 1) * (bounds.maxY - bounds.minY + 1)
            )
        ))
        ImageEditorHealingBrushKernel.heal(
            targetPixels: &untouched,
            targetContextPixels: contextPixels,
            sourcePixels: contextPixels,
            mask: emptyMask,
            width: width,
            height: height,
            sourceOffset: .zero,
            destinationReference: CGPoint(x: 2, y: 2),
            brushDiameter: 8,
            opacity: 1
        )

        #expect(untouched == targetPixels)
    }

    @Test func healingStrokeBoundsCoverTheStrokeAndClipToCanvas() {
        let bounds = ImageEditorHealingBrushKernel.strokeBounds(
            width: 20,
            height: 12,
            points: [CGPoint(x: 1, y: 4), CGPoint(x: 9, y: 6)],
            diameter: 4
        )
        let mask = ImageEditorHealingBrushKernel.strokeAlpha(
            width: 20,
            height: 12,
            points: [CGPoint(x: 1, y: 4), CGPoint(x: 9, y: 6)],
            diameter: 4,
            hardness: 0.5
        )

        #expect(bounds?.minX == 0)
        #expect(bounds?.maxX == 11)
        #expect(bounds?.minY == 2)
        #expect(bounds?.maxY == 8)
        for (index, alpha) in mask.enumerated() where alpha > 0 {
            let x = index % 20
            let y = index / 20
            #expect(x >= (bounds?.minX ?? 20) && x <= (bounds?.maxX ?? -1))
            #expect(y >= (bounds?.minY ?? 12) && y <= (bounds?.maxY ?? -1))
        }
    }

    @Test func compactStrokeMaskMatchesLegacyCanvasAlphaWithinItsBounds() throws {
        let width = 32
        let height = 20
        let points = [CGPoint(x: -1, y: 4), CGPoint(x: 12, y: 8), CGPoint(x: 26, y: 13)]
        let bounds = try #require(ImageEditorHealingBrushKernel.strokeBounds(
            width: width,
            height: height,
            points: points,
            diameter: 6
        ))
        let fullCanvasAlpha = ImageEditorHealingBrushKernel.strokeAlpha(
            width: width,
            height: height,
            points: points,
            diameter: 6,
            hardness: 0.35
        )
        let compactMask = try #require(ImageEditorHealingBrushKernel.strokeMask(
            width: width,
            height: height,
            points: points,
            diameter: 6,
            hardness: 0.35,
            bounds: bounds
        ))

        #expect(
            compactMask.pixels.count
                == (bounds.maxX - bounds.minX + 1) * (bounds.maxY - bounds.minY + 1)
        )
        #expect(compactMask.pixels.count < width * height)
        for y in bounds.minY...bounds.maxY {
            for x in bounds.minX...bounds.maxX {
                #expect(compactMask.alpha(atX: x, y: y) == fullCanvasAlpha[y * width + x])
            }
        }
    }

    @Test func compactHealingMaskStorageScalesWithStrokeBounds() throws {
        let width = 4_096
        let height = 4_096
        let points = [CGPoint(x: 2_048, y: 2_048)]
        let bounds = try #require(ImageEditorHealingBrushKernel.strokeBounds(
            width: width,
            height: height,
            points: points,
            diameter: 24
        ))
        let mask = try #require(ImageEditorHealingBrushKernel.strokeMask(
            width: width,
            height: height,
            points: points,
            diameter: 24,
            hardness: 0.5,
            bounds: bounds
        ))

        #expect(mask.pixels.count == 625)
        #expect(mask.pixels.count < width * height / 10_000)
    }

    @Test func healingBrushRequiresAnExplicitSource() {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: blemishImage(size: canvasSize)) { _ in }
        let historyCount = viewModel.document.history.count

        viewModel.healingBrush(points: [CGPoint(x: 34, y: 25), CGPoint(x: 46, y: 25)])

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.healingSourceMissing"))
    }

    @Test func imageEditorHealingBrushBlendsBlemishTowardSurroundings() async throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: blemishImage(size: canvasSize)) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(blemishImage(size: canvasSize), historyTitle: L10n.text("imageEditor.history.brush"))
        viewModel.brushSize = 12
        viewModel.opacity = 1
        viewModel.setHealingSource(at: CGPoint(x: 16, y: 25))

        viewModel.healingBrush(points: [CGPoint(x: 34, y: 25), CGPoint(x: 46, y: 25)])

        let layer = try #require(viewModel.document.selectedLayer)
        let healed = try #require(layer.image.color(at: CGPoint(x: 40, y: 25))?.usingColorSpace(.deviceRGB))
        let untouched = try #require(layer.image.color(at: CGPoint(x: 10, y: 25))?.usingColorSpace(.deviceRGB))
        #expect(healed.redComponent < 0.55)
        #expect(abs(healed.redComponent - healed.greenComponent) < 0.18)
        #expect(abs(untouched.redComponent - 0.45) < 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.healingBrush"))
    }

    @Test func imageEditorHealingBrushRepairsASingleClick() throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: blemishImage(size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            blemishImage(size: canvasSize),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.brushSize = 12
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.setHealingSource(at: CGPoint(x: 16, y: 25))

        viewModel.healingBrush(points: [CGPoint(x: 40, y: 25)])

        let layer = try #require(viewModel.document.selectedLayer)
        let healed = try #require(
            layer.image.color(at: CGPoint(x: 40, y: 25))?.usingColorSpace(.deviceRGB)
        )
        #expect(healed.redComponent < 0.55)
        #expect(abs(healed.redComponent - healed.greenComponent) < 0.18)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.healingBrush"))
    }

    @Test func spotHealingRepairsASingleClickWithoutAnExplicitSource() throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: blemishImage(size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            blemishImage(size: canvasSize),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.healingBrushMode = .spot
        viewModel.brushSize = 12
        viewModel.hardness = 1
        viewModel.opacity = 1

        viewModel.healingBrush(points: [CGPoint(x: 40, y: 25)])

        let layer = try #require(viewModel.document.selectedLayer)
        let healed = try #require(
            layer.image.color(at: CGPoint(x: 40, y: 25))?.usingColorSpace(.deviceRGB)
        )
        #expect(viewModel.healingSourcePoint == nil)
        #expect(healed.redComponent < 0.55)
        #expect(abs(healed.redComponent - healed.greenComponent) < 0.18)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.spotHealingBrush"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.spotHealingApplied"))
    }

    @Test func spotHealingFindsAnInBoundsSourceNearACanvasEdge() {
        let width = 80
        let height = 50
        let pixels = [UInt8](repeating: 255, count: width * height * 4)

        let offset = ImageEditorHealingBrushKernel.spotSourceOffset(
            pixels: pixels,
            width: width,
            height: height,
            points: [CGPoint(x: 7, y: 25)],
            destinationReference: CGPoint(x: 7, y: 25),
            brushDiameter: 10
        )

        #expect(offset != nil)
        #expect((offset?.width ?? 0) > 0)
    }

    @Test func spotHealingFindsNearestLegalSourceWhenPreferredDistancesDoNotFit() {
        let width = 40
        let height = 40
        let pixels = [UInt8](repeating: 255, count: width * height * 4)

        let offset = ImageEditorHealingBrushKernel.spotSourceOffset(
            pixels: pixels,
            width: width,
            height: height,
            points: [CGPoint(x: 20, y: 20)],
            destinationReference: CGPoint(x: 20, y: 20),
            brushDiameter: 18
        )

        #expect(offset != nil)
        #expect(abs(offset?.width ?? 0) <= 10)
        #expect(abs(offset?.height ?? 0) <= 10)
        #expect(abs(offset?.width ?? 0) + abs(offset?.height ?? 0) > 0)
        #expect(offset?.width.rounded() == offset?.width)
        #expect(offset?.height.rounded() == offset?.height)
    }

    @Test func sampledBrushPressureControlsSourceAndSpotHealingDiameter() throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let sourceLight = configuredHealingViewModel(size: canvasSize, mode: .source)
        let sourceFull = configuredHealingViewModel(size: canvasSize, mode: .source)
        let sourceMouseBaseline = configuredHealingViewModel(size: canvasSize, mode: .source)
        let sourceMousePressureEnabled = configuredHealingViewModel(size: canvasSize, mode: .source)
        let spotLight = configuredHealingViewModel(size: canvasSize, mode: .spot)
        let spotFull = configuredHealingViewModel(size: canvasSize, mode: .spot)
        sourceLight.retouchPressureControlsSize = true
        sourceFull.retouchPressureControlsSize = true
        sourceMouseBaseline.retouchPressureControlsSize = false
        sourceMousePressureEnabled.retouchPressureControlsSize = true
        spotLight.retouchPressureControlsSize = true
        spotFull.retouchPressureControlsSize = true
        let destination = CGPoint(x: 40, y: 25)
        let lightSample = [ImageEditorBrushStrokeSample(point: destination, pressure: 0.05)]
        let fullSample = [ImageEditorBrushStrokeSample(point: destination, pressure: 1)]
        let mouseSample = [ImageEditorBrushStrokeSample(point: destination)]

        sourceLight.healingBrush(samples: lightSample)
        sourceFull.healingBrush(samples: fullSample)
        sourceMouseBaseline.healingBrush(samples: mouseSample)
        sourceMousePressureEnabled.healingBrush(samples: mouseSample)
        spotLight.healingBrush(samples: lightSample)
        spotFull.healingBrush(samples: fullSample)

        let edgePoint = CGPoint(x: 40, y: 28)
        let sourceLightEdge = try healingColor(in: sourceLight, at: edgePoint)
        let sourceFullEdge = try healingColor(in: sourceFull, at: edgePoint)
        let sourceMouseEdge = try healingColor(in: sourceMouseBaseline, at: edgePoint)
        let sourceEnabledMouseEdge = try healingColor(in: sourceMousePressureEnabled, at: edgePoint)
        let spotLightEdge = try healingColor(in: spotLight, at: edgePoint)
        let spotFullEdge = try healingColor(in: spotFull, at: edgePoint)
        #expect(sourceLightEdge.redComponent > 0.8)
        #expect(sourceFullEdge.redComponent < sourceLightEdge.redComponent - 0.20)
        #expect(abs(sourceMouseEdge.redComponent - sourceEnabledMouseEdge.redComponent) < 0.001)
        #expect(spotLightEdge.redComponent > 0.8)
        #expect(spotFullEdge.redComponent < spotLightEdge.redComponent - 0.20)
        #expect(sourceFull.document.history.last?.title == L10n.text("imageEditor.history.healingBrush"))
        #expect(spotFull.document.history.last?.title == L10n.text("imageEditor.history.spotHealingBrush"))
    }

    @Test func imageEditorHealingBrushRespectsActiveSelection() async throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: blemishImage(size: canvasSize)) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(blemishImage(size: canvasSize), historyTitle: L10n.text("imageEditor.history.brush"))
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 36, y: 50))
        viewModel.brushSize = 12
        viewModel.opacity = 1
        viewModel.setHealingSource(at: CGPoint(x: 16, y: 25))

        viewModel.healingBrush(points: [CGPoint(x: 34, y: 25), CGPoint(x: 46, y: 25)])

        let layer = try #require(viewModel.document.selectedLayer)
        let clippedBlemish = try #require(layer.image.color(at: CGPoint(x: 40, y: 25))?.usingColorSpace(.deviceRGB))
        #expect(clippedBlemish.redComponent > 0.8)
    }

    @Test func healingStrokeMaskIsStableAcrossExtraCollinearSamples() {
        let sparse = ImageEditorHealingBrushKernel.strokeAlpha(
            width: 40,
            height: 24,
            points: [CGPoint(x: 6, y: 12), CGPoint(x: 34, y: 12)],
            diameter: 10,
            hardness: 0.35
        )
        let dense = ImageEditorHealingBrushKernel.strokeAlpha(
            width: 40,
            height: 24,
            points: [
                CGPoint(x: 6, y: 12),
                CGPoint(x: 13, y: 12),
                CGPoint(x: 20, y: 12),
                CGPoint(x: 27, y: 12),
                CGPoint(x: 34, y: 12)
            ],
            diameter: 10,
            hardness: 0.35
        )

        #expect(sparse == dense)
    }

    @Test func healingStrokeMaskSupportsASinglePointDab() {
        let alpha = ImageEditorHealingBrushKernel.strokeAlpha(
            width: 24,
            height: 24,
            points: [CGPoint(x: 12, y: 12)],
            diameter: 10,
            hardness: 0.5
        )

        #expect(alpha.count == 24 * 24)
        #expect(alpha[12 * 24 + 12] > 240)
        #expect(alpha[12 * 24 + 16] > 0)
        #expect(alpha[12 * 24 + 18] == 0)
    }

    @Test func healingStrokeHardnessPreservesAVisibleSoftEdge() {
        let soft = ImageEditorHealingBrushKernel.strokeAlpha(
            width: 24,
            height: 24,
            points: [CGPoint(x: 6, y: 12), CGPoint(x: 18, y: 12)],
            diameter: 10,
            hardness: 0
        )
        let hard = ImageEditorHealingBrushKernel.strokeAlpha(
            width: 24,
            height: 24,
            points: [CGPoint(x: 6, y: 12), CGPoint(x: 18, y: 12)],
            diameter: 10,
            hardness: 1
        )
        let center = 12 * 24 + 12
        let edge = 15 * 24 + 12

        #expect(soft[center] > 240)
        #expect(soft[edge] > 0 && soft[edge] < 220)
        #expect(hard[edge] > soft[edge])
    }

    @Test func healingBrushCanSampleAllVisibleLayersIntoAnEmptyLayer() throws {
        let currentLayer = layeredHealingViewModel()
        currentLayer.healingBrushSampleSource = .currentLayer
        performLayeredHealingStroke(on: currentLayer)
        let currentPixel = try #require(
            currentLayer.document.selectedLayer?.image.color(at: CGPoint(x: 62, y: 15))
        )
        #expect(currentPixel.alphaComponent < 0.05)

        let allVisible = layeredHealingViewModel()
        allVisible.healingBrushSampleSource = .allVisible
        performLayeredHealingStroke(on: allVisible)
        let visiblePixel = try #require(
            allVisible.document.selectedLayer?.image.color(at: CGPoint(x: 62, y: 15))
        )
        #expect(visiblePixel.alphaComponent > 0.9)
    }

    @Test func healingCompositeInputCanExcludeAdjustmentLayers() throws {
        let viewModel = adjustmentHealingViewModel()
        let layer = try #require(viewModel.document.selectedLayer)

        let adjusted = try #require(viewModel.sampledBrushInput(
            for: layer,
            canvasOffset: .zero,
            sampleSource: .allVisible
        ))
        let adjustedPixel = try #require(
            adjusted.image.color(at: CGPoint(x: 12, y: 15))?.usingColorSpace(.deviceRGB)
        )
        #expect(adjustedPixel.redComponent > 0.95)

        let ignored = try #require(viewModel.sampledBrushInput(
            for: layer,
            canvasOffset: .zero,
            sampleSource: .allVisible,
            ignoringAdjustmentLayers: true
        ))
        let ignoredPixel = try #require(
            ignored.image.color(at: CGPoint(x: 12, y: 15))?.usingColorSpace(.deviceRGB)
        )
        #expect(ignoredPixel.redComponent < 0.05)
        #expect(ignoredPixel.greenComponent < 0.05)
        #expect(ignoredPixel.blueComponent < 0.05)
        #expect(ignoredPixel.alphaComponent > 0.95)

        viewModel.healingBrushSampleSource = .allVisible
        performLayeredHealingStroke(on: viewModel)
        let adjustedStrokePixel = try #require(
            viewModel.document.selectedLayer?.image
                .color(at: CGPoint(x: 62, y: 15))?
                .usingColorSpace(.deviceRGB)
        )
        #expect(adjustedStrokePixel.redComponent > 0.95)
        #expect(adjustedStrokePixel.alphaComponent > 0.95)

        let ignoredStroke = adjustmentHealingViewModel()
        ignoredStroke.healingBrushSampleSource = .allVisible
        ignoredStroke.healingBrushIgnoresAdjustmentLayers = true
        performLayeredHealingStroke(on: ignoredStroke)
        let ignoredStrokePixel = try #require(
            ignoredStroke.document.selectedLayer?.image
                .color(at: CGPoint(x: 62, y: 15))?
                .usingColorSpace(.deviceRGB)
        )
        #expect(ignoredStrokePixel.redComponent < 0.05)
        #expect(ignoredStrokePixel.greenComponent < 0.05)
        #expect(ignoredStrokePixel.blueComponent < 0.05)
        #expect(ignoredStrokePixel.alphaComponent > 0.95)
    }

    @Test func healingBatchSamplingReusesCurrentLayerImageForDifferentOffsets() throws {
        let viewModel = layeredHealingViewModel()
        let layer = try #require(viewModel.document.selectedLayer)
        let offsets = [CGSize(width: 4, height: -3), .zero]

        let inputs = try #require(viewModel.sampledBrushInputs(
            for: layer,
            canvasOffsets: offsets,
            sampleSource: .currentLayer
        ))

        #expect(inputs.count == offsets.count)
        #expect(inputs[0].image === inputs[1].image)
        #expect(inputs[0].localOffset == CGSize(width: 4, height: -3))
        #expect(inputs[1].localOffset == .zero)
    }

    @Test func healingBatchCompositeSamplingKeepsEachCanvasOffset() throws {
        let viewModel = layeredHealingViewModel()
        let layer = try #require(viewModel.document.selectedLayer)

        let inputs = try #require(viewModel.sampledBrushInputs(
            for: layer,
            canvasOffsets: [.zero, CGSize(width: 5, height: 0)],
            sampleSource: .currentAndBelow
        ))
        let zeroOffsetPixel = try #require(
            inputs[0].image.color(at: CGPoint(x: 17, y: 15))?.usingColorSpace(.deviceRGB)
        )
        let shiftedPixel = try #require(
            inputs[1].image.color(at: CGPoint(x: 12, y: 15))?.usingColorSpace(.deviceRGB)
        )

        #expect(inputs.count == 2)
        #expect(zeroOffsetPixel.redComponent > zeroOffsetPixel.blueComponent)
        #expect(shiftedPixel.redComponent > shiftedPixel.blueComponent)
        #expect(abs(zeroOffsetPixel.redComponent - shiftedPixel.redComponent) < 0.03)
        #expect(abs(zeroOffsetPixel.alphaComponent - shiftedPixel.alphaComponent) < 0.03)
    }

    private func blemishImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor(deviceRed: 0.45, green: 0.45, blue: 0.45, alpha: 1).setFill()
            rect.fill()
            NSColor.systemRed.setFill()
            CGRect(x: 36, y: 21, width: 8, height: 8).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func configuredHealingViewModel(
        size: NSSize,
        mode: ImageEditorHealingBrushMode
    ) -> ImageEditorViewModel {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: blemishImage(size: size)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            blemishImage(size: size),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.healingBrushMode = mode
        viewModel.brushSize = 16
        viewModel.hardness = 1
        viewModel.opacity = 1
        if mode == .source {
            viewModel.setHealingSource(at: CGPoint(x: 16, y: 25))
        }
        return viewModel
    }

    private func healingColor(
        in viewModel: ImageEditorViewModel,
        at point: CGPoint
    ) throws -> NSColor {
        try #require(
            viewModel.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
    }

    private func layeredHealingViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 90, height: 30)
        let background = NSImage.rendered(size: size) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            NSColor.systemRed.setFill()
            CGRect(x: 7, y: 10, width: 14, height: 10).fill()
        } ?? NSImage.transparent(size: size)
        var document = ImageEditorDocument(sourceName: "source.png", image: background)
        var bottom = ImageEditorLayer.blank(name: "Bottom", size: size)
        bottom.image = background
        let edit = ImageEditorLayer.blank(name: "Edit", size: size)
        document.layers = [bottom, edit]
        document.selectedLayerID = edit.id
        document.selectedLayerIDs = [edit.id]
        return ImageEditorViewModel(document: document) { _ in }
    }

    private func adjustmentHealingViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 90, height: 30)
        let black = NSImage.rendered(size: size) { rect in
            NSColor.black.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
        var document = ImageEditorDocument(sourceName: "source.png", image: black)
        var bottom = ImageEditorLayer.blank(name: "Bottom", size: size)
        bottom.image = black
        let adjustment = ImageEditorLayer.adjustment(
            name: "Invert",
            size: size,
            kind: .invert,
            amount: 1
        )
        let edit = ImageEditorLayer.blank(name: "Edit", size: size)
        document.layers = [bottom, adjustment, edit]
        document.selectedLayerID = edit.id
        document.selectedLayerIDs = [edit.id]
        return ImageEditorViewModel(document: document) { _ in }
    }

    private func performLayeredHealingStroke(on viewModel: ImageEditorViewModel) {
        viewModel.brushSize = 6
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.isHealingBrushAligned = false
        viewModel.setHealingSource(at: CGPoint(x: 12, y: 15))
        viewModel.healingBrush(points: [CGPoint(x: 60, y: 15), CGPoint(x: 66, y: 15)])
    }
}
