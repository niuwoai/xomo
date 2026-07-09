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

    private func solidImage(size: NSSize, color: NSColor) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
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
