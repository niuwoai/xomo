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
