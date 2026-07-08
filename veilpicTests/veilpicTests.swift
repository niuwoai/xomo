//
//  veilpicTests.swift
//  veilpicTests
//
//  Created by rocky on 2026/5/19.
//

import Testing
@testable import musepic
import AppKit

@MainActor
@Suite(.serialized)
struct veilpicTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

    @Test func losslessOptimizerKeepsPNGAndNeverIncreasesSize() async throws {
        let image = NSImage(size: NSSize(width: 48, height: 48))
        image.lockFocus()
        NSColor(calibratedRed: 0.91, green: 0.97, blue: 0.98, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 48, height: 48).fill()
        NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.29, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 32, height: 32)).fill()
        image.unlockFocus()

        let originalData = try #require(image.qingtuPNGData())
        let result = LosslessImageOptimizer.optimizedPNGData(originalData, image: image)
        let pngSignature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

        #expect(Array(result.optimizedData.prefix(8)) == pngSignature)
        #expect(result.optimizedData.count <= originalData.count)
    }

    @MainActor
    @Test func applyingEditedPreviewImageResetsPostProcessPipeline() async throws {
        let viewModel = MenuBarUploadViewModel(
            profileStore: InMemoryStorageProfileStore(),
            historyStore: InMemoryUploadHistoryStore()
        )
        let original = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let edited = testImage(color: .systemPink, size: NSSize(width: 40, height: 30))

        viewModel.workspaceItem = ImageWorkspaceItem(originalImage: original, sourceName: "source.png", createdAt: Date())
        viewModel.postProcessRecipe = PostProcessRecipe.defaults(for: .rounded)
        viewModel.generatedVariants = [
            GeneratedImageVariant(kind: .original, filename: "old.png", data: Data([1, 2, 3]), contentType: "image/png")
        ]
        viewModel.uploadResult = UploadResult(
            sourceName: "old.png",
            createdAt: Date(),
            links: [.original: try #require(URL(string: "https://example.com/old.png"))]
        )

        viewModel.applyEditedPreviewImage(edited)

        #expect(viewModel.workspaceItem?.sourceName == "source.png-edited")
        #expect(viewModel.workspaceItem?.originalImage.size == edited.size)
        #expect(viewModel.postProcessRecipe == PostProcessRecipe.defaults(for: .original))
        #expect(viewModel.generatedVariants.isEmpty)
        #expect(viewModel.uploadResult == nil)
        #expect(viewModel.processedPreviewData != nil)
    }

    @MainActor
    @Test func imageEditorStartsWithBackgroundAndEditableLayer() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        #expect(viewModel.document.canvasSize == image.size)
        #expect(viewModel.document.layers.count == 2)
        #expect(viewModel.document.layers.first?.name == L10n.text("imageEditor.layer.background"))
        #expect(viewModel.document.layers.first?.isLocked == true)
        #expect(viewModel.document.selectedLayer?.name == L10n.text("imageEditor.layer.edit"))
        #expect(viewModel.currentImage.size == image.size)
    }

    @MainActor
    @Test func imageEditorBrushChangesSelectedLayerOnly() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let backgroundBefore = try #require(viewModel.document.layers.first?.image.qingtuPNGData())
        let editBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 12
        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 38, y: 38), CGPoint(x: 70, y: 52)])

        let backgroundAfter = try #require(viewModel.document.layers.first?.image.qingtuPNGData())
        let editAfter = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        #expect(backgroundAfter == backgroundBefore)
        #expect(editAfter != editBefore)
        #expect(viewModel.canUndo)
    }

    @MainActor
    @Test func imageEditorLayerControlsSelectDuplicateMergeAndUndo() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let originalLayerCount = viewModel.document.layers.count

        viewModel.addLayer()
        let addedLayerID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.document.layers.count == originalLayerCount + 1)

        viewModel.setSelectedLayerOpacity(0.45)
        #expect(viewModel.selectedLayerOpacity == 0.45)

        viewModel.duplicateSelectedLayer()
        #expect(viewModel.document.layers.count == originalLayerCount + 2)
        #expect(viewModel.document.selectedLayerID != addedLayerID)

        viewModel.mergeSelectedLayerDown()
        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(viewModel.document.selectedLayer?.frame.size == image.size)

        viewModel.undo()
        #expect(viewModel.document.layers.count == originalLayerCount + 2)
        #expect(viewModel.canRedo)
    }

    @MainActor
    @Test func imageEditorLayerRenameTrimsRejectsEmptyNamesAndUndoRestores() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let originalName = try #require(viewModel.document.selectedLayer?.name)

        viewModel.renameSelectedLayer(to: "  Retouch Highlights  ")
        #expect(viewModel.document.selectedLayer?.name == "Retouch Highlights")
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRename"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerRenamed"))

        viewModel.renameSelectedLayer(to: "   ")
        #expect(viewModel.document.selectedLayer?.name == "Retouch Highlights")
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerNameInvalid"))

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.name == originalName)
    }

    @MainActor
    @Test func imageEditorSelectedLayersMoveToStackEdgesPreservesOrderAndUndo() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let thirdID = try #require(viewModel.document.selectedLayerID)
        let originalOrder = viewModel.document.layers.map(\.id)

        viewModel.selectLayer(firstID, editingMask: false)
        viewModel.selectLayer(secondID, editingMask: false, extendingSelection: true)

        #expect(viewModel.canMoveSelectedLayerToTop)
        viewModel.moveSelectedLayerToTop()
        #expect(viewModel.document.layers.suffix(2).map(\.id) == [firstID, secondID])
        #expect(viewModel.document.selectedLayerID == secondID)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMoveToTop"))

        viewModel.moveSelectedLayerToBottom()
        #expect(viewModel.document.layers.prefix(2).map(\.id) == [firstID, secondID])
        #expect(viewModel.document.layers.contains { $0.id == thirdID })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMoveToBottom"))

        viewModel.undo()
        #expect(viewModel.document.layers.suffix(2).map(\.id) == [firstID, secondID])
        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalOrder)
    }

    @MainActor
    @Test func imageEditorImportImageCreatesCenteredScaledLayerAndUndoRestores() async throws {
        let canvas = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let imported = testImage(color: .systemPink, size: NSSize(width: 160, height: 120))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: canvas) { _ in }
        let originalLayerCount = viewModel.document.layers.count

        viewModel.importImageLayer(imported, sourceName: "  poster.large.png  ")

        let importedLayer = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(importedLayer.name == L10n.format("imageEditor.layer.importedName", "poster.large"))
        #expect(importedLayer.image.size == imported.size)
        #expect(importedLayer.frame == CGRect(x: 0, y: 0, width: 80, height: 60))
        #expect(importedLayer.opacity == 1)
        #expect(importedLayer.blendMode == .normal)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerImport"))

        viewModel.undo()
        #expect(viewModel.document.layers.count == originalLayerCount)
    }

    @MainActor
    @Test func imageEditorRasterizeTextLayerBakesStyleAndUndoRestoresEditableText() async throws {
        let canvasSize = NSSize(width: 120, height: 80)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.textValue = "Raster"
        viewModel.textSize = 28
        viewModel.foregroundColor = .white
        viewModel.addText(at: CGPoint(x: 18, y: 24))
        viewModel.toggleSelectedLayerStroke()

        let textLayer = try #require(viewModel.document.selectedLayer)
        let textFrame = textLayer.frame
        let expectedRasterFrame = textLayer.compositingFrame
        let compositedBeforeRasterize = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.canRasterizeSelectedLayer)
        viewModel.rasterizeSelectedLayer()

        let rasterizedLayer = try #require(viewModel.document.selectedLayer)
        #expect(!rasterizedLayer.isText)
        #expect(rasterizedLayer.mask == nil)
        #expect(!rasterizedLayer.hasLayerEffects)
        #expect(!rasterizedLayer.isAdjustment)
        #expect(!rasterizedLayer.isFilter)
        #expect(rasterizedLayer.frame == expectedRasterFrame)
        #expect(rasterizedLayer.frame.width >= textFrame.width)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRasterize"))
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeRasterize)

        viewModel.undo()
        let restoredTextLayer = try #require(viewModel.document.selectedLayer)
        #expect(restoredTextLayer.isText)
        #expect(restoredTextLayer.hasLayerEffects)
    }

    @MainActor
    @Test func imageEditorSelectionConstrainsBrushEdits() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 24, y: 24))
        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 14
        viewModel.drawBrush(points: [CGPoint(x: 6, y: 6), CGPoint(x: 74, y: 54)])

        let editedLayer = try #require(viewModel.document.selectedLayer)
        let inside = try #require(editedLayer.image.color(at: CGPoint(x: 10, y: 9)))
        let outside = try #require(editedLayer.image.color(at: CGPoint(x: 72, y: 52)))

        #expect(inside.alphaComponent > 0.2)
        #expect(outside.alphaComponent < 0.05)
    }

    @MainActor
    @Test func imageEditorSelectionInvertAndFeatherConstrainEdits() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let black = NSColor(calibratedWhite: 0, alpha: 1)
        let white = NSColor(calibratedWhite: 1, alpha: 1)
        let image = testImage(color: black, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.replaceSelectedLayerImageForTesting(
            testImage(color: black, size: canvasSize),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(from: CGPoint(x: 20, y: 10), to: CGPoint(x: 60, y: 50))
        viewModel.invertSelection()
        #expect(viewModel.document.selection?.isInverted == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionInverted"))

        viewModel.foregroundColor = white
        viewModel.brushSize = 80
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 30), CGPoint(x: 80, y: 30)])
        let invertedOutside = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        let invertedInside = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(invertedOutside.redComponent > 0.8)
        #expect(invertedInside.redComponent < 0.1)

        viewModel.clearSelection()
        viewModel.replaceSelectedLayerImageForTesting(
            testImage(color: black, size: canvasSize),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(from: CGPoint(x: 20, y: 10), to: CGPoint(x: 60, y: 50))
        viewModel.feather = 10
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 30), CGPoint(x: 80, y: 30)])
        let featherOutside = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 5, y: 30))?.usingColorSpace(.deviceRGB))
        let featherEdge = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 30))?.usingColorSpace(.deviceRGB))
        let featherInside = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(featherInside.redComponent > 0.8)
        #expect(featherEdge.redComponent > featherOutside.redComponent + 0.15)
        #expect(featherEdge.redComponent < featherInside.redComponent - 0.15)
    }

    @MainActor
    @Test func imageEditorLoadsRasterSelectionFromLayerTransparency() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let transparent = NSColor(calibratedWhite: 0, alpha: 0)
        let alphaShape = testBitmapImage(
            size: canvasSize,
            background: transparent,
            fills: [
                (CGRect(x: 6, y: 6, width: 12, height: 12), .white),
                (CGRect(x: 62, y: 42, width: 12, height: 12), .white)
            ]
        )
        viewModel.replaceSelectedLayerImageForTesting(
            alphaShape,
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        #expect(viewModel.canLoadSelectionFromLayerTransparency)
        viewModel.loadSelectionFromLayerTransparency()

        let selection = try #require(viewModel.document.selection)
        #expect(selection.rasterMask != nil)
        #expect(selection.bounds.minX <= 6)
        #expect(selection.bounds.maxX >= 74)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromLayer"))

        viewModel.addLayer()
        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 90
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 30), CGPoint(x: 80, y: 30)])

        let paintedLayer = try #require(viewModel.document.selectedLayer)
        let selectedA = try #require(paintedLayer.image.color(at: CGPoint(x: 10, y: 10)))
        let selectedB = try #require(paintedLayer.image.color(at: CGPoint(x: 68, y: 48)))
        let middleOfBounds = try #require(paintedLayer.image.color(at: CGPoint(x: 40, y: 30)))

        #expect(selectedA.alphaComponent > 0.2)
        #expect(selectedB.alphaComponent > 0.2)
        #expect(middleOfBounds.alphaComponent < 0.05)
    }

    @MainActor
    @Test func imageEditorSavesRestoresAndUndoesSelection() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 8, y: 8), to: CGPoint(x: 28, y: 30))
        let saved = try #require(viewModel.document.selection)
        viewModel.saveCurrentSelection()
        #expect(viewModel.hasSavedSelection)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionSaved"))

        viewModel.clearSelection()
        #expect(viewModel.document.selection == nil)

        viewModel.restoreSavedSelection()
        #expect(viewModel.document.selection == saved)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionRestored"))

        viewModel.undo()
        #expect(viewModel.document.selection == nil)
        #expect(viewModel.hasSavedSelection)
    }

    @MainActor
    @Test func imageEditorFillsStrokesAndCopiesSelectionToNewLayer() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 20, y: 12), to: CGPoint(x: 60, y: 48))
        viewModel.foregroundColor = .systemPink
        viewModel.opacity = 1

        #expect(viewModel.canEditSelectionPixels)
        viewModel.fillSelection()

        let filledLayer = try #require(viewModel.document.selectedLayer)
        let filledInside = try #require(filledLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let filledOutside = try #require(filledLayer.image.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(filledInside.redComponent > 0.8)
        #expect(filledInside.alphaComponent > 0.8)
        #expect(filledOutside.alphaComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFill"))

        viewModel.clearSelection()
        viewModel.replaceSelectedLayerImageForTesting(
            NSImage.transparent(size: canvasSize),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(from: CGPoint(x: 20, y: 12), to: CGPoint(x: 60, y: 48))
        viewModel.brushSize = 6
        viewModel.strokeSelection()

        let strokedLayer = try #require(viewModel.document.selectedLayer)
        let strokeEdge = try #require(strokedLayer.image.color(at: CGPoint(x: 20, y: 30))?.usingColorSpace(.deviceRGB))
        let strokeCenter = try #require(strokedLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let strokeOutside = try #require(strokedLayer.image.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(strokeEdge.redComponent > 0.8)
        #expect(strokeEdge.alphaComponent > 0.8)
        #expect(strokeCenter.alphaComponent < 0.1)
        #expect(strokeOutside.alphaComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionStroke"))

        let sourceLayerID = try #require(viewModel.document.selectedLayer?.id)
        let layerCountBeforeCopy = viewModel.document.layers.count
        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: .systemPink),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.copySelectionToNewLayer()

        let copiedLayer = try #require(viewModel.document.selectedLayer)
        let copiedInside = try #require(copiedLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let copiedOutside = try #require(copiedLayer.image.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == layerCountBeforeCopy + 1)
        #expect(copiedLayer.id != sourceLayerID)
        #expect(copiedInside.redComponent > 0.8)
        #expect(copiedInside.alphaComponent > 0.8)
        #expect(copiedOutside.alphaComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionCopyLayer"))

        viewModel.undo()
        #expect(viewModel.document.layers.count == layerCountBeforeCopy)
    }

    @MainActor
    @Test func imageEditorClearsAndCutsSelectionPixels() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: .systemPink),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(from: CGPoint(x: 20, y: 12), to: CGPoint(x: 60, y: 48))

        #expect(viewModel.canEditSelectionPixels)
        viewModel.clearSelectionPixels()

        let clearedLayer = try #require(viewModel.document.selectedLayer)
        let clearedInside = try #require(clearedLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let clearedOutside = try #require(clearedLayer.image.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(clearedInside.alphaComponent < 0.1)
        #expect(clearedOutside.alphaComponent > 0.8)
        #expect(clearedOutside.redComponent > 0.8)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionClearPixels"))

        viewModel.undo()
        let restoredLayer = try #require(viewModel.document.selectedLayer)
        let restoredInside = try #require(restoredLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(restoredInside.alphaComponent > 0.8)
        #expect(restoredInside.redComponent > 0.8)

        let sourceLayerID = try #require(viewModel.document.selectedLayerID)
        let layerCountBeforeCut = viewModel.document.layers.count
        viewModel.cutSelectionToNewLayer()

        let cutLayer = try #require(viewModel.document.selectedLayer)
        let sourceLayer = try #require(viewModel.document.layers.first { $0.id == sourceLayerID })
        let cutInside = try #require(cutLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let cutOutside = try #require(cutLayer.image.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        let sourceInside = try #require(sourceLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let sourceOutside = try #require(sourceLayer.image.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == layerCountBeforeCut + 1)
        #expect(cutLayer.id != sourceLayerID)
        #expect(cutInside.alphaComponent > 0.8)
        #expect(cutInside.redComponent > 0.8)
        #expect(cutOutside.alphaComponent < 0.1)
        #expect(sourceInside.alphaComponent < 0.1)
        #expect(sourceOutside.alphaComponent > 0.8)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionCutLayer"))

        viewModel.undo()
        #expect(viewModel.document.layers.count == layerCountBeforeCut)
        #expect(viewModel.document.selectedLayerID == sourceLayerID)
    }

    @MainActor
    @Test func imageEditorBlendModeChangesCompositedOutput() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 90
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 0), CGPoint(x: 80, y: 60)])
        let normalData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.setSelectedLayerBlendMode(.multiply)
        let multipliedData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.selectedLayerBlendMode == .multiply)
        #expect(multipliedData != normalData)
    }

    @MainActor
    @Test func imageEditorLockedLayerRejectsEditsUntilUnlocked() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let selectedID = try #require(viewModel.document.selectedLayerID)
        let before = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.toggleLayerLock(selectedID)
        viewModel.foregroundColor = .systemPink
        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 70, y: 50)])
        let lockedAfter = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.toggleLayerLock(selectedID)
        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 70, y: 50)])
        let unlockedAfter = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        #expect(lockedAfter == before)
        #expect(unlockedAfter != before)
    }

    @MainActor
    @Test func imageEditorStampVisibleCreatesMergedPixelLayerAndUndoRestoresStack() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 48
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 0), CGPoint(x: 80, y: 60)])

        viewModel.addLayer()
        let hiddenLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.foregroundColor = .systemGreen
        viewModel.brushSize = 80
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 30), CGPoint(x: 80, y: 30)])
        viewModel.toggleLayerVisibility(hiddenLayerID)

        let layerCountBeforeStamp = viewModel.document.layers.count
        let compositedBeforeStamp = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.stampVisibleLayers()

        let stampLayer = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.count == layerCountBeforeStamp + 1)
        #expect(stampLayer.name == L10n.text("imageEditor.layer.visibleStampName"))
        #expect(stampLayer.image.qingtuPNGData() == compositedBeforeStamp)
        #expect(viewModel.document.layers.contains { $0.id == hiddenLayerID && !$0.isVisible })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStampVisible"))

        viewModel.undo()
        #expect(viewModel.document.layers.count == layerCountBeforeStamp)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeStamp)
    }

    @MainActor
    @Test func imageEditorMergeVisibleKeepsHiddenLayersAndUndoRestoresStack() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 44
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 0), CGPoint(x: 80, y: 60)])

        viewModel.addLayer()
        let hiddenLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.foregroundColor = .systemGreen
        viewModel.brushSize = 60
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 30), CGPoint(x: 80, y: 30)])
        viewModel.toggleLayerVisibility(hiddenLayerID)

        viewModel.addLayer()
        viewModel.foregroundColor = .systemYellow
        viewModel.brushSize = 32
        viewModel.drawBrush(points: [CGPoint(x: 10, y: 10), CGPoint(x: 70, y: 50)])

        let layerCountBeforeMerge = viewModel.document.layers.count
        let compositedBeforeMerge = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.canMergeVisibleLayers)
        viewModel.mergeVisibleLayers()

        let mergedLayer = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.count == 2)
        #expect(layerCountBeforeMerge == 4)
        #expect(mergedLayer.name == L10n.text("imageEditor.layer.visibleMergedName"))
        #expect(mergedLayer.image.qingtuPNGData() == compositedBeforeMerge)
        #expect(viewModel.document.layers.contains { $0.id == hiddenLayerID && !$0.isVisible })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeVisible"))
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeMerge)

        viewModel.undo()
        #expect(viewModel.document.layers.count == layerCountBeforeMerge)
        #expect(viewModel.document.layers.contains { $0.id == hiddenLayerID && !$0.isVisible })
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeMerge)
    }

    @MainActor
    @Test func imageEditorFlattenImageDiscardsHiddenLayersAndUndoRestoresStack() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let hiddenLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.foregroundColor = .systemGreen
        viewModel.brushSize = 60
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 30), CGPoint(x: 80, y: 30)])
        viewModel.toggleLayerVisibility(hiddenLayerID)

        viewModel.addLayer()
        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 40
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 0), CGPoint(x: 80, y: 60)])

        let layerCountBeforeFlatten = viewModel.document.layers.count
        let compositedBeforeFlatten = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.canFlattenImage)
        viewModel.flattenImage()

        let flattenedLayer = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.count == 1)
        #expect(layerCountBeforeFlatten == 4)
        #expect(flattenedLayer.name == L10n.text("imageEditor.layer.flattenedName"))
        #expect(!flattenedLayer.isGroup)
        #expect(!flattenedLayer.isAdjustment)
        #expect(!flattenedLayer.isFilter)
        #expect(!flattenedLayer.isText)
        #expect(flattenedLayer.mask == nil)
        #expect(!flattenedLayer.hasLayerEffects)
        #expect(!viewModel.document.layers.contains { $0.id == hiddenLayerID })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFlatten"))
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeFlatten)

        viewModel.undo()
        #expect(viewModel.document.layers.count == layerCountBeforeFlatten)
        #expect(viewModel.document.layers.contains { $0.id == hiddenLayerID && !$0.isVisible })
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeFlatten)
    }

    @MainActor
    @Test func imageEditorLayerMaskHidesAndRestoresCompositedPixels() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 90
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 0), CGPoint(x: 80, y: 60)])
        let paintedData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.addLayerMask()
        #expect(viewModel.selectedLayerHasMask)
        #expect(viewModel.isEditingLayerMask)

        viewModel.brushSize = 40
        viewModel.drawBrush(points: [CGPoint(x: 20, y: 20), CGPoint(x: 60, y: 40)])
        let hiddenData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.drawBrush(points: [CGPoint(x: 20, y: 20), CGPoint(x: 60, y: 40)], erase: true)
        let restoredData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(hiddenData != paintedData)
        #expect(restoredData != hiddenData)
        #expect(viewModel.document.selectedLayer?.mask != nil)
    }

    @MainActor
    @Test func imageEditorCreatesInvertsAndAppliesLayerMaskFromSelection() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 90
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 30), CGPoint(x: 80, y: 30)])
        viewModel.createRectSelection(from: CGPoint(x: 20, y: 12), to: CGPoint(x: 60, y: 48))

        #expect(viewModel.canCreateLayerMaskFromSelection)
        viewModel.addLayerMaskFromSelection()

        let maskedLayer = try #require(viewModel.document.selectedLayer)
        let insideMasked = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let outsideMasked = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(maskedLayer.mask != nil)
        #expect(viewModel.isEditingLayerMask)
        #expect(insideMasked.redComponent > outsideMasked.redComponent + 0.25)
        #expect(outsideMasked.blueComponent > insideMasked.blueComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskFromSelection"))

        viewModel.invertLayerMask()
        let insideInverted = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let outsideInverted = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(insideInverted.blueComponent > outsideInverted.blueComponent + 0.25)
        #expect(outsideInverted.redComponent > insideInverted.redComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskInvert"))

        let compositedBeforeApply = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(viewModel.canApplyLayerMask)
        viewModel.applyLayerMask()

        let appliedLayer = try #require(viewModel.document.selectedLayer)
        #expect(appliedLayer.mask == nil)
        #expect(!viewModel.isEditingLayerMask)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskApply"))
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeApply)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.mask != nil)
    }

    @MainActor
    @Test func imageEditorMoveToolTranslatesSelectedLayerFrameAndUndoRestoresIt() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let originalFrame = try #require(viewModel.document.selectedLayer?.frame)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 12, height: 7))
        viewModel.finishMovingSelectedLayer()

        let movedFrame = try #require(viewModel.document.selectedLayer?.frame)
        #expect(movedFrame.origin.x == originalFrame.origin.x + 12)
        #expect(movedFrame.origin.y == originalFrame.origin.y + 7)
        #expect(viewModel.canUndo)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.frame == originalFrame)
    }

    @MainActor
    @Test func imageEditorHistoryPanelRestoresSnapshotAndUndoReturnsToLaterState() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let openHistoryID = try #require(viewModel.document.history.first?.id)
        let originalData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 20
        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 70, y: 50)])
        let paintedData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.restoreHistoryEntry(openHistoryID)
        let restoredData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(paintedData != originalData)
        #expect(restoredData == originalData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.revert"))

        viewModel.undo()
        let undoData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(undoData == paintedData)
    }

    @MainActor
    @Test func imageEditorLayerFreeTransformScalesRotatesMaskAndUndoRestores() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let originalFrame = try #require(viewModel.document.selectedLayer?.frame)

        viewModel.addLayerMask()
        viewModel.scaleSelectedLayer(by: 0.5)
        let scaledFrame = try #require(viewModel.document.selectedLayer?.frame)
        #expect(scaledFrame.width == originalFrame.width * 0.5)
        #expect(scaledFrame.height == originalFrame.height * 0.5)
        #expect(scaledFrame.midX == originalFrame.midX)
        #expect(scaledFrame.midY == originalFrame.midY)

        viewModel.rotateSelectedLayer(degrees: 15)
        let rotatedLayer = try #require(viewModel.document.selectedLayer)
        #expect(rotatedLayer.image.size.width > image.size.width)
        #expect(rotatedLayer.image.size.height > image.size.height)
        #expect(rotatedLayer.mask?.size == rotatedLayer.image.size)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.frame == scaledFrame)
    }

    @MainActor
    @Test func imageEditorLayerStylesAreNonDestructiveUntilMergeDown() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 24
        viewModel.drawBrush(points: [CGPoint(x: 18, y: 18), CGPoint(x: 54, y: 42)])
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedBeforeStyle = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.toggleSelectedLayerStroke()
        viewModel.toggleSelectedLayerShadow()
        let layerPixelsAfterStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedWithStyle = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(compositedWithStyle != compositedBeforeStyle)
        #expect(viewModel.selectedLayerHasStroke)
        #expect(viewModel.selectedLayerHasShadow)

        let layerCountBeforeMerge = viewModel.document.layers.count
        viewModel.mergeSelectedLayerDown()
        let mergedLayer = try #require(viewModel.document.selectedLayer)

        #expect(viewModel.document.layers.count == layerCountBeforeMerge - 1)
        #expect(!mergedLayer.hasLayerEffects)
        #expect(mergedLayer.image.size == image.size)
        let mergedCompositeData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(!mergedCompositeData.isEmpty)
    }

    @MainActor
    @Test func imageEditorLayerStyleParametersUpdateHistoryAndRespectLock() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let selectedID = try #require(viewModel.document.selectedLayerID)

        viewModel.setSelectedLayerStrokeWidth(9)
        viewModel.setSelectedLayerShadowOpacity(0.7)
        viewModel.setSelectedLayerShadowBlur(14)
        viewModel.setSelectedLayerShadowOffsetX(11)
        viewModel.setSelectedLayerShadowOffsetY(-12)
        let styledLayer = try #require(viewModel.document.selectedLayer)

        #expect(styledLayer.style.strokeEnabled)
        #expect(styledLayer.style.shadowEnabled)
        #expect(styledLayer.style.strokeWidth == 9)
        #expect(styledLayer.style.shadowOpacity == 0.7)
        #expect(styledLayer.style.shadowBlur == 14)
        #expect(styledLayer.style.shadowOffset == CGSize(width: 11, height: -12))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        viewModel.toggleLayerLock(selectedID)
        viewModel.setSelectedLayerStrokeWidth(18)

        #expect(viewModel.document.selectedLayer?.style.strokeWidth == 9)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerLocked"))
    }

    @MainActor
    @Test func imageEditorLayerGroupControlsChildVisibilityOpacityLockAndDelete() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let childID = try #require(viewModel.document.selectedLayerID)
        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 28
        viewModel.drawBrush(points: [CGPoint(x: 12, y: 12), CGPoint(x: 64, y: 44)])
        let paintedData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.groupSelectedLayer()
        let groupLayer = try #require(viewModel.document.selectedLayer)
        #expect(groupLayer.isGroup)
        #expect(viewModel.document.layers.first { $0.id == childID }?.groupID == groupLayer.id)

        viewModel.setSelectedLayerOpacity(0)
        let transparentGroupData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(transparentGroupData != paintedData)

        viewModel.setSelectedLayerOpacity(1)
        viewModel.toggleLayerVisibility(groupLayer.id)
        let hiddenGroupData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(hiddenGroupData == transparentGroupData)

        viewModel.toggleLayerVisibility(groupLayer.id)
        viewModel.toggleLayerLock(groupLayer.id)
        viewModel.selectLayer(childID)
        let childPixelsBeforeLockedBrush = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.drawBrush(points: [CGPoint(x: 2, y: 2), CGPoint(x: 78, y: 58)])
        let childPixelsAfterLockedBrush = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        #expect(childPixelsAfterLockedBrush == childPixelsBeforeLockedBrush)

        viewModel.selectLayer(groupLayer.id)
        viewModel.toggleLayerLock(groupLayer.id)
        let countBeforeDelete = viewModel.document.layers.count
        viewModel.deleteSelectedLayer()

        #expect(viewModel.document.layers.count == countBeforeDelete - 2)
        #expect(viewModel.document.layers.contains { $0.id == groupLayer.id } == false)
        #expect(viewModel.document.layers.contains { $0.id == childID } == false)
    }

    @MainActor
    @Test func imageEditorMultiSelectGroupsDeletesAndRestoresLayerSelection() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let spareID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)

        #expect(viewModel.selectedLayerCount == 2)
        #expect(viewModel.isLayerSelected(firstID))
        #expect(viewModel.isLayerSelected(secondID))
        #expect(viewModel.canGroupSelectedLayer)

        viewModel.groupSelectedLayer()
        let groupLayer = try #require(viewModel.document.selectedLayer)
        #expect(groupLayer.isGroup)
        #expect(viewModel.document.layers.first { $0.id == firstID }?.groupID == groupLayer.id)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.groupID == groupLayer.id)
        #expect(viewModel.selectedLayerCount == 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGroupSelected"))

        viewModel.undo()
        #expect(viewModel.document.layers.contains { $0.id == groupLayer.id } == false)
        #expect(viewModel.selectedLayerCount == 2)
        #expect(viewModel.isLayerSelected(firstID))
        #expect(viewModel.isLayerSelected(secondID))

        let countBeforeDelete = viewModel.document.layers.count
        viewModel.deleteSelectedLayer()
        #expect(viewModel.document.layers.count == countBeforeDelete - 2)
        #expect(viewModel.document.layers.contains { $0.id == firstID } == false)
        #expect(viewModel.document.layers.contains { $0.id == secondID } == false)
        #expect(viewModel.document.layers.contains { $0.id == spareID })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDelete"))

        viewModel.undo()
        #expect(viewModel.document.layers.contains { $0.id == firstID })
        #expect(viewModel.document.layers.contains { $0.id == secondID })
        #expect(viewModel.selectedLayerCount == 2)
    }

    @MainActor
    @Test func imageEditorMultiSelectTransformsLayersTogether() async throws {
        let canvasSize = NSSize(width: 160, height: 120)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.textValue = "One"
        viewModel.textSize = 18
        viewModel.foregroundColor = .white
        viewModel.addText(at: CGPoint(x: 18, y: 22))
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstFrame = try #require(viewModel.document.selectedLayer?.frame.standardized)
        let firstImageSize = try #require(viewModel.document.selectedLayer?.image.size)

        viewModel.textValue = "Two"
        viewModel.addText(at: CGPoint(x: 92, y: 58))
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondFrame = try #require(viewModel.document.selectedLayer?.frame.standardized)
        let secondImageSize = try #require(viewModel.document.selectedLayer?.image.size)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        let originalBounds = firstFrame.union(secondFrame)
        #expect(viewModel.selectedLayerCount == 2)
        #expect(viewModel.selectedLayerTransformFrame == originalBounds)
        #expect(viewModel.canResizeSelectedLayer)
        #expect(viewModel.canRotateSelectedLayer)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 10, height: -4))
        viewModel.finishMovingSelectedLayer()
        let movedFirst = try #require(viewModel.document.layers.first { $0.id == firstID }?.frame.standardized)
        let movedSecond = try #require(viewModel.document.layers.first { $0.id == secondID }?.frame.standardized)
        #expect(movedFirst.minX == firstFrame.minX + 10)
        #expect(movedFirst.minY == firstFrame.minY - 4)
        #expect(movedSecond.minX == secondFrame.minX + 10)
        #expect(movedSecond.minY == secondFrame.minY - 4)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))

        viewModel.undo()
        #expect(viewModel.selectedLayerTransformFrame == originalBounds)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: originalBounds.maxX + 32, y: originalBounds.midY),
            handle: .right
        )
        viewModel.finishResizingSelectedLayer()
        let resizedBounds = try #require(viewModel.selectedLayerTransformFrame)
        let resizedFirst = try #require(viewModel.document.layers.first { $0.id == firstID }?.frame.standardized)
        let resizeScale = (originalBounds.width + 32) / originalBounds.width

        #expect(abs(resizedBounds.width - (originalBounds.width + 32)) < 0.01)
        #expect(abs(resizedBounds.height - originalBounds.height) < 0.01)
        #expect(abs(resizedFirst.width - firstFrame.width * resizeScale) < 0.01)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerResize"))

        viewModel.undo()
        #expect(viewModel.selectedLayerTransformFrame == originalBounds)

        let rotationStart = CGPoint(x: originalBounds.midX, y: originalBounds.maxY + 40)
        let dragAngle = CGFloat(104) * .pi / 180
        let dragPoint = CGPoint(
            x: originalBounds.midX + cos(dragAngle) * 40,
            y: originalBounds.midY + sin(dragAngle) * 40
        )
        viewModel.beginRotatingSelectedLayer(from: rotationStart)
        viewModel.rotateSelectedLayer(to: dragPoint, snappingToStep: true)
        viewModel.finishRotatingSelectedLayer()

        let rotatedFirst = try #require(viewModel.document.layers.first { $0.id == firstID }?.frame.standardized)
        let rotatedSecond = try #require(viewModel.document.layers.first { $0.id == secondID }?.frame.standardized)
        #expect(abs(rotatedFirst.midX - firstFrame.midX) > 0.1 || abs(rotatedFirst.midY - firstFrame.midY) > 0.1)
        #expect(abs(rotatedSecond.midX - secondFrame.midX) > 0.1 || abs(rotatedSecond.midY - secondFrame.midY) > 0.1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRotate"))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == firstID }?.frame.standardized == firstFrame)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.frame.standardized == secondFrame)
        #expect(viewModel.document.layers.first { $0.id == firstID }?.image.size == firstImageSize)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.image.size == secondImageSize)
    }

    @MainActor
    @Test func imageEditorAdjustmentLayerIsNonDestructiveAndCanMergeDown() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let gray = NSColor(calibratedRed: 0.36, green: 0.36, blue: 0.36, alpha: 1)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let baseImage = testBitmapImage(size: canvasSize, background: gray)
        viewModel.replaceSelectedLayerImageForTesting(baseImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let before = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))

        viewModel.selectedAdjustment = .brightness
        viewModel.adjustmentValue = 0.35
        viewModel.addAdjustmentLayer()

        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let afterBright = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(adjustmentLayer.isAdjustment)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(afterBright.redComponent > before.redComponent + 0.12)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))

        viewModel.adjustmentValue = -0.25
        viewModel.updateSelectedAdjustmentLayer()
        let afterDark = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(afterDark.redComponent < before.redComponent - 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentUpdate"))

        let countBeforeMerge = viewModel.document.layers.count
        viewModel.mergeSelectedLayerDown()
        let mergedLayer = try #require(viewModel.document.selectedLayer)
        let mergedColor = try #require(mergedLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == countBeforeMerge - 1)
        #expect(!mergedLayer.isAdjustment)
        #expect(mergedColor.redComponent < before.redComponent - 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeDown"))
    }

    @MainActor
    @Test func imageEditorAdjustmentLayerMaskConstrainsEffectAndMergeBakesMask() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let gray = NSColor(calibratedRed: 0.34, green: 0.34, blue: 0.34, alpha: 1)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: gray),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let originalCenter = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))

        viewModel.selectedAdjustment = .brightness
        viewModel.adjustmentValue = 0.35
        viewModel.addAdjustmentLayer()
        #expect(viewModel.canAddLayerMask)
        viewModel.addLayerMask()
        #expect(viewModel.selectedLayerHasMask)
        #expect(viewModel.isEditingLayerMask)

        viewModel.brushSize = 28
        viewModel.drawBrush(points: [CGPoint(x: 30, y: 30), CGPoint(x: 50, y: 30)])

        let hiddenCenter = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let adjustedCorner = try #require(viewModel.currentImage.color(at: CGPoint(x: 70, y: 50))?.usingColorSpace(.deviceRGB))
        #expect(hiddenCenter.redComponent < originalCenter.redComponent + 0.08)
        #expect(adjustedCorner.redComponent > originalCenter.redComponent + 0.12)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskHide"))

        let countBeforeMerge = viewModel.document.layers.count
        viewModel.mergeSelectedLayerDown()
        let mergedLayer = try #require(viewModel.document.selectedLayer)
        let mergedHidden = try #require(mergedLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let mergedAdjusted = try #require(mergedLayer.image.color(at: CGPoint(x: 70, y: 50))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == countBeforeMerge - 1)
        #expect(mergedLayer.mask == nil)
        #expect(mergedHidden.redComponent < originalCenter.redComponent + 0.08)
        #expect(mergedAdjusted.redComponent > originalCenter.redComponent + 0.12)
    }

    @MainActor
    @Test func imageEditorFilterLayerIsNonDestructiveAndCanMergeDown() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let black = NSColor(calibratedWhite: 0, alpha: 1)
        let white = NSColor(calibratedWhite: 1, alpha: 1)
        let image = NSImage.rendered(size: canvasSize) { rect in
            black.setFill()
            rect.fill()
        } ?? testImage(color: black, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let edgeImage = NSImage.rendered(size: canvasSize) { rect in
            black.setFill()
            rect.fill()
            white.setFill()
            CGRect(x: 40, y: 0, width: 40, height: 60).fill()
        } ?? image
        viewModel.replaceSelectedLayerImageForTesting(edgeImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let beforeBlackSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 39, y: 30))?.usingColorSpace(.deviceRGB))
        let beforeWhiteSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 41, y: 30))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.9
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let afterBlackSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 39, y: 30))?.usingColorSpace(.deviceRGB))
        let afterWhiteSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 41, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(viewModel.canAddLayerMask)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(afterBlackSide.redComponent > beforeBlackSide.redComponent + 0.08)
        #expect(afterWhiteSide.redComponent < beforeWhiteSide.redComponent - 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        viewModel.filterIntensity = 0.35
        viewModel.updateSelectedFilterLayer()
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterUpdate"))

        let countBeforeMerge = viewModel.document.layers.count
        viewModel.mergeSelectedLayerDown()
        let mergedLayer = try #require(viewModel.document.selectedLayer)
        let mergedBlackSide = try #require(mergedLayer.image.color(at: CGPoint(x: 39, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == countBeforeMerge - 1)
        #expect(!mergedLayer.isFilter)
        #expect(mergedBlackSide.redComponent > beforeBlackSide.redComponent + 0.02)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeDown"))
    }

    @MainActor
    @Test func imageEditorClippingMaskClipsUpperLayerToLowerAlpha() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let blue = NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.94, alpha: 1)
        let pink = NSColor(calibratedRed: 0.95, green: 0.05, blue: 0.52, alpha: 1)
        let green = NSColor(calibratedRed: 0.04, green: 0.88, blue: 0.12, alpha: 1)
        let image = testBitmapImage(size: canvasSize, background: blue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let baseImage = testBitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [(CGRect(x: 24, y: 18, width: 32, height: 24), pink)]
        )
        viewModel.replaceSelectedLayerImageForTesting(baseImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.addLayer()
        let topImage = testBitmapImage(size: canvasSize, background: green)
        viewModel.replaceSelectedLayerImageForTesting(topImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let unclippedData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.canToggleSelectedLayerClippingMask)
        viewModel.toggleSelectedLayerClippingMask()
        let clippedData = try #require(viewModel.currentImage.qingtuPNGData())
        let outsideColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8)))
        let insideColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 31)))
        let outside = try #require(outsideColor.usingColorSpace(.deviceRGB))
        let inside = try #require(insideColor.usingColorSpace(.deviceRGB))

        #expect(clippedData != unclippedData)
        #expect(viewModel.selectedLayerIsClippingMask)
        #expect(outside.blueComponent > outside.greenComponent + 0.15)
        #expect(inside.greenComponent > inside.blueComponent + 0.15)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerClippingMask"))
    }

    @MainActor
    @Test func imageEditorClippingMaskChainSharesBaseAndMergeBakesVisualPixels() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let blue = NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.94, alpha: 1)
        let pink = NSColor(calibratedRed: 0.95, green: 0.05, blue: 0.52, alpha: 1)
        let green = NSColor(calibratedRed: 0.04, green: 0.88, blue: 0.12, alpha: 1)
        let yellow = NSColor(calibratedRed: 0.98, green: 0.86, blue: 0.08, alpha: 1)
        let image = testBitmapImage(size: canvasSize, background: blue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let baseImage = testBitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [(CGRect(x: 24, y: 18, width: 32, height: 24), pink)]
        )
        viewModel.replaceSelectedLayerImageForTesting(baseImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseID = try #require(viewModel.document.selectedLayerID)

        viewModel.addLayer()
        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: green),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.toggleSelectedLayerClippingMask()

        viewModel.addLayer()
        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: yellow),
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        #expect(viewModel.canToggleSelectedLayerClippingMask)
        viewModel.toggleSelectedLayerClippingMask()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        #expect(viewModel.document.clippingBase(forLayerAt: selectedIndex)?.id == baseID)

        let beforeMergeCount = viewModel.document.layers.count
        let beforeOutside = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        let beforeInside = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 31))?.usingColorSpace(.deviceRGB))
        #expect(beforeOutside.blueComponent > beforeOutside.greenComponent + 0.15)
        #expect(beforeInside.redComponent > beforeInside.blueComponent + 0.15)
        #expect(beforeInside.greenComponent > beforeInside.blueComponent + 0.15)

        viewModel.mergeSelectedLayerDown()
        let mergedLayer = try #require(viewModel.document.selectedLayer)
        let mergedOutside = try #require(mergedLayer.image.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        let mergedInside = try #require(mergedLayer.image.color(at: CGPoint(x: 40, y: 31))?.usingColorSpace(.deviceRGB))
        let afterOutside = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        let afterInside = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 31))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == beforeMergeCount - 1)
        #expect(!viewModel.selectedLayerIsClippingMask)
        #expect(mergedOutside.alphaComponent < 0.05)
        #expect(mergedInside.redComponent > mergedInside.blueComponent + 0.15)
        #expect(afterOutside.blueComponent > afterOutside.greenComponent + 0.15)
        #expect(afterInside.redComponent > afterInside.blueComponent + 0.15)
        #expect(afterInside.greenComponent > afterInside.blueComponent + 0.15)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeDown"))
    }

    @MainActor
    @Test func imageEditorTextLayerIsEditableAndCanMergeDown() async throws {
        let canvasSize = NSSize(width: 120, height: 80)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let editLayerID = try #require(viewModel.document.selectedLayerID)
        let editPixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedBefore = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.textValue = "Hello"
        viewModel.textSize = 28
        viewModel.foregroundColor = .white
        viewModel.addText(at: CGPoint(x: 16, y: 24))

        let textLayer = try #require(viewModel.document.selectedLayer)
        let textContent = try #require(textLayer.textContent)
        let compositedWithText = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.selectedLayerIsText)
        #expect(textContent.text == "Hello")
        #expect(textContent.fontSize == 28)
        #expect(textLayer.frame.width < canvasSize.width)
        #expect(textLayer.frame.height < canvasSize.height)
        #expect(viewModel.document.layers.first { $0.id == editLayerID }?.image.qingtuPNGData() == editPixelsBefore)
        #expect(compositedWithText != compositedBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTextNew"))

        viewModel.textValue = "World"
        viewModel.textSize = 36
        viewModel.foregroundColor = .systemPink
        viewModel.updateSelectedTextLayer()

        let updatedTextLayer = try #require(viewModel.document.selectedLayer)
        let updatedTextContent = try #require(updatedTextLayer.textContent)
        let compositedWithUpdatedText = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(updatedTextContent.text == "World")
        #expect(updatedTextContent.fontSize == 36)
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

    @MainActor
    @Test func imageEditorDragResizeHandleUpdatesLayerFrameAndUndoRestores() async throws {
        let canvasSize = NSSize(width: 120, height: 80)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.textValue = "Resize"
        viewModel.textSize = 24
        viewModel.foregroundColor = .white
        viewModel.addText(at: CGPoint(x: 18, y: 20))

        let originalFrame = try #require(viewModel.selectedLayerTransformFrame)
        viewModel.beginResizingSelectedLayer(handle: .topRight)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: originalFrame.maxX + 22, y: originalFrame.maxY + 14),
            handle: .topRight
        )
        viewModel.finishResizingSelectedLayer()

        let resizedFrame = try #require(viewModel.selectedLayerTransformFrame)
        #expect(resizedFrame.minX == originalFrame.minX)
        #expect(resizedFrame.minY == originalFrame.minY)
        #expect(resizedFrame.width == originalFrame.width + 22)
        #expect(resizedFrame.height == originalFrame.height + 14)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerResize"))

        viewModel.undo()
        #expect(viewModel.selectedLayerTransformFrame == originalFrame)
    }

    @MainActor
    @Test func imageEditorSideResizeHandlesAndAspectRatioConstraintWork() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.textValue = "Aspect"
        viewModel.textSize = 24
        viewModel.foregroundColor = .white
        viewModel.addText(at: CGPoint(x: 20, y: 22))
        let originalFrame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: originalFrame.maxX + 30, y: originalFrame.midY + 40),
            handle: .right
        )
        viewModel.finishResizingSelectedLayer()
        let sideResizedFrame = try #require(viewModel.selectedLayerTransformFrame)

        #expect(sideResizedFrame.minX == originalFrame.minX)
        #expect(sideResizedFrame.midY == originalFrame.midY)
        #expect(sideResizedFrame.width == originalFrame.width + 30)
        #expect(sideResizedFrame.height == originalFrame.height)

        viewModel.undo()
        #expect(viewModel.selectedLayerTransformFrame == originalFrame)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: originalFrame.maxX + 30, y: originalFrame.midY + 40),
            handle: .right,
            preservingAspectRatio: true
        )
        viewModel.finishResizingSelectedLayer()
        let aspectFrame = try #require(viewModel.selectedLayerTransformFrame)
        let originalAspect = originalFrame.width / originalFrame.height
        let resizedAspect = aspectFrame.width / aspectFrame.height

        #expect(aspectFrame.width == originalFrame.width + 30)
        #expect(abs(resizedAspect - originalAspect) < 0.001)
        #expect(aspectFrame.midY == originalFrame.midY)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerResize"))
    }

    @MainActor
    @Test func imageEditorRotateHandleSnapsAndUndoRestores() async throws {
        let canvasSize = NSSize(width: 120, height: 80)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let originalLayer = try #require(viewModel.document.selectedLayer)
        let originalFrame = try #require(viewModel.selectedLayerTransformFrame)
        let originalImageSize = originalLayer.image.size
        let center = CGPoint(x: originalFrame.midX, y: originalFrame.midY)
        let radius: CGFloat = 60
        let startPoint = CGPoint(x: center.x, y: center.y + radius)
        let snappedAngle = CGFloat(15)
        let dragAngle = CGFloat(104) * .pi / 180
        let dragPoint = CGPoint(
            x: center.x + cos(dragAngle) * radius,
            y: center.y + sin(dragAngle) * radius
        )

        viewModel.beginRotatingSelectedLayer(from: startPoint)
        viewModel.rotateSelectedLayer(to: dragPoint, snappingToStep: true)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerRotated"))
        viewModel.finishRotatingSelectedLayer()

        let rotatedFrame = try #require(viewModel.selectedLayerTransformFrame)
        let radians = snappedAngle * .pi / 180
        let expectedWidth = originalImageSize.width * abs(cos(radians)) + originalImageSize.height * abs(sin(radians))
        let expectedHeight = originalImageSize.width * abs(sin(radians)) + originalImageSize.height * abs(cos(radians))

        #expect(abs(rotatedFrame.width - expectedWidth) < 0.01)
        #expect(abs(rotatedFrame.height - expectedHeight) < 0.01)
        #expect(abs(rotatedFrame.midX - originalFrame.midX) < 0.01)
        #expect(abs(rotatedFrame.midY - originalFrame.midY) < 0.01)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRotate"))

        viewModel.undo()
        #expect(viewModel.selectedLayerTransformFrame == originalFrame)
        #expect(viewModel.document.selectedLayer?.image.size == originalImageSize)
    }

    @MainActor
    @Test func imageEditorExportsCompositeAndCurrentLayerWithFormatSettings() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let editIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[editIndex].image = testBitmapImage(
            size: image.size,
            background: .clear,
            fills: [(CGRect(x: 20, y: 15, width: 20, height: 20), .systemPink)]
        )

        let layerPNGData = try #require(viewModel.exportData(settings: ImageEditorExportSettings(
            format: .png,
            scope: .selectedLayer,
            scale: 2,
            quality: 0.9
        )))
        let layerPNG = try #require(NSImage(data: layerPNGData))
        let inside = try #require(layerPNG.color(at: CGPoint(x: 50, y: 50))?.usingColorSpace(.deviceRGB))
        let outside = try #require(layerPNG.color(at: CGPoint(x: 5, y: 5))?.usingColorSpace(.deviceRGB))

        #expect(layerPNG.size == NSSize(width: 160, height: 120))
        #expect(inside.redComponent > 0.8)
        #expect(outside.alphaComponent < 0.1)

        let jpegData = try #require(viewModel.exportData(settings: ImageEditorExportSettings(
            format: .jpeg,
            scope: .composited,
            scale: 0.5,
            quality: 0.75
        )))
        #expect(Array(jpegData.prefix(2)) == [0xFF, 0xD8])
        let jpegImage = try #require(NSImage(data: jpegData))
        #expect(jpegImage.size == NSSize(width: 40, height: 30))
    }

    private func testImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    private func testBitmapImage(
        size: NSSize,
        background: NSColor,
        fills: [(rect: CGRect, color: NSColor)] = []
    ) -> NSImage {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let representation else { return NSImage(size: size) }

        for y in 0..<height {
            for x in 0..<width {
                let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                let fill = fills.last { item in
                    item.rect.contains(point)
                }
                representation.setColor(fill?.color ?? background, atX: x, y: y)
            }
        }

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        return image
    }

}

private final class InMemoryStorageProfileStore: StorageProfileStoring {
    private var profile = StorageProfile()

    func load() -> StorageProfile {
        profile
    }

    func save(_ profile: StorageProfile) {
        self.profile = profile
    }
}

private final class InMemoryUploadHistoryStore: UploadHistoryStoring {
    private var items: [UploadHistoryItem] = []

    func load() -> [UploadHistoryItem] {
        items
    }

    func append(_ item: UploadHistoryItem, to history: [UploadHistoryItem]) -> [UploadHistoryItem] {
        items = [item] + history
        return items
    }

    func remove(_ item: UploadHistoryItem, from history: [UploadHistoryItem]) -> [UploadHistoryItem] {
        items = history.filter { $0.id != item.id }
        return items
    }

    func clear() {
        items = []
    }
}
