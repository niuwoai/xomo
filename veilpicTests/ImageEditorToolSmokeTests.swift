//
//  ImageEditorToolSmokeTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/11.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorToolSmokeTests {
    @Test func lassoCreatesAUsablePolygonSelection() throws {
        let viewModel = makeViewModel(image: solidImage(color: .systemBlue))

        viewModel.createLassoSelection(points: [
            CGPoint(x: 4, y: 4),
            CGPoint(x: 30, y: 5),
            CGPoint(x: 24, y: 22),
            CGPoint(x: 6, y: 20),
        ])

        let selection = try #require(viewModel.document.selection)
        #expect(selection.isPolygon)
        #expect(selection.contains(CGPoint(x: 15, y: 12)))
        #expect(!selection.contains(CGPoint(x: 36, y: 25)))
    }

    @Test func quickSelectionCombinesSampledColorRegions() throws {
        let image = NSImage.rendered(size: canvasSize) { rect in
            NSColor.systemRed.setFill()
            CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
            NSColor.systemBlue.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: canvasSize)
        let viewModel = makeViewModel(image: image)
        viewModel.tolerance = 0.05
        viewModel.brushSize = 4

        viewModel.createQuickSelection(points: [CGPoint(x: 5, y: 14), CGPoint(x: 35, y: 14)])

        let selection = try #require(viewModel.document.selection)
        #expect(selection.contains(CGPoint(x: 5, y: 14)))
        #expect(selection.contains(CGPoint(x: 35, y: 14)))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.quickSelection"))
    }

    @Test func spongeIncreasesLocalColorSaturation() throws {
        let muted = NSColor(deviceRed: 0.58, green: 0.50, blue: 0.42, alpha: 1)
        let viewModel = makeEditableViewModel(image: solidImage(color: muted))
        viewModel.brushSize = 12
        viewModel.opacity = 1
        let before = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 14))?.usingColorSpace(.deviceRGB))

        viewModel.spongeBrush(points: [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)])

        let after = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 14))?.usingColorSpace(.deviceRGB))
        #expect((after.redComponent - after.blueComponent) > (before.redComponent - before.blueComponent))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func spongeDesaturateModePullsLocalColorTowardGray() throws {
        let color = NSColor(deviceRed: 0.72, green: 0.43, blue: 0.18, alpha: 1)
        let viewModel = makeEditableViewModel(image: solidImage(color: color))
        viewModel.spongeMode = .desaturate
        viewModel.brushSize = 12
        viewModel.opacity = 1
        let point = CGPoint(x: 20, y: 14)
        let before = try #require(
            viewModel.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )

        viewModel.spongeBrush(points: [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)])

        let after = try #require(
            viewModel.document.selectedLayer?.image.color(at: point)?.usingColorSpace(.deviceRGB)
        )
        let beforeRange = before.redComponent - before.blueComponent
        let afterRange = after.redComponent - after.blueComponent
        #expect(afterRange < beforeRange * 0.35)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func spongeHardnessControlsTheVisibleStrokeEdge() throws {
        let color = NSColor(deviceRed: 0.64, green: 0.46, blue: 0.24, alpha: 1)
        let soft = makeEditableViewModel(image: solidImage(color: color))
        let hard = makeEditableViewModel(image: solidImage(color: color))
        for viewModel in [soft, hard] {
            viewModel.spongeMode = .saturate
            viewModel.brushSize = 12
            viewModel.opacity = 1
        }
        soft.hardness = 0
        hard.hardness = 1
        let points = [CGPoint(x: 10, y: 14), CGPoint(x: 30, y: 14)]

        soft.spongeBrush(points: points)
        hard.spongeBrush(points: points)

        let edgePoint = CGPoint(x: 20, y: 18)
        let softEdge = try #require(
            soft.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        let hardEdge = try #require(
            hard.document.selectedLayer?.image.color(at: edgePoint)?.usingColorSpace(.deviceRGB)
        )
        let softRange = softEdge.redComponent - softEdge.blueComponent
        let hardRange = hardEdge.redComponent - hardEdge.blueComponent
        #expect(hardRange > softRange + 0.06)
        #expect(soft.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
        #expect(hard.document.history.last?.title == L10n.text("imageEditor.history.sponge"))
    }

    @Test func redEyeToolReducesExcessRedAtTheClickedPupil() throws {
        let image = NSImage.rendered(size: canvasSize) { rect in
            NSColor(deviceWhite: 0.35, alpha: 1).setFill()
            rect.fill()
            NSColor(deviceRed: 1, green: 0.05, blue: 0.05, alpha: 1).setFill()
            CGRect(x: 16, y: 10, width: 8, height: 8).fill()
        } ?? NSImage.transparent(size: canvasSize)
        let viewModel = makeEditableViewModel(image: image)
        viewModel.brushSize = 10
        viewModel.opacity = 1
        let before = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 14))?.usingColorSpace(.deviceRGB))

        viewModel.reduceRedEye(at: CGPoint(x: 20, y: 14))

        let after = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 14))?.usingColorSpace(.deviceRGB))
        #expect(after.redComponent < before.redComponent)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.redEye"))
    }

    @Test func shapeToolUsesTheCanvasTopLeftCoordinateSystem() throws {
        let viewModel = makeViewModel(image: NSImage.transparent(size: canvasSize))
        viewModel.foregroundColor = .systemRed

        viewModel.drawShape(from: CGPoint(x: 4, y: 3), to: CGPoint(x: 18, y: 11), ellipse: false)

        let topShapeColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 11, y: 7))?.usingColorSpace(NSColorSpace.deviceRGB))
        let mirroredLocationColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 11, y: 21))?.usingColorSpace(NSColorSpace.deviceRGB))
        #expect(topShapeColor.redComponent > 0.8)
        #expect(mirroredLocationColor.alphaComponent < 0.1)
    }

    @Test func eyedropperAndColorSamplerReadCanvasPixels() throws {
        let image = solidImage(color: .magenta)
        let viewModel = makeViewModel(image: image)

        viewModel.sampleColor(at: CGPoint(x: 20, y: 14))
        let foreground = try #require(viewModel.foregroundColor.usingColorSpace(NSColorSpace.deviceRGB))
        #expect(foreground.redComponent > 0.8)
        #expect(foreground.blueComponent > 0.8)

        viewModel.addColorSampler(at: CGPoint(x: 20, y: 14))
        let sample = try #require(viewModel.colorSamplerPoints.last)
        let sampledColor = try #require(sample.color.usingColorSpace(NSColorSpace.deviceRGB))
        #expect(sampledColor.redComponent > 0.8)
        #expect(sampledColor.blueComponent > 0.8)
    }

    private let canvasSize = NSSize(width: 40, height: 28)

    private func makeViewModel(image: NSImage) -> ImageEditorViewModel {
        ImageEditorViewModel(sourceName: "tool-smoke.png", image: image) { _ in }
    }

    private func makeEditableViewModel(image: NSImage) -> ImageEditorViewModel {
        let viewModel = makeViewModel(image: image)
        viewModel.replaceSelectedLayerImageForTesting(image, historyTitle: L10n.text("imageEditor.history.brush"))
        return viewModel
    }

    private func solidImage(color: NSColor) -> NSImage {
        NSImage.rendered(size: canvasSize) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: canvasSize)
    }
}
