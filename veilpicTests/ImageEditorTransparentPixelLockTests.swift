//
//  ImageEditorTransparentPixelLockTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorTransparentPixelLockTests {
    @Test func selectionFillPreservesTransparentPixelsWhenLocked() async throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(
            sourceName: "alpha.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            alphaSplitImage(size: canvasSize),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let selectedID = try #require(viewModel.document.selectedLayerID)
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == selectedID })
        viewModel.document.layers[layerIndex].isLocked = false
        viewModel.document.layers[layerIndex].locksTransparentPixels = true
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 80, y: 50))
        viewModel.foregroundColor = .systemGreen
        viewModel.opacity = 1

        viewModel.fillSelection()

        let layer = try #require(viewModel.document.selectedLayer)
        let transparentSide = try #require(layer.image.color(at: CGPoint(x: 10, y: 25))?.usingColorSpace(.deviceRGB))
        let filledSide = try #require(layer.image.color(at: CGPoint(x: 65, y: 25))?.usingColorSpace(.deviceRGB))
        #expect(transparentSide.alphaComponent < 0.05)
        #expect(filledSide.alphaComponent > 0.95)
        #expect(filledSide.greenComponent > 0.75)
    }

    @Test func groupTransparentPixelLockConstrainsChildGradient() async throws {
        let canvasSize = NSSize(width: 80, height: 50)
        let viewModel = ImageEditorViewModel(sourceName: "alpha.png", image: NSImage.transparent(size: canvasSize)) { _ in }
        var group = ImageEditorLayer.group(name: "Locked Group", size: canvasSize)
        group.locksTransparentPixels = true
        var child = ImageEditorLayer.blank(name: "Child", size: canvasSize)
        child.image = alphaSplitImage(size: canvasSize)
        child.groupID = group.id
        viewModel.document.layers = [child, group]
        viewModel.document.selectedLayerID = child.id
        viewModel.document.selectedLayerIDs = [child.id]
        viewModel.foregroundColor = .systemGreen
        viewModel.backgroundColor = .systemBlue
        viewModel.opacity = 1

        viewModel.drawGradient(from: CGPoint(x: 0, y: 25), to: CGPoint(x: 80, y: 25))

        let editedChild = try #require(viewModel.document.layers.first { $0.id == child.id })
        let transparentSide = try #require(editedChild.image.color(at: CGPoint(x: 10, y: 25))?.usingColorSpace(.deviceRGB))
        let gradientSide = try #require(editedChild.image.color(at: CGPoint(x: 65, y: 25))?.usingColorSpace(.deviceRGB))
        #expect(transparentSide.alphaComponent < 0.05)
        #expect(gradientSide.alphaComponent > 0.95)
        #expect(gradientSide.blueComponent > 0.45 || gradientSide.greenComponent > 0.45)
    }

    private func alphaSplitImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.clear.setFill()
            rect.fill()
            NSColor.systemRed.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: size)
    }
}
