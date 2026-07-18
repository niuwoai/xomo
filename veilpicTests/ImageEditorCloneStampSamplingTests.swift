//
//  ImageEditorCloneStampSamplingTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorCloneStampSamplingTests {
    @Test func offsetResolutionKeepsOrResetsTheSourceOffset() {
        let firstAligned = ImageEditorSampledBrushOffsetResolution.resolve(
            sourcePoint: CGPoint(x: 10, y: 12),
            destinationStart: CGPoint(x: 50, y: 20),
            isAligned: true,
            alignedOffset: nil
        )
        #expect(firstAligned.canvasOffset == CGSize(width: -40, height: -8))
        #expect(firstAligned.nextAlignedOffset == firstAligned.canvasOffset)

        let nextAligned = ImageEditorSampledBrushOffsetResolution.resolve(
            sourcePoint: CGPoint(x: 10, y: 12),
            destinationStart: CGPoint(x: 70, y: 20),
            isAligned: true,
            alignedOffset: firstAligned.nextAlignedOffset
        )
        #expect(nextAligned.canvasOffset == CGSize(width: -40, height: -8))

        let nonAligned = ImageEditorSampledBrushOffsetResolution.resolve(
            sourcePoint: CGPoint(x: 10, y: 12),
            destinationStart: CGPoint(x: 70, y: 20),
            isAligned: false,
            alignedOffset: firstAligned.nextAlignedOffset
        )
        #expect(nonAligned.canvasOffset == CGSize(width: -60, height: -8))
        #expect(nonAligned.nextAlignedOffset == nil)
    }

    @Test func alignedAndNonAlignedStrokesUseDifferentSecondSources() throws {
        let aligned = patternedCurrentLayerViewModel()
        aligned.isCloneStampAligned = true
        performTwoStrokes(on: aligned)
        let alignedSecond = try color(
            aligned.document.selectedLayer?.image,
            at: CGPoint(x: 71, y: 15)
        )
        #expect(alignedSecond.greenComponent > alignedSecond.redComponent + 0.25)

        let nonAligned = patternedCurrentLayerViewModel()
        nonAligned.isCloneStampAligned = false
        performTwoStrokes(on: nonAligned)
        let nonAlignedSecond = try color(
            nonAligned.document.selectedLayer?.image,
            at: CGPoint(x: 71, y: 15)
        )
        #expect(nonAlignedSecond.redComponent > nonAlignedSecond.greenComponent + 0.25)
    }

    @Test func samplingRangeDistinguishesCurrentBelowAndAllVisibleLayers() throws {
        let current = layeredSamplingViewModel()
        current.cloneStampSampleSource = .currentLayer
        performSamplingStroke(on: current)
        let currentPixel = try color(current.document.selectedLayer?.image, at: CGPoint(x: 61, y: 15))
        #expect(currentPixel.alphaComponent < 0.05)

        let currentAndBelow = layeredSamplingViewModel()
        currentAndBelow.cloneStampSampleSource = .currentAndBelow
        performSamplingStroke(on: currentAndBelow)
        let belowPixel = try color(currentAndBelow.document.selectedLayer?.image, at: CGPoint(x: 61, y: 15))
        #expect(belowPixel.redComponent > belowPixel.greenComponent + 0.25)

        let allVisible = layeredSamplingViewModel()
        allVisible.cloneStampSampleSource = .allVisible
        performSamplingStroke(on: allVisible)
        let visiblePixel = try color(allVisible.document.selectedLayer?.image, at: CGPoint(x: 61, y: 15))
        #expect(visiblePixel.greenComponent > visiblePixel.redComponent + 0.25)
        #expect(allVisible.document.history.last?.title == L10n.text("imageEditor.history.cloneStamp"))

        allVisible.undo()
        let undonePixel = try color(allVisible.document.selectedLayer?.image, at: CGPoint(x: 61, y: 15))
        #expect(undonePixel.alphaComponent < 0.05)
        allVisible.redo()
        let redonePixel = try color(allVisible.document.selectedLayer?.image, at: CGPoint(x: 61, y: 15))
        #expect(redonePixel.greenComponent > redonePixel.redComponent + 0.25)
    }

    @Test func cloneStampSupportsASingleClick() throws {
        let viewModel = patternedCurrentLayerViewModel()
        viewModel.brushSize = 8
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))

        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 15)])

        let stamped = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 60, y: 15)
        )
        let outsideDab = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 66, y: 15)
        )
        #expect(stamped.redComponent > stamped.blueComponent + 0.25)
        #expect(outsideDab.blueComponent > outsideDab.redComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.cloneStamp"))
    }

    @Test func compositeSamplingCanReachOutsideSelectedLayerFrame() throws {
        let canvasSize = CGSize(width: 100, height: 30)
        let sourceImage = bitmap(size: canvasSize, background: .systemBlue, fills: [
            (CGRect(x: 8, y: 10, width: 12, height: 10), .systemRed)
        ])
        var document = ImageEditorDocument(sourceName: "source.png", image: sourceImage)
        var editLayer = ImageEditorLayer.blank(name: "Small", size: CGSize(width: 40, height: 30))
        editLayer.frame = CGRect(x: 50, y: 0, width: 40, height: 30)
        document.layers = [document.layers[0], editLayer]
        document.selectedLayerID = editLayer.id
        document.selectedLayerIDs = [editLayer.id]
        let viewModel = ImageEditorViewModel(document: document) { _ in }
        viewModel.cloneStampSampleSource = .currentAndBelow
        viewModel.brushSize = 6
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 12, y: 15))
        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 15), CGPoint(x: 65, y: 15)])

        let stamped = try color(viewModel.document.selectedLayer?.image, at: CGPoint(x: 11, y: 15))
        #expect(stamped.redComponent > stamped.blueComponent + 0.25)
    }

    @Test func compositeSamplingStillRespectsSelectionAndTransparencyLock() throws {
        let selected = layeredSamplingViewModel()
        selected.cloneStampSampleSource = .allVisible
        selected.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 30, height: 30))
        performSamplingStroke(on: selected)
        let outsideSelection = try color(selected.document.selectedLayer?.image, at: CGPoint(x: 61, y: 15))
        #expect(outsideSelection.alphaComponent < 0.05)

        let transparencyLocked = layeredSamplingViewModel()
        transparencyLocked.cloneStampSampleSource = .allVisible
        if let index = transparencyLocked.document.selectedLayerIndex {
            transparencyLocked.document.layers[index].locksTransparentPixels = true
        }
        performSamplingStroke(on: transparencyLocked)
        let lockedPixel = try color(
            transparencyLocked.document.selectedLayer?.image,
            at: CGPoint(x: 61, y: 15)
        )
        #expect(lockedPixel.alphaComponent < 0.05)
    }

    private func patternedCurrentLayerViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 100, height: 30)
        let image = bitmap(size: size, background: .systemBlue, fills: [
            (CGRect(x: 7, y: 10, width: 10, height: 10), .systemRed),
            (CGRect(x: 27, y: 10, width: 10, height: 10), .systemGreen)
        ])
        var document = ImageEditorDocument(sourceName: "source.png", image: image)
        var editLayer = ImageEditorLayer.blank(name: "Pattern", size: size)
        editLayer.image = image
        document.layers = [editLayer]
        document.selectedLayerID = editLayer.id
        document.selectedLayerIDs = [editLayer.id]
        return ImageEditorViewModel(document: document) { _ in }
    }

    private func layeredSamplingViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 100, height: 30)
        let bottomImage = bitmap(size: size, background: .systemBlue, fills: [
            (CGRect(x: 7, y: 10, width: 12, height: 10), .systemRed)
        ])
        let topImage = bitmap(size: size, background: .clear, fills: [
            (CGRect(x: 7, y: 10, width: 12, height: 10), .systemGreen)
        ])
        var document = ImageEditorDocument(sourceName: "source.png", image: bottomImage)
        var bottom = ImageEditorLayer.blank(name: "Bottom", size: size)
        bottom.image = bottomImage
        let edit = ImageEditorLayer.blank(name: "Edit", size: size)
        var top = ImageEditorLayer.blank(name: "Top", size: size)
        top.image = topImage
        document.layers = [bottom, edit, top]
        document.selectedLayerID = edit.id
        document.selectedLayerIDs = [edit.id]
        return ImageEditorViewModel(document: document) { _ in }
    }

    private func performTwoStrokes(on viewModel: ImageEditorViewModel) {
        viewModel.brushSize = 6
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))
        viewModel.cloneStamp(points: [CGPoint(x: 50, y: 15), CGPoint(x: 55, y: 15)])
        viewModel.cloneStamp(points: [CGPoint(x: 70, y: 15), CGPoint(x: 75, y: 15)])
    }

    private func performSamplingStroke(on viewModel: ImageEditorViewModel) {
        viewModel.isCloneStampAligned = false
        viewModel.brushSize = 6
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))
        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 15), CGPoint(x: 65, y: 15)])
    }

    private func bitmap(
        size: CGSize,
        background: NSColor,
        fills: [(CGRect, NSColor)]
    ) -> NSImage {
        NSImage.rendered(size: size) { rect in
            background.setFill()
            rect.fill()
            for (fillRect, color) in fills {
                color.setFill()
                fillRect.fill()
            }
        } ?? NSImage.transparent(size: size)
    }

    private func color(_ image: NSImage?, at point: CGPoint) throws -> NSColor {
        try #require(image?.color(at: point)?.usingColorSpace(.deviceRGB))
    }
}
