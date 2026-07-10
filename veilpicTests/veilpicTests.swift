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
    @Test func imageEditorConvertsBackgroundAndLayerBothWays() async throws {
        let canvas = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: canvas) { _ in }

        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(backgroundID)
        #expect(viewModel.canConvertBackgroundToLayer)
        viewModel.convertBackgroundToLayer()

        var unlockedBackground = try #require(viewModel.document.layers.first)
        #expect(unlockedBackground.id == backgroundID)
        #expect(unlockedBackground.name == L10n.text("imageEditor.layer.unlockedBackground"))
        #expect(unlockedBackground.isLocked == false)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFromBackground"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerFromBackground"))

        viewModel.undo()
        unlockedBackground = try #require(viewModel.document.layers.first)
        #expect(unlockedBackground.name == L10n.text("imageEditor.layer.background"))
        #expect(unlockedBackground.isLocked)

        viewModel.addLayer()
        let layerID = try #require(viewModel.document.selectedLayerID)
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        viewModel.document.layers[layerIndex].image = testBitmapImage(
            size: NSSize(width: 20, height: 10),
            background: .clear,
            fills: [(rect: CGRect(x: 0, y: 0, width: 10, height: 10), color: .systemRed)]
        )
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 15, width: 20, height: 10)
        viewModel.backgroundColor = .white

        #expect(viewModel.canConvertSelectedLayerToBackground)
        viewModel.convertSelectedLayerToBackground()

        let convertedBackground = try #require(viewModel.document.layers.first)
        #expect(convertedBackground.id == layerID)
        #expect(convertedBackground.name == L10n.text("imageEditor.layer.background"))
        #expect(convertedBackground.isLocked)
        #expect(convertedBackground.frame == CGRect(origin: .zero, size: canvas.size))
        #expect(viewModel.document.selectedLayerID == layerID)
        let filledPixel = try #require(convertedBackground.image.color(at: CGPoint(x: 2, y: 2))?.usingColorSpace(.deviceRGB))
        let redPixel = try #require(convertedBackground.image.color(at: CGPoint(x: 12, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(filledPixel.redComponent > 0.9 && filledPixel.greenComponent > 0.9 && filledPixel.blueComponent > 0.9)
        #expect(redPixel.redComponent > 0.8 && redPixel.greenComponent < 0.3)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.backgroundFromLayer"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.backgroundFromLayer"))
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
    @Test func imageEditorLayerLabelColorsApplyToSelectionUndoAndLayerComps() async throws {
        let image = testImage(color: .systemPurple, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let editID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let detailID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(editID)
        viewModel.selectLayer(detailID, extendingSelection: true)
        #expect(viewModel.canSetSelectedLayerLabelColor)

        viewModel.setSelectedLayersLabelColor(.green)
        #expect(viewModel.document.layers.first { $0.id == editID }?.labelColor == .green)
        #expect(viewModel.document.layers.first { $0.id == detailID }?.labelColor == .green)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerLabelColor"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerLabelColor", ImageEditorLayerLabelColor.green.title))

        viewModel.addLayerComp(named: "Green labels")
        let compID = try #require(viewModel.document.selectedLayerCompID)

        viewModel.setSelectedLayersLabelColor(.red)
        #expect(viewModel.document.layers.first { $0.id == detailID }?.labelColor == .red)

        viewModel.applyLayerComp(compID)
        #expect(viewModel.document.layers.first { $0.id == editID }?.labelColor == .green)
        #expect(viewModel.document.layers.first { $0.id == detailID }?.labelColor == .green)

        viewModel.setSelectedLayersLabelColor(nil)
        #expect(viewModel.document.layers.first { $0.id == editID }?.labelColor == nil)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerLabelColorCleared"))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == editID }?.labelColor == .green)
    }

    @MainActor
    @Test func imageEditorLayerCompMenuCommandsDuplicateNavigateApplyUpdateAndDelete() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let detailID = try #require(viewModel.document.selectedLayerID)

        viewModel.addLayerComp(named: "Visible detail")
        let visibleCompID = try #require(viewModel.document.selectedLayerCompID)

        viewModel.toggleLayerVisibility(detailID)
        viewModel.addLayerComp(named: "Hidden detail")
        let hiddenCompID = try #require(viewModel.document.selectedLayerCompID)

        #expect(viewModel.canSelectPreviousLayerComp)
        #expect(!viewModel.canSelectNextLayerComp)

        viewModel.selectPreviousLayerComp()
        #expect(viewModel.document.selectedLayerCompID == visibleCompID)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerCompSelected", "Visible detail"))

        viewModel.selectNextLayerComp()
        #expect(viewModel.document.selectedLayerCompID == hiddenCompID)

        viewModel.duplicateSelectedLayerComp()
        let duplicatedCompID = try #require(viewModel.document.selectedLayerCompID)
        #expect(viewModel.document.layerComps.count == 3)
        #expect(viewModel.document.layerComps.first { $0.id == duplicatedCompID }?.name == L10n.format("imageEditor.layerComp.copyName", "Hidden detail"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerCompDuplicate"))
        #expect(viewModel.canApplySelectedLayerComp)
        #expect(viewModel.canUpdateSelectedLayerComp)
        #expect(viewModel.canDeleteSelectedLayerComp)

        viewModel.toggleLayerVisibility(detailID)
        #expect(viewModel.document.layers.first { $0.id == detailID }?.isVisible == true)

        viewModel.applySelectedLayerComp()
        #expect(viewModel.document.layers.first { $0.id == detailID }?.isVisible == false)

        viewModel.toggleLayerVisibility(detailID)
        viewModel.updateSelectedLayerComp()
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerCompUpdate"))

        viewModel.toggleLayerVisibility(detailID)
        viewModel.applySelectedLayerComp()
        #expect(viewModel.document.layers.first { $0.id == detailID }?.isVisible == true)

        viewModel.deleteSelectedLayerComp()
        #expect(viewModel.document.layerComps.count == 2)
        #expect(viewModel.document.selectedLayerCompID == hiddenCompID)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerCompDelete"))
    }

    @MainActor
    @Test func imageEditorHistorySnapshotMenuCommandsSelectDuplicateRestoreAndDelete() async throws {
        let image = testImage(color: .systemIndigo, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let detailID = try #require(viewModel.document.selectedLayerID)

        viewModel.createHistorySnapshot()
        let visibleSnapshotID = try #require(viewModel.selectedHistorySnapshotID)
        let visibleSnapshotName = try #require(viewModel.namedHistorySnapshots.first { $0.id == visibleSnapshotID }?.name)
        #expect(viewModel.canRestoreSelectedHistorySnapshot)
        #expect(!viewModel.canSelectPreviousHistorySnapshot)
        #expect(!viewModel.canSelectNextHistorySnapshot)

        viewModel.toggleLayerVisibility(detailID)
        viewModel.createHistorySnapshot()
        let hiddenSnapshotID = try #require(viewModel.selectedHistorySnapshotID)
        let hiddenSnapshotName = try #require(viewModel.namedHistorySnapshots.first { $0.id == hiddenSnapshotID }?.name)
        #expect(viewModel.canSelectPreviousHistorySnapshot)
        #expect(!viewModel.canSelectNextHistorySnapshot)

        viewModel.selectPreviousHistorySnapshot()
        #expect(viewModel.selectedHistorySnapshotID == visibleSnapshotID)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.historySnapshotSelected", visibleSnapshotName))

        viewModel.selectNextHistorySnapshot()
        #expect(viewModel.selectedHistorySnapshotID == hiddenSnapshotID)

        viewModel.duplicateSelectedHistorySnapshot()
        let duplicatedSnapshotID = try #require(viewModel.selectedHistorySnapshotID)
        let duplicatedSnapshotName = L10n.format("imageEditor.history.snapshotCopyName", hiddenSnapshotName)
        #expect(viewModel.namedHistorySnapshots.count == 3)
        #expect(viewModel.namedHistorySnapshots.first { $0.id == duplicatedSnapshotID }?.name == duplicatedSnapshotName)
        #expect(viewModel.canDuplicateSelectedHistorySnapshot)
        #expect(viewModel.canDeleteSelectedHistorySnapshot)

        viewModel.toggleLayerVisibility(detailID)
        #expect(viewModel.document.layers.first { $0.id == detailID }?.isVisible == true)

        viewModel.restoreSelectedHistorySnapshot()
        #expect(viewModel.selectedHistorySnapshotID == duplicatedSnapshotID)
        #expect(viewModel.document.layers.first { $0.id == detailID }?.isVisible == false)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.snapshotRestore"))

        viewModel.deleteSelectedHistorySnapshot()
        #expect(viewModel.namedHistorySnapshots.count == 2)
        #expect(viewModel.selectedHistorySnapshotID == hiddenSnapshotID)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.historySnapshotDeleted", duplicatedSnapshotName))
    }

    @MainActor
    @Test func imageEditorVisibleLayerRowsCanFilterByNameKindLabelStateAndAttribute() async throws {
        let image = testImage(color: .systemTeal, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        var pixelLayer = ImageEditorLayer.blank(name: "Retouch Pixel", size: image.size)
        pixelLayer.labelColor = .blue
        pixelLayer.mask = testImage(color: .white, size: image.size)
        var groupLayer = ImageEditorLayer.group(name: "Assets Group", size: image.size)
        groupLayer.isVisible = false
        groupLayer.isLocked = true
        var textLayer = ImageEditorLayer.text(
            name: "Headline Text",
            origin: CGPoint(x: 8, y: 10),
            content: ImageEditorTextContent(
                text: "Headline",
                color: .white,
                fontSize: 18,
                point: CGPoint(x: 2, y: 2)
            )
        )
        textLayer.labelColor = .green
        textLayer.groupID = groupLayer.id
        var shapeLayer = ImageEditorLayer.shape(
            name: "Badge Shape",
            frame: CGRect(x: 12, y: 12, width: 24, height: 24),
            content: ImageEditorShapeContent(
                kind: .ellipse,
                fillColor: .systemBlue,
                fillOpacity: 1,
                strokeColor: .white,
                strokeWidth: 2,
                strokeOpacity: 1
            )
        )
        shapeLayer.labelColor = .green
        shapeLayer.style.strokeEnabled = true
        let adjustmentLayer = ImageEditorLayer.adjustment(
            name: "Tone Adjustment",
            size: image.size,
            kind: .brightness,
            amount: 0.25
        )
        let filterLayer = ImageEditorLayer.filter(
            name: "Blur Filter",
            size: image.size,
            kind: .gaussianBlur,
            intensity: 0.4
        )
        var clippedFilterLayer = filterLayer
        clippedFilterLayer.isClippingMask = true
        var smartObjectLayer = ImageEditorLayer.smartObject(
            name: "Logo Smart",
            image: image,
            sourceName: "logo.png"
        )
        smartObjectLayer.smartFilters.append(ImageEditorSmartFilter(kind: .sharpen, intensity: 0.35))
        pixelLayer.linkedLayerIDs = [shapeLayer.id]
        shapeLayer.linkedLayerIDs = [pixelLayer.id]

        viewModel.document.layers.append(contentsOf: [
            pixelLayer,
            textLayer,
            shapeLayer,
            adjustmentLayer,
            clippedFilterLayer,
            smartObjectLayer,
            groupLayer
        ])

        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .all, labelFilter: nil, stateFilter: .all).count == viewModel.visibleLayerRows.count)
        #expect(viewModel.visibleLayerRows(matching: "headline", kindFilter: .text, labelFilter: nil, stateFilter: .all).map(\.id) == [textLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "headline", kindFilter: .shape, labelFilter: nil, stateFilter: .all).isEmpty)
        #expect(viewModel.visibleLayerRows(matching: "badge", kindFilter: .shape, labelFilter: nil, stateFilter: .all).map(\.id) == [shapeLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .adjustment, labelFilter: nil, stateFilter: .all).map(\.id) == [adjustmentLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .filter, labelFilter: nil, stateFilter: .all).map(\.id) == [clippedFilterLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .smartObject, labelFilter: nil, stateFilter: .all).map(\.id) == [smartObjectLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .group, labelFilter: nil, stateFilter: .all).map(\.id) == [groupLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "retouch", kindFilter: .pixel, labelFilter: .blue, stateFilter: .visible).map(\.id) == [pixelLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .all, labelFilter: .green, stateFilter: .all).map(\.id) == [shapeLayer.id, textLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "headline", kindFilter: .text, labelFilter: .green, stateFilter: .hidden).map(\.id) == [textLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "headline", kindFilter: .text, labelFilter: .green, stateFilter: .locked).map(\.id) == [textLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "headline", kindFilter: .text, labelFilter: .blue, stateFilter: .all).isEmpty)
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .group, labelFilter: nil, stateFilter: .hidden).map(\.id) == [groupLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .group, labelFilter: nil, stateFilter: .locked).map(\.id) == [groupLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "badge", kindFilter: .shape, labelFilter: .green, stateFilter: .unlocked).map(\.id) == [shapeLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .all, labelFilter: nil, stateFilter: .all, attributeFilter: .masked).map(\.id) == [pixelLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .all, labelFilter: nil, stateFilter: .all, attributeFilter: .styled).map(\.id) == [shapeLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .all, labelFilter: nil, stateFilter: .all, attributeFilter: .clipping).map(\.id) == [clippedFilterLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .all, labelFilter: nil, stateFilter: .all, attributeFilter: .smartFiltered).map(\.id) == [smartObjectLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "", kindFilter: .all, labelFilter: nil, stateFilter: .all, attributeFilter: .linked).map(\.id) == [shapeLayer.id, pixelLayer.id])
        #expect(viewModel.visibleLayerRows(matching: "retouch", kindFilter: .pixel, labelFilter: .blue, stateFilter: .visible, attributeFilter: .masked).map(\.id) == [pixelLayer.id])

        #expect(viewModel.canSelectVisibleLayers)
        viewModel.selectVisibleLayers()
        #expect(viewModel.document.selectedLayerIDs == Set([pixelLayer.id, shapeLayer.id, adjustmentLayer.id, clippedFilterLayer.id, smartObjectLayer.id]))
        #expect(viewModel.document.selectedLayerID == smartObjectLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectVisible", 5))

        #expect(viewModel.canSelectHiddenLayers)
        viewModel.selectHiddenLayers()
        #expect(viewModel.document.selectedLayerIDs == Set([textLayer.id, groupLayer.id]))
        #expect(viewModel.document.selectedLayerID == groupLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectHidden", 2))

        #expect(viewModel.canSelectMaskedLayers)
        viewModel.selectMaskedLayers()
        #expect(viewModel.document.selectedLayerIDs == [pixelLayer.id])
        #expect(viewModel.document.selectedLayerID == pixelLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectMasked", 1))

        #expect(viewModel.canSelectStyledLayers)
        viewModel.selectStyledLayers()
        #expect(viewModel.document.selectedLayerIDs == [shapeLayer.id])
        #expect(viewModel.document.selectedLayerID == shapeLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectStyled", 1))

        #expect(viewModel.canSelectClippingMaskLayers)
        viewModel.selectClippingMaskLayers()
        #expect(viewModel.document.selectedLayerIDs == [clippedFilterLayer.id])
        #expect(viewModel.document.selectedLayerID == clippedFilterLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectClipping", 1))

        #expect(viewModel.canSelectSmartFilteredLayers)
        viewModel.selectSmartFilteredLayers()
        #expect(viewModel.document.selectedLayerIDs == [smartObjectLayer.id])
        #expect(viewModel.document.selectedLayerID == smartObjectLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectSmartFiltered", 1))
    }

    @MainActor
    @Test func imageEditorCanSelectLayersByKindSimilarityBlendModeOrLabelColor() async throws {
        let image = testImage(color: .systemTeal, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        var titleLayer = ImageEditorLayer.text(
            name: "Title",
            origin: CGPoint(x: 8, y: 10),
            content: ImageEditorTextContent(
                text: "Title",
                color: .white,
                fontSize: 18,
                point: CGPoint(x: 2, y: 2)
            )
        )
        titleLayer.labelColor = .green
        titleLayer.blendMode = .multiply
        var subtitleLayer = ImageEditorLayer.text(
            name: "Subtitle",
            origin: CGPoint(x: 22, y: 46),
            content: ImageEditorTextContent(
                text: "Subtitle",
                color: .white,
                fontSize: 14,
                point: CGPoint(x: 2, y: 2)
            )
        )
        subtitleLayer.labelColor = .green
        subtitleLayer.blendMode = .multiply
        var captionLayer = ImageEditorLayer.text(
            name: "Caption",
            origin: CGPoint(x: 16, y: 28),
            content: ImageEditorTextContent(
                text: "Caption",
                color: .white,
                fontSize: 12,
                point: CGPoint(x: 2, y: 2)
            )
        )
        captionLayer.blendMode = .screen
        var shapeLayer = ImageEditorLayer.shape(
            name: "Badge",
            frame: CGRect(x: 12, y: 12, width: 24, height: 24),
            content: ImageEditorShapeContent(
                kind: .ellipse,
                fillColor: .systemBlue,
                fillOpacity: 1,
                strokeColor: .white,
                strokeWidth: 2,
                strokeOpacity: 1
            )
        )
        shapeLayer.labelColor = .green
        shapeLayer.blendMode = .multiply
        viewModel.document.layers.append(contentsOf: [titleLayer, subtitleLayer, captionLayer, shapeLayer])

        viewModel.selectLayer(titleLayer.id)
        #expect(viewModel.canSelectLayersWithSameKind)
        viewModel.selectLayersWithSameKind()
        #expect(viewModel.document.selectedLayerIDs == [titleLayer.id, subtitleLayer.id, captionLayer.id])
        #expect(viewModel.document.selectedLayerID == captionLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectSameKind", 3, ImageEditorLayerKindFilter.text.title))

        viewModel.selectLayer(titleLayer.id)
        #expect(viewModel.canSelectSimilarLayers)
        viewModel.selectSimilarLayers()
        #expect(viewModel.document.selectedLayerIDs == [titleLayer.id, subtitleLayer.id])
        #expect(viewModel.document.selectedLayerID == subtitleLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectSimilar", 2, ImageEditorLayerKindFilter.text.title, ImageEditorBlendMode.multiply.title))

        viewModel.selectLayer(titleLayer.id)
        #expect(viewModel.canSelectLayersWithSameBlendMode)
        viewModel.selectLayersWithSameBlendMode()
        #expect(viewModel.document.selectedLayerIDs == [titleLayer.id, subtitleLayer.id, shapeLayer.id])
        #expect(viewModel.document.selectedLayerID == shapeLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectSameBlendMode", 3, ImageEditorBlendMode.multiply.title))

        viewModel.selectLayer(titleLayer.id)
        #expect(viewModel.canSelectLayersWithSameLabelColor)
        viewModel.selectLayersWithSameLabelColor()
        #expect(viewModel.document.selectedLayerIDs == [titleLayer.id, subtitleLayer.id, shapeLayer.id])
        #expect(viewModel.document.selectedLayerID == shapeLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectSameLabelColor", 3, ImageEditorLayerLabelColor.green.title))

        viewModel.selectLayer(captionLayer.id)
        #expect(!viewModel.canSelectLayersWithSameLabelColor)
    }

    @MainActor
    @Test func imageEditorCanSelectVisibleAndHiddenLayers() async throws {
        let image = testImage(color: .systemIndigo, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let visibleLayer = ImageEditorLayer.blank(name: "Visible", size: image.size)
        var hiddenLayer = ImageEditorLayer.blank(name: "Hidden", size: image.size)
        hiddenLayer.isVisible = false
        var groupLayer = ImageEditorLayer.group(name: "Hidden Group", size: image.size)
        groupLayer.isVisible = false
        var childLayer = ImageEditorLayer.blank(name: "Group Child", size: image.size)
        childLayer.groupID = groupLayer.id
        viewModel.document.layers = [visibleLayer, hiddenLayer, childLayer, groupLayer]
        viewModel.document.selectedLayerID = visibleLayer.id
        viewModel.document.selectedLayerIDs = [visibleLayer.id]

        #expect(viewModel.canSelectVisibleLayers)
        viewModel.selectVisibleLayers()
        #expect(viewModel.document.selectedLayerIDs == [visibleLayer.id])
        #expect(viewModel.document.selectedLayerID == visibleLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectVisible", 1))

        #expect(viewModel.canSelectHiddenLayers)
        viewModel.selectHiddenLayers()
        #expect(viewModel.document.selectedLayerIDs == [hiddenLayer.id, childLayer.id, groupLayer.id])
        #expect(viewModel.document.selectedLayerID == groupLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectHidden", 3))
    }

    @MainActor
    @Test func imageEditorCanSelectLockedAndUnlockedLayers() async throws {
        let image = testImage(color: .systemCyan, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let unlockedLayer = ImageEditorLayer.blank(name: "Unlocked", size: image.size)
        var lockedLayer = ImageEditorLayer.blank(name: "Locked", size: image.size)
        lockedLayer.isLocked = true
        var lockedGroup = ImageEditorLayer.group(name: "Locked Group", size: image.size)
        lockedGroup.isLocked = true
        var childLayer = ImageEditorLayer.blank(name: "Group Child", size: image.size)
        childLayer.groupID = lockedGroup.id
        viewModel.document.layers = [unlockedLayer, lockedLayer, childLayer, lockedGroup]
        viewModel.document.selectedLayerID = unlockedLayer.id
        viewModel.document.selectedLayerIDs = [unlockedLayer.id]

        #expect(viewModel.canSelectLockedLayers)
        viewModel.selectLockedLayers()
        #expect(viewModel.document.selectedLayerIDs == [lockedLayer.id, childLayer.id, lockedGroup.id])
        #expect(viewModel.document.selectedLayerID == lockedGroup.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectLocked", 3))

        #expect(viewModel.canSelectUnlockedLayers)
        viewModel.selectUnlockedLayers()
        #expect(viewModel.document.selectedLayerIDs == [unlockedLayer.id])
        #expect(viewModel.document.selectedLayerID == unlockedLayer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectUnlocked", 1))
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
    @Test func imageEditorLinkedLayersMoveTogetherAndCanBeUnlinked() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 120, height: 90))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        viewModel.document.layers[firstIndex].frame = CGRect(x: 10, y: 12, width: 24, height: 18)

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        viewModel.document.layers[secondIndex].frame = CGRect(x: 52, y: 30, width: 20, height: 16)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        #expect(viewModel.canLinkSelectedLayers)
        viewModel.linkSelectedLayers()
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerLink"))
        #expect(viewModel.isLayerLinked(firstID))
        #expect(viewModel.isLayerLinked(secondID))

        viewModel.selectLayer(firstID)
        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 7, height: -3))
        viewModel.finishMovingSelectedLayer()

        let movedFirstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        let movedSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[movedFirstIndex].frame.origin == CGPoint(x: 17, y: 9))
        #expect(viewModel.document.layers[movedSecondIndex].frame.origin == CGPoint(x: 59, y: 27))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTranslate"))

        viewModel.unlinkSelectedLayers()
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerUnlink"))
        #expect(!viewModel.isLayerLinked(firstID))
        #expect(!viewModel.isLayerLinked(secondID))

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 5, height: 5))
        viewModel.finishMovingSelectedLayer()

        let unlinkedFirstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        let unlinkedSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[unlinkedFirstIndex].frame.origin == CGPoint(x: 22, y: 14))
        #expect(viewModel.document.layers[unlinkedSecondIndex].frame.origin == CGPoint(x: 59, y: 27))
    }

    @MainActor
    @Test func imageEditorLinkedLayersScaleTogetherAndCleanLinksOnCopyDelete() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 140, height: 100))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        viewModel.document.layers[firstIndex].frame = CGRect(x: 10, y: 10, width: 20, height: 10)

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        viewModel.document.layers[secondIndex].frame = CGRect(x: 50, y: 30, width: 10, height: 10)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.linkSelectedLayers()

        viewModel.selectLayer(firstID)
        viewModel.scaleSelectedLayer(by: 2)

        let scaledFirstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        let scaledSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[scaledFirstIndex].frame == CGRect(x: -15, y: -5, width: 40, height: 20))
        #expect(viewModel.document.layers[scaledSecondIndex].frame == CGRect(x: 65, y: 35, width: 20, height: 20))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerScale"))

        viewModel.duplicateSelectedLayer()
        let copiedID = try #require(viewModel.document.selectedLayerID)
        #expect(!viewModel.isLayerLinked(copiedID))
        #expect(viewModel.isLayerLinked(firstID))
        #expect(viewModel.isLayerLinked(secondID))

        viewModel.selectLayer(secondID)
        viewModel.deleteSelectedLayer()
        #expect(!viewModel.document.layers.contains { $0.id == secondID })
        #expect(!viewModel.isLayerLinked(firstID))
        #expect(!viewModel.isLayerLinked(copiedID))
    }

    @MainActor
    @Test func imageEditorFitsAndFillsSelectedLayerToCanvasAndSelection() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let layerID = try #require(viewModel.document.selectedLayerID)

        func setFrame(_ frame: CGRect) throws {
            let index = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
            viewModel.document.layers[index].frame = frame
            viewModel.selectLayer(layerID)
        }

        try setFrame(CGRect(x: 10, y: 10, width: 20, height: 10))
        #expect(viewModel.canFitSelectedLayerToCanvas)
        viewModel.fitSelectedLayerToCanvas()
        #expect(viewModel.document.selectedLayer?.frame == CGRect(x: 0, y: 15, width: 100, height: 50))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFitCanvas"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerFitCanvas"))

        try setFrame(CGRect(x: 10, y: 10, width: 20, height: 10))
        viewModel.fillSelectedLayerToCanvas()
        #expect(viewModel.document.selectedLayer?.frame == CGRect(x: -30, y: 0, width: 160, height: 80))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFillCanvas"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerFillCanvas"))

        viewModel.document.selection = .rectangle(CGRect(x: 20, y: 10, width: 40, height: 40))
        try setFrame(CGRect(x: 10, y: 10, width: 20, height: 10))
        #expect(viewModel.canFitSelectedLayerToSelection)
        viewModel.fitSelectedLayerToSelection()
        #expect(viewModel.document.selectedLayer?.frame == CGRect(x: 20, y: 20, width: 40, height: 20))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFitSelection"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerFitSelection"))

        try setFrame(CGRect(x: 10, y: 10, width: 20, height: 10))
        viewModel.fillSelectedLayerToSelection()
        #expect(viewModel.document.selectedLayer?.frame == CGRect(x: 0, y: 10, width: 80, height: 40))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFillSelection"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerFillSelection"))
    }

    @MainActor
    @Test func imageEditorFlipsSelectedLayerPixelsAndMultiLayerPositions() async throws {
        let canvas = testImage(color: .systemBlue, size: NSSize(width: 120, height: 80))
        let splitImage = NSImage.rendered(size: NSSize(width: 20, height: 10)) { rect in
            NSColor.systemRed.setFill()
            CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
            NSColor.systemGreen.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage(size: NSSize(width: 20, height: 10))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: canvas) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        viewModel.document.layers[firstIndex].image = splitImage
        viewModel.document.layers[firstIndex].frame = CGRect(x: 10, y: 20, width: 20, height: 10)

        #expect(viewModel.canFlipSelectedLayer)
        viewModel.flipSelectedLayerHorizontal()

        var flippedFirstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        let flippedLeft = try #require(viewModel.document.layers[flippedFirstIndex].image.color(at: CGPoint(x: 2, y: 5))?.usingColorSpace(.deviceRGB))
        let flippedRight = try #require(viewModel.document.layers[flippedFirstIndex].image.color(at: CGPoint(x: 18, y: 5))?.usingColorSpace(.deviceRGB))
        #expect(flippedLeft.greenComponent > 0.5)
        #expect(flippedRight.redComponent > 0.8)
        #expect(viewModel.document.layers[flippedFirstIndex].frame == CGRect(x: 10, y: 20, width: 20, height: 10))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFlipHorizontal"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerFlipHorizontal"))

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        viewModel.document.layers[secondIndex].frame = CGRect(x: 70, y: 20, width: 20, height: 10)
        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)

        viewModel.flipSelectedLayerHorizontal()

        flippedFirstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        let flippedSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[flippedFirstIndex].frame == CGRect(x: 70, y: 20, width: 20, height: 10))
        #expect(viewModel.document.layers[flippedSecondIndex].frame == CGRect(x: 10, y: 20, width: 20, height: 10))

        viewModel.flipSelectedLayerVertical()
        flippedFirstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        #expect(viewModel.document.layers[flippedFirstIndex].frame == CGRect(x: 70, y: 20, width: 20, height: 10))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFlipVertical"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerFlipVertical"))
    }

    @MainActor
    @Test func imageEditorRotatesSelectedLayerByRightAnglesFromTransformMenuCommands() async throws {
        let canvas = testImage(color: .systemBlue, size: NSSize(width: 120, height: 80))
        let layerImage = testImage(color: .systemRed, size: NSSize(width: 20, height: 10))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: canvas) { _ in }

        viewModel.addLayer()
        let layerID = try #require(viewModel.document.selectedLayerID)
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        viewModel.document.layers[layerIndex].image = layerImage
        viewModel.document.layers[layerIndex].mask = testImage(color: .white, size: NSSize(width: 20, height: 10))
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 20, width: 20, height: 10)

        #expect(viewModel.canRotateSelectedLayer)
        viewModel.rotateSelectedLayerLeft90()

        var rotatedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        var rotatedLayer = viewModel.document.layers[rotatedIndex]
        #expect(abs(rotatedLayer.image.size.width - 10) < 0.01)
        #expect(abs(rotatedLayer.image.size.height - 20) < 0.01)
        #expect(abs((rotatedLayer.mask?.size.width ?? 0) - 10) < 0.01)
        #expect(abs((rotatedLayer.mask?.size.height ?? 0) - 20) < 0.01)
        #expect(abs(rotatedLayer.frame.midX - 20) < 0.01)
        #expect(abs(rotatedLayer.frame.midY - 25) < 0.01)
        #expect(abs(rotatedLayer.frame.width - 10) < 0.01)
        #expect(abs(rotatedLayer.frame.height - 20) < 0.01)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRotate"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerRotated"))

        viewModel.undo()
        var restoredIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        #expect(viewModel.document.layers[restoredIndex].frame == CGRect(x: 10, y: 20, width: 20, height: 10))

        viewModel.rotateSelectedLayerRight90()
        rotatedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        rotatedLayer = viewModel.document.layers[rotatedIndex]
        #expect(abs(rotatedLayer.frame.midX - 20) < 0.01)
        #expect(abs(rotatedLayer.frame.midY - 25) < 0.01)
        #expect(abs(rotatedLayer.frame.width - 10) < 0.01)
        #expect(abs(rotatedLayer.frame.height - 20) < 0.01)

        viewModel.undo()
        viewModel.rotateSelectedLayer180()
        restoredIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        let halfTurnLayer = viewModel.document.layers[restoredIndex]
        #expect(abs(halfTurnLayer.frame.midX - 20) < 0.01)
        #expect(abs(halfTurnLayer.frame.midY - 25) < 0.01)
        #expect(abs(halfTurnLayer.frame.width - 20) < 0.01)
        #expect(abs(halfTurnLayer.frame.height - 10) < 0.01)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRotate"))
    }

    @MainActor
    @Test func imageEditorTrimsSelectedLayerTransparentPixels() async throws {
        let canvas = testImage(color: .systemBlue, size: NSSize(width: 120, height: 80))
        let transparentImage = testBitmapImage(
            size: NSSize(width: 20, height: 10),
            background: .clear,
            fills: [(rect: CGRect(x: 5, y: 2, width: 10, height: 6), color: .systemRed)]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: canvas) { _ in }

        viewModel.addLayer()
        let layerID = try #require(viewModel.document.selectedLayerID)
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        viewModel.document.layers[layerIndex].image = transparentImage
        viewModel.document.layers[layerIndex].mask = testImage(color: .white, size: NSSize(width: 20, height: 10))
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 20, width: 40, height: 20)

        #expect(viewModel.canTrimSelectedLayerTransparentPixels)
        viewModel.trimSelectedLayerTransparentPixels()

        let trimmedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        let trimmedLayer = viewModel.document.layers[trimmedIndex]
        #expect(trimmedLayer.image.size == NSSize(width: 10, height: 6))
        #expect(trimmedLayer.mask?.size == NSSize(width: 10, height: 6))
        #expect(trimmedLayer.frame == CGRect(x: 20, y: 24, width: 20, height: 12))
        let visiblePixel = try #require(trimmedLayer.image.color(at: CGPoint(x: 5, y: 3))?.usingColorSpace(.deviceRGB))
        #expect(visiblePixel.redComponent > 0.8)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTrimTransparentPixels"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerTrimTransparentPixels"))

        viewModel.undo()
        let restoredIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        #expect(viewModel.document.layers[restoredIndex].image.size == NSSize(width: 20, height: 10))
        #expect(viewModel.document.layers[restoredIndex].frame == CGRect(x: 10, y: 20, width: 40, height: 20))
    }

    @MainActor
    @Test func imageEditorCanUnlinkAllLinkedLayersAtOnce() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 140, height: 100))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let thirdID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.linkSelectedLayers()
        viewModel.selectLayer(secondID)
        viewModel.selectLayer(thirdID, extendingSelection: true)
        viewModel.linkSelectedLayers()

        #expect(viewModel.canUnlinkAllLayers)
        #expect(viewModel.isLayerLinked(firstID))
        #expect(viewModel.isLayerLinked(secondID))
        #expect(viewModel.isLayerLinked(thirdID))

        viewModel.selectLayer(firstID)
        viewModel.unlinkAllLayers()

        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerUnlinkAll"))
        #expect(!viewModel.canUnlinkAllLayers)
        #expect(!viewModel.isLayerLinked(firstID))
        #expect(!viewModel.isLayerLinked(secondID))
        #expect(!viewModel.isLayerLinked(thirdID))

        viewModel.undo()
        #expect(viewModel.canUnlinkAllLayers)
        #expect(viewModel.isLayerLinked(firstID))
        #expect(viewModel.isLayerLinked(secondID))
        #expect(viewModel.isLayerLinked(thirdID))
    }

    @MainActor
    @Test func imageEditorCanSelectTransitiveLinkedLayers() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 140, height: 100))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let thirdID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let unlinkedID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.linkSelectedLayers()
        viewModel.selectLayer(secondID)
        viewModel.selectLayer(thirdID, extendingSelection: true)
        viewModel.linkSelectedLayers()

        viewModel.selectLayer(firstID)
        #expect(viewModel.canSelectLinkedLayers)
        viewModel.selectLinkedLayers()

        #expect(viewModel.document.selectedLayerIDs == Set([firstID, secondID, thirdID]))
        #expect(viewModel.document.selectedLayerID == thirdID)
        #expect(!viewModel.document.selectedLayerIDs.contains(unlinkedID))

        viewModel.selectLayer(unlinkedID)
        #expect(!viewModel.canSelectLinkedLayers)
        viewModel.selectLinkedLayers()
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerNoLinks"))
        #expect(viewModel.document.selectedLayerIDs == Set([unlinkedID]))
    }

    @MainActor
    @Test func imageEditorCanSelectInvertAndClearLayerSelection() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 120, height: 80))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let backgroundID = try #require(viewModel.document.selectedLayerID)

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selection = .rectangle(CGRect(x: 8, y: 6, width: 20, height: 16))

        #expect(viewModel.canSelectAllLayers)
        viewModel.selectAllLayers()

        #expect(viewModel.document.selectedLayerIDs == Set([backgroundID, firstID, secondID]))
        #expect(viewModel.document.selectedLayerID == secondID)
        #expect(viewModel.document.selection?.points.first == CGPoint(x: 8, y: 6))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectAll", 3))

        viewModel.selectLayer(firstID)
        viewModel.invertLayerSelection()

        #expect(viewModel.document.selectedLayerIDs == Set([backgroundID, secondID]))
        #expect(viewModel.document.selectedLayerID == secondID)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSelectionInverted", 2))

        viewModel.clearLayerSelection()

        #expect(viewModel.document.selectedLayerID == nil)
        #expect(viewModel.document.selectedLayerIDs.isEmpty)
        #expect(viewModel.selectedLayerCount == 0)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerSelectionCleared"))

        viewModel.invertLayerSelection()

        #expect(viewModel.document.selectedLayerIDs == Set([backgroundID, firstID, secondID]))
        #expect(viewModel.document.selectedLayerID == secondID)
    }

    @MainActor
    @Test func imageEditorAlignsSelectedAndLinkedLayers() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 140, height: 100))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        viewModel.document.layers[firstIndex].frame = CGRect(x: 10, y: 10, width: 20, height: 10)

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        viewModel.document.layers[secondIndex].frame = CGRect(x: 50, y: 30, width: 10, height: 20)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        #expect(viewModel.canAlignSelectedLayers)
        viewModel.alignSelectedLayers(.left)

        let leftAlignedFirstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        let leftAlignedSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[leftAlignedFirstIndex].frame.minX == 10)
        #expect(viewModel.document.layers[leftAlignedSecondIndex].frame.minX == 10)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAlign"))

        viewModel.alignSelectedLayers(.verticalCenter)
        let centeredFirstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        let centeredSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[centeredFirstIndex].frame.midY == 25)
        #expect(viewModel.document.layers[centeredSecondIndex].frame.midY == 25)

        viewModel.undo()
        viewModel.undo()
        viewModel.linkSelectedLayers()
        viewModel.selectLayer(firstID)
        #expect(viewModel.canAlignSelectedLayers)
        viewModel.alignSelectedLayers(.right)

        let rightAlignedFirstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        let rightAlignedSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[rightAlignedFirstIndex].frame.maxX == 60)
        #expect(viewModel.document.layers[rightAlignedSecondIndex].frame.maxX == 60)
    }

    @MainActor
    @Test func imageEditorAlignsSelectedLayersToCanvasIncludingGroups() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 160, height: 120))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == firstID })].frame = CGRect(x: 12, y: 14, width: 30, height: 20)
        #expect(viewModel.canAlignSelectedLayersToCanvas)
        viewModel.alignSelectedLayersToCanvas(.horizontalCenter)
        var firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        #expect(viewModel.document.layers[firstIndex].frame.midX == 80)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAlignCanvas"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerAlignedToCanvas"))

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == secondID })].frame = CGRect(x: 70, y: 30, width: 20, height: 30)
        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.alignSelectedLayersToCanvas(.right)
        firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        var secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[firstIndex].frame.maxX == 160)
        #expect(viewModel.document.layers[secondIndex].frame.maxX == 160)

        viewModel.document.layers[firstIndex].frame = CGRect(x: 20, y: 15, width: 30, height: 20)
        viewModel.document.layers[secondIndex].frame = CGRect(x: 70, y: 35, width: 20, height: 30)
        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.document.selectedLayer?.isGroup == true)
        #expect(viewModel.canAlignSelectedLayersToCanvas)
        viewModel.alignSelectedLayersToCanvas(.top)

        firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[firstIndex].frame.maxY == 120)
        #expect(viewModel.document.layers[secondIndex].frame.maxY == 120)
        #expect(viewModel.document.selectedLayerID == groupID)
    }

    @MainActor
    @Test func imageEditorAlignsSelectedLayersToSelectionIncludingGroups() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 180, height: 140))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        viewModel.document.selection = .rectangle(CGRect(x: 30, y: 20, width: 90, height: 70))

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == firstID })].frame = CGRect(x: 8, y: 10, width: 30, height: 20)
        #expect(viewModel.canAlignSelectedLayersToSelection)
        viewModel.alignSelectedLayersToSelection(.horizontalCenter)
        var firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        #expect(viewModel.document.layers[firstIndex].frame.midX == 75)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAlignSelection"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerAlignedToSelection"))

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == secondID })].frame = CGRect(x: 80, y: 30, width: 20, height: 30)
        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.alignSelectedLayersToSelection(.left)
        firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        var secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[firstIndex].frame.minX == 30)
        #expect(viewModel.document.layers[secondIndex].frame.minX == 30)

        viewModel.document.layers[firstIndex].frame = CGRect(x: 20, y: 15, width: 30, height: 20)
        viewModel.document.layers[secondIndex].frame = CGRect(x: 70, y: 35, width: 20, height: 30)
        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.canAlignSelectedLayersToSelection)
        viewModel.alignSelectedLayersToSelection(.bottom)

        firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[firstIndex].frame.minY == 20)
        #expect(viewModel.document.layers[secondIndex].frame.minY == 20)
        #expect(viewModel.document.selectedLayerID == groupID)

        viewModel.document.selection = nil
        #expect(!viewModel.canAlignSelectedLayersToSelection)
        viewModel.alignSelectedLayersToSelection(.right)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.noSelection"))
    }

    @MainActor
    @Test func imageEditorDistributesSelectedLayersByEdgesAndCenters() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 180, height: 140))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        viewModel.document.layers[firstIndex].frame = CGRect(x: 10, y: 10, width: 20, height: 10)

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        viewModel.document.layers[secondIndex].frame = CGRect(x: 90, y: 80, width: 20, height: 10)

        viewModel.addLayer()
        let thirdID = try #require(viewModel.document.selectedLayerID)
        let thirdIndex = try #require(viewModel.document.layers.firstIndex { $0.id == thirdID })
        viewModel.document.layers[thirdIndex].frame = CGRect(x: 130, y: 110, width: 20, height: 10)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(thirdID, extendingSelection: true)
        #expect(viewModel.canDistributeSelectedLayers)

        func setFrames(
            first: CGRect = CGRect(x: 10, y: 10, width: 20, height: 10),
            second: CGRect = CGRect(x: 90, y: 80, width: 20, height: 10),
            third: CGRect = CGRect(x: 130, y: 110, width: 20, height: 10)
        ) throws {
            viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == firstID })].frame = first
            viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == secondID })].frame = second
            viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == thirdID })].frame = third
        }

        try setFrames()
        viewModel.distributeSelectedLayers(.left)
        var distributedSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[distributedSecondIndex].frame.minX == 70)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDistribute"))

        try setFrames(third: CGRect(x: 150, y: 110, width: 10, height: 10))
        viewModel.distributeSelectedLayers(.right)
        distributedSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[distributedSecondIndex].frame.maxX == 95)

        try setFrames()
        viewModel.distributeSelectedLayers(.horizontalCenter)

        let horizontallyDistributedSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[horizontallyDistributedSecondIndex].frame.midX == 80)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDistribute"))

        try setFrames()
        viewModel.distributeSelectedLayers(.top)
        distributedSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[distributedSecondIndex].frame.maxY == 70)

        try setFrames()
        viewModel.distributeSelectedLayers(.bottom)
        distributedSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[distributedSecondIndex].frame.minY == 60)

        try setFrames()
        viewModel.distributeSelectedLayers(.verticalCenter)

        let verticallyDistributedSecondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[verticallyDistributedSecondIndex].frame.midY == 65)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDistribute"))
    }

    @MainActor
    @Test func imageEditorDistributesSelectedLayerSpacing() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 200, height: 160))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let thirdID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(thirdID, extendingSelection: true)
        #expect(viewModel.canDistributeSelectedLayers)

        func setFrames(
            first: CGRect = CGRect(x: 10, y: 10, width: 20, height: 10),
            second: CGRect = CGRect(x: 60, y: 50, width: 30, height: 20),
            third: CGRect = CGRect(x: 150, y: 130, width: 10, height: 30)
        ) throws {
            viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == firstID })].frame = first
            viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == secondID })].frame = second
            viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == thirdID })].frame = third
        }

        try setFrames()
        viewModel.distributeSelectedLayerSpacing(.horizontal)
        var firstFrame = try #require(viewModel.document.layers.first { $0.id == firstID }?.frame.standardized)
        var secondFrame = try #require(viewModel.document.layers.first { $0.id == secondID }?.frame.standardized)
        var thirdFrame = try #require(viewModel.document.layers.first { $0.id == thirdID }?.frame.standardized)
        #expect(firstFrame.minX == 10)
        #expect(secondFrame.minX == 75)
        #expect(thirdFrame.minX == 150)
        #expect(secondFrame.minX - firstFrame.maxX == thirdFrame.minX - secondFrame.maxX)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDistributeSpacing"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerSpacingDistributed"))

        try setFrames()
        viewModel.distributeSelectedLayerSpacing(.vertical)
        firstFrame = try #require(viewModel.document.layers.first { $0.id == firstID }?.frame.standardized)
        secondFrame = try #require(viewModel.document.layers.first { $0.id == secondID }?.frame.standardized)
        thirdFrame = try #require(viewModel.document.layers.first { $0.id == thirdID }?.frame.standardized)
        #expect(firstFrame.minY == 10)
        #expect(secondFrame.minY == 65)
        #expect(thirdFrame.minY == 130)
        #expect(secondFrame.minY - firstFrame.maxY == thirdFrame.minY - secondFrame.maxY)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDistributeSpacing"))
    }

    @MainActor
    @Test func imageEditorImportImageCreatesCenteredScaledLayerAndUndoRestores() async throws {
        let canvas = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let imported = testImage(color: .systemPink, size: NSSize(width: 160, height: 120))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: canvas) { _ in }
        let originalLayerCount = viewModel.document.layers.count

        #expect(viewModel.canCopyMergedToClipboard)
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

        viewModel.importImageLayer(
            imported,
            sourceName: L10n.text("source.clipboard"),
            historyTitle: L10n.text("imageEditor.history.clipboardPasteLayer"),
            importedStatus: L10n.text("imageEditor.status.clipboardPastedToLayer")
        )

        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.clipboardPasteLayer"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.clipboardPastedToLayer"))

        viewModel.undo()
        #expect(viewModel.document.layers.count == originalLayerCount)

        var leftHalfAlpha = [UInt8](repeating: 0, count: Int(canvas.size.width * canvas.size.height))
        for y in 0..<Int(canvas.size.height) {
            for x in 0..<Int(canvas.size.width / 2) {
                leftHalfAlpha[y * Int(canvas.size.width) + x] = UInt8.max
            }
        }
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(
                width: Int(canvas.size.width),
                height: Int(canvas.size.height),
                alpha: leftHalfAlpha
            ),
            bounds: CGRect(origin: .zero, size: canvas.size)
        )
        viewModel.importImageLayerIntoSelection(
            imported,
            sourceName: L10n.text("source.clipboard"),
            historyTitle: L10n.text("imageEditor.history.clipboardPasteIntoSelection"),
            importedStatus: L10n.text("imageEditor.status.clipboardPastedIntoSelection")
        )

        let pastedIntoSelectionLayer = try #require(viewModel.document.selectedLayer)
        let pastedIntoSelectionMask = try #require(pastedIntoSelectionLayer.mask)
        let leftMask = try #require(pastedIntoSelectionMask.color(at: CGPoint(x: 40, y: 60))?.usingColorSpace(.deviceRGB))
        let rightMask = try #require(pastedIntoSelectionMask.color(at: CGPoint(x: 120, y: 60))?.usingColorSpace(.deviceRGB))
        let pastedLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 30))?.usingColorSpace(.deviceRGB))
        let pastedRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 60, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(pastedIntoSelectionLayer.frame == CGRect(x: 0, y: 0, width: 80, height: 60))
        #expect(leftMask.alphaComponent > 0.8)
        #expect(rightMask.alphaComponent < 0.05)
        #expect(pastedLeft.redComponent > 0.8)
        #expect(pastedRight.blueComponent > 0.8)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.clipboardPasteIntoSelection"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.clipboardPastedIntoSelection"))

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
    @Test func imageEditorConvertsLayerToSmartObjectAndRasterizesIt() async throws {
        let canvasSize = NSSize(width: 120, height: 80)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.textValue = "Smart"
        viewModel.textSize = 26
        viewModel.foregroundColor = .white
        viewModel.addText(at: CGPoint(x: 18, y: 24))
        viewModel.toggleSelectedLayerStroke()

        let textLayer = try #require(viewModel.document.selectedLayer)
        let expectedFrame = textLayer.compositingFrame
        let beforeConversion = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.canConvertSelectedLayerToSmartObject)
        viewModel.convertSelectedLayerToSmartObject()

        let smartObjectLayer = try #require(viewModel.document.selectedLayer)
        let smartObject = try #require(smartObjectLayer.smartObjectContent)
        #expect(smartObjectLayer.isSmartObject)
        #expect(!smartObjectLayer.isText)
        #expect(!smartObjectLayer.hasLayerEffects)
        #expect(smartObjectLayer.frame == expectedFrame)
        #expect(smartObject.originalSize == smartObjectLayer.image.size)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartObject"))
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == beforeConversion)
        #expect(viewModel.canRasterizeSelectedLayer)

        let originalSmartObjectData = try #require(smartObjectLayer.image.qingtuPNGData())
        let replacement = testBitmapImage(size: NSSize(width: 30, height: 20), background: .systemPink)
        viewModel.replaceSelectedSmartObjectContents(replacement, sourceName: " replacement.logo.png ")

        let replacedLayer = try #require(viewModel.document.selectedLayer)
        let replacedContent = try #require(replacedLayer.smartObjectContent)
        #expect(replacedLayer.frame == expectedFrame)
        #expect(replacedLayer.image.size == NSSize(width: 30, height: 20))
        #expect(replacedContent.originalSize == NSSize(width: 30, height: 20))
        #expect(replacedContent.sourceName == "replacement.logo")
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartObjectReplace"))

        let replacedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[replacedIndex].frame = CGRect(x: 12, y: 13, width: 12, height: 8)
        #expect(viewModel.canResetSelectedSmartObjectTransform)
        viewModel.resetSelectedSmartObjectTransform()

        let resetLayer = try #require(viewModel.document.selectedLayer)
        #expect(resetLayer.isSmartObject)
        #expect(resetLayer.image.size == NSSize(width: 30, height: 20))
        #expect(resetLayer.frame == CGRect(x: 3, y: 7, width: 30, height: 20))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartObjectResetTransform"))

        viewModel.undo()
        let restoredReplacedSmartObject = try #require(viewModel.document.selectedLayer)
        #expect(restoredReplacedSmartObject.isSmartObject)
        #expect(restoredReplacedSmartObject.frame == CGRect(x: 12, y: 13, width: 12, height: 8))

        viewModel.undo()
        let restoredOriginalSmartObject = try #require(viewModel.document.selectedLayer)
        #expect(restoredOriginalSmartObject.isSmartObject)
        #expect(restoredOriginalSmartObject.frame == expectedFrame)
        #expect(restoredOriginalSmartObject.image.qingtuPNGData() == originalSmartObjectData)

        viewModel.rasterizeSelectedLayer()

        let rasterizedLayer = try #require(viewModel.document.selectedLayer)
        #expect(!rasterizedLayer.isSmartObject)
        #expect(!rasterizedLayer.isText)
        #expect(rasterizedLayer.kind.isPixel)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRasterize"))

        viewModel.undo()
        let restoredSmartObjectLayer = try #require(viewModel.document.selectedLayer)
        #expect(restoredSmartObjectLayer.isSmartObject)
    }

    @MainActor
    @Test func imageEditorSmartObjectDuplicatesShareReplacedSource() async throws {
        let canvasSize = NSSize(width: 120, height: 80)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.textValue = "Logo"
        viewModel.textSize = 22
        viewModel.foregroundColor = .white
        viewModel.addText(at: CGPoint(x: 12, y: 18))
        viewModel.convertSelectedLayerToSmartObject()

        let originalLayer = try #require(viewModel.document.selectedLayer)
        let originalSourceID = try #require(originalLayer.smartObjectContent?.sourceID)
        let originalImageData = try #require(originalLayer.image.qingtuPNGData())
        viewModel.duplicateSelectedLayer()

        let duplicateLayer = try #require(viewModel.document.selectedLayer)
        #expect(duplicateLayer.id != originalLayer.id)
        #expect(duplicateLayer.smartObjectContent?.sourceID == originalSourceID)

        let originalIndex = try #require(viewModel.document.layers.firstIndex { $0.id == originalLayer.id })
        let duplicateIndex = try #require(viewModel.document.layers.firstIndex { $0.id == duplicateLayer.id })
        let originalFrame = CGRect(x: 8, y: 10, width: 24, height: 18)
        let duplicateFrame = CGRect(x: 52, y: 20, width: 36, height: 24)
        viewModel.document.layers[originalIndex].frame = originalFrame
        viewModel.document.layers[duplicateIndex].frame = duplicateFrame

        let replacement = testBitmapImage(size: NSSize(width: 30, height: 20), background: .systemTeal)
        viewModel.replaceSelectedSmartObjectContents(replacement, sourceName: " shared.logo.png ")

        let sharedLayers = viewModel.document.layers.filter { layer in
            layer.smartObjectContent?.sourceID == originalSourceID
        }
        #expect(sharedLayers.count == 2)
        #expect(viewModel.document.layers[originalIndex].image.size == NSSize(width: 30, height: 20))
        #expect(viewModel.document.layers[duplicateIndex].image.size == NSSize(width: 30, height: 20))
        #expect(viewModel.document.layers[originalIndex].smartObjectContent?.sourceName == "shared.logo")
        #expect(viewModel.document.layers[duplicateIndex].smartObjectContent?.sourceName == "shared.logo")
        #expect(viewModel.document.layers[originalIndex].frame == originalFrame)
        #expect(viewModel.document.layers[duplicateIndex].frame == duplicateFrame)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartObjectInstancesReplaced", 2, "shared.logo"))

        viewModel.undo()
        #expect(viewModel.document.layers[originalIndex].smartObjectContent?.sourceID == originalSourceID)
        #expect(viewModel.document.layers[duplicateIndex].smartObjectContent?.sourceID == originalSourceID)
        #expect(viewModel.document.layers[originalIndex].image.qingtuPNGData() == originalImageData)
        #expect(viewModel.document.layers[duplicateIndex].image.qingtuPNGData() == originalImageData)

        viewModel.document.selectedLayerID = duplicateLayer.id
        viewModel.document.selectedLayerIDs = [duplicateLayer.id]
        #expect(viewModel.canMakeSelectedSmartObjectUnique)
        viewModel.makeSelectedSmartObjectUnique()

        let uniqueSourceID = try #require(viewModel.document.layers[duplicateIndex].smartObjectContent?.sourceID)
        #expect(uniqueSourceID != originalSourceID)
        #expect(viewModel.document.layers[originalIndex].smartObjectContent?.sourceID == originalSourceID)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartObjectMakeUnique"))

        let uniqueReplacement = testBitmapImage(size: NSSize(width: 18, height: 12), background: .systemPurple)
        viewModel.replaceSelectedSmartObjectContents(uniqueReplacement, sourceName: " unique.logo.png ")
        #expect(viewModel.document.layers[originalIndex].image.qingtuPNGData() == originalImageData)
        #expect(viewModel.document.layers[duplicateIndex].image.size == NSSize(width: 18, height: 12))
        #expect(viewModel.document.layers[duplicateIndex].smartObjectContent?.sourceName == "unique.logo")
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartObjectReplaced", "unique.logo"))

        viewModel.undo()
        #expect(viewModel.document.layers[duplicateIndex].smartObjectContent?.sourceID == uniqueSourceID)
        #expect(viewModel.document.layers[duplicateIndex].image.qingtuPNGData() == originalImageData)

        viewModel.undo()
        #expect(viewModel.document.layers[duplicateIndex].smartObjectContent?.sourceID == originalSourceID)
    }

    @MainActor
    @Test func imageEditorConvertsMultipleSelectedLayersToSingleSmartObject() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let firstLayerID = try #require(viewModel.document.selectedLayerID)
        let firstLayerImage = testBitmapImage(
            size: canvasSize,
            background: NSColor(calibratedWhite: 0, alpha: 0),
            fills: [(CGRect(x: 12, y: 18, width: 34, height: 22), .systemPink)]
        )
        viewModel.replaceSelectedLayerImageForTesting(
            firstLayerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        viewModel.addLayer()
        let secondLayerID = try #require(viewModel.document.selectedLayerID)
        let secondLayerImage = testBitmapImage(
            size: canvasSize,
            background: NSColor(calibratedWhite: 0, alpha: 0),
            fills: [(CGRect(x: 66, y: 38, width: 30, height: 26), .systemTeal)]
        )
        viewModel.replaceSelectedLayerImageForTesting(
            secondLayerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        viewModel.selectLayer(firstLayerID)
        viewModel.selectLayer(secondLayerID, extendingSelection: true)
        let layerCountBeforeConversion = viewModel.document.layers.count
        let compositedBeforeConversion = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.selectedLayerCount == 2)
        #expect(viewModel.canConvertSelectedLayerToSmartObject)
        viewModel.convertSelectedLayerToSmartObject()

        let smartObjectLayer = try #require(viewModel.document.selectedLayer)
        let smartObject = try #require(smartObjectLayer.smartObjectContent)
        #expect(smartObjectLayer.isSmartObject)
        #expect(smartObject.sourceName == L10n.format("imageEditor.layer.smartObjectSelectionName", 2))
        #expect(smartObjectLayer.frame.minX <= 12)
        #expect(smartObjectLayer.frame.maxX >= 96)
        #expect(viewModel.document.layers.count == layerCountBeforeConversion - 1)
        #expect(!viewModel.document.layers.contains { $0.id == firstLayerID })
        #expect(!viewModel.document.layers.contains { $0.id == secondLayerID })
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeConversion)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartObject"))

        viewModel.undo()
        #expect(viewModel.document.layers.count == layerCountBeforeConversion)
        #expect(viewModel.document.layers.contains { $0.id == firstLayerID })
        #expect(viewModel.document.layers.contains { $0.id == secondLayerID })
        #expect(viewModel.selectedLayerCount == 2)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeConversion)
    }

    @MainActor
    @Test func imageEditorConvertsLayerGroupToSmartObjectAndUndoRestoresHierarchy() async throws {
        let canvasSize = NSSize(width: 140, height: 100)
        let image = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let firstLayerID = try #require(viewModel.document.selectedLayerID)
        let firstLayerImage = testBitmapImage(
            size: canvasSize,
            background: NSColor(calibratedWhite: 0, alpha: 0),
            fills: [(CGRect(x: 16, y: 16, width: 36, height: 26), .systemYellow)]
        )
        viewModel.replaceSelectedLayerImageForTesting(
            firstLayerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        viewModel.addLayer()
        let secondLayerID = try #require(viewModel.document.selectedLayerID)
        let secondLayerImage = testBitmapImage(
            size: canvasSize,
            background: NSColor(calibratedWhite: 0, alpha: 0),
            fills: [(CGRect(x: 70, y: 42, width: 28, height: 30), .systemPurple)]
        )
        viewModel.replaceSelectedLayerImageForTesting(
            secondLayerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        viewModel.selectLayer(firstLayerID)
        viewModel.selectLayer(secondLayerID, extendingSelection: true)
        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)
        let groupName = try #require(viewModel.document.selectedLayer?.name)
        let layerCountBeforeConversion = viewModel.document.layers.count
        let compositedBeforeConversion = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.document.selectedLayer?.isGroup == true)
        #expect(viewModel.canConvertSelectedLayerToSmartObject)
        viewModel.convertSelectedLayerToSmartObject()

        let smartObjectLayer = try #require(viewModel.document.selectedLayer)
        let smartObject = try #require(smartObjectLayer.smartObjectContent)
        #expect(smartObjectLayer.isSmartObject)
        #expect(smartObject.sourceName == groupName)
        #expect(viewModel.document.layers.count == layerCountBeforeConversion - 2)
        #expect(!viewModel.document.layers.contains { $0.id == groupID })
        #expect(!viewModel.document.layers.contains { $0.id == firstLayerID })
        #expect(!viewModel.document.layers.contains { $0.id == secondLayerID })
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeConversion)

        viewModel.undo()
        #expect(viewModel.document.layers.contains { $0.id == groupID })
        #expect(viewModel.document.layers.first { $0.id == firstLayerID }?.groupID == groupID)
        #expect(viewModel.document.layers.first { $0.id == secondLayerID }?.groupID == groupID)
        #expect(viewModel.document.selectedLayerID == groupID)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeConversion)
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

        viewModel.createRectSelection(from: CGPoint(x: 20, y: 12), to: CGPoint(x: 60, y: 48))
        let layerCountBeforeMergedCopy = viewModel.document.layers.count
        viewModel.copyMergedToNewLayer()

        let mergedCopyLayer = try #require(viewModel.document.selectedLayer)
        let mergedInside = try #require(mergedCopyLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let mergedOutside = try #require(mergedCopyLayer.image.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == layerCountBeforeMergedCopy + 1)
        #expect(mergedCopyLayer.frame == CGRect(origin: .zero, size: canvasSize))
        #expect(mergedInside.alphaComponent > 0.8)
        #expect(mergedOutside.alphaComponent < 0.05)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionCopyMergedLayer"))

        viewModel.undo()
        #expect(viewModel.document.layers.count == layerCountBeforeMergedCopy)
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
    @Test func imageEditorContentAwareFillsSelectionAndRespectsTransparentPixelLock() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let blemishRect = CGRect(x: 32, y: 22, width: 16, height: 16)
        let blemishImage = testBitmapImage(
            size: canvasSize,
            background: .systemGreen,
            fills: [(rect: blemishRect, color: .black)]
        )

        viewModel.replaceSelectedLayerImageForTesting(blemishImage, historyTitle: L10n.text("imageEditor.history.brush"))
        viewModel.createRectSelection(from: CGPoint(x: 32, y: 22), to: CGPoint(x: 48, y: 38))
        let beforeFill = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let blemishBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.canEditSelectionPixels)
        viewModel.contentAwareFillSelection()

        let filledLayer = try #require(viewModel.document.selectedLayer)
        let filledData = try #require(filledLayer.image.qingtuPNGData())
        let filledCenter = try #require(filledLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let outsideSelection = try #require(filledLayer.image.color(at: CGPoint(x: 12, y: 12))?.usingColorSpace(.deviceRGB))

        #expect(blemishBefore.redComponent < 0.1)
        #expect(filledData != beforeFill)
        #expect(filledCenter.greenComponent > 0.65)
        #expect(filledCenter.redComponent < 0.25)
        #expect(outsideSelection.greenComponent > 0.65)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionContentAwareFill"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionContentAwareFilled"))

        viewModel.undo()
        let restoredCenter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(restoredCenter.redComponent < 0.1)

        let transparentBlemishImage = testBitmapImage(
            size: canvasSize,
            background: .systemGreen,
            fills: [(rect: blemishRect, color: .clear)]
        )
        viewModel.replaceSelectedLayerImageForTesting(transparentBlemishImage, historyTitle: L10n.text("imageEditor.history.brush"))
        viewModel.createRectSelection(from: CGPoint(x: 32, y: 22), to: CGPoint(x: 48, y: 38))
        if let index = viewModel.document.selectedLayerIndex {
            viewModel.document.layers[index].locksTransparentPixels = true
        }
        viewModel.contentAwareFillSelection()

        let lockedCenter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(lockedCenter.alphaComponent < 0.1)
    }

    @MainActor
    @Test func imageEditorPatchToolSamplesDraggedSelectionOffset() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let blemishRect = CGRect(x: 32, y: 22, width: 16, height: 16)
        let sampleRect = CGRect(x: 12, y: 22, width: 16, height: 16)
        let patchSource = testBitmapImage(
            size: canvasSize,
            background: .systemGreen,
            fills: [
                (rect: sampleRect, color: .systemRed),
                (rect: blemishRect, color: .black)
            ]
        )

        viewModel.replaceSelectedLayerImageForTesting(patchSource, historyTitle: L10n.text("imageEditor.history.brush"))
        viewModel.createRectSelection(from: CGPoint(x: 32, y: 22), to: CGPoint(x: 48, y: 38))
        let beforePatch = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let blemishBefore = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))

        viewModel.patchSelection(from: CGPoint(x: 40, y: 30), to: CGPoint(x: 20, y: 30))

        let patchedLayer = try #require(viewModel.document.selectedLayer)
        let patchedData = try #require(patchedLayer.image.qingtuPNGData())
        let patchedCenter = try #require(patchedLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let untouchedOutside = try #require(patchedLayer.image.color(at: CGPoint(x: 70, y: 50))?.usingColorSpace(.deviceRGB))

        #expect(blemishBefore.redComponent < 0.1)
        #expect(patchedData != beforePatch)
        #expect(patchedCenter.redComponent > 0.75)
        #expect(patchedCenter.greenComponent < 0.35)
        #expect(untouchedOutside.greenComponent > 0.65)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionPatch"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionPatched"))

        viewModel.undo()
        let restoredCenter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(restoredCenter.redComponent < 0.1)

        let transparentPatchSource = testBitmapImage(
            size: canvasSize,
            background: .systemGreen,
            fills: [
                (rect: sampleRect, color: .systemRed),
                (rect: blemishRect, color: .clear)
            ]
        )
        viewModel.replaceSelectedLayerImageForTesting(transparentPatchSource, historyTitle: L10n.text("imageEditor.history.brush"))
        viewModel.createRectSelection(from: CGPoint(x: 32, y: 22), to: CGPoint(x: 48, y: 38))
        if let index = viewModel.document.selectedLayerIndex {
            viewModel.document.layers[index].locksTransparentPixels = true
        }
        viewModel.patchSelection(from: CGPoint(x: 40, y: 30), to: CGPoint(x: 20, y: 30))

        let lockedCenter = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(lockedCenter.alphaComponent < 0.1)
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
    @Test func imageEditorPhotoshopBlendModesCompositeWithPixelMath() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let baseColor = NSColor(calibratedRed: 0.20, green: 0.25, blue: 0.30, alpha: 1)
        let overlayColor = NSColor(calibratedRed: 0.70, green: 0.50, blue: 0.30, alpha: 1)
        let image = testBitmapImage(size: canvasSize, background: baseColor)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: overlayColor),
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        #expect(ImageEditorBlendMode.allCases.contains(.linearDodge))
        #expect(ImageEditorBlendMode.allCases.contains(.linearBurn))
        #expect(ImageEditorBlendMode.allCases.contains(.vividLight))
        #expect(ImageEditorBlendMode.allCases.contains(.linearLight))
        #expect(ImageEditorBlendMode.allCases.contains(.pinLight))
        #expect(ImageEditorBlendMode.allCases.contains(.exclusion))
        #expect(ImageEditorBlendMode.allCases.contains(.hue))
        #expect(ImageEditorBlendMode.allCases.contains(.saturation))
        #expect(ImageEditorBlendMode.allCases.contains(.color))
        #expect(ImageEditorBlendMode.allCases.contains(.luminosity))

        viewModel.setSelectedLayerBlendMode(.linearDodge)
        let dodge = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 15))?.usingColorSpace(.deviceRGB))
        #expect(abs(dodge.redComponent - 0.90) < 0.02)
        #expect(abs(dodge.greenComponent - 0.75) < 0.02)
        #expect(abs(dodge.blueComponent - 0.60) < 0.02)

        viewModel.setSelectedLayerBlendMode(.linearBurn)
        let burn = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 15))?.usingColorSpace(.deviceRGB))
        #expect(burn.redComponent < 0.03)
        #expect(burn.greenComponent < 0.03)
        #expect(burn.blueComponent < 0.03)

        viewModel.setSelectedLayerBlendMode(.color)
        let color = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 15))?.usingColorSpace(.deviceRGB))
        #expect(color.redComponent > color.greenComponent)
        #expect(color.greenComponent > color.blueComponent)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerBlendMode"))
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
    @Test func imageEditorLayerPartialLocksProtectPixelsAndPositionSeparately() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let selectedID = try #require(viewModel.document.selectedLayerID)
        let imageBeforePixelLock = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let frameBeforePixelLock = try #require(viewModel.document.selectedLayer?.frame)

        viewModel.toggleLayerPixelsLock(selectedID)
        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 24
        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 70, y: 50)])

        let imageAfterPixelLockedBrush = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        #expect(viewModel.document.selectedLayer?.locksPixels == true)
        #expect(imageAfterPixelLockedBrush == imageBeforePixelLock)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerPixelsLock"))

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 6, height: 4))
        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.document.selectedLayer?.frame != frameBeforePixelLock)

        viewModel.toggleLayerPixelsLock(selectedID)
        viewModel.toggleLayerPositionLock(selectedID)
        let frameBeforePositionLock = try #require(viewModel.document.selectedLayer?.frame)
        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 8, height: 8))
        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.document.selectedLayer?.locksPosition == true)
        #expect(viewModel.document.selectedLayer?.frame == frameBeforePositionLock)

        viewModel.drawBrush(points: [CGPoint(x: 8, y: 8), CGPoint(x: 70, y: 50)])
        let imageAfterPositionLockedBrush = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        #expect(imageAfterPositionLockedBrush != imageBeforePixelLock)
    }

    @MainActor
    @Test func imageEditorBatchLayerLockCommandsAffectSelectedEditableLayers() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)

        #expect(viewModel.canLockSelectedLayers)
        viewModel.lockSelectedLayers()
        #expect(viewModel.document.layers.first { $0.id == firstID }?.isLocked == true)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.isLocked == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerLockSelected"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerLockSelected"))

        #expect(viewModel.canUnlockSelectedLayers)
        viewModel.unlockSelectedLayers()
        #expect(viewModel.document.layers.first { $0.id == firstID }?.isLocked == false)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.isLocked == false)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerUnlockSelected"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerUnlockSelected"))

        viewModel.lockSelectedLayerPixels()
        viewModel.lockSelectedLayerPosition()
        viewModel.lockSelectedLayerTransparentPixels()
        let firstLocked = try #require(viewModel.document.layers.first { $0.id == firstID })
        let secondLocked = try #require(viewModel.document.layers.first { $0.id == secondID })
        #expect(firstLocked.locksPixels)
        #expect(firstLocked.locksPosition)
        #expect(firstLocked.locksTransparentPixels)
        #expect(secondLocked.locksPixels)
        #expect(secondLocked.locksPosition)
        #expect(secondLocked.locksTransparentPixels)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTransparentPixelsLockSelected"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerTransparentPixelsLockSelected"))

        viewModel.unlockSelectedLayers()
        let firstUnlocked = try #require(viewModel.document.layers.first { $0.id == firstID })
        let secondUnlocked = try #require(viewModel.document.layers.first { $0.id == secondID })
        #expect(!firstUnlocked.isLocked)
        #expect(!firstUnlocked.locksPixels)
        #expect(!firstUnlocked.locksPosition)
        #expect(!firstUnlocked.locksTransparentPixels)
        #expect(!secondUnlocked.isLocked)
        #expect(!secondUnlocked.locksPixels)
        #expect(!secondUnlocked.locksPosition)
        #expect(!secondUnlocked.locksTransparentPixels)
    }

    @MainActor
    @Test func imageEditorGroupPositionLockProtectsDescendantTransforms() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let childID = try #require(viewModel.document.selectedLayerID)
        let childFrame = try #require(viewModel.document.selectedLayer?.frame)

        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerPositionLock(groupID)
        #expect(viewModel.document.selectedLayer?.locksPosition == true)

        viewModel.selectLayer(childID)
        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 12, height: 9))
        viewModel.finishMovingSelectedLayer()

        let childLayer = try #require(viewModel.document.layers.first { $0.id == childID })
        #expect(childLayer.frame == childFrame)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerLocked"))
    }

    @MainActor
    @Test func imageEditorTransparentPixelLockPreservesLayerAlpha() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let selectedID = try #require(viewModel.document.selectedLayerID)
        let halfOpaqueLayer = testBitmapImage(
            size: canvasSize,
            background: NSColor(calibratedWhite: 0, alpha: 0),
            fills: [
                (CGRect(x: 0, y: 0, width: 32, height: 60), .systemPink)
            ]
        )

        viewModel.replaceSelectedLayerImageForTesting(
            halfOpaqueLayer,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.toggleLayerTransparentPixelsLock(selectedID)

        #expect(viewModel.document.selectedLayer?.locksTransparentPixels == true)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTransparentPixelsLock"))

        viewModel.foregroundColor = .systemGreen
        viewModel.brushSize = 96
        viewModel.opacity = 1
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 30), CGPoint(x: 80, y: 30)])

        let paintedLayer = try #require(viewModel.document.selectedLayer)
        let opaqueSide = try #require(paintedLayer.image.color(at: CGPoint(x: 12, y: 30))?.usingColorSpace(.deviceRGB))
        let transparentSide = try #require(paintedLayer.image.color(at: CGPoint(x: 68, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(opaqueSide.alphaComponent > 0.8)
        #expect(opaqueSide.greenComponent > opaqueSide.redComponent)
        #expect(transparentSide.alphaComponent < 0.05)

        viewModel.drawBrush(points: [CGPoint(x: 8, y: 30), CGPoint(x: 24, y: 30)], erase: true)
        let erasedOpaqueSide = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 16, y: 30))?.usingColorSpace(.deviceRGB))
        let erasedTransparentSide = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 68, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(erasedOpaqueSide.alphaComponent > 0.8)
        #expect(erasedTransparentSide.alphaComponent < 0.05)
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
    @Test func imageEditorStampSelectedCreatesMergedCopyAndPreservesSourceLayers() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let firstLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 44
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 0), CGPoint(x: 80, y: 60)])

        viewModel.addLayer()
        let secondLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.foregroundColor = .systemYellow
        viewModel.brushSize = 28
        viewModel.drawBrush(points: [CGPoint(x: 10, y: 10), CGPoint(x: 70, y: 50)])

        viewModel.addLayer()
        let unselectedLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.foregroundColor = .systemGreen
        viewModel.brushSize = 22
        viewModel.drawBrush(points: [CGPoint(x: 72, y: 8), CGPoint(x: 76, y: 12)])

        viewModel.selectLayer(firstLayerID)
        viewModel.selectLayer(secondLayerID, extendingSelection: true)

        let layerCountBeforeStamp = viewModel.document.layers.count
        let compositedBeforeStamp = try #require(viewModel.currentImage.qingtuPNGData())
        let selectedCompositeBeforeStamp = try #require(
            viewModel.document.compositedImage(includingOnly: [firstLayerID, secondLayerID]).qingtuPNGData()
        )

        #expect(viewModel.canStampSelectedLayers)
        viewModel.stampSelectedLayers()

        let stampLayer = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.count == layerCountBeforeStamp + 1)
        #expect(stampLayer.name == L10n.text("imageEditor.layer.selectedStampName"))
        #expect(stampLayer.image.qingtuPNGData() == selectedCompositeBeforeStamp)
        #expect(viewModel.document.layers.contains { $0.id == firstLayerID })
        #expect(viewModel.document.layers.contains { $0.id == secondLayerID })
        #expect(viewModel.document.layers.contains { $0.id == unselectedLayerID })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStampSelected"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerStampSelected"))

        viewModel.undo()
        #expect(viewModel.document.layers.count == layerCountBeforeStamp)
        #expect(viewModel.document.layers.contains { $0.id == firstLayerID })
        #expect(viewModel.document.layers.contains { $0.id == secondLayerID })
        #expect(viewModel.document.layers.contains { $0.id == unselectedLayerID })
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
    @Test func imageEditorMergeSelectedLayersBakesOnlySelectedCompositeAndUndoRestoresStack() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let firstLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.foregroundColor = .systemPink
        viewModel.brushSize = 44
        viewModel.drawBrush(points: [CGPoint(x: 0, y: 0), CGPoint(x: 80, y: 60)])

        viewModel.addLayer()
        let secondLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.foregroundColor = .systemYellow
        viewModel.brushSize = 28
        viewModel.drawBrush(points: [CGPoint(x: 10, y: 10), CGPoint(x: 70, y: 50)])

        let layerCountBeforeMerge = viewModel.document.layers.count
        let compositedBeforeMerge = try #require(viewModel.currentImage.qingtuPNGData())
        let selectedCompositeBeforeMerge = try #require(
            viewModel.document.compositedImage(includingOnly: [firstLayerID, secondLayerID]).qingtuPNGData()
        )

        viewModel.selectLayer(firstLayerID)
        viewModel.selectLayer(secondLayerID, extendingSelection: true)

        #expect(viewModel.canMergeSelectedLayers)
        viewModel.mergeSelectedLayers()

        let mergedLayer = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.count == layerCountBeforeMerge - 1)
        #expect(mergedLayer.name == L10n.text("imageEditor.layer.selectedMergedName"))
        #expect(mergedLayer.image.qingtuPNGData() == selectedCompositeBeforeMerge)
        #expect(!viewModel.document.layers.contains { $0.id == firstLayerID })
        #expect(!viewModel.document.layers.contains { $0.id == secondLayerID })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeSelected"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerMergeSelected"))
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeMerge)

        viewModel.undo()
        #expect(viewModel.document.layers.count == layerCountBeforeMerge)
        #expect(viewModel.document.layers.contains { $0.id == firstLayerID })
        #expect(viewModel.document.layers.contains { $0.id == secondLayerID })
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
    @Test func imageEditorCombinesExistingLayerMaskWithCurrentSelection() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayerMaskHidingAll()
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 30, y: 30))

        #expect(viewModel.canCombineLayerMaskWithSelection)
        viewModel.revealSelectionOnLayerMask()

        var maskImage = try #require(viewModel.document.selectedLayer?.mask)
        var mask = try #require(maskImage.alphaMask(width: 80, height: 60))
        #expect(maskAlpha(mask, x: 10, y: 10) == 255)
        #expect(maskAlpha(mask, x: 50, y: 10) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskRevealSelection"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerMaskRevealSelection"))

        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 15, y: 30))
        viewModel.hideSelectionOnLayerMask()

        maskImage = try #require(viewModel.document.selectedLayer?.mask)
        mask = try #require(maskImage.alphaMask(width: 80, height: 60))
        #expect(maskAlpha(mask, x: 10, y: 10) == 0)
        #expect(maskAlpha(mask, x: 25, y: 10) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskHideSelectionFromMask"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerMaskHideSelectionFromMask"))

        viewModel.createRectSelection(from: CGPoint(x: 40, y: 0), to: CGPoint(x: 70, y: 30))
        viewModel.revealSelectionOnLayerMask()
        viewModel.createRectSelection(from: CGPoint(x: 45, y: 0), to: CGPoint(x: 60, y: 30))
        viewModel.intersectLayerMaskWithSelection()

        maskImage = try #require(viewModel.document.selectedLayer?.mask)
        mask = try #require(maskImage.alphaMask(width: 80, height: 60))
        #expect(maskAlpha(mask, x: 50, y: 10) == 255)
        #expect(maskAlpha(mask, x: 25, y: 10) == 0)
        #expect(maskAlpha(mask, x: 65, y: 10) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskIntersectSelection"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerMaskIntersectSelection"))
    }

    @MainActor
    @Test func imageEditorCopiesPrimaryLayerMaskToSelectedLayers() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let targetID = try #require(viewModel.document.selectedLayerID)
        let targetIndex = try #require(viewModel.document.layers.firstIndex { $0.id == targetID })
        viewModel.document.layers[targetIndex].image = testBitmapImage(
            size: NSSize(width: 10, height: 5),
            background: .clear
        )
        viewModel.document.layers[targetIndex].mask = nil

        viewModel.addLayer()
        let sourceID = try #require(viewModel.document.selectedLayerID)
        let sourceIndex = try #require(viewModel.document.layers.firstIndex { $0.id == sourceID })
        viewModel.document.layers[sourceIndex].mask = testBitmapImage(
            size: NSSize(width: 20, height: 10),
            background: .clear,
            fills: [(rect: CGRect(x: 10, y: 0, width: 10, height: 10), color: .white)]
        )
        viewModel.document.layers[sourceIndex].isMaskEnabled = false
        viewModel.document.layers[sourceIndex].isMaskLinked = false
        viewModel.document.layers[sourceIndex].maskDensity = 0.42
        viewModel.document.layers[sourceIndex].maskFeather = 3

        viewModel.selectLayer(targetID)
        viewModel.selectLayer(sourceID, extendingSelection: true)
        #expect(viewModel.document.selectedLayerID == sourceID)
        #expect(viewModel.canCopyLayerMaskToSelectedLayers)

        viewModel.copyLayerMaskToSelectedLayers()

        let targetLayer = try #require(viewModel.document.layers.first { $0.id == targetID })
        let targetMask = try #require(targetLayer.mask)
        let targetAlpha = try #require(targetMask.alphaMask(width: 10, height: 5))
        #expect(targetMask.size == NSSize(width: 10, height: 5))
        #expect(maskAlpha(targetAlpha, x: 2, y: 2) == 0)
        #expect(maskAlpha(targetAlpha, x: 8, y: 2) == 255)
        #expect(targetLayer.isMaskEnabled == false)
        #expect(targetLayer.isMaskLinked == false)
        #expect(abs(targetLayer.maskDensity - 0.42) < 0.001)
        #expect(targetLayer.maskFeather == 3)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskCopy"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerMaskCopied", 1))
    }

    @MainActor
    @Test func imageEditorCanLoadSelectionsFromLayerAndVectorMasks() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testBitmapImage(size: canvasSize, background: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 20, y: 12), to: CGPoint(x: 60, y: 48))
        viewModel.addLayerMaskFromSelection()
        viewModel.document.selection = nil

        #expect(viewModel.canLoadSelectionFromLayerMask)
        viewModel.loadSelectionFromLayerMask()

        let rasterSelection = try #require(viewModel.document.selection)
        let rasterMask = try #require(rasterSelection.rasterMask)
        let rasterBounds = try #require(rasterMask.selectedBounds(in: canvasSize))
        #expect(abs(rasterBounds.minX - 20) < 1)
        #expect(abs(rasterBounds.minY - 12) < 1)
        #expect(abs(rasterBounds.maxX - 60) < 1)
        #expect(abs(rasterBounds.maxY - 48) < 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromLayerMask"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerMaskSelection"))

        let maskedLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let transparentLayerID = try #require(viewModel.document.selectedLayerID)
        let transparentLayerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == transparentLayerID })
        viewModel.document.layers[transparentLayerIndex].image = testBitmapImage(
            size: NSSize(width: 20, height: 10),
            background: .clear,
            fills: [(rect: CGRect(x: 5, y: 2, width: 10, height: 6), color: .systemPink)]
        )
        viewModel.document.layers[transparentLayerIndex].frame = CGRect(x: 30, y: 20, width: 20, height: 10)
        viewModel.document.selection = nil

        #expect(viewModel.canLoadSelectionFromLayerTransparency)
        viewModel.loadSelectionFromLayerTransparency()

        let transparencySelection = try #require(viewModel.document.selection)
        let transparencyMask = try #require(transparencySelection.rasterMask)
        let transparencyBounds = try #require(transparencyMask.selectedBounds(in: canvasSize))
        #expect(abs(transparencyBounds.minX - 35) < 1)
        #expect(abs(transparencyBounds.minY - 22) < 1)
        #expect(abs(transparencyBounds.maxX - 45) < 1)
        #expect(abs(transparencyBounds.maxY - 28) < 1)
        #expect(maskAlpha(transparencyMask, x: 40, y: 25) == 255)
        #expect(maskAlpha(transparencyMask, x: 50, y: 25) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromLayer"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionCreated"))

        viewModel.createRectSelection(from: CGPoint(x: 40, y: 20), to: CGPoint(x: 60, y: 30))
        viewModel.selectionMode = .intersect
        viewModel.loadSelectionFromLayerTransparency()
        viewModel.selectionMode = .replace

        let intersectedTransparencySelection = try #require(viewModel.document.selection)
        let intersectedTransparencyMask = try #require(intersectedTransparencySelection.rasterMask)
        #expect(maskAlpha(intersectedTransparencyMask, x: 42, y: 25) == 255)
        #expect(maskAlpha(intersectedTransparencyMask, x: 37, y: 25) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text(ImageEditorSelectionMode.intersect.historyKey))

        viewModel.selectLayer(maskedLayerID)
        let anchors = [
            ImageEditorPathAnchor(point: CGPoint(x: 10, y: 8)),
            ImageEditorPathAnchor(point: CGPoint(x: 32, y: 8)),
            ImageEditorPathAnchor(point: CGPoint(x: 32, y: 28)),
            ImageEditorPathAnchor(point: CGPoint(x: 10, y: 28))
        ]
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].vectorMask = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: anchors.map(\.point),
            pathAnchors: anchors,
            isPathClosed: true
        )
        viewModel.document.selection = nil

        #expect(viewModel.canLoadSelectionFromVectorMask)
        viewModel.loadSelectionFromVectorMask()

        let vectorSelection = try #require(viewModel.document.selection)
        let vectorMask = try #require(vectorSelection.rasterMask)
        let vectorBounds = try #require(vectorMask.selectedBounds(in: canvasSize))
        #expect(abs(vectorBounds.minX - 10) < 1)
        #expect(abs(vectorBounds.minY - 8) < 1)
        #expect(abs(vectorBounds.maxX - 32) < 1)
        #expect(abs(vectorBounds.maxY - 28) < 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromVectorMask"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.vectorMaskSelection"))
    }

    @MainActor
    @Test func imageEditorCanLoadSelectionFromGroupTransparency() async throws {
        let canvasSize = NSSize(width: 90, height: 70)
        let image = testBitmapImage(size: canvasSize, background: .clear)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        var group = ImageEditorLayer.group(name: "Artwork Group", size: canvasSize)
        group.opacity = 0.8
        let groupID = group.id

        var leftLayer = ImageEditorLayer.blank(name: "Left Shape", size: canvasSize)
        leftLayer.groupID = groupID
        leftLayer.image = testBitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [(rect: CGRect(x: 10, y: 12, width: 22, height: 18), color: .systemPink)]
        )

        var rightLayer = ImageEditorLayer.blank(name: "Right Shape", size: canvasSize)
        rightLayer.groupID = groupID
        rightLayer.image = testBitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [(rect: CGRect(x: 58, y: 38, width: 18, height: 16), color: .systemGreen)]
        )

        viewModel.document.layers = [
            ImageEditorLayer.background(image: image),
            group,
            leftLayer,
            rightLayer
        ]
        viewModel.document.selectedLayerID = groupID
        viewModel.document.selectedLayerIDs = [groupID]
        viewModel.document.selection = nil

        #expect(viewModel.canLoadSelectionFromLayerTransparency)
        viewModel.loadSelectionFromLayerTransparency()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        let bounds = try #require(mask.selectedBounds(in: canvasSize))
        #expect(bounds.minX <= 11)
        #expect(bounds.minY <= 13)
        #expect(bounds.maxX >= 75)
        #expect(bounds.maxY >= 53)
        #expect(maskAlpha(mask, x: 18, y: 20) == 255)
        #expect(maskAlpha(mask, x: 66, y: 46) == 255)
        #expect(maskAlpha(mask, x: 44, y: 34) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromLayer"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionCreated"))
    }

    @MainActor
    @Test func imageEditorCanCreateHideAllAndHideSelectionLayerMasks() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testImage(color: .systemBlue, size: canvasSize)
        let hideAllViewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        hideAllViewModel.foregroundColor = .systemPink
        hideAllViewModel.brushSize = 90
        hideAllViewModel.drawBrush(points: [CGPoint(x: 0, y: 30), CGPoint(x: 80, y: 30)])
        hideAllViewModel.addLayerMaskHidingAll()

        let hiddenAllColor = try #require(hideAllViewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(hideAllViewModel.selectedLayerHasMask)
        #expect(hideAllViewModel.isEditingLayerMask)
        #expect(hiddenAllColor.blueComponent > hiddenAllColor.redComponent)
        #expect(hideAllViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskHideAll"))

        let hideSelectionViewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        hideSelectionViewModel.foregroundColor = .systemPink
        hideSelectionViewModel.brushSize = 90
        hideSelectionViewModel.drawBrush(points: [CGPoint(x: 0, y: 30), CGPoint(x: 80, y: 30)])
        hideSelectionViewModel.createRectSelection(from: CGPoint(x: 20, y: 12), to: CGPoint(x: 60, y: 48))
        hideSelectionViewModel.addLayerMaskHidingSelection()

        let insideHidden = try #require(hideSelectionViewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let outsideVisible = try #require(hideSelectionViewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        #expect(hideSelectionViewModel.selectedLayerHasMask)
        #expect(hideSelectionViewModel.isEditingLayerMask)
        #expect(insideHidden.blueComponent > outsideVisible.blueComponent + 0.25)
        #expect(outsideVisible.redComponent > insideHidden.redComponent + 0.25)
        #expect(hideSelectionViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskHideSelection"))
    }

    @MainActor
    @Test func imageEditorLayerMaskDensityAndFeatherAreNonDestructiveUntilApplied() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testBitmapImage(size: canvasSize, background: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: .systemPink),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(from: CGPoint(x: 20, y: 12), to: CGPoint(x: 60, y: 48))
        viewModel.addLayerMaskFromSelection()

        let outsideHard = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(outsideHard.blueComponent > outsideHard.redComponent)

        viewModel.setSelectedLayerMaskDensity(0.5)
        viewModel.commitSelectedLayerMaskDensityChange()
        let outsideDense = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(viewModel.selectedLayerMaskDensity == 0.5)
        #expect(outsideDense.redComponent > outsideHard.redComponent + 0.15)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskDensity"))

        viewModel.setSelectedLayerMaskDensity(1)
        viewModel.setSelectedLayerMaskFeather(8)
        viewModel.commitSelectedLayerMaskFeatherChange()
        let featheredEdge = try #require(viewModel.currentImage.color(at: CGPoint(x: 18, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(viewModel.selectedLayerMaskFeather == 8)
        #expect(featheredEdge.redComponent > outsideHard.redComponent + 0.15)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskFeather"))

        let compositedBeforeApply = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.applyLayerMask()
        let appliedLayer = try #require(viewModel.document.selectedLayer)

        #expect(appliedLayer.mask == nil)
        #expect(appliedLayer.maskDensity == 1)
        #expect(appliedLayer.maskFeather == 0)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeApply)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskApply"))
    }

    @MainActor
    @Test func imageEditorCanDisableReenableAndApplyDisabledLayerMask() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testBitmapImage(size: canvasSize, background: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: .systemPink),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(from: CGPoint(x: 20, y: 12), to: CGPoint(x: 60, y: 48))
        viewModel.addLayerMaskFromSelection()

        let outsideMasked = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(outsideMasked.blueComponent > outsideMasked.redComponent)
        #expect(viewModel.document.selectedLayer?.isMaskEnabled == true)

        viewModel.toggleLayerMaskEnabled()
        let outsideDisabled = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(viewModel.document.selectedLayer?.isMaskEnabled == false)
        #expect(outsideDisabled.redComponent > outsideMasked.redComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskDisable"))

        viewModel.toggleLayerMaskEnabled()
        let outsideReenabled = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(viewModel.document.selectedLayer?.isMaskEnabled == true)
        #expect(outsideReenabled.blueComponent > outsideReenabled.redComponent)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskEnable"))

        viewModel.toggleLayerMaskEnabled()
        let visibleBeforeApply = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.applyLayerMask()
        let appliedLayer = try #require(viewModel.document.selectedLayer)

        #expect(appliedLayer.mask == nil)
        #expect(appliedLayer.isMaskEnabled)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == visibleBeforeApply)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskApply"))
    }

    @MainActor
    @Test func imageEditorCanUnlinkLayerMaskBeforeMovingLayerContents() async throws {
        func maskedViewModel() -> ImageEditorViewModel {
            let canvasSize = NSSize(width: 80, height: 60)
            let image = testBitmapImage(size: canvasSize, background: .systemBlue)
            let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
            viewModel.replaceSelectedLayerImageForTesting(
                testBitmapImage(size: canvasSize, background: .systemPink),
                historyTitle: L10n.text("imageEditor.history.brush")
            )
            viewModel.createRectSelection(from: CGPoint(x: 20, y: 12), to: CGPoint(x: 60, y: 48))
            viewModel.addLayerMaskFromSelection()
            return viewModel
        }

        let linkedViewModel = maskedViewModel()
        linkedViewModel.beginMovingSelectedLayer()
        linkedViewModel.moveSelectedLayer(by: CGSize(width: 12, height: 0))
        linkedViewModel.finishMovingSelectedLayer()

        let linkedSample = try #require(linkedViewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(linkedViewModel.document.selectedLayer?.isMaskLinked == true)
        #expect(linkedSample.blueComponent > linkedSample.redComponent)

        let unlinkedViewModel = maskedViewModel()
        unlinkedViewModel.toggleLayerMaskLinked()
        #expect(unlinkedViewModel.document.selectedLayer?.isMaskLinked == false)
        #expect(unlinkedViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskUnlink"))

        unlinkedViewModel.beginMovingSelectedLayer()
        unlinkedViewModel.moveSelectedLayer(by: CGSize(width: 12, height: 0))
        unlinkedViewModel.finishMovingSelectedLayer()

        let unlinkedSample = try #require(unlinkedViewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(unlinkedSample.redComponent > linkedSample.redComponent + 0.25)
        #expect(unlinkedSample.redComponent > unlinkedSample.blueComponent)

        func vectorMaskedViewModel() -> ImageEditorViewModel {
            let canvasSize = NSSize(width: 80, height: 60)
            let image = testBitmapImage(size: canvasSize, background: .systemBlue)
            let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
            viewModel.replaceSelectedLayerImageForTesting(
                testBitmapImage(size: canvasSize, background: .systemPink),
                historyTitle: L10n.text("imageEditor.history.brush")
            )
            let anchors = [
                ImageEditorPathAnchor(point: CGPoint(x: 20, y: 12)),
                ImageEditorPathAnchor(point: CGPoint(x: 60, y: 12)),
                ImageEditorPathAnchor(point: CGPoint(x: 60, y: 48)),
                ImageEditorPathAnchor(point: CGPoint(x: 20, y: 48))
            ]
            viewModel.document.layers[viewModel.document.selectedLayerIndex ?? 0].vectorMask = ImageEditorShapeContent(
                kind: .path,
                fillColor: .white,
                fillOpacity: 1,
                strokeColor: .white,
                strokeWidth: 1,
                strokeOpacity: 0,
                pathPoints: anchors.map(\.point),
                pathAnchors: anchors,
                isPathClosed: true
            )
            return viewModel
        }

        let linkedVectorViewModel = vectorMaskedViewModel()
        linkedVectorViewModel.beginMovingSelectedLayer()
        linkedVectorViewModel.moveSelectedLayer(by: CGSize(width: 12, height: 0))
        linkedVectorViewModel.finishMovingSelectedLayer()

        let linkedVectorSample = try #require(linkedVectorViewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(linkedVectorViewModel.document.selectedLayer?.isMaskLinked == true)
        #expect(linkedVectorSample.blueComponent > linkedVectorSample.redComponent)

        let unlinkedVectorViewModel = vectorMaskedViewModel()
        #expect(unlinkedVectorViewModel.canToggleLayerMaskLinked)
        unlinkedVectorViewModel.toggleLayerMaskLinked()
        unlinkedVectorViewModel.beginMovingSelectedLayer()
        unlinkedVectorViewModel.moveSelectedLayer(by: CGSize(width: 12, height: 0))
        unlinkedVectorViewModel.finishMovingSelectedLayer()

        let unlinkedVectorSample = try #require(unlinkedVectorViewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(unlinkedVectorViewModel.document.selectedLayer?.isMaskLinked == false)
        #expect(unlinkedVectorSample.redComponent > linkedVectorSample.redComponent + 0.25)
        #expect(unlinkedVectorSample.redComponent > unlinkedVectorSample.blueComponent)
    }

    @MainActor
    @Test func imageEditorCloneStampSamplesCurrentLayerPixels() async throws {
        let image = testBitmapImage(
            size: NSSize(width: 80, height: 60),
            background: .systemBlue,
            fills: [
                (CGRect(x: 8, y: 20, width: 20, height: 20), .systemRed)
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.brushSize = 8
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 16, y: 30))
        viewModel.cloneStamp(points: [
            CGPoint(x: 55, y: 30),
            CGPoint(x: 65, y: 30)
        ])

        let cloned = try #require(viewModel.currentImage.color(at: CGPoint(x: 56, y: 30))?.usingColorSpace(.deviceRGB))
        let untouched = try #require(viewModel.currentImage.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(cloned.redComponent > cloned.blueComponent + 0.25)
        #expect(untouched.blueComponent > untouched.redComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.cloneStamp"))
    }

    @MainActor
    @Test func imageEditorDodgeAndBurnAdjustStrokePixelsOnly() async throws {
        let baseColor = NSColor(calibratedWhite: 0.4, alpha: 1)
        let image = testBitmapImage(size: NSSize(width: 90, height: 60), background: baseColor)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let before = try #require(viewModel.currentImage.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))

        viewModel.brushSize = 10
        viewModel.opacity = 1
        viewModel.toneBrush(points: [
            CGPoint(x: 18, y: 30),
            CGPoint(x: 28, y: 30)
        ], burn: false)

        let dodged = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 30))?.usingColorSpace(.deviceRGB))
        let untouched = try #require(viewModel.currentImage.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(dodged.redComponent > before.redComponent + 0.2)
        #expect(abs(untouched.redComponent - before.redComponent) < 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.dodge"))

        viewModel.toneBrush(points: [
            CGPoint(x: 68, y: 30),
            CGPoint(x: 78, y: 30)
        ], burn: true)

        let burned = try #require(viewModel.currentImage.color(at: CGPoint(x: 70, y: 30))?.usingColorSpace(.deviceRGB))
        let stillUntouched = try #require(viewModel.currentImage.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(burned.redComponent < before.redComponent - 0.18)
        #expect(abs(stillUntouched.redComponent - before.redComponent) < 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.burn"))
    }

    @MainActor
    @Test func imageEditorBlurBrushSoftensStrokeAreaOnly() async throws {
        let image = testBitmapImage(
            size: NSSize(width: 90, height: 60),
            background: .systemBlue,
            fills: [
                (CGRect(x: 0, y: 0, width: 45, height: 60), .systemRed)
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.brushSize = 18
        viewModel.opacity = 1
        viewModel.blurBrush(points: [
            CGPoint(x: 45, y: 12),
            CGPoint(x: 45, y: 48)
        ])

        let blurredEdge = try #require(viewModel.currentImage.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        let untouchedRed = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 30))?.usingColorSpace(.deviceRGB))
        let untouchedBlue = try #require(viewModel.currentImage.color(at: CGPoint(x: 78, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(blurredEdge.redComponent > 0.15)
        #expect(blurredEdge.blueComponent > 0.15)
        #expect(untouchedRed.redComponent > untouchedRed.blueComponent + 0.45)
        #expect(untouchedBlue.blueComponent > untouchedBlue.redComponent + 0.45)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.blur"))
    }

    @MainActor
    @Test func imageEditorSharpenBrushIncreasesStrokeEdgeContrastOnly() async throws {
        let hardEdge = testBitmapImage(
            size: NSSize(width: 90, height: 60),
            background: .white,
            fills: [
                (CGRect(x: 0, y: 0, width: 45, height: 60), .black)
            ]
        )
        let blurredEdge = try #require(hardEdge.blurred(radius: 5))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: blurredEdge) { _ in }
        let beforeDark = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let beforeLight = try #require(viewModel.currentImage.color(at: CGPoint(x: 50, y: 30))?.usingColorSpace(.deviceRGB))
        let beforeFar = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 30))?.usingColorSpace(.deviceRGB))
        let beforeContrast = beforeLight.redComponent - beforeDark.redComponent

        viewModel.brushSize = 22
        viewModel.opacity = 1
        viewModel.sharpenBrush(points: [
            CGPoint(x: 45, y: 12),
            CGPoint(x: 45, y: 48)
        ])

        let afterDark = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let afterLight = try #require(viewModel.currentImage.color(at: CGPoint(x: 50, y: 30))?.usingColorSpace(.deviceRGB))
        let afterFar = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 30))?.usingColorSpace(.deviceRGB))
        let afterContrast = afterLight.redComponent - afterDark.redComponent

        #expect(afterContrast > beforeContrast + 0.04)
        #expect(abs(afterFar.redComponent - beforeFar.redComponent) < 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.sharpen"))
    }

    @MainActor
    @Test func imageEditorSmudgeBrushDragsPixelsAlongStrokeOnly() async throws {
        let image = testBitmapImage(
            size: NSSize(width: 90, height: 60),
            background: .systemBlue,
            fills: [
                (CGRect(x: 0, y: 0, width: 45, height: 60), .systemRed)
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let beforeDragged = try #require(viewModel.currentImage.color(at: CGPoint(x: 56, y: 30))?.usingColorSpace(.deviceRGB))
        let beforeFarBlue = try #require(viewModel.currentImage.color(at: CGPoint(x: 80, y: 30))?.usingColorSpace(.deviceRGB))

        viewModel.brushSize = 18
        viewModel.opacity = 1
        viewModel.smudgeBrush(points: [
            CGPoint(x: 36, y: 30),
            CGPoint(x: 44, y: 30),
            CGPoint(x: 52, y: 30),
            CGPoint(x: 60, y: 30)
        ])

        let dragged = try #require(viewModel.currentImage.color(at: CGPoint(x: 56, y: 30))?.usingColorSpace(.deviceRGB))
        let farBlue = try #require(viewModel.currentImage.color(at: CGPoint(x: 80, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(dragged.redComponent > beforeDragged.redComponent + 0.2)
        #expect(dragged.redComponent > dragged.blueComponent)
        #expect(abs(farBlue.redComponent - beforeFarBlue.redComponent) < 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.smudge"))
    }

    @MainActor
    @Test func imageEditorLayerGroupMaskClipsDescendantLayers() async throws {
        let canvasSize = NSSize(width: 90, height: 60)
        let image = testBitmapImage(size: canvasSize, background: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == firstID })].image = testBitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [(CGRect(x: 0, y: 0, width: 45, height: 60), .systemPink)]
        )

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == secondID })].image = testBitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [(CGRect(x: 45, y: 0, width: 45, height: 60), .systemGreen)]
        )

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 45, y: 60))

        #expect(viewModel.canCreateLayerMaskFromSelection)
        viewModel.addLayerMaskFromSelection()
        let groupLayer = try #require(viewModel.document.layers.first { $0.id == groupID })
        let visibleLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 30))?.usingColorSpace(.deviceRGB))
        let clippedRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 70, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(groupLayer.isGroup)
        #expect(groupLayer.mask?.size == canvasSize)
        #expect(viewModel.selectedLayerHasMask)
        #expect(viewModel.isEditingLayerMask)
        #expect(!viewModel.canApplyLayerMask)
        #expect(visibleLeft.redComponent > visibleLeft.blueComponent + 0.2)
        #expect(clippedRight.blueComponent > clippedRight.greenComponent + 0.2)

        viewModel.invertLayerMask()
        let clippedLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 30))?.usingColorSpace(.deviceRGB))
        let visibleRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 70, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(clippedLeft.blueComponent > clippedLeft.redComponent + 0.2)
        #expect(visibleRight.greenComponent > visibleRight.blueComponent + 0.2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskInvert"))

        viewModel.deleteLayerMask()
        #expect(viewModel.document.layers.first { $0.id == groupID }?.mask == nil)
        #expect(!viewModel.isEditingLayerMask)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskDelete"))
    }

    @MainActor
    @Test func imageEditorLayerGroupBlendModeIsolatesDescendantsBeforeCompositing() async throws {
        let canvasSize = NSSize(width: 90, height: 60)
        let blue = NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.94, alpha: 1)
        let green = NSColor(calibratedRed: 0.04, green: 0.88, blue: 0.12, alpha: 1)
        let image = testBitmapImage(size: canvasSize, background: blue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        let childImage = testBitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [(CGRect(x: 24, y: 18, width: 32, height: 24), green)]
        )
        viewModel.replaceSelectedLayerImageForTesting(childImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let normalInside = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let normalOutside = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.document.selectedLayer?.isGroup == true)

        viewModel.setSelectedLayerBlendMode(.multiply)
        let multipliedInside = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let multipliedOutside = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.first { $0.id == groupID }?.blendMode == .multiply)
        #expect(normalInside.greenComponent > normalInside.blueComponent + 0.25)
        #expect(multipliedInside.greenComponent < normalInside.greenComponent - 0.45)
        #expect(multipliedInside.blueComponent < normalInside.blueComponent - 0.08)
        #expect(abs(multipliedOutside.blueComponent - normalOutside.blueComponent) < 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerBlendMode"))
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
        viewModel.toggleSelectedLayerOuterGlow()
        viewModel.toggleSelectedLayerInnerGlow()
        let layerPixelsAfterStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedWithStyle = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(compositedWithStyle != compositedBeforeStyle)
        #expect(viewModel.selectedLayerHasStroke)
        #expect(viewModel.selectedLayerHasShadow)
        #expect(viewModel.selectedLayerHasOuterGlow)
        #expect(viewModel.selectedLayerHasInnerGlow)

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
        viewModel.setSelectedLayerShadowContour(.soft)
        viewModel.setSelectedLayerInnerShadowOpacity(0.6)
        viewModel.setSelectedLayerInnerShadowBlur(12)
        viewModel.setSelectedLayerInnerShadowChoke(4)
        viewModel.setSelectedLayerInnerShadowNoise(0.35)
        viewModel.setSelectedLayerInnerShadowContour(.cone)
        viewModel.setSelectedLayerOuterGlowOpacity(0.65)
        viewModel.setSelectedLayerOuterGlowBlur(18)
        viewModel.setSelectedLayerOuterGlowSpread(6)
        viewModel.setSelectedLayerOuterGlowNoise(0.4)
        viewModel.setSelectedLayerOuterGlowContour(.steep)
        viewModel.setSelectedLayerInnerGlowOpacity(0.55)
        viewModel.setSelectedLayerInnerGlowBlur(16)
        viewModel.setSelectedLayerInnerGlowChoke(5)
        viewModel.setSelectedLayerInnerGlowNoise(0.45)
        viewModel.setSelectedLayerInnerGlowSource(.center)
        viewModel.setSelectedLayerSatinOpacity(0.5)
        viewModel.setSelectedLayerSatinContour(.ring)
        viewModel.setSelectedLayerSatinInvert(true)
        let styledLayer = try #require(viewModel.document.selectedLayer)

        #expect(styledLayer.style.strokeEnabled)
        #expect(styledLayer.style.shadowEnabled)
        #expect(styledLayer.style.innerShadowEnabled)
        #expect(styledLayer.style.outerGlowEnabled)
        #expect(styledLayer.style.innerGlowEnabled)
        #expect(styledLayer.style.strokeWidth == 9)
        #expect(styledLayer.style.shadowOpacity == 0.7)
        #expect(styledLayer.style.shadowBlur == 14)
        #expect(styledLayer.style.shadowOffset == CGSize(width: 11, height: -12))
        #expect(styledLayer.style.shadowContour == .soft)
        #expect(styledLayer.style.innerShadowOpacity == 0.6)
        #expect(styledLayer.style.innerShadowBlur == 12)
        #expect(styledLayer.style.innerShadowChoke == 4)
        #expect(styledLayer.style.innerShadowNoise == 0.35)
        #expect(styledLayer.style.innerShadowContour == .cone)
        #expect(styledLayer.style.outerGlowOpacity == 0.65)
        #expect(styledLayer.style.outerGlowBlur == 18)
        #expect(styledLayer.style.outerGlowSpread == 6)
        #expect(styledLayer.style.outerGlowNoise == 0.4)
        #expect(styledLayer.style.outerGlowContour == .steep)
        #expect(styledLayer.style.innerGlowOpacity == 0.55)
        #expect(styledLayer.style.innerGlowBlur == 16)
        #expect(styledLayer.style.innerGlowChoke == 5)
        #expect(styledLayer.style.innerGlowNoise == 0.45)
        #expect(styledLayer.style.innerGlowSource == .center)
        #expect(styledLayer.style.satinOpacity == 0.5)
        #expect(styledLayer.style.satinContour == .ring)
        #expect(styledLayer.style.satinInvert)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        viewModel.toggleLayerLock(selectedID)
        viewModel.setSelectedLayerStrokeWidth(18)
        viewModel.setSelectedLayerShadowContour(.ring)
        viewModel.setSelectedLayerInnerShadowChoke(11)
        viewModel.setSelectedLayerInnerShadowNoise(0.85)
        viewModel.setSelectedLayerInnerShadowContour(.soft)
        viewModel.setSelectedLayerOuterGlowSpread(12)
        viewModel.setSelectedLayerOuterGlowNoise(0.9)
        viewModel.setSelectedLayerOuterGlowContour(.ring)
        viewModel.setSelectedLayerInnerGlowChoke(10)
        viewModel.setSelectedLayerInnerGlowNoise(0.95)
        viewModel.setSelectedLayerInnerGlowSource(.edge)
        viewModel.setSelectedLayerSatinContour(.cone)
        viewModel.setSelectedLayerSatinInvert(false)

        #expect(viewModel.document.selectedLayer?.style.strokeWidth == 9)
        #expect(viewModel.document.selectedLayer?.style.shadowContour == .soft)
        #expect(viewModel.document.selectedLayer?.style.innerShadowChoke == 4)
        #expect(viewModel.document.selectedLayer?.style.innerShadowNoise == 0.35)
        #expect(viewModel.document.selectedLayer?.style.innerShadowContour == .cone)
        #expect(viewModel.document.selectedLayer?.style.outerGlowSpread == 6)
        #expect(viewModel.document.selectedLayer?.style.outerGlowNoise == 0.4)
        #expect(viewModel.document.selectedLayer?.style.outerGlowContour == .steep)
        #expect(viewModel.document.selectedLayer?.style.innerGlowChoke == 5)
        #expect(viewModel.document.selectedLayer?.style.innerGlowNoise == 0.45)
        #expect(viewModel.document.selectedLayer?.style.innerGlowSource == .center)
        #expect(viewModel.document.selectedLayer?.style.satinContour == .ring)
        #expect(viewModel.document.selectedLayer?.style.satinInvert == true)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerLocked"))
    }

    @MainActor
    @Test func imageEditorLayerFillOpacityFadesContentButKeepsLayerStyleVisible() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let image = testImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let content = testBitmapImage(
            size: canvasSize,
            background: NSColor(calibratedWhite: 0, alpha: 0),
            fills: [
                (CGRect(x: 28, y: 20, width: 24, height: 20), .systemPink)
            ]
        )

        viewModel.replaceSelectedLayerImageForTesting(
            content,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.setSelectedLayerStrokeWidth(6)
        viewModel.setSelectedLayerFillOpacity(0)
        viewModel.commitSelectedLayerFillOpacityChange()

        let fillHiddenCenter = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let strokeStillVisible = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(viewModel.selectedLayerFillOpacity == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFillOpacity"))
        #expect(fillHiddenCenter.blueComponent > fillHiddenCenter.redComponent)
        #expect(strokeStillVisible.redComponent > 0.75)
        #expect(strokeStillVisible.greenComponent > 0.75)
        #expect(strokeStillVisible.blueComponent > 0.75)

        viewModel.setSelectedLayerOpacity(0)
        let opacityHiddenStroke = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(opacityHiddenStroke.blueComponent > opacityHiddenStroke.redComponent)
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
    @Test func imageEditorLayerGroupsCollapseSelectMembersAndUngroup() async throws {
        let image = testImage(color: .systemTeal, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)

        #expect(viewModel.document.layers.first { $0.id == groupID }?.isGroup == true)
        #expect(viewModel.visibleLayerRows.contains { $0.id == firstID })
        #expect(viewModel.visibleLayerRows.contains { $0.id == secondID })

        viewModel.selectLayer(firstID)
        viewModel.toggleLayerGroupExpansion(groupID)
        #expect(viewModel.document.layers.first { $0.id == groupID }?.isGroupExpanded == false)
        #expect(viewModel.document.selectedLayerID == groupID)
        #expect(viewModel.visibleLayerRows.contains { $0.id == groupID })
        #expect(!viewModel.visibleLayerRows.contains { $0.id == firstID })
        #expect(!viewModel.visibleLayerRows.contains { $0.id == secondID })

        viewModel.toggleLayerGroupExpansion(groupID)
        viewModel.selectLayer(firstID)
        #expect(viewModel.canSelectParentGroup)
        viewModel.selectParentGroup()
        #expect(viewModel.document.selectedLayerID == groupID)
        #expect(viewModel.document.selectedLayerIDs == [groupID])
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerParentGroupSelected", viewModel.document.selectedLayer?.name ?? ""))

        #expect(viewModel.canSelectSelectedGroupMembers)
        viewModel.selectSelectedGroupMembers()
        #expect(viewModel.selectedLayerCount == 2)
        #expect(viewModel.isLayerSelected(firstID))
        #expect(viewModel.isLayerSelected(secondID))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerGroupMembersSelected", 2))

        viewModel.selectLayer(groupID)
        #expect(viewModel.canUngroupSelectedLayers)
        viewModel.ungroupSelectedLayers()
        #expect(viewModel.document.layers.contains { $0.id == groupID } == false)
        #expect(viewModel.document.layers.first { $0.id == firstID }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.groupID == nil)
        #expect(viewModel.selectedLayerCount == 2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerUngroup"))

        viewModel.undo()
        #expect(viewModel.document.layers.contains { $0.id == groupID })
        #expect(viewModel.document.layers.first { $0.id == firstID }?.groupID == groupID)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.groupID == groupID)
    }

    @MainActor
    @Test func imageEditorMovesSelectedLayersIntoAndOutOfGroups() async throws {
        let image = testImage(color: .systemCyan, size: NSSize(width: 90, height: 70))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayerGroup()
        let groupID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        #expect(viewModel.canMoveSelectedLayersIntoGroup)
        #expect(!viewModel.canMoveSelectedLayersOutOfGroup)

        viewModel.moveSelectedLayersIntoGroup()
        #expect(viewModel.document.layers.first { $0.id == firstID }?.groupID == groupID)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.groupID == groupID)
        #expect(viewModel.document.layers.first { $0.id == groupID }?.isGroupExpanded == true)
        #expect(viewModel.document.selectedLayerIDs == Set([firstID, secondID]))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMoveIntoGroup"))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == firstID }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.groupID == nil)
        #expect(viewModel.document.selectedLayerIDs == Set([firstID, secondID]))

        viewModel.moveSelectedLayersIntoGroup()
        #expect(viewModel.canMoveSelectedLayersOutOfGroup)
        viewModel.moveSelectedLayersOutOfGroup()
        #expect(viewModel.document.layers.first { $0.id == firstID }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == secondID }?.groupID == nil)
        #expect(viewModel.document.selectedLayerIDs == Set([firstID, secondID]))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMoveOutOfGroup"))
    }

    @MainActor
    @Test func imageEditorNewLayersInheritSelectedGroupContext() async throws {
        let image = testImage(color: .systemMint, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayerGroup()
        let groupID = try #require(viewModel.document.selectedLayerID)
        let groupIndexBeforeChild = try #require(viewModel.document.layers.firstIndex { $0.id == groupID })

        viewModel.addLayer()
        let childID = try #require(viewModel.document.selectedLayerID)
        let childIndex = try #require(viewModel.document.layers.firstIndex { $0.id == childID })
        let groupIndexAfterChild = try #require(viewModel.document.layers.firstIndex { $0.id == groupID })
        #expect(viewModel.document.layers[childIndex].groupID == groupID)
        #expect(childIndex == groupIndexBeforeChild)
        #expect(groupIndexAfterChild == groupIndexBeforeChild + 1)
        #expect(viewModel.document.layers[groupIndexAfterChild].isGroupExpanded)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerNew"))

        viewModel.addLayerGroup()
        let nestedGroupID = try #require(viewModel.document.selectedLayerID)
        let nestedGroup = try #require(viewModel.document.layers.first { $0.id == nestedGroupID })
        #expect(nestedGroup.isGroup)
        #expect(nestedGroup.groupID == groupID)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGroupNew"))

        viewModel.undo()
        #expect(!viewModel.document.layers.contains { $0.id == nestedGroupID })
        #expect(viewModel.document.selectedLayerID == childID)
        #expect(viewModel.document.layers.first { $0.id == childID }?.groupID == groupID)
    }

    @MainActor
    @Test func imageEditorDragReordersLayersAcrossGroups() async throws {
        let image = testImage(color: .systemTeal, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let editID = try #require(viewModel.document.selectedLayerID)

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayerGroup()
        let groupID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        let movedIntoGroup = viewModel.moveLayerIDs(
            viewModel.layerDragSourceIDs(for: firstID),
            toDropTarget: ImageEditorLayerDropTarget(layerID: groupID, placement: .insideGroup)
        )
        let firstIndexInGroup = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        let groupIndex = try #require(viewModel.document.layers.firstIndex { $0.id == groupID })
        #expect(movedIntoGroup)
        #expect(viewModel.document.layers[firstIndexInGroup].groupID == groupID)
        #expect(firstIndexInGroup < groupIndex)
        #expect(viewModel.document.layers[groupIndex].isGroupExpanded)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerReorder"))

        let movedOutAboveEdit = viewModel.moveLayerIDs(
            [firstID],
            toDropTarget: ImageEditorLayerDropTarget(layerID: editID, placement: .above)
        )
        let firstIndexAfterMoveOut = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        let editIndex = try #require(viewModel.document.layers.firstIndex { $0.id == editID })
        #expect(movedOutAboveEdit)
        #expect(viewModel.document.layers[firstIndexAfterMoveOut].groupID == nil)
        #expect(firstIndexAfterMoveOut == editIndex + 1)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerReordered"))

        viewModel.selectLayer(groupID)
        viewModel.addLayerGroup()
        let nestedGroupID = try #require(viewModel.document.selectedLayerID)
        let originalOrder = viewModel.document.layers.map(\.id)
        let rejectedCycle = viewModel.moveLayerIDs(
            [groupID],
            toDropTarget: ImageEditorLayerDropTarget(layerID: nestedGroupID, placement: .insideGroup)
        )
        #expect(!rejectedCycle)
        #expect(viewModel.document.layers.map(\.id) == originalOrder)

        viewModel.selectLayer(secondID)
        #expect(viewModel.layerDragSourceIDs(for: firstID) == Set([firstID]))
    }

    @MainActor
    @Test func imageEditorFiltersVisibleLayerRowsByName() async throws {
        let image = testImage(color: .systemBlue, size: NSSize(width: 96, height: 72))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.renameSelectedLayer(to: "Retouch Highlights")
        let retouchID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        viewModel.renameSelectedLayer(to: "Shadow Cleanup")
        let shadowID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayerGroup()
        viewModel.renameSelectedLayer(to: "Reference Group")
        let groupID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        viewModel.renameSelectedLayer(to: "Reference Hidden Detail")
        let hiddenDetailID = try #require(viewModel.document.selectedLayerID)

        #expect(viewModel.visibleLayerRows(matching: "retouch").map(\.id) == [retouchID])
        #expect(viewModel.visibleLayerRows(matching: " SHADOW ").map(\.id) == [shadowID])
        #expect(viewModel.visibleLayerRows(matching: "").count == viewModel.visibleLayerRows.count)

        viewModel.toggleLayerGroupExpansion(groupID)
        let referenceMatches = viewModel.visibleLayerRows(matching: "reference").map(\.id)
        #expect(referenceMatches.contains(groupID))
        #expect(!referenceMatches.contains(hiddenDetailID))
    }

    @MainActor
    @Test func imageEditorLayerGroupsDuplicateAndTransformMembers() async throws {
        let image = testImage(color: .systemIndigo, size: NSSize(width: 160, height: 120))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == firstID })].frame = CGRect(x: 10, y: 12, width: 20, height: 14)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == secondID })].frame = CGRect(x: 40, y: 24, width: 24, height: 18)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)

        viewModel.duplicateSelectedLayer()
        let duplicateGroupID = try #require(viewModel.document.selectedLayerID)
        let duplicateGroup = try #require(viewModel.document.layers.first { $0.id == duplicateGroupID })
        let duplicateMembers = viewModel.document.layers.filter { $0.groupID == duplicateGroupID }

        #expect(duplicateGroup.isGroup)
        #expect(duplicateGroupID != groupID)
        #expect(duplicateMembers.count == 2)
        #expect(duplicateMembers.allSatisfy { $0.id != firstID && $0.id != secondID })
        #expect(viewModel.document.layers.filter { $0.groupID == groupID }.count == 2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDuplicate"))

        viewModel.selectLayer(groupID)
        #expect(viewModel.canResizeSelectedLayer)
        let firstFrameBeforeMove = try #require(viewModel.document.layers.first { $0.id == firstID }?.frame)
        let secondFrameBeforeMove = try #require(viewModel.document.layers.first { $0.id == secondID }?.frame)
        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 8, height: -5))
        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.document.layers.first { $0.id == firstID }?.frame.origin == CGPoint(x: firstFrameBeforeMove.minX + 8, y: firstFrameBeforeMove.minY - 5))
        #expect(viewModel.document.layers.first { $0.id == secondID }?.frame.origin == CGPoint(x: secondFrameBeforeMove.minX + 8, y: secondFrameBeforeMove.minY - 5))

        let firstFrameBeforeScale = try #require(viewModel.document.layers.first { $0.id == firstID }?.frame)
        let secondFrameBeforeScale = try #require(viewModel.document.layers.first { $0.id == secondID }?.frame)
        viewModel.scaleSelectedLayer(by: 1.5)
        let firstFrameAfterScale = try #require(viewModel.document.layers.first { $0.id == firstID }?.frame)
        let secondFrameAfterScale = try #require(viewModel.document.layers.first { $0.id == secondID }?.frame)
        #expect(firstFrameAfterScale.width > firstFrameBeforeScale.width)
        #expect(secondFrameAfterScale.width > secondFrameBeforeScale.width)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerScale"))
    }

    @MainActor
    @Test func imageEditorNestedLayerGroupsInheritAndDuplicateHierarchy() async throws {
        let image = testImage(color: .systemPurple, size: NSSize(width: 180, height: 140))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == firstID })].frame = CGRect(x: 10, y: 12, width: 20, height: 14)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == secondID })].frame = CGRect(x: 38, y: 20, width: 24, height: 18)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.groupSelectedLayer()
        let childGroupID = try #require(viewModel.document.selectedLayerID)

        viewModel.addLayer()
        let thirdID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.layers.firstIndex { $0.id == thirdID })].frame = CGRect(x: 70, y: 32, width: 18, height: 16)

        viewModel.selectLayer(childGroupID)
        viewModel.selectLayer(thirdID, extendingSelection: true)
        #expect(viewModel.canGroupSelectedLayer)
        viewModel.groupSelectedLayer()
        let parentGroupID = try #require(viewModel.document.selectedLayerID)

        #expect(viewModel.document.layers.first { $0.id == childGroupID }?.groupID == parentGroupID)
        #expect(viewModel.document.layers.first { $0.id == thirdID }?.groupID == parentGroupID)
        #expect(viewModel.document.layers.first { $0.id == firstID }?.groupID == childGroupID)
        #expect(viewModel.document.groupDepth(for: try #require(viewModel.document.layers.first { $0.id == firstID })) == 2)

        viewModel.toggleLayerGroupExpansion(parentGroupID)
        #expect(viewModel.visibleLayerRows.contains { $0.id == parentGroupID })
        #expect(!viewModel.visibleLayerRows.contains { $0.id == childGroupID })
        #expect(!viewModel.visibleLayerRows.contains { $0.id == firstID })
        #expect(!viewModel.visibleLayerRows.contains { $0.id == thirdID })
        viewModel.toggleLayerGroupExpansion(parentGroupID)

        viewModel.duplicateSelectedLayer()
        let duplicateParentID = try #require(viewModel.document.selectedLayerID)
        let duplicateParent = try #require(viewModel.document.layers.first { $0.id == duplicateParentID })
        let duplicateChildGroups = viewModel.document.layers.filter { $0.groupID == duplicateParentID && $0.isGroup }
        let duplicateLooseMembers = viewModel.document.layers.filter { $0.groupID == duplicateParentID && !$0.isGroup }
        let duplicateChildGroup = try #require(duplicateChildGroups.first)

        #expect(duplicateParent.isGroup)
        #expect(duplicateChildGroups.count == 1)
        #expect(duplicateLooseMembers.count == 1)
        #expect(viewModel.document.layers.filter { $0.groupID == duplicateChildGroup.id && !$0.isGroup }.count == 2)

        viewModel.selectLayer(parentGroupID)
        let firstFrameBeforeMove = try #require(viewModel.document.layers.first { $0.id == firstID }?.frame)
        let thirdFrameBeforeMove = try #require(viewModel.document.layers.first { $0.id == thirdID }?.frame)
        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 11, height: 7))
        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.document.layers.first { $0.id == firstID }?.frame.origin == CGPoint(x: firstFrameBeforeMove.minX + 11, y: firstFrameBeforeMove.minY + 7))
        #expect(viewModel.document.layers.first { $0.id == thirdID }?.frame.origin == CGPoint(x: thirdFrameBeforeMove.minX + 11, y: thirdFrameBeforeMove.minY + 7))

        viewModel.ungroupSelectedLayers()
        #expect(!viewModel.document.layers.contains { $0.id == parentGroupID })
        #expect(viewModel.document.layers.first { $0.id == childGroupID }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == thirdID }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == firstID }?.groupID == childGroupID)
    }

    @MainActor
    @Test func imageEditorCanIsolateSelectedLayersAndShowAllLayers() async throws {
        let image = testImage(color: .systemIndigo, size: NSSize(width: 160, height: 120))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let backgroundID = try #require(viewModel.document.layers.first?.id)

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let outsideID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        #expect(viewModel.canIsolateSelectedLayers)
        viewModel.isolateSelectedLayers()
        #expect(!isLayerVisible(backgroundID, in: viewModel))
        #expect(isLayerVisible(groupID, in: viewModel))
        #expect(isLayerVisible(firstID, in: viewModel))
        #expect(!isLayerVisible(secondID, in: viewModel))
        #expect(!isLayerVisible(outsideID, in: viewModel))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerIsolateSelected", 1))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerIsolateSelected"))

        #expect(viewModel.canShowAllLayers)
        viewModel.showAllLayers()
        let allLayersVisible = viewModel.document.layers.allSatisfy { $0.isVisible }
        #expect(allLayersVisible)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerShowAll"))

        viewModel.undo()
        #expect(isLayerVisible(groupID, in: viewModel))
        #expect(isLayerVisible(firstID, in: viewModel))
        #expect(!isLayerVisible(secondID, in: viewModel))
        #expect(!isLayerVisible(outsideID, in: viewModel))

        viewModel.showAllLayers()
        viewModel.selectLayer(groupID)
        #expect(viewModel.canIsolateSelectedLayers)
        viewModel.isolateSelectedLayers()
        #expect(isLayerVisible(groupID, in: viewModel))
        #expect(isLayerVisible(firstID, in: viewModel))
        #expect(isLayerVisible(secondID, in: viewModel))
        #expect(!isLayerVisible(outsideID, in: viewModel))
    }

    @MainActor
    @Test func imageEditorCanShowAndHideSelectedLayersInBatch() async throws {
        let image = testImage(color: .systemIndigo, size: NSSize(width: 160, height: 120))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let backgroundID = try #require(viewModel.document.layers.first?.id)

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)

        #expect(viewModel.canHideSelectedLayers)
        #expect(!viewModel.canShowSelectedLayers)
        viewModel.hideSelectedLayers()

        #expect(isLayerVisible(backgroundID, in: viewModel))
        #expect(!isLayerVisible(firstID, in: viewModel))
        #expect(!isLayerVisible(secondID, in: viewModel))
        #expect(!viewModel.canHideSelectedLayers)
        #expect(viewModel.canShowSelectedLayers)
        #expect(viewModel.document.selectedLayerIDs == Set([firstID, secondID]))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerHideSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerHideSelected", 2))

        viewModel.showSelectedLayers()

        #expect(isLayerVisible(firstID, in: viewModel))
        #expect(isLayerVisible(secondID, in: viewModel))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerShowSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerShowSelected", 2))

        viewModel.undo()
        #expect(!isLayerVisible(firstID, in: viewModel))
        #expect(!isLayerVisible(secondID, in: viewModel))

        viewModel.undo()
        #expect(isLayerVisible(firstID, in: viewModel))
        #expect(isLayerVisible(secondID, in: viewModel))
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
    @Test func imageEditorClippedAdjustmentLayerTargetsBaseAlphaAndMergeMatchesPreview() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let background = testBitmapImage(size: canvasSize, background: .black)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: background) { _ in }
        let baseImage = testBitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [(CGRect(x: 24, y: 18, width: 32, height: 24), NSColor(calibratedRed: 0.32, green: 0.32, blue: 0.32, alpha: 1))]
        )
        viewModel.replaceSelectedLayerImageForTesting(baseImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectedAdjustment = .brightness
        viewModel.adjustmentValue = 0.45
        viewModel.addAdjustmentLayer()
        #expect(viewModel.document.selectedLayer?.isAdjustment == true)
        #expect(viewModel.canToggleSelectedLayerClippingMask)
        viewModel.toggleSelectedLayerClippingMask()

        let clippedLayer = try #require(viewModel.document.selectedLayer)
        let outsidePreview = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        let insidePreview = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(clippedLayer.isClippingMask)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(outsidePreview.redComponent < 0.05)
        #expect(insidePreview.redComponent > 0.62)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerClippingMask"))

        let previewData = try #require(viewModel.currentImage.qingtuPNGData())
        let countBeforeMerge = viewModel.document.layers.count
        viewModel.mergeSelectedLayerDown()
        let mergedLayer = try #require(viewModel.document.selectedLayer)
        let mergedOutside = try #require(mergedLayer.image.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        let mergedInside = try #require(mergedLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.document.layers.count == countBeforeMerge - 1)
        #expect(!mergedLayer.isAdjustment)
        #expect(!viewModel.selectedLayerIsClippingMask)
        #expect(mergedOutside.alphaComponent < 0.05)
        #expect(mergedInside.redComponent > 0.62)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == previewData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeDown"))
    }

    @MainActor
    @Test func imageEditorAdditionalAdjustmentsSupportPixelApplyAndLayers() async throws {
        let image = testBitmapImage(
            size: NSSize(width: 80, height: 60),
            background: NSColor(calibratedRed: 0.25, green: 0.25, blue: 0.25, alpha: 1),
            fills: [
                (CGRect(x: 40, y: 0, width: 40, height: 60), NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.8, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectedAdjustment = .invert
        viewModel.applyAdjustment()
        let inverted = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(inverted.redComponent > 0.68)

        viewModel.undo()
        viewModel.selectedAdjustment = .threshold
        viewModel.adjustmentValue = 0
        viewModel.applyAdjustment()
        let darkThreshold = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        let lightThreshold = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 60, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(darkThreshold.redComponent < 0.1)
        #expect(lightThreshold.redComponent > 0.9)

        viewModel.undo()
        let beforeExposure = try #require(viewModel.currentImage.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        viewModel.selectedAdjustment = .exposure
        viewModel.adjustmentValue = 0.5
        viewModel.addAdjustmentLayer()
        let afterExposure = try #require(viewModel.currentImage.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(viewModel.document.selectedLayer?.adjustment?.kind == .exposure)
        #expect(afterExposure.redComponent > beforeExposure.redComponent + 0.18)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @MainActor
    @Test func imageEditorAutoLevelsStretchesSelectedLayerChannels() async throws {
        let image = testBitmapImage(
            size: NSSize(width: 80, height: 60),
            background: NSColor(calibratedRed: 0.20, green: 0.30, blue: 0.40, alpha: 1),
            fills: [
                (CGRect(x: 40, y: 0, width: 40, height: 60), NSColor(calibratedRed: 0.60, green: 0.70, blue: 0.80, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        #expect(viewModel.canAutoLevelsSelectedLayer)
        viewModel.autoLevelsSelectedLayer()

        let dark = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        let light = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 60, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(dark.redComponent < 0.04)
        #expect(dark.greenComponent < 0.04)
        #expect(dark.blueComponent < 0.04)
        #expect(light.redComponent > 0.95)
        #expect(light.greenComponent > 0.95)
        #expect(light.blueComponent > 0.95)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.autoLevels"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.autoLevels"))
    }

    @MainActor
    @Test func imageEditorAutoContrastStretchesSelectedLayerLuminance() async throws {
        let image = testBitmapImage(
            size: NSSize(width: 80, height: 60),
            background: NSColor(calibratedWhite: 0.35, alpha: 1),
            fills: [
                (CGRect(x: 40, y: 0, width: 40, height: 60), NSColor(calibratedWhite: 0.65, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        #expect(viewModel.canAutoContrastSelectedLayer)
        viewModel.autoContrastSelectedLayer()

        let dark = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        let light = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 60, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(dark.redComponent < 0.04)
        #expect(dark.greenComponent < 0.04)
        #expect(dark.blueComponent < 0.04)
        #expect(light.redComponent > 0.95)
        #expect(light.greenComponent > 0.95)
        #expect(light.blueComponent > 0.95)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.autoContrast"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.autoContrast"))
    }

    @MainActor
    @Test func imageEditorAutoColorReducesSelectedLayerColorCast() async throws {
        let image = testBitmapImage(
            size: NSSize(width: 80, height: 60),
            background: NSColor(calibratedRed: 0.72, green: 0.28, blue: 0.28, alpha: 1),
            fills: [
                (CGRect(x: 40, y: 0, width: 40, height: 60), NSColor(calibratedRed: 0.84, green: 0.38, blue: 0.38, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let before = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        let beforeCast = before.redComponent - ((before.greenComponent + before.blueComponent) / 2)

        #expect(viewModel.canAutoColorSelectedLayer)
        viewModel.autoColorSelectedLayer()

        let after = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        let afterCast = abs(after.redComponent - ((after.greenComponent + after.blueComponent) / 2))
        #expect(afterCast < beforeCast * 0.45)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.autoColor"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.autoColor"))
    }

    @MainActor
    @Test func imageEditorLevelsAdjustmentSupportsThreeParametersAndLayerState() async throws {
        let image = testBitmapImage(
            size: NSSize(width: 90, height: 60),
            background: NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.18, alpha: 1),
            fills: [
                (CGRect(x: 30, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0.48, green: 0.48, blue: 0.48, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.82, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectedAdjustment = .levels
        viewModel.levelsBlackPoint = 0.25
        viewModel.levelsGamma = 0.55
        viewModel.levelsWhitePoint = 0.78
        viewModel.applyAdjustment()
        let dark = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        let mid = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        let light = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(dark.redComponent < 0.04)
        #expect(mid.redComponent > 0.55)
        #expect(light.redComponent > 0.95)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .levels
        viewModel.levelsBlackPoint = 0.20
        viewModel.levelsGamma = 0.70
        viewModel.levelsWhitePoint = 0.80
        viewModel.addAdjustmentLayer()
        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let leveledLight = try #require(viewModel.currentImage.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .levels)
        #expect(settings.levelsBlackPoint == 0.20)
        #expect(settings.levelsGamma == 0.70)
        #expect(settings.levelsWhitePoint == 0.80)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(leveledLight.redComponent > 0.95)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @MainActor
    @Test func imageEditorCurvesAdjustmentSupportsToneCurveAndLayerState() async throws {
        let image = testBitmapImage(
            size: NSSize(width: 90, height: 60),
            background: NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 1),
            fills: [
                (CGRect(x: 30, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.50, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.82, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectedAdjustment = .curves
        viewModel.curvesShadows = 0.60
        viewModel.curvesMidtones = 0.20
        viewModel.curvesHighlights = -0.50
        viewModel.applyAdjustment()
        let liftedShadow = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        let liftedMidtone = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        let compressedHighlight = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(liftedShadow.redComponent > 0.34)
        #expect(liftedMidtone.redComponent > 0.55)
        #expect(compressedHighlight.redComponent < 0.78)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .curves
        viewModel.curvesShadows = -0.40
        viewModel.curvesMidtones = 0.30
        viewModel.curvesHighlights = 0.20
        viewModel.addAdjustmentLayer()
        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let adjustedMidtone = try #require(viewModel.currentImage.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .curves)
        #expect(settings.curvesShadows == -0.40)
        #expect(settings.curvesMidtones == 0.30)
        #expect(settings.curvesHighlights == 0.20)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(adjustedMidtone.redComponent > 0.58)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    @MainActor
    @Test func imageEditorColorBalanceAdjustmentSupportsToneRangesAndLayerState() async throws {
        let image = testBitmapImage(
            size: NSSize(width: 90, height: 60),
            background: NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 1),
            fills: [
                (CGRect(x: 30, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.50, alpha: 1)),
                (CGRect(x: 60, y: 0, width: 30, height: 60), NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.82, alpha: 1))
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.selectedAdjustment = .colorBalance
        viewModel.colorBalanceShadowsCyanRed = 0.70
        viewModel.colorBalanceMidtonesMagentaGreen = 0.70
        viewModel.colorBalanceHighlightsYellowBlue = 0.70
        viewModel.applyAdjustment()
        let shiftedShadow = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 30))?.usingColorSpace(.deviceRGB))
        let shiftedMidtone = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))
        let shiftedHighlight = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 75, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(shiftedShadow.redComponent > 0.30)
        #expect(shiftedMidtone.greenComponent > 0.62)
        #expect(shiftedHighlight.blueComponent > 0.90)

        viewModel.undo()
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.selectedAdjustment = .colorBalance
        viewModel.colorBalanceShadowsCyanRed = -0.35
        viewModel.colorBalanceShadowsMagentaGreen = 0.20
        viewModel.colorBalanceMidtonesCyanRed = 0.45
        viewModel.colorBalanceMidtonesMagentaGreen = -0.25
        viewModel.colorBalanceMidtonesYellowBlue = 0.30
        viewModel.colorBalanceHighlightsYellowBlue = 0.55
        viewModel.addAdjustmentLayer()
        let adjustmentLayer = try #require(viewModel.document.selectedLayer)
        let settings = adjustmentLayer.adjustmentSettings.normalized()
        let adjustedMidtone = try #require(viewModel.currentImage.color(at: CGPoint(x: 45, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(adjustmentLayer.adjustment?.kind == .colorBalance)
        #expect(settings.colorBalanceShadowsCyanRed == -0.35)
        #expect(settings.colorBalanceShadowsMagentaGreen == 0.20)
        #expect(settings.colorBalanceMidtonesCyanRed == 0.45)
        #expect(settings.colorBalanceMidtonesMagentaGreen == -0.25)
        #expect(settings.colorBalanceMidtonesYellowBlue == 0.30)
        #expect(settings.colorBalanceHighlightsYellowBlue == 0.55)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(adjustedMidtone.redComponent > 0.58)
        #expect(adjustedMidtone.greenComponent < 0.48)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAdjustmentNew"))
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
    @Test func imageEditorSmartFilterStackIsNonDestructiveAndBakesOnRasterizeAndMerge() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let black = NSColor(calibratedWhite: 0, alpha: 1)
        let white = NSColor(calibratedWhite: 1, alpha: 1)
        let background = testBitmapImage(size: canvasSize, background: black)
        let edgeImage = testBitmapImage(
            size: canvasSize,
            background: black,
            fills: [(CGRect(x: 40, y: 0, width: 40, height: 60), white)]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: background) { _ in }

        viewModel.replaceSelectedLayerImageForTesting(edgeImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedBefore = try #require(viewModel.currentImage.qingtuPNGData())
        let beforeBlackSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 39, y: 30))?.usingColorSpace(.deviceRGB))
        let beforeWhiteSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 41, y: 30))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.9
        #expect(viewModel.canAddSmartFilterToSelectedLayer)
        viewModel.addSmartFilterToSelectedLayer()

        var filteredLayer = try #require(viewModel.document.selectedLayer)
        let afterBlackSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 39, y: 30))?.usingColorSpace(.deviceRGB))
        let afterWhiteSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 41, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(filteredLayer.id == baseLayerID)
        #expect(!filteredLayer.isFilter)
        #expect(filteredLayer.smartFilters.count == 1)
        #expect(filteredLayer.image.qingtuPNGData() == basePixelsBefore)
        #expect(afterBlackSide.redComponent > beforeBlackSide.redComponent + 0.08)
        #expect(afterWhiteSide.redComponent < beforeWhiteSide.redComponent - 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        viewModel.filterIntensity = 0.35
        viewModel.updateLastSmartFilterOnSelectedLayer()
        filteredLayer = try #require(viewModel.document.selectedLayer)
        let firstFilterID = try #require(filteredLayer.smartFilters.last?.id)
        #expect(filteredLayer.smartFilters.last?.intensity == 0.35)
        #expect(filteredLayer.image.qingtuPNGData() == basePixelsBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterUpdate"))

        viewModel.toggleSmartFilterOnSelectedLayer(firstFilterID)
        filteredLayer = try #require(viewModel.document.selectedLayer)
        #expect(filteredLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterToggle"))

        viewModel.toggleSmartFilterOnSelectedLayer(firstFilterID)
        filteredLayer = try #require(viewModel.document.selectedLayer)
        #expect(filteredLayer.smartFilters.first?.isEnabled == true)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) != compositedBefore)

        viewModel.selectedFilter = .sharpen
        viewModel.filterIntensity = 0.5
        viewModel.addSmartFilterToSelectedLayer()
        filteredLayer = try #require(viewModel.document.selectedLayer)
        let secondFilterID = try #require(filteredLayer.smartFilters.last?.id)
        #expect(filteredLayer.smartFilters.map(\.id) == [firstFilterID, secondFilterID])

        viewModel.moveSmartFilterOnSelectedLayer(firstFilterID, offset: 1)
        filteredLayer = try #require(viewModel.document.selectedLayer)
        #expect(filteredLayer.smartFilters.map(\.id) == [secondFilterID, firstFilterID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterMove"))

        viewModel.removeSmartFilterFromSelectedLayer(secondFilterID)
        filteredLayer = try #require(viewModel.document.selectedLayer)
        #expect(filteredLayer.smartFilters.map(\.id) == [firstFilterID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterRemove"))

        viewModel.clearSmartFiltersFromSelectedLayer()
        filteredLayer = try #require(viewModel.document.selectedLayer)
        #expect(filteredLayer.smartFilters.isEmpty)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterClear"))

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.9
        viewModel.addSmartFilterToSelectedLayer()
        let compositedBeforeRasterize = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(viewModel.canRasterizeSelectedLayer)
        viewModel.rasterizeSelectedLayer()

        let rasterizedLayer = try #require(viewModel.document.selectedLayer)
        #expect(rasterizedLayer.smartFilters.isEmpty)
        #expect(!rasterizedLayer.isFilter)
        #expect(rasterizedLayer.image.qingtuPNGData() != basePixelsBefore)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositedBeforeRasterize)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRasterize"))

        let mergeViewModel = ImageEditorViewModel(sourceName: "source.png", image: background) { _ in }
        mergeViewModel.replaceSelectedLayerImageForTesting(edgeImage, historyTitle: L10n.text("imageEditor.history.brush"))
        mergeViewModel.selectedFilter = .gaussianBlur
        mergeViewModel.filterIntensity = 0.9
        mergeViewModel.addSmartFilterToSelectedLayer()
        let compositedBeforeMerge = try #require(mergeViewModel.currentImage.qingtuPNGData())
        let countBeforeMerge = mergeViewModel.document.layers.count

        mergeViewModel.mergeSelectedLayerDown()
        let mergedLayer = try #require(mergeViewModel.document.selectedLayer)
        #expect(mergeViewModel.document.layers.count == countBeforeMerge - 1)
        #expect(mergedLayer.smartFilters.isEmpty)
        #expect(!mergedLayer.isFilter)
        #expect(mergedLayer.image.qingtuPNGData() == compositedBeforeMerge)
        #expect(try #require(mergeViewModel.currentImage.qingtuPNGData()) == compositedBeforeMerge)
        #expect(mergeViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeDown"))
    }

    @MainActor
    @Test func imageEditorClippedFilterLayerTargetsBaseAlpha() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let background = NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.92, alpha: 1)
        let image = testBitmapImage(size: canvasSize, background: background)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let baseImage = testBitmapImage(
            size: canvasSize,
            background: .clear,
            fills: [
                (CGRect(x: 20, y: 18, width: 20, height: 24), .white),
                (CGRect(x: 40, y: 18, width: 20, height: 24), .black)
            ]
        )
        viewModel.replaceSelectedLayerImageForTesting(baseImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let beforeInsideLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 38, y: 30))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.9
        viewModel.addFilterLayer()
        #expect(viewModel.document.selectedLayer?.isFilter == true)
        #expect(viewModel.canToggleSelectedLayerClippingMask)
        viewModel.toggleSelectedLayerClippingMask()

        let clippedFilter = try #require(viewModel.document.selectedLayer)
        let outsidePreview = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        let afterInsideLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 38, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(clippedFilter.isClippingMask)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == baseImage.qingtuPNGData())
        #expect(outsidePreview.blueComponent > 0.80)
        #expect(outsidePreview.redComponent < 0.08)
        #expect(afterInsideLeft.redComponent < beforeInsideLeft.redComponent - 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerClippingMask"))
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
    @Test func imageEditorCreatesAndReleasesClippingMasksForSelectedLayers() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let blue = NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.94, alpha: 1)
        let pink = NSColor(calibratedRed: 0.95, green: 0.05, blue: 0.52, alpha: 1)
        let green = NSColor(calibratedRed: 0.04, green: 0.88, blue: 0.12, alpha: 1)
        let yellow = NSColor(calibratedRed: 0.98, green: 0.86, blue: 0.08, alpha: 1)
        let image = testBitmapImage(size: canvasSize, background: blue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(
                size: canvasSize,
                background: .clear,
                fills: [(CGRect(x: 24, y: 18, width: 32, height: 24), pink)]
            ),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let baseID = try #require(viewModel.document.selectedLayerID)

        viewModel.addLayer()
        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: green),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let firstClipID = try #require(viewModel.document.selectedLayerID)

        viewModel.addLayer()
        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: yellow),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let secondClipID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstClipID)
        viewModel.selectLayer(secondClipID, extendingSelection: true)

        #expect(viewModel.canCreateClippingMasksForSelectedLayers)
        viewModel.createClippingMasksForSelectedLayers()

        let clippedFirst = try #require(viewModel.document.layers.first { $0.id == firstClipID })
        let clippedSecond = try #require(viewModel.document.layers.first { $0.id == secondClipID })
        let baseLayer = try #require(viewModel.document.layers.first { $0.id == baseID })
        let outsideClipped = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))
        let insideClipped = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 31))?.usingColorSpace(.deviceRGB))

        #expect(clippedFirst.isClippingMask)
        #expect(clippedSecond.isClippingMask)
        #expect(!baseLayer.isClippingMask)
        #expect(outsideClipped.blueComponent > outsideClipped.greenComponent + 0.15)
        #expect(insideClipped.redComponent > insideClipped.blueComponent + 0.15)
        #expect(insideClipped.greenComponent > insideClipped.blueComponent + 0.15)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerClippingMaskCreateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerClippingMaskCreatedSelected", 2))

        #expect(viewModel.canReleaseSelectedClippingMasks)
        viewModel.releaseSelectedClippingMasks()

        let releasedFirst = try #require(viewModel.document.layers.first { $0.id == firstClipID })
        let releasedSecond = try #require(viewModel.document.layers.first { $0.id == secondClipID })
        let outsideReleased = try #require(viewModel.currentImage.color(at: CGPoint(x: 8, y: 8))?.usingColorSpace(.deviceRGB))

        #expect(!releasedFirst.isClippingMask)
        #expect(!releasedSecond.isClippingMask)
        #expect(outsideReleased.redComponent > outsideReleased.blueComponent + 0.15)
        #expect(outsideReleased.greenComponent > outsideReleased.blueComponent + 0.15)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerClippingMaskReleaseSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerClippingMaskReleasedSelected", 2))
    }

    @MainActor
    @Test func imageEditorGroupingClippedLayerAloneClearsOrphanClippingMask() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let blue = NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.94, alpha: 1)
        let pink = NSColor(calibratedRed: 0.95, green: 0.05, blue: 0.52, alpha: 1)
        let green = NSColor(calibratedRed: 0.04, green: 0.88, blue: 0.12, alpha: 1)
        let image = testBitmapImage(size: canvasSize, background: blue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(
                size: canvasSize,
                background: .clear,
                fills: [(CGRect(x: 24, y: 18, width: 32, height: 24), pink)]
            ),
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        viewModel.addLayer()
        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: green),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let clippedLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleSelectedLayerClippingMask()
        #expect(viewModel.document.layers.first { $0.id == clippedLayerID }?.isClippingMask == true)

        viewModel.groupSelectedLayer()

        let groupedLayer = try #require(viewModel.document.layers.first { $0.id == clippedLayerID })
        #expect(groupedLayer.groupID != nil)
        #expect(!groupedLayer.isClippingMask)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGroupSelected"))
    }

    @MainActor
    @Test func imageEditorMovingClippedLayerBelowBaseClearsOrphanClippingMask() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let blue = NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.94, alpha: 1)
        let pink = NSColor(calibratedRed: 0.95, green: 0.05, blue: 0.52, alpha: 1)
        let green = NSColor(calibratedRed: 0.04, green: 0.88, blue: 0.12, alpha: 1)
        let image = testBitmapImage(size: canvasSize, background: blue)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(
                size: canvasSize,
                background: .clear,
                fills: [(CGRect(x: 24, y: 18, width: 32, height: 24), pink)]
            ),
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        viewModel.addLayer()
        viewModel.replaceSelectedLayerImageForTesting(
            testBitmapImage(size: canvasSize, background: green),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let clippedLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleSelectedLayerClippingMask()
        #expect(viewModel.document.layers.first { $0.id == clippedLayerID }?.isClippingMask == true)
        #expect(viewModel.canMoveSelectedLayerToBottom)

        viewModel.moveSelectedLayerToBottom()

        let movedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == clippedLayerID })
        #expect(movedIndex == 0)
        #expect(!viewModel.document.layers[movedIndex].isClippingMask)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMoveToBottom"))
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
        let firstLayerID = viewModel.document.layers[editIndex].id
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

        viewModel.addLayer()
        let secondLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.selectedLayerIndex)].image = testBitmapImage(
            size: image.size,
            background: .clear,
            fills: [(CGRect(x: 50, y: 20, width: 12, height: 12), .systemYellow)]
        )
        viewModel.addLayer()
        let unselectedLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.layers[try #require(viewModel.document.selectedLayerIndex)].image = testBitmapImage(
            size: image.size,
            background: .clear,
            fills: [(CGRect(x: 66, y: 6, width: 8, height: 8), .systemGreen)]
        )

        viewModel.selectLayer(firstLayerID)
        viewModel.selectLayer(secondLayerID, extendingSelection: true)
        #expect(viewModel.canExportSelectedLayers)
        #expect(!viewModel.document.selectedLayerIDs.contains(unselectedLayerID))

        let selectedLayersPNGData = try #require(viewModel.exportData(settings: ImageEditorExportSettings(
            format: .png,
            scope: .selectedLayers,
            scale: 1,
            quality: 0.9
        )))
        let selectedLayersPNG = try #require(NSImage(data: selectedLayersPNGData))
        let selectedPink = try #require(selectedLayersPNG.color(at: CGPoint(x: 25, y: 25))?.usingColorSpace(.deviceRGB))
        let selectedYellow = try #require(selectedLayersPNG.color(at: CGPoint(x: 55, y: 25))?.usingColorSpace(.deviceRGB))
        let selectedGreenSpot = try #require(selectedLayersPNG.color(at: CGPoint(x: 70, y: 10))?.usingColorSpace(.deviceRGB))

        #expect(selectedLayersPNG.size == NSSize(width: 80, height: 60))
        #expect(selectedPink.redComponent > 0.8)
        #expect(selectedYellow.redComponent > 0.8)
        #expect(selectedYellow.greenComponent > 0.7)
        #expect(selectedGreenSpot.alphaComponent < 0.1)

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

    @MainActor
    @Test func imageEditorGradientToolUsesDragDirectionSelectionAndMaskAlpha() async throws {
        let image = testImage(color: .clear, size: NSSize(width: 80, height: 60))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }
        let editIndex = try #require(viewModel.document.selectedLayerIndex)

        viewModel.foregroundColor = .systemRed
        viewModel.backgroundColor = .systemBlue
        viewModel.opacity = 1
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 40, y: 60))
        viewModel.drawGradient(from: CGPoint(x: 0, y: 30), to: CGPoint(x: 80, y: 30))

        let gradientLayer = viewModel.document.layers[editIndex]
        let selectedStart = try #require(gradientLayer.image.color(at: CGPoint(x: 3, y: 30))?.usingColorSpace(.deviceRGB))
        let selectedEnd = try #require(gradientLayer.image.color(at: CGPoint(x: 38, y: 30))?.usingColorSpace(.deviceRGB))
        let outsideSelection = try #require(gradientLayer.image.color(at: CGPoint(x: 70, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(selectedStart.redComponent > selectedStart.blueComponent)
        #expect(selectedEnd.blueComponent > 0.35)
        #expect(outsideSelection.alphaComponent < 0.1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.gradient"))

        viewModel.undo()
        let restored = try #require(viewModel.document.layers[editIndex].image.color(at: CGPoint(x: 3, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(restored.alphaComponent < 0.1)

        let maskViewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(color: .systemGreen, size: NSSize(width: 80, height: 60))) { _ in }
        maskViewModel.opacity = 1
        maskViewModel.addLayerMask()
        #expect(maskViewModel.isEditingLayerMask)
        maskViewModel.drawGradient(from: CGPoint(x: 0, y: 30), to: CGPoint(x: 80, y: 30))

        let mask = try #require(maskViewModel.document.selectedLayer?.mask)
        let maskStart = try #require(mask.color(at: CGPoint(x: 3, y: 30))?.usingColorSpace(.deviceRGB))
        let maskEnd = try #require(mask.color(at: CGPoint(x: 77, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(maskStart.alphaComponent > 0.85)
        #expect(maskEnd.alphaComponent < 0.2)
        #expect(maskViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskGradient"))
    }

    @MainActor
    @Test func imageEditorMagicWandSelectsContiguousRegionOnly() async throws {
        let image = testBitmapImage(
            size: NSSize(width: 80, height: 60),
            background: .systemBlue,
            fills: [
                (CGRect(x: 5, y: 10, width: 20, height: 40), .systemRed),
                (CGRect(x: 55, y: 10, width: 20, height: 40), .systemRed)
            ]
        )
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: image) { _ in }

        viewModel.createMagicSelection(at: CGPoint(x: 15, y: 30))
        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)

        #expect(maskAlpha(mask, x: 15, y: 30) == 255)
        #expect(maskAlpha(mask, x: 35, y: 30) == 0)
        #expect(maskAlpha(mask, x: 65, y: 30) == 0)
        #expect(selection.bounds.minX < 6)
        #expect(selection.bounds.maxX < 26)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.magicSelection"))
    }

    @MainActor
    @Test func imageEditorSelectionBooleanModesProduceRasterMask() async throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .white, size: NSSize(width: 80, height: 60))
        ) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 30, y: 30))

        viewModel.selectionMode = .add
        viewModel.createRectSelection(from: CGPoint(x: 40, y: 0), to: CGPoint(x: 70, y: 30))
        let addedSelection = try #require(viewModel.document.selection)
        let addedMask = try #require(addedSelection.rasterMask)
        #expect(maskAlpha(addedMask, x: 10, y: 10) == 255)
        #expect(maskAlpha(addedMask, x: 50, y: 10) == 255)
        #expect(maskAlpha(addedMask, x: 35, y: 10) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionAdd"))

        viewModel.selectionMode = .subtract
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 20, y: 30))
        let subtractedSelection = try #require(viewModel.document.selection)
        let subtractedMask = try #require(subtractedSelection.rasterMask)
        #expect(maskAlpha(subtractedMask, x: 10, y: 10) == 0)
        #expect(maskAlpha(subtractedMask, x: 25, y: 10) == 255)
        #expect(maskAlpha(subtractedMask, x: 50, y: 10) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionSubtract"))

        viewModel.selectionMode = .intersect
        viewModel.createRectSelection(from: CGPoint(x: 45, y: 0), to: CGPoint(x: 60, y: 30))
        let intersectedSelection = try #require(viewModel.document.selection)
        let intersectedMask = try #require(intersectedSelection.rasterMask)
        #expect(maskAlpha(intersectedMask, x: 50, y: 10) == 255)
        #expect(maskAlpha(intersectedMask, x: 25, y: 10) == 0)
        #expect(maskAlpha(intersectedMask, x: 65, y: 10) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionIntersect"))
    }

    @MainActor
    @Test func imageEditorCanCenterSelectionOnCanvasAxes() async throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .white, size: NSSize(width: 80, height: 60))
        ) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 5, y: 10), to: CGPoint(x: 25, y: 30))
        viewModel.centerSelectionHorizontally()
        let horizontallyCentered = try #require(viewModel.document.selection)
        #expect(abs(horizontallyCentered.bounds.midX - 40) < 1.5)
        #expect(abs(horizontallyCentered.bounds.midY - 20) < 1.5)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionCenterHorizontal"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionCenteredHorizontal"))

        viewModel.createRectSelection(from: CGPoint(x: 5, y: 8), to: CGPoint(x: 25, y: 28))
        viewModel.centerSelectionVertically()
        let verticallyCentered = try #require(viewModel.document.selection)
        #expect(abs(verticallyCentered.bounds.midX - 15) < 1.5)
        #expect(abs(verticallyCentered.bounds.midY - 30) < 1.5)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionCenterVertical"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionCenteredVertical"))

        viewModel.createRectSelection(from: CGPoint(x: 5, y: 8), to: CGPoint(x: 25, y: 28))
        viewModel.centerSelectionInCanvas()
        let canvasCentered = try #require(viewModel.document.selection)
        let centeredMask = try #require(canvasCentered.rasterMask)
        #expect(abs(canvasCentered.bounds.midX - 40) < 1.5)
        #expect(abs(canvasCentered.bounds.midY - 30) < 1.5)
        #expect(maskAlpha(centeredMask, x: 40, y: 30) == 255)
        #expect(maskAlpha(centeredMask, x: 10, y: 12) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionCenterCanvas"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionCenteredCanvas"))
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

    private func maskAlpha(_ mask: ImageEditorSelectionMask, x: Int, y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < mask.width, y < mask.height else { return 0 }
        return mask.alpha[y * mask.width + x]
    }

    private func isLayerVisible(_ id: UUID, in viewModel: ImageEditorViewModel) -> Bool {
        viewModel.document.layers.first { $0.id == id }?.isVisible == true
    }

    private func isPixelLayer(_ layer: ImageEditorLayer) -> Bool {
        if case .pixel = layer.kind {
            return true
        }
        return false
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
