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
        let boundaryBefore = try #require(
            viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 40, y: 25))?.usingColorSpace(.deviceRGB)
        )

        viewModel.paintBucketFill(at: CGPoint(x: 10, y: 25))

        let layer = try #require(viewModel.document.selectedLayer)
        let filled = try #require(layer.image.color(at: CGPoint(x: 10, y: 25))?.usingColorSpace(.deviceRGB))
        let hardBoundary = try #require(layer.image.color(at: CGPoint(x: 40, y: 25))?.usingColorSpace(.deviceRGB))
        let untouched = try #require(layer.image.color(at: CGPoint(x: 65, y: 25))?.usingColorSpace(.deviceRGB))
        #expect(filled.greenComponent > 0.75)
        #expect(filled.redComponent < 0.25)
        #expect(abs(hardBoundary.redComponent - boundaryBefore.redComponent) < 0.01)
        #expect(abs(hardBoundary.greenComponent - boundaryBefore.greenComponent) < 0.01)
        #expect(abs(hardBoundary.blueComponent - boundaryBefore.blueComponent) < 0.01)
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

    @Test func paintBucketOutsideOffsetLayerDoesNotClampToEdgeOrCreateHistory() throws {
        let canvasSize = NSSize(width: 100, height: 80)
        let layerImage = splitImage(size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(
            sourceName: "offset-layer.png",
            image: layerImage
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.canvasSize = canvasSize
        viewModel.document.layers[layerIndex].frame = CGRect(x: 30, y: 20, width: 40, height: 30)
        viewModel.foregroundColor = .systemGreen
        viewModel.opacity = 1
        viewModel.tolerance = 0.05
        let originalPixels = try #require(
            viewModel.document.layers[layerIndex].image.normalizedBitmapImage().qingtuPNGData()
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.paintBucketFill(at: CGPoint(x: 12, y: 12))

        let pixelsAfterClick = try #require(
            viewModel.document.layers[layerIndex].image.normalizedBitmapImage().qingtuPNGData()
        )
        #expect(pixelsAfterClick == originalPixels)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.paintBucketOutsideLayer"))
    }

    @Test func paintBucketOutsideActiveSelectionDoesNotCreateNoOpHistory() throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(
            sourceName: "selection.png",
            image: splitImage(size: canvasSize)
        ) { _ in }
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 20, y: 50))
        viewModel.foregroundColor = .systemGreen
        viewModel.opacity = 1
        viewModel.tolerance = 0.05
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let originalPixels = try #require(
            viewModel.document.layers[layerIndex].image.normalizedBitmapImage().qingtuPNGData()
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.paintBucketFill(at: CGPoint(x: 65, y: 25))

        let pixelsAfterClick = try #require(
            viewModel.document.layers[layerIndex].image.normalizedBitmapImage().qingtuPNGData()
        )
        #expect(pixelsAfterClick == originalPixels)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.paintBucketOutsideSelection"))
    }

    @Test func paintBucketHonorsInvertedSelectionMask() throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(
            sourceName: "inverted-selection.png",
            image: splitImage(size: canvasSize)
        ) { _ in }
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 20, y: 50))
        viewModel.invertSelection()
        viewModel.foregroundColor = .systemGreen
        viewModel.opacity = 1
        viewModel.tolerance = 0.05
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.paintBucketFill(at: CGPoint(x: 10, y: 25))

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.paintBucketOutsideSelection"))

        viewModel.paintBucketFill(at: CGPoint(x: 65, y: 25))

        let layer = try #require(viewModel.document.selectedLayer)
        let filled = try #require(
            layer.image.color(at: CGPoint(x: 65, y: 25))?.usingColorSpace(.deviceRGB)
        )
        #expect(filled.greenComponent > 0.75)
        #expect(filled.greenComponent > filled.blueComponent + 0.35)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
    }

    @Test func paintBucketZeroOpacityDoesNotCreateNoOpHistory() throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(
            sourceName: "matching-fill.png",
            image: splitImage(size: canvasSize)
        ) { _ in }
        viewModel.foregroundColor = .systemGreen
        viewModel.opacity = 0
        viewModel.tolerance = 0.05
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let originalPixels = try #require(
            viewModel.document.layers[layerIndex].image.normalizedBitmapImage().qingtuPNGData()
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.paintBucketFill(at: CGPoint(x: 10, y: 25))

        let pixelsAfterClick = try #require(
            viewModel.document.layers[layerIndex].image.normalizedBitmapImage().qingtuPNGData()
        )
        #expect(pixelsAfterClick == originalPixels)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.paintBucketUnchanged"))
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
