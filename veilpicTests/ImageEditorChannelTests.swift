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
        let sourceColor = try #require(
            viewModel.currentImage
                .color(at: CGPoint(x: 0.5, y: 0.5))?
                .usingColorSpace(.deviceRGB)
        )

        viewModel.selectChannelPreview(.red)
        let redPreview = try #require(viewModel.previewImage.color(at: CGPoint(x: 0.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        #expect(approximately(redPreview.redComponent, sourceColor.redComponent, tolerance: 0.03))
        #expect(approximately(redPreview.greenComponent, sourceColor.redComponent, tolerance: 0.03))
        #expect(approximately(redPreview.blueComponent, sourceColor.redComponent, tolerance: 0.03))
        #expect(approximately(redPreview.alphaComponent, 1, tolerance: 0.01))

        viewModel.selectChannelPreview(.green)
        let greenPreview = try #require(viewModel.previewImage.color(at: CGPoint(x: 0.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        #expect(approximately(greenPreview.redComponent, sourceColor.greenComponent, tolerance: 0.03))
        #expect(approximately(greenPreview.greenComponent, sourceColor.greenComponent, tolerance: 0.03))
        #expect(approximately(greenPreview.blueComponent, sourceColor.greenComponent, tolerance: 0.03))

        viewModel.selectChannelPreview(.blue)
        let bluePreview = try #require(viewModel.previewImage.color(at: CGPoint(x: 0.5, y: 0.5))?.usingColorSpace(.deviceRGB))
        #expect(approximately(bluePreview.redComponent, sourceColor.blueComponent, tolerance: 0.03))
        #expect(approximately(bluePreview.greenComponent, sourceColor.blueComponent, tolerance: 0.03))
        #expect(approximately(bluePreview.blueComponent, sourceColor.blueComponent, tolerance: 0.03))

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

        let historyCountBeforeRepeatedClear = viewModel.document.history.count
        viewModel.clearSelectedAlphaChannel()
        #expect(viewModel.document.history.count == historyCountBeforeRepeatedClear)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))

        viewModel.fillSelectedAlphaChannelWhite()
        let filledChannel = try #require(viewModel.document.alphaChannels.first)
        #expect(filledChannel.mask.alpha.allSatisfy { $0 == UInt8.max })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelFillWhite"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelFilledWhite", filledChannel.name))

        let historyCountAfterFill = viewModel.document.history.count
        viewModel.fillSelectedAlphaChannelWhite()
        #expect(viewModel.document.history.count == historyCountAfterFill)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))

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
        let compositeImage = viewModel.currentImage

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
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, compositeImage) <= 1)

        viewModel.selectChannelPreview(.composite)

        #expect(viewModel.previewedAlphaChannelID == nil)
        #expect(viewModel.channelPreviewTitle == ImageEditorChannelPreview.composite.title)
    }

    @Test func channelSelectionLoadsThroughSelectionModes() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let sourceGreen = try #require(
            viewModel.currentImage.color(
                at: CGPoint(x: 1.5, y: 0.5),
                coordinateSize: viewModel.document.canvasSize
            )?.usingColorSpace(.deviceRGB)
        )
        #expect(sourceGreen.redComponent < 0.05)
        #expect(sourceGreen.greenComponent > 0.95)
        let sourceRedMask = try #require(
            viewModel.currentImage.channelSelectionMask(
                .red,
                targetSize: viewModel.document.canvasSize
            )
        )
        #expect(maskAlpha(sourceRedMask, x: 0, y: 0) == 255)
        #expect(maskAlpha(sourceRedMask, x: 1, y: 0) == 0)

        viewModel.loadSelectionFromChannel(.red)
        var mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 1, y: 0) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromChannel"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.channelSelection", ImageEditorChannelPreview.red.title))

        let historyCountAfterFirstLoad = viewModel.document.history.count
        viewModel.loadSelectionFromChannel(.red)
        #expect(viewModel.document.history.count == historyCountAfterFirstLoad)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionUnchanged"))

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
        #expect(approximately(sampled.greenComponent, 1, tolerance: 0.05))
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
        let redSample = try #require(viewModel.colorRangeIncludeColors.first?.usingColorSpace(.deviceRGB))
        #expect(redSample.redComponent > redSample.greenComponent + 0.6)
        #expect(redSample.redComponent > redSample.blueComponent + 0.6)

        viewModel.colorRangeSampleMode = .add
        viewModel.sampleColorRangeColor(at: CGPoint(x: 1.5, y: 0.5))

        #expect(viewModel.colorRangeIncludeColors.count == 2)
        let greenSample = try #require(viewModel.colorRangeIncludeColors.last?.usingColorSpace(.deviceRGB))
        #expect(greenSample.greenComponent > greenSample.redComponent + 0.6)
        #expect(greenSample.greenComponent > greenSample.blueComponent + 0.6)
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

    @Test func alreadyGrownColorSelectionDoesNotCreateUndoOrHistory() {
        let image = NSImage.rendered(size: NSSize(width: 5, height: 1)) { rect in
            NSColor.systemRed.setFill()
            rect.fill()
        } ?? NSImage(size: NSSize(width: 5, height: 1))
        let viewModel = ImageEditorViewModel(sourceName: "grown.png", image: image) { _ in }
        viewModel.document.selection = .fullCanvas(size: image.size)
        let historyCountBeforeGrowth = viewModel.document.history.count
        #expect(!viewModel.canUndo)

        viewModel.growColorSelection(tolerance: 0.08)

        #expect(viewModel.document.history.count == historyCountBeforeGrowth)
        #expect(!viewModel.canUndo)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionUnchanged"))
        #expect(viewModel.document.selection?.bounds == CGRect(origin: .zero, size: image.size))
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

        let historyCountAfterFirstLoad = viewModel.document.history.count
        viewModel.selectedAlphaChannelID = nil
        viewModel.loadSelectionFromAlphaChannel(channel.id)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.history.count == historyCountAfterFirstLoad)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionUnchanged"))

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

    @Test func alphaChannelsDoNotRecordEquivalentSelectionUpdates() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "update-no-op.png", image: splitChannelImage()) { _ in }
        let mask = ImageEditorSelectionMask(width: 2, height: 1, alpha: [255, 0])
        let channel = ImageEditorAlphaChannel(name: "Same Selection", mask: mask)
        viewModel.document.alphaChannels = [channel]
        viewModel.document.selection = ImageEditorSelection.raster(
            mask: mask,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        let historyCountBeforeUpdate = viewModel.document.history.count

        viewModel.updateAlphaChannelFromSelection(channel.id)

        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.alphaChannels.first?.mask == mask)
        #expect(viewModel.document.history.count == historyCountBeforeUpdate)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))
    }

    @Test func alphaChannelsDoNotRecordEquivalentRenames() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "rename-no-op.png", image: splitChannelImage()) { _ in }
        let channel = ImageEditorAlphaChannel(
            name: "Existing Name",
            mask: ImageEditorSelectionMask(width: 2, height: 1, alpha: [255, 0])
        )
        viewModel.document.alphaChannels = [channel]
        let historyCountBeforeRename = viewModel.document.history.count

        viewModel.renameAlphaChannel(channel.id, to: "  Existing Name  ")

        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.alphaChannels.first?.name == channel.name)
        #expect(viewModel.document.history.count == historyCountBeforeRename)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))
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
            mask: ImageEditorSelectionMask(width: 4, height: 1, alpha: [0, 0, 255, 0]),
            bounds: CGRect(x: 2, y: 0, width: 1, height: 1)
        )
        #expect(viewModel.canIntersectSelectionWithSelectedAlphaChannel)
        viewModel.intersectSelectionWithSelectedAlphaChannel()

        combinedMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(combinedMask, x: 0, y: 0) == 0)
        #expect(maskAlpha(combinedMask, x: 1, y: 0) == 0)
        #expect(maskAlpha(combinedMask, x: 2, y: 0) == 0)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelSelectionIntersected", "Combine Alpha"))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelSelectionIntersect"))
    }

    @Test func alphaChannelsDoNotRecordEquivalentSelectionCombinations() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "combine-no-op.png", image: splitChannelImage()) { _ in }
        let mask = ImageEditorSelectionMask(width: 2, height: 1, alpha: [255, 0])
        let channel = ImageEditorAlphaChannel(name: "Stable Alpha", mask: mask)
        viewModel.document.alphaChannels = [channel]
        viewModel.document.selection = ImageEditorSelection.raster(
            mask: mask,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        let historyCountBeforeCombination = viewModel.document.history.count

        viewModel.addSelectionToAlphaChannel(channel.id)

        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.alphaChannels.first?.mask == mask)
        #expect(viewModel.document.history.count == historyCountBeforeCombination)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))
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
        let historyCountBeforeEquivalentUpdate = viewModel.document.history.count
        viewModel.updateSelectedAlphaChannelFromSelection()
        let updatedChannel = try #require(viewModel.selectedAlphaChannel)
        #expect(maskAlpha(updatedChannel.mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(updatedChannel.mask, x: 1, y: 0) == 0)
        #expect(viewModel.document.history.count == historyCountBeforeEquivalentUpdate)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", updatedChannel.name))

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

    @Test func currentTargetInvertPrefersPreviewedAlphaThenReturnsToLayerPixels() throws {
        let sourceImage = splitChannelImage()
        let viewModel = ImageEditorViewModel(
            sourceName: "current-invert-target.png",
            image: sourceImage
        ) { _ in }
        let selectedLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedLayerIndex].image = sourceImage
        viewModel.loadSelectionFromChannel(.red)
        viewModel.saveSelectionAsAlphaChannel()
        let channelID = try #require(viewModel.selectedAlphaChannelID)
        viewModel.selectAlphaChannel(channelID)
        let originalLayerData = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let originalMask = try #require(viewModel.selectedAlphaChannel?.mask)

        #expect(viewModel.previewedAlphaChannelID == channelID)
        #expect(viewModel.canInvertCurrentEditingTarget)
        #expect(viewModel.invertCurrentEditingTarget())
        let invertedMask = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(maskAlpha(invertedMask, x: 0, y: 0) == UInt8.max - maskAlpha(originalMask, x: 0, y: 0))
        #expect(maskAlpha(invertedMask, x: 1, y: 0) == UInt8.max - maskAlpha(originalMask, x: 1, y: 0))
        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == originalLayerData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.alphaChannelInvert"))

        viewModel.selectChannelPreview(.composite)
        #expect(viewModel.previewedAlphaChannelID == nil)
        #expect(viewModel.selectedAlphaChannelID == channelID)
        viewModel.document.selection = nil
        let alphaBeforePixelInvert = try #require(viewModel.selectedAlphaChannel?.mask)
        #expect(viewModel.canInvertCurrentEditingTarget)
        #expect(viewModel.invertCurrentEditingTarget())
        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) != originalLayerData)
        #expect(viewModel.selectedAlphaChannel?.mask == alphaBeforePixelInvert)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.invert"))
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

        let historyCountAfterThreshold = viewModel.document.history.count
        viewModel.selectedAlphaChannelID = nil
        viewModel.thresholdAlphaChannel(channel.id)

        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.history.count == historyCountAfterThreshold)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", "Soft"))

        viewModel.undo()
        let restoredChannel = try #require(viewModel.document.alphaChannels.first)
        #expect(restoredChannel.mask.alpha == [0, 127, 128])
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

    @Test func alphaChannelsDoNotRecordEquivalentFeather() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let mask = ImageEditorSelectionMask(
            width: 3,
            height: 3,
            alpha: Array(repeating: 0, count: 9)
        )
        let channel = ImageEditorAlphaChannel(name: "Empty", mask: mask)
        viewModel.document.alphaChannels = [channel]
        let historyCountBeforeFeather = viewModel.document.history.count

        viewModel.featherAlphaChannel(channel.id, radius: 1)

        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.alphaChannels.first?.mask == mask)
        #expect(viewModel.document.history.count == historyCountBeforeFeather)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))
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

        let historyCountAfterExpansion = viewModel.document.history.count
        viewModel.selectedAlphaChannelID = nil
        viewModel.expandAlphaChannel(dotChannel.id, radius: 1)
        #expect(viewModel.selectedAlphaChannelID == dotChannel.id)
        #expect(viewModel.document.history.count == historyCountAfterExpansion)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", "Dot"))

        viewModel.undo()
        let restoredDotChannel = try #require(viewModel.document.alphaChannels.first)
        #expect(restoredDotChannel.mask == dotMask)

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

        let historyCountAfterSmoothing = viewModel.document.history.count
        viewModel.selectedAlphaChannelID = nil
        viewModel.smoothAlphaChannel(channel.id, radius: 1)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.history.count == historyCountAfterSmoothing)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", "Noise"))

        viewModel.undo()
        let restoredChannel = try #require(viewModel.document.alphaChannels.first)
        #expect(restoredChannel.mask == noisyMask)
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

        let historyCountAfterFill = viewModel.document.history.count
        viewModel.selectedAlphaChannelID = nil
        viewModel.fillHolesAlphaChannel(channel.id)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.history.count == historyCountAfterFill)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", "Ring"))

        viewModel.undo()
        let restoredChannel = try #require(viewModel.document.alphaChannels.first)
        #expect(restoredChannel.mask == holedMask)
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

        let historyCountAfterCleanup = viewModel.document.history.count
        viewModel.selectedAlphaChannelID = nil
        viewModel.removeSpecklesAlphaChannel(channel.id, maximumArea: 1)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.history.count == historyCountAfterCleanup)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", "Speckles"))

        viewModel.undo()
        let restoredChannel = try #require(viewModel.document.alphaChannels.first)
        #expect(restoredChannel.mask == speckledMask)
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

    @Test func alphaChannelsDoNotRecordSymmetricFlips() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let symmetricMask = ImageEditorSelectionMask(
            width: 3,
            height: 3,
            alpha: [
                0, 255, 0,
                255, 255, 255,
                0, 255, 0
            ]
        )
        let channel = ImageEditorAlphaChannel(name: "Symmetric", mask: symmetricMask)
        viewModel.document.alphaChannels = [channel]
        let historyCountBeforeFlip = viewModel.document.history.count

        viewModel.flipAlphaChannelHorizontal(channel.id)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.alphaChannels.first?.mask == symmetricMask)
        #expect(viewModel.document.history.count == historyCountBeforeFlip)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))

        viewModel.selectedAlphaChannelID = nil
        viewModel.flipAlphaChannelVertical(channel.id)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.alphaChannels.first?.mask == symmetricMask)
        #expect(viewModel.document.history.count == historyCountBeforeFlip)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))
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

    @Test func alphaChannelsDoNotRecordSymmetricRotations() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let symmetricMask = ImageEditorSelectionMask(
            width: 3,
            height: 3,
            alpha: [
                0, 255, 0,
                255, 255, 255,
                0, 255, 0
            ]
        )
        let channel = ImageEditorAlphaChannel(name: "Symmetric", mask: symmetricMask)
        viewModel.document.alphaChannels = [channel]
        let historyCountBeforeRotation = viewModel.document.history.count

        viewModel.rotateAlphaChannelClockwise(channel.id)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.alphaChannels.first?.mask == symmetricMask)
        #expect(viewModel.document.history.count == historyCountBeforeRotation)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))

        viewModel.selectedAlphaChannelID = nil
        viewModel.rotateAlphaChannelCounterclockwise(channel.id)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.alphaChannels.first?.mask == symmetricMask)
        #expect(viewModel.document.history.count == historyCountBeforeRotation)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))

        viewModel.selectedAlphaChannelID = nil
        viewModel.rotateAlphaChannel180(channel.id)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.alphaChannels.first?.mask == symmetricMask)
        #expect(viewModel.document.history.count == historyCountBeforeRotation)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))
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

    @Test func alphaChannelsDoNotRecordEquivalentScales() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "split.png", image: splitChannelImage()) { _ in }
        let emptyMask = ImageEditorSelectionMask(
            width: 8,
            height: 8,
            alpha: Array(repeating: 0, count: 64)
        )
        let channel = ImageEditorAlphaChannel(name: "Empty", mask: emptyMask)
        viewModel.document.alphaChannels = [channel]
        let historyCountBeforeScale = viewModel.document.history.count

        viewModel.scaleAlphaChannelUp(channel.id)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.alphaChannels.first?.mask == emptyMask)
        #expect(viewModel.document.history.count == historyCountBeforeScale)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))

        viewModel.selectedAlphaChannelID = nil
        viewModel.scaleAlphaChannelDown(channel.id)
        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.document.alphaChannels.first?.mask == emptyMask)
        #expect(viewModel.document.history.count == historyCountBeforeScale)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))
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

    @Test func alphaChannelsDoNotRecordEquivalentCanvasFits() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "fit-no-op.png", image: splitChannelImage()) { _ in }
        let fullMask = ImageEditorSelectionMask(
            width: 8,
            height: 8,
            alpha: Array(repeating: 255, count: 64)
        )
        let fullChannel = ImageEditorAlphaChannel(name: "Full", mask: fullMask)
        let emptyMask = ImageEditorSelectionMask(
            width: 8,
            height: 8,
            alpha: Array(repeating: 0, count: 64)
        )
        let emptyChannel = ImageEditorAlphaChannel(name: "Empty", mask: emptyMask)
        viewModel.document.alphaChannels = [fullChannel, emptyChannel]
        let historyCountBeforeFit = viewModel.document.history.count

        viewModel.fitAlphaChannelToCanvas(fullChannel.id)
        #expect(viewModel.selectedAlphaChannelID == fullChannel.id)
        #expect(viewModel.document.alphaChannels[0].mask == fullMask)
        #expect(viewModel.document.history.count == historyCountBeforeFit)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", fullChannel.name))

        viewModel.selectedAlphaChannelID = nil
        viewModel.fitAlphaChannelToCanvas(emptyChannel.id)
        #expect(viewModel.selectedAlphaChannelID == emptyChannel.id)
        #expect(viewModel.document.alphaChannels[1].mask == emptyMask)
        #expect(viewModel.document.history.count == historyCountBeforeFit)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", emptyChannel.name))
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

    @Test func alphaChannelsDoNotRecordEquivalentMoves() async throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "move-no-op.png",
            image: NSImage.transparent(size: CGSize(width: 8, height: 8))
        ) { _ in }
        let emptyMask = ImageEditorSelectionMask(
            width: 8,
            height: 8,
            alpha: Array(repeating: 0, count: 64)
        )
        let emptyChannel = ImageEditorAlphaChannel(name: "Empty", mask: emptyMask)
        let subpixelMask = ImageEditorSelectionMask(width: 1, height: 1, alpha: [255])
        let subpixelChannel = ImageEditorAlphaChannel(name: "Subpixel", mask: subpixelMask)
        viewModel.document.alphaChannels = [emptyChannel, subpixelChannel]
        viewModel.selectionModifyAmount = 1
        let historyCountBeforeMove = viewModel.document.history.count

        viewModel.moveAlphaChannelRight(emptyChannel.id)
        #expect(viewModel.selectedAlphaChannelID == emptyChannel.id)
        #expect(viewModel.document.alphaChannels[0].mask == emptyMask)
        #expect(viewModel.document.history.count == historyCountBeforeMove)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", emptyChannel.name))

        viewModel.selectedAlphaChannelID = nil
        viewModel.moveAlphaChannelRight(subpixelChannel.id)
        #expect(viewModel.selectedAlphaChannelID == subpixelChannel.id)
        #expect(viewModel.document.alphaChannels[1].mask == subpixelMask)
        #expect(viewModel.document.history.count == historyCountBeforeMove)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", subpixelChannel.name))
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
        let sourceLayerID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(sourceLayerID)
        let selectedLayer = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.canvasSize == CGSize(width: 2, height: 1))
        #expect(selectedLayer.frame == CGRect(x: 0, y: 0, width: 2, height: 1))
        let sourceMask = try #require(
            selectedLayer.image.channelSelectionMask(.alpha, targetSize: viewModel.document.canvasSize)
        )
        #expect(maskAlpha(sourceMask, x: 0, y: 0) == 0)
        #expect(maskAlpha(sourceMask, x: 1, y: 0) == 255)

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
        #expect(viewModel.document.canvasSize == CGSize(width: 2, height: 1))
        #expect(viewModel.document.selectedLayer?.frame == CGRect(x: 0, y: 0, width: 2, height: 1))
        #expect(layerMask.size == CGSize(width: 2, height: 1))
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

    @Test func alphaChannelsDoNotRecordEquivalentLayerMaskApplications() async throws {
        let viewModel = ImageEditorViewModel(sourceName: "apply-mask-no-op.png", image: splitChannelImage()) { _ in }
        let channel = ImageEditorAlphaChannel(
            name: "Existing Mask",
            mask: ImageEditorSelectionMask(width: 2, height: 1, alpha: [255, 0])
        )
        viewModel.document.alphaChannels = [channel]

        viewModel.applyAlphaChannelToSelectedLayerMask(channel.id)
        let historyCountAfterFirstApplication = viewModel.document.history.count
        viewModel.isEditingLayerMask = false

        viewModel.applyAlphaChannelToSelectedLayerMask(channel.id)

        #expect(viewModel.selectedAlphaChannelID == channel.id)
        #expect(viewModel.isEditingLayerMask)
        #expect(viewModel.document.history.count == historyCountAfterFirstApplication)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.alphaChannelUnchanged", channel.name))
    }

    @Test func histogramSummaryReportsBinsAndAverageColor() async throws {
        let image = grayscaleHistogramImage()
        let summary = image.histogramSummary(binCount: 4, maximumSampleEdge: 8)

        #expect(summary.pixelCount == summary.sampledPixelCount)
        #expect(summary.transparentPixelCount == 0)
        #expect(summary.bins.count == 4)
        #expect(summary.bins.allSatisfy { approximately($0.luminance, 1, tolerance: 0.01) })
        #expect(approximately(summary.averageRed, summary.averageGreen, tolerance: 0.01))
        #expect(approximately(summary.averageGreen, summary.averageBlue, tolerance: 0.01))
        #expect(approximately(summary.averageBlue, summary.averageLuminance, tolerance: 0.01))
        // NSColor's calibrated gray samples are converted into the histogram's
        // device-RGB space before analysis; the two middle samples land at 111
        // and 177, so their even-sized median is 144.
        #expect(approximately(summary.medianLuminance, 144, tolerance: 2))
        #expect(approximately(summary.medianRed, summary.medianGreen, tolerance: 0.01))
        #expect(approximately(summary.medianGreen, summary.medianBlue, tolerance: 0.01))
        #expect(approximately(summary.standardDeviationLuminance, 95, tolerance: 2))
        #expect(approximately(
            summary.standardDeviationRed,
            summary.standardDeviationGreen,
            tolerance: 0.01
        ))
        #expect(approximately(
            summary.standardDeviationGreen,
            summary.standardDeviationBlue,
            tolerance: 0.01
        ))
        #expect(summary.clippedShadowPixels * 4 == summary.pixelCount)
        #expect(summary.clippedHighlightPixels * 4 == summary.pixelCount)
        #expect(approximately(summary.clippedShadowRatio, 0.25, tolerance: 0.01))
        #expect(approximately(summary.clippedHighlightRatio, 0.25, tolerance: 0.01))
        let probe = try #require(summary.probe(channel: .luminance, binIndex: 2))
        #expect(probe.lowerLevel == 128)
        #expect(probe.upperLevel == 191)
        #expect(probe.count * 4 == summary.pixelCount)
        #expect(approximately(probe.percentile, 0.75, tolerance: 0.001))
        #expect(summary.probe(channel: .luminance, binIndex: -1) == nil)
        #expect(summary.probe(channel: .luminance, binIndex: 4) == nil)
        let rangeProbe = try #require(summary.rangeProbe(
            channel: .luminance,
            lowerBinIndex: 3,
            upperBinIndex: 1
        ))
        #expect(rangeProbe.lowerLevel == 64)
        #expect(rangeProbe.upperLevel == 255)
        #expect(rangeProbe.count * 4 == summary.pixelCount * 3)
        #expect(approximately(rangeProbe.percentage, 0.75, tolerance: 0.001))
        #expect(summary.rangeProbe(
            channel: .luminance,
            lowerBinIndex: -1,
            upperBinIndex: 1
        ) == nil)
        #expect(summary.binIndex(forLevel: 0) == 0)
        #expect(summary.binIndex(forLevel: 63) == 0)
        #expect(summary.binIndex(forLevel: 64) == 1)
        #expect(summary.binIndex(forLevel: 255) == 3)
        #expect(summary.binIndex(forLevel: -1) == nil)
        #expect(summary.binIndex(forLevel: 256) == nil)
        #expect(summary.binIndex(atX: -20, plotWidth: 100) == 0)
        #expect(summary.binIndex(atX: 50, plotWidth: 100) == 2)
        #expect(summary.binIndex(atX: 120, plotWidth: 100) == 3)
        #expect(summary.binIndex(atX: 4, plotWidth: 8) == nil)
    }

    @Test func histogramChannelsExposeTheirOwnBinsAndAverages() async throws {
        let summary = ImageEditorHistogramSummary(
            bins: [
                ImageEditorHistogramBin(
                    index: 0,
                    red: 0.25,
                    green: 0.50,
                    blue: 0.75,
                    luminance: 0.45,
                    redCount: 1,
                    greenCount: 2,
                    blueCount: 3,
                    luminanceCount: 4
                )
            ],
            sampledPixelCount: 4,
            pixelCount: 4,
            transparentPixelCount: 0,
            averageRed: 64,
            averageGreen: 128,
            averageBlue: 192,
            averageLuminance: 116,
            medianRed: 60,
            medianGreen: 120,
            medianBlue: 180,
            medianLuminance: 110,
            standardDeviationRed: 10,
            standardDeviationGreen: 20,
            standardDeviationBlue: 30,
            standardDeviationLuminance: 25,
            clippedShadowPixels: 1,
            clippedHighlightPixels: 1
        )
        let bin = try #require(summary.bins.first)

        #expect(ImageEditorHistogramChannel.allCases.map(\.rawValue) == [
            "rgb", "luminance", "red", "green", "blue"
        ])
        #expect(approximately(ImageEditorHistogramChannel.rgb.value(in: bin), 0.75, tolerance: 0.0001))
        #expect(approximately(ImageEditorHistogramChannel.luminance.value(in: bin), 0.45, tolerance: 0.0001))
        #expect(approximately(ImageEditorHistogramChannel.red.value(in: bin), 0.25, tolerance: 0.0001))
        #expect(approximately(ImageEditorHistogramChannel.green.value(in: bin), 0.50, tolerance: 0.0001))
        #expect(approximately(ImageEditorHistogramChannel.blue.value(in: bin), 0.75, tolerance: 0.0001))
        #expect(ImageEditorHistogramChannel.rgb.count(in: bin) == 4)
        #expect(ImageEditorHistogramChannel.luminance.count(in: bin) == 4)
        #expect(ImageEditorHistogramChannel.red.count(in: bin) == 1)
        #expect(ImageEditorHistogramChannel.green.count(in: bin) == 2)
        #expect(ImageEditorHistogramChannel.blue.count(in: bin) == 3)
        #expect(approximately(ImageEditorHistogramChannel.rgb.average(in: summary), 116, tolerance: 0.0001))
        #expect(approximately(ImageEditorHistogramChannel.red.average(in: summary), 64, tolerance: 0.0001))
        #expect(approximately(ImageEditorHistogramChannel.green.average(in: summary), 128, tolerance: 0.0001))
        #expect(approximately(ImageEditorHistogramChannel.blue.average(in: summary), 192, tolerance: 0.0001))
        #expect(approximately(ImageEditorHistogramChannel.rgb.median(in: summary), 110, tolerance: 0.0001))
        #expect(approximately(ImageEditorHistogramChannel.red.median(in: summary), 60, tolerance: 0.0001))
        #expect(approximately(ImageEditorHistogramChannel.green.median(in: summary), 120, tolerance: 0.0001))
        #expect(approximately(ImageEditorHistogramChannel.blue.median(in: summary), 180, tolerance: 0.0001))
        #expect(approximately(
            ImageEditorHistogramChannel.rgb.standardDeviation(in: summary),
            25,
            tolerance: 0.0001
        ))
        #expect(approximately(
            ImageEditorHistogramChannel.red.standardDeviation(in: summary),
            10,
            tolerance: 0.0001
        ))
        #expect(approximately(
            ImageEditorHistogramChannel.green.standardDeviation(in: summary),
            20,
            tolerance: 0.0001
        ))
        #expect(approximately(
            ImageEditorHistogramChannel.blue.standardDeviation(in: summary),
            30,
            tolerance: 0.0001
        ))
    }

    @Test func histogramIgnoresTransparentPixelsAndRestoresPartiallyTransparentColor() async throws {
        let summary = transparencyHistogramImage().histogramSummary(binCount: 4, maximumSampleEdge: 8)
        let opaqueReference = transparencyHistogramImage(redAlpha: 1)
            .histogramSummary(binCount: 4, maximumSampleEdge: 8)

        #expect(summary.sampledPixelCount == summary.pixelCount + summary.transparentPixelCount)
        #expect(summary.pixelCount * 3 == summary.sampledPixelCount * 2)
        #expect(summary.transparentPixelCount * 3 == summary.sampledPixelCount)
        #expect(summary.pixelCount == opaqueReference.pixelCount)
        #expect(summary.transparentPixelCount == opaqueReference.transparentPixelCount)
        #expect(approximately(summary.averageRed, opaqueReference.averageRed, tolerance: 1))
        #expect(approximately(summary.averageGreen, opaqueReference.averageGreen, tolerance: 1))
        #expect(approximately(summary.averageBlue, opaqueReference.averageBlue, tolerance: 1))
        #expect(approximately(summary.averageLuminance, opaqueReference.averageLuminance, tolerance: 1))
        #expect(approximately(summary.medianRed, opaqueReference.medianRed, tolerance: 1))
        #expect(approximately(summary.medianGreen, opaqueReference.medianGreen, tolerance: 1))
        #expect(approximately(summary.medianBlue, opaqueReference.medianBlue, tolerance: 1))
        #expect(approximately(summary.medianLuminance, opaqueReference.medianLuminance, tolerance: 1))
        #expect(approximately(
            summary.standardDeviationRed,
            opaqueReference.standardDeviationRed,
            tolerance: 1
        ))
        #expect(approximately(
            summary.standardDeviationLuminance,
            opaqueReference.standardDeviationLuminance,
            tolerance: 1
        ))
        #expect(summary.clippedShadowPixels == opaqueReference.clippedShadowPixels)
        #expect(summary.clippedHighlightPixels == opaqueReference.clippedHighlightPixels)
    }

    @Test func histogramReturnsZeroStatisticsForFullyTransparentImage() async throws {
        let summary = NSImage.transparent(size: NSSize(width: 3, height: 2))
            .histogramSummary(binCount: 4, maximumSampleEdge: 8)

        #expect(summary.sampledPixelCount > 0)
        #expect(summary.pixelCount == 0)
        #expect(summary.transparentPixelCount == summary.sampledPixelCount)
        #expect(summary.averageRed == 0)
        #expect(summary.averageGreen == 0)
        #expect(summary.averageBlue == 0)
        #expect(summary.averageLuminance == 0)
        #expect(summary.medianRed == 0)
        #expect(summary.medianGreen == 0)
        #expect(summary.medianBlue == 0)
        #expect(summary.medianLuminance == 0)
        #expect(summary.standardDeviationRed == 0)
        #expect(summary.standardDeviationGreen == 0)
        #expect(summary.standardDeviationBlue == 0)
        #expect(summary.standardDeviationLuminance == 0)
        #expect(summary.clippedShadowRatio == 0)
        #expect(summary.clippedHighlightRatio == 0)
        #expect(summary.bins.count == 4)
        #expect(summary.bins.allSatisfy {
            $0.red == 0
                && $0.green == 0
                && $0.blue == 0
                && $0.luminance == 0
                && $0.redCount == 0
                && $0.greenCount == 0
                && $0.blueCount == 0
                && $0.luminanceCount == 0
        })
    }

    @Test func viewModelExposesHistogramReadoutsForNavigatorPanel() async throws {
        let image = grayscaleHistogramImage()
        let viewModel = ImageEditorViewModel(sourceName: "histogram.png", image: image) { _ in }

        #expect(viewModel.selectedHistogramChannel == .rgb)
        viewModel.selectedHistogramChannel = .red
        #expect(viewModel.selectedHistogramChannel == .red)
        let summary = viewModel.histogramSummary
        #expect(summary.bins.count == 32)
        let redReadout = viewModel.selectedHistogramChannelAverageText(for: summary)
        #expect(redReadout.contains(ImageEditorHistogramChannel.red.title))
        #expect(redReadout.contains("\(Int(summary.averageRed.rounded()))"))
        viewModel.selectedHistogramChannel = .luminance
        let luminanceReadout = viewModel.selectedHistogramChannelAverageText(for: summary)
        #expect(luminanceReadout == viewModel.histogramLuminanceText(for: summary))
        viewModel.selectedHistogramChannel = .rgb
        let rgbReadout = viewModel.selectedHistogramChannelAverageText(for: summary)
        #expect(rgbReadout == viewModel.histogramAverageText(for: summary))
        let statisticsReadout = viewModel.selectedHistogramStatisticsText(for: summary)
        #expect(statisticsReadout.contains(ImageEditorHistogramChannel.rgb.title))
        #expect(statisticsReadout.contains("\(Int(summary.medianLuminance.rounded()))"))
        let pixelCountReadout = viewModel.histogramPixelCountText(for: summary)
        #expect(pixelCountReadout.contains("\(summary.pixelCount)"))
        #expect(pixelCountReadout.contains("\(summary.sampledPixelCount)"))
        #expect(
            viewModel.histogramProbeText(for: summary, binIndex: nil)
                == L10n.text("imageEditor.histogram.probe.empty")
        )
        let probeReadout = viewModel.histogramProbeText(for: summary, binIndex: 0)
        #expect(probeReadout.contains("0"))
        #expect(probeReadout.contains("7"))
        let rangeReadout = viewModel.histogramProbeText(
            for: summary,
            binIndex: nil,
            selectedRange: 0...1
        )
        #expect(rangeReadout.contains("0"))
        #expect(rangeReadout.contains("15"))
        #expect(viewModel.histogramClippingText.contains("25"))
    }

    @Test func viewModelScopesHistogramToCompositeSelectedLayerAndSelection() async throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "histogram-scopes.png",
            image: splitChannelImage()
        ) { _ in }
        var blueLayer = ImageEditorLayer.blank(
            name: "Blue Overlay",
            size: viewModel.document.canvasSize
        )
        blueLayer.image = NSImage.rendered(size: viewModel.document.canvasSize) { _ in
            NSColor.blue.setFill()
            CGRect(x: 0, y: 0, width: 1, height: 1).fill()
        } ?? blueLayer.image
        viewModel.document.layers.append(blueLayer)
        viewModel.selectLayer(blueLayer.id)

        #expect(ImageEditorHistogramSource.allCases.map(\.rawValue) == [
            "composite", "selectedLayer", "selection"
        ])
        #expect(viewModel.activeHistogramSource == .composite)
        #expect(viewModel.canInspectHistogramSource(.selectedLayer))
        #expect(!viewModel.canInspectHistogramSource(.selection))

        let composite = viewModel.histogramSummary(for: .composite)
        let selectedLayer = viewModel.histogramSummary(for: .selectedLayer)
        #expect(selectedLayer.averageBlue > 245)
        #expect(selectedLayer.averageGreen < 5)
        #expect(composite.averageGreen > 100)
        #expect(composite.averageBlue > 100)

        viewModel.selectedHistogramSource = .selection
        #expect(viewModel.activeHistogramSource == .composite)
        #expect(viewModel.histogramSummary == composite)

        viewModel.document.selection = .rectangle(CGRect(x: 1, y: 0, width: 1, height: 1))
        #expect(viewModel.activeHistogramSource == .selection)
        let selection = viewModel.histogramSummary
        #expect(selection.averageGreen > 245)
        #expect(selection.averageRed < 5)
        #expect(selection.averageBlue < 5)

        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(backgroundID)
        let background = viewModel.histogramSummary(for: .selectedLayer)
        #expect(background.averageRed > 100)
        #expect(background.averageGreen > 100)
        #expect(background.averageBlue < 5)
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

    private func transparencyHistogramImage(redAlpha: CGFloat = 0.5) -> NSImage {
        NSImage.rendered(size: NSSize(width: 3, height: 1)) { _ in
            NSColor.clear.setFill()
            CGRect(x: 0, y: 0, width: 1, height: 1).fill()
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: redAlpha).setFill()
            CGRect(x: 1, y: 0, width: 1, height: 1).fill()
            NSColor.blue.setFill()
            CGRect(x: 2, y: 0, width: 1, height: 1).fill()
        } ?? NSImage(size: NSSize(width: 3, height: 1))
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
