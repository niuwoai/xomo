//
//  ImageEditorCanvasGeometryTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/10.
//

import CoreGraphics
import Foundation
import Testing
@testable import musepic

struct ImageEditorCanvasGeometryTests {
    @Test
    func transformsPointsAndRectsUsingCanvasDimensionsOnly() throws {
        let canvasSize = CGSize(width: 400, height: 200)
        let viewportSize = CGSize(width: 1_000, height: 600)
        let imageRect = ImageEditorCanvasGeometry.fittedImageRect(
            canvasSize: canvasSize,
            viewportSize: viewportSize,
            zoom: 1,
            canvasOffset: CGSize(width: 20, height: -10)
        )

        assertEqual(imageRect, CGRect(x: 150, y: 105, width: 740, height: 370))

        let imagePoint = try #require(ImageEditorCanvasGeometry.imagePoint(
            from: CGPoint(x: 224, y: 142),
            imageRect: imageRect,
            canvasSize: canvasSize
        ))
        assertEqual(imagePoint, CGPoint(x: 40, y: 20))

        let outsidePoint = ImageEditorCanvasGeometry.unboundedImagePoint(
            from: CGPoint(x: 76, y: 86.5),
            imageRect: imageRect,
            canvasSize: canvasSize
        )
        assertEqual(outsidePoint, CGPoint(x: -40, y: -10))

        let viewRect = ImageEditorCanvasGeometry.viewRect(
            from: CGRect(x: 40, y: 20, width: 120, height: 60),
            imageRect: imageRect,
            canvasSize: canvasSize
        )
        assertEqual(viewRect, CGRect(x: 224, y: 142, width: 222, height: 111))
    }

    @Test
    func navigatorViewportTracksZoomAndPanInsideThumbnail() throws {
        let canvasSize = CGSize(width: 400, height: 200)
        let previewBounds = CGRect(x: 0, y: 0, width: 184, height: 92)
        let fullViewport = ImageEditorCanvasGeometry.navigatorViewportRect(
            canvasSize: canvasSize,
            canvasViewportSize: CGSize(width: 800, height: 600),
            zoom: 1,
            canvasOffset: .zero,
            previewBounds: previewBounds
        )
        let full = try #require(fullViewport)
        assertEqual(full, previewBounds)

        let zoomedViewport = ImageEditorCanvasGeometry.navigatorViewportRect(
            canvasSize: canvasSize,
            canvasViewportSize: CGSize(width: 800, height: 600),
            zoom: 2,
            canvasOffset: CGSize(width: -120, height: 40),
            previewBounds: previewBounds
        )
        let zoomed = try #require(zoomedViewport)
        #expect(zoomed.width < previewBounds.width)
        #expect(zoomed.height < previewBounds.height)
        #expect(zoomed.minX >= previewBounds.minX)
        #expect(zoomed.maxX <= previewBounds.maxX)
        #expect(zoomed.minY >= previewBounds.minY)
        #expect(zoomed.maxY <= previewBounds.maxY)
    }

    @Test
    func visibleCanvasCenterTracksZoomAndPanAndStaysInsideCanvas() {
        let canvasSize = CGSize(width: 400, height: 200)
        let viewportSize = CGSize(width: 1_000, height: 600)

        assertEqual(
            ImageEditorCanvasGeometry.visibleCanvasCenter(
                canvasSize: canvasSize,
                viewportSize: viewportSize,
                zoom: 1,
                canvasOffset: .zero
            ),
            CGPoint(x: 200, y: 100)
        )
        assertEqual(
            ImageEditorCanvasGeometry.visibleCanvasCenter(
                canvasSize: canvasSize,
                viewportSize: viewportSize,
                zoom: 2,
                canvasOffset: CGSize(width: -120, height: 40)
            ),
            CGPoint(x: 232.432_432, y: 89.189_189)
        )
        assertEqual(
            ImageEditorCanvasGeometry.visibleCanvasCenter(
                canvasSize: canvasSize,
                viewportSize: viewportSize,
                zoom: 2,
                canvasOffset: CGSize(width: 10_000, height: -10_000)
            ),
            CGPoint(x: 0, y: 200)
        )
        assertEqual(
            ImageEditorCanvasGeometry.visibleCanvasCenter(
                canvasSize: canvasSize,
                viewportSize: .zero,
                zoom: 2,
                canvasOffset: CGSize(width: 100, height: 100)
            ),
            CGPoint(x: 200, y: 100)
        )
    }

    @Test
    func marchingAntsDashPhaseWrapsAndHandlesNegativeTime() {
        let patternLength = ImageEditorSelectionMarchingAnts.patternLength
        #expect(ImageEditorSelectionMarchingAnts.dashPhase(at: 0) == 0)
        #expect(abs(ImageEditorSelectionMarchingAnts.dashPhase(at: 0.18) - patternLength / 4) < 0.001)
        #expect(abs(ImageEditorSelectionMarchingAnts.dashPhase(at: 0.72)) < 0.001)
        #expect(abs(ImageEditorSelectionMarchingAnts.dashPhase(at: -0.18) - patternLength * 3 / 4) < 0.001)
        #expect(ImageEditorSelectionMarchingAnts.dashPhase(at: .infinity) == 0)
    }

    @Test
    func cropGeometryMovesAndResizesWithinCanvasBounds() {
        let crop = CGRect(x: 20, y: 30, width: 80, height: 60)
        #expect(
            ImageEditorCropGeometry.hitHandle(
                at: CGPoint(x: 21, y: 60),
                in: crop,
                tolerance: 3
            ) == .left
        )
        #expect(
            ImageEditorCropGeometry.hitHandle(
                at: CGPoint(x: 55, y: 55),
                in: crop,
                tolerance: 3
            ) == .move
        )

        let moved = ImageEditorCropGeometry.adjustedFrame(
            from: crop,
            handle: .move,
            delta: CGSize(width: 500, height: -500),
            canvasSize: CGSize(width: 160, height: 120)
        )
        #expect(moved == CGRect(x: 80, y: 0, width: 80, height: 60))

        let resized = ImageEditorCropGeometry.adjustedFrame(
            from: crop,
            handle: .topLeft,
            delta: CGSize(width: -40, height: -50),
            canvasSize: CGSize(width: 160, height: 120)
        )
        #expect(resized == CGRect(x: 0, y: 0, width: 100, height: 90))
        #expect(resized.maxX == crop.maxX)
        #expect(resized.maxY == crop.maxY)

        let minimum = ImageEditorCropGeometry.adjustedFrame(
            from: crop,
            handle: .right,
            delta: CGSize(width: -500, height: 0),
            canvasSize: CGSize(width: 160, height: 120)
        )
        #expect(minimum.width == 4)
        #expect(minimum.maxX == crop.minX + 4)
    }

    @Test
    func cropRuleOfThirdsGuidesDivideThePreviewAndAreWiredToTheCanvas() throws {
        let guides = ImageEditorCropGeometry.ruleOfThirdsSegments(
            in: CGRect(x: 12, y: 18, width: 90, height: 60)
        )

        #expect(guides == [
            ImageEditorCropGuideSegment(
                start: CGPoint(x: 42, y: 18),
                end: CGPoint(x: 42, y: 78)
            ),
            ImageEditorCropGuideSegment(
                start: CGPoint(x: 72, y: 18),
                end: CGPoint(x: 72, y: 78)
            ),
            ImageEditorCropGuideSegment(
                start: CGPoint(x: 12, y: 38),
                end: CGPoint(x: 102, y: 38)
            ),
            ImageEditorCropGuideSegment(
                start: CGPoint(x: 12, y: 58),
                end: CGPoint(x: 102, y: 58)
            )
        ])
        #expect(ImageEditorCropGeometry.ruleOfThirdsSegments(in: .zero).isEmpty)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("ImageEditorCropGeometry.ruleOfThirdsSegments"))
        #expect(source.contains("for segment in cropGuideSegments"))
    }

    @Test
    func cropShieldDimsOnlyTheCanvasAreaOutsideThePreview() throws {
        let canvas = CGRect(x: 10, y: 20, width: 100, height: 80)
        #expect(ImageEditorCropGeometry.shieldRects(
            in: canvas,
            excluding: CGRect(x: 30, y: 35, width: 60, height: 50)
        ) == [
            CGRect(x: 10, y: 20, width: 100, height: 15),
            CGRect(x: 10, y: 85, width: 100, height: 15),
            CGRect(x: 10, y: 35, width: 20, height: 50),
            CGRect(x: 90, y: 35, width: 20, height: 50)
        ])
        #expect(ImageEditorCropGeometry.shieldRects(in: canvas, excluding: canvas).isEmpty)
        #expect(ImageEditorCropGeometry.shieldRects(
            in: canvas,
            excluding: CGRect(x: -200, y: -200, width: 10, height: 10)
        ) == [canvas])

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(source.contains("ImageEditorCropGeometry.shieldRects"))
        #expect(source.contains("for shieldRect in cropShieldRects"))
        #expect(source.contains("Color.black.opacity(0.48)"))
    }

    private func assertEqual(
        _ actual: CGRect,
        _ expected: CGRect,
        accuracy: CGFloat = 0.001
    ) {
        #expect(abs(actual.origin.x - expected.origin.x) < accuracy)
        #expect(abs(actual.origin.y - expected.origin.y) < accuracy)
        #expect(abs(actual.width - expected.width) < accuracy)
        #expect(abs(actual.height - expected.height) < accuracy)
    }

    private func assertEqual(
        _ actual: CGPoint,
        _ expected: CGPoint,
        accuracy: CGFloat = 0.001
    ) {
        #expect(abs(actual.x - expected.x) < accuracy)
        #expect(abs(actual.y - expected.y) < accuracy)
    }
}
