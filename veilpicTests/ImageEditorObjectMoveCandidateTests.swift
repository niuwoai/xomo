import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorObjectMoveCandidateTests {
    private typealias Fixture = ImageEditorNativePointerTestFixture

    @Test func detachedAndReattachedCandidateDoesNotReturnAfterCallback() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onObjectMoveCandidateBegan = { [weak host] _, _, _ in
                if let host {
                    host.removeFromSuperview()
                    window.contentView?.addSubview(host)
                }
                return true
            }
            rejectUnexpectedCallbacks(host)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
        }
    }

    @Test(arguments: [false, true])
    func replacementKeepsNewestClickSnapshot(oldAccepted: Bool) throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let nextDown = try Fixture.event(.leftMouseDown, window: window,
                point: CGPoint(x: 100, y: 90), modifiers: [.shift], clickCount: 2)
            var begins = 0
            var points: [CGPoint] = []
            var modifiers: NSEvent.ModifierFlags = []
            var count = 0
            host.onObjectMoveCandidateBegan = { [weak host] _, _, _ in
                begins += 1
                if begins == 1 {
                    #expect(host?.handleCanvasPointerDrag(nextDown) == true)
                    return oldAccepted
                }
                return true
            }
            host.onObjectMoveClicked = { point, flags, clicks in
                points.append(point)
                modifiers = flags
                count = clicks
            }
            host.onObjectMoveCancelled = { Issue.record("Unactivated candidate must not cancel a move") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
            #expect(points == [CGPoint(x: 100, y: 150)])
            #expect(modifiers == [.shift])
            #expect(count == 2)
        }
    }

    @Test func releaseDuringPreparationConsumesWithoutClickOrRestoringCandidate() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let up = try Fixture.event(.leftMouseUp, window: window)
            host.onObjectMoveCandidateBegan = { [weak host] _, _, _ in
                #expect(host?.handleCanvasPointerDrag(up) == true)
                return true
            }
            rejectUnexpectedCallbacks(host)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(!host.handleCanvasPointerDrag(up))
        }
    }

    @Test func preparingCandidateConsumesDragWithoutPrematureActivation() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let drag = try Fixture.event(.leftMouseDragged, window: window, point: CGPoint(x: 70, y: 70))
            var activations = 0
            host.onObjectMoveActivated = { _, _ in activations += 1; return true }
            host.onObjectMoveCandidateBegan = { [weak host] _, _, _ in
                #expect(host?.handleCanvasPointerDrag(drag) == true)
                #expect(activations == 0)
                return true
            }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(drag))
            #expect(activations == 1)
        }
    }

    @Test func rejectedCandidateLeavesReleaseUnclaimedWithoutCancellation() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onObjectMoveCandidateBegan = { _, _, _ in false }
            rejectUnexpectedCallbacks(host)
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
        }
    }

    @Test func acceptedCandidateOwnsPointerBeforeActivationThresholdAndReleasesOnClick() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onObjectMoveCandidateBegan = { _, _, _ in true }
            host.onObjectMoveClicked = { _, _, _ in }

            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.pointerCaptureState.isObjectMoveCandidateActive)
            #expect(host.pointerCaptureState.hasActivePointerOwnership)

            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
            #expect(!host.pointerCaptureState.isObjectMoveCandidateActive)
            #expect(!host.pointerCaptureState.hasActivePointerOwnership)
        }
    }

    @Test func teardownWithoutDetachingStillInvalidatesPreparingCandidate() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            host.onObjectMoveCandidateBegan = { [weak host] _, _, _ in
                host?.teardownMonitor()
                return true
            }
            rejectUnexpectedCallbacks(host)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
        }
    }

    private func rejectUnexpectedCallbacks(_ host: ScrollWheelZoomNSView) {
        host.onObjectMoveActivated = { _, _ in Issue.record("Invalid candidate activated"); return true }
        host.onObjectMoveChanged = { _ in Issue.record("Invalid candidate moved") }
        host.onObjectMoveClicked = { _, _, _ in Issue.record("Invalid candidate clicked") }
        host.onObjectMoveEnded = { Issue.record("Invalid candidate committed") }
        host.onObjectMoveCancelled = { Issue.record("Unactivated candidate cancelled a move") }
    }
}
