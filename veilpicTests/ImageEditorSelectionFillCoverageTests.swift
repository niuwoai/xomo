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

    @Test func copyingSelectionToNewLayerUsesSelectionSizeAndCanvasFrame() throws {
        let canvasSize = CGSize(width: 120, height: 90)
        let viewModel = ImageEditorViewModel(
            sourceName: "selection-layer-copy.png",
            image: .transparent(size: canvasSize)
        ) { _ in }
        let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
        let sourceFrame = CGRect(x: 18, y: 22, width: 40, height: 30)
        viewModel.document.layers[sourceIndex].image = NSImage(
            size: sourceFrame.size,
            flipped: false
        ) { rect in
            NSColor.systemOrange.setFill()
            rect.fill()
            return true
        }
        viewModel.document.layers[sourceIndex].frame = sourceFrame
        let sourceID = viewModel.document.layers[sourceIndex].id
        let selectionFrame = CGRect(x: 24, y: 27, width: 16, height: 12)
        viewModel.document.selection = .rectangle(selectionFrame)
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        viewModel.copySelectionToNewLayer()

        let copiedLayer = try #require(viewModel.document.selectedLayer)
        #expect(copiedLayer.id != sourceID)
        #expect(copiedLayer.image.size == selectionFrame.size)
        #expect(copiedLayer.frame == selectionFrame)
        let copiedCenter = try #require(
            copiedLayer.image.color(at: CGPoint(x: 8, y: 6))?.usingColorSpace(.deviceRGB)
        )
        #expect(copiedCenter.alphaComponent > 0.95)
        #expect(copiedCenter.redComponent > 0.8)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
    }

    @Test func copyingFeatheredSelectionRetainsFalloffOutsideHardBounds() throws {
        let canvasSize = CGSize(width: 120, height: 90)
        let viewModel = ImageEditorViewModel(
            sourceName: "feathered-selection-copy.png",
            image: .transparent(size: canvasSize)
        ) { _ in }
        let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[sourceIndex].image = NSImage(
            size: canvasSize,
            flipped: false
        ) { rect in
            NSColor.systemOrange.setFill()
            rect.fill()
            return true
        }
        viewModel.document.layers[sourceIndex].frame = CGRect(origin: .zero, size: canvasSize)
        let selectionFrame = CGRect(x: 40, y: 30, width: 20, height: 16)
        let feather: CGFloat = 4
        let featherExtent = feather * 3
        let expectedFrame = selectionFrame.insetBy(dx: -featherExtent, dy: -featherExtent)
        viewModel.document.selection = .rectangle(selectionFrame)
        viewModel.feather = feather

        viewModel.copySelectionToNewLayer()

        let copiedLayer = try #require(viewModel.document.selectedLayer)
        #expect(copiedLayer.frame == expectedFrame)
        #expect(copiedLayer.image.size == expectedFrame.size)
        let outsideFalloff = try #require(
            copiedLayer.image.color(
                at: CGPoint(x: featherExtent - 1, y: expectedFrame.height / 2)
            )?.usingColorSpace(.deviceRGB)
        )
        let center = try #require(
            copiedLayer.image.color(
                at: CGPoint(x: expectedFrame.width / 2, y: expectedFrame.height / 2)
            )?.usingColorSpace(.deviceRGB)
        )
        #expect(outsideFalloff.alphaComponent > 0.01)
        #expect(outsideFalloff.alphaComponent < center.alphaComponent)
        #expect(center.alphaComponent > 0.9)
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

    @Test func cuttingSelectionToNewLayerUsesSelectionFrameAndClearsSource() throws {
        let canvasSize = CGSize(width: 120, height: 90)
        let viewModel = ImageEditorViewModel(
            sourceName: "selection-layer-cut.png",
            image: .transparent(size: canvasSize)
        ) { _ in }
        let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
        let sourceFrame = CGRect(x: 18, y: 22, width: 40, height: 30)
        viewModel.document.layers[sourceIndex].image = NSImage(
            size: sourceFrame.size,
            flipped: false
        ) { rect in
            NSColor.systemPink.setFill()
            rect.fill()
            return true
        }
        viewModel.document.layers[sourceIndex].frame = sourceFrame
        let sourceID = viewModel.document.layers[sourceIndex].id
        let selectionFrame = CGRect(x: 24, y: 27, width: 16, height: 12)
        viewModel.document.selection = .rectangle(selectionFrame)
        let originalLayerCount = viewModel.document.layers.count
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        viewModel.cutSelectionToNewLayer()

        let cutLayer = try #require(viewModel.document.selectedLayer)
        let sourceLayer = try #require(viewModel.document.layers.first { $0.id == sourceID })
        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(cutLayer.id != sourceID)
        #expect(cutLayer.image.size == selectionFrame.size)
        #expect(cutLayer.frame == selectionFrame)
        let cutCenter = try #require(
            cutLayer.image.color(at: CGPoint(x: 8, y: 6))?.usingColorSpace(.deviceRGB)
        )
        let clearedCenter = try #require(
            sourceLayer.image.color(at: CGPoint(x: 14, y: 11))?.usingColorSpace(.deviceRGB)
        )
        let retainedCorner = try #require(
            sourceLayer.image.color(at: CGPoint(x: 2, y: 2))?.usingColorSpace(.deviceRGB)
        )
        #expect(cutCenter.alphaComponent > 0.95)
        #expect(clearedCenter.alphaComponent < 0.05)
        #expect(retainedCorner.alphaComponent > 0.95)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)
        #expect(viewModel.undoStack.count == originalUndoCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.count == originalLayerCount)
        let restoredSource = try #require(viewModel.document.layers.first { $0.id == sourceID })
        let restoredCenter = try #require(
            restoredSource.image.color(at: CGPoint(x: 14, y: 11))?.usingColorSpace(.deviceRGB)
        )
        #expect(restoredCenter.alphaComponent > 0.95)
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

    @Test func copyingMergedSelectionToNewLayerUsesSelectionFrameAndCompositePixels() throws {
        let canvasSize = CGSize(width: 120, height: 90)
        let viewModel = ImageEditorViewModel(
            sourceName: "merged-selection-layer.png",
            image: NSImage(size: canvasSize, flipped: false) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
                return true
            }
        ) { _ in }
        var overlay = ImageEditorLayer.blank(name: "Overlay", size: CGSize(width: 40, height: 30))
        overlay.image = NSImage(size: overlay.image.size, flipped: false) { rect in
            NSColor.systemPink.setFill()
            rect.fill()
            return true
        }
        overlay.frame = CGRect(x: 18, y: 22, width: 40, height: 30)
        viewModel.document.layers.append(overlay)
        viewModel.document.selectedLayerID = overlay.id
        viewModel.document.selectedLayerIDs = [overlay.id]
        let selectionFrame = CGRect(x: 24, y: 27, width: 16, height: 12)
        viewModel.document.selection = .rectangle(selectionFrame)
        let expectedColor = try #require(
            viewModel.document.compositedImage
                .color(at: CGPoint(x: selectionFrame.midX, y: selectionFrame.midY))?
                .usingColorSpace(.deviceRGB)
        )
        let originalLayerCount = viewModel.document.layers.count
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        viewModel.copyMergedToNewLayer()

        let mergedLayer = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(mergedLayer.image.size == selectionFrame.size)
        #expect(mergedLayer.frame == selectionFrame)
        let mergedColor = try #require(
            mergedLayer.image.color(at: CGPoint(x: 8, y: 6))?.usingColorSpace(.deviceRGB)
        )
        #expect(abs(mergedColor.redComponent - expectedColor.redComponent) < 0.02)
        #expect(abs(mergedColor.blueComponent - expectedColor.blueComponent) < 0.02)
        #expect(mergedColor.alphaComponent > 0.95)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)
        #expect(viewModel.undoStack.count == originalUndoCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.count == originalLayerCount)
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

    @Test func copyingSelectionPreservesLayerLabelColor() throws {
        let viewModel = labeledLayerViewModel(sourceName: "labeled-copy.png", labelColor: .purple)

        viewModel.copySelectionToNewLayer()

        let copiedLayer = try #require(viewModel.document.selectedLayer)
        #expect(copiedLayer.labelColor == .purple)
    }

    @Test func cuttingSelectionPreservesLayerLabelColor() throws {
        let viewModel = labeledLayerViewModel(sourceName: "labeled-cut.png", labelColor: .orange)

        viewModel.cutSelectionToNewLayer()

        let cutLayer = try #require(viewModel.document.selectedLayer)
        #expect(cutLayer.labelColor == .orange)
    }

    @Test func copyingSelectionPreservesAutoLayoutChildSemantics() throws {
        let viewModel = autoLayoutChildViewModel(sourceName: "layout-copy.png")

        viewModel.copySelectionToNewLayer()

        let copiedLayer = try #require(viewModel.document.selectedLayer)
        #expect(copiedLayer.stackChildLayout == ImageEditorStackChildLayout(
            grow: 2,
            stretchesCrossAxis: true
        ))
        #expect(copiedLayer.isStackLayoutExcluded)
    }

    @Test func cuttingSelectionPreservesAutoLayoutChildSemantics() throws {
        let viewModel = autoLayoutChildViewModel(sourceName: "layout-cut.png")

        viewModel.cutSelectionToNewLayer()

        let cutLayer = try #require(viewModel.document.selectedLayer)
        #expect(cutLayer.stackChildLayout == ImageEditorStackChildLayout(
            grow: 2,
            stretchesCrossAxis: true
        ))
        #expect(cutLayer.isStackLayoutExcluded)
    }

    @Test func cuttingSelectionToNewLayerRejectsMultipleSelectedLayersWithoutPartialMutation() throws {
        let size = CGSize(width: 48, height: 32)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemPink.setFill()
            rect.fill()
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: "multi-cut.png", image: image) { _ in }
        let primaryIndex = try #require(viewModel.document.selectedLayerIndex)
        var secondLayer = ImageEditorLayer.blank(name: "Second", size: size)
        secondLayer.image = image
        secondLayer.frame = CGRect(origin: .zero, size: size)
        viewModel.document.layers.insert(secondLayer, at: primaryIndex + 1)
        let primaryID = viewModel.document.layers[primaryIndex].id
        viewModel.document.selectedLayerID = primaryID
        viewModel.document.selectedLayerIDs = [primaryID, secondLayer.id]
        viewModel.selectAll()
        let originalLayerCount = viewModel.document.layers.count
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count
        let originalPrimaryData = try #require(
            viewModel.document.layers.first { $0.id == primaryID }?.image.qingtuPNGData()
        )
        let originalSecondData = try #require(
            viewModel.document.layers.first { $0.id == secondLayer.id }?.image.qingtuPNGData()
        )

        #expect(!viewModel.canCutSelectionToNewLayer)
        viewModel.cutSelectionToNewLayer()

        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.document.layers.first { $0.id == primaryID }?.image.qingtuPNGData() == originalPrimaryData)
        #expect(viewModel.document.layers.first { $0.id == secondLayer.id }?.image.qingtuPNGData() == originalSecondData)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @Test func copyingSelectionToNewLayerRejectsGroupWithOperationFailure() {
        let size = CGSize(width: 48, height: 32)
        let viewModel = ImageEditorViewModel(
            sourceName: "group-copy.png",
            image: .transparent(size: size)
        ) { _ in }
        let group = ImageEditorLayer.group(name: "Group", size: size)
        viewModel.document.layers = [group]
        viewModel.document.selectedLayerID = group.id
        viewModel.document.selectedLayerIDs = [group.id]
        viewModel.selectAll()
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        #expect(!viewModel.canCopySelectionToNewLayer)
        viewModel.copySelectionToNewLayer()

        #expect(viewModel.document.layers.count == 1)
        #expect(viewModel.document.selectedLayerID == group.id)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @Test func copyingSelectionWhileEditingLayerMaskDoesNotReadLayerPixelsOrExitMaskMode() throws {
        let size = CGSize(width: 48, height: 32)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemGreen.setFill()
            rect.fill()
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: "mask-copy.png", image: image) { _ in }
        viewModel.addLayerMask()
        viewModel.selectAll()
        let sourceID = try #require(viewModel.document.selectedLayerID)
        let originalLayerCount = viewModel.document.layers.count
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        #expect(viewModel.isEditingLayerMask)
        #expect(!viewModel.canCopySelectionToNewLayer)
        #expect(!viewModel.canCopySelectionToClipboard)
        viewModel.copySelectionToNewLayer()

        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.selectedLayerID == sourceID)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.isEditingLayerMask)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))

        viewModel.copySelectionToClipboard()
        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.selectedLayerID == sourceID)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.isEditingLayerMask)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))

        viewModel.cutSelectionToClipboard()
        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.selectedLayerID == sourceID)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.isEditingLayerMask)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @Test func transparencyLockPreventsSelectionClearAndCutWithoutBlockingCopy() throws {
        let size = CGSize(width: 48, height: 32)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemRed.setFill()
            rect.fill()
            return true
        }
        let viewModel = ImageEditorViewModel(
            sourceName: "alpha-locked-cut.png",
            image: .transparent(size: size)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            image,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[sourceIndex].locksTransparentPixels = true
        let sourceID = viewModel.document.layers[sourceIndex].id
        viewModel.selectAll()
        let originalData = try #require(viewModel.document.layers[sourceIndex].image.qingtuPNGData())
        let originalLayerCount = viewModel.document.layers.count
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        #expect(viewModel.canCopySelectionToNewLayer)
        #expect(viewModel.canCopySelectionToClipboard)
        #expect(viewModel.canEditSelectionPixels)
        #expect(!viewModel.canRemoveSelectionPixels)
        #expect(!viewModel.canCutSelectionToNewLayer)
        #expect(!viewModel.canCutSelectionToClipboard)

        viewModel.clearSelectionPixels()
        #expect(viewModel.document.layers.first { $0.id == sourceID }?.image.qingtuPNGData() == originalData)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))

        viewModel.cutSelectionToNewLayer()
        viewModel.cutSelectionToClipboard()
        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.layers.first { $0.id == sourceID }?.image.qingtuPNGData() == originalData)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
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

    private func labeledLayerViewModel(
        sourceName: String,
        labelColor: ImageEditorLayerLabelColor
    ) -> ImageEditorViewModel {
        let size = CGSize(width: 48, height: 32)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemTeal.setFill()
            rect.fill()
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: sourceName, image: image) { _ in }
        if let sourceIndex = viewModel.document.selectedLayerIndex {
            viewModel.document.layers[sourceIndex].labelColor = labelColor
        }
        viewModel.selectAll()
        return viewModel
    }

    private func autoLayoutChildViewModel(sourceName: String) -> ImageEditorViewModel {
        let size = CGSize(width: 48, height: 32)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemIndigo.setFill()
            rect.fill()
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: sourceName, image: image) { _ in }
        if let sourceIndex = viewModel.document.selectedLayerIndex {
            viewModel.document.layers[sourceIndex].stackChildLayout = ImageEditorStackChildLayout(
                grow: 2,
                stretchesCrossAxis: true
            )
            viewModel.document.layers[sourceIndex].isStackLayoutExcluded = true
        }
        viewModel.selectAll()
        return viewModel
    }
}
