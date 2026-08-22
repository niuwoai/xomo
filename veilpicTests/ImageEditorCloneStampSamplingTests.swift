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

    @Test func cloneSourceSlotsRetainIndependentSourcesAndDriveRealStrokes() throws {
        let viewModel = patternedCurrentLayerViewModel()
        viewModel.isCloneStampAligned = false
        viewModel.brushSize = 6
        viewModel.opacity = 1
        let historyCount = viewModel.document.history.count

        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))
        viewModel.cloneStamp(points: [CGPoint(x: 50, y: 15)])

        #expect(viewModel.selectCloneSourceSlot(1))
        viewModel.setCloneSource(at: CGPoint(x: 30, y: 15))
        viewModel.cloneStamp(points: [CGPoint(x: 70, y: 15)])

        #expect(viewModel.selectCloneSourceSlot(0))
        #expect(viewModel.cloneSourcePoint == CGPoint(x: 10, y: 15))
        viewModel.cloneStamp(points: [CGPoint(x: 90, y: 15)])

        let firstSlotPixel = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 50, y: 15)
        )
        let secondSlotPixel = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 70, y: 15)
        )
        let restoredSlotPixel = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 90, y: 15)
        )
        #expect(firstSlotPixel.redComponent > firstSlotPixel.greenComponent + 0.25)
        #expect(secondSlotPixel.greenComponent > secondSlotPixel.redComponent + 0.25)
        #expect(restoredSlotPixel.redComponent > restoredSlotPixel.greenComponent + 0.25)
        #expect(viewModel.document.history.count == historyCount + 3)

        let activeSlot = viewModel.activeCloneSourceSlotIndex
        let activePoint = viewModel.cloneSourcePoint
        #expect(!viewModel.selectCloneSourceSlot(-1))
        #expect(!viewModel.selectCloneSourceSlot(ImageEditorCloneSourceSlotState.maximumCount))
        #expect(viewModel.activeCloneSourceSlotIndex == activeSlot)
        #expect(viewModel.cloneSourcePoint == activePoint)
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

    @Test func compositeSamplingCanExcludeAdjustmentLayers() throws {
        let adjusted = adjustmentSamplingViewModel()
        adjusted.cloneStampSampleSource = .currentAndBelow
        performSamplingStroke(on: adjusted)
        let adjustedPixel = try color(
            adjusted.document.selectedLayer?.image,
            at: CGPoint(x: 61, y: 15)
        )
        #expect(adjustedPixel.redComponent > 0.95)
        #expect(adjustedPixel.greenComponent > 0.95)
        #expect(adjustedPixel.blueComponent > 0.95)

        let ignored = adjustmentSamplingViewModel()
        ignored.cloneStampSampleSource = .currentAndBelow
        ignored.cloneStampIgnoresAdjustmentLayers = true
        performSamplingStroke(on: ignored)
        let ignoredPixel = try color(
            ignored.document.selectedLayer?.image,
            at: CGPoint(x: 61, y: 15)
        )
        #expect(ignoredPixel.redComponent < 0.05)
        #expect(ignoredPixel.greenComponent < 0.05)
        #expect(ignoredPixel.blueComponent < 0.05)
        #expect(ignoredPixel.alphaComponent > 0.95)
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

    @Test func cloneStampHardnessControlsTheDabEdge() throws {
        let hard = patternedCurrentLayerViewModel()
        hard.brushSize = 10
        hard.hardness = 1
        hard.opacity = 1
        hard.setCloneSource(at: CGPoint(x: 10, y: 15))
        hard.cloneStamp(points: [CGPoint(x: 60, y: 15)])

        let soft = patternedCurrentLayerViewModel()
        soft.brushSize = 10
        soft.hardness = 0
        soft.opacity = 1
        soft.setCloneSource(at: CGPoint(x: 10, y: 15))
        soft.cloneStamp(points: [CGPoint(x: 60, y: 15)])

        let hardCenter = try color(hard.document.selectedLayer?.image, at: CGPoint(x: 60, y: 15))
        let softCenter = try color(soft.document.selectedLayer?.image, at: CGPoint(x: 60, y: 15))
        let hardEdge = try color(hard.document.selectedLayer?.image, at: CGPoint(x: 64, y: 15))
        let softEdge = try color(soft.document.selectedLayer?.image, at: CGPoint(x: 64, y: 15))

        #expect(hardCenter.redComponent > hardCenter.blueComponent + 0.25)
        #expect(softCenter.redComponent > softCenter.blueComponent + 0.25)
        #expect(hardEdge.redComponent > hardEdge.blueComponent + 0.25)
        #expect(softEdge.blueComponent > softEdge.redComponent + 0.25)
    }

    @Test func sampledBrushPressureControlsCloneStampDiameterWithoutChangingMouseStrokes() throws {
        let light = patternedCurrentLayerViewModel()
        let full = patternedCurrentLayerViewModel()
        let mouseBaseline = patternedCurrentLayerViewModel()
        let mousePressureEnabled = patternedCurrentLayerViewModel()
        for viewModel in [light, full, mouseBaseline, mousePressureEnabled] {
            viewModel.brushSize = 16
            viewModel.hardness = 1
            viewModel.opacity = 1
            viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))
        }
        light.retouchPressureControlsSize = true
        full.retouchPressureControlsSize = true
        mouseBaseline.retouchPressureControlsSize = false
        mousePressureEnabled.retouchPressureControlsSize = true
        let destination = CGPoint(x: 60, y: 15)

        light.cloneStamp(samples: [
            ImageEditorBrushStrokeSample(point: destination, pressure: 0.05)
        ])
        full.cloneStamp(samples: [
            ImageEditorBrushStrokeSample(point: destination, pressure: 1)
        ])
        mouseBaseline.cloneStamp(samples: [ImageEditorBrushStrokeSample(point: destination)])
        mousePressureEnabled.cloneStamp(samples: [ImageEditorBrushStrokeSample(point: destination)])

        let edgePoint = CGPoint(x: 60, y: 19)
        let lightEdge = try color(light.document.selectedLayer?.image, at: edgePoint)
        let fullEdge = try color(full.document.selectedLayer?.image, at: edgePoint)
        let baselineMouseEdge = try color(mouseBaseline.document.selectedLayer?.image, at: edgePoint)
        let enabledMouseEdge = try color(mousePressureEnabled.document.selectedLayer?.image, at: edgePoint)
        #expect(lightEdge.blueComponent > lightEdge.redComponent + 0.25)
        #expect(fullEdge.redComponent > fullEdge.blueComponent + 0.25)
        #expect(abs(baselineMouseEdge.redComponent - enabledMouseEdge.redComponent) < 0.001)
        #expect(abs(baselineMouseEdge.blueComponent - enabledMouseEdge.blueComponent) < 0.001)
        #expect(full.document.history.last?.title == L10n.text("imageEditor.history.cloneStamp"))
        full.undo()
        let undoneEdge = try color(full.document.selectedLayer?.image, at: edgePoint)
        #expect(undoneEdge.blueComponent > undoneEdge.redComponent + 0.25)
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

    private func adjustmentSamplingViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 100, height: 30)
        let black = bitmap(size: size, background: .black, fills: [])
        var document = ImageEditorDocument(sourceName: "source.png", image: black)
        var bottom = ImageEditorLayer.blank(name: "Bottom", size: size)
        bottom.image = black
        let adjustment = ImageEditorLayer.adjustment(
            name: "Invert",
            size: size,
            kind: .invert,
            amount: 1
        )
        let edit = ImageEditorLayer.blank(name: "Edit", size: size)
        document.layers = [bottom, adjustment, edit]
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
