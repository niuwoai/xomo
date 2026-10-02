//
//  ImageEditorSelectionEdgeTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionEdgeTests {
    @Test func rasterEdgesFollowConcavityInsteadOfSelectionBounds() {
        var alpha = [UInt8](repeating: 0, count: 16)
        alpha[1 * 4 + 1] = 255
        alpha[1 * 4 + 2] = 255
        alpha[2 * 4 + 1] = 255
        let selection = ImageEditorSelection.raster(
            mask: ImageEditorSelectionMask(width: 4, height: 4, alpha: alpha),
            bounds: CGRect(x: 1, y: 1, width: 2, height: 2)
        )

        let geometry = ImageEditorSelectionEdgeGeometry.make(
            selection: selection,
            canvasSize: CGSize(width: 4, height: 4)
        )

        #expect(geometry.segments.count == 6)
        #expect(containsSegment(
            geometry,
            from: CGPoint(x: 2, y: 2),
            to: CGPoint(x: 3, y: 2)
        ))
        #expect(!containsSegment(
            geometry,
            from: CGPoint(x: 1, y: 3),
            to: CGPoint(x: 3, y: 3)
        ))
    }

    @Test func rasterEdgesPreserveInteriorHoles() {
        var alpha = [UInt8](repeating: 255, count: 25)
        alpha[2 * 5 + 2] = 0
        let selection = ImageEditorSelection.raster(
            mask: ImageEditorSelectionMask(width: 5, height: 5, alpha: alpha),
            bounds: CGRect(x: 0, y: 0, width: 5, height: 5)
        )

        let geometry = ImageEditorSelectionEdgeGeometry.make(
            selection: selection,
            canvasSize: CGSize(width: 5, height: 5)
        )

        #expect(geometry.segments.count == 8)
        #expect(containsSegment(
            geometry,
            from: CGPoint(x: 2, y: 2),
            to: CGPoint(x: 3, y: 2)
        ))
        #expect(containsSegment(
            geometry,
            from: CGPoint(x: 2, y: 3),
            to: CGPoint(x: 3, y: 3)
        ))
    }

    @Test func invertedRasterEdgesIncludeCanvasAndMaskBoundaries() {
        var alpha = [UInt8](repeating: 0, count: 9)
        alpha[1 * 3 + 1] = 255
        var selection = ImageEditorSelection.raster(
            mask: ImageEditorSelectionMask(width: 3, height: 3, alpha: alpha),
            bounds: CGRect(x: 1, y: 1, width: 1, height: 1)
        )
        selection.isInverted = true

        let geometry = ImageEditorSelectionEdgeGeometry.make(
            selection: selection,
            canvasSize: CGSize(width: 3, height: 3)
        )

        #expect(geometry.segments.count == 8)
        #expect(containsSegment(
            geometry,
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 3, y: 0)
        ))
        #expect(containsSegment(
            geometry,
            from: CGPoint(x: 1, y: 1),
            to: CGPoint(x: 2, y: 1)
        ))
    }

    @Test func invertedVectorEdgesIncludeCanvasAndSelectionBoundaries() {
        var selection = ImageEditorSelection.rectangle(CGRect(x: 2, y: 2, width: 4, height: 3))
        selection.isInverted = true

        let geometry = ImageEditorSelectionEdgeGeometry.make(
            selection: selection,
            canvasSize: CGSize(width: 10, height: 8)
        )

        #expect(geometry.contours.count == 2)
        #expect(geometry.segments.count == 8)
        #expect(containsSegment(
            geometry,
            from: .zero,
            to: CGPoint(x: 10, y: 0)
        ))
        #expect(containsSegment(
            geometry,
            from: CGPoint(x: 2, y: 2),
            to: CGPoint(x: 6, y: 2)
        ))
    }

    @Test func diagonallyTouchingIslandsKeepSeparateClosedContours() {
        let selection = ImageEditorSelection.raster(
            mask: ImageEditorSelectionMask(width: 2, height: 2, alpha: [255, 0, 0, 255]),
            bounds: CGRect(x: 0, y: 0, width: 2, height: 2)
        )

        let geometry = ImageEditorSelectionEdgeGeometry.make(
            selection: selection,
            canvasSize: CGSize(width: 2, height: 2)
        )

        #expect(geometry.contours.count == 2)
        #expect(geometry.segments.count == 8)
        #expect(geometry.contours.allSatisfy { $0.first == $0.last })
    }

    @Test func cachedEdgesRemainStableWhileZoomingAndPanning() throws {
        let canvasSize = CGSize(width: 100, height: 50)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        var alpha = [UInt8](repeating: 0, count: 100 * 50)
        for y in 10..<30 {
            for x in 20..<60 {
                alpha[y * 100 + x] = 255
            }
        }
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 100, height: 50, alpha: alpha),
            bounds: CGRect(x: 20, y: 10, width: 40, height: 20)
        )
        let originalGeometry = try #require(viewModel.selectionEdgeGeometry)
        #expect(originalGeometry.segments.count == 4)

        viewModel.zoom = 2
        viewModel.canvasOffset = CGSize(width: 30, height: -20)

        #expect(viewModel.selectionEdgeGeometry == originalGeometry)
        let imageRect = ImageEditorCanvasGeometry.fittedImageRect(
            canvasSize: canvasSize,
            viewportSize: CGSize(width: 1_000, height: 600),
            zoom: viewModel.zoom,
            canvasOffset: viewModel.canvasOffset
        )
        let transformedPoint = ImageEditorCanvasGeometry.viewPoint(
            from: CGPoint(x: 20, y: 10),
            imageRect: imageRect,
            canvasSize: canvasSize
        )
        assertEqual(transformedPoint, CGPoint(x: 86, y: 58))
    }

    @Test func outsideDragsClampToCanvasAndKeepFixedAspectRatio() throws {
        let canvasSize = CGSize(width: 10, height: 10)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        viewModel.marqueeShape = .square

        let rect = viewModel.marqueeSelectionRect(
            from: CGPoint(x: 6, y: 2),
            to: CGPoint(x: 20, y: 20)
        )
        #expect(rect == CGRect(x: 6, y: 2, width: 4, height: 4))

        viewModel.createLassoSelection(points: [
            CGPoint(x: 2, y: 2),
            CGPoint(x: 20, y: 2),
            CGPoint(x: 20, y: 20)
        ])
        let selection = try #require(viewModel.document.selection)
        #expect(selection.points == [
            CGPoint(x: 2, y: 2),
            CGPoint(x: 10, y: 2),
            CGPoint(x: 10, y: 10)
        ])

        let boundedPoint = ImageEditorCanvasGeometry.boundedImagePoint(
            from: CGPoint(x: -40, y: 400),
            imageRect: CGRect(x: 100, y: 100, width: 400, height: 200),
            canvasSize: CGSize(width: 400, height: 200)
        )
        #expect(boundedPoint == CGPoint(x: 0, y: 200))
    }

    @Test func marqueeCanGrowOutwardFromItsStartPoint() throws {
        let canvasSize = CGSize(width: 20, height: 16)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }

        let centeredRectangle = viewModel.marqueeSelectionRect(
            from: CGPoint(x: 10, y: 8),
            to: CGPoint(x: 13, y: 10),
            isCentered: true
        )
        #expect(centeredRectangle == CGRect(x: 7, y: 6, width: 6, height: 4))
        #expect(viewModel.createMarqueeSelection(
            from: CGPoint(x: 10, y: 8),
            to: CGPoint(x: 13, y: 10),
            isCentered: true
        ))
        #expect(viewModel.document.selection?.bounds == centeredRectangle)

        viewModel.marqueeShape = .circle
        let centeredCircle = viewModel.marqueeSelectionRect(
            from: CGPoint(x: 10, y: 8),
            to: CGPoint(x: 13, y: 10),
            isCentered: true
        )
        #expect(centeredCircle == CGRect(x: 8, y: 6, width: 4, height: 4))

        let clippedRectangle = viewModel.marqueeSelectionRect(
            from: CGPoint(x: 2, y: 2),
            to: CGPoint(x: -10, y: -8),
            isCentered: true
        )
        #expect(clippedRectangle == CGRect(x: 0, y: 0, width: 4, height: 4))
    }

    @Test func lassoRejectsCollinearGeometryButKeepsSelfIntersectingRegions() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: NSImage.transparent(size: CGSize(width: 100, height: 100))
        ) { _ in }
        viewModel.createRectSelection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 20, y: 20))
        let selectionBeforeInvalidLasso = viewModel.document.selection
        let historyCountBeforeInvalidLasso = viewModel.document.history.count
        let undoCountBeforeInvalidLasso = viewModel.undoStack.count

        #expect(!viewModel.createLassoSelection(points: [
            CGPoint(x: 10, y: 10),
            CGPoint(x: 30, y: 30),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 70, y: 70)
        ]))
        #expect(viewModel.document.selection == selectionBeforeInvalidLasso)
        #expect(viewModel.document.history.count == historyCountBeforeInvalidLasso)
        #expect(viewModel.undoStack.count == undoCountBeforeInvalidLasso)

        let selfIntersectingPoints = [
            CGPoint(x: 10, y: 10),
            CGPoint(x: 70, y: 70),
            CGPoint(x: 10, y: 70),
            CGPoint(x: 70, y: 10)
        ]
        #expect(viewModel.createLassoSelection(points: selfIntersectingPoints))
        let selection = try #require(viewModel.document.selection)
        #expect(selection.points == selfIntersectingPoints)
        #expect(selection.isPolygon)
        #expect(viewModel.document.history.count == historyCountBeforeInvalidLasso + 1)
        #expect(viewModel.undoStack.count == undoCountBeforeInvalidLasso + 1)
    }

    @Test func everyStageASelectionSourceCanRoundTripThroughQuickMask() throws {
        let canvasSize = CGSize(width: 24, height: 24)
        let preferencesSuiteName = "ImageEditorSelectionEdgeTests.\(UUID().uuidString)"
        let preferencesDefaults = try #require(UserDefaults(suiteName: preferencesSuiteName))
        defer { preferencesDefaults.removePersistentDomain(forName: preferencesSuiteName) }
        let builders: [(ImageEditorViewModel) -> Void] = [
            { $0.createRectSelection(from: CGPoint(x: 3, y: 3), to: CGPoint(x: 21, y: 21)) },
            {
                $0.marqueeShape = .ellipse
                $0.createMarqueeSelection(from: CGPoint(x: 3, y: 3), to: CGPoint(x: 21, y: 21))
            },
            {
                $0.createLassoSelection(points: [
                    CGPoint(x: 3, y: 3),
                    CGPoint(x: 21, y: 5),
                    CGPoint(x: 12, y: 21)
                ])
            },
            { $0.createMagicSelection(at: CGPoint(x: 12, y: 12)) },
            { $0.createQuickSelection(points: [CGPoint(x: 12, y: 12)]) }
        ]

        for buildSelection in builders {
            let viewModel = ImageEditorViewModel(
                sourceName: "source.png",
                image: solidImage(color: .systemBlue, size: canvasSize),
                preferencesDefaults: preferencesDefaults
            ) { _ in }
            buildSelection(viewModel)
            _ = try #require(viewModel.document.selection)
            viewModel.brushSize = 4
            viewModel.opacity = 1

            viewModel.toggleQuickMaskMode()
            #expect(viewModel.isQuickMaskMode)
            viewModel.drawBrush(points: [CGPoint(x: 12, y: 12)])
            #expect(viewModel.document.selection?.rasterMask != nil)
            #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.quickMaskHide"))

            viewModel.toggleQuickMaskMode()
            #expect(!viewModel.isQuickMaskMode)
            viewModel.undo()
            #expect(viewModel.document.selection != nil)
            viewModel.redo()
            #expect(viewModel.document.selection?.rasterMask != nil)
        }
    }

    private func containsSegment(
        _ geometry: ImageEditorSelectionEdgeGeometry,
        from start: CGPoint,
        to end: CGPoint
    ) -> Bool {
        geometry.segments.contains { segment in
            (segment.start == start && segment.end == end)
                || (segment.start == end && segment.end == start)
        }
    }

    private func assertEqual(_ actual: CGPoint, _ expected: CGPoint, accuracy: CGFloat = 0.001) {
        #expect(abs(actual.x - expected.x) < accuracy)
        #expect(abs(actual.y - expected.y) < accuracy)
    }

    private func solidImage(color: NSColor, size: CGSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }
}
