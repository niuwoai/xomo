//
//  ImageEditorSelectionOperationTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionOperationTests {
    @Test func informationPanelReportsSelectionGeometryAndInvertedCanvasBounds() {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(size: canvasSize)
        ) { _ in }

        #expect(viewModel.selectionBoundsInfoText.contains("—"))

        viewModel.createRectSelection(
            from: CGPoint(x: 10.2, y: 8.4),
            to: CGPoint(x: 31.7, y: 29.1)
        )

        #expect(viewModel.selectionBoundsInfoText.contains("X 10"))
        #expect(viewModel.selectionBoundsInfoText.contains("Y 8"))
        #expect(viewModel.selectionBoundsInfoText.contains("W 22"))
        #expect(viewModel.selectionBoundsInfoText.contains("H 22"))

        viewModel.invertSelection()

        #expect(viewModel.selectionBoundsInfoText.contains("X 0"))
        #expect(viewModel.selectionBoundsInfoText.contains("Y 0"))
        #expect(viewModel.selectionBoundsInfoText.contains("W 80"))
        #expect(viewModel.selectionBoundsInfoText.contains("H 60"))

        viewModel.clearSelection()

        #expect(viewModel.selectionBoundsInfoText.contains("—"))
    }

    @Test func imageEditorCreatesFixedAspectMarqueeShapes() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.selectMarqueeShape(.square)
        viewModel.createMarqueeSelection(from: CGPoint(x: 10, y: 8), to: CGPoint(x: 42, y: 28))

        var selection = try #require(viewModel.document.selection)
        #expect(selection.bounds == CGRect(x: 10, y: 8, width: 20, height: 20))
        #expect(!selection.isPolygon)

        viewModel.selectMarqueeShape(.circle)
        viewModel.createMarqueeSelection(from: CGPoint(x: 50, y: 40), to: CGPoint(x: 24, y: 12))

        selection = try #require(viewModel.document.selection)
        #expect(abs(selection.bounds.width - selection.bounds.height) < 0.001)
        #expect(selection.bounds == CGRect(x: 24, y: 14, width: 26, height: 26))
        #expect(selection.isPolygon)
        #expect(selection.points.count == 64)
    }

    @Test func imageEditorCreatesEllipseMarqueeWithExpectedBounds() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.selectMarqueeShape(.ellipse)
        viewModel.createMarqueeSelection(from: CGPoint(x: 8, y: 6), to: CGPoint(x: 56, y: 30))

        let selection = try #require(viewModel.document.selection)
        #expect(abs(selection.bounds.minX - 8) < 0.001)
        #expect(abs(selection.bounds.minY - 6) < 0.001)
        #expect(abs(selection.bounds.width - 48) < 0.001)
        #expect(abs(selection.bounds.height - 24) < 0.001)
        #expect(selection.contains(CGPoint(x: 32, y: 18)))
        #expect(!selection.contains(CGPoint(x: 8, y: 6)))
    }

    @Test func imageEditorSelectionAddKeepsAsymmetricMarqueeYCoordinate() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.selectMarqueeShape(.rectangle)
        viewModel.createMarqueeSelection(from: CGPoint(x: 5, y: 8), to: CGPoint(x: 22, y: 18))

        viewModel.selectionMode = .add
        viewModel.selectMarqueeShape(.circle)
        viewModel.createMarqueeSelection(from: CGPoint(x: 40, y: 36), to: CGPoint(x: 58, y: 54))

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 10, y: 12) == 255)
        #expect(maskAlpha(mask, x: 49, y: 45) == 255)
        #expect(maskAlpha(mask, x: 49, y: 15) == 0)
        #expect(selection.bounds.minY < 9)
        #expect(selection.bounds.maxY > 53)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionAdd"))
    }

    @Test func imageEditorSelectionSubtractKeepsRasterAndVectorMasksInTheSameRowOrder() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 5, y: 6), to: CGPoint(x: 30, y: 24))
        viewModel.selectionMode = .add
        viewModel.createRectSelection(from: CGPoint(x: 40, y: 36), to: CGPoint(x: 65, y: 55))
        #expect(viewModel.document.selection?.rasterMask != nil)

        viewModel.selectionMode = .subtract
        viewModel.createRectSelection(from: CGPoint(x: 42, y: 44), to: CGPoint(x: 64, y: 55))

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 10, y: 12) == 255)
        #expect(maskAlpha(mask, x: 50, y: 40) == 255)
        #expect(maskAlpha(mask, x: 50, y: 50) == 0)
        #expect(maskAlpha(mask, x: 50, y: 10) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionSubtract"))
    }

    @Test func imageEditorSelectionIntersectKeepsAnAsymmetricRasterRegionAtItsCanvasPosition() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 10, y: 6), to: CGPoint(x: 70, y: 20))
        viewModel.selectionMode = .add
        viewModel.createRectSelection(from: CGPoint(x: 10, y: 40), to: CGPoint(x: 70, y: 54))

        viewModel.selectionMode = .intersect
        viewModel.selectMarqueeShape(.ellipse)
        viewModel.createMarqueeSelection(from: CGPoint(x: 30, y: 42), to: CGPoint(x: 50, y: 52))

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 40, y: 47) == 255)
        #expect(maskAlpha(mask, x: 40, y: 13) == 0)
        #expect(selection.bounds.minY >= 42)
        #expect(selection.bounds.maxY <= 52)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionIntersect"))
    }

    @Test func imageEditorSelectAllCoversCanvas() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.selectAll()

        let selection = try #require(viewModel.document.selection)
        #expect(selection.bounds == CGRect(origin: .zero, size: canvasSize))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionAll"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionAll"))
    }

    @Test func quickMaskShowsUnselectedAreaAndUsesQShortcut() throws {
        let canvasSize = NSSize(width: 8, height: 6)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        viewModel.setQuickMaskOverlayTarget(.maskedAreas)
        viewModel.setQuickMaskOverlayColor(.systemRed)
        viewModel.setQuickMaskOverlayOpacity(0.5)

        viewModel.toggleQuickMaskMode()
        #expect(!viewModel.isQuickMaskMode)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.quickMaskNeedsSelection"))

        viewModel.createRectSelection(from: CGPoint(x: 2, y: 1), to: CGPoint(x: 6, y: 4))
        viewModel.toggleQuickMaskMode()

        #expect(viewModel.isQuickMaskMode)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.quickMaskEnabled"))
        let overlay = try #require(viewModel.quickMaskOverlayImage)
        let unselectedColor = try #require(quickMaskColor(overlay, x: 0, y: 0)?.usingColorSpace(.deviceRGB))
        let selectedAlpha = quickMaskColor(overlay, x: 3, y: 2)?.alphaComponent ?? 0
        let lowerUnselectedAlpha = quickMaskColor(overlay, x: 3, y: 5)?.alphaComponent ?? 0
        #expect(unselectedColor.redComponent > 0.9)
        #expect(unselectedColor.alphaComponent > 0.4)
        #expect(selectedAlpha < 0.05)
        #expect(lowerUnselectedAlpha > 0.4)
        #expect(
            ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: "q",
                modifierFlags: []
            ) == .toggleQuickMask
        )

        viewModel.clearSelection()
        #expect(!viewModel.isQuickMaskMode)
        #expect(viewModel.quickMaskOverlayImage == nil)
    }

    @Test func quickMaskBrushAndEraserEditSelectionWithUndoAndRedo() throws {
        let canvasSize = NSSize(width: 32, height: 24)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        viewModel.setQuickMaskOverlayTarget(.maskedAreas)
        viewModel.setQuickMaskOverlayColor(.systemRed)
        viewModel.setQuickMaskOverlayOpacity(0.5)
        let originalLayerData = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.createRectSelection(from: CGPoint(x: 4, y: 4), to: CGPoint(x: 28, y: 20))
        viewModel.brushSize = 6
        viewModel.opacity = 1
        viewModel.toggleQuickMaskMode()
        viewModel.drawBrush(points: [CGPoint(x: 10, y: 12), CGPoint(x: 22, y: 12)])

        var selection = try #require(viewModel.document.selection)
        var mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 16, y: 12) == 0)
        #expect(maskAlpha(mask, x: 16, y: 6) == 255)
        #expect(maskAlpha(mask, x: 1, y: 1) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.quickMaskHide"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.quickMaskHidden"))
        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == originalLayerData)

        viewModel.undo()
        selection = try #require(viewModel.document.selection)
        mask = try #require(selection.rasterizedMask(canvasSize: canvasSize))
        #expect(maskAlpha(mask, x: 16, y: 12) == 255)
        #expect(viewModel.isQuickMaskMode)
        #expect((quickMaskColor(viewModel.quickMaskOverlayImage, x: 16, y: 12)?.alphaComponent ?? 0) < 0.05)

        viewModel.redo()
        selection = try #require(viewModel.document.selection)
        mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 16, y: 12) == 0)
        #expect((quickMaskColor(viewModel.quickMaskOverlayImage, x: 16, y: 12)?.alphaComponent ?? 0) > 0.4)

        viewModel.drawBrush(
            points: [CGPoint(x: 10, y: 12), CGPoint(x: 22, y: 12)],
            erase: true
        )
        selection = try #require(viewModel.document.selection)
        mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 16, y: 12) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.quickMaskReveal"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.quickMaskRevealed"))

        viewModel.toggleQuickMaskMode()
        #expect(!viewModel.isQuickMaskMode)
        #expect(viewModel.document.selection?.rasterMask != nil)
    }

    @Test func quickMaskStrokeHonorsOpacityAndBrushDiameter() throws {
        let width = 16
        let height = 16
        let fullMask = ImageEditorSelectionMask(
            width: width,
            height: height,
            alpha: [UInt8](repeating: .max, count: width * height)
        )

        let hidden = try #require(
            fullMask.paintedByQuickMaskStroke(
                points: [CGPoint(x: 5, y: 8), CGPoint(x: 11, y: 8)],
                canvasSize: CGSize(width: width, height: height),
                diameter: 4,
                opacity: 0.5,
                reveal: false
            )
        )
        #expect(maskAlpha(hidden, x: 8, y: 8) >= 126)
        #expect(maskAlpha(hidden, x: 8, y: 8) <= 129)
        #expect(maskAlpha(hidden, x: 8, y: 12) == 255)

        let revealed = try #require(
            hidden.paintedByQuickMaskStroke(
                points: [CGPoint(x: 5, y: 8), CGPoint(x: 11, y: 8)],
                canvasSize: CGSize(width: width, height: height),
                diameter: 4,
                opacity: 0.5,
                reveal: true
            )
        )
        #expect(maskAlpha(revealed, x: 8, y: 8) >= 190)
        #expect(maskAlpha(revealed, x: 8, y: 8) <= 193)
    }

    @Test func imageEditorCanReselectLastClearedSelection() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 6, y: 4), to: CGPoint(x: 24, y: 18))
        let originalSelection = try #require(viewModel.document.selection)

        viewModel.clearSelection()

        #expect(viewModel.document.selection == nil)
        #expect(viewModel.canReselectSelection)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionCleared"))

        viewModel.reselectSelection()

        #expect(viewModel.document.selection == originalSelection)
        #expect(!viewModel.canReselectSelection)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionReselected"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionReselected"))

        viewModel.undo()

        #expect(viewModel.document.selection == nil)
        #expect(viewModel.canReselectSelection)
    }

    @Test func imageEditorCanFillSelectionWithBackgroundColorShortcutCommand() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: solidImage(color: .systemRed, size: canvasSize)) { _ in }

        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].image = solidImage(color: .systemRed, size: canvasSize)
        viewModel.backgroundColor = .systemBlue
        viewModel.document.selection = ImageEditorSelection.rectangle(CGRect(x: 6, y: 4, width: 16, height: 12))

        viewModel.fillSelectionWithBackgroundColor()

        let filledPixel = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 8, y: 6))?.usingColorSpace(.deviceRGB))
        let retainedPixel = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 2, y: 2))?.usingColorSpace(.deviceRGB))
        #expect(filledPixel.blueComponent > 0.75)
        #expect(filledPixel.redComponent < 0.25)
        #expect(retainedPixel.redComponent > 0.75)
        #expect(retainedPixel.blueComponent < 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFill"))
    }

    @Test func imageEditorCommandXCanCutSelectionToClipboard() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: solidImage(color: .systemRed, size: canvasSize)) { _ in }

        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].image = solidImage(color: .systemRed, size: canvasSize)
        viewModel.document.selection = ImageEditorSelection.rectangle(CGRect(x: 6, y: 4, width: 16, height: 12))

        #expect(viewModel.canCutSelectionToClipboard)
        viewModel.cutSelectionToClipboard()

        let cutPixel = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 8, y: 6))?.usingColorSpace(.deviceRGB))
        let retainedPixel = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 2, y: 2))?.usingColorSpace(.deviceRGB))

        #expect(cutPixel.alphaComponent < 0.05)
        #expect(retainedPixel.redComponent > 0.75)
        #expect(retainedPixel.alphaComponent > 0.95)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionCutClipboard"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionCutToClipboard"))
    }

    @Test func imageEditorCommandJUsesLayerViaCopyWhenSelectionExists() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: solidImage(color: .systemRed, size: canvasSize)) { _ in }

        let sourceLayerID = try #require(viewModel.document.selectedLayerID)
        let sourceLayerIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == sourceLayerID }
        )
        viewModel.document.layers[sourceLayerIndex].image = solidImage(
            color: .systemRed,
            size: canvasSize
        )
        let originalLayerCount = viewModel.document.layers.count
        viewModel.document.selection = ImageEditorSelection.rectangle(CGRect(x: 6, y: 4, width: 16, height: 12))

        #expect(viewModel.canDuplicateSelectionOrSelectedLayer)
        viewModel.duplicateSelectionOrSelectedLayer()

        let copiedLayer = try #require(viewModel.document.selectedLayer)
        let copiedComposite = viewModel.document.compositedImage(includingOnly: [copiedLayer.id])
        let copiedInside = try #require(copiedComposite.color(at: CGPoint(x: 8, y: 6))?.usingColorSpace(.deviceRGB))
        let copiedOutside = try #require(copiedComposite.color(at: CGPoint(x: 2, y: 2))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(copiedLayer.id != sourceLayerID)
        #expect(copiedLayer.image.size == NSSize(width: 16, height: 12))
        #expect(copiedLayer.frame == CGRect(x: 6, y: 4, width: 16, height: 12))
        #expect(copiedInside.redComponent > 0.75)
        #expect(copiedInside.alphaComponent > 0.95)
        #expect(copiedOutside.alphaComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionCopyLayer"))
    }

    @Test func imageEditorCommandJDuplicatesSelectedGroupWhenSelectionCannotBeCopied() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: solidImage(color: .systemRed, size: canvasSize)) { _ in }

        viewModel.addLayerGroup()
        let sourceGroupID = try #require(viewModel.document.selectedLayerID)
        let sourceGroupName = try #require(viewModel.document.selectedLayer?.name)
        viewModel.document.selection = ImageEditorSelection.rectangle(CGRect(x: 6, y: 4, width: 16, height: 12))

        #expect(viewModel.canDuplicateSelectionOrSelectedLayer)
        #expect(!viewModel.canCopySelectionToNewLayer)
        viewModel.duplicateSelectionOrSelectedLayer()

        let copiedGroup = try #require(viewModel.document.selectedLayer)
        #expect(copiedGroup.isGroup)
        #expect(copiedGroup.id != sourceGroupID)
        #expect(copiedGroup.name == L10n.format("imageEditor.layer.copyName", sourceGroupName))
        #expect(viewModel.document.selection != nil)
    }

    @Test func imageEditorBatchEditsSelectionPixelsAcrossSelectedPixelLayersAndSkipsLockedOrIneligibleLayers() async throws {
        let canvasSize = NSSize(width: 24, height: 18)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: solidImage(color: .black, size: canvasSize)) { _ in }
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        viewModel.document.layers[firstIndex].image = solidImage(color: .black, size: canvasSize)

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        viewModel.document.layers[secondIndex].image = solidImage(color: .black, size: canvasSize)

        viewModel.addLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        let lockedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == lockedID })
        viewModel.document.layers[lockedIndex].image = solidImage(color: .black, size: canvasSize)
        viewModel.document.layers[lockedIndex].locksPixels = true

        viewModel.textValue = "Label"
        viewModel.foregroundColor = .white
        viewModel.addText(at: CGPoint(x: 2, y: 2))
        let textID = try #require(viewModel.document.selectedLayerID)

        let firstBefore = try #require(viewModel.document.layers.first { $0.id == firstID }?.image.qingtuPNGData())
        let secondBefore = try #require(viewModel.document.layers.first { $0.id == secondID }?.image.qingtuPNGData())
        let lockedBefore = try #require(viewModel.document.layers.first { $0.id == lockedID }?.image.qingtuPNGData())
        let textBefore = try #require(viewModel.document.layers.first { $0.id == textID }?.textContent)

        viewModel.createRectSelection(from: CGPoint(x: 4, y: 4), to: CGPoint(x: 12, y: 12))
        viewModel.document.selectedLayerID = secondID
        viewModel.document.selectedLayerIDs = [firstID, secondID, lockedID, textID]
        viewModel.foregroundColor = .systemRed
        viewModel.opacity = 1

        #expect(viewModel.canEditSelectionPixels)
        viewModel.fillSelection()

        let firstFilled = try #require(viewModel.document.layers.first { $0.id == firstID }?.image.color(at: CGPoint(x: 6, y: 6))?.usingColorSpace(.deviceRGB))
        let secondFilled = try #require(viewModel.document.layers.first { $0.id == secondID }?.image.color(at: CGPoint(x: 6, y: 6))?.usingColorSpace(.deviceRGB))
        let lockedAfterFill = try #require(viewModel.document.layers.first { $0.id == lockedID })
        let textAfterFill = try #require(viewModel.document.layers.first { $0.id == textID })

        #expect(firstFilled.redComponent > 0.75)
        #expect(secondFilled.redComponent > 0.75)
        #expect(lockedAfterFill.image.qingtuPNGData() == lockedBefore)
        #expect(textAfterFill.textContent?.text == textBefore.text)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFillSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionFilledSelected", 2))

        viewModel.undo()
        #expect(try #require(viewModel.document.layers.first { $0.id == firstID }?.image.qingtuPNGData()) == firstBefore)
        #expect(try #require(viewModel.document.layers.first { $0.id == secondID }?.image.qingtuPNGData()) == secondBefore)

        viewModel.foregroundColor = .white
        viewModel.brushSize = 2
        viewModel.strokeSelection()

        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionStrokeSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionStrokedSelected", 2))

        viewModel.undo()
        viewModel.clearSelectionPixels()

        let firstCleared = viewModel.document.layers.first { $0.id == firstID }?.image.color(at: CGPoint(x: 6, y: 6))
        let secondCleared = viewModel.document.layers.first { $0.id == secondID }?.image.color(at: CGPoint(x: 6, y: 6))
        #expect((firstCleared?.alphaComponent ?? 1) < 0.05)
        #expect((secondCleared?.alphaComponent ?? 1) < 0.05)
        #expect(try #require(viewModel.document.layers.first { $0.id == lockedID }?.image.qingtuPNGData()) == lockedBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionClearPixelsSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionPixelsClearedSelected", 2))

        viewModel.undo()
        viewModel.document.selectedLayerID = textID
        viewModel.document.selectedLayerIDs = [textID, lockedID]
        #expect(!viewModel.canEditSelectionPixels)
    }

    @Test func imageEditorExpandsAndContractsSelectionMask() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 10, y: 8), to: CGPoint(x: 20, y: 18))
        viewModel.selectionModifyAmount = 3
        viewModel.expandSelection()

        var selection = try #require(viewModel.document.selection)
        var mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 7, y: 13) == 255)
        #expect(maskAlpha(mask, x: 6, y: 13) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionExpand"))

        viewModel.selectionModifyAmount = 2
        viewModel.contractSelection()

        selection = try #require(viewModel.document.selection)
        mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 8, y: 13) == 0)
        #expect(maskAlpha(mask, x: 10, y: 13) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionContract"))
    }

    @Test func imageEditorFeathersSelectionMask() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 10, y: 8), to: CGPoint(x: 20, y: 18))
        viewModel.selectionModifyAmount = 3
        viewModel.featherSelection()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 15, y: 13) == 255)
        #expect(maskAlpha(mask, x: 7, y: 13) > 0)
        #expect(maskAlpha(mask, x: 7, y: 13) < 255)
        #expect(maskAlpha(mask, x: 6, y: 13) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFeather"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionFeathered", 3))
    }

    @Test func imageEditorCreatesSelectionBorderMask() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 10, y: 8), to: CGPoint(x: 20, y: 18))
        viewModel.selectionModifyAmount = 2
        viewModel.borderSelection()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 8, y: 13) == 255)
        #expect(maskAlpha(mask, x: 10, y: 13) == 255)
        #expect(maskAlpha(mask, x: 15, y: 13) == 0)
        #expect(maskAlpha(mask, x: 21, y: 13) == 255)
        #expect(maskAlpha(mask, x: 22, y: 13) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionBorder"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionBordered", 2))
    }

    @Test func imageEditorSmoothsSelectionMask() async throws {
        let canvasSize = NSSize(width: 12, height: 12)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))

        for y in 3...8 {
            for x in 3...8 {
                alpha[y * Int(canvasSize.width) + x] = 255
            }
        }
        alpha[2 * Int(canvasSize.width) + 5] = 255
        alpha[5 * Int(canvasSize.width) + 5] = 0
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 12, height: 12, alpha: alpha),
            bounds: CGRect(x: 3, y: 2, width: 6, height: 7)
        )
        viewModel.selectionModifyAmount = 1

        viewModel.smoothSelection()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 5, y: 2) == 0)
        #expect(maskAlpha(mask, x: 5, y: 5) == 255)
        #expect(maskAlpha(mask, x: 4, y: 4) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionSmooth"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionSmoothed", 1))
    }

    @Test func imageEditorFillsSelectionHolesWithoutSelectingOutsideBackground() async throws {
        let canvasSize = NSSize(width: 8, height: 8)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))

        for y in 2...5 {
            for x in 2...5 {
                alpha[y * Int(canvasSize.width) + x] = 255
            }
        }
        alpha[3 * Int(canvasSize.width) + 3] = 0
        alpha[4 * Int(canvasSize.width) + 4] = 0
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 8, height: 8, alpha: alpha),
            bounds: CGRect(x: 2, y: 2, width: 4, height: 4)
        )

        viewModel.fillSelectionHoles()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 4, y: 4) == 255)
        #expect(maskAlpha(mask, x: 1, y: 1) == 0)
        #expect(maskAlpha(mask, x: 6, y: 6) == 0)
        #expect(selection.bounds == CGRect(x: 2, y: 2, width: 4, height: 4))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFillHoles"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionFillHoles"))
    }

    @Test func imageEditorRemovesSmallSelectionSpecklesWithoutShrinkingMainIsland() async throws {
        let canvasSize = NSSize(width: 10, height: 10)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))

        for y in 3...5 {
            for x in 3...5 {
                alpha[y * Int(canvasSize.width) + x] = 255
            }
        }
        alpha[1 * Int(canvasSize.width) + 8] = 255
        alpha[1 * Int(canvasSize.width) + 9] = 255
        alpha[8 * Int(canvasSize.width) + 1] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 10, height: 10, alpha: alpha),
            bounds: CGRect(x: 1, y: 1, width: 9, height: 8)
        )
        viewModel.selectionModifyAmount = 2

        viewModel.removeSelectionSpeckles()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 5, y: 5) == 255)
        #expect(maskAlpha(mask, x: 8, y: 1) == 0)
        #expect(maskAlpha(mask, x: 9, y: 1) == 0)
        #expect(maskAlpha(mask, x: 1, y: 8) == 0)
        #expect(selection.bounds == CGRect(x: 3, y: 3, width: 3, height: 3))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionRemoveSpeckles"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionSpecklesRemoved", 2))
    }

    @Test func imageEditorMovesSelectionMaskWithoutMovingPixels() async throws {
        let canvasSize = NSSize(width: 8, height: 6)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[1 * Int(canvasSize.width) + 1] = 255
        alpha[1 * Int(canvasSize.width) + 2] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 8, height: 6, alpha: alpha),
            bounds: CGRect(x: 1, y: 1, width: 2, height: 1)
        )
        viewModel.selectionModifyAmount = 2

        viewModel.moveSelectionRight()
        viewModel.selectionModifyAmount = 1
        viewModel.moveSelectionUp()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 1, y: 1) == 0)
        #expect(maskAlpha(mask, x: 2, y: 1) == 0)
        #expect(maskAlpha(mask, x: 3, y: 2) == 255)
        #expect(maskAlpha(mask, x: 4, y: 2) == 255)
        #expect(selection.bounds == CGRect(x: 3, y: 2, width: 2, height: 1))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionMove"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionMoved", 0, 1))
    }

    @Test func imageEditorFlipsSelectionMaskAroundItsOwnBounds() async throws {
        let canvasSize = NSSize(width: 6, height: 5)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[1 * Int(canvasSize.width) + 1] = 255
        alpha[2 * Int(canvasSize.width) + 1] = 255
        alpha[2 * Int(canvasSize.width) + 2] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 6, height: 5, alpha: alpha),
            bounds: CGRect(x: 1, y: 1, width: 2, height: 2)
        )

        viewModel.flipSelectionHorizontal()

        var selection = try #require(viewModel.document.selection)
        var mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 1, y: 1) == 0)
        #expect(maskAlpha(mask, x: 2, y: 1) == 255)
        #expect(maskAlpha(mask, x: 1, y: 2) == 255)
        #expect(maskAlpha(mask, x: 2, y: 2) == 255)
        #expect(selection.bounds == CGRect(x: 1, y: 1, width: 2, height: 2))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFlipHorizontal"))

        viewModel.flipSelectionVertical()

        selection = try #require(viewModel.document.selection)
        mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 1, y: 1) == 255)
        #expect(maskAlpha(mask, x: 2, y: 1) == 255)
        #expect(maskAlpha(mask, x: 1, y: 2) == 0)
        #expect(maskAlpha(mask, x: 2, y: 2) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFlipVertical"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionFlippedVertical"))
    }

    @Test func imageEditorRotatesSelectionMaskAroundItsOwnBounds() async throws {
        let canvasSize = NSSize(width: 7, height: 6)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[1 * Int(canvasSize.width) + 2] = 255
        alpha[1 * Int(canvasSize.width) + 3] = 255
        alpha[1 * Int(canvasSize.width) + 4] = 255
        alpha[2 * Int(canvasSize.width) + 2] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 7, height: 6, alpha: alpha),
            bounds: CGRect(x: 2, y: 1, width: 3, height: 2)
        )

        viewModel.rotateSelectionClockwise()

        var selection = try #require(viewModel.document.selection)
        var mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 2, y: 1) == 255)
        #expect(maskAlpha(mask, x: 3, y: 1) == 255)
        #expect(maskAlpha(mask, x: 3, y: 2) == 255)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 4, y: 1) == 0)
        #expect(selection.bounds == CGRect(x: 2, y: 1, width: 2, height: 3))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionRotateClockwise"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionRotatedClockwise"))

        viewModel.rotateSelection180()

        selection = try #require(viewModel.document.selection)
        mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 2, y: 1) == 255)
        #expect(maskAlpha(mask, x: 2, y: 2) == 255)
        #expect(maskAlpha(mask, x: 2, y: 3) == 255)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 3, y: 1) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionRotate180"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionRotated180"))
    }

    @Test func imageEditorRotatesSelectionMaskCounterclockwise() async throws {
        let canvasSize = NSSize(width: 7, height: 6)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[1 * Int(canvasSize.width) + 2] = 255
        alpha[1 * Int(canvasSize.width) + 3] = 255
        alpha[1 * Int(canvasSize.width) + 4] = 255
        alpha[2 * Int(canvasSize.width) + 2] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 7, height: 6, alpha: alpha),
            bounds: CGRect(x: 2, y: 1, width: 3, height: 2)
        )

        viewModel.rotateSelectionCounterclockwise()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 2, y: 1) == 255)
        #expect(maskAlpha(mask, x: 2, y: 2) == 255)
        #expect(maskAlpha(mask, x: 2, y: 3) == 255)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 3, y: 1) == 0)
        #expect(selection.bounds == CGRect(x: 2, y: 1, width: 2, height: 3))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionRotateCounterclockwise"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionRotatedCounterclockwise"))
    }

    @Test func imageEditorScalesSelectionMaskAroundItsOwnCenter() async throws {
        let canvasSize = NSSize(width: 8, height: 8)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[2 * Int(canvasSize.width) + 2] = 255
        alpha[2 * Int(canvasSize.width) + 3] = 255
        alpha[3 * Int(canvasSize.width) + 2] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 8, height: 8, alpha: alpha),
            bounds: CGRect(x: 2, y: 2, width: 2, height: 2)
        )

        viewModel.scaleSelectionUp()

        var selection = try #require(viewModel.document.selection)
        var mask = try #require(selection.rasterMask)
        #expect(selection.bounds == CGRect(x: 1, y: 1, width: 4, height: 4))
        #expect(maskAlpha(mask, x: 1, y: 1) == 255)
        #expect(maskAlpha(mask, x: 4, y: 1) == 255)
        #expect(maskAlpha(mask, x: 1, y: 4) == 255)
        #expect(maskAlpha(mask, x: 4, y: 4) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionScaleUp"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionScaledUp"))

        alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        for y in 2...5 {
            for x in 2...5 {
                alpha[y * Int(canvasSize.width) + x] = 255
            }
        }
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 8, height: 8, alpha: alpha),
            bounds: CGRect(x: 2, y: 2, width: 4, height: 4)
        )

        viewModel.scaleSelectionDown()

        selection = try #require(viewModel.document.selection)
        mask = try #require(selection.rasterMask)
        #expect(selection.bounds == CGRect(x: 3, y: 3, width: 2, height: 2))
        #expect(maskAlpha(mask, x: 2, y: 2) == 0)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 4, y: 4) == 255)
        #expect(maskAlpha(mask, x: 5, y: 5) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionScaleDown"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionScaledDown"))
    }

    @Test func imageEditorFitsSelectionMaskToCanvas() async throws {
        let canvasSize = NSSize(width: 5, height: 4)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[2 * Int(canvasSize.width) + 3] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 5, height: 4, alpha: alpha),
            bounds: CGRect(x: 3, y: 2, width: 1, height: 1)
        )

        viewModel.fitSelectionToCanvas()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(selection.bounds == CGRect(x: 0, y: 0, width: 5, height: 4))
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 4, y: 3) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFitCanvas"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionFitCanvas"))
    }

    private func testImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }

    private func solidImage(color: NSColor, size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }

    private func maskAlpha(_ mask: ImageEditorSelectionMask, x: Int, y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < mask.width, y < mask.height else { return 0 }
        return mask.alpha[y * mask.width + x]
    }

    private func quickMaskColor(_ image: NSImage?, x: Int, y: Int) -> NSColor? {
        guard let bitmap = image?.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
              x >= 0,
              y >= 0,
              x < bitmap.pixelsWide,
              y < bitmap.pixelsHigh
        else { return nil }
        return bitmap.colorAt(x: x, y: bitmap.pixelsHigh - y - 1)
    }
}
