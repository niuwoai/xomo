import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSelectionFillCoverageTests {
    @Test func fillOnlyCommitsLayersCoveredBySelection() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "fill-coverage.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[firstIndex].frame = CGRect(x: 0, y: 0, width: 40, height: 40)

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[secondIndex].frame = CGRect(x: 70, y: 50, width: 40, height: 30)
        viewModel.document.selectedLayerID = firstID
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        viewModel.createRectSelection(from: CGPoint(x: 8, y: 8), to: CGPoint(x: 28, y: 28))
        viewModel.foregroundColor = .systemRed
        viewModel.opacity = 1
        let resolvedFirstIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == firstID }
        )
        let resolvedSecondIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == secondID }
        )
        let firstBefore = try #require(
            viewModel.document.layers[resolvedFirstIndex].image.qingtuPNGData()
        )
        let secondBefore = try #require(
            viewModel.document.layers[resolvedSecondIndex].image.qingtuPNGData()
        )

        viewModel.fillSelection()

        let firstAfter = try #require(
            viewModel.document.layers[resolvedFirstIndex].image.qingtuPNGData()
        )
        let secondAfter = try #require(
            viewModel.document.layers[resolvedSecondIndex].image.qingtuPNGData()
        )
        #expect(firstAfter != firstBefore)
        #expect(secondAfter == secondBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFill"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionFilled"))
    }

    @Test func fillOutsideEveryEditableLayerDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "empty-fill.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 70, y: 55, width: 40, height: 25)
        viewModel.createRectSelection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 30, y: 25))
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.fillSelection()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func strokeOnlyCommitsLayersReachedByItsOuterEdge() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "stroke-coverage.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        viewModel.addLayer()
        let reachedID = try #require(viewModel.document.selectedLayerID)
        let reachedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[reachedIndex].frame = CGRect(x: 30, y: 10, width: 30, height: 30)

        viewModel.addLayer()
        let untouchedID = try #require(viewModel.document.selectedLayerID)
        let untouchedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[untouchedIndex].frame = CGRect(x: 75, y: 55, width: 30, height: 25)
        viewModel.document.selectedLayerID = reachedID
        viewModel.document.selectedLayerIDs = [reachedID, untouchedID]
        viewModel.createRectSelection(from: CGPoint(x: 10, y: 15), to: CGPoint(x: 28, y: 35))
        viewModel.brushSize = 6
        viewModel.foregroundColor = .systemBlue
        viewModel.opacity = 1
        let resolvedReachedIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == reachedID }
        )
        let resolvedUntouchedIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == untouchedID }
        )
        let reachedBefore = try #require(
            viewModel.document.layers[resolvedReachedIndex].image.qingtuPNGData()
        )
        let untouchedBefore = try #require(
            viewModel.document.layers[resolvedUntouchedIndex].image.qingtuPNGData()
        )

        viewModel.strokeSelection()

        let reachedAfter = try #require(
            viewModel.document.layers[resolvedReachedIndex].image.qingtuPNGData()
        )
        let untouchedAfter = try #require(
            viewModel.document.layers[resolvedUntouchedIndex].image.qingtuPNGData()
        )
        #expect(reachedAfter != reachedBefore)
        #expect(untouchedAfter == untouchedBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionStroke"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionStroked"))
    }

    @Test func strokeOutsideEveryEditableLayerDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "empty-stroke.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 75, y: 55, width: 35, height: 25)
        viewModel.createRectSelection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 25, y: 25))
        viewModel.brushSize = 8
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.strokeSelection()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func clearOutsideEveryEditableLayerDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "empty-clear.png",
            image: .transparent(size: CGSize(width: 36, height: 24))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 70, y: 50, width: 36, height: 24)
        viewModel.createRectSelection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 25, y: 25))
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.clearSelectionPixels()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func contentAwareFillOutsideEveryEditableLayerDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "empty-content-aware.png",
            image: .transparent(size: CGSize(width: 32, height: 28))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 72, y: 52, width: 32, height: 28)
        viewModel.createRectSelection(from: CGPoint(x: 4, y: 4), to: CGPoint(x: 24, y: 24))
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.contentAwareFillSelection()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func clearingAlreadyTransparentPixelsDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "transparent-clear.png",
            image: .transparent(size: CGSize(width: 40, height: 30))
        ) { _ in }
        viewModel.selectAll()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.clearSelectionPixels()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func zeroOpacityFillDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "zero-opacity-fill.png",
            image: .transparent(size: CGSize(width: 40, height: 30))
        ) { _ in }
        viewModel.selectAll()
        viewModel.foregroundColor = .systemPink
        viewModel.opacity = 0
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.fillSelection()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func copyingTransparentSelectionDoesNotCreateBlankLayer() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "transparent-copy.png",
            image: .transparent(size: CGSize(width: 48, height: 32))
        ) { _ in }
        viewModel.createRectSelection(from: CGPoint(x: 6, y: 5), to: CGPoint(x: 30, y: 24))
        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.copySelectionToNewLayer()

        #expect(viewModel.document.layers.count == layerCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func cuttingTransparentSelectionDoesNotCreateBlankLayer() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "transparent-cut.png",
            image: .transparent(size: CGSize(width: 48, height: 32))
        ) { _ in }
        viewModel.createRectSelection(from: CGPoint(x: 6, y: 5), to: CGPoint(x: 30, y: 24))
        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.cutSelectionToNewLayer()

        #expect(viewModel.document.layers.count == layerCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func copyingTransparentMergedSelectionDoesNotCreateBlankLayer() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "transparent-merged-copy.png",
            image: .transparent(size: CGSize(width: 48, height: 32))
        ) { _ in }
        viewModel.createRectSelection(from: CGPoint(x: 6, y: 5), to: CGPoint(x: 30, y: 24))
        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.copyMergedToNewLayer()

        #expect(viewModel.document.layers.count == layerCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func copyingSelectionPreservesBlendIfThresholds() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "blend-if-copy.png",
            image: NSImage(size: CGSize(width: 48, height: 32), flipped: false) { rect in
                NSColor.systemPink.setFill()
                rect.fill()
                return true
            }
        ) { _ in }
        let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[sourceIndex].blendIfSourceBlack = 0.18
        viewModel.document.layers[sourceIndex].blendIfSourceWhite = 0.82
        viewModel.document.layers[sourceIndex].blendIfUnderlyingBlack = 0.27
        viewModel.document.layers[sourceIndex].blendIfUnderlyingWhite = 0.73
        viewModel.selectAll()

        viewModel.copySelectionToNewLayer()

        let copiedLayer = try #require(viewModel.document.selectedLayer)
        #expect(copiedLayer.blendIfSourceBlack == 0.18)
        #expect(copiedLayer.blendIfSourceWhite == 0.82)
        #expect(copiedLayer.blendIfUnderlyingBlack == 0.27)
        #expect(copiedLayer.blendIfUnderlyingWhite == 0.73)
    }

    @Test func cuttingSelectionPreservesBlendIfThresholds() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "blend-if-cut.png",
            image: NSImage(size: CGSize(width: 48, height: 32), flipped: false) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
                return true
            }
        ) { _ in }
        let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[sourceIndex].blendIfSourceBlack = 0.14
        viewModel.document.layers[sourceIndex].blendIfSourceWhite = 0.86
        viewModel.document.layers[sourceIndex].blendIfUnderlyingBlack = 0.31
        viewModel.document.layers[sourceIndex].blendIfUnderlyingWhite = 0.69
        viewModel.selectAll()

        viewModel.cutSelectionToNewLayer()

        let cutLayer = try #require(viewModel.document.selectedLayer)
        #expect(cutLayer.blendIfSourceBlack == 0.14)
        #expect(cutLayer.blendIfSourceWhite == 0.86)
        #expect(cutLayer.blendIfUnderlyingBlack == 0.31)
        #expect(cutLayer.blendIfUnderlyingWhite == 0.69)
    }

    @Test func copyingSelectionPreservesClippingMaskAppearance() throws {
        let viewModel = clippingMaskViewModel(sourceName: "clipping-copy.png")
        let before = viewModel.document.compositedImage

        viewModel.copySelectionToNewLayer()

        let copiedLayer = try #require(viewModel.document.selectedLayer)
        #expect(copiedLayer.isClippingMask)
        #expect(imageEditorMaximumPixelDifference(viewModel.document.compositedImage, before) <= 1)
    }

    @Test func cuttingSelectionPreservesClippingMaskAppearance() throws {
        let viewModel = clippingMaskViewModel(sourceName: "clipping-cut.png")
        let before = viewModel.document.compositedImage

        viewModel.cutSelectionToNewLayer()

        let cutLayer = try #require(viewModel.document.selectedLayer)
        #expect(cutLayer.isClippingMask)
        #expect(imageEditorMaximumPixelDifference(viewModel.document.compositedImage, before) <= 1)
    }

    @Test func copyingSelectionPreservesLayerStyle() throws {
        let viewModel = styledLayerViewModel(sourceName: "styled-copy.png")

        viewModel.copySelectionToNewLayer()

        let copiedLayer = try #require(viewModel.document.selectedLayer)
        #expect(copiedLayer.style.strokeEnabled)
        #expect(copiedLayer.style.strokeWidth == 4)
        #expect(copiedLayer.style.shadowEnabled)
        #expect(copiedLayer.style.shadowOpacity == 0.6)
    }

    @Test func cuttingSelectionPreservesLayerStyleAppearance() throws {
        let viewModel = styledLayerViewModel(sourceName: "styled-cut.png")
        let before = viewModel.document.compositedImage

        viewModel.cutSelectionToNewLayer()

        let cutLayer = try #require(viewModel.document.selectedLayer)
        #expect(cutLayer.style.strokeEnabled)
        #expect(cutLayer.style.shadowEnabled)
        #expect(imageEditorMaximumPixelDifference(viewModel.document.compositedImage, before) <= 1)
    }

    @Test func copyingSelectionReadsLockedLayersWithoutEnablingCut() throws {
        for useFullLock in [false, true] {
            let size = CGSize(width: 48, height: 32)
            let image = NSImage(size: size, flipped: false) { rect in
                NSColor.systemPink.setFill()
                rect.fill()
                return true
            }
            let viewModel = ImageEditorViewModel(
                sourceName: useFullLock ? "fully-locked-copy.png" : "pixel-locked-copy.png",
                image: image
            ) { _ in }
            viewModel.replaceSelectedLayerImageForTesting(
                image,
                historyTitle: L10n.text("imageEditor.history.brush")
            )
            let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
            if useFullLock {
                viewModel.document.layers[sourceIndex].isLocked = true
            } else {
                viewModel.document.layers[sourceIndex].isLocked = false
                viewModel.document.layers[sourceIndex].locksPixels = true
            }
            let sourceID = viewModel.document.layers[sourceIndex].id
            let sourceData = try #require(viewModel.document.layers[sourceIndex].image.qingtuPNGData())
            let layerCountBeforeCopy = viewModel.document.layers.count
            viewModel.selectAll()

            #expect(viewModel.canCopySelectionToNewLayer)
            #expect(viewModel.canCopySelectionToClipboard)
            #expect(!viewModel.canCutSelectionToNewLayer)
            #expect(!viewModel.canCutSelectionToClipboard)

            viewModel.copySelectionToNewLayer()

            #expect(viewModel.document.layers.count == layerCountBeforeCopy + 1)
            #expect(viewModel.document.selectedLayerID != sourceID)
            let unchangedSource = try #require(viewModel.document.layers.first { $0.id == sourceID })
            #expect(unchangedSource.image.qingtuPNGData() == sourceData)
        }
    }

    @Test func copyingSelectionPreservesHiddenLayerVisibility() throws {
        let viewModel = hiddenLayerViewModel(sourceName: "hidden-copy.png")
        let before = viewModel.document.compositedImage

        viewModel.copySelectionToNewLayer()

        let copiedLayer = try #require(viewModel.document.selectedLayer)
        #expect(!copiedLayer.isVisible)
        #expect(copiedLayer.image.nonTransparentPixelBounds() != nil)
        #expect(imageEditorMaximumPixelDifference(viewModel.document.compositedImage, before) <= 1)
    }

    @Test func cuttingSelectionPreservesHiddenLayerVisibility() throws {
        let viewModel = hiddenLayerViewModel(sourceName: "hidden-cut.png")
        let before = viewModel.document.compositedImage

        viewModel.cutSelectionToNewLayer()

        let cutLayer = try #require(viewModel.document.selectedLayer)
        #expect(!cutLayer.isVisible)
        #expect(cutLayer.image.nonTransparentPixelBounds() != nil)
        #expect(imageEditorMaximumPixelDifference(viewModel.document.compositedImage, before) <= 1)
    }

    private func clippingMaskViewModel(sourceName: String) -> ImageEditorViewModel {
        let size = CGSize(width: 48, height: 32)
        let baseImage = NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            NSColor.systemPink.setFill()
            CGRect(x: 0, y: 0, width: rect.width / 2, height: rect.height).fill()
            return true
        }
        let sourceImage = NSImage(size: size, flipped: false) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: sourceName, image: baseImage) { _ in }
        viewModel.addLayer()
        viewModel.replaceSelectedLayerImageForTesting(
            sourceImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        if let sourceIndex = viewModel.document.selectedLayerIndex {
            viewModel.document.layers[sourceIndex].isClippingMask = true
        }
        viewModel.selectAll()
        return viewModel
    }

    private func styledLayerViewModel(sourceName: String) -> ImageEditorViewModel {
        let size = CGSize(width: 48, height: 32)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            NSColor.systemBlue.setFill()
            CGRect(x: 8, y: 7, width: 24, height: 16).fill()
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: sourceName, image: image) { _ in }
        if let sourceIndex = viewModel.document.selectedLayerIndex {
            viewModel.document.layers[sourceIndex].style.strokeEnabled = true
            viewModel.document.layers[sourceIndex].style.strokeWidth = 4
            viewModel.document.layers[sourceIndex].style.strokeColor = .white
            viewModel.document.layers[sourceIndex].style.shadowEnabled = true
            viewModel.document.layers[sourceIndex].style.shadowOpacity = 0.6
            viewModel.document.layers[sourceIndex].style.shadowBlur = 3
            viewModel.document.layers[sourceIndex].style.shadowOffset = CGSize(width: 2, height: -2)
        }
        viewModel.selectAll()
        return viewModel
    }

    private func hiddenLayerViewModel(sourceName: String) -> ImageEditorViewModel {
        let size = CGSize(width: 48, height: 32)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            return true
        }
        let viewModel = ImageEditorViewModel(
            sourceName: sourceName,
            image: .transparent(size: size)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            image,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        if let sourceIndex = viewModel.document.selectedLayerIndex {
            viewModel.document.layers[sourceIndex].isVisible = false
        }
        viewModel.selectAll()
        return viewModel
    }
}
