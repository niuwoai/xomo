//
//  ImageEditorShapeStyleTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/15.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@Suite
@MainActor
struct ImageEditorShapeStyleTests {
    @Test func gradientDitherIsDeterministicVisibleAndBackwardCompatible() throws {
        var gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: .black,
            endColor: .white
        )
        let plain = gradient.renderedImage(size: CGSize(width: 64, height: 4))
        gradient.dither = true
        let first = gradient.renderedImage(size: CGSize(width: 64, height: 4))
        let second = gradient.renderedImage(size: CGSize(width: 64, height: 4))

        #expect(first.qingtuPNGData() == second.qingtuPNGData())
        #expect(first.qingtuPNGData() != plain.qingtuPNGData())
        let plainSamples = try (0..<4).map { y in
            try #require(plain.color(at: CGPoint(x: 32, y: y))).redComponent
        }
        let ditheredSamples = try (0..<4).map { y in
            try #require(first.color(at: CGPoint(x: 32, y: y))).redComponent
        }
        #expect(Set(plainSamples).count == 1)
        #expect(Set(ditheredSamples).count > 1)

        let legacy = try JSONDecoder().decode(
            ImageEditorGradientFillContent.self,
            from: Data(#"{"preset":"blackWhite","style":"linear"}"#.utf8)
        )
        #expect(!legacy.dither)
    }

    @Test func shapeGradientDitherIsUndoableAndPersistsAcrossProjects() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 70),
            ellipse: false,
            fillGradient: .shapeLinear(startColor: .black, endColor: .white)
        )
        let historyCount = viewModel.document.history.count

        viewModel.setSelectedShapeGradientDither(true)
        #expect(viewModel.selectedShapeGradientDither)
        #expect(viewModel.document.history.count == historyCount + 1)
        viewModel.setSelectedShapeGradientDither(true)
        #expect(viewModel.document.history.count == historyCount + 1)
        viewModel.undo()
        #expect(!viewModel.selectedShapeGradientDither)
        viewModel.redo()
        #expect(viewModel.selectedShapeGradientDither)

        let reopened = makeViewModel()
        try reopened.loadProjectData(viewModel.projectData())
        #expect(reopened.selectedShapeGradientDither)
    }

    @Test func angleGradientSweepsAroundItsCenterAndRotatesWithAngle() throws {
        var gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: .black,
            endColor: .white,
            angle: 0
        )
        gradient.style = .angle
        let image = gradient.renderedImage(size: CGSize(width: 101, height: 101))
        let right = try #require(image.color(at: CGPoint(x: 90, y: 50))).redComponent
        let left = try #require(image.color(at: CGPoint(x: 10, y: 50))).redComponent
        let vertical = try [CGPoint(x: 50, y: 10), CGPoint(x: 50, y: 90)].map {
            try #require(image.color(at: $0)).redComponent
        }.sorted()

        #expect(right < 0.03)
        #expect(abs(left - 0.5) < 0.03)
        #expect(abs(vertical[0] - 0.25) < 0.03)
        #expect(abs(vertical[1] - 0.75) < 0.03)

        gradient.angle = 90
        let rotated = gradient.renderedImage(size: CGSize(width: 101, height: 101))
        let rotatedRight = try #require(
            rotated.color(at: CGPoint(x: 90, y: 50))
        ).redComponent
        #expect(abs(rotatedRight - 0.75) < 0.03)
    }

    @Test func gradientColorStopAlphaRendersAndPersistsAcrossProjects() throws {
        let gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(
                position: 0,
                red: 1,
                green: 0,
                blue: 0,
                alpha: 0
            ),
            ImageEditorGradientColorStop(
                position: 1,
                red: 1,
                green: 0,
                blue: 0,
                alpha: 1
            )
        ])
        let midpointColor = try #require(
            gradient.shapeColor(at: 0.5).usingColorSpace(.deviceRGB)
        )
        #expect(abs(midpointColor.alphaComponent - 0.5) < 0.001)

        let rendered = gradient.renderedImage(size: CGSize(width: 101, height: 1))
        let renderedMidpoint = try #require(rendered.color(at: CGPoint(x: 50, y: 0)))
        #expect(abs(renderedMidpoint.redComponent - 1) < 0.025)
        #expect(abs(renderedMidpoint.alphaComponent - 0.5) < 0.025)

        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 70),
            ellipse: false,
            fillGradient: gradient,
            fillOpacity: 0.8
        )
        let shapeImage = try #require(
            viewModel.document.selectedLayer?.shapeContent?.renderedImage(
                size: CGSize(width: 101, height: 61)
            )
        )
        let shapeMidpoint = try #require(shapeImage.color(at: CGPoint(x: 50, y: 30)))
        #expect(abs(shapeMidpoint.alphaComponent - 0.4) < 0.04)

        let projectData = try viewModel.projectData()
        let reopened = makeViewModel()
        try reopened.loadProjectData(projectData)
        #expect(reopened.selectedShapeGradientColorStops[0].alpha == 0)
        #expect(reopened.selectedShapeGradientColorStops[1].alpha == 1)

        let legacyStop = try JSONDecoder().decode(
            ImageEditorGradientColorStop.self,
            from: Data(#"{"position":0,"red":1,"green":0,"blue":0}"#.utf8)
        )
        #expect(legacyStop.alpha == ImageEditorGradientColorStop.defaultAlpha)
    }

    @Test func gradientStopOpacityEditingIsUndoableAndColorChangesPreserveAlpha() throws {
        let gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(
                position: 0,
                red: 0.8,
                green: 0.1,
                blue: 0.2,
                alpha: 0.2,
                midpoint: 0.3
            ),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 70),
            ellipse: false,
            fillGradient: gradient
        )
        let original = viewModel.selectedShapeGradientColorStops[0]
        let historyCount = viewModel.document.history.count

        viewModel.setSelectedShapeGradientStopOpacity(at: 0, opacity: 0.35)
        let edited = viewModel.selectedShapeGradientColorStops[0]
        #expect(abs(edited.alpha - 0.35) < 0.000_001)
        #expect(edited.red == original.red)
        #expect(edited.green == original.green)
        #expect(edited.blue == original.blue)
        #expect(edited.midpoint == original.midpoint)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.setSelectedShapeGradientStopOpacity(at: 0, opacity: 0.35)
        #expect(viewModel.document.history.count == historyCount + 1)
        viewModel.undo()
        #expect(viewModel.selectedShapeGradientColorStops[0] == original)
        #expect(viewModel.canRedo)

        viewModel.setSelectedShapeGradientStopOpacity(at: 0, opacity: .infinity)
        #expect(viewModel.selectedShapeGradientColorStops[0] == original)
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(abs(viewModel.selectedShapeGradientColorStops[0].alpha - 0.35) < 0.000_001)

        viewModel.setSelectedShapeGradientStopColor(at: 0, color: .systemGreen)
        let recolored = viewModel.selectedShapeGradientColorStops[0]
        #expect(abs(recolored.alpha - 0.35) < 0.000_001)
        #expect(recolored.midpoint == original.midpoint)

        let projectData = try viewModel.projectData()
        let reopened = makeViewModel()
        try reopened.loadProjectData(projectData)
        #expect(reopened.selectedShapeGradientColorStops[0] == recolored)
        reopened.setSelectedShapeGradientStopOpacity(at: 0, opacity: -1)
        #expect(reopened.selectedShapeGradientColorStops[0].alpha == 0)
        reopened.setSelectedShapeGradientStopOpacity(at: 0, opacity: 2)
        #expect(reopened.selectedShapeGradientColorStops[0].alpha == 1)
    }

    @Test func gradientColorMidpointsShapeRenderingAndPersistAcrossProjects() throws {
        let gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(
                position: 0,
                red: 0,
                green: 0,
                blue: 0,
                midpoint: 0.25
            ),
            ImageEditorGradientColorStop(position: 1, red: 1, green: 1, blue: 1)
        ])
        let midpointColor = try #require(
            gradient.shapeColor(at: 0.25).usingColorSpace(.deviceRGB)
        )
        let laterColor = try #require(
            gradient.shapeColor(at: 0.5).usingColorSpace(.deviceRGB)
        )
        #expect(abs(midpointColor.redComponent - 0.5) < 0.001)
        #expect(abs(midpointColor.greenComponent - 0.5) < 0.001)
        #expect(abs(midpointColor.blueComponent - 0.5) < 0.001)
        #expect(abs(laterColor.redComponent - (2.0 / 3.0)) < 0.001)

        let rendered = gradient.renderedImage(size: CGSize(width: 101, height: 1))
        let renderedMidpoint = try #require(rendered.color(at: CGPoint(x: 25, y: 0)))
        #expect(abs(renderedMidpoint.redComponent - 0.5) < 0.025)
        var reversed = gradient
        reversed.reverse = true
        let reversedImage = reversed.renderedImage(size: CGSize(width: 101, height: 1))
        let reversedMidpoint = try #require(reversedImage.color(at: CGPoint(x: 75, y: 0)))
        #expect(abs(reversedMidpoint.redComponent - 0.5) < 0.025)

        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 70),
            ellipse: false,
            fillGradient: gradient
        )
        viewModel.setSelectedShapeGradientStopColor(at: 0, color: .systemRed)
        #expect(abs(viewModel.selectedShapeGradientColorStops[0].midpoint - 0.25) < 0.000_001)

        let projectData = try viewModel.projectData()
        let reopened = makeViewModel()
        try reopened.loadProjectData(projectData)
        #expect(abs(reopened.selectedShapeGradientColorStops[0].midpoint - 0.25) < 0.000_001)

        let legacyStop = try JSONDecoder().decode(
            ImageEditorGradientColorStop.self,
            from: Data(#"{"position":0,"red":0,"green":0,"blue":0}"#.utf8)
        )
        #expect(legacyStop.midpoint == 0.5)
    }

    @Test func linearGradientFillClipsToShapeAndPreservesIndependentStroke() throws {
        let gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: .systemRed,
            endColor: .systemBlue
        )
        let image = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .clear,
            fillGradient: gradient,
            fillOpacity: 0.7,
            strokeColor: .systemGreen,
            strokeWidth: 4,
            strokeOpacity: 0.9,
            cornerRadius: 8
        ).renderedImage(size: CGSize(width: 48, height: 32))

        let left = try #require(image.color(at: CGPoint(x: 8, y: 16)))
        let right = try #require(image.color(at: CGPoint(x: 39, y: 16)))
        let edge = try #require(image.color(at: CGPoint(x: 1, y: 16)))
        let corner = try #require(image.color(at: CGPoint(x: 0, y: 0)))
        #expect(left.redComponent > left.blueComponent + 0.2)
        #expect(right.blueComponent > right.redComponent + 0.2)
        #expect(abs(left.alphaComponent - 0.7) < 0.1)
        #expect(edge.greenComponent > edge.redComponent + 0.35)
        #expect(corner.alphaComponent < 0.05)
    }

    @Test func radialGradientRendersPersistsAndSwitchesWithOneUndoPerEdit() throws {
        var gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: .systemRed,
            endColor: .systemBlue,
            scale: 0.7
        )
        gradient.style = .radial
        let content = ImageEditorShapeContent(
            kind: .ellipse,
            fillColor: .clear,
            fillGradient: gradient,
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0
        ).normalized(size: CGSize(width: 101, height: 101))
        #expect(content.fillGradient?.style == .radial)
        for style in [ImageEditorGradientFillStyle.angle, .reflected, .diamond] {
            var alternateContent = content
            alternateContent.fillGradient?.style = style
            #expect(
                alternateContent.normalized(size: CGSize(width: 101, height: 101))
                    .fillGradient?.style == style
            )
        }
        let image = content.renderedImage(size: CGSize(width: 101, height: 101))
        let center = try #require(image.color(at: CGPoint(x: 50, y: 50)))
        let edge = try #require(image.color(at: CGPoint(x: 95, y: 50)))
        let corner = try #require(image.color(at: CGPoint(x: 0, y: 0)))
        #expect(center.redComponent > center.blueComponent + 0.7)
        #expect(edge.blueComponent > edge.redComponent + 0.5)
        #expect(corner.alphaComponent < 0.05)

        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 110),
            ellipse: true
        )
        let historyBeforeKind = viewModel.document.history.count
        viewModel.setSelectedShapeFillKind(.radialGradient)
        #expect(viewModel.selectedShapeFillKind == .radialGradient)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.style == .radial)
        #expect(viewModel.document.history.count == historyBeforeKind + 1)
        #expect(viewModel.selectedShapeGradientCanvasHandlePoints == nil)

        let historyBeforeScale = viewModel.document.history.count
        viewModel.setSelectedShapeGradientScale(0.65)
        #expect(abs(viewModel.selectedShapeGradientScale - 0.65) < 0.001)
        #expect(viewModel.document.history.count == historyBeforeScale + 1)
        viewModel.undo()
        #expect(abs(viewModel.selectedShapeGradientScale - 1) < 0.001)
        viewModel.redo()

        let projectData = try viewModel.projectData()
        let reopened = makeViewModel()
        try reopened.loadProjectData(projectData)
        #expect(reopened.selectedShapeFillKind == .radialGradient)
        #expect(abs(reopened.selectedShapeGradientScale - 0.65) < 0.001)
        reopened.setSelectedShapeFillKind(.linearGradient)
        #expect(reopened.selectedShapeFillKind == .linearGradient)
        #expect(reopened.document.selectedLayer?.shapeContent?.fillGradient?.style == .linear)
    }

    @Test func reflectedAndDiamondShapeGradientsStayEditableAndPersist() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 70),
            ellipse: false
        )

        viewModel.setSelectedShapeFillKind(.reflectedGradient)
        #expect(viewModel.selectedShapeFillKind == .reflectedGradient)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.style == .reflected)
        viewModel.setSelectedShapeGradientScale(0.75)
        #expect(abs(viewModel.selectedShapeGradientScale - 0.75) < 0.001)

        viewModel.setSelectedShapeFillKind(.diamondGradient)
        #expect(viewModel.selectedShapeFillKind == .diamondGradient)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient?.style == .diamond)

        let projectData = try viewModel.projectData()
        let reopened = makeViewModel()
        try reopened.loadProjectData(projectData)
        #expect(reopened.selectedShapeFillKind == .diamondGradient)
        #expect(reopened.document.selectedLayer?.shapeContent?.fillGradient?.style == .diamond)
        #expect(abs(reopened.selectedShapeGradientScale - 0.75) < 0.001)
    }

    @Test func gradientEndpointHandleColorsUseActualStopsAndTrackReverse() {
        var gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(
                position: 0,
                color: NSColor(deviceRed: 0.9, green: 0.1, blue: 0.2, alpha: 1)
            ),
            ImageEditorGradientColorStop(
                position: 0.4,
                color: NSColor(deviceRed: 0.2, green: 0.8, blue: 0.3, alpha: 1)
            ),
            ImageEditorGradientColorStop(
                position: 1,
                color: NSColor(deviceRed: 0.1, green: 0.3, blue: 0.95, alpha: 1)
            )
        ])
        let normalStart = ImageEditorShapeGradientGeometry.displayedEndpointColor(
            gradient: gradient,
            handle: .start
        )
        let normalEnd = ImageEditorShapeGradientGeometry.displayedEndpointColor(
            gradient: gradient,
            handle: .end
        )
        #expect(abs(normalStart.redComponent - 0.9) < 0.001)
        #expect(abs(normalStart.blueComponent - 0.2) < 0.001)
        #expect(abs(normalEnd.redComponent - 0.1) < 0.001)
        #expect(abs(normalEnd.blueComponent - 0.95) < 0.001)

        gradient.reverse = true
        let reversedStart = ImageEditorShapeGradientGeometry.displayedEndpointColor(
            gradient: gradient,
            handle: .start
        )
        let reversedEnd = ImageEditorShapeGradientGeometry.displayedEndpointColor(
            gradient: gradient,
            handle: .end
        )
        #expect(abs(reversedStart.redComponent - normalEnd.redComponent) < 0.001)
        #expect(abs(reversedStart.blueComponent - normalEnd.blueComponent) < 0.001)
        #expect(abs(reversedEnd.redComponent - normalStart.redComponent) < 0.001)
        #expect(abs(reversedEnd.blueComponent - normalStart.blueComponent) < 0.001)
    }

    @Test func radialCanvasGeometryRespectsNonUniformLayerFrames() throws {
        var gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: .systemRed,
            endColor: .systemBlue,
            scale: 0.8
        )
        gradient.style = .radial
        let content = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .clear,
            fillGradient: gradient,
            fillGradientCenter: CGPoint(x: 0.25, y: 0.4),
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0
        )
        let imageSize = CGSize(width: 100, height: 50)
        let layerFrame = CGRect(x: 10, y: 20, width: 200, height: 150)
        let geometry = try #require(
            ImageEditorShapeGradientGeometry.radialCanvasGeometry(
                content: content,
                imageSize: imageSize,
                layerFrame: layerFrame
            )
        )
        let localRadius = hypot(50, 25) * 0.8
        #expect(abs(geometry.center.x - 60) < 0.001)
        #expect(abs(geometry.center.y - 80) < 0.001)
        #expect(abs(geometry.radius.x - (60 + localRadius * 2)) < 0.001)
        #expect(abs(geometry.boundaryRect.width - localRadius * 4) < 0.001)
        #expect(abs(geometry.boundaryRect.height - localRadius * 6) < 0.001)

        let movedCenter = try #require(
            ImageEditorShapeGradientGeometry.updatedRadialContent(
                from: content,
                imageSize: imageSize,
                layerFrame: layerFrame,
                moving: .center,
                to: CGPoint(x: 110, y: 95)
            )
        )
        #expect(abs(movedCenter.fillGradientCenter.x - 0.5) < 0.001)
        #expect(abs(movedCenter.fillGradientCenter.y - 0.5) < 0.001)

        let referenceRadius: CGFloat = hypot(50, 25)
        let resized = try #require(
            ImageEditorShapeGradientGeometry.updatedRadialContent(
                from: content,
                imageSize: imageSize,
                layerFrame: layerFrame,
                moving: .radius,
                to: CGPoint(x: 60 + referenceRadius * 3, y: 80)
            )
        )
        #expect(abs((resized.fillGradient?.scale ?? 0) - 1.5) < 0.001)
        #expect(resized.fillGradient?.style == .radial)
        #expect(resized.fillGradientCenter == content.fillGradientCenter)
    }

    @Test func radialGradientStopsFollowRadiusAndReverseProjection() throws {
        var gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.25, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ], scale: 0.8)
        gradient.style = .radial
        let content = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .clear,
            fillGradient: gradient,
            fillGradientCenter: CGPoint(x: 0.25, y: 0.4),
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0
        )
        let imageSize = CGSize(width: 100, height: 50)
        let layerFrame = CGRect(x: 10, y: 20, width: 200, height: 150)
        let geometry = try #require(
            ImageEditorShapeGradientGeometry.radialCanvasGeometry(
                content: content,
                imageSize: imageSize,
                layerFrame: layerFrame
            )
        )
        let handles = ImageEditorShapeGradientGeometry.canvasStopHandlePoints(
            content: content,
            imageSize: imageSize,
            layerFrame: layerFrame
        )
        let handle = try #require(handles.first)
        #expect(handles.count == 1)
        #expect(handle.index == 1)
        #expect(abs(handle.canvasPoint.x - (geometry.center.x + (geometry.radius.x - geometry.center.x) * 0.25)) < 0.001)
        #expect(abs(handle.canvasPoint.y - geometry.center.y) < 0.001)

        let projected = try #require(
            ImageEditorShapeGradientGeometry.updatedContent(
                from: content,
                imageSize: imageSize,
                layerFrame: layerFrame,
                movingStopAt: 1,
                to: CGPoint(
                    x: geometry.center.x + (geometry.radius.x - geometry.center.x) * 0.7,
                    y: geometry.center.y + 200
                )
            )
        )
        #expect(abs((projected.fillGradient?.shapeColorStops[1].position ?? 0) - 0.7) < 0.001)

        var reversedContent = content
        reversedContent.fillGradient?.reverse = true
        let reversedHandle = try #require(
            ImageEditorShapeGradientGeometry.canvasStopHandlePoints(
                content: reversedContent,
                imageSize: imageSize,
                layerFrame: layerFrame
            ).first
        )
        #expect(abs(reversedHandle.canvasPoint.x - (geometry.center.x + (geometry.radius.x - geometry.center.x) * 0.75)) < 0.001)
        let reversedPosition = try #require(
            ImageEditorShapeGradientGeometry.logicalStopPosition(
                content: reversedContent,
                imageSize: imageSize,
                layerFrame: layerFrame,
                canvasPoint: CGPoint(
                    x: geometry.center.x + (geometry.radius.x - geometry.center.x) * 0.25,
                    y: geometry.center.y - 100
                )
            )
        )
        #expect(abs(reversedPosition - 0.75) < 0.001)
    }

    @Test func radialGradientStopDragAndRemovalEachCommitOneUndoStep() throws {
        var gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.3, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        gradient.style = .radial
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 70),
            ellipse: false,
            fillGradient: gradient
        )
        let originalHistoryCount = viewModel.document.history.count
        let geometry = try #require(viewModel.selectedShapeRadialGradientCanvasGeometry)
        #expect(viewModel.selectedShapeGradientCanvasHandlePoints == nil)
        #expect(viewModel.selectedShapeGradientCanvasStopHandlePoints.count == 1)
        #expect(viewModel.canEditSelectedShapeGradientStops)
        #expect(viewModel.beginEditingSelectedShapeGradientStop(at: 1))
        viewModel.updateSelectedShapeGradientStop(
            to: CGPoint(
                x: geometry.center.x + (geometry.radius.x - geometry.center.x) * 0.7,
                y: geometry.center.y
            )
        )
        viewModel.finishEditingSelectedShapeGradient()
        #expect(abs(viewModel.selectedShapeGradientColorStops[1].position - 0.7) < 0.001)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)
        viewModel.undo()
        #expect(abs(viewModel.selectedShapeGradientColorStops[1].position - 0.3) < 0.001)

        let historyBeforeRemoval = viewModel.document.history.count
        #expect(viewModel.removeSelectedShapeGradientCanvasStop(at: 1) != nil)
        #expect(viewModel.selectedShapeGradientColorStops.count == 2)
        #expect(viewModel.document.history.count == historyBeforeRemoval + 1)
        viewModel.undo()
        #expect(viewModel.selectedShapeGradientColorStops.count == 3)

        let selectedID = try #require(viewModel.document.selectedLayerID)
        let selectedIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == selectedID }
        )
        viewModel.document.layers[selectedIndex].isLocked = true
        let lockedHistoryCount = viewModel.document.history.count
        #expect(!viewModel.canEditSelectedShapeGradientStops)
        #expect(!viewModel.beginEditingSelectedShapeGradientStop(at: 1))
        #expect(
            viewModel.addSelectedShapeGradientStop(
                atCanvasPoint: CGPoint(x: 40, y: 30)
            ) == nil
        )
        #expect(viewModel.document.history.count == lockedHistoryCount)
    }

    @Test func radialGradientAxisAddsInterpolatedStopForNormalAndReversedFills() throws {
        var gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: pureRed,
            endColor: pureBlue
        )
        gradient.style = .radial
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 70),
            ellipse: false,
            fillGradient: gradient
        )
        let geometry = try #require(viewModel.selectedShapeRadialGradientCanvasGeometry)
        let insertionPoint = CGPoint(
            x: geometry.center.x + (geometry.radius.x - geometry.center.x) * 0.25,
            y: geometry.center.y
        )
        let historyBeforeAdd = viewModel.document.history.count
        let insertedIndex = try #require(
            viewModel.addSelectedShapeGradientStop(atCanvasPoint: insertionPoint)
        )
        let inserted = viewModel.selectedShapeGradientColorStops[insertedIndex]
        #expect(insertedIndex == 1)
        #expect(abs(inserted.position - 0.25) < 0.001)
        #expect(abs(inserted.red - 0.75) < 0.001)
        #expect(abs(inserted.green) < 0.001)
        #expect(abs(inserted.blue - 0.25) < 0.001)
        #expect(viewModel.selectedShapeGradientCanvasStopHandlePoints.count == 1)
        #expect(viewModel.document.history.count == historyBeforeAdd + 1)
        viewModel.undo()
        #expect(viewModel.selectedShapeGradientColorStops.count == 2)

        gradient.reverse = true
        let reversedViewModel = makeViewModel()
        reversedViewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 70),
            ellipse: false,
            fillGradient: gradient
        )
        let reversedGeometry = try #require(
            reversedViewModel.selectedShapeRadialGradientCanvasGeometry
        )
        let reversedIndex = try #require(
            reversedViewModel.addSelectedShapeGradientStop(
                atCanvasPoint: CGPoint(
                    x: reversedGeometry.center.x
                        + (reversedGeometry.radius.x - reversedGeometry.center.x) * 0.25,
                    y: reversedGeometry.center.y
                )
            )
        )
        let reversedStop = reversedViewModel.selectedShapeGradientColorStops[reversedIndex]
        #expect(abs(reversedStop.position - 0.75) < 0.001)
        #expect(abs(reversedStop.red - 0.25) < 0.001)
        #expect(abs(reversedStop.blue - 0.75) < 0.001)
    }

    @Test func radialGradientAxisRejectsTheSixteenthStopLimit() throws {
        let stops = (0..<ImageEditorGradientFillContent.maximumColorStopCount).map { index in
            let position = Double(index)
                / Double(ImageEditorGradientFillContent.maximumColorStopCount - 1)
            return ImageEditorGradientColorStop(
                position: position,
                color: NSColor(
                    deviceRed: position,
                    green: 0,
                    blue: 1 - position,
                    alpha: 1
                )
            )
        }
        var gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: stops)
        gradient.style = .radial
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 70),
            ellipse: false,
            fillGradient: gradient
        )
        let historyCount = viewModel.document.history.count
        let geometry = try #require(viewModel.selectedShapeRadialGradientCanvasGeometry)
        #expect(viewModel.selectedShapeGradientColorStops.count == 16)
        #expect(
            viewModel.addSelectedShapeGradientStop(
                atCanvasPoint: CGPoint(
                    x: (geometry.center.x + geometry.radius.x) / 2,
                    y: geometry.center.y
                )
            ) == nil
        )
        #expect(viewModel.selectedShapeGradientColorStops.count == 16)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func radialCanvasHandlesCommitOneUndoAndRejectNoOpOrLockedEdits() throws {
        var gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: .systemRed,
            endColor: .systemBlue
        )
        gradient.style = .radial
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 70),
            ellipse: false,
            fillGradient: gradient
        )
        let originalCenter = try #require(
            viewModel.document.selectedLayer?.shapeContent?.fillGradientCenter
        )
        let centerHistoryCount = viewModel.document.history.count
        let centerGeometry = try #require(viewModel.selectedShapeRadialGradientCanvasGeometry)
        #expect(viewModel.selectedShapeGradientCanvasHandlePoints == nil)
        #expect(viewModel.beginEditingSelectedShapeRadialGradient(handle: .center))
        viewModel.updateSelectedShapeRadialGradient(
            handle: .center,
            to: CGPoint(x: centerGeometry.center.x + 12, y: centerGeometry.center.y + 6)
        )
        viewModel.finishEditingSelectedShapeGradient()
        #expect(viewModel.document.history.count == centerHistoryCount + 1)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradientCenter != originalCenter)
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradientCenter == originalCenter)

        let radiusHistoryCount = viewModel.document.history.count
        let radiusGeometry = try #require(viewModel.selectedShapeRadialGradientCanvasGeometry)
        #expect(viewModel.beginEditingSelectedShapeRadialGradient(handle: .radius))
        viewModel.updateSelectedShapeRadialGradient(
            handle: .radius,
            to: CGPoint(x: radiusGeometry.radius.x + 24, y: radiusGeometry.radius.y)
        )
        viewModel.finishEditingSelectedShapeGradient()
        #expect(viewModel.document.history.count == radiusHistoryCount + 1)
        #expect((viewModel.document.selectedLayer?.shapeContent?.fillGradient?.scale ?? 1) > 1)
        viewModel.undo()
        #expect(abs((viewModel.document.selectedLayer?.shapeContent?.fillGradient?.scale ?? 0) - 1) < 0.001)

        let noOpHistoryCount = viewModel.document.history.count
        let noOpGeometry = try #require(viewModel.selectedShapeRadialGradientCanvasGeometry)
        #expect(viewModel.beginEditingSelectedShapeRadialGradient(handle: .center))
        viewModel.updateSelectedShapeRadialGradient(handle: .center, to: noOpGeometry.center)
        viewModel.finishEditingSelectedShapeGradient()
        #expect(viewModel.document.history.count == noOpHistoryCount)

        let selectedID = try #require(viewModel.document.selectedLayerID)
        let selectedIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == selectedID }
        )
        viewModel.document.layers[selectedIndex].isLocked = true
        #expect(!viewModel.beginEditingSelectedShapeRadialGradient(handle: .radius))
        #expect(viewModel.document.history.count == noOpHistoryCount)
    }

    @Test func gradientAppearanceIsUndoablePersistentAndCanReturnToSolid() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 90, y: 60),
            ellipse: false
        )
        let gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: .systemOrange,
            endColor: .systemPurple,
            angle: 35,
            scale: 1.4
        )
        let historyCount = viewModel.document.history.count

        viewModel.updateSelectedShapeProperties(fillGradient: gradient, fillOpacity: 0.65)
        let edited = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(edited.fillGradient == gradient)
        #expect(edited.fillOpacity == 0.65)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient == nil)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradient == gradient)

        let projectData = try viewModel.projectData()
        let reopened = makeViewModel()
        try reopened.loadProjectData(projectData)
        #expect(reopened.document.selectedLayer?.shapeContent?.fillGradient == gradient)
        #expect(reopened.document.selectedLayer?.shapeContent?.fillOpacity == 0.65)

        reopened.setSelectedShapeFillKind(.solid)
        #expect(reopened.document.selectedLayer?.shapeContent?.fillGradient == nil)
        reopened.undo()
        #expect(reopened.document.selectedLayer?.shapeContent?.fillGradient == gradient)
    }

    @Test func multiStopGradientRendersMiddleColorAtItsPosition() throws {
        let gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(position: 0, color: pureRed),
            ImageEditorGradientColorStop(position: 0.5, color: pureGreen),
            ImageEditorGradientColorStop(position: 1, color: pureBlue)
        ])
        let image = gradient.renderedImage(size: CGSize(width: 101, height: 9))
        let left = try #require(image.color(at: CGPoint(x: 0, y: 4)))
        let middle = try #require(image.color(at: CGPoint(x: 50, y: 4)))
        let right = try #require(image.color(at: CGPoint(x: 100, y: 4)))

        #expect(left.redComponent > 0.9)
        #expect(middle.greenComponent > middle.redComponent + 0.6)
        #expect(middle.greenComponent > middle.blueComponent + 0.6)
        #expect(right.blueComponent > 0.9)

        var reversedGradient = gradient
        reversedGradient.reverse = true
        let reversed = reversedGradient.renderedImage(size: CGSize(width: 101, height: 9))
        let reversedLeft = try #require(reversed.color(at: CGPoint(x: 0, y: 4)))
        let reversedMiddle = try #require(reversed.color(at: CGPoint(x: 50, y: 4)))
        let reversedRight = try #require(reversed.color(at: CGPoint(x: 100, y: 4)))
        #expect(reversedLeft.blueComponent > 0.9)
        #expect(reversedMiddle.greenComponent > reversedMiddle.redComponent + 0.6)
        #expect(reversedRight.redComponent > 0.9)
    }

    @Test func gradientStopsCanBeAddedEditedRemovedUndoneAndPersisted() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 100, y: 60),
            ellipse: false,
            fillGradient: .shapeLinear(startColor: .systemRed, endColor: .systemBlue)
        )
        let historyCount = viewModel.document.history.count
        let addedIndex = try #require(viewModel.addSelectedShapeGradientStop())
        #expect(addedIndex == 1)
        #expect(viewModel.selectedShapeGradientColorStops.count == 3)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.setSelectedShapeGradientStopColor(at: addedIndex, color: .systemGreen)
        viewModel.setSelectedShapeGradientStopPosition(at: addedIndex, position: 0.4)
        let edited = viewModel.selectedShapeGradientColorStops
        #expect(abs(edited[1].position - 0.4) < 0.001)
        let editedColor = try #require(edited[1].color.usingColorSpace(.deviceRGB))
        let expectedColor = try #require(NSColor.systemGreen.usingColorSpace(.deviceRGB))
        #expect(abs(editedColor.redComponent - expectedColor.redComponent) < 0.02)
        #expect(abs(editedColor.greenComponent - expectedColor.greenComponent) < 0.02)
        #expect(abs(editedColor.blueComponent - expectedColor.blueComponent) < 0.02)

        let projectData = try viewModel.projectData()
        let reopened = makeViewModel()
        try reopened.loadProjectData(projectData)
        #expect(reopened.selectedShapeGradientColorStops == edited)

        let removedIndex = try #require(reopened.removeSelectedShapeGradientStop(at: 1))
        #expect(removedIndex == 1)
        #expect(reopened.selectedShapeGradientColorStops.count == 2)
        reopened.undo()
        #expect(reopened.selectedShapeGradientColorStops == edited)
    }

    @Test func legacyTwoColorGradientDecodesIntoEditableEndpointStops() throws {
        let data = Data(
            """
            {
              "preset": "custom",
              "style": "linear",
              "reverse": false,
              "angle": 25,
              "scale": 1,
              "startRed": 1,
              "startGreen": 0,
              "startBlue": 0,
              "endRed": 0,
              "endGreen": 0,
              "endBlue": 1
            }
            """.utf8
        )
        let gradient = try JSONDecoder().decode(ImageEditorGradientFillContent.self, from: data)
        let stops = gradient.shapeColorStops
        #expect(stops.count == 2)
        #expect(stops[0].position == 0)
        #expect(stops[0].red == 1)
        #expect(stops[1].position == 1)
        #expect(stops[1].blue == 1)
    }

    @Test func gradientHandlesKeepOppositeEndpointFixedAndCommitOneUndoStep() throws {
        let imageSize = CGSize(width: 100, height: 50)
        let layerFrame = CGRect(x: 10, y: 20, width: 200, height: 100)
        let original = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .clear,
            fillGradient: .shapeLinear(startColor: .systemRed, endColor: .systemBlue),
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0
        )
        let originalPoints = try #require(
            ImageEditorShapeGradientGeometry.canvasHandlePoints(
                content: original,
                imageSize: imageSize,
                layerFrame: layerFrame
            )
        )
        #expect(abs(originalPoints.start.x - 10) < 0.001)
        #expect(abs(originalPoints.end.x - 210) < 0.001)

        let updated = try #require(
            ImageEditorShapeGradientGeometry.updatedContent(
                from: original,
                imageSize: imageSize,
                layerFrame: layerFrame,
                moving: .end,
                to: CGPoint(x: 310, y: 70),
                snappingAngle: false
            )
        )
        let updatedPoints = try #require(
            ImageEditorShapeGradientGeometry.canvasHandlePoints(
                content: updated,
                imageSize: imageSize,
                layerFrame: layerFrame
            )
        )
        #expect(abs(updatedPoints.start.x - originalPoints.start.x) < 0.001)
        #expect(abs(updatedPoints.end.x - 310) < 0.001)
        #expect(abs(updated.fillGradientCenter.x - 0.75) < 0.001)
        #expect(abs((updated.fillGradient?.scale ?? 0) - 1.5) < 0.001)

        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 90, y: 60),
            ellipse: false,
            fillGradient: .shapeLinear(startColor: .systemRed, endColor: .systemBlue)
        )
        let historyCount = viewModel.document.history.count
        viewModel.document.selectedLayerIDs = []
        #expect(viewModel.selectedShapeGradientCanvasHandlePoints != nil)
        #expect(viewModel.beginEditingSelectedShapeGradient(handle: .end))
        let points = try #require(viewModel.selectedShapeGradientCanvasHandlePoints)
        viewModel.updateSelectedShapeGradient(
            handle: .end,
            to: CGPoint(x: points.end.x + 20, y: points.end.y),
            snappingAngle: false
        )
        viewModel.finishEditingSelectedShapeGradient()
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradientCenter.x != 0.5)
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.fillGradientCenter == CGPoint(x: 0.5, y: 0.5))
    }

    @Test func canvasGradientStopProjectsOntoAxisAndCommitsOneUndoStep() throws {
        let gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.25, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        let content = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .clear,
            fillGradient: gradient,
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0
        )
        let imageSize = CGSize(width: 100, height: 50)
        let layerFrame = CGRect(x: 10, y: 20, width: 200, height: 100)
        let handles = ImageEditorShapeGradientGeometry.canvasStopHandlePoints(
            content: content,
            imageSize: imageSize,
            layerFrame: layerFrame
        )
        #expect(handles.count == 1)
        #expect(handles[0].index == 1)
        #expect(abs(handles[0].canvasPoint.x - 60) < 0.001)
        #expect(abs(handles[0].canvasPoint.y - 70) < 0.001)

        let projected = try #require(
            ImageEditorShapeGradientGeometry.updatedContent(
                from: content,
                imageSize: imageSize,
                layerFrame: layerFrame,
                movingStopAt: 1,
                to: CGPoint(x: 160, y: 500)
            )
        )
        #expect(abs((projected.fillGradient?.shapeColorStops[1].position ?? 0) - 0.75) < 0.001)
        let projectedAxis = try #require(
            ImageEditorShapeGradientGeometry.canvasHandlePoints(
                content: projected,
                imageSize: imageSize,
                layerFrame: layerFrame
            )
        )
        #expect(abs(projectedAxis.start.x - 10) < 0.001)
        #expect(abs(projectedAxis.end.x - 210) < 0.001)

        var reversedContent = content
        reversedContent.fillGradient?.reverse = true
        let reversedHandles = ImageEditorShapeGradientGeometry.canvasStopHandlePoints(
            content: reversedContent,
            imageSize: imageSize,
            layerFrame: layerFrame
        )
        #expect(abs((reversedHandles.first?.canvasPoint.x ?? 0) - 160) < 0.001)
        let reversedMoved = try #require(
            ImageEditorShapeGradientGeometry.updatedContent(
                from: reversedContent,
                imageSize: imageSize,
                layerFrame: layerFrame,
                movingStopAt: 1,
                to: CGPoint(x: 60, y: 70)
            )
        )
        #expect(abs((reversedMoved.fillGradient?.shapeColorStops[1].position ?? 0) - 0.75) < 0.001)

        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 60),
            ellipse: false,
            fillGradient: gradient
        )
        let historyCount = viewModel.document.history.count
        let originalPosition = viewModel.selectedShapeGradientColorStops[1].position
        let canvasStops = viewModel.selectedShapeGradientCanvasStopHandlePoints
        let axis = try #require(viewModel.selectedShapeGradientCanvasHandlePoints)
        #expect(viewModel.beginEditingSelectedShapeGradientStop(at: 1))
        viewModel.updateSelectedShapeGradientStop(
            to: CGPoint(
                x: axis.start.x + (axis.end.x - axis.start.x) * 0.7,
                y: axis.start.y + (axis.end.y - axis.start.y) * 0.7
            )
        )
        viewModel.finishEditingSelectedShapeGradient()
        #expect(canvasStops.count == 1)
        #expect(abs(viewModel.selectedShapeGradientColorStops[1].position - 0.7) < 0.001)
        #expect(viewModel.document.history.count == historyCount + 1)
        viewModel.undo()
        #expect(abs(viewModel.selectedShapeGradientColorStops[1].position - originalPosition) < 0.001)

        let noOpHistoryCount = viewModel.document.history.count
        let noOpPoint = try #require(viewModel.selectedShapeGradientCanvasStopHandlePoints.first)
        #expect(viewModel.beginEditingSelectedShapeGradientStop(at: noOpPoint.index))
        viewModel.updateSelectedShapeGradientStop(to: noOpPoint.canvasPoint)
        viewModel.finishEditingSelectedShapeGradient()
        #expect(viewModel.document.history.count == noOpHistoryCount)
    }

    @Test func canvasGradientMidpointsProjectPerSegmentAndRespectReverse() throws {
        let gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(
                position: 0,
                color: .systemRed,
                midpoint: 0.25
            ),
            ImageEditorGradientColorStop(
                position: 0.5,
                color: .systemGreen,
                midpoint: 0.8
            ),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        let content = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .clear,
            fillGradient: gradient,
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0
        )
        let imageSize = CGSize(width: 100, height: 50)
        let layerFrame = CGRect(x: 10, y: 20, width: 200, height: 100)
        let points = ImageEditorShapeGradientGeometry.canvasMidpointHandlePoints(
            content: content,
            imageSize: imageSize,
            layerFrame: layerFrame
        )
        #expect(points.count == 2)
        #expect(points.map(\.lowerStopIndex) == [0, 1])
        #expect(abs(points[0].canvasPoint.x - 35) < 0.001)
        #expect(abs(points[1].canvasPoint.x - 190) < 0.001)

        let moved = try #require(
            ImageEditorShapeGradientGeometry.updatedContent(
                from: content,
                imageSize: imageSize,
                layerFrame: layerFrame,
                movingMidpointAfter: 0,
                to: CGPoint(x: 90, y: 500)
            )
        )
        #expect(abs((moved.fillGradient?.shapeColorStops[0].midpoint ?? 0) - 0.8) < 0.001)

        var reversedContent = content
        reversedContent.fillGradient?.reverse = true
        let reversedPoints = ImageEditorShapeGradientGeometry.canvasMidpointHandlePoints(
            content: reversedContent,
            imageSize: imageSize,
            layerFrame: layerFrame
        )
        #expect(abs(reversedPoints[0].canvasPoint.x - 185) < 0.001)
        #expect(abs(reversedPoints[1].canvasPoint.x - 30) < 0.001)
        let reversedMoved = try #require(
            ImageEditorShapeGradientGeometry.updatedContent(
                from: reversedContent,
                imageSize: imageSize,
                layerFrame: layerFrame,
                movingMidpointAfter: 0,
                to: CGPoint(x: 130, y: -500)
            )
        )
        #expect(
            abs((reversedMoved.fillGradient?.shapeColorStops[0].midpoint ?? 0) - 0.8)
                < 0.001
        )

        var radialContent = content
        radialContent.fillGradient?.style = .radial
        #expect(
            ImageEditorShapeGradientGeometry.canvasMidpointHandlePoints(
                content: radialContent,
                imageSize: imageSize,
                layerFrame: layerFrame
            ).count == 2
        )
    }

    @Test func canvasGradientMidpointDragCommitsOneUndoAndNoOpPreservesHistory() throws {
        let gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(
                position: 0,
                color: .systemRed,
                midpoint: 0.25
            ),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 60),
            ellipse: false,
            fillGradient: gradient
        )
        let historyCount = viewModel.document.history.count
        let axis = try #require(viewModel.selectedShapeGradientCanvasHandlePoints)
        #expect(viewModel.selectedShapeGradientCanvasMidpointHandlePoints.count == 1)
        #expect(viewModel.beginEditingSelectedShapeGradientMidpoint(after: 0))
        viewModel.updateSelectedShapeGradientMidpoint(
            to: CGPoint(
                x: axis.start.x + (axis.end.x - axis.start.x) * 0.75,
                y: axis.start.y + (axis.end.y - axis.start.y) * 0.75
            )
        )
        viewModel.finishEditingSelectedShapeGradient()
        #expect(abs(viewModel.selectedShapeGradientColorStops[0].midpoint - 0.75) < 0.001)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.text("imageEditor.history.shapeGradientMidpoint")
        )
        viewModel.undo()
        #expect(abs(viewModel.selectedShapeGradientColorStops[0].midpoint - 0.25) < 0.001)
        viewModel.redo()
        #expect(abs(viewModel.selectedShapeGradientColorStops[0].midpoint - 0.75) < 0.001)

        let noOpHistoryCount = viewModel.document.history.count
        let currentPoint = try #require(
            viewModel.selectedShapeGradientCanvasMidpointHandlePoints.first?.canvasPoint
        )
        #expect(viewModel.beginEditingSelectedShapeGradientMidpoint(after: 0))
        viewModel.updateSelectedShapeGradientMidpoint(to: currentPoint)
        viewModel.finishEditingSelectedShapeGradient()
        #expect(viewModel.document.history.count == noOpHistoryCount)

        viewModel.setSelectedShapeGradientStopMidpoint(after: 0, midpoint: 0.4)
        #expect(abs(viewModel.selectedShapeGradientColorStops[0].midpoint - 0.4) < 0.001)
        let propertyHistoryCount = viewModel.document.history.count
        viewModel.setSelectedShapeGradientStopMidpoint(after: 0, midpoint: 0.4)
        #expect(viewModel.document.history.count == propertyHistoryCount)

        viewModel.undo()
        #expect(abs(viewModel.selectedShapeGradientColorStops[0].midpoint - 0.75) < 0.001)
        #expect(viewModel.canRedo)
        let redoPreservingHistoryCount = viewModel.document.history.count
        let redoPreservingPoint = try #require(
            viewModel.selectedShapeGradientCanvasMidpointHandlePoints.first?.canvasPoint
        )
        #expect(viewModel.beginEditingSelectedShapeGradientMidpoint(after: 0))
        viewModel.updateSelectedShapeGradientMidpoint(to: redoPreservingPoint)
        viewModel.finishEditingSelectedShapeGradient()
        #expect(viewModel.document.history.count == redoPreservingHistoryCount)
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(abs(viewModel.selectedShapeGradientColorStops[0].midpoint - 0.4) < 0.001)
    }

    @Test func propertyTrackStopDragCommitsOnceAndRoundTripPreservesRedo() throws {
        var gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.5, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        gradient.style = .reflected
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 60),
            ellipse: false,
            fillGradient: gradient
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.canEditSelectedShapeGradientStops)
        #expect(viewModel.beginEditingSelectedShapeGradientStop(at: 1))
        viewModel.updateSelectedShapeGradientStop(toLogicalPosition: 0.62)
        viewModel.updateSelectedShapeGradientStop(toLogicalPosition: 0.7)
        viewModel.finishEditingSelectedShapeGradient()

        #expect(abs(viewModel.selectedShapeGradientColorStops[1].position - 0.7) < 0.001)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(!viewModel.canRedo)

        viewModel.undo()
        #expect(abs(viewModel.selectedShapeGradientColorStops[1].position - 0.5) < 0.001)
        #expect(viewModel.canRedo)
        let redoPreservingHistoryCount = viewModel.document.history.count
        let redoPreservingUndoCount = viewModel.undoStack.count

        #expect(viewModel.beginEditingSelectedShapeGradientStop(at: 1))
        viewModel.updateSelectedShapeGradientStop(toLogicalPosition: 0.8)
        viewModel.updateSelectedShapeGradientStop(toLogicalPosition: 0.5)
        viewModel.finishEditingSelectedShapeGradient()

        #expect(viewModel.document.history.count == redoPreservingHistoryCount)
        #expect(viewModel.undoStack.count == redoPreservingUndoCount)
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(abs(viewModel.selectedShapeGradientColorStops[1].position - 0.7) < 0.001)
    }

    @Test func propertyTrackMidpointDragSupportsDiamondGradientAsOneTransaction() throws {
        var gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(
                position: 0,
                color: .systemRed,
                midpoint: 0.25
            ),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        gradient.style = .diamond
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 60),
            ellipse: false,
            fillGradient: gradient
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.canEditSelectedShapeGradientStops)
        #expect(viewModel.beginEditingSelectedShapeGradientMidpoint(after: 0))
        viewModel.updateSelectedShapeGradientMidpoint(toLogicalMidpoint: 0.4)
        viewModel.updateSelectedShapeGradientMidpoint(toLogicalMidpoint: 0.8)
        viewModel.finishEditingSelectedShapeGradient()

        #expect(abs(viewModel.selectedShapeGradientColorStops[0].midpoint - 0.8) < 0.001)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        viewModel.undo()
        #expect(abs(viewModel.selectedShapeGradientColorStops[0].midpoint - 0.25) < 0.001)
        viewModel.redo()
        #expect(abs(viewModel.selectedShapeGradientColorStops[0].midpoint - 0.8) < 0.001)
    }

    @Test func propertyTrackInsertionUsesExactPositionAndCurrentGradientCurve() throws {
        let gradient = ImageEditorGradientFillContent.shapeLinear(colorStops: [
            ImageEditorGradientColorStop(
                position: 0,
                red: 0,
                green: 0,
                blue: 0,
                alpha: 0.2,
                midpoint: 0.3
            ),
            ImageEditorGradientColorStop(
                position: 1,
                red: 1,
                green: 1,
                blue: 1,
                alpha: 0.8
            )
        ])
        let expectedColor = try #require(
            gradient.shapeColor(at: 0.4).usingColorSpace(.deviceRGB)
        )
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 60),
            ellipse: false,
            fillGradient: gradient
        )
        let historyCount = viewModel.document.history.count

        let insertedIndex = try #require(viewModel.addSelectedShapeGradientStop(at: 0.4))
        let inserted = viewModel.selectedShapeGradientColorStops[insertedIndex]
        #expect(abs(inserted.position - 0.4) < 0.000_001)
        #expect(abs(inserted.red - Double(expectedColor.redComponent)) < 0.000_001)
        #expect(abs(inserted.green - Double(expectedColor.greenComponent)) < 0.000_001)
        #expect(abs(inserted.blue - Double(expectedColor.blueComponent)) < 0.000_001)
        #expect(abs(inserted.alpha - Double(expectedColor.alphaComponent)) < 0.000_001)
        #expect(viewModel.document.history.count == historyCount + 1)
    }

    @Test func lockedShapeRejectsCanvasGradientStopDrag() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 60),
            ellipse: false,
            fillGradient: .shapeLinear(colorStops: [
                ImageEditorGradientColorStop(position: 0, color: .systemRed),
                ImageEditorGradientColorStop(position: 0.5, color: .systemGreen),
                ImageEditorGradientColorStop(position: 1, color: .systemBlue)
            ])
        )
        let selectedID = try #require(viewModel.document.selectedLayerID)
        let index = try #require(viewModel.document.layers.firstIndex { $0.id == selectedID })
        viewModel.document.layers[index].isLocked = true
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.beginEditingSelectedShapeGradientStop(at: 1))
        #expect(!viewModel.beginEditingSelectedShapeGradientMidpoint(after: 0))
        #expect(viewModel.addSelectedShapeGradientStop(atCanvasPoint: CGPoint(x: 40, y: 30)) == nil)
        #expect(viewModel.removeSelectedShapeGradientCanvasStop(at: 1) == nil)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.selectedShapeGradientColorStops[1].position == 0.5)
    }

    @Test func canvasGradientAxisAddsAndDeletesSelectedStopWithOneUndoStep() throws {
        let gradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: pureRed,
            endColor: pureBlue
        )
        let content = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .clear,
            fillGradient: gradient,
            fillOpacity: 1,
            strokeColor: .clear,
            strokeWidth: 1,
            strokeOpacity: 0
        )
        let imageSize = CGSize(width: 100, height: 50)
        let layerFrame = CGRect(x: 10, y: 20, width: 200, height: 100)
        var reversedContent = content
        reversedContent.fillGradient?.reverse = true
        let reversedPosition = try #require(
            ImageEditorShapeGradientGeometry.logicalStopPosition(
                content: reversedContent,
                imageSize: imageSize,
                layerFrame: layerFrame,
                canvasPoint: CGPoint(x: 50, y: 70)
            )
        )
        #expect(abs(reversedPosition - 0.8) < 0.001)

        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 60),
            ellipse: false,
            fillGradient: gradient
        )
        let axis = try #require(viewModel.selectedShapeGradientCanvasHandlePoints)
        let insertionPoint = CGPoint(
            x: axis.start.x + (axis.end.x - axis.start.x) * 0.3,
            y: axis.start.y + (axis.end.y - axis.start.y) * 0.3
        )
        let historyBeforeAdd = viewModel.document.history.count
        let insertedIndex = try #require(
            viewModel.addSelectedShapeGradientStop(atCanvasPoint: insertionPoint)
        )
        #expect(insertedIndex == 1)
        #expect(viewModel.selectedShapeGradientColorStops.count == 3)
        #expect(abs(viewModel.selectedShapeGradientColorStops[insertedIndex].position - 0.3) < 0.001)
        let insertedColor = viewModel.selectedShapeGradientColorStops[insertedIndex].vector
        #expect(abs(insertedColor.x - 0.7) < 0.001)
        #expect(abs(insertedColor.y) < 0.001)
        #expect(abs(insertedColor.z - 0.3) < 0.001)
        #expect(viewModel.document.history.count == historyBeforeAdd + 1)
        viewModel.undo()
        #expect(viewModel.selectedShapeGradientColorStops.count == 2)

        let reinsertedIndex = try #require(
            viewModel.addSelectedShapeGradientStop(atCanvasPoint: insertionPoint)
        )
        let historyBeforeRemove = viewModel.document.history.count
        #expect(ImageEditorGradientStopDeleteAvailabilityPolicy.resolve(
            selectedIndex: reinsertedIndex,
            stopCount: viewModel.selectedShapeGradientColorStops.count,
            isInteractionAvailable: true
        ))
        #expect(!ImageEditorGradientStopDeleteAvailabilityPolicy.resolve(
            selectedIndex: 0,
            stopCount: viewModel.selectedShapeGradientColorStops.count,
            isInteractionAvailable: true
        ))
        #expect(!ImageEditorGradientStopDeleteAvailabilityPolicy.resolve(
            selectedIndex: viewModel.selectedShapeGradientColorStops.count - 1,
            stopCount: viewModel.selectedShapeGradientColorStops.count,
            isInteractionAvailable: true
        ))
        #expect(viewModel.removeSelectedShapeGradientCanvasStop(at: reinsertedIndex) != nil)
        #expect(viewModel.selectedShapeGradientColorStops.count == 2)
        #expect(viewModel.document.history.count == historyBeforeRemove + 1)
        viewModel.undo()
        #expect(viewModel.selectedShapeGradientColorStops.count == 3)
    }

    @Test func fillAndStrokeRenderAsIndependentEditableProperties() throws {
        let image = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .systemRed,
            fillOpacity: 0.6,
            strokeColor: .systemBlue,
            strokeWidth: 6,
            strokeOpacity: 0.8
        ).renderedImage(size: CGSize(width: 40, height: 30))

        let center = try #require(image.color(at: CGPoint(x: 20, y: 15)))
        let edge = try #require(image.color(at: CGPoint(x: 1, y: 15)))
        #expect(center.redComponent > center.blueComponent + 0.5)
        #expect(abs(center.alphaComponent - 0.6) < 0.08)
        #expect(edge.blueComponent > edge.redComponent + 0.5)
        #expect(abs(edge.alphaComponent - 0.8) < 0.08)
    }

    @Test func dashOffsetChangesRenderedPhaseAndNormalizesInvalidValues() throws {
        let base = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: .clear,
            fillOpacity: 0,
            strokeColor: .black,
            strokeWidth: 4,
            strokeOpacity: 1,
            strokeDashPattern: [8, 4]
        )
        var shifted = base
        shifted.strokeDashOffset = 5.5

        #expect(
            base.renderedImage(size: CGSize(width: 80, height: 50)).tiffRepresentation
                != shifted.renderedImage(size: CGSize(width: 80, height: 50)).tiffRepresentation
        )
        var invalid = shifted
        invalid.strokeDashOffset = CGFloat.infinity
        #expect(invalid.normalized(size: CGSize(width: 80, height: 50)).strokeDashOffset == 0)
        invalid.strokeDashOffset = 4_096
        #expect(
            invalid.normalized(size: CGSize(width: 80, height: 50)).strokeDashOffset
                == ImageEditorShapeContent.maximumStrokeDashOffset
        )
    }

    @Test func openPathStrokeDecorationsRenderPersistAndEditAtomically() throws {
        let size = CGSize(width: 120, height: 80)
        let base = ImageEditorShapeContent(
            kind: .path,
            fillColor: .clear,
            fillOpacity: 0,
            strokeColor: .black,
            strokeWidth: 4,
            strokeOpacity: 1,
            pathAnchors: [
                ImageEditorPathAnchor(point: CGPoint(x: 30, y: 40)),
                ImageEditorPathAnchor(point: CGPoint(x: 90, y: 40))
            ],
            isPathClosed: false
        )
        let undecorated = base.renderedImage(size: size).qingtuPNGData()
        for decoration in ImageEditorStrokeDecoration.allCases where decoration != .none {
            var decorated = base
            decorated.strokeStartDecoration = decoration
            decorated.strokeEndDecoration = decoration
            #expect(decorated.renderedImage(size: size).qingtuPNGData() != undecorated)
            let restored = try JSONDecoder().decode(
                ImageEditorProjectShapeContent.self,
                from: JSONEncoder().encode(ImageEditorProjectShapeContent(content: decorated))
            ).content
            #expect(restored.strokeStartDecoration == decoration)
            #expect(restored.strokeEndDecoration == decoration)
        }

        let viewModel = makeViewModel()
        viewModel.addPenPoint(CGPoint(x: 20, y: 30))
        viewModel.addPenPoint(CGPoint(x: 90, y: 50))
        viewModel.finishPenPath(closed: false)
        #expect(viewModel.selectedShapeSupportsStrokeDecorations)
        let historyCount = viewModel.document.history.count
        viewModel.updateSelectedShapeProperties(
            strokeStartDecoration: .filledCircle,
            strokeEndDecoration: .openArrow
        )
        #expect(viewModel.selectedShapeStrokeStartDecoration == .filledCircle)
        #expect(viewModel.selectedShapeStrokeEndDecoration == .openArrow)
        #expect(viewModel.document.history.count == historyCount + 1)
        viewModel.updateSelectedShapeProperties(
            strokeStartDecoration: .filledCircle,
            strokeEndDecoration: .openArrow
        )
        #expect(viewModel.document.history.count == historyCount + 1)
        viewModel.undo()
        #expect(viewModel.selectedShapeStrokeStartDecoration == .none)
        #expect(viewModel.selectedShapeStrokeEndDecoration == .none)
        viewModel.redo()
        #expect(viewModel.selectedShapeStrokeStartDecoration == .filledCircle)
        #expect(viewModel.selectedShapeStrokeEndDecoration == .openArrow)
    }

    @Test func closedPathsIgnoreStrokeDecorationsAndFigmaCapsMapCompletely() throws {
        let size = CGSize(width: 100, height: 80)
        let base = ImageEditorShapeContent(
            kind: .path,
            fillColor: .clear,
            fillOpacity: 0,
            strokeColor: .black,
            strokeWidth: 4,
            strokeOpacity: 1,
            pathAnchors: [
                ImageEditorPathAnchor(point: CGPoint(x: 20, y: 20)),
                ImageEditorPathAnchor(point: CGPoint(x: 80, y: 20)),
                ImageEditorPathAnchor(point: CGPoint(x: 50, y: 60))
            ],
            isPathClosed: true
        )
        var decorated = base
        decorated.strokeStartDecoration = .filledDiamond
        decorated.strokeEndDecoration = .filledCircle
        #expect(base.renderedImage(size: size).qingtuPNGData() == decorated.renderedImage(size: size).qingtuPNGData())

        let mappings: [(String, ImageEditorStrokeDecoration)] = [
            ("ARROW_LINES", .openArrow),
            ("ARROW_EQUILATERAL", .filledArrow),
            ("TRIANGLE_FILLED", .filledTriangle),
            ("DIAMOND_FILLED", .filledDiamond),
            ("CIRCLE_FILLED", .filledCircle)
        ]
        for (figmaValue, expected) in mappings {
            #expect(ImageEditorStrokeDecoration(figmaValue: figmaValue) == expected)
        }
        #expect(ImageEditorStrokeDecoration(figmaValue: "ROUND") == .none)
        #expect(ImageEditorStrokeDecoration(figmaValue: "FUTURE") == .none)
    }

    @Test func dashPresetTitlesResolveAndCustomPatternRemainsReadOnly() throws {
        for preset in ImageEditorStrokeDashPreset.allCases {
            #expect(
                preset.title
                    == L10n.text("imageEditor.properties.shapeStrokeDash.\(preset.rawValue)")
            )
        }
        for cap in ImageEditorStrokeCap.allCases {
            #expect(
                cap.title
                    == L10n.text("imageEditor.properties.shapeStrokeCap.\(cap.rawValue)")
            )
        }
        for join in ImageEditorStrokeJoin.allCases {
            #expect(
                join.title
                    == L10n.text("imageEditor.properties.shapeStrokeJoin.\(join.rawValue)")
            )
        }
        for decoration in ImageEditorStrokeDecoration.allCases {
            #expect(
                decoration.title
                    == L10n.text("imageEditor.properties.shapeStrokeDecoration.\(decoration.rawValue)")
            )
        }

        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 70, y: 50),
            ellipse: false
        )
        viewModel.updateSelectedShapeProperties(strokeDashPattern: [7, 3, 2, 3])
        #expect(viewModel.selectedShapeStrokeDashPreset == .custom)
        let historyCount = viewModel.document.history.count

        viewModel.setSelectedShapeStrokeDashPreset(.custom)

        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeDashPattern == [7, 3, 2, 3])
        #expect(viewModel.document.history.count == historyCount)

        viewModel.setSelectedShapeStrokeDashPreset(.dash)
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeDashPattern == [6, 3])
        #expect(viewModel.document.history.count == historyCount + 1)
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeDashPattern == [7, 3, 2, 3])
    }

    @Test func customDashTextParsesFormatsAndCommitsAsOneUndoableEdit() throws {
        #expect(ImageEditorStrokeDashPatternText.string(from: [6, 3, 2.5, 0.125]) == "6, 3, 2.5, 0.125")
        #expect(ImageEditorStrokeDashPatternText.pattern(from: "6, 3 2.5; 0.125") == [6, 3, 2.5, 0.125])
        #expect(ImageEditorStrokeDashPatternText.pattern(from: "") == [])
        for invalid in ["6", "6, 0", "6, -3", "6, nan", "6, 2049"] {
            #expect(ImageEditorStrokeDashPatternText.pattern(from: invalid) == nil)
        }
        #expect(
            ImageEditorStrokeDashPatternText.pattern(
                from: Array(repeating: "1", count: 17).joined(separator: ",")
            ) == nil
        )

        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 70, y: 50),
            ellipse: false
        )
        let original = viewModel.document.selectedLayer?.shapeContent?.strokeDashPattern
        let historyCount = viewModel.document.history.count
        let parsed = try #require(ImageEditorStrokeDashPatternText.pattern(from: "7, 3, 2, 3"))

        viewModel.setSelectedShapeStrokeDashPattern(parsed)

        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeDashPattern == [7, 3, 2, 3])
        #expect(viewModel.selectedShapeStrokeDashPreset == .custom)
        #expect(viewModel.document.history.count == historyCount + 1)
        viewModel.setSelectedShapeStrokeDashPattern(parsed)
        #expect(viewModel.document.history.count == historyCount + 1)
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.shapeContent?.strokeDashPattern == original)
    }

    @Test func appearanceEditIsOneUndoableProjectPersistentChange() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 70, y: 50),
            ellipse: false
        )
        let original = try #require(viewModel.document.selectedLayer?.shapeContent)
        let historyCount = viewModel.document.history.count

        viewModel.updateSelectedShapeProperties(
            fillColor: .systemRed,
            fillOpacity: 0.55,
            strokeColor: .systemBlue,
            strokeOpacity: 0.75,
            strokeWidth: 7,
            strokePosition: .outside,
            strokeCap: .square,
            strokeJoin: .bevel,
            strokeMiterLimit: 4,
            strokeDashPattern: [12, 4],
            strokeDashOffset: 5.5
        )

        let edited = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(edited.fillColor.isEqual(NSColor.systemRed))
        #expect(edited.fillOpacity == 0.55)
        #expect(edited.strokeColor.isEqual(NSColor.systemBlue))
        #expect(edited.strokeOpacity == 0.75)
        #expect(edited.strokeWidth == 7)
        #expect(edited.strokePosition == .outside)
        #expect(edited.strokeCap == .square)
        #expect(edited.strokeJoin == .bevel)
        #expect(edited.strokeMiterLimit == 4)
        #expect(edited.strokeDashPattern == [12, 4])
        #expect(edited.strokeDashOffset == 5.5)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        let undone = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(undone.fillColor.isEqual(original.fillColor))
        #expect(undone.fillOpacity == original.fillOpacity)
        #expect(undone.strokeColor.isEqual(original.strokeColor))
        #expect(undone.strokeOpacity == original.strokeOpacity)
        #expect(undone.strokeWidth == original.strokeWidth)
        #expect(undone.strokePosition == original.strokePosition)
        #expect(undone.strokeCap == original.strokeCap)
        #expect(undone.strokeJoin == original.strokeJoin)
        #expect(undone.strokeMiterLimit == original.strokeMiterLimit)
        #expect(undone.strokeDashPattern == original.strokeDashPattern)
        #expect(undone.strokeDashOffset == original.strokeDashOffset)
        viewModel.redo()
        let redone = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(redone.fillColor.isEqual(edited.fillColor))
        #expect(redone.fillOpacity == edited.fillOpacity)
        #expect(redone.strokeColor.isEqual(edited.strokeColor))
        #expect(redone.strokeOpacity == edited.strokeOpacity)
        #expect(redone.strokeWidth == edited.strokeWidth)
        #expect(redone.strokePosition == edited.strokePosition)
        #expect(redone.strokeCap == edited.strokeCap)
        #expect(redone.strokeJoin == edited.strokeJoin)
        #expect(redone.strokeMiterLimit == edited.strokeMiterLimit)
        #expect(redone.strokeDashPattern == edited.strokeDashPattern)
        #expect(redone.strokeDashOffset == edited.strokeDashOffset)

        let projectData = try viewModel.projectData()
        let reopened = makeViewModel()
        try reopened.loadProjectData(projectData)
        let restored = try #require(reopened.document.selectedLayer?.shapeContent)
        #expect(colorsApproximatelyEqual(restored.fillColor, edited.fillColor))
        #expect(restored.fillOpacity == edited.fillOpacity)
        #expect(colorsApproximatelyEqual(restored.strokeColor, edited.strokeColor))
        #expect(restored.strokeOpacity == edited.strokeOpacity)
        #expect(restored.strokeWidth == edited.strokeWidth)
        #expect(restored.strokePosition == edited.strokePosition)
        #expect(restored.strokeCap == edited.strokeCap)
        #expect(restored.strokeJoin == edited.strokeJoin)
        #expect(restored.strokeMiterLimit == edited.strokeMiterLimit)
        #expect(restored.strokeDashPattern == edited.strokeDashPattern)
        #expect(restored.strokeDashOffset == edited.strokeDashOffset)
    }

    @Test func subpixelStrokeWidthEditsNormalizeAndPersist() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 70, y: 50),
            ellipse: false
        )

        viewModel.setSelectedShapeStrokeWidth(0.5)
        let edited = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(edited.strokeWidth == 0.5)
        #expect(edited.normalized(size: CGSize(width: 60, height: 40)).strokeWidth == 0.5)

        let projectData = try viewModel.projectData()
        let reopened = makeViewModel()
        try reopened.loadProjectData(projectData)
        #expect(reopened.document.selectedLayer?.shapeContent?.strokeWidth == 0.5)

        reopened.setSelectedShapeStrokeWidth(0.01)
        #expect(
            reopened.document.selectedLayer?.shapeContent?.strokeWidth
                == ImageEditorShapeContent.minimumStrokeWidth
        )
    }

    @Test func opacityEditsClampAtInterfaceBoundariesAndRemainUndoable() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 70, y: 50),
            ellipse: false
        )
        let original = try #require(viewModel.document.selectedLayer?.shapeContent)
        let historyCount = viewModel.document.history.count

        viewModel.updateSelectedShapeProperties(fillOpacity: -0.5, strokeOpacity: 1.5)
        let clamped = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(clamped.fillOpacity == 0)
        #expect(clamped.strokeOpacity == 1)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        let restored = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(restored.fillOpacity == original.fillOpacity)
        #expect(restored.strokeOpacity == original.strokeOpacity)
    }

    @Test func miterLimitBatchEditClampsAndIsOneUndoableChange() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 8, y: 8),
            to: CGPoint(x: 48, y: 38),
            ellipse: false
        )
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.drawShape(
            from: CGPoint(x: 58, y: 18),
            to: CGPoint(x: 108, y: 68),
            ellipse: false
        )
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        viewModel.document.selectedLayerID = secondID
        let historyCount = viewModel.document.history.count

        viewModel.setSelectedShapeStrokeMiterLimit(0.5)

        for id in [firstID, secondID] {
            let content = try #require(viewModel.document.layers.first { $0.id == id }?.shapeContent)
            #expect(content.strokeMiterLimit == ImageEditorShapeContent.minimumStrokeMiterLimit)
        }
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        for id in [firstID, secondID] {
            let content = try #require(viewModel.document.layers.first { $0.id == id }?.shapeContent)
            #expect(content.strokeMiterLimit == ImageEditorShapeContent.defaultStrokeMiterLimit)
        }
        viewModel.redo()
        #expect(viewModel.document.layers.first { $0.id == firstID }?.shapeContent?.strokeMiterLimit == 1)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.shapeContent?.strokeMiterLimit == 1)
    }

    @Test func lockedShapeRejectsAppearanceChanges() throws {
        let viewModel = makeViewModel()
        viewModel.drawShape(
            from: CGPoint(x: 8, y: 8),
            to: CGPoint(x: 48, y: 38),
            ellipse: false
        )
        let selectedID = try #require(viewModel.document.selectedLayerID)
        let selectedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == selectedID })
        let original = try #require(viewModel.document.layers[selectedIndex].shapeContent)
        let historyCount = viewModel.document.history.count
        viewModel.document.layers[selectedIndex].isLocked = true

        viewModel.updateSelectedShapeProperties(fillColor: .systemGreen, strokeWidth: 20)
        viewModel.setSelectedShapeFillKind(.radialGradient)
        viewModel.setSelectedShapeGradientScale(0.5)
        viewModel.setSelectedShapeGradientStopOpacity(at: 0, opacity: 0.25)

        let locked = try #require(viewModel.document.layers[selectedIndex].shapeContent)
        #expect(locked.fillColor.isEqual(original.fillColor))
        #expect(locked.fillGradient == nil)
        #expect(locked.strokeWidth == original.strokeWidth)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func propertiesPanelControlsStayKeyboardNeutral() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot()
                .appendingPathComponent("veilpic/ImageEditorShapeStyleControls.swift"),
            encoding: .utf8
        )
        for identifier in [
            "image-editor-shape-fill-kind",
            "image-editor-shape-fill-color",
            "image-editor-shape-gradient-stops",
            "image-editor-shape-gradient-track",
            "image-editor-shape-gradient-track-midpoint-",
            "image-editor-shape-gradient-stop-add",
            "image-editor-shape-gradient-stop-remove",
            "image-editor-shape-gradient-stop-color",
            "image-editor-shape-gradient-stop-opacity",
            "image-editor-shape-gradient-stop-position",
            "image-editor-shape-gradient-stop-midpoint",
            "image-editor-shape-gradient-dither",
            "image-editor-shape-gradient-angle",
            "image-editor-shape-fill-opacity",
            "image-editor-shape-stroke-color",
            "image-editor-shape-stroke-opacity",
            "image-editor-shape-stroke-width",
            "image-editor-shape-stroke-position",
            "image-editor-shape-stroke-cap",
            "image-editor-shape-stroke-join",
            "image-editor-shape-stroke-miter-limit",
            "image-editor-shape-stroke-dash",
            "image-editor-shape-stroke-dash-pattern",
            "image-editor-shape-stroke-dash-offset"
        ] {
            #expect(source.contains(identifier))
        }
        #expect(source.components(separatedBy: ".focusable(false)").count - 1 >= 10)
        #expect(source.contains("if viewModel.selectedShapeStrokeJoin == .miter"))
        #expect(source.contains("viewModel.setSelectedShapeStrokeMiterLimit(limit)"))
        #expect(source.contains("selectedShapeStrokeDashOffsetBinding"))
        #expect(source.contains("imageEditor.properties.shapeStrokeDashOffsetValue"))
        #expect(source.contains(".disabled(preset == .custom)"))
        #expect(source.contains("ImageEditorStrokeDashPatternText.pattern(from: draft)"))
        #expect(source.contains("onCommit(parsed)"))
        #expect(source.contains("image-editor-shape-stroke-dash-pattern-error"))
        #expect(source.contains("ImageEditorGradientStopTrackGeometry.logicalPosition"))
        #expect(source.contains("ImageEditorGradientStopTrackGeometry.midpoint"))
        #expect(source.contains("SpatialTapGesture("))
        #expect(source.contains("DragGesture("))
        #expect(source.contains("beginEditingSelectedShapeGradientStop"))
        #expect(source.contains("beginEditingSelectedShapeGradientMidpoint"))
        #expect(source.contains("updateSelectedShapeGradientStop(toLogicalPosition:"))
        #expect(source.contains("updateSelectedShapeGradientMidpoint("))
        #expect(source.contains("toLogicalMidpoint:"))
        #expect(source.contains("finishEditingSelectedShapeGradient()"))

        let canvasSource = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(canvasSource.contains("image-editor-shape-gradient-canvas-stop-"))
        #expect(canvasSource.contains("image-editor-shape-gradient-axis"))
        #expect(canvasSource.contains("axisPath.strokedPath"))
        #expect(canvasSource.contains("beginEditingSelectedShapeGradientStop"))
        #expect(canvasSource.contains("viewModel.addSelectedShapeGradientStop("))
        #expect(canvasSource.contains("deleteSelectedShapeGradientStopIfNeeded"))
        #expect(canvasSource.contains("SpatialTapGesture"))
        #expect(canvasSource.contains("!isTextInputActive"))
        #expect(canvasSource.contains("deleteSelectedObject(event)"))
        #expect(canvasSource.contains("activeShapeGradientStopIndex"))
        #expect(canvasSource.contains("activeShapeGradientMidpointIndex"))
        #expect(canvasSource.contains("image-editor-shape-gradient-midpoint-"))
        #expect(canvasSource.contains("beginEditingSelectedShapeGradientMidpoint"))
        #expect(canvasSource.contains("updateSelectedShapeGradientMidpoint"))
        #expect(canvasSource.contains("image-editor-shape-radial-gradient-boundary"))
        #expect(canvasSource.contains("image-editor-shape-radial-gradient-axis"))

        let gradientHandleSource = try String(
            contentsOf: Self.repositoryRoot()
                .appendingPathComponent("veilpic/ImageEditorShapeGradientHandles.swift"),
            encoding: .utf8
        )
        #expect(gradientHandleSource.contains("func addSelectedShapeGradientStop(atCanvasPoint"))
        #expect(gradientHandleSource.contains("func canvasMidpointHandlePoints("))
        #expect(gradientHandleSource.contains("movingMidpointAfter:"))
        #expect(canvasSource.contains("image-editor-shape-radial-gradient-handle-"))
        #expect(canvasSource.contains("radiusPath.strokedPath"))
        #expect(canvasSource.contains("beginEditingSelectedShapeRadialGradient"))
        #expect(
            canvasSource.contains(
                "shapeGradientHandleColor(handle == .center ? .start : .end)"
            )
        )
        #expect(canvasSource.components(separatedBy: "SpatialTapGesture").count - 1 >= 2)
        #expect(
            canvasSource.components(
                separatedBy: "ForEach(viewModel.selectedShapeGradientCanvasStopHandlePoints)"
            ).count - 1 == 2
        )
        #expect(
            canvasSource.components(
                separatedBy: "ForEach(viewModel.selectedShapeGradientCanvasMidpointHandlePoints)"
            ).count - 1 == 2
        )

        #expect(source.contains("image-editor-shape-fill-kind-\\(kind.rawValue)"))
        #expect(ImageEditorShapeFillKind.radialGradient.rawValue == "radialGradient")
        #expect(ImageEditorShapeFillKind.angleGradient.rawValue == "angleGradient")
        #expect(ImageEditorShapeFillKind.reflectedGradient.rawValue == "reflectedGradient")
        #expect(ImageEditorShapeFillKind.diamondGradient.rawValue == "diamondGradient")
        #expect(source.contains("image-editor-shape-gradient-radius"))
        #expect(source.contains("image-editor-shape-gradient-scale"))
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "shape-style.png",
            image: NSImage.transparent(size: CGSize(width: 120, height: 80))
        ) { _ in }
    }

    private var pureRed: NSColor {
        NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1)
    }

    private var pureGreen: NSColor {
        NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    }

    private var pureBlue: NSColor {
        NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
    }

    private func colorsApproximatelyEqual(
        _ lhs: NSColor,
        _ rhs: NSColor,
        tolerance: CGFloat = 0.002
    ) -> Bool {
        guard let lhs = lhs.usingColorSpace(.deviceRGB),
              let rhs = rhs.usingColorSpace(.deviceRGB)
        else { return false }
        return abs(lhs.redComponent - rhs.redComponent) <= tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) <= tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) <= tolerance
            && abs(lhs.alphaComponent - rhs.alphaComponent) <= tolerance
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
