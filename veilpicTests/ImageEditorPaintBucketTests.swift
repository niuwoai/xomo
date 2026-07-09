//
//  ImageEditorPaintBucketTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPaintBucketTests {
    @Test func imageEditorPaintBucketFillsContiguousColorOnly() async throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: splitImage(size: canvasSize)) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(splitImage(size: canvasSize), historyTitle: L10n.text("imageEditor.history.brush"))
        viewModel.foregroundColor = .systemGreen
        viewModel.opacity = 1
        viewModel.tolerance = 0.05

        viewModel.paintBucketFill(at: CGPoint(x: 10, y: 25))

        let layer = try #require(viewModel.document.selectedLayer)
        let filled = try #require(layer.image.color(at: CGPoint(x: 10, y: 25))?.usingColorSpace(.deviceRGB))
        let untouched = try #require(layer.image.color(at: CGPoint(x: 65, y: 25))?.usingColorSpace(.deviceRGB))
        #expect(filled.greenComponent > 0.75)
        #expect(filled.redComponent < 0.25)
        #expect(untouched.blueComponent > 0.75)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.paintBucket"))
    }

    @Test func imageEditorPaintBucketRespectsActiveSelection() async throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: splitImage(size: canvasSize)) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(splitImage(size: canvasSize), historyTitle: L10n.text("imageEditor.history.brush"))
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 20, y: 50))
        viewModel.foregroundColor = .systemGreen
        viewModel.opacity = 1
        viewModel.tolerance = 0.05

        viewModel.paintBucketFill(at: CGPoint(x: 10, y: 25))

        let layer = try #require(viewModel.document.selectedLayer)
        let selectedFill = try #require(layer.image.color(at: CGPoint(x: 10, y: 25))?.usingColorSpace(.deviceRGB))
        let clippedRed = try #require(layer.image.color(at: CGPoint(x: 32, y: 25))?.usingColorSpace(.deviceRGB))
        let untouchedBlue = try #require(layer.image.color(at: CGPoint(x: 65, y: 25))?.usingColorSpace(.deviceRGB))
        #expect(selectedFill.greenComponent > 0.75)
        #expect(clippedRed.redComponent > 0.75)
        #expect(untouchedBlue.blueComponent > 0.75)
    }

    private func splitImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.systemRed.setFill()
            CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
            NSColor.systemBlue.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: size)
    }
}
