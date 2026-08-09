//
//  XomoFigmaNodeImportPlanTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/15.
//

import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoFigmaNodeImportPlanTests {
    @Test func supportedTextCaseStylesMapToNativeEditableSemantics() {
        #expect(XomoFigmaNodeImportMapper.characters("Hello 世界", applying: "UPPER") == "HELLO 世界")
        #expect(XomoFigmaNodeImportMapper.characters("Hello 世界", applying: "LOWER") == "hello 世界")
        #expect(XomoFigmaNodeImportMapper.characters("hello world", applying: "TITLE") == "Hello World")
        #expect(XomoFigmaNodeImportMapper.characters("Hello", applying: "ORIGINAL") == "Hello")
        #expect(XomoFigmaNodeImportMapper.characters("Hello", applying: "SMALL_CAPS") == "HELLO")
        #expect(XomoFigmaNodeImportMapper.mappedTextCase("UPPER") == .uppercase)
        #expect(XomoFigmaNodeImportMapper.mappedTextCase("LOWER") == .lowercase)
        #expect(XomoFigmaNodeImportMapper.mappedTextCase("TITLE") == .titleCase)
        #expect(XomoFigmaNodeImportMapper.mappedTextCase("ORIGINAL") == .original)
        #expect(XomoFigmaNodeImportMapper.mappedTextCase("SMALL_CAPS") == .smallCaps)
    }

    @Test func figmaTextCaseRemainsEditableAndSurvivesProjectRoundTrip() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:7":{"document":{"id":"1:7","name":"Label","type":"TEXT","characters":"Continue 继续","style":{"fontSize":16,"textCase":"UPPER"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":24}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:7")
        let item = try #require(plan.items.first)
        #expect(item.text?.characters == "Continue 继续")
        #expect(item.text?.textCase == .uppercase)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.textCaseFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let layer = try #require(result.layers.first)
        guard case let .text(content) = layer.kind else {
            Issue.record("Figma text case should remain editable text")
            return
        }
        #expect(content.text == "Continue 继续")
        #expect(content.textCase == .uppercase)
        #expect(content.attributedString.string == "CONTINUE 继续")

        let data = try JSONEncoder().encode(ImageEditorProjectTextContent(content: content))
        let restored = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: data).textContent
        #expect(restored.text == "Continue 继续")
        #expect(restored.textCase == .uppercase)
        #expect(restored.attributedString.string == "CONTINUE 继续")
    }

    @Test func figmaSmallCapsRemainsNativeEditableTypography() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:8":{"document":{"id":"1:8","name":"Label","type":"TEXT","characters":"Caption","style":{"fontSize":16,"textCase":"SMALL_CAPS"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":24}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:8")
        let item = try #require(plan.items.first)
        #expect(item.text?.textCase == .smallCaps)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.textCaseFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let content = try #require(result.layers.first?.textContent)
        #expect(content.text == "Caption")
        #expect(content.displayText == "CAPTION")
        #expect(content.attributedString.string == "CAPTION")
        let leadingFont = try #require(content.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let smallCapsFont = try #require(content.attributedString.attribute(.font, at: 1, effectiveRange: nil) as? NSFont)
        #expect(leadingFont.pointSize == 16)
        #expect(abs(smallCapsFont.pointSize - 12.8) < 0.001)

        let data = try JSONEncoder().encode(ImageEditorProjectTextContent(content: content))
        let restored = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: data).textContent
        #expect(restored.text == "Caption")
        #expect(restored.textCase == .smallCaps)
        #expect(restored.attributedString.string == "CAPTION")
    }

    @Test func figmaLineHeightUsesPixelsBeforeFontSizePercentageFallback() throws {
        let decoder = JSONDecoder()
        let pixels = try decoder.decode(
            XomoFigmaTypeStyle.self,
            from: Data(#"{"fontSize":16,"lineHeightPx":22,"lineHeightPercentFontSize":150}"#.utf8)
        )
        let percent = try decoder.decode(
            XomoFigmaTypeStyle.self,
            from: Data(#"{"fontSize":16,"lineHeightPercentFontSize":137.5}"#.utf8)
        )
        let unitFallback = try decoder.decode(
            XomoFigmaTypeStyle.self,
            from: Data(#"{"fontSize":20,"lineHeightPercent":120,"lineHeightUnit":"FONT_SIZE_%"}"#.utf8)
        )
        let intrinsic = try decoder.decode(
            XomoFigmaTypeStyle.self,
            from: Data(#"{"fontSize":20,"lineHeightPercent":120,"lineHeightUnit":"INTRINSIC_%"}"#.utf8)
        )

        #expect(XomoFigmaNodeImportMapper.lineHeight(for: pixels) == 22)
        #expect(XomoFigmaNodeImportMapper.lineHeight(for: percent) == 22)
        #expect(XomoFigmaNodeImportMapper.lineHeight(for: unitFallback) == 24)
        #expect(XomoFigmaNodeImportMapper.lineHeight(for: intrinsic) == nil)
    }

    @Test func unmappableIntrinsicLineHeightIsReportedAsPartialInsteadOfExact() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:1":{"document":{"id":"1:1","name":"Caption","type":"TEXT","characters":"Caption","style":{"fontSize":16,"lineHeightPercent":120,"lineHeightUnit":"INTRINSIC_%"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":24}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:1")
        let item = try #require(plan.items.first)
        #expect(item.text?.lineHeight == nil)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.textLineHeightFlattened))
    }

    @Test func compressedFigmaLineHeightReportsNativeClampInsteadOfClaimingExactImport() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:2":{"document":{"id":"1:2","name":"Tight Label","type":"TEXT","characters":"One\nTwo","style":{"fontSize":16,"lineHeightPercentFontSize":80},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":32}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:2")
        let item = try #require(plan.items.first)
        #expect(item.text?.lineHeight == 12.8)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.textLineHeightFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let content = try #require(result.layers.first?.textContent)
        #expect(content.fontSize == 16)
        #expect(content.lineSpacing == 0)
    }

    @Test func oversizedFigmaLineHeightReportsAndUsesEditableNativeMaximum() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:16":{"document":{"id":"1:16","name":"Loose Label","type":"TEXT","characters":"One\nTwo","style":{"fontSize":16,"lineHeightPx":200},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":240}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:16")
        let item = try #require(plan.items.first)
        #expect(item.text?.lineHeight == 200)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.textLineHeightFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 320)
        )
        let content = try #require(result.layers.first?.textContent)
        #expect(content.fontSize == 16)
        #expect(content.lineSpacing == ImageEditorTextContent.maximumLineSpacing)
    }

    @Test func figmaParagraphSpacingRemainsEditableAndSurvivesProjectRoundTrip() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:2":{"document":{"id":"1:2","name":"Body","type":"TEXT","characters":"One\nTwo","style":{"fontSize":16,"paragraphSpacing":12},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":48}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:2")
        let item = try #require(plan.items.first)
        #expect(item.text?.characters == "One\nTwo")
        #expect(item.text?.paragraphSpacing == 12)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.textParagraphSpacingFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let layer = try #require(result.layers.first)
        guard case let .text(content) = layer.kind else {
            Issue.record("Figma paragraph spacing should remain editable text")
            return
        }
        #expect(content.paragraphSpacing == 12)

        let data = try JSONEncoder().encode(ImageEditorProjectTextContent(content: content))
        let restored = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: data).textContent
        #expect(restored.paragraphSpacing == 12)
        #expect(restored.requiredParagraphHeight == content.requiredParagraphHeight)
    }

    @Test func invalidFigmaParagraphSpacingIsReportedAsPartial() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:6":{"document":{"id":"1:6","name":"Body","type":"TEXT","characters":"One\nTwo","style":{"fontSize":16,"paragraphSpacing":-4},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":48}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:6")
        let item = try #require(plan.items.first)
        #expect(item.text?.paragraphSpacing == nil)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.textParagraphSpacingFlattened))
    }

    @Test func oversizedFigmaParagraphSpacingClampsToEditableNativeMaximum() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:12":{"document":{"id":"1:12","name":"Body","type":"TEXT","characters":"One\nTwo","style":{"fontSize":16,"paragraphSpacing":600},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":48}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:12")
        let item = try #require(plan.items.first)
        #expect(item.text?.paragraphSpacing == Double(ImageEditorTextContent.maximumParagraphSpacing))
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.textParagraphSpacingFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let content = try #require(result.layers.first?.textContent)
        #expect(content.paragraphSpacing == ImageEditorTextContent.maximumParagraphSpacing)
    }

    @Test func negativeFigmaParagraphIndentReportsClampInsteadOfClaimingExactImport() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:7":{"document":{"id":"1:7","name":"Body","type":"TEXT","characters":"Indented","style":{"fontSize":16,"paragraphIndent":-8},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":48}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:7")
        let item = try #require(plan.items.first)
        #expect(item.text?.paragraphIndent == 0)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.textParagraphIndentFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        #expect(result.layers.first?.textContent?.firstLineIndent == 0)
    }

    @Test func oversizedFigmaParagraphIndentClampsToEditableNativeMaximum() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:13":{"document":{"id":"1:13","name":"Body","type":"TEXT","characters":"Indented","style":{"fontSize":16,"paragraphIndent":1200},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":48}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:13")
        let item = try #require(plan.items.first)
        #expect(item.text?.paragraphIndent == Double(ImageEditorTextContent.maximumFirstLineIndent))
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.textParagraphIndentFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        #expect(
            result.layers.first?.textContent?.firstLineIndent
                == ImageEditorTextContent.maximumFirstLineIndent
        )
    }

    @Test func outOfRangeFigmaLetterSpacingClampsAndReportsPartialFidelity() throws {
        let cases: [(nodeID: String, source: Double, expected: CGFloat)] = [
            ("1:14", 72, ImageEditorTextContent.maximumCharacterSpacing),
            ("1:15", -12, ImageEditorTextContent.minimumCharacterSpacing)
        ]

        for testCase in cases {
            let json = """
            {"name":"Typography","nodes":{"\(testCase.nodeID)":{"document":{"id":"\(testCase.nodeID)","name":"Tracked","type":"TEXT","characters":"Tracking","style":{"fontSize":16,"letterSpacing":\(testCase.source)},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":48}}}}}
            """
            let response = try JSONDecoder().decode(XomoFigmaNodeResponse.self, from: Data(json.utf8))
            let plan = try XomoFigmaNodeImportMapper.makePlan(
                response: response,
                requestedNodeID: testCase.nodeID
            )
            let item = try #require(plan.items.first)
            #expect(item.text?.letterSpacing == Double(testCase.expected))
            #expect(item.fidelity == .partial)
            #expect(item.issues.contains(.textLetterSpacingFlattened))

            let result = XomoFigmaNodeMaterializer.materialize(
                plan: plan,
                canvasSize: CGSize(width: 320, height: 240)
            )
            #expect(result.layers.first?.textContent?.characterSpacing == testCase.expected)
        }
    }

    @Test func figmaAutoWidthAndHeightTextMaterializesAsEditablePointText() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:3":{"document":{"id":"1:3","name":"Button Label","type":"TEXT","characters":"Continue","style":{"fontSize":16,"textAutoResize":"WIDTH_AND_HEIGHT"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":10,"y":20,"width":72,"height":20}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:3")
        let item = try #require(plan.items.first)
        #expect(item.text?.usesAutoWidthAndHeight == true)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.textAutoResizeFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let layer = try #require(result.layers.first)
        guard case let .text(content) = layer.kind else {
            Issue.record("Figma auto-size text should remain editable text")
            return
        }
        #expect(content.layoutMode == .point)
        #expect(content.boxWidth == 0)
        #expect(content.boxHeight == 0)
    }

    @Test func figmaAutoHeightTextRemainsEditableAndSurvivesProjectRoundTrip() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:4":{"document":{"id":"1:4","name":"Body","type":"TEXT","characters":"One\nTwo","style":{"fontSize":16,"textAutoResize":"HEIGHT"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":48}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:4")
        let item = try #require(plan.items.first)
        #expect(item.text?.usesAutoWidthAndHeight == false)
        #expect(item.text?.usesAutoHeight == true)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.textAutoResizeFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let layer = try #require(result.layers.first)
        guard case let .text(content) = layer.kind else {
            Issue.record("Figma auto-height text should remain editable text")
            return
        }
        #expect(content.layoutMode == .paragraph)
        #expect(content.boxWidth > 0)
        #expect(content.boxHeight == 0)

        var expanded = content
        expanded.text = "One\nTwo\nThree\nFour"
        #expect(expanded.layerSize().height > content.layerSize().height)

        let data = try JSONEncoder().encode(ImageEditorProjectTextContent(content: expanded))
        let restored = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: data).textContent
        #expect(restored.boxWidth == expanded.boxWidth)
        #expect(restored.boxHeight == 0)
        #expect(restored.layerSize() == expanded.layerSize())
    }

    @Test func figmaTextTruncationRemainsEditableAndSurvivesProjectRoundTrip() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:5":{"document":{"id":"1:5","name":"Clamped Body","type":"TEXT","characters":"One\nTwo","style":{"fontSize":16,"textAutoResize":"TRUNCATE"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":48}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:5")
        let item = try #require(plan.items.first)
        #expect(item.text?.usesAutoWidthAndHeight == false)
        #expect(item.text?.usesAutoHeight == false)
        #expect(item.text?.truncatesOverflow == true)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.textAutoResizeFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let content = try #require(result.layers.first?.textContent)
        #expect(content.layoutMode == .paragraph)
        #expect(content.boxWidth > 0)
        #expect(content.boxHeight > 0)
        #expect(content.truncatesOverflow)
        #expect(content.paragraphStyle.lineBreakMode == .byWordWrapping)
        #expect(content.drawingOptions.contains(.truncatesLastVisibleLine))

        let data = try JSONEncoder().encode(ImageEditorProjectTextContent(content: content))
        let restored = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: data).textContent
        #expect(restored.text == "One\nTwo")
        #expect(restored.truncatesOverflow)
        #expect(restored.boxWidth == content.boxWidth)
        #expect(restored.boxHeight == content.boxHeight)
    }

    @Test func figmaHorizontalAlignmentUsesNativeValuesAndReportsUnknownValues() throws {
        #expect(XomoFigmaNodeImportMapper.mappedTextHorizontalAlignment(nil) == .left)
        #expect(XomoFigmaNodeImportMapper.mappedTextHorizontalAlignment("LEFT") == .left)
        #expect(XomoFigmaNodeImportMapper.mappedTextHorizontalAlignment("CENTER") == .center)
        #expect(XomoFigmaNodeImportMapper.mappedTextHorizontalAlignment("RIGHT") == .right)
        #expect(XomoFigmaNodeImportMapper.mappedTextHorizontalAlignment("JUSTIFIED") == .justified)
        #expect(XomoFigmaNodeImportMapper.mappedTextHorizontalAlignment("DISTRIBUTED") == nil)

        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:6":{"document":{"id":"1:6","name":"Centered Label","type":"TEXT","characters":"Centered","style":{"fontSize":16,"textAlignHorizontal":"CENTER"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":40}}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:6")
        let item = try #require(plan.items.first)
        #expect(item.text?.horizontalAlignment == ImageEditorTextAlignment.center.rawValue)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.textHorizontalAlignmentFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        #expect(result.layers.first?.textContent?.alignment == .center)

        let unknownResponse = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:7":{"document":{"id":"1:7","name":"Unknown Alignment","type":"TEXT","characters":"Unknown","style":{"fontSize":16,"textAlignHorizontal":"DISTRIBUTED"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":40}}}}}"#.utf8
            )
        )
        let unknownPlan = try XomoFigmaNodeImportMapper.makePlan(
            response: unknownResponse,
            requestedNodeID: "1:7"
        )
        let unknownItem = try #require(unknownPlan.items.first)
        #expect(unknownItem.text?.horizontalAlignment == nil)
        #expect(unknownItem.fidelity == .partial)
        #expect(unknownItem.issues.contains(.textHorizontalAlignmentFlattened))
        let unknownResult = XomoFigmaNodeMaterializer.materialize(
            plan: unknownPlan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        #expect(unknownResult.layers.first?.textContent?.alignment == .left)
    }

    @Test func figmaFixedTextVerticalAlignmentRemainsNativeAndRoundTrips() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:6":{"document":{"id":"1:6","name":"Centered Label","type":"TEXT","characters":"Centered","style":{"fontSize":16,"textAlignVertical":"CENTER"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:6")
        let item = try #require(plan.items.first)
        #expect(item.text?.verticalAlignment == .center)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.textVerticalAlignmentFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let content = try #require(result.layers.first?.textContent)
        #expect(content.verticalAlignment == .center)
        #expect(content.drawingRect(in: content.layerSize()).minY > content.point.y)

        let data = try JSONEncoder().encode(ImageEditorProjectTextContent(content: content))
        let restored = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: data).textContent
        #expect(restored.verticalAlignment == .center)

        let unknownResponse = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:7":{"document":{"id":"1:7","name":"Unknown Alignment","type":"TEXT","characters":"Unknown","style":{"fontSize":16,"textAlignVertical":"JUSTIFIED"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}}}}}"#.utf8
            )
        )
        let unknownPlan = try XomoFigmaNodeImportMapper.makePlan(
            response: unknownResponse,
            requestedNodeID: "1:7"
        )
        let unknownItem = try #require(unknownPlan.items.first)
        #expect(unknownItem.text?.verticalAlignment == .top)
        #expect(unknownItem.fidelity == .partial)
        #expect(unknownItem.issues.contains(.textVerticalAlignmentFlattened))
    }

    @Test func figmaTextDecorationUsesTypedNativeMappingAndReportsUnknownValues() throws {
        #expect(XomoFigmaNodeImportMapper.mappedTextDecoration(nil) == XomoFigmaPlanTextDecoration.none)
        #expect(XomoFigmaNodeImportMapper.mappedTextDecoration("NONE") == XomoFigmaPlanTextDecoration.none)
        #expect(XomoFigmaNodeImportMapper.mappedTextDecoration("UNDERLINE") == .underline)
        #expect(XomoFigmaNodeImportMapper.mappedTextDecoration("STRIKETHROUGH") == .strikethrough)
        #expect(XomoFigmaNodeImportMapper.mappedTextDecoration("WAVY") == nil)

        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:8":{"document":{"id":"1:8","name":"Underlined Label","type":"TEXT","characters":"Underlined","style":{"fontSize":16,"textDecoration":"UNDERLINE"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":40}}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:8")
        let item = try #require(plan.items.first)
        #expect(item.text?.decoration == .underline)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.textDecorationFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let content = try #require(result.layers.first?.textContent)
        #expect(content.isUnderlined)
        #expect(!content.isStruckThrough)

        let unknownResponse = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:9":{"document":{"id":"1:9","name":"Unknown Decoration","type":"TEXT","characters":"Unknown","style":{"fontSize":16,"textDecoration":"WAVY"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":40}}}}}"#.utf8
            )
        )
        let unknownPlan = try XomoFigmaNodeImportMapper.makePlan(
            response: unknownResponse,
            requestedNodeID: "1:9"
        )
        let unknownItem = try #require(unknownPlan.items.first)
        #expect(unknownItem.text?.decoration == XomoFigmaPlanTextDecoration.none)
        #expect(unknownItem.fidelity == .partial)
        #expect(unknownItem.issues.contains(.textDecorationFlattened))
    }

    @Test func figmaFontWeightReportsApproximationWithoutLosingClosestVisualWeight() throws {
        #expect(XomoFigmaNodeImportMapper.mappedTextBold(nil) == false)
        #expect(XomoFigmaNodeImportMapper.mappedTextBold(400) == false)
        #expect(XomoFigmaNodeImportMapper.mappedTextBold(700) == true)
        #expect(XomoFigmaNodeImportMapper.mappedTextBold(300) == nil)
        #expect(XomoFigmaNodeImportMapper.mappedTextBold(600) == nil)
        #expect(!XomoFigmaNodeImportMapper.approximatedTextBold(500))
        #expect(XomoFigmaNodeImportMapper.approximatedTextBold(600))

        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:10":{"document":{"id":"1:10","name":"Semibold Label","type":"TEXT","characters":"Semibold","style":{"fontSize":16,"fontWeight":600},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":40}}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:10")
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.textFontWeightFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        #expect(result.layers.first?.textContent?.isBold == true)

        let exactResponse = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:11":{"document":{"id":"1:11","name":"Bold Label","type":"TEXT","characters":"Bold","style":{"fontSize":16,"fontWeight":700},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":40}}}}}"#.utf8
            )
        )
        let exactPlan = try XomoFigmaNodeImportMapper.makePlan(
            response: exactResponse,
            requestedNodeID: "1:11"
        )
        let exactItem = try #require(exactPlan.items.first)
        #expect(exactItem.fidelity == .exact)
        #expect(!exactItem.issues.contains(.textFontWeightFlattened))
    }

    @Test func figmaFontSizeBelowNativeMinimumReportsClampInsteadOfClaimingExactImport() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:12":{"document":{"id":"1:12","name":"Micro Label","type":"TEXT","characters":"Micro","style":{"fontSize":4},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":60,"height":12}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:12")
        let item = try #require(plan.items.first)
        #expect(item.text?.fontSize == 4)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.textFontSizeFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        #expect(result.layers.first?.textContent?.fontSize == ImageEditorTextContent.minimumFontSize)
    }

    @Test func figmaFontSizeAboveNativeMaximumReportsClampInsteadOfClaimingExactImport() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:17":{"document":{"id":"1:17","name":"Display","type":"TEXT","characters":"Huge","style":{"fontSize":300},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":310,"height":310}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:17")
        let item = try #require(plan.items.first)
        #expect(item.text?.fontSize == 300)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.textFontSizeFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 400)
        )
        #expect(result.layers.first?.textContent?.fontSize == ImageEditorTextContent.maximumFontSize)
    }

    @Test func figmaSliceBecomesNativeFireworksSliceAndExportsWithoutCreatingLayer() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Delivery",
                  "version": "1",
                  "nodes": {
                    "1:70": {
                      "document": {
                        "id": "1:70",
                        "name": "Hero Export",
                        "type": "SLICE",
                        "absoluteBoundingBox": {"x": 120, "y": 240, "width": 80, "height": 40}
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:70"
        )
        let item = try #require(plan.items.first)
        #expect(item.targetKind == .slice)
        #expect(item.fidelity == .exact)
        #expect(item.issues.isEmpty)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let slice = try #require(materialized.slices.first)
        #expect(materialized.layers.isEmpty)
        #expect(materialized.importedCount == 1)
        #expect(materialized.omittedCount == 0)
        #expect(slice.name == "Hero Export")
        #expect(slice.frame == CGRect(x: 160, y: 130, width: 80, height: 40))

        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.rendered(size: CGSize(width: 400, height: 300)) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
            } ?? NSImage.transparent(size: CGSize(width: 400, height: 300))
        ) { _ in }
        let initialLayerIDs = viewModel.document.layers.map(\.id)
        let initialHistoryCount = viewModel.document.history.count

        #expect(viewModel.importFigmaNodePlan(plan))
        #expect(viewModel.document.layers.map(\.id) == initialLayerIDs)
        #expect(viewModel.document.slices.count == 1)
        #expect(viewModel.document.slices.first?.name == "Hero Export")
        #expect(viewModel.exportSettings.scope == .slice)
        #expect(viewModel.exportSettings.sliceID == viewModel.document.slices.first?.id)
        #expect(viewModel.isSlicesPanelVisible)
        #expect(viewModel.document.history.count == initialHistoryCount + 1)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.figmaNodeImported", 1, 0))

        let exported = try #require(viewModel.exportData(settings: viewModel.exportSettings))
        let exportedImage = try #require(NSImage(data: exported))
        #expect(exportedImage.size == CGSize(width: 80, height: 40))

        let restored = try ImageEditorProjectDocument(document: viewModel.document).restoredDocument()
        #expect(restored.slices == viewModel.document.slices)

        viewModel.undo()
        #expect(viewModel.document.slices.isEmpty)
        #expect(viewModel.document.layers.map(\.id) == initialLayerIDs)

        viewModel.redo()
        #expect(viewModel.document.slices.count == 1)
        #expect(viewModel.document.layers.map(\.id) == initialLayerIDs)
    }

    @Test func gradientStopResolutionRunsOffMainActorAndRejectsInvalidValues() async {
        let resolved = await Task.detached {
            XomoFigmaNodeImportMapper.resolveGradientStopColor(
                XomoFigmaGradientStop(
                    position: 0.4,
                    color: XomoFigmaColor(r: 0.2, g: 0.4, b: 0.6, a: 0.8)
                )
            )
        }.value
        let invalidPosition = await Task.detached {
            XomoFigmaNodeImportMapper.resolveGradientStopColor(
                XomoFigmaGradientStop(
                    position: .nan,
                    color: XomoFigmaColor(r: 0.2, g: 0.4, b: 0.6, a: 0.8)
                )
            )
        }.value
        let invalidChannel = await Task.detached {
            XomoFigmaNodeImportMapper.resolveGradientStopColor(
                XomoFigmaGradientStop(
                    position: 0.4,
                    color: XomoFigmaColor(r: 0.2, g: 1.4, b: 0.6, a: 0.8)
                )
            )
        }.value

        #expect(resolved == XomoFigmaPlanColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8))
        #expect(invalidPosition == nil)
        #expect(invalidChannel == nil)
    }

    @Test func offsetMultiStopLinearGradientsMapToEditableShapes() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Gradients",
                  "nodes": {
                    "1:30": {
                      "document": {
                        "id": "1:30",
                        "name": "Gradient Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 240, "height": 160},
                        "children": [
                          {
                            "id": "2:30",
                            "name": "Editable Gradient",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 20, "width": 120, "height": 48},
                            "fills": [{
                              "type": "GRADIENT_LINEAR",
                              "opacity": 0.8,
                              "gradientHandlePositions": [
                                {"x": 0.1, "y": 0.5},
                                {"x": 0.7, "y": 0.5},
                                {"x": 0, "y": 0}
                              ],
                              "gradientStops": [
                                {"position": 0, "color": {"r": 1, "g": 0, "b": 0, "a": 0.5}},
                                {"position": 1, "color": {"r": 0, "g": 0, "b": 1, "a": 0.5}}
                              ]
                            }]
                          },
                          {
                            "id": "2:31",
                            "name": "Three Stops",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 90, "width": 120, "height": 48},
                            "fills": [{
                              "type": "GRADIENT_LINEAR",
                              "gradientHandlePositions": [
                                {"x": 0, "y": 0.5},
                                {"x": 1, "y": 0.5},
                                {"x": 0, "y": 0}
                              ],
                              "gradientStops": [
                                {"position": 0, "color": {"r": 1, "g": 0, "b": 0, "a": 1}},
                                {"position": 0.5, "color": {"r": 0, "g": 1, "b": 0, "a": 1}},
                                {"position": 1, "color": {"r": 0, "g": 0, "b": 1, "a": 1}}
                              ]
                            }]
                          },
                          {
                            "id": "2:32",
                            "name": "Different Stop Alpha",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 150, "y": 90, "width": 70, "height": 48},
                            "fills": [{
                              "type": "GRADIENT_LINEAR",
                              "gradientHandlePositions": [
                                {"x": 0, "y": 0.5},
                                {"x": 1, "y": 0.5},
                                {"x": 0, "y": 0}
                              ],
                              "gradientStops": [
                                {"position": 0, "color": {"r": 1, "g": 0, "b": 0, "a": 1}},
                                {"position": 0.5, "color": {"r": 0, "g": 1, "b": 0, "a": 0.5}},
                                {"position": 1, "color": {"r": 0, "g": 0, "b": 1, "a": 1}}
                              ]
                            }]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:30"
        )
        let editable = try #require(plan.items.first { $0.sourceID == "2:30" })
        let multiStop = try #require(plan.items.first { $0.sourceID == "2:31" })
        let differentAlpha = try #require(plan.items.first { $0.sourceID == "2:32" })
        #expect(editable.fidelity == .exact)
        #expect(editable.linearGradientFill?.angle == 0)
        #expect(abs((editable.linearGradientFill?.scale ?? 0) - 0.6) < 0.001)
        #expect(abs((editable.linearGradientFill?.centerX ?? 0) - 0.4) < 0.001)
        #expect(editable.linearGradientFill?.centerY == 0.5)
        #expect(editable.linearGradientFill?.opacity == 0.4)
        #expect(!editable.issues.contains(.unsupportedPaint))
        #expect(multiStop.fidelity == .exact)
        #expect(multiStop.linearGradientFill?.colorStops.count == 3)
        #expect(multiStop.linearGradientFill?.colorStops[1].position == 0.5)
        #expect(!multiStop.issues.contains(.unsupportedPaint))
        #expect(differentAlpha.fidelity == .partial)
        #expect(differentAlpha.linearGradientFill == nil)
        #expect(differentAlpha.issues.contains(.unsupportedPaint))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let shape = try #require(
            materialized.layers.first { $0.name == "Editable Gradient" }?.shapeContent
        )
        #expect(shape.fillGradient?.angle == 0)
        #expect(abs((shape.fillGradient?.scale ?? 0) - 0.6) < 0.001)
        #expect(abs(shape.fillGradientCenter.x - 0.4) < 0.001)
        #expect(shape.fillGradientCenter.y == 0.5)
        #expect(abs(shape.fillOpacity - 0.4) < 0.001)
        let multiStopShape = try #require(
            materialized.layers.first { $0.name == "Three Stops" }?.shapeContent
        )
        #expect(multiStopShape.fillGradient?.shapeColorStops.count == 3)
        #expect((multiStopShape.fillGradient?.shapeColorStops[1].green ?? 0) > 0.95)
    }

    @Test func outOfRangeFigmaSolidPaintReportsAndUsesSafeEditableColor() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Paint Bounds","nodes":{"1:30":{"document":{"id":"1:30","name":"Paint Bounds","type":"RECTANGLE","fills":[{"type":"SOLID","opacity":0.5,"color":{"r":1.4,"g":-0.2,"b":0.5,"a":1.2}}],"strokes":[{"type":"SOLID"}],"strokeWeight":2,"absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":60}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:30")
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.unsupportedPaint))
        #expect(item.solidFill == XomoFigmaPlanColor(red: 1, green: 0, blue: 0.5, alpha: 0.5))
        #expect(item.solidStroke == nil)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 180)
        )
        let shape = try #require(result.layers.first?.shapeContent)
        let color = try #require(shape.fillColor.usingColorSpace(.sRGB))
        #expect(abs(color.redComponent - 1) < 0.001)
        #expect(abs(color.greenComponent) < 0.001)
        #expect(abs(color.blueComponent - 0.5) < 0.001)
        #expect(abs(shape.fillOpacity - 0.5) < 0.001)
    }

    @Test func nonNormalFigmaPaintBlendModeReportsEditableFallback() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Paint Blend","nodes":{"1:31":{"document":{"id":"1:31","name":"Paint Blend","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":220,"height":80},"children":[{"id":"2:31","name":"Normal Paint","type":"RECTANGLE","fills":[{"type":"SOLID","blendMode":"NORMAL","color":{"r":0.2,"g":0.4,"b":0.6}}],"absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":60}},{"id":"2:32","name":"Multiply Paint","type":"RECTANGLE","fills":[{"type":"SOLID","blendMode":"MULTIPLY","color":{"r":0.8,"g":0.3,"b":0.1}}],"absoluteBoundingBox":{"x":120,"y":0,"width":100,"height":60}}]}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:31")
        let normal = try #require(plan.items.first { $0.sourceID == "2:31" })
        let multiply = try #require(plan.items.first { $0.sourceID == "2:32" })
        #expect(normal.fidelity == .exact)
        #expect(!normal.issues.contains(.unsupportedPaint))
        #expect(multiply.fidelity == .partial)
        #expect(multiply.issues.contains(.unsupportedPaint))
        #expect(multiply.solidFill == XomoFigmaPlanColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 180)
        )
        let shape = try #require(result.layers.first { $0.name == "Multiply Paint" }?.shapeContent)
        let color = try #require(shape.fillColor.usingColorSpace(.sRGB))
        #expect(abs(color.redComponent - 0.8) < 0.001)
        #expect(abs(color.greenComponent - 0.3) < 0.001)
        #expect(abs(color.blueComponent - 0.1) < 0.001)
    }

    @Test func outOfRangeFigmaGradientColorUsesSafeEditableFallback() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Gradient Bounds","nodes":{"1:32":{"document":{"id":"1:32","name":"Gradient Bounds","type":"RECTANGLE","fills":[{"type":"GRADIENT_LINEAR","opacity":1.4,"gradientHandlePositions":[{"x":0,"y":0.5},{"x":1,"y":0.5},{"x":0,"y":0}],"gradientStops":[{"position":0,"color":{"r":1.3,"g":-0.2,"b":0.4,"a":1.2}},{"position":1,"color":{"r":0.2,"g":0.6,"b":1.5,"a":1.2}}]}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":60}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:32")
        let item = try #require(plan.items.first)
        let gradient = try #require(item.linearGradientFill)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.unsupportedPaint))
        #expect(gradient.opacity == 1)
        #expect(gradient.startColor == XomoFigmaPlanColor(red: 1, green: 0, blue: 0.4, alpha: 1))
        #expect(gradient.endColor == XomoFigmaPlanColor(red: 0.2, green: 0.6, blue: 1, alpha: 1))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 160)
        )
        let shape = try #require(result.layers.first?.shapeContent)
        let materializedGradient = try #require(shape.fillGradient)
        let startColor = try #require(materializedGradient.shapeStartColor.usingColorSpace(.sRGB))
        let endColor = try #require(materializedGradient.shapeEndColor.usingColorSpace(.sRGB))
        #expect(abs(startColor.redComponent - 1) < 0.001)
        #expect(abs(startColor.greenComponent) < 0.001)
        #expect(abs(endColor.blueComponent - 1) < 0.001)
        #expect(abs(shape.fillOpacity - 1) < 0.001)
    }

    @Test func outOfRangeFigmaGradientStopsUseOrderedEditableFallback() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Gradient Stop Bounds","nodes":{"1:33":{"document":{"id":"1:33","name":"Gradient Stop Bounds","type":"RECTANGLE","fills":[{"type":"GRADIENT_LINEAR","gradientHandlePositions":[{"x":0,"y":0.5},{"x":1,"y":0.5},{"x":0,"y":0}],"gradientStops":[{"position":-0.2,"color":{"r":1,"g":0,"b":0}},{"position":0.4,"color":{"r":0,"g":1,"b":0}},{"position":1.3,"color":{"r":0,"g":0,"b":1}}]}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":60}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:33")
        let item = try #require(plan.items.first)
        let gradient = try #require(item.linearGradientFill)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.unsupportedPaint))
        #expect(gradient.colorStops.map(\.position) == [0, 0.4, 1])

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 160)
        )
        let shape = try #require(result.layers.first?.shapeContent)
        #expect(shape.fillGradient?.shapeColorStops.map(\.position) == [0, 0.4, 1])
    }

    @Test func outOfRangeLinearGradientCenterUsesEditableBoundaryAndReportsPartialFidelity() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Gradient Center","nodes":{"1:34":{"document":{"id":"1:34","name":"Far Gradient","type":"RECTANGLE","fills":[{"type":"GRADIENT_LINEAR","gradientHandlePositions":[{"x":5,"y":0.5},{"x":6,"y":0.5},{"x":5,"y":0}],"gradientStops":[{"position":0,"color":{"r":1,"g":0,"b":0}},{"position":1,"color":{"r":0,"g":0,"b":1}}]}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":60}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:34")
        let item = try #require(plan.items.first)
        let gradient = try #require(item.linearGradientFill)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.unsupportedPaint))
        #expect(gradient.centerX == 5)
        #expect(gradient.centerY == 0.5)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 160)
        )
        let shape = try #require(result.layers.first?.shapeContent)
        #expect(shape.fillGradientCenter == CGPoint(x: 5, y: 0.5))
    }

    @Test func outOfRangeGradientScaleUsesEditableBoundariesAndReportsPartialFidelity() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Gradient Scale","nodes":{"1:35":{"document":{"id":"1:35","name":"Gradient Scale","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":220,"height":100},"children":[{"id":"2:35","name":"Wide Linear","type":"RECTANGLE","fills":[{"type":"GRADIENT_LINEAR","gradientHandlePositions":[{"x":0,"y":0.5},{"x":5,"y":0.5},{"x":0,"y":0}],"gradientStops":[{"position":0,"color":{"r":1,"g":0,"b":0}},{"position":1,"color":{"r":0,"g":0,"b":1}}]}],"absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":100}},{"id":"2:36","name":"Tight Radial","type":"ELLIPSE","fills":[{"type":"GRADIENT_RADIAL","gradientHandlePositions":[{"x":0.5,"y":0.5},{"x":0.55,"y":0.5},{"x":0.5,"y":0.55}],"gradientStops":[{"position":0,"color":{"r":1,"g":1,"b":1}},{"position":1,"color":{"r":0,"g":0,"b":0}}]}],"absoluteBoundingBox":{"x":120,"y":0,"width":100,"height":100}}]}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:35")
        let linear = try #require(plan.items.first { $0.sourceID == "2:35" })
        let radial = try #require(plan.items.first { $0.sourceID == "2:36" })
        #expect(linear.fidelity == .partial)
        #expect(linear.issues.contains(.unsupportedPaint))
        #expect(linear.linearGradientFill?.scale == 4)
        #expect(radial.fidelity == .partial)
        #expect(radial.issues.contains(.unsupportedPaint))
        #expect(radial.radialGradientFill?.scale == 0.25)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 200)
        )
        #expect(result.layers.first { $0.name == "Wide Linear" }?.shapeContent?.fillGradient?.scale == 4)
        #expect(result.layers.first { $0.name == "Tight Radial" }?.shapeContent?.fillGradient?.scale == 0.25)
    }

    @Test func outOfRangeRadialGradientCenterUsesEditableBoundaryAndReportsPartialFidelity() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Radial Center","nodes":{"1:37":{"document":{"id":"1:37","name":"Far Radial","type":"ELLIPSE","fills":[{"type":"GRADIENT_RADIAL","gradientHandlePositions":[{"x":5.5,"y":0.5},{"x":6,"y":0.5},{"x":5.5,"y":1}],"gradientStops":[{"position":0,"color":{"r":1,"g":1,"b":1}},{"position":1,"color":{"r":0,"g":0,"b":0}}]}],"absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":100}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:37")
        let item = try #require(plan.items.first)
        let gradient = try #require(item.radialGradientFill)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.unsupportedPaint))
        #expect(gradient.centerX == 5)
        #expect(gradient.centerY == 0.5)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 180)
        )
        let shape = try #require(result.layers.first?.shapeContent)
        #expect(shape.fillGradient?.style == .radial)
        #expect(shape.fillGradientCenter == CGPoint(x: 5, y: 0.5))
    }

    @Test func outOfRangeFigmaNodeOpacityReportsAndUsesEditableBounds() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Opacity","nodes":{"1:27":{"document":{"id":"1:27","name":"Opacity","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":300,"height":120},"children":[{"id":"2:27","name":"Too Opaque","type":"RECTANGLE","opacity":1.4,"absoluteBoundingBox":{"x":0,"y":0,"width":80,"height":40}},{"id":"2:28","name":"Negative","type":"RECTANGLE","opacity":-0.2,"absoluteBoundingBox":{"x":100,"y":0,"width":80,"height":40}},{"id":"2:29","name":"Native","type":"RECTANGLE","opacity":0.4,"absoluteBoundingBox":{"x":200,"y":0,"width":80,"height":40}}]}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:27")
        let tooOpaque = try #require(plan.items.first { $0.sourceID == "2:27" })
        let negative = try #require(plan.items.first { $0.sourceID == "2:28" })
        let native = try #require(plan.items.first { $0.sourceID == "2:29" })
        #expect(tooOpaque.opacity == 1)
        #expect(negative.opacity == 0)
        for item in [tooOpaque, negative] {
            #expect(item.fidelity == .partial)
            #expect(item.issues.contains(.nodeOpacityFlattened))
        }
        #expect(native.opacity == 0.4)
        #expect(native.fidelity == .exact)
        #expect(!native.issues.contains(.nodeOpacityFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 240)
        )
        #expect(result.layers.first { $0.name == "Too Opaque" }?.opacity == 1)
        #expect(result.layers.first { $0.name == "Negative" }?.opacity == 0)
        #expect(result.layers.first { $0.name == "Native" }?.opacity == 0.4)
    }

    @Test func supportedFigmaBlendModesRemainEditableAndUnknownModesStayExplicitlyPartial() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Blend Modes",
                  "nodes": {
                    "1:50": {
                      "document": {
                        "id": "1:50",
                        "name": "Blend Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 240, "height": 180},
                        "children": [
                          {
                            "id": "2:50",
                            "name": "Multiply",
                            "type": "RECTANGLE",
                            "blendMode": "MULTIPLY",
                            "absoluteBoundingBox": {"x": 10, "y": 10, "width": 80, "height": 40},
                            "fills": [{"type": "SOLID", "color": {"r": 1, "g": 0, "b": 0, "a": 1}}]
                          },
                          {
                            "id": "2:51",
                            "name": "Screen",
                            "type": "RECTANGLE",
                            "blendMode": "SCREEN",
                            "absoluteBoundingBox": {"x": 100, "y": 10, "width": 80, "height": 40},
                            "fills": [{"type": "SOLID", "color": {"r": 0, "g": 1, "b": 0, "a": 1}}]
                          },
                          {
                            "id": "2:52",
                            "name": "Future Mode",
                            "type": "RECTANGLE",
                            "blendMode": "PLUS_LIGHTER",
                            "absoluteBoundingBox": {"x": 10, "y": 70, "width": 80, "height": 40},
                            "fills": [{"type": "SOLID", "color": {"r": 0, "g": 0, "b": 1, "a": 1}}]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:50"
        )
        let multiply = try #require(plan.items.first { $0.sourceID == "2:50" })
        let screen = try #require(plan.items.first { $0.sourceID == "2:51" })
        let unknown = try #require(plan.items.first { $0.sourceID == "2:52" })
        #expect(multiply.blendMode == ImageEditorBlendMode.multiply.rawValue)
        #expect(multiply.fidelity == .exact)
        #expect(!multiply.issues.contains(.blendModeFlattened))
        #expect(screen.blendMode == ImageEditorBlendMode.screen.rawValue)
        #expect(screen.fidelity == .exact)
        #expect(unknown.blendMode == nil)
        #expect(unknown.fidelity == .partial)
        #expect(unknown.issues.contains(.blendModeFlattened))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let multiplyLayer = try #require(materialized.layers.first { $0.name == "Multiply" })
        let screenLayer = try #require(materialized.layers.first { $0.name == "Screen" })
        let unknownLayer = try #require(materialized.layers.first { $0.name == "Future Mode" })
        #expect(multiplyLayer.blendMode == .multiply)
        #expect(screenLayer.blendMode == .screen)
        #expect(unknownLayer.blendMode == .normal)
    }

    @Test func multipleSolidFillsCompositeVisuallyAndReportLostFillSemantics() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Solid Paint Stack",
                  "nodes": {
                    "1:60": {
                      "document": {
                        "id": "1:60",
                        "name": "Solid Paint Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 200, "height": 120},
                        "children": [{
                          "id": "2:60",
                          "name": "Layered Solid",
                          "type": "RECTANGLE",
                          "absoluteBoundingBox": {"x": 20, "y": 20, "width": 100, "height": 50},
                          "fills": [
                            {"type": "SOLID", "color": {"r": 0, "g": 0, "b": 1, "a": 0.5}},
                            {"type": "SOLID", "color": {"r": 1, "g": 0, "b": 0, "a": 0.5}}
                          ]
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:60"
        )
        let item = try #require(plan.items.first { $0.sourceID == "2:60" })
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.unsupportedPaint))
        let color = try #require(item.solidFill)
        #expect(abs(color.alpha - 0.75) < 0.001)
        #expect(abs(color.red - (1.0 / 3.0)) < 0.001)
        #expect(abs(color.blue - (2.0 / 3.0)) < 0.001)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 300, height: 200)
        )
        let shape = try #require(materialized.layers.first { $0.name == "Layered Solid" }?.shapeContent)
        #expect(abs(shape.fillOpacity - 0.75) < 0.001)
        #expect(abs((shape.fillColor.usingColorSpace(.sRGB)?.redComponent ?? 0) - (1.0 / 3.0)) < 0.001)
        #expect(abs((shape.fillColor.usingColorSpace(.sRGB)?.blueComponent ?? 0) - (2.0 / 3.0)) < 0.001)
    }

    @Test func circularRadialGradientsMapWhileEllipticalAxesDegrade() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Radial Gradients",
                  "nodes": {
                    "1:40": {
                      "document": {
                        "id": "1:40",
                        "name": "Radial Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 300, "height": 140},
                        "children": [
                          {
                            "id": "2:40",
                            "name": "Editable Radial",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 20, "width": 120, "height": 80},
                            "fills": [{
                              "type": "GRADIENT_RADIAL",
                              "opacity": 0.8,
                              "gradientHandlePositions": [
                                {"x": 0.4, "y": 0.5},
                                {"x": 0.7333333333, "y": 0.5},
                                {"x": 0.4, "y": 1.0}
                              ],
                              "gradientStops": [
                                {"position": 0, "color": {"r": 1, "g": 0, "b": 0, "a": 0.5}},
                                {"position": 0.45, "color": {"r": 0, "g": 1, "b": 0, "a": 0.5}},
                                {"position": 1, "color": {"r": 0, "g": 0, "b": 1, "a": 0.5}}
                              ]
                            }]
                          },
                          {
                            "id": "2:41",
                            "name": "Elliptical Radial",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 160, "y": 20, "width": 100, "height": 80},
                            "fills": [{
                              "type": "GRADIENT_RADIAL",
                              "gradientHandlePositions": [
                                {"x": 0.5, "y": 0.5},
                                {"x": 0.9, "y": 0.5},
                                {"x": 0.5, "y": 0.7}
                              ],
                              "gradientStops": [
                                {"position": 0, "color": {"r": 1, "g": 1, "b": 1, "a": 1}},
                                {"position": 1, "color": {"r": 0, "g": 0, "b": 0, "a": 1}}
                              ]
                            }]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:40"
        )
        let radial = try #require(plan.items.first { $0.sourceID == "2:40" })
        let elliptical = try #require(plan.items.first { $0.sourceID == "2:41" })
        let radialFill = try #require(radial.radialGradientFill)
        #expect(radial.fidelity == .exact)
        #expect(radial.linearGradientFill == nil)
        #expect(!radial.issues.contains(.unsupportedPaint))
        #expect(abs(radialFill.centerX - 0.4) < 0.001)
        #expect(abs(radialFill.centerY - 0.5) < 0.001)
        #expect(abs(radialFill.scale - (40 / hypot(60, 40))) < 0.001)
        #expect(abs(radialFill.opacity - 0.4) < 0.001)
        #expect(radialFill.colorStops.count == 3)
        #expect(radialFill.colorStops[1].position == 0.45)
        #expect(elliptical.fidelity == .partial)
        #expect(elliptical.radialGradientFill == nil)
        #expect(elliptical.issues.contains(.unsupportedPaint))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 200)
        )
        let shape = try #require(
            materialized.layers.first { $0.name == "Editable Radial" }?.shapeContent
        )
        #expect(shape.fillGradient?.style == .radial)
        #expect(abs((shape.fillGradient?.scale ?? 0) - radialFill.scale) < 0.001)
        #expect(abs(shape.fillGradientCenter.x - 0.4) < 0.001)
        #expect(abs(shape.fillGradientCenter.y - 0.5) < 0.001)
        #expect(abs(shape.fillOpacity - 0.4) < 0.001)
        #expect(shape.fillGradient?.shapeColorStops.count == 3)
        #expect((shape.fillGradient?.shapeColorStops[1].green ?? 0) > 0.95)
    }

    @Test func clientRequiresSpecificNodeAndUsesBoundedOfficialEndpoint() async throws {
        let transport = RecordingFigmaNodeTransport(statusCode: 200, body: Self.validNodeResponse)
        let client = XomoFigmaNodeContentAPIClient(transport: transport)
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let filePreview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout"
        )
        let nodePreview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3&version-id=77"
        )

        await #expect(throws: XomoFigmaNodeImportError.nodeSelectionRequired) {
            try await client.fetchPlan(for: filePreview, credential: token)
        }
        let plan = try await client.fetchPlan(for: nodePreview, credential: token)
        let request = try #require(transport.lastRequest)
        let requestURL = try #require(request.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(request.httpMethod == "GET")
        #expect(components.path == "/v1/files/abc123DEF456/nodes")
        #expect(query == ["ids": "1:3", "depth": "6", "geometry": "paths", "version": "77"])
        #expect(request.value(forHTTPHeaderField: "X-Figma-Token") == token.rawValue)
        #expect(request.url?.absoluteString.contains(token.rawValue) == false)
        #expect(plan.rootSourceID == "1:3")
        #expect(plan.sourceCanonicalURL == nodePreview.canonicalURL)
    }

    @Test func mapperBuildsEditableHierarchyAndRelativeFrames() async throws {
        let transport = RecordingFigmaNodeTransport(statusCode: 200, body: Self.validNodeResponse)
        let client = XomoFigmaNodeContentAPIClient(transport: transport)
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3"
        )

        let plan = try await client.fetchPlan(for: preview, credential: token)
        let frame = try #require(plan.items.first { $0.sourceID == "1:3" })
        let group = try #require(plan.items.first { $0.sourceID == "2:1" })
        let text = try #require(plan.items.first { $0.sourceID == "2:2" })
        let rectangle = try #require(plan.items.first { $0.sourceID == "2:3" })
        let ellipse = try #require(plan.items.first { $0.sourceID == "2:4" })
        let vector = try #require(plan.items.first { $0.sourceID == "2:5" })
        #expect(plan.sourceCanonicalURL == preview.canonicalURL)

        #expect(frame.targetKind == .group)
        #expect(frame.frame == XomoFigmaPlanRect(x: 0, y: 0, width: 390, height: 844))
        #expect(group.parentSourceID == "1:3")
        #expect(group.targetKind == .group)
        #expect(group.stackLayout?.axis == .horizontal)
        #expect(text.parentSourceID == "2:1")
        #expect(text.targetKind == .text)
        #expect(text.stackChildLayout == ImageEditorStackChildLayout(
            grow: 1,
            stretchesCrossAxis: true
        ))
        #expect(text.text?.characters == "Continue 继续")
        #expect(text.text?.textCase == .uppercase)
        #expect(text.text?.fontFamily == "Inter")
        #expect(text.text?.fontSize == 16)
        #expect(text.frame == XomoFigmaPlanRect(x: 30, y: 60, width: 64, height: 24))
        #expect(rectangle.targetKind == .rectangle)
        #expect(rectangle.fidelity == .exact)
        #expect(!rectangle.issues.contains(.cornerRadiusFlattened))
        #expect(rectangle.cornerRadius == 8)
        #expect(rectangle.solidFill == XomoFigmaPlanColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1))
        #expect(rectangle.opacity == 0.8)
        #expect(rectangle.isLocked)
        #expect(ellipse.targetKind == .ellipse)
        #expect(vector.targetKind == .vector)
        #expect(vector.vectorPaths == ["M 0 0 L 20 0 L 10 20 Z"])
        #expect(vector.geometrySize == XomoFigmaPlanSize(width: 20, height: 20))
        #expect(vector.solidStroke == XomoFigmaPlanColor(red: 0, green: 0, blue: 0, alpha: 1))
        #expect(vector.strokeWeight == 2)
    }

    @Test func figmaSubpixelStrokeRemainsNativeAndEditable() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Hairline","nodes":{"1:20":{"document":{"id":"1:20","name":"Hairline Card","type":"RECTANGLE","fills":[{"type":"SOLID","color":{"r":1,"g":1,"b":1,"a":1}}],"strokes":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"strokeWeight":0.5,"absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":50}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:20")
        let item = try #require(plan.items.first)
        #expect(item.strokeWeight == 0.5)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.strokeWeightFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        #expect(result.layers.first?.shapeContent?.strokeWidth == 0.5)
    }

    @Test func oversizedFigmaStrokeClampsToEditableNativeMaximum() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Heavy Stroke","nodes":{"1:21":{"document":{"id":"1:21","name":"Heavy Card","type":"RECTANGLE","fills":[{"type":"SOLID","color":{"r":1,"g":1,"b":1,"a":1}}],"strokes":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"strokeWeight":120,"absoluteBoundingBox":{"x":0,"y":0,"width":400,"height":400}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:21")
        let item = try #require(plan.items.first)
        #expect(item.strokeWeight == 120)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.strokeWeightFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 500, height: 500)
        )
        let shape = try #require(result.layers.first?.shapeContent)
        #expect(shape.strokeWidth == ImageEditorShapeContent.maximumStrokeWidth)
    }

    @Test func figmaShapeStrokeReportsGeometryClampInsteadOfClaimingExactImport() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Compact Stroke","nodes":{"1:22":{"document":{"id":"1:22","name":"Compact Card","type":"RECTANGLE","fills":[{"type":"SOLID","color":{"r":1,"g":1,"b":1,"a":1}}],"strokes":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"strokeWeight":40,"absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":50}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:22")
        let item = try #require(plan.items.first)
        #expect(item.strokeWeight == 40)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.strokeWeightFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        #expect(result.layers.first?.shapeContent?.strokeWidth == 25)
    }

    @Test func mapperImportsSectionAsEditableGroupAndPreservesGradientBackground() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Sections",
                  "nodes": {
                    "1:50": {
                      "document": {
                        "id": "1:50",
                        "name": "Checkout Section",
                        "type": "SECTION",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 320, "height": 200},
                        "fills": [{
                          "type": "GRADIENT_LINEAR",
                          "gradientHandlePositions": [
                            {"x": 0, "y": 0.5},
                            {"x": 1, "y": 0.5},
                            {"x": 0, "y": 0}
                          ],
                          "gradientStops": [
                            {"position": 0, "color": {"r": 0.1, "g": 0.2, "b": 0.4, "a": 1}},
                            {"position": 1, "color": {"r": 0.4, "g": 0.6, "b": 1, "a": 1}}
                          ]
                        }],
                        "children": [{
                          "id": "2:50",
                          "name": "Section Button",
                          "type": "RECTANGLE",
                          "absoluteBoundingBox": {"x": 24, "y": 24, "width": 120, "height": 40},
                          "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}]
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:50")
        let section = try #require(plan.items.first { $0.sourceID == "1:50" })
        let button = try #require(plan.items.first { $0.sourceID == "2:50" })
        #expect(section.targetKind == .group)
        #expect(section.fidelity == .exact)
        #expect(!section.issues.contains(.unsupportedNodeType))
        #expect(section.linearGradientFill?.colorStops.count == 2)
        #expect(button.parentSourceID == "1:50")

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 640, height: 400)
        )
        #expect(materialized.omittedCount == 0)
        #expect(materialized.layers.contains { $0.name == "Section Button" })
        let background = try #require(
            materialized.layers.first { $0.isStackLayoutBackground }
        )
        #expect(background.shapeContent?.fillGradient?.shapeColorStops.count == 2)
    }

    @Test func mapperFlattensBooleanOperationToEditableVectorWithoutDuplicateChildren() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Boolean Shapes",
                  "nodes": {
                    "1:60": {
                      "document": {
                        "id": "1:60",
                        "name": "Union Result",
                        "type": "BOOLEAN_OPERATION",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 120, "height": 80},
                        "fills": [{"type": "SOLID", "color": {"r": 0.2, "g": 0.5, "b": 0.9, "a": 1}}],
                        "fillGeometry": [{"path": "M 0 0 L 120 0 L 120 80 L 0 80 Z"}],
                        "children": [
                          {
                            "id": "2:60",
                            "name": "Union Source A",
                            "type": "ELLIPSE",
                            "absoluteBoundingBox": {"x": 0, "y": 0, "width": 80, "height": 80}
                          },
                          {
                            "id": "2:61",
                            "name": "Union Source B",
                            "type": "ELLIPSE",
                            "absoluteBoundingBox": {"x": 40, "y": 0, "width": 80, "height": 80}
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:60")
        let operation = try #require(plan.items.first { $0.sourceID == "1:60" })
        #expect(operation.targetKind == .vector)
        #expect(operation.fidelity == .partial)
        #expect(operation.issues.contains(.booleanOperationFlattened))
        #expect(operation.vectorPaths == ["M 0 0 L 120 0 L 120 80 L 0 80 Z"])

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 160)
        )
        #expect(materialized.omittedCount == 0)
        #expect(materialized.layers.count == 1)
        let result = try #require(materialized.layers.first)
        #expect(result.name == "Union Result")
        #expect(result.shapeContent?.kind == .path)
        #expect(result.shapeContent?.pathAnchors.count == 4)
        #expect(result.xomoFigmaSourceID == "1:60")
        #expect(result.xomoFigmaNodeType == "BOOLEAN_OPERATION")

        var sourceDocument = ImageEditorDocument(sourceName: "Figma Boolean", image: result.image)
        sourceDocument.canvasSize = CGSize(width: 240, height: 160)
        sourceDocument.layers = materialized.layers
        sourceDocument.selectedLayerID = result.id
        sourceDocument.selectedLayerIDs = [result.id]
        let project = try ImageEditorProjectDocument(document: sourceDocument)
        let restoredDocument = try project.restoredDocument()
        #expect(restoredDocument.layers.first?.xomoFigmaSourceID == "1:60")
        #expect(restoredDocument.layers.first?.xomoFigmaNodeType == "BOOLEAN_OPERATION")
    }

    @Test func mapperPreservesOrthogonalVectorTransformAndMaterializesRotatedGeometry() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Rotated Vector",
                  "nodes": {
                    "1:70": {
                      "document": {
                        "id": "1:70",
                        "name": "Rotated Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                        "children": [
                          {
                            "id": "2:70",
                            "name": "Quarter Turn",
                            "type": "VECTOR",
                            "absoluteBoundingBox": {"x": 10, "y": 20, "width": 10, "height": 20},
                            "size": {"width": 20, "height": 10},
                            "relativeTransform": [[0, -1, 10], [1, 0, 0]],
                            "fills": [{"type": "SOLID", "color": {"r": 0.1, "g": 0.4, "b": 0.8, "a": 1}}],
                            "fillGeometry": [{"path": "M 0 0 L 20 0 L 0 10 Z"}]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:70")
        let vector = try #require(plan.items.first { $0.sourceID == "2:70" })
        #expect(vector.relativeTransform == XomoFigmaPlanTransform([[0, -1, 10], [1, 0, 0]]))
        #expect(!vector.issues.contains(.transformFlattened))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let layer = try #require(materialized.layers.first { $0.name == "Quarter Turn" })
        let points = try #require(layer.shapeContent?.pathPoints)
        #expect(points.count == 3)
        #expect(abs(points[0].x - 10) < 0.001)
        #expect(abs(points[0].y) < 0.001)
        #expect(abs(points[1].x - 10) < 0.001)
        #expect(abs(points[1].y - 20) < 0.001)
        #expect(abs(points[2].x) < 0.001)
        #expect(abs(points[2].y) < 0.001)
    }

    @Test func mapperStillReportsShearedVectorTransformAsFlattened() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Sheared Vector",
                  "nodes": {
                    "1:71": {
                      "document": {
                        "id": "1:71",
                        "name": "Sheared Vector",
                        "type": "VECTOR",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 20, "height": 20},
                        "size": {"width": 20, "height": 20},
                        "relativeTransform": [[1, 0.5, 0], [0, 1, 0]],
                        "fillGeometry": [{"path": "M 0 0 L 20 0 L 0 20 Z"}]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:71")
        let vector = try #require(plan.items.first)
        #expect(vector.issues.contains(.transformFlattened))
    }

    @Test func mapperPreservesFrameClipsContentAsEditableGroupMask() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Clipped Card",
                  "nodes": {
                    "1:80": {
                      "document": {
                        "id": "1:80",
                        "name": "Clipped Card",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 20, "y": 20, "width": 40, "height": 40},
                        "clipsContent": true,
                        "children": [
                          {
                            "id": "2:80",
                            "name": "Overflowing Content",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 0, "y": 0, "width": 80, "height": 80},
                            "fills": [{"type": "SOLID", "color": {"r": 0.2, "g": 0.7, "b": 0.9, "a": 1}}]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:80")
        let group = try #require(plan.items.first { $0.sourceID == "1:80" })
        #expect(group.clipsContent)
        #expect(!group.issues.contains(.clippingFlattened))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let layer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "1:80" })
        #expect(layer.isGroup)
        #expect(layer.mask?.size == CGSize(width: 200, height: 200))
    }

    @Test func mapperPreservesSimpleRectangleMaskOnSubsequentSiblings() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Masked Group",
                  "nodes": {
                    "1:81": {
                      "document": {
                        "id": "1:81",
                        "name": "Masked Group",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                        "children": [
                          {
                            "id": "2:80",
                            "name": "Before Mask",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                            "fills": [{"type": "SOLID", "color": {"r": 0.1, "g": 0.2, "b": 0.9, "a": 1}}]
                          },
                          {
                            "id": "2:81",
                            "name": "Mask Rectangle",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 20, "width": 60, "height": 60},
                            "isMask": true,
                            "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}]
                          },
                          {
                            "id": "2:82",
                            "name": "Masked Content",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                            "fills": [{"type": "SOLID", "color": {"r": 0.9, "g": 0.2, "b": 0.1, "a": 1}}]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:81")
        let group = try #require(plan.items.first { $0.sourceID == "1:81" })
        let before = try #require(plan.items.first { $0.sourceID == "2:80" })
        let mask = try #require(plan.items.first { $0.sourceID == "2:81" })
        let after = try #require(plan.items.first { $0.sourceID == "2:82" })
        #expect(group.maskFrame == XomoFigmaPlanRect(x: 20, y: 20, width: 60, height: 60))
        #expect(!group.issues.contains(.maskFlattened))
        #expect(before.siblingMaskFrame == nil)
        #expect(mask.isMask)
        #expect(!mask.issues.contains(.maskFlattened))
        #expect(after.siblingMaskFrame == group.maskFrame)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let groupLayer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "1:81" })
        let beforeLayer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "2:80" })
        let maskLayer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "2:81" })
        let afterLayer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "2:82" })
        #expect(groupLayer.mask == nil)
        #expect(beforeLayer.mask == nil)
        #expect(afterLayer.mask?.size == afterLayer.image.size)
        let insideMask = try #require(afterLayer.effectiveMask?.color(at: CGPoint(x: afterLayer.image.size.width / 2, y: afterLayer.image.size.height / 2)))
        let outsideMask = try #require(afterLayer.effectiveMask?.color(at: .zero))
        #expect(insideMask.alphaComponent > 0.9)
        #expect(outsideMask.alphaComponent < 0.1)
        #expect(!maskLayer.isVisible)
    }

    @Test func mapperPreservesSimpleEllipseMaskOnSubsequentSiblings() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Elliptical Masked Group",
                  "nodes": {
                    "1:83": {
                      "document": {
                        "id": "1:83",
                        "name": "Elliptical Masked Group",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                        "children": [
                          {
                            "id": "2:83",
                            "name": "Ellipse Mask",
                            "type": "ELLIPSE",
                            "absoluteBoundingBox": {"x": 20, "y": 30, "width": 60, "height": 40},
                            "isMask": true,
                            "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}]
                          },
                          {
                            "id": "2:84",
                            "name": "Elliptical Content",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                            "fills": [{"type": "SOLID", "color": {"r": 0.9, "g": 0.2, "b": 0.1, "a": 1}}]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:83")
        let group = try #require(plan.items.first { $0.sourceID == "1:83" })
        let mask = try #require(plan.items.first { $0.sourceID == "2:83" })
        let content = try #require(plan.items.first { $0.sourceID == "2:84" })
        #expect(group.maskShape == .ellipse)
        #expect(mask.maskShape == .ellipse)
        #expect(content.siblingMaskShape == .ellipse)
        #expect(!group.issues.contains(.maskFlattened))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let contentLayer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "2:84" })
        let inside = try #require(contentLayer.effectiveMask?.color(at: CGPoint(x: contentLayer.image.size.width / 2, y: contentLayer.image.size.height / 2)))
        let corner = try #require(contentLayer.effectiveMask?.color(at: .zero))
        #expect(inside.alphaComponent > 0.9)
        #expect(corner.alphaComponent < 0.1)
    }

    @Test func mapperReportsPartialImageComponentLayoutAndUnsupportedNodes() async throws {
        let transport = RecordingFigmaNodeTransport(statusCode: 200, body: Self.validNodeResponse)
        let client = XomoFigmaNodeContentAPIClient(transport: transport)
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3"
        )

        let plan = try await client.fetchPlan(for: preview, credential: token)
        let text = try #require(plan.items.first { $0.sourceID == "2:2" })
        let image = try #require(plan.items.first { $0.sourceID == "2:6" })
        let component = try #require(plan.items.first { $0.sourceID == "2:7" })
        let unsupported = try #require(plan.items.first { $0.sourceID == "2:8" })

        #expect(image.targetKind == .imagePlaceholder)
        #expect(image.fidelity == .partial)
        #expect(image.issues.contains(.imageAssetPending))
        #expect(image.imageReference == "img-ref-1")
        #expect(component.targetKind == .group)
        #expect(component.fidelity == .partial)
        #expect(component.componentRole == .component)
        #expect(component.componentProperties["Size"] == XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Large",
            preferredValues: [
                XomoFigmaComponentPreferredValue(key: "Small", name: "Small"),
                XomoFigmaComponentPreferredValue(key: "Large", name: "Large")
            ]
        ))
        #expect(component.componentProperties["Is Enabled"]?.value == "true")
        #expect(component.issues.contains(.componentSemanticsFlattened))
        #expect(!component.issues.contains(.autoLayoutFlattened))
        #expect(component.stackLayout == ImageEditorStackLayout(
            axis: .vertical,
            spacing: 12,
            paddingTop: 8,
            paddingRight: 16,
            paddingBottom: 8,
            paddingLeft: 16,
            primaryAlignment: .center,
            crossAlignment: .end,
            primarySizingMode: .hug,
            crossSizingMode: .hug
        ))
        #expect(unsupported.targetKind == nil)
        #expect(unsupported.fidelity == .unsupported)
        #expect(unsupported.issues == [.unsupportedNodeType])
        #expect(text.fidelity == .partial)
        #expect(text.issues.contains(.textFontWeightFlattened))
        #expect(!text.issues.contains(.textCaseFlattened))
        #expect(plan.exactCount == 5)
        #expect(plan.partialCount == 3)
        #expect(plan.unsupportedCount == 1)
    }

    @Test func mapperKeepsUniformCornersAndReportsIndependentOrSmoothedCorners() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Corners",
                  "nodes": {
                    "1:20": {
                      "document": {
                        "id": "1:20",
                        "name": "Corners Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 320, "height": 240},
                        "children": [
                          {
                            "id": "2:20",
                            "name": "Uniform",
                            "type": "RECTANGLE",
                            "rectangleCornerRadii": [6, 6, 6, 6],
                            "absoluteBoundingBox": {"x": 10, "y": 10, "width": 100, "height": 40}
                          },
                          {
                            "id": "2:21",
                            "name": "Independent",
                            "type": "RECTANGLE",
                            "rectangleCornerRadii": [4, 8, 12, 16],
                            "absoluteBoundingBox": {"x": 10, "y": 70, "width": 100, "height": 40}
                          },
                          {
                            "id": "2:22",
                            "name": "Smoothed",
                            "type": "RECTANGLE",
                            "cornerRadius": 10,
                            "cornerSmoothing": 0.6,
                            "absoluteBoundingBox": {"x": 10, "y": 130, "width": 100, "height": 40}
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:20")
        let uniform = try #require(plan.items.first { $0.sourceID == "2:20" })
        let independent = try #require(plan.items.first { $0.sourceID == "2:21" })
        let smoothed = try #require(plan.items.first { $0.sourceID == "2:22" })

        #expect(uniform.cornerRadius == 6)
        #expect(uniform.fidelity == .exact)
        #expect(!uniform.issues.contains(.cornerRadiusFlattened))
        #expect(independent.cornerRadius == nil)
        #expect(independent.cornerRadii == XomoFigmaPlanCornerRadii(
            topLeft: 4,
            topRight: 8,
            bottomRight: 12,
            bottomLeft: 16
        ))
        #expect(independent.fidelity == .exact)
        #expect(!independent.issues.contains(.cornerRadiusFlattened))
        #expect(smoothed.cornerRadius == 10)
        #expect(smoothed.cornerSmoothing == 0.6)
        #expect(smoothed.fidelity == .partial)
        #expect(smoothed.issues.contains(.cornerRadiusFlattened))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let independentLayer = try #require(
            materialized.layers.first { $0.name == "Independent" }
        )
        let smoothedLayer = try #require(
            materialized.layers.first { $0.name == "Smoothed" }
        )
        let scale = independentLayer.frame.width / 100
        #expect(independentLayer.shapeContent?.cornerRadii == ImageEditorRectangleCornerRadii(
            topLeft: 4 * scale,
            topRight: 8 * scale,
            bottomRight: 12 * scale,
            bottomLeft: 16 * scale
        ))
        #expect(smoothedLayer.shapeContent?.cornerSmoothing == 0.6)
    }

    @Test func oversizedFigmaCornerRadiiReportGeometryClamp() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Corners","nodes":{"1:23":{"document":{"id":"1:23","name":"Corners","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":240,"height":120},"children":[{"id":"2:23","name":"Uniform","type":"RECTANGLE","cornerRadius":40,"absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":40}},{"id":"2:24","name":"Independent","type":"RECTANGLE","rectangleCornerRadii":[8,30,12,4],"absoluteBoundingBox":{"x":120,"y":0,"width":80,"height":40}}]}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:23")
        let uniform = try #require(plan.items.first { $0.sourceID == "2:23" })
        let independent = try #require(plan.items.first { $0.sourceID == "2:24" })
        for item in [uniform, independent] {
            #expect(item.fidelity == .partial)
            #expect(item.issues.contains(.cornerRadiusFlattened))
        }

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let uniformLayer = try #require(result.layers.first { $0.name == "Uniform" })
        let independentLayer = try #require(result.layers.first { $0.name == "Independent" })
        let uniformScale = uniformLayer.frame.width / 100
        let independentScale = independentLayer.frame.width / 80
        #expect(uniformLayer.shapeContent?.cornerRadius == 20 * uniformScale)
        #expect(independentLayer.shapeContent?.cornerRadii?.topRight == 20 * independentScale)
    }

    @Test func mapperUsesStrokeGeometryAndReportsInheritedRotatedTransform() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Rotated",
                  "nodes": {
                    "1:9": {
                      "document": {
                        "id": "1:9",
                        "name": "Rotated Frame",
                        "type": "FRAME",
                        "clipsContent": true,
                        "relativeTransform": [[0, -1, 100], [1, 0, 200]],
                        "absoluteBoundingBox": {"x": 100, "y": 200, "width": 80, "height": 120},
                        "children": [{
                          "id": "2:9",
                          "name": "Stroke Only",
                          "type": "LINE",
                          "size": {"width": 40, "height": 1},
                          "strokes": [{"type": "SOLID", "color": {"r": 1, "g": 0, "b": 0}}],
                          "strokeWeight": 3,
                          "strokeGeometry": [{"path": "M 0 0 L 40 0"}],
                          "absoluteBoundingBox": {"x": 110, "y": 210, "width": 40, "height": 3}
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:9")
        let frame = try #require(plan.items.first { $0.sourceID == "1:9" })
        let line = try #require(plan.items.first { $0.sourceID == "2:9" })

        #expect(frame.fidelity == .partial)
        #expect(frame.issues.contains(.transformFlattened))
        #expect(frame.clipsContent)
        #expect(!frame.issues.contains(.clippingFlattened))
        #expect(line.targetKind == .vector)
        #expect(line.vectorPaths == ["M 0 0 L 40 0"])
        #expect(line.issues.contains(.transformFlattened))
        #expect(line.solidStroke?.red == 1)
        #expect(line.strokeWeight == 3)
    }

    @Test func mapperAndMaterializerPreserveFigmaStrokeCapAndJoin() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Stroke Styles",
                  "nodes": {
                    "1:20": {
                      "document": {
                        "id": "1:20",
                        "name": "Stroke Styles",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 160, "height": 120},
                        "children": [{
                          "id": "2:20",
                          "name": "Bevel Square",
                          "type": "RECTANGLE",
                          "fills": [],
                          "strokes": [{"type": "SOLID", "color": {"r": 0, "g": 0, "b": 0, "a": 1}}],
                          "strokeWeight": 6,
                          "strokeAlign": "OUTSIDE",
                          "strokeCap": "SQUARE",
                          "strokeJoin": "BEVEL",
                          "strokeDashes": [6, 3],
                          "absoluteBoundingBox": {"x": 20, "y": 20, "width": 80, "height": 48}
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:20")
        let item = try #require(plan.items.first { $0.sourceID == "2:20" })
        #expect(item.strokeCap == "SQUARE")
        #expect(item.strokeJoin == "BEVEL")
        #expect(item.strokeDashes == [6, 3])
        #expect(item.strokeAlign == "OUTSIDE")
        #expect(!item.issues.contains(.strokeStyleFlattened))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let layer = try #require(materialized.layers.first { $0.name == "Bevel Square" })
        #expect(layer.shapeContent?.strokeCap == .square)
        #expect(layer.shapeContent?.strokeJoin == .bevel)
        #expect(layer.shapeContent?.strokeDashPattern == [6 * (layer.frame.width / 80), 3 * (layer.frame.width / 80)])
        #expect(layer.shapeContent?.strokePosition == .outside)

        var noneItem = item
        noneItem.strokeCap = "NONE"
        let noneLayer = XomoFigmaNodeMaterializer.materialize(
            plan: XomoFigmaNodeImportPlan(
                fileName: "stroke.json",
                version: nil,
                rootSourceID: "2:20",
                rootName: "Bevel Square",
                items: [noneItem]
            ),
            canvasSize: CGSize(width: 320, height: 240)
        ).layers.first
        #expect(noneLayer?.shapeContent?.strokeCap == .butt)
    }

    @Test func unsupportedFigmaStrokeStylesReportEditableFallbacks() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Stroke Fallbacks","nodes":{"1:24":{"document":{"id":"1:24","name":"Stroke Fallbacks","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":240,"height":120},"children":[{"id":"2:25","name":"Unknown Stroke","type":"RECTANGLE","fills":[],"strokes":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"strokeWeight":4,"strokeAlign":"FUTURE","strokeCap":"TRIANGLE","strokeJoin":"ARCS","absoluteBoundingBox":{"x":0,"y":0,"width":80,"height":40}},{"id":"2:26","name":"Invalid Dash","type":"RECTANGLE","fills":[],"strokes":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"strokeWeight":4,"strokeDashes":[8],"absoluteBoundingBox":{"x":100,"y":0,"width":80,"height":40}}]}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:24")
        let unknown = try #require(plan.items.first { $0.sourceID == "2:25" })
        let invalidDash = try #require(plan.items.first { $0.sourceID == "2:26" })
        for item in [unknown, invalidDash] {
            #expect(item.fidelity == .partial)
            #expect(item.issues.contains(.strokeStyleFlattened))
        }

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let unknownLayer = try #require(result.layers.first { $0.name == "Unknown Stroke" })
        let dashLayer = try #require(result.layers.first { $0.name == "Invalid Dash" })
        #expect(unknownLayer.shapeContent?.strokePosition == .inside)
        #expect(unknownLayer.shapeContent?.strokeCap == .round)
        #expect(unknownLayer.shapeContent?.strokeJoin == .round)
        #expect(dashLayer.shapeContent?.strokeDashPattern.isEmpty == true)
    }

    @Test func mapperImportsHorizontalWrapAndCounterSpacingWithFillChildSemantics() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Wrapped",
                  "nodes": {
                    "1:10": {
                      "document": {
                        "id": "1:10",
                        "name": "Wrapped Frame",
                        "type": "FRAME",
                        "layoutMode": "HORIZONTAL",
                        "layoutWrap": "WRAP",
                        "primaryAxisSizingMode": "FIXED",
                        "itemSpacing": 6,
                        "counterAxisSpacing": 14,
                        "counterAxisAlignContent": "AUTO",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 200, "height": 100},
                        "children": [{
                          "id": "1:11",
                          "name": "Fill Child",
                          "type": "RECTANGLE",
                          "layoutGrow": 1,
                          "layoutAlign": "STRETCH",
                          "absoluteBoundingBox": {"x": 0, "y": 0, "width": 40, "height": 20}
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:10")
        let frame = try #require(plan.items.first { $0.sourceID == "1:10" })
        let child = try #require(plan.items.first { $0.sourceID == "1:11" })
        #expect(frame.stackLayout?.axis == .horizontal)
        #expect(frame.stackLayout?.spacing == 6)
        #expect(frame.stackLayout?.wrapMode == .wrap)
        #expect(frame.stackLayout?.counterSpacing == 14)
        #expect(!frame.issues.contains(.autoLayoutFlattened))
        #expect(!child.issues.contains(.autoLayoutFlattened))
        #expect(child.stackChildLayout == ImageEditorStackChildLayout(
            grow: 1,
            stretchesCrossAxis: true
        ))
    }

    @Test func mapperSupportsHorizontalBaselineAndReportsUnknownTrackDistribution() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Unsupported wrapped alignment",
                  "nodes": {
                    "1:12": {
                      "document": {
                        "id": "1:12",
                        "name": "Baseline Wrap",
                        "type": "FRAME",
                        "layoutMode": "HORIZONTAL",
                        "layoutWrap": "WRAP",
                        "counterAxisAlignItems": "BASELINE",
                        "counterAxisAlignContent": "SPACE_AROUND",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 200, "height": 100}
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:12")
        let frame = try #require(plan.items.first)
        #expect(frame.stackLayout?.wrapMode == .wrap)
        #expect(frame.stackLayout?.crossAlignment == .baseline)
        #expect(frame.issues.contains(.autoLayoutFlattened))
        #expect(frame.fidelity == .partial)
    }

    @Test func mapperImportsHorizontalWrappedSpaceBetweenTracksAsNativeLayout() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Space between rows",
                  "nodes": {
                    "1:15": {
                      "document": {
                        "id": "1:15",
                        "name": "Wrapped distribution",
                        "type": "FRAME",
                        "layoutMode": "HORIZONTAL",
                        "layoutWrap": "WRAP",
                        "counterAxisAlignContent": "SPACE_BETWEEN",
                        "counterAxisSpacing": 12,
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 240, "height": 180}
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:15")
        let frame = try #require(plan.items.first)
        #expect(frame.stackLayout?.wrapMode == .wrap)
        #expect(frame.stackLayout?.crossTrackAlignment == .spaceBetween)
        #expect(frame.stackLayout?.counterSpacing == 12)
        #expect(!frame.issues.contains(.autoLayoutFlattened))
        #expect(frame.fidelity == .exact)
    }

    @Test func mapperPreservesFigmaVariableBindingsAndProjectRoundTrip() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Variable bindings",
                  "nodes": {
                    "1:16": {
                      "document": {
                        "id": "1:16",
                        "name": "Token Button",
                        "type": "RECTANGLE",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 120, "height": 44},
                        "fills": [{"type": "SOLID", "color": {"r": 0.2, "g": 0.4, "b": 0.8}}],
                        "boundVariables": {
                          "fills": [{"type": "VARIABLE_ALIAS", "id": "VariableID:brand-fill"}],
                          "characters": {"type": "VARIABLE_ALIAS", "id": "VariableID:body-font"}
                        }
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:16")
        let item = try #require(plan.items.first)
        #expect(item.variableBindings == [
            XomoFigmaVariableBinding(field: "fills", variableID: "VariableID:brand-fill"),
            XomoFigmaVariableBinding(field: "characters", variableID: "VariableID:body-font")
        ])
        #expect(item.issues.contains(.variableBindingPreserved))
        #expect(item.fidelity == .partial)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let layer = try #require(materialized.layers.first)
        #expect(layer.xomoFigmaVariableBindings == item.variableBindings)

        var document = ImageEditorDocument(
            sourceName: "variables.png",
            image: NSImage.transparent(size: CGSize(width: 400, height: 300))
        )
        document.layers.append(contentsOf: materialized.layers)
        let project = try ImageEditorProjectDocument(document: document)
        let restored = try project.restoredDocument()
        let restoredLayer = try #require(restored.layers.first { $0.id == layer.id })
        #expect(restoredLayer.xomoFigmaVariableBindings == item.variableBindings)
    }

    @Test func imageFillSourceMetadataSurvivesMaterializationAndProjectRoundTrip() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Image metadata",
                  "nodes": {
                    "1:17": {
                      "document": {
                        "id": "1:17",
                        "name": "Hero",
                        "type": "RECTANGLE",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 240, "height": 120},
                        "fills": [{
                          "type": "IMAGE",
                          "imageRef": "img-ref-hero",
                          "scaleMode": "CROP",
                          "imageTransform": [[0.8, 0.1, 0.12], [-0.1, 0.9, 0.08]],
                          "scalingFactor": 1.5,
                          "rotation": 90,
                          "filters": {
                            "exposure": 0.25,
                            "contrast": -0.2,
                            "saturation": 0.1
                          }
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:17"
        )
        let item = try #require(plan.items.first)
        #expect(item.targetKind == .imagePlaceholder)
        #expect(item.imageReference == "img-ref-hero")
        let transform = try #require(item.imageTransform)
        #expect(transform.translationX == 0.12)
        #expect(item.imageFilters.exposure == 0.25)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let layer = try #require(materialized.layers.first)
        let metadata = try #require(layer.xomoFigmaImageFill)
        #expect(metadata.imageReference == "img-ref-hero")
        #expect(metadata.scaleMode == "CROP")
        #expect(metadata.imageTransform == item.imageTransform)
        #expect(metadata.scalingFactor == 1.5)
        #expect(metadata.rotation == 90)
        #expect(metadata.filters == item.imageFilters)

        var document = ImageEditorDocument(
            sourceName: "image-metadata.png",
            image: NSImage.transparent(size: CGSize(width: 400, height: 300))
        )
        document.layers.append(contentsOf: materialized.layers)
        let project = try ImageEditorProjectDocument(document: document)
        let restored = try project.restoredDocument()
        let restoredLayer = try #require(restored.layers.first { $0.id == layer.id })
        #expect(restoredLayer.xomoFigmaImageFill == metadata)
    }

    @Test func figmaVariablesResolveDefaultModeColorsAndAliases() async throws {
        let transport = RecordingFigmaNodeTransport(
            statusCode: 200,
            body: Data(
                """
                {
                  "meta": {
                    "variables": {
                      "VariableID:brand-fill": {
                        "id": "VariableID:brand-fill",
                        "name": "Brand Fill",
                        "variableCollectionId": "CollectionID:tokens",
                        "resolvedType": "COLOR",
                        "valuesByMode": {
                          "ModeID:default": {"type": "VARIABLE_ALIAS", "id": "VariableID:brand-base"}
                        }
                      },
                      "VariableID:brand-base": {
                        "id": "VariableID:brand-base",
                        "name": "Brand Base",
                        "variableCollectionId": "CollectionID:tokens",
                        "resolvedType": "COLOR",
                        "valuesByMode": {
                          "ModeID:default": {"r": 0.1, "g": 0.3, "b": 0.8, "a": 0.9}
                        }
                      }
                    },
                    "variableCollections": {
                      "CollectionID:tokens": {
                        "id": "CollectionID:tokens",
                        "name": "Tokens",
                        "defaultModeId": "ModeID:default",
                        "modes": [{"modeId": "ModeID:default", "name": "Default"}]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let credential = try XomoFigmaPersonalAccessToken(validating: "figma-test-token")
        let client = XomoFigmaVariableAPIClient(
            baseURL: URL(string: "https://example.test")!,
            transport: transport
        )

        let store = try await client.fetchVariables(fileKey: "file-key", credential: credential)
        #expect(store.color(for: "VariableID:brand-fill") == XomoFigmaPlanColor(
            red: 0.1, green: 0.3, blue: 0.8, alpha: 0.9
        ))
        #expect(transport.lastRequest?.url?.path == "/v1/files/file-key/variables/local")
        #expect(transport.lastRequest?.value(forHTTPHeaderField: "X-Figma-Token") == credential.rawValue)

        let item = XomoFigmaNodeImportItem(
            sourceID: "node",
            parentSourceID: nil,
            depth: 0,
            sourceName: "Token",
            sourceType: "RECTANGLE",
            targetKind: .rectangle,
            fidelity: .partial,
            issues: [.variableBindingPreserved],
            variableBindings: [XomoFigmaVariableBinding(field: "fills", variableID: "VariableID:brand-fill")],
            frame: XomoFigmaPlanRect(x: 0, y: 0, width: 20, height: 20),
            opacity: 1,
            isVisible: true,
            solidFill: XomoFigmaPlanColor(red: 1, green: 1, blue: 1, alpha: 1),
            solidStroke: nil,
            strokeWeight: nil,
            cornerRadius: nil,
            text: nil,
            vectorPaths: [],
            geometrySize: nil,
            relativeTransform: nil,
            clipsContent: false,
            isMask: false,
            maskFrame: nil,
            imageReference: nil,
            imageScaleMode: nil,
            imageTransform: nil,
            imageScalingFactor: nil,
            imageRotation: nil,
            stackLayout: nil,
            stackChildLayout: nil,
            isStackLayoutExcluded: false
        )
        let plan = XomoFigmaNodeImportPlan(
            fileName: "Variables",
            version: nil,
            rootSourceID: "node",
            rootName: "Token",
            items: [item]
        )
        let resolved = try #require(plan.resolvingVariables(store).items.first)
        #expect(resolved.solidFill == XomoFigmaPlanColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 0.9))
        #expect(resolved.issues.isEmpty)
        #expect(resolved.fidelity == .exact)
    }

    @Test func mapperImportsHorizontalBaselineAsEditableNativeLayout() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Baseline row",
                  "nodes": {
                    "1:13": {
                      "document": {
                        "id": "1:13",
                        "name": "Baseline Row",
                        "type": "FRAME",
                        "layoutMode": "HORIZONTAL",
                        "counterAxisAlignItems": "BASELINE",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 200, "height": 80}
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:13")
        let frame = try #require(plan.items.first)
        #expect(frame.stackLayout?.axis == .horizontal)
        #expect(frame.stackLayout?.crossAlignment == .baseline)
        #expect(!frame.issues.contains(.autoLayoutFlattened))
        #expect(frame.fidelity == .exact)
    }

    @Test func mapperKeepsInvalidVerticalBaselineAsExplicitDowngrade() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Invalid baseline column",
                  "nodes": {
                    "1:14": {
                      "document": {
                        "id": "1:14",
                        "name": "Baseline Column",
                        "type": "FRAME",
                        "layoutMode": "VERTICAL",
                        "counterAxisAlignItems": "BASELINE",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 200}
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:14")
        let frame = try #require(plan.items.first)
        #expect(frame.stackLayout?.axis == .vertical)
        #expect(frame.stackLayout?.crossAlignment == .start)
        #expect(frame.issues.contains(.autoLayoutFlattened))
        #expect(frame.fidelity == .partial)
    }

    @Test func clientMapsBadRequestAuthorizationMissingNodeRateLimitAndServerErrors() async throws {
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3"
        )
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let expectations: [(Int, XomoFigmaNodeImportError)] = [
            (400, .invalidRequest),
            (401, .authorizationDenied),
            (403, .authorizationDenied),
            (404, .fileNotFound),
            (429, .rateLimited),
            (503, .serviceUnavailable)
        ]

        for (statusCode, expectedError) in expectations {
            let client = XomoFigmaNodeContentAPIClient(
                transport: RecordingFigmaNodeTransport(statusCode: statusCode, body: Data())
            )
            await #expect(throws: expectedError) {
                try await client.fetchPlan(for: preview, credential: token)
            }
        }
    }

    @Test func clientRejectsMissingNodeOversizedResponsesAndExcessiveTrees() async throws {
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3"
        )
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let missingNode = Data(#"{"name":"Checkout","nodes":{"1:3":null}}"#.utf8)
        let oversized = Data(repeating: 65, count: XomoFigmaNodeContentAPIClient.maximumResponseBytes + 1)
        let tooManyChildren = (0...XomoFigmaNodeImportMapper.maximumNodeCount).map {
            #"{"id":"9:\#($0)","name":"N","type":"RECTANGLE","absoluteBoundingBox":{"x":0,"y":0,"width":1,"height":1}}"#
        }.joined(separator: ",")
        let excessiveTree = Data(
            #"{"name":"Checkout","nodes":{"1:3":{"document":{"id":"1:3","name":"Root","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":10,"height":10},"children":[\#(tooManyChildren)]}}}}"#.utf8
        )

        await #expect(throws: XomoFigmaNodeImportError.nodeNotFound) {
            try await XomoFigmaNodeContentAPIClient(
                transport: RecordingFigmaNodeTransport(statusCode: 200, body: missingNode)
            ).fetchPlan(for: preview, credential: token)
        }
        await #expect(throws: XomoFigmaNodeImportError.responseTooLarge) {
            try await XomoFigmaNodeContentAPIClient(
                transport: RecordingFigmaNodeTransport(statusCode: 200, body: oversized)
            ).fetchPlan(for: preview, credential: token)
        }
        await #expect(throws: XomoFigmaNodeImportError.nodeLimitExceeded) {
            try await XomoFigmaNodeContentAPIClient(
                transport: RecordingFigmaNodeTransport(statusCode: 200, body: excessiveTree)
            ).fetchPlan(for: preview, credential: token)
        }
    }

    @Test func controllerDoesNotReadUntilExplicitUserActionAndClearsStalePlan() async throws {
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let store = InMemoryFigmaNodeCredentialStore(credential: token)
        let fetcher = RecordingFigmaNodePlanFetcher(result: .success(Self.samplePlan))
        let controller = XomoFigmaNodeImportController(store: store, fetcher: fetcher)
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3"
        )

        #expect(fetcher.calls.isEmpty)
        #expect(controller.state == .idle)

        await controller.fetchPlan(preview: preview)

        #expect(fetcher.calls == ["1:3"])
        #expect(controller.state == .loaded(Self.samplePlan))

        controller.clear()
        #expect(controller.state == .idle)
    }

    @Test func sheetMakesNodeReadExplicitAndRequiresNodeSelection() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sheet = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoFigmaLinkImportSheet.swift"),
            encoding: .utf8
        )

        #expect(sheet.contains("XomoFigmaNodeImportController"))
        #expect(sheet.contains("xomo-figma-read-node-plan"))
        #expect(sheet.contains("preview.nodeID == nil"))
        #expect(sheet.contains("await nodeImportController.fetchPlan(preview: preview)"))
        #expect(sheet.contains("viewModel.importFigmaNodePlan(plan)"))
        #expect(sheet.contains("xomo-figma-import-node-plan"))
        #expect(!sheet.contains(".onChange(of: draft.preview) { await nodeImportController.fetchPlan"))
    }

    @Test nonisolated func svgParserSupportsRelativeCurvesQuadraticsAndArcs() throws {
        let result = try #require(XomoSVGPathParser.parse(
            "M 0 0 l 20 0 q 10 0 10 10 t 10 10 a 10 10 0 0 1 10 10 z"
        ))
        let anchors = try #require(result.subpaths.first)

        #expect(result.isClosed)
        #expect(anchors.count >= 5)
        #expect(anchors.first?.point == .zero)
        #expect(anchors[1].point == CGPoint(x: 20, y: 0))
        #expect(anchors[1].outControl != nil)
        #expect(anchors.last?.point == CGPoint(x: 50, y: 30))
        #expect(XomoSVGPathParser.parse("M 0 0 B 10 10") == nil)
        #expect(XomoSVGPathParser.parse("M 0 0 C 1 2") == nil)
    }

    @Test func supportedFigmaShadowsBecomeEditableLayerEffects() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Effects",
                  "nodes": {
                    "1:40": {
                      "document": {
                        "id": "1:40",
                        "name": "Effects Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 240, "height": 160},
                        "children": [
                          {
                            "id": "2:40",
                            "name": "Shadowed Card",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 20, "width": 120, "height": 48},
                            "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}],
                            "effects": [
                              {"type": "DROP_SHADOW", "color": {"r": 0.1, "g": 0.2, "b": 0.3, "a": 0.45}, "offset": {"x": 4, "y": 6}, "radius": 8, "spread": 2, "visible": true},
                              {"type": "INNER_SHADOW", "color": {"r": 0.8, "g": 0.1, "b": 0.2, "a": 0.25}, "offset": {"x": -2, "y": 3}, "radius": 4, "visible": true}
                            ]
                          },
                          {
                            "id": "2:41",
                            "name": "Blurred Card",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 90, "width": 120, "height": 48},
                            "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}],
                            "effects": [
                              {"type": "LAYER_BLUR", "radius": 6, "visible": true},
                              {"type": "BACKGROUND_BLUR", "radius": 4, "visible": true}
                            ]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:40"
        )
        let shadowed = try #require(plan.items.first { $0.sourceID == "2:40" })
        #expect(shadowed.effects.count == 2)
        #expect(shadowed.fidelity == .exact)
        #expect(!shadowed.issues.contains(.effectsFlattened))
        let blurred = try #require(plan.items.first { $0.sourceID == "2:41" })
        #expect(blurred.effects.count == 2)
        #expect(blurred.effects.map(\.kind) == [.layerBlur, .backgroundBlur])
        #expect(blurred.fidelity == .exact)
        #expect(!blurred.issues.contains(.effectsFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let layer = try #require(result.layers.first { $0.name == "Shadowed Card" })
        #expect(layer.style.shadowEnabled)
        #expect(layer.style.innerShadowEnabled)
        #expect(abs(layer.style.shadowBlur - 8) < 0.001)
        #expect(abs(layer.style.shadowSpread - 2) < 0.001)
        #expect(abs(layer.style.shadowOffset.width - 4) < 0.001)
        #expect(abs(layer.style.shadowOffset.height - 6) < 0.001)
        #expect(abs(layer.style.innerShadowDistance - sqrt(13)) < 0.001)
        let blurredLayer = try #require(result.layers.first { $0.name == "Blurred Card" })
        #expect(blurredLayer.smartFilters.count == 2)
        #expect(blurredLayer.smartFilters.first?.kind == .gaussianBlur)
        #expect(blurredLayer.smartFilters.first?.normalizedSettings.gaussianBlurRadius == 6)
        #expect(blurredLayer.smartFilters.first?.appliesToBackdrop == false)
        #expect(blurredLayer.smartFilters.last?.kind == .gaussianBlur)
        #expect(blurredLayer.smartFilters.last?.normalizedSettings.gaussianBlurRadius == 4)
        #expect(blurredLayer.smartFilters.last?.appliesToBackdrop == true)
    }

    @Test func outOfRangeFigmaEffectsUseEditableBoundsAndReportPartialFidelity() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Effect Bounds","nodes":{"1:42":{"document":{"id":"1:42","name":"Effect Bounds","type":"RECTANGLE","effects":[{"type":"DROP_SHADOW","radius":45,"spread":30,"offset":{"x":4,"y":6},"color":{"r":1.2,"g":-0.2,"b":0.4,"a":1.3}},{"type":"LAYER_BLUR","radius":300}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:42")
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.effectsFlattened))
        #expect(item.effects.count == 2)
        let shadow = try #require(item.effects.first { $0.kind == .dropShadow })
        #expect(shadow.radius == 30)
        #expect(shadow.spread == 24)
        #expect(shadow.color == XomoFigmaPlanColor(red: 1, green: 0, blue: 0.4, alpha: 1))
        #expect(item.effects.first { $0.kind == .layerBlur }?.radius == 256)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 180)
        )
        let layer = try #require(result.layers.first)
        #expect(layer.style.shadowBlur == 30)
        #expect(layer.style.shadowSpread == 24)
        #expect(layer.style.shadowOpacity == 1)
        #expect(layer.smartFilters.first?.normalizedSettings.gaussianBlurRadius == 256)
    }

    @Test func outOfRangeFigmaShadowOffsetsPreserveDirectionAtEditableDistances() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Shadow Distance","nodes":{"1:43":{"document":{"id":"1:43","name":"Far Shadows","type":"RECTANGLE","effects":[{"type":"DROP_SHADOW","radius":8,"spread":2,"offset":{"x":60,"y":80},"color":{"r":0,"g":0,"b":0,"a":0.5}},{"type":"INNER_SHADOW","radius":6,"spread":1,"offset":{"x":60,"y":80},"color":{"r":0,"g":0,"b":0,"a":0.4}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:43")
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.effectsFlattened))
        let drop = try #require(item.effects.first { $0.kind == .dropShadow })
        let inner = try #require(item.effects.first { $0.kind == .innerShadow })
        #expect(abs(drop.offsetX - 48) < 0.001)
        #expect(abs(drop.offsetY - 64) < 0.001)
        #expect(abs(hypot(drop.offsetX, drop.offsetY) - 80) < 0.001)
        #expect(abs(inner.offsetX - 28.8) < 0.001)
        #expect(abs(inner.offsetY - 38.4) < 0.001)
        #expect(abs(hypot(inner.offsetX, inner.offsetY) - 48) < 0.001)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 180)
        )
        let layer = try #require(result.layers.first)
        #expect(abs(layer.style.shadowDistance - 80) < 0.001)
        #expect(abs(layer.style.innerShadowDistance - 48) < 0.001)
        #expect(abs(layer.style.shadowAngle - layer.style.innerShadowAngle) < 0.001)
    }

    @Test func duplicateFigmaEffectKindsKeepDeterministicEditableFallback() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Duplicate Effects","nodes":{"1:44":{"document":{"id":"1:44","name":"Two Shadows","type":"RECTANGLE","effects":[{"type":"DROP_SHADOW","radius":4,"spread":1,"offset":{"x":2,"y":3},"color":{"r":1,"g":0,"b":0,"a":0.3}},{"type":"DROP_SHADOW","radius":12,"spread":4,"offset":{"x":6,"y":8},"color":{"r":0,"g":0,"b":1,"a":0.7}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:44")
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.effectsFlattened))
        #expect(item.effects.count == 1)
        let shadow = try #require(item.effects.first)
        #expect(shadow.kind == .dropShadow)
        #expect(shadow.radius == 12)
        #expect(shadow.spread == 4)
        #expect(shadow.offsetX == 6)
        #expect(shadow.offsetY == 8)
        #expect(shadow.color == XomoFigmaPlanColor(red: 0, green: 0, blue: 1, alpha: 0.7))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 180)
        )
        let layer = try #require(result.layers.first)
        #expect(layer.style.shadowBlur == 12)
        #expect(layer.style.shadowSpread == 4)
        #expect(layer.style.shadowOffset == CGSize(width: 6, height: 8))
        #expect(layer.style.shadowOpacity == 0.7)
    }

    @Test func nonNormalFigmaEffectBlendModeReportsEditableFallback() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Effect Blend","nodes":{"1:45":{"document":{"id":"1:45","name":"Multiply Shadow","type":"RECTANGLE","effects":[{"type":"DROP_SHADOW","blendMode":"MULTIPLY","radius":10,"spread":3,"offset":{"x":4,"y":6},"color":{"r":0.2,"g":0.3,"b":0.4,"a":0.6}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:45")
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.effectsFlattened))
        let shadow = try #require(item.effects.first)
        #expect(shadow.kind == .dropShadow)
        #expect(shadow.radius == 10)
        #expect(shadow.spread == 3)
        #expect(shadow.offsetX == 4)
        #expect(shadow.offsetY == 6)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 180)
        )
        let layer = try #require(result.layers.first)
        #expect(layer.style.shadowEnabled)
        #expect(layer.style.shadowBlur == 10)
        #expect(layer.style.shadowSpread == 3)
        #expect(layer.style.shadowOpacity == 0.6)
    }

    @Test func hiddenBehindNodeFigmaShadowReportsEditableFallback() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Shadow Visibility","nodes":{"1:46":{"document":{"id":"1:46","name":"Outside Only Shadow","type":"RECTANGLE","effects":[{"type":"DROP_SHADOW","showShadowBehindNode":false,"radius":9,"spread":2,"offset":{"x":5,"y":7},"color":{"r":0.1,"g":0.2,"b":0.3,"a":0.55}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:46")
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.effectsFlattened))
        let shadow = try #require(item.effects.first)
        #expect(shadow.kind == .dropShadow)
        #expect(shadow.radius == 9)
        #expect(shadow.spread == 2)
        #expect(shadow.offsetX == 5)
        #expect(shadow.offsetY == 7)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 180)
        )
        let layer = try #require(result.layers.first)
        #expect(layer.style.shadowEnabled)
        #expect(layer.style.shadowBlur == 9)
        #expect(layer.style.shadowSpread == 2)
        #expect(layer.style.shadowOffset == CGSize(width: 5, height: 7))
        #expect(layer.style.shadowOpacity == 0.55)
    }

    @Test func disabledFigmaEffectReportsLostEditableSemanticsWithoutRendering() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Disabled Effect","nodes":{"1:47":{"document":{"id":"1:47","name":"Disabled Shadow","type":"RECTANGLE","effects":[{"type":"DROP_SHADOW","visible":false,"radius":9,"spread":2,"offset":{"x":5,"y":7},"color":{"r":0.1,"g":0.2,"b":0.3,"a":0.55}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:47")
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.effectsFlattened))
        #expect(item.effects.isEmpty)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 180)
        )
        let layer = try #require(result.layers.first)
        #expect(!layer.style.shadowEnabled)
        #expect(!layer.style.innerShadowEnabled)
        #expect(layer.smartFilters.isEmpty)
    }

    @Test func disabledFigmaPaintReportsLostEditableSemanticsWithoutRendering() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Disabled Paint","nodes":{"1:48":{"document":{"id":"1:48","name":"Visible Blue","type":"RECTANGLE","fills":[{"type":"SOLID","visible":true,"color":{"r":0.1,"g":0.2,"b":0.8,"a":1}},{"type":"SOLID","visible":false,"color":{"r":1,"g":0,"b":0,"a":1}}],"strokes":[{"type":"SOLID","visible":false,"color":{"r":0,"g":1,"b":0,"a":1}}],"strokeWeight":4,"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:48")
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.unsupportedPaint))
        #expect(item.solidFill == XomoFigmaPlanColor(red: 0.1, green: 0.2, blue: 0.8, alpha: 1))
        #expect(item.solidStroke == nil)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 180)
        )
        let shape = try #require(result.layers.first?.shapeContent)
        let fill = try #require(shape.fillColor.usingColorSpace(.sRGB))
        #expect(abs(fill.redComponent - 0.1) < 0.001)
        #expect(abs(fill.greenComponent - 0.2) < 0.001)
        #expect(abs(fill.blueComponent - 0.8) < 0.001)
        #expect(shape.strokeOpacity == 0)
    }

    @Test func individualFigmaStrokeWeightsUseEditableAverageAndReportPartialFidelity() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Individual Strokes","nodes":{"1:49":{"document":{"id":"1:49","name":"Uneven Border","type":"RECTANGLE","strokes":[{"type":"SOLID","color":{"r":0.2,"g":0.4,"b":0.8,"a":1}}],"strokeWeight":2,"individualStrokeWeights":{"top":2,"right":4,"bottom":6,"left":8},"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:49")
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.strokeWeightFlattened))
        #expect(item.strokeWeight == 5)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 180)
        )
        let shape = try #require(result.layers.first?.shapeContent)
        #expect(shape.strokeWidth == 5)
        #expect(shape.strokeOpacity == 1)
    }

    @Test func uniformFigmaIndividualStrokeWeightsRemainExact() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Uniform Stroke","nodes":{"1:50":{"document":{"id":"1:50","name":"Uniform Border","type":"RECTANGLE","strokes":[{"type":"SOLID","color":{"r":0.2,"g":0.4,"b":0.8,"a":1}}],"strokeWeight":1,"individualStrokeWeights":{"top":3,"right":3,"bottom":3,"left":3},"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:50")
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.strokeWeightFlattened))
        #expect(item.strokeWeight == 3)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 180)
        )
        #expect(result.layers.first?.shapeContent?.strokeWidth == 3)
    }

    @Test func customFigmaMiterAngleMapsToNativeLimitWhileDefaultMiterRemainsExact() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Miter Angles","nodes":{"1:51":{"document":{"id":"1:51","name":"Miter Angles","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":220,"height":80},"children":[{"id":"2:51","name":"Custom Miter","type":"RECTANGLE","strokes":[{"type":"SOLID","color":{"r":0.2,"g":0.4,"b":0.8,"a":1}}],"strokeWeight":4,"strokeJoin":"MITER","strokeMiterAngle":30,"absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":80}},{"id":"2:52","name":"Default Miter","type":"RECTANGLE","strokes":[{"type":"SOLID","color":{"r":0.2,"g":0.4,"b":0.8,"a":1}}],"strokeWeight":4,"strokeJoin":"MITER","absoluteBoundingBox":{"x":120,"y":0,"width":100,"height":80}}]}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:51")
        let custom = try #require(plan.items.first { $0.sourceID == "2:51" })
        let standard = try #require(plan.items.first { $0.sourceID == "2:52" })
        #expect(custom.fidelity == .exact)
        #expect(!custom.issues.contains(.strokeStyleFlattened))
        #expect(custom.strokeJoin == "MITER")
        #expect(abs((custom.strokeMiterLimit ?? 0) - 3.863_703_305) < 0.000_001)
        #expect(standard.fidelity == .exact)
        #expect(!standard.issues.contains(.strokeStyleFlattened))
        #expect(standard.strokeMiterLimit == nil)

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 180)
        )
        #expect(result.layers.first { $0.name == "Custom Miter" }?.shapeContent?.strokeJoin == .miter)
        #expect(abs((result.layers.first { $0.name == "Custom Miter" }?.shapeContent?.strokeMiterLimit ?? 0) - 3.863_703_305) < 0.000_001)
        #expect(result.layers.first { $0.name == "Default Miter" }?.shapeContent?.strokeJoin == .miter)
        #expect(result.layers.first { $0.name == "Default Miter" }?.shapeContent?.strokeMiterLimit == 10)
    }

    @Test func materializerCreatesEditableHierarchyAtCenteredScaleAndHonestPlaceholder() throws {
        let plan = try Self.decodedPlan()
        let textPlan = try #require(plan.items.first { $0.sourceName == "Continue Label" })
        #expect(textPlan.text?.characters == "Continue 继续")
        #expect(textPlan.text?.textCase == .uppercase)
        #expect(textPlan.fidelity == .partial)
        #expect(textPlan.issues.contains(.textFontWeightFlattened))
        #expect(!textPlan.issues.contains(.textCaseFlattened))
        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 600, height: 1_000)
        )
        let root = try #require(result.layers.first { $0.name == "Checkout Frame" })
        let rootBackground = try #require(
            result.layers.first { $0.name == L10n.format("imageEditor.layer.figmaFrameBackground", "Checkout Frame") }
        )
        let actions = try #require(result.layers.first { $0.name == "Actions" })
        let text = try #require(result.layers.first { $0.name == "Continue Label" })
        let rectangle = try #require(result.layers.first { $0.name == "Primary" })
        let vector = try #require(result.layers.first { $0.name == "Arrow" })
        let placeholder = try #require(result.layers.first { $0.name == "Hero Image" })
        let component = try #require(result.layers.first { $0.name == "Card Component" })

        #expect(result.importedCount == 9)
        #expect(result.omittedCount == 1)
        #expect(result.selectedLayerID == root.id)
        #expect(result.layers.last?.id == root.id)
        #expect(root.isGroup)
        #expect(rootBackground.groupID == root.id)
        #expect(rootBackground.isStackLayoutExcluded)
        #expect(rootBackground.isStackLayoutBackground)
        #expect(actions.groupID == root.id)
        #expect(text.groupID == actions.id)
        #expect(text.stackChildLayout == ImageEditorStackChildLayout(
            grow: 1,
            stretchesCrossAxis: true
        ))
        #expect(text.frame.origin == CGPoint(x: 135, y: 138))
        if case let .text(content) = text.kind {
            #expect(content.text == "Continue 继续")
            #expect(content.textCase == .uppercase)
            #expect(content.attributedString.string == "CONTINUE 继续")
            #expect(content.fontFamilyName == "Inter")
            #expect(content.fontSize == 16)
            #expect(content.isBold)
            #expect(content.isItalic)
            #expect(content.isUnderlined)
            #expect(!content.isStruckThrough)
            #expect(content.characterSpacing == -1.5)
            #expect(content.lineSpacing == 6)
            #expect(content.firstLineIndent == 12)
            #expect(content.alignment == .center)
        } else {
            Issue.record("Figma text should materialize as editable text")
        }
        #expect(rectangle.frame == CGRect(x: 125, y: 218, width: 200, height: 44))
        #expect(rectangle.opacity == 0.8)
        #expect(rectangle.isLocked)
        if case let .shape(content) = rectangle.kind {
            #expect(content.fillOpacity == 1)
            #expect(content.cornerRadius == 8)
        } else {
            Issue.record("Figma rectangle should materialize as an editable shape")
        }
        if case let .shape(content) = vector.kind {
            #expect(content.kind == .path)
            #expect(content.pathAnchors.count == 3)
            #expect(content.strokeOpacity == 1)
            #expect(content.strokeWidth == 2)
            #expect(content.isPathClosed)
        } else {
            Issue.record("Figma vector should materialize as an editable path")
        }
        #expect(placeholder.kind.isPixel)
        #expect(placeholder.frame == CGRect(x: 125, y: 348, width: 240, height: 120))
        #expect(component.frame == CGRect(x: 125, y: 488, width: 240, height: 120))
        #expect(component.stackLayout?.axis == .vertical)
        #expect(component.stackLayout?.crossAlignment == .end)
        #expect(component.stackLayout?.primarySizingMode == .hug)
        #expect(component.stackLayout?.crossSizingMode == .hug)
    }

    @Test func viewModelImportsPlanAsSingleUndoableHistoryStep() throws {
        let plan = try Self.decodedPlan()
        let viewModel = ImageEditorViewModel(
            sourceName: "figma-import.png",
            image: NSImage.transparent(size: CGSize(width: 600, height: 1_000))
        ) { _ in }
        let initialLayerCount = viewModel.document.layers.count
        let initialHistoryCount = viewModel.document.history.count

        #expect(viewModel.importFigmaNodePlan(plan))
        #expect(viewModel.document.layers.count == initialLayerCount + 9)
        #expect(viewModel.document.history.count == initialHistoryCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.figmaNodeImport"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.figmaNodeImported", 9, 1))
        #expect(viewModel.document.selectedLayer?.name == "Checkout Frame")

        let restored = try ImageEditorProjectDocument(document: viewModel.document).restoredDocument()
        #expect(restored.layers.count == viewModel.document.layers.count)
        let restoredRoot = try #require(restored.layers.first { $0.name == "Checkout Frame" })
        let restoredActions = try #require(restored.layers.first { $0.name == "Actions" })
        let restoredText = try #require(restored.layers.first { $0.name == "Continue Label" })
        let restoredComponent = try #require(restored.layers.first { $0.name == "Card Component" })
        #expect(restoredRoot.isGroup)
        #expect(restoredActions.groupID == restoredRoot.id)
        #expect(restoredText.groupID == restoredActions.id)
        #expect(restoredComponent.stackLayout?.axis == .vertical)
        #expect(restoredComponent.stackLayout?.spacing == 12)
        #expect(restoredComponent.stackLayout?.primarySizingMode == .hug)
        #expect(restoredComponent.stackLayout?.crossSizingMode == .hug)

        viewModel.undo()
        #expect(viewModel.document.layers.count == initialLayerCount)

        viewModel.redo()
        #expect(viewModel.document.layers.count == initialLayerCount + 9)
        #expect(viewModel.document.selectedLayer?.name == "Checkout Frame")
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.figmaNodeImport"))
    }

    @Test func importedHierarchySurvivesProjectDataAndCompositeExport() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "figma-round-trip.png",
            image: NSImage.transparent(size: CGSize(width: 600, height: 1_000))
        ) { _ in }
        #expect(viewModel.importFigmaNodePlan(try Self.decodedPlan()))

        let projectData = try viewModel.projectData()
        let projectSource = try #require(String(data: projectData, encoding: .utf8))
        #expect(!projectSource.contains("figd_"))
        #expect(!projectSource.contains("X-Figma-Token"))

        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: NSImage.transparent(size: CGSize(width: 8, height: 8))
        ) { _ in }
        try reopened.loadProjectData(projectData)

        #expect(reopened.document.sourceName == "figma-round-trip.png")
        #expect(reopened.document.canvasSize == CGSize(width: 600, height: 1_000))
        #expect(reopened.document.layers.count == viewModel.document.layers.count)
        let root = try #require(reopened.document.layers.first { $0.name == "Checkout Frame" })
        let actions = try #require(reopened.document.layers.first { $0.name == "Actions" })
        let text = try #require(reopened.document.layers.first { $0.name == "Continue Label" })
        let primary = try #require(reopened.document.layers.first { $0.name == "Primary" })
        let vector = try #require(reopened.document.layers.first { $0.name == "Arrow" })
        let placeholder = try #require(reopened.document.layers.first { $0.name == "Hero Image" })
        #expect(root.isGroup)
        #expect(actions.groupID == root.id)
        #expect(text.groupID == actions.id)
        #expect(text.stackChildLayout == ImageEditorStackChildLayout(
            grow: 1,
            stretchesCrossAxis: true
        ))
        #expect(text.textContent?.text == "Continue 继续")
        #expect(text.textContent?.textCase == .uppercase)
        #expect(text.textContent?.attributedString.string == "CONTINUE 继续")
        #expect(primary.shapeContent?.cornerRadius == 8)
        #expect(vector.shapeContent?.kind == .path)
        #expect(vector.shapeContent?.editablePathAnchors.count == 3)
        #expect(placeholder.kind.isPixel)

        let pngData = try #require(reopened.exportData(settings: ImageEditorExportSettings(
            format: .png,
            scope: .composited,
            scale: 1
        )))
        #expect(Array(pngData.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let exportedImage = try #require(NSImage(data: pngData))
        #expect(exportedImage.size == CGSize(width: 600, height: 1_000))
        #expect(exportedImage.nonTransparentPixelBounds() != nil)
    }

    @Test func materializerOnlyShrinksOversizedRootAndKeepsItInsideCanvasInset() throws {
        let result = XomoFigmaNodeMaterializer.materialize(
            plan: try Self.decodedPlan(),
            canvasSize: CGSize(width: 300, height: 400)
        )
        let rootBackground = try #require(
            result.layers.first { $0.name == L10n.format("imageEditor.layer.figmaFrameBackground", "Checkout Frame") }
        )
        let expectedScale = 360.0 / 844.0
        let primary = try #require(result.layers.first { $0.name == "Primary" })

        #expect(abs(rootBackground.frame.height - 360) < 0.001)
        #expect(abs(rootBackground.frame.width - 390 * expectedScale) < 0.001)
        #expect(abs(rootBackground.frame.midX - 150) < 0.001)
        #expect(abs(rootBackground.frame.midY - 200) < 0.001)
        #expect(abs((primary.shapeContent?.cornerRadius ?? 0) - 8 * expectedScale) < 0.001)
    }

    @Test func viewModelInsertsImportedRootAfterExistingTopLevelGroup() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "grouped.png",
            image: NSImage.transparent(size: CGSize(width: 600, height: 1_000))
        ) { _ in }
        let group = ImageEditorLayer.group(name: "Existing Group", size: viewModel.document.canvasSize)
        var child = ImageEditorLayer.blank(name: "Existing Child", size: CGSize(width: 20, height: 20))
        child.groupID = group.id
        viewModel.document.layers = [child, group]
        viewModel.document.selectedLayerID = child.id
        viewModel.document.selectedLayerIDs = [child.id]

        #expect(viewModel.importFigmaNodePlan(try Self.decodedPlan()))
        #expect(viewModel.document.layers[0].id == child.id)
        #expect(viewModel.document.layers[1].id == group.id)
        #expect(
            viewModel.document.layers[2].name
                == L10n.format("imageEditor.layer.figmaFrameBackground", "Checkout Frame")
        )

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == [child.id, group.id])
    }

    private static func decodedPlan() throws -> XomoFigmaNodeImportPlan {
        let response = try JSONDecoder().decode(XomoFigmaNodeResponse.self, from: validNodeResponse)
        return try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:3")
    }

    @Test func modernFigmaAutoLayoutSizingMapsByPhysicalAxisAndReportsFillFallback() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Modern sizing","nodes":{"1:60":{"document":{"id":"1:60","name":"Root","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":500,"height":300},"children":[{"id":"2:60","name":"Horizontal Hug","type":"FRAME","layoutMode":"HORIZONTAL","layoutSizingHorizontal":"HUG","layoutSizingVertical":"FIXED","absoluteBoundingBox":{"x":0,"y":0,"width":160,"height":60}},{"id":"2:61","name":"Vertical Hug Width","type":"FRAME","layoutMode":"VERTICAL","layoutSizingHorizontal":"HUG","layoutSizingVertical":"FIXED","absoluteBoundingBox":{"x":180,"y":0,"width":160,"height":60}},{"id":"2:62","name":"Nested Fill","type":"FRAME","layoutMode":"HORIZONTAL","layoutSizingHorizontal":"FILL","layoutSizingVertical":"FIXED","absoluteBoundingBox":{"x":0,"y":100,"width":340,"height":60}}]}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:60"
        )
        let horizontal = try #require(plan.items.first { $0.sourceID == "2:60" })
        let vertical = try #require(plan.items.first { $0.sourceID == "2:61" })
        let fill = try #require(plan.items.first { $0.sourceID == "2:62" })

        #expect(horizontal.stackLayout?.primarySizingMode == .hug)
        #expect(horizontal.stackLayout?.crossSizingMode == .fixed)
        #expect(!horizontal.issues.contains(.autoLayoutFlattened))
        #expect(vertical.stackLayout?.primarySizingMode == .fixed)
        #expect(vertical.stackLayout?.crossSizingMode == .hug)
        #expect(!vertical.issues.contains(.autoLayoutFlattened))
        #expect(fill.stackLayout?.primarySizingMode == .fixed)
        #expect(fill.issues.contains(.autoLayoutFlattened))
    }

    @Test func modernFigmaFillChildrenMapToEditableStackChildSizingByParentAxis() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Modern child sizing","nodes":{"1:70":{"document":{"id":"1:70","name":"Root","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":500,"height":300},"children":[{"id":"2:70","name":"Horizontal Parent","type":"FRAME","layoutMode":"HORIZONTAL","layoutSizingHorizontal":"FIXED","layoutSizingVertical":"FIXED","absoluteBoundingBox":{"x":0,"y":0,"width":240,"height":100},"children":[{"id":"3:70","name":"Fill Both","type":"RECTANGLE","layoutSizingHorizontal":"FILL","layoutSizingVertical":"FILL","absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":60}}]},{"id":"2:71","name":"Vertical Parent","type":"FRAME","layoutMode":"VERTICAL","layoutSizingHorizontal":"FIXED","layoutSizingVertical":"FIXED","absoluteBoundingBox":{"x":260,"y":0,"width":200,"height":240},"children":[{"id":"3:71","name":"Fill Main","type":"RECTANGLE","layoutSizingHorizontal":"HUG","layoutSizingVertical":"FILL","absoluteBoundingBox":{"x":260,"y":0,"width":80,"height":100}}]}]}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:70"
        )
        let fillBoth = try #require(plan.items.first { $0.sourceID == "3:70" })
        let fillVerticalMain = try #require(plan.items.first { $0.sourceID == "3:71" })

        #expect(fillBoth.stackChildLayout == ImageEditorStackChildLayout(
            grow: 1,
            stretchesCrossAxis: true
        ))
        #expect(!fillBoth.issues.contains(.autoLayoutFlattened))
        #expect(fillVerticalMain.stackChildLayout == ImageEditorStackChildLayout(
            grow: 1,
            stretchesCrossAxis: false
        ))
        #expect(!fillVerticalMain.issues.contains(.autoLayoutFlattened))
    }

    @Test func figmaAutoLayoutGeometryUsesNativeBoundsAndReportsOnlyLossyClamps() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Layout geometry","nodes":{"1:80":{"document":{"id":"1:80","name":"Root","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":700,"height":300},"children":[{"id":"2:80","name":"Overlap","type":"FRAME","layoutMode":"HORIZONTAL","itemSpacing":-24,"paddingLeft":16,"paddingRight":16,"paddingTop":12,"paddingBottom":12,"absoluteBoundingBox":{"x":0,"y":0,"width":300,"height":120}},{"id":"2:81","name":"Clamped","type":"FRAME","layoutMode":"HORIZONTAL","layoutWrap":"WRAP","itemSpacing":5000,"counterAxisSpacing":-8,"paddingLeft":-20,"paddingRight":5000,"absoluteBoundingBox":{"x":340,"y":0,"width":300,"height":120}}]}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:80"
        )
        let overlap = try #require(plan.items.first { $0.sourceID == "2:80" })
        let clamped = try #require(plan.items.first { $0.sourceID == "2:81" })

        #expect(overlap.stackLayout?.spacing == -24)
        #expect(overlap.stackLayout?.paddingLeft == 16)
        #expect(!overlap.issues.contains(.autoLayoutFlattened))
        #expect(clamped.stackLayout?.spacing == ImageEditorStackLayout.maximumSpacing)
        #expect(clamped.stackLayout?.counterSpacing == 0)
        #expect(clamped.stackLayout?.paddingLeft == 0)
        #expect(clamped.stackLayout?.paddingRight == ImageEditorStackLayout.maximumPadding)
        #expect(clamped.issues.contains(.autoLayoutFlattened))
    }

    @Test func figmaAutoLayoutAlignmentReportsUnknownValuesWithoutMislabelingNativeCases() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Alignment fidelity","nodes":{"1:90":{"document":{"id":"1:90","name":"Root","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":700,"height":300},"children":[{"id":"2:90","name":"Native","type":"FRAME","layoutMode":"HORIZONTAL","primaryAxisAlignItems":"SPACE_BETWEEN","counterAxisAlignItems":"MAX","absoluteBoundingBox":{"x":0,"y":0,"width":300,"height":120}},{"id":"2:91","name":"Unknown","type":"FRAME","layoutMode":"HORIZONTAL","primaryAxisAlignItems":"SPACE_AROUND","counterAxisAlignItems":"STRETCH","absoluteBoundingBox":{"x":340,"y":0,"width":300,"height":120}}]}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:90"
        )
        let native = try #require(plan.items.first { $0.sourceID == "2:90" })
        let unknown = try #require(plan.items.first { $0.sourceID == "2:91" })

        #expect(native.stackLayout?.primaryAlignment == .spaceBetween)
        #expect(native.stackLayout?.crossAlignment == .end)
        #expect(!native.issues.contains(.autoLayoutFlattened))
        #expect(native.fidelity == .exact)
        #expect(unknown.stackLayout?.primaryAlignment == .start)
        #expect(unknown.stackLayout?.crossAlignment == .start)
        #expect(unknown.issues.contains(.autoLayoutFlattened))
        #expect(unknown.fidelity == .partial)
    }

    @Test func modernFigmaSizingOverridesUnknownLegacyValuesWhileBareUnknownLegacyDegrades() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Sizing precedence","nodes":{"1:100":{"document":{"id":"1:100","name":"Root","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":700,"height":300},"children":[{"id":"2:100","name":"Modern Wins","type":"FRAME","layoutMode":"VERTICAL","layoutSizingHorizontal":"FIXED","layoutSizingVertical":"HUG","primaryAxisSizingMode":"UNKNOWN_PRIMARY","counterAxisSizingMode":"UNKNOWN_CROSS","absoluteBoundingBox":{"x":0,"y":0,"width":300,"height":120}},{"id":"2:101","name":"Legacy Unknown","type":"FRAME","layoutMode":"VERTICAL","primaryAxisSizingMode":"UNKNOWN_PRIMARY","counterAxisSizingMode":"FIXED","absoluteBoundingBox":{"x":340,"y":0,"width":300,"height":120}}]}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:100"
        )
        let modern = try #require(plan.items.first { $0.sourceID == "2:100" })
        let legacyUnknown = try #require(plan.items.first { $0.sourceID == "2:101" })

        #expect(modern.stackLayout?.primarySizingMode == .hug)
        #expect(modern.stackLayout?.crossSizingMode == .fixed)
        #expect(!modern.issues.contains(.autoLayoutFlattened))
        #expect(modern.fidelity == .exact)
        #expect(legacyUnknown.stackLayout?.primarySizingMode == .fixed)
        #expect(legacyUnknown.stackLayout?.crossSizingMode == .fixed)
        #expect(legacyUnknown.issues.contains(.autoLayoutFlattened))
        #expect(legacyUnknown.fidelity == .partial)
    }

    @Test func modernChildSizingClearsLegacyFillWhileInvalidBareLegacyChildValuesDegrade() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Child sizing precedence","nodes":{"1:110":{"document":{"id":"1:110","name":"Parent","type":"FRAME","layoutMode":"HORIZONTAL","absoluteBoundingBox":{"x":0,"y":0,"width":700,"height":300},"children":[{"id":"2:110","name":"Modern Fixed","type":"RECTANGLE","layoutSizingHorizontal":"FIXED","layoutSizingVertical":"HUG","layoutGrow":5,"layoutAlign":"STRETCH","absoluteBoundingBox":{"x":0,"y":0,"width":200,"height":100}},{"id":"2:111","name":"Invalid Legacy","type":"RECTANGLE","layoutGrow":5000,"layoutAlign":"UNKNOWN_ALIGN","absoluteBoundingBox":{"x":240,"y":0,"width":200,"height":100}}]}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:110"
        )
        let modern = try #require(plan.items.first { $0.sourceID == "2:110" })
        let invalidLegacy = try #require(plan.items.first { $0.sourceID == "2:111" })

        #expect(modern.stackChildLayout == nil)
        #expect(!modern.issues.contains(.autoLayoutFlattened))
        #expect(modern.fidelity == .exact)
        #expect(invalidLegacy.stackChildLayout == ImageEditorStackChildLayout(
            grow: ImageEditorStackChildLayout.maximumGrow,
            stretchesCrossAxis: false
        ))
        #expect(invalidLegacy.issues.contains(.autoLayoutFlattened))
        #expect(invalidLegacy.fidelity == .partial)
    }

    @Test func figmaAutoLayoutChildPositioningPreservesNativeModesAndReportsUnknownValues() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Child positioning","nodes":{"1:120":{"document":{"id":"1:120","name":"Parent","type":"FRAME","layoutMode":"HORIZONTAL","absoluteBoundingBox":{"x":0,"y":0,"width":700,"height":300},"children":[{"id":"2:120","name":"Flow","type":"RECTANGLE","layoutPositioning":"AUTO","absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":80}},{"id":"2:121","name":"Pinned","type":"RECTANGLE","layoutPositioning":"ABSOLUTE","absoluteBoundingBox":{"x":140,"y":0,"width":120,"height":80}},{"id":"2:122","name":"Unknown","type":"RECTANGLE","layoutPositioning":"FLOATING","absoluteBoundingBox":{"x":280,"y":0,"width":120,"height":80}}]}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:120"
        )
        let flow = try #require(plan.items.first { $0.sourceID == "2:120" })
        let pinned = try #require(plan.items.first { $0.sourceID == "2:121" })
        let unknown = try #require(plan.items.first { $0.sourceID == "2:122" })

        #expect(!flow.isStackLayoutExcluded)
        #expect(flow.fidelity == .exact)
        #expect(pinned.isStackLayoutExcluded)
        #expect(pinned.fidelity == .exact)
        #expect(!unknown.isStackLayoutExcluded)
        #expect(unknown.issues.contains(.autoLayoutFlattened))
        #expect(unknown.fidelity == .partial)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 800, height: 500)
        )
        #expect(materialized.layers.first { $0.name == "Flow" }?.isStackLayoutExcluded == false)
        #expect(materialized.layers.first { $0.name == "Pinned" }?.isStackLayoutExcluded == true)
        #expect(materialized.layers.first { $0.name == "Unknown" }?.isStackLayoutExcluded == false)
    }

    @Test func figmaAutoLayoutWrapPreservesNativeModesAndReportsUnknownValues() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Wrap fidelity","nodes":{"1:130":{"document":{"id":"1:130","name":"Root","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":700,"height":420},"children":[{"id":"2:130","name":"No Wrap","type":"FRAME","layoutMode":"HORIZONTAL","layoutWrap":"NO_WRAP","absoluteBoundingBox":{"x":0,"y":0,"width":300,"height":100}},{"id":"2:131","name":"Wrap","type":"FRAME","layoutMode":"HORIZONTAL","layoutWrap":"WRAP","absoluteBoundingBox":{"x":340,"y":0,"width":300,"height":180}},{"id":"2:132","name":"Unknown","type":"FRAME","layoutMode":"HORIZONTAL","layoutWrap":"BALANCED","absoluteBoundingBox":{"x":0,"y":220,"width":300,"height":100}}]}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:130"
        )
        let noWrap = try #require(plan.items.first { $0.sourceID == "2:130" })
        let wrap = try #require(plan.items.first { $0.sourceID == "2:131" })
        let unknown = try #require(plan.items.first { $0.sourceID == "2:132" })

        #expect(noWrap.stackLayout?.wrapMode == .noWrap)
        #expect(noWrap.fidelity == .exact)
        #expect(wrap.stackLayout?.wrapMode == .wrap)
        #expect(wrap.fidelity == .exact)
        #expect(unknown.stackLayout?.wrapMode == .noWrap)
        #expect(unknown.issues.contains(.autoLayoutFlattened))
        #expect(unknown.fidelity == .partial)
    }

    @Test func figmaAutoLayoutSizeConstraintsAreReportedInsteadOfSilentlyClaimingExactFidelity() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Constraints","nodes":{"1:140":{"document":{"id":"1:140","name":"Constrained Parent","type":"FRAME","layoutMode":"HORIZONTAL","minWidth":240,"maxWidth":640,"absoluteBoundingBox":{"x":0,"y":0,"width":420,"height":180},"children":[{"id":"2:140","name":"Constrained Child","type":"RECTANGLE","minHeight":48,"maxHeight":96,"absoluteBoundingBox":{"x":20,"y":20,"width":160,"height":64}}]}}}}"#.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:140"
        )
        let parent = try #require(plan.items.first { $0.sourceID == "1:140" })
        let child = try #require(plan.items.first { $0.sourceID == "2:140" })

        #expect(parent.stackLayout?.axis == .horizontal)
        #expect(parent.issues.contains(.autoLayoutFlattened))
        #expect(parent.fidelity == .partial)
        #expect(child.issues.contains(.autoLayoutFlattened))
        #expect(child.fidelity == .partial)
        #expect(child.frame?.height == 64)
    }

    private static let validNodeResponse = Data(
        """
        {
          "name": "Checkout",
          "lastModified": "2026-07-15T01:00:00Z",
          "version": "88",
          "nodes": {
            "1:3": {
              "document": {
                "id": "1:3",
                "name": "Checkout Frame",
                "type": "FRAME",
                "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}],
                "absoluteBoundingBox": {"x": 100, "y": 200, "width": 390, "height": 844},
                "children": [
                  {
                    "id": "2:1",
                    "name": "Actions",
                    "type": "GROUP",
                    "layoutMode": "HORIZONTAL",
                    "primaryAxisSizingMode": "FIXED",
                    "counterAxisSizingMode": "FIXED",
                    "itemSpacing": 8,
                    "absoluteBoundingBox": {"x": 120, "y": 240, "width": 200, "height": 80},
                    "children": [
                      {
                        "id": "2:2",
                        "name": "Continue Label",
                        "type": "TEXT",
                        "layoutGrow": 1,
                        "layoutAlign": "STRETCH",
                        "characters": "Continue 继续",
                        "style": {"fontFamily": "Inter", "fontSize": 16, "fontWeight": 600, "textAlignHorizontal": "CENTER", "letterSpacing": -1.5, "lineHeightPercentFontSize": 137.5, "lineHeightUnit": "FONT_SIZE_%", "italic": true, "textDecoration": "UNDERLINE", "paragraphIndent": 12, "textCase": "UPPER"},
                        "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}],
                        "absoluteBoundingBox": {"x": 130, "y": 260, "width": 64, "height": 24}
                      }
                    ]
                  },
                  {
                    "id": "2:3",
                    "name": "Primary",
                    "type": "RECTANGLE",
                    "opacity": 0.8,
                    "locked": true,
                    "fills": [{"type": "SOLID", "color": {"r": 0.1, "g": 0.4, "b": 0.9, "a": 1}}],
                    "cornerRadius": 8,
                    "absoluteBoundingBox": {"x": 120, "y": 340, "width": 200, "height": 44}
                  },
                  {
                    "id": "2:4",
                    "name": "Avatar",
                    "type": "ELLIPSE",
                    "fills": [{"type": "SOLID", "color": {"r": 0.3, "g": 0.3, "b": 0.3, "a": 1}}],
                    "absoluteBoundingBox": {"x": 120, "y": 400, "width": 48, "height": 48}
                  },
                  {
                    "id": "2:5",
                    "name": "Arrow",
                    "type": "VECTOR",
                    "size": {"width": 20, "height": 20},
                    "relativeTransform": [[1, 0, 180], [0, 1, 400]],
                    "strokes": [{"type": "SOLID", "color": {"r": 0, "g": 0, "b": 0, "a": 1}}],
                    "strokeWeight": 2,
                    "fillGeometry": [{"path": "M 0 0 L 20 0 L 10 20 Z", "windingRule": "NONZERO"}],
                    "absoluteBoundingBox": {"x": 180, "y": 400, "width": 20, "height": 20}
                  },
                  {
                    "id": "2:6",
                    "name": "Hero Image",
                    "type": "RECTANGLE",
                    "fills": [{"type": "IMAGE", "imageRef": "img-ref-1"}],
                    "absoluteBoundingBox": {"x": 120, "y": 470, "width": 240, "height": 120}
                  },
                  {
                    "id": "2:7",
                    "name": "Card Component",
                    "type": "COMPONENT",
                    "componentProperties": {
                      "Size": {"type": "VARIANT", "value": "Large", "preferredValues": [{"key": "Small", "name": "Small"}, {"key": "Large", "name": "Large"}]},
                      "Is Enabled": {"type": "BOOLEAN", "value": "true"}
                    },
                    "layoutMode": "VERTICAL",
                    "primaryAxisSizingMode": "AUTO",
                    "counterAxisSizingMode": "AUTO",
                    "itemSpacing": 12,
                    "paddingTop": 8,
                    "paddingRight": 16,
                    "paddingBottom": 8,
                    "paddingLeft": 16,
                    "primaryAxisAlignItems": "CENTER",
                    "counterAxisAlignItems": "MAX",
                    "absoluteBoundingBox": {"x": 120, "y": 610, "width": 240, "height": 120}
                  },
                  {
                    "id": "2:8",
                    "name": "Embedded Video",
                    "type": "EMBED",
                    "absoluteBoundingBox": {"x": 120, "y": 750, "width": 240, "height": 80}
                  }
                ]
              }
            }
          }
        }
        """.utf8
    )

    private static let samplePlan = XomoFigmaNodeImportPlan(
        fileName: "Checkout",
        version: "88",
        rootSourceID: "1:3",
        rootName: "Checkout Frame",
        items: []
    )
}

private final class RecordingFigmaNodeTransport: XomoFigmaHTTPTransport {
    private(set) var lastRequest: URLRequest?
    let statusCode: Int
    let body: Data

    init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = try #require(
            HTTPURLResponse(
                url: request.url ?? URL(string: "https://api.figma.com")!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        )
        return (body, response)
    }
}

@MainActor
private final class InMemoryFigmaNodeCredentialStore: XomoFigmaCredentialStoring {
    var credential: XomoFigmaPersonalAccessToken?

    init(credential: XomoFigmaPersonalAccessToken?) {
        self.credential = credential
    }

    func load() throws -> XomoFigmaPersonalAccessToken? { credential }
    func save(_ credential: XomoFigmaPersonalAccessToken) throws { self.credential = credential }
    func delete() throws { credential = nil }
}

@MainActor
private final class RecordingFigmaNodePlanFetcher: XomoFigmaNodePlanFetching {
    private(set) var calls: [String] = []
    let result: Result<XomoFigmaNodeImportPlan, XomoFigmaNodeImportError>

    init(result: Result<XomoFigmaNodeImportPlan, XomoFigmaNodeImportError>) {
        self.result = result
    }

    func fetchPlan(
        for preview: XomoFigmaLinkPreview,
        credential: XomoFigmaPersonalAccessToken
    ) async throws -> XomoFigmaNodeImportPlan {
        calls.append(preview.nodeID ?? "")
        return try result.get()
    }
}
