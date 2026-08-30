import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorMiddleMousePanCompletionTests {
    private typealias Fixture = ImageEditorNativePointerTestFixture

    @Test func releaseAppliesLastDeltaBeforeEnding() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var deltas: [CGSize] = []
            var ended: [CGSize] = []
            host.onMiddleMousePanChanged = { deltas.append($0) }
            host.onMiddleMousePanEnded = { ended = deltas }
            try beginAndDrag(host, window)
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, window, 90, 100)))
            #expect(deltas == [CGSize(width: 20, height: -20), CGSize(width: 20, height: -30)])
            #expect(ended == deltas)
        }
    }

    @Test func releaseWithoutDraggedEventStillMovesToFinalPosition() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var deltas: [CGSize] = []
            host.onMiddleMousePanChanged = { deltas.append($0) }
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window)))
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, window, 90, 100)))
            #expect(deltas == [CGSize(width: 40, height: -50)])
        }
    }

    @Test func unchangedReleaseDoesNotRepeatDelta() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var deltas: [CGSize] = []
            host.onMiddleMousePanChanged = { deltas.append($0) }
            try beginAndDrag(host, window)
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, window, 70, 70)))
            #expect(deltas == [CGSize(width: 20, height: -20)])
        }
    }

    @Test(arguments: [false, true])
    func foreignReleaseNeverUsesForeignCoordinates(hasWindow: Bool) throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let other = hasWindow ? Fixture.makeWindow() : nil
            defer { other?.close() }
            var deltas: [CGSize] = []
            var ends = 0
            host.onMiddleMousePanChanged = { deltas.append($0) }
            host.onMiddleMousePanEnded = { ends += 1 }
            try beginAndDrag(host, window)
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, other, 200, 100)))
            #expect(deltas == [CGSize(width: 20, height: -20)])
            #expect(ends == 1)
        }
    }

    @Test func freshPressEndsPreviousPanBeforeStartingAgain() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var phases: [String] = []
            host.onMiddleMousePanBegan = { phases.append("begin") }
            host.onMiddleMousePanEnded = { phases.append("end") }
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window)))
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window, 80, 80)))
            #expect(phases == ["begin", "end", "begin"])
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, nil)))
            #expect(phases == ["begin", "end", "begin", "end"])
        }
    }

    @Test func finalDeltaThatDetachesCanvasEndsOnlyOnce() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            try beginAndDrag(host, window)
            var changes = 0
            var ends = 0
            host.onMiddleMousePanChanged = { [weak host] _ in changes += 1; host?.removeFromSuperview() }
            host.onMiddleMousePanEnded = { ends += 1 }
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, window, 90, 100)))
            #expect(changes == 1)
            #expect(ends == 1)
            #expect(!host.handleMiddleMousePan(try event(.otherMouseUp, nil)))
        }
    }

    @Test func finalDeltaCanStartReplacementWithoutOldReleaseEndingIt() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            try beginAndDrag(host, window)
            let nextDown = try event(.otherMouseDown, window, 100, 100)
            var ends = 0
            var starts = 0
            host.onMiddleMousePanBegan = { starts += 1 }
            host.onMiddleMousePanEnded = { ends += 1 }
            host.onMiddleMousePanChanged = { [weak host] _ in
                #expect(host?.handleMiddleMousePan(nextDown) == true)
            }
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, window, 90, 100)))
            #expect(starts == 1)
            #expect(ends == 1)
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, nil)))
            #expect(ends == 2)
        }
    }

    @Test func nestedRestartFromEndCallbackKeepsItsOwnOrigin() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let nestedDown = try event(.otherMouseDown, window, 100, 100)
            var ends = 0
            var starts = 0
            var deltas: [CGSize] = []
            host.onMiddleMousePanBegan = { starts += 1 }
            host.onMiddleMousePanEnded = { [weak host] in
                ends += 1
                if ends == 1 { #expect(host?.handleMiddleMousePan(nestedDown) == true) }
            }
            host.onMiddleMousePanChanged = { deltas.append($0) }
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window)))
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window, 80, 80)))
            #expect(host.handleMiddleMousePan(try event(.otherMouseDragged, window, 105, 110)))
            #expect(deltas == [CGSize(width: 5, height: -10)])
            #expect(starts == 2)
            #expect(ends == 1)
            #expect(host.handleMiddleMousePan(try event(.otherMouseUp, nil)))
        }
    }

    @Test func restartStopsIfEndingOldPanDetachesCanvas() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var starts = 0
            host.onMiddleMousePanBegan = { starts += 1 }
            host.onMiddleMousePanEnded = { [weak host] in host?.removeFromSuperview() }
            #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window)))
            #expect(!host.handleMiddleMousePan(try event(.otherMouseDown, window, 80, 80)))
            #expect(starts == 1)
        }
    }

    @Test func reentrantReleaseFromFinalDeltaDoesNotRepeatEnd() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            try beginAndDrag(host, window)
            let up = try event(.otherMouseUp, window, 90, 100)
            var changes = 0
            var ends = 0
            host.onMiddleMousePanChanged = { [weak host] _ in
                changes += 1
                if changes == 1 { #expect(host?.handleMiddleMousePan(up) == true) }
            }
            host.onMiddleMousePanEnded = { ends += 1 }
            #expect(host.handleMiddleMousePan(up))
            #expect(changes == 1)
            #expect(ends == 1)
        }
    }

    private func beginAndDrag(_ host: ScrollWheelZoomNSView, _ window: NSWindow) throws {
        #expect(host.handleMiddleMousePan(try event(.otherMouseDown, window)))
        #expect(host.handleMiddleMousePan(try event(.otherMouseDragged, window, 70, 70)))
    }

    private func event(_ type: NSEvent.EventType, _ window: NSWindow?, _ x: CGFloat = 50, _ y: CGFloat = 50) throws -> NSEvent {
        try Fixture.event(type, window: window, point: CGPoint(x: x, y: y))
    }
}
