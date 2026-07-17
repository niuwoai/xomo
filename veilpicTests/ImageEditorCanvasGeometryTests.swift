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
