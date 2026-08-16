import AppKit
import Testing
@testable import musepic

struct ImageEditorTextInputShortcutTests {
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
