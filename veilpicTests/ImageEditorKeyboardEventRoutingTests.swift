import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorKeyboardEventRoutingTests {
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
