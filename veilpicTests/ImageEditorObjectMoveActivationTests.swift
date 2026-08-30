import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorObjectMoveActivationTests {
    private typealias Fixture = ImageEditorNativePointerTestFixture

    @Test func detachingDuringActivationCancelsWithoutPublishingMovement() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var cancellations = 0
            host.onObjectMoveCandidateBegan = { _, _, _ in true }
            host.onObjectMoveActivated = { [weak host] _, _ in
                host?.removeFromSuperview()
                return true
            }
            host.onObjectMoveCancelled = { cancellations += 1 }
            host.onObjectMoveChanged = { _ in Issue.record("Detached activation published movement") }
            host.onObjectMoveEnded = { Issue.record("Detached activation committed") }
            try beginMove(host, window)
            #expect(cancellations == 1)
            #expect(!host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: nil)))
        }
    }

    @Test(arguments: [false, true])
    func replacementCandidateSurvivesOldActivationResult(accepted: Bool) throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let nextDown = try Fixture.event(.leftMouseDown, window: window, point: CGPoint(x: 90, y: 100))
            var cancellations = 0
            var clicked: [CGPoint] = []
            host.onObjectMoveCandidateBegan = { _, _, _ in true }
            host.onObjectMoveActivated = { [weak host] _, _ in
                #expect(host?.handleCanvasPointerDrag(nextDown) == true)
                return accepted
            }
            host.onObjectMoveCancelled = { cancellations += 1 }
            host.onObjectMoveClicked = { point, _, _ in clicked.append(point) }
            host.onObjectMoveChanged = { _ in Issue.record("Old activation moved replacement") }
            host.onObjectMoveEnded = { Issue.record("Old activation committed replacement") }
            try beginMove(host, window)
            #expect(cancellations == 1)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
            #expect(clicked == [CGPoint(x: 90, y: 140)])
        }
    }

    @Test func recursiveDragDuringActivationDoesNotActivateTwice() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let drag = try Fixture.event(.leftMouseDragged, window: window, point: CGPoint(x: 70, y: 70))
            var activations = 0
            var changes = 0
            host.onObjectMoveCandidateBegan = { _, _, _ in true }
            host.onObjectMoveActivated = { [weak host] _, _ in
                activations += 1
                if activations == 1 { #expect(host?.handleCanvasPointerDrag(drag) == true) }
                return true
            }
            host.onObjectMoveChanged = { _ in changes += 1 }
            try beginMove(host, window)
            #expect(activations == 1)
            #expect(changes == 1)
        }
    }

    @Test func releaseDuringActivationCancelsRatherThanClickingOrCommitting() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let release = try Fixture.event(.leftMouseUp, window: window)
            var cancellations = 0
            host.onObjectMoveCandidateBegan = { _, _, _ in true }
            host.onObjectMoveActivated = { [weak host] _, _ in
                #expect(host?.handleCanvasPointerDrag(release) == true)
                return true
            }
            host.onObjectMoveCancelled = { cancellations += 1 }
            host.onObjectMoveClicked = { _, _, _ in Issue.record("Activating drag became click") }
            host.onObjectMoveChanged = { _ in Issue.record("Released activation moved") }
            host.onObjectMoveEnded = { Issue.record("Released activation committed") }
            try beginMove(host, window)
            #expect(cancellations == 1)
            #expect(!host.handleCanvasPointerDrag(release))
        }
    }

    @Test func cancellationDuringActivationCanDetachWithoutRepeatedCancellation() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var cancellations = 0
            host.onObjectMoveCandidateBegan = { _, _, _ in true }
            host.onObjectMoveActivated = { [weak host] _, _ in
                host?.teardownMonitor()
                return true
            }
            host.onObjectMoveCancelled = { [weak host] in
                cancellations += 1
                if cancellations == 1 { host?.removeFromSuperview() }
            }
            host.onObjectMoveChanged = { _ in Issue.record("Cancelled activation moved") }
            try beginMove(host, window)
            #expect(cancellations == 1)
        }
    }

    @Test func rejectedActivationRemainsConsumedWithoutSpuriousCancellation() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var activations = 0
            host.onObjectMoveCandidateBegan = { _, _, _ in true }
            host.onObjectMoveActivated = { _, _ in activations += 1; return false }
            host.onObjectMoveCancelled = { Issue.record("Rejected activation is not an active move") }
            host.onObjectMoveClicked = { _, _, _ in Issue.record("Rejected activation became click") }
            host.onObjectMoveChanged = { _ in Issue.record("Rejected activation moved") }
            try beginMove(host, window)
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseUp, window: window)))
            #expect(activations == 1)
        }
    }

    private func beginMove(_ host: ScrollWheelZoomNSView, _ window: NSWindow) throws {
        #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
        #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: window, point: CGPoint(x: 70, y: 70))))
    }
}
