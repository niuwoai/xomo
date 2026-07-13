//
//  ImageEditorTextBoxCreationTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorTextBoxCreationTests {
    @Test func reverseDragProducesNormalizedParagraphRectAndExactContentSize() throws {
        let rect = try #require(ImageEditorTextBoxGeometry.paragraphRect(
            from: CGPoint(x: 190, y: 150),
            to: CGPoint(x: 30, y: 42),
            viewTranslation: CGSize(width: -120, height: -80)
        ))

        #expect(rect == CGRect(x: 30, y: 42, width: 160, height: 108))
        #expect(ImageEditorTextBoxGeometry.contentSize(for: rect) == CGSize(width: 152, height: 100))
    }

    @Test func clickAndOneAxisMovementRemainPointTextGestures() {
        #expect(ImageEditorTextBoxGeometry.paragraphRect(
            from: CGPoint(x: 20, y: 20),
            to: CGPoint(x: 20, y: 20),
            viewTranslation: .zero
        ) == nil)
        #expect(ImageEditorTextBoxGeometry.paragraphRect(
            from: CGPoint(x: 20, y: 20),
            to: CGPoint(x: 120, y: 22),
            viewTranslation: CGSize(width: 100, height: 2)
        ) == nil)
    }

    @Test func fixedParagraphHeightControlsLayerFrameWhileLegacyHeightStaysAutomatic() {
        var fixed = textContent("One line")
        fixed.boxWidth = 120
        fixed.boxHeight = 76
        let fixedSize = fixed.layerSize()

        var automatic = fixed
        automatic.boxHeight = 0
        let automaticSize = automatic.layerSize()

        #expect(fixedSize == CGSize(width: 128, height: 84))
        #expect(fixed.drawingRect(in: fixedSize).size == CGSize(width: 120, height: 76))
        #expect(automaticSize.height < fixedSize.height)
    }

    @Test func creatingAndUpdatingFixedTextBoxPreservesDimensionsAndUndo() throws {
        let viewModel = editor()
        viewModel.textValue = "Dragged paragraph"
        viewModel.textBoxWidth = 132
        viewModel.textBoxHeight = 68
        viewModel.addText(at: CGPoint(x: 24, y: 30))

        let created = try #require(viewModel.document.selectedLayer)
        #expect(created.frame == CGRect(x: 24, y: 30, width: 140, height: 76))
        #expect(created.textContent?.boxHeight == 68)

        viewModel.textBoxHeight = 96
        viewModel.updateSelectedTextLayer()
        #expect(viewModel.document.selectedLayer?.frame.height == 104)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 96)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.frame == created.frame)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 68)
    }

    @Test func projectRoundTripKeepsFixedHeightAndLegacyPayloadDefaultsToAutoHeight() throws {
        var content = textContent("Project text box")
        content.boxWidth = 144
        content.boxHeight = 88
        let encoded = try JSONEncoder().encode(ImageEditorProjectTextContent(content: content))
        let restored = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: encoded).textContent

        #expect(restored.boxHeight == 88)

        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "boxHeight")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacy = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: legacyData).textContent

        #expect(legacy.boxWidth == 144)
        #expect(legacy.boxHeight == 0)
    }

    @Test func imageResizeScalesFixedTextBoxWidthAndHeightOnIndependentAxes() throws {
        let viewModel = editor()
        viewModel.textValue = "Scaled paragraph"
        viewModel.textBoxWidth = 100
        viewModel.textBoxHeight = 60
        viewModel.addText(at: CGPoint(x: 12, y: 18))

        viewModel.resizeImage(to: CGSize(width: 640, height: 330))

        let content = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(content.boxWidth == 200)
        #expect(content.boxHeight == 90)
    }

    @Test func canvasGestureWiresLiveTextRectAndParagraphEditor() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("case .crop, .marquee, .rectangle, .ellipse, .text:"))
        #expect(source.contains("ImageEditorTextBoxGeometry.paragraphRect("))
        #expect(source.contains("beginCanvasParagraphTextEditing(in: paragraphRect)"))
        #expect(source.contains("canvasTextEditingFrame = frame"))
    }

    private func editor() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "text-box-creation.png",
            image: NSImage.transparent(size: NSSize(width: 320, height: 220))
        ) { _ in }
    }

    private func textContent(_ text: String) -> ImageEditorTextContent {
        ImageEditorTextContent(
            text: text,
            color: NSColor(deviceWhite: 1, alpha: 1),
            fontSize: 22,
            point: CGPoint(
                x: ImageEditorTextContent.drawingPadding,
                y: ImageEditorTextContent.drawingPadding
            )
        )
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
