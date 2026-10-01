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

    @Test func externalOpenFocusRequestIsWiredToEditorAppearanceAndChanges() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("restoreKeyboardFocusAfterExternalOpenIfNeeded()"))
        #expect(source.contains(
            ".onChange(of: externalOpenCoordinator.editorKeyboardFocusRequestID)"
        ))
        #expect(source.contains(
            "externalOpenCoordinator.fulfillEditorKeyboardFocusRequest(requestID)"
        ))
    }

    @Test func externalFigmaWebLocationRequestIsWiredToEditorAppearanceAndChanges() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("presentExternalFigmaLinkImportIfNeeded()"))
        #expect(source.contains(
            ".onChange(of: externalOpenCoordinator.figmaLinkImportRequest?.id)"
        ))
        #expect(source.contains("guard !isFigmaLinkImportPresented"))
        #expect(source.contains(
            "externalOpenCoordinator.fulfillFigmaLinkImportRequest(request.id)"
        ))
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
    @Test func canvasInteractionReclaimsDeleteFromAStaleTextField() {
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

        #expect(ImageEditorFilePanelKeyboardFocusRestorer.claimEditorResponder(in: window))
        #expect(window.firstResponder === keyboardResponder)
        window.orderOut(nil)
    }

    @MainActor
    @Test func selectedImportedLayerReclaimsDeleteWithoutStealingExplicitEditors() {
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

        for editingState in [
            (canvas: true, inlineName: false, constraint: false),
            (canvas: false, inlineName: true, constraint: false),
            (canvas: false, inlineName: false, constraint: true)
        ] {
            #expect(window.makeFirstResponder(staleField))
            #expect(!ImageEditorLayerSelectionKeyboardFocusRestorer.reclaimIfNeeded(
                in: window,
                hasSelectedLayers: true,
                isCanvasTextEditing: editingState.canvas,
                isInlineLayerNameEditing: editingState.inlineName,
                isFigmaSizeConstraintEditing: editingState.constraint
            ))
            #expect(window.firstResponder is NSTextView || window.firstResponder is NSTextField)
        }

        #expect(!ImageEditorLayerSelectionKeyboardFocusRestorer.reclaimIfNeeded(
            in: window,
            hasSelectedLayers: false,
            isCanvasTextEditing: false,
            isInlineLayerNameEditing: false,
            isFigmaSizeConstraintEditing: false
        ))
        #expect(window.firstResponder is NSTextView || window.firstResponder is NSTextField)

        #expect(ImageEditorLayerSelectionKeyboardFocusRestorer.reclaimIfNeeded(
            in: window,
            hasSelectedLayers: true,
            isCanvasTextEditing: false,
            isInlineLayerNameEditing: false,
            isFigmaSizeConstraintEditing: false
        ))
        #expect(window.firstResponder === keyboardResponder)
        window.orderOut(nil)
    }

    @Test func layerSelectionChangesWireKeyboardFocusRecoveryIntoTheEditor() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains(
            ".onChange(of: viewModel.document.selectedLayerIDs) { selectedLayerIDs in"
        ))
        #expect(source.contains(
            "ImageEditorLayerSelectionKeyboardFocusRestorer.reclaimIfNeeded("
        ))
        #expect(source.contains("hasSelectedLayers: !selectedLayerIDs.isEmpty"))
        #expect(source.contains("isCanvasTextEditing: isCanvasTextEditorFocused"))
        #expect(source.contains("isInlineLayerNameEditing: focusedInlineLayerNameID != nil"))
        #expect(source.contains(
            "isFigmaSizeConstraintEditing: focusedFigmaSizeConstraintField != nil"
        ))
    }

    @Test func repeatedLayerPanelSelectionReclaimsDeleteEvenWhenSelectionDoesNotChange() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let panelSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        let selectionFunction = try #require(
            panelSource.components(separatedBy: "private func selectLayerFromPanel").dropFirst().first
        )

        #expect(selectionFunction.contains("viewModel.selectLayer("))
        #expect(selectionFunction.contains("reclaimEditorKeyboardFocusAfterLayerSelection()"))
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

        var deferredRestores: [@MainActor () -> Void] = []
        ImageEditorFilePanelKeyboardFocusRestorer.restore(
            to: window,
            isApplicationActive: true,
            deferredApplicationActivity: { true },
            scheduleDeferredRestore: { deferredRestores.append($0) }
        )
        #expect(window.firstResponder === keyboardResponder)
        #expect(deferredRestores.count == 1)

        // AppKit may complete panel teardown after the completion handler and
        // restore the field editor that owned focus before the import.
        #expect(window.makeFirstResponder(staleField))
        #expect(window.firstResponder is NSTextView || window.firstResponder is NSTextField)

        let restoreAfterTeardown = try #require(deferredRestores.first)
        restoreAfterTeardown()
        #expect(window.firstResponder === keyboardResponder)
        #expect(deferredRestores.count == 2)

        // A second AppKit run-loop turn can still restore the panel's former
        // field editor. The final pass must return Delete to the imported layer.
        #expect(window.makeFirstResponder(staleField))
        let restoreAfterLateTeardown = try #require(deferredRestores.last)
        restoreAfterLateTeardown()
        #expect(window.firstResponder === keyboardResponder)
        #expect(deferredRestores.count == 2)
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

    @Test func textInputFocusPolicyRecognizesAppKitTextControls() throws {
        #expect(ImageEditorTextInputFocusPolicy.isActive(firstResponder: NSTextField()))
        #expect(ImageEditorTextInputFocusPolicy.isActive(firstResponder: NSTextView()))
        #expect(!ImageEditorTextInputFocusPolicy.isActive(firstResponder: NSView()))
        #expect(!ImageEditorTextInputFocusPolicy.isActive(firstResponder: nil))

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("isTextInputActive: isTextInputActiveForDirectShortcut"))
        #expect(source.contains("ImageEditorTextInputFocusPolicy.isActive("))
        #expect(source.contains("firstResponder: NSApp.keyWindow?.firstResponder"))
        #expect(source.contains("&& !isTextInputActive"))
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
