import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorObjectMoveEventTests {
    private typealias Fixture = ImageEditorNativePointerTestFixture

    @Test func moveEndConsumesOnceAndCannotReenterAsAnotherMoveOrClick() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            configureMove(host)
            let release = try Fixture.event(.leftMouseUp, window: nil)
            var ends = 0
            host.onObjectMoveClicked = { _, _, _ in Issue.record("A drag must not become a click") }
            host.onObjectMoveEnded = { [weak host] in
                ends += 1
                if ends == 1 { #expect(host?.handleCanvasPointerDrag(release) == false) }
            }
            try beginMove(host, window)
            #expect(host.handleCanvasPointerDrag(release))
            #expect(ends == 1)
            #expect(!host.handleCanvasPointerDrag(release))
        }
    }

    @Test func cancellationThatDetachesViewDoesNotCancelTwice() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            configureMove(host)
            var cancellations = 0
            host.onObjectMoveCancelled = { [weak host] in
                cancellations += 1
                if cancellations == 1 { host?.removeFromSuperview() }
            }
            host.onObjectMoveEnded = { Issue.record("Cancelled move must not commit") }
            try beginMove(host, window)
            host.teardownMonitor()
            #expect(cancellations == 1)
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
        }
    }

    @Test func clickKeepsOriginalModifiersCountAndPointAfterCaptureClears() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            configureMove(host)
            var points: [CGPoint] = []
            var modifiers: NSEvent.ModifierFlags = []
            var count = 0
            let release = try Fixture.event(.leftMouseUp, window: window)
            host.onObjectMoveClicked = { [weak host] point, flags, clicks in
                points.append(point)
                modifiers = flags
                count = clicks
                #expect(host?.handleCanvasPointerDrag(release) == false)
            }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window, modifiers: [.shift], clickCount: 2)))
            #expect(host.handleCanvasPointerDrag(release))
            #expect(points == [CGPoint(x: 50, y: 190)])
            #expect(modifiers == [.shift])
            #expect(count == 2)
        }
    }

    @Test func endCallbackCanStartFreshCandidateWithoutOldCleanupErasingIt() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            configureMove(host)
            let nextDown = try Fixture.event(.leftMouseDown, window: window, point: CGPoint(x: 80, y: 90))
            var clicked: [CGPoint] = []
            host.onObjectMoveEnded = { [weak host] in #expect(host?.handleCanvasPointerDrag(nextDown) == true) }
            host.onObjectMoveClicked = { point, _, _ in clicked.append(point) }
            try beginMove(host, window)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
            #expect(clicked == [CGPoint(x: 80, y: 150)])
        }
    }

    @Test func rejectedActivationConsumesReleaseWithoutClickOrMoveCommit() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            configureMove(host)
            host.onObjectMoveActivated = { _, _ in false }
            host.onObjectMoveEnded = { Issue.record("Rejected move committed") }
            host.onObjectMoveClicked = { _, _, _ in Issue.record("Rejected drag became click") }
            try beginMove(host, window)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
        }
    }

    @Test func freshPressCancelsOldMoveBeforeAcceptingNextCandidate() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            configureMove(host)
            var events: [String] = []
            host.onObjectMoveCandidateBegan = { _, _, _ in events.append("candidate"); return true }
            host.onObjectMoveCancelled = { events.append("cancel") }
            host.onObjectMoveClicked = { _, _, _ in events.append("click") }
            try beginMove(host, window)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
            #expect(events == ["candidate", "cancel", "candidate", "click"])
        }
    }

    @Test func detachingUnactivatedCandidateDoesNotEmitMoveCancellationOrClick() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            configureMove(host)
            host.onObjectMoveCancelled = { Issue.record("Candidate is not an active move") }
            host.onObjectMoveClicked = { _, _, _ in Issue.record("Detached candidate clicked") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            host.removeFromSuperview()
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
        }
    }

    private func configureMove(_ host: ScrollWheelZoomNSView) {
        host.onObjectMoveCandidateBegan = { _, _, _ in true }
        host.onObjectMoveActivated = { _, _ in true }
    }

    private func beginMove(_ host: ScrollWheelZoomNSView, _ window: NSWindow) throws {
        #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
        #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: window, point: CGPoint(x: 70, y: 70))))
    }
}
