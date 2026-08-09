import AppKit
import Testing
@testable import musepic

struct ImageEditorTextInputShortcutTests {
    @Test func standardTextEditingShortcutsRemainOwnedByTheActiveTextInput() {
        let standardActions: [(String, NSEvent.ModifierFlags, ImageEditorKeyboardShortcutAction)] = [
            ("a", [.command], .selectAll),
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
}
