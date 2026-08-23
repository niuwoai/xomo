//
//  ImageEditorSampledBrushPreviewTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/19.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSampledBrushPreviewTests {
    @Test func clonePreviewKeepsAlignedOffsetAndResetsNonAlignedOffset() {
        let viewModel = sampledBrushViewModel()
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))

        let firstPreview = viewModel.sampledBrushPreviewSourcePoint(
            for: .cloneStamp,
            strokeStart: CGPoint(x: 50, y: 15),
            currentDestination: CGPoint(x: 55, y: 15)
        )
        #expect(firstPreview == CGPoint(x: 15, y: 15))

        viewModel.cloneStamp(points: [CGPoint(x: 50, y: 15), CGPoint(x: 55, y: 15)])
        let nextAlignedPreview = viewModel.sampledBrushPreviewSourcePoint(
            for: .cloneStamp,
            strokeStart: CGPoint(x: 70, y: 15),
            currentDestination: CGPoint(x: 75, y: 15)
        )
        #expect(nextAlignedPreview == CGPoint(x: 35, y: 15))

        viewModel.isCloneStampAligned = false
        let nonAlignedPreview = viewModel.sampledBrushPreviewSourcePoint(
            for: .cloneStamp,
            strokeStart: CGPoint(x: 70, y: 15),
            currentDestination: CGPoint(x: 75, y: 15)
        )
        #expect(nonAlignedPreview == CGPoint(x: 15, y: 15))
    }

    @Test func cloneSourceSlotsRetainTheirOwnAlignedOffsets() {
        let viewModel = sampledBrushViewModel()
        viewModel.setCloneSource(at: CGPoint(x: 10, y: 15))
        viewModel.cloneStamp(points: [CGPoint(x: 50, y: 15)])

        #expect(viewModel.selectCloneSourceSlot(1))
        viewModel.setCloneSource(at: CGPoint(x: 30, y: 15))
        viewModel.cloneStamp(points: [CGPoint(x: 60, y: 15)])

        #expect(viewModel.selectCloneSourceSlot(0))
        let firstSlotPreview = viewModel.sampledBrushPreviewSourcePoint(
            for: .cloneStamp,
            strokeStart: CGPoint(x: 80, y: 15),
            currentDestination: CGPoint(x: 85, y: 15)
        )
        #expect(firstSlotPreview == CGPoint(x: 45, y: 15))

        #expect(viewModel.selectCloneSourceSlot(1))
        let secondSlotPreview = viewModel.sampledBrushPreviewSourcePoint(
            for: .cloneStamp,
            strokeStart: CGPoint(x: 80, y: 15),
            currentDestination: CGPoint(x: 85, y: 15)
        )
        #expect(secondSlotPreview == CGPoint(x: 55, y: 15))

        viewModel.isCloneStampAligned = false
        viewModel.isCloneStampAligned = true
        let resetPreview = viewModel.sampledBrushPreviewSourcePoint(
            for: .cloneStamp,
            strokeStart: CGPoint(x: 80, y: 15),
            currentDestination: CGPoint(x: 85, y: 15)
        )
        #expect(resetPreview == CGPoint(x: 35, y: 15))
    }

    @Test func healingPreviewUsesItsOwnSourceAndRejectsOtherTools() {
        let viewModel = sampledBrushViewModel()
        viewModel.isHealingBrushAligned = false
        viewModel.setHealingSource(at: CGPoint(x: 12, y: 14))

        let preview = viewModel.sampledBrushPreviewSourcePoint(
            for: .healingBrush,
            strokeStart: CGPoint(x: 60, y: 20),
            currentDestination: CGPoint(x: 66, y: 24)
        )

        #expect(preview == CGPoint(x: 18, y: 18))
        #expect(viewModel.sampledBrushPreviewSourcePoint(
            for: .brush,
            strokeStart: .zero,
            currentDestination: CGPoint(x: 10, y: 10)
        ) == nil)
    }

    @Test func overlayGeometryTracksLiveSourceAndPressureAdjustedFootprint() {
        let pressure: CGFloat = 0.25
        let geometry = ImageEditorSampledBrushOverlayGeometry.resolve(
            sourcePoint: CGPoint(x: 10, y: 20),
            liveSourcePoint: CGPoint(x: 25, y: 30),
            currentDestination: CGPoint(x: 85, y: 30),
            isPickingSource: false,
            brushDiameter: 20,
            pressure: pressure,
            pressureControlsSize: true,
            pressureSensitivity: 0.5
        )
        let expectedDiameter = 20 * ImageEditorBrushStrokeKernel.mappedPressure(
            pressure,
            sensitivity: 0.5
        )

        #expect(geometry.sourcePoint == CGPoint(x: 25, y: 30))
        #expect(geometry.destinationPoint == CGPoint(x: 85, y: 30))
        #expect(abs(geometry.diameter - expectedDiameter) < 0.001)
    }

    @Test func overlayGeometryUsesIdleSourceAndFullDiameter() {
        let idle = ImageEditorSampledBrushOverlayGeometry.resolve(
            sourcePoint: CGPoint(x: 10, y: 20),
            liveSourcePoint: nil,
            currentDestination: nil,
            isPickingSource: false,
            brushDiameter: 18,
            pressure: nil,
            pressureControlsSize: true,
            pressureSensitivity: 0.5
        )

        #expect(idle.sourcePoint == CGPoint(x: 10, y: 20))
        #expect(idle.destinationPoint == nil)
        #expect(idle.diameter == 18)
        #expect(idle.connector == nil)
    }

    @Test func overlayGeometryKeepsSourcePickingAtTheOriginalPoint() {
        let picking = ImageEditorSampledBrushOverlayGeometry.resolve(
            sourcePoint: CGPoint(x: 10, y: 20),
            liveSourcePoint: CGPoint(x: 40, y: 20),
            currentDestination: CGPoint(x: 80, y: 20),
            isPickingSource: true,
            brushDiameter: 24,
            pressure: 0.1,
            pressureControlsSize: false,
            pressureSensitivity: 1
        )

        #expect(picking.sourcePoint == CGPoint(x: 10, y: 20))
        #expect(picking.destinationPoint == nil)
        #expect(picking.diameter == 24)
        #expect(picking.connector == nil)
    }

    @Test func overlayConnectorTrimsBothFootprintsAndSuppressesShortSegments() {
        let separated = ImageEditorSampledBrushOverlayGeometry(
            sourcePoint: CGPoint(x: 25, y: 30),
            destinationPoint: CGPoint(x: 85, y: 30),
            diameter: 20
        )
        #expect(separated.connector?.start == CGPoint(x: 35, y: 30))
        #expect(separated.connector?.end == CGPoint(x: 75, y: 30))

        let nearby = ImageEditorSampledBrushOverlayGeometry(
            sourcePoint: CGPoint(x: 10, y: 10),
            destinationPoint: CGPoint(x: 25, y: 10),
            diameter: 20
        )
        #expect(nearby.connector == nil)
    }

    @Test func independentCloneScalesAndRotationDescribeTheSourceFootprint() {
        let geometry = ImageEditorSampledBrushOverlayGeometry.resolve(
            sourcePoint: CGPoint(x: 10, y: 20),
            liveSourcePoint: CGPoint(x: 20, y: 30),
            currentDestination: CGPoint(x: 80, y: 30),
            isPickingSource: false,
            brushDiameter: 20,
            horizontalSourceScale: 2,
            verticalSourceScale: 1,
            sourceRotationDegrees: 37,
            pressure: nil,
            pressureControlsSize: false,
            pressureSensitivity: 0.5
        )

        #expect(geometry.diameter == 10)
        #expect(geometry.sourceHeight == 20)
        #expect(geometry.sourceRotationDegrees == 37)
        #expect(geometry.destinationDiameter == 20)
        #expect(geometry.connector?.start == CGPoint(x: 25, y: 30))
        #expect(geometry.connector?.end == CGPoint(x: 70, y: 30))
    }

    @Test func cloneOverlayGeometryMapsSourcePixelsThroughTheSharedAffineOrder() {
        let geometry = ImageEditorCloneStampOverlayGeometry(
            canvasOffset: CGSize(width: -40, height: 0),
            destinationReference: CGPoint(x: 60, y: 20),
            targetFrame: CGRect(x: 0, y: 0, width: 100, height: 40),
            horizontalScale: 2,
            verticalScale: 0.5,
            flipsHorizontally: true,
            flipsVertically: false,
            rotationDegrees: 90
        )

        #expect(
            geometry.transformedCanvasPoint(
                fromSourceCanvasPoint: CGPoint(x: 20, y: 20)
            ) == CGPoint(x: 60, y: 20)
        )
        let transformed = geometry.transformedCanvasPoint(
            fromSourceCanvasPoint: CGPoint(x: 16, y: 14)
        )
        #expect(abs(transformed.x - 63) < 0.0001)
        #expect(abs(transformed.y - 28) < 0.0001)
    }

    @Test func canvasOverlayUsesLiveStrokeEndpointsButNotSourceSetting() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let overlayStart = try #require(source.range(of: "private func sampledBrushSourceOverlay(in size: CGSize)"))
        let propertyStart = try #require(
            source[overlayStart.upperBound...].range(
                of: "private var sampledBrushOverlayGeometry: ImageEditorSampledBrushOverlayGeometry?"
            )
        )
        let propertyEnd = try #require(
            source[propertyStart.upperBound...].range(of: "private func canvasGesture")
        )
        let overlaySource = source[overlayStart.lowerBound..<propertyStart.lowerBound]
        let propertySource = source[propertyStart.lowerBound..<propertyEnd.lowerBound]

        #expect(propertySource.contains("let strokeStart = dragPoints.first"))
        #expect(propertySource.contains("let currentDestination = dragPoints.last"))
        #expect(propertySource.contains("sampledBrushPreviewSourcePoint("))
        #expect(propertySource.contains("isPickingSource: isSettingSampledBrushSourceGesture"))
        #expect(propertySource.contains("pressure: brushStrokeSamples.last?.pressure"))
        #expect(propertySource.contains("pressureControlsSize: viewModel.retouchPressureControlsSize"))
        #expect(propertySource.contains("viewModel.healingBrushMode == .source"))
        #expect(propertySource.contains("viewModel.cloneSourceHorizontalScalePercent"))
        #expect(propertySource.contains("viewModel.cloneSourceVerticalScalePercent"))
        #expect(propertySource.contains("viewModel.cloneSourceRotationDegrees"))
        #expect(overlaySource.contains("geometry.connector"))
        #expect(overlaySource.contains("StrokeStyle(lineWidth: 1, dash: [5, 4])"))
        #expect(overlaySource.contains("geometry.diameter * viewScale"))
        #expect(overlaySource.contains("geometry.sourceHeight"))
        #expect(overlaySource.contains("geometry.sourceRotationDegrees"))
        #expect(overlaySource.contains(".rotationEffect("))
        #expect(source.contains("cloneStampPixelOverlay(in: geometry.size)"))
        #expect(source.contains("viewModel.cloneStampOverlayPreview("))
        #expect(source.contains("isPainting: !dragPoints.isEmpty"))
        #expect(source.contains("brushCenter: dragPoints.last ?? hoverCanvasPoint"))
        #expect(source.contains("sampledBrushOverlayGeometry?.destinationDiameter"))
        #expect(source.contains("context.clip(to: Path(targetFrame))"))
        #expect(source.contains("if let brushClip = preview.brushClip"))
        #expect(source.contains("ellipseIn: viewRect(from: brushClip.canvasRect, in: size)"))
        #expect(source.contains("context.opacity = Double(preview.opacity)"))
        #expect(source.contains("if preview.invertsColors"))
        #expect(source.contains("context.addFilter(.colorInvert(1))"))
        #expect(source.contains("context.draw(Image(nsImage: preview.sourceCanvas), in: sourceFrame)"))
        #expect(overlaySource.contains("Ellipse()"))
    }

    private func sampledBrushViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 100, height: 30)
        let image = NSImage.rendered(size: size) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            NSColor.systemRed.setFill()
            CGRect(x: 6, y: 10, width: 18, height: 10).fill()
        } ?? NSImage.transparent(size: size)
        return ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
