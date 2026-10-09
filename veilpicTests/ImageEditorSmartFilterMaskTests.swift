import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSmartFilterMaskTests {
    @Test func smartFilterMaskThumbnailShowsGrayscaleCoverage() throws {
        let mask = ImageEditorSelectionMask(width: 4, height: 1, alpha: [0, 64, 128, 255])
        let thumbnail = mask.grayscaleThumbnailImage(targetSize: CGSize(width: 4, height: 1))
        let pixels = try #require(imageEditorRGBABytes(thumbnail, width: 4, height: 1))

        for (x, expected) in [UInt8(0), 64, 128, 255].enumerated() {
            let offset = x * 4
            #expect(pixels[offset] == expected)
            #expect(pixels[offset + 1] == expected)
            #expect(pixels[offset + 2] == expected)
            #expect(pixels[offset + 3] == .max)
        }
    }

    @Test func invalidStoredMaskDoesNotExpandSmartFilterAcrossTheWholeLayer() throws {
        let source = patternedImage(width: 8, height: 8)
        var layer = ImageEditorLayer.blank(name: "Invalid filter mask", size: source.size)
        layer.image = source
        layer.smartFilters = [
            ImageEditorSmartFilter(
                kind: .pixelate,
                intensity: 1,
                settings: ImageEditorFilterSettings(pixelateCellSize: 8),
                mask: ImageEditorSelectionMask(width: 2, height: 2, alpha: [])
            )
        ]

        let rendered = try #require(layer.contentImage)
        #expect(imageEditorMaximumPixelDifference(rendered, source) == 0)
    }

    @Test func selectionMaskLimitsOneSmartFilterAndUndoRedoRestoresIt() throws {
        let source = patternedImage(width: 32, height: 16)
        let viewModel = ImageEditorViewModel(sourceName: "filter-mask.png", image: source) { _ in }
        let selectedLayerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedLayerIndex].image = source
        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 1
        viewModel.filterPixelateCellSize = 4
        viewModel.addSmartFilterToSelectedLayer()
        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        let fullFilterResult = try #require(viewModel.document.selectedLayer?.contentImage)
        let fullPixels = try #require(imageEditorRGBABytes(fullFilterResult, width: 32, height: 16))
        let sourcePixels = try #require(imageEditorRGBABytes(source, width: 32, height: 16))

        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 16, height: 16))
        #expect(viewModel.canSetSmartFilterMaskFromSelection(filterID))
        #expect(viewModel.setSmartFilterMaskFromSelection(filterID) == 1)
        let filter = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        let mask = try #require(filter.mask)
        #expect(mask.width == 32)
        #expect(mask.height == 16)
        #expect(mask.alpha[8 * mask.width + 4] == .max)
        #expect(mask.alpha[8 * mask.width + 28] == .min)
        let maskImage = try #require(NSImage.selectionMaskImage(
            mask,
            inverted: false,
            targetSize: source.size
        ))
        let roundTripMask = try #require(maskImage.imageEditorSelectionMask(
            targetSize: source.size,
            flipsY: false
        ))
        #expect(roundTripMask.alpha[8 * mask.width + 28] == .min)

        let maskedResult = try #require(viewModel.document.selectedLayer?.contentImage)
        let maskedPixels = try #require(imageEditorRGBABytes(maskedResult, width: 32, height: 16))
        var selectedRegionChanged = false
        var outsideSelectionMatches = true
        var outsideMismatchSamples: [String] = []
        for y in 0..<16 {
            for x in 16..<32 {
                let offset = (y * 32 + x) * 4
                let maskedPixel = Array(maskedPixels[offset..<(offset + 4)])
                let sourcePixel = Array(sourcePixels[offset..<(offset + 4)])
                if maskedPixel != sourcePixel {
                    outsideSelectionMatches = false
                    if outsideMismatchSamples.count < 3 {
                        let index = y * mask.width + x
                        let fullPixel = Array(fullPixels[offset..<(offset + 4)])
                        outsideMismatchSamples.append(
                            "(\(x),\(y)) mask=\(mask.alpha[index]) roundTrip=\(roundTripMask.alpha[index]) source=\(sourcePixel) full=\(fullPixel) masked=\(maskedPixel)"
                        )
                    }
                }
            }
            for x in 2..<14 {
                let offset = (y * 32 + x) * 4
                if maskedPixels[offset..<(offset + 3)] != sourcePixels[offset..<(offset + 3)] {
                    selectedRegionChanged = true
                }
            }
        }
        #expect(selectedRegionChanged)
        #expect(outsideSelectionMatches, "Outside-mask samples: \(outsideMismatchSamples)")

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.mask == nil)
        #expect(try #require(viewModel.document.selectedLayer?.contentImage).qingtuPNGData()
            == fullFilterResult.qingtuPNGData())
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.mask == mask)
        #expect(imageEditorMaximumPixelDifference(
            try #require(viewModel.document.selectedLayer?.contentImage),
            maskedResult
        ) == 0)
        #expect(fullPixels != sourcePixels)
    }

    @Test func filterMaskSurvivesProjectRoundTripAndCanBeCleared() throws {
        let source = patternedImage(width: 24, height: 16)
        let viewModel = ImageEditorViewModel(sourceName: "filter-mask-roundtrip.png", image: source) { _ in }
        viewModel.selectedFilter = .pixelate
        viewModel.filterPixelateCellSize = 4
        viewModel.addSmartFilterToSelectedLayer()
        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        viewModel.document.selection = .rectangle(CGRect(x: 4, y: 2, width: 12, height: 10))
        #expect(viewModel.setSmartFilterMaskFromSelection(filterID) == 1)
        #expect(viewModel.setSmartFilterMaskDensityOnSelectedLayer(filterID, density: 0.65) == 1)
        #expect(viewModel.setSmartFilterMaskFeatherOnSelectedLayer(filterID, feather: 3) == 1)
        #expect(viewModel.invertSmartFilterMaskOnSelectedLayer(filterID) == 1)
        let savedMask = try #require(viewModel.document.selectedLayer?.smartFilters.first?.mask)

        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: NSImage.transparent(size: NSSize(width: 4, height: 4))
        ) { _ in }
        try reopened.loadProjectData(viewModel.projectData())
        let restoredFilter = try #require(reopened.document.selectedLayer?.smartFilters.first)
        #expect(restoredFilter.id == filterID)
        #expect(restoredFilter.mask == savedMask)
        #expect(restoredFilter.normalizedMaskDensity == 0.65)
        #expect(restoredFilter.normalizedMaskFeather == 3)
        #expect(restoredFilter.isMaskInverted)

        #expect(reopened.clearSmartFilterMask(filterID) == 1)
        let clearedFilter = try #require(reopened.document.selectedLayer?.smartFilters.first)
        #expect(clearedFilter.mask == nil)
        #expect(clearedFilter.normalizedMaskDensity == 1)
        #expect(clearedFilter.normalizedMaskFeather == 0)
        #expect(!clearedFilter.isMaskInverted)
        reopened.undo()
        let undoneFilter = try #require(reopened.document.selectedLayer?.smartFilters.first)
        #expect(undoneFilter.mask == savedMask)
        #expect(undoneFilter.normalizedMaskDensity == 0.65)
        #expect(undoneFilter.normalizedMaskFeather == 3)
        #expect(undoneFilter.isMaskInverted)
        reopened.redo()
        #expect(reopened.document.selectedLayer?.smartFilters.first?.mask == nil)
    }

    @Test func replacingFilterMaskFromSelectionPreservesRefinementAndUndoRedo() throws {
        let source = patternedImage(width: 24, height: 16)
        let viewModel = ImageEditorViewModel(sourceName: "filter-mask-replace.png", image: source) { _ in }
        viewModel.selectedFilter = .pixelate
        viewModel.addSmartFilterToSelectedLayer()
        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)

        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 12, height: 16))
        #expect(viewModel.setSmartFilterMaskFromSelection(filterID) == 1)
        #expect(viewModel.setSmartFilterMaskDensityOnSelectedLayer(filterID, density: 0.65) == 1)
        #expect(viewModel.setSmartFilterMaskFeatherOnSelectedLayer(filterID, feather: 3) == 1)
        #expect(viewModel.invertSmartFilterMaskOnSelectedLayer(filterID) == 1)
        let originalFilter = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        let originalMask = try #require(originalFilter.mask)

        viewModel.document.selection = .rectangle(CGRect(x: 12, y: 0, width: 12, height: 16))
        #expect(viewModel.setSmartFilterMaskFromSelection(filterID) == 1)
        let replacementFilter = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        let replacementMask = try #require(replacementFilter.mask)
        #expect(replacementMask != originalMask)
        #expect(replacementFilter.normalizedMaskDensity == 0.65)
        #expect(replacementFilter.normalizedMaskFeather == 3)
        #expect(replacementFilter.isMaskInverted)

        viewModel.undo()
        let undoneFilter = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        #expect(undoneFilter.mask == originalMask)
        #expect(undoneFilter.normalizedMaskDensity == 0.65)
        #expect(undoneFilter.normalizedMaskFeather == 3)
        #expect(undoneFilter.isMaskInverted)

        viewModel.redo()
        let redoneFilter = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        #expect(redoneFilter.mask == replacementMask)
        #expect(redoneFilter.normalizedMaskDensity == 0.65)
        #expect(redoneFilter.normalizedMaskFeather == 3)
        #expect(redoneFilter.isMaskInverted)
    }

    @Test func brushAndEraserPaintOnlySelectedSmartFilterMaskAndUndoRedoRestoreStrokes() throws {
        let source = patternedImage(width: 32, height: 16)
        let viewModel = ImageEditorViewModel(sourceName: "filter-mask-paint.png", image: source) { _ in }
        viewModel.selectedFilter = .pixelate
        viewModel.addSmartFilterToSelectedLayer()
        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 32, height: 16))
        #expect(viewModel.setSmartFilterMaskFromSelection(filterID) == 1)
        let layerPixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let originalMask = try #require(viewModel.document.selectedLayer?.smartFilters.first?.mask)

        viewModel.toggleSmartFilterMaskEditing(filterID)
        #expect(viewModel.isEditingSmartFilterMask(filterID))
        viewModel.brushSize = 6
        viewModel.document.selection = .rectangle(CGRect(x: 8, y: 4, width: 16, height: 8))
        viewModel.drawBrush(points: [CGPoint(x: 16, y: 8)])
        let maskAfterSelectedStroke = try #require(viewModel.document.selectedLayer?.smartFilters.first?.mask)
        viewModel.drawBrush(points: [CGPoint(x: 2, y: 8)])

        let paintedFilter = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        let paintedMask = try #require(paintedFilter.mask)
        #expect(maskAfterSelectedStroke != originalMask)
        #expect(paintedMask != originalMask)
        #expect(paintedMask.alpha[8 * paintedMask.width + 16] == .min)
        #expect(paintedMask.alpha[8 * paintedMask.width + 2] == originalMask.alpha[8 * originalMask.width + 2])
        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == layerPixelsBefore)

        viewModel.drawBrush(points: [CGPoint(x: 16, y: 8)], erase: true)
        let restoredMask = try #require(viewModel.document.selectedLayer?.smartFilters.first?.mask)
        #expect(restoredMask.alpha[8 * restoredMask.width + 16] == .max)
        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == layerPixelsBefore)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.mask == paintedMask)
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.mask == originalMask)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.mask == paintedMask)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.mask == restoredMask)
    }

    @Test func enteringSmartFilterMaskEditingLeavesQuickMaskBeforePainting() throws {
        let source = patternedImage(width: 32, height: 16)
        let viewModel = ImageEditorViewModel(sourceName: "filter-mask-from-quick-mask.png", image: source) { _ in }
        viewModel.selectedFilter = .pixelate
        viewModel.addSmartFilterToSelectedLayer()
        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 32, height: 16))
        #expect(viewModel.setSmartFilterMaskFromSelection(filterID) == 1)
        viewModel.document.selection = nil
        let originalMask = try #require(viewModel.document.selectedLayer?.smartFilters.first?.mask)

        viewModel.toggleQuickMaskMode()
        #expect(viewModel.isQuickMaskMode)
        viewModel.toggleSmartFilterMaskEditing(filterID)

        #expect(!viewModel.isQuickMaskMode)
        #expect(viewModel.document.selection == nil)
        #expect(viewModel.isEditingSmartFilterMask(filterID))
        viewModel.brushSize = 6
        viewModel.drawBrush(points: [CGPoint(x: 16, y: 8)])

        let paintedMask = try #require(viewModel.document.selectedLayer?.smartFilters.first?.mask)
        #expect(paintedMask != originalMask)
        #expect(paintedMask.alpha[8 * paintedMask.width + 16] == .min)
        #expect(viewModel.isQuickMaskMode == false)
    }

    @Test func smartFilterMaskEditingShowsRubylithForExcludedFilterCoverage() throws {
        let source = patternedImage(width: 32, height: 16)
        let viewModel = ImageEditorViewModel(sourceName: "filter-mask-overlay.png", image: source) { _ in }
        viewModel.selectedFilter = .pixelate
        viewModel.addSmartFilterToSelectedLayer()
        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 16, height: 16))
        #expect(viewModel.setSmartFilterMaskFromSelection(filterID) == 1)
        viewModel.toggleSmartFilterMaskEditing(filterID)

        let overlay = try #require(viewModel.smartFilterMaskOverlayImage)
        let included = try #require(overlay.color(at: CGPoint(x: 4.5, y: 8.5))?.usingColorSpace(.deviceRGB))
        let excluded = try #require(overlay.color(at: CGPoint(x: 28.5, y: 8.5))?.usingColorSpace(.deviceRGB))
        #expect(included.alphaComponent < 0.02)
        #expect(excluded.redComponent > 0.98)
        #expect(excluded.greenComponent < 0.02)
        #expect(excluded.blueComponent < 0.02)
        #expect(abs(excluded.alphaComponent - 0.5) < 0.02)

        #expect(viewModel.setSmartFilterMaskDensityOnSelectedLayer(filterID, density: 0.5) == 1)
        let densityAdjustedOverlay = try #require(viewModel.smartFilterMaskOverlayImage)
        let partiallyExcluded = try #require(
            densityAdjustedOverlay.color(at: CGPoint(x: 28.5, y: 8.5))?.usingColorSpace(.deviceRGB)
        )
        #expect(abs(partiallyExcluded.alphaComponent - 0.25) < 0.03)

        #expect(viewModel.invertSmartFilterMaskOnSelectedLayer(filterID) == 1)
        let invertedOverlay = try #require(viewModel.smartFilterMaskOverlayImage)
        let nowExcluded = try #require(
            invertedOverlay.color(at: CGPoint(x: 4.5, y: 8.5))?.usingColorSpace(.deviceRGB)
        )
        let nowIncluded = try #require(
            invertedOverlay.color(at: CGPoint(x: 28.5, y: 8.5))?.usingColorSpace(.deviceRGB)
        )
        #expect(abs(nowExcluded.alphaComponent - 0.25) < 0.03)
        #expect(nowIncluded.alphaComponent < 0.02)

        #expect(viewModel.setSmartFilterMaskDensityOnSelectedLayer(filterID, density: 1) == 1)
        #expect(viewModel.invertSmartFilterMaskOnSelectedLayer(filterID) == 1)
        #expect(viewModel.setSmartFilterMaskFeatherOnSelectedLayer(filterID, feather: 2) == 1)
        let featheredOverlay = try #require(viewModel.smartFilterMaskOverlayImage)
        let featheredEdge = try #require(
            featheredOverlay.color(at: CGPoint(x: 15.5, y: 8.5))?.usingColorSpace(.deviceRGB)
        )
        #expect(featheredEdge.alphaComponent > 0.02)
        #expect(featheredEdge.alphaComponent < 0.48)
    }

    @Test func optionClickPreviewsSmartFilterMaskAndNormalClickPaintsIt() throws {
        let source = patternedImage(width: 32, height: 16)
        let viewModel = ImageEditorViewModel(sourceName: "filter-mask-solo-preview.png", image: source) { _ in }
        viewModel.selectedFilter = .pixelate
        viewModel.addSmartFilterToSelectedLayer()
        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 16, height: 16))
        #expect(viewModel.setSmartFilterMaskFromSelection(filterID) == 1)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.activateSmartFilterMaskThumbnail(filterID, modifierFlags: .option)

        #expect(viewModel.isPreviewingSmartFilterMask(filterID))
        #expect(!viewModel.isEditingSmartFilterMask(filterID))
        #expect(viewModel.smartFilterMaskOverlayImage == nil)
        let previewPixels = try #require(imageEditorRGBABytes(viewModel.previewImage, width: 32, height: 16))
        #expect(previewPixels[(8 * 32 + 4) * 4] > 250)
        #expect(previewPixels[(8 * 32 + 28) * 4] < 5)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)

        viewModel.activateSmartFilterMaskThumbnail(filterID, modifierFlags: [])

        #expect(!viewModel.isPreviewingSmartFilterMask(filterID))
        #expect(viewModel.isEditingSmartFilterMask(filterID))
        #expect(viewModel.smartFilterMaskOverlayImage != nil)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)

        viewModel.selectChannelPreview(.red)
        #expect(!viewModel.isPreviewingSmartFilterMask(filterID))
        #expect(viewModel.previewImage.qingtuPNGData() == viewModel.channelPreviewImage(for: .red).qingtuPNGData())
    }

    @Test func legacySmartFilterDecodingDefaultsToNoMask() throws {
        let data = Data(
            #"{"kind":"pixelate","intensity":0.75,"settings":{},"isEnabled":true}"#.utf8
        )
        let filter = try JSONDecoder().decode(ImageEditorSmartFilter.self, from: data)
        #expect(filter.mask == nil)
        #expect(filter.normalizedMaskDensity == 1)
        #expect(filter.normalizedMaskFeather == 0)
        #expect(!filter.isMaskInverted)

        var normalized = ImageEditorSmartFilter(kind: .pixelate, intensity: 0.5)
        normalized.maskDensity = 4
        normalized.maskFeather = -3
        let decodedNormalized = try JSONDecoder().decode(
            ImageEditorSmartFilter.self,
            from: JSONEncoder().encode(normalized)
        )
        #expect(decodedNormalized.normalizedMaskDensity == 1)
        #expect(decodedNormalized.normalizedMaskFeather == 0)
    }

    @Test func maskDensityFeatherAndInversionChangeTheFilterCoverage() throws {
        let source = maskCoverageImage(width: 32, height: 16, selectedWidth: 16)
        let viewModel = ImageEditorViewModel(sourceName: "filter-mask-refine.png", image: source) { _ in }
        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 1
        viewModel.filterPixelateCellSize = 4
        viewModel.addSmartFilterToSelectedLayer()
        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        viewModel.document.selection = .rectangle(CGRect(x: 0, y: 0, width: 16, height: 16))
        #expect(viewModel.setSmartFilterMaskFromSelection(filterID) == 1)
        let sourcePixels = try #require(imageEditorRGBABytes(source, width: 32, height: 16))
        let historyCountBeforeInvalidValues = viewModel.document.history.count
        #expect(viewModel.setSmartFilterMaskDensityOnSelectedLayer(filterID, density: .nan) == 0)
        #expect(viewModel.setSmartFilterMaskFeatherOnSelectedLayer(filterID, feather: .infinity) == 0)
        #expect(viewModel.document.history.count == historyCountBeforeInvalidValues)

        #expect(viewModel.setSmartFilterMaskFeatherOnSelectedLayer(filterID, feather: 4) == 1)
        let featheredFilter = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        #expect(featheredFilter.normalizedMaskFeather == 4)
        let featheredMaskModel = try #require(featheredFilter.mask)
        let featheredSourceMask = try #require(NSImage.selectionMaskImage(
            featheredMaskModel,
            inverted: false,
            targetSize: source.size
        ))
        let processedMask = try #require(featheredSourceMask.processedLayerMask(density: 1, feather: 4))
        let processedMaskAlpha = try #require(processedMask.alphaPlane())
        let sourceMaskAlpha = try #require(featheredSourceMask.alphaPlane())
        #expect(processedMaskAlpha.values != sourceMaskAlpha.values)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.normalizedMaskFeather == 0)
        #expect(viewModel.setSmartFilterMaskDensityOnSelectedLayer(filterID, density: 0) == 1)
        let fullDensityImage = try #require(viewModel.document.selectedLayer?.contentImage)
        let fullDensityPixels = try #require(imageEditorRGBABytes(fullDensityImage, width: 32, height: 16))
        var outsideSelectionChanged = false
        for y in 0..<16 {
            let offset = (y * 32 + 28) * 4
            outsideSelectionChanged = outsideSelectionChanged
                || fullDensityPixels[offset..<(offset + 3)] != sourcePixels[offset..<(offset + 3)]
        }
        #expect(outsideSelectionChanged)

        viewModel.undo()
        #expect(viewModel.setSmartFilterMaskDensityOnSelectedLayer(filterID, density: 1) == 0)
        #expect(viewModel.invertSmartFilterMaskOnSelectedLayer(filterID) == 1)
        let invertedImage = try #require(viewModel.document.selectedLayer?.contentImage)
        let invertedPixels = try #require(imageEditorRGBABytes(invertedImage, width: 32, height: 16))
        var insideSelectionUnchanged = true
        var outsideSelectionChangedAfterInvert = false
        for y in 0..<16 {
            let insideOffset = (y * 32 + 2) * 4
            let outsideOffset = (y * 32 + 28) * 4
            insideSelectionUnchanged = insideSelectionUnchanged
                && invertedPixels[insideOffset..<(insideOffset + 3)] == sourcePixels[insideOffset..<(insideOffset + 3)]
            outsideSelectionChangedAfterInvert = outsideSelectionChangedAfterInvert
                || invertedPixels[outsideOffset..<(outsideOffset + 3)] != sourcePixels[outsideOffset..<(outsideOffset + 3)]
        }
        #expect(insideSelectionUnchanged)
        #expect(outsideSelectionChangedAfterInvert)
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.isMaskInverted == false)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.isMaskInverted == true)
    }

    @Test func oversizedSmartFilterMasksAreRejectedBeforeRendering() {
        let selection = ImageEditorSelection.rectangle(CGRect(x: 0, y: 0, width: 8, height: 8))
        #expect(selection.smartFilterMask(
            layerFrame: CGRect(x: 0, y: 0, width: 100_000, height: 1_000),
            layerSize: CGSize(width: 100_000, height: 1_000),
            canvasSize: CGSize(width: 8, height: 8)
        ) == nil)
    }

    private func patternedImage(width: Int, height: Int) -> NSImage {
        let rendered = NSImage.rendered(size: CGSize(width: width, height: height)) { _ in
            for y in 0..<height {
                for x in 0..<width {
                    ((x + y).isMultiple(of: 2) ? NSColor.black : NSColor.white).setFill()
                    NSRect(x: x, y: y, width: 1, height: 1).fill()
                }
            }
        }
        guard let image = rendered else { fatalError("Unable to render smart filter mask test fixture") }
        return image
    }

    private func maskCoverageImage(width: Int, height: Int, selectedWidth: Int) -> NSImage {
        let rendered = NSImage.rendered(size: CGSize(width: width, height: height)) { _ in
            for y in 0..<height {
                for x in 0..<width {
                    let gray = x < selectedWidth
                        ? 0
                        : CGFloat(x - selectedWidth) / CGFloat(max(1, width - selectedWidth - 1))
                    NSColor(calibratedWhite: gray, alpha: 1).setFill()
                    NSRect(x: x, y: y, width: 1, height: 1).fill()
                }
            }
        }
        guard let image = rendered else { fatalError("Unable to render smart filter mask coverage fixture") }
        return image
    }
}
