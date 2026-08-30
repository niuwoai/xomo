import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerResizePointerEventTests {
    private typealias Fixture = ImageEditorNativePointerTestFixture

    @Test func windowlessReleaseUsesLastValidResizePoint() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onLayerResizeBegan = { _ in true }
            var ends: [CGPoint] = []
            host.onLayerResizeEnded = { ends.append($0) }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: window, point: CGPoint(x: 90, y: 80))))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
            #expect(ends == [CGPoint(x: 90, y: 160)])
            #expect(!host.pointerCaptureState.isLayerResizing)
            #expect(host.pointerCaptureState.lastLayerResizePoint == nil)
        }
    }

    @Test func foreignDragDoesNotChangeResizeAndForeignReleaseUsesStartPoint() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let foreign = Fixture.makeWindow()
            defer { foreign.close() }
            host.onLayerResizeBegan = { _ in true }
            var changes: [CGPoint] = []
            var ends: [CGPoint] = []
            host.onLayerResizeChanged = { changes.append($0) }
            host.onLayerResizeEnded = { ends.append($0) }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: foreign, point: CGPoint(x: 200, y: 210))))
            #expect(changes.isEmpty)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: foreign)))
            #expect(ends == [CGPoint(x: 50, y: 190)])
        }
    }

    @Test func foreignPressDoesNotStartResizeOrEraseExistingCapture() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let foreign = Fixture.makeWindow()
            defer { foreign.close() }
            var starts = 0
            host.onLayerResizeBegan = { _ in starts += 1; return true }
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: foreign)))
            #expect(starts == 0)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: foreign)))
            #expect(starts == 1)
            #expect(host.pointerCaptureState.isLayerResizing)
            #expect(host.pointerCaptureState.lastLayerResizePoint == CGPoint(x: 50, y: 190))
        }
    }

    @Test func localReleaseUsesItsOwnFinalPointAndNextResizeGetsFreshStart() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onLayerResizeBegan = { _ in true }
            var ends: [CGPoint] = []
            host.onLayerResizeEnded = { ends.append($0) }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window, point: CGPoint(x: 100, y: 100))))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window, point: CGPoint(x: 80, y: 80))))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
            #expect(ends == [CGPoint(x: 100, y: 140), CGPoint(x: 80, y: 160)])
        }
    }

    @Test func releaseClearsResizeBeforeCallbackReentryAndDetach() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onLayerResizeBegan = { _ in true }
            let release = try Fixture.event(.leftMouseUp, window: nil)
            var ends = 0
            var cancellations = 0
            host.onLayerResizeCancelled = { cancellations += 1 }
            host.onLayerResizeEnded = { [weak host] _ in
                ends += 1
                if ends == 1 {
                    #expect(host?.handleCanvasPointerDrag(release) == false)
                    host?.removeFromSuperview()
                }
            }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(release))
            #expect(ends == 1)
            #expect(cancellations == 0)
        }
    }

    @Test func missingCapturePointCancelsRatherThanInventingCanvasOrigin() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, _: NSWindow) throws -> Void in
            host.pointerCaptureState.isLayerResizing = true
            var cancellations = 0
            host.onLayerResizeCancelled = { cancellations += 1 }
            host.onLayerResizeEnded = { _ in Issue.record("Invalid capture committed a fabricated point") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
            #expect(cancellations == 1)
            #expect(!host.pointerCaptureState.isLayerResizing)
        }
    }

    @Test func detachClearsLastResizePointAndCancelsWithoutCommit() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onLayerResizeBegan = { _ in true }
            var cancellations = 0
            host.onLayerResizeCancelled = { cancellations += 1 }
            host.onLayerResizeEnded = { _ in Issue.record("Detached resize should not commit") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            host.removeFromSuperview()
            #expect(cancellations == 1)
            #expect(host.pointerCaptureState.lastLayerResizePoint == nil)
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
        }
    }
}
