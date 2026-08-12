//
//  ImageEditorVectorLayerTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorVectorLayerTests {
    @Test func imageEditorTextLayerRendersUprightInAppKitCoordinates() throws {
        let content = ImageEditorTextContent(
            text: "L",
            color: .white,
            fontSize: 48,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            isBold: true
        )
        let layer = ImageEditorLayer.text(name: "Orientation", origin: .zero, content: content)
        let drawingRect = content.drawingRect(in: layer.image.size)
        let appKitDrawingRect = CGRect(
            x: drawingRect.minX,
            y: layer.image.size.height - drawingRect.maxY,
            width: drawingRect.width,
            height: drawingRect.height
        )
        let expectedUpright = try #require(NSImage.rendered(size: layer.image.size) { _ in
            content.attributedString.draw(
                with: appKitDrawingRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
        })
        let verticallyFlipped = try #require(NSImage.rendered(size: layer.image.size) { _ in
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: layer.image.size.height) {
                content.attributedString.draw(
                    with: drawingRect,
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                )
            }
        })

        let renderedData = try #require(layer.contentImage.qingtuPNGData())
        #expect(renderedData == expectedUpright.qingtuPNGData())
        #expect(renderedData != verticallyFlipped.qingtuPNGData())
    }

    @Test func imageEditorTextLayerIsEditableAndCanMergeDown() async throws {
        let canvasSize = NSSize(width: 120, height: 80)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.document.layers[0].isLocked = false
        let editLayerID = try #require(viewModel.document.selectedLayerID)
        let editPixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedBefore = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.textValue = "Hello\nWorld"
        viewModel.textSize = 28
        viewModel.textBold = true
        viewModel.textItalic = true
        viewModel.textCharacterSpacing = 2
        viewModel.textLineSpacing = 6
        viewModel.textBoxWidth = 72
        viewModel.selectedTextAlignment = .center
        viewModel.foregroundColor = .white
        viewModel.addText(at: CGPoint(x: 16, y: 24))

        let textLayer = try #require(viewModel.document.selectedLayer)
        let textContent = try #require(textLayer.textContent)
        let compositedWithText = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.selectedLayerIsText)
        #expect(textContent.text == "Hello\nWorld")
        #expect(textContent.fontSize == 28)
        #expect(textContent.isBold)
        #expect(textContent.isItalic)
        #expect(textContent.characterSpacing == 2)
        #expect(textContent.lineSpacing == 6)
        #expect(textContent.boxWidth == 72)
        #expect(textContent.alignment == .center)
        #expect(viewModel.selectedTextAlignment == .center)
        #expect(textLayer.frame.width < canvasSize.width)
        #expect(textLayer.frame.height > 0)
        #expect(viewModel.document.layers.first { $0.id == editLayerID }?.image.qingtuPNGData() == editPixelsBefore)
        #expect(compositedWithText != compositedBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTextNew"))

        viewModel.textValue = "World"
        viewModel.textSize = 36
        viewModel.textBold = false
        viewModel.textItalic = false
        viewModel.textCharacterSpacing = 4
        viewModel.textLineSpacing = 10
        viewModel.textBoxWidth = 96
        viewModel.selectedTextAlignment = .right
        viewModel.foregroundColor = .systemPink
        viewModel.updateSelectedTextLayer()

        let updatedTextLayer = try #require(viewModel.document.selectedLayer)
        let updatedTextContent = try #require(updatedTextLayer.textContent)
        let compositedWithUpdatedText = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(updatedTextContent.text == "World")
        #expect(updatedTextContent.fontSize == 36)
        #expect(!updatedTextContent.isBold)
        #expect(!updatedTextContent.isItalic)
        #expect(updatedTextContent.characterSpacing == 4)
        #expect(updatedTextContent.lineSpacing == 10)
        #expect(updatedTextContent.boxWidth == 96)
        #expect(updatedTextContent.alignment == .right)
        #expect(compositedWithUpdatedText != compositedWithText)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTextUpdate"))

        let countBeforeMerge = viewModel.document.layers.count
        viewModel.mergeSelectedLayerDown()
        let mergedLayer = try #require(viewModel.document.selectedLayer)

        #expect(viewModel.document.layers.count == countBeforeMerge - 1)
        #expect(!mergedLayer.isText)
        #expect(mergedLayer.image.size == canvasSize)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeDown"))
    }

    @Test func imageEditorShapeLayerIsEditableAndRasterizesWithoutChangingComposite() async throws {
        let canvasSize = NSSize(width: 120, height: 80)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let editLayerID = try #require(viewModel.document.selectedLayerID)
        let editPixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedBefore = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 18
        viewModel.opacity = 0.9
        viewModel.drawShape(from: CGPoint(x: 20, y: 18), to: CGPoint(x: 82, y: 58), ellipse: false)

        let shapeLayer = try #require(viewModel.document.selectedLayer)
        let shapeContent = try #require(shapeLayer.shapeContent)
        let compositedWithShape = try #require(viewModel.currentImage.qingtuPNGData())
        let shapeInside = try #require(viewModel.currentImage.color(at: CGPoint(x: 48, y: 36))?.usingColorSpace(.deviceRGB))
        let shapeOutside = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.selectedLayerIsShape)
        #expect(shapeContent.kind == .rectangle)
        #expect(shapeLayer.frame == CGRect(x: 20, y: 18, width: 62, height: 40))
        #expect(viewModel.document.layers.first { $0.id == editLayerID }?.image.qingtuPNGData() == editPixelsBefore)
        #expect(compositedWithShape != compositedBefore)
        #expect(shapeInside.redComponent > shapeInside.blueComponent + 0.15)
        #expect(shapeOutside.redComponent < 0.05)
        #expect(shapeOutside.greenComponent < 0.05)
        #expect(shapeOutside.blueComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerShapeNew"))

        viewModel.foregroundColor = .systemGreen
        viewModel.brushSize = 30
        viewModel.opacity = 1
        viewModel.updateSelectedShapeLayer()

        let updatedShapeLayer = try #require(viewModel.document.selectedLayer)
        let updatedShapeContent = try #require(updatedShapeLayer.shapeContent)
        let compositedWithUpdatedShape = try #require(viewModel.currentImage.qingtuPNGData())
        let updatedInside = try #require(viewModel.currentImage.color(at: CGPoint(x: 48, y: 36))?.usingColorSpace(.deviceRGB))

        #expect(updatedShapeContent.kind == .rectangle)
        #expect(updatedShapeContent.strokeWidth > shapeContent.strokeWidth)
        #expect(compositedWithUpdatedShape != compositedWithShape)
        #expect(updatedInside.greenComponent > updatedInside.redComponent + 0.15)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerShapeUpdate"))

        #expect(viewModel.canRasterizeSelectedLayer)
        viewModel.rasterizeSelectedLayer()
        let rasterizedLayer = try #require(viewModel.document.selectedLayer)

        #expect(!rasterizedLayer.isShape)
        #expect(!rasterizedLayer.isText)
        #expect(isPixelLayer(rasterizedLayer))
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedWithUpdatedShape)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRasterize"))

        viewModel.undo()
        #expect(try #require(viewModel.document.selectedLayer?.shapeContent).kind == .rectangle)
    }

    @Test func imageEditorBatchUpdatesSelectedTextLayersAndSkipsLockedOrIneligibleLayers() async throws {
        let canvasSize = NSSize(width: 140, height: 90)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let pixelLayerID = try #require(viewModel.document.selectedLayerID)

        viewModel.textValue = "Alpha"
        viewModel.textSize = 18
        viewModel.foregroundColor = .white
        viewModel.addText(at: CGPoint(x: 10, y: 12))
        let firstID = try #require(viewModel.document.selectedLayerID)

        viewModel.textValue = "Beta"
        viewModel.textSize = 20
        viewModel.foregroundColor = .systemYellow
        viewModel.addText(at: CGPoint(x: 42, y: 24))
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.textValue = "Locked"
        viewModel.textSize = 14
        viewModel.addText(at: CGPoint(x: 70, y: 48))
        let lockedID = try #require(viewModel.document.selectedLayerID)
        let lockedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == lockedID })
        viewModel.document.layers[lockedIndex].locksPixels = true

        let firstBefore = try #require(viewModel.document.layers.first { $0.id == firstID }?.textContent)
        let secondBefore = try #require(viewModel.document.layers.first { $0.id == secondID }?.textContent)
        let lockedBefore = try #require(viewModel.document.layers.first { $0.id == lockedID }?.textContent)
        let pixelBefore = try #require(viewModel.document.layers.first { $0.id == pixelLayerID }?.image.qingtuPNGData())

        viewModel.document.selectedLayerID = firstID
        viewModel.document.selectedLayerIDs = [firstID, secondID, lockedID, pixelLayerID]
        viewModel.textValue = "Shared"
        viewModel.textSize = 32
        viewModel.textBold = true
        viewModel.textItalic = true
        viewModel.textCharacterSpacing = 3
        viewModel.textLineSpacing = 7
        viewModel.textBoxWidth = 88
        viewModel.selectedTextAlignment = .center
        viewModel.foregroundColor = .systemPink
        viewModel.updateSelectedTextLayer()

        let firstAfter = try #require(viewModel.document.layers.first { $0.id == firstID }?.textContent)
        let secondAfter = try #require(viewModel.document.layers.first { $0.id == secondID }?.textContent)
        let lockedAfter = try #require(viewModel.document.layers.first { $0.id == lockedID }?.textContent)

        #expect(firstAfter.text == firstBefore.text)
        #expect(secondAfter.text == secondBefore.text)
        #expect(firstAfter.fontSize == 32)
        #expect(secondAfter.fontSize == 32)
        #expect(firstAfter.isBold && secondAfter.isBold)
        #expect(firstAfter.isItalic && secondAfter.isItalic)
        #expect(firstAfter.characterSpacing == 3)
        #expect(secondAfter.lineSpacing == 7)
        #expect(firstAfter.boxWidth == 88)
        #expect(secondAfter.alignment == .center)
        #expect(lockedAfter.text == lockedBefore.text)
        #expect(lockedAfter.fontSize == lockedBefore.fontSize)
        #expect(viewModel.document.layers.first { $0.id == pixelLayerID }?.image.qingtuPNGData() == pixelBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTextUpdateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerTextUpdatedSelected", 2))

        viewModel.undo()
        #expect(try #require(viewModel.document.layers.first { $0.id == firstID }?.textContent).fontSize == firstBefore.fontSize)
        #expect(try #require(viewModel.document.layers.first { $0.id == secondID }?.textContent).fontSize == secondBefore.fontSize)
    }

    @Test func imageEditorBatchUpdatesSelectedShapeLayersAndSkipsLockedOrIneligibleLayers() async throws {
        let canvasSize = NSSize(width: 140, height: 90)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let pixelLayerID = try #require(viewModel.document.selectedLayerID)

        viewModel.foregroundColor = .systemRed
        viewModel.brushSize = 10
        viewModel.opacity = 0.5
        viewModel.drawShape(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 48, y: 40), ellipse: false)
        let rectangleID = try #require(viewModel.document.selectedLayerID)

        viewModel.foregroundColor = .systemBlue
        viewModel.brushSize = 12
        viewModel.opacity = 0.6
        viewModel.drawShape(from: CGPoint(x: 54, y: 12), to: CGPoint(x: 96, y: 50), ellipse: true)
        let ellipseID = try #require(viewModel.document.selectedLayerID)

        viewModel.foregroundColor = .systemOrange
        viewModel.drawShape(from: CGPoint(x: 22, y: 52), to: CGPoint(x: 62, y: 82), ellipse: false)
        let lockedID = try #require(viewModel.document.selectedLayerID)
        let lockedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == lockedID })
        viewModel.document.layers[lockedIndex].locksPixels = true

        let rectangleBefore = try #require(viewModel.document.layers.first { $0.id == rectangleID }?.shapeContent)
        let ellipseBefore = try #require(viewModel.document.layers.first { $0.id == ellipseID }?.shapeContent)
        let lockedBefore = try #require(viewModel.document.layers.first { $0.id == lockedID }?.shapeContent)
        let pixelBefore = try #require(viewModel.document.layers.first { $0.id == pixelLayerID }?.image.qingtuPNGData())

        viewModel.document.selectedLayerID = rectangleID
        viewModel.document.selectedLayerIDs = [rectangleID, ellipseID, lockedID, pixelLayerID]
        viewModel.foregroundColor = .systemGreen
        viewModel.brushSize = 28
        viewModel.opacity = 0.85
        viewModel.updateSelectedShapeLayer()

        let rectangleAfter = try #require(viewModel.document.layers.first { $0.id == rectangleID }?.shapeContent)
        let ellipseAfter = try #require(viewModel.document.layers.first { $0.id == ellipseID }?.shapeContent)
        let lockedAfter = try #require(viewModel.document.layers.first { $0.id == lockedID }?.shapeContent)
        let rectangleColor = rectangleAfter.fillColor.usingColorSpace(.deviceRGB)
        let ellipseColor = ellipseAfter.fillColor.usingColorSpace(.deviceRGB)

        #expect(rectangleAfter.kind == rectangleBefore.kind)
        #expect(ellipseAfter.kind == ellipseBefore.kind)
        #expect(rectangleColor?.greenComponent ?? 0 > 0.45)
        #expect(ellipseColor?.greenComponent ?? 0 > 0.45)
        #expect(rectangleAfter.strokeWidth > rectangleBefore.strokeWidth)
        #expect(ellipseAfter.strokeWidth > ellipseBefore.strokeWidth)
        #expect(abs(rectangleAfter.fillOpacity - 0.85) < 0.001)
        #expect(abs(ellipseAfter.strokeOpacity - 0.85) < 0.001)
        #expect(lockedAfter.strokeWidth == lockedBefore.strokeWidth)
        #expect(viewModel.document.layers.first { $0.id == pixelLayerID }?.image.qingtuPNGData() == pixelBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerShapeUpdateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerShapeUpdatedSelected", 2))

        viewModel.undo()
        #expect(try #require(viewModel.document.layers.first { $0.id == rectangleID }?.shapeContent).strokeWidth == rectangleBefore.strokeWidth)
        #expect(try #require(viewModel.document.layers.first { $0.id == ellipseID }?.shapeContent).strokeWidth == ellipseBefore.strokeWidth)
    }

    @Test func imageEditorPenToolCreatesEditablePathShapeLayer() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let targetLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[targetLayerIndex].image = testBitmapImage(size: canvasSize, background: .systemBlue)
        viewModel.document.layers[targetLayerIndex].frame = CGRect(origin: .zero, size: canvasSize)
        let compositedBefore = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.selectTool(.pen)
        viewModel.foregroundColor = .systemYellow
        viewModel.opacity = 0.85
        viewModel.brushSize = 18
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)

        let pathLayer = try #require(viewModel.document.selectedLayer)
        let pathContent = try #require(pathLayer.shapeContent)
        let compositedWithPath = try #require(viewModel.currentImage.qingtuPNGData())
        let pathInside = try #require(viewModel.currentImage.color(at: CGPoint(x: 68, y: 42))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.pendingPenPathPoints.isEmpty)
        #expect(viewModel.selectedLayerIsShape)
        #expect(pathContent.kind == .path)
        #expect(pathContent.isPathClosed)
        #expect(pathContent.pathPoints.count == 3)
        #expect(pathContent.pathAnchors.count == 3)
        #expect(pathLayer.name == L10n.format("imageEditor.layer.shapeName", ImageEditorShapeKind.path.title))
        #expect(compositedWithPath != compositedBefore)
        #expect(pathInside.redComponent > 0.5)
        #expect(pathInside.greenComponent > 0.4)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerShapeNew"))

        viewModel.foregroundColor = .systemTeal
        viewModel.brushSize = 26
        viewModel.opacity = 1
        viewModel.updateSelectedShapeLayer()

        let updatedLayer = try #require(viewModel.document.selectedLayer)
        let updatedContent = try #require(updatedLayer.shapeContent)

        #expect(updatedContent.kind == .path)
        #expect(updatedContent.pathPoints.count == 3)
        #expect(updatedContent.pathAnchors.count == 3)
        #expect(updatedContent.strokeWidth > pathContent.strokeWidth)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerShapeUpdate"))

        viewModel.selectTool(.pen)
        viewModel.selectNextPathAnchor()
        viewModel.smoothSelectedPathAnchor()

        let smoothLayer = try #require(viewModel.document.selectedLayer)
        let smoothContent = try #require(smoothLayer.shapeContent)
        let smoothedAnchor = try #require(smoothContent.pathAnchors[safe: 1])
        let outHandle = try #require(viewModel.selectedPathOutControlCanvasPoint)

        #expect(smoothedAnchor.inControl != nil)
        #expect(smoothedAnchor.outControl != nil)
        #expect(viewModel.selectedPathControlRole == .outHandle)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathHandlesUpdate"))

        #expect(viewModel.beginMovingPathAnchor(at: outHandle))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: outHandle.x + 12, y: outHandle.y + 9))
        viewModel.finishMovingPathAnchor()

        let handledLayer = try #require(viewModel.document.selectedLayer)
        let handledContent = try #require(handledLayer.shapeContent)
        let movedHandleAnchor = try #require(handledContent.pathAnchors[safe: 1])

        #expect(viewModel.selectedPathControlRole == .outHandle)
        #expect(movedHandleAnchor.outControl != smoothedAnchor.outControl)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathAnchorMove"))

        #expect(viewModel.beginMovingPathAnchor(at: CGPoint(x: 20, y: 20)))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: 32, y: 36))
        viewModel.finishMovingPathAnchor()

        let movedLayer = try #require(viewModel.document.selectedLayer)
        let movedContent = try #require(movedLayer.shapeContent)
        let movedPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)

        #expect(movedContent.kind == .path)
        #expect(movedContent.pathPoints.count == 3)
        #expect(movedContent.pathAnchors.count == 3)
        #expect(Int(movedPoint.x.rounded()) == 32)
        #expect(Int(movedPoint.y.rounded()) == 36)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathAnchorMove"))

        #expect(viewModel.canLoadSelectionFromSelectedPath)
        viewModel.selectionMode = .replace
        viewModel.loadSelectionFromSelectedPath()

        let pathSelection = try #require(viewModel.document.selection)
        let pathSelectionMask = try #require(pathSelection.rasterMask)

        #expect(pathSelection.bounds.width > 20)
        #expect(pathSelection.bounds.height > 20)
        #expect(pathSelectionMask.alpha.contains(UInt8.max))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromPath"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionFromPath"))

        let layerCountBeforeVectorMask = viewModel.document.layers.count
        #expect(viewModel.canApplySelectedPathAsVectorMask)
        viewModel.applySelectedPathAsVectorMask()

        let maskedLayer = try #require(viewModel.document.selectedLayer)
        let vectorMask = try #require(maskedLayer.vectorMask)
        let maskedInside = try #require(viewModel.currentImage.color(at: CGPoint(x: 68, y: 42))?.usingColorSpace(.deviceRGB))
        let maskedOutside = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == layerCountBeforeVectorMask - 1)
        #expect(vectorMask.kind == .path)
        #expect(vectorMask.isPathClosed)
        #expect(!maskedLayer.isShape)
        #expect(maskedInside.blueComponent > 0.4)
        #expect(maskedOutside.redComponent < 0.05)
        #expect(maskedOutside.greenComponent < 0.05)
        #expect(maskedOutside.blueComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathVectorMask"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathVectorMask"))

        #expect(viewModel.canToggleVectorMaskEnabled)
        viewModel.toggleVectorMaskEnabled()

        let disabledOutside = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        #expect(viewModel.document.selectedLayer?.isVectorMaskEnabled == false)
        #expect(disabledOutside.blueComponent > 0.4)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskDisable"))

        viewModel.toggleVectorMaskEnabled()

        let reenabledOutside = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        #expect(viewModel.document.selectedLayer?.isVectorMaskEnabled == true)
        #expect(reenabledOutside.blueComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskEnable"))

        #expect(viewModel.canDeleteVectorMask)
        viewModel.deleteVectorMask()

        let deletedOutside = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        #expect(viewModel.document.selectedLayer?.vectorMask == nil)
        #expect(deletedOutside.blueComponent > 0.4)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskDelete"))
    }

    @Test func pendingPenPathUndoRedoNeverCrossesIntoDocumentHistory() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.addLayer()
        viewModel.undo()
        #expect(viewModel.canRedo)
        let originalImageData = try #require(viewModel.currentImage.qingtuPNGData())
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalSelectedLayerIDs = viewModel.document.selectedLayerIDs
        let originalHistory = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count
        let points = [
            CGPoint(x: 20, y: 20),
            CGPoint(x: 104, y: 28),
            CGPoint(x: 70, y: 78)
        ]

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(points[0])
        #expect(viewModel.hasPendingPenPathTransaction)
        #expect(viewModel.canUndo)
        #expect(!viewModel.canRedo)

        viewModel.undo()
        #expect(viewModel.pendingPenPathPoints.isEmpty)
        #expect(viewModel.undonePendingPenPathPoints == [points[0]])
        #expect(!viewModel.canUndo)
        #expect(viewModel.canRedo)
        viewModel.undo()
        #expect(viewModel.currentImage.qingtuPNGData() == originalImageData)
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.selectedLayerIDs == originalSelectedLayerIDs)
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)

        viewModel.redo()
        #expect(viewModel.pendingPenPathPoints == [points[0]])
        #expect(viewModel.undonePendingPenPathPoints.isEmpty)
        points.dropFirst().forEach(viewModel.addPenPoint)
        viewModel.undo()
        #expect(viewModel.pendingPenPathPoints == Array(points.prefix(2)))
        #expect(viewModel.undonePendingPenPathPoints == [points[2]])

        let replacement = CGPoint(x: 82, y: 64)
        viewModel.addPenPoint(replacement)
        #expect(viewModel.pendingPenPathPoints == [points[0], points[1], replacement])
        #expect(viewModel.undonePendingPenPathPoints.isEmpty)
        #expect(!viewModel.canRedo)
        #expect(viewModel.currentImage.qingtuPNGData() == originalImageData)
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.selectedLayerIDs == originalSelectedLayerIDs)
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)

        #expect(viewModel.cancelPenPath())
        #expect(!viewModel.cancelPenPath())
        #expect(!viewModel.hasPendingPenPathTransaction)
        #expect(viewModel.pendingPenPathPoints.isEmpty)
        #expect(viewModel.undonePendingPenPathPoints.isEmpty)
        #expect(viewModel.canRedo)
        #expect(viewModel.currentImage.qingtuPNGData() == originalImageData)
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.selectedLayerIDs == originalSelectedLayerIDs)
        #expect(viewModel.document.history == originalHistory)
    }

    @Test func finishingPendingPenPathCommitsOnlyTheCurrentTransientBranch() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let points = [
            CGPoint(x: 20, y: 20),
            CGPoint(x: 104, y: 28),
            CGPoint(x: 70, y: 78)
        ]
        viewModel.selectTool(.pen)
        points.forEach(viewModel.addPenPoint)
        viewModel.undo()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.finishPenPath(closed: false)

        let content = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(content.kind == .path)
        #expect(content.editablePathAnchors.map(\.point).count == 2)
        #expect(!content.isPathClosed)
        #expect(!viewModel.hasPendingPenPathTransaction)
        #expect(viewModel.pendingPenPathPoints.isEmpty)
        #expect(viewModel.undonePendingPenPathPoints.isEmpty)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
    }

    @Test func deleteKeyRemovesPendingPenPointsWithoutReachingDocumentObjects() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.addLayer()
        viewModel.undo()
        let originalImageData = try #require(viewModel.currentImage.qingtuPNGData())
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalHistory = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count
        let points = [
            CGPoint(x: 20, y: 20),
            CGPoint(x: 104, y: 28),
            CGPoint(x: 70, y: 78)
        ]
        viewModel.selectTool(.pen)
        points.forEach(viewModel.addPenPoint)

        for expectedCount in stride(from: points.count - 1, through: 0, by: -1) {
            #expect(viewModel.deletePendingPenPointIfNeeded())
            #expect(viewModel.pendingPenPathPoints.count == expectedCount)
        }
        #expect(viewModel.undonePendingPenPathPoints == Array(points.reversed()))

        // The transient branch still owns Delete after its visible points are
        // exhausted, so another key press cannot reach a selected path/layer.
        #expect(viewModel.deletePendingPenPointIfNeeded())
        #expect(viewModel.pendingPenPathPoints.isEmpty)
        #expect(viewModel.undonePendingPenPathPoints == Array(points.reversed()))
        #expect(viewModel.currentImage.qingtuPNGData() == originalImageData)
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)

        #expect(viewModel.cancelPenPath())
        #expect(!viewModel.deletePendingPenPointIfNeeded())
        #expect(!viewModel.hasPendingPenPathTransaction)
        #expect(viewModel.canRedo)
    }

    @Test func returnKeyFinishesOpenPenPathAndConsumesIncompleteTransientBranch() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let originalLayerCount = viewModel.document.layers.count
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        #expect(!viewModel.finishPendingPenPathFromKeyboard())
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        #expect(viewModel.finishPendingPenPathFromKeyboard())
        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.pendingPenPathPoints == [CGPoint(x: 20, y: 20)])
        #expect(viewModel.statusText == L10n.text("imageEditor.status.penNeedsPoints"))

        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        #expect(viewModel.finishPendingPenPathFromKeyboard())
        let content = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(content.kind == .path)
        #expect(!content.isPathClosed)
        #expect(content.editablePathAnchors.map(\.point).count == 2)
        #expect(!viewModel.hasPendingPenPathTransaction)
        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
    }

    @Test func shiftClickConstrainsPendingPenPointWithoutWritingDocumentHistory() throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalHistory = viewModel.document.history
        let originalUndoCount = viewModel.undoStack.count

        let firstPoint = CGPoint(x: 20, y: 20)
        let proposedPoint = CGPoint(x: 80, y: 35)
        viewModel.addPenPoint(firstPoint, constrainedToAngleIncrement: true)
        viewModel.addPenPoint(proposedPoint, constrainedToAngleIncrement: true)

        #expect(viewModel.pendingPenPathPoints.count == 2)
        #expect(viewModel.pendingPenPathPoints[0] == firstPoint)
        let constrainedPoint = viewModel.pendingPenPathPoints[1]
        #expect(abs(constrainedPoint.y - firstPoint.y) < 0.000_001)
        #expect(abs(
            hypot(constrainedPoint.x - firstPoint.x, constrainedPoint.y - firstPoint.y)
                - hypot(proposedPoint.x - firstPoint.x, proposedPoint.y - firstPoint.y)
        ) < 0.000_001)
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.undoStack.count == originalUndoCount)

        viewModel.addPenPoint(
            CGPoint(x: 90, y: 70),
            constrainedToAngleIncrement: true
        )
        viewModel.addPenPoint(
            CGPoint(x: firstPoint.x + 1, y: firstPoint.y + 1),
            constrainedToAngleIncrement: true
        )
        let closedContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(closedContent.isPathClosed)
        #expect(closedContent.editablePathAnchors.count == 3)
    }

    @Test func penPointerGestureDistinguishesCornerClicksFromSmoothDrags() throws {
        let click = try #require(ImageEditorPendingPenGesturePolicy.resolve(
            startImagePoint: CGPoint(x: 20, y: 20),
            endImagePoint: CGPoint(x: 21, y: 21),
            viewTranslation: CGSize(width: 2, height: 1)
        ))
        #expect(click.anchorPoint == CGPoint(x: 21, y: 21))
        #expect(click.symmetricControlDrag == nil)

        let drag = try #require(ImageEditorPendingPenGesturePolicy.resolve(
            startImagePoint: CGPoint(x: 20, y: 20),
            endImagePoint: CGPoint(x: 34, y: 27),
            viewTranslation: CGSize(width: 14, height: 7)
        ))
        #expect(drag.anchorPoint == CGPoint(x: 20, y: 20))
        #expect(drag.symmetricControlDrag == CGSize(width: 14, height: 7))
    }

    @Test func clickDragPenAnchorsCommitSymmetricBezierControls() throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.addPenPoint(CGPoint(x: 20, y: 50))
        viewModel.addPenPoint(
            CGPoint(x: 80, y: 50),
            symmetricControlDrag: CGSize(width: 12, height: 18),
            constrainedToAngleIncrement: false
        )
        let pendingSmoothAnchor = try #require(viewModel.pendingPenPathAnchors.last)
        viewModel.undoPendingPenPoint()
        #expect(viewModel.undonePendingPenPathAnchors == [pendingSmoothAnchor])
        viewModel.redoPendingPenPoint()
        #expect(viewModel.pendingPenPathAnchors.last == pendingSmoothAnchor)

        viewModel.finishPenPath(closed: false)

        let content = try #require(viewModel.document.selectedLayer?.shapeContent)
        let anchor = try #require(content.editablePathAnchors.last)
        let inControl = try #require(anchor.inControl)
        let outControl = try #require(anchor.outControl)
        #expect(abs((inControl.x - anchor.point.x) + (outControl.x - anchor.point.x)) < 0.000_001)
        #expect(abs((inControl.y - anchor.point.y) + (outControl.y - anchor.point.y)) < 0.000_001)
        #expect(hypot(outControl.x - anchor.point.x, outControl.y - anchor.point.y) > 1)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
    }

    @Test func smoothPenControlsUseOneScaleNearCanvasEdges() throws {
        let controls = try #require(ImageEditorPenPointGeometry.symmetricControls(
            anchor: CGPoint(x: 135, y: 12),
            drag: CGSize(width: 30, height: -18),
            canvasSize: CGSize(width: 140, height: 100)
        ))
        let inward = CGSize(
            width: controls.inControl.x - 135,
            height: controls.inControl.y - 12
        )
        let outward = CGSize(
            width: controls.outControl.x - 135,
            height: controls.outControl.y - 12
        )
        #expect(abs(inward.width + outward.width) < 0.000_001)
        #expect(abs(inward.height + outward.height) < 0.000_001)
        for point in [controls.inControl, controls.outControl] {
            #expect(point.x >= 0 && point.x <= 140)
            #expect(point.y >= 0 && point.y <= 100)
        }
    }

    @Test func pendingPenPreviewMatchesConstrainedCommitAndCloseTarget() {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let firstPoint = CGPoint(x: 20, y: 20)
        let proposedPoint = CGPoint(x: 80, y: 35)

        #expect(viewModel.pendingPenPreviewPoint(
            at: proposedPoint,
            constrainedToAngleIncrement: true
        ) == nil)
        viewModel.addPenPoint(firstPoint)
        let constrainedPreview = viewModel.pendingPenPreviewPoint(
            at: proposedPoint,
            constrainedToAngleIncrement: true
        )
        viewModel.addPenPoint(proposedPoint, constrainedToAngleIncrement: true)
        #expect(constrainedPreview == viewModel.pendingPenPathPoints.last)

        viewModel.addPenPoint(CGPoint(x: 88, y: 74))
        let closePreview = viewModel.pendingPenPreviewPoint(
            at: CGPoint(x: firstPoint.x + 1, y: firstPoint.y + 1),
            constrainedToAngleIncrement: true
        )
        #expect(closePreview == firstPoint)

        let freePreview = viewModel.pendingPenPreviewPoint(
            at: CGPoint(x: 56, y: 67),
            constrainedToAngleIncrement: false
        )
        #expect(freePreview == CGPoint(x: 56, y: 67))
    }

    @Test func pathSelectionHitsClosedPathGeometryAndMovesWholeLayer() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let backgroundID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectTool(.pen)
        viewModel.foregroundColor = .systemYellow
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)

        let pathLayer = try #require(viewModel.document.selectedLayer)
        let pathID = pathLayer.id
        let originalFrame = pathLayer.frame
        viewModel.selectLayer(backgroundID)

        #expect(viewModel.selectPathLayer(at: CGPoint(x: 68, y: 42)))
        #expect(viewModel.document.selectedLayerID == pathID)
        #expect(!viewModel.selectPathLayer(at: CGPoint(x: 25, y: 72)))
        #expect(viewModel.document.selectedLayerID == pathID)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 12, height: 9), snapping: false)
        viewModel.finishMovingSelectedLayer()

        let movedLayer = try #require(viewModel.document.layers.first { $0.id == pathID })
        let movedFrame = movedLayer.frame
        #expect(movedFrame.origin == CGPoint(x: originalFrame.minX + 12, y: originalFrame.minY + 9))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))
    }

    @Test func directSelectionSwitchesToPathAnchorAndMovesOneNode() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)
        viewModel.selectTool(.directSelection)
        let pathID = try #require(viewModel.document.selectedLayerID)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.beginDirectPathAnchorMove(at: CGPoint(x: 20, y: 20)))
        viewModel.finishMovingPathAnchor()
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.document.selectedLayerID == pathID)
        #expect(viewModel.selectedPathAnchorIndex == 0)

        #expect(viewModel.beginDirectPathAnchorMove(at: CGPoint(x: 20, y: 20)))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: 32, y: 36))
        viewModel.finishMovingPathAnchor()

        let movedPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)
        #expect(movedPoint == CGPoint(x: 32, y: 36))
        #expect(viewModel.document.selectedLayerID == pathID)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathAnchorMove"))

        viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: 5, height: -2))
        let nudgedPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)
        #expect(nudgedPoint == CGPoint(x: 37, y: 34))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathAnchorMove"))

        viewModel.deleteSelectedPathAnchor()
        let remainingAnchors = try #require(viewModel.document.selectedLayer?.shapeContent?.pathAnchors)
        #expect(remainingAnchors.count == 2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathAnchorDelete"))
    }

    @Test func imageEditorCreatesEditablePathLayerFromCurrentSelection() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let selectedLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.foregroundColor = .systemYellow
        viewModel.opacity = 0.8
        viewModel.brushSize = 12
        viewModel.document.selection = .rectangle(CGRect(x: 24, y: 18, width: 64, height: 42))

        #expect(viewModel.canCreatePathFromSelection)
        viewModel.createPathFromSelection()

        let pathLayer = try #require(viewModel.document.selectedLayer)
        let pathContent = try #require(pathLayer.shapeContent)
        let selectedPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)

        #expect(pathLayer.id != selectedLayerID)
        #expect(pathLayer.name == L10n.text("imageEditor.layer.selectionPathName"))
        #expect(pathContent.kind == .path)
        #expect(pathContent.isPathClosed)
        #expect(pathContent.fillOpacity == 0)
        #expect(pathContent.strokeOpacity > 0)
        #expect(pathContent.editablePathAnchors.count == 4)
        #expect(viewModel.selectedPathAnchorIndex == 0)
        #expect(viewModel.selectedPathControlRole == .anchor)
        #expect(Int(selectedPoint.x.rounded()) == 24)
        #expect(Int(selectedPoint.y.rounded()) == 18)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathFromSelection"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathFromSelection"))

        #expect(viewModel.canLoadSelectionFromSelectedPath)
        viewModel.selectionMode = .replace
        let selectionBeforeReload = try #require(viewModel.document.selection)
        let historyCountBeforeReload = viewModel.document.history.count
        let undoCountBeforeReload = viewModel.undoStack.count
        viewModel.loadSelectionFromSelectedPath()

        let loadedSelection = try #require(viewModel.document.selection)

        #expect(loadedSelection == selectionBeforeReload)
        #expect(Int(loadedSelection.bounds.minX.rounded()) == 24)
        #expect(Int(loadedSelection.bounds.minY.rounded()) == 18)
        #expect(Int(loadedSelection.bounds.width.rounded()) == 64)
        #expect(Int(loadedSelection.bounds.height.rounded()) == 42)
        #expect(viewModel.document.history.count == historyCountBeforeReload)
        #expect(viewModel.undoStack.count == undoCountBeforeReload)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionUnchanged"))
    }

    @Test func equivalentSelectedPathSelectionDoesNotCreateAnEmptyTransaction() async throws {
        let canvasSize = NSSize(width: 120, height: 90)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 18))
        viewModel.addPenPoint(CGPoint(x: 96, y: 24))
        viewModel.addPenPoint(CGPoint(x: 58, y: 72))
        viewModel.finishPenPath(closed: true)
        viewModel.selectionMode = .replace
        viewModel.loadSelectionFromSelectedPath()
        let selectionMask = try #require(viewModel.document.selection?.rasterizedMask(canvasSize: canvasSize))
        let historyIDs = viewModel.document.history.map(\.id)
        let undoCount = viewModel.undoStack.count

        viewModel.loadSelectionFromSelectedPath()

        #expect(viewModel.document.selection?.rasterizedMask(canvasSize: canvasSize) == selectionMask)
        #expect(viewModel.document.history.map(\.id) == historyIDs)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionUnchanged"))
    }

    @Test func imageEditorCreatesEditablePathLayerFromRasterSelectionOutline() async throws {
        let canvasSize = NSSize(width: 20, height: 16)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        var alpha = [UInt8](repeating: 0, count: 20 * 16)
        for y in 3..<12 {
            for x in 2..<6 {
                alpha[y * 20 + x] = UInt8.max
            }
        }
        for y in 8..<12 {
            for x in 6..<14 {
                alpha[y * 20 + x] = UInt8.max
            }
        }
        let mask = ImageEditorSelectionMask(width: 20, height: 16, alpha: alpha)
        let bounds = try #require(mask.selectedBounds(in: canvasSize))
        viewModel.foregroundColor = .systemYellow
        viewModel.brushSize = 8
        viewModel.document.selection = .raster(mask: mask, bounds: bounds)

        #expect(viewModel.canCreatePathFromSelection)
        viewModel.createPathFromSelection()

        let pathLayer = try #require(viewModel.document.selectedLayer)
        let pathContent = try #require(pathLayer.shapeContent)
        let canvasAnchors = pathContent.editablePathAnchors.map { anchor in
            CGPoint(x: pathLayer.frame.minX + anchor.point.x, y: pathLayer.frame.minY + anchor.point.y)
        }

        #expect(pathContent.kind == .path)
        #expect(pathContent.isPathClosed)
        #expect(pathContent.editablePathAnchors.count > 4)
        #expect(canvasAnchors.contains { Int($0.x.rounded()) == 6 && Int($0.y.rounded()) == 8 })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathFromSelection"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathFromSelection"))

        #expect(viewModel.canLoadSelectionFromSelectedPath)
        viewModel.selectionMode = .replace
        let historyCountBeforeReload = viewModel.document.history.count
        let undoCountBeforeReload = viewModel.undoStack.count
        viewModel.loadSelectionFromSelectedPath()

        let loadedSelection = try #require(viewModel.document.selection)
        let loadedMask = try #require(loadedSelection.rasterMask)

        #expect(maskAlpha(loadedMask, x: 3, y: 4) == UInt8.max)
        #expect(maskAlpha(loadedMask, x: 10, y: 10) == UInt8.max)
        #expect(maskAlpha(loadedMask, x: 10, y: 4) == 0)
        #expect(viewModel.document.history.count == historyCountBeforeReload)
        #expect(viewModel.undoStack.count == undoCountBeforeReload)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionUnchanged"))
    }

    @Test func imageEditorCreatesCompoundPathLayerFromRasterSelectionIslands() async throws {
        let canvasSize = NSSize(width: 24, height: 16)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let layerCountBefore = viewModel.document.layers.count
        var alpha = [UInt8](repeating: 0, count: 24 * 16)
        for y in 2..<8 {
            for x in 2..<7 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        for y in 9..<14 {
            for x in 14..<22 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        let mask = ImageEditorSelectionMask(width: 24, height: 16, alpha: alpha)
        let bounds = try #require(mask.selectedBounds(in: canvasSize))
        viewModel.document.selection = .raster(mask: mask, bounds: bounds)

        #expect(viewModel.canCreatePathFromSelection)
        viewModel.createPathFromSelection()

        let pathLayer = try #require(viewModel.document.selectedLayer)
        let pathContent = try #require(pathLayer.shapeContent)

        #expect(viewModel.document.layers.count == layerCountBefore + 1)
        #expect(pathLayer.name == L10n.text("imageEditor.layer.selectionPathName"))
        #expect(pathContent.kind == .path)
        #expect(pathContent.editablePathAnchors.count == 4)
        #expect(pathContent.editablePathSubpaths.count == 1)
        #expect(pathContent.editablePathSubpaths.first?.count == 4)
        #expect(viewModel.selectedPathAnchorIndex == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathFromSelection"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.pathContoursFromSelection", 2))

        #expect(viewModel.canLoadSelectionFromSelectedPath)
        viewModel.selectionMode = .replace
        let historyCountBeforeReload = viewModel.document.history.count
        let undoCountBeforeReload = viewModel.undoStack.count
        viewModel.loadSelectionFromSelectedPath()

        let loadedSelection = try #require(viewModel.document.selection)
        let loadedMask = try #require(loadedSelection.rasterMask)

        #expect(maskAlpha(loadedMask, x: 4, y: 4) == UInt8.max)
        #expect(maskAlpha(loadedMask, x: 18, y: 11) == UInt8.max)
        #expect(maskAlpha(loadedMask, x: 10, y: 8) == 0)
        #expect(viewModel.document.history.count == historyCountBeforeReload)
        #expect(viewModel.undoStack.count == undoCountBeforeReload)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionUnchanged"))
    }

    @Test func imageEditorMovesCompoundPathSubpathAnchorWithoutChangingPrimaryPath() async throws {
        let canvasSize = NSSize(width: 24, height: 16)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        var alpha = [UInt8](repeating: 0, count: 24 * 16)
        for y in 2..<8 {
            for x in 2..<7 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        for y in 9..<14 {
            for x in 14..<22 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        let mask = ImageEditorSelectionMask(width: 24, height: 16, alpha: alpha)
        let bounds = try #require(mask.selectedBounds(in: canvasSize))
        viewModel.document.selection = .raster(mask: mask, bounds: bounds)
        viewModel.createPathFromSelection()

        let pathLayer = try #require(viewModel.document.selectedLayer)
        let pathContent = try #require(pathLayer.shapeContent)
        let subpath = try #require(pathContent.editablePathSubpaths.first)
        let primaryBefore = pathContent.editablePathAnchors[0]
        let subpathBefore = subpath[0]
        let primaryBeforeCanvas = CGPoint(
            x: pathLayer.frame.minX + primaryBefore.point.x,
            y: pathLayer.frame.minY + primaryBefore.point.y
        )
        let subpathBeforeCanvas = CGPoint(
            x: pathLayer.frame.minX + subpathBefore.point.x,
            y: pathLayer.frame.minY + subpathBefore.point.y
        )
        let target = CGPoint(x: subpathBeforeCanvas.x + 2, y: subpathBeforeCanvas.y + 1)

        #expect(viewModel.beginMovingPathAnchor(at: subpathBeforeCanvas))
        #expect(viewModel.selectedPathSubpathIndex == 1)
        #expect(viewModel.selectedPathAnchorIndex == 0)
        viewModel.moveSelectedPathAnchor(to: target)
        viewModel.finishMovingPathAnchor()

        let movedLayer = try #require(viewModel.document.selectedLayer)
        let movedContent = try #require(movedLayer.shapeContent)
        let movedSubpath = try #require(movedContent.editablePathSubpaths.first)
        let primaryAfterCanvas = CGPoint(
            x: movedLayer.frame.minX + movedContent.editablePathAnchors[0].point.x,
            y: movedLayer.frame.minY + movedContent.editablePathAnchors[0].point.y
        )
        let subpathAfterCanvas = CGPoint(
            x: movedLayer.frame.minX + movedSubpath[0].point.x,
            y: movedLayer.frame.minY + movedSubpath[0].point.y
        )

        #expect(Int(primaryAfterCanvas.x.rounded()) == Int(primaryBeforeCanvas.x.rounded()))
        #expect(Int(primaryAfterCanvas.y.rounded()) == Int(primaryBeforeCanvas.y.rounded()))
        #expect(Int(subpathAfterCanvas.x.rounded()) == Int(target.x.rounded()))
        #expect(Int(subpathAfterCanvas.y.rounded()) == Int(target.y.rounded()))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathAnchorMove"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathAnchorMoved"))
    }

    @Test func imageEditorDeletesCompoundPathSubpathWithoutRemovingPrimaryPath() async throws {
        let canvasSize = NSSize(width: 24, height: 16)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        var alpha = [UInt8](repeating: 0, count: 24 * 16)
        for y in 2..<8 {
            for x in 2..<7 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        for y in 9..<14 {
            for x in 14..<22 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        let mask = ImageEditorSelectionMask(width: 24, height: 16, alpha: alpha)
        let bounds = try #require(mask.selectedBounds(in: canvasSize))
        viewModel.document.selection = .raster(mask: mask, bounds: bounds)
        viewModel.createPathFromSelection()

        let pathLayer = try #require(viewModel.document.selectedLayer)
        let pathContent = try #require(pathLayer.shapeContent)
        let primaryBefore = try #require(pathContent.editablePathAnchors.first)
        let primaryBeforeCanvas = CGPoint(
            x: pathLayer.frame.minX + primaryBefore.point.x,
            y: pathLayer.frame.minY + primaryBefore.point.y
        )

        #expect(pathContent.editablePathSubpaths.count == 1)
        viewModel.selectedPathSubpathIndex = 1
        viewModel.selectedPathAnchorIndex = 0
        #expect(viewModel.canDeleteSelectedPathSubpath)

        viewModel.deleteSelectedPathSubpath()

        let updatedLayer = try #require(viewModel.document.selectedLayer)
        let updatedContent = try #require(updatedLayer.shapeContent)
        let primaryAfter = try #require(updatedContent.editablePathAnchors.first)
        let primaryAfterCanvas = CGPoint(
            x: updatedLayer.frame.minX + primaryAfter.point.x,
            y: updatedLayer.frame.minY + primaryAfter.point.y
        )

        #expect(updatedContent.editablePathSubpaths.isEmpty)
        #expect(viewModel.selectedPathSubpathIndex == 0)
        #expect(viewModel.selectedPathAnchorIndex == 0)
        #expect(!viewModel.canDeleteSelectedPathSubpath)
        #expect(Int(primaryAfterCanvas.x.rounded()) == Int(primaryBeforeCanvas.x.rounded()))
        #expect(Int(primaryAfterCanvas.y.rounded()) == Int(primaryBeforeCanvas.y.rounded()))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathSubpathDelete"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathSubpathDeleted"))
    }

    @Test func imageEditorDuplicatesCompoundPathSubpathAndSelectsCopy() async throws {
        let canvasSize = NSSize(width: 24, height: 16)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        var alpha = [UInt8](repeating: 0, count: 24 * 16)
        for y in 2..<8 {
            for x in 2..<7 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        for y in 9..<14 {
            for x in 14..<22 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        let mask = ImageEditorSelectionMask(width: 24, height: 16, alpha: alpha)
        let bounds = try #require(mask.selectedBounds(in: canvasSize))
        viewModel.document.selection = .raster(mask: mask, bounds: bounds)
        viewModel.createPathFromSelection()

        let pathLayer = try #require(viewModel.document.selectedLayer)
        let pathContent = try #require(pathLayer.shapeContent)
        let primaryBefore = pathContent.editablePathAnchors.map { anchor in
            CGPoint(x: pathLayer.frame.minX + anchor.point.x, y: pathLayer.frame.minY + anchor.point.y)
        }

        #expect(viewModel.canDuplicateSelectedPathSubpath)
        viewModel.duplicateSelectedPathSubpath()

        let duplicatedLayer = try #require(viewModel.document.selectedLayer)
        let duplicatedContent = try #require(duplicatedLayer.shapeContent)
        let primaryAfter = duplicatedContent.editablePathAnchors.map { anchor in
            CGPoint(x: duplicatedLayer.frame.minX + anchor.point.x, y: duplicatedLayer.frame.minY + anchor.point.y)
        }
        let duplicatedSubpath = try #require(duplicatedContent.editablePathSubpaths.first).map { anchor in
            CGPoint(x: duplicatedLayer.frame.minX + anchor.point.x, y: duplicatedLayer.frame.minY + anchor.point.y)
        }

        #expect(duplicatedContent.editablePathSubpaths.count == 2)
        #expect(primaryAfter.count == primaryBefore.count)
        #expect(duplicatedSubpath.count == primaryBefore.count)
        let primaryBounds = primaryBefore.reduce(CGRect.null) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
        let expectedOffset = CGSize(
            width: min(8, max(0, canvasSize.width - primaryBounds.maxX)),
            height: min(8, max(0, canvasSize.height - primaryBounds.maxY))
        )
        for (before, after) in zip(primaryBefore, primaryAfter) {
            #expect(Int(after.x.rounded()) == Int(before.x.rounded()))
            #expect(Int(after.y.rounded()) == Int(before.y.rounded()))
        }
        for (before, duplicate) in zip(primaryBefore, duplicatedSubpath) {
            #expect(Int(duplicate.x.rounded()) == Int((before.x + expectedOffset.width).rounded()))
            #expect(Int(duplicate.y.rounded()) == Int((before.y + expectedOffset.height).rounded()))
        }
        #expect(viewModel.selectedPathSubpathIndex == 1)
        #expect(viewModel.selectedPathAnchorIndex == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathSubpathDuplicate"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathSubpathDuplicated"))
    }

    @Test func imageEditorNudgesCompoundPathSubpathWithoutMovingPrimaryPath() async throws {
        let canvasSize = NSSize(width: 24, height: 16)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        var alpha = [UInt8](repeating: 0, count: 24 * 16)
        for y in 2..<8 {
            for x in 2..<7 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        for y in 9..<14 {
            for x in 14..<22 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        let mask = ImageEditorSelectionMask(width: 24, height: 16, alpha: alpha)
        let bounds = try #require(mask.selectedBounds(in: canvasSize))
        viewModel.document.selection = .raster(mask: mask, bounds: bounds)
        viewModel.createPathFromSelection()

        let pathLayer = try #require(viewModel.document.selectedLayer)
        let pathContent = try #require(pathLayer.shapeContent)
        let primaryBefore = pathContent.editablePathAnchors.map { anchor in
            CGPoint(x: pathLayer.frame.minX + anchor.point.x, y: pathLayer.frame.minY + anchor.point.y)
        }
        let subpathBefore = try #require(pathContent.editablePathSubpaths.first).map { anchor in
            CGPoint(x: pathLayer.frame.minX + anchor.point.x, y: pathLayer.frame.minY + anchor.point.y)
        }

        viewModel.selectedPathSubpathIndex = 1
        viewModel.selectedPathAnchorIndex = 0
        #expect(viewModel.canMoveSelectedPathSubpath)
        viewModel.nudgeSelectedPathSubpath(dx: 2, dy: -1)

        let movedLayer = try #require(viewModel.document.selectedLayer)
        let movedContent = try #require(movedLayer.shapeContent)
        let primaryAfter = movedContent.editablePathAnchors.map { anchor in
            CGPoint(x: movedLayer.frame.minX + anchor.point.x, y: movedLayer.frame.minY + anchor.point.y)
        }
        let subpathAfter = try #require(movedContent.editablePathSubpaths.first).map { anchor in
            CGPoint(x: movedLayer.frame.minX + anchor.point.x, y: movedLayer.frame.minY + anchor.point.y)
        }

        #expect(primaryAfter.count == primaryBefore.count)
        #expect(subpathAfter.count == subpathBefore.count)
        for (before, after) in zip(primaryBefore, primaryAfter) {
            #expect(Int(after.x.rounded()) == Int(before.x.rounded()))
            #expect(Int(after.y.rounded()) == Int(before.y.rounded()))
        }
        for (before, after) in zip(subpathBefore, subpathAfter) {
            #expect(Int(after.x.rounded()) == Int((before.x + 2).rounded()))
            #expect(Int(after.y.rounded()) == Int((before.y - 1).rounded()))
        }
        #expect(viewModel.selectedPathSubpathIndex == 1)
        #expect(viewModel.selectedPathAnchorIndex == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathSubpathMove"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathSubpathMoved"))
    }

    @Test func imageEditorCyclesCompoundPathSubpathSelection() async throws {
        let canvasSize = NSSize(width: 24, height: 16)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        var alpha = [UInt8](repeating: 0, count: 24 * 16)
        for y in 2..<8 {
            for x in 2..<7 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        for y in 9..<14 {
            for x in 14..<22 {
                alpha[y * 24 + x] = UInt8.max
            }
        }
        let mask = ImageEditorSelectionMask(width: 24, height: 16, alpha: alpha)
        let bounds = try #require(mask.selectedBounds(in: canvasSize))
        viewModel.document.selection = .raster(mask: mask, bounds: bounds)
        viewModel.createPathFromSelection()

        #expect(viewModel.canSelectAdjacentPathSubpath)
        #expect(viewModel.selectedPathSubpathIndex == 0)
        #expect(viewModel.selectedPathAnchorIndex == 0)

        viewModel.selectNextPathSubpath()
        #expect(viewModel.selectedPathSubpathIndex == 1)
        #expect(viewModel.selectedPathAnchorIndex == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.pathSubpathSelected", 2, 2))

        viewModel.selectNextPathSubpath()
        #expect(viewModel.selectedPathSubpathIndex == 0)
        #expect(viewModel.selectedPathAnchorIndex == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.pathSubpathSelected", 1, 2))

        viewModel.selectPreviousPathSubpath()
        #expect(viewModel.selectedPathSubpathIndex == 1)
        #expect(viewModel.selectedPathAnchorIndex == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.pathSubpathSelected", 2, 2))
    }

    @Test func imageEditorDeletesSelectedPathAnchorAndOpensSmallClosedPath() async throws {
        let canvasSize = NSSize(width: 120, height: 90)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.foregroundColor = .systemYellow
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 92, y: 24))
        viewModel.addPenPoint(CGPoint(x: 54, y: 70))
        viewModel.finishPenPath(closed: true)

        var pathLayer = try #require(viewModel.document.selectedLayer)
        var pathContent = try #require(pathLayer.shapeContent)
        #expect(pathContent.isPathClosed)
        #expect(pathContent.editablePathAnchors.count == 3)
        #expect(viewModel.canDeleteSelectedPathAnchor)

        viewModel.deleteSelectedPathAnchor()

        pathLayer = try #require(viewModel.document.selectedLayer)
        pathContent = try #require(pathLayer.shapeContent)
        let selectedPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)

        #expect(!pathContent.isPathClosed)
        #expect(pathContent.fillOpacity == 0)
        #expect(pathContent.editablePathAnchors.count == 2)
        #expect(!viewModel.canLoadSelectionFromSelectedPath)
        #expect(!viewModel.canDeleteSelectedPathAnchor)
        #expect(Int(selectedPoint.x.rounded()) == 92)
        #expect(viewModel.selectedPathControlRole == .anchor)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathAnchorDelete"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathAnchorDeleted"))
    }

    @Test func imageEditorPenArrowNudgeMovesSelectedAnchorAsOneUndoableStep() async throws {
        let canvasSize = NSSize(width: 120, height: 90)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 92, y: 24))
        viewModel.addPenPoint(CGPoint(x: 54, y: 70))
        viewModel.finishPenPath(closed: true)

        let originalPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)
        let historyCount = viewModel.document.history.count
        viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: 5, height: -2))

        let movedPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)
        #expect(movedPoint == CGPoint(x: originalPoint.x + 5, y: originalPoint.y - 2))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathAnchorMove"))

        viewModel.undo()
        #expect(viewModel.selectedPathAnchorCanvasPoint == originalPoint)
    }

    @Test func equivalentPathAnchorPositionEditsPreserveHistoryAndRedo() async throws {
        let canvasSize = NSSize(width: 120, height: 90)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 92, y: 24))
        viewModel.addPenPoint(CGPoint(x: 54, y: 70))
        viewModel.finishPenPath(closed: true)

        let originalPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)
        viewModel.nudgeSelectedPathAnchor(by: CGSize(width: 4, height: 0))
        viewModel.undo()
        #expect(viewModel.canRedo)
        let historyCount = viewModel.document.history.count

        viewModel.setSelectedPathAnchorX(originalPoint.x)
        viewModel.setSelectedPathAnchorY(originalPoint.y)
        viewModel.nudgeSelectedPathAnchor(by: .zero)

        #expect(viewModel.selectedPathAnchorCanvasPoint == originalPoint)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.canRedo)
    }

    @Test func imageEditorInsertsPathAnchorAndPreservesCurvedSegmentHandles() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)
        viewModel.selectNextPathAnchor()
        viewModel.smoothSelectedPathAnchor()

        var pathContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let smoothedAnchor = try #require(pathContent.pathAnchors[safe: 1])
        let nextAnchorBeforeSplit = try #require(pathContent.pathAnchors[safe: 2])
        let p0 = smoothedAnchor.point
        let p1 = smoothedAnchor.outControl ?? p0
        let p2 = nextAnchorBeforeSplit.inControl ?? nextAnchorBeforeSplit.point
        let p3 = nextAnchorBeforeSplit.point
        let expectedSplitPoint = CGPoint(
            x: (p0.x + 3 * p1.x + 3 * p2.x + p3.x) / 8,
            y: (p0.y + 3 * p1.y + 3 * p2.y + p3.y) / 8
        )
        #expect(smoothedAnchor.outControl != nil)
        #expect(viewModel.canInsertPathAnchorAfterSelection)

        viewModel.insertPathAnchorAfterSelection()

        pathContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let selectedPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)
        let previousAnchor = try #require(pathContent.pathAnchors[safe: 1])
        let insertedAnchor = try #require(pathContent.pathAnchors[safe: 2])
        let nextAnchor = try #require(pathContent.pathAnchors[safe: 3])

        #expect(pathContent.isPathClosed)
        #expect(pathContent.pathAnchors.count == 4)
        #expect(previousAnchor.outControl != nil)
        #expect(insertedAnchor.inControl != nil)
        #expect(insertedAnchor.outControl != nil)
        #expect(nextAnchor.inControl != nil)
        #expect(abs(insertedAnchor.point.x - expectedSplitPoint.x) < 0.001)
        #expect(abs(insertedAnchor.point.y - expectedSplitPoint.y) < 0.001)
        #expect(abs(selectedPoint.x - (viewModel.document.selectedLayer?.frame.minX ?? 0) - expectedSplitPoint.x) < 0.001)
        #expect(abs(selectedPoint.y - (viewModel.document.selectedLayer?.frame.minY ?? 0) - expectedSplitPoint.y) < 0.001)
        #expect(viewModel.selectedPathControlRole == .anchor)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathAnchorInsert"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathAnchorInserted"))
    }

    @Test func imageEditorTogglesOpenPathClosedAndBackToOpen() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.opacity = 0.7
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: false)

        var pathContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(!pathContent.isPathClosed)
        #expect(pathContent.fillOpacity == 0)
        #expect(viewModel.canToggleSelectedPathClosed)
        #expect(!viewModel.canLoadSelectionFromSelectedPath)
        #expect(!viewModel.selectedPathIsClosed)

        viewModel.toggleSelectedPathClosed()

        pathContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(pathContent.isPathClosed)
        #expect(pathContent.fillOpacity > 0)
        #expect(viewModel.selectedPathAnchorIndex == 0)
        #expect(viewModel.selectedPathControlRole == .anchor)
        #expect(viewModel.canLoadSelectionFromSelectedPath)
        #expect(viewModel.selectedPathIsClosed)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathClose"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathClosed"))

        viewModel.toggleSelectedPathClosed()

        pathContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        #expect(!pathContent.isPathClosed)
        #expect(pathContent.fillOpacity == 0)
        #expect(!viewModel.canLoadSelectionFromSelectedPath)
        #expect(!viewModel.selectedPathIsClosed)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathOpen"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathOpened"))
    }

    @Test func imageEditorSymmetrizesSelectedPathAnchorHandles() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)
        viewModel.selectNextPathAnchor()
        viewModel.smoothSelectedPathAnchor()

        let originalOutHandle = try #require(viewModel.selectedPathOutControlCanvasPoint)
        #expect(viewModel.beginMovingPathAnchor(at: originalOutHandle))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: originalOutHandle.x + 18, y: originalOutHandle.y - 7))
        viewModel.finishMovingPathAnchor()
        #expect(viewModel.selectedPathControlRole == .outHandle)
        #expect(viewModel.canSymmetrizeSelectedPathAnchorHandles)

        viewModel.symmetrizeSelectedPathAnchorHandles()

        let anchorPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)
        let inHandle = try #require(viewModel.selectedPathInControlCanvasPoint)
        let outHandle = try #require(viewModel.selectedPathOutControlCanvasPoint)
        let inVector = CGSize(width: anchorPoint.x - inHandle.x, height: anchorPoint.y - inHandle.y)
        let outVector = CGSize(width: outHandle.x - anchorPoint.x, height: outHandle.y - anchorPoint.y)

        #expect(Int(inVector.width.rounded()) == Int(outVector.width.rounded()))
        #expect(Int(inVector.height.rounded()) == Int(outVector.height.rounded()))
        #expect(viewModel.selectedPathControlRole == .outHandle)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathHandlesSymmetric"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathHandlesSymmetric"))
    }

    @Test func repeatedPathHandleNormalizationPreservesHistoryAndRedo() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)
        viewModel.selectNextPathAnchor()
        viewModel.smoothSelectedPathAnchor()

        let smoothContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let smoothFrame = try #require(viewModel.document.selectedLayer?.frame)
        let smoothHistoryCount = viewModel.document.history.count
        viewModel.smoothSelectedPathAnchor()
        #expect(viewModel.document.selectedLayer?.shapeContent?.allEditablePathSubpaths == smoothContent.allEditablePathSubpaths)
        #expect(viewModel.document.selectedLayer?.frame == smoothFrame)
        #expect(viewModel.document.history.count == smoothHistoryCount)

        let originalOutHandle = try #require(viewModel.selectedPathOutControlCanvasPoint)
        #expect(viewModel.beginMovingPathAnchor(at: originalOutHandle))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: originalOutHandle.x + 18, y: originalOutHandle.y - 7))
        viewModel.finishMovingPathAnchor()
        viewModel.symmetrizeSelectedPathAnchorHandles()
        let symmetricContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let symmetricFrame = try #require(viewModel.document.selectedLayer?.frame)

        viewModel.nudgeSelectedPathAnchor(by: CGSize(width: 1, height: 0))
        viewModel.undo()
        #expect(viewModel.canRedo)
        let historyCountAfterUndo = viewModel.document.history.count
        viewModel.symmetrizeSelectedPathAnchorHandles()

        #expect(viewModel.document.selectedLayer?.shapeContent?.allEditablePathSubpaths == symmetricContent.allEditablePathSubpaths)
        #expect(viewModel.document.selectedLayer?.frame == symmetricFrame)
        #expect(viewModel.document.history.count == historyCountAfterUndo)
        #expect(viewModel.canRedo)
    }

    @Test func edgeConstrainedHandleSymmetryConvergesWithoutClearingRedo() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 50))
        viewModel.addPenPoint(CGPoint(x: 130, y: 50))
        viewModel.addPenPoint(CGPoint(x: 70, y: 80))
        viewModel.finishPenPath(closed: true)
        viewModel.selectNextPathAnchor()
        viewModel.smoothSelectedPathAnchor()

        let anchorPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)
        let originalInHandle = try #require(viewModel.selectedPathInControlCanvasPoint)
        #expect(viewModel.beginMovingPathAnchor(at: originalInHandle))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: 90, y: anchorPoint.y))
        viewModel.finishMovingPathAnchor()
        #expect(viewModel.selectedPathControlRole == .inHandle)

        viewModel.symmetrizeSelectedPathAnchorHandles()
        let inHandle = try #require(viewModel.selectedPathInControlCanvasPoint)
        let outHandle = try #require(viewModel.selectedPathOutControlCanvasPoint)
        #expect(abs((anchorPoint.x - inHandle.x) - (outHandle.x - anchorPoint.x)) < 0.000_001)
        #expect(abs((anchorPoint.y - inHandle.y) - (outHandle.y - anchorPoint.y)) < 0.000_001)
        #expect(outHandle.x <= canvasSize.width)

        let symmetricContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let symmetricFrame = try #require(viewModel.document.selectedLayer?.frame)
        viewModel.nudgeSelectedPathAnchor(by: CGSize(width: -1, height: 0))
        viewModel.undo()
        #expect(viewModel.canRedo)
        let historyCount = viewModel.document.history.count

        viewModel.symmetrizeSelectedPathAnchorHandles()

        #expect(viewModel.document.selectedLayer?.shapeContent?.allEditablePathSubpaths == symmetricContent.allEditablePathSubpaths)
        #expect(viewModel.document.selectedLayer?.frame == symmetricFrame)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.canRedo)
    }

    @Test func pathAnchorRoundTripDragPreservesHistoryUndoAndRedo() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)
        viewModel.selectNextPathAnchor()
        let anchorPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)

        viewModel.nudgeSelectedPathAnchor(by: CGSize(width: 1, height: 0))
        viewModel.undo()
        #expect(viewModel.canRedo)
        let originalContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let originalFrame = try #require(viewModel.document.selectedLayer?.frame)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        #expect(viewModel.beginMovingPathAnchor(at: anchorPoint))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: anchorPoint.x + 16, y: anchorPoint.y - 9))
        viewModel.moveSelectedPathAnchor(to: anchorPoint)
        viewModel.finishMovingPathAnchor()

        #expect(viewModel.document.selectedLayer?.shapeContent?.allEditablePathSubpaths == originalContent.allEditablePathSubpaths)
        #expect(viewModel.document.selectedLayer?.frame == originalFrame)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.canRedo)
    }

    @Test func cancellingPathHandleDragRestoresDocumentRedoAndAllowsNextGesture() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)
        viewModel.selectNextPathAnchor()
        viewModel.smoothSelectedPathAnchor()
        let outHandle = try #require(viewModel.selectedPathOutControlCanvasPoint)

        viewModel.nudgeSelectedPathAnchor(by: CGSize(width: 1, height: 0))
        viewModel.undo()
        #expect(viewModel.canRedo)
        let originalContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let originalFrame = try #require(viewModel.document.selectedLayer?.frame)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        #expect(viewModel.beginMovingPathAnchor(at: outHandle))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: outHandle.x + 18, y: outHandle.y + 11))
        #expect(viewModel.document.selectedLayer?.shapeContent?.allEditablePathSubpaths != originalContent.allEditablePathSubpaths)
        #expect(viewModel.cancelMovingPathAnchor())

        #expect(viewModel.document.selectedLayer?.shapeContent?.allEditablePathSubpaths == originalContent.allEditablePathSubpaths)
        #expect(viewModel.document.selectedLayer?.frame == originalFrame)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.canRedo)
        #expect(!viewModel.cancelMovingPathAnchor())

        #expect(viewModel.beginMovingPathAnchor(at: outHandle))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: outHandle.x + 7, y: outHandle.y - 5))
        viewModel.finishMovingPathAnchor()
        #expect(viewModel.document.selectedLayer?.shapeContent?.allEditablePathSubpaths != originalContent.allEditablePathSubpaths)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.redoStack.isEmpty)
    }

    @Test func switchingToolsCancelsPathDragBeforeChangingInputContext() async throws {
        let fixture = try makeActivePathDragFixture()

        fixture.viewModel.selectTool(.brush)

        #expect(fixture.viewModel.selectedTool == .brush)
        expectCancelledPathDragRestored(fixture)
        fixture.viewModel.selectTool(.directSelection)
        #expect(fixture.viewModel.beginMovingPathAnchor(at: fixture.anchorPoint))
        fixture.viewModel.moveSelectedPathAnchor(
            to: CGPoint(x: fixture.anchorPoint.x + 6, y: fixture.anchorPoint.y + 4)
        )
        fixture.viewModel.finishMovingPathAnchor()
        #expect(fixture.viewModel.document.history.count == fixture.historyCount + 1)
        #expect(fixture.viewModel.undoStack.count == fixture.undoCount + 1)
        #expect(fixture.viewModel.redoStack.isEmpty)
    }

    @Test func enteringComponentLibraryCancelsPathDragAndKeepsNextGestureUsable() async throws {
        let fixture = try makeActivePathDragFixture()

        fixture.viewModel.selectLeftSidebarTab(.components)

        #expect(fixture.viewModel.selectedLeftSidebarTab == .components)
        expectCancelledPathDragRestored(fixture)
        fixture.viewModel.selectLeftSidebarTab(.tools)
        #expect(fixture.viewModel.beginMovingPathAnchor(at: fixture.anchorPoint))
        fixture.viewModel.moveSelectedPathAnchor(
            to: CGPoint(x: fixture.anchorPoint.x - 5, y: fixture.anchorPoint.y + 7)
        )
        fixture.viewModel.finishMovingPathAnchor()
        #expect(fixture.viewModel.document.history.count == fixture.historyCount + 1)
        #expect(fixture.viewModel.undoStack.count == fixture.undoCount + 1)
        #expect(fixture.viewModel.redoStack.isEmpty)
    }

    @Test func selectingAnotherLayerCancelsPathDragBeforeChangingEditingObject() async throws {
        let fixture = try makeActivePathDragFixture(includingAlternateLayer: true)
        let alternateLayerID = try #require(fixture.alternateLayerID)

        fixture.viewModel.selectLayer(alternateLayerID)

        #expect(fixture.viewModel.document.selectedLayerID == alternateLayerID)
        expectCancelledPathDragRestored(fixture)
        fixture.viewModel.selectLayer(fixture.pathLayerID)
        #expect(fixture.viewModel.beginMovingPathAnchor(at: fixture.anchorPoint))
        fixture.viewModel.moveSelectedPathAnchor(
            to: CGPoint(x: fixture.anchorPoint.x + 8, y: fixture.anchorPoint.y - 3)
        )
        fixture.viewModel.finishMovingPathAnchor()
        #expect(fixture.viewModel.document.history.count == fixture.historyCount + 1)
        #expect(fixture.viewModel.undoStack.count == fixture.undoCount + 1)
        #expect(fixture.viewModel.redoStack.isEmpty)
    }

    @Test func startingFreshAnchorMoveCancelsAnyStaleTransactionBeforeBeginning() async throws {
        let fixture = try makeActivePathDragFixture()

        #expect(fixture.viewModel.beginMovingPathAnchor(at: fixture.anchorPoint))
        fixture.viewModel.moveSelectedPathAnchor(
            to: CGPoint(x: fixture.anchorPoint.x - 7, y: fixture.anchorPoint.y - 6)
        )
        fixture.viewModel.finishMovingPathAnchor()

        #expect(!fixture.viewModel.hasActivePathAnchorMoveTransaction)
        #expect(fixture.viewModel.document.history.count == fixture.historyCount + 1)
        #expect(fixture.viewModel.undoStack.count == fixture.undoCount + 1)
        #expect(fixture.viewModel.redoStack.isEmpty)
        fixture.viewModel.undo()
        let restoredLayer = fixture.viewModel.document.layers.first { $0.id == fixture.pathLayerID }
        #expect(restoredLayer?.shapeContent?.allEditablePathSubpaths == fixture.originalContent.allEditablePathSubpaths)
        #expect(restoredLayer?.frame == fixture.originalFrame)
    }

    @Test func arrowNudgeDuringPathDragCancelsPreviewBeforeNextNudgeEdits() async throws {
        let fixture = try makeActivePathDragFixture()

        fixture.viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: 1, height: 0))

        expectCancelledPathDragRestored(fixture)
        fixture.viewModel.nudgeSelectionOrSelectedLayer(by: CGSize(width: 1, height: 0))
        #expect(fixture.viewModel.selectedPathAnchorCanvasPoint == CGPoint(
            x: fixture.anchorPoint.x + 1,
            y: fixture.anchorPoint.y
        ))
        #expect(fixture.viewModel.document.history.count == fixture.historyCount + 1)
        #expect(fixture.viewModel.undoStack.count == fixture.undoCount + 1)
        #expect(fixture.viewModel.redoStack.isEmpty)
    }

    @Test func deleteDuringPathDragCancelsPreviewBeforeNextDeleteEdits() async throws {
        let fixture = try makeActivePathDragFixture()
        let originalAnchorCount = fixture.originalContent.editablePathAnchors.count

        fixture.viewModel.deleteSelectedPathAnchor()

        expectCancelledPathDragRestored(fixture)
        fixture.viewModel.deleteSelectedPathAnchor()
        let editedContent = try #require(
            fixture.viewModel.document.layers.first { $0.id == fixture.pathLayerID }?.shapeContent
        )
        #expect(editedContent.editablePathAnchors.count == originalAnchorCount - 1)
        #expect(fixture.viewModel.document.history.count == fixture.historyCount + 1)
        #expect(fixture.viewModel.undoStack.count == fixture.undoCount + 1)
        #expect(fixture.viewModel.redoStack.isEmpty)
    }

    @Test func anchorNavigationDuringPathDragCancelsPreviewBeforeChangingSelection() async throws {
        let fixture = try makeActivePathDragFixture()
        let originalSelection = fixture.viewModel.selectedPathAnchorIndex

        fixture.viewModel.selectNextPathAnchor()

        expectCancelledPathDragRestored(fixture)
        #expect(fixture.viewModel.selectedPathAnchorIndex == originalSelection)
        fixture.viewModel.selectNextPathAnchor()
        #expect(fixture.viewModel.selectedPathAnchorIndex != originalSelection)
        #expect(fixture.viewModel.document.history.count == fixture.historyCount)
        #expect(fixture.viewModel.undoStack.count == fixture.undoCount)
        #expect(fixture.viewModel.redoStack.count == fixture.redoCount)
    }

    @Test func handleCommandDuringPathDragCancelsPreviewBeforeNextCommandEdits() async throws {
        let fixture = try makeActivePathDragFixture()

        fixture.viewModel.smoothSelectedPathAnchor()

        expectCancelledPathDragRestored(fixture)
        let restoredAnchor = try #require(
            fixture.viewModel.document.selectedLayer?.shapeContent?.editablePathAnchors[safe: 1]
        )
        #expect(restoredAnchor.inControl == nil)
        #expect(restoredAnchor.outControl == nil)

        fixture.viewModel.smoothSelectedPathAnchor()
        let editedAnchor = try #require(
            fixture.viewModel.document.selectedLayer?.shapeContent?.editablePathAnchors[safe: 1]
        )
        #expect(editedAnchor.inControl != nil)
        #expect(editedAnchor.outControl != nil)
        #expect(fixture.viewModel.document.history.count == fixture.historyCount + 1)
        #expect(fixture.viewModel.undoStack.count == fixture.undoCount + 1)
        #expect(fixture.viewModel.redoStack.isEmpty)
    }

    @Test func undoDuringPathAnchorDragCancelsPreviewBeforeReachingHistory() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)
        viewModel.selectNextPathAnchor()
        let anchorPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)
        viewModel.nudgeSelectedPathAnchor(by: CGSize(width: 1, height: 0))
        viewModel.undo()
        #expect(viewModel.canRedo)

        let originalContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let originalFrame = try #require(viewModel.document.selectedLayer?.frame)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count
        #expect(viewModel.beginMovingPathAnchor(at: anchorPoint))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: anchorPoint.x + 16, y: anchorPoint.y - 9))
        #expect(viewModel.hasActivePathAnchorMoveTransaction)
        #expect(viewModel.canRedo)

        viewModel.undo()

        #expect(!viewModel.hasActivePathAnchorMoveTransaction)
        #expect(viewModel.document.selectedLayer?.shapeContent?.allEditablePathSubpaths == originalContent.allEditablePathSubpaths)
        #expect(viewModel.document.selectedLayer?.frame == originalFrame)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(!viewModel.cancelMovingPathAnchor())

        viewModel.redo()
        #expect(viewModel.selectedPathAnchorCanvasPoint == CGPoint(x: anchorPoint.x + 1, y: anchorPoint.y))
    }

    @Test func redoDuringPathHandleDragCancelsPreviewBeforeApplyingExistingRedo() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)
        viewModel.selectNextPathAnchor()
        viewModel.smoothSelectedPathAnchor()
        let anchorPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)
        let outHandle = try #require(viewModel.selectedPathOutControlCanvasPoint)
        viewModel.nudgeSelectedPathAnchor(by: CGSize(width: 1, height: 0))
        viewModel.undo()
        #expect(viewModel.canRedo)

        let originalContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let originalFrame = try #require(viewModel.document.selectedLayer?.frame)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count
        #expect(viewModel.beginMovingPathAnchor(at: outHandle))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: outHandle.x + 18, y: outHandle.y + 11))
        #expect(viewModel.hasActivePathAnchorMoveTransaction)
        #expect(viewModel.canRedo)

        viewModel.redo()

        #expect(!viewModel.hasActivePathAnchorMoveTransaction)
        #expect(viewModel.document.selectedLayer?.shapeContent?.allEditablePathSubpaths == originalContent.allEditablePathSubpaths)
        #expect(viewModel.document.selectedLayer?.frame == originalFrame)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(!viewModel.cancelMovingPathAnchor())

        viewModel.redo()
        #expect(viewModel.selectedPathAnchorCanvasPoint == CGPoint(x: anchorPoint.x + 1, y: anchorPoint.y))
    }

    @Test func realPathAnchorDragCommitsOneUndoAndClearsRedo() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)
        viewModel.selectNextPathAnchor()
        let originalPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)

        viewModel.nudgeSelectedPathAnchor(by: CGSize(width: 1, height: 0))
        viewModel.undo()
        #expect(viewModel.canRedo)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.beginMovingPathAnchor(at: originalPoint))
        viewModel.moveSelectedPathAnchor(to: CGPoint(x: originalPoint.x + 12, y: originalPoint.y + 7))
        viewModel.finishMovingPathAnchor()

        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(!viewModel.canRedo)
        viewModel.undo()
        #expect(viewModel.selectedPathAnchorCanvasPoint == originalPoint)
    }

    @Test func imageEditorReversesPathDirectionAndSwapsControlHandles() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)
        viewModel.selectNextPathAnchor()
        viewModel.smoothSelectedPathAnchor()

        let beforeContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let beforeFirst = try #require(beforeContent.pathAnchors.first)
        let beforeMiddle = try #require(beforeContent.pathAnchors[safe: 1])
        let beforeLast = try #require(beforeContent.pathAnchors.last)
        #expect(beforeMiddle.inControl != nil)
        #expect(beforeMiddle.outControl != nil)
        #expect(viewModel.canReverseSelectedPathDirection)

        viewModel.reverseSelectedPathDirection()

        let afterContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let afterFirst = try #require(afterContent.pathAnchors.first)
        let afterMiddle = try #require(afterContent.pathAnchors[safe: 1])
        let afterLast = try #require(afterContent.pathAnchors.last)

        #expect(afterContent.isPathClosed)
        #expect(afterContent.pathAnchors.count == beforeContent.pathAnchors.count)
        #expect(afterFirst.point == beforeLast.point)
        #expect(afterMiddle.point == beforeMiddle.point)
        #expect(pointsApproximatelyEqual(afterMiddle.inControl, beforeMiddle.outControl))
        #expect(pointsApproximatelyEqual(afterMiddle.outControl, beforeMiddle.inControl))
        #expect(afterLast.point == beforeFirst.point)
        #expect(viewModel.selectedPathAnchorIndex == 1)
        #expect(viewModel.selectedPathControlRole == .anchor)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathReverse"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathReversed"))
    }

    @Test func imageEditorStrokesSelectedPathToLowerPixelLayer() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let targetLayerID = try #require(viewModel.document.selectedLayerID)
        let targetPixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectTool(.pen)
        viewModel.foregroundColor = .white
        viewModel.brushSize = 10
        viewModel.opacity = 1
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: false)

        let pathLayerID = try #require(viewModel.document.selectedLayerID)
        #expect(pathLayerID != targetLayerID)
        #expect(viewModel.canStrokeSelectedPathToPixelLayer)

        viewModel.strokeSelectedPathToPixelLayer()

        let targetLayer = try #require(viewModel.document.layers.first { $0.id == targetLayerID })
        let strokedPixel = try #require(targetLayer.image.color(at: CGPoint(x: 62, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.selectedLayerID == pathLayerID)
        #expect(try #require(targetLayer.image.qingtuPNGData()) != targetPixelsBefore)
        #expect(strokedPixel.redComponent > 0.6)
        #expect(strokedPixel.greenComponent > 0.6)
        #expect(strokedPixel.blueComponent > 0.6)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathStroke"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathStroked"))
    }

    @Test func imageEditorFillsSelectedPathToLowerPixelLayer() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let targetLayerID = try #require(viewModel.document.selectedLayerID)
        let targetPixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectTool(.pen)
        viewModel.foregroundColor = .white
        viewModel.opacity = 1
        viewModel.addPenPoint(CGPoint(x: 22, y: 22))
        viewModel.addPenPoint(CGPoint(x: 112, y: 26))
        viewModel.addPenPoint(CGPoint(x: 68, y: 82))
        viewModel.finishPenPath(closed: true)

        let pathLayerID = try #require(viewModel.document.selectedLayerID)
        #expect(pathLayerID != targetLayerID)
        #expect(viewModel.canFillSelectedPathToPixelLayer)

        viewModel.fillSelectedPathToPixelLayer()

        let targetLayer = try #require(viewModel.document.layers.first { $0.id == targetLayerID })
        let filledPixel = try #require(targetLayer.image.color(at: CGPoint(x: 70, y: 44))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.selectedLayerID == pathLayerID)
        #expect(try #require(targetLayer.image.qingtuPNGData()) != targetPixelsBefore)
        #expect(filledPixel.redComponent > 0.6)
        #expect(filledPixel.greenComponent > 0.6)
        #expect(filledPixel.blueComponent > 0.6)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathFill"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathFilled"))
    }

    @Test func imageEditorAppliesSelectedPathAsLowerLayerMask() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let targetLayerID = try #require(viewModel.document.selectedLayerID)
        let targetLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[targetLayerIndex].isLocked = false
        viewModel.document.layers[targetLayerIndex].image = testBitmapImage(
            size: canvasSize,
            background: .systemBlue
        )

        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 22, y: 22))
        viewModel.addPenPoint(CGPoint(x: 112, y: 26))
        viewModel.addPenPoint(CGPoint(x: 68, y: 82))
        viewModel.finishPenPath(closed: true)

        let pathLayerID = try #require(viewModel.document.selectedLayerID)
        let layerCountBeforeMask = viewModel.document.layers.count
        #expect(pathLayerID != targetLayerID)
        #expect(viewModel.canApplySelectedPathAsLayerMask)

        viewModel.applySelectedPathAsLayerMask()

        let targetLayer = try #require(viewModel.document.layers.first { $0.id == targetLayerID })
        let insidePixel = try #require(targetLayer.visibleImage.color(at: CGPoint(x: 70, y: 44))?.usingColorSpace(.deviceRGB))
        let outsidePixel = try #require(targetLayer.visibleImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == layerCountBeforeMask)
        #expect(viewModel.document.selectedLayerID == pathLayerID)
        #expect(targetLayer.mask != nil)
        #expect(targetLayer.isMaskEnabled)
        #expect(targetLayer.isMaskLinked)
        #expect(insidePixel.blueComponent > 0.4)
        #expect(outsidePixel.alphaComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathLayerMask"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.pathLayerMask"))
    }

    @Test func imageEditorRasterizesSelectedVectorMaskToLayerMask() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let vectorMask = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: [
                CGPoint(x: 22, y: 22),
                CGPoint(x: 112, y: 26),
                CGPoint(x: 68, y: 82)
            ],
            pathAnchors: [
                ImageEditorPathAnchor(point: CGPoint(x: 22, y: 22)),
                ImageEditorPathAnchor(point: CGPoint(x: 112, y: 26)),
                ImageEditorPathAnchor(point: CGPoint(x: 68, y: 82))
            ],
            isPathClosed: true
        )
        viewModel.document.layers[layerIndex].isLocked = false
        viewModel.document.layers[layerIndex].image = testBitmapImage(
            size: canvasSize,
            background: .systemBlue
        )
        viewModel.document.layers[layerIndex].vectorMask = vectorMask.normalized(size: canvasSize)
        viewModel.document.layers[layerIndex].isVectorMaskEnabled = true

        let insideBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 70, y: 44))?.usingColorSpace(.deviceRGB))
        let outsideBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.canRasterizeSelectedVectorMask)
        #expect(insideBefore.blueComponent > 0.4)
        #expect(outsideBefore.redComponent < 0.05)
        #expect(outsideBefore.greenComponent < 0.05)
        #expect(outsideBefore.blueComponent < 0.05)

        viewModel.rasterizeSelectedVectorMask()

        let rasterizedLayer = try #require(viewModel.document.selectedLayer)
        let insideAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 70, y: 44))?.usingColorSpace(.deviceRGB))
        let outsideAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(rasterizedLayer.vectorMask == nil)
        #expect(rasterizedLayer.mask != nil)
        #expect(rasterizedLayer.isMaskEnabled)
        #expect(rasterizedLayer.isMaskLinked)
        #expect(viewModel.isEditingLayerMask)
        #expect(insideAfter.blueComponent > 0.4)
        #expect(outsideAfter.redComponent < 0.05)
        #expect(outsideAfter.greenComponent < 0.05)
        #expect(outsideAfter.blueComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskRasterize"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.vectorMaskRasterized"))
    }

    @Test func imageEditorCreatesVectorMaskFromCurrentSelection() async throws {
        let canvasSize = NSSize(width: 100, height: 80)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].image = testBitmapImage(size: canvasSize, background: .systemBlue)
        viewModel.document.layers[layerIndex].frame = CGRect(origin: .zero, size: canvasSize)
        viewModel.document.layers[layerIndex].isLocked = false
        viewModel.document.selection = .rectangle(CGRect(x: 20, y: 15, width: 50, height: 35))
        let sourceInside = try #require(
            viewModel.document.layers[layerIndex].image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB)
        )

        #expect(viewModel.canCreateVectorMaskFromSelection)

        viewModel.addVectorMaskFromSelection()

        let maskedLayer = try #require(viewModel.document.selectedLayer)
        let vectorMask = try #require(maskedLayer.vectorMask)
        let effectiveMask = try #require(maskedLayer.effectiveMask)
        let maskInside = try #require(effectiveMask.color(at: CGPoint(x: 40, y: 30)))
        let maskOutside = try #require(effectiveMask.color(at: CGPoint(x: 8, y: 8)))
        let anchors = vectorMask.editablePathAnchors
        let inside = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let outside = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(vectorMask.kind == .path)
        #expect(vectorMask.isPathClosed)
        #expect(anchors.map(\.point) == [
            CGPoint(x: 20, y: 15),
            CGPoint(x: 70, y: 15),
            CGPoint(x: 70, y: 50),
            CGPoint(x: 20, y: 50)
        ])
        #expect(maskedLayer.isVectorMaskEnabled)
        #expect(sourceInside.alphaComponent > 0.95)
        #expect(sourceInside.redComponent < 0.15)
        #expect(sourceInside.greenComponent < 0.75)
        #expect(sourceInside.blueComponent > 0.4)
        #expect(maskInside.alphaComponent > 0.95)
        #expect(maskOutside.alphaComponent < 0.05)
        #expect(inside.blueComponent > 0.4)
        #expect(outside.redComponent < 0.05)
        #expect(outside.greenComponent < 0.05)
        #expect(outside.blueComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskFromSelection"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.vectorMaskFromSelection"))

        viewModel.clearSelection()
        #expect(viewModel.document.selection == nil)
        #expect(viewModel.canLoadSelectionFromVectorMask)
        viewModel.loadSelectionFromVectorMask()
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromVectorMask"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.vectorMaskSelection"))
    }

    @Test func imageEditorCreatesVectorMaskOnLayerGroupFromCurrentSelection() async throws {
        let canvasSize = NSSize(width: 100, height: 80)
        let image = testBitmapImage(size: canvasSize, background: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == firstID })].image = testBitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [(CGRect(x: 0, y: 0, width: 50, height: 80), .systemPink)]
        )

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == secondID })].image = testBitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [(CGRect(x: 50, y: 0, width: 50, height: 80), .systemGreen)]
        )

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 50, height: 80))

        #expect(viewModel.canCreateVectorMaskFromSelection)

        viewModel.addVectorMaskFromSelection()

        let groupLayer = try #require(viewModel.document.layers.first { $0.id == groupID })
        let vectorMask = try #require(groupLayer.vectorMask)
        let anchors = vectorMask.editablePathAnchors
        let visibleLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 25, y: 40))?.usingColorSpace(.deviceRGB))
        let clippedRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 40))?.usingColorSpace(.deviceRGB))

        #expect(groupLayer.isGroup)
        #expect(vectorMask.kind == .path)
        #expect(vectorMask.isPathClosed)
        #expect(anchors.map(\.point) == [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 0),
            CGPoint(x: 50, y: 80),
            CGPoint(x: 0, y: 80)
        ])
        #expect(groupLayer.isVectorMaskEnabled)
        #expect(visibleLeft.redComponent > visibleLeft.blueComponent + 0.2)
        #expect(clippedRight.blueComponent > clippedRight.greenComponent + 0.2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskFromSelection"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.vectorMaskFromSelection"))

        viewModel.clearSelection()
        #expect(viewModel.document.selection == nil)
        #expect(viewModel.canLoadSelectionFromVectorMask)
        viewModel.loadSelectionFromVectorMask()
        let loadedSelection = try #require(viewModel.document.selection)
        #expect(loadedSelection.rasterMask?.selectedBounds(in: canvasSize) == CGRect(x: 0, y: 0, width: 50, height: 80))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromVectorMask"))

        #expect(viewModel.canEditSelectedVectorMaskAsPath)
        viewModel.editSelectedVectorMaskAsPath()
        let pathLayer = try #require(viewModel.document.selectedLayer)
        let pathContent = try #require(pathLayer.shapeContent)
        #expect(pathContent.kind == .path)
        #expect(pathContent.isPathClosed)
        #expect(viewModel.document.layers.first { $0.id == groupID }?.vectorMask == nil)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskEditPath"))
    }

    @Test func imageEditorCopiesVectorMaskToSelectedLayersWithScaledPath() async throws {
        let canvasSize = NSSize(width: 120, height: 90)
        let image = testBitmapImage(size: canvasSize, background: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let sourceID = try #require(viewModel.document.selectedLayerID)
        let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
        let vectorMask = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: [
                CGPoint(x: 20, y: 10),
                CGPoint(x: 100, y: 20),
                CGPoint(x: 60, y: 80)
            ],
            pathAnchors: [
                ImageEditorPathAnchor(
                    point: CGPoint(x: 20, y: 10),
                    inControl: CGPoint(x: 10, y: 8),
                    outControl: CGPoint(x: 35, y: 16)
                ),
                ImageEditorPathAnchor(point: CGPoint(x: 100, y: 20)),
                ImageEditorPathAnchor(point: CGPoint(x: 60, y: 80))
            ],
            isPathClosed: true
        )
        viewModel.document.layers[sourceIndex].vectorMask = vectorMask.normalized(size: canvasSize)
        viewModel.document.layers[sourceIndex].isVectorMaskEnabled = false
        viewModel.document.layers[sourceIndex].isMaskLinked = false

        viewModel.addLayer()
        let targetID = try #require(viewModel.document.selectedLayerID)
        let targetIndex = try #require(viewModel.document.selectedLayerIndex)
        let targetSize = NSSize(width: 60, height: 45)
        viewModel.document.layers[targetIndex].image = testBitmapImage(size: targetSize, background: .clear)
        viewModel.document.layers[targetIndex].frame = CGRect(origin: .zero, size: targetSize)

        viewModel.selectLayer(targetID)
        viewModel.selectLayer(sourceID, extendingSelection: true)

        #expect(viewModel.canCopyVectorMaskToSelectedLayers)
        viewModel.copyVectorMaskToSelectedLayers()

        let copiedLayer = try #require(viewModel.document.layers.first { $0.id == targetID })
        let copiedMask = try #require(copiedLayer.vectorMask)
        let anchors = copiedMask.editablePathAnchors

        #expect(anchors.count == 3)
        #expect(anchors[0].point == CGPoint(x: 10, y: 5))
        #expect(anchors[0].inControl == CGPoint(x: 5, y: 4))
        #expect(anchors[0].outControl == CGPoint(x: 17.5, y: 8))
        #expect(anchors[1].point == CGPoint(x: 50, y: 10))
        #expect(anchors[2].point == CGPoint(x: 30, y: 40))
        #expect(copiedLayer.isVectorMaskEnabled == false)
        #expect(copiedLayer.isMaskLinked == false)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskCopy"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.vectorMaskCopied", 1))

        let historyCountAfterFirstCopy = viewModel.document.history.count
        viewModel.copyVectorMaskToSelectedLayers()
        #expect(viewModel.document.history.count == historyCountAfterFirstCopy)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.vectorMaskCopyUnchanged"))
    }

    @Test func imageEditorVectorMaskCanRoundTripThroughEditablePathLayer() async throws {
        let canvasSize = NSSize(width: 120, height: 90)
        let image = testBitmapImage(size: canvasSize, background: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let targetID = try #require(viewModel.document.selectedLayerID)
        let targetIndex = try #require(viewModel.document.selectedLayerIndex)
        let vectorMask = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: [
                CGPoint(x: 20, y: 18),
                CGPoint(x: 96, y: 24),
                CGPoint(x: 64, y: 72)
            ],
            pathAnchors: [
                ImageEditorPathAnchor(point: CGPoint(x: 20, y: 18)),
                ImageEditorPathAnchor(point: CGPoint(x: 96, y: 24)),
                ImageEditorPathAnchor(point: CGPoint(x: 64, y: 72))
            ],
            isPathClosed: true
        )
        viewModel.document.layers[targetIndex].vectorMask = vectorMask.normalized(size: canvasSize)

        let layerCountBeforeEdit = viewModel.document.layers.count
        #expect(viewModel.canEditSelectedVectorMaskAsPath)
        viewModel.editSelectedVectorMaskAsPath()

        let pathLayer = try #require(viewModel.document.selectedLayer)
        let pathContent = try #require(pathLayer.shapeContent)
        let targetAfterEdit = try #require(viewModel.document.layers.first { $0.id == targetID })

        #expect(viewModel.document.layers.count == layerCountBeforeEdit + 1)
        #expect(targetAfterEdit.vectorMask == nil)
        #expect(pathContent.kind == .path)
        #expect(pathContent.isPathClosed)
        #expect(pathContent.editablePathAnchors.count == 3)
        #expect(pathLayer.name == L10n.text("imageEditor.layer.vectorMaskPathName"))
        #expect(viewModel.selectedPathAnchorCanvasPoint != nil)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskEditPath"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.vectorMaskEditPath"))

        #expect(viewModel.canApplySelectedPathAsVectorMask)
        viewModel.applySelectedPathAsVectorMask()

        let targetAfterApply = try #require(viewModel.document.selectedLayer)
        let reappliedMask = try #require(targetAfterApply.vectorMask)

        #expect(viewModel.document.layers.count == layerCountBeforeEdit)
        #expect(targetAfterApply.id == targetID)
        #expect(reappliedMask.kind == .path)
        #expect(reappliedMask.isPathClosed)
        #expect(reappliedMask.editablePathAnchors.count == 3)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pathVectorMask"))
    }

    private func testBitmapImage(
        size: NSSize,
        background: NSColor,
        fills: [(rect: CGRect, color: NSColor)] = []
    ) -> NSImage {
        NSImage.rendered(size: size) { rect in
            (background.usingColorSpace(.deviceRGB) ?? background).setFill()
            rect.fill()
            for fill in fills {
                (fill.color.usingColorSpace(.deviceRGB) ?? fill.color).setFill()
                fill.rect.fill()
            }
        } ?? NSImage.transparent(size: size)
    }

    private struct ActivePathDragFixture {
        let viewModel: ImageEditorViewModel
        let pathLayerID: UUID
        let alternateLayerID: UUID?
        let anchorPoint: CGPoint
        let originalContent: ImageEditorShapeContent
        let originalFrame: CGRect
        let historyCount: Int
        let undoCount: Int
        let redoCount: Int
    }

    private func makeActivePathDragFixture(
        includingAlternateLayer: Bool = false
    ) throws -> ActivePathDragFixture {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.selectTool(.pen)
        viewModel.addPenPoint(CGPoint(x: 20, y: 20))
        viewModel.addPenPoint(CGPoint(x: 104, y: 28))
        viewModel.addPenPoint(CGPoint(x: 70, y: 78))
        viewModel.finishPenPath(closed: true)
        let pathLayerID = try #require(viewModel.document.selectedLayerID)
        var alternateLayerID: UUID?
        if includingAlternateLayer {
            viewModel.addLayer()
            alternateLayerID = try #require(viewModel.document.selectedLayerID)
            viewModel.selectLayer(pathLayerID)
        }
        viewModel.selectNextPathAnchor()
        let anchorPoint = try #require(viewModel.selectedPathAnchorCanvasPoint)
        viewModel.nudgeSelectedPathAnchor(by: CGSize(width: 1, height: 0))
        viewModel.undo()
        let originalContent = try #require(viewModel.document.selectedLayer?.shapeContent)
        let originalFrame = try #require(viewModel.document.selectedLayer?.frame)
        let fixture = ActivePathDragFixture(
            viewModel: viewModel,
            pathLayerID: pathLayerID,
            alternateLayerID: alternateLayerID,
            anchorPoint: anchorPoint,
            originalContent: originalContent,
            originalFrame: originalFrame,
            historyCount: viewModel.document.history.count,
            undoCount: viewModel.undoStack.count,
            redoCount: viewModel.redoStack.count
        )
        #expect(viewModel.beginMovingPathAnchor(at: anchorPoint))
        viewModel.moveSelectedPathAnchor(
            to: CGPoint(x: anchorPoint.x + 15, y: anchorPoint.y - 8)
        )
        #expect(viewModel.hasActivePathAnchorMoveTransaction)
        return fixture
    }

    private func expectCancelledPathDragRestored(_ fixture: ActivePathDragFixture) {
        let pathLayer = fixture.viewModel.document.layers.first { $0.id == fixture.pathLayerID }
        #expect(!fixture.viewModel.hasActivePathAnchorMoveTransaction)
        #expect(pathLayer?.shapeContent?.allEditablePathSubpaths == fixture.originalContent.allEditablePathSubpaths)
        #expect(pathLayer?.frame == fixture.originalFrame)
        #expect(fixture.viewModel.document.history.count == fixture.historyCount)
        #expect(fixture.viewModel.undoStack.count == fixture.undoCount)
        #expect(fixture.viewModel.redoStack.count == fixture.redoCount)
        #expect(!fixture.viewModel.cancelMovingPathAnchor())
    }

    private func isPixelLayer(_ layer: ImageEditorLayer) -> Bool {
        if case .pixel = layer.kind {
            return true
        }
        return false
    }

    private func maskAlpha(_ mask: ImageEditorSelectionMask, x: Int, y: Int) -> UInt8 {
        guard x >= 0, x < mask.width, y >= 0, y < mask.height else { return 0 }
        return mask.alpha[y * mask.width + x]
    }

    private func pointsApproximatelyEqual(_ lhs: CGPoint?, _ rhs: CGPoint?, tolerance: CGFloat = 0.000_1) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        return abs(lhs.x - rhs.x) <= tolerance && abs(lhs.y - rhs.y) <= tolerance
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
