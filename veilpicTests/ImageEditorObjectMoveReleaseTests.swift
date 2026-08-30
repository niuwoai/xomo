import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorObjectMoveReleaseTests {
    private typealias Fixture = ImageEditorNativePointerTestFixture

    @Test func releaseAppliesFinalTranslationBeforeCommit() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var translations: [CGSize] = []
            var committed: [CGSize] = []
            host.onObjectMoveChanged = { translations.append($0) }
            host.onObjectMoveEnded = { committed = translations }
            try beginMove(host, window)
            #expect(host.handleCanvasPointerDrag(try release(window, x: 90, y: 100)))
            #expect(translations == [CGSize(width: 20, height: -20), CGSize(width: 40, height: -50)])
            #expect(committed == translations)
        }
    }

    @Test func unchangedReleaseDoesNotRepeatTranslation() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var translations: [CGSize] = []
            var ends = 0
            host.onObjectMoveChanged = { translations.append($0) }
            host.onObjectMoveEnded = { ends += 1 }
            try beginMove(host, window)
            #expect(host.handleCanvasPointerDrag(try release(window, x: 70, y: 70)))
            #expect(translations == [CGSize(width: 20, height: -20)])
            #expect(ends == 1)
        }
    }

    @Test(arguments: [false, true])
    func foreignOrWindowlessReleasePreservesLastTranslation(foreignWindow: Bool) throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            let other = foreignWindow ? Fixture.makeWindow() : nil
            defer { other?.close() }
            var translations: [CGSize] = []
            var ends = 0
            host.onObjectMoveChanged = { translations.append($0) }
            host.onObjectMoveEnded = { ends += 1 }
            try beginMove(host, window)
            #expect(host.handleCanvasPointerDrag(try release(other, x: 200, y: 150)))
            #expect(translations == [CGSize(width: 20, height: -20)])
            #expect(ends == 1)
        }
    }

    @Test func releaseOutsideCanvasStillUsesOwningWindowCoordinates() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            var last: CGSize?
            host.onObjectMoveChanged = { last = $0 }
            try beginMove(host, window)
            #expect(host.handleCanvasPointerDrag(try release(window, x: 350, y: -10)))
            #expect(last == CGSize(width: 300, height: 60))
        }
    }

    @Test func candidateReleaseDoesNotActivateMoveFromReleaseDistance() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            configureMove(host)
            var clicks = 0
            host.onObjectMoveActivated = { _, _ in Issue.record("Release must not activate a drag"); return true }
            host.onObjectMoveChanged = { _ in Issue.record("Candidate must not move") }
            host.onObjectMoveClicked = { _, _, _ in clicks += 1 }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try release(window, x: 90, y: 100)))
            #expect(clicks == 1)
        }
    }

    @Test func rejectedMoveDoesNotApplyReleaseTranslation() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            configureMove(host)
            host.onObjectMoveActivated = { _, _ in false }
            host.onObjectMoveChanged = { _ in Issue.record("Rejected move must not change") }
            host.onObjectMoveEnded = { Issue.record("Rejected move must not commit") }
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
            #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: window, point: CGPoint(x: 70, y: 70))))
            #expect(host.handleCanvasPointerDrag(try release(window, x: 90, y: 100)))
        }
    }

    @Test func detachingDuringFinalTranslationCancelsWithoutCommit() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            try beginMove(host, window)
            var cancellations = 0
            host.onObjectMoveCancelled = { cancellations += 1 }
            host.onObjectMoveChanged = { [weak host] _ in host?.removeFromSuperview() }
            host.onObjectMoveEnded = { Issue.record("Detached move must not commit") }
            #expect(host.handleCanvasPointerDrag(try release(window, x: 90, y: 100)))
            #expect(cancellations == 1)
        }
    }

    @Test func finalTranslationCannotClearReplacementCandidate() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            try beginMove(host, window)
            let nextDown = try Fixture.event(.leftMouseDown, window: window)
            var cancellations = 0
            var clicks = 0
            host.onObjectMoveChanged = { [weak host] _ in #expect(host?.handleCanvasPointerDrag(nextDown) == true) }
            host.onObjectMoveCancelled = { cancellations += 1 }
            host.onObjectMoveEnded = { Issue.record("Superseded move must not commit") }
            host.onObjectMoveClicked = { _, _, _ in clicks += 1 }
            #expect(host.handleCanvasPointerDrag(try release(window, x: 90, y: 100)))
            #expect(cancellations == 1)
            #expect(host.handleCanvasPointerDrag(try release(window, x: 50, y: 50)))
            #expect(clicks == 1)
        }
    }

    @Test func reentrantReleaseDuringFinalTranslationCommitsOnlyOnce() throws {
        try Fixture.withHost { (host: ScrollWheelZoomNSView, window: NSWindow) throws -> Void in
            try beginMove(host, window)
            let up = try release(window, x: 90, y: 100)
            var changes = 0
            var ends = 0
            host.onObjectMoveChanged = { [weak host] _ in
                changes += 1
                if changes == 1 { #expect(host?.handleCanvasPointerDrag(up) == true) }
            }
            host.onObjectMoveEnded = { ends += 1 }
            #expect(host.handleCanvasPointerDrag(up))
            #expect(changes == 1)
            #expect(ends == 1)
            #expect(!host.handleCanvasPointerDrag(up))
        }
    }

    private func configureMove(_ host: ScrollWheelZoomNSView) {
        host.onObjectMoveCandidateBegan = { _, _, _ in true }
        host.onObjectMoveActivated = { _, _ in true }
    }

    private func beginMove(_ host: ScrollWheelZoomNSView, _ window: NSWindow) throws {
        configureMove(host)
        #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDown, window: window)))
        #expect(host.handleCanvasPointerDrag(try Fixture.event(.leftMouseDragged, window: window, point: CGPoint(x: 70, y: 70))))
    }

    private func release(_ window: NSWindow?, x: CGFloat, y: CGFloat) throws -> NSEvent {
        try Fixture.event(.leftMouseUp, window: window, point: CGPoint(x: x, y: y))
    }
}
