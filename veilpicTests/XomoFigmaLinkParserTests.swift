import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoFigmaLinkParserTests {
    @Test func parsesDesignSelectionAndBuildsSanitizedCanonicalURL() throws {
        let preview = try XomoFigmaLinkParser.parse(
            "  https://www.figma.com/design/abttA1F3GxZdZlkI9t5s99/Example-Figma-file?node-id=32-9&version-id=1234567890&t=secret&token=never-store  "
        )

        #expect(preview.resourceType == .design)
        #expect(preview.fileKey == "abttA1F3GxZdZlkI9t5s99")
        #expect(preview.fileSlug == "Example-Figma-file")
        #expect(preview.displayName == "Example Figma file")
        #expect(preview.nodeID == "32:9")
        #expect(preview.startingPointNodeID == nil)
        #expect(preview.versionID == "1234567890")
        #expect(preview.discardedQueryItemCount == 2)
        #expect(preview.authorizationState == .notChecked)
        #expect(preview.plannedImportScope == .designDocument)
        #expect(
            preview.canonicalURL.absoluteString ==
                "https://www.figma.com/design/abttA1F3GxZdZlkI9t5s99/Example-Figma-file?node-id=32-9&version-id=1234567890"
        )
        #expect(!preview.canonicalURL.absoluteString.contains("secret"))
        #expect(!preview.canonicalURL.absoluteString.contains("token"))
    }

    @Test func recognizesCurrentOfficialFigmaResourcePathsAndLegacyFiles() throws {
        let expectations: [(String, XomoFigmaResourceType, XomoFigmaPlannedImportScope)] = [
            ("design", .design, .designDocument),
            ("file", .legacyFile, .designDocument),
            ("proto", .prototype, .designDocument),
            ("board", .figJam, .figJamBoard),
            ("slides", .slides, .previewOnly),
            ("deck", .slideDeck, .previewOnly),
            ("site", .site, .previewOnly),
            ("buzz", .buzz, .previewOnly),
            ("make", .make, .previewOnly)
        ]

        for (path, expectedType, expectedScope) in expectations {
            let preview = try XomoFigmaLinkParser.parse(
                "https://figma.com/\(path)/abc123DEF456/Shared-Work"
            )
            #expect(preview.resourceType == expectedType)
            #expect(preview.plannedImportScope == expectedScope)
            #expect(preview.canonicalURL.host == "www.figma.com")
        }
    }

    @Test func parsesPrototypeStartingPointAndNormalizesNestedNodeIDs() throws {
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/proto/abc123DEF456/Checkout?node-id=I32-9%3B44-5&starting-point-node-id=0-3"
        )

        #expect(preview.resourceType == .prototype)
        #expect(preview.nodeID == "I32:9;44:5")
        #expect(preview.startingPointNodeID == "0:3")
        #expect(
            preview.canonicalURL.absoluteString ==
                "https://www.figma.com/proto/abc123DEF456/Checkout?node-id=I32-9%3B44-5&starting-point-node-id=0-3"
        )
    }

    @Test func sourceOpenPolicyRetargetsCanonicalLinkToTheSelectedLayerNode() throws {
        let sourceURL = try #require(URL(
            string: "https://figma.com/design/abc123/Checkout?node-id=10-20&version-id=7&utm_source=mail"
        ))

        #expect(
            XomoFigmaSourceOpenPolicy.canonicalURL(
                from: sourceURL,
                selectingNodeID: "I32:9;44:5"
            )?.absoluteString ==
                "https://www.figma.com/design/abc123/Checkout?node-id=I32-9%3B44-5&version-id=7"
        )
        #expect(
            XomoFigmaSourceOpenPolicy.canonicalURL(from: sourceURL)?.absoluteString ==
                "https://www.figma.com/design/abc123/Checkout?node-id=10-20&version-id=7"
        )
        #expect(
            XomoFigmaSourceOpenPolicy.canonicalURL(
                from: sourceURL,
                selectingNodeID: "../../outside"
            ) == nil
        )
    }

    @Test func rejectsInsecureSpoofedCredentialAndCustomPortURLs() {
        let unsafeURLs = [
            "http://www.figma.com/design/abc123DEF456/File",
            "https://www.figma.com.evil.example/design/abc123DEF456/File",
            "https://evil.example@www.figma.com/design/abc123DEF456/File",
            "https://www.figma.com:443/design/abc123DEF456/File"
        ]

        for unsafeURL in unsafeURLs {
            #expect(throws: XomoFigmaLinkParserError.self) {
                try XomoFigmaLinkParser.parse(unsafeURL)
            }
        }
    }

    @Test func rejectsUnsupportedRoutesAndMalformedFileIdentity() {
        let invalidURLs = [
            "https://www.figma.com/community/file/abc123DEF456/File",
            "https://www.figma.com/design/short/File",
            "https://www.figma.com/design/abc123DEF456",
            "https://www.figma.com/design/abc123DEF456/File/extra",
            "not a URL"
        ]

        for invalidURL in invalidURLs {
            #expect(throws: XomoFigmaLinkParserError.self) {
                try XomoFigmaLinkParser.parse(invalidURL)
            }
        }
    }

    @Test func rejectsAmbiguousOrMalformedSelectors() {
        let invalidURLs = [
            "https://www.figma.com/design/abc123DEF456/File?node-id=1-2&node-id=3-4",
            "https://www.figma.com/design/abc123DEF456/File?node-id=1--2",
            "https://www.figma.com/design/abc123DEF456/File?starting-point-node-id=%2Fetc%2Fpasswd",
            "https://www.figma.com/design/abc123DEF456/File?version-id=../../secret"
        ]

        for invalidURL in invalidURLs {
            #expect(throws: XomoFigmaLinkParserError.self) {
                try XomoFigmaLinkParser.parse(invalidURL)
            }
        }
    }

    @Test func codablePreviewNeverPersistsDiscardedQueryValues() throws {
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/board/abc123DEF456/Planning?node-id=1-2&access-token=top-secret"
        )
        let encoded = try JSONEncoder().encode(preview)
        let encodedText = try #require(String(data: encoded, encoding: .utf8))
        let restored = try JSONDecoder().decode(XomoFigmaLinkPreview.self, from: encoded)

        #expect(restored == preview)
        #expect(!encodedText.contains("top-secret"))
        #expect(!encodedText.contains("access-token"))
        #expect(restored.discardedQueryItemCount == 1)
    }

    @Test func rejectsOversizedInputBeforeURLParsing() {
        let oversized = "https://www.figma.com/design/abc123DEF456/" + String(repeating: "a", count: 4_100)

        #expect(throws: XomoFigmaLinkParserError.inputTooLong) {
            try XomoFigmaLinkParser.parse(oversized)
        }
    }
}
