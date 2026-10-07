import AppKit
import Testing
@testable import musepic

enum FilteredCutMaskVariation: CaseIterable {
    case reducedDensity
    case feathered
    case unlinked
}

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionCutSamplingTests {
    private let canvasSize = CGSize(width: 24, height: 20)
    private let selectedRect = CGRect(x: 8, y: 9, width: 1, height: 1)

    @Test(arguments: [false, true])
    func fineSelectionCutPreservesContentAndOnlyClearsSelectedCanvasPixel(raster: Bool) throws {
        let model = try fixture(raster: raster)
        let source = try #require(model.document.selectedLayer)
        let original = try model.projectData()
        let originalPixels = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20))
        let undoCount = model.undoStack.count
        #expect(model.canCutSelectionToNewLayer)

        model.cutSelectionToNewLayer()

        #expect(model.document.layers.count == 2)
        let cut = try #require(model.document.selectedLayer)
        #expect(cut.id != source.id)
        #expect(cut.frame == selectedRect)
        #expect(imageEditorRGBABytes(cut.image, width: 1, height: 1) == [255, 0, 0, 255])
        #expect(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20) == originalPixels)
        #expect(model.undoStack.count == undoCount + 1)

        var expectedSource = originalPixels
        let selectedOffset = (9 * 24 + 8) * 4
        expectedSource.replaceSubrange(selectedOffset..<(selectedOffset + 4), with: [0, 0, 0, 0])
        let clearedSource = model.document.compositedImage(includingOnly: [source.id])
        #expect(imageEditorRGBABytes(clearedSource, width: 24, height: 20) == expectedSource)

        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        #expect(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20) == originalPixels)
        let reopened = try fixture()
        try reopened.loadProjectData(model.projectData())
        #expect(imageEditorRGBABytes(reopened.document.compositedImage(includingOnly: [source.id]), width: 24, height: 20) == expectedSource)
        #expect(imageEditorRGBABytes(reopened.document.compositedImage, width: 24, height: 20) == originalPixels)
    }

    @Test(arguments: [false, true])
    func isolatedClipboardCutPasteAndProjectReloadPreserveExactPixels(raster: Bool) throws {
        let model = try fixture(raster: raster)
        let source = try #require(model.document.selectedLayer)
        let original = try model.projectData()
        let pixels = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20))
        let undoCount = model.undoStack.count
        let pasteboard = isolatedPasteboard()
        defer { pasteboard.clearContents() }

        #expect(model.cutSelectionToClipboard(to: pasteboard))
        #expect(model.document.layers.count == 1)
        #expect(model.document.selectedLayerID == source.id)
        #expect(model.undoStack.count == undoCount + 1)
        #expect(XomoClipboardLayerPayload.frame(from: pasteboard) == selectedRect)
        let copied = try #require(pasteboard.readImage())
        #expect(imageEditorRGBABytes(copied, width: 1, height: 1) == [255, 0, 0, 255])
        #expect(model.pasteClipboardInPlaceAsLayer(from: pasteboard))
        #expect(model.undoStack.count == undoCount + 2)
        #expect(model.document.selectedLayer?.frame == selectedRect)
        #expect(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20) == pixels)
        model.undo()
        #expect(model.document.layers.count == 1)
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        model.redo()
        let reopened = try fixture()
        try reopened.loadProjectData(model.projectData())
        #expect(imageEditorRGBABytes(reopened.document.compositedImage, width: 24, height: 20) == pixels)
    }

    @Test func softCoverageClearsOnlyItsComplementAndKeepsClipboardAlpha() throws {
        let model = try fixture(raster: true)
        var alpha = [UInt8](repeating: 0, count: 24 * 20)
        alpha[9 * 24 + 8] = 64
        alpha[9 * 24 + 9] = 192
        model.document.selection = .raster(mask: ImageEditorSelectionMask(width: 24, height: 20, alpha: alpha),
                                          bounds: CGRect(origin: .zero, size: canvasSize))
        let sourceID = try #require(model.document.selectedLayerID)
        let pasteboard = isolatedPasteboard()
        defer { pasteboard.clearContents() }
        #expect(model.cutSelectionToClipboard(to: pasteboard))
        let copied = try #require(pasteboard.readImage())
        #expect(imageEditorRGBABytes(copied, width: 2, height: 1) == [64, 0, 0, 64, 192, 0, 0, 192])
        let cleared = try #require(imageEditorRGBABytes(model.document.compositedImage(includingOnly: [sourceID]), width: 24, height: 20))
        #expect(Array(cleared[(9 * 24 + 8) * 4..<(9 * 24 + 9) * 4]) == [191, 0, 0, 191])
        #expect(Array(cleared[(9 * 24 + 9) * 4..<(9 * 24 + 10) * 4]) == [63, 0, 0, 63])
        #expect(Array(cleared[(9 * 24 + 10) * 4..<(9 * 24 + 11) * 4]) == [255, 0, 0, 255])
    }

    @Test(arguments: [true, false])
    func promotedBackingKeepsMasksInCanvasSpaceAndStyleLengths(linked: Bool) throws {
        let model = try fixture()
        var layer = try #require(model.document.selectedLayer)
        let mask = try #require(NSImage.rendered(size: CGSize(width: 12, height: 12)) { rect in
            NSColor.white.setFill()
            rect.fill()
        })
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 4, y: 0), CGPoint(x: 4, y: 4), CGPoint(x: 0, y: 4)]
        layer.mask = mask
        layer.vectorMask = ImageEditorShapeContent(kind: .path, fillColor: .white, fillOpacity: 1, strokeColor: .clear,
            strokeWidth: 1, strokeOpacity: 0, pathPoints: points,
            pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true)
        layer.isMaskLinked = linked
        layer.maskFeatherSamplingScale = 2
        layer.style.strokeWidth = 2
        layer.style.shadowBlur = 1
        layer.style.shadowOffset = CGSize(width: 1, height: -2)
        let promoted = try #require(layer.selectionPixelEditingBacking())
        #expect(promoted.id == layer.id)
        #expect(promoted.frame == layer.frame)
        #expect(promoted.image.size == CGSize(width: 12, height: 12))
        #expect(promoted.mask === mask)
        #expect(promoted.isMaskLinked == linked)
        #expect(promoted.maskFeatherSamplingScale == 2)
        #expect(promoted.vectorMask?.pathPoints == points.map { CGPoint(x: $0.x * 3, y: $0.y * 3) })
        #expect(promoted.style.strokeWidth == 6)
        #expect(promoted.style.shadowBlur == 3)
        #expect(promoted.style.shadowOffset == CGSize(width: 3, height: -6))
        #expect(imageEditorRGBABytes(promoted.visibleImage, width: 12, height: 12)
            == imageEditorRGBABytes(layer.visibleImage, width: 12, height: 12))
        model.document.layers[0] = layer
        let original = try model.projectData()
        model.cutSelectionToNewLayer()
        let cleared = try #require(model.document.layers.first { $0.id == layer.id })
        #expect(cleared.isMaskLinked == linked)
        #expect(cleared.mask === mask)
        #expect(cleared.vectorMask?.pathPoints == promoted.vectorMask?.pathPoints)
        let raw = try #require(imageEditorRGBABytes(cleared.image, width: 12, height: 12))
        #expect(Array(raw[(5 * 12 + 4) * 4..<(5 * 12 + 5) * 4]) == [0, 0, 0, 0])
        model.undo()
        #expect(try model.projectData() == original)
    }

    @Test func cutKeepsSmartBlurNonDestructiveAtItsPhysicalRadiusAndReloads() throws {
        let model = try fixture()
        let filter = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.5,
                                            settings: .init(gaussianBlurRadius: 2), opacity: 0.75)
        model.document.layers[0].smartFilters = [filter]
        let original = try model.projectData()
        let sourceID = try #require(model.document.selectedLayerID)
        model.cutSelectionToNewLayer()
        let source = try #require(model.document.layers.first { $0.id == sourceID })
        let retainedFilter = try #require(source.smartFilters.first)
        #expect(source.image.size == CGSize(width: 4, height: 4))
        #expect(retainedFilter.id == filter.id)
        #expect(retainedFilter.opacity == filter.opacity)
        #expect(retainedFilter.intensity == filter.intensity)
        #expect(retainedFilter.settings == filter.settings)
        #expect(retainedFilter.pixelSamplingScale == filter.pixelSamplingScale)
        let reference = try #require(source.image.applyingFilter(kind: .gaussianBlur, intensity: 0.5,
                                        settings: .init(gaussianBlurRadius: 2), mask: nil, opacity: 0.75))
        #expect(imageEditorRGBABytes(source.contentImage, width: 4, height: 4)
            == imageEditorRGBABytes(reference, width: 4, height: 4))
        let reopened = try fixture()
        try reopened.loadProjectData(model.projectData())
        let restored = try #require(reopened.document.layers.first { $0.id == sourceID })
        #expect(restored.smartFilters == source.smartFilters)
        #expect(imageEditorRGBABytes(restored.contentImage, width: 4, height: 4)
            == imageEditorRGBABytes(reference, width: 4, height: 4))
        model.selectLayer(sourceID)
        #expect(model.loadSmartFilterIntoControls(retainedFilter.id))
        let undoCount = model.undoStack.count
        let historyCount = model.document.history.count
        #expect(!model.canDiscardLoadedSmartFilterControlChanges)
        #expect(model.updateLoadedSmartFilterOnSelectedLayer() == 0)
        #expect(model.undoStack.count == undoCount)
        #expect(model.document.history.count == historyCount)
        model.undo()
        #expect(try model.projectData() == original)
    }

    @Test(arguments: FilteredCutMaskVariation.allCases)
    func filteredClipboardCutPreservesExistingMaskAndSourceThroughUndoRedo(
        variation: FilteredCutMaskVariation
    ) throws {
        let model = try fixture()
        model.document.layers[0].mask = try #require(NSImage.rendered(size: CGSize(width: 4, height: 4)) { rect in
            NSColor.white.setFill()
            rect.fill()
            NSColor.black.setFill()
            CGRect(x: 2, y: 0, width: 2, height: 4).fill()
        })
        switch variation {
        case .reducedDensity:
            model.document.layers[0].maskDensity = 0.5
        case .feathered:
            model.document.layers[0].maskFeather = 1
        case .unlinked:
            model.document.layers[0].isMaskLinked = false
        }
        let filter = ImageEditorSmartFilter(
            kind: .gaussianBlur,
            intensity: 1,
            settings: .init(gaussianBlurRadius: 2)
        )
        model.document.layers[0].smartFilters = [filter]
        let source = try #require(model.document.selectedLayer)
        let sourceID = source.id
        let originalProject = try model.projectData()
        let originalComposite = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20))
        var cutComposite = originalComposite
        let selectedOffset = (Int(selectedRect.minY) * 24 + Int(selectedRect.minX)) * 4
        cutComposite.replaceSubrange(selectedOffset..<(selectedOffset + 4), with: [0, 0, 0, 0])
        let expectedPasteboard = isolatedPasteboard()
        defer { expectedPasteboard.clearContents() }
        #expect(model.copySelectionToClipboard(to: expectedPasteboard))
        let expectedClipboardImage = try #require(expectedPasteboard.readImage())
        let expectedClipboardPixels = try #require(imageEditorRGBABytes(expectedClipboardImage, width: 1, height: 1))

        let pasteboard = isolatedPasteboard()
        defer { pasteboard.clearContents() }
        #expect(model.cutSelectionToClipboard(to: pasteboard))

        let sourceAfterCut = try #require(model.document.layers.first { $0.id == sourceID })
        #expect(sourceAfterCut.image.size == source.image.size)
        #expect(sourceAfterCut.smartFilters == [filter])
        #expect(sourceAfterCut.postFilterCutoutMask != nil)
        #expect(sourceAfterCut.mask?.qingtuPNGData() == source.mask?.qingtuPNGData())
        #expect(sourceAfterCut.maskDensity == source.maskDensity)
        #expect(sourceAfterCut.maskFeather == source.maskFeather)
        #expect(sourceAfterCut.isMaskLinked == source.isMaskLinked)
        #expect(try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20)) == cutComposite)
        #expect(XomoClipboardLayerPayload.frame(from: pasteboard) == selectedRect)
        let actualClipboardImage = try #require(pasteboard.readImage())
        let actualClipboardPixels = try #require(imageEditorRGBABytes(actualClipboardImage, width: 1, height: 1))
        #expect(actualClipboardPixels == expectedClipboardPixels)

        let firstCutProject = try model.projectData()
        let secondSelection = ImageEditorSelection.rectangle(CGRect(x: 10, y: 9, width: 1, height: 1))
        model.document.selection = secondSelection
        let beforeSecondCutProject = try model.projectData()
        var twiceCutComposite = cutComposite
        let secondSelectedOffset = (9 * 24 + 10) * 4
        twiceCutComposite.replaceSubrange(secondSelectedOffset..<(secondSelectedOffset + 4), with: [0, 0, 0, 0])
        let secondPasteboard = isolatedPasteboard()
        defer { secondPasteboard.clearContents() }
        #expect(model.cutSelectionToClipboard(to: secondPasteboard))
        let secondCutProject = try model.projectData()
        #expect(try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20)) == twiceCutComposite)

        model.undo()
        #expect(try model.projectData() == beforeSecondCutProject)
        #expect(try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20)) == cutComposite)
        model.undo()
        #expect(try model.projectData() == originalProject)
        model.redo()
        let firstRedoProject = try model.projectData()
        #expect(model.document.layers.first { $0.id == sourceID }?.postFilterCutoutMask != nil)
        #expect(try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20)) == cutComposite)
        model.redo()
        #expect(try model.projectData() == secondCutProject)
        #expect(try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20)) == twiceCutComposite)
        let reopened = try fixture()
        try reopened.loadProjectData(secondCutProject)
        #expect(try #require(imageEditorRGBABytes(reopened.document.compositedImage, width: 24, height: 20)) == twiceCutComposite)
        #expect(firstCutProject != firstRedoProject)
    }

    @Test(arguments: [false, true])
    func cuttingSelectionFromFilteredLayerPreservesCompositePixels(hasRasterMask: Bool) throws {
        let model = try fixture()
        if hasRasterMask {
            model.document.layers[0].mask = try #require(NSImage.rendered(size: CGSize(width: 4, height: 4)) { rect in
                NSColor.white.withAlphaComponent(0.5).setFill()
                rect.fill()
            })
        }
        model.document.layers[0].smartFilters = [
            ImageEditorSmartFilter(
                kind: .gaussianBlur,
                intensity: 1,
                settings: .init(gaussianBlurRadius: 2)
            )
        ]
        let originalProject = try model.projectData()
        let originalComposite = try #require(imageEditorRGBABytes(
            model.document.compositedImage,
            width: 24,
            height: 20
        ))

        model.cutSelectionToNewLayer()

        let cutComposite = try #require(imageEditorRGBABytes(
            model.document.compositedImage,
            width: 24,
            height: 20
        ))
        let differingBytes = zip(originalComposite, cutComposite).enumerated().compactMap { index, values in
            values.0 == values.1 ? nil : (index, values.0, values.1)
        }.prefix(12)
        #expect(differingBytes.isEmpty, "First differing RGBA bytes (offset, before, after): \(Array(differingBytes))")
        model.undo()
        #expect(try model.projectData() == originalProject)
        model.redo()
        #expect(try #require(imageEditorRGBABytes(
            model.document.compositedImage,
            width: 24,
            height: 20
        )) == originalComposite)
        let reopened = try fixture()
        try reopened.loadProjectData(model.projectData())
        #expect(try #require(imageEditorRGBABytes(
            reopened.document.compositedImage,
            width: 24,
            height: 20
        )) == originalComposite)
    }

    @Test(arguments: FilteredCutMaskVariation.allCases)
    func cuttingFilteredLayerWithComplexRasterMaskPreservesCompositeAndRoundTrips(
        variation: FilteredCutMaskVariation
    ) throws {
        let model = try fixture()
        model.document.layers[0].mask = try #require(NSImage.rendered(size: CGSize(width: 4, height: 4)) { rect in
            NSColor.white.setFill()
            rect.fill()
            if variation == .reducedDensity { NSColor.black.setFill() }
            if variation == .feathered {
                NSColor.black.setFill()
                CGRect(x: 2, y: 0, width: 2, height: 4).fill()
            }
        })
        switch variation {
        case .reducedDensity:
            model.document.layers[0].maskDensity = 0.5
        case .feathered:
            model.document.layers[0].maskFeather = 1
        case .unlinked:
            model.document.layers[0].isMaskLinked = false
        }
        model.document.layers[0].smartFilters = [
            ImageEditorSmartFilter(
                kind: .gaussianBlur,
                intensity: 1,
                settings: .init(gaussianBlurRadius: 2)
            )
        ]
        let originalComposite = try #require(imageEditorRGBABytes(
            model.document.compositedImage,
            width: 24,
            height: 20
        ))
        let originalProject = try model.projectData()
        let originalUndoCount = model.undoStack.count
        let originalLayerCount = model.document.layers.count
        let sourceID = try #require(model.document.selectedLayerID)

        model.cutSelectionToNewLayer()

        #expect(model.undoStack.count == originalUndoCount + 1)
        #expect(model.document.layers.count == originalLayerCount + 1)
        #expect(model.document.layers.first { $0.id == sourceID }?.maskDensity == (variation == .reducedDensity ? 0.5 : 1))
        #expect(try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20)) == originalComposite)
        let source = try #require(model.document.layers.first { $0.id == sourceID })
        #expect(source.postFilterCutoutMask != nil)
        #expect(source.isMaskLinked == (variation != .unlinked))
        model.undo()
        #expect(try model.projectData() == originalProject)
        model.redo()
        #expect(try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20)) == originalComposite)
        let reopened = try fixture()
        try reopened.loadProjectData(model.projectData())
        let restored = try #require(reopened.document.layers.first { $0.id == sourceID })
        #expect(restored.postFilterCutoutMask != nil)
        #expect(try #require(imageEditorRGBABytes(reopened.document.compositedImage, width: 24, height: 20)) == originalComposite)
    }

    @Test func filteredCutoutMaskSurvivesLayerCompAndPSDExport() throws {
        let model = try fixture()
        model.document.layers[0].smartFilters = [
            ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 1,
                                   settings: .init(gaussianBlurRadius: 2))
        ]
        let sourceID = try #require(model.document.selectedLayerID)
        let originalComposite = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20))
        model.cutSelectionToNewLayer()
        model.addLayerComp(named: "Cutout")
        let compID = try #require(model.document.selectedLayerCompID)
        let sourceIndex = try #require(model.document.layers.firstIndex { $0.id == sourceID })
        let savedCutout = try #require(model.document.layers[sourceIndex].postFilterCutoutMask)
        model.document.layers[sourceIndex].postFilterCutoutMask = nil
        model.document.layerComps.append(ImageEditorLayerComp.capture(name: "Other", document: model.document))
        model.document.selectedLayerCompID = model.document.layerComps.last?.id
        #expect(model.applyLayerComp(compID))
        let restoredCutout = try #require(model.document.layers[sourceIndex].postFilterCutoutMask)
        #expect(imageEditorRGBABytes(restoredCutout, width: Int(savedCutout.size.width), height: Int(savedCutout.size.height))
            == imageEditorRGBABytes(savedCutout, width: Int(savedCutout.size.width), height: Int(savedCutout.size.height)))
        #expect(try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20)) == originalComposite)

        let sourceComposite = try #require(imageEditorRGBABytes(
            model.document.compositedImage(includingOnly: [sourceID]), width: 24, height: 20
        ))
        let data = try ImageEditorPSDCodec.encode(document: model.document)
        let decoded = try ImageEditorPSDCodec.decode(data, sourceName: "cutout.psd")
        let decodedComposite = try #require(imageEditorRGBABytes(decoded.compositedImage, width: 24, height: 20))
        let originalAlpha = stride(from: 3, to: originalComposite.count, by: 4).map { originalComposite[$0] }
        let decodedAlpha = stride(from: 3, to: decodedComposite.count, by: 4).map { decodedComposite[$0] }
        #expect(decodedAlpha == originalAlpha)
        let decodedSourceID = try #require(decoded.layers.first { $0.name == "Cut source" }?.id)
        let decodedSource = try #require(imageEditorRGBABytes(
            decoded.compositedImage(includingOnly: [decodedSourceID]), width: 24, height: 20
        ))
        #expect(Array(stride(from: 3, to: decodedSource.count, by: 4).map { decodedSource[$0] })
            == Array(stride(from: 3, to: sourceComposite.count, by: 4).map { sourceComposite[$0] }))
    }

    @Test func postFilterCutoutContributesToAdjustmentAndClippingMasks() throws {
        let model = try fixture()
        let sourceID = try #require(model.document.selectedLayerID)
        model.document.layers[0].postFilterCutoutMask = NSImage.rendered(size: CGSize(width: 4, height: 4)) { rect in
            NSColor.clear.setFill()
            rect.fill()
            NSColor.white.setFill()
            CGRect(x: 2, y: 0, width: 2, height: 4).fill()
        }
        let adjustmentMask = try #require(model.document.localEffectMask(forLayerAt: 0))
        #expect(imageEditorRGBABytes(adjustmentMask, width: 4, height: 4)?.contains(0) == true)
        #expect(imageEditorRGBABytes(adjustmentMask, width: 4, height: 4)?.contains(255) == true)

        var clipping = ImageEditorLayer.blank(name: "Clip", size: CGSize(width: 4, height: 4))
        clipping.isClippingMask = true
        clipping.frame = model.document.layers[0].frame
        model.document.layers.append(clipping)
        let clipMask = try #require(model.document.clippingBaseCanvasMask(forLayerAt: 1))
        #expect(imageEditorRGBABytes(clipMask, width: 24, height: 20)?.contains(0) == true)
        #expect(imageEditorRGBABytes(clipMask, width: 24, height: 20)?.contains(255) == true)
        #expect(model.document.layers.first { $0.id == sourceID }?.postFilterCutoutMask != nil)
    }

    @Test func legacyProjectWithoutPostFilterCutoutKeyRestoresNil() throws {
        let model = try fixture()
        var projectObject = try #require(JSONSerialization.jsonObject(with: model.projectData()) as? [String: Any])
        projectObject["formatVersion"] = ImageEditorProjectDocument.formatVersion - 1
        var layers = try #require(projectObject["layers"] as? [[String: Any]])
        for index in layers.indices {
            layers[index].removeValue(forKey: "postFilterCutoutMaskData")
        }
        projectObject["layers"] = layers
        let legacyData = try JSONSerialization.data(withJSONObject: projectObject)

        let reopened = try fixture()
        try reopened.loadProjectData(legacyData)
        #expect(reopened.document.layers.allSatisfy { $0.postFilterCutoutMask == nil })
    }

    @Test func rasterizingFilteredCutoutLayerBakesPostFilterCutout() throws {
        let model = try fixture()
        model.document.layers[0].smartFilters = [
            ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 1,
                                   settings: .init(gaussianBlurRadius: 2))
        ]
        let sourceID = try #require(model.document.selectedLayerID)
        model.cutSelectionToNewLayer()
        model.selectLayer(sourceID)
        let before = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20))
        model.rasterizeSelectedLayers(.layer)
        let rasterized = try #require(model.document.layers.first { $0.id == sourceID })
        #expect(rasterized.postFilterCutoutMask == nil)
        #expect(rasterized.smartFilters.isEmpty)
        #expect(try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20)) == before)
    }

    @Test func filteredCutoutMaskFollowsLayerResizeAndRotation() throws {
        let model = try fixture()
        model.document.layers[0].smartFilters = [
            ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 1,
                                   settings: .init(gaussianBlurRadius: 2))
        ]
        let sourceID = try #require(model.document.selectedLayerID)
        model.cutSelectionToNewLayer()
        model.document.selectedLayerID = sourceID
        model.document.selectedLayerIDs = [sourceID]
        model.scaleSelectedLayer(by: 1.5)
        let resized = try #require(model.document.layers.first { $0.id == sourceID })
        #expect(resized.postFilterCutoutMask?.size == CGSize(width: 18, height: 18))
        model.document.selectedLayerID = sourceID
        model.document.selectedLayerIDs = [sourceID]
        #expect(model.rotateSelectedLayer(degrees: 90))
        let rotated = try #require(model.document.layers.first { $0.id == sourceID })
        #expect(rotated.postFilterCutoutMask?.size == rotated.image.size)
    }

    @Test func failedCutLeavesClipboardDocumentAndHistoryUntouched() throws {
        let model = try fixture()
        // The canvas copy fits the budget, but promoting this enormous frame does not.
        model.document.layers[0].frame = CGRect(x: 4, y: 4, width: 100_000, height: 100_000)
        let original = try model.projectData()
        let pasteboard = isolatedPasteboard()
        defer { pasteboard.clearContents() }
        #expect(pasteboard.setString("sentinel", forType: .string))
        #expect(!model.cutSelectionToClipboard(to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "sentinel")
        #expect(try model.projectData() == original)
        #expect(model.undoStack.isEmpty)
        model.cutSelectionToNewLayer()
        #expect(try model.projectData() == original)
        #expect(model.undoStack.isEmpty)
    }

    @Test(arguments: [ImageEditorFilter.gaussianBlur, .pixelate, .motionBlur, .highPass,
                      .minimum, .maximum, .oilPaint, .unsharpMask, .emboss, .offset, .liquifyPush])
    func backingPromotionRetainsFilterSettingsAndScalesRenderedPixelLengths(kind: ImageEditorFilter) throws {
        let model = try fixture()
        var layer = try #require(model.document.selectedLayer)
        layer.image = try #require(NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
            NSColor.green.setFill()
            CGRect(x: 1, y: 0, width: 2, height: 4).fill()
        })
        let settings = ImageEditorFilterSettings(gaussianBlurRadius: 2, highPassRadius: 2, highPassGainPercent: 100,
            morphologyRadius: 2, pixelateCellSize: 2, motionBlurDistance: 2, embossAngleDegrees: 0, embossHeight: 2,
            oilPaintRadius: 2, unsharpRadiusPixels: 2, liquifyPushXPixels: 1, liquifyPushYPixels: -1,
            offsetXPixels: 1, offsetYPixels: -1)
        let filter = ImageEditorSmartFilter(kind: kind, intensity: 0.5, settings: settings)
        layer.smartFilters = [filter]
        let backing = try #require(layer.selectionPixelEditingBacking())
        #expect(backing.smartFilters.first?.settings == settings)
        #expect(backing.smartFilters.first?.pixelSamplingScale == 3)
        var referenceSettings = settings
        referenceSettings.gaussianBlurRadius = 6
        referenceSettings.highPassRadius = 6
        referenceSettings.morphologyRadius = 6
        referenceSettings.pixelateCellSize = 6
        referenceSettings.motionBlurDistance = 6
        referenceSettings.embossHeight = 6
        referenceSettings.oilPaintRadius = 6
        referenceSettings.unsharpRadiusPixels = 6
        referenceSettings.liquifyPushXPixels = 3
        referenceSettings.liquifyPushYPixels = -3
        referenceSettings.offsetXPixels = 3
        referenceSettings.offsetYPixels = -3
        let reference = try #require(backing.image.applyingFilter(kind: kind, intensity: 0.5, settings: referenceSettings, mask: nil))
        #expect(imageEditorRGBABytes(backing.contentImage, width: 12, height: 12)
            == imageEditorRGBABytes(reference, width: 12, height: 12))
    }

    @Test func filterSamplingScaleRoundTripsWithoutChangingUserSettingsOrLegacyDefaults() throws {
        var filter = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.5,
                                            settings: .init(gaussianBlurRadius: 1_000))
        let legacy = try JSONDecoder().decode(ImageEditorSmartFilter.self, from: JSONEncoder().encode(filter))
        #expect(legacy.pixelSamplingScale == nil)
        #expect(legacy.renderingSettings.renderingScale == 1)
        filter.pixelSamplingScale = 3
        #expect(filter.normalizedSettings.gaussianBlurRadius == 1_000)
        #expect(filter.normalizedSettings.renderingScale == 1)
        #expect(filter.renderingSettings.renderingScale == 3)
        let restored = try JSONDecoder().decode(ImageEditorSmartFilter.self, from: JSONEncoder().encode(filter))
        #expect(restored == filter)
        #expect(restored.settings.renderingScale == 1)
        filter.appliesToBackdrop = true
        #expect(filter.renderingSettings.renderingScale == 1)
        filter.appliesToBackdrop = false
        filter.pixelSamplingScale = .nan
        #expect(filter.renderingSettings.renderingScale == 1)
        filter.pixelSamplingScale = -1
        #expect(filter.renderingSettings.renderingScale == 1)
    }

    @Test func featheredCutKeepsCoverageTailAndComplementarySourceAlpha() throws {
        let model = try fixture(raster: true)
        model.feather = 1
        let sourceID = try #require(model.document.selectedLayerID)
        let pasteboard = isolatedPasteboard()
        defer { pasteboard.clearContents() }
        #expect(model.cutSelectionToClipboard(to: pasteboard))
        let copied = try #require(pasteboard.readImage())
        #expect(XomoClipboardLayerPayload.frame(from: pasteboard) == selectedRect.insetBy(dx: -3, dy: -3))
        let selected = try #require(imageEditorRGBABytes(copied, width: 7, height: 7))
        let source = try #require(imageEditorRGBABytes(model.document.compositedImage(includingOnly: [sourceID]), width: 24, height: 20))
        #expect(selected[(3 * 7 + 2) * 4 + 3] > 0)
        for y in 0..<7 {
            for x in 0..<7 {
                let coverage = selected[(y * 7 + x) * 4 + 3]
                let expected = UInt8.max - coverage
                let offset = ((y + 6) * 24 + x + 5) * 4
                #expect(Array(source[offset..<(offset + 4)]) == [expected, 0, 0, expected])
            }
        }
    }

    private func isolatedPasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: .init("im.some.xomo.tests.selection-cut.\(UUID())"))
        pasteboard.clearContents()
        return pasteboard
    }

    private func fixture(raster: Bool = false) throws -> ImageEditorViewModel {
        let image = try #require(NSImage.rendered(size: CGSize(width: 4, height: 4)) { rect in
            NSColor.red.setFill()
            rect.fill()
            NSColor.blue.setFill()
            CGRect(x: 3, y: 0, width: 1, height: 4).fill()
        })
        var layer = ImageEditorLayer.blank(name: "Cut source", size: image.size)
        layer.image = image
        layer.frame = CGRect(x: 4, y: 4, width: 12, height: 12)
        let model = ImageEditorViewModel(sourceName: "cut-sampling.png", image: .transparent(size: canvasSize)) { _ in }
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        if raster {
            var alpha = [UInt8](repeating: 0, count: 24 * 20)
            alpha[9 * 24 + 8] = 255
            model.document.selection = .raster(
                mask: ImageEditorSelectionMask(width: 24, height: 20, alpha: alpha),
                bounds: CGRect(origin: .zero, size: canvasSize)
            )
        } else {
            model.document.selection = .rectangle(selectedRect)
        }
        return model
    }
}
