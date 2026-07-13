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

    @Test func paragraphContentReportsOverflowAgainstItsFixedHeight() {
        var content = textContent("One two three four five six seven eight nine ten")
        content.boxWidth = 72
        content.boxHeight = 18

        #expect(content.requiredParagraphHeight > content.boxHeight)
        #expect(content.hasOverflow)

        content.boxHeight = content.requiredParagraphHeight
        #expect(!content.hasOverflow)

        content.boxHeight = 0
        #expect(!content.hasOverflow)
    }

    @Test func resizeGeometryKeepsTheOppositeTextBoxEdgesFixed() {
        let original = CGRect(x: 20, y: 30, width: 108, height: 68)

        let right = ImageEditorTextBoxGeometry.normalizedResizeFrame(
            CGRect(x: 20, y: 30, width: 143.2, height: 68),
            originalFrame: original,
            handle: .right
        )
        #expect(right == CGRect(x: 20, y: 30, width: 144, height: 68))

        let bottomLeft = ImageEditorTextBoxGeometry.normalizedResizeFrame(
            CGRect(x: 4.2, y: 12.4, width: 123.8, height: 85.6),
            originalFrame: original,
            handle: .bottomLeft
        )
        #expect(bottomLeft.maxX == original.maxX)
        #expect(bottomLeft.maxY == original.maxY)
        #expect(bottomLeft.width == 124)
        #expect(bottomLeft.height == 86)
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

    @Test func dragResizeChangesParagraphContainerWithoutScalingTypeAndUndoRestores() throws {
        let viewModel = editor()
        viewModel.textValue = "A paragraph that wraps across several lines"
        viewModel.textSize = 22
        viewModel.textBoxWidth = 100
        viewModel.textBoxHeight = 44
        viewModel.addText(at: CGPoint(x: 24, y: 30))
        viewModel.toggleGuideSnapping()

        let originalLayer = try #require(viewModel.document.selectedLayer)
        let originalFrame = originalLayer.frame
        #expect(viewModel.selectedLayerTransformFrame == originalFrame)

        viewModel.beginResizingSelectedLayer(handle: .topRight)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: originalFrame.maxX + 36, y: originalFrame.maxY + 28),
            handle: .topRight,
            preservingAspectRatio: true
        )
        viewModel.finishResizingSelectedLayer()

        let resized = try #require(viewModel.document.selectedLayer)
        let resizedContent = try #require(resized.textContent)
        #expect(resized.frame == CGRect(
            x: originalFrame.minX,
            y: originalFrame.minY,
            width: originalFrame.width + 36,
            height: originalFrame.height + 28
        ))
        #expect(resizedContent.boxWidth == 136)
        #expect(resizedContent.boxHeight == 72)
        #expect(resizedContent.fontSize == 22)
        #expect(resized.image.size == resized.frame.size)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.textBoxResize"))

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.frame == originalFrame)
        #expect(viewModel.document.selectedLayer?.textContent?.boxWidth == 100)
        #expect(viewModel.document.selectedLayer?.textContent?.boxHeight == 44)
        #expect(viewModel.document.selectedLayer?.textContent?.fontSize == 22)
    }

    @Test func selectedParagraphOverflowStateTracksTextBoxResize() {
        let viewModel = editor()
        viewModel.textValue = "One two three four five six seven eight nine ten eleven twelve"
        viewModel.textBoxWidth = 72
        viewModel.textBoxHeight = 16
        viewModel.addText(at: CGPoint(x: 20, y: 24))
        #expect(viewModel.selectedTextBoxHasOverflow)

        let originalFrame = viewModel.document.selectedLayer?.frame ?? .zero
        let requiredHeight = viewModel.document.selectedLayer?.textContent?.requiredParagraphHeight ?? 1
        viewModel.toggleGuideSnapping()
        viewModel.beginResizingSelectedLayer(handle: .top)
        viewModel.resizeSelectedLayer(
            to: CGPoint(
                x: originalFrame.midX,
                y: originalFrame.minY + requiredHeight + ImageEditorTextContent.drawingPadding * 2 + 12
            ),
            handle: .top
        )
        viewModel.finishResizingSelectedLayer()

        #expect(!viewModel.selectedTextBoxHasOverflow)
    }

    @Test func pointTextStillUsesTheExistingLayerScalePath() throws {
        let viewModel = editor()
        viewModel.textValue = "Point text"
        viewModel.textSize = 22
        viewModel.textBoxWidth = 0
        viewModel.textBoxHeight = 0
        viewModel.addText(at: CGPoint(x: 18, y: 22))
        viewModel.toggleGuideSnapping()

        let originalFrame = try #require(viewModel.selectedLayerTransformFrame)
        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: originalFrame.maxX + 30, y: originalFrame.midY),
            handle: .right,
            preservingAspectRatio: true
        )
        viewModel.finishResizingSelectedLayer()

        let resizedFrame = try #require(viewModel.selectedLayerTransformFrame)
        #expect(resizedFrame.width == originalFrame.width + 30)
        #expect(abs(resizedFrame.width / resizedFrame.height - originalFrame.width / originalFrame.height) < 0.001)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerResize"))
        #expect(viewModel.document.selectedLayer?.textContent?.layoutMode == .point)
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
        #expect(source.contains("textBoxOverflowOverlay(in: geometry.size)"))
        #expect(source.contains("image-editor-text-box-overflow"))
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
