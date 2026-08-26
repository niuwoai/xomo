import AppKit
import Testing
@testable import musepic

struct ImageEditorTextInputShortcutTests {
    @MainActor
    @Test func filePanelCompletionReturnsDeleteOwnershipToTheEditorKeyboardResponder() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let searchField = NSTextField(frame: NSRect(x: 20, y: 20, width: 160, height: 24))
        let keyboardResponder = ImageEditorKeyboardShortcutResponderNSView(
            frame: NSRect(x: 0, y: 0, width: 1, height: 1)
        )
        window.contentView = NSView(frame: window.contentLayoutRect)
        window.contentView?.addSubview(searchField)
        window.contentView?.addSubview(keyboardResponder)
        window.orderFront(nil)
        #expect(window.makeFirstResponder(searchField))
        #expect(window.firstResponder is NSTextView || window.firstResponder is NSTextField)

        ImageEditorFilePanelKeyboardFocusRestorer.restore(
            to: window,
            isApplicationActive: true
        )

        #expect(window.firstResponder === keyboardResponder)
        window.orderOut(nil)
    }

    @MainActor
    @Test func filePanelFocusRestorerFallsBackSafelyWithoutAKeyboardHost() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let searchField = NSTextField(frame: NSRect(x: 20, y: 20, width: 160, height: 24))
        window.contentView = NSView(frame: window.contentLayoutRect)
        window.contentView?.addSubview(searchField)
        window.orderFront(nil)
        #expect(window.makeFirstResponder(searchField))

        ImageEditorFilePanelKeyboardFocusRestorer.restore(
            to: window,
            isApplicationActive: true
        )

        #expect(!(window.firstResponder is NSTextView))
        #expect(!(window.firstResponder is NSTextField))
        window.orderOut(nil)
    }

    @MainActor
    @Test func filePanelTeardownCannotStealDeleteFromTheImportedObject() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let staleField = NSTextField(frame: NSRect(x: 20, y: 20, width: 160, height: 24))
        let keyboardResponder = ImageEditorKeyboardShortcutResponderNSView(
            frame: NSRect(x: 0, y: 0, width: 1, height: 1)
        )
        window.contentView = NSView(frame: window.contentLayoutRect)
        window.contentView?.addSubview(staleField)
        window.contentView?.addSubview(keyboardResponder)
        window.orderFront(nil)
        #expect(window.makeFirstResponder(staleField))

        var deferredRestore: (@MainActor () -> Void)?
        ImageEditorFilePanelKeyboardFocusRestorer.restore(
            to: window,
            isApplicationActive: true,
            deferredApplicationActivity: { true },
            scheduleDeferredRestore: { deferredRestore = $0 }
        )
        #expect(window.firstResponder === keyboardResponder)

        // AppKit may complete panel teardown after the completion handler and
        // restore the field editor that owned focus before the import.
        #expect(window.makeFirstResponder(staleField))
        #expect(window.firstResponder is NSTextView || window.firstResponder is NSTextField)

        let restoreAfterTeardown = try #require(deferredRestore)
        restoreAfterTeardown()
        #expect(window.firstResponder === keyboardResponder)
        window.orderOut(nil)
    }

    @Test func contextualDeleteClearsPixelsBeforeDeletingASelectedLayer() {
        #expect(
            ImageEditorContextualDocumentDeletePolicy.resolve(
                hasSelection: true,
                canRemoveSelectionPixels: true,
                canDeleteLayer: true
            ) == .clearSelectionPixels
        )
        #expect(
            ImageEditorContextualDocumentDeletePolicy.resolve(
                hasSelection: true,
                canRemoveSelectionPixels: false,
                canDeleteLayer: true
            ) == nil
        )
        #expect(
            ImageEditorContextualDocumentDeletePolicy.resolve(
                hasSelection: false,
                canRemoveSelectionPixels: false,
                canDeleteLayer: true
            ) == .deleteSelectedLayer
        )
        #expect(
            ImageEditorContextualDocumentDeletePolicy.resolve(
                hasSelection: false,
                canRemoveSelectionPixels: false,
                canDeleteLayer: false
            ) == nil
        )
    }

    @Test func standardTextEditingShortcutsRemainOwnedByTheActiveTextInput() {
        let standardActions: [(String, NSEvent.ModifierFlags, ImageEditorKeyboardShortcutAction)] = [
            ("a", [.command], .selectAll),
            ("a", [.command, .option], .selectAllLayers),
            ("c", [.command], .copySelectionClipboard),
            ("x", [.command], .cutSelectionClipboard),
            ("v", [.command], .pasteClipboardLayer),
            ("z", [.command], .undo),
            ("z", [.command, .shift], .redo)
        ]

        for (key, modifiers, expected) in standardActions {
            let action = ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: key,
                modifierFlags: modifiers
            )
            #expect(action == expected)
            #expect(action?.isBlockedByTextInput == true)
        }
    }

    @Test func explicitEditorCommandsStillWorkWhileTextInputIsActive() {
        #expect(!ImageEditorKeyboardShortcutAction.openProject.isBlockedByTextInput)
        #expect(!ImageEditorKeyboardShortcutAction.saveProject.isBlockedByTextInput)
        #expect(!ImageEditorKeyboardShortcutAction.copyMergedClipboard.isBlockedByTextInput)
        #expect(!ImageEditorKeyboardShortcutAction.pasteClipboardInPlaceLayer.isBlockedByTextInput)
        #expect(ImageEditorKeyboardShortcutAction.toggleQuickMask.isBlockedByTextInput)
        #expect(ImageEditorKeyboardShortcutAction.toggleQuickMaskGrayscalePreview.isBlockedByTextInput)
        #expect(ImageEditorKeyboardShortcutAction.toggleLayerMaskRubylith.isBlockedByTextInput)
    }

    @Test func deleteAndFillShortcutsRemainOwnedByActiveTextInput() {
        let fillDialogAction = ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "",
            modifierFlags: [.shift],
            keyCode: 96
        )
        #expect(fillDialogAction == .openSelectionFill)
        #expect(fillDialogAction?.isBlockedByTextInput == true)

        let cases: [(NSEvent.ModifierFlags, ImageEditorKeyboardShortcutAction)] = [
            ([.option], .fillSelection),
            ([.option, .shift], .fillSelectionPreservingTransparency),
            ([.command], .fillSelectionBackground),
            ([.command, .shift], .fillSelectionBackgroundPreservingTransparency),
            ([.command, .option], .fillSelectionHistory),
            ([.command, .option, .shift], .fillSelectionHistoryPreservingTransparency)
        ]

        for (modifiers, expected) in cases {
            let action = ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "",
                modifierFlags: modifiers,
                keyCode: 51
            )
            #expect(action == expected)
            #expect(action?.isBlockedByTextInput == true)
        }

        for keyCode: UInt16 in [51, 117] {
            let action = ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "",
                modifierFlags: [],
                keyCode: keyCode
            )
            #expect(action == .clearSelectionPixels)
            #expect(action?.isBlockedByTextInput == true)
        }
    }

    @Test func commonTextFormattingAndFindKeysCannotTriggerDestructiveCanvasCommands() {
        let protectedActions: [(String, ImageEditorKeyboardShortcutAction)] = [
            ("b", .colorBalance),
            ("i", .invertPixels),
            ("u", .hueSaturation),
            ("f", .applyLastFilter),
            ("t", .toggleTransformControls),
            ("m", .curves),
            ("l", .levels)
        ]

        for (key, expected) in protectedActions {
            let action = ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: key,
                modifierFlags: [.command]
            )
            #expect(action == expected)
            #expect(action?.isBlockedByTextInput == true)
        }
    }

    @Test func textFindNavigationAndParagraphKeysCannotMutateLayersOrViewState() {
        let protectedActions: [(String, NSEvent.ModifierFlags, ImageEditorKeyboardShortcutAction)] = [
            ("g", [.command], .groupSelectedLayer),
            ("g", [.command, .shift], .ungroupSelectedLayers),
            ("j", [.command], .duplicateSelectionOrLayer),
            ("j", [.command, .shift], .cutSelectionToLayer),
            ("e", [.command], .mergeDown),
            ("r", [.command], .toggleRulers)
        ]

        for (key, modifiers, expected) in protectedActions {
            let action = ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: key,
                modifierFlags: modifiers
            )
            #expect(action == expected)
            #expect(action?.isBlockedByTextInput == true)
        }
    }

    @Test func textIndentationKeysCannotReorderDocumentLayers() {
        let protectedActions: [(String, NSEvent.ModifierFlags, ImageEditorKeyboardShortcutAction)] = [
            ("]", [.command], .layerUp),
            ("]", [.command, .shift], .layerTop),
            ("[", [.command], .layerDown),
            ("[", [.command, .shift], .layerBottom)
        ]

        for (key, modifiers, expected) in protectedActions {
            let action = ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: key,
                modifierFlags: modifiers
            )
            #expect(action == expected)
            #expect(action?.isBlockedByTextInput == true)
        }
    }
}
