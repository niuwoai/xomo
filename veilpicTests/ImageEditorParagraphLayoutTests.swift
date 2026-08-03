//
//  ImageEditorParagraphLayoutTests.swift
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
struct ImageEditorParagraphLayoutTests {
    @Test func paragraphStyleMapsJustificationAndThreeIndependentIndents() {
        var content = textContent()
        content.alignment = .justified
        content.leftIndent = 18
        content.rightIndent = 14
        content.firstLineIndent = 12

        let style = content.paragraphStyle

        #expect(style.alignment == .justified)
        #expect(style.headIndent == 18)
        #expect(style.tailIndent == -14)
        #expect(style.firstLineHeadIndent == 30)
        #expect(ImageEditorTextAlignment.allCases.count == 4)
    }

    @Test func paragraphSpacingAffectsNativeLayoutWithoutMasqueradingAsLineSpacing() {
        var content = textContent()
        content.text = "First paragraph\nSecond paragraph"
        content.boxWidth = 180
        let baselineHeight = content.requiredParagraphHeight

        content.paragraphSpacing = 14

        #expect(content.paragraphStyle.paragraphSpacing == 14)
        #expect(content.paragraphStyle.lineSpacing == 0)
        #expect(content.requiredParagraphHeight >= baselineHeight + 13)
    }

    @Test func justificationAndIndentsChangeWrappedParagraphRendering() throws {
        var plain = textContent()
        plain.text = "Classic paragraph layout wraps several words across multiple lines."
        plain.boxWidth = 150
        let plainLayer = ImageEditorLayer.text(name: "Plain", origin: .zero, content: plain)

        plain.alignment = .justified
        plain.leftIndent = 16
        plain.rightIndent = 12
        plain.firstLineIndent = 10
        let formattedLayer = ImageEditorLayer.text(name: "Formatted", origin: .zero, content: plain)

        #expect(plainLayer.contentImage.qingtuPNGData() != formattedLayer.contentImage.qingtuPNGData())
    }

    @Test func newAndExistingTextLayersRoundTripParagraphControlsThroughUndo() throws {
        let viewModel = editor()
        viewModel.textValue = "First paragraph wraps into a text box."
        viewModel.textBoxWidth = 140
        viewModel.selectedTextAlignment = .justified
        viewModel.textLeftIndent = 16
        viewModel.textRightIndent = 12
        viewModel.textFirstLineIndent = 8
        viewModel.textParagraphSpacing = 14
        viewModel.addText(at: CGPoint(x: 8, y: 10))

        let created = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(created.alignment == .justified)
        #expect(created.leftIndent == 16)
        #expect(created.rightIndent == 12)
        #expect(created.firstLineIndent == 8)
        #expect(created.paragraphSpacing == 14)

        viewModel.selectedTextAlignment = .right
        viewModel.textLeftIndent = 24
        viewModel.textRightIndent = 20
        viewModel.textFirstLineIndent = -6
        viewModel.textParagraphSpacing = 22
        viewModel.updateSelectedTextLayer()

        let updated = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(updated.alignment == .right)
        #expect(updated.leftIndent == 24)
        #expect(updated.rightIndent == 20)
        #expect(updated.firstLineIndent == -6)
        #expect(updated.paragraphSpacing == 22)

        viewModel.undo()

        let restored = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(restored.alignment == .justified)
        #expect(restored.leftIndent == 16)
        #expect(restored.rightIndent == 12)
        #expect(restored.firstLineIndent == 8)
        #expect(restored.paragraphSpacing == 14)
    }

    @Test func batchParagraphUpdateAppliesToEditableTextAndSkipsLockedLayer() throws {
        let viewModel = editor()
        viewModel.textValue = "First"
        viewModel.addText(at: CGPoint(x: 8, y: 8))
        let firstID = try #require(viewModel.document.selectedLayerID)

        viewModel.textValue = "Second"
        viewModel.addText(at: CGPoint(x: 36, y: 24))
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.textValue = "Locked"
        viewModel.addText(at: CGPoint(x: 64, y: 40))
        let lockedID = try #require(viewModel.document.selectedLayerID)
        let lockedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == lockedID })
        viewModel.document.layers[lockedIndex].locksPixels = true

        viewModel.document.selectedLayerID = firstID
        viewModel.document.selectedLayerIDs = [firstID, secondID, lockedID]
        viewModel.selectedTextAlignment = .justified
        viewModel.textLeftIndent = 28
        viewModel.textRightIndent = 20
        viewModel.textFirstLineIndent = 12
        viewModel.textParagraphSpacing = 24
        viewModel.updateSelectedTextLayer()

        let first = try #require(text(firstID, in: viewModel))
        let second = try #require(text(secondID, in: viewModel))
        let locked = try #require(text(lockedID, in: viewModel))
        #expect(first.alignment == .justified && second.alignment == .justified)
        #expect(first.leftIndent == 28 && second.rightIndent == 20)
        #expect(first.firstLineIndent == 12 && second.firstLineIndent == 12)
        #expect(first.paragraphSpacing == 24 && second.paragraphSpacing == 24)
        #expect(locked.alignment == .left)
        #expect(locked.leftIndent == 0 && locked.rightIndent == 0 && locked.firstLineIndent == 0)
        #expect(locked.paragraphSpacing == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTextUpdateSelected"))
    }

    @Test func projectParagraphLayoutRoundTripsAndLegacyPayloadDefaultsToZeroIndents() throws {
        var content = textContent()
        content.alignment = .justified
        content.leftIndent = 18
        content.rightIndent = 14
        content.firstLineIndent = -4
        content.paragraphSpacing = 18
        let encoded = try JSONEncoder().encode(ImageEditorProjectTextContent(content: content))
        let restored = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: encoded).textContent

        #expect(restored.alignment == .justified)
        #expect(restored.leftIndent == 18)
        #expect(restored.rightIndent == 14)
        #expect(restored.firstLineIndent == -4)
        #expect(restored.paragraphSpacing == 18)

        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "leftIndent")
        legacyObject.removeValue(forKey: "rightIndent")
        legacyObject.removeValue(forKey: "firstLineIndent")
        legacyObject.removeValue(forKey: "paragraphSpacing")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacy = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: legacyData).textContent

        #expect(legacy.leftIndent == 0)
        #expect(legacy.rightIndent == 0)
        #expect(legacy.firstLineIndent == 0)
        #expect(legacy.paragraphSpacing == 0)
    }

    @Test func justifiedParagraphRemainsAvailableToEditableSVGExport() throws {
        let viewModel = editor()
        viewModel.textValue = "Justified SVG paragraph"
        viewModel.textBoxWidth = 140
        viewModel.selectedTextAlignment = .justified
        viewModel.textLeftIndent = 16
        viewModel.addText(at: CGPoint(x: 8, y: 10))

        #expect(viewModel.canExportSVG)
        let data = try #require(
            viewModel.exportData(settings: ImageEditorExportSettings(format: .svg))
        )
        let source = try #require(String(data: data, encoding: .utf8))
        #expect(source.contains("text-anchor=\"start\""))
        #expect(source.contains("<text x=\"32\""))
    }

    private func editor() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "paragraph-layout.png",
            image: NSImage.transparent(size: NSSize(width: 240, height: 160))
        ) { _ in }
    }

    private func textContent() -> ImageEditorTextContent {
        ImageEditorTextContent(
            text: "Paragraph",
            color: NSColor(deviceWhite: 1, alpha: 1),
            fontSize: 22,
            point: CGPoint(
                x: ImageEditorTextContent.drawingPadding,
                y: ImageEditorTextContent.drawingPadding
            )
        )
    }

    private func text(_ id: UUID, in viewModel: ImageEditorViewModel) -> ImageEditorTextContent? {
        viewModel.document.layers.first { $0.id == id }?.textContent
    }
}
