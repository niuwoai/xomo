//
//  ImageEditorAdjustmentTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorAdjustmentTests {
    @Test func imageEditorPatternFillLayerRendersSmartFiltersAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 60, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectedPatternFillKind = .checkerboard
        viewModel.patternFillRed = 0.90
        viewModel.patternFillGreen = 0.20
        viewModel.patternFillBlue = 0.10
        viewModel.patternFillOpacity = 1
        viewModel.patternFillScale = 10
        viewModel.addPatternFillLayer()

        let patternLayer = try #require(viewModel.document.selectedLayer)
        let patternContent = try #require(patternLayer.patternFillContent?.normalized())
        let coloredSquare = try #require(viewModel.currentImage.color(at: CGPoint(x: 2, y: 2))?.usingColorSpace(.deviceRGB))
        let transparentSquare = try #require(viewModel.currentImage.color(at: CGPoint(x: 7, y: 2))?.usingColorSpace(.deviceRGB))

        #expect(patternLayer.isPatternFill)
        #expect(patternContent.kind == .checkerboard)
        #expect(abs(patternContent.red - 0.90) < 0.001)
        #expect(abs(patternContent.green - 0.20) < 0.001)
        #expect(abs(patternContent.blue - 0.10) < 0.001)
        #expect(abs(patternContent.opacity - 1) < 0.001)
        #expect(abs(patternContent.scale - 10) < 0.001)
        #expect(coloredSquare.redComponent > transparentSquare.redComponent + 0.45)
        #expect(coloredSquare.greenComponent > transparentSquare.greenComponent + 0.08)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.patternFillLayerValue", patternContent.kind.title, 100, 10))
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .patternFill).contains { $0.id == patternLayer.id })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerPatternFillNew"))

        viewModel.selectedPatternFillKind = .dots
        viewModel.patternFillOpacity = 0.50
        viewModel.patternFillScale = 18
        viewModel.updateSelectedPatternFillLayer()

        let updatedContent = try #require(viewModel.document.selectedLayer?.patternFillContent?.normalized())
        #expect(updatedContent.kind == .dots)
        #expect(abs(updatedContent.opacity - 0.50) < 0.001)
        #expect(abs(updatedContent.scale - 18) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerPatternFillUpdate"))

        viewModel.selectedFilter = .vignette
        viewModel.filterIntensity = 1
        viewModel.addSmartFilterToSelectedLayer()

        let smartFilteredLayer = try #require(viewModel.document.selectedLayer)
        let filteredCorner = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        #expect(smartFilteredLayer.smartFilters.first?.kind == .vignette)
        #expect(filteredCorner.redComponent < coloredSquare.redComponent * 0.35)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == patternLayer.id })
        let restoredContent = try #require(restoredLayer.patternFillContent?.normalized())
        #expect(restoredLayer.isPatternFill)
        #expect(restoredContent.kind == .dots)
        #expect(abs(restoredContent.opacity - 0.50) < 0.001)
        #expect(abs(restoredContent.scale - 18) < 0.001)
        #expect(restoredLayer.smartFilters.first?.kind == .vignette)
    }

    @Test func imageEditorSolidColorFillLayerRendersSmartFiltersAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 60, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.solidColorFillRed = 0.10
        viewModel.solidColorFillGreen = 0.45
        viewModel.solidColorFillBlue = 0.95
        viewModel.addSolidColorFillLayer()

        let fillLayer = try #require(viewModel.document.selectedLayer)
        let fillContent = try #require(fillLayer.solidColorFillContent?.normalized())
        let centerColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 30, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(fillLayer.isSolidColorFill)
        #expect(abs(fillContent.red - 0.10) < 0.001)
        #expect(abs(fillContent.green - 0.45) < 0.001)
        #expect(abs(fillContent.blue - 0.95) < 0.001)
        #expect(abs(centerColor.redComponent - 0.10) < 0.03)
        #expect(abs(centerColor.greenComponent - 0.45) < 0.03)
        #expect(abs(centerColor.blueComponent - 0.95) < 0.03)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.solidColorFillLayerValue", 26, 115, 242))
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .solidColorFill).contains { $0.id == fillLayer.id })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSolidColorFillNew"))

        viewModel.solidColorFillRed = 0.80
        viewModel.solidColorFillGreen = 0.10
        viewModel.solidColorFillBlue = 0.20
        viewModel.updateSelectedSolidColorFillLayer()

        let updatedContent = try #require(viewModel.document.selectedLayer?.solidColorFillContent?.normalized())
        let updatedColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 30, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(abs(updatedContent.red - 0.80) < 0.001)
        #expect(updatedColor.redComponent > 0.76)
        #expect(updatedColor.greenComponent < 0.13)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSolidColorFillUpdate"))

        viewModel.selectedFilter = .vignette
        viewModel.filterIntensity = 1
        viewModel.addSmartFilterToSelectedLayer()

        let smartFilteredLayer = try #require(viewModel.document.selectedLayer)
        let cornerColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        #expect(smartFilteredLayer.smartFilters.first?.kind == .vignette)
        #expect(cornerColor.redComponent < updatedColor.redComponent * 0.35)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == fillLayer.id })
        let restoredContent = try #require(restoredLayer.solidColorFillContent?.normalized())
        #expect(restoredLayer.isSolidColorFill)
        #expect(abs(restoredContent.red - 0.80) < 0.001)
        #expect(abs(restoredContent.green - 0.10) < 0.001)
        #expect(restoredLayer.smartFilters.first?.kind == .vignette)
    }

    @Test func imageEditorGradientFillLayerRendersUpdatesAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 30)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectedGradientFillPreset = .custom
        viewModel.gradientFillStartRed = 1
        viewModel.gradientFillStartGreen = 0
        viewModel.gradientFillStartBlue = 0
        viewModel.gradientFillEndRed = 0
        viewModel.gradientFillEndGreen = 1
        viewModel.gradientFillEndBlue = 0
        viewModel.selectedGradientFillStyle = .linear
        viewModel.gradientFillAngle = 0
        viewModel.gradientFillScale = 1
        viewModel.addGradientFillLayer()

        let gradientLayer = try #require(viewModel.document.selectedLayer)
        let content = try #require(gradientLayer.gradientFillContent?.normalized())
        let leftColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 4, y: 15))?.usingColorSpace(.deviceRGB))
        let rightColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 76, y: 15))?.usingColorSpace(.deviceRGB))

        #expect(content.preset == .custom)
        #expect(content.style == .linear)
        #expect(content.angle == 0)
        #expect(content.scale == 1)
        #expect(leftColor.redComponent > rightColor.redComponent + 0.55)
        #expect(rightColor.greenComponent > leftColor.greenComponent + 0.55)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.gradientFillLayerValue", content.preset.title, content.style.title, 0, 100))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGradientFillNew"))

        viewModel.gradientFillReverse = true
        viewModel.gradientFillScale = 2
        viewModel.updateSelectedGradientFillLayer()

        let updatedContent = try #require(viewModel.document.selectedLayer?.gradientFillContent?.normalized())
        let reversedLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 4, y: 15))?.usingColorSpace(.deviceRGB))
        let reversedRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 76, y: 15))?.usingColorSpace(.deviceRGB))
        #expect(updatedContent.reverse)
        #expect(updatedContent.scale == 2)
        #expect(reversedLeft.greenComponent > reversedRight.greenComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGradientFillUpdate"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == gradientLayer.id })
        let restoredContent = try #require(restoredLayer.gradientFillContent?.normalized())
        #expect(restoredContent.preset == .custom)
        #expect(restoredContent.style == .linear)
        #expect(restoredContent.reverse)
        #expect(restoredContent.scale == 2)
        #expect(restoredContent.startRed == 1)
        #expect(restoredContent.endGreen == 1)
    }

    @Test func imageEditorGradientFillStylesRenderAndRoundTripProjectState() async throws {
        let canvasSize = NSSize(width: 61, height: 61)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }

        viewModel.selectedGradientFillPreset = .custom
        viewModel.selectedGradientFillStyle = .radial
        viewModel.gradientFillStartRed = 1
        viewModel.gradientFillStartGreen = 0
        viewModel.gradientFillStartBlue = 0
        viewModel.gradientFillEndRed = 0
        viewModel.gradientFillEndGreen = 0
        viewModel.gradientFillEndBlue = 1
        viewModel.gradientFillScale = 1
        viewModel.addGradientFillLayer()

        let gradientLayer = try #require(viewModel.document.selectedLayer)
        let radialContent = try #require(gradientLayer.gradientFillContent?.normalized())
        let radialCenter = try #require(viewModel.currentImage.color(at: CGPoint(x: 30, y: 30))?.usingColorSpace(.deviceRGB))
        let radialCorner = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        #expect(radialContent.style == .radial)
        #expect(radialCenter.redComponent > radialCorner.redComponent + 0.45)
        #expect(radialCorner.blueComponent > radialCenter.blueComponent + 0.45)

        viewModel.selectedGradientFillStyle = .reflected
        viewModel.gradientFillAngle = 0
        viewModel.updateSelectedGradientFillLayer()

        let reflectedContent = try #require(viewModel.document.selectedLayer?.gradientFillContent?.normalized())
        let reflectedCenter = try #require(viewModel.currentImage.color(at: CGPoint(x: 30, y: 30))?.usingColorSpace(.deviceRGB))
        let reflectedEdge = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(reflectedContent.style == .reflected)
        #expect(reflectedCenter.redComponent > reflectedEdge.redComponent + 0.35)
        #expect(reflectedEdge.blueComponent > reflectedCenter.blueComponent + 0.35)

        viewModel.selectedGradientFillStyle = .diamond
        viewModel.updateSelectedGradientFillLayer()

        let diamondContent = try #require(viewModel.document.selectedLayer?.gradientFillContent?.normalized())
        let diamondCenter = try #require(viewModel.currentImage.color(at: CGPoint(x: 30, y: 30))?.usingColorSpace(.deviceRGB))
        let diamondCorner = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        #expect(diamondContent.style == .diamond)
        #expect(diamondCenter.redComponent > diamondCorner.redComponent + 0.45)
        #expect(diamondCorner.blueComponent > diamondCenter.blueComponent + 0.45)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.gradientFillLayerValue", diamondContent.preset.title, diamondContent.style.title, 0, 100))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == gradientLayer.id })
        let restoredContent = try #require(restoredLayer.gradientFillContent?.normalized())
        #expect(restoredContent.style == .diamond)
        #expect(restoredContent.preset == .custom)
        #expect(restoredContent.startRed == 1)
        #expect(restoredContent.endBlue == 1)
    }

    @Test func imageEditorVibranceAdjustmentPrioritizesMutedColorsAndSupportsLayerState() async throws {
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let mutedRed = NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.35, alpha: 1)
        let vividRed = NSColor(calibratedRed: 0.95, green: 0.05, blue: 0.05, alpha: 1)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 40, height: 40), mutedRed),
                (CGRect(x: 40, y: 0, width: 40, height: 40), vividRed)
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        let mutedBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let vividBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))
        let mutedBeforeSaturation = saturation(of: mutedBefore)
        let vividBeforeSaturation = saturation(of: vividBefore)

        viewModel.selectedAdjustment = .vibrance
        viewModel.adjustmentValue = 1
        viewModel.applyAdjustment()

        let mutedAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let vividAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))
        let mutedGain = saturation(of: mutedAfter) - mutedBeforeSaturation
        let vividGain = saturation(of: vividAfter) - vividBeforeSaturation

        #expect(mutedGain > 0.45)
        #expect(mutedGain > vividGain + 0.35)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.vibrance"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .vibrance
        viewModel.adjustmentValue = 0.75
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let previewMuted = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .vibrance)
        #expect(adjustmentLayer.adjustment?.amount == 0.75)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(saturation(of: previewMuted) > mutedBeforeSaturation + 0.30)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorPosterizeAdjustmentQuantizesChannelsAndSupportsLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.22, green: 0.47, blue: 0.84, alpha: 1)),
                (CGRect(x: 30, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.49, green: 0.51, blue: 0.49, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 40), NSColor(calibratedRed: 0.82, green: 0.18, blue: 0.18, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .posterize
        viewModel.adjustmentValue = 3
        viewModel.applyAdjustment()

        let darkQuantized = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let midQuantized = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 20))?.usingColorSpace(.deviceRGB))
        let lightQuantized = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(darkQuantized.redComponent < 0.05)
        #expect(abs(darkQuantized.greenComponent - 0.5) < 0.03)
        #expect(darkQuantized.blueComponent > 0.95)
        #expect(abs(midQuantized.redComponent - 0.5) < 0.03)
        #expect(abs(midQuantized.greenComponent - 0.5) < 0.03)
        #expect(lightQuantized.redComponent > 0.95)
        #expect(lightQuantized.greenComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.posterize"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .posterize
        viewModel.adjustmentValue = 4
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let preview = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .posterize)
        #expect(adjustmentLayer.adjustment?.amount == 4)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.posterizeLayerValue", 4))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(preview.greenComponent - (1.0 / 3.0)) < 0.04)
        #expect(preview.blueComponent > 0.95)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorShadowsHighlightsAdjustmentRecoversToneRangeAndSupportsLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 40), NSColor(calibratedWhite: 0.16, alpha: 1)),
                (CGRect(x: 30, y: 0, width: 30, height: 40), NSColor(calibratedWhite: 0.50, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 40), NSColor(calibratedWhite: 0.92, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        let shadowBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let midtoneBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 20))?.usingColorSpace(.deviceRGB))
        let highlightBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        viewModel.selectedAdjustment = .shadowsHighlights
        viewModel.shadowsHighlightsShadows = 0.70
        viewModel.shadowsHighlightsHighlights = 0.60
        viewModel.applyAdjustment()

        let shadowAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let midtoneAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 20))?.usingColorSpace(.deviceRGB))
        let highlightAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(shadowAfter.redComponent > shadowBefore.redComponent + 0.35)
        #expect(highlightAfter.redComponent < highlightBefore.redComponent - 0.25)
        #expect(abs(midtoneAfter.redComponent - midtoneBefore.redComponent) < 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.shadowsHighlights"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .shadowsHighlights
        viewModel.shadowsHighlightsShadows = 0.70
        viewModel.shadowsHighlightsHighlights = 0.60
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewShadow = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let previewHighlight = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .shadowsHighlights)
        #expect(abs(settings.shadowsHighlightsShadows - 0.70) < 0.001)
        #expect(abs(settings.shadowsHighlightsHighlights - 0.60) < 0.001)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.shadowsHighlightsLayerValue", 70, 60))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewShadow.redComponent > shadowBefore.redComponent + 0.35)
        #expect(previewHighlight.redComponent < highlightBefore.redComponent - 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorExposureAdjustmentUsesEvOffsetGammaAndSupportsLayerState() async throws {
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 40, height: 40), NSColor(calibratedWhite: 0.25, alpha: 1)),
                (CGRect(x: 40, y: 0, width: 40, height: 40), NSColor(calibratedWhite: 0.65, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        let shadowBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let highlightBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))

        viewModel.selectedAdjustment = .exposure
        viewModel.exposureEV = 1
        viewModel.exposureOffset = 0.05
        viewModel.exposureGamma = 2
        viewModel.applyAdjustment()

        let shadowAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let highlightAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(shadowAfter.redComponent > shadowBefore.redComponent + 0.45)
        #expect(highlightAfter.redComponent > 0.95)
        #expect(highlightAfter.redComponent > highlightBefore.redComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.exposure"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .exposure
        viewModel.exposureEV = -1
        viewModel.exposureOffset = -0.05
        viewModel.exposureGamma = 1.2
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewShadow = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let previewHighlight = try #require(viewModel.currentImage.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .exposure)
        #expect(abs(settings.exposureEV + 1) < 0.001)
        #expect(abs(settings.exposureOffset + 0.05) < 0.001)
        #expect(abs(settings.exposureGamma - 1.2) < 0.001)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.exposureLayerValue", -1.0, -0.05, 1.2))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewShadow.redComponent < shadowBefore.redComponent - 0.08)
        #expect(previewHighlight.redComponent < highlightBefore.redComponent - 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorBrightnessContrastAdjustmentCombinesToneControlsAndSupportsLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 40), NSColor(calibratedWhite: 0.30, alpha: 1)),
                (CGRect(x: 30, y: 0, width: 30, height: 40), NSColor(calibratedWhite: 0.50, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 40), NSColor(calibratedWhite: 0.70, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        let darkBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let midBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 20))?.usingColorSpace(.deviceRGB))
        let brightBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        viewModel.selectedAdjustment = .brightnessContrast
        viewModel.brightnessContrastBrightness = 0.10
        viewModel.brightnessContrastContrast = 1.00
        viewModel.applyAdjustment()

        let darkAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let midAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 20))?.usingColorSpace(.deviceRGB))
        let brightAfter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(darkAfter.redComponent < darkBefore.redComponent - 0.08)
        #expect(midAfter.redComponent > midBefore.redComponent + 0.08)
        #expect(brightAfter.redComponent > brightBefore.redComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.brightnessContrast"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .brightnessContrast
        viewModel.brightnessContrastBrightness = -0.10
        viewModel.brightnessContrastContrast = -0.40
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewDark = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 20))?.usingColorSpace(.deviceRGB))
        let previewBright = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .brightnessContrast)
        #expect(abs(settings.brightnessContrastBrightness + 0.10) < 0.001)
        #expect(abs(settings.brightnessContrastContrast + 0.40) < 0.001)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.brightnessContrastLayerValue", -10, -40))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewDark.redComponent > darkBefore.redComponent - 0.04)
        #expect(previewBright.redComponent < brightBefore.redComponent - 0.15)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorGradientMapAdjustmentSupportsPresetsAndLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 60)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 60), .black),
                (CGRect(x: 30, y: 0, width: 30, height: 60), NSColor(calibratedWhite: 0.5, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 60), .white)
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .gradientMap
        viewModel.selectedGradientMapPreset = .custom
        viewModel.gradientMapShadowRed = 1
        viewModel.gradientMapShadowGreen = 0
        viewModel.gradientMapShadowBlue = 0
        viewModel.gradientMapHighlightRed = 0
        viewModel.gradientMapHighlightGreen = 0
        viewModel.gradientMapHighlightBlue = 1
        viewModel.applyAdjustment()

        let mappedBlack = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let mappedGray = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        let mappedWhite = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(mappedBlack.redComponent > 0.95)
        #expect(mappedBlack.blueComponent < 0.05)
        #expect(mappedGray.redComponent > 0.35)
        #expect(mappedGray.blueComponent > 0.35)
        #expect(mappedWhite.blueComponent > 0.95)
        #expect(mappedWhite.redComponent < 0.05)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .gradientMap
        viewModel.selectedGradientMapPreset = .custom
        viewModel.gradientMapReverse = true
        viewModel.gradientMapShadowRed = 1
        viewModel.gradientMapShadowGreen = 0
        viewModel.gradientMapShadowBlue = 0
        viewModel.gradientMapHighlightRed = 0
        viewModel.gradientMapHighlightGreen = 0
        viewModel.gradientMapHighlightBlue = 1
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewBlack = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let previewWhite = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .gradientMap)
        #expect(settings.gradientMapPreset == .custom)
        #expect(settings.gradientMapReverse)
        #expect(settings.gradientMapShadowRed == 1)
        #expect(settings.gradientMapHighlightBlue == 1)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewBlack.blueComponent > 0.95)
        #expect(previewBlack.redComponent < 0.05)
        #expect(previewWhite.redComponent > 0.95)
        #expect(previewWhite.blueComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorSelectiveColorAdjustmentSupportsRangesAndLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 60)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 60), .systemRed),
                (CGRect(x: 30, y: 0, width: 30, height: 60), .systemGreen),
                (CGRect(x: 60, y: 0, width: 30, height: 60), .systemBlue)
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .selectiveColor
        var directSettings = ImageEditorSelectiveColorSettings()
        directSettings.setValues(ImageEditorSelectiveColorValues(cyan: 0.70), for: .reds)
        viewModel.selectiveColorSettings = directSettings
        viewModel.selectiveColorMethod = .absolute
        viewModel.applyAdjustment()

        let adjustedRed = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let adjustedGreen = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustedRed.redComponent < 0.45)
        #expect(adjustedRed.greenComponent < 0.05)
        #expect(adjustedRed.blueComponent < 0.05)
        #expect(adjustedGreen.greenComponent > 0.90)
        #expect(adjustedGreen.redComponent < 0.08)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .selectiveColor
        viewModel.selectedSelectiveColorRange = .reds
        var layerSettings = ImageEditorSelectiveColorSettings()
        layerSettings.setValues(ImageEditorSelectiveColorValues(cyan: 0.50, black: 0.20), for: .reds)
        layerSettings.setValues(ImageEditorSelectiveColorValues(yellow: 0.60), for: .blues)
        viewModel.selectiveColorSettings = layerSettings
        viewModel.selectiveColorMethod = .relative
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewRed = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let previewBlue = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .selectiveColor)
        #expect(settings.selectiveColorMethod == .relative)
        #expect(settings.selectiveColorSettings.values(for: .reds).cyan == 0.50)
        #expect(settings.selectiveColorSettings.values(for: .reds).black == 0.20)
        #expect(settings.selectiveColorSettings.values(for: .blues).yellow == 0.60)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewRed.redComponent < 0.45)
        #expect(previewBlue.blueComponent > previewBlue.redComponent + 0.30)
        #expect(previewBlue.greenComponent < 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorPhotoFilterAdjustmentSupportsPresetsAndCustomLayerState() async throws {
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(size: canvasSize, background: NSColor(calibratedWhite: 0.5, alpha: 1))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .photoFilter
        viewModel.selectedPhotoFilterPreset = .warming85
        viewModel.photoFilterDensity = 0.50
        viewModel.photoFilterPreserveLuminosity = true
        viewModel.applyAdjustment()

        let warmed = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(warmed.redComponent > warmed.blueComponent + 0.20)
        #expect(warmed.greenComponent > warmed.blueComponent + 0.08)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .photoFilter
        viewModel.selectedPhotoFilterPreset = .custom
        viewModel.photoFilterDensity = 0.60
        viewModel.photoFilterPreserveLuminosity = false
        viewModel.photoFilterCustomRed = 0.10
        viewModel.photoFilterCustomGreen = 0.30
        viewModel.photoFilterCustomBlue = 1.0
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let preview = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .photoFilter)
        #expect(settings.photoFilterPreset == .custom)
        #expect(settings.photoFilterDensity == 0.60)
        #expect(!settings.photoFilterPreserveLuminosity)
        #expect(settings.photoFilterCustomRed == 0.10)
        #expect(settings.photoFilterCustomGreen == 0.30)
        #expect(settings.photoFilterCustomBlue == 1.0)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(preview.blueComponent > preview.redComponent + 0.30)
        #expect(preview.blueComponent > preview.greenComponent + 0.20)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorColorLookupAdjustmentSupportsPresetsAndLayerState() async throws {
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(size: canvasSize, background: NSColor(calibratedWhite: 0.45, alpha: 1))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .colorLookup
        viewModel.selectedColorLookupPreset = .crispWarm
        viewModel.applyAdjustment()

        let warmed = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(warmed.redComponent > warmed.blueComponent + 0.09)
        #expect(warmed.greenComponent > warmed.blueComponent + 0.04)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.adjustment.colorLookup"))

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .colorLookup
        viewModel.selectedColorLookupPreset = .moonlight
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let preview = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .colorLookup)
        #expect(settings.colorLookupPreset == .moonlight)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.colorLookupLayerValue", ImageEditorColorLookupPreset.moonlight.title))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(preview.blueComponent > preview.redComponent + 0.13)
        #expect(preview.greenComponent > preview.redComponent + 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorColorLookupAdjustmentImportsCubeLUTAndPersistsLayerState() async throws {
        let cubeText = """
        TITLE "Swap RB"
        LUT_3D_SIZE 2
        0 0 0
        1 0 0
        0 1 0
        1 1 0
        0 0 1
        1 0 1
        0 1 1
        1 1 1
        """
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(size: canvasSize, background: NSColor(calibratedRed: 0.20, green: 0.40, blue: 0.80, alpha: 1))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        #expect(viewModel.importColorLookupCube(name: "Swap RB", contents: cubeText))
        #expect(viewModel.selectedAdjustment == .colorLookup)
        #expect(viewModel.selectedColorLookupPreset == .customCube)
        #expect(viewModel.selectedColorLookupCube.name == "Swap RB")
        #expect(viewModel.selectedColorLookupCube.dimension == 2)
        viewModel.applyAdjustment()

        let swapped = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(swapped.redComponent > 0.74)
        #expect(swapped.blueComponent < 0.26)
        #expect(abs(swapped.greenComponent - 0.40) < 0.04)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        #expect(viewModel.importColorLookupCube(name: "Swap RB", contents: cubeText))
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let preview = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .colorLookup)
        #expect(settings.colorLookupPreset == .customCube)
        #expect(settings.colorLookupCube.name == "Swap RB")
        #expect(settings.colorLookupCube.dimension == 2)
        #expect(settings.colorLookupCube.values.count == 24)
        #expect(viewModel.selectedLayerGeometryText == L10n.format("imageEditor.properties.colorLookupLayerValue", "Swap RB"))
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(preview.redComponent > 0.74)
        #expect(preview.blueComponent < 0.26)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorChannelMixerAdjustmentSupportsRGBMatrixAndMonochromeLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 60)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 60), .systemRed),
                (CGRect(x: 30, y: 0, width: 30, height: 60), .systemGreen),
                (CGRect(x: 60, y: 0, width: 30, height: 60), .systemBlue)
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .channelMixer
        viewModel.channelMixerRedRed = 0
        viewModel.channelMixerRedGreen = 1
        viewModel.applyAdjustment()

        let shiftedRed = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let shiftedGreen = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(shiftedRed.redComponent < 0.05)
        #expect(shiftedRed.greenComponent < 0.05)
        #expect(shiftedGreen.redComponent > 0.90)
        #expect(shiftedGreen.greenComponent > 0.90)
        #expect(shiftedGreen.blueComponent < 0.05)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .channelMixer
        viewModel.channelMixerMonochrome = true
        viewModel.channelMixerMonoRed = 1.20
        viewModel.channelMixerMonoGreen = 0.45
        viewModel.channelMixerMonoBlue = 0.10
        viewModel.channelMixerMonoConstant = 0
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewRed = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let previewGreen = try #require(viewModel.currentImage.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        let previewBlue = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .channelMixer)
        #expect(settings.channelMixerMonochrome)
        #expect(settings.channelMixerMonoRed == 1.20)
        #expect(settings.channelMixerMonoGreen == 0.45)
        #expect(settings.channelMixerMonoBlue == 0.10)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(previewRed.redComponent - previewRed.greenComponent) < 0.02)
        #expect(previewRed.redComponent > previewGreen.redComponent + 0.30)
        #expect(previewGreen.redComponent > previewBlue.redComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorHueSaturationAdjustmentSupportsColorizeAndLayerState() async throws {
        let canvasSize = NSSize(width: 80, height: 40)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 40, height: 40), .systemRed),
                (CGRect(x: 40, y: 0, width: 40, height: 40), .systemGreen)
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .hueSaturation
        viewModel.hueSaturationHue = 120
        viewModel.applyAdjustment()

        let shiftedRed = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(shiftedRed.greenComponent > shiftedRed.redComponent + 0.45)
        #expect(shiftedRed.greenComponent > shiftedRed.blueComponent + 0.45)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .hueSaturation
        viewModel.hueSaturationHue = -120
        viewModel.hueSaturationSaturation = 0.60
        viewModel.hueSaturationLightness = 0.10
        viewModel.hueSaturationColorize = true
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 20))?.usingColorSpace(.deviceRGB))
        let previewRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 60, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .hueSaturation)
        #expect(settings.hueSaturationHue == -120)
        #expect(settings.hueSaturationSaturation == 0.60)
        #expect(settings.hueSaturationLightness == 0.10)
        #expect(settings.hueSaturationColorize)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(previewLeft.blueComponent > previewLeft.redComponent + 0.30)
        #expect(previewRight.blueComponent > previewRight.greenComponent + 0.30)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @Test func imageEditorBlackWhiteAdjustmentSupportsSixChannelMixAndLayerState() async throws {
        let canvasSize = NSSize(width: 90, height: 60)
        let sourceImage = bitmapImage(size: canvasSize, background: .black)
        let layerImage = bitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 0, y: 0, width: 30, height: 60), .systemRed),
                (CGRect(x: 30, y: 0, width: 30, height: 60), .systemGreen),
                (CGRect(x: 60, y: 0, width: 30, height: 60), .systemBlue)
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.selectedAdjustment = .blackWhite
        viewModel.blackWhiteReds = 1.20
        viewModel.blackWhiteGreens = 0.50
        viewModel.blackWhiteBlues = 0.15
        viewModel.applyAdjustment()

        let redGray = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let greenGray = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        let blueGray = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(abs(redGray.redComponent - redGray.greenComponent) < 0.02)
        #expect(abs(greenGray.greenComponent - greenGray.blueComponent) < 0.02)
        #expect(redGray.redComponent > greenGray.redComponent + 0.25)
        #expect(greenGray.redComponent > blueGray.redComponent + 0.18)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .blackWhite
        viewModel.blackWhiteReds = 1.10
        viewModel.blackWhiteYellows = 0.70
        viewModel.blackWhiteGreens = 0.45
        viewModel.blackWhiteCyans = 0.65
        viewModel.blackWhiteBlues = 0.20
        viewModel.blackWhiteMagentas = 0.90
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let previewRed = try #require(viewModel.currentImage.color(at: CGPoint(x: 15, y: 30))?.usingColorSpace(.deviceRGB))
        let previewBlue = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .blackWhite)
        #expect(settings.blackWhiteReds == 1.10)
        #expect(settings.blackWhiteYellows == 0.70)
        #expect(settings.blackWhiteGreens == 0.45)
        #expect(settings.blackWhiteCyans == 0.65)
        #expect(settings.blackWhiteBlues == 0.20)
        #expect(settings.blackWhiteMagentas == 0.90)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(previewRed.redComponent - previewRed.blueComponent) < 0.03)
        #expect(previewRed.redComponent > previewBlue.redComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    private func bitmapImage(
        size: NSSize,
        background: NSColor,
        fills: [(rect: CGRect, color: NSColor)] = []
    ) -> NSImage {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let representation else { return NSImage(size: size) }

        for y in 0..<height {
            for x in 0..<width {
                let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                let fill = fills.last { item in
                    item.rect.contains(point)
                }
                representation.setColor(fill?.color ?? background, atX: x, y: y)
            }
        }

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        return image
    }

    private func saturation(of color: NSColor) -> CGFloat {
        let red = color.redComponent
        let green = color.greenComponent
        let blue = color.blueComponent
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let lightness = (maximum + minimum) / 2
        guard maximum > minimum else { return 0 }
        if lightness > 0.5 {
            return (maximum - minimum) / max(0.0001, 2 - maximum - minimum)
        }
        return (maximum - minimum) / max(0.0001, maximum + minimum)
    }
}
