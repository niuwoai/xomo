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
    @Test func imageEditorHealingBrushBlendsBlemishTowardSurroundings() async throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: blemishImage(size: canvasSize)) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(blemishImage(size: canvasSize), historyTitle: L10n.text("imageEditor.history.brush"))
        viewModel.brushSize = 12
        viewModel.opacity = 1

        viewModel.healingBrush(points: [CGPoint(x: 34, y: 25), CGPoint(x: 46, y: 25)])

        let layer = try #require(viewModel.document.selectedLayer)
        let healed = try #require(layer.image.color(at: CGPoint(x: 40, y: 25))?.usingColorSpace(.deviceRGB))
        let untouched = try #require(layer.image.color(at: CGPoint(x: 10, y: 25))?.usingColorSpace(.deviceRGB))
        #expect(healed.redComponent < 0.55)
        #expect(abs(healed.redComponent - healed.greenComponent) < 0.18)
        #expect(abs(untouched.redComponent - 0.45) < 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.healingBrush"))
    }

    @Test func imageEditorHealingBrushRespectsActiveSelection() async throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: blemishImage(size: canvasSize)) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(blemishImage(size: canvasSize), historyTitle: L10n.text("imageEditor.history.brush"))
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 36, y: 50))
        viewModel.brushSize = 12
        viewModel.opacity = 1

        viewModel.healingBrush(points: [CGPoint(x: 34, y: 25), CGPoint(x: 46, y: 25)])

        let layer = try #require(viewModel.document.selectedLayer)
        let clippedBlemish = try #require(layer.image.color(at: CGPoint(x: 40, y: 25))?.usingColorSpace(.deviceRGB))
        #expect(clippedBlemish.redComponent > 0.8)
    }

    private func blemishImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor(deviceRed: 0.45, green: 0.45, blue: 0.45, alpha: 1).setFill()
            rect.fill()
            NSColor.systemRed.setFill()
            CGRect(x: 36, y: 21, width: 8, height: 8).fill()
        } ?? NSImage.transparent(size: size)
    }
}
