import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorKeyboardEventRoutingTests {
    private final class MonitorOwner {}

    @Test func monitorConsumesHandledDeleteWithoutForwardingItAgain() throws {
        let owner = MonitorOwner()
        let event = try keyEvent(type: .keyDown)
        var deletions = 0
        var downstreamEvents = 0
        let monitor = ImageEditorKeyboardEventRouter.monitorHandler(for: owner) { _, event in
            ImageEditorKeyboardEventRouter.route(
                event,
                updateCanvasModifiers: { _ in },
                handleKeyEvent: { event in
                    let handled = ImageEditorKeyboardResponderDeleteDispatcher.perform(
                        event: event,
                        deleteSelectedObject: { _ in deletions += 1; return true }
                    )
                    return handled ? nil : event
                }
            )
        }
        if monitor(event) != nil { downstreamEvents += 1 }
        #expect(deletions == 1)
        #expect(downstreamEvents == 0)
        withExtendedLifetime(owner) {}
    }

    @Test func monitorPreservesUnhandledAndReplacementEvents() throws {
        let owner = MonitorOwner()
        let event = try keyEvent(type: .keyDown)
        let replacement = try keyEvent(type: .keyUp)
        let passthrough = ImageEditorKeyboardEventRouter.monitorHandler(for: owner) { _, event in event }
        let replacing = ImageEditorKeyboardEventRouter.monitorHandler(for: owner) { _, _ in replacement }
        #expect(passthrough(event) === event)
        #expect(replacing(event) === replacement)
        withExtendedLifetime(owner) {}
    }

    @Test func monitorDoesNotRetainOwnerAndPassesThroughAfterRelease() throws {
        var owner: MonitorOwner? = MonitorOwner()
        weak var releasedOwner = owner
        var calls = 0
        let monitor = ImageEditorKeyboardEventRouter.monitorHandler(for: try #require(owner)) { _, _ in
            calls += 1
            return nil
        }
        owner = nil
        #expect(releasedOwner == nil)
        let event = try keyEvent(type: .keyDown)
        #expect(monitor(event) === event)
        #expect(calls == 0)
    }

    @Test func monitorKeepsModifierEventsInResponderChain() throws {
        let owner = MonitorOwner()
        let event = try modifierEvent(flags: [.maskShift])
        var flags: NSEvent.ModifierFlags = []
        let monitor = ImageEditorKeyboardEventRouter.monitorHandler(for: owner) { _, event in
            ImageEditorKeyboardEventRouter.route(
                event,
                updateCanvasModifiers: { flags = $0 },
                handleKeyEvent: { _ in Issue.record("Modifier event entered keyboard handler"); return nil }
            )
        }
        #expect(monitor(event) === event)
        #expect(flags == [.shift])
        withExtendedLifetime(owner) {}
    }

    @Test func appKitMonitorUsesHandlerWithoutCoalescingConsumedEvents() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"), encoding: .utf8)
        #expect(source.contains("handler: ImageEditorKeyboardEventRouter.monitorHandler(for: self)"))
        #expect(source.contains("owner.handle(event)"))
        #expect(!source.contains("self?.handle(event) ?? event"))
    }

    @Test func modifierEventsUpdateCursorWithoutReadingKeyboardCharacters() throws {
        let event = try modifierEvent(flags: [.maskShift, .maskAlternate, .maskCommand])
        var receivedFlags: NSEvent.ModifierFlags = []
        var keyboardCalls = 0
        let result = ImageEditorKeyboardEventRouter.route(
            event,
            updateCanvasModifiers: { receivedFlags = $0 },
            handleKeyEvent: { _ in
                keyboardCalls += 1
                return nil
            }
        )
        #expect(receivedFlags == [.shift, .option])
        #expect(keyboardCalls == 0)
        #expect(result === event)
    }

    @Test func modifierReleaseClearsCursorFlagsAndPreservesOriginalEvent() throws {
        let event = try modifierEvent(flags: [])
        var receivedFlags: NSEvent.ModifierFlags = [.option, .capsLock]
        let result = ImageEditorKeyboardEventRouter.route(
            event,
            updateCanvasModifiers: { receivedFlags = $0 },
            handleKeyEvent: { _ in Issue.record("Modifier release entered key handling"); return nil }
        )
        #expect(receivedFlags.isEmpty)
        #expect(result === event)
    }

    @Test func keyDownAndKeyUpReachHandlerAfterCursorUpdate() throws {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            let event = try keyEvent(type: type)
            var calls: [String] = []
            let result = ImageEditorKeyboardEventRouter.route(
                event,
                updateCanvasModifiers: { _ in calls.append("modifiers") },
                handleKeyEvent: { received in
                    #expect(received === event)
                    #expect(received.charactersIgnoringModifiers == "\u{7F}")
                    calls.append("key")
                    return nil
                }
            )
            #expect(calls == ["modifiers", "key"])
            #expect(result == nil)
        }
    }

    @Test func deleteRespondersRejectModifierAndKeyUpEvents() throws {
        for event in [try modifierEvent(flags: [.maskShift]), try keyEvent(type: .keyUp)] {
            var deletions = 0
            #expect(!ImageEditorKeyboardResponderDeleteDispatcher.perform(
                event: event,
                deleteSelectedObject: { _ in deletions += 1; return true }
            ))
            #expect(!ImageEditorKeyboardResponderDeleteDispatcher.performKeyEquivalent(
                event: event,
                isTextInputActive: false,
                deleteSelectedObject: { _ in deletions += 1; return true }
            ))
            #expect(deletions == 0)
        }
    }

    @Test func realDeleteKeyDownStillReachesBothResponderEntryPoints() throws {
        let event = try keyEvent(type: .keyDown)
        var deletions = 0
        #expect(ImageEditorKeyboardResponderDeleteDispatcher.perform(
            event: event,
            deleteSelectedObject: { _ in deletions += 1; return true }
        ))
        #expect(ImageEditorKeyboardResponderDeleteDispatcher.performKeyEquivalent(
            event: event,
            isTextInputActive: false,
            deleteSelectedObject: { _ in deletions += 1; return true }
        ))
        #expect(deletions == 2)
        #expect(!ImageEditorKeyboardResponderDeleteDispatcher.performKeyEquivalent(
            event: event,
            isTextInputActive: true,
            deleteSelectedObject: { _ in deletions += 1; return true }
        ))
        #expect(deletions == 2)
    }

    @Test func windowMonitorUsesSafeRouterBeforeAnyCharacterRead() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"), encoding: .utf8)
        let start = try #require(source.range(of: "private func handle(_ event: NSEvent)"))
        let end = try #require(source.range(of: "private func handleKeyEvent(_ event: NSEvent)"))
        let windowHandler = source[start.lowerBound..<end.lowerBound]
        #expect(windowHandler.contains("ImageEditorKeyboardEventRouter.route("))
        #expect(windowHandler.contains("updateCanvasModifiers: setCanvasModifierFlags"))
        #expect(!windowHandler.contains("event.charactersIgnoringModifiers"))
    }

    private func modifierEvent(flags: CGEventFlags) throws -> NSEvent {
        let raw = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 56, keyDown: true))
        raw.type = .flagsChanged
        raw.flags = flags
        let event = try #require(NSEvent(cgEvent: raw))
        #expect(event.type == .flagsChanged)
        return event
    }

    private func keyEvent(type: NSEvent.EventType) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: [], timestamp: 12.5,
            windowNumber: 0, context: nil, characters: "\u{7F}",
            charactersIgnoringModifiers: "\u{7F}", isARepeat: false, keyCode: 51
        ))
    }
}
