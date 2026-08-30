import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSpacebarPanEventTests {
    @Test func spaceReleaseEndsPanningWithAnyHeldShortcutModifiers() throws {
        let modifiers: [NSEvent.ModifierFlags] = [[], .shift, .option, .command, .control, [.shift, .option]]
        for flags in modifiers {
            var panning = false
            var transitions: [Bool] = []
            #expect(ImageEditorSpacebarPanEventRouter.handle(
                try event(.keyDown), isPanning: &panning, isTextInputActive: false,
                setPanning: { transitions.append($0) }
            ))
            #expect(panning)
            #expect(ImageEditorSpacebarPanEventRouter.handle(
                try event(.keyUp, flags: flags), isPanning: &panning, isTextInputActive: false,
                setPanning: { transitions.append($0) }
            ))
            #expect(!panning)
            #expect(transitions == [true, false])
        }
    }

    @Test func spaceReleaseStillEndsPanningAfterTextFocusChanges() throws {
        var panning = true
        var transitions: [Bool] = []
        #expect(ImageEditorSpacebarPanEventRouter.handle(
            try event(.keyUp, flags: [.shift]), isPanning: &panning, isTextInputActive: true,
            setPanning: { transitions.append($0) }
        ))
        #expect(!panning)
        #expect(transitions == [false])
    }

    @Test func textSpaceAndModifiedSpaceDoNotStartTemporaryHand() throws {
        for (flags, textInput) in [(NSEvent.ModifierFlags(), true), (.command, false), (.shift, false), (.option, false), (.control, false)] {
            var panning = false
            #expect(!ImageEditorSpacebarPanEventRouter.handle(
                try event(.keyDown, flags: flags), isPanning: &panning, isTextInputActive: textInput,
                setPanning: { _ in Issue.record("Reserved space started panning") }
            ))
            #expect(!panning)
        }
    }

    @Test func repeatAndDuplicateReleaseDoNotRepeatStateTransitions() throws {
        var panning = false
        var transitions: [Bool] = []
        for repeated in [false, true, true] {
            #expect(ImageEditorSpacebarPanEventRouter.handle(
                try event(.keyDown, repeated: repeated), isPanning: &panning, isTextInputActive: false,
                setPanning: { transitions.append($0) }
            ))
        }
        #expect(ImageEditorSpacebarPanEventRouter.handle(
            try event(.keyUp), isPanning: &panning, isTextInputActive: false,
            setPanning: { transitions.append($0) }
        ))
        #expect(!ImageEditorSpacebarPanEventRouter.handle(
            try event(.keyUp), isPanning: &panning, isTextInputActive: false,
            setPanning: { transitions.append($0) }
        ))
        #expect(transitions == [true, false])
    }

    @Test func otherKeysAndModifierEventsNeverEndActivePanning() throws {
        let raw = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 56, keyDown: true))
        raw.type = .flagsChanged
        for event in [try event(.keyUp, keyCode: 51), try #require(NSEvent(cgEvent: raw))] {
            var panning = true
            #expect(!ImageEditorSpacebarPanEventRouter.handle(
                event, isPanning: &panning, isTextInputActive: false,
                setPanning: { _ in Issue.record("Unrelated event changed panning") }
            ))
            #expect(panning)
        }
    }

    @Test func releasedSpacePreservesHeldCursorModifiersThroughKeyboardRouter() throws {
        var panning = true
        var cursorModifiers: NSEvent.ModifierFlags = []
        let result = ImageEditorKeyboardEventRouter.route(
            try event(.keyUp, flags: [.option, .shift, .capsLock]),
            updateCanvasModifiers: { cursorModifiers = $0 },
            handleKeyEvent: { event in
                ImageEditorSpacebarPanEventRouter.handle(
                    event, isPanning: &panning, isTextInputActive: false, setPanning: { _ in }
                ) ? nil : event
            }
        )
        #expect(result == nil)
        #expect(!panning)
        #expect(cursorModifiers == [.option, .shift, .capsLock])
    }

    @Test func componentCursorReturnsToSystemArrowAfterModifiedSpaceRelease() throws {
        var panning = true
        #expect(ImageEditorSpacebarPanEventRouter.handle(
            try event(.keyUp, flags: [.shift]), isPanning: &panning,
            isTextInputActive: false, setPanning: { _ in }
        ))
        #expect(ImageEditorCanvasCursor.interactionMode(
            for: .components, selectedTool: .brush,
            isSpacebarPanning: panning, isCanvasPanGestureActive: false
        ) == .componentLibrary)
        let tool = ImageEditorCanvasCursor.tool(
            for: .components, selectedTool: .brush,
            isSpacebarPanning: panning, isCanvasPanGestureActive: false
        )
        #expect(ImageEditorCanvasCursor.cursor(for: tool, brushDiameter: 18) === NSCursor.arrow)
        #expect(ImageEditorCanvasCursor.interactionMode(
            for: .tools, selectedTool: .brush,
            isSpacebarPanning: panning, isCanvasPanGestureActive: false
        ) == .tool(.brush))
    }

    @Test func coordinatorUsesSpaceRouterWithoutClearingHeldModifiersOnRelease() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"), encoding: .utf8)
        let start = try #require(source.range(of: "private func handleKeyEvent(_ event: NSEvent)"))
        let end = try #require(source.range(of: "let isDelete = ImageEditorDeleteKeyPolicy.matches(", range: start.upperBound..<source.endIndex))
        let spaceHandler = source[start.lowerBound..<end.lowerBound]
        #expect(spaceHandler.contains("ImageEditorSpacebarPanEventRouter.handle("))
        #expect(spaceHandler.contains("isPanning: &isSpacebarPanning"))
        #expect(spaceHandler.contains("setPanning: setSpacebarPanning"))
        #expect(!spaceHandler.contains("resetTransientKeyboardState()"))
    }

    private func event(
        _ type: NSEvent.EventType,
        flags: NSEvent.ModifierFlags = [],
        keyCode: UInt16 = 49,
        repeated: Bool = false
    ) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: flags, timestamp: 15,
            windowNumber: 0, context: nil, characters: " ", charactersIgnoringModifiers: " ",
            isARepeat: repeated, keyCode: keyCode
        ))
    }
}
