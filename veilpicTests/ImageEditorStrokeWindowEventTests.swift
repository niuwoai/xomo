import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorStrokeWindowEventTests {
    private typealias Fixture = ImageEditorNativePointerTestFixture

    @Test func primaryStrokeIgnoresForeignDragAndEndsAtLastValidPoint() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let foreign = Fixture.makeWindow()
            defer { foreign.close() }
            host.onPrimaryToolDragBegan = { _ in true }
            var changes: [CGPoint] = []
            var committed: [ImageEditorPrimaryPointerSample] = []
            host.onPrimaryToolDragChanged = { point, _, _ in changes.append(point) }
            host.onPrimaryToolDragEnded = { _, samples in committed = samples }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: window, point: CGPoint(x: 60, y: 70))))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: foreign)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: nil)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: foreign)))
            #expect(changes == [CGPoint(x: 60, y: 170)])
            #expect(committed.map(\.location) == [CGPoint(x: 50, y: 190), CGPoint(x: 60, y: 170), CGPoint(x: 60, y: 170)])
            #expect(host.pointerCaptureState.activeKind == .none)
        }
    }

    @Test func explicitRecognizerRouteKeepsRangeInSourceWindowCoordinates() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let foreign = Fixture.makeWindow()
            defer { foreign.close() }
            host.onRangeToolDragBegan = { _ in true }
            var changes: [CGPoint] = []
            var ends: [CGPoint] = []
            host.onRangeToolDragChanged = { changes.append($0) }
            host.onRangeToolDragEnded = { ends.append($0) }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window), phase: .down))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: window, point: CGPoint(x: 70, y: 80)), phase: .dragged))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: foreign), phase: .dragged))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil), phase: .up))
            #expect(changes == [CGPoint(x: 70, y: 160)])
            #expect(ends == [CGPoint(x: 70, y: 160)])
        }
    }

    @Test func switchingBetweenMonitorAndRecognizerDoesNotDoubleApplyWindowDelta() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onRangeToolDragBegan = { _ in true }
            var ends: [CGPoint] = []
            host.onRangeToolDragEnded = { ends.append($0) }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: window, point: CGPoint(x: 60, y: 60))))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: window, point: CGPoint(x: 70, y: 70)), phase: .dragged))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window, point: CGPoint(x: 80, y: 80))))
            #expect(ends == [CGPoint(x: 80, y: 160)])
        }
    }

    @Test func anotherCanvasHostFinishesOnlyTheOriginalCaptureState() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            try Fixture.withHost { (other: ScrollWheelZoomNSView, otherWindow: NSWindow) throws -> Void in
                host.onRangeToolDragBegan = { _ in true }
                var ends: [CGPoint] = []
                host.onRangeToolDragEnded = { ends.append($0) }
                other.pointerCaptureState.lastLayerResizePoint = CGPoint(x: 7, y: 9)
                #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
                #expect(other.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: otherWindow)))
                #expect(ends == [CGPoint(x: 50, y: 190)])
                #expect(host.pointerCaptureState.activeKind == .none)
                #expect(other.pointerCaptureState.lastLayerResizePoint == CGPoint(x: 7, y: 9))
            }
        }
    }

    @Test func unrelatedCanvasDetachDoesNotCancelAnOwnedStroke() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            try Fixture.withHost { (other: ScrollWheelZoomNSView, _: NSWindow) throws -> Void in
                host.onPrimaryToolDragBegan = { _ in true }
                var cancellations = 0
                var ends = 0
                host.onPrimaryToolDragCancelled = { cancellations += 1 }
                host.onPrimaryToolDragEnded = { _, _ in ends += 1 }
                #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
                other.removeFromSuperview()
                #expect(cancellations == 0)
                #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
                #expect(ends == 1)
            }
        }
    }

    @Test func originalStrokeToolRemainsAvailableUntilCommitCallbackCompletes() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onPrimaryToolDragBegan = { [weak host] _ in
                host?.pointerCaptureState.activeTool = .brush
                return true
            }
            var toolAtCommit: ImageEditorTool?
            host.onPrimaryToolDragEnded = { [weak host] _, _ in toolAtCommit = host?.pointerCaptureState.activeTool }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
            #expect(toolAtCommit == .brush)
            #expect(host.pointerCaptureState.activeTool == nil)
        }
    }

    @Test func sourceCanvasDetachStillCancelsAndLateReleaseDoesNotCommit() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onRangeToolDragBegan = { _ in true }
            var cancellations = 0
            host.onRangeToolDragCancelled = { cancellations += 1 }
            host.onRangeToolDragEnded = { _ in Issue.record("Detached stroke must not commit") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            host.removeFromSuperview()
            #expect(cancellations == 1)
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
        }
    }
}
