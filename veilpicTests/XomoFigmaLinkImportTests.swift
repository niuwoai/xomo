import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoFigmaLinkImportTests {
    @Test func draftValidatesImmediatelyAndKeepsOnlyParsedPreview() throws {
        var draft = XomoFigmaLinkImportDraft()

        #expect(draft.state == .empty)
        #expect(draft.preview == nil)

        draft.updateInput(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2&tracking=discarded"
        )
        let preview = try #require(draft.preview)
        #expect(draft.state == .valid(preview))
        #expect(preview.nodeID == "1:2")
        #expect(preview.discardedQueryItemCount == 1)
        #expect(draft.canCopyCanonicalURL)

        draft.updateInput("https://figma.example/design/abc123DEF456/Checkout")
        #expect(draft.preview == nil)
        #expect(draft.error == .untrustedHost)
        #expect(!draft.canCopyCanonicalURL)

        draft.updateInput("   ")
        #expect(draft.state == .empty)
        #expect(draft.error == nil)
    }

    @Test func everyParserErrorHasUniqueLocalizedPresentationKey() {
        let keys = XomoFigmaLinkParserError.allCases.map(\.localizationKey)

        #expect(Set(keys).count == XomoFigmaLinkParserError.allCases.count)
        #expect(keys.allSatisfy { $0.hasPrefix("xomo.figma.error.") })
    }

    @Test func everyResourceAndScopeHasLocalizedPresentationKey() {
        let resourceKeys = XomoFigmaResourceType.allCases.map(\.localizationKey)
        let scopes: [XomoFigmaPlannedImportScope] = [.designDocument, .figJamBoard, .previewOnly]

        #expect(Set(resourceKeys).count == XomoFigmaResourceType.allCases.count)
        #expect(resourceKeys.allSatisfy { $0.hasPrefix("xomo.figma.resource.") })
        #expect(scopes.map(\.localizationKey).allSatisfy { $0.hasPrefix("xomo.figma.scope.") })
        #expect(XomoFigmaAuthorizationState.notChecked.localizationKey == "xomo.figma.authorization.notChecked")
    }

    @Test func fileMenuAndEditorPresentTheFigmaPreviewSheet() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let menu = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let editor = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let applicationCommands = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoApplicationCommands.swift"),
            encoding: .utf8
        )
        let sheet = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoFigmaLinkImportSheet.swift"),
            encoding: .utf8
        )

        #expect(menu.contains("XomoFileMenuItems(actions: xomoFileCommandActions)"))
        #expect(menu.contains("importFigmaLink: { isFigmaLinkImportPresented = true }"))
        #expect(applicationCommands.contains("case .importFigmaLink:"))
        #expect(applicationCommands.contains("imageEditor.action.figmaLinkImport"))
        #expect(applicationCommands.contains(".keyboardShortcut(\"f\", modifiers: [.command, .option])"))
        #expect(editor.contains(".sheet(isPresented: $isFigmaLinkImportPresented)"))
        #expect(editor.contains("XomoFigmaLinkImportSheet(viewModel: viewModel)"))
        #expect(editor.contains("case .openFigmaLinkImport: isFigmaLinkImportPresented = true"))
        #expect(sheet.contains("xomo-figma-link-input"))
        #expect(sheet.contains("xomo-figma-copy-canonical-link"))
        #expect(sheet.contains("XomoFigmaLinkImportDraft"))
        #expect(sheet.contains("NSPasteboard.general"))
    }

    @Test func keyboardShortcutOpensFigmaLinkImportWithoutConflictingWithImageResize() {
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "f",
                modifierFlags: [.command, .option]
            ) == .openFigmaLinkImport
        )
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "i",
                modifierFlags: [.command, .option]
            ) == .resizeImage
        )
    }

    @Test func selectedLayerFigmaVariableBindingsAreVisibleAndCopyable() throws {
        let image = NSImage(size: NSSize(width: 32, height: 32))
        let viewModel = ImageEditorViewModel(
            sourceName: "Variables",
            image: image,
            onApply: { _ in }
        )
        let selectedID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[viewModel.document.selectedLayerIndex!].xomoFigmaVariableBindings = [
            XomoFigmaVariableBinding(field: "fills", variableID: "VariableID:brand-primary"),
            XomoFigmaVariableBinding(field: "characters", variableID: "VariableID:label")
        ]
        viewModel.document.selectedLayerID = selectedID
        viewModel.document.selectedLayerIDs = [selectedID]

        #expect(viewModel.hasSelectedLayerFigmaVariableBindings)
        #expect(viewModel.selectedLayerFigmaVariableBindings.map(\.field) == ["fills", "characters"])

        viewModel.copyFigmaVariableBinding(viewModel.selectedLayerFigmaVariableBindings[0])
        #expect(NSPasteboard.general.string(forType: .string) == "VariableID:brand-primary")

        viewModel.copySelectedFigmaVariableBindings()
        #expect(
            NSPasteboard.general.string(forType: .string)
                == "VariableID:brand-primary\nVariableID:label"
        )
    }

    @Test func selectedLayerFigmaVariableBindingsBatchCopyIsStableAndDeduplicated() throws {
        let image = NSImage(size: NSSize(width: 32, height: 32))
        let viewModel = ImageEditorViewModel(
            sourceName: "Variables",
            image: image,
            onApply: { _ in }
        )
        let firstID = try #require(viewModel.document.layers.first?.id)
        var second = ImageEditorLayer.blank(name: "Second", size: viewModel.document.canvasSize)
        second.xomoFigmaVariableBindings = [
            XomoFigmaVariableBinding(field: "fills", variableID: "VariableID:brand-primary"),
            XomoFigmaVariableBinding(field: "characters", variableID: "VariableID:label")
        ]
        viewModel.document.layers.append(second)
        viewModel.document.layers[0].xomoFigmaVariableBindings = [
            XomoFigmaVariableBinding(field: "fills", variableID: "VariableID:brand-primary")
        ]
        viewModel.document.selectedLayerID = second.id
        viewModel.document.selectedLayerIDs = [firstID, second.id]

        #expect(viewModel.selectedLayersFigmaVariableBindings.map(\.variableID) == [
            "VariableID:brand-primary",
            "VariableID:label"
        ])
        viewModel.copySelectedFigmaVariableBindings()
        #expect(
            NSPasteboard.general.string(forType: .string)
                == "VariableID:brand-primary\nVariableID:label"
        )
    }

    @Test func propertiesPanelPresentsFigmaVariableBindingsWithoutKeyboardFocus() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("selectedLayersFigmaVariableBindings"))
        #expect(source.contains("image-editor-copy-figma-variables"))
        #expect(source.contains("image-editor-copy-figma-variable-\\(binding.id)"))
        #expect(source.contains("imageEditor.properties.figmaVariables"))
        #expect(source.contains(".focusable(false)"))
    }
}
