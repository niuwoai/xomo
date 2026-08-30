import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPointerSequenceRecoveryTests {
    private typealias Fixture = ImageEditorNativePointerTestFixture

    @Test func freshPressCancelsOldStrokeBeforeBeginningAndCommitsOnlyNewSamples() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var events: [String] = []
            var committed: [CGPoint] = []
            host.onPrimaryToolDragBegan = { _ in events.append("begin"); return true }
            host.onPrimaryToolDragCancelled = { events.append("cancel") }
            host.onPrimaryToolDragEnded = { _, samples in events.append("end"); committed = samples.map(\.location) }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window, point: CGPoint(x: 80, y: 100))))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window, point: CGPoint(x: 90, y: 110))))
            #expect(events == ["begin", "cancel", "begin", "end"])
            #expect(committed == [CGPoint(x: 80, y: 140), CGPoint(x: 90, y: 130)])
        }
    }

    @Test func rangeToBrushHandoffCancelsRangeBeforeStartingBrush() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var events: [String] = []
            host.onRangeToolDragBegan = { _ in events.append("range.begin"); return true }
            host.onRangeToolDragCancelled = { events.append("range.cancel") }
            host.onRangeToolDragEnded = { _ in Issue.record("Old range must not commit") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            host.onPrimaryToolDragBegan = { _ in events.append("brush.begin"); return true }
            host.onPrimaryToolDragEnded = { _, _ in events.append("brush.end") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window), phase: .down))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil), phase: .up))
            #expect(events == ["range.begin", "range.cancel", "brush.begin", "brush.end"])
        }
    }

    @Test func resizeToRangeHandoffClearsOldResizeOwnership() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var events: [String] = []
            host.onLayerResizeBegan = { _ in events.append("resize.begin"); return true }
            host.onLayerResizeCancelled = { events.append("resize.cancel") }
            host.onLayerResizeEnded = { _ in Issue.record("Old resize must not commit") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            host.onRangeToolDragBegan = { _ in events.append("range.begin"); return true }
            host.onRangeToolDragEnded = { _ in events.append("range.end") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
            #expect(events == ["resize.begin", "resize.cancel", "range.begin", "range.end"])
            #expect(!host.pointerCaptureState.isLayerResizing)
        }
    }

    @Test func newCanvasPressCancelsPreviousCanvasStrokeBeforeItsOwnBegin() throws {
        try Fixture.withHost { (first: ScrollWheelZoomNSView, firstWindow: NSWindow) throws -> Void in
            try Fixture.withHost { (second: ScrollWheelZoomNSView, secondWindow: NSWindow) throws -> Void in
                var events: [String] = []
                first.onPrimaryToolDragBegan = { _ in true }
                first.onPrimaryToolDragCancelled = { events.append("first.cancel") }
                first.onPrimaryToolDragEnded = { _, _ in Issue.record("Superseded stroke committed") }
                second.onRangeToolDragBegan = { _ in events.append("second.begin"); return true }
                second.onRangeToolDragEnded = { _ in events.append("second.end") }
                #expect(first.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: firstWindow)))
                #expect(second.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: secondWindow)))
                #expect(first.pointerCaptureState.activeKind == .none)
                #expect(second.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: secondWindow)))
                #expect(events == ["first.cancel", "second.begin", "second.end"])
            }
        }
    }

    @Test func unrelatedPressDoesNotCancelCurrentStroke() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let foreign = Fixture.makeWindow()
            defer { foreign.close() }
            host.onRangeToolDragBegan = { _ in true }
            var cancellations = 0
            host.onRangeToolDragCancelled = { cancellations += 1 }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: foreign)))
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window, point: CGPoint(x: -10, y: -10))))
            #expect(cancellations == 0)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
        }
    }

    @Test func cancellationThatDetachesHostRunsOnceAndDoesNotStartANewGesture() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var starts = 0
            var cancellations = 0
            host.onLayerResizeBegan = { _ in starts += 1; return true }
            host.onLayerResizeCancelled = { [weak host] in
                cancellations += 1
                if cancellations == 1 { host?.removeFromSuperview() }
            }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(cancellations == 1)
            #expect(starts == 1)
        }
    }

    @Test func rejectedNewCaptureStillCancelsSupersededStroke() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onPrimaryToolDragBegan = { _ in true }
            var cancellations = 0
            host.onPrimaryToolDragCancelled = { cancellations += 1 }
            host.onPrimaryToolDragEnded = { _, _ in Issue.record("Cancelled stroke committed") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            host.onPrimaryToolDragBegan = { _ in false }
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(cancellations == 1)
            #expect(host.pointerCaptureState.activeKind == .none)
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
        }
    }
}
