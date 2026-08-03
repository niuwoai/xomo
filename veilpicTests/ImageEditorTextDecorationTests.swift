//
//  ImageEditorTextDecorationTests.swift
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
struct ImageEditorTextDecorationTests {
    @Test func attributedTextUsesIndependentUnderlineAndStrikethroughAttributes() {
        var content = textContent()

        #expect(content.attributes[.underlineStyle] == nil)
        #expect(content.attributes[.strikethroughStyle] == nil)

        content.isUnderlined = true
        #expect(content.attributes[.underlineStyle] as? Int == NSUnderlineStyle.single.rawValue)
        #expect(content.attributes[.strikethroughStyle] == nil)

        content.isStruckThrough = true
        #expect(content.attributes[.underlineStyle] as? Int == NSUnderlineStyle.single.rawValue)
        #expect(content.attributes[.strikethroughStyle] as? Int == NSUnderlineStyle.single.rawValue)
    }

    @Test func decorationsChangeRenderedTextLayerPixels() throws {
        var plain = textContent()
        plain.text = "MMMM"
        plain.color = NSColor(deviceWhite: 1, alpha: 1)
        plain.fontSize = 36
        let plainLayer = ImageEditorLayer.text(name: "Plain", origin: .zero, content: plain)

        plain.isUnderlined = true
        plain.isStruckThrough = true
        let decoratedLayer = ImageEditorLayer.text(name: "Decorated", origin: .zero, content: plain)

        #expect(plainLayer.contentImage.qingtuPNGData() != decoratedLayer.contentImage.qingtuPNGData())
    }

    @Test func newAndExistingTextLayersRoundTripDecorationControlsThroughUndo() throws {
        let viewModel = editor()
        viewModel.textValue = "Classic type"
        viewModel.textUnderlined = true
        viewModel.textStruckThrough = true
        viewModel.addText(at: CGPoint(x: 8, y: 10))

        let created = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(created.isUnderlined)
        #expect(created.isStruckThrough)
        #expect(created.attributes[.underlineStyle] as? Int == NSUnderlineStyle.single.rawValue)
        #expect(created.attributes[.strikethroughStyle] as? Int == NSUnderlineStyle.single.rawValue)

        viewModel.textUnderlined = false
        viewModel.textStruckThrough = false
        viewModel.updateSelectedTextLayer()

        let updated = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(!updated.isUnderlined)
        #expect(!updated.isStruckThrough)

        viewModel.undo()

        let restored = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(restored.isUnderlined)
        #expect(restored.isStruckThrough)
    }

    @Test func batchTextUpdateAppliesDecorationsAndSkipsLockedLayer() throws {
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
        viewModel.textUnderlined = true
        viewModel.textStruckThrough = true
        viewModel.updateSelectedTextLayer()

        #expect(try #require(text(firstID, in: viewModel)).isUnderlined)
        #expect(try #require(text(secondID, in: viewModel)).isStruckThrough)
        #expect(!(try #require(text(lockedID, in: viewModel))).isUnderlined)
        #expect(!(try #require(text(lockedID, in: viewModel))).isStruckThrough)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTextUpdateSelected"))
    }

    @Test func projectTextDecorationsRoundTripAndLegacyPayloadDefaultsOff() throws {
        var content = textContent()
        content.isUnderlined = true
        content.isStruckThrough = true
        let encoded = try JSONEncoder().encode(ImageEditorProjectTextContent(content: content))
        let restored = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: encoded).textContent

        #expect(restored.isUnderlined)
        #expect(restored.isStruckThrough)

        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "isUnderlined")
        legacyObject.removeValue(forKey: "isStruckThrough")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacy = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: legacyData).textContent

        #expect(!legacy.isUnderlined)
        #expect(!legacy.isStruckThrough)
    }

    @Test func textCaseControlsCreateSelectionSyncUpdateAndUndo() throws {
        let viewModel = editor()
        viewModel.textValue = "Continue 继续"
        viewModel.selectedTextCase = .uppercase
        viewModel.addText(at: CGPoint(x: 8, y: 10))
        let uppercaseID = try #require(viewModel.document.selectedLayerID)
        let created = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(created.text == "Continue 继续")
        #expect(created.textCase == .uppercase)
        #expect(created.attributedString.string == "CONTINUE 继续")

        viewModel.textValue = "Second Label"
        viewModel.selectedTextCase = .original
        viewModel.addText(at: CGPoint(x: 40, y: 24))
        viewModel.selectLayer(uppercaseID)
        #expect(viewModel.selectedTextCase == .uppercase)

        viewModel.selectedTextCase = .lowercase
        viewModel.updateSelectedTextLayer()
        #expect(viewModel.document.selectedLayer?.textContent?.textCase == .lowercase)
        #expect(viewModel.document.selectedLayer?.textContent?.attributedString.string == "continue 继续")

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.textContent?.textCase == .uppercase)
        #expect(viewModel.document.selectedLayer?.textContent?.attributedString.string == "CONTINUE 继续")

        viewModel.selectedTextCase = .smallCaps
        viewModel.updateSelectedTextLayer()
        let smallCaps = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(smallCaps.text == "Continue 继续")
        #expect(smallCaps.displayText == "CONTINUE 继续")
        let capitalFont = try #require(smallCaps.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let reducedFont = try #require(smallCaps.attributedString.attribute(.font, at: 1, effectiveRange: nil) as? NSFont)
        #expect(capitalFont.pointSize == smallCaps.font.pointSize)
        #expect(abs(reducedFont.pointSize - smallCaps.font.pointSize * ImageEditorTextContent.smallCapsScale) < 0.001)
    }

    @Test func batchTextCaseUpdateSkipsLockedLayer() throws {
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

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(lockedID, extendingSelection: true)
        viewModel.selectedTextCase = .titleCase
        viewModel.updateSelectedTextLayer()

        #expect(try #require(text(firstID, in: viewModel)).textCase == .titleCase)
        #expect(try #require(text(secondID, in: viewModel)).textCase == .titleCase)
        #expect(try #require(text(lockedID, in: viewModel)).textCase == .original)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTextUpdateSelected"))
    }

    private func editor() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "text-decoration.png",
            image: NSImage.transparent(size: NSSize(width: 160, height: 100))
        ) { _ in }
    }

    private func textContent() -> ImageEditorTextContent {
        ImageEditorTextContent(
            text: "Typography",
            color: .white,
            fontSize: 24,
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
