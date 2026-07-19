//
//  ImageEditorFilterTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorFilterTests {
    @Test func everyFilterAtZeroStrengthIsAnExactNoOpAcrossRenderingPaths() throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let sourceImage = gradientImage(size: canvasSize)
        let sourcePixels = try #require(sourceImage.qingtuPNGData())

        for filter in ImageEditorFilter.allCases {
            let zeroOutput = try #require(sourceImage.filtered(kind: filter, intensity: 0))
            let negativeOutput = try #require(sourceImage.filtered(kind: filter, intensity: -1))
            #expect(zeroOutput === sourceImage, "\(filter.rawValue) should bypass rendering at 0%")
            #expect(negativeOutput === sourceImage, "\(filter.rawValue) should clamp negative strength to 0%")
            #expect(zeroOutput.qingtuPNGData() == sourcePixels)
            #expect(negativeOutput.qingtuPNGData() == sourcePixels)
        }

        let destructiveViewModel = ImageEditorViewModel(
            sourceName: "zero-filter.png",
            image: sourceImage
        ) { _ in }
        let destructivePreviewBefore = destructiveViewModel.currentImage
        destructiveViewModel.selectedFilter = .pixelate
        destructiveViewModel.filterIntensity = 0
        destructiveViewModel.applySelectedFilter()
        #expect(imageEditorMaximumPixelDifference(destructiveViewModel.currentImage, destructivePreviewBefore) == 0)

        let filterLayerViewModel = ImageEditorViewModel(
            sourceName: "zero-filter-layer.png",
            image: sourceImage
        ) { _ in }
        let filterLayerPreviewBefore = filterLayerViewModel.currentImage
        filterLayerViewModel.selectedFilter = .emboss
        filterLayerViewModel.filterIntensity = 0
        filterLayerViewModel.addFilterLayer()

        #expect(filterLayerViewModel.document.selectedLayer?.isFilter == true)
        #expect(filterLayerViewModel.document.selectedLayer?.filter?.kind == .emboss)
        #expect(imageEditorMaximumPixelDifference(filterLayerViewModel.currentImage, filterLayerPreviewBefore) == 0)

        let smartViewModel = ImageEditorViewModel(
            sourceName: "zero-smart-filter.png",
            image: sourceImage
        ) { _ in }
        let smartPreviewBefore = smartViewModel.currentImage
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .highPass
        smartViewModel.filterIntensity = 0
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.kind == .highPass)
        #expect(smartLayer.smartFilters.first?.intensity == 0)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(imageEditorMaximumPixelDifference(smartViewModel.currentImage, smartPreviewBefore) == 0)
    }

    @Test func zeroStrengthMaskedFilterPreservesSemiTransparentPixels() throws {
        let canvasSize = NSSize(width: 32, height: 24)
        let sourceImage = solidImage(
            size: canvasSize,
            color: NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.85, alpha: 0.35)
        )
        let mask = solidImage(size: canvasSize, color: .white)

        let directOutput = try #require(
            sourceImage.applyingFilter(kind: .pixelate, intensity: 0, mask: mask)
        )
        let negativeOutput = try #require(
            sourceImage.applyingFilter(kind: .pixelate, intensity: -1, mask: mask)
        )
        #expect(directOutput === sourceImage)
        #expect(negativeOutput === sourceImage)
        #expect(imageEditorMaximumPixelDifference(directOutput, sourceImage) == 0)
        #expect(imageEditorMaximumPixelDifference(negativeOutput, sourceImage) == 0)

        let viewModel = ImageEditorViewModel(
            sourceName: "zero-masked-filter.png",
            image: sourceImage
        ) { _ in }
        let compositeBefore = viewModel.currentImage
        viewModel.selectedFilter = .emboss
        viewModel.filterIntensity = 0
        viewModel.addFilterLayer()

        let filterLayerIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == viewModel.document.selectedLayerID }
        )
        viewModel.document.layers[filterLayerIndex].mask = mask

        #expect(viewModel.document.layers[filterLayerIndex].isFilter)
        #expect(viewModel.document.layers[filterLayerIndex].mask != nil)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, compositeBefore) == 0)
    }

    @Test func maskedFilterInterpolatesPixelsWithoutIncreasingSourceAlpha() throws {
        let canvasSize = NSSize(width: 32, height: 24)
        let sourceImage = solidImage(
            size: canvasSize,
            color: NSColor(calibratedRed: 0.30, green: 0.55, blue: 0.75, alpha: 0.35)
        )
        let mask = splitColorImage(
            size: canvasSize,
            left: NSColor(calibratedWhite: 1, alpha: 0.5),
            right: .clear
        )

        let output = try #require(
            sourceImage.applyingFilter(kind: .addNoise, intensity: 1, mask: mask)
        )
        let sourceLeft = try #require(
            sourceImage.color(at: CGPoint(x: 8, y: 12))?.usingColorSpace(.deviceRGB)
        )
        let outputLeft = try #require(
            output.color(at: CGPoint(x: 8, y: 12))?.usingColorSpace(.deviceRGB)
        )
        let sourceRight = try #require(
            sourceImage.color(at: CGPoint(x: 24, y: 12))?.usingColorSpace(.deviceRGB)
        )
        let outputRight = try #require(
            output.color(at: CGPoint(x: 24, y: 12))?.usingColorSpace(.deviceRGB)
        )

        #expect(abs(outputLeft.alphaComponent - sourceLeft.alphaComponent) < 0.01)
        #expect(abs(outputRight.alphaComponent - sourceRight.alphaComponent) < 0.01)
        #expect(abs(outputRight.redComponent - sourceRight.redComponent) < 0.01)
        #expect(abs(outputRight.greenComponent - sourceRight.greenComponent) < 0.01)
        #expect(abs(outputRight.blueComponent - sourceRight.blueComponent) < 0.01)
        #expect(imageEditorMaximumPixelDifference(output, sourceImage) > 0)
    }

    @Test func imageEditorAppliesCurrentFilterWithClassicLastFilterCommand() throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let sourceImage = solidImage(size: canvasSize, color: NSColor(calibratedWhite: 0.5, alpha: 1))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }

        let beforeA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 16))?.usingColorSpace(.deviceRGB))
        let beforeB = try #require(viewModel.currentImage.color(at: CGPoint(x: 13, y: 16))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.canApplySelectedFilter)
        viewModel.selectedFilter = .addNoise
        viewModel.filterIntensity = 0.8
        viewModel.applySelectedFilter()

        let afterA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 16))?.usingColorSpace(.deviceRGB))
        let afterB = try #require(viewModel.currentImage.color(at: CGPoint(x: 13, y: 16))?.usingColorSpace(.deviceRGB))

        #expect(abs(beforeA.redComponent - beforeB.redComponent) < 0.002)
        #expect(abs(afterA.redComponent - afterB.redComponent) > 0.02)
        #expect(viewModel.document.history.last?.title == L10n.format("imageEditor.history.filter", ImageEditorFilter.addNoise.title))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.filter", ImageEditorFilter.addNoise.title))
    }

    @Test func commandFRepeatsTheLastSuccessfulFilterAndItsParameters() throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let sourceImage = solidImage(size: canvasSize, color: NSColor(calibratedWhite: 0.5, alpha: 1))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.2
        viewModel.applySelectedFilter()
        let invocation = try #require(viewModel.lastAppliedFilter)

        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 0.9
        let beforeRepeat = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.applyLastFilter()
        let afterRepeat = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(invocation.kind == .gaussianBlur)
        #expect(invocation.intensity == 0.2)
        #expect(viewModel.lastAppliedFilter == invocation)
        #expect(afterRepeat != beforeRepeat)
        #expect(viewModel.document.history.last?.title == L10n.format("imageEditor.history.filter", ImageEditorFilter.gaussianBlur.title))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.filter", ImageEditorFilter.gaussianBlur.title))
    }

    @Test func imageEditorBatchAddsUpdatesAndClearsSmartFiltersAcrossEditableSelection() async throws {
        let canvasSize = NSSize(width: 32, height: 24)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(size: canvasSize, color: .black)
        ) { _ in }

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

        #expect(viewModel.canAddSmartFilterToSelectedLayer)
        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.35
        viewModel.addSmartFilterToSelectedLayer()

        var first = try #require(layer(firstID, in: viewModel))
        var second = try #require(layer(secondID, in: viewModel))
        var locked = try #require(layer(lockedID, in: viewModel))
        var group = try #require(layer(groupID, in: viewModel))
        #expect(first.smartFilters.count == 1)
        #expect(first.smartFilters.first?.kind == .gaussianBlur)
        #expect(first.smartFilters.first?.intensity == 0.35)
        #expect(second.smartFilters.count == 1)
        #expect(second.smartFilters.first?.kind == .gaussianBlur)
        #expect(second.smartFilters.first?.intensity == 0.35)
        #expect(locked.smartFilters.isEmpty)
        #expect(group.smartFilters.isEmpty)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        #expect(viewModel.canUpdateLastSmartFilterOnSelectedLayer)
        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 0.8
        viewModel.updateLastSmartFilterOnSelectedLayer()

        first = try #require(layer(firstID, in: viewModel))
        second = try #require(layer(secondID, in: viewModel))
        locked = try #require(layer(lockedID, in: viewModel))
        group = try #require(layer(groupID, in: viewModel))
        #expect(first.smartFilters.count == 1)
        #expect(first.smartFilters.first?.kind == .pixelate)
        #expect(first.smartFilters.first?.intensity == 0.8)
        #expect(first.smartFilters.first?.isEnabled == true)
        #expect(second.smartFilters.count == 1)
        #expect(second.smartFilters.first?.kind == .pixelate)
        #expect(second.smartFilters.first?.intensity == 0.8)
        #expect(second.smartFilters.first?.isEnabled == true)
        #expect(locked.smartFilters.isEmpty)
        #expect(group.smartFilters.isEmpty)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterUpdate"))

        #expect(viewModel.canClearSmartFiltersFromSelectedLayer)
        viewModel.clearSmartFiltersFromSelectedLayer()

        first = try #require(layer(firstID, in: viewModel))
        second = try #require(layer(secondID, in: viewModel))
        locked = try #require(layer(lockedID, in: viewModel))
        group = try #require(layer(groupID, in: viewModel))
        #expect(first.smartFilters.isEmpty)
        #expect(second.smartFilters.isEmpty)
        #expect(locked.smartFilters.isEmpty)
        #expect(group.smartFilters.isEmpty)
        #expect(!viewModel.canUpdateLastSmartFilterOnSelectedLayer)
        #expect(!viewModel.canClearSmartFiltersFromSelectedLayer)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterClear"))
    }

    @Test func backgroundBlurSmartFilterSamplesTheBackdropWithoutChangingLayerPixels() throws {
        let canvasSize = NSSize(width: 64, height: 32)
        let sourceImage = splitColorImage(
            size: canvasSize,
            left: .black,
            right: .white
        )
        let plainViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let plainLayer = ImageEditorLayer.blank(name: "Glass", size: NSSize(width: 24, height: 32))
        var plain = plainLayer
        plain.image = solidImage(
            size: NSSize(width: 24, height: 32),
            color: NSColor.white.withAlphaComponent(0.2)
        )
        plain.frame = CGRect(x: 20, y: 0, width: 24, height: 32)
        plainViewModel.document.layers.append(plain)

        let blurredViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        var blurred = plain
        var filter = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 1,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 6)
        )
        filter.appliesToBackdrop = true
        blurred.smartFilters = [filter]
        blurredViewModel.document.layers.append(blurred)

        let plainColor = try #require(
            plainViewModel.document.compositedImage.color(at: CGPoint(x: 32, y: 16))?.usingColorSpace(.deviceRGB)
        )
        let blurredColor = try #require(
            blurredViewModel.document.compositedImage.color(at: CGPoint(x: 32, y: 16))?.usingColorSpace(.deviceRGB)
        )
        #expect(blurred.smartFilters.first?.appliesToBackdrop == true)
        #expect(blurred.image.qingtuPNGData() == plain.image.qingtuPNGData())
        #expect(abs(blurredColor.redComponent - plainColor.redComponent) > 0.02)
        #expect(abs(blurredColor.redComponent - blurredColor.blueComponent) < 0.02)
    }

    @Test func imageEditorUnsharpMaskFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = softEdgeImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let beforeDarkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 23, y: 24))?.usingColorSpace(.deviceRGB))
        let beforeLightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .unsharpMask
        viewModel.filterIntensity = 1
        viewModel.filterUnsharpRadius = 2
        viewModel.filterUnsharpThreshold = 0
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sharpenedDarkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 23, y: 24))?.usingColorSpace(.deviceRGB))
        let sharpenedLightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .unsharpMask)
        #expect(filterLayer.filterSettings.normalized().unsharpRadius == 2)
        #expect(filterLayer.filterSettings.normalized().unsharpThreshold == 0)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sharpenedDarkSide.redComponent < beforeDarkSide.redComponent - 0.08)
        #expect(sharpenedLightSide.redComponent > beforeLightSide.redComponent + 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .unsharpMask
        smartViewModel.filterIntensity = 1
        smartViewModel.filterUnsharpRadius = 2
        smartViewModel.filterUnsharpThreshold = 0
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartSharpenedLightSide = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .unsharpMask)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.unsharpRadius == 2)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.unsharpThreshold == 0)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSharpenedLightSide.redComponent > beforeLightSide.redComponent + 0.08)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let thresholdFiltered = try #require(
            sourceImage.filtered(
                kind: .unsharpMask,
                intensity: 1,
                settings: ImageEditorFilterSettings(unsharpRadius: 2, unsharpThreshold: 1)
            )
        )
        let thresholdLightSide = try #require(thresholdFiltered.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(abs(thresholdLightSide.redComponent - beforeLightSide.redComponent) < 0.01)
    }

    @Test func imageEditorMedianFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = saltAndPepperImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let noisyWhiteBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        let noisyBlackBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 25, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .median
        viewModel.filterIntensity = 1
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let whiteAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        let blackAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 25, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .median)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(noisyWhiteBefore.redComponent > 0.95)
        #expect(noisyBlackBefore.redComponent < 0.05)
        #expect(abs(whiteAfter.redComponent - 0.5) < 0.04)
        #expect(abs(blackAfter.redComponent - 0.5) < 0.04)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())
        smartViewModel.selectedFilter = .median
        smartViewModel.filterIntensity = 1
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartWhiteAfter = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .median)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(abs(smartWhiteAfter.redComponent - 0.5) < 0.04)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func imageEditorAddNoiseFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = solidImage(size: canvasSize, color: NSColor(calibratedWhite: 0.5, alpha: 1))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let beforeA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let beforeB = try #require(viewModel.currentImage.color(at: CGPoint(x: 13, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .addNoise
        viewModel.filterIntensity = 0.8
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let noisyA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let noisyB = try #require(viewModel.currentImage.color(at: CGPoint(x: 13, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .addNoise)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(beforeA.redComponent - beforeB.redComponent) < 0.002)
        #expect(abs(noisyA.redComponent - noisyB.redComponent) > 0.02)
        #expect(abs(noisyA.redComponent - noisyA.greenComponent) < 0.002)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())
        smartViewModel.selectedFilter = .addNoise
        smartViewModel.filterIntensity = 0.8
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartNoisyA = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let smartNoisyB = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 13, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .addNoise)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(abs(smartNoisyA.redComponent - smartNoisyB.redComponent) > 0.02)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func imageEditorMotionBlurFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = verticalEdgeImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let beforeDarkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))
        let beforeLightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 37, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .motionBlur
        viewModel.filterIntensity = 0.9
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let blurredDarkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))
        let blurredLightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 37, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .motionBlur)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(blurredDarkSide.redComponent > beforeDarkSide.redComponent + 0.08)
        #expect(blurredLightSide.redComponent < beforeLightSide.redComponent - 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .motionBlur
        smartViewModel.filterIntensity = 0.9
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartBlurredDarkSide = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .motionBlur)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartBlurredDarkSide.redComponent > beforeDarkSide.redComponent + 0.08)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))
    }

    @Test func imageEditorPixelateFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = gradientImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let beforeNearA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let beforeNearB = try #require(viewModel.currentImage.color(at: CGPoint(x: 14, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 0.9
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let filterLayerNearA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let filterLayerNearB = try #require(viewModel.currentImage.color(at: CGPoint(x: 14, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .pixelate)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(beforeNearA.redComponent - beforeNearB.redComponent) > 0.01)
        #expect(abs(filterLayerNearA.redComponent - filterLayerNearB.redComponent) < 0.004)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())

        smartViewModel.selectedFilter = .pixelate
        smartViewModel.filterIntensity = 0.9
        #expect(smartViewModel.canAddSmartFilterToSelectedLayer)
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartNearA = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let smartNearB = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 14, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(smartLayer.smartFilters.first?.kind == .pixelate)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(abs(smartNearA.redComponent - smartNearB.redComponent) < 0.004)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) != smartPreviewBefore)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterToggle"))
    }

    @Test func imageEditorHighPassFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = verticalEdgeImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectedFilter = .highPass
        viewModel.filterIntensity = 0.65
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let flatLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let edgeDarkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 34, y: 24))?.usingColorSpace(.deviceRGB))
        let edgeLightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 37, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .highPass)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(flatLeft.redComponent - 0.5) < 0.04)
        #expect(edgeDarkSide.redComponent < 0.20)
        #expect(edgeLightSide.redComponent > 0.80)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())

        smartViewModel.selectedFilter = .highPass
        smartViewModel.filterIntensity = 0.65
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartEdgeLightSide = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 37, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .highPass)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartEdgeLightSide.redComponent > 0.80)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func imageEditorEmbossFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = verticalEdgeImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectedFilter = .emboss
        viewModel.filterIntensity = 0.75
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let flatLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let edgeHighlight = try #require(viewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .emboss)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(flatLeft.redComponent - 0.5) < 0.04)
        #expect(abs(flatLeft.redComponent - flatLeft.greenComponent) < 0.002)
        #expect(edgeHighlight.redComponent > 0.85)
        #expect(abs(edgeHighlight.redComponent - edgeHighlight.greenComponent) < 0.002)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())

        smartViewModel.selectedFilter = .emboss
        smartViewModel.filterIntensity = 0.75
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartEdgeHighlight = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .emboss)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartEdgeHighlight.redComponent > 0.85)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func imageEditorFindEdgesFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = verticalEdgeImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectedFilter = .findEdges
        viewModel.filterIntensity = 1
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let flatLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let flatRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 60, y: 24))?.usingColorSpace(.deviceRGB))
        let detectedEdge = try #require(viewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .findEdges)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(flatLeft.redComponent > 0.95)
        #expect(flatRight.redComponent > 0.95)
        #expect(detectedEdge.redComponent < 0.08)
        #expect(abs(detectedEdge.redComponent - detectedEdge.greenComponent) < 0.002)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())

        smartViewModel.selectedFilter = .findEdges
        smartViewModel.filterIntensity = 1
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartDetectedEdge = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .findEdges)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartDetectedEdge.redComponent < 0.08)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func imageEditorMinimumAndMaximumFiltersExpandDarkAndLightRegions() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let whiteSpotImage = binarySpotImage(
            size: canvasSize,
            background: .black,
            spot: .white,
            spotSize: 5
        )
        let maximumViewModel = ImageEditorViewModel(sourceName: "source.png", image: whiteSpotImage) { _ in }
        maximumViewModel.replaceSelectedLayerImageForTesting(whiteSpotImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let maximumBaseLayerID = try #require(maximumViewModel.document.selectedLayerID)
        let maximumBasePixelsBefore = try #require(maximumViewModel.document.selectedLayer?.image.qingtuPNGData())

        maximumViewModel.selectedFilter = .maximum
        maximumViewModel.filterIntensity = 0.35
        maximumViewModel.addFilterLayer()

        let maximumLayer = try #require(maximumViewModel.document.selectedLayer)
        let expandedLight = try #require(maximumViewModel.currentImage.color(at: CGPoint(x: 28, y: 24))?.usingColorSpace(.deviceRGB))
        let farDark = try #require(maximumViewModel.currentImage.color(at: CGPoint(x: 8, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(maximumLayer.isFilter)
        #expect(maximumLayer.filter?.kind == .maximum)
        #expect(maximumViewModel.document.layers.first { $0.id == maximumBaseLayerID }?.image.qingtuPNGData() == maximumBasePixelsBefore)
        #expect(expandedLight.redComponent > 0.95)
        #expect(farDark.redComponent < 0.05)
        #expect(maximumViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let blackSpotImage = binarySpotImage(
            size: canvasSize,
            background: .white,
            spot: .black,
            spotSize: 5
        )
        let minimumViewModel = ImageEditorViewModel(sourceName: "source.png", image: blackSpotImage) { _ in }
        minimumViewModel.replaceSelectedLayerImageForTesting(blackSpotImage, historyTitle: L10n.text("imageEditor.history.brush"))
        minimumViewModel.selectedFilter = .minimum
        minimumViewModel.filterIntensity = 0.35
        minimumViewModel.addFilterLayer()

        let minimumLayer = try #require(minimumViewModel.document.selectedLayer)
        let expandedDark = try #require(minimumViewModel.currentImage.color(at: CGPoint(x: 28, y: 24))?.usingColorSpace(.deviceRGB))
        let farLight = try #require(minimumViewModel.currentImage.color(at: CGPoint(x: 8, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(minimumLayer.isFilter)
        #expect(minimumLayer.filter?.kind == .minimum)
        #expect(expandedDark.redComponent < 0.05)
        #expect(farLight.redComponent > 0.95)

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: whiteSpotImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(whiteSpotImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())
        smartViewModel.selectedFilter = .maximum
        smartViewModel.filterIntensity = 0.35
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartExpandedLight = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 28, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .maximum)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartExpandedLight.redComponent > 0.95)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func imageEditorOilPaintFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = colorSpotImage(
            size: canvasSize,
            background: NSColor(calibratedRed: 0.9, green: 0.1, blue: 0.08, alpha: 1),
            spot: NSColor(calibratedRed: 0.05, green: 0.2, blue: 0.95, alpha: 1),
            spotSize: 3
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let blueSpotBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .oilPaint
        viewModel.filterIntensity = 0.75
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let paintedCenter = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .oilPaint)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(blueSpotBefore.blueComponent > 0.85)
        #expect(paintedCenter.redComponent > 0.75)
        #expect(paintedCenter.blueComponent < 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())
        smartViewModel.selectedFilter = .oilPaint
        smartViewModel.filterIntensity = 0.75
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartPaintedCenter = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .oilPaint)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartPaintedCenter.redComponent > 0.75)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func imageEditorVignetteFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = solidImage(size: canvasSize, color: NSColor(calibratedWhite: 0.8, alpha: 1))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let centerBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .vignette
        viewModel.filterIntensity = 1
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let centerAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        let cornerAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .vignette)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(centerBefore.redComponent - 0.8) < 0.02)
        #expect(centerAfter.redComponent > 0.74)
        #expect(cornerAfter.redComponent < 0.18)
        #expect(abs(cornerAfter.redComponent - cornerAfter.greenComponent) < 0.002)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())
        smartViewModel.selectedFilter = .vignette
        smartViewModel.filterIntensity = 1
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartCornerAfter = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .vignette)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartCornerAfter.redComponent < 0.18)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func imageEditorLiquifyPushFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = splitColorImage(size: canvasSize, left: .systemRed, right: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let centerBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .liquifyPush
        viewModel.filterIntensity = 1
        viewModel.filterLiquifyPushX = 1
        viewModel.filterLiquifyPushY = 0
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let centerAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .liquifyPush)
        #expect(filterLayer.filterSettings.normalized().liquifyPushX == 1)
        #expect(filterLayer.filterSettings.normalized().liquifyPushY == 0)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(centerBefore.blueComponent > centerBefore.redComponent + 0.4)
        #expect(centerAfter.redComponent > centerAfter.blueComponent + 0.4)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .liquifyPush
        smartViewModel.filterIntensity = 1
        smartViewModel.filterLiquifyPushX = 1
        smartViewModel.filterLiquifyPushY = 0
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartCenterAfter = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .liquifyPush)
        #expect(smartFilter.normalizedSettings.liquifyPushX == 1)
        #expect(smartFilter.normalizedSettings.liquifyPushY == 0)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartCenterAfter.redComponent > smartCenterAfter.blueComponent + 0.4)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterLiquifyPushItem", smartFilter.kind.title, 100, 100, 0))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .liquifyPush)
        #expect(restoredFilter.normalizedSettings.liquifyPushX == 1)
        #expect(restoredFilter.normalizedSettings.liquifyPushY == 0)
    }

    @Test func imageEditorLiquifyTwirlFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = quadrantImage(
            size: canvasSize,
            topLeft: .systemRed,
            topRight: .systemBlue,
            bottomLeft: .systemGreen,
            bottomRight: .systemYellow
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let samplePoint = CGPoint(x: 24, y: 12)
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .liquifyTwirl
        viewModel.filterIntensity = 1
        viewModel.filterLiquifyTwirlAngle = 1
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sampleAfter = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .liquifyTwirl)
        #expect(filterLayer.filterSettings.normalized().liquifyTwirlAngle == 1)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleBefore.blueComponent > sampleBefore.redComponent + 0.4)
        #expect(sampleAfter.redComponent > sampleAfter.blueComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .liquifyTwirl
        smartViewModel.filterIntensity = 1
        smartViewModel.filterLiquifyTwirlAngle = 1
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .liquifyTwirl)
        #expect(smartFilter.normalizedSettings.liquifyTwirlAngle == 1)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleAfter.redComponent > smartSampleAfter.blueComponent + 0.25)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterLiquifyTwirlItem", smartFilter.kind.title, 100, 100))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .liquifyTwirl)
        #expect(restoredFilter.normalizedSettings.liquifyTwirlAngle == 1)
    }

    @Test func imageEditorLiquifyPuckerBloatFilterLayerAndSmartFilterWarpRadialPixels() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = radialRampImage(size: canvasSize)
        let samplePoint = CGPoint(x: 31, y: 24)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .liquifyPuckerBloat
        viewModel.filterIntensity = 1
        viewModel.filterLiquifyBulgeAmount = 1
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let bloatedSample = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        let farEdge = try #require(viewModel.currentImage.color(at: CGPoint(x: 47, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .liquifyPuckerBloat)
        #expect(filterLayer.filterSettings.normalized().liquifyBulgeAmount == 1)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(bloatedSample.redComponent < sampleBefore.redComponent - 0.05)
        #expect(farEdge.redComponent > 0.88)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .liquifyPuckerBloat
        smartViewModel.filterIntensity = 1
        smartViewModel.filterLiquifyBulgeAmount = -1
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let puckeredSample = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .liquifyPuckerBloat)
        #expect(smartFilter.normalizedSettings.liquifyBulgeAmount == -1)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(puckeredSample.redComponent > sampleBefore.redComponent + 0.05)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterLiquifyPuckerBloatItem", smartFilter.kind.title, 100, -100))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .liquifyPuckerBloat)
        #expect(restoredFilter.normalizedSettings.liquifyBulgeAmount == -1)
    }

    @Test func imageEditorWaveFilterLayerAndSmartFilterWarpHorizontalPixels() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = splitColorImage(size: canvasSize, left: .systemRed, right: .systemBlue)
        let positiveWavePoint = CGPoint(x: 24, y: 12)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: positiveWavePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .wave
        viewModel.filterIntensity = 1
        viewModel.filterWaveAmplitude = 1
        viewModel.filterWaveFrequency = 0
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let wavedSample = try #require(viewModel.currentImage.color(at: positiveWavePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .wave)
        #expect(filterLayer.filterSettings.normalized().waveAmplitude == 1)
        #expect(filterLayer.filterSettings.normalized().waveFrequency == 0)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleBefore.blueComponent > sampleBefore.redComponent + 0.4)
        #expect(wavedSample.redComponent > wavedSample.blueComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let negativeWavePoint = CGPoint(x: 23, y: 12)
        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartSampleBefore = try #require(smartViewModel.currentImage.color(at: negativeWavePoint)?.usingColorSpace(.deviceRGB))
        smartViewModel.selectedFilter = .wave
        smartViewModel.filterIntensity = 1
        smartViewModel.filterWaveAmplitude = -1
        smartViewModel.filterWaveFrequency = 0
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: negativeWavePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .wave)
        #expect(smartFilter.normalizedSettings.waveAmplitude == -1)
        #expect(smartFilter.normalizedSettings.waveFrequency == 0)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleBefore.redComponent > smartSampleBefore.blueComponent + 0.4)
        #expect(smartSampleAfter.blueComponent > smartSampleAfter.redComponent + 0.25)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterWaveItem", smartFilter.kind.title, 100, -100, 0))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .wave)
        #expect(restoredFilter.normalizedSettings.waveAmplitude == -1)
        #expect(restoredFilter.normalizedSettings.waveFrequency == 0)
    }

    @Test func imageEditorOffsetFilterLayerAndSmartFilterWrapPixels() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = splitColorImage(size: canvasSize, left: .systemRed, right: .systemBlue)
        let samplePoint = CGPoint(x: 12, y: 24)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .offset
        viewModel.filterIntensity = 1
        viewModel.filterOffsetX = 1
        viewModel.filterOffsetY = 0
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sampleAfter = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .offset)
        #expect(filterLayer.filterSettings.normalized().offsetX == 1)
        #expect(filterLayer.filterSettings.normalized().offsetY == 0)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleBefore.redComponent > sampleBefore.blueComponent + 0.4)
        #expect(sampleAfter.blueComponent > sampleAfter.redComponent + 0.4)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let quadrantSource = quadrantImage(
            size: canvasSize,
            topLeft: .systemRed,
            topRight: .systemBlue,
            bottomLeft: .systemGreen,
            bottomRight: .systemYellow
        )
        let verticalSamplePoint = CGPoint(x: 12, y: 12)
        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: quadrantSource) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(quadrantSource, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartSampleBefore = try #require(smartViewModel.currentImage.color(at: verticalSamplePoint)?.usingColorSpace(.deviceRGB))
        smartViewModel.selectedFilter = .offset
        smartViewModel.filterIntensity = 1
        smartViewModel.filterOffsetX = 0
        smartViewModel.filterOffsetY = 1
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: verticalSamplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .offset)
        #expect(smartFilter.normalizedSettings.offsetX == 0)
        #expect(smartFilter.normalizedSettings.offsetY == 1)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleBefore.redComponent > smartSampleBefore.greenComponent + 0.4)
        #expect(smartSampleAfter.greenComponent > smartSampleAfter.redComponent + 0.25)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterOffsetItem", smartFilter.kind.title, 100, 0, 100))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .offset)
        #expect(restoredFilter.normalizedSettings.offsetX == 0)
        #expect(restoredFilter.normalizedSettings.offsetY == 1)
    }

    @Test func imageEditorRippleFilterLayerAndSmartFilterWarpRadialPixels() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = radialRampImage(size: canvasSize)
        let samplePoint = CGPoint(x: 29, y: 24)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .ripple
        viewModel.filterIntensity = 1
        viewModel.filterRippleAmount = 1
        viewModel.filterRippleFrequency = 0
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sampleAfter = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .ripple)
        #expect(filterLayer.filterSettings.normalized().rippleAmount == 1)
        #expect(filterLayer.filterSettings.normalized().rippleFrequency == 0)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleAfter.redComponent > sampleBefore.redComponent + 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartSampleBefore = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        smartViewModel.selectedFilter = .ripple
        smartViewModel.filterIntensity = 1
        smartViewModel.filterRippleAmount = -1
        smartViewModel.filterRippleFrequency = 0
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .ripple)
        #expect(smartFilter.normalizedSettings.rippleAmount == -1)
        #expect(smartFilter.normalizedSettings.rippleFrequency == 0)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleAfter.redComponent < smartSampleBefore.redComponent - 0.03)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterRippleItem", smartFilter.kind.title, 100, -100, 0))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .ripple)
        #expect(restoredFilter.normalizedSettings.rippleAmount == -1)
        #expect(restoredFilter.normalizedSettings.rippleFrequency == 0)
    }

    @Test func imageEditorPinchFilterLayerAndSmartFilterWarpRadialPixels() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = radialRampImage(size: canvasSize)
        let samplePoint = CGPoint(x: 30, y: 24)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .pinch
        viewModel.filterIntensity = 1
        viewModel.filterPinchAmount = 1
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sampleAfter = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .pinch)
        #expect(filterLayer.filterSettings.normalized().pinchAmount == 1)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleAfter.redComponent > sampleBefore.redComponent + 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartSampleBefore = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        smartViewModel.selectedFilter = .pinch
        smartViewModel.filterIntensity = 1
        smartViewModel.filterPinchAmount = -1
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .pinch)
        #expect(smartFilter.normalizedSettings.pinchAmount == -1)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleAfter.redComponent < smartSampleBefore.redComponent - 0.03)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterPinchItem", smartFilter.kind.title, 100, -100))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .pinch)
        #expect(restoredFilter.normalizedSettings.pinchAmount == -1)
    }

    @Test func imageEditorSpherizeFilterLayerAndSmartFilterWarpRadialPixels() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = radialRampImage(size: canvasSize)
        let samplePoint = CGPoint(x: 30, y: 24)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .spherize
        viewModel.filterIntensity = 1
        viewModel.filterSpherizeAmount = 1
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sampleAfter = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .spherize)
        #expect(filterLayer.filterSettings.normalized().spherizeAmount == 1)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleAfter.redComponent < sampleBefore.redComponent - 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartSampleBefore = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        smartViewModel.selectedFilter = .spherize
        smartViewModel.filterIntensity = 1
        smartViewModel.filterSpherizeAmount = -1
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .spherize)
        #expect(smartFilter.normalizedSettings.spherizeAmount == -1)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleAfter.redComponent > smartSampleBefore.redComponent + 0.03)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterSpherizeItem", smartFilter.kind.title, 100, -100))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .spherize)
        #expect(restoredFilter.normalizedSettings.spherizeAmount == -1)
    }

    @Test func updatingFigmaBackdropBlurToContentSmartFilterReentersPixelPipeline() throws {
        let canvasSize = NSSize(width: 64, height: 40)
        let sourceImage = gradientImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let layerID = try #require(viewModel.document.selectedLayerID)
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        let basePixels = try #require(viewModel.document.layers[layerIndex].image.qingtuPNGData())

        var backdropBlur = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 0.8,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 8)
        )
        backdropBlur.appliesToBackdrop = true
        viewModel.document.layers[layerIndex].smartFilters = [backdropBlur]
        let backdropPreview = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 1
        viewModel.updateSmartFilterOnSelectedLayer(backdropBlur.id)

        let updatedLayer = try #require(layer(layerID, in: viewModel))
        let updatedFilter = try #require(updatedLayer.smartFilters.first)
        let pixelatedPreview = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(updatedFilter.kind == .pixelate)
        #expect(updatedFilter.appliesToBackdrop == false)
        #expect(updatedLayer.image.qingtuPNGData() == basePixels)
        #expect(pixelatedPreview != backdropPreview)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterUpdate"))

        viewModel.undo()

        let restoredFilter = try #require(layer(layerID, in: viewModel)?.smartFilters.first)
        #expect(restoredFilter.kind == .gaussianBlur)
        #expect(restoredFilter.appliesToBackdrop == true)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == backdropPreview)
    }

    @Test func batchSmartFilterUpdatePreservesBackdropRoutingOnlyForGaussianBlur() throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: gradientImage(size: canvasSize)
        ) { _ in }
        let backdropLayerID = try #require(viewModel.document.selectedLayerID)
        let backdropIndex = try #require(viewModel.document.layers.firstIndex { $0.id == backdropLayerID })
        var backdropBlur = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.4)
        backdropBlur.appliesToBackdrop = true
        viewModel.document.layers[backdropIndex].smartFilters = [backdropBlur]

        viewModel.addLayer()
        let contentLayerID = try #require(viewModel.document.selectedLayerID)
        let contentIndex = try #require(viewModel.document.layers.firstIndex { $0.id == contentLayerID })
        viewModel.document.layers[contentIndex].smartFilters = [
            ImageEditorSmartFilter(kind: .sharpen, intensity: 0.3)
        ]
        viewModel.selectLayer(backdropLayerID)
        viewModel.selectLayer(contentLayerID, extendingSelection: true)

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.65
        viewModel.updateLastSmartFilterOnSelectedLayer()

        #expect(try #require(layer(backdropLayerID, in: viewModel)?.smartFilters.last).appliesToBackdrop == true)
        #expect(try #require(layer(contentLayerID, in: viewModel)?.smartFilters.last).appliesToBackdrop == false)

        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 0.9
        viewModel.updateLastSmartFilterOnSelectedLayer()

        let updatedBackdrop = try #require(layer(backdropLayerID, in: viewModel)?.smartFilters.last)
        let updatedContent = try #require(layer(contentLayerID, in: viewModel)?.smartFilters.last)
        #expect(updatedBackdrop.kind == .pixelate)
        #expect(updatedBackdrop.appliesToBackdrop == false)
        #expect(updatedContent.kind == .pixelate)
        #expect(updatedContent.appliesToBackdrop == false)

        viewModel.undo()

        #expect(try #require(layer(backdropLayerID, in: viewModel)?.smartFilters.last).appliesToBackdrop == true)
        #expect(try #require(layer(contentLayerID, in: viewModel)?.smartFilters.last).appliesToBackdrop == false)
    }

    @Test func imageEditorBatchUpdatesSelectedFilterLayersAndSkipsLockedOrIneligibleLayers() async throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(size: canvasSize, color: .systemBlue)
        ) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.20
        viewModel.addFilterLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.30
        viewModel.addFilterLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.40
        viewModel.addFilterLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(lockedID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(lockedID, extendingSelection: true)
        viewModel.selectLayer(baseLayerID, extendingSelection: true)

        viewModel.selectedFilter = .unsharpMask
        viewModel.filterIntensity = 0.75
        viewModel.filterUnsharpRadius = 2.5
        viewModel.filterUnsharpThreshold = 0.30
        viewModel.updateSelectedFilterLayer()

        let first = try #require(layer(firstID, in: viewModel))
        let second = try #require(layer(secondID, in: viewModel))
        let locked = try #require(layer(lockedID, in: viewModel))
        let base = try #require(layer(baseLayerID, in: viewModel))

        #expect(first.filter?.kind == .unsharpMask)
        #expect(first.filter?.intensity == 0.75)
        #expect(first.filterSettings.normalized().unsharpRadius == 2.5)
        #expect(first.filterSettings.normalized().unsharpThreshold == 0.30)
        #expect(second.filter?.kind == .unsharpMask)
        #expect(second.filterSettings.normalized().unsharpRadius == 2.5)
        #expect(locked.filter?.kind == .gaussianBlur)
        #expect(locked.filter?.intensity == 0.40)
        #expect(!base.isFilter)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterUpdateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerFilterUpdatedSelected", 2))

        viewModel.undo()

        #expect(try #require(layer(firstID, in: viewModel)).filter?.kind == .gaussianBlur)
        #expect(try #require(layer(firstID, in: viewModel)).filter?.intensity == 0.20)
        #expect(try #require(layer(secondID, in: viewModel)).filter?.kind == .gaussianBlur)
        #expect(try #require(layer(secondID, in: viewModel)).filter?.intensity == 0.30)
        #expect(try #require(layer(lockedID, in: viewModel)).filter?.intensity == 0.40)
    }

    private func solidImage(size: NSSize, color: NSColor) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }

    private func layer(_ id: UUID, in viewModel: ImageEditorViewModel) -> ImageEditorLayer? {
        viewModel.document.layers.first { $0.id == id }
    }

    private func splitColorImage(size: NSSize, left: NSColor, right: NSColor) -> NSImage {
        NSImage.rendered(size: size) { rect in
            left.setFill()
            CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
            right.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func quadrantImage(
        size: NSSize,
        topLeft: NSColor,
        topRight: NSColor,
        bottomLeft: NSColor,
        bottomRight: NSColor
    ) -> NSImage {
        NSImage.rendered(size: size) { rect in
            let halfWidth = rect.width / 2
            let halfHeight = rect.height / 2
            topLeft.setFill()
            CGRect(x: rect.minX, y: rect.minY, width: halfWidth, height: halfHeight).fill()
            topRight.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: halfWidth, height: halfHeight).fill()
            bottomLeft.setFill()
            CGRect(x: rect.minX, y: rect.midY, width: halfWidth, height: halfHeight).fill()
            bottomRight.setFill()
            CGRect(x: rect.midX, y: rect.midY, width: halfWidth, height: halfHeight).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func radialRampImage(size: NSSize) -> NSImage {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let centerX = Double(max(width - 1, 1)) / 2
        let centerY = Double(max(height - 1, 1)) / 2
        let maxDistance = max(1, min(Double(width), Double(height)) / 2)
        var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let distance = min(1, hypot(Double(x) - centerX, Double(y) - centerY) / maxDistance)
                let value = UInt8((0.12 + distance * 0.82) * 255)
                pixels[offset] = value
                pixels[offset + 1] = value
                pixels[offset + 2] = value
                pixels[offset + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else {
            return NSImage.transparent(size: size)
        }

        return NSImage(cgImage: cgImage, size: size)
    }

    private func binarySpotImage(size: NSSize, background: NSColor, spot: NSColor, spotSize: CGFloat) -> NSImage {
        NSImage.rendered(size: size) { rect in
            background.setFill()
            rect.fill()
            spot.setFill()
            CGRect(
                x: rect.midX - spotSize / 2,
                y: rect.midY - spotSize / 2,
                width: spotSize,
                height: spotSize
            ).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func colorSpotImage(size: NSSize, background: NSColor, spot: NSColor, spotSize: CGFloat) -> NSImage {
        NSImage.rendered(size: size) { rect in
            background.setFill()
            rect.fill()
            spot.setFill()
            CGRect(
                x: rect.midX - spotSize / 2,
                y: rect.midY - spotSize / 2,
                width: spotSize,
                height: spotSize
            ).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func saltAndPepperImage(size: NSSize) -> NSImage {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 128, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                pixels[offset] = 128
                pixels[offset + 1] = 128
                pixels[offset + 2] = 128
                pixels[offset + 3] = 255
            }
        }

        let centerY = height / 2
        let whiteOffset = centerY * bytesPerRow + (width / 2) * bytesPerPixel
        pixels[whiteOffset] = 255
        pixels[whiteOffset + 1] = 255
        pixels[whiteOffset + 2] = 255
        let blackOffset = centerY * bytesPerRow + (width / 2 + 1) * bytesPerPixel
        pixels[blackOffset] = 0
        pixels[blackOffset + 1] = 0
        pixels[blackOffset + 2] = 0

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else {
            return NSImage.transparent(size: size)
        }

        return NSImage(cgImage: cgImage, size: size)
    }

    private func verticalEdgeImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.black.setFill()
            rect.fill()
            NSColor.white.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func softEdgeImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor(calibratedWhite: 0.4, alpha: 1).setFill()
            rect.fill()
            NSColor(calibratedWhite: 0.6, alpha: 1).setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func gradientImage(size: NSSize) -> NSImage {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let red = UInt8((Double(x) / Double(max(width - 1, 1)) * 255).rounded())
                let green = UInt8((Double(y) / Double(max(height - 1, 1)) * 255).rounded())
                pixels[offset] = red
                pixels[offset + 1] = green
                pixels[offset + 2] = 120
                pixels[offset + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else {
            return NSImage.transparent(size: size)
        }

        return NSImage(cgImage: cgImage, size: size)
    }
}
