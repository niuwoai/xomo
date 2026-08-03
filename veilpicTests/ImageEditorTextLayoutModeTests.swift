//
//  ImageEditorTextLayoutModeTests.swift
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
struct ImageEditorTextLayoutModeTests {
    @Test func layoutModeAndParagraphConversionWidthFollowBoxWidthSemantics() {
        var content = textContent("Classic point text")

        #expect(content.layoutMode == .point)
        let expectedWidth = content.drawingRect(in: content.layerSize()).width
        #expect(content.widthForParagraphConversion() == expectedWidth)

        content.boxWidth = expectedWidth
        #expect(content.layoutMode == .paragraph)
    }

    @Test func pointTextConvertsToParagraphWithoutMovingAndUndoRestoresIt() throws {
        let viewModel = editor()
        viewModel.textValue = "Classic point text"
        viewModel.textBold = true
        viewModel.addText(at: CGPoint(x: 18, y: 22))

        let before = try #require(viewModel.document.selectedLayer)
        let beforeContent = try #require(before.textContent)
        #expect(beforeContent.layoutMode == .point)

        viewModel.convertSelectedTextLayers(to: .paragraph)

        let converted = try #require(viewModel.document.selectedLayer)
        let convertedContent = try #require(converted.textContent)
        #expect(converted.frame.origin == before.frame.origin)
        #expect(converted.frame.width == before.frame.width)
        #expect(convertedContent.layoutMode == .paragraph)
        #expect(convertedContent.text == beforeContent.text)
        #expect(convertedContent.isBold)
        #expect(abs(viewModel.textBoxWidth - Double(convertedContent.boxWidth)) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.textConvertToParagraph"))

        viewModel.undo()

        let restored = try #require(viewModel.document.selectedLayer)
        #expect(restored.frame == before.frame)
        #expect(restored.textContent?.layoutMode == .point)
    }

    @Test func paragraphTextConvertsToPointWithoutMovingAndKeepsExplicitContent() throws {
        let viewModel = editor()
        viewModel.textValue = "Paragraph text wraps automatically across its box."
        viewModel.textBoxWidth = 92
        viewModel.textBoxHeight = 64
        viewModel.selectedTextAlignment = .right
        viewModel.addText(at: CGPoint(x: 26, y: 30))

        let before = try #require(viewModel.document.selectedLayer)
        let beforeContent = try #require(before.textContent)
        #expect(beforeContent.layoutMode == .paragraph)
        #expect(beforeContent.boxHeight == 64)

        viewModel.convertSelectedTextLayers(to: .point)

        let converted = try #require(viewModel.document.selectedLayer)
        let convertedContent = try #require(converted.textContent)
        #expect(converted.frame.origin == before.frame.origin)
        #expect(convertedContent.layoutMode == .point)
        #expect(convertedContent.boxHeight == 0)
        #expect(convertedContent.text == beforeContent.text)
        #expect(convertedContent.alignment == .right)
        #expect(converted.frame.width > before.frame.width)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.textConvertToPoint"))
    }

    @Test func batchConversionChangesOnlyEligiblePointTextAndUsesOneUndoStep() throws {
        let viewModel = editor()
        viewModel.textValue = "Editable"
        viewModel.addText(at: CGPoint(x: 8, y: 8))
        let editableID = try #require(viewModel.document.selectedLayerID)

        viewModel.textValue = "Locked"
        viewModel.addText(at: CGPoint(x: 30, y: 28))
        let lockedID = try #require(viewModel.document.selectedLayerID)
        let lockedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == lockedID })
        viewModel.document.layers[lockedIndex].locksPixels = true

        viewModel.textValue = "Already paragraph"
        viewModel.textBoxWidth = 110
        viewModel.addText(at: CGPoint(x: 54, y: 48))
        let paragraphID = try #require(viewModel.document.selectedLayerID)

        let pixelLayer = try #require(viewModel.document.layers.first { !$0.isText })
        let pixelID = pixelLayer.id
        viewModel.document.selectedLayerID = editableID
        viewModel.document.selectedLayerIDs = [editableID, lockedID, paragraphID, pixelID]
        let historyCount = viewModel.document.history.count

        viewModel.convertSelectedTextLayers(to: .paragraph)

        #expect(try #require(text(editableID, in: viewModel)).layoutMode == .paragraph)
        #expect(try #require(text(lockedID, in: viewModel)).layoutMode == .point)
        #expect(try #require(text(paragraphID, in: viewModel)).boxWidth == 110)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(try #require(text(editableID, in: viewModel)).layoutMode == .point)
        #expect(try #require(text(lockedID, in: viewModel)).layoutMode == .point)
        #expect(try #require(text(paragraphID, in: viewModel)).boxWidth == 110)
    }

    @Test func projectRoundTripRetainsPointAndParagraphModes() throws {
        let point = ImageEditorProjectTextContent(content: textContent("Point"))
        var paragraphContent = textContent("Paragraph")
        paragraphContent.boxWidth = 144
        let paragraph = ImageEditorProjectTextContent(content: paragraphContent)

        let pointData = try JSONEncoder().encode(point)
        let paragraphData = try JSONEncoder().encode(paragraph)
        let restoredPoint = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: pointData).textContent
        let restoredParagraph = try JSONDecoder().decode(ImageEditorProjectTextContent.self, from: paragraphData).textContent

        #expect(restoredPoint.layoutMode == .point)
        #expect(restoredParagraph.layoutMode == .paragraph)
        #expect(restoredParagraph.boxWidth == 144)
    }

    @Test func fittingTextBoxToContentCanShrinkAndUndoWithoutChangingTypography() throws {
        let viewModel = editor()
        viewModel.textValue = "A short paragraph"
        viewModel.textSize = 22
        viewModel.textBoxWidth = 120
        viewModel.textBoxHeight = 220
        viewModel.addText(at: CGPoint(x: 24, y: 28))

        let before = try #require(viewModel.document.selectedLayer)
        let beforeContent = try #require(before.textContent)
        let requiredHeight = beforeContent.requiredParagraphHeight
        #expect(viewModel.canFitSelectedTextBoxesToContent)
        #expect(!viewModel.canExpandSelectedTextBoxes)

        viewModel.fitSelectedTextBoxes(.fitContent)

        let fitted = try #require(viewModel.document.selectedLayer)
        let fittedContent = try #require(fitted.textContent)
        #expect(fitted.frame.origin == before.frame.origin)
        #expect(fitted.frame.width == before.frame.width)
        #expect(fittedContent.boxWidth == beforeContent.boxWidth)
        #expect(fittedContent.boxHeight == requiredHeight)
        #expect(fittedContent.fontSize == beforeContent.fontSize)
        #expect(fitted.frame.height == requiredHeight + ImageEditorTextContent.drawingPadding * 2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.textBoxFitContent"))

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.frame == before.frame)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 220)
    }

    @Test func expandingTextBoxOnlyGrowsOverflowingContent() throws {
        let viewModel = editor()
        viewModel.textValue = "One two three four five six seven eight nine ten eleven twelve"
        viewModel.textBoxWidth = 72
        viewModel.textBoxHeight = 14
        viewModel.addText(at: CGPoint(x: 18, y: 20))

        let requiredHeight = try #require(viewModel.document.selectedLayer?.textContent).requiredParagraphHeight
        #expect(viewModel.selectedTextBoxHasOverflow)
        #expect(viewModel.canExpandSelectedTextBoxes)

        viewModel.fitSelectedTextBoxes(.expandHeight)

        let expanded = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(expanded.boxHeight == requiredHeight)
        #expect(!expanded.hasOverflow)
        #expect(!viewModel.canExpandSelectedTextBoxes)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.textBoxExpandHeight"))
    }

    @Test func batchFitSkipsLockedAndPointTextWithOneHistoryStep() throws {
        let viewModel = editor()
        viewModel.textValue = "Editable paragraph"
        viewModel.textBoxWidth = 90
        viewModel.textBoxHeight = 160
        viewModel.addText(at: CGPoint(x: 8, y: 8))
        let editableID = try #require(viewModel.document.selectedLayerID)

        viewModel.textValue = "Locked paragraph"
        viewModel.textBoxWidth = 90
        viewModel.textBoxHeight = 180
        viewModel.addText(at: CGPoint(x: 30, y: 28))
        let lockedID = try #require(viewModel.document.selectedLayerID)
        let lockedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == lockedID })
        viewModel.document.layers[lockedIndex].locksPixels = true

        viewModel.textValue = "Point text"
        viewModel.textBoxWidth = 0
        viewModel.textBoxHeight = 0
        viewModel.addText(at: CGPoint(x: 54, y: 48))
        let pointID = try #require(viewModel.document.selectedLayerID)

        viewModel.document.selectedLayerID = editableID
        viewModel.document.selectedLayerIDs = [editableID, lockedID, pointID]
        let historyCount = viewModel.document.history.count

        viewModel.fitSelectedTextBoxes(.fitContent)

        #expect(try #require(text(editableID, in: viewModel)).boxHeight < 160)
        #expect(try #require(text(lockedID, in: viewModel)).boxHeight == 180)
        #expect(try #require(text(pointID, in: viewModel)).layoutMode == .point)
        #expect(viewModel.document.history.count == historyCount + 1)
    }

    @Test func autoHeightToggleResizesParagraphAndUndoRestoresFixedHeight() throws {
        let viewModel = editor()
        viewModel.textValue = "One two three four five six seven eight"
        viewModel.textBoxWidth = 80
        viewModel.textBoxHeight = 140
        viewModel.addText(at: CGPoint(x: 16, y: 20))

        let before = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.canSetSelectedTextBoxAutoHeight)
        #expect(!viewModel.selectedTextBoxUsesAutoHeight)

        viewModel.setSelectedTextBoxesAutoHeight(true)

        let automatic = try #require(viewModel.document.selectedLayer)
        let automaticContent = try #require(automatic.textContent)
        #expect(automaticContent.boxHeight == 0)
        #expect(viewModel.selectedTextBoxUsesAutoHeight)
        #expect(automatic.frame.height == automaticContent.requiredParagraphHeight + ImageEditorTextContent.drawingPadding * 2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.textBoxAutoHeightEnable"))

        viewModel.setSelectedTextBoxesAutoHeight(false)

        let fixed = try #require(viewModel.document.selectedLayer?.textContent)
        #expect(fixed.boxHeight == fixed.requiredParagraphHeight)
        #expect(!viewModel.selectedTextBoxUsesAutoHeight)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 0)
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.frame == before.frame)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 140)
    }

    private func editor() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "text-layout-mode.png",
            image: NSImage.transparent(size: NSSize(width: 260, height: 180))
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

    private func text(_ id: UUID, in viewModel: ImageEditorViewModel) -> ImageEditorTextContent? {
        viewModel.document.layers.first { $0.id == id }?.textContent
    }
}
