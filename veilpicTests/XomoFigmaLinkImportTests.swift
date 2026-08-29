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

    @Test func draftAndContextualPasteAcceptOneFigmaLinkInsideSharedText() throws {
        let sharedText = """
        Checkout review
        https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2&utm_source=chat
        """
        let draft = XomoFigmaLinkImportDraft(input: sharedText)

        #expect(draft.input == sharedText)
        #expect(draft.preview?.nodeID == "1:2")
        #expect(draft.canUseCanonicalURL)
        #expect(
            XomoFigmaClipboardPastePolicy.resolve(
                hasLayerPayload: false,
                clipboardText: sharedText
            ) == .figmaLink(
                "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2"
            )
        )
        #expect(
            XomoCanvasStringDropPolicy.resolve(
                [sharedText],
                knownComponentPayloads: []
            ) == .figmaLink(
                "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2"
            )
        )
    }

    @Test func draftCanRetargetAFileLinkWithoutLosingVersionIdentity() throws {
        var draft = XomoFigmaLinkImportDraft(
            input: "https://www.figma.com/design/abc123DEF456/Checkout?starting-point-node-id=0-3&version-id=42&utm_source=mail"
        )
        let originalInput = draft.input

        let didRejectUnsafeNode = draft.retarget(toNodeInput: "../../outside")
        #expect(!didRejectUnsafeNode)
        #expect(draft.input == originalInput)
        #expect(draft.preview?.nodeID == nil)

        let didSelectNode = draft.retarget(toNodeInput: "  I32:9;44:5  ")
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

        let didReplaceNode = draft.retarget(toNodeInput: "64-7")
        #expect(didReplaceNode)
        #expect(draft.preview?.nodeID == "64:7")
        #expect(draft.preview?.startingPointNodeID == "0:3")
        #expect(draft.preview?.versionID == "42")

        let stableDraft = draft
        let didReuseNode = draft.retarget(toNodeInput: "64:7")
        #expect(didReuseNode)
        #expect(draft == stableDraft)
    }

    @Test func draftAcceptsOnlyTrustedSameFileNodeLinksAsNodeInput() {
        var draft = XomoFigmaLinkImportDraft(
            input: "https://www.figma.com/design/abc123DEF456/Checkout?version-id=42"
        )

        let didUseNodeLink = draft.retarget(
            toNodeInput: " https://figma.com/proto/abc123DEF456/Another-Name?node-id=9-8&version-id=99&utm_source=mail "
        )
        #expect(didUseNodeLink)
        #expect(draft.preview?.resourceType == .design)
        #expect(draft.preview?.fileSlug == "Checkout")
        #expect(draft.preview?.nodeID == "9:8")
        #expect(draft.preview?.versionID == "42")
        #expect(
            draft.input ==
                "https://www.figma.com/design/abc123DEF456/Checkout?node-id=9-8&version-id=42"
        )

        let stableDraft = draft
        for rejectedInput in [
            "https://www.figma.com/design/otherFile999/Other?node-id=1-2",
            "https://www.figma.com/design/abc123DEF456/Checkout",
            "https://figma.example/design/abc123DEF456/Checkout?node-id=1-2"
        ] {
            let didRetarget = draft.retarget(toNodeInput: rejectedInput)
            #expect(!didRetarget)
            #expect(draft == stableDraft)
        }
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

    @Test func contextualPasteReadsRichLinkTargetsAndRejectsSpoofedOrConflictingRepresentations() {
        let figma = "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2&utm_source=mail"
        let canonical = "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2"

        #expect(
            XomoFigmaClipboardPastePolicy.resolve(
                hasLayerPayload: false,
                clipboardText: "查看设计",
                clipboardURLString: figma
            ) == .figmaLink(canonical)
        )
        #expect(
            XomoFigmaClipboardPastePolicy.resolve(
                hasLayerPayload: true,
                clipboardText: "查看设计",
                clipboardURLString: figma
            ) == .layerPayload
        )
        #expect(
            XomoFigmaClipboardPastePolicy.resolve(
                hasLayerPayload: false,
                clipboardText: canonical,
                clipboardURLString: "https://www.figma.com.evil.example/design/abc123DEF456/Checkout"
            ) == .unavailable
        )
        #expect(
            XomoFigmaClipboardPastePolicy.resolve(
                hasLayerPayload: false,
                clipboardText: canonical,
                clipboardURLString: "https://www.figma.com/design/otherFile999/Other"
            ) == .unavailable
        )
    }

    @Test func fileImportPrefillAcceptsTrustedClipboardLinksAndRejectsConflictingRepresentations() {
        let figma = "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2&utm_source=mail"
        let canonical = "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2"

        #expect(
            XomoFigmaClipboardLinkPolicy.canonicalURL(
                clipboardText: "查看设计",
                clipboardURLString: figma
            ) == canonical
        )
        #expect(
            XomoFigmaClipboardLinkPolicy.canonicalURL(
                clipboardText: "设计链接：\(figma)"
            ) == canonical
        )
        #expect(
            XomoFigmaClipboardLinkPolicy.canonicalURL(
                clipboardText: canonical,
                clipboardURLString: "https://www.figma.com/design/otherFile999/Other"
            ) == nil
        )
        #expect(
            XomoFigmaClipboardLinkPolicy.canonicalURL(
                clipboardText: "普通文字",
                clipboardURLString: "https://www.figma.com.evil.example/design/abc123DEF456/Checkout"
            ) == nil
        )
    }

    @Test func canonicalLinkCopyWritesFourInteroperableRepresentationsAsOneTrustedItem() throws {
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("im.some.xomo.tests.figma-link.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        let source = try #require(URL(
            string: "https://figma.com/design/abc123DEF456/Checkout-Review?node-id=1-2&utm_source=xomo"
        ))
        let canonical = "https://www.figma.com/design/abc123DEF456/Checkout-Review?node-id=1-2"

        #expect(XomoFigmaClipboardWriter.writeCanonicalURL(source, to: pasteboard))
        #expect(pasteboard.pasteboardItems?.count == 1)
        #expect(pasteboard.string(forType: .string) == canonical)
        #expect(pasteboard.string(forType: .URL) == canonical)
        let htmlData = try #require(pasteboard.data(forType: .html))
        let rtfData = try #require(pasteboard.data(forType: .rtf))
        let itemTypes = Set(pasteboard.pasteboardItems?.first?.types ?? [])
        #expect(Set([.string, .URL, .html, .rtf]).isSubset(of: itemTypes))
        let htmlLink = try NSAttributedString(
            data: htmlData,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        )
        let rtfLink = try NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        #expect(htmlLink.string.trimmingCharacters(in: .newlines) == "Checkout Review")
        #expect(rtfLink.string == "Checkout Review")
        #expect(XomoFigmaRichClipboardLinkExtractor.targets(from: pasteboard) == [canonical])
        #expect(
            XomoFigmaClipboardPastePolicy.resolve(
                hasLayerPayload: false,
                clipboardText: pasteboard.string(forType: .string),
                clipboardURLString: pasteboard.string(forType: .URL),
                clipboardRichLinkTargets: XomoFigmaRichClipboardLinkExtractor.targets(
                    from: pasteboard
                )
            ) == .figmaLink(canonical)
        )

        pasteboard.clearContents()
        #expect(pasteboard.setString("keep me", forType: .string))
        let untrusted = try #require(URL(
            string: "https://www.figma.com.evil.example/design/abc123DEF456/Checkout"
        ))
        #expect(!XomoFigmaClipboardWriter.writeCanonicalURL(untrusted, to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "keep me")
        #expect(pasteboard.string(forType: .URL) == nil)
        #expect(pasteboard.data(forType: .html) == nil)
        #expect(pasteboard.data(forType: .rtf) == nil)
    }

    @Test func clipboardPasteButtonReadsURLRepresentationsWithoutBypassingTextValidation() {
        let figma = "https://figma.com/design/abc123DEF456/Checkout?node-id=1-2&utm_source=mail"
        let canonical = "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2"

        #expect(
            XomoFigmaClipboardInputPolicy.resolve(
                clipboardText: nil,
                clipboardURLString: figma
            ) == .input(canonical)
        )
        #expect(
            XomoFigmaClipboardInputPolicy.resolve(
                clipboardText: "查看设计",
                clipboardURLString: figma
            ) == .input(canonical)
        )
        #expect(
            XomoFigmaClipboardInputPolicy.resolve(
                clipboardText: "not a link"
            ) == .input("not a link")
        )
        #expect(
            XomoFigmaClipboardInputPolicy.resolve(
                clipboardText: nil
            ) == .empty
        )
        #expect(
            XomoFigmaClipboardInputPolicy.resolve(
                clipboardText: canonical,
                clipboardURLString: "https://www.figma.com/design/otherFile999/Other"
            ) == .rejected
        )
        #expect(
            XomoFigmaClipboardInputPolicy.resolve(
                clipboardText: "查看设计",
                clipboardURLString: "https://www.figma.com.evil.example/design/abc123DEF456/Checkout"
            ) == .rejected
        )
    }

    @Test func clipboardRoutesReadHTMLAndRTFLinkTargetsAndRejectConflicts() throws {
        let figma = "https://figma.com/design/abc123DEF456/Checkout?node-id=1-2&utm_source=mail"
        let canonical = "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2"
        let htmlData = try #require(
            "<p><a href=\"\(figma)\">查看设计</a></p>".data(using: .utf8)
        )
        let attributedString = NSMutableAttributedString(string: "View in Figma")
        attributedString.addAttribute(
            .link,
            value: figma,
            range: NSRange(location: 0, length: attributedString.length)
        )
        let rtfData = try attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )

        let sharedTargets = XomoFigmaRichClipboardLinkExtractor.targets(
            htmlData: htmlData,
            rtfData: rtfData
        )
        #expect(sharedTargets == [figma])
        let pasteboard = NSPasteboard(name: .init("xomo-figma-rich-link-\(UUID().uuidString)"))
        pasteboard.declareTypes([.html, .rtf], owner: nil)
        #expect(pasteboard.setData(htmlData, forType: .html))
        #expect(pasteboard.setData(rtfData, forType: .rtf))
        #expect(XomoFigmaRichClipboardLinkExtractor.targets(from: pasteboard) == [figma])
        #expect(
            XomoFigmaClipboardLinkPolicy.canonicalURL(
                clipboardText: "查看设计",
                clipboardRichLinkTargets: sharedTargets
            ) == canonical
        )
        #expect(
            XomoFigmaClipboardInputPolicy.resolve(
                clipboardText: "查看设计",
                clipboardRichLinkTargets: sharedTargets
            ) == .input(canonical)
        )
        #expect(
            XomoFigmaClipboardPastePolicy.resolve(
                hasLayerPayload: false,
                clipboardText: "View in Figma",
                clipboardRichLinkTargets: sharedTargets
            ) == .figmaLink(canonical)
        )

        let conflictingHTMLData = try #require(
            """
            <a href="https://www.figma.com/design/abc123DEF456/Checkout">First</a>
            <a href="https://www.figma.com/design/otherFile999/Other">Second</a>
            """.data(using: .utf8)
        )
        let conflictingTargets = XomoFigmaRichClipboardLinkExtractor.targets(
            htmlData: conflictingHTMLData
        )
        #expect(conflictingTargets.count == 2)
        #expect(
            XomoFigmaClipboardInputPolicy.resolve(
                clipboardText: "Two designs",
                clipboardRichLinkTargets: conflictingTargets
            ) == .rejected
        )
        #expect(
            XomoFigmaClipboardPastePolicy.resolve(
                hasLayerPayload: false,
                clipboardText: canonical,
                clipboardRichLinkTargets: [
                    "https://www.figma.com.evil.example/design/abc123DEF456/Checkout"
                ]
            ) == .unavailable
        )
        #expect(
            XomoFigmaClipboardLinkPolicy.canonicalURL(
                clipboardText: canonical,
                clipboardURLString: canonical,
                clipboardRichLinkTargets: [
                    "https://www.figma.com/design/otherFile999/Other"
                ]
            ) == nil
        )
    }

    @Test func canvasRichLinkDropAcceptsOneTrustedTargetAndRejectsConflicts() throws {
        let figma = "https://figma.com/design/abc123DEF456/Checkout?node-id=1-2&utm_source=mail"
        let canonical = "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-2"
        let htmlData = try #require(
            "<a href=\"\(figma)\">查看设计</a>".data(using: .utf8)
        )
        let attributedString = NSAttributedString(
            string: "View in Figma",
            attributes: [.link: figma]
        )
        let rtfData = try attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )

        #expect(
            XomoCanvasRichLinkDropPolicy.resolve(
                htmlData: htmlData,
                rtfData: rtfData
            ) == .figmaLink(canonical)
        )
        #expect(XomoCanvasRichLinkDropPolicy.resolve() == .unavailable)
        let conflictingHTMLData = try #require(
            "<a href=\"https://www.figma.com/design/otherFile999/Other\">Other</a>"
                .data(using: .utf8)
        )
        #expect(
            XomoCanvasRichLinkDropPolicy.resolve(
                htmlData: conflictingHTMLData,
                rtfData: rtfData
            ) == .unavailable
        )
        let spoofedHTMLData = try #require(
            "<a href=\"https://www.figma.com.evil.example/design/abc123DEF456/Checkout\">Fake</a>"
                .data(using: .utf8)
        )
        #expect(
            XomoCanvasRichLinkDropPolicy.resolve(htmlData: spoofedHTMLData) == .unavailable
        )
        #expect(
            XomoCanvasRichLinkDropPolicy.resolve(
                htmlData: Data("not html".utf8)
            ) == .unavailable
        )
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
        #expect(menu.contains("canonicalURL: XomoFigmaClipboardLinkPolicy.canonicalURL("))
        #expect(menu.contains("clipboardRichLinkTargets: XomoFigmaRichClipboardLinkExtractor.targets("))
        #expect(menu.contains("clipboardText: NSPasteboard.general.string(forType: .string)"))
        #expect(menu.contains("clipboardURLString: NSPasteboard.general.string(forType: .URL)"))
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
        #expect(editor.contains("XomoFigmaRichClipboardLinkExtractor.targets("))
        #expect(editor.contains("clipboardURLString: pasteboard.string(forType: .URL)"))
        #expect(editor.contains("XomoCanvasStringDropPolicy.resolve("))
        #expect(editor.contains("case let .componentPayload(rawValue):"))
        #expect(editor.contains("XomoCanvasURLDropPolicy.resolve(urls)"))
        #expect(editor.contains("case let .figmaLink(canonicalURL):"))
        #expect(editor.contains("placementCenter: canvasPoint"))
        #expect(menu.contains("func presentFigmaLinkImport("))
        #expect(menu.contains("pendingFigmaLinkImportPlacementCenter = placementCenter"))
        #expect(menu.contains("placementCenter: viewModel.visibleCanvasCenter"))
        #expect(editor.contains("placementCenter: viewModel.visibleCanvasCenter"))
        #expect(menu.contains("pasteAsLayerTitleKey: contextualPasteAsLayerTitleKey"))
        #expect(menu.contains("return \"imageEditor.action.pasteFigmaLink\""))
        #expect(menu.contains("clipboardURLString: NSPasteboard.general.string(forType: .URL)"))
        #expect(applicationCommands.contains("actions?.pasteAsLayerTitleKey"))
        #expect(
            editor.contains(
                "case .openFigmaLinkImport: performFileCommand(.importFigmaLink)"
            )
        )
        #expect(sheet.contains("xomo-figma-link-input"))
        #expect(sheet.contains("XomoFigmaClipboardInputPolicy.resolve("))
        #expect(sheet.contains("clipboardURLString: NSPasteboard.general.string(forType: .URL)"))
        #expect(sheet.contains("clipboardRichLinkTargets: XomoFigmaRichClipboardLinkExtractor.targets("))
        #expect(sheet.contains("case .rejected:"))
        #expect(sheet.contains("xomo.figma.clipboard.untrusted"))
        #expect(sheet.contains("xomo-figma-copy-canonical-link"))
        #expect(sheet.contains("XomoFigmaClipboardWriter.writeCanonicalURL(draft.preview?.canonicalURL)"))
        #expect(sheet.contains("xomo-figma-use-canonical-link"))
        #expect(sheet.contains("draft.useCanonicalURL()"))
        #expect(sheet.contains("xomo.figma.message.canonicalURLApplied"))
        #expect(sheet.contains("xomo-figma-node-id-input"))
        #expect(sheet.contains("xomo-figma-use-node-id"))
        #expect(sheet.contains(".submitLabel(.done)"))
        #expect(sheet.contains(".onSubmit {"))
        #expect(sheet.contains("guard canApplyNodeSelection else { return }"))
        #expect(sheet.contains(".disabled(!canApplyNodeSelection)"))
        #expect(sheet.contains("draft.retarget(toNodeInput: nodeIDDraft)"))
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
