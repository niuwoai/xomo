//
//  ImageEditorCloneStampSamplingTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import SwiftUI
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

    @Test func resettingActiveCloneTransformPreservesSourceAlignmentAndOtherSlots() throws {
        let viewModel = patternedCurrentLayerViewModel()
        viewModel.setCloneSourceScalePercent(200)
        viewModel.setCloneSourceFlipsHorizontally(true)

        #expect(viewModel.selectCloneSourceSlot(2))
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))
        viewModel.cloneStampAlignedCanvasOffset = CGSize(width: -40, height: -5)
        viewModel.setCloneSourceScalesLinked(false)
        viewModel.configureCloneSourceScale(
            horizontalPercent: 175,
            verticalPercent: 60,
            linked: false
        )
        viewModel.setCloneSourceFlipsHorizontally(true)
        viewModel.setCloneSourceFlipsVertically(true)
        viewModel.setCloneSourceRotationDegrees(37)
        let previewBeforeReset = try #require(
            viewModel.cloneStampOverlayPreview(destinationReference: CGPoint(x: 60, y: 20))
        )
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canResetCloneSourceTransform)
        #expect(viewModel.resetActiveCloneSourceTransform())
        #expect(!viewModel.canResetCloneSourceTransform)
        #expect(viewModel.cloneSourcePoint == CGPoint(x: 10, y: 15))
        #expect(viewModel.cloneStampAlignedCanvasOffset == CGSize(width: -40, height: -5))
        #expect(!viewModel.cloneSourceScalesLinked)
        #expect(viewModel.cloneSourceHorizontalScalePercent == 100)
        #expect(viewModel.cloneSourceVerticalScalePercent == 100)
        #expect(viewModel.cloneSourceRotationDegrees == 0)
        #expect(!viewModel.cloneSourceFlipsHorizontally)
        #expect(!viewModel.cloneSourceFlipsVertically)
        #expect(viewModel.document.history.count == historyCount)
        #expect(!viewModel.resetActiveCloneSourceTransform())

        let previewAfterReset = try #require(
            viewModel.cloneStampOverlayPreview(destinationReference: CGPoint(x: 60, y: 20))
        )
        #expect(previewAfterReset.sourceCanvas === previewBeforeReset.sourceCanvas)

        #expect(viewModel.selectCloneSourceSlot(0))
        #expect(viewModel.cloneSourceHorizontalScalePercent == 200)
        #expect(viewModel.cloneSourceVerticalScalePercent == 200)
        #expect(viewModel.cloneSourceFlipsHorizontally)
    }

    @Test func horizontalSourceFlipMirrorsRealClonePixelsAroundTheSamplingOrigin() throws {
        let ordinary = mirroredSourceViewModel()
        let flipped = mirroredSourceViewModel()
        for viewModel in [ordinary, flipped] {
            viewModel.isCloneStampAligned = false
            viewModel.brushSize = 18
            viewModel.hardness = 1
            viewModel.opacity = 1
            viewModel.setCloneSource(at: CGPoint(x: 20, y: 15))
        }
        flipped.setCloneSourceFlipsHorizontally(true)

        ordinary.cloneStamp(points: [CGPoint(x: 60, y: 15)])
        flipped.cloneStamp(points: [CGPoint(x: 60, y: 15)])

        let ordinaryLeft = try color(
            ordinary.document.selectedLayer?.image,
            at: CGPoint(x: 55, y: 15)
        )
        let ordinaryRight = try color(
            ordinary.document.selectedLayer?.image,
            at: CGPoint(x: 65, y: 15)
        )
        let flippedLeft = try color(
            flipped.document.selectedLayer?.image,
            at: CGPoint(x: 55, y: 15)
        )
        let flippedRight = try color(
            flipped.document.selectedLayer?.image,
            at: CGPoint(x: 65, y: 15)
        )

        #expect(ordinaryLeft.redComponent > ordinaryLeft.greenComponent + 0.25)
        #expect(ordinaryRight.greenComponent > ordinaryRight.redComponent + 0.25)
        #expect(flippedLeft.greenComponent > flippedLeft.redComponent + 0.25)
        #expect(flippedRight.redComponent > flippedRight.greenComponent + 0.25)
        #expect(flipped.document.history.last?.title == L10n.text("imageEditor.history.cloneStamp"))
    }

    @Test func verticalSourceFlipMirrorsRealClonePixelsAroundTheSamplingOrigin() throws {
        let ordinary = verticallyMirroredSourceViewModel()
        let flipped = verticallyMirroredSourceViewModel()
        for viewModel in [ordinary, flipped] {
            viewModel.isCloneStampAligned = false
            viewModel.brushSize = 18
            viewModel.hardness = 1
            viewModel.opacity = 1
            viewModel.setCloneSource(at: CGPoint(x: 20, y: 15))
        }
        let sourceAbove = try color(
            ordinary.document.selectedLayer?.image,
            at: CGPoint(x: 20, y: 10)
        )
        let sourceBelow = try color(
            ordinary.document.selectedLayer?.image,
            at: CGPoint(x: 20, y: 20)
        )
        flipped.setCloneSourceFlipsVertically(true)

        ordinary.cloneStamp(points: [CGPoint(x: 60, y: 15)])
        flipped.cloneStamp(points: [CGPoint(x: 60, y: 15)])

        let ordinaryTop = try color(
            ordinary.document.selectedLayer?.image,
            at: CGPoint(x: 60, y: 10)
        )
        let ordinaryBottom = try color(
            ordinary.document.selectedLayer?.image,
            at: CGPoint(x: 60, y: 20)
        )
        let flippedTop = try color(
            flipped.document.selectedLayer?.image,
            at: CGPoint(x: 60, y: 10)
        )
        let flippedBottom = try color(
            flipped.document.selectedLayer?.image,
            at: CGPoint(x: 60, y: 20)
        )

        #expect(colorsMatch(ordinaryTop, sourceAbove))
        #expect(colorsMatch(ordinaryBottom, sourceBelow))
        #expect(colorsMatch(flippedTop, sourceBelow))
        #expect(colorsMatch(flippedBottom, sourceAbove))
        #expect(flipped.document.history.last?.title == L10n.text("imageEditor.history.cloneStamp"))
    }

    @Test func combinedSourceFlipsMirrorBothAxesInOneStroke() throws {
        let viewModel = quadrantSourceViewModel()
        viewModel.isCloneStampAligned = false
        viewModel.brushSize = 28
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 20, y: 20))
        viewModel.setCloneSourceFlipsHorizontally(true)
        viewModel.setCloneSourceFlipsVertically(true)
        let expectedTopLeft = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 25, y: 25)
        )
        let expectedBottomRight = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 15, y: 15)
        )

        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 20)])

        let destinationTopLeft = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 55, y: 15)
        )
        let destinationBottomRight = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 65, y: 25)
        )

        #expect(colorsMatch(destinationTopLeft, expectedTopLeft))
        #expect(colorsMatch(destinationBottomRight, expectedBottomRight))
    }

    @Test func uniformSourceScaleEnlargesRealClonePixelsAroundTheSamplingOrigin() throws {
        let ordinary = mirroredSourceViewModel()
        let scaled = mirroredSourceViewModel()
        for viewModel in [ordinary, scaled] {
            viewModel.isCloneStampAligned = false
            viewModel.brushSize = 30
            viewModel.hardness = 1
            viewModel.opacity = 1
            viewModel.setCloneSource(at: CGPoint(x: 20, y: 15))
        }
        scaled.setCloneSourceScalePercent(200)

        ordinary.cloneStamp(points: [CGPoint(x: 60, y: 15)])
        scaled.cloneStamp(points: [CGPoint(x: 60, y: 15)])

        let ordinaryPixel = try color(
            ordinary.document.selectedLayer?.image,
            at: CGPoint(x: 72, y: 15)
        )
        let scaledPixel = try color(
            scaled.document.selectedLayer?.image,
            at: CGPoint(x: 72, y: 15)
        )
        #expect(ordinaryPixel.blueComponent > ordinaryPixel.greenComponent + 0.25)
        #expect(scaledPixel.greenComponent > scaledPixel.blueComponent + 0.25)
        #expect(scaled.document.history.last?.title == L10n.text("imageEditor.history.cloneStamp"))
    }

    @Test func minimumSourceScaleCanPullPreviouslyOffCanvasAlignedPixelsIntoTheStroke() throws {
        let viewModel = compressedSourceViewModel()
        viewModel.isCloneStampAligned = false
        viewModel.brushSize = 30
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 20, y: 15))
        viewModel.setCloneSourceScalePercent(25)

        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 15)])

        let compressedPixel = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 72, y: 15)
        )
        #expect(compressedPixel.redComponent > compressedPixel.blueComponent + 0.25)
    }

    @Test func horizontalFlipComposesWithUniformSourceScaleInOneTransform() throws {
        let viewModel = mirroredSourceViewModel()
        viewModel.isCloneStampAligned = false
        viewModel.brushSize = 24
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 20, y: 15))
        viewModel.setCloneSourceScalePercent(200)
        viewModel.setCloneSourceFlipsHorizontally(true)
        let expected = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 16, y: 15)
        )

        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 15)])

        let transformed = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 68, y: 15)
        )
        #expect(colorsMatch(transformed, expected))
    }

    @Test func verticalSourceScaleChangesOnlyTheVerticalSamplingAxis() throws {
        let viewModel = verticallyMirroredSourceViewModel()
        viewModel.isCloneStampAligned = false
        viewModel.brushSize = 30
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 20, y: 15))
        viewModel.setCloneSourceScalesLinked(false)
        viewModel.setCloneSourceVerticalScalePercent(200)
        let expected = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 20, y: 21)
        )

        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 15)])

        let scaledPixel = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 60, y: 27)
        )
        #expect(colorsMatch(scaledPixel, expected))
        #expect(viewModel.cloneSourceHorizontalScalePercent == 100)
        #expect(viewModel.cloneSourceVerticalScalePercent == 200)
    }

    @Test func anisotropicScaleComposesWithHorizontalFlipWithoutScalingY() throws {
        let viewModel = quadrantSourceViewModel()
        viewModel.isCloneStampAligned = false
        viewModel.brushSize = 30
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 20, y: 20))
        viewModel.setCloneSourceScalesLinked(false)
        viewModel.setCloneSourceHorizontalScalePercent(200)
        viewModel.setCloneSourceFlipsHorizontally(true)
        let expected = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 16, y: 28)
        )

        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 20)])

        let transformed = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 68, y: 28)
        )
        #expect(colorsMatch(transformed, expected))
    }

    @Test func sourceRotationTurnsRealClonePixelsClockwiseAroundTheStrokeOrigin() throws {
        let viewModel = quadrantSourceViewModel()
        viewModel.isCloneStampAligned = false
        viewModel.brushSize = 30
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 20, y: 20))
        viewModel.setCloneSourceRotationDegrees(90)
        let expected = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 16, y: 14)
        )

        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 20)])

        let rotatedPixel = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 66, y: 16)
        )
        #expect(colorsMatch(rotatedPixel, expected))
    }

    @Test func rotationComposesWithAnisotropicScaleAndFlipInOneTransform() throws {
        let viewModel = quadrantSourceViewModel()
        viewModel.isCloneStampAligned = false
        viewModel.brushSize = 30
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 20, y: 20))
        viewModel.configureCloneSourceScale(
            horizontalPercent: 200,
            verticalPercent: 50,
            linked: false
        )
        viewModel.setCloneSourceFlipsHorizontally(true)
        viewModel.setCloneSourceRotationDegrees(90)
        let expected = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 16, y: 14)
        )

        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 20)])

        let transformedPixel = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 63, y: 28)
        )
        #expect(colorsMatch(transformedPixel, expected))
    }

    @Test func bothSourceFlipsComposeWithUniformScaleAcrossBothAxes() throws {
        let viewModel = quadrantSourceViewModel()
        viewModel.isCloneStampAligned = false
        viewModel.brushSize = 30
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 20, y: 20))
        viewModel.setCloneSourceScalePercent(200)
        viewModel.setCloneSourceFlipsHorizontally(true)
        viewModel.setCloneSourceFlipsVertically(true)
        let expected = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 16, y: 16)
        )

        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 20)])

        let transformed = try color(
            viewModel.document.selectedLayer?.image,
            at: CGPoint(x: 68, y: 28)
        )
        #expect(colorsMatch(transformed, expected))
    }

    @Test func sourceFlipsAreRememberedPerSlotAndSurviveResampling() {
        let viewModel = patternedCurrentLayerViewModel()
        viewModel.setCloneSourceFlipsHorizontally(true)
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))

        #expect(viewModel.cloneSourceFlipsHorizontally)
        #expect(!viewModel.cloneSourceFlipsVertically)
        #expect(viewModel.selectCloneSourceSlot(1))
        #expect(!viewModel.cloneSourceFlipsHorizontally)
        viewModel.setCloneSourceFlipsVertically(true)
        viewModel.setCloneSource(at: CGPoint(x: 30, y: 15))
        #expect(viewModel.cloneSourceFlipsVertically)

        #expect(viewModel.selectCloneSourceSlot(0))
        #expect(viewModel.cloneSourceFlipsHorizontally)
        #expect(!viewModel.cloneSourceFlipsVertically)
        viewModel.setCloneSource(at: CGPoint(x: 12, y: 15))
        #expect(viewModel.cloneSourceFlipsHorizontally)
        #expect(!viewModel.cloneSourceFlipsVertically)

        #expect(viewModel.selectCloneSourceSlot(1))
        #expect(!viewModel.cloneSourceFlipsHorizontally)
        #expect(viewModel.cloneSourceFlipsVertically)
    }

    @Test func sourceScalesLinkByRatioAndRemainIndependentPerSlot() {
        let viewModel = patternedCurrentLayerViewModel()
        viewModel.setCloneSourceHorizontalScalePercent(200)
        #expect(viewModel.cloneSourceHorizontalScalePercent == 200)
        #expect(viewModel.cloneSourceVerticalScalePercent == 200)

        viewModel.setCloneSourceScalesLinked(false)
        viewModel.setCloneSourceVerticalScalePercent(50)
        #expect(viewModel.cloneSourceHorizontalScalePercent == 200)
        #expect(viewModel.cloneSourceVerticalScalePercent == 50)

        viewModel.setCloneSourceScalesLinked(true)
        viewModel.setCloneSourceHorizontalScalePercent(400)
        #expect(viewModel.cloneSourceHorizontalScalePercent == 400)
        #expect(viewModel.cloneSourceVerticalScalePercent == 100)
        viewModel.setCloneSourceVerticalScalePercent(400)
        #expect(viewModel.cloneSourceHorizontalScalePercent == 400)
        #expect(viewModel.cloneSourceVerticalScalePercent == 100)
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))

        #expect(viewModel.selectCloneSourceSlot(1))
        #expect(viewModel.cloneSourceHorizontalScalePercent == 100)
        #expect(viewModel.cloneSourceVerticalScalePercent == 100)
        #expect(viewModel.cloneSourceScalesLinked)
        viewModel.configureCloneSourceScale(
            horizontalPercent: 75,
            verticalPercent: 150,
            linked: false
        )
        viewModel.setCloneSource(at: CGPoint(x: 30, y: 15))
        #expect(viewModel.cloneSourceHorizontalScalePercent == 75)
        #expect(viewModel.cloneSourceVerticalScalePercent == 150)
        #expect(!viewModel.cloneSourceScalesLinked)

        #expect(viewModel.selectCloneSourceSlot(0))
        #expect(viewModel.cloneSourceHorizontalScalePercent == 400)
        #expect(viewModel.cloneSourceVerticalScalePercent == 100)
        #expect(viewModel.cloneSourceScalesLinked)
        viewModel.setCloneSource(at: CGPoint(x: 12, y: 15))
        #expect(viewModel.cloneSourceHorizontalScalePercent == 400)
        #expect(viewModel.cloneSourceVerticalScalePercent == 100)

        #expect(viewModel.selectCloneSourceSlot(1))
        #expect(viewModel.cloneSourceHorizontalScalePercent == 75)
        #expect(viewModel.cloneSourceVerticalScalePercent == 150)
        #expect(!viewModel.cloneSourceScalesLinked)
    }

    @Test func uniformScaleCompatibilityClampsBothAxesTogether() {
        let viewModel = patternedCurrentLayerViewModel()
        viewModel.setCloneSourceScalesLinked(false)

        viewModel.setCloneSourceScalePercent(500)
        #expect(viewModel.cloneSourceHorizontalScalePercent == 400)
        #expect(viewModel.cloneSourceVerticalScalePercent == 400)
        viewModel.setCloneSourceScalePercent(10)
        #expect(viewModel.cloneSourceHorizontalScalePercent == 25)
        #expect(viewModel.cloneSourceVerticalScalePercent == 25)
    }

    @Test func sourceRotationIsClampedRememberedPerSlotAndSurvivesResampling() {
        let viewModel = patternedCurrentLayerViewModel()
        viewModel.setCloneSourceRotationDegrees(270)
        #expect(viewModel.cloneSourceRotationDegrees == 180)
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))

        #expect(viewModel.selectCloneSourceSlot(1))
        #expect(viewModel.cloneSourceRotationDegrees == 0)
        viewModel.setCloneSourceRotationDegrees(-270)
        #expect(viewModel.cloneSourceRotationDegrees == -180)
        viewModel.setCloneSourceRotationDegrees(37)
        viewModel.setCloneSource(at: CGPoint(x: 30, y: 15))

        #expect(viewModel.selectCloneSourceSlot(0))
        #expect(viewModel.cloneSourceRotationDegrees == 180)
        viewModel.setCloneSource(at: CGPoint(x: 12, y: 15))
        #expect(viewModel.cloneSourceRotationDegrees == 180)

        #expect(viewModel.selectCloneSourceSlot(1))
        #expect(viewModel.cloneSourceRotationDegrees == 37)
    }

    @Test func cloneOverlayUsesTheConfiguredSourceRangeAndOpacity() throws {
        let viewModel = layeredSamplingViewModel()
        viewModel.cloneStampSampleSource = .currentAndBelow
        viewModel.setCloneStampOverlayOpacityPercent(35)
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))

        let preview = try #require(
            viewModel.cloneStampOverlayPreview(
                destinationReference: CGPoint(x: 60, y: 15)
            )
        )
        let sourceColor = try color(preview.sourceCanvas, at: CGPoint(x: 10, y: 15))
        #expect(sourceColor.redComponent > sourceColor.greenComponent + 0.25)
        #expect(preview.opacity == 0.35)
        #expect(
            preview.geometry.transformedCanvasPoint(
                fromSourceCanvasPoint: CGPoint(x: 10, y: 15)
            ) == CGPoint(x: 60, y: 15)
        )

        viewModel.cloneStampShowsOverlay = false
        #expect(
            viewModel.cloneStampOverlayPreview(
                destinationReference: CGPoint(x: 60, y: 15)
            ) == nil
        )
        viewModel.setCloneStampOverlayOpacityPercent(-20)
        #expect(viewModel.cloneStampOverlayOpacityPercent == 0)
        viewModel.setCloneStampOverlayOpacityPercent(120)
        #expect(viewModel.cloneStampOverlayOpacityPercent == 100)
    }

    @Test func cloneOverlayAutoHideSuppressesOnlyAnActivePaintStroke() throws {
        let viewModel = patternedCurrentLayerViewModel()
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))
        let destination = CGPoint(x: 60, y: 15)

        #expect(
            viewModel.cloneStampOverlayPreview(
                destinationReference: destination,
                isPainting: true
            ) != nil
        )

        viewModel.cloneStampOverlayAutoHidesWhilePainting = true
        #expect(
            viewModel.cloneStampOverlayPreview(
                destinationReference: destination,
                isPainting: false
            ) != nil
        )
        #expect(
            viewModel.cloneStampOverlayPreview(
                destinationReference: destination,
                isPainting: true
            ) == nil
        )

        viewModel.cloneStampOverlayAutoHidesWhilePainting = false
        #expect(
            viewModel.cloneStampOverlayPreview(
                destinationReference: destination,
                isPainting: true
            ) != nil
        )
    }

    @Test func cloneOverlayInvertReusesTheSourceCanvasWithoutChangingSampledPixels() throws {
        let viewModel = patternedCurrentLayerViewModel()
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))
        let destination = CGPoint(x: 60, y: 15)
        let normal = try #require(
            viewModel.cloneStampOverlayPreview(destinationReference: destination)
        )
        let sourceColor = try color(normal.sourceCanvas, at: CGPoint(x: 10, y: 15))
        #expect(!normal.invertsColors)

        viewModel.cloneStampOverlayInvertsColors = true
        let inverted = try #require(
            viewModel.cloneStampOverlayPreview(destinationReference: destination)
        )

        #expect(inverted.invertsColors)
        #expect(inverted.sourceCanvas === normal.sourceCanvas)
        #expect(
            try color(inverted.sourceCanvas, at: CGPoint(x: 10, y: 15))
                == sourceColor
        )
    }

    @Test func cloneOverlayClippedUsesTheLiveBrushFootprintWithoutRebuildingSource() throws {
        let viewModel = patternedCurrentLayerViewModel()
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))
        let destination = CGPoint(x: 60, y: 15)
        let fullOverlay = try #require(
            viewModel.cloneStampOverlayPreview(destinationReference: destination)
        )
        #expect(fullOverlay.brushClip == nil)

        viewModel.cloneStampOverlayClipsToBrush = true
        let clipped = try #require(viewModel.cloneStampOverlayPreview(
            destinationReference: destination,
            isPainting: true,
            brushCenter: CGPoint(x: 66, y: 18),
            brushDiameter: 14
        ))

        #expect(clipped.sourceCanvas === fullOverlay.sourceCanvas)
        #expect(clipped.brushClip?.center == CGPoint(x: 66, y: 18))
        #expect(clipped.brushClip?.diameter == 14)
        #expect(clipped.brushClip?.canvasRect == CGRect(x: 59, y: 11, width: 14, height: 14))
    }

    @Test func cloneOverlayBlendModesMapToCanvasAndReuseTheSourceCanvas() throws {
        #expect(ImageEditorCloneStampOverlayBlendMode.normal.canvasBlendMode == .normal)
        #expect(ImageEditorCloneStampOverlayBlendMode.darken.canvasBlendMode == .darken)
        #expect(ImageEditorCloneStampOverlayBlendMode.lighten.canvasBlendMode == .lighten)
        #expect(ImageEditorCloneStampOverlayBlendMode.difference.canvasBlendMode == .difference)
        #expect(ImageEditorCloneStampOverlayBlendMode.allCases.map(\.rawValue) == [
            "normal", "darken", "lighten", "difference"
        ])

        let viewModel = patternedCurrentLayerViewModel()
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))
        let normal = try #require(
            viewModel.cloneStampOverlayPreview(destinationReference: CGPoint(x: 60, y: 15))
        )
        #expect(normal.blendMode == .normal)

        viewModel.cloneStampOverlayBlendMode = .difference
        let difference = try #require(
            viewModel.cloneStampOverlayPreview(destinationReference: CGPoint(x: 60, y: 15))
        )
        #expect(difference.blendMode == .difference)
        #expect(difference.sourceCanvas === normal.sourceCanvas)
    }

    @Test func cloneOverlaySourceCanvasIsCachedAcrossHoverAndInvalidatedByEdits() throws {
        let viewModel = patternedCurrentLayerViewModel()
        viewModel.isCloneStampAligned = false
        viewModel.brushSize = 6
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))

        let first = try #require(
            viewModel.cloneStampOverlayPreview(
                destinationReference: CGPoint(x: 50, y: 15)
            )
        )
        let second = try #require(
            viewModel.cloneStampOverlayPreview(
                destinationReference: CGPoint(x: 70, y: 15)
            )
        )
        #expect(first.sourceCanvas === second.sourceCanvas)

        viewModel.cloneStamp(points: [CGPoint(x: 50, y: 15)])
        let afterEdit = try #require(
            viewModel.cloneStampOverlayPreview(
                destinationReference: CGPoint(x: 70, y: 15)
            )
        )
        #expect(afterEdit.sourceCanvas !== first.sourceCanvas)
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

    private func mirroredSourceViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 100, height: 30)
        let image = bitmap(size: size, background: .systemBlue, fills: [
            (CGRect(x: 10, y: 8, width: 10, height: 14), .systemRed),
            (CGRect(x: 20, y: 8, width: 10, height: 14), .systemGreen)
        ])
        var document = ImageEditorDocument(sourceName: "source.png", image: image)
        var layer = ImageEditorLayer.blank(name: "Mirror Pattern", size: size)
        layer.image = image
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        return ImageEditorViewModel(document: document) { _ in }
    }

    private func verticallyMirroredSourceViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 100, height: 30)
        let image = bitmap(size: size, background: .systemBlue, fills: [
            (CGRect(x: 14, y: 5, width: 12, height: 10), .systemRed),
            (CGRect(x: 14, y: 15, width: 12, height: 10), .systemGreen)
        ])
        var document = ImageEditorDocument(sourceName: "source.png", image: image)
        var layer = ImageEditorLayer.blank(name: "Vertical Mirror Pattern", size: size)
        layer.image = image
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        return ImageEditorViewModel(document: document) { _ in }
    }

    private func compressedSourceViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 100, height: 30)
        let image = bitmap(size: size, background: .systemBlue, fills: [
            (CGRect(x: 66, y: 8, width: 8, height: 14), .systemRed)
        ])
        var document = ImageEditorDocument(sourceName: "source.png", image: image)
        var layer = ImageEditorLayer.blank(name: "Compressed Pattern", size: size)
        layer.image = image
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        return ImageEditorViewModel(document: document) { _ in }
    }

    private func quadrantSourceViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 100, height: 40)
        let image = bitmap(size: size, background: .systemBlue, fills: [
            (CGRect(x: 10, y: 10, width: 10, height: 10), .systemRed),
            (CGRect(x: 20, y: 10, width: 10, height: 10), .systemGreen),
            (CGRect(x: 10, y: 20, width: 10, height: 10), .systemYellow),
            (CGRect(x: 20, y: 20, width: 10, height: 10), .magenta)
        ])
        var document = ImageEditorDocument(sourceName: "source.png", image: image)
        var layer = ImageEditorLayer.blank(name: "Quadrant Pattern", size: size)
        layer.image = image
        document.layers = [layer]
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
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

    private func colorsMatch(_ lhs: NSColor, _ rhs: NSColor, tolerance: CGFloat = 0.05) -> Bool {
        abs(lhs.redComponent - rhs.redComponent) <= tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) <= tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) <= tolerance
            && abs(lhs.alphaComponent - rhs.alphaComponent) <= tolerance
    }
}
