//
//  ImageEditorChannelTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorChannelTests {
    @Test func channelPreviewShowsSingleChannelsWithoutChangingComposite() async throws {
        let image = channelTestImage()
        let viewModel = ImageEditorViewModel(sourceName: "channels.png", image: image) { _ in }
        let compositeData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.selectChannelPreview(.red)
        let redPreview = try #require(viewModel.previewImage.color(at: CGPoint(x: 0.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        #expect(approximately(redPreview.redComponent, 0.25, tolerance: 0.03))
        #expect(approximately(redPreview.greenComponent, 0.25, tolerance: 0.03))
        #expect(approximately(redPreview.blueComponent, 0.25, tolerance: 0.03))
        #expect(approximately(redPreview.alphaComponent, 1, tolerance: 0.01))

        viewModel.selectChannelPreview(.green)
        let greenPreview = try #require(viewModel.previewImage.color(at: CGPoint(x: 0.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        #expect(approximately(greenPreview.redComponent, 0.50, tolerance: 0.03))
        #expect(approximately(greenPreview.greenComponent, 0.50, tolerance: 0.03))
        #expect(approximately(greenPreview.blueComponent, 0.50, tolerance: 0.03))

        viewModel.selectChannelPreview(.blue)
        let bluePreview = try #require(viewModel.previewImage.color(at: CGPoint(x: 0.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        #expect(approximately(bluePreview.redComponent, 0.75, tolerance: 0.03))
        #expect(approximately(bluePreview.greenComponent, 0.75, tolerance: 0.03))
        #expect(approximately(bluePreview.blueComponent, 0.75, tolerance: 0.03))

        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositeData)
    }

    @Test func alphaChannelPreviewUsesVisibleAlphaAsGrayscale() async throws {
        let image = alphaTestImage()
        let viewModel = ImageEditorViewModel(sourceName: "alpha.png", image: image) { _ in }
        let compositeData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.selectChannelPreview(.alpha)

        let clearPreview = try #require(viewModel.previewImage.color(at: CGPoint(x: 0.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        let opaquePreview = try #require(viewModel.previewImage.color(at: CGPoint(x: 1.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        #expect(approximately(clearPreview.redComponent, 0, tolerance: 0.01))
        #expect(approximately(clearPreview.greenComponent, 0, tolerance: 0.01))
        #expect(approximately(clearPreview.blueComponent, 0, tolerance: 0.01))
        #expect(approximately(clearPreview.alphaComponent, 1, tolerance: 0.01))
        #expect(approximately(opaquePreview.redComponent, 1, tolerance: 0.01))
        #expect(approximately(opaquePreview.greenComponent, 1, tolerance: 0.01))
        #expect(approximately(opaquePreview.blueComponent, 1, tolerance: 0.01))
        #expect(approximately(opaquePreview.alphaComponent, 1, tolerance: 0.01))

        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositeData)
    }

    @Test func channelPanelThumbnailsUseSmallCachedImages() throws {
        let viewModel = ImageEditorViewModel(sourceName: "thumbnails.png", image: splitChannelImage()) { _ in }

        let redThumbnail = viewModel.channelThumbnailImage(for: .red)
        let cachedRedThumbnail = viewModel.channelThumbnailImage(for: .red)

        #expect(redThumbnail.size == CGSize(width: 84, height: 56))
        #expect(redThumbnail === cachedRedThumbnail)

        viewModel.createBlankAlphaChannel()
        let alphaChannel = try #require(viewModel.document.alphaChannels.first)
        let alphaThumbnail = viewModel.alphaChannelThumbnailImage(alphaChannel)
        let cachedAlphaThumbnail = viewModel.alphaChannelThumbnailImage(alphaChannel)

        #expect(alphaThumbnail.size == CGSize(width: 84, height: 56))
        #expect(alphaThumbnail === cachedAlphaThumbnail)
    }

    @Test func blankAlphaChannelStartsEmptyAndSelected() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "blank-alpha.png", image: splitChannelImage()) { _ in }

        #expect(viewModel.canCreateBlankAlphaChannel)
        viewModel.createBlankAlphaChannel()

        let channel = try #require(viewModel.document.alphaChannels.first)
        #expect(channel.name == L10n.format("imageEditor.channel.alphaChannelName", 1))
        #expect(channel.mask.width == Int(viewModel.document.canvasSize.width.rounded()))
        #expect(channel.mask.height == Int(viewModel.document.canvasSize.height.rounded()))
        #expect(channel.mask.alpha.allSatisfy { $0 == 0 })
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.previewedAlphaChannelID == channel.id)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelBlank"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelBlank", channel.name))

        viewModel.fillSelectedAlphaChannelWhite()
        let filledChannel = try #require(viewModel.document.alphaChannels.first)
        #expect(filledChannel.mask.alpha.allSatisfy { $0 == UInt8.max })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelFillWhite"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelFilledWhite", filledChannel.name))

        viewModel.loadSelectionFromSelectedAlphaChannel()
        let filledSelection = try #require(viewModel.document.selection?.rasterMask)
        #expect(filledSelection.alpha.allSatisfy { $0 == UInt8.max })

        viewModel.clearSelectedAlphaChannel()
        let clearedChannel = try #require(viewModel.document.alphaChannels.first)
        #expect(clearedChannel.mask.alpha.allSatisfy { $0 == 0 })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelClear"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelCleared", clearedChannel.name))

        viewModel.loadSelectionFromSelectedAlphaChannel()

        #expect(viewModel.statusText == L10n.text("imageEditor.status.alphaChannelSelectionEmpty"))
    }

    @Test func savedAlphaChannelCanPreviewOnMainCanvas() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let compositeData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.loadSelectionFromChannel(.red)
        viewModel.saveSelectionAsAlphaChannel()

        let channel = try #require(viewModel.document.alphaChannels.first)
        #expect(viewModel.previewedAlphaChannelID == nil)

        viewModel.selectAlphaChannel(channel.id)

        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.previewedAlphaChannelID == channel.id)
        #expect(viewModel.channelPreviewTitle == channel.name)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelSelected", channel.name))

        let selectedPreview = try #require(viewModel.previewImage.color(at: CGPoint(x: 0.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        let unselectedPreview = try #require(viewModel.previewImage.color(at: CGPoint(x: 1.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        #expect(approximately(selectedPreview.redComponent, 1, tolerance: 0.02))
        #expect(approximately(selectedPreview.greenComponent, 1, tolerance: 0.02))
        #expect(approximately(selectedPreview.blueComponent, 1, tolerance: 0.02))
        #expect(approximately(unselectedPreview.redComponent, 0, tolerance: 0.02))
        #expect(approximately(unselectedPreview.greenComponent, 0, tolerance: 0.02))
        #expect(approximately(unselectedPreview.blueComponent, 0, tolerance: 0.02))
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositeData)

        viewModel.selectChannelPreview(.composite)

        #expect(viewModel.previewedAlphaChannelID == nil)
        #expect(viewModel.channelPreviewTitle == ImageEditorChannelPreview.composite.title)
    }

    @Test func channelSelectionLoadsThroughSelectionModes() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }

        viewModel.loadSelectionFromChannel(.red)
        var mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 1, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromChannel"))

        viewModel.selectionMode = .add
        viewModel.loadSelectionFromChannel(.green)
        mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 1, y: 0) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionAdd"))
    }

    @Test func colorRangeSelectionUsesForegroundColorAndSelectionModes() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "range.png", image: colorRangeTestImage()) { _ in }
        viewModel.foregroundColor = NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)
        viewModel.tolerance = 0.03

        viewModel.selectColorRangeFromForeground()

        var mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 1, y: 0) == 0)
        #expect(maskAlpha(mask, x: 2, y: 0) == 0)
        #expect(maskAlpha(mask, x: 3, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionColorRange"))

        viewModel.selectionMode = .add
        viewModel.foregroundColor = NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1)

        viewModel.selectColorRangeFromForeground()

        mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 1, y: 0) == 255)
        #expect(maskAlpha(mask, x: 2, y: 0) == 0)
        #expect(maskAlpha(mask, x: 3, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionAdd"))
    }

    @Test func colorRangePanelAppliesInvertedPreviewSettings() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "range.png", image: colorRangeTestImage()) { _ in }
        let red = NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)
        viewModel.foregroundColor = red
        viewModel.tolerance = 0.03

        viewModel.presentColorRangePanel()
        #expect(viewModel.isColorRangeSheetPresented)
        #expect(viewModel.colorRangeTolerance == 0.03)

        viewModel.colorRangeInverted = true
        viewModel.applyColorRangeSelectionFromPanel()

        let mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(mask, x: 1, y: 0) == 255)
        #expect(maskAlpha(mask, x: 2, y: 0) == 255)
        #expect(maskAlpha(mask, x: 3, y: 0) == 0)
        #expect(!viewModel.isColorRangeSheetPresented)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionColorRange"))
    }

    @Test func colorRangePanelSamplesSourcePreviewColor() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "range.png", image: colorRangeTestImage()) { _ in }
        viewModel.presentColorRangePanel()
        viewModel.colorRangeTolerance = 0.03

        viewModel.sampleColorRangeColor(at: CGPoint(x: 1.5, y: 0.5))

        let sampled = try #require(viewModel.colorRangeColor.usingColorSpace(.deviceRGB))
        #expect(approximately(sampled.redComponent, 0, tolerance: 0.02))
        #expect(approximately(sampled.greenComponent, 1, tolerance: 0.02))
        #expect(approximately(sampled.blueComponent, 0, tolerance: 0.02))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionColorRangeSampled"))

        viewModel.applyColorRangeSelectionFromPanel()

        let mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(mask, x: 1, y: 0) == 255)
        #expect(maskAlpha(mask, x: 2, y: 0) == 0)
        #expect(maskAlpha(mask, x: 3, y: 0) == 0)
    }

    @Test func colorRangePanelAddsAndSubtractsSampleColors() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "range.png", image: colorRangeTestImage()) { _ in }
        viewModel.presentColorRangePanel()
        viewModel.colorRangeTolerance = 0.03
        viewModel.sampleColorRangeColor(at: CGPoint(x: 0.5, y: 0.5))

        viewModel.colorRangeSampleMode = .add
        viewModel.sampleColorRangeColor(at: CGPoint(x: 1.5, y: 0.5))

        #expect(viewModel.colorRangeIncludeColors.count == 2)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionColorRangeSampleAdded"))

        viewModel.applyColorRangeSelectionFromPanel()
        var mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 1, y: 0) == 255)
        #expect(maskAlpha(mask, x: 2, y: 0) == 0)
        #expect(maskAlpha(mask, x: 3, y: 0) == 0)

        viewModel.presentColorRangePanel()
        viewModel.colorRangeTolerance = 0.03
        viewModel.sampleColorRangeColor(at: CGPoint(x: 0.5, y: 0.5))
        viewModel.colorRangeSampleMode = .add
        viewModel.sampleColorRangeColor(at: CGPoint(x: 1.5, y: 0.5))
        viewModel.colorRangeSampleMode = .subtract
        viewModel.sampleColorRangeColor(at: CGPoint(x: 1.5, y: 0.5))

        #expect(viewModel.colorRangeExcludeColors.count == 1)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionColorRangeSampleSubtracted"))

        viewModel.applyColorRangeSelectionFromPanel()
        mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 1, y: 0) == 0)
        #expect(maskAlpha(mask, x: 2, y: 0) == 0)
        #expect(maskAlpha(mask, x: 3, y: 0) == 0)
    }

    @Test func selectSimilarColorsSamplesCurrentSelectionAcrossCanvas() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "range.png", image: colorRangeTestImage()) { _ in }
        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 1, height: 1))
        viewModel.tolerance = 0.08

        viewModel.selectSimilarColors()

        let mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 1, y: 0) == 0)
        #expect(maskAlpha(mask, x: 2, y: 0) == 255)
        #expect(maskAlpha(mask, x: 3, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionSimilar"))
    }

    @Test func growColorSelectionOnlyAddsAdjacentSimilarPixels() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "grow.png", image: growColorSelectionTestImage()) { _ in }
        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 1, height: 1))
        viewModel.tolerance = 0.08

        viewModel.growColorSelection()

        let mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 1, y: 0) == 255)
        #expect(maskAlpha(mask, x: 2, y: 0) == 0)
        #expect(maskAlpha(mask, x: 3, y: 0) == 0)
        #expect(maskAlpha(mask, x: 4, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionGrow"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionGrown"))
    }

    @Test func alphaChannelSelectionUsesCompositeTransparency() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "alpha.png", image: alphaTestImage()) { _ in }

        viewModel.loadSelectionFromChannel(.alpha)

        let mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(mask, x: 1, y: 0) == 255)
    }

    @Test func selectedPreviewChannelCanSaveAsAlphaChannel() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        viewModel.selectChannelPreview(.green)

        #expect(viewModel.canSaveSelectedChannelAsAlphaChannel)
        viewModel.saveSelectedChannelAsAlphaChannel()

        let channel = try #require(viewModel.document.alphaChannels.first)
        #expect(channel.name == L10n.format("imageEditor.channel.alphaChannelFromChannelName", ImageEditorChannelPreview.green.title))
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(maskAlpha(channel.mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(channel.mask, x: 1, y: 0) == 255)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelFromChannel", ImageEditorChannelPreview.green.title))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelFromChannel"))
    }

    @Test func alphaChannelsCanSaveLoadAndDeleteSelection() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }

        viewModel.loadSelectionFromChannel(.red)
        viewModel.saveSelectionAsAlphaChannel()

        #expect(viewModel.document.alphaChannels.count == 1)
        let channel = try #require(viewModel.document.alphaChannels.first)
        #expect(channel.name == L10n.format("imageEditor.channel.alphaChannelName", 1))
        #expect(maskAlpha(channel.mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(channel.mask, x: 1, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelSave"))

        viewModel.document.selection = nil
        viewModel.loadSelectionFromAlphaChannel(channel.id)

        let restoredMask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(restoredMask, x: 0, y: 0) == 255)
        #expect(maskAlpha(restoredMask, x: 1, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelLoad"))

        viewModel.deleteAlphaChannel(channel.id)

        #expect(viewModel.document.alphaChannels.isEmpty)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelDelete"))
    }

    @Test func alphaChannelsCanRenameDuplicateAndUpdateFromSelection() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }

        viewModel.loadSelectionFromChannel(.red)
        viewModel.saveSelectionAsAlphaChannel()

        let originalID = try #require(viewModel.document.alphaChannels.first?.id)
        viewModel.renameAlphaChannel(originalID, to: "Cutout")
        #expect(viewModel.document.alphaChannels.first?.name == "Cutout")
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelRename"))

        viewModel.duplicateAlphaChannel(originalID)
        #expect(viewModel.document.alphaChannels.count == 2)
        let duplicate = try #require(viewModel.document.alphaChannels.last)
        #expect(duplicate.name == L10n.format("imageEditor.channel.alphaChannelCopyName", "Cutout"))
        #expect(maskAlpha(duplicate.mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(duplicate.mask, x: 1, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelDuplicate"))

        viewModel.loadSelectionFromChannel(.green)
        viewModel.updateAlphaChannelFromSelection(originalID)

        let updated = try #require(viewModel.document.alphaChannels.first)
        #expect(maskAlpha(updated.mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(updated.mask, x: 1, y: 0) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelUpdate"))
    }

    @Test func alphaChannelsCanCombineCurrentSelectionWithSavedMask() async throws {
        let canvasSize = NSSize(width: 4, height: 1)
        let image = NSImage.rendered(size: canvasSize) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        } ?? NSImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "combine-alpha.png", image: image) { _ in }
        let channel = ImageEditorAlphaChannel(
            name: "Combine Alpha",
            mask: ImageEditorSelectionMask(width: 4, height: 1, alpha: [255, 0, 0, 0])
        )
        viewModel.document.alphaChannels = [channel]
        viewModel.selectAlphaChannel(channel.id)
        viewModel.document.selection = ImageEditorSelection.raster(
            mask: ImageEditorSelectionMask(width: 4, height: 1, alpha: [0, 255, 0, 0]),
            bounds: CGRect(x: 1, y: 0, width: 1, height: 1)
        )

        #expect(viewModel.canAddSelectionToSelectedAlphaChannel)
        viewModel.addSelectionToSelectedAlphaChannel()

        var combinedMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(combinedMask, x: 0, y: 0) == 255)
        #expect(maskAlpha(combinedMask, x: 1, y: 0) == 255)
        #expect(maskAlpha(combinedMask, x: 2, y: 0) == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelSelectionAdded", "Combine Alpha"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelSelectionAdd"))

        viewModel.document.selection = ImageEditorSelection.raster(
            mask: ImageEditorSelectionMask(width: 4, height: 1, alpha: [255, 0, 0, 0]),
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        #expect(viewModel.canSubtractSelectionFromSelectedAlphaChannel)
        viewModel.subtractSelectionFromSelectedAlphaChannel()

        combinedMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(combinedMask, x: 0, y: 0) == 0)
        #expect(maskAlpha(combinedMask, x: 1, y: 0) == 255)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelSelectionSubtracted", "Combine Alpha"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelSelectionSubtract"))

        viewModel.document.selection = ImageEditorSelection.raster(
            mask: ImageEditorSelectionMask(width: 4, height: 1, alpha: [0, 255, 255, 0]),
            bounds: CGRect(x: 1, y: 0, width: 2, height: 1)
        )
        #expect(viewModel.canIntersectSelectionWithSelectedAlphaChannel)
        viewModel.intersectSelectionWithSelectedAlphaChannel()

        combinedMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(combinedMask, x: 0, y: 0) == 0)
        #expect(maskAlpha(combinedMask, x: 1, y: 0) == 255)
        #expect(maskAlpha(combinedMask, x: 2, y: 0) == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelSelectionIntersected", "Combine Alpha"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelSelectionIntersect"))
    }

    @Test func selectedAlphaChannelDrivesMenuStyleCommands() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }

        viewModel.loadSelectionFromChannel(.red)
        viewModel.saveSelectionAsAlphaChannel()
        let redChannel = try #require(viewModel.document.alphaChannels.first)
        #expect(viewModel.selectedAlphaChannelID == redChannel.id)
        #expect(viewModel.canLoadSelectedAlphaChannelSelection)

        viewModel.loadSelectionFromChannel(.green)
        viewModel.saveSelectionAsAlphaChannel()
        let greenChannel = try #require(viewModel.document.alphaChannels.last)
        #expect(viewModel.selectedAlphaChannelID == greenChannel.id)
        #expect(viewModel.canSelectPreviousAlphaChannel)
        #expect(!viewModel.canSelectNextAlphaChannel)

        viewModel.selectPreviousAlphaChannel()
        #expect(viewModel.selectedAlphaChannelID == redChannel.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelSelected", redChannel.name))

        viewModel.selectNextAlphaChannel()
        #expect(viewModel.selectedAlphaChannelID == greenChannel.id)
        #expect(viewModel.canDuplicateSelectedAlphaChannel)
        viewModel.duplicateSelectedAlphaChannel()

        let duplicatedChannel = try #require(viewModel.selectedAlphaChannel)
        #expect(viewModel.document.alphaChannels.count == 3)
        #expect(viewModel.selectedAlphaChannelID == duplicatedChannel.id)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelDuplicate"))

        #expect(viewModel.canInvertSelectedAlphaChannel)
        viewModel.invertSelectedAlphaChannel()
        let invertedChannel = try #require(viewModel.selectedAlphaChannel)
        #expect(maskAlpha(invertedChannel.mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(invertedChannel.mask, x: 1, y: 0) == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelInverted", invertedChannel.name))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelInvert"))

        viewModel.document.selection = nil
        viewModel.loadSelectionFromSelectedAlphaChannel()
        var mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 1, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelLoad"))

        viewModel.loadSelectionFromChannel(.red)
        viewModel.updateSelectedAlphaChannelFromSelection()
        let updatedChannel = try #require(viewModel.selectedAlphaChannel)
        #expect(maskAlpha(updatedChannel.mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(updatedChannel.mask, x: 1, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelUpdate"))

        #expect(viewModel.canApplySelectedAlphaChannelToLayerMask)
        viewModel.applySelectedAlphaChannelToSelectedLayerMask()
        let layerMask = try #require(viewModel.document.selectedLayer?.mask)
        mask = try #require(layerMask.alphaMask(width: 2, height: 1))
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 1, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelApplyToMask"))

        viewModel.deleteSelectedAlphaChannel()
        #expect(!viewModel.document.alphaChannels.contains { $0.id == duplicatedChannel.id })
        #expect(viewModel.selectedAlphaChannelID == greenChannel.id)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelDelete"))
    }

    @Test func alphaChannelsCanThresholdSoftMasks() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let mask = ImageEditorSelectionMask(width: 3, height: 1, alpha: [0, 127, 128])
        let channel = ImageEditorAlphaChannel(name: "Soft", mask: mask)
        viewModel.document.alphaChannels = [channel]
        viewModel.selectAlphaChannel(channel.id)

        #expect(viewModel.canThresholdSelectedAlphaChannel)
        viewModel.thresholdSelectedAlphaChannel()

        let thresholdedChannel = try #require(viewModel.selectedAlphaChannel)
        #expect(maskAlpha(thresholdedChannel.mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(thresholdedChannel.mask, x: 1, y: 0) == 0)
        #expect(maskAlpha(thresholdedChannel.mask, x: 2, y: 0) == 255)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelThresholded", "Soft"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelThreshold"))
        #expect(viewModel.previewedAlphaChannelID == channel.id)
    }

    @Test func alphaChannelsCanFeatherHardMasks() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let mask = ImageEditorSelectionMask(
            width: 3,
            height: 3,
            alpha: [
                0, 0, 0,
                0, 255, 0,
                0, 0, 0
            ]
        )
        let channel = ImageEditorAlphaChannel(name: "Dot", mask: mask)
        viewModel.document.alphaChannels = [channel]
        viewModel.selectionModifyAmount = 1
        viewModel.selectAlphaChannel(channel.id)

        #expect(viewModel.canFeatherSelectedAlphaChannel)
        viewModel.featherSelectedAlphaChannel()

        let featheredChannel = try #require(viewModel.selectedAlphaChannel)
        #expect(maskAlpha(featheredChannel.mask, x: 0, y: 0) == 28)
        #expect(maskAlpha(featheredChannel.mask, x: 1, y: 1) == 28)
        #expect(maskAlpha(featheredChannel.mask, x: 2, y: 2) == 28)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelFeathered", "Dot", 1))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelFeather"))
        #expect(viewModel.previewedAlphaChannelID == channel.id)
    }

    @Test func alphaChannelsCanExpandAndContractMasks() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let dotMask = ImageEditorSelectionMask(
            width: 3,
            height: 3,
            alpha: [
                0, 0, 0,
                0, 255, 0,
                0, 0, 0
            ]
        )
        let dotChannel = ImageEditorAlphaChannel(name: "Dot", mask: dotMask)
        viewModel.document.alphaChannels = [dotChannel]
        viewModel.selectionModifyAmount = 1
        viewModel.selectAlphaChannel(dotChannel.id)

        #expect(viewModel.canExpandSelectedAlphaChannel)
        viewModel.expandSelectedAlphaChannel()

        let expandedChannel = try #require(viewModel.selectedAlphaChannel)
        #expect((0..<3).allSatisfy { y in (0..<3).allSatisfy { x in maskAlpha(expandedChannel.mask, x: x, y: y) == 255 } })
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelExpanded", "Dot", 1))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelExpand"))

        let fullMask = ImageEditorSelectionMask(width: 5, height: 5, alpha: Array(repeating: UInt8.max, count: 25))
        let fullChannel = ImageEditorAlphaChannel(name: "Full", mask: fullMask)
        viewModel.document.alphaChannels = [fullChannel]
        viewModel.selectAlphaChannel(fullChannel.id)

        #expect(viewModel.canContractSelectedAlphaChannel)
        viewModel.contractSelectedAlphaChannel()

        let contractedChannel = try #require(viewModel.selectedAlphaChannel)
        #expect(maskAlpha(contractedChannel.mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(contractedChannel.mask, x: 1, y: 1) == 255)
        #expect(maskAlpha(contractedChannel.mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(contractedChannel.mask, x: 4, y: 4) == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelContracted", "Full", 1))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelContract"))
    }

    @Test func alphaChannelsCanSmoothMaskNoise() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let noisyMask = ImageEditorSelectionMask(
            width: 3,
            height: 3,
            alpha: [
                0, 0, 0,
                0, 255, 0,
                0, 0, 0
            ]
        )
        let channel = ImageEditorAlphaChannel(name: "Noise", mask: noisyMask)
        viewModel.document.alphaChannels = [channel]
        viewModel.selectionModifyAmount = 1
        viewModel.selectAlphaChannel(channel.id)

        #expect(viewModel.canSmoothSelectedAlphaChannel)
        viewModel.smoothSelectedAlphaChannel()

        let smoothedChannel = try #require(viewModel.selectedAlphaChannel)
        #expect((0..<3).allSatisfy { y in (0..<3).allSatisfy { x in maskAlpha(smoothedChannel.mask, x: x, y: y) == 0 } })
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelSmoothed", "Noise", 1))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelSmooth"))
    }

    @Test func alphaChannelsCanFillMaskHoles() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let holedMask = ImageEditorSelectionMask(
            width: 5,
            height: 5,
            alpha: [
                0, 0, 0, 0, 0,
                0, 255, 255, 255, 0,
                0, 255, 0, 255, 0,
                0, 255, 255, 255, 0,
                0, 0, 0, 0, 0
            ]
        )
        let channel = ImageEditorAlphaChannel(name: "Ring", mask: holedMask)
        viewModel.document.alphaChannels = [channel]
        viewModel.selectAlphaChannel(channel.id)

        #expect(viewModel.canFillHolesSelectedAlphaChannel)
        viewModel.fillHolesSelectedAlphaChannel()

        let filledChannel = try #require(viewModel.selectedAlphaChannel)
        #expect(maskAlpha(filledChannel.mask, x: 2, y: 2) == 255)
        #expect(maskAlpha(filledChannel.mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(filledChannel.mask, x: 4, y: 4) == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelFilledHoles", "Ring"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelFillHoles"))
    }

    @Test func alphaChannelsCanRemoveMaskSpeckles() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let speckledMask = ImageEditorSelectionMask(
            width: 5,
            height: 5,
            alpha: [
                255, 0, 0, 0, 0,
                0, 0, 0, 0, 0,
                0, 0, 255, 255, 0,
                0, 0, 255, 255, 0,
                0, 0, 0, 0, 0
            ]
        )
        let channel = ImageEditorAlphaChannel(name: "Speckles", mask: speckledMask)
        viewModel.document.alphaChannels = [channel]
        viewModel.selectionModifyAmount = 1
        viewModel.selectAlphaChannel(channel.id)

        #expect(viewModel.canRemoveSpecklesSelectedAlphaChannel)
        viewModel.removeSpecklesSelectedAlphaChannel()

        let cleanedChannel = try #require(viewModel.selectedAlphaChannel)
        #expect(maskAlpha(cleanedChannel.mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(cleanedChannel.mask, x: 2, y: 2) == 255)
        #expect(maskAlpha(cleanedChannel.mask, x: 3, y: 3) == 255)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelSpecklesRemoved", "Speckles", 1))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelRemoveSpeckles"))
    }

    @Test func alphaChannelsCanFlipMaskHorizontalAndVertical() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let asymmetricMask = ImageEditorSelectionMask(
            width: 4,
            height: 3,
            alpha: [
                255, 0, 0, 0,
                0, 255, 255, 0,
                0, 0, 0, 0
            ]
        )

        let horizontalChannel = ImageEditorAlphaChannel(name: "Asymmetric H", mask: asymmetricMask)
        viewModel.document.alphaChannels = [horizontalChannel]
        viewModel.selectAlphaChannel(horizontalChannel.id)

        #expect(viewModel.canFlipSelectedAlphaChannelHorizontal)
        viewModel.flipSelectedAlphaChannelHorizontal()

        let flippedHorizontal = try #require(viewModel.selectedAlphaChannel)
        #expect(maskAlpha(flippedHorizontal.mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(flippedHorizontal.mask, x: 2, y: 0) == 255)
        #expect(maskAlpha(flippedHorizontal.mask, x: 0, y: 1) == 255)
        #expect(maskAlpha(flippedHorizontal.mask, x: 1, y: 1) == 255)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelFlippedHorizontal", "Asymmetric H"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelFlipHorizontal"))

        let verticalChannel = ImageEditorAlphaChannel(name: "Asymmetric V", mask: asymmetricMask)
        viewModel.document.alphaChannels = [verticalChannel]
        viewModel.selectAlphaChannel(verticalChannel.id)

        #expect(viewModel.canFlipSelectedAlphaChannelVertical)
        viewModel.flipSelectedAlphaChannelVertical()

        let flippedVertical = try #require(viewModel.selectedAlphaChannel)
        #expect(maskAlpha(flippedVertical.mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(flippedVertical.mask, x: 0, y: 1) == 255)
        #expect(maskAlpha(flippedVertical.mask, x: 1, y: 0) == 255)
        #expect(maskAlpha(flippedVertical.mask, x: 2, y: 0) == 255)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelFlippedVertical", "Asymmetric V"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelFlipVertical"))
    }

    @Test func alphaChannelsCanRotateMaskClockwiseAndCounterclockwise() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        var alpha = [UInt8](repeating: 0, count: 42)
        alpha[1 * 7 + 2] = 255
        alpha[1 * 7 + 3] = 255
        alpha[1 * 7 + 4] = 255
        alpha[2 * 7 + 2] = 255
        let lShapeMask = ImageEditorSelectionMask(width: 7, height: 6, alpha: alpha)

        let clockwiseChannel = ImageEditorAlphaChannel(name: "Rotate CW", mask: lShapeMask)
        viewModel.document.alphaChannels = [clockwiseChannel]
        viewModel.selectAlphaChannel(clockwiseChannel.id)

        #expect(viewModel.canRotateSelectedAlphaChannelClockwise)
        viewModel.rotateSelectedAlphaChannelClockwise()

        let clockwiseMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(clockwiseMask, x: 2, y: 1) == 255)
        #expect(maskAlpha(clockwiseMask, x: 3, y: 1) == 255)
        #expect(maskAlpha(clockwiseMask, x: 3, y: 2) == 255)
        #expect(maskAlpha(clockwiseMask, x: 3, y: 3) == 255)
        #expect(maskAlpha(clockwiseMask, x: 4, y: 1) == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelRotatedClockwise", "Rotate CW"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelRotateClockwise"))

        let counterclockwiseChannel = ImageEditorAlphaChannel(name: "Rotate CCW", mask: lShapeMask)
        viewModel.document.alphaChannels = [counterclockwiseChannel]
        viewModel.selectAlphaChannel(counterclockwiseChannel.id)

        #expect(viewModel.canRotateSelectedAlphaChannelCounterclockwise)
        viewModel.rotateSelectedAlphaChannelCounterclockwise()

        let counterclockwiseMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(counterclockwiseMask, x: 2, y: 1) == 255)
        #expect(maskAlpha(counterclockwiseMask, x: 2, y: 2) == 255)
        #expect(maskAlpha(counterclockwiseMask, x: 2, y: 3) == 255)
        #expect(maskAlpha(counterclockwiseMask, x: 3, y: 3) == 255)
        #expect(maskAlpha(counterclockwiseMask, x: 3, y: 1) == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelRotatedCounterclockwise", "Rotate CCW"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelRotateCounterclockwise"))
    }

    @Test func alphaChannelsCanRotateMask180() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        var alpha = [UInt8](repeating: 0, count: 42)
        alpha[1 * 7 + 2] = 255
        alpha[1 * 7 + 3] = 255
        alpha[1 * 7 + 4] = 255
        alpha[2 * 7 + 2] = 255
        let lShapeMask = ImageEditorSelectionMask(width: 7, height: 6, alpha: alpha)
        let channel = ImageEditorAlphaChannel(name: "Rotate 180", mask: lShapeMask)
        viewModel.document.alphaChannels = [channel]
        viewModel.selectAlphaChannel(channel.id)

        #expect(viewModel.canRotateSelectedAlphaChannel180)
        viewModel.rotateSelectedAlphaChannel180()

        let rotatedMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(rotatedMask, x: 2, y: 1) == 0)
        #expect(maskAlpha(rotatedMask, x: 3, y: 1) == 0)
        #expect(maskAlpha(rotatedMask, x: 4, y: 1) == 255)
        #expect(maskAlpha(rotatedMask, x: 2, y: 2) == 255)
        #expect(maskAlpha(rotatedMask, x: 3, y: 2) == 255)
        #expect(maskAlpha(rotatedMask, x: 4, y: 2) == 255)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelRotated180", "Rotate 180"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelRotate180"))
    }

    @Test func alphaChannelsCanScaleMasksUpAndDown() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        var alpha = [UInt8](repeating: 0, count: 64)
        alpha[2 * 8 + 2] = 255
        alpha[2 * 8 + 3] = 255
        alpha[3 * 8 + 2] = 255
        let smallMask = ImageEditorSelectionMask(width: 8, height: 8, alpha: alpha)
        let upChannel = ImageEditorAlphaChannel(name: "Scale Up", mask: smallMask)
        viewModel.document.alphaChannels = [upChannel]
        viewModel.selectAlphaChannel(upChannel.id)

        #expect(viewModel.canScaleSelectedAlphaChannelUp)
        viewModel.scaleSelectedAlphaChannelUp()

        var scaledMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(scaledMask, x: 1, y: 1) == 255)
        #expect(maskAlpha(scaledMask, x: 4, y: 1) == 255)
        #expect(maskAlpha(scaledMask, x: 1, y: 4) == 255)
        #expect(maskAlpha(scaledMask, x: 4, y: 4) == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelScaledUp", "Scale Up"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelScaleUp"))

        alpha = [UInt8](repeating: 0, count: 64)
        for y in 2...5 {
            for x in 2...5 {
                alpha[y * 8 + x] = 255
            }
        }
        let largeMask = ImageEditorSelectionMask(width: 8, height: 8, alpha: alpha)
        let downChannel = ImageEditorAlphaChannel(name: "Scale Down", mask: largeMask)
        viewModel.document.alphaChannels = [downChannel]
        viewModel.selectAlphaChannel(downChannel.id)

        #expect(viewModel.canScaleSelectedAlphaChannelDown)
        viewModel.scaleSelectedAlphaChannelDown()

        scaledMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(scaledMask, x: 2, y: 2) == 0)
        #expect(maskAlpha(scaledMask, x: 3, y: 3) == 255)
        #expect(maskAlpha(scaledMask, x: 4, y: 4) == 255)
        #expect(maskAlpha(scaledMask, x: 5, y: 5) == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelScaledDown", "Scale Down"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelScaleDown"))
    }

    @Test func alphaChannelsCanFitMasksToCanvas() async throws {
        let canvasSize = NSSize(width: 5, height: 4)
        let image = NSImage.rendered(size: canvasSize) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        } ?? NSImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "fit-alpha.png", image: image) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[2 * 5 + 3] = 255
        let channel = ImageEditorAlphaChannel(
            name: "Fit Alpha",
            mask: ImageEditorSelectionMask(width: 5, height: 4, alpha: alpha)
        )
        viewModel.document.alphaChannels = [channel]
        viewModel.selectAlphaChannel(channel.id)

        #expect(viewModel.canFitSelectedAlphaChannelToCanvas)
        viewModel.fitSelectedAlphaChannelToCanvas()

        let fittedMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(fittedMask, x: 0, y: 0) == 255)
        #expect(maskAlpha(fittedMask, x: 4, y: 0) == 255)
        #expect(maskAlpha(fittedMask, x: 0, y: 3) == 255)
        #expect(maskAlpha(fittedMask, x: 4, y: 3) == 255)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelFitCanvas", "Fit Alpha"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelFitCanvas"))
    }

    @Test func alphaChannelsCanMoveMasksByModifyAmount() async throws {
        let canvasSize = NSSize(width: 8, height: 6)
        let image = NSImage.rendered(size: canvasSize) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        } ?? NSImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "move-alpha.png", image: image) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[1 * 8 + 1] = 255
        alpha[1 * 8 + 2] = 255
        let channel = ImageEditorAlphaChannel(
            name: "Move Alpha",
            mask: ImageEditorSelectionMask(width: 8, height: 6, alpha: alpha)
        )
        viewModel.document.alphaChannels = [channel]
        viewModel.selectAlphaChannel(channel.id)
        viewModel.selectionModifyAmount = 2

        #expect(viewModel.canMoveSelectedAlphaChannelRight)
        viewModel.moveSelectedAlphaChannelRight()
        viewModel.selectionModifyAmount = 1

        #expect(viewModel.canMoveSelectedAlphaChannelUp)
        viewModel.moveSelectedAlphaChannelUp()

        let movedMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(movedMask, x: 1, y: 1) == 0)
        #expect(maskAlpha(movedMask, x: 2, y: 1) == 0)
        #expect(maskAlpha(movedMask, x: 3, y: 2) == 255)
        #expect(maskAlpha(movedMask, x: 4, y: 2) == 255)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelMoved", "Move Alpha", 0, 1))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelMove"))
    }

    @Test func alphaChannelCanCreateGrayscalePixelLayer() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "alpha-layer.png", image: splitChannelImage()) { _ in }
        let layerCount = viewModel.document.layers.count
        let channel = ImageEditorAlphaChannel(
            name: "Stencil",
            mask: ImageEditorSelectionMask(width: 2, height: 1, alpha: [0, 255])
        )
        viewModel.document.alphaChannels = [channel]
        viewModel.selectAlphaChannel(channel.id)

        #expect(viewModel.canCreateLayerFromSelectedAlphaChannel)
        viewModel.createLayerFromSelectedAlphaChannel()

        #expect(viewModel.document.layers.count == layerCount + 1)
        let layer = try #require(viewModel.document.selectedLayer)
        #expect(layer.name == L10n.format("imageEditor.layer.alphaChannelName", channel.name))
        #expect(!layer.isGroup)
        #expect(!layer.isAdjustment)
        #expect(!layer.isFilter)
        #expect(viewModel.document.selectedLayerIDs == [layer.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelLayer"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelLayer", channel.name))

        let black = try #require(layer.image.color(at: CGPoint(x: 0.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        let white = try #require(layer.image.color(at: CGPoint(x: 1.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        #expect(approximately(black.redComponent, 0, tolerance: 0.02))
        #expect(approximately(black.greenComponent, 0, tolerance: 0.02))
        #expect(approximately(black.blueComponent, 0, tolerance: 0.02))
        #expect(approximately(black.alphaComponent, 1, tolerance: 0.02))
        #expect(approximately(white.redComponent, 1, tolerance: 0.02))
        #expect(approximately(white.greenComponent, 1, tolerance: 0.02))
        #expect(approximately(white.blueComponent, 1, tolerance: 0.02))
        #expect(approximately(white.alphaComponent, 1, tolerance: 0.02))
    }

    @Test func selectedLayerTransparencyCanSaveAsAlphaChannel() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "layer-alpha.png", image: alphaTestImage()) { _ in }

        #expect(viewModel.canSaveSelectedLayerTransparencyAsAlphaChannel)
        viewModel.saveSelectedLayerTransparencyAsAlphaChannel()

        let channel = try #require(viewModel.document.alphaChannels.first)
        #expect(channel.name == L10n.format("imageEditor.channel.alphaChannelFromTransparencyName", 1))
        #expect(maskAlpha(channel.mask, x: 0, y: 0) == 0)
        #expect(maskAlpha(channel.mask, x: 1, y: 0) == 255)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.previewedAlphaChannelID == channel.id)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelFromTransparency"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.alphaChannelFromTransparency"))
    }

    @Test func alphaChannelsRoundTripWithLayerMasks() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }

        viewModel.loadSelectionFromChannel(.red)
        viewModel.saveSelectionAsAlphaChannel()

        let channel = try #require(viewModel.document.alphaChannels.first)
        #expect(viewModel.canApplyAlphaChannelToSelectedLayerMask)
        viewModel.applyAlphaChannelToSelectedLayerMask(channel.id)

        let layerMask = try #require(viewModel.document.selectedLayer?.mask)
        let appliedMask = try #require(layerMask.alphaMask(width: 2, height: 1))
        #expect(maskAlpha(appliedMask, x: 0, y: 0) == 255)
        #expect(maskAlpha(appliedMask, x: 1, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelApplyToMask"))

        #expect(viewModel.canSaveSelectedLayerMaskAsAlphaChannel)
        viewModel.saveSelectedLayerMaskAsAlphaChannel()

        #expect(viewModel.document.alphaChannels.count == 2)
        let savedFromMask = try #require(viewModel.document.alphaChannels.last)
        #expect(savedFromMask.name == L10n.format("imageEditor.channel.alphaChannelFromMaskName", 2))
        #expect(maskAlpha(savedFromMask.mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(savedFromMask.mask, x: 1, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelFromMask"))
    }

    @Test func histogramSummaryReportsBinsAndAverageColor() async throws {
        let image = grayscaleHistogramImage()
        let summary = image.histogramSummary(binCount: 4, maximumSampleEdge: 8)

        #expect(summary.pixelCount == 4)
        #expect(summary.bins.count == 4)
        #expect(summary.bins.allSatisfy { approximately($0.luminance, 1, tolerance: 0.01) })
        #expect(approximately(summary.averageRed, 128, tolerance: 1))
        #expect(approximately(summary.averageGreen, 128, tolerance: 1))
        #expect(approximately(summary.averageBlue, 128, tolerance: 1))
        #expect(approximately(summary.averageLuminance, 128, tolerance: 1))
        #expect(summary.clippedShadowPixels == 1)
        #expect(summary.clippedHighlightPixels == 1)
        #expect(approximately(summary.clippedShadowRatio, 0.25, tolerance: 0.01))
        #expect(approximately(summary.clippedHighlightRatio, 0.25, tolerance: 0.01))
    }

    @Test func viewModelExposesHistogramReadoutsForNavigatorPanel() async throws {
        let image = grayscaleHistogramImage()
        let viewModel = ImageEditorViewModel(sourceName: "histogram.png", image: image) { _ in }

        #expect(viewModel.histogramSummary.bins.count == 32)
        #expect(viewModel.histogramAverageText.contains("128"))
        #expect(viewModel.histogramLuminanceText.contains("128"))
        #expect(viewModel.histogramClippingText.contains("25"))
    }

    private func channelTestImage() -> NSImage {
        NSImage.rendered(size: NSSize(width: 2, height: 1)) { _ in
            NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.75, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: 2, height: 1).fill()
        } ?? NSImage(size: NSSize(width: 2, height: 1))
    }

    private func alphaTestImage() -> NSImage {
        NSImage.rendered(size: NSSize(width: 2, height: 1)) { _ in
            NSColor.clear.setFill()
            CGRect(x: 0, y: 0, width: 1, height: 1).fill()
            NSColor.white.setFill()
            CGRect(x: 1, y: 0, width: 1, height: 1).fill()
        } ?? NSImage(size: NSSize(width: 2, height: 1))
    }

    private func splitChannelImage() -> NSImage {
        NSImage.rendered(size: NSSize(width: 2, height: 1)) { _ in
            NSColor.red.setFill()
            CGRect(x: 0, y: 0, width: 1, height: 1).fill()
            NSColor.green.setFill()
            CGRect(x: 1, y: 0, width: 1, height: 1).fill()
        } ?? NSImage(size: NSSize(width: 2, height: 1))
    }

    private func colorRangeTestImage() -> NSImage {
        NSImage.rendered(size: NSSize(width: 4, height: 1)) { _ in
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: 1, height: 1).fill()
            NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1).setFill()
            CGRect(x: 1, y: 0, width: 1, height: 1).fill()
            NSColor(calibratedRed: 0.94, green: 0.02, blue: 0.02, alpha: 1).setFill()
            CGRect(x: 2, y: 0, width: 1, height: 1).fill()
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0).setFill()
            CGRect(x: 3, y: 0, width: 1, height: 1).fill()
        } ?? NSImage(size: NSSize(width: 4, height: 1))
    }

    private func grayscaleHistogramImage() -> NSImage {
        NSImage.rendered(size: NSSize(width: 4, height: 1)) { _ in
            for index in 0..<4 {
                let value = CGFloat(index) / 3
                NSColor(calibratedRed: value, green: value, blue: value, alpha: 1).setFill()
                CGRect(x: index, y: 0, width: 1, height: 1).fill()
            }
        } ?? NSImage(size: NSSize(width: 4, height: 1))
    }

    private func growColorSelectionTestImage() -> NSImage {
        NSImage.rendered(size: NSSize(width: 5, height: 1)) { _ in
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: 1, height: 1).fill()
            NSColor(calibratedRed: 0.94, green: 0.02, blue: 0.02, alpha: 1).setFill()
            CGRect(x: 1, y: 0, width: 1, height: 1).fill()
            NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1).setFill()
            CGRect(x: 2, y: 0, width: 1, height: 1).fill()
            NSColor(calibratedRed: 0.94, green: 0.02, blue: 0.02, alpha: 1).setFill()
            CGRect(x: 3, y: 0, width: 1, height: 1).fill()
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0).setFill()
            CGRect(x: 4, y: 0, width: 1, height: 1).fill()
        } ?? NSImage(size: NSSize(width: 5, height: 1))
    }

    private func maskAlpha(_ mask: ImageEditorSelectionMask, x: Int, y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < mask.width, y < mask.height else { return 0 }
        return mask.alpha[y * mask.width + x]
    }

    private func approximately(_ value: CGFloat, _ expected: CGFloat, tolerance: CGFloat) -> Bool {
        abs(value - expected) <= tolerance
    }

    private func approximately(_ value: Double, _ expected: Double, tolerance: Double) -> Bool {
        abs(value - expected) <= tolerance
    }
}
