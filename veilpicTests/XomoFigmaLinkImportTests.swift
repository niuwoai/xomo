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
        #expect(draft.canUseCanonicalURL)

        let originalPreview = preview
        let didUseCanonicalURL = draft.useCanonicalURL()
        #expect(didUseCanonicalURL)
        #expect(draft.input == preview.canonicalURL.absoluteString)
        #expect(draft.preview?.resourceType == originalPreview.resourceType)
        #expect(draft.preview?.fileKey == originalPreview.fileKey)
        #expect(draft.preview?.nodeID == originalPreview.nodeID)
        #expect(draft.preview?.startingPointNodeID == originalPreview.startingPointNodeID)
        #expect(draft.preview?.versionID == originalPreview.versionID)
        #expect(draft.preview?.canonicalURL == originalPreview.canonicalURL)
        #expect(draft.preview?.discardedQueryItemCount == 0)
        #expect(!draft.canUseCanonicalURL)
        let didReuseCanonicalURL = draft.useCanonicalURL()
        #expect(!didReuseCanonicalURL)

        draft.updateInput("https://figma.example/design/abc123DEF456/Checkout")
        #expect(draft.preview == nil)
        #expect(draft.error == .untrustedHost)
        #expect(!draft.canCopyCanonicalURL)
        #expect(!draft.canUseCanonicalURL)
        let didUseInvalidURL = draft.useCanonicalURL()
        #expect(!didUseInvalidURL)

        draft.updateInput("   ")
        #expect(draft.state == .empty)
        #expect(draft.error == nil)
    }

    @Test func draftCanStartWithACanonicalClipboardLink() throws {
        let draft = XomoFigmaLinkImportDraft(
            input: "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2"
        )

        let preview = try #require(draft.preview)
        #expect(draft.input == preview.canonicalURL.absoluteString)
        #expect(preview.fileKey == "abc123DEF456")
        #expect(preview.nodeID == "1:2")
        #expect(!draft.canUseCanonicalURL)
    }

    @Test func draftCanRetargetAFileLinkWithoutLosingVersionIdentity() throws {
        var draft = XomoFigmaLinkImportDraft(
            input: "https://www.figma.com/design/abc123DEF456/Checkout?starting-point-node-id=0-3&version-id=42&utm_source=mail"
        )
        let originalInput = draft.input

        let didRejectUnsafeNode = draft.retarget(toNodeID: "../../outside")
        #expect(!didRejectUnsafeNode)
        #expect(draft.input == originalInput)
        #expect(draft.preview?.nodeID == nil)

        let didSelectNode = draft.retarget(toNodeID: "  I32:9;44:5  ")
        #expect(didSelectNode)
        #expect(draft.preview?.fileKey == "abc123DEF456")
        #expect(draft.preview?.nodeID == "I32:9;44:5")
        #expect(draft.preview?.startingPointNodeID == "0:3")
        #expect(draft.preview?.versionID == "42")

        #expect(draft.preview?.discardedQueryItemCount == 0)
        #expect(
            draft.input ==
                "https://www.figma.com/design/abc123DEF456/Checkout?node-id=I32-9%3B44-5&starting-point-node-id=0-3&version-id=42"
        )

        let didReplaceNode = draft.retarget(toNodeID: "64-7")
        #expect(didReplaceNode)
        #expect(draft.preview?.nodeID == "64:7")
        #expect(draft.preview?.startingPointNodeID == "0:3")
        #expect(draft.preview?.versionID == "42")

        let stableDraft = draft
        let didReuseNode = draft.retarget(toNodeID: "64:7")
        #expect(didReuseNode)
        #expect(draft == stableDraft)
    }

    @Test func contextualPastePrefersLayerPayloadAndAcceptsOnlyTrustedFigmaLinks() {
        let copiedLink = " https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2&token=discarded "

        #expect(
            XomoFigmaClipboardPastePolicy.resolve(
                hasLayerPayload: true,
                clipboardText: copiedLink
            ) == .layerPayload
        )
        #expect(
            XomoFigmaClipboardPastePolicy.resolve(
                hasLayerPayload: false,
                clipboardText: copiedLink
            ) == .figmaLink(
                "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2"
            )
        )

        for rejectedText in [
            nil,
            "ordinary layer name",
            "http://www.figma.com/design/abc123DEF456/Checkout",
            "https://figma.example/design/abc123DEF456/Checkout"
        ] as [String?] {
            #expect(
                XomoFigmaClipboardPastePolicy.resolve(
                    hasLayerPayload: false,
                    clipboardText: rejectedText
                ) == .unavailable
            )
        }
    }

    @Test func canvasURLDropKeepsLocalFilesAndAcceptsOneTrustedFigmaLink() throws {
        let png = URL(fileURLWithPath: "/tmp/Poster.PNG")
        let svg = URL(fileURLWithPath: "/tmp/Icon.svg")
        let figma = try #require(URL(
            string: "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2&tracking=discarded"
        ))

        #expect(XomoCanvasURLDropPolicy.resolve([png, svg]) == .localFiles([png, svg]))
        #expect(
            XomoCanvasURLDropPolicy.resolve([figma]) == .figmaLink(
                "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2"
            )
        )
    }

    @Test func canvasURLDropRejectsAmbiguousOrUntrustedRemoteURLs() throws {
        let png = URL(fileURLWithPath: "/tmp/Poster.PNG")
        let figma = try #require(URL(
            string: "https://www.figma.com/design/abc123DEF456/Checkout"
        ))
        let secondFigma = try #require(URL(
            string: "https://www.figma.com/file/XYZ789abc012/Library"
        ))
        let insecure = try #require(URL(
            string: "http://www.figma.com/design/abc123DEF456/Checkout"
        ))
        let impostor = try #require(URL(
            string: "https://figma.example/design/abc123DEF456/Checkout"
        ))

        #expect(XomoCanvasURLDropPolicy.resolve([]) == .unavailable)
        #expect(XomoCanvasURLDropPolicy.resolve([figma, secondFigma]) == .unavailable)
        #expect(XomoCanvasURLDropPolicy.resolve([png, figma]) == .unavailable)
        #expect(XomoCanvasURLDropPolicy.resolve([insecure]) == .unavailable)
        #expect(XomoCanvasURLDropPolicy.resolve([impostor]) == .unavailable)
    }

    @Test func canvasStringDropKeepsComponentsAheadOfTrustedFigmaLinks() {
        let componentPayloads: Set<String> = ["button", "image"]
        let figma = " https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2&tracking=discarded "

        #expect(
            XomoCanvasStringDropPolicy.resolve(
                ["button"],
                knownComponentPayloads: componentPayloads
            ) == .componentPayload("button")
        )
        #expect(
            XomoCanvasStringDropPolicy.resolve(
                [figma],
                knownComponentPayloads: componentPayloads
            ) == .figmaLink(
                "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2"
            )
        )
    }

    @Test func canvasStringDropRejectsMultipleValuesOrdinaryTextAndUnsafeLinks() {
        let componentPayloads: Set<String> = ["button"]
        let figma = "https://www.figma.com/design/abc123DEF456/Checkout"

        for values in [
            [],
            ["button", figma],
            ["ordinary layer name"],
            ["http://www.figma.com/design/abc123DEF456/Checkout"],
            ["https://figma.example/design/abc123DEF456/Checkout"]
        ] {
            #expect(
                XomoCanvasStringDropPolicy.resolve(
                    values,
                    knownComponentPayloads: componentPayloads
                ) == .unavailable
            )
        }
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

        #expect(menu.contains("var xomoFileCommandActions: XomoFileCommandActions"))
        #expect(menu.contains("importFigmaLink: { performFileCommand(.importFigmaLink) }"))
        #expect(menu.contains("case .importFigmaLink:"))
        #expect(menu.contains("isFigmaLinkImportPresented = true"))
        #expect(applicationCommands.contains("case .importFigmaLink:"))
        #expect(applicationCommands.contains("imageEditor.action.figmaLinkImport"))
        #expect(applicationCommands.contains(".keyboardShortcut(\"f\", modifiers: [.command, .option])"))
        #expect(editor.contains("pendingFigmaLinkImportInput = nil"))
        #expect(editor.contains("pendingFigmaLinkImportPlacementCenter = nil"))
        #expect(editor.contains("initialLink: pendingFigmaLinkImportInput"))
        #expect(editor.contains("placementCenter: pendingFigmaLinkImportPlacementCenter"))
        #expect(editor.contains("case .pasteAsLayer: performContextualPasteAsLayer()"))
        #expect(editor.contains("XomoFigmaClipboardPastePolicy.resolve("))
        #expect(editor.contains("XomoCanvasStringDropPolicy.resolve("))
        #expect(editor.contains("case let .componentPayload(rawValue):"))
        #expect(editor.contains("XomoCanvasURLDropPolicy.resolve(urls)"))
        #expect(editor.contains("case let .figmaLink(canonicalURL):"))
        #expect(editor.contains("placementCenter: canvasPoint"))
        #expect(menu.contains("func presentFigmaLinkImport("))
        #expect(menu.contains("pendingFigmaLinkImportPlacementCenter = placementCenter"))
        #expect(menu.contains("presentFigmaLinkImport(placementCenter: viewModel.visibleCanvasCenter)"))
        #expect(editor.contains("placementCenter: viewModel.visibleCanvasCenter"))
        #expect(menu.contains("pasteAsLayerTitleKey: contextualPasteAsLayerTitleKey"))
        #expect(menu.contains("return \"imageEditor.action.pasteFigmaLink\""))
        #expect(applicationCommands.contains("actions?.pasteAsLayerTitleKey"))
        #expect(
            editor.contains(
                "case .openFigmaLinkImport: performFileCommand(.importFigmaLink)"
            )
        )
        #expect(sheet.contains("xomo-figma-link-input"))
        #expect(sheet.contains("xomo-figma-copy-canonical-link"))
        #expect(sheet.contains("xomo-figma-use-canonical-link"))
        #expect(sheet.contains("draft.useCanonicalURL()"))
        #expect(sheet.contains("xomo.figma.message.canonicalURLApplied"))
        #expect(sheet.contains("xomo-figma-node-id-input"))
        #expect(sheet.contains("xomo-figma-use-node-id"))
        #expect(sheet.contains("draft.retarget(toNodeID: nodeIDDraft)"))
        #expect(sheet.contains("draft.preview?.nodeID != previousNodeID"))
        #expect(sheet.contains("nodeImportController.clear()"))
        #expect(sheet.contains("XomoFigmaLinkImportDraft"))
        #expect(sheet.contains("NSPasteboard.general"))
        #expect(sheet.contains("placementCenter: CGPoint? = nil"))
        #expect(sheet.contains("centeredAt: placementCenter"))
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
