//
//  ImageEditorFilterTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorFilterTests {
    @Test func everyFilterAtZeroStrengthIsAnExactNoOpAcrossRenderingPaths() throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let sourceImage = gradientImage(size: canvasSize)
        let sourcePixels = try #require(sourceImage.qingtuPNGData())

        for filter in ImageEditorFilter.allCases {
            let zeroOutput = try #require(sourceImage.filtered(kind: filter, intensity: 0))
            let negativeOutput = try #require(sourceImage.filtered(kind: filter, intensity: -1))
            #expect(zeroOutput === sourceImage, "\(filter.rawValue) should bypass rendering at 0%")
            #expect(negativeOutput === sourceImage, "\(filter.rawValue) should clamp negative strength to 0%")
            #expect(zeroOutput.qingtuPNGData() == sourcePixels)
            #expect(negativeOutput.qingtuPNGData() == sourcePixels)
        }

        let destructiveViewModel = ImageEditorViewModel(
            sourceName: "zero-filter.png",
            image: sourceImage
        ) { _ in }
        let destructivePreviewBefore = destructiveViewModel.currentImage
        destructiveViewModel.selectedFilter = .pixelate
        destructiveViewModel.filterIntensity = 0
        destructiveViewModel.applySelectedFilter()
        #expect(imageEditorMaximumPixelDifference(destructiveViewModel.currentImage, destructivePreviewBefore) == 0)

        let filterLayerViewModel = ImageEditorViewModel(
            sourceName: "zero-filter-layer.png",
            image: sourceImage
        ) { _ in }
        let filterLayerPreviewBefore = filterLayerViewModel.currentImage
        filterLayerViewModel.selectedFilter = .emboss
        filterLayerViewModel.filterIntensity = 0
        filterLayerViewModel.addFilterLayer()

        #expect(filterLayerViewModel.document.selectedLayer?.isFilter == true)
        #expect(filterLayerViewModel.document.selectedLayer?.filter?.kind == .emboss)
        #expect(imageEditorMaximumPixelDifference(filterLayerViewModel.currentImage, filterLayerPreviewBefore) == 0)

        let smartViewModel = ImageEditorViewModel(
            sourceName: "zero-smart-filter.png",
            image: sourceImage
        ) { _ in }
        let smartPreviewBefore = smartViewModel.currentImage
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .highPass
        smartViewModel.filterIntensity = 0
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.kind == .highPass)
        #expect(smartLayer.smartFilters.first?.intensity == 0)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(imageEditorMaximumPixelDifference(smartViewModel.currentImage, smartPreviewBefore) == 0)
    }

    @Test func smartFilterOpacityBlendsTheCompleteResultAndSupportsUndoRedo() throws {
        let sourceImage = saltAndPepperImage(size: NSSize(width: 48, height: 48))
        let viewModel = ImageEditorViewModel(sourceName: "smart-opacity.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            sourceImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let filterInputImage = try #require(viewModel.document.selectedLayer?.image)
        viewModel.selectedFilter = .median
        viewModel.filterIntensity = 1
        viewModel.addSmartFilterToSelectedLayer()

        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        let fullImage = try #require(viewModel.document.selectedLayer?.contentImage)
        viewModel.setSmartFilterOpacityOnSelectedLayer(filterID, opacity: 0.5)
        let halfImage = try #require(viewModel.document.selectedLayer?.contentImage)

        let width = 48
        let height = 48
        let centerRedOffset = ((height / 2) * width + width / 2) * 4
        let inputPixels = try #require(imageEditorRGBABytes(filterInputImage, width: width, height: height))
        let fullPixels = try #require(imageEditorRGBABytes(fullImage, width: width, height: height))
        let halfPixels = try #require(imageEditorRGBABytes(halfImage, width: width, height: height))
        let expectedHalfRed = Int(inputPixels[centerRedOffset])
            + (Int(fullPixels[centerRedOffset]) - Int(inputPixels[centerRedOffset])) / 2

        #expect(Int(inputPixels[centerRedOffset]) > Int(fullPixels[centerRedOffset]) + 40)
        #expect(abs(Int(fullPixels[centerRedOffset]) - 128) <= 1)
        #expect(abs(Int(halfPixels[centerRedOffset]) - expectedHalfRed) <= 1)
        #expect(viewModel.smartFilterOpacity(filterID) == 0.5)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterOpacity"))

        viewModel.undo()
        #expect(viewModel.smartFilterOpacity(filterID) == 1)
        #expect(imageEditorMaximumPixelDifference(
            try #require(viewModel.document.selectedLayer?.contentImage),
            fullImage
        ) == 0)

        viewModel.redo()
        #expect(viewModel.smartFilterOpacity(filterID) == 0.5)
        #expect(imageEditorMaximumPixelDifference(
            try #require(viewModel.document.selectedLayer?.contentImage),
            halfImage
        ) == 0)
    }

    @Test func smartFilterBlendModeCombinesTheCompleteResultAndSupportsUndoRedo() throws {
        let sourceImage = saltAndPepperImage(size: NSSize(width: 48, height: 48))
        let viewModel = ImageEditorViewModel(sourceName: "smart-blend.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            sourceImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.selectedFilter = .median
        viewModel.filterIntensity = 1
        viewModel.addSmartFilterToSelectedLayer()

        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        let normalImage = try #require(viewModel.document.selectedLayer?.contentImage)
        viewModel.setSmartFilterBlendModeOnSelectedLayer(filterID, blendMode: .multiply)
        let multipliedImage = try #require(viewModel.document.selectedLayer?.contentImage)

        let normalPixels = try #require(imageEditorRGBABytes(normalImage, width: 48, height: 48))
        let multipliedPixels = try #require(imageEditorRGBABytes(multipliedImage, width: 48, height: 48))
        #expect(abs(Int(normalPixels[0]) - 128) <= 1)
        #expect(abs(Int(multipliedPixels[0]) - 64) <= 1)
        #expect(normalPixels[3] == 255)
        #expect(multipliedPixels[3] == 255)
        #expect(viewModel.smartFilterBlendMode(filterID) == .multiply)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterBlendMode"))

        viewModel.undo()
        #expect(viewModel.smartFilterBlendMode(filterID) == .normal)
        #expect(imageEditorMaximumPixelDifference(
            try #require(viewModel.document.selectedLayer?.contentImage),
            normalImage
        ) == 0)

        viewModel.redo()
        #expect(viewModel.smartFilterBlendMode(filterID) == .multiply)
        #expect(imageEditorMaximumPixelDifference(
            try #require(viewModel.document.selectedLayer?.contentImage),
            multipliedImage
        ) == 0)

        let translucentInput = solidImage(
            size: NSSize(width: 12, height: 12),
            color: NSColor(calibratedRed: 0.6, green: 0.4, blue: 0.2, alpha: 0.35)
        )
        let translucentOutput = try #require(
            translucentInput.applyingFilter(
                kind: .pixelate,
                intensity: 1,
                mask: nil,
                blendMode: .multiply
            )
        )
        let translucentInputPixels = try #require(imageEditorRGBABytes(translucentInput, width: 12, height: 12))
        let translucentOutputPixels = try #require(imageEditorRGBABytes(translucentOutput, width: 12, height: 12))
        #expect(abs(Int(translucentOutputPixels[3]) - Int(translucentInputPixels[3])) <= 1)
        #expect(translucentOutputPixels[0] < translucentInputPixels[0])
    }

    @Test func smartFilterOpacityCodableDefaultsLegacyDocumentsToFullyOpaque() throws {
        let filter = ImageEditorSmartFilter(
            kind: .median,
            intensity: 0.8,
            opacity: 0.35,
            blendMode: .softLight
        )
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(filter)
        let decoded = try JSONDecoder().decode(ImageEditorSmartFilter.self, from: encoded)
        #expect(decoded.normalizedOpacity == 0.35)
        #expect(decoded.normalizedBlendMode == .softLight)

        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "opacity")
        legacyObject.removeValue(forKey: "blendMode")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyDecoded = try JSONDecoder().decode(ImageEditorSmartFilter.self, from: legacyData)
        #expect(legacyDecoded.normalizedOpacity == 1)
        #expect(legacyDecoded.normalizedBlendMode == .normal)
    }

    @Test func loadingSpecificSmartFilterRestoresControlsWithoutChangingDocumentHistory() throws {
        let image = solidImage(
            size: NSSize(width: 32, height: 24),
            color: NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        )
        let viewModel = ImageEditorViewModel(sourceName: "load-smart-filter.png", image: image) { _ in }
        let layerIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == viewModel.document.selectedLayerID }
        )
        let target = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 0.72,
            settings: ImageEditorFilterSettings(
                gaussianBlurRadius: 42,
                unsharpRadius: 3.5,
                offsetX: -0.4,
                waveFrequency: 0.8
            )
        )
        let other = ImageEditorSmartFilter(kind: .sharpen, intensity: 0.2)
        viewModel.document.layers[layerIndex].smartFilters = [target, other]
        viewModel.selectedFilter = .wave
        viewModel.filterIntensity = 0.1
        viewModel.filterUnsharpRadius = 0.5
        viewModel.filterOffsetX = 0.9
        viewModel.filterWaveFrequency = 0.1
        let historyCount = viewModel.document.history.count
        let presentationRequest = viewModel.filterPanelPresentationRequest
        let imageBefore = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.loadSmartFilterIntoControls(target.id))
        #expect(viewModel.selectedFilter == .gaussianBlur)
        #expect(viewModel.filterIntensity == 0.72)
        #expect(viewModel.filterGaussianBlurRadius == 42)
        #expect(viewModel.filterUnsharpRadius == 3.5)
        #expect(viewModel.filterOffsetX == -0.4)
        #expect(viewModel.filterWaveFrequency == 0.8)
        #expect(viewModel.filterPanelPresentationRequest == presentationRequest + 1)
        #expect(viewModel.isPropertiesPanelVisible)
        #expect(viewModel.document.history.count == historyCount)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == imageBefore)

        viewModel.filterIntensity = 0.6
        viewModel.updateSmartFilterOnSelectedLayer(target.id)
        let updated = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        #expect(updated.intensity == 0.6)
        #expect(updated.normalizedSettings.gaussianBlurRadius == 42)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterUpdate"))

        viewModel.undo()
        let restored = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        #expect(restored.intensity == 0.72)
        #expect(restored.normalizedSettings.gaussianBlurRadius == 42)

        viewModel.selectedFilter = .sharpen
        #expect(viewModel.filterGaussianBlurRadius == nil)
    }

    @Test func loadedSmartFilterSelectionFollowsStackMutationsAndUndo() throws {
        let image = solidImage(size: NSSize(width: 24, height: 18), color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-selection.png", image: image) { _ in }
        viewModel.selectedFilter = .median
        viewModel.filterIntensity = 0.7
        viewModel.addSmartFilterToSelectedLayer()

        let originalID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        #expect(viewModel.loadedSmartFilterID == originalID)
        #expect(viewModel.isSmartFilterLoadedForEditing(originalID))

        let duplication = try #require(viewModel.duplicateSmartFilterOnSelectedLayer(originalID))
        let duplicateID = try #require(duplication.primaryDuplicateID)
        #expect(duplication.duplicatedLayerCount == 1)
        #expect(viewModel.loadedSmartFilterID == duplicateID)
        #expect(viewModel.isSmartFilterLoadedForEditing(duplicateID))
        #expect(!viewModel.isSmartFilterLoadedForEditing(originalID))

        #expect(viewModel.loadSmartFilterIntoControls(originalID))
        #expect(viewModel.moveSmartFilterOnSelectedLayer(originalID, offset: 1) == 1)
        #expect(viewModel.isSmartFilterLoadedForEditing(originalID))

        viewModel.removeSmartFilterFromSelectedLayer(originalID)
        #expect(viewModel.loadedSmartFilterID == duplicateID)
        #expect(viewModel.isSmartFilterLoadedForEditing(duplicateID))
        #expect(!viewModel.isSmartFilterLoadedForEditing(originalID))

        viewModel.clearSmartFiltersFromSelectedLayer()
        #expect(viewModel.loadedSmartFilterID == nil)
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [duplicateID])
        #expect(viewModel.isSmartFilterLoadedForEditing(duplicateID))

        viewModel.selectFilter(.wave)
        #expect(viewModel.loadedSmartFilterID == nil)
    }

    @Test func removingLoadedSmartFilterSelectsNextThenPreviousNeighbor() throws {
        let image = solidImage(size: NSSize(width: 24, height: 18), color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-remove-neighbor.png", image: image) { _ in }
        let layerIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == viewModel.document.selectedLayerID }
        )
        let first = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 0.2,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 4)
        )
        let middle = ImageEditorSmartFilter(kind: .sharpen, intensity: 0.4)
        let last = ImageEditorSmartFilter(kind: .pixelate, intensity: 0.6)
        viewModel.document.layers[layerIndex].smartFilters = [first, middle, last]

        #expect(viewModel.loadSmartFilterIntoControls(middle.id))
        let historyCount = viewModel.document.history.count
        viewModel.removeSmartFilterFromSelectedLayer(middle.id)
        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [first.id, last.id])
        #expect(viewModel.loadedSmartFilterID == last.id)
        #expect(viewModel.selectedFilter == .pixelate)
        #expect(abs(viewModel.filterIntensity - 0.6) < 0.000_001)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.removeSmartFilterFromSelectedLayer(last.id)
        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [first.id])
        #expect(viewModel.loadedSmartFilterID == first.id)
        #expect(viewModel.selectedFilter == .gaussianBlur)
        #expect(abs(viewModel.filterIntensity - 0.2) < 0.000_001)
        #expect(viewModel.filterGaussianBlurRadius == 4)
        #expect(viewModel.document.history.count == historyCount + 2)

        viewModel.removeSmartFilterFromSelectedLayer(first.id)
        #expect(viewModel.document.selectedLayer?.smartFilters.isEmpty == true)
        #expect(viewModel.loadedSmartFilterID == nil)
        #expect(viewModel.document.history.count == historyCount + 3)
    }

    @Test func removingUnloadedSmartFilterPreservesLoadedControls() throws {
        let image = solidImage(size: NSSize(width: 24, height: 18), color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-remove-other.png", image: image) { _ in }
        let layerIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == viewModel.document.selectedLayerID }
        )
        let first = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.2)
        let loaded = ImageEditorSmartFilter(
            kind: .sharpen,
            intensity: 0.45,
            settings: ImageEditorFilterSettings(unsharpRadius: 2.5)
        )
        let last = ImageEditorSmartFilter(kind: .pixelate, intensity: 0.7)
        viewModel.document.layers[layerIndex].smartFilters = [first, loaded, last]

        #expect(viewModel.loadSmartFilterIntoControls(loaded.id))
        let historyCount = viewModel.document.history.count
        viewModel.removeSmartFilterFromSelectedLayer(first.id)

        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [loaded.id, last.id])
        #expect(viewModel.loadedSmartFilterID == loaded.id)
        #expect(viewModel.selectedFilter == .sharpen)
        #expect(abs(viewModel.filterIntensity - 0.45) < 0.000_001)
        #expect(viewModel.filterUnsharpRadius == 2.5)
        #expect(viewModel.document.history.count == historyCount + 1)
    }

    @Test func removingSmartFilterDeletesMatchingStackPositionAcrossSelection() throws {
        let canvasSize = NSSize(width: 24, height: 18)
        let image = solidImage(size: canvasSize, color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-remove-selected.png", image: image) { _ in }
        let primaryIndex = try #require(viewModel.document.selectedLayerIndex)
        let primaryID = viewModel.document.layers[primaryIndex].id
        let primaryLead = ImageEditorSmartFilter(kind: .median, intensity: 0.2)
        let primaryTarget = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.4)
        let primaryTail = ImageEditorSmartFilter(kind: .sharpen, intensity: 0.6)
        viewModel.document.layers[primaryIndex].smartFilters = [primaryLead, primaryTarget, primaryTail]

        var secondary = ImageEditorLayer.blank(name: "Secondary", size: canvasSize)
        let secondaryLead = ImageEditorSmartFilter(kind: .pixelate, intensity: 0.3)
        let secondaryTarget = ImageEditorSmartFilter(kind: .wave, intensity: 0.5)
        let secondaryTail = ImageEditorSmartFilter(kind: .ripple, intensity: 0.7)
        secondary.smartFilters = [secondaryLead, secondaryTarget, secondaryTail]
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let lockedFilters = [
            ImageEditorSmartFilter(kind: .offset, intensity: 0.2),
            ImageEditorSmartFilter(kind: .pinch, intensity: 0.4),
            ImageEditorSmartFilter(kind: .spherize, intensity: 0.6)
        ]
        locked.smartFilters = lockedFilters
        locked.isLocked = true
        var missingPosition = ImageEditorLayer.blank(name: "Short Stack", size: canvasSize)
        let shortFilter = ImageEditorSmartFilter(kind: .findEdges, intensity: 0.8)
        missingPosition.smartFilters = [shortFilter]
        viewModel.document.layers.append(contentsOf: [secondary, locked, missingPosition])
        viewModel.document.selectedLayerID = primaryID
        viewModel.document.selectedLayerIDs = [primaryID, secondary.id, locked.id, missingPosition.id]

        #expect(viewModel.loadSmartFilterIntoControls(primaryTarget.id))
        let historyCount = viewModel.document.history.count
        #expect(viewModel.removeSmartFilterFromSelectedLayer(primaryTarget.id) == 2)

        #expect(
            viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.map(\.id)
                == [primaryLead.id, primaryTail.id]
        )
        #expect(
            viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.map(\.id)
                == [secondaryLead.id, secondaryTail.id]
        )
        #expect(viewModel.document.layers.first { $0.id == locked.id }?.smartFilters == lockedFilters)
        #expect(viewModel.document.layers.first { $0.id == missingPosition.id }?.smartFilters.map(\.id) == [shortFilter.id])
        #expect(viewModel.loadedSmartFilterID == primaryTail.id)
        #expect(viewModel.selectedFilter == .sharpen)
        #expect(viewModel.document.selectedLayerIDs == [primaryID, secondary.id, locked.id, missingPosition.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterRemoveSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterRemovedSelected", 2))

        viewModel.undo()
        #expect(
            viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.map(\.id)
                == [primaryLead.id, primaryTarget.id, primaryTail.id]
        )
        #expect(
            viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.map(\.id)
                == [secondaryLead.id, secondaryTarget.id, secondaryTail.id]
        )
        #expect(viewModel.loadedSmartFilterID == primaryTail.id)

        viewModel.redo()
        #expect(
            viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.map(\.id)
                == [primaryLead.id, primaryTail.id]
        )
        #expect(
            viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.map(\.id)
                == [secondaryLead.id, secondaryTail.id]
        )
        #expect(viewModel.loadedSmartFilterID == primaryTail.id)
    }

    @Test func togglingSmartFilterConvergesMatchingStackPositionAcrossSelection() throws {
        let canvasSize = NSSize(width: 24, height: 18)
        let image = solidImage(size: canvasSize, color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-toggle-selected.png", image: image) { _ in }
        let primaryIndex = try #require(viewModel.document.selectedLayerIndex)
        let primaryID = viewModel.document.layers[primaryIndex].id
        let primaryLead = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.2)
        let primaryTarget = ImageEditorSmartFilter(kind: .sharpen, intensity: 0.4)
        viewModel.document.layers[primaryIndex].smartFilters = [primaryLead, primaryTarget]

        var secondary = ImageEditorLayer.blank(name: "Secondary", size: canvasSize)
        secondary.smartFilters = [
            ImageEditorSmartFilter(kind: .pixelate, intensity: 0.3),
            ImageEditorSmartFilter(kind: .wave, intensity: 0.5)
        ]
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        locked.smartFilters = [
            ImageEditorSmartFilter(kind: .median, intensity: 0.6),
            ImageEditorSmartFilter(kind: .ripple, intensity: 0.7)
        ]
        locked.isLocked = true
        var missingPosition = ImageEditorLayer.blank(name: "Short Stack", size: canvasSize)
        missingPosition.smartFilters = [ImageEditorSmartFilter(kind: .offset, intensity: 0.8)]
        viewModel.document.layers.append(contentsOf: [secondary, locked, missingPosition])
        viewModel.document.selectedLayerID = primaryID
        viewModel.document.selectedLayerIDs = [primaryID, secondary.id, locked.id, missingPosition.id]

        #expect(viewModel.loadSmartFilterIntoControls(primaryTarget.id))
        let historyCount = viewModel.document.history.count
        let disabledLayerCount = viewModel.toggleSmartFilterOnSelectedLayer(primaryTarget.id)

        let disabledPrimary = try #require(viewModel.document.layers.first { $0.id == primaryID })
        let disabledSecondary = try #require(viewModel.document.layers.first { $0.id == secondary.id })
        let skippedLocked = try #require(viewModel.document.layers.first { $0.id == locked.id })
        let skippedShort = try #require(viewModel.document.layers.first { $0.id == missingPosition.id })
        #expect(disabledPrimary.smartFilters.map(\.isEnabled) == [true, false])
        #expect(disabledSecondary.smartFilters.map(\.isEnabled) == [true, false])
        #expect(skippedLocked.smartFilters.map(\.isEnabled) == [true, true])
        #expect(skippedShort.smartFilters.map(\.isEnabled) == [true])
        #expect(disabledLayerCount == 2)
        #expect(viewModel.loadedSmartFilterID == primaryTarget.id)
        #expect(viewModel.document.selectedLayerIDs == [primaryID, secondary.id, locked.id, missingPosition.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterDisableSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterDisabledSelected", 2))

        let enabledLayerCount = viewModel.toggleSmartFilterOnSelectedLayer(primaryTarget.id)
        let enabledPrimary = try #require(viewModel.document.layers.first { $0.id == primaryID })
        let enabledSecondary = try #require(viewModel.document.layers.first { $0.id == secondary.id })
        #expect(enabledPrimary.smartFilters.map(\.isEnabled) == [true, true])
        #expect(enabledSecondary.smartFilters.map(\.isEnabled) == [true, true])
        #expect(enabledLayerCount == 2)
        #expect(viewModel.document.history.count == historyCount + 2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterEnableSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterEnabledSelected", 2))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters[1].isEnabled == false)
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters[1].isEnabled == false)
        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters[1].isEnabled == true)
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters[1].isEnabled == true)
    }

    @Test func smartFilterOpacityShowsMixedValueAndConvergesMatchingStackPosition() throws {
        let canvasSize = NSSize(width: 24, height: 18)
        let image = solidImage(size: canvasSize, color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-opacity-selected.png", image: image) { _ in }
        let primaryIndex = try #require(viewModel.document.selectedLayerIndex)
        let primaryID = viewModel.document.layers[primaryIndex].id
        let primaryLead = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.2, opacity: 0.6)
        let primaryTarget = ImageEditorSmartFilter(kind: .sharpen, intensity: 0.4, opacity: 0.25)
        viewModel.document.layers[primaryIndex].smartFilters = [primaryLead, primaryTarget]

        var secondary = ImageEditorLayer.blank(name: "Secondary", size: canvasSize)
        secondary.smartFilters = [
            ImageEditorSmartFilter(kind: .pixelate, intensity: 0.3, opacity: 0.5),
            ImageEditorSmartFilter(kind: .wave, intensity: 0.5, opacity: 0.75)
        ]
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        locked.smartFilters = [
            ImageEditorSmartFilter(kind: .median, intensity: 0.6, opacity: 0.4),
            ImageEditorSmartFilter(kind: .ripple, intensity: 0.7, opacity: 0.9)
        ]
        locked.isLocked = true
        var missingPosition = ImageEditorLayer.blank(name: "Short Stack", size: canvasSize)
        missingPosition.smartFilters = [
            ImageEditorSmartFilter(kind: .offset, intensity: 0.8, opacity: 0.1)
        ]
        viewModel.document.layers.append(contentsOf: [secondary, locked, missingPosition])
        viewModel.document.selectedLayerID = primaryID
        viewModel.document.selectedLayerIDs = [primaryID, secondary.id, locked.id, missingPosition.id]

        #expect(viewModel.loadSmartFilterIntoControls(primaryTarget.id))
        #expect(viewModel.smartFilterOpacityState(primaryTarget.id) == .mixed)
        let historyCount = viewModel.document.history.count
        let updatedLayerCount = viewModel.setSmartFilterOpacityOnSelectedLayer(
            primaryTarget.id,
            opacity: 0.4
        )

        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.map(\.opacity) == [0.6, 0.4])
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.map(\.opacity) == [0.5, 0.4])
        #expect(viewModel.document.layers.first { $0.id == locked.id }?.smartFilters.map(\.opacity) == [0.4, 0.9])
        #expect(viewModel.document.layers.first { $0.id == missingPosition.id }?.smartFilters.map(\.opacity) == [0.1])
        #expect(updatedLayerCount == 2)
        #expect(viewModel.smartFilterOpacityState(primaryTarget.id) == .value(0.4))
        #expect(viewModel.loadedSmartFilterID == primaryTarget.id)
        #expect(viewModel.document.selectedLayerIDs == [primaryID, secondary.id, locked.id, missingPosition.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterOpacitySelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterOpacitySelected", 40, 2))

        let noOpLayerCount = viewModel.setSmartFilterOpacityOnSelectedLayer(primaryTarget.id, opacity: 0.4)
        #expect(noOpLayerCount == 0)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.smartFilterOpacityState(primaryTarget.id) == .mixed)
        let convergedLayerCount = viewModel.setSmartFilterOpacityOnSelectedLayer(
            primaryTarget.id,
            opacity: 0.25
        )
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters[1].opacity == 0.25)
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters[1].opacity == 0.25)
        #expect(convergedLayerCount == 1)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterOpacitySelected", 25, 1))
        #expect(viewModel.smartFilterOpacityState(primaryTarget.id) == .value(0.25))
    }

    @Test func smartFilterBlendModeShowsMixedValueAndConvergesMatchingStackPosition() throws {
        let canvasSize = NSSize(width: 24, height: 18)
        let image = solidImage(size: canvasSize, color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-blend-selected.png", image: image) { _ in }
        let primaryIndex = try #require(viewModel.document.selectedLayerIndex)
        let primaryID = viewModel.document.layers[primaryIndex].id
        let primaryLead = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.2, blendMode: .overlay)
        let primaryTarget = ImageEditorSmartFilter(kind: .sharpen, intensity: 0.4, blendMode: .normal)
        viewModel.document.layers[primaryIndex].smartFilters = [primaryLead, primaryTarget]

        var secondary = ImageEditorLayer.blank(name: "Secondary", size: canvasSize)
        secondary.smartFilters = [
            ImageEditorSmartFilter(kind: .pixelate, intensity: 0.3, blendMode: .screen),
            ImageEditorSmartFilter(kind: .wave, intensity: 0.5, blendMode: .multiply)
        ]
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        locked.smartFilters = [
            ImageEditorSmartFilter(kind: .median, intensity: 0.6, blendMode: .darken),
            ImageEditorSmartFilter(kind: .ripple, intensity: 0.7, blendMode: .difference)
        ]
        locked.isLocked = true
        var missingPosition = ImageEditorLayer.blank(name: "Short Stack", size: canvasSize)
        missingPosition.smartFilters = [
            ImageEditorSmartFilter(kind: .offset, intensity: 0.8, blendMode: .lighten)
        ]
        viewModel.document.layers.append(contentsOf: [secondary, locked, missingPosition])
        viewModel.document.selectedLayerID = primaryID
        viewModel.document.selectedLayerIDs = [primaryID, secondary.id, locked.id, missingPosition.id]

        #expect(viewModel.loadSmartFilterIntoControls(primaryTarget.id))
        #expect(viewModel.smartFilterBlendModeState(primaryTarget.id) == .mixed)
        let historyCount = viewModel.document.history.count
        let updatedLayerCount = viewModel.setSmartFilterBlendModeOnSelectedLayer(
            primaryTarget.id,
            blendMode: .softLight
        )

        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.map(\.blendMode) == [.overlay, .softLight])
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.map(\.blendMode) == [.screen, .softLight])
        #expect(viewModel.document.layers.first { $0.id == locked.id }?.smartFilters.map(\.blendMode) == [.darken, .difference])
        #expect(viewModel.document.layers.first { $0.id == missingPosition.id }?.smartFilters.map(\.blendMode) == [.lighten])
        #expect(updatedLayerCount == 2)
        #expect(viewModel.smartFilterBlendModeState(primaryTarget.id) == .value(.softLight))
        #expect(viewModel.loadedSmartFilterID == primaryTarget.id)
        #expect(viewModel.document.selectedLayerIDs == [primaryID, secondary.id, locked.id, missingPosition.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterBlendModeSelected"))
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerSmartFilterBlendModeSelected",
            ImageEditorBlendMode.softLight.title,
            2
        ))

        let noOpLayerCount = viewModel.setSmartFilterBlendModeOnSelectedLayer(
            primaryTarget.id,
            blendMode: .softLight
        )
        #expect(noOpLayerCount == 0)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.smartFilterBlendModeState(primaryTarget.id) == .mixed)
        let convergedLayerCount = viewModel.setSmartFilterBlendModeOnSelectedLayer(
            primaryTarget.id,
            blendMode: .normal
        )
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters[1].blendMode == .normal)
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters[1].blendMode == .normal)
        #expect(convergedLayerCount == 1)
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.layerSmartFilterBlendModeSelected",
            ImageEditorBlendMode.normal.title,
            1
        ))
        #expect(viewModel.smartFilterBlendModeState(primaryTarget.id) == .value(.normal))
    }

    @Test func updatingLoadedSmartFilterTargetsMatchingStackPositionAcrossSelection() throws {
        let canvasSize = NSSize(width: 24, height: 18)
        let image = solidImage(size: canvasSize, color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-loaded-update.png", image: image) { _ in }
        let primaryIndex = try #require(viewModel.document.selectedLayerIndex)
        let primaryID = viewModel.document.layers[primaryIndex].id
        let primaryTarget = ImageEditorSmartFilter(kind: .median, intensity: 0.25)
        let primaryTail = ImageEditorSmartFilter(kind: .sharpen, intensity: 0.35)
        viewModel.document.layers[primaryIndex].smartFilters = [primaryTarget, primaryTail]

        var secondaryLayer = ImageEditorLayer.blank(name: "Secondary", size: canvasSize)
        let secondaryTarget = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.45)
        let secondaryTail = ImageEditorSmartFilter(kind: .wave, intensity: 0.55)
        secondaryLayer.smartFilters = [secondaryTarget, secondaryTail]
        viewModel.document.layers.append(secondaryLayer)
        viewModel.document.selectedLayerID = primaryID
        viewModel.document.selectedLayerIDs = [primaryID, secondaryLayer.id]

        #expect(viewModel.loadSmartFilterIntoControls(primaryTarget.id))
        #expect(viewModel.canUpdateLoadedSmartFilterOnSelectedLayer)
        #expect(viewModel.loadedSmartFilterHasPendingChanges)
        #expect(viewModel.smartFilterHasPendingControlChanges(primaryTarget.id))
        #expect(!viewModel.canDiscardSmartFilterControlChanges(primaryTarget.id))
        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 0.8
        #expect(viewModel.canDiscardSmartFilterControlChanges(primaryTarget.id))
        let historyCount = viewModel.document.history.count

        viewModel.updateLoadedSmartFilterOnSelectedLayer()

        let primaryFilters = viewModel.document.layers[primaryIndex].smartFilters
        let secondaryFilters = try #require(
            viewModel.document.layers.first(where: { $0.id == secondaryLayer.id })?.smartFilters
        )
        #expect(primaryFilters[0].id == primaryTarget.id)
        #expect(primaryFilters[0].kind == .pixelate)
        #expect(primaryFilters[0].intensity == 0.8)
        #expect(primaryFilters[1].id == primaryTail.id)
        #expect(primaryFilters[1].kind == .sharpen)
        #expect(secondaryFilters[0].id == secondaryTarget.id)
        #expect(secondaryFilters[0].kind == .pixelate)
        #expect(secondaryFilters[0].intensity == 0.8)
        #expect(secondaryFilters[1].id == secondaryTail.id)
        #expect(secondaryFilters[1].kind == .wave)
        #expect(viewModel.loadedSmartFilterID == primaryTarget.id)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterUpdateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterUpdatedSelected", 2))
        #expect(!viewModel.loadedSmartFilterHasPendingChanges)
        #expect(!viewModel.smartFilterHasPendingControlChanges(primaryTarget.id))
        #expect(!viewModel.canUpdateLoadedSmartFilterOnSelectedLayer)

        viewModel.undo()
        #expect(viewModel.document.layers[primaryIndex].smartFilters[0].kind == .median)
        #expect(viewModel.document.layers[primaryIndex].smartFilters[1].kind == .sharpen)
        let restoredSecondary = try #require(
            viewModel.document.layers.first(where: { $0.id == secondaryLayer.id })?.smartFilters
        )
        #expect(restoredSecondary[0].kind == .gaussianBlur)
        #expect(restoredSecondary[1].kind == .wave)

        viewModel.selectFilter(.wave)
        viewModel.filterIntensity = 0.65
        #expect(viewModel.loadedSmartFilterID == nil)
        viewModel.updateLoadedSmartFilterOnSelectedLayer()
        #expect(viewModel.document.layers[primaryIndex].smartFilters[0].kind == .median)
        #expect(viewModel.document.layers[primaryIndex].smartFilters[1].kind == .wave)
        let fallbackSecondary = try #require(
            viewModel.document.layers.first(where: { $0.id == secondaryLayer.id })?.smartFilters
        )
        #expect(fallbackSecondary[0].kind == .gaussianBlur)
        #expect(fallbackSecondary[1].kind == .wave)
        #expect(fallbackSecondary[1].intensity == 0.65)
        viewModel.undo()

        #expect(viewModel.loadSmartFilterIntoControls(primaryTarget.id))
        viewModel.document.layers[primaryIndex].isLocked = true
        #expect(!viewModel.canUpdateLoadedSmartFilterOnSelectedLayer)
        let lockedHistoryCount = viewModel.document.history.count
        viewModel.updateLoadedSmartFilterOnSelectedLayer()
        #expect(viewModel.document.history.count == lockedHistoryCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @Test func loadedSmartFilterPendingChangesAvoidNoOpHistoryAndClearAfterUpdate() throws {
        let image = solidImage(size: NSSize(width: 24, height: 18), color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-pending.png", image: image) { _ in }
        viewModel.selectedFilter = .median
        viewModel.filterIntensity = 0.4
        viewModel.addSmartFilterToSelectedLayer()

        let filterID = try #require(viewModel.document.selectedLayer?.smartFilters.first?.id)
        #expect(viewModel.loadSmartFilterIntoControls(filterID))
        #expect(!viewModel.loadedSmartFilterHasPendingChanges)
        #expect(!viewModel.smartFilterHasPendingControlChanges(filterID))
        #expect(!viewModel.canUpdateLoadedSmartFilterOnSelectedLayer)

        let initialHistoryCount = viewModel.document.history.count
        viewModel.updateLoadedSmartFilterOnSelectedLayer()
        #expect(viewModel.document.history.count == initialHistoryCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.smartFilterUnchanged"))

        viewModel.filterIntensity = 0.65
        #expect(viewModel.loadedSmartFilterHasPendingChanges)
        #expect(viewModel.smartFilterHasPendingControlChanges(filterID))
        #expect(viewModel.canUpdateLoadedSmartFilterOnSelectedLayer)

        viewModel.updateLoadedSmartFilterOnSelectedLayer()
        #expect(viewModel.document.selectedLayer?.smartFilters.first?.intensity == 0.65)
        #expect(viewModel.document.history.count == initialHistoryCount + 1)
        #expect(!viewModel.loadedSmartFilterHasPendingChanges)
        #expect(!viewModel.smartFilterHasPendingControlChanges(filterID))
        #expect(!viewModel.canUpdateLoadedSmartFilterOnSelectedLayer)

        let updatedHistoryCount = viewModel.document.history.count
        viewModel.updateSmartFilterOnSelectedLayer(filterID)
        #expect(viewModel.document.history.count == updatedHistoryCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.smartFilterUnchanged"))
    }

    @Test func discardingPendingSmartFilterControlsRestoresSavedValuesWithoutHistory() throws {
        let image = solidImage(size: NSSize(width: 24, height: 18), color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-discard.png", image: image) { _ in }
        let layerIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == viewModel.document.selectedLayerID }
        )
        let target = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 0.35,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 8)
        )
        viewModel.document.layers[layerIndex].smartFilters = [target]

        #expect(viewModel.loadSmartFilterIntoControls(target.id))
        let historyCount = viewModel.document.history.count

        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 0.8
        #expect(viewModel.smartFilterHasPendingControlChanges(target.id))
        #expect(viewModel.canDiscardSmartFilterControlChanges(target.id))
        #expect(viewModel.canDiscardLoadedSmartFilterControlChanges)

        #expect(viewModel.discardLoadedSmartFilterControlChanges())
        #expect(viewModel.selectedFilter == .gaussianBlur)
        #expect(abs(viewModel.filterIntensity - 0.35) < 0.000_001)
        #expect(viewModel.filterGaussianBlurRadius == 8)
        #expect(!viewModel.smartFilterHasPendingControlChanges(target.id))
        #expect(!viewModel.canDiscardSmartFilterControlChanges(target.id))
        #expect(!viewModel.canDiscardLoadedSmartFilterControlChanges)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.smartFilterChangesDiscarded"))
        #expect(!viewModel.discardSmartFilterControlChanges(target.id))
        #expect(!viewModel.discardLoadedSmartFilterControlChanges())
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func duplicatingSmartFilterPreservesCompleteSettingsAndSupportsUndoRedo() throws {
        let image = solidImage(
            size: NSSize(width: 32, height: 24),
            color: NSColor(calibratedRed: 0.3, green: 0.5, blue: 0.7, alpha: 0.8)
        )
        let viewModel = ImageEditorViewModel(sourceName: "duplicate-smart-filter.png", image: image) { _ in }
        let layerIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == viewModel.document.selectedLayerID }
        )
        let original = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 0.67,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 14),
            isEnabled: false,
            opacity: 0.35,
            blendMode: .softLight,
            appliesToBackdrop: true
        )
        viewModel.document.layers[layerIndex].smartFilters = [original]

        let duplication = try #require(viewModel.duplicateSmartFilterOnSelectedLayer(original.id))
        let duplicateID = try #require(duplication.primaryDuplicateID)
        #expect(duplication.duplicatedLayerCount == 1)
        let duplicatedFilters = viewModel.document.layers[layerIndex].smartFilters
        #expect(duplicatedFilters.map(\.id) == [original.id, duplicateID])
        let duplicate = try #require(duplicatedFilters.last)
        #expect(duplicate.kind == original.kind)
        #expect(duplicate.intensity == original.intensity)
        #expect(duplicate.settings == original.settings)
        #expect(duplicate.isEnabled == original.isEnabled)
        #expect(duplicate.normalizedOpacity == original.normalizedOpacity)
        #expect(duplicate.normalizedBlendMode == original.normalizedBlendMode)
        #expect(duplicate.appliesToBackdrop == original.appliesToBackdrop)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterDuplicate"))

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [original.id])

        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [original.id, duplicateID])
    }

    @Test func duplicatingSmartFilterCopiesEachSelectedLayersMatchingStackPosition() throws {
        let canvasSize = NSSize(width: 24, height: 18)
        let image = solidImage(size: canvasSize, color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "duplicate-smart-filter-selected.png", image: image) { _ in }
        let primaryIndex = try #require(viewModel.document.selectedLayerIndex)
        let primaryID = viewModel.document.layers[primaryIndex].id
        let primaryLead = ImageEditorSmartFilter(kind: .median, intensity: 0.2)
        let primaryTarget = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 0.67,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 14),
            isEnabled: false,
            opacity: 0.35,
            blendMode: .softLight,
            appliesToBackdrop: true
        )
        viewModel.document.layers[primaryIndex].smartFilters = [primaryLead, primaryTarget]

        var secondary = ImageEditorLayer.blank(name: "Secondary", size: canvasSize)
        let secondaryLead = ImageEditorSmartFilter(kind: .pixelate, intensity: 0.3)
        let secondaryTarget = ImageEditorSmartFilter(
            kind: .wave,
            intensity: 0.42,
            settings: ImageEditorFilterSettings(waveAmplitude: 0.7, waveFrequency: 0.8),
            opacity: 0.8,
            blendMode: .screen
        )
        secondary.smartFilters = [secondaryLead, secondaryTarget]
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        locked.smartFilters = [
            ImageEditorSmartFilter(kind: .sharpen, intensity: 0.5),
            ImageEditorSmartFilter(kind: .ripple, intensity: 0.6)
        ]
        locked.isLocked = true
        var missingPosition = ImageEditorLayer.blank(name: "Short Stack", size: canvasSize)
        missingPosition.smartFilters = [ImageEditorSmartFilter(kind: .offset, intensity: 0.7)]
        viewModel.document.layers.append(contentsOf: [secondary, locked, missingPosition])
        viewModel.document.selectedLayerID = primaryID
        viewModel.document.selectedLayerIDs = [primaryID, secondary.id, locked.id, missingPosition.id]

        #expect(viewModel.loadSmartFilterIntoControls(primaryTarget.id))
        let historyCount = viewModel.document.history.count
        let duplication = try #require(
            viewModel.duplicateSmartFilterOnSelectedLayer(primaryTarget.id)
        )
        let primaryDuplicateID = try #require(duplication.primaryDuplicateID)
        #expect(duplication.duplicatedLayerCount == 2)

        let primaryFilters = try #require(
            viewModel.document.layers.first { $0.id == primaryID }?.smartFilters
        )
        let secondaryFilters = try #require(
            viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters
        )
        #expect(primaryFilters.count == 3)
        #expect(secondaryFilters.count == 3)
        #expect(primaryFilters.map(\.id) == [primaryLead.id, primaryTarget.id, primaryDuplicateID])
        #expect(secondaryFilters[2].id != secondaryTarget.id)
        #expect(secondaryFilters[2].id != primaryDuplicateID)
        var normalizedPrimaryDuplicate = primaryFilters[2]
        normalizedPrimaryDuplicate.id = primaryTarget.id
        var normalizedSecondaryDuplicate = secondaryFilters[2]
        normalizedSecondaryDuplicate.id = secondaryTarget.id
        #expect(normalizedPrimaryDuplicate == primaryTarget)
        #expect(normalizedSecondaryDuplicate == secondaryTarget)
        #expect(viewModel.document.layers.first { $0.id == locked.id }?.smartFilters.count == 2)
        #expect(viewModel.document.layers.first { $0.id == missingPosition.id }?.smartFilters.count == 1)
        #expect(viewModel.loadedSmartFilterID == primaryDuplicateID)
        #expect(viewModel.document.selectedLayerIDs == [primaryID, secondary.id, locked.id, missingPosition.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterDuplicateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterDuplicatedSelected", 2))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.map(\.id) == [primaryLead.id, primaryTarget.id])
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.map(\.id) == [secondaryLead.id, secondaryTarget.id])
        #expect(viewModel.loadedSmartFilterID == primaryTarget.id)

        viewModel.redo()
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.last?.id == primaryDuplicateID)
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.count == 3)
        #expect(viewModel.loadedSmartFilterID == primaryDuplicateID)
    }

    @Test func smartFilterMoveAvailabilityDisablesBoundariesAndAvoidsEmptyHistory() throws {
        let image = solidImage(size: NSSize(width: 24, height: 18), color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-move-boundaries.png", image: image) { _ in }
        let layerIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == viewModel.document.selectedLayerID }
        )
        let first = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.2)
        let middle = ImageEditorSmartFilter(kind: .sharpen, intensity: 0.4)
        let last = ImageEditorSmartFilter(kind: .pixelate, intensity: 0.6)
        viewModel.document.layers[layerIndex].smartFilters = [first, middle, last]

        #expect(!viewModel.canMoveSmartFilterOnSelectedLayer(first.id, offset: -1))
        #expect(viewModel.canMoveSmartFilterOnSelectedLayer(first.id, offset: 1))
        #expect(viewModel.canMoveSmartFilterOnSelectedLayer(middle.id, offset: -1))
        #expect(viewModel.canMoveSmartFilterOnSelectedLayer(middle.id, offset: 1))
        #expect(viewModel.canMoveSmartFilterOnSelectedLayer(last.id, offset: -1))
        #expect(!viewModel.canMoveSmartFilterOnSelectedLayer(last.id, offset: 1))

        let historyCount = viewModel.document.history.count
        #expect(viewModel.moveSmartFilterOnSelectedLayer(first.id, offset: -1) == 0)
        #expect(viewModel.document.history.count == historyCount)

        #expect(viewModel.loadSmartFilterIntoControls(middle.id))
        #expect(viewModel.moveSmartFilterOnSelectedLayer(middle.id, offset: -1) == 1)
        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [middle.id, first.id, last.id])
        #expect(viewModel.isSmartFilterLoadedForEditing(middle.id))
        #expect(!viewModel.canMoveSmartFilterOnSelectedLayer(middle.id, offset: -1))
        #expect(viewModel.canMoveSmartFilterOnSelectedLayer(middle.id, offset: 1))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterMove"))

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.smartFilters.map(\.id) == [first.id, middle.id, last.id])
    }

    @Test func movingSmartFilterReordersMatchingStackPositionAcrossSelection() throws {
        let canvasSize = NSSize(width: 24, height: 18)
        let image = solidImage(size: canvasSize, color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-move-selected.png", image: image) { _ in }
        let primaryIndex = try #require(viewModel.document.selectedLayerIndex)
        let primaryID = viewModel.document.layers[primaryIndex].id
        let primaryLead = ImageEditorSmartFilter(kind: .median, intensity: 0.2)
        let primaryTarget = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 0.4,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 18),
            isEnabled: false,
            opacity: 0.35,
            blendMode: .softLight,
            appliesToBackdrop: true
        )
        let primaryTail = ImageEditorSmartFilter(kind: .sharpen, intensity: 0.6)
        viewModel.document.layers[primaryIndex].smartFilters = [primaryLead, primaryTarget, primaryTail]

        var secondary = ImageEditorLayer.blank(name: "Secondary", size: canvasSize)
        let secondaryLead = ImageEditorSmartFilter(kind: .pixelate, intensity: 0.3)
        let secondaryTarget = ImageEditorSmartFilter(
            kind: .wave,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(waveAmplitude: 0.7, waveFrequency: 0.8),
            opacity: 0.75,
            blendMode: .screen
        )
        let secondaryTail = ImageEditorSmartFilter(kind: .ripple, intensity: 0.7)
        secondary.smartFilters = [secondaryLead, secondaryTarget, secondaryTail]
        var locked = ImageEditorLayer.blank(name: "Locked", size: canvasSize)
        let lockedFilters = [
            ImageEditorSmartFilter(kind: .offset, intensity: 0.2),
            ImageEditorSmartFilter(kind: .pinch, intensity: 0.4),
            ImageEditorSmartFilter(kind: .spherize, intensity: 0.6)
        ]
        locked.smartFilters = lockedFilters
        locked.isLocked = true
        var missingDestination = ImageEditorLayer.blank(name: "Short Stack", size: canvasSize)
        let shortLead = ImageEditorSmartFilter(kind: .findEdges, intensity: 0.3)
        let shortTarget = ImageEditorSmartFilter(kind: .emboss, intensity: 0.5)
        missingDestination.smartFilters = [shortLead, shortTarget]
        viewModel.document.layers.append(contentsOf: [secondary, locked, missingDestination])
        viewModel.document.selectedLayerID = primaryID
        viewModel.document.selectedLayerIDs = [primaryID, secondary.id, locked.id, missingDestination.id]

        #expect(viewModel.loadSmartFilterIntoControls(primaryTarget.id))
        let historyCount = viewModel.document.history.count
        #expect(viewModel.moveSmartFilterOnSelectedLayer(primaryTarget.id, offset: 1) == 2)

        #expect(
            viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.map(\.id)
                == [primaryLead.id, primaryTail.id, primaryTarget.id]
        )
        #expect(
            viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.map(\.id)
                == [secondaryLead.id, secondaryTail.id, secondaryTarget.id]
        )
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.last == primaryTarget)
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.last == secondaryTarget)
        #expect(viewModel.document.layers.first { $0.id == locked.id }?.smartFilters == lockedFilters)
        #expect(
            viewModel.document.layers.first { $0.id == missingDestination.id }?.smartFilters.map(\.id)
                == [shortLead.id, shortTarget.id]
        )
        #expect(viewModel.isSmartFilterLoadedForEditing(primaryTarget.id))
        #expect(viewModel.document.selectedLayerIDs == [primaryID, secondary.id, locked.id, missingDestination.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterMoveSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterMovedSelected", 2))

        viewModel.undo()
        #expect(
            viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.map(\.id)
                == [primaryLead.id, primaryTarget.id, primaryTail.id]
        )
        #expect(
            viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.map(\.id)
                == [secondaryLead.id, secondaryTarget.id, secondaryTail.id]
        )
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters[1] == primaryTarget)
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters[1] == secondaryTarget)
        #expect(viewModel.loadedSmartFilterID == primaryTail.id)

        viewModel.redo()
        #expect(viewModel.isSmartFilterLoadedForEditing(primaryTarget.id))
        #expect(viewModel.moveSmartFilterOnSelectedLayer(primaryTarget.id, offset: -1) == 2)
        #expect(
            viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.map(\.id)
                == [primaryLead.id, primaryTarget.id, primaryTail.id]
        )
        #expect(
            viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.map(\.id)
                == [secondaryLead.id, secondaryTarget.id, secondaryTail.id]
        )
        #expect(viewModel.isSmartFilterLoadedForEditing(primaryTarget.id))
        #expect(viewModel.document.history.count == historyCount + 2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterMoveSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterMovedSelected", 2))
    }

    @Test func movingSmartFilterUsesLockedPrimaryAsStackAnchorAndReportsActualCount() throws {
        let canvasSize = NSSize(width: 24, height: 18)
        let image = solidImage(size: canvasSize, color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-move-locked-anchor.png", image: image) { _ in }
        let primaryIndex = try #require(viewModel.document.selectedLayerIndex)
        let primaryID = viewModel.document.layers[primaryIndex].id
        let primaryLead = ImageEditorSmartFilter(kind: .median, intensity: 0.2)
        let primaryTarget = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.4)
        let primaryTail = ImageEditorSmartFilter(kind: .sharpen, intensity: 0.6)
        viewModel.document.layers[primaryIndex].smartFilters = [primaryLead, primaryTarget, primaryTail]
        viewModel.document.layers[primaryIndex].isLocked = true

        var peer = ImageEditorLayer.blank(name: "Peer", size: canvasSize)
        let peerLead = ImageEditorSmartFilter(kind: .pixelate, intensity: 0.3)
        let peerTarget = ImageEditorSmartFilter(kind: .wave, intensity: 0.5)
        let peerTail = ImageEditorSmartFilter(kind: .ripple, intensity: 0.7)
        peer.smartFilters = [peerLead, peerTarget, peerTail]
        var shortPeer = ImageEditorLayer.blank(name: "Short Peer", size: canvasSize)
        shortPeer.smartFilters = [
            ImageEditorSmartFilter(kind: .findEdges, intensity: 0.3),
            ImageEditorSmartFilter(kind: .emboss, intensity: 0.5)
        ]
        viewModel.document.layers.append(contentsOf: [peer, shortPeer])
        viewModel.document.selectedLayerID = primaryID
        viewModel.document.selectedLayerIDs = [primaryID, peer.id, shortPeer.id]

        #expect(viewModel.loadSmartFilterIntoControls(primaryTarget.id))
        #expect(viewModel.canMoveSmartFilterOnSelectedLayer(primaryTarget.id, offset: 1))
        let historyCount = viewModel.document.history.count
        #expect(viewModel.moveSmartFilterOnSelectedLayer(primaryTarget.id, offset: 1) == 1)
        #expect(
            viewModel.document.layers.first { $0.id == primaryID }?.smartFilters.map(\.id)
                == [primaryLead.id, primaryTarget.id, primaryTail.id]
        )
        #expect(
            viewModel.document.layers.first { $0.id == peer.id }?.smartFilters.map(\.id)
                == [peerLead.id, peerTail.id, peerTarget.id]
        )
        #expect(viewModel.document.layers.first { $0.id == shortPeer.id }?.smartFilters.count == 2)
        #expect(viewModel.loadedSmartFilterID == primaryTarget.id)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterMove"))

        viewModel.undo()
        #expect(
            viewModel.document.layers.first { $0.id == peer.id }?.smartFilters.map(\.id)
                == [peerLead.id, peerTarget.id, peerTail.id]
        )
        #expect(viewModel.loadedSmartFilterID == primaryTail.id)
    }

    @Test func clearingSmartFiltersAcrossSelectionReportsCountAndPreservesSkippedLoadedFilter() throws {
        let canvasSize = NSSize(width: 24, height: 18)
        let image = solidImage(size: canvasSize, color: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "smart-filter-clear-selected.png", image: image) { _ in }
        let primaryIndex = try #require(viewModel.document.selectedLayerIndex)
        let primaryID = viewModel.document.layers[primaryIndex].id
        let primaryLead = ImageEditorSmartFilter(kind: .median, intensity: 0.2)
        let primaryTarget = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 0.4,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 18),
            opacity: 0.35,
            blendMode: .softLight
        )
        let primaryFilters = [primaryLead, primaryTarget]
        viewModel.document.layers[primaryIndex].smartFilters = primaryFilters

        var secondary = ImageEditorLayer.blank(name: "Secondary", size: canvasSize)
        let secondaryFilters = [
            ImageEditorSmartFilter(kind: .pixelate, intensity: 0.3),
            ImageEditorSmartFilter(
                kind: .wave,
                intensity: 0.5,
                settings: ImageEditorFilterSettings(waveAmplitude: 0.7, waveFrequency: 0.8),
                opacity: 0.75,
                blendMode: .screen
            )
        ]
        secondary.smartFilters = secondaryFilters
        var tertiary = ImageEditorLayer.blank(name: "Tertiary", size: canvasSize)
        let tertiaryFilters = [ImageEditorSmartFilter(kind: .ripple, intensity: 0.7)]
        tertiary.smartFilters = tertiaryFilters
        let empty = ImageEditorLayer.blank(name: "Empty", size: canvasSize)
        viewModel.document.layers.append(contentsOf: [secondary, tertiary, empty])
        viewModel.document.selectedLayerID = primaryID
        viewModel.document.selectedLayerIDs = [primaryID, secondary.id, tertiary.id, empty.id]

        #expect(viewModel.loadSmartFilterIntoControls(primaryTarget.id))
        viewModel.document.layers[primaryIndex].isLocked = true
        let historyCount = viewModel.document.history.count
        #expect(viewModel.canClearSmartFiltersFromSelectedLayer)
        #expect(viewModel.clearSmartFiltersFromSelectedLayer() == 2)

        #expect(viewModel.document.layers.first { $0.id == primaryID }?.smartFilters == primaryFilters)
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.isEmpty == true)
        #expect(viewModel.document.layers.first { $0.id == tertiary.id }?.smartFilters.isEmpty == true)
        #expect(viewModel.document.layers.first { $0.id == empty.id }?.smartFilters.isEmpty == true)
        #expect(viewModel.isSmartFilterLoadedForEditing(primaryTarget.id))
        #expect(viewModel.document.selectedLayerIDs == [primaryID, secondary.id, tertiary.id, empty.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterClearSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterClearedSelected", 2))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters == secondaryFilters)
        #expect(viewModel.document.layers.first { $0.id == tertiary.id }?.smartFilters == tertiaryFilters)
        #expect(viewModel.isSmartFilterLoadedForEditing(primaryTarget.id))

        viewModel.redo()
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters.isEmpty == true)
        #expect(viewModel.document.layers.first { $0.id == tertiary.id }?.smartFilters.isEmpty == true)
        #expect(viewModel.isSmartFilterLoadedForEditing(primaryTarget.id))
        let historyCountBeforeNoOp = viewModel.document.history.count
        #expect(viewModel.clearSmartFiltersFromSelectedLayer() == 0)
        #expect(viewModel.document.history.count == historyCountBeforeNoOp)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == secondary.id }?.smartFilters == secondaryFilters)
        #expect(viewModel.document.layers.first { $0.id == tertiary.id }?.smartFilters == tertiaryFilters)
    }

    @Test func zeroStrengthMaskedFilterPreservesSemiTransparentPixels() throws {
        let canvasSize = NSSize(width: 32, height: 24)
        let sourceImage = solidImage(
            size: canvasSize,
            color: NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.85, alpha: 0.35)
        )
        let mask = solidImage(size: canvasSize, color: .white)

        let directOutput = try #require(
            sourceImage.applyingFilter(kind: .pixelate, intensity: 0, mask: mask)
        )
        let negativeOutput = try #require(
            sourceImage.applyingFilter(kind: .pixelate, intensity: -1, mask: mask)
        )
        #expect(directOutput === sourceImage)
        #expect(negativeOutput === sourceImage)
        #expect(imageEditorMaximumPixelDifference(directOutput, sourceImage) == 0)
        #expect(imageEditorMaximumPixelDifference(negativeOutput, sourceImage) == 0)

        let viewModel = ImageEditorViewModel(
            sourceName: "zero-masked-filter.png",
            image: sourceImage
        ) { _ in }
        let compositeBefore = viewModel.currentImage
        viewModel.selectedFilter = .emboss
        viewModel.filterIntensity = 0
        viewModel.addFilterLayer()

        let filterLayerIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == viewModel.document.selectedLayerID }
        )
        viewModel.document.layers[filterLayerIndex].mask = mask

        #expect(viewModel.document.layers[filterLayerIndex].isFilter)
        #expect(viewModel.document.layers[filterLayerIndex].mask != nil)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, compositeBefore) == 0)
    }

    @Test func maskedFilterInterpolatesPixelsWithoutIncreasingSourceAlpha() throws {
        let canvasSize = NSSize(width: 32, height: 24)
        let sourceImage = solidImage(
            size: canvasSize,
            color: NSColor(calibratedRed: 0.30, green: 0.55, blue: 0.75, alpha: 0.35)
        )
        let mask = splitColorImage(
            size: canvasSize,
            left: NSColor(calibratedWhite: 1, alpha: 0.5),
            right: .clear
        )

        let output = try #require(
            sourceImage.applyingFilter(kind: .addNoise, intensity: 1, mask: mask)
        )
        let sourceLeft = try #require(
            sourceImage.color(at: CGPoint(x: 8, y: 12))?.usingColorSpace(.deviceRGB)
        )
        let outputLeft = try #require(
            output.color(at: CGPoint(x: 8, y: 12))?.usingColorSpace(.deviceRGB)
        )
        let sourceRight = try #require(
            sourceImage.color(at: CGPoint(x: 24, y: 12))?.usingColorSpace(.deviceRGB)
        )
        let outputRight = try #require(
            output.color(at: CGPoint(x: 24, y: 12))?.usingColorSpace(.deviceRGB)
        )

        #expect(abs(outputLeft.alphaComponent - sourceLeft.alphaComponent) < 0.01)
        #expect(abs(outputRight.alphaComponent - sourceRight.alphaComponent) < 0.01)
        #expect(abs(outputRight.redComponent - sourceRight.redComponent) < 0.01)
        #expect(abs(outputRight.greenComponent - sourceRight.greenComponent) < 0.01)
        #expect(abs(outputRight.blueComponent - sourceRight.blueComponent) < 0.01)
        #expect(imageEditorMaximumPixelDifference(output, sourceImage) > 0)
    }

    @Test func filterLayerOpacityBlendsTheCompletedEffectWithoutChangingItsParameters() throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let sourceImage = splitColorImage(
            size: canvasSize,
            left: NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1),
            right: NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1)
        )
        let viewModel = ImageEditorViewModel(
            sourceName: "filter-layer-opacity.png",
            image: sourceImage
        ) { _ in }
        viewModel.selectedFilter = .offset
        viewModel.filterIntensity = 1
        viewModel.filterOffsetX = 1
        viewModel.filterOffsetY = 0
        viewModel.addFilterLayer()

        let filterIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == viewModel.document.selectedLayerID }
        )
        let baseIndex = try #require(
            viewModel.document.layers.indices.first { !viewModel.document.layers[$0].isFilter }
        )
        let mask = splitColorImage(
            size: canvasSize,
            left: .white,
            right: .clear
        )
        viewModel.document.layers[filterIndex].mask = mask
        viewModel.setSelectedLayerOpacity(0.5)

        var settings = ImageEditorFilterSettings()
        settings.offsetX = 1
        settings.offsetY = 0
        let expectedImage = try #require(
            sourceImage.applyingFilter(
                kind: .offset,
                intensity: 1,
                settings: settings,
                mask: mask,
                opacity: 0.5
            )
        )
        let parameterScaledImage = try #require(
            sourceImage.applyingFilter(
                kind: .offset,
                intensity: 0.5,
                settings: settings,
                mask: mask
            )
        )
        let expectedSample = try #require(
            expectedImage.color(at: CGPoint(x: 12, y: 16))?.usingColorSpace(.deviceRGB)
        )
        let sourceRight = try #require(
            sourceImage.color(at: CGPoint(x: 36, y: 16))?.usingColorSpace(.deviceRGB)
        )
        let filteredSample = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 12, y: 16))?.usingColorSpace(.deviceRGB)
        )
        let maskedOutSample = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 36, y: 16))?.usingColorSpace(.deviceRGB)
        )
        let filterLayer = viewModel.document.layers[filterIndex]
        let merged = try #require(viewModel.mergedFilterLayer(lowerIndex: baseIndex, filterIndex: filterIndex))

        #expect(filterLayer.filter?.intensity == 1)
        #expect(abs(filteredSample.redComponent - expectedSample.redComponent) < 0.01)
        #expect(abs(filteredSample.greenComponent - expectedSample.greenComponent) < 0.01)
        #expect(abs(filteredSample.blueComponent - expectedSample.blueComponent) < 0.01)
        #expect(abs(maskedOutSample.redComponent - sourceRight.redComponent) < 0.01)
        #expect(abs(maskedOutSample.greenComponent - sourceRight.greenComponent) < 0.01)
        #expect(abs(maskedOutSample.blueComponent - sourceRight.blueComponent) < 0.01)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, expectedImage) == 0)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, parameterScaledImage) > 0)
        #expect(imageEditorMaximumPixelDifference(merged.image, viewModel.currentImage) == 0)
    }

    @Test func imageEditorAppliesCurrentFilterWithClassicLastFilterCommand() throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let sourceImage = solidImage(size: canvasSize, color: NSColor(calibratedWhite: 0.5, alpha: 1))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            sourceImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        let beforeA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 16))?.usingColorSpace(.deviceRGB))
        let beforeB = try #require(viewModel.currentImage.color(at: CGPoint(x: 13, y: 16))?.usingColorSpace(.deviceRGB))

        #expect(viewModel.canApplySelectedFilter)
        viewModel.selectedFilter = .addNoise
        viewModel.filterIntensity = 0.8
        viewModel.applySelectedFilter()

        let afterA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 16))?.usingColorSpace(.deviceRGB))
        let afterB = try #require(viewModel.currentImage.color(at: CGPoint(x: 13, y: 16))?.usingColorSpace(.deviceRGB))

        #expect(abs(beforeA.redComponent - beforeB.redComponent) < 0.002)
        #expect(abs(afterA.redComponent - afterB.redComponent) > 0.02)
        #expect(viewModel.document.history.last?.title == L10n.format("imageEditor.history.filter", ImageEditorFilter.addNoise.title))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.filter", ImageEditorFilter.addNoise.title))
    }

    @Test func commandFRepeatsTheLastSuccessfulFilterAndItsParameters() throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let sourceImage = gradientImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            sourceImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.2
        viewModel.applySelectedFilter()
        let invocation = try #require(viewModel.lastAppliedFilter)

        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 0.9
        let beforeRepeat = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.applyLastFilter()
        let afterRepeat = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(invocation.kind == .gaussianBlur)
        #expect(invocation.intensity == 0.2)
        #expect(viewModel.lastAppliedFilter == invocation)
        #expect(afterRepeat != beforeRepeat)
        #expect(viewModel.document.history.last?.title == L10n.format("imageEditor.history.filter", ImageEditorFilter.gaussianBlur.title))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.filter", ImageEditorFilter.gaussianBlur.title))
    }

    @Test func imageEditorBatchAddsUpdatesAndClearsSmartFiltersAcrossEditableSelection() async throws {
        let canvasSize = NSSize(width: 32, height: 24)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(size: canvasSize, color: .black)
        ) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(lockedID)
        viewModel.addLayerGroup()
        let groupID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(lockedID, extendingSelection: true)
        viewModel.selectLayer(groupID, extendingSelection: true)

        #expect(viewModel.canAddSmartFilterToSelectedLayer)
        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.35
        let addedLayerCount = viewModel.addSmartFilterToSelectedLayer()

        var first = try #require(layer(firstID, in: viewModel))
        var second = try #require(layer(secondID, in: viewModel))
        var locked = try #require(layer(lockedID, in: viewModel))
        var group = try #require(layer(groupID, in: viewModel))
        #expect(first.smartFilters.count == 1)
        #expect(first.smartFilters.first?.kind == .gaussianBlur)
        #expect(first.smartFilters.first?.intensity == 0.35)
        #expect(second.smartFilters.count == 1)
        #expect(second.smartFilters.first?.kind == .gaussianBlur)
        #expect(second.smartFilters.first?.intensity == 0.35)
        #expect(locked.smartFilters.isEmpty)
        #expect(group.smartFilters.isEmpty)
        #expect(addedLayerCount == 2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAddSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterAddedSelected", 2))

        #expect(viewModel.canUpdateLastSmartFilterOnSelectedLayer)
        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 0.8
        let updatedLayerCount = viewModel.updateLastSmartFilterOnSelectedLayer()

        first = try #require(layer(firstID, in: viewModel))
        second = try #require(layer(secondID, in: viewModel))
        locked = try #require(layer(lockedID, in: viewModel))
        group = try #require(layer(groupID, in: viewModel))
        #expect(first.smartFilters.count == 1)
        #expect(first.smartFilters.first?.kind == .pixelate)
        #expect(first.smartFilters.first?.intensity == 0.8)
        #expect(first.smartFilters.first?.isEnabled == true)
        #expect(second.smartFilters.count == 1)
        #expect(second.smartFilters.first?.kind == .pixelate)
        #expect(second.smartFilters.first?.intensity == 0.8)
        #expect(second.smartFilters.first?.isEnabled == true)
        #expect(locked.smartFilters.isEmpty)
        #expect(group.smartFilters.isEmpty)
        #expect(updatedLayerCount == 2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterUpdateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterUpdatedSelected", 2))

        #expect(viewModel.canClearSmartFiltersFromSelectedLayer)
        let clearedLayerCount = viewModel.clearSmartFiltersFromSelectedLayer()

        first = try #require(layer(firstID, in: viewModel))
        second = try #require(layer(secondID, in: viewModel))
        locked = try #require(layer(lockedID, in: viewModel))
        group = try #require(layer(groupID, in: viewModel))
        #expect(first.smartFilters.isEmpty)
        #expect(second.smartFilters.isEmpty)
        #expect(locked.smartFilters.isEmpty)
        #expect(group.smartFilters.isEmpty)
        #expect(!viewModel.canUpdateLastSmartFilterOnSelectedLayer)
        #expect(!viewModel.canClearSmartFiltersFromSelectedLayer)
        #expect(clearedLayerCount == 2)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterClearSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerSmartFilterClearedSelected", 2))
    }

    @Test func backgroundBlurSmartFilterSamplesTheBackdropWithoutChangingLayerPixels() throws {
        let canvasSize = NSSize(width: 64, height: 32)
        let sourceImage = splitColorImage(
            size: canvasSize,
            left: .black,
            right: .white
        )
        let plainViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let plainLayer = ImageEditorLayer.blank(name: "Glass", size: NSSize(width: 24, height: 32))
        var plain = plainLayer
        plain.image = solidImage(
            size: NSSize(width: 24, height: 32),
            color: NSColor.white.withAlphaComponent(0.2)
        )
        plain.frame = CGRect(x: 20, y: 0, width: 24, height: 32)
        plainViewModel.document.layers.append(plain)

        let blurredViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        var blurred = plain
        var filter = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 1,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 6)
        )
        filter.appliesToBackdrop = true
        blurred.smartFilters = [filter]
        blurredViewModel.document.layers.append(blurred)

        let halfBlurredViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        var halfBlurred = plain
        filter.opacity = 0.5
        halfBlurred.smartFilters = [filter]
        halfBlurredViewModel.document.layers.append(halfBlurred)

        let plainColor = try #require(
            plainViewModel.document.compositedImage.color(at: CGPoint(x: 32, y: 16))?.usingColorSpace(.deviceRGB)
        )
        let blurredColor = try #require(
            blurredViewModel.document.compositedImage.color(at: CGPoint(x: 32, y: 16))?.usingColorSpace(.deviceRGB)
        )
        let halfBlurredColor = try #require(
            halfBlurredViewModel.document.compositedImage.color(at: CGPoint(x: 32, y: 16))?.usingColorSpace(.deviceRGB)
        )
        #expect(blurred.smartFilters.first?.appliesToBackdrop == true)
        #expect(blurred.image.qingtuPNGData() == plain.image.qingtuPNGData())
        #expect(abs(blurredColor.redComponent - plainColor.redComponent) > 0.02)
        #expect(abs(halfBlurredColor.redComponent - plainColor.redComponent) > 0.005)
        #expect(abs(halfBlurredColor.redComponent - plainColor.redComponent) < abs(blurredColor.redComponent - plainColor.redComponent))
        #expect(abs(blurredColor.redComponent - blurredColor.blueComponent) < 0.02)
    }

    @Test func imageEditorSharpenAmountIsExplicitAndBackwardCompatible() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = softEdgeImage(size: canvasSize)
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.sharpenAmountPercent == nil)

        let legacy = try #require(sourceImage.filtered(
            kind: .sharpen,
            intensity: 0.5,
            settings: legacySettings
        ))
        let explicitLegacyAmount = try #require(sourceImage.filtered(
            kind: .sharpen,
            intensity: 0,
            settings: ImageEditorFilterSettings(sharpenAmountPercent: 75)
        ))
        let maximumAmount = try #require(sourceImage.filtered(
            kind: .sharpen,
            intensity: 0,
            settings: ImageEditorFilterSettings(sharpenAmountPercent: 400)
        ))
        let zeroAmount = try #require(sourceImage.filtered(
            kind: .sharpen,
            intensity: 1,
            settings: ImageEditorFilterSettings(sharpenAmountPercent: 0)
        ))
        #expect(legacy.qingtuPNGData() == explicitLegacyAmount.qingtuPNGData())
        #expect(maximumAmount.qingtuPNGData() != explicitLegacyAmount.qingtuPNGData())
        #expect(zeroAmount.qingtuPNGData() == sourceImage.qingtuPNGData())
        #expect(ImageEditorFilterSettings(sharpenAmountPercent: -20).normalized().sharpenAmountPercent == 0)
        #expect(ImageEditorFilterSettings(sharpenAmountPercent: 400).normalized().sharpenAmountPercent == 200)

        let filterViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        let baseLayerID = try #require(filterViewModel.document.selectedLayerID)
        let basePixels = try #require(filterViewModel.document.selectedLayer?.image.qingtuPNGData())
        filterViewModel.selectedFilter = .sharpen
        filterViewModel.filterIntensity = 0
        filterViewModel.filterSharpenAmountPercent = 180
        filterViewModel.addFilterLayer()

        let filterLayer = try #require(filterViewModel.document.selectedLayer)
        #expect(filterLayer.filter?.kind == .sharpen)
        #expect(filterLayer.filterSettings.normalized().sharpenAmountPercent == 180)
        #expect(filterViewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixels)
        #expect(filterViewModel.currentImage.qingtuPNGData() != sourceImage.qingtuPNGData())

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(
            sourceImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let smartBasePixels = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .sharpen
        smartViewModel.filterIntensity = 0
        smartViewModel.filterSharpenAmountPercent = 180
        #expect(smartViewModel.addSmartFilterToSelectedLayer() == 1)

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        #expect(smartFilter.kind == .sharpen)
        #expect(smartFilter.normalizedSettings.sharpenAmountPercent == 180)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixels)
        #expect(smartLayer.contentImage.qingtuPNGData() != sourceImage.qingtuPNGData())
        #expect(smartViewModel.currentImage.qingtuPNGData() != sourceImage.qingtuPNGData())
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format(
            "imageEditor.properties.smartFilterItem",
            ImageEditorFilter.sharpen.title,
            180
        ))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restored = try project.restoredDocument()
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.sharpenAmountPercent == 180)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-sharpen-amount"))
        #expect(viewSource.contains("viewModel.selectedFilter != .sharpen"))
    }

    @Test func imageEditorUnsharpMaskFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = softEdgeImage(size: canvasSize)
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.unsharpAmountPercent == nil)
        #expect(legacySettings.unsharpRadiusPixels == nil)
        #expect(legacySettings.unsharpThresholdLevels == nil)
        let legacyAmount = try #require(sourceImage.filtered(
            kind: .unsharpMask,
            intensity: 0.5,
            settings: legacySettings
        ))
        let explicitLegacyAmount = try #require(sourceImage.filtered(
            kind: .unsharpMask,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(unsharpAmountPercent: 150)
        ))
        #expect(legacyAmount.qingtuPNGData() == explicitLegacyAmount.qingtuPNGData())
        let legacyRoundedRadius = try #require(sourceImage.filtered(
            kind: .unsharpMask,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(unsharpRadius: 2.5)
        ))
        let explicitRoundedRadius = try #require(sourceImage.filtered(
            kind: .unsharpMask,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(unsharpRadiusPixels: 3)
        ))
        let preciseFractionalRadius = try #require(sourceImage.filtered(
            kind: .unsharpMask,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(unsharpRadiusPixels: 2.5)
        ))
        #expect(legacyRoundedRadius.qingtuPNGData() == explicitRoundedRadius.qingtuPNGData())
        #expect(preciseFractionalRadius.qingtuPNGData() != legacyRoundedRadius.qingtuPNGData())
        let maximumRadius = try #require(sourceImage.filtered(
            kind: .unsharpMask,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(unsharpRadiusPixels: 250)
        ))
        #expect(maximumRadius.qingtuPNGData() != explicitRoundedRadius.qingtuPNGData())
        let legacyThreshold = try #require(sourceImage.filtered(
            kind: .unsharpMask,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(unsharpThreshold: 0.2)
        ))
        let explicitThreshold = try #require(sourceImage.filtered(
            kind: .unsharpMask,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(unsharpThresholdLevels: 51)
        ))
        #expect(legacyThreshold.qingtuPNGData() == explicitThreshold.qingtuPNGData())

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let beforeDarkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 23, y: 24))?.usingColorSpace(.deviceRGB))
        let beforeLightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .unsharpMask
        viewModel.filterIntensity = 1
        viewModel.filterUnsharpAmountPercent = 325
        viewModel.filterUnsharpRadiusPixels = 37.5
        viewModel.filterUnsharpThresholdLevels = 17
        viewModel.filterUnsharpRadius = 2
        viewModel.filterUnsharpThreshold = 0
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sharpenedDarkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 23, y: 24))?.usingColorSpace(.deviceRGB))
        let sharpenedLightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .unsharpMask)
        #expect(filterLayer.filterSettings.normalized().unsharpAmountPercent == 325)
        #expect(filterLayer.filterSettings.normalized().unsharpRadiusPixels == 37.5)
        #expect(filterLayer.filterSettings.normalized().unsharpThresholdLevels == 17)
        #expect(filterLayer.filterSettings.normalized().unsharpRadius == 2)
        #expect(filterLayer.filterSettings.normalized().unsharpThreshold == 0)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sharpenedDarkSide.redComponent < beforeDarkSide.redComponent - 0.08)
        #expect(sharpenedLightSide.redComponent > beforeLightSide.redComponent + 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .unsharpMask
        smartViewModel.filterIntensity = 1
        smartViewModel.filterUnsharpAmountPercent = 325
        smartViewModel.filterUnsharpRadiusPixels = 37.5
        smartViewModel.filterUnsharpThresholdLevels = 17
        smartViewModel.filterUnsharpRadius = 2
        smartViewModel.filterUnsharpThreshold = 0
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartSharpenedLightSide = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .unsharpMask)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.unsharpAmountPercent == 325)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.unsharpRadiusPixels == 37.5)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.unsharpThresholdLevels == 17)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.unsharpRadius == 2)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.unsharpThreshold == 0)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSharpenedLightSide.redComponent > beforeLightSide.redComponent + 0.08)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))
        let smartFilter = try #require(smartLayer.smartFilters.first)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format(
            "imageEditor.properties.smartFilterUnsharpItem",
            ImageEditorFilter.unsharpMask.title,
            325,
            "37.5",
            17
        ))
        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restored = try project.restoredDocument()
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.unsharpAmountPercent == 325)
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.unsharpRadiusPixels == 37.5)
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.unsharpThresholdLevels == 17)

        let thresholdFiltered = try #require(
            sourceImage.filtered(
                kind: .unsharpMask,
                intensity: 1,
                settings: ImageEditorFilterSettings(unsharpRadius: 2, unsharpThreshold: 1)
            )
        )
        let thresholdLightSide = try #require(thresholdFiltered.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(abs(thresholdLightSide.redComponent - beforeLightSide.redComponent) < 0.01)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-unsharp-amount"))
        #expect(viewSource.contains("image-editor-filter-unsharp-radius"))
        #expect(viewSource.contains("image-editor-filter-unsharp-threshold"))
        #expect(viewSource.contains("viewModel.selectedFilter != .unsharpMask"))
    }

    @Test func imageEditorMedianFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = saltAndPepperImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let noisyWhiteBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        let noisyBlackBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 25, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .median
        viewModel.filterIntensity = 1
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let whiteAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        let blackAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 25, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .median)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(noisyWhiteBefore.redComponent > 0.95)
        #expect(noisyBlackBefore.redComponent < 0.05)
        #expect(abs(whiteAfter.redComponent - 0.5) < 0.04)
        #expect(abs(blackAfter.redComponent - 0.5) < 0.04)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())
        smartViewModel.selectedFilter = .median
        smartViewModel.filterIntensity = 1
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartWhiteAfter = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .median)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(abs(smartWhiteAfter.redComponent - 0.5) < 0.04)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func imageEditorAddNoiseFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = solidImage(size: canvasSize, color: NSColor(calibratedWhite: 0.5, alpha: 1))
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let beforeA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let beforeB = try #require(viewModel.currentImage.color(at: CGPoint(x: 13, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .addNoise
        viewModel.filterIntensity = 0.8
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let noisyA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let noisyB = try #require(viewModel.currentImage.color(at: CGPoint(x: 13, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .addNoise)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(beforeA.redComponent - beforeB.redComponent) < 0.002)
        #expect(abs(noisyA.redComponent - noisyB.redComponent) > 0.02)
        #expect(abs(noisyA.redComponent - noisyA.greenComponent) < 0.002)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())
        smartViewModel.selectedFilter = .addNoise
        smartViewModel.filterIntensity = 0.8
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartNoisyA = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let smartNoisyB = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 13, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .addNoise)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(abs(smartNoisyA.redComponent - smartNoisyB.redComponent) > 0.02)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func addNoiseAmountAndModesPreserveLegacyPixelsAndSupportGaussianColorNoise() throws {
        let sourceImage = solidImage(
            size: NSSize(width: 72, height: 48),
            color: NSColor(calibratedWhite: 0.5, alpha: 1)
        )
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.addNoiseAmountPercent == nil)
        #expect(legacySettings.addNoiseMonochromatic == nil)
        #expect(legacySettings.addNoiseDistribution == nil)

        let legacy = try #require(sourceImage.filtered(
            kind: .addNoise,
            intensity: 0.7,
            settings: legacySettings
        ))
        let explicitMonochromatic = try #require(sourceImage.filtered(
            kind: .addNoise,
            intensity: 0,
            settings: ImageEditorFilterSettings(
                addNoiseAmountPercent: 70,
                addNoiseMonochromatic: true,
                addNoiseDistribution: .uniform
            )
        ))
        #expect(legacy.qingtuPNGData() == explicitMonochromatic.qingtuPNGData())
        let maximumAmount = try #require(sourceImage.filtered(
            kind: .addNoise,
            intensity: 0,
            settings: ImageEditorFilterSettings(addNoiseAmountPercent: 400)
        ))
        #expect(maximumAmount.qingtuPNGData() != explicitMonochromatic.qingtuPNGData())
        #expect(ImageEditorFilterSettings(addNoiseAmountPercent: -20).normalized().addNoiseAmountPercent == 0.1)
        #expect(ImageEditorFilterSettings(addNoiseAmountPercent: 800).normalized().addNoiseAmountPercent == 400)

        let colorNoise = try #require(sourceImage.filtered(
            kind: .addNoise,
            intensity: 0.7,
            settings: ImageEditorFilterSettings(addNoiseMonochromatic: false)
        ))
        let gaussianNoise = try #require(sourceImage.filtered(
            kind: .addNoise,
            intensity: 0.7,
            settings: ImageEditorFilterSettings(
                addNoiseMonochromatic: false,
                addNoiseDistribution: .gaussian
            )
        ))
        let monochromaticPixel = try #require(
            explicitMonochromatic.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB)
        )
        let colorPixel = try #require(
            colorNoise.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB)
        )
        #expect(abs(monochromaticPixel.redComponent - monochromaticPixel.greenComponent) < 0.002)
        #expect(
            max(colorPixel.redComponent, colorPixel.greenComponent, colorPixel.blueComponent)
                - min(colorPixel.redComponent, colorPixel.greenComponent, colorPixel.blueComponent) > 0.02
        )
        #expect(gaussianNoise.qingtuPNGData() != colorNoise.qingtuPNGData())
        let uniformBytes = try #require(imageEditorRGBABytes(colorNoise, width: 72, height: 48))
        let gaussianBytes = try #require(imageEditorRGBABytes(gaussianNoise, width: 72, height: 48))
        let redOffsets = stride(from: 0, to: uniformBytes.count, by: 4)
        let uniformMeanDeviation = redOffsets.reduce(0.0) {
            $0 + abs(Double(uniformBytes[$1]) - 128)
        } / Double(uniformBytes.count / 4)
        let gaussianMeanDeviation = redOffsets.reduce(0.0) {
            $0 + abs(Double(gaussianBytes[$1]) - 128)
        } / Double(gaussianBytes.count / 4)
        #expect(gaussianMeanDeviation < uniformMeanDeviation * 0.75)

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            sourceImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.selectedFilter = .addNoise
        viewModel.filterIntensity = 0
        viewModel.filterAddNoiseAmountPercent = 137.5
        viewModel.filterAddNoiseMonochromatic = false
        viewModel.filterAddNoiseDistribution = .gaussian
        viewModel.addSmartFilterToSelectedLayer()

        let smartFilter = try #require(viewModel.document.selectedLayer?.smartFilters.last)
        #expect(smartFilter.normalizedSettings.addNoiseAmountPercent == 137.5)
        #expect(smartFilter.normalizedSettings.addNoiseMonochromatic == false)
        #expect(smartFilter.normalizedSettings.addNoiseDistribution == .gaussian)
        #expect(imageEditorMaximumPixelDifference(viewModel.currentImage, sourceImage) > 0)
        #expect(viewModel.smartFilterLabel(smartFilter) == L10n.format(
            "imageEditor.properties.smartFilterAddNoiseItem",
            ImageEditorFilter.addNoise.title,
            "137.5",
            ImageEditorAddNoiseDistribution.gaussian.title,
            L10n.text("imageEditor.filter.addNoiseColor")
        ))
        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        #expect(restored.selectedLayer?.smartFilters.last?.normalizedSettings.addNoiseAmountPercent == 137.5)
        #expect(restored.selectedLayer?.smartFilters.last?.normalizedSettings.addNoiseMonochromatic == false)
        #expect(restored.selectedLayer?.smartFilters.last?.normalizedSettings.addNoiseDistribution == .gaussian)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-add-noise-amount"))
        #expect(viewSource.contains("image-editor-filter-add-noise-monochromatic"))
        #expect(viewSource.contains("image-editor-filter-add-noise-distribution"))
        #expect(viewSource.contains("viewModel.selectedFilter != .addNoise"))
    }

    @Test func imageEditorGaussianBlurRadiusPreservesLegacyPixelsAndRoundTripsExactPixels() throws {
        let sourceImage = gradientImage(size: NSSize(width: 72, height: 48))
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.gaussianBlurRadius == nil)

        let legacy = try #require(sourceImage.filtered(
            kind: .gaussianBlur,
            intensity: 0.5,
            settings: legacySettings
        ))
        let explicitLegacyRadius = try #require(sourceImage.filtered(
            kind: .gaussianBlur,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 9)
        ))
        #expect(legacy.qingtuPNGData() == explicitLegacyRadius.qingtuPNGData())
        #expect(ImageEditorFilterSettings(gaussianBlurRadius: -10).normalized().gaussianBlurRadius == 0)
        #expect(ImageEditorFilterSettings(gaussianBlurRadius: 2_000).normalized().gaussianBlurRadius == 1_000)
        let maximumRadius = try #require(sourceImage.filtered(
            kind: .gaussianBlur,
            intensity: 0,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 1_000)
        ))
        #expect(imageEditorMaximumPixelDifference(maximumRadius, sourceImage) > 0)
        let zeroRadius = try #require(sourceImage.filtered(
            kind: .gaussianBlur,
            intensity: 1,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 0)
        ))
        #expect(zeroRadius.qingtuPNGData() == sourceImage.qingtuPNGData())

        let viewModel = ImageEditorViewModel(sourceName: "blur-radius.png", image: sourceImage) { _ in }
        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.5
        #expect(viewModel.filterGaussianBlurRadius == nil)
        #expect(viewModel.filterGaussianBlurEffectiveRadius == 9)
        viewModel.filterGaussianBlurEffectiveRadius = 512.5
        viewModel.addSmartFilterToSelectedLayer()

        let smartFilter = try #require(viewModel.document.selectedLayer?.smartFilters.last)
        #expect(smartFilter.normalizedSettings.gaussianBlurRadius == 512.5)
        #expect(viewModel.smartFilterLabel(smartFilter) == L10n.format(
            "imageEditor.properties.smartFilterGaussianBlurItem",
            ImageEditorFilter.gaussianBlur.title,
            "512.5"
        ))
        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        #expect(restored.selectedLayer?.smartFilters.last?.normalizedSettings.gaussianBlurRadius == 512.5)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-gaussian-blur-radius"))
        #expect(viewSource.contains("viewModel.selectedFilter != .gaussianBlur"))
        #expect(viewSource.contains("in: 0.1...1_000"))
    }

    @Test func gaussianBlurQuickPanelUsesPhotoshopRadiusInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let gaussianStart = try #require(
            panelSource.range(of: "if viewModel.selectedFilter == .gaussianBlur")
        )
        let gaussianEnd = try #require(
            panelSource[gaussianStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .sharpen"
            )
        )
        let gaussianSource = panelSource[gaussianStart.lowerBound..<gaussianEnd.lowerBound]

        #expect(gaussianSource.contains("viewModel.filterGaussianBlurEffectiveRadius"))
        #expect(gaussianSource.contains("in: 0.1...1_000"))
        #expect(gaussianSource.contains("step: 0.1"))
        #expect(gaussianSource.contains("imageEditor.filter.gaussianBlurRadius"))
        #expect(gaussianSource.contains("image-editor-filter-quick-gaussian-blur-radius"))
        #expect(!gaussianSource.contains("viewModel.filterIntensity"))
    }

    @Test func sharpenQuickPanelUsesExplicitAmountInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let sharpenStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .sharpen")
        )
        let sharpenEnd = try #require(
            panelSource[sharpenStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .pixelate"
            )
        )
        let sharpenSource = panelSource[sharpenStart.lowerBound..<sharpenEnd.lowerBound]

        #expect(sharpenSource.contains("viewModel.filterSharpenEffectiveAmountPercent"))
        #expect(sharpenSource.contains("in: 0...200"))
        #expect(sharpenSource.contains("step: 1"))
        #expect(sharpenSource.contains("imageEditor.filter.unsharpAmount"))
        #expect(sharpenSource.contains("image-editor-filter-quick-sharpen-amount"))
        #expect(!sharpenSource.contains("viewModel.filterIntensity"))
    }

    @Test func pixelateQuickPanelUsesCellSizeInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let pixelateStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .pixelate")
        )
        let pixelateEnd = try #require(
            panelSource[pixelateStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .addNoise"
            )
        )
        let pixelateSource = panelSource[pixelateStart.lowerBound..<pixelateEnd.lowerBound]

        #expect(pixelateSource.contains("viewModel.filterPixelateCellSize"))
        #expect(pixelateSource.contains("in: 2...200"))
        #expect(pixelateSource.contains("step: 1"))
        #expect(pixelateSource.contains("imageEditor.filter.pixelateCellSize"))
        #expect(pixelateSource.contains("image-editor-filter-quick-pixelate-cell-size"))
        #expect(!pixelateSource.contains("viewModel.filterIntensity"))
    }

    @Test func addNoiseQuickPanelUsesExplicitAmountInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let addNoiseStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .addNoise")
        )
        let addNoiseEnd = try #require(
            panelSource[addNoiseStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .vignette"
            )
        )
        let addNoiseSource = panelSource[addNoiseStart.lowerBound..<addNoiseEnd.lowerBound]

        #expect(addNoiseSource.contains("viewModel.filterAddNoiseEffectiveAmountPercent"))
        #expect(addNoiseSource.contains("in: 0.1...400"))
        #expect(addNoiseSource.contains("step: 0.1"))
        #expect(addNoiseSource.contains("imageEditor.filter.addNoiseAmount"))
        #expect(addNoiseSource.contains("image-editor-filter-quick-add-noise-amount"))
        #expect(!addNoiseSource.contains("viewModel.filterIntensity"))
    }

    @Test func vignetteQuickPanelUsesSignedAmountInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let vignetteStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .vignette")
        )
        let vignetteEnd = try #require(
            panelSource[vignetteStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .oilPaint"
            )
        )
        let vignetteSource = panelSource[vignetteStart.lowerBound..<vignetteEnd.lowerBound]

        #expect(vignetteSource.contains("viewModel.filterVignetteEffectiveAmountPercent"))
        #expect(vignetteSource.contains("in: -100...100"))
        #expect(vignetteSource.contains("step: 1"))
        #expect(vignetteSource.contains("imageEditor.filter.vignetteAmount"))
        #expect(vignetteSource.contains("image-editor-filter-quick-vignette-amount"))
        #expect(!vignetteSource.contains("viewModel.filterIntensity"))
    }

    @Test func oilPaintQuickPanelUsesBrushRadiusInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let oilPaintStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .oilPaint")
        )
        let oilPaintEnd = try #require(
            panelSource[oilPaintStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .highPass"
            )
        )
        let oilPaintSource = panelSource[oilPaintStart.lowerBound..<oilPaintEnd.lowerBound]

        #expect(oilPaintSource.contains("viewModel.filterOilPaintRadius"))
        #expect(oilPaintSource.contains("in: 1...10"))
        #expect(oilPaintSource.contains("step: 1"))
        #expect(oilPaintSource.contains("imageEditor.filter.oilPaintRadius"))
        #expect(oilPaintSource.contains("image-editor-filter-quick-oil-paint-radius"))
        #expect(!oilPaintSource.contains("viewModel.filterIntensity"))
    }

    @Test func highPassQuickPanelUsesRadiusInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let highPassStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .highPass")
        )
        let highPassEnd = try #require(
            panelSource[highPassStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .motionBlur"
            )
        )
        let highPassSource = panelSource[highPassStart.lowerBound..<highPassEnd.lowerBound]

        #expect(highPassSource.contains("viewModel.filterHighPassRadius"))
        #expect(highPassSource.contains("in: 1...1_000"))
        #expect(highPassSource.contains("step: 1"))
        #expect(highPassSource.contains("imageEditor.filter.highPassRadius"))
        #expect(highPassSource.contains("image-editor-filter-quick-high-pass-radius"))
        #expect(!highPassSource.contains("viewModel.filterIntensity"))
    }

    @Test func motionBlurQuickPanelUsesDistanceInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let motionBlurStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .motionBlur")
        )
        let motionBlurEnd = try #require(
            panelSource[motionBlurStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .unsharpMask"
            )
        )
        let motionBlurSource = panelSource[motionBlurStart.lowerBound..<motionBlurEnd.lowerBound]

        #expect(motionBlurSource.contains("viewModel.filterMotionBlurDistance"))
        #expect(motionBlurSource.contains("in: 1...999"))
        #expect(motionBlurSource.contains("step: 1"))
        #expect(motionBlurSource.contains("imageEditor.filter.motionBlurDistance"))
        #expect(motionBlurSource.contains("image-editor-filter-quick-motion-blur-distance"))
        #expect(!motionBlurSource.contains("viewModel.filterIntensity"))
    }

    @Test func unsharpQuickPanelUsesAmountInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let unsharpStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .unsharpMask")
        )
        let unsharpEnd = try #require(
            panelSource[unsharpStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .emboss"
            )
        )
        let unsharpSource = panelSource[unsharpStart.lowerBound..<unsharpEnd.lowerBound]

        #expect(unsharpSource.contains("viewModel.filterUnsharpEffectiveAmountPercent"))
        #expect(unsharpSource.contains("in: 1...500"))
        #expect(unsharpSource.contains("step: 1"))
        #expect(unsharpSource.contains("imageEditor.filter.unsharpAmount"))
        #expect(unsharpSource.contains("image-editor-filter-quick-unsharp-amount"))
        #expect(!unsharpSource.contains("viewModel.filterIntensity"))
    }

    @Test func embossQuickPanelUsesHeightInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let embossStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .emboss")
        )
        let embossEnd = try #require(
            panelSource[embossStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .minimum"
            )
        )
        let embossSource = panelSource[embossStart.lowerBound..<embossEnd.lowerBound]

        #expect(embossSource.contains("viewModel.filterEmbossHeight"))
        #expect(embossSource.contains("in: 1...10"))
        #expect(embossSource.contains("step: 1"))
        #expect(embossSource.contains("imageEditor.filter.embossHeight"))
        #expect(embossSource.contains("image-editor-filter-quick-emboss-height"))
        #expect(!embossSource.contains("viewModel.filterIntensity"))
    }

    @Test func liquifyTwirlQuickPanelUsesAngleInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let twirlStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .liquifyTwirl")
        )
        let twirlEnd = try #require(
            panelSource[twirlStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .liquifyPuckerBloat"
            )
        )
        let twirlSource = panelSource[twirlStart.lowerBound..<twirlEnd.lowerBound]

        #expect(twirlSource.contains("viewModel.filterLiquifyTwirlEffectiveAngleDegrees"))
        #expect(twirlSource.contains("in: -999...999"))
        #expect(twirlSource.contains("step: 1"))
        #expect(twirlSource.contains("imageEditor.filter.liquifyTwirlAngle"))
        #expect(twirlSource.contains("image-editor-filter-quick-liquify-twirl-angle"))
        #expect(!twirlSource.contains("viewModel.filterIntensity"))
    }

    @Test func liquifyPuckerBloatQuickPanelUsesAmountInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let puckerBloatStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .liquifyPuckerBloat")
        )
        let puckerBloatEnd = try #require(
            panelSource[puckerBloatStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .pinch"
            )
        )
        let puckerBloatSource = panelSource[puckerBloatStart.lowerBound..<puckerBloatEnd.lowerBound]

        #expect(puckerBloatSource.contains("viewModel.filterLiquifyBulgeEffectiveAmountPercent"))
        #expect(puckerBloatSource.contains("in: -100...100"))
        #expect(puckerBloatSource.contains("step: 1"))
        #expect(puckerBloatSource.contains("imageEditor.filter.liquifyBulgeAmount"))
        #expect(puckerBloatSource.contains("image-editor-filter-quick-liquify-bulge-amount"))
        #expect(!puckerBloatSource.contains("viewModel.filterIntensity"))
    }

    @Test func pinchQuickPanelUsesAmountInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let pinchStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .pinch")
        )
        let pinchEnd = try #require(
            panelSource[pinchStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .spherize"
            )
        )
        let pinchSource = panelSource[pinchStart.lowerBound..<pinchEnd.lowerBound]

        #expect(pinchSource.contains("viewModel.filterPinchEffectiveAmountPercent"))
        #expect(pinchSource.contains("in: -100...100"))
        #expect(pinchSource.contains("step: 1"))
        #expect(pinchSource.contains("imageEditor.filter.pinchAmount"))
        #expect(pinchSource.contains("image-editor-filter-quick-pinch-amount"))
        #expect(!pinchSource.contains("viewModel.filterIntensity"))
    }

    @Test func spherizeQuickPanelUsesAmountInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let spherizeStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .spherize")
        )
        let spherizeEnd = try #require(
            panelSource[spherizeStart.upperBound...].range(
                of: "else if viewModel.selectedFilter == .lensCorrection"
            )
        )
        let spherizeSource = panelSource[spherizeStart.lowerBound..<spherizeEnd.lowerBound]

        #expect(spherizeSource.contains("viewModel.filterSpherizeEffectiveAmountPercent"))
        #expect(spherizeSource.contains("in: -100...100"))
        #expect(spherizeSource.contains("step: 1"))
        #expect(spherizeSource.contains("imageEditor.filter.spherizeAmount"))
        #expect(spherizeSource.contains("image-editor-filter-quick-spherize-amount"))
        #expect(!spherizeSource.contains("viewModel.filterIntensity"))
    }

    @Test func lensCorrectionQuickPanelUsesDistortionInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let lensCorrectionStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .lensCorrection")
        )
        let lensCorrectionEnd = try #require(
            panelSource[lensCorrectionStart.upperBound...].range(of: "else if viewModel.selectedFilter == .ripple")
        )
        let lensCorrectionSource = panelSource[lensCorrectionStart.lowerBound..<lensCorrectionEnd.lowerBound]

        #expect(lensCorrectionSource.contains("viewModel.filterLensDistortionEffectiveAmountPercent"))
        #expect(lensCorrectionSource.contains("in: -100...100"))
        #expect(lensCorrectionSource.contains("step: 1"))
        #expect(lensCorrectionSource.contains("imageEditor.filter.lensDistortion"))
        #expect(lensCorrectionSource.contains("image-editor-filter-quick-lens-distortion-amount"))
        #expect(!lensCorrectionSource.contains("viewModel.filterIntensity"))
    }

    @Test func rippleQuickPanelUsesAmountInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let rippleStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .ripple")
        )
        let rippleEnd = try #require(
            panelSource[rippleStart.upperBound...].range(of: "else if viewModel.selectedFilter == .wave")
        )
        let rippleSource = panelSource[rippleStart.lowerBound..<rippleEnd.lowerBound]

        #expect(rippleSource.contains("viewModel.filterRippleEffectiveAmountPercent"))
        #expect(rippleSource.contains("in: -100...100"))
        #expect(rippleSource.contains("step: 1"))
        #expect(rippleSource.contains("imageEditor.filter.rippleAmount"))
        #expect(rippleSource.contains("image-editor-filter-quick-ripple-amount"))
        #expect(!rippleSource.contains("viewModel.filterIntensity"))
    }

    @Test func waveQuickPanelUsesAmplitudeInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let waveStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .wave")
        )
        let waveEnd = try #require(
            panelSource[waveStart.upperBound...].range(of: "else if viewModel.selectedFilter == .offset")
        )
        let waveSource = panelSource[waveStart.lowerBound..<waveEnd.lowerBound]

        #expect(waveSource.contains("viewModel.filterWaveEffectiveAmplitudePercent"))
        #expect(waveSource.contains("in: -100...100"))
        #expect(waveSource.contains("step: 1"))
        #expect(waveSource.contains("imageEditor.filter.waveAmplitude"))
        #expect(waveSource.contains("image-editor-filter-quick-wave-amplitude"))
        #expect(!waveSource.contains("viewModel.filterIntensity"))
    }

    @Test func offsetQuickPanelUsesTwoPixelAxesInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let offsetStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .offset")
        )
        let offsetEnd = try #require(
            panelSource[offsetStart.upperBound...].range(of: "else if viewModel.selectedFilter == .liquifyPush")
        )
        let offsetSource = panelSource[offsetStart.lowerBound..<offsetEnd.lowerBound]

        #expect(offsetSource.contains("viewModel.filterOffsetEffectiveXPixels"))
        #expect(offsetSource.contains("viewModel.filterOffsetEffectiveYPixels"))
        #expect(offsetSource.components(separatedBy: "in: -9_999...9_999").count == 3)
        #expect(offsetSource.components(separatedBy: "step: 1").count == 3)
        #expect(offsetSource.contains("imageEditor.filter.offsetX"))
        #expect(offsetSource.contains("imageEditor.filter.offsetY"))
        #expect(offsetSource.contains("image-editor-filter-quick-offset-x-pixels"))
        #expect(offsetSource.contains("image-editor-filter-quick-offset-y-pixels"))
        #expect(!offsetSource.contains("viewModel.filterIntensity"))
    }

    @Test func liquifyPushQuickPanelUsesTwoPixelAxesInsteadOfLegacyIntensity() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let liquifyPushStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .liquifyPush")
        )
        let liquifyPushEnd = try #require(
            panelSource[liquifyPushStart.upperBound...].range(of: "else if viewModel.selectedFilter == .findEdges")
        )
        let liquifyPushSource = panelSource[liquifyPushStart.lowerBound..<liquifyPushEnd.lowerBound]

        #expect(liquifyPushSource.contains("viewModel.filterLiquifyPushEffectiveXPixels"))
        #expect(liquifyPushSource.contains("viewModel.filterLiquifyPushEffectiveYPixels"))
        #expect(liquifyPushSource.components(separatedBy: "in: -9_999...9_999").count == 3)
        #expect(liquifyPushSource.components(separatedBy: "step: 1").count == 3)
        #expect(liquifyPushSource.contains("imageEditor.filter.liquifyPushX"))
        #expect(liquifyPushSource.contains("imageEditor.filter.liquifyPushY"))
        #expect(liquifyPushSource.contains("image-editor-filter-quick-liquify-push-x-pixels"))
        #expect(liquifyPushSource.contains("image-editor-filter-quick-liquify-push-y-pixels"))
        #expect(!liquifyPushSource.contains("viewModel.filterIntensity"))
    }

    @Test func findEdgesQuickPanelDeclaresNoAdjustableParameters() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let findEdgesStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .findEdges")
        )
        let findEdgesSource = panelSource[findEdgesStart.lowerBound...]

        #expect(findEdgesSource.contains("imageEditor.filter.noAdjustableParameters"))
        #expect(findEdgesSource.contains("image-editor-filter-quick-no-adjustable-parameters"))
        #expect(!findEdgesSource.contains("Slider("))
        #expect(!findEdgesSource.contains("viewModel.filterIntensity"))
    }

    @Test func medianQuickPanelOwnsItsStrengthControlWithoutGenericFallback() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let panelStart = try #require(viewSource.range(of: "private var filtersQuickPanel: some View"))
        let panelEnd = try #require(
            viewSource[panelStart.upperBound...].range(of: "private func historySnapshotRow")
        )
        let panelSource = viewSource[panelStart.lowerBound..<panelEnd.lowerBound]
        let medianStart = try #require(
            panelSource.range(of: "else if viewModel.selectedFilter == .median")
        )
        let medianEnd = try #require(
            panelSource[medianStart.upperBound...].range(of: "else if viewModel.selectedFilter == .findEdges")
        )
        let medianSource = panelSource[medianStart.lowerBound..<medianEnd.lowerBound]

        #expect(medianSource.contains("viewModel.filterIntensity"))
        #expect(medianSource.contains("in: 0...1, step: 0.05"))
        #expect(medianSource.contains("imageEditor.option.strength"))
        #expect(medianSource.contains("image-editor-filter-quick-median-strength"))
        #expect(!panelSource.contains("image-editor-filter-intensity"))
    }

    @Test func imageEditorMotionBlurFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = verticalEdgeImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let beforeDarkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))
        let beforeLightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 37, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .motionBlur
        viewModel.filterIntensity = 0.9
        viewModel.filterMotionBlurAngleDegrees = 0
        viewModel.filterMotionBlurDistance = 25
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let blurredDarkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))
        let blurredLightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 37, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .motionBlur)
        #expect(filterLayer.filterSettings.normalized().motionBlurAngleDegrees == 0)
        #expect(filterLayer.filterSettings.normalized().motionBlurDistance == 25)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(blurredDarkSide.redComponent > beforeDarkSide.redComponent + 0.08)
        #expect(blurredLightSide.redComponent < beforeLightSide.redComponent - 0.08)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .motionBlur
        smartViewModel.filterIntensity = 0.9
        smartViewModel.filterMotionBlurAngleDegrees = 0
        smartViewModel.filterMotionBlurDistance = 25
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartBlurredDarkSide = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .motionBlur)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.motionBlurAngleDegrees == 0)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.motionBlurDistance == 25)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartBlurredDarkSide.redComponent > beforeDarkSide.redComponent + 0.08)
        #expect(smartViewModel.smartFilterLabel(try #require(smartLayer.smartFilters.first)) == L10n.format(
            "imageEditor.properties.smartFilterMotionBlurItem",
            ImageEditorFilter.motionBlur.title,
            0,
            25
        ))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restored = try project.restoredDocument()
        let restoredFilter = try #require(restored.selectedLayer?.smartFilters.first)
        #expect(restoredFilter.normalizedSettings.motionBlurAngleDegrees == 0)
        #expect(restoredFilter.normalizedSettings.motionBlurDistance == 25)
    }

    @Test func motionBlurAngleAndDistanceControlDirectionAndPreserveLegacyProjects() throws {
        let sourceImage = verticalEdgeImage(size: NSSize(width: 72, height: 48))

        func red(x: CGFloat, angle: Double, distance: Double) throws -> CGFloat {
            let output = try #require(sourceImage.filtered(
                kind: .motionBlur,
                intensity: 0.9,
                settings: ImageEditorFilterSettings(
                    motionBlurAngleDegrees: angle,
                    motionBlurDistance: distance
                )
            ))
            return try #require(
                output.color(at: CGPoint(x: x, y: 24))?.usingColorSpace(.deviceRGB)
            ).redComponent
        }

        let horizontal = try red(x: 35, angle: 0, distance: 20)
        let vertical = try red(x: 35, angle: 90, distance: 20)
        let short = try red(x: 30, angle: 0, distance: 2)
        let long = try red(x: 30, angle: 0, distance: 20)
        #expect(horizontal > vertical + 0.15)
        #expect(long > short + 0.08)

        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.motionBlurAngleDegrees == nil)
        #expect(legacySettings.motionBlurDistance == nil)
        let legacy = try #require(sourceImage.filtered(
            kind: .motionBlur,
            intensity: 0.9,
            settings: legacySettings
        ))
        let equivalentExplicit = try #require(sourceImage.filtered(
            kind: .motionBlur,
            intensity: 0.9,
            settings: ImageEditorFilterSettings(
                motionBlurAngleDegrees: 0,
                motionBlurDistance: 0.9 * 28
            )
        ))
        #expect(legacy.qingtuPNGData() == equivalentExplicit.qingtuPNGData())

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-motion-blur-angle"))
        #expect(viewSource.contains("image-editor-filter-motion-blur-distance"))
        #expect(viewModelSource.contains("motionBlurAngleDegrees: selectedFilter == .motionBlur"))
        #expect(viewModelSource.contains("motionBlurDistance: selectedFilter == .motionBlur"))
    }

    @Test func imageEditorPixelateFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = gradientImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let beforeNearA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let beforeNearB = try #require(viewModel.currentImage.color(at: CGPoint(x: 14, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 0.9
        viewModel.filterPixelateCellSize = 32
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let filterLayerNearA = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let filterLayerNearB = try #require(viewModel.currentImage.color(at: CGPoint(x: 14, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .pixelate)
        #expect(filterLayer.filterSettings.normalized().pixelateCellSize == 32)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(beforeNearA.redComponent - beforeNearB.redComponent) > 0.01)
        #expect(abs(filterLayerNearA.redComponent - filterLayerNearB.redComponent) < 0.004)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())

        smartViewModel.selectedFilter = .pixelate
        smartViewModel.filterIntensity = 0.9
        smartViewModel.filterPixelateCellSize = 32
        #expect(smartViewModel.canAddSmartFilterToSelectedLayer)
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartNearA = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let smartNearB = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 14, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(smartLayer.smartFilters.first?.kind == .pixelate)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.pixelateCellSize == 32)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(abs(smartNearA.redComponent - smartNearB.redComponent) < 0.004)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) != smartPreviewBefore)
        #expect(smartViewModel.smartFilterLabel(try #require(smartLayer.smartFilters.first)) == L10n.format(
            "imageEditor.properties.smartFilterPixelateItem",
            ImageEditorFilter.pixelate.title,
            32
        ))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restored = try project.restoredDocument()
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.pixelateCellSize == 32)

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterToggle"))
    }

    @Test func pixelateCellSizeControlsMosaicScaleAndPreservesLegacyProjects() throws {
        let sourceImage = gradientImage(size: NSSize(width: 72, height: 48))

        func distinctRedValues(cellSize: Double) throws -> Set<Int> {
            let output = try #require(sourceImage.filtered(
                kind: .pixelate,
                intensity: 0.9,
                settings: ImageEditorFilterSettings(pixelateCellSize: cellSize)
            ))
            return try Set(stride(from: CGFloat(4), through: 68, by: 2).map { x in
                let color = try #require(
                    output.color(at: CGPoint(x: x, y: 24))?.usingColorSpace(.deviceRGB)
                )
                return Int((color.redComponent * 255).rounded())
            })
        }

        let fineValues = try distinctRedValues(cellSize: 2)
        let coarseValues = try distinctRedValues(cellSize: 40)
        #expect(fineValues.count > coarseValues.count + 8)

        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.pixelateCellSize == nil)
        let legacy = try #require(sourceImage.filtered(
            kind: .pixelate,
            intensity: 0.9,
            settings: legacySettings
        ))
        let equivalentExplicit = try #require(sourceImage.filtered(
            kind: .pixelate,
            intensity: 0.9,
            settings: ImageEditorFilterSettings(pixelateCellSize: 2 + 0.9 * 32)
        ))
        #expect(legacy.qingtuPNGData() == equivalentExplicit.qingtuPNGData())

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-pixelate-cell-size"))
        #expect(viewModelSource.contains("pixelateCellSize: selectedFilter == .pixelate"))
    }

    @Test func imageEditorHighPassFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = verticalEdgeImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectedFilter = .highPass
        viewModel.filterIntensity = 0.65
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let flatLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let edgeDarkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 34, y: 24))?.usingColorSpace(.deviceRGB))
        let edgeLightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 37, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .highPass)
        #expect(filterLayer.filterSettings.normalized().highPassGainPercent == 100)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(flatLeft.redComponent - 0.5) < 0.04)
        #expect(edgeDarkSide.redComponent < 0.20)
        #expect(edgeLightSide.redComponent > 0.80)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())

        smartViewModel.selectedFilter = .highPass
        smartViewModel.filterIntensity = 0.65
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartEdgeLightSide = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 37, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .highPass)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.highPassGainPercent == 100)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartEdgeLightSide.redComponent > 0.80)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func highPassRadiusAndCanonicalGainPreserveLegacyRenderingAndPersistNonDestructively() throws {
        let sourceImage = verticalEdgeImage(size: NSSize(width: 72, height: 48))
        let legacyIntensity = 0.65
        let legacySettings = ImageEditorFilterSettings(highPassRadius: 14)
        let legacy = try #require(sourceImage.filtered(
            kind: .highPass,
            intensity: legacyIntensity,
            settings: legacySettings
        ))
        let explicitLegacyGain = try #require(sourceImage.filtered(
            kind: .highPass,
            intensity: 0,
            settings: ImageEditorFilterSettings(
                highPassRadius: 14,
                highPassGainPercent: (1.4 + legacyIntensity * 2.4) * 100
            )
        ))
        #expect(legacy.qingtuPNGData() == explicitLegacyGain.qingtuPNGData())

        let narrow = try #require(sourceImage.filtered(
            kind: .highPass,
            intensity: 0,
            settings: ImageEditorFilterSettings(highPassRadius: 2, highPassGainPercent: 100)
        ))
        let wide = try #require(sourceImage.filtered(
            kind: .highPass,
            intensity: 0,
            settings: ImageEditorFilterSettings(highPassRadius: 14, highPassGainPercent: 100)
        ))
        let samplePoint = CGPoint(x: 26, y: 24)
        let narrowSample = try #require(narrow.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        let wideSample = try #require(wide.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(abs(narrowSample.redComponent - 0.5) < 0.04)
        #expect(abs(wideSample.redComponent - 0.5) > 0.12)

        #expect(ImageEditorFilterSettings(highPassRadius: -20).normalized().highPassRadius == 1)
        #expect(ImageEditorFilterSettings(highPassRadius: 2_000).normalized().highPassRadius == 1_000)
        #expect(ImageEditorFilterSettings(highPassGainPercent: -20).normalized().highPassGainPercent == 0)
        #expect(ImageEditorFilterSettings(highPassGainPercent: 900).normalized().highPassGainPercent == 400)

        let viewModel = ImageEditorViewModel(sourceName: "high-pass-radius.png", image: sourceImage) { _ in }
        viewModel.selectedFilter = .highPass
        viewModel.filterHighPassRadius = 14
        viewModel.addSmartFilterToSelectedLayer()

        let smartFilter = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        #expect(smartFilter.normalizedSettings.highPassRadius == 14)
        #expect(smartFilter.normalizedSettings.highPassGainPercent == 100)
        #expect(
            viewModel.smartFilterLabel(smartFilter)
                == L10n.format(
                    "imageEditor.properties.smartFilterHighPassRadiusItem",
                    smartFilter.kind.title,
                    14
                )
        )

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.highPassRadius == 14)
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.highPassGainPercent == 100)

        let decodedLegacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(decodedLegacySettings.highPassRadius == nil)
        #expect(decodedLegacySettings.highPassGainPercent == nil)
    }

    @Test func highPassRadiusControlUsesTheSameSettingForEveryFilterDestination() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("image-editor-filter-high-pass-radius"))
        #expect(viewSource.contains("$viewModel.filterHighPassRadius"))
        #expect(viewSource.contains("in: 1...1_000, step: 1"))
        #expect(viewSource.contains("viewModel.selectedFilter != .highPass"))
        #expect(
            viewModelSource.contains(
                "highPassRadius: selectedFilter == .highPass ? filterHighPassRadius : nil"
            )
        )
        #expect(
            viewModelSource.contains(
                "highPassGainPercent: selectedFilter == .highPass ? filterHighPassGainPercent : nil"
            )
        )
        #expect(viewModelSource.contains("filterHighPassRadius = normalized.highPassRadius"))
        #expect(viewModelSource.contains("filterHighPassGainPercent = normalized.highPassGainPercent"))
    }

    @Test func imageEditorEmbossFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = verticalEdgeImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectedFilter = .emboss
        viewModel.filterIntensity = 0.75
        viewModel.filterEmbossAngleDegrees = 0
        viewModel.filterEmbossHeight = 2
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let flatLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let edgeHighlight = try #require(viewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .emboss)
        #expect(filterLayer.filterSettings.normalized().embossAngleDegrees == 0)
        #expect(filterLayer.filterSettings.normalized().embossHeight == 2)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(abs(flatLeft.redComponent - 0.5) < 0.04)
        #expect(abs(flatLeft.redComponent - flatLeft.greenComponent) < 0.002)
        #expect(edgeHighlight.redComponent > 0.85)
        #expect(abs(edgeHighlight.redComponent - edgeHighlight.greenComponent) < 0.002)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())

        smartViewModel.selectedFilter = .emboss
        smartViewModel.filterIntensity = 0.75
        smartViewModel.filterEmbossAngleDegrees = 0
        smartViewModel.filterEmbossHeight = 2
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartEdgeHighlight = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .emboss)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.embossAngleDegrees == 0)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.embossHeight == 2)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartEdgeHighlight.redComponent > 0.85)
        #expect(smartViewModel.smartFilterLabel(try #require(smartLayer.smartFilters.first)) == L10n.format(
            "imageEditor.properties.smartFilterEmbossItem",
            ImageEditorFilter.emboss.title,
            75,
            0,
            2
        ))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restored = try project.restoredDocument()
        let restoredFilter = try #require(restored.selectedLayer?.smartFilters.first)
        #expect(restoredFilter.normalizedSettings.embossAngleDegrees == 0)
        #expect(restoredFilter.normalizedSettings.embossHeight == 2)

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func embossAngleAndHeightControlReliefDirectionAndPreserveLegacyProjects() throws {
        let sourceImage = verticalEdgeImage(size: NSSize(width: 72, height: 48))

        func color(x: CGFloat, angle: Double, height: Double) throws -> NSColor {
            let output = try #require(sourceImage.filtered(
                kind: .emboss,
                intensity: 0.75,
                settings: ImageEditorFilterSettings(
                    embossAngleDegrees: angle,
                    embossHeight: height
                )
            ))
            return try #require(
                output.color(at: CGPoint(x: x, y: 24))?.usingColorSpace(.deviceRGB)
            )
        }

        let rightFacing = try color(x: 35, angle: 0, height: 1)
        let leftFacing = try color(x: 35, angle: 180, height: 1)
        let shallow = try color(x: 34, angle: 0, height: 1)
        let tall = try color(x: 34, angle: 0, height: 3)
        #expect(rightFacing.redComponent > 0.85)
        #expect(leftFacing.redComponent < 0.15)
        #expect(tall.redComponent > shallow.redComponent + 0.3)

        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.embossAngleDegrees == nil)
        #expect(legacySettings.embossHeight == nil)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-emboss-angle"))
        #expect(viewSource.contains("image-editor-filter-emboss-height"))
        #expect(viewSource.contains("image-editor-filter-emboss-amount"))
        #expect(viewModelSource.contains("embossAngleDegrees: selectedFilter == .emboss"))
        #expect(viewModelSource.contains("embossHeight: selectedFilter == .emboss"))
    }

    @Test func imageEditorFindEdgesFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 72, height: 48)
        let sourceImage = verticalEdgeImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.selectedFilter = .findEdges
        #expect(viewModel.filterIntensity == 1)
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let flatLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 12, y: 24))?.usingColorSpace(.deviceRGB))
        let flatRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 60, y: 24))?.usingColorSpace(.deviceRGB))
        let detectedEdge = try #require(viewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))

        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .findEdges)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(flatLeft.redComponent > 0.95)
        #expect(flatRight.redComponent > 0.95)
        #expect(detectedEdge.redComponent < 0.08)
        #expect(abs(detectedEdge.redComponent - detectedEdge.greenComponent) < 0.002)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())

        smartViewModel.selectedFilter = .findEdges
        #expect(smartViewModel.filterIntensity == 1)
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartDetectedEdge = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 35, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .findEdges)
        #expect(smartLayer.smartFilters.first?.normalizedIntensity == 1)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartDetectedEdge.redComponent < 0.08)
        #expect(smartViewModel.smartFilterLabel(try #require(smartLayer.smartFilters.first)) == ImageEditorFilter.findEdges.title)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        #expect(restoredDocument.selectedLayer?.smartFilters.first?.normalizedIntensity == 1)

        let legacyFilter = ImageEditorSmartFilter(kind: .findEdges, intensity: 0.35)
        #expect(
            smartViewModel.smartFilterLabel(legacyFilter)
                == L10n.format(
                    "imageEditor.properties.smartFilterItem",
                    legacyFilter.kind.title,
                    35
                )
        )
        let legacyViewModel = ImageEditorViewModel(sourceName: "legacy.png", image: sourceImage) { _ in }
        let legacyLayerIndex = try #require(legacyViewModel.document.selectedLayerIndex)
        legacyViewModel.document.layers[legacyLayerIndex].smartFilters = [legacyFilter]
        #expect(legacyViewModel.loadSmartFilterIntoControls(legacyFilter.id))
        #expect(legacyViewModel.selectedFilter == .findEdges)
        #expect(legacyViewModel.filterIntensity == 0.35)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("viewModel.selectedFilter != .findEdges"))
        #expect(viewModelSource.contains("if selectedFilter == .findEdges"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func imageEditorMinimumAndMaximumFiltersExpandDarkAndLightRegions() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let whiteSpotImage = binarySpotImage(
            size: canvasSize,
            background: .black,
            spot: .white,
            spotSize: 5
        )
        let maximumViewModel = ImageEditorViewModel(sourceName: "source.png", image: whiteSpotImage) { _ in }
        maximumViewModel.replaceSelectedLayerImageForTesting(whiteSpotImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let maximumBaseLayerID = try #require(maximumViewModel.document.selectedLayerID)
        let maximumBasePixelsBefore = try #require(maximumViewModel.document.selectedLayer?.image.qingtuPNGData())

        maximumViewModel.selectedFilter = .maximum
        maximumViewModel.filterIntensity = 0.35
        maximumViewModel.addFilterLayer()

        let maximumLayer = try #require(maximumViewModel.document.selectedLayer)
        let expandedLight = try #require(maximumViewModel.currentImage.color(at: CGPoint(x: 28, y: 24))?.usingColorSpace(.deviceRGB))
        let farDark = try #require(maximumViewModel.currentImage.color(at: CGPoint(x: 8, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(maximumLayer.isFilter)
        #expect(maximumLayer.filter?.kind == .maximum)
        #expect(maximumViewModel.document.layers.first { $0.id == maximumBaseLayerID }?.image.qingtuPNGData() == maximumBasePixelsBefore)
        #expect(expandedLight.redComponent > 0.95)
        #expect(farDark.redComponent < 0.05)
        #expect(maximumViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let blackSpotImage = binarySpotImage(
            size: canvasSize,
            background: .white,
            spot: .black,
            spotSize: 5
        )
        let minimumViewModel = ImageEditorViewModel(sourceName: "source.png", image: blackSpotImage) { _ in }
        minimumViewModel.replaceSelectedLayerImageForTesting(blackSpotImage, historyTitle: L10n.text("imageEditor.history.brush"))
        minimumViewModel.selectedFilter = .minimum
        minimumViewModel.filterIntensity = 0.35
        minimumViewModel.addFilterLayer()

        let minimumLayer = try #require(minimumViewModel.document.selectedLayer)
        let expandedDark = try #require(minimumViewModel.currentImage.color(at: CGPoint(x: 28, y: 24))?.usingColorSpace(.deviceRGB))
        let farLight = try #require(minimumViewModel.currentImage.color(at: CGPoint(x: 8, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(minimumLayer.isFilter)
        #expect(minimumLayer.filter?.kind == .minimum)
        #expect(expandedDark.redComponent < 0.05)
        #expect(farLight.redComponent > 0.95)

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: whiteSpotImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(whiteSpotImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())
        smartViewModel.selectedFilter = .maximum
        smartViewModel.filterIntensity = 0.35
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartExpandedLight = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 28, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .maximum)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartExpandedLight.redComponent > 0.95)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func minimumAndMaximumUseAnExplicitPixelRadiusAndPersistItNonDestructively() throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let whiteSpot = binarySpotImage(
            size: canvasSize,
            background: .black,
            spot: .white,
            spotSize: 5
        )
        let narrowMaximum = try #require(whiteSpot.filtered(
            kind: .maximum,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(morphologyRadius: 1)
        ))
        let wideMaximum = try #require(whiteSpot.filtered(
            kind: .maximum,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(morphologyRadius: 8)
        ))
        let samplePoint = CGPoint(x: 30, y: 24)
        let narrowLight = try #require(narrowMaximum.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        let wideLight = try #require(wideMaximum.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(narrowLight.redComponent < 0.05)
        #expect(wideLight.redComponent > 0.95)

        let blackSpot = binarySpotImage(
            size: canvasSize,
            background: .white,
            spot: .black,
            spotSize: 5
        )
        let narrowMinimum = try #require(blackSpot.filtered(
            kind: .minimum,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(morphologyRadius: 1)
        ))
        let wideMinimum = try #require(blackSpot.filtered(
            kind: .minimum,
            intensity: 0.5,
            settings: ImageEditorFilterSettings(morphologyRadius: 8)
        ))
        let narrowDark = try #require(narrowMinimum.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        let wideDark = try #require(wideMinimum.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(narrowDark.redComponent > 0.95)
        #expect(wideDark.redComponent < 0.05)

        #expect(ImageEditorFilterSettings(morphologyRadius: -12).normalized().morphologyRadius == 1)
        #expect(ImageEditorFilterSettings(morphologyRadius: 900).normalized().morphologyRadius == 256)

        let viewModel = ImageEditorViewModel(sourceName: "morphology-radius.png", image: whiteSpot) { _ in }
        viewModel.selectedFilter = .maximum
        viewModel.filterMorphologyRadius = 18
        viewModel.addSmartFilterToSelectedLayer()

        let smartFilter = try #require(viewModel.document.selectedLayer?.smartFilters.first)
        #expect(smartFilter.normalizedSettings.morphologyRadius == 18)
        #expect(
            viewModel.smartFilterLabel(smartFilter)
                == L10n.format(
                    "imageEditor.properties.smartFilterMorphologyItem",
                    smartFilter.kind.title,
                    18
                )
        )

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.morphologyRadius == 18)

        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.morphologyRadius == nil)
    }

    @Test func morphologyRadiusControlUsesTheSameSettingForEveryFilterDestination() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )
        let filterSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorFilters.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("image-editor-filter-morphology-radius"))
        #expect(viewSource.contains("$viewModel.filterMorphologyRadius"))
        #expect(viewSource.contains("in: 1...256, step: 1"))
        #expect(
            viewModelSource.contains(
                "morphologyRadius: selectedFilter == .minimum || selectedFilter == .maximum"
            )
        )
        #expect(viewModelSource.contains("filterMorphologyRadius = normalized.morphologyRadius"))
        #expect(filterSource.contains("writeSlidingExtrema("))
    }

    @Test func imageEditorOilPaintFilterLayerAndSmartFilterAreNonDestructive() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = colorSpotImage(
            size: canvasSize,
            background: NSColor(calibratedRed: 0.9, green: 0.1, blue: 0.08, alpha: 1),
            spot: NSColor(calibratedRed: 0.05, green: 0.2, blue: 0.95, alpha: 1),
            spotSize: 3
        )
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.oilPaintRadius == nil)
        #expect(legacySettings.oilPaintTonalLevels == nil)
        #expect(legacySettings.oilPaintStylization == nil)
        #expect(legacySettings.oilPaintCleanliness == nil)
        #expect(legacySettings.oilPaintBristleDetail == nil)
        #expect(legacySettings.oilPaintShine == nil)
        #expect(legacySettings.oilPaintLightingAngleDegrees == nil)
        #expect(legacySettings.oilPaintLightingEnabled == nil)
        let legacyPaint = try #require(sourceImage.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: legacySettings
        ))
        let explicitLegacyPaint = try #require(sourceImage.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(
                oilPaintRadius: 5,
                oilPaintTonalLevels: 11,
                oilPaintStylization: 10,
                oilPaintCleanliness: 0,
                oilPaintBristleDetail: 0,
                oilPaintShine: 0,
                oilPaintLightingAngleDegrees: 135,
                oilPaintLightingEnabled: true
            )
        ))
        #expect(legacyPaint.qingtuPNGData() == explicitLegacyPaint.qingtuPNGData())

        let unstyledPaint = try #require(sourceImage.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(
                oilPaintRadius: 8,
                oilPaintTonalLevels: 11,
                oilPaintStylization: 0
            )
        ))
        #expect(unstyledPaint.qingtuPNGData() == sourceImage.qingtuPNGData())
        #expect(unstyledPaint.qingtuPNGData() != legacyPaint.qingtuPNGData())

        let tonalSource = gradientImage(size: canvasSize)
        let coarseTones = try #require(tonalSource.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(
                oilPaintRadius: 4,
                oilPaintTonalLevels: 6
            )
        ))
        let detailedTones = try #require(tonalSource.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(
                oilPaintRadius: 4,
                oilPaintTonalLevels: 18
            )
        ))
        #expect(coarseTones.qingtuPNGData() != detailedTones.qingtuPNGData())

        let legacyCleanliness = try #require(tonalSource.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(
                oilPaintRadius: 4,
                oilPaintTonalLevels: 11,
                oilPaintStylization: 10,
                oilPaintCleanliness: 0
            )
        ))
        let fullCleanliness = try #require(tonalSource.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(
                oilPaintRadius: 4,
                oilPaintTonalLevels: 11,
                oilPaintStylization: 10,
                oilPaintCleanliness: 10
            )
        ))
        #expect(legacyCleanliness.qingtuPNGData() != fullCleanliness.qingtuPNGData())
        #expect(ImageEditorFilterSettings(oilPaintCleanliness: 25).normalized().oilPaintCleanliness == 10)

        let fullBristleDetail = try #require(tonalSource.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(
                oilPaintRadius: 4,
                oilPaintTonalLevels: 11,
                oilPaintStylization: 10,
                oilPaintCleanliness: 0,
                oilPaintBristleDetail: 10
            )
        ))
        #expect(legacyCleanliness.qingtuPNGData() != fullBristleDetail.qingtuPNGData())
        #expect(ImageEditorFilterSettings(oilPaintBristleDetail: -2).normalized().oilPaintBristleDetail == 0)

        let fullShine = try #require(tonalSource.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(
                oilPaintRadius: 4,
                oilPaintTonalLevels: 11,
                oilPaintStylization: 10,
                oilPaintCleanliness: 0,
                oilPaintBristleDetail: 0,
                oilPaintShine: 10
            )
        ))
        #expect(legacyCleanliness.qingtuPNGData() != fullShine.qingtuPNGData())
        #expect(ImageEditorFilterSettings(oilPaintShine: 12).normalized().oilPaintShine == 10)

        let explicitLegacyAngle = try #require(tonalSource.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(
                oilPaintRadius: 4,
                oilPaintTonalLevels: 11,
                oilPaintStylization: 10,
                oilPaintCleanliness: 0,
                oilPaintBristleDetail: 0,
                oilPaintShine: 10,
                oilPaintLightingAngleDegrees: 135
            )
        ))
        #expect(fullShine.qingtuPNGData() == explicitLegacyAngle.qingtuPNGData())
        let oppositeLightingAngle = try #require(tonalSource.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(
                oilPaintRadius: 4,
                oilPaintTonalLevels: 11,
                oilPaintStylization: 10,
                oilPaintCleanliness: 0,
                oilPaintBristleDetail: 0,
                oilPaintShine: 10,
                oilPaintLightingAngleDegrees: -45
            )
        ))
        #expect(explicitLegacyAngle.qingtuPNGData() != oppositeLightingAngle.qingtuPNGData())
        let disabledLighting = try #require(tonalSource.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(
                oilPaintRadius: 4,
                oilPaintTonalLevels: 11,
                oilPaintStylization: 10,
                oilPaintCleanliness: 0,
                oilPaintBristleDetail: 0,
                oilPaintShine: 10,
                oilPaintLightingAngleDegrees: -45,
                oilPaintLightingEnabled: false
            )
        ))
        #expect(disabledLighting.qingtuPNGData() == legacyCleanliness.qingtuPNGData())
        #expect(
            ImageEditorFilterSettings(oilPaintLightingAngleDegrees: 220)
                .normalized().oilPaintLightingAngleDegrees == 180
        )

        let finePaint = try #require(sourceImage.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(oilPaintRadius: 1)
        ))
        let broadPaint = try #require(sourceImage.filtered(
            kind: .oilPaint,
            intensity: 0.75,
            settings: ImageEditorFilterSettings(oilPaintRadius: 8)
        ))
        let fineCenter = try #require(
            finePaint.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB)
        )
        let broadCenter = try #require(
            broadPaint.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB)
        )
        #expect(fineCenter.blueComponent > broadCenter.blueComponent + 0.2)
        #expect(broadCenter.redComponent > 0.75)
        #expect(broadCenter.blueComponent < 0.25)
        #expect(finePaint.qingtuPNGData() != broadPaint.qingtuPNGData())

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let blueSpotBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .oilPaint
        viewModel.filterIntensity = 0.75
        viewModel.filterOilPaintRadius = 8
        viewModel.filterOilPaintTonalLevels = 11
        viewModel.filterOilPaintStylization = 10
        viewModel.filterOilPaintCleanliness = 6.5
        viewModel.filterOilPaintBristleDetail = 7.5
        viewModel.filterOilPaintShine = 5.5
        viewModel.filterOilPaintLightingAngleDegrees = -45
        viewModel.filterOilPaintLightingEnabled = false
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let paintedCenter = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .oilPaint)
        #expect(filterLayer.filterSettings.normalized().oilPaintRadius == 8)
        #expect(filterLayer.filterSettings.normalized().oilPaintTonalLevels == 11)
        #expect(filterLayer.filterSettings.normalized().oilPaintStylization == 10)
        #expect(filterLayer.filterSettings.normalized().oilPaintCleanliness == 6.5)
        #expect(filterLayer.filterSettings.normalized().oilPaintBristleDetail == 7.5)
        #expect(filterLayer.filterSettings.normalized().oilPaintShine == 5.5)
        #expect(filterLayer.filterSettings.normalized().oilPaintLightingAngleDegrees == -45)
        #expect(filterLayer.filterSettings.normalized().oilPaintLightingEnabled == false)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(blueSpotBefore.blueComponent > 0.85)
        #expect(paintedCenter.redComponent > 0.65)
        #expect(paintedCenter.blueComponent > 0.25)
        #expect(paintedCenter.blueComponent < 0.4)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())
        smartViewModel.selectedFilter = .oilPaint
        smartViewModel.filterIntensity = 0.75
        smartViewModel.filterOilPaintRadius = 8
        smartViewModel.filterOilPaintTonalLevels = 11
        smartViewModel.filterOilPaintStylization = 10
        smartViewModel.filterOilPaintCleanliness = 6.5
        smartViewModel.filterOilPaintBristleDetail = 7.5
        smartViewModel.filterOilPaintShine = 5.5
        smartViewModel.filterOilPaintLightingAngleDegrees = -45
        smartViewModel.filterOilPaintLightingEnabled = false
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartPaintedCenter = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .oilPaint)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.oilPaintRadius == 8)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.oilPaintTonalLevels == 11)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.oilPaintStylization == 10)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.oilPaintCleanliness == 6.5)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.oilPaintBristleDetail == 7.5)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.oilPaintShine == 5.5)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.oilPaintLightingAngleDegrees == -45)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.oilPaintLightingEnabled == false)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartPaintedCenter.redComponent > 0.65)
        #expect(smartPaintedCenter.blueComponent > 0.25)
        #expect(smartPaintedCenter.blueComponent < 0.4)
        #expect(smartViewModel.smartFilterLabel(try #require(smartLayer.smartFilters.first)) == L10n.format(
            "imageEditor.properties.smartFilterOilPaintItem",
            ImageEditorFilter.oilPaint.title,
            8,
            11,
            "10.0",
            "6.5",
            "7.5",
            "5.5",
            -45,
            L10n.text("imageEditor.filter.oilPaintLightingOff")
        ))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restored = try project.restoredDocument()
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.oilPaintRadius == 8)
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.oilPaintTonalLevels == 11)
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.oilPaintStylization == 10)
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.oilPaintCleanliness == 6.5)
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.oilPaintBristleDetail == 7.5)
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.oilPaintShine == 5.5)
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.oilPaintLightingAngleDegrees == -45)
        #expect(restored.selectedLayer?.smartFilters.first?.normalizedSettings.oilPaintLightingEnabled == false)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-oil-paint-radius"))
        #expect(viewSource.contains("image-editor-filter-oil-paint-tonal-levels"))
        #expect(viewSource.contains("image-editor-filter-oil-paint-stylization"))
        #expect(viewSource.contains("image-editor-filter-oil-paint-cleanliness"))
        #expect(viewSource.contains("image-editor-filter-oil-paint-bristle-detail"))
        #expect(viewSource.contains("image-editor-filter-oil-paint-shine"))
        #expect(viewSource.contains("image-editor-filter-oil-paint-lighting-angle"))
        #expect(viewSource.contains("image-editor-filter-oil-paint-lighting-enabled"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)
    }

    @Test func imageEditorVignetteAmountAndMidpointSupportDarkAndLightEdges() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = solidImage(size: canvasSize, color: NSColor(calibratedWhite: 0.8, alpha: 1))
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.vignetteAmountPercent == nil)
        #expect(legacySettings.vignetteMidpoint == nil)
        let legacyVignette = try #require(sourceImage.filtered(
            kind: .vignette,
            intensity: 1,
            settings: legacySettings
        ))
        let explicitLegacyVignette = try #require(sourceImage.filtered(
            kind: .vignette,
            intensity: 0,
            settings: ImageEditorFilterSettings(
                vignetteAmountPercent: -85,
                vignetteMidpoint: 0.28
            )
        ))
        #expect(legacyVignette.qingtuPNGData() == explicitLegacyVignette.qingtuPNGData())
        #expect(ImageEditorFilterSettings(vignetteAmountPercent: -200).normalized().vignetteAmountPercent == -100)
        #expect(ImageEditorFilterSettings(vignetteAmountPercent: 200).normalized().vignetteAmountPercent == 100)
        let zeroVignette = try #require(sourceImage.filtered(
            kind: .vignette,
            intensity: 1,
            settings: ImageEditorFilterSettings(vignetteAmountPercent: 0)
        ))
        #expect(zeroVignette.qingtuPNGData() == sourceImage.qingtuPNGData())

        let middleGrayImage = solidImage(
            size: canvasSize,
            color: NSColor(calibratedWhite: 0.4, alpha: 1)
        )
        let middleGrayCenter = try #require(
            middleGrayImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB)
        )
        let lightVignette = try #require(middleGrayImage.filtered(
            kind: .vignette,
            intensity: 0,
            settings: ImageEditorFilterSettings(vignetteAmountPercent: 60)
        ))
        let lightCenter = try #require(
            lightVignette.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB)
        )
        let lightCorner = try #require(
            lightVignette.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB)
        )
        #expect(abs(lightCenter.redComponent - middleGrayCenter.redComponent) < 0.01)
        #expect(lightCorner.redComponent > 0.60)

        let broadCenterVignette = try #require(sourceImage.filtered(
            kind: .vignette,
            intensity: 1,
            settings: ImageEditorFilterSettings(vignetteMidpoint: 0.75)
        ))
        let legacyMidEdge = try #require(
            legacyVignette.color(at: CGPoint(x: 8, y: 24))?.usingColorSpace(.deviceRGB)
        )
        let broadCenterMidEdge = try #require(
            broadCenterVignette.color(at: CGPoint(x: 8, y: 24))?.usingColorSpace(.deviceRGB)
        )
        #expect(broadCenterMidEdge.redComponent > legacyMidEdge.redComponent + 0.03)

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let centerBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .vignette
        viewModel.filterIntensity = 0
        viewModel.filterVignetteAmountPercent = -70
        viewModel.filterVignetteMidpoint = 0.75
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let centerAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        let cornerAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .vignette)
        #expect(filterLayer.filterSettings.normalized().vignetteAmountPercent == -70)
        #expect(filterLayer.filterSettings.normalized().vignetteMidpoint == 0.75)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(centerBefore.redComponent > 0.72)
        #expect(abs(centerBefore.redComponent - centerBefore.greenComponent) < 0.002)
        #expect(centerAfter.redComponent > 0.74)
        #expect(cornerAfter.redComponent < 0.28)
        #expect(abs(cornerAfter.redComponent - cornerAfter.greenComponent) < 0.002)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartPreviewBefore = try #require(smartViewModel.currentImage.qingtuPNGData())
        smartViewModel.selectedFilter = .vignette
        smartViewModel.filterIntensity = 0
        smartViewModel.filterVignetteAmountPercent = -70
        smartViewModel.filterVignetteMidpoint = 0.75
        smartViewModel.addSmartFilterToSelectedLayer()

        var smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilterID = try #require(smartLayer.smartFilters.first?.id)
        let smartCornerAfter = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 0, y: 0))?.usingColorSpace(.deviceRGB))
        #expect(smartLayer.smartFilters.first?.kind == .vignette)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.vignetteAmountPercent == -70)
        #expect(smartLayer.smartFilters.first?.normalizedSettings.vignetteMidpoint == 0.75)
        #expect(smartViewModel.smartFilterLabel(try #require(smartLayer.smartFilters.first)) == L10n.format(
            "imageEditor.properties.smartFilterVignetteItem",
            ImageEditorFilter.vignette.title,
            "-70",
            75
        ))
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartCornerAfter.redComponent < 0.28)
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        smartViewModel.toggleSmartFilterOnSelectedLayer(smartFilterID)
        smartLayer = try #require(smartViewModel.document.selectedLayer)
        #expect(smartLayer.smartFilters.first?.isEnabled == false)
        #expect(try #require(smartViewModel.currentImage.qingtuPNGData()) == smartPreviewBefore)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()
        #expect(restored.selectedLayer?.filterSettings.normalized().vignetteAmountPercent == -70)
        #expect(restored.selectedLayer?.filterSettings.normalized().vignetteMidpoint == 0.75)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-vignette-amount"))
        #expect(viewSource.contains("image-editor-filter-vignette-midpoint"))
        #expect(viewSource.contains("viewModel.selectedFilter != .vignette"))
    }

    @Test func imageEditorLiquifyPushPixelsSupportLegacyValuesLayersAndSmartFilters() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = splitColorImage(size: canvasSize, left: .systemRed, right: .systemBlue)
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.liquifyPushXPixels == nil)
        #expect(legacySettings.liquifyPushYPixels == nil)
        #expect(legacySettings.liquifyPushX == 0.25)
        #expect(legacySettings.liquifyPushY == 0)
        let legacyMaximumShift = 48 * 0.45 * 0.42
        let legacyPush = try #require(sourceImage.filtered(
            kind: .liquifyPush,
            intensity: 1,
            settings: legacySettings
        ))
        let explicitLegacyPush = try #require(sourceImage.filtered(
            kind: .liquifyPush,
            intensity: 0,
            settings: ImageEditorFilterSettings(
                liquifyPushXPixels: legacyMaximumShift * 0.25,
                liquifyPushYPixels: 0
            )
        ))
        #expect(legacyPush.qingtuPNGData() == explicitLegacyPush.qingtuPNGData())
        #expect(ImageEditorFilterSettings(liquifyPushXPixels: -15_000).normalized().liquifyPushXPixels == -9_999)
        #expect(ImageEditorFilterSettings(liquifyPushYPixels: 15_000).normalized().liquifyPushYPixels == 9_999)
        let zeroPush = try #require(sourceImage.filtered(
            kind: .liquifyPush,
            intensity: 1,
            settings: ImageEditorFilterSettings(liquifyPushXPixels: 0, liquifyPushYPixels: 0)
        ))
        #expect(zeroPush.qingtuPNGData() == sourceImage.qingtuPNGData())

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let centerBefore = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .liquifyPush
        viewModel.filterIntensity = 0
        viewModel.filterLiquifyPushXPixels = 10
        viewModel.filterLiquifyPushYPixels = 0
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let centerAfter = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .liquifyPush)
        #expect(filterLayer.filterSettings.normalized().liquifyPushXPixels == 10)
        #expect(filterLayer.filterSettings.normalized().liquifyPushYPixels == 0)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(centerBefore.blueComponent > centerBefore.redComponent + 0.4)
        #expect(centerAfter.redComponent > centerAfter.blueComponent + 0.4)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .liquifyPush
        smartViewModel.filterIntensity = 0
        smartViewModel.filterLiquifyPushXPixels = 10
        smartViewModel.filterLiquifyPushYPixels = 0
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartCenterAfter = try #require(smartViewModel.currentImage.color(at: CGPoint(x: 24, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .liquifyPush)
        #expect(smartFilter.normalizedSettings.liquifyPushXPixels == 10)
        #expect(smartFilter.normalizedSettings.liquifyPushYPixels == 0)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartCenterAfter.redComponent > smartCenterAfter.blueComponent + 0.4)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterLiquifyPushItem", smartFilter.kind.title, "+10", "+0"))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .liquifyPush)
        #expect(restoredFilter.normalizedSettings.liquifyPushXPixels == 10)
        #expect(restoredFilter.normalizedSettings.liquifyPushYPixels == 0)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-liquify-push-x-pixels"))
        #expect(viewSource.contains("image-editor-filter-liquify-push-y-pixels"))
        #expect(viewSource.contains("viewModel.selectedFilter != .liquifyPush"))
    }

    @Test func imageEditorLiquifyTwirlAngleSupportsLegacyAndSignedDegrees() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = quadrantImage(
            size: canvasSize,
            topLeft: .systemRed,
            topRight: .systemBlue,
            bottomLeft: .systemGreen,
            bottomRight: .systemYellow
        )
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.liquifyTwirlAngleDegrees == nil)
        #expect(legacySettings.liquifyTwirlAngle == 0.5)
        let legacyTwirl = try #require(sourceImage.filtered(
            kind: .liquifyTwirl,
            intensity: 1,
            settings: legacySettings
        ))
        let explicitLegacyTwirl = try #require(sourceImage.filtered(
            kind: .liquifyTwirl,
            intensity: 0,
            settings: ImageEditorFilterSettings(liquifyTwirlAngleDegrees: 135)
        ))
        #expect(legacyTwirl.qingtuPNGData() == explicitLegacyTwirl.qingtuPNGData())
        #expect(ImageEditorFilterSettings(liquifyTwirlAngleDegrees: -1_500).normalized().liquifyTwirlAngleDegrees == -999)
        #expect(ImageEditorFilterSettings(liquifyTwirlAngleDegrees: 1_500).normalized().liquifyTwirlAngleDegrees == 999)
        let zeroTwirl = try #require(sourceImage.filtered(
            kind: .liquifyTwirl,
            intensity: 1,
            settings: ImageEditorFilterSettings(liquifyTwirlAngleDegrees: 0)
        ))
        #expect(zeroTwirl.qingtuPNGData() == sourceImage.qingtuPNGData())

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let samplePoint = CGPoint(x: 30, y: 30)
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .liquifyTwirl
        viewModel.filterIntensity = 0
        viewModel.filterLiquifyTwirlAngleDegrees = 270
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sampleAfter = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .liquifyTwirl)
        #expect(filterLayer.filterSettings.normalized().liquifyTwirlAngleDegrees == 270)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleBefore.blueComponent > sampleBefore.redComponent + 0.4)
        let sampleDifference = abs(sampleAfter.redComponent - sampleBefore.redComponent)
            + abs(sampleAfter.greenComponent - sampleBefore.greenComponent)
            + abs(sampleAfter.blueComponent - sampleBefore.blueComponent)
        #expect(sampleDifference > 0.5)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .liquifyTwirl
        smartViewModel.filterIntensity = 0
        smartViewModel.filterLiquifyTwirlAngleDegrees = -270
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .liquifyTwirl)
        #expect(smartFilter.normalizedSettings.liquifyTwirlAngleDegrees == -270)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        let smartSampleDifference = abs(smartSampleAfter.redComponent - sampleBefore.redComponent)
            + abs(smartSampleAfter.greenComponent - sampleBefore.greenComponent)
            + abs(smartSampleAfter.blueComponent - sampleBefore.blueComponent)
        #expect(smartSampleDifference > 0.5)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterLiquifyTwirlItem", smartFilter.kind.title, "-270"))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .liquifyTwirl)
        #expect(restoredFilter.normalizedSettings.liquifyTwirlAngleDegrees == -270)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-liquify-twirl-angle"))
        #expect(viewSource.contains("viewModel.selectedFilter != .liquifyTwirl"))
    }

    @Test func imageEditorLiquifyPuckerBloatAmountSupportsLegacyAndSignedRadialWarp() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = radialRampImage(size: canvasSize)
        let samplePoint = CGPoint(x: 31, y: 24)
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.liquifyBulgeAmountPercent == nil)
        #expect(legacySettings.liquifyBulgeAmount == 0.5)
        let legacyBloat = try #require(sourceImage.filtered(
            kind: .liquifyPuckerBloat,
            intensity: 1,
            settings: legacySettings
        ))
        let explicitLegacyBloat = try #require(sourceImage.filtered(
            kind: .liquifyPuckerBloat,
            intensity: 0,
            settings: ImageEditorFilterSettings(liquifyBulgeAmountPercent: 50)
        ))
        #expect(legacyBloat.qingtuPNGData() == explicitLegacyBloat.qingtuPNGData())
        #expect(ImageEditorFilterSettings(liquifyBulgeAmountPercent: -200).normalized().liquifyBulgeAmountPercent == -100)
        #expect(ImageEditorFilterSettings(liquifyBulgeAmountPercent: 200).normalized().liquifyBulgeAmountPercent == 100)
        let zeroAmount = try #require(sourceImage.filtered(
            kind: .liquifyPuckerBloat,
            intensity: 1,
            settings: ImageEditorFilterSettings(liquifyBulgeAmountPercent: 0)
        ))
        #expect(zeroAmount.qingtuPNGData() == sourceImage.qingtuPNGData())

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .liquifyPuckerBloat
        viewModel.filterIntensity = 0
        viewModel.filterLiquifyBulgeAmountPercent = 100
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let bloatedSample = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        let farEdge = try #require(viewModel.currentImage.color(at: CGPoint(x: 47, y: 24))?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .liquifyPuckerBloat)
        #expect(filterLayer.filterSettings.normalized().liquifyBulgeAmountPercent == 100)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(bloatedSample.redComponent < sampleBefore.redComponent - 0.05)
        #expect(farEdge.redComponent > 0.88)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        smartViewModel.selectedFilter = .liquifyPuckerBloat
        smartViewModel.filterIntensity = 0
        smartViewModel.filterLiquifyBulgeAmountPercent = -100
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let puckeredSample = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .liquifyPuckerBloat)
        #expect(smartFilter.normalizedSettings.liquifyBulgeAmountPercent == -100)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(puckeredSample.redComponent > sampleBefore.redComponent + 0.05)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterLiquifyPuckerBloatItem", smartFilter.kind.title, "-100"))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .liquifyPuckerBloat)
        #expect(restoredFilter.normalizedSettings.liquifyBulgeAmountPercent == -100)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-liquify-bulge-amount"))
        #expect(viewSource.contains("viewModel.selectedFilter != .liquifyPuckerBloat"))
    }

    @Test func imageEditorWaveAmplitudeSupportsLegacyAndSignedHorizontalWarp() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = splitColorImage(size: canvasSize, left: .systemRed, right: .systemBlue)
        let positiveWavePoint = CGPoint(x: 24, y: 12)
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.waveAmplitudePercent == nil)
        #expect(legacySettings.waveAmplitude == 0.5)
        #expect(legacySettings.waveFrequency == 0.25)
        let legacyWave = try #require(sourceImage.filtered(
            kind: .wave,
            intensity: 1,
            settings: legacySettings
        ))
        let explicitLegacyWave = try #require(sourceImage.filtered(
            kind: .wave,
            intensity: 0,
            settings: ImageEditorFilterSettings(
                waveAmplitudePercent: 50,
                waveFrequency: 0.25
            )
        ))
        #expect(legacyWave.qingtuPNGData() == explicitLegacyWave.qingtuPNGData())
        #expect(ImageEditorFilterSettings(waveAmplitudePercent: -200).normalized().waveAmplitudePercent == -100)
        #expect(ImageEditorFilterSettings(waveAmplitudePercent: 200).normalized().waveAmplitudePercent == 100)
        let zeroWave = try #require(sourceImage.filtered(
            kind: .wave,
            intensity: 1,
            settings: ImageEditorFilterSettings(waveAmplitudePercent: 0)
        ))
        #expect(zeroWave.qingtuPNGData() == sourceImage.qingtuPNGData())

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: positiveWavePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .wave
        viewModel.filterIntensity = 0
        viewModel.filterWaveAmplitudePercent = 100
        viewModel.filterWaveFrequency = 0
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let wavedSample = try #require(viewModel.currentImage.color(at: positiveWavePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .wave)
        #expect(filterLayer.filterSettings.normalized().waveAmplitudePercent == 100)
        #expect(filterLayer.filterSettings.normalized().waveFrequency == 0)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleBefore.blueComponent > sampleBefore.redComponent + 0.4)
        #expect(wavedSample.redComponent > wavedSample.blueComponent + 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let negativeWavePoint = CGPoint(x: 23, y: 12)
        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartSampleBefore = try #require(smartViewModel.currentImage.color(at: negativeWavePoint)?.usingColorSpace(.deviceRGB))
        smartViewModel.selectedFilter = .wave
        smartViewModel.filterIntensity = 0
        smartViewModel.filterWaveAmplitudePercent = -100
        smartViewModel.filterWaveFrequency = 0
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: negativeWavePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .wave)
        #expect(smartFilter.normalizedSettings.waveAmplitudePercent == -100)
        #expect(smartFilter.normalizedSettings.waveFrequency == 0)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleBefore.redComponent > smartSampleBefore.blueComponent + 0.4)
        #expect(smartSampleAfter.blueComponent > smartSampleAfter.redComponent + 0.25)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterWaveItem", smartFilter.kind.title, "-100", 0))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .wave)
        #expect(restoredFilter.normalizedSettings.waveAmplitudePercent == -100)
        #expect(restoredFilter.normalizedSettings.waveFrequency == 0)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-wave-amplitude"))
        #expect(viewSource.contains("viewModel.selectedFilter != .wave"))
    }

    @Test func imageEditorOffsetPixelsSupportLegacyValuesLayersAndSmartFilters() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = splitColorImage(size: canvasSize, left: .systemRed, right: .systemBlue)
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.offsetXPixels == nil)
        #expect(legacySettings.offsetYPixels == nil)
        #expect(legacySettings.offsetX == 0.25)

        let legacyOutput = try #require(sourceImage.filtered(
            kind: .offset,
            intensity: 1,
            settings: legacySettings
        ))
        let explicitOutput = try #require(sourceImage.filtered(
            kind: .offset,
            intensity: 0,
            settings: ImageEditorFilterSettings(offsetXPixels: 6, offsetYPixels: 0)
        ))
        #expect(legacyOutput.qingtuPNGData() == explicitOutput.qingtuPNGData())

        let clampedSettings = ImageEditorFilterSettings(
            offsetXPixels: 15_000,
            offsetYPixels: -15_000
        ).normalized()
        #expect(clampedSettings.offsetXPixels == 9_999)
        #expect(clampedSettings.offsetYPixels == -9_999)
        let bypassed = try #require(sourceImage.filtered(
            kind: .offset,
            intensity: 1,
            settings: ImageEditorFilterSettings(offsetXPixels: 0, offsetYPixels: 0)
        ))
        #expect(bypassed.qingtuPNGData() == sourceImage.qingtuPNGData())

        let samplePoint = CGPoint(x: 12, y: 24)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .offset
        viewModel.filterIntensity = 0
        viewModel.filterOffsetXPixels = 24
        viewModel.filterOffsetYPixels = 0
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sampleAfter = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .offset)
        #expect(filterLayer.filterSettings.normalized().offsetXPixels == 24)
        #expect(filterLayer.filterSettings.normalized().offsetYPixels == 0)
        #expect(filterLayer.filterSettings.normalized().offsetUndefinedAreaMode == .wrapAround)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleBefore.redComponent > sampleBefore.blueComponent + 0.4)
        #expect(sampleAfter.blueComponent > sampleAfter.redComponent + 0.4)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let quadrantSource = quadrantImage(
            size: canvasSize,
            topLeft: .systemRed,
            topRight: .systemBlue,
            bottomLeft: .systemGreen,
            bottomRight: .systemYellow
        )
        let verticalSamplePoint = CGPoint(x: 12, y: 36)
        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: quadrantSource) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(quadrantSource, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartSampleBefore = try #require(smartViewModel.currentImage.color(at: verticalSamplePoint)?.usingColorSpace(.deviceRGB))
        smartViewModel.selectedFilter = .offset
        smartViewModel.filterIntensity = 0
        smartViewModel.filterOffsetXPixels = 0
        smartViewModel.filterOffsetYPixels = 24
        smartViewModel.filterOffsetUndefinedAreaMode = .repeatEdgePixels
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: verticalSamplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .offset)
        #expect(smartFilter.normalizedSettings.offsetXPixels == 0)
        #expect(smartFilter.normalizedSettings.offsetYPixels == 24)
        #expect(smartFilter.normalizedSettings.offsetUndefinedAreaMode == .repeatEdgePixels)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleBefore.redComponent > smartSampleBefore.greenComponent + 0.4)
        #expect(smartSampleAfter.greenComponent > smartSampleAfter.redComponent + 0.25)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format(
            "imageEditor.properties.smartFilterOffsetItem",
            smartFilter.kind.title,
            "+0",
            "+24",
            ImageEditorOffsetUndefinedAreaMode.repeatEdgePixels.title
        ))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .offset)
        #expect(restoredFilter.normalizedSettings.offsetXPixels == 0)
        #expect(restoredFilter.normalizedSettings.offsetYPixels == 24)
        #expect(restoredFilter.normalizedSettings.offsetUndefinedAreaMode == .repeatEdgePixels)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-offset-x-pixels"))
        #expect(viewSource.contains("image-editor-filter-offset-y-pixels"))
        #expect(viewSource.contains("viewModel.selectedFilter != .offset"))
    }

    @Test func offsetUndefinedAreaModesRenderDistinctPixelsAndPreserveLegacyProjects() throws {
        let sourceImage = splitColorImage(
            size: NSSize(width: 48, height: 48),
            left: .systemRed,
            right: .systemBlue
        )
        let samplePoint = CGPoint(x: 12, y: 24)

        func color(for mode: ImageEditorOffsetUndefinedAreaMode) throws -> NSColor {
            let output = try #require(sourceImage.filtered(
                kind: .offset,
                intensity: 1,
                settings: ImageEditorFilterSettings(
                    offsetX: 1,
                    offsetY: 0,
                    offsetUndefinedAreaMode: mode
                )
            ))
            return try #require(output.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        }

        let wrapped = try color(for: .wrapAround)
        let repeated = try color(for: .repeatEdgePixels)
        let transparent = try color(for: .transparent)
        #expect(wrapped.blueComponent > wrapped.redComponent + 0.4)
        #expect(repeated.redComponent > repeated.blueComponent + 0.4)
        #expect(transparent.alphaComponent < 0.02)

        let restoredLegacy = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(restoredLegacy.offsetUndefinedAreaMode == .wrapAround)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let viewModelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorViewModel.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-offset-undefined-area-mode"))
        #expect(viewSource.contains("$viewModel.filterOffsetUndefinedAreaMode"))
        #expect(viewModelSource.contains("offsetUndefinedAreaMode: filterOffsetUndefinedAreaMode"))
        #expect(viewModelSource.contains("filterOffsetUndefinedAreaMode = normalized.offsetUndefinedAreaMode"))
    }

    @Test func imageEditorRippleAmountSupportsLegacyAndSignedRadialWarp() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = radialRampImage(size: canvasSize)
        let samplePoint = CGPoint(x: 29, y: 24)
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.rippleAmountPercent == nil)
        #expect(legacySettings.rippleAmount == 0.5)
        #expect(legacySettings.rippleFrequency == 0.25)
        let legacyRipple = try #require(sourceImage.filtered(
            kind: .ripple,
            intensity: 1,
            settings: legacySettings
        ))
        let explicitLegacyRipple = try #require(sourceImage.filtered(
            kind: .ripple,
            intensity: 0,
            settings: ImageEditorFilterSettings(
                rippleAmountPercent: 50,
                rippleFrequency: 0.25
            )
        ))
        #expect(legacyRipple.qingtuPNGData() == explicitLegacyRipple.qingtuPNGData())
        #expect(ImageEditorFilterSettings(rippleAmountPercent: -200).normalized().rippleAmountPercent == -100)
        #expect(ImageEditorFilterSettings(rippleAmountPercent: 200).normalized().rippleAmountPercent == 100)
        let zeroRipple = try #require(sourceImage.filtered(
            kind: .ripple,
            intensity: 1,
            settings: ImageEditorFilterSettings(rippleAmountPercent: 0)
        ))
        #expect(zeroRipple.qingtuPNGData() == sourceImage.qingtuPNGData())

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .ripple
        viewModel.filterIntensity = 0
        viewModel.filterRippleAmountPercent = 100
        viewModel.filterRippleFrequency = 0
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sampleAfter = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .ripple)
        #expect(filterLayer.filterSettings.normalized().rippleAmountPercent == 100)
        #expect(filterLayer.filterSettings.normalized().rippleFrequency == 0)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleAfter.redComponent > sampleBefore.redComponent + 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartSampleBefore = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        smartViewModel.selectedFilter = .ripple
        smartViewModel.filterIntensity = 0
        smartViewModel.filterRippleAmountPercent = -100
        smartViewModel.filterRippleFrequency = 0
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .ripple)
        #expect(smartFilter.normalizedSettings.rippleAmountPercent == -100)
        #expect(smartFilter.normalizedSettings.rippleFrequency == 0)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleAfter.redComponent < smartSampleBefore.redComponent - 0.03)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterRippleItem", smartFilter.kind.title, "-100", 0))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .ripple)
        #expect(restoredFilter.normalizedSettings.rippleAmountPercent == -100)
        #expect(restoredFilter.normalizedSettings.rippleFrequency == 0)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-ripple-amount"))
        #expect(viewSource.contains("viewModel.selectedFilter != .ripple"))
    }

    @Test func imageEditorPinchAmountSupportsLegacyAndSignedRadialWarp() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = radialRampImage(size: canvasSize)
        let samplePoint = CGPoint(x: 30, y: 24)
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.pinchAmountPercent == nil)
        #expect(legacySettings.pinchAmount == 0.5)
        let legacyPinch = try #require(sourceImage.filtered(
            kind: .pinch,
            intensity: 1,
            settings: legacySettings
        ))
        let explicitLegacyPinch = try #require(sourceImage.filtered(
            kind: .pinch,
            intensity: 0,
            settings: ImageEditorFilterSettings(pinchAmountPercent: 50)
        ))
        #expect(legacyPinch.qingtuPNGData() == explicitLegacyPinch.qingtuPNGData())
        #expect(ImageEditorFilterSettings(pinchAmountPercent: -200).normalized().pinchAmountPercent == -100)
        #expect(ImageEditorFilterSettings(pinchAmountPercent: 200).normalized().pinchAmountPercent == 100)
        let zeroPinch = try #require(sourceImage.filtered(
            kind: .pinch,
            intensity: 1,
            settings: ImageEditorFilterSettings(pinchAmountPercent: 0)
        ))
        #expect(zeroPinch.qingtuPNGData() == sourceImage.qingtuPNGData())

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .pinch
        viewModel.filterIntensity = 0
        viewModel.filterPinchAmountPercent = 100
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sampleAfter = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .pinch)
        #expect(filterLayer.filterSettings.normalized().pinchAmountPercent == 100)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleAfter.redComponent > sampleBefore.redComponent + 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartSampleBefore = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        smartViewModel.selectedFilter = .pinch
        smartViewModel.filterIntensity = 0
        smartViewModel.filterPinchAmountPercent = -100
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .pinch)
        #expect(smartFilter.normalizedSettings.pinchAmountPercent == -100)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleAfter.redComponent < smartSampleBefore.redComponent - 0.03)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterPinchItem", smartFilter.kind.title, "-100"))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .pinch)
        #expect(restoredFilter.normalizedSettings.pinchAmountPercent == -100)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-pinch-amount"))
        #expect(viewSource.contains("viewModel.selectedFilter != .pinch"))
    }

    @Test func imageEditorSpherizeAmountSupportsLegacyAndSignedRadialWarp() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = radialRampImage(size: canvasSize)
        let samplePoint = CGPoint(x: 30, y: 24)
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.spherizeAmountPercent == nil)
        #expect(legacySettings.spherizeAmount == 0.5)
        let legacySpherize = try #require(sourceImage.filtered(
            kind: .spherize,
            intensity: 1,
            settings: legacySettings
        ))
        let explicitLegacySpherize = try #require(sourceImage.filtered(
            kind: .spherize,
            intensity: 0,
            settings: ImageEditorFilterSettings(spherizeAmountPercent: 50)
        ))
        #expect(legacySpherize.qingtuPNGData() == explicitLegacySpherize.qingtuPNGData())
        #expect(ImageEditorFilterSettings(spherizeAmountPercent: -200).normalized().spherizeAmountPercent == -100)
        #expect(ImageEditorFilterSettings(spherizeAmountPercent: 200).normalized().spherizeAmountPercent == 100)
        let zeroSpherize = try #require(sourceImage.filtered(
            kind: .spherize,
            intensity: 1,
            settings: ImageEditorFilterSettings(spherizeAmountPercent: 0)
        ))
        #expect(zeroSpherize.qingtuPNGData() == sourceImage.qingtuPNGData())

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .spherize
        viewModel.filterIntensity = 0
        viewModel.filterSpherizeAmountPercent = 100
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sampleAfter = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .spherize)
        #expect(filterLayer.filterSettings.normalized().spherizeAmountPercent == 100)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleAfter.redComponent < sampleBefore.redComponent - 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartSampleBefore = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        smartViewModel.selectedFilter = .spherize
        smartViewModel.filterIntensity = 0
        smartViewModel.filterSpherizeAmountPercent = -100
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .spherize)
        #expect(smartFilter.normalizedSettings.spherizeAmountPercent == -100)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleAfter.redComponent > smartSampleBefore.redComponent + 0.03)
        #expect(smartViewModel.smartFilterLabel(smartFilter) == L10n.format("imageEditor.properties.smartFilterSpherizeItem", smartFilter.kind.title, "-100"))
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .spherize)
        #expect(restoredFilter.normalizedSettings.spherizeAmountPercent == -100)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-spherize-amount"))
        #expect(viewSource.contains("viewModel.selectedFilter != .spherize"))
    }

    @Test func imageEditorLensCorrectionAmountSupportsLegacyAndSignedRadialDistortion() async throws {
        let canvasSize = NSSize(width: 48, height: 48)
        let sourceImage = radialRampImage(size: canvasSize)
        let samplePoint = CGPoint(x: 34, y: 24)
        let legacySettings = try JSONDecoder().decode(
            ImageEditorFilterSettings.self,
            from: Data("{}".utf8)
        )
        #expect(legacySettings.lensDistortionAmountPercent == nil)
        #expect(legacySettings.lensDistortion == 0.35)
        let legacyCorrection = try #require(sourceImage.filtered(
            kind: .lensCorrection,
            intensity: 1,
            settings: legacySettings
        ))
        let explicitLegacyCorrection = try #require(sourceImage.filtered(
            kind: .lensCorrection,
            intensity: 0,
            settings: ImageEditorFilterSettings(lensDistortionAmountPercent: 35)
        ))
        #expect(legacyCorrection.qingtuPNGData() == explicitLegacyCorrection.qingtuPNGData())
        #expect(ImageEditorFilterSettings(lensDistortionAmountPercent: -200).normalized().lensDistortionAmountPercent == -100)
        #expect(ImageEditorFilterSettings(lensDistortionAmountPercent: 200).normalized().lensDistortionAmountPercent == 100)
        let zeroCorrection = try #require(sourceImage.filtered(
            kind: .lensCorrection,
            intensity: 1,
            settings: ImageEditorFilterSettings(lensDistortionAmountPercent: 0)
        ))
        #expect(zeroCorrection.qingtuPNGData() == sourceImage.qingtuPNGData())

        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let baseLayerID = try #require(viewModel.document.selectedLayerID)
        let basePixelsBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let sampleBefore = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))

        viewModel.selectedFilter = .lensCorrection
        viewModel.filterIntensity = 0
        viewModel.filterLensDistortionAmountPercent = 100
        viewModel.addFilterLayer()

        let filterLayer = try #require(viewModel.document.selectedLayer)
        let sampleAfter = try #require(viewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(filterLayer.isFilter)
        #expect(filterLayer.filter?.kind == .lensCorrection)
        #expect(filterLayer.filterSettings.normalized().lensDistortionAmountPercent == 100)
        #expect(viewModel.document.layers.first { $0.id == baseLayerID }?.image.qingtuPNGData() == basePixelsBefore)
        #expect(sampleAfter.redComponent > sampleBefore.redComponent + 0.02)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterNew"))

        let smartViewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        smartViewModel.replaceSelectedLayerImageForTesting(sourceImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let smartBasePixelsBefore = try #require(smartViewModel.document.selectedLayer?.image.qingtuPNGData())
        let smartSampleBefore = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        smartViewModel.selectedFilter = .lensCorrection
        smartViewModel.filterIntensity = 0
        smartViewModel.filterLensDistortionAmountPercent = -100
        smartViewModel.addSmartFilterToSelectedLayer()

        let smartLayer = try #require(smartViewModel.document.selectedLayer)
        let smartFilter = try #require(smartLayer.smartFilters.first)
        let smartSampleAfter = try #require(smartViewModel.currentImage.color(at: samplePoint)?.usingColorSpace(.deviceRGB))
        #expect(smartFilter.kind == .lensCorrection)
        #expect(smartFilter.normalizedSettings.lensDistortionAmountPercent == -100)
        #expect(smartLayer.image.qingtuPNGData() == smartBasePixelsBefore)
        #expect(smartSampleAfter.redComponent < smartSampleBefore.redComponent - 0.02)
        #expect(
            smartViewModel.smartFilterLabel(smartFilter)
                == L10n.format("imageEditor.properties.smartFilterLensCorrectionItem", smartFilter.kind.title, "-100")
        )
        #expect(smartViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterAdd"))

        let project = try ImageEditorProjectDocument(document: smartViewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == smartLayer.id })
        let restoredFilter = try #require(restoredLayer.smartFilters.first)
        #expect(restoredFilter.kind == .lensCorrection)
        #expect(restoredFilter.normalizedSettings.lensDistortionAmountPercent == -100)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        #expect(viewSource.contains("image-editor-filter-lens-distortion-amount"))
        #expect(viewSource.contains("viewModel.selectedFilter != .lensCorrection"))
    }

    @Test func updatingFigmaBackdropBlurToContentSmartFilterReentersPixelPipeline() throws {
        let canvasSize = NSSize(width: 64, height: 40)
        let sourceImage = gradientImage(size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: sourceImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            solidImage(size: canvasSize, color: NSColor.white.withAlphaComponent(0.2)),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerID = try #require(viewModel.document.selectedLayerID)
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        let basePixels = try #require(viewModel.document.layers[layerIndex].image.qingtuPNGData())

        var backdropBlur = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 0.8,
            settings: ImageEditorFilterSettings(gaussianBlurRadius: 8)
        )
        backdropBlur.appliesToBackdrop = true
        viewModel.document.layers[layerIndex].smartFilters = [backdropBlur]
        let backdropPreview = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 1
        viewModel.updateSmartFilterOnSelectedLayer(backdropBlur.id)

        let updatedLayer = try #require(layer(layerID, in: viewModel))
        let updatedFilter = try #require(updatedLayer.smartFilters.first)
        let pixelatedPreview = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(updatedFilter.kind == .pixelate)
        #expect(updatedFilter.appliesToBackdrop == false)
        #expect(updatedLayer.image.qingtuPNGData() == basePixels)
        #expect(pixelatedPreview != backdropPreview)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartFilterUpdate"))

        viewModel.undo()

        let restoredFilter = try #require(layer(layerID, in: viewModel)?.smartFilters.first)
        #expect(restoredFilter.kind == .gaussianBlur)
        #expect(restoredFilter.appliesToBackdrop == true)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == backdropPreview)
    }

    @Test func batchSmartFilterUpdatePreservesBackdropRoutingOnlyForGaussianBlur() throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: gradientImage(size: canvasSize)
        ) { _ in }
        let backdropLayerID = try #require(viewModel.document.selectedLayerID)
        let backdropIndex = try #require(viewModel.document.layers.firstIndex { $0.id == backdropLayerID })
        var backdropBlur = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.4)
        backdropBlur.appliesToBackdrop = true
        viewModel.document.layers[backdropIndex].smartFilters = [backdropBlur]

        viewModel.addLayer()
        let contentLayerID = try #require(viewModel.document.selectedLayerID)
        let contentIndex = try #require(viewModel.document.layers.firstIndex { $0.id == contentLayerID })
        viewModel.document.layers[contentIndex].smartFilters = [
            ImageEditorSmartFilter(kind: .sharpen, intensity: 0.3)
        ]
        viewModel.selectLayer(backdropLayerID)
        viewModel.selectLayer(contentLayerID, extendingSelection: true)

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.65
        viewModel.updateLastSmartFilterOnSelectedLayer()

        #expect(try #require(layer(backdropLayerID, in: viewModel)?.smartFilters.last).appliesToBackdrop == true)
        #expect(try #require(layer(contentLayerID, in: viewModel)?.smartFilters.last).appliesToBackdrop == false)

        viewModel.selectedFilter = .pixelate
        viewModel.filterIntensity = 0.9
        viewModel.updateLastSmartFilterOnSelectedLayer()

        let updatedBackdrop = try #require(layer(backdropLayerID, in: viewModel)?.smartFilters.last)
        let updatedContent = try #require(layer(contentLayerID, in: viewModel)?.smartFilters.last)
        #expect(updatedBackdrop.kind == .pixelate)
        #expect(updatedBackdrop.appliesToBackdrop == false)
        #expect(updatedContent.kind == .pixelate)
        #expect(updatedContent.appliesToBackdrop == false)

        viewModel.undo()

        #expect(try #require(layer(backdropLayerID, in: viewModel)?.smartFilters.last).appliesToBackdrop == true)
        #expect(try #require(layer(contentLayerID, in: viewModel)?.smartFilters.last).appliesToBackdrop == false)
    }

    @Test func imageEditorBatchUpdatesSelectedFilterLayersAndSkipsLockedOrIneligibleLayers() async throws {
        let canvasSize = NSSize(width: 48, height: 32)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(size: canvasSize, color: .systemBlue)
        ) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.20
        viewModel.addFilterLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.30
        viewModel.addFilterLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)

        viewModel.selectedFilter = .gaussianBlur
        viewModel.filterIntensity = 0.40
        viewModel.addFilterLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        viewModel.toggleLayerLock(lockedID)

        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        viewModel.selectLayer(lockedID, extendingSelection: true)
        viewModel.selectLayer(baseLayerID, extendingSelection: true)

        viewModel.selectedFilter = .unsharpMask
        viewModel.filterIntensity = 0.75
        viewModel.filterUnsharpRadius = 2.5
        viewModel.filterUnsharpThreshold = 0.30
        viewModel.updateSelectedFilterLayer()

        let first = try #require(layer(firstID, in: viewModel))
        let second = try #require(layer(secondID, in: viewModel))
        let locked = try #require(layer(lockedID, in: viewModel))
        let base = try #require(layer(baseLayerID, in: viewModel))

        #expect(first.filter?.kind == .unsharpMask)
        #expect(first.filter?.intensity == 0.75)
        #expect(first.filterSettings.normalized().unsharpRadius == 2.5)
        #expect(first.filterSettings.normalized().unsharpThreshold == 0.30)
        #expect(second.filter?.kind == .unsharpMask)
        #expect(second.filterSettings.normalized().unsharpRadius == 2.5)
        #expect(locked.filter?.kind == .gaussianBlur)
        #expect(locked.filter?.intensity == 0.40)
        #expect(!base.isFilter)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFilterUpdateSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerFilterUpdatedSelected", 2))

        viewModel.undo()

        #expect(try #require(layer(firstID, in: viewModel)).filter?.kind == .gaussianBlur)
        #expect(try #require(layer(firstID, in: viewModel)).filter?.intensity == 0.20)
        #expect(try #require(layer(secondID, in: viewModel)).filter?.kind == .gaussianBlur)
        #expect(try #require(layer(secondID, in: viewModel)).filter?.intensity == 0.30)
        #expect(try #require(layer(lockedID, in: viewModel)).filter?.intensity == 0.40)
    }

    private func solidImage(size: NSSize, color: NSColor) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }

    private func layer(_ id: UUID, in viewModel: ImageEditorViewModel) -> ImageEditorLayer? {
        viewModel.document.layers.first { $0.id == id }
    }

    private func splitColorImage(size: NSSize, left: NSColor, right: NSColor) -> NSImage {
        NSImage.rendered(size: size) { rect in
            left.setFill()
            CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
            right.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func quadrantImage(
        size: NSSize,
        topLeft: NSColor,
        topRight: NSColor,
        bottomLeft: NSColor,
        bottomRight: NSColor
    ) -> NSImage {
        NSImage.rendered(size: size) { rect in
            let halfWidth = rect.width / 2
            let halfHeight = rect.height / 2
            topLeft.setFill()
            CGRect(x: rect.minX, y: rect.minY, width: halfWidth, height: halfHeight).fill()
            topRight.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: halfWidth, height: halfHeight).fill()
            bottomLeft.setFill()
            CGRect(x: rect.minX, y: rect.midY, width: halfWidth, height: halfHeight).fill()
            bottomRight.setFill()
            CGRect(x: rect.midX, y: rect.midY, width: halfWidth, height: halfHeight).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func radialRampImage(size: NSSize) -> NSImage {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let centerX = Double(max(width - 1, 1)) / 2
        let centerY = Double(max(height - 1, 1)) / 2
        let maxDistance = max(1, min(Double(width), Double(height)) / 2)
        var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let distance = min(1, hypot(Double(x) - centerX, Double(y) - centerY) / maxDistance)
                let value = UInt8((0.12 + distance * 0.82) * 255)
                pixels[offset] = value
                pixels[offset + 1] = value
                pixels[offset + 2] = value
                pixels[offset + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else {
            return NSImage.transparent(size: size)
        }

        return NSImage(cgImage: cgImage, size: size)
    }

    private func binarySpotImage(size: NSSize, background: NSColor, spot: NSColor, spotSize: CGFloat) -> NSImage {
        NSImage.rendered(size: size) { rect in
            background.setFill()
            rect.fill()
            spot.setFill()
            let integralSpotSize = max(1, Int(spotSize.rounded()))
            let originX = Int(rect.midX.rounded()) - integralSpotSize / 2
            let originY = Int(rect.midY.rounded()) - integralSpotSize / 2
            CGRect(
                x: originX,
                y: originY,
                width: integralSpotSize,
                height: integralSpotSize
            ).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func colorSpotImage(size: NSSize, background: NSColor, spot: NSColor, spotSize: CGFloat) -> NSImage {
        NSImage.rendered(size: size) { rect in
            background.setFill()
            rect.fill()
            spot.setFill()
            CGRect(
                x: rect.midX - spotSize / 2,
                y: rect.midY - spotSize / 2,
                width: spotSize,
                height: spotSize
            ).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func saltAndPepperImage(size: NSSize) -> NSImage {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 128, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                pixels[offset] = 128
                pixels[offset + 1] = 128
                pixels[offset + 2] = 128
                pixels[offset + 3] = 255
            }
        }

        let centerY = height / 2
        let whiteOffset = centerY * bytesPerRow + (width / 2) * bytesPerPixel
        pixels[whiteOffset] = 255
        pixels[whiteOffset + 1] = 255
        pixels[whiteOffset + 2] = 255
        let blackOffset = centerY * bytesPerRow + (width / 2 + 1) * bytesPerPixel
        pixels[blackOffset] = 0
        pixels[blackOffset + 1] = 0
        pixels[blackOffset + 2] = 0

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else {
            return NSImage.transparent(size: size)
        }

        return NSImage(cgImage: cgImage, size: size)
    }

    private func verticalEdgeImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.black.setFill()
            rect.fill()
            NSColor.white.setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func softEdgeImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor(calibratedWhite: 0.4, alpha: 1).setFill()
            rect.fill()
            NSColor(calibratedWhite: 0.6, alpha: 1).setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func gradientImage(size: NSSize) -> NSImage {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let red = UInt8((Double(x) / Double(max(width - 1, 1)) * 255).rounded())
                let green = UInt8((Double(y) / Double(max(height - 1, 1)) * 255).rounded())
                pixels[offset] = red
                pixels[offset + 1] = green
                pixels[offset + 2] = 120
                pixels[offset + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else {
            return NSImage.transparent(size: size)
        }

        return NSImage(cgImage: cgImage, size: size)
    }
}
