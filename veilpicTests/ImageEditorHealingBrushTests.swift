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
            targetContextPixels: pixels,
            width: width,
            height: height,
            points: [CGPoint(x: 7, y: 25)],
            destinationReference: CGPoint(x: 7, y: 25),
            brushDiameter: 10
        )

        #expect(offset != nil)
        #expect((offset?.width ?? 0) > 0)
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

    private func blemishImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor(deviceRed: 0.45, green: 0.45, blue: 0.45, alpha: 1).setFill()
            rect.fill()
            NSColor.systemRed.setFill()
            CGRect(x: 36, y: 21, width: 8, height: 8).fill()
        } ?? NSImage.transparent(size: size)
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

    private func performLayeredHealingStroke(on viewModel: ImageEditorViewModel) {
        viewModel.brushSize = 6
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.isHealingBrushAligned = false
        viewModel.setHealingSource(at: CGPoint(x: 12, y: 15))
        viewModel.healingBrush(points: [CGPoint(x: 60, y: 15), CGPoint(x: 66, y: 15)])
    }
}
