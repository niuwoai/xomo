import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorMiddleMousePanEventTests {
    @Test func windowlessReleaseEndsPanOnceAndRejectsFurtherDrag() throws {
        try withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var ends = 0
            host.onMiddleMousePanEnded = { ends += 1 }
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window: window)))
            let release = try event(.otherMouseUp, window: nil)
            #expect(release.window == nil)
            #expect(host.handleMiddleMousePan(release))
            #expect(!host.handleMiddleMousePan(release))
            #expect(!host.handleMiddleMousePan(try event(.otherMouseDragged, window: window)))
            #expect(ends == 1)
        }
    }

    @Test func foreignWindowDragIsConsumedWithoutDeltaAndReleaseEndsPan() throws {
        try withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let foreign = makeWindow()
            defer { foreign.close() }
            var deltas: [CGSize] = []
            var ends = 0
            host.onMiddleMousePanChanged = { deltas.append($0) }
            host.onMiddleMousePanEnded = { ends += 1 }
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window: window)))
            #expect(host.handleMiddleMousePan(try event(.otherMouseDragged, window: foreign)))
            #expect(deltas.isEmpty)
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, window: foreign)))
            #expect(ends == 1)
        }
    }

    @Test func foreignAndOutOfBoundsPressesDoNotStartPan() throws {
        try withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let foreign = makeWindow()
            defer { foreign.close() }
            var starts = 0
            host.onMiddleMousePanBegan = { starts += 1 }
            #expect(!host.handleMiddleMousePan(try event(.otherMouseDown, window: foreign)))
            #expect(!host.handleMiddleMousePan(try event(.otherMouseDown, window: nil)))
            #expect(!host.handleMiddleMousePan(try event(.otherMouseDown, window: window, point: CGPoint(x: -10, y: -10))))
            #expect(!host.handleMiddleMousePan(try event(.otherMouseUp, window: nil)))
            #expect(starts == 0)
        }
    }

    @Test func nonMiddleReleaseDoesNotInterruptPan() throws {
        try withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var ends = 0
            host.onMiddleMousePanEnded = { ends += 1 }
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window: window)))
            #expect(!host.handleMiddleMousePan(try event(.rightMouseUp, window: window)))
            #expect(ends == 0)
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, window: nil)))
            #expect(ends == 1)
        }
    }

    @Test func nativeDragKeepsFlippedDeltaAndNextGestureHasFreshOrigin() throws {
        try withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var deltas: [CGSize] = []
            host.onMiddleMousePanChanged = { deltas.append($0) }
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window: window)))
            #expect(host.handleMiddleMousePan(try event(.otherMouseDragged, window: window, point: CGPoint(x: 60, y: 70))))
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, window: nil)))
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window: window, point: CGPoint(x: 80, y: 90))))
            #expect(host.handleMiddleMousePan(try event(.otherMouseDragged, window: window, point: CGPoint(x: 85, y: 95))))
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, window: window, point: CGPoint(x: 85, y: 95))))
            #expect(deltas == [CGSize(width: 10, height: -20), CGSize(width: 5, height: -5)])
        }
    }

    @Test func releaseClearsOwnershipBeforeReentrantEndCallback() throws {
        try withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let release = try event(.otherMouseUp, window: nil)
            var ends = 0
            host.onMiddleMousePanEnded = { [weak host] in
                ends += 1
                if ends == 1 { #expect(host?.handleMiddleMousePan(release) == false) }
            }
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window: window)))
            #expect(host.handleMiddleMousePan(release))
            #expect(ends == 1)
        }
    }

    @Test func detachEndsPanAndLateReleaseIsNotConsumedAgain() throws {
        try withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var ends = 0
            host.onMiddleMousePanEnded = { ends += 1 }
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window: window)))
            host.removeFromSuperview()
            #expect(ends == 1)
            #expect(!host.handleMiddleMousePan(try event(.otherMouseUp, window: nil)))
        }
    }

    private func withHost(_ body: (ScrollWheelZoomNSView, NSWindow) throws -> Void) rethrows {
        try ImageEditorNativePointerTestFixture.withHost(body)
    }

    private func makeWindow() -> NSWindow {
        ImageEditorNativePointerTestFixture.makeWindow()
    }

    private func event(
        _ type: NSEvent.EventType,
        window: NSWindow?,
        point: CGPoint = CGPoint(x: 50, y: 50)
    ) throws -> NSEvent {
        try ImageEditorNativePointerTestFixture.event(type, window: window, point: point)
    }
}
