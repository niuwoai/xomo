import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSelectionFillDialogTests {
    @Test func fillContentsResolveClassicSources() throws {
        let foreground = NSColor(deviceRed: 0.8, green: 0.2, blue: 0.1, alpha: 1)
        let background = NSColor(deviceRed: 0.1, green: 0.3, blue: 0.9, alpha: 1)
        let custom = NSColor(deviceRed: 0.2, green: 0.7, blue: 0.4, alpha: 1)

        #expect(imageEditorColorsMatch(
            try #require(ImageEditorSelectionFillContents.foreground.resolvedColor(
                foreground: foreground, background: background, custom: custom
            )),
            foreground
        ))
        #expect(imageEditorColorsMatch(
            try #require(ImageEditorSelectionFillContents.background.resolvedColor(
                foreground: foreground, background: background, custom: custom
            )),
            background
        ))
        #expect(imageEditorColorsMatch(
            try #require(ImageEditorSelectionFillContents.color.resolvedColor(
                foreground: foreground, background: background, custom: custom
            )),
            custom
        ))
        #expect(ImageEditorSelectionFillContents.pattern.resolvedColor(
            foreground: foreground, background: background, custom: custom
        ) == nil)
        #expect(ImageEditorSelectionFillContents.contentAware.resolvedColor(
            foreground: foreground, background: background, custom: custom
        ) == nil)
        #expect(ImageEditorSelectionFillContents.history.resolvedColor(
            foreground: foreground, background: background, custom: custom
        ) == nil)
        #expect(ImageEditorSelectionFillContents.allCases.count == 9)
        #expect(ImageEditorSelectionFillContents.availableCases(isQuickMaskMode: false).contains(.contentAware))
        #expect(ImageEditorSelectionFillContents.availableCases(isQuickMaskMode: false).contains(.history))
        #expect(!ImageEditorSelectionFillContents.availableCases(isQuickMaskMode: true).contains(.contentAware))
        #expect(!ImageEditorSelectionFillContents.availableCases(isQuickMaskMode: true).contains(.history))
        #expect(ImageEditorSelectionFillContents.availableCases(isQuickMaskMode: true).contains(.pattern))
    }

    @Test func multiplyFillUsesDialogOpacityAndCommitsOneTransaction() throws {
        let sourceColor = NSColor(deviceRed: 0.8, green: 0.5, blue: 0.25, alpha: 1)
        let viewModel = makeViewModel(color: sourceColor)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .color,
            customColor: NSColor(deviceWhite: 0.5, alpha: 1),
            blendMode: .multiply,
            opacity: 0.5,
            preservesTransparency: false
        ))

        let image = try #require(viewModel.document.selectedLayer?.image)
        let pixel = try #require(imageEditorRGBABytes(image, width: 2, height: 2))
        #expect(abs(Int(pixel[0]) - 153) <= 3)
        #expect(abs(Int(pixel[1]) - 96) <= 3)
        #expect(abs(Int(pixel[2]) - 48) <= 3)
        #expect(pixel[3] == 255)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
    }

    @Test func preserveTransparencyKeepsPartialAlphaAndTransparentPixels() throws {
        let image = NSImage(size: CGSize(width: 2, height: 1), flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            NSColor(deviceRed: 0.2, green: 0.4, blue: 0.8, alpha: 0.5).setFill()
            CGRect(x: 0, y: 0, width: 1, height: 1).fill()
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: "fill-alpha.png", image: image) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            image,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.selectAll()

        viewModel.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .white,
            customColor: .black,
            blendMode: .normal,
            opacity: 1,
            preservesTransparency: true
        ))

        let output = try #require(viewModel.document.selectedLayer?.image)
        let pixels = try #require(imageEditorRGBABytes(output, width: 2, height: 1))
        #expect(abs(Int(pixels[3]) - 128) <= 2)
        #expect(abs(Int(pixels[0]) - Int(pixels[3])) <= 2)
        #expect(pixels[7] == 0)
    }

    @Test func quickMaskFillBlendsTheTemporaryChannelDeterministically() {
        let source: [UInt8] = [0, 64, 255, 128]
        let normal = ImageEditorQuickMaskFillCompositor.fill(
            alpha: source,
            width: 2,
            targetAlpha: 255,
            opacity: 0.5,
            blendMode: .normal
        )
        #expect(normal == [128, 160, 255, 192])

        let multiply = ImageEditorQuickMaskFillCompositor.fill(
            alpha: source,
            width: 2,
            targetAlpha: 128,
            opacity: 1,
            blendMode: .multiply
        )
        #expect(multiply == [0, 32, 128, 64])

        let firstDissolve = ImageEditorQuickMaskFillCompositor.fill(
            alpha: source,
            width: 2,
            targetAlpha: 255,
            opacity: 0.5,
            blendMode: .dissolve
        )
        let secondDissolve = ImageEditorQuickMaskFillCompositor.fill(
            alpha: source,
            width: 2,
            targetAlpha: 255,
            opacity: 0.5,
            blendMode: .dissolve
        )
        #expect(firstDissolve == secondDissolve)
    }

    @Test func patternFillUsesNativeTileContentAndOneTransaction() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "pattern-fill.png",
            image: .transparent(size: CGSize(width: 12, height: 12))
        ) { _ in }
        viewModel.selectAll()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        let options = ImageEditorSelectionFillOptions(
            contents: .pattern,
            blendMode: .normal,
            opacity: 1,
            patternContent: ImageEditorPatternFillContent(
                kind: .checkerboard,
                red: 1,
                green: 0,
                blue: 0,
                opacity: 1,
                scale: 6
            )
        )
        viewModel.fillSelection(options: options)

        let image = try #require(viewModel.document.selectedLayer?.image)
        let pixels = try #require(imageEditorRGBABytes(image, width: 12, height: 12))
        let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        #expect(alpha.contains(0))
        #expect(alpha.contains(where: { $0 > 240 }))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)

        viewModel.fillSelection(options: options)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
    }

    @Test func canvasAlignedPatternCompensatesEachLayerOrigin() throws {
        let content = ImageEditorPatternFillContent(
            kind: .checkerboard,
            scale: 12,
            offsetX: 5,
            offsetY: -7
        )
        let frame = CGRect(x: 31, y: 19, width: 40, height: 24)
        let canvasAligned = ImageEditorSelectionPatternAlignment.localizedContent(
            content,
            layerFrame: frame,
            alignsWithCanvas: true
        )
        let layerAligned = ImageEditorSelectionPatternAlignment.localizedContent(
            content,
            layerFrame: frame,
            alignsWithCanvas: false
        )

        #expect(canvasAligned.offsetX == -2)
        #expect(canvasAligned.offsetY == -2)
        #expect(layerAligned.offsetX == 5)
        #expect(layerAligned.offsetY == -7)

        let firstFrame = CGRect(x: 0, y: 0, width: 12, height: 12)
        let secondFrame = CGRect(x: 5, y: 0, width: 12, height: 12)
        let firstPattern = ImageEditorSelectionPatternAlignment.localizedContent(
            ImageEditorPatternFillContent(kind: .checkerboard, opacity: 1, scale: 12),
            layerFrame: firstFrame,
            alignsWithCanvas: true
        ).renderedImage(size: firstFrame.size)
        let secondPattern = ImageEditorSelectionPatternAlignment.localizedContent(
            ImageEditorPatternFillContent(kind: .checkerboard, opacity: 1, scale: 12),
            layerFrame: secondFrame,
            alignsWithCanvas: true
        ).renderedImage(size: secondFrame.size)
        let firstPixels = try #require(imageEditorRGBABytes(firstPattern, width: 12, height: 12))
        let secondPixels = try #require(imageEditorRGBABytes(secondPattern, width: 12, height: 12))
        for globalX in 5..<12 {
            let firstOffset = (6 * 12 + globalX) * 4
            let secondOffset = (6 * 12 + globalX - 5) * 4
            #expect(firstPixels[firstOffset + 3] == secondPixels[secondOffset + 3])
        }
    }

    @Test func quickMaskPatternLeavesTransparentTileAreasUntouched() throws {
        let source = [UInt8](repeating: 64, count: 12 * 12)
        let output = try #require(ImageEditorQuickMaskFillCompositor.fill(
            alpha: source,
            width: 12,
            height: 12,
            targetAlpha: 255,
            pattern: ImageEditorPatternFillContent(
                kind: .checkerboard,
                red: 1,
                green: 1,
                blue: 1,
                opacity: 1,
                scale: 6
            ),
            opacity: 1,
            blendMode: .normal
        ))
        #expect(output.contains(64))
        #expect(output.contains(where: { $0 > 240 }))
    }

    @Test func fillDialogPatternTargetsQuickMaskWithoutChangingLayerPixels() throws {
        let image = NSImage(size: CGSize(width: 12, height: 12), flipped: false) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: "quick-mask-pattern.png", image: image) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            image,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.selectAll()
        let layerBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.setQuickMaskOverlayTarget(.maskedAreas)
        viewModel.toggleQuickMaskMode()
        let historyCount = viewModel.document.history.count

        viewModel.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .pattern,
            blendMode: .normal,
            opacity: 1,
            patternContent: ImageEditorPatternFillContent(
                kind: .checkerboard,
                red: 0,
                green: 0,
                blue: 0,
                opacity: 1,
                scale: 6
            )
        ))

        let mask = try #require(viewModel.document.selection?.rasterizedMask(
            canvasSize: viewModel.document.canvasSize
        ))
        #expect(mask.alpha.contains(0))
        #expect(mask.alpha.contains(255))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == layerBefore)
    }

    @Test func contentAwareFillUsesDialogOpacityAndCommitsOneTransaction() throws {
        let viewModel = makeContentAwareViewModel()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .contentAware,
            blendMode: .normal,
            opacity: 0.5,
            adaptsContentAwareColor: true
        ))

        let image = try #require(viewModel.document.selectedLayer?.image)
        let center = try #require(image.color(at: CGPoint(x: 30, y: 20))?.usingColorSpace(.deviceRGB))
        #expect(center.greenComponent > 0.35)
        #expect(center.greenComponent < 0.75)
        #expect(center.redComponent < 0.2)
        #expect(center.blueComponent < 0.2)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionContentAwareFill"))
    }

    @Test func contentAwareFillHonorsBlendMode() throws {
        let normal = makeSplitSamplingViewModel(selectedColor: NSColor(deviceWhite: 0.5, alpha: 1))
        let multiply = makeSplitSamplingViewModel(selectedColor: NSColor(deviceWhite: 0.5, alpha: 1))

        normal.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .contentAware,
            blendMode: .normal,
            opacity: 1,
            adaptsContentAwareColor: false
        ))
        multiply.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .contentAware,
            blendMode: .multiply,
            opacity: 1,
            adaptsContentAwareColor: false
        ))

        let normalCenter = try #require(normal.document.selectedLayer?.image.color(
            at: CGPoint(x: 30, y: 20)
        )?.usingColorSpace(.deviceRGB))
        let multiplyCenter = try #require(multiply.document.selectedLayer?.image.color(
            at: CGPoint(x: 30, y: 20)
        )?.usingColorSpace(.deviceRGB))
        #expect(multiplyCenter.redComponent < normalCenter.redComponent * 0.7)
        #expect(multiplyCenter.blueComponent < normalCenter.blueComponent * 0.7)
    }

    @Test func contentAwareColorAdaptationUsesNearbyPixelsInsteadOfOneGlobalAverage() throws {
        let adapted = makeSplitSamplingViewModel(selectedColor: .black)
        let uniform = makeSplitSamplingViewModel(selectedColor: .black)

        adapted.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .contentAware,
            adaptsContentAwareColor: true
        ))
        uniform.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .contentAware,
            adaptsContentAwareColor: false
        ))

        let adaptedImage = try #require(adapted.document.selectedLayer?.image)
        let uniformImage = try #require(uniform.document.selectedLayer?.image)
        let adaptedLeft = try #require(adaptedImage.color(at: CGPoint(x: 21, y: 20))?.usingColorSpace(.deviceRGB))
        let adaptedRight = try #require(adaptedImage.color(at: CGPoint(x: 38, y: 20))?.usingColorSpace(.deviceRGB))
        let uniformLeft = try #require(uniformImage.color(at: CGPoint(x: 21, y: 20))?.usingColorSpace(.deviceRGB))
        let uniformRight = try #require(uniformImage.color(at: CGPoint(x: 38, y: 20))?.usingColorSpace(.deviceRGB))

        #expect(adaptedLeft.redComponent > adaptedLeft.blueComponent + 0.4)
        #expect(adaptedRight.blueComponent > adaptedRight.redComponent + 0.4)
        #expect(abs(uniformLeft.redComponent - uniformRight.redComponent) < 0.03)
        #expect(abs(uniformLeft.blueComponent - uniformRight.blueComponent) < 0.03)
    }

    @Test func contentAwareFillPreservesTransparentPixelsWhenRequested() throws {
        let canvasSize = CGSize(width: 60, height: 40)
        let image = NSImage(size: canvasSize, flipped: false) { rect in
            NSColor.systemGreen.setFill()
            rect.fill()
            NSColor.clear.setFill()
            CGRect(x: 20, y: 10, width: 20, height: 20).fill(using: .copy)
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: "content-aware-alpha.png", image: image) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            image,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(from: CGPoint(x: 20, y: 10), to: CGPoint(x: 40, y: 30))

        viewModel.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .contentAware,
            preservesTransparency: true
        ))

        let center = try #require(viewModel.document.selectedLayer?.image.color(
            at: CGPoint(x: 30, y: 20)
        )?.usingColorSpace(.deviceRGB))
        #expect(center.alphaComponent < 0.05)
    }

    @Test func contentAwareFillIsUnavailableInQuickMaskAndDoesNotMutateHistory() throws {
        let viewModel = makeContentAwareViewModel()
        let layerBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.toggleQuickMaskMode()
        let maskBefore = viewModel.document.selection
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.fillSelection(options: ImageEditorSelectionFillOptions(contents: .contentAware))

        #expect(viewModel.document.selection == maskBefore)
        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == layerBefore)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @Test func historyFillRestoresOnlySelectedPixelsFromTheChosenHistoryState() throws {
        let canvasSize = CGSize(width: 8, height: 4)
        let source = solidImage(color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1), size: canvasSize)
        let current = solidImage(color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "history-fill.png", image: source) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            source,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let sourceEntryID = try #require(viewModel.document.history.last?.id)
        viewModel.setHistoryFillSource(entryID: sourceEntryID)
        viewModel.replaceSelectedLayerImageForTesting(
            current,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 4, y: 4))
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.fillSelection(options: ImageEditorSelectionFillOptions(contents: .history))

        let image = try #require(viewModel.document.selectedLayer?.image)
        let inside = try #require(image.color(at: CGPoint(x: 2, y: 2))?.usingColorSpace(.deviceRGB))
        let outside = try #require(image.color(at: CGPoint(x: 6, y: 2))?.usingColorSpace(.deviceRGB))
        #expect(inside.greenComponent > 0.7)
        #expect(inside.redComponent < 0.3)
        #expect(outside.redComponent > 0.7)
        #expect(outside.greenComponent < 0.3)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionHistoryFill"))
    }

    @Test func namedSnapshotCanOwnTheHistoryFillSourceWithoutRestoringTheWholeDocument() throws {
        let canvasSize = CGSize(width: 6, height: 4)
        let green = solidImage(color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1), size: canvasSize)
        let blue = solidImage(color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1), size: canvasSize)
        let red = solidImage(color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "history-snapshot-fill.png", image: green) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            green,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createHistorySnapshot()
        let snapshotID = try #require(viewModel.namedHistorySnapshots.first?.id)
        viewModel.replaceSelectedLayerImageForTesting(
            blue,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.replaceSelectedLayerImageForTesting(
            red,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.selectAll()
        viewModel.setHistoryFillSource(snapshotID: snapshotID)

        viewModel.fillSelectionFromHistory()

        #expect(viewModel.isHistoryFillSource(snapshotID: snapshotID))
        let center = try #require(viewModel.document.selectedLayer?.image.color(
            at: CGPoint(x: 3, y: 2)
        )?.usingColorSpace(.deviceRGB))
        #expect(center.greenComponent > 0.7)
        #expect(center.redComponent < 0.3)
        #expect(center.blueComponent < 0.3)
    }

    @Test func historyFillAlignsTheSourceLayerByItsHistoricalCanvasFrame() throws {
        let canvasSize = CGSize(width: 12, height: 12)
        let background = solidImage(color: .black, size: canvasSize)
        let green = solidImage(
            color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1),
            size: CGSize(width: 6, height: 6)
        )
        let red = solidImage(
            color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1),
            size: CGSize(width: 6, height: 6)
        )
        let viewModel = ImageEditorViewModel(sourceName: "history-fill-frame.png", image: background) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            green,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let sourceEntryID = try #require(viewModel.document.history.last?.id)
        viewModel.setHistoryFillSource(entryID: sourceEntryID)
        viewModel.replaceSelectedLayerImageForTesting(
            red,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].frame.origin = CGPoint(x: 3, y: 3)
        viewModel.createRectSelection(from: CGPoint(x: 3, y: 3), to: CGPoint(x: 9, y: 9))
        #expect(viewModel.effectiveHistoryFillSource == .entry(sourceEntryID))
        #expect(viewModel.canFillSelectionFromHistory)
        #expect(viewModel.document.layers[selectedIndex].frame == CGRect(x: 3, y: 3, width: 6, height: 6))

        viewModel.fillSelectionFromHistory()

        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionHistoryFilled"))
        let image = try #require(viewModel.document.selectedLayer?.image)
        let pixels = try #require(imageEditorRGBABytes(image, width: 6, height: 6))
        let pixelOffsets = stride(from: 0, to: pixels.count, by: 4)
        let restoredGreenCount = pixelOffsets.filter { offset in
            pixels[offset] < 10 && pixels[offset + 1] > 245
                && pixels[offset + 2] < 10 && pixels[offset + 3] > 245
        }.count
        let restoredTransparencyCount = pixelOffsets.filter { pixels[$0 + 3] < 10 }.count
        #expect(restoredGreenCount == 9)
        #expect(restoredTransparencyCount == 27)
    }

    @Test func historyFillRestoresTransparencyUnlessPreserveTransparencyIsRequested() throws {
        let canvasSize = CGSize(width: 6, height: 4)
        let source = NSImage(size: canvasSize, flipped: false) { rect in
            NSColor.systemGreen.setFill()
            rect.fill()
            NSColor.clear.setFill()
            CGRect(x: 2, y: 1, width: 2, height: 2).fill(using: .copy)
            return true
        }
        let current = solidImage(color: .systemRed, size: canvasSize)
        let restoring = historyFillViewModel(source: source, current: current)
        let preserving = historyFillViewModel(source: source, current: current)

        restoring.fillSelection(options: ImageEditorSelectionFillOptions(contents: .history))
        preserving.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .history,
            preservesTransparency: true
        ))

        let restoredCenter = try #require(restoring.document.selectedLayer?.image.color(
            at: CGPoint(x: 3, y: 2)
        )?.usingColorSpace(.deviceRGB))
        let preservedCenter = try #require(preserving.document.selectedLayer?.image.color(
            at: CGPoint(x: 3, y: 2)
        )?.usingColorSpace(.deviceRGB))
        #expect(restoredCenter.alphaComponent < 0.05)
        #expect(preservedCenter.alphaComponent > 0.95)
    }

    @Test func historyFillUsesDialogOpacityAndBlendMode() throws {
        let canvasSize = CGSize(width: 4, height: 4)
        let source = solidImage(color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), size: canvasSize)
        let current = solidImage(color: NSColor(deviceWhite: 0.5, alpha: 1), size: canvasSize)
        let normal = historyFillViewModel(source: source, current: current)
        let multiply = historyFillViewModel(source: source, current: current)

        normal.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .history,
            blendMode: .normal,
            opacity: 0.5
        ))
        multiply.fillSelection(options: ImageEditorSelectionFillOptions(
            contents: .history,
            blendMode: .multiply,
            opacity: 1
        ))

        let normalCenter = try #require(normal.document.selectedLayer?.image.color(
            at: CGPoint(x: 2, y: 2)
        )?.usingColorSpace(.deviceRGB))
        let multiplyCenter = try #require(multiply.document.selectedLayer?.image.color(
            at: CGPoint(x: 2, y: 2)
        )?.usingColorSpace(.deviceRGB))
        #expect(normalCenter.redComponent > 0.7)
        #expect(normalCenter.greenComponent > 0.15)
        #expect(multiplyCenter.redComponent < normalCenter.redComponent * 0.75)
        #expect(multiplyCenter.greenComponent < 0.1)
    }

    @Test func classicHistoryShortcutUsesFullOpacityAndShiftOnlyPreservesTransparency() throws {
        let canvasSize = CGSize(width: 4, height: 4)
        let source = solidImage(
            color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1),
            size: canvasSize
        )
        let current = solidImage(
            color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1),
            size: canvasSize
        )
        let viewModel = historyFillViewModel(source: source, current: current)
        viewModel.opacity = 0.2

        viewModel.fillSelectionFromHistoryPreservingTransparency()

        let center = try #require(viewModel.document.selectedLayer?.image.color(
            at: CGPoint(x: 2, y: 2)
        )?.usingColorSpace(.deviceRGB))
        #expect(center.greenComponent > 0.9)
        #expect(center.redComponent < 0.1)
        #expect(center.alphaComponent > 0.95)
    }

    @Test func unchangedHistoryFillPreservesUndoRedoAndHistory() throws {
        let canvasSize = CGSize(width: 4, height: 4)
        let red = solidImage(color: .systemRed, size: canvasSize)
        let blue = solidImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(sourceName: "history-fill-noop.png", image: red) { _ in }
        viewModel.selectAll()
        let sourceEntryID = try #require(viewModel.document.history.last?.id)
        viewModel.setHistoryFillSource(entryID: sourceEntryID)
        viewModel.replaceSelectedLayerImageForTesting(
            blue,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.undo()
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        viewModel.fillSelectionFromHistory()

        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.historyFillUnchanged"))
    }

    @Test func historyFillIsUnavailableInQuickMaskWithoutMutation() throws {
        let canvasSize = CGSize(width: 4, height: 4)
        let source = solidImage(color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1), size: canvasSize)
        let current = solidImage(color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), size: canvasSize)
        let viewModel = historyFillViewModel(source: source, current: current)
        viewModel.toggleQuickMaskMode()
        let layerBefore = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let selectionBefore = viewModel.document.selection
        let historyCount = viewModel.document.history.count

        viewModel.fillSelection(options: ImageEditorSelectionFillOptions(contents: .history))

        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == layerBefore)
        #expect(viewModel.document.selection == selectionBefore)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @Test func historyBrushRestoresOnlyItsFootprintInsideTheExistingSelection() throws {
        let canvasSize = CGSize(width: 16, height: 10)
        let green = solidImage(
            color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1),
            size: canvasSize
        )
        let red = solidImage(
            color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1),
            size: canvasSize
        )
        let viewModel = historyBrushViewModel(source: green, current: red)
        viewModel.brushSize = 4
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.brushFlow = 100
        viewModel.createRectSelection(from: CGPoint(x: 8, y: 0), to: CGPoint(x: 16, y: 10))
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        let didChange = viewModel.historyBrush(samples: [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 2, y: 5)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 14, y: 5)),
        ])

        #expect(didChange)
        let image = try #require(viewModel.document.selectedLayer?.image)
        let outsideSelection = try #require(image.color(
            at: CGPoint(x: 5, y: 5)
        )?.usingColorSpace(.deviceRGB))
        let insideStroke = try #require(image.color(
            at: CGPoint(x: 11, y: 5)
        )?.usingColorSpace(.deviceRGB))
        let outsideStroke = try #require(image.color(
            at: CGPoint(x: 11, y: 9)
        )?.usingColorSpace(.deviceRGB))
        #expect(outsideSelection.redComponent > 0.8)
        #expect(outsideSelection.greenComponent < 0.2)
        #expect(insideStroke.greenComponent > 0.8)
        #expect(insideStroke.redComponent < 0.2)
        #expect(outsideStroke.redComponent > 0.8)
        #expect(outsideStroke.greenComponent < 0.2)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.historyBrush"))
        viewModel.undo()
        let restored = try #require(viewModel.document.selectedLayer?.image.color(
            at: CGPoint(x: 11, y: 5)
        )?.usingColorSpace(.deviceRGB))
        #expect(restored.redComponent > 0.8)
        #expect(restored.greenComponent < 0.2)
    }

    @Test func historyBrushUsesTheNamedSnapshotSourceWithoutRestoringTheDocument() throws {
        let canvasSize = CGSize(width: 8, height: 6)
        let green = solidImage(color: .systemGreen, size: canvasSize)
        let blue = solidImage(color: .systemBlue, size: canvasSize)
        let red = solidImage(color: .systemRed, size: canvasSize)
        let viewModel = ImageEditorViewModel(
            sourceName: "history-brush-snapshot.png",
            image: green
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            green,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createHistorySnapshot()
        let snapshotID = try #require(viewModel.namedHistorySnapshots.first?.id)
        viewModel.replaceSelectedLayerImageForTesting(
            blue,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.replaceSelectedLayerImageForTesting(
            red,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.setHistoryFillSource(snapshotID: snapshotID)
        viewModel.brushSize = 4
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.brushFlow = 100

        #expect(viewModel.historyBrush(samples: [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 2, y: 3)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 6, y: 3)),
        ]))

        let painted = try #require(viewModel.document.selectedLayer?.image.color(
            at: CGPoint(x: 4, y: 3)
        )?.usingColorSpace(.deviceRGB))
        let untouched = try #require(viewModel.document.selectedLayer?.image.color(
            at: CGPoint(x: 4, y: 0)
        )?.usingColorSpace(.deviceRGB))
        #expect(painted.greenComponent > painted.redComponent + 0.4)
        #expect(painted.greenComponent > painted.blueComponent + 0.4)
        #expect(untouched.redComponent > untouched.greenComponent + 0.4)
        #expect(untouched.redComponent > untouched.blueComponent + 0.4)
        #expect(viewModel.isHistoryFillSource(snapshotID: snapshotID))
    }

    @Test func unchangedHistoryBrushPreservesUndoRedoAndHistory() throws {
        let canvasSize = CGSize(width: 8, height: 6)
        let red = solidImage(color: .systemRed, size: canvasSize)
        let blue = solidImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(
            sourceName: "history-brush-noop.png",
            image: red
        ) { _ in }
        let sourceEntryID = try #require(viewModel.document.history.last?.id)
        viewModel.setHistoryFillSource(entryID: sourceEntryID)
        viewModel.replaceSelectedLayerImageForTesting(
            blue,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.undo()
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        let didChange = viewModel.historyBrush(samples: [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 2, y: 3)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 6, y: 3)),
        ])

        #expect(!didChange)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.historyBrushUnchanged"))
    }

    @Test func historyBrushRejectsQuickMaskWithoutChangingPixelsOrHistory() throws {
        let canvasSize = CGSize(width: 8, height: 6)
        let green = solidImage(color: .systemGreen, size: canvasSize)
        let red = solidImage(color: .systemRed, size: canvasSize)
        let viewModel = historyBrushViewModel(source: green, current: red)
        viewModel.selectAll()
        viewModel.toggleQuickMaskMode()
        let pixels = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let selection = viewModel.document.selection
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count

        let didChange = viewModel.historyBrush(samples: [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 2, y: 3)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 6, y: 3)),
        ])

        #expect(!didChange)
        #expect(try #require(viewModel.document.selectedLayer?.image.qingtuPNGData()) == pixels)
        #expect(viewModel.document.selection == selection)
        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.historyBrushUnavailable"))
    }

    @Test func eraseToHistoryRestoresPixelsWhileOrdinaryEraserClearsThem() throws {
        let canvasSize = CGSize(width: 12, height: 8)
        let green = solidImage(color: .systemGreen, size: canvasSize)
        let red = solidImage(color: .systemRed, size: canvasSize)
        let restoring = historyBrushViewModel(source: green, current: red)
        let erasing = historyBrushViewModel(source: green, current: red)
        for viewModel in [restoring, erasing] {
            viewModel.brushSize = 4
            viewModel.hardness = 1
            viewModel.opacity = 1
            viewModel.brushFlow = 100
        }
        let samples = [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 4, y: 4)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 8, y: 4)),
        ]

        restoring.eraseBrush(samples: samples, restoringHistory: true)
        erasing.eraseBrush(samples: samples, restoringHistory: false)

        let restored = try #require(restoring.document.selectedLayer?.image.color(
            at: CGPoint(x: 6, y: 4)
        )?.usingColorSpace(.deviceRGB))
        let erased = try #require(erasing.document.selectedLayer?.image.color(
            at: CGPoint(x: 6, y: 4)
        )?.usingColorSpace(.deviceRGB))
        let untouched = try #require(restoring.document.selectedLayer?.image.color(
            at: CGPoint(x: 6, y: 0)
        )?.usingColorSpace(.deviceRGB))
        #expect(restored.greenComponent > restored.redComponent + 0.4)
        #expect(restored.alphaComponent > 0.9)
        #expect(erased.alphaComponent < 0.1)
        #expect(untouched.redComponent > untouched.greenComponent + 0.4)
        #expect(restoring.document.history.last?.title == L10n.text("imageEditor.history.historyBrush"))
        #expect(erasing.document.history.last?.title == L10n.text("imageEditor.history.erase"))
    }

    @Test func eraseToHistoryPolicyRequiresACompatibleSourceAndSupportsOption() {
        let canvasSize = CGSize(width: 8, height: 6)
        let green = solidImage(color: .systemGreen, size: canvasSize)
        let red = solidImage(color: .systemRed, size: canvasSize)
        let viewModel = historyBrushViewModel(source: green, current: red)

        #expect(viewModel.canEraseToHistory)
        #expect(!viewModel.shouldEraseToHistory(modifierFlags: []))
        #expect(viewModel.shouldEraseToHistory(modifierFlags: [.option]))
        viewModel.eraserErasesToHistory = true
        #expect(viewModel.shouldEraseToHistory(modifierFlags: []))

        viewModel.toggleQuickMaskMode()
        #expect(!viewModel.canEraseToHistory)
        #expect(!viewModel.shouldEraseToHistory(modifierFlags: [.option]))
    }

    @Test func unchangedEraseToHistoryPreservesUndoRedoAndHistory() throws {
        let canvasSize = CGSize(width: 8, height: 6)
        let red = solidImage(color: .systemRed, size: canvasSize)
        let blue = solidImage(color: .systemBlue, size: canvasSize)
        let viewModel = ImageEditorViewModel(
            sourceName: "erase-to-history-noop.png",
            image: red
        ) { _ in }
        let sourceEntryID = try #require(viewModel.document.history.last?.id)
        viewModel.setHistoryFillSource(entryID: sourceEntryID)
        viewModel.replaceSelectedLayerImageForTesting(
            blue,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.undo()
        let history = viewModel.document.history
        let undoCount = viewModel.undoStack.count
        let redoCount = viewModel.redoStack.count

        viewModel.eraseBrush(
            samples: [
                ImageEditorBrushStrokeSample(point: CGPoint(x: 2, y: 3)),
                ImageEditorBrushStrokeSample(point: CGPoint(x: 6, y: 3)),
            ],
            restoringHistory: true
        )

        #expect(viewModel.document.history == history)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.redoStack.count == redoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.historyBrushUnchanged"))
    }

    @Test func panelDefaultsAndApplyUseOneExplicitFillTransaction() {
        let viewModel = makeViewModel(color: .systemBlue)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.presentSelectionFillPanel()
        #expect(viewModel.isSelectionFillSheetPresented)
        #expect(viewModel.selectionFillContents == .foreground)
        #expect(viewModel.selectionFillBlendMode == .normal)
        #expect(viewModel.selectionFillOpacity == 1)
        #expect(!viewModel.selectionFillPreservesTransparency)

        viewModel.selectionFillContents = .black
        viewModel.applySelectionFillFromPanel()
        #expect(!viewModel.isSelectionFillSheetPresented)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
    }

    private func makeViewModel(color: NSColor) -> ImageEditorViewModel {
        let image = NSImage(size: CGSize(width: 2, height: 2), flipped: false) { rect in
            color.setFill()
            rect.fill()
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: "fill-dialog.png", image: image) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            image,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.selectAll()
        return viewModel
    }

    private func makeContentAwareViewModel() -> ImageEditorViewModel {
        let canvasSize = CGSize(width: 60, height: 40)
        let image = NSImage(size: canvasSize, flipped: false) { rect in
            NSColor.systemGreen.setFill()
            rect.fill()
            NSColor.black.setFill()
            CGRect(x: 20, y: 10, width: 20, height: 20).fill()
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: "content-aware-fill.png", image: image) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            image,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(from: CGPoint(x: 20, y: 10), to: CGPoint(x: 40, y: 30))
        return viewModel
    }

    private func makeSplitSamplingViewModel(selectedColor: NSColor) -> ImageEditorViewModel {
        let canvasSize = CGSize(width: 60, height: 40)
        let image = NSImage(size: canvasSize, flipped: false) { _ in
            NSColor.systemRed.setFill()
            CGRect(x: 0, y: 0, width: 20, height: 40).fill()
            selectedColor.setFill()
            CGRect(x: 20, y: 0, width: 20, height: 40).fill()
            NSColor.systemBlue.setFill()
            CGRect(x: 40, y: 0, width: 20, height: 40).fill()
            return true
        }
        let viewModel = ImageEditorViewModel(sourceName: "content-aware-adaptation.png", image: image) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            image,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.createRectSelection(from: CGPoint(x: 20, y: 0), to: CGPoint(x: 40, y: 40))
        return viewModel
    }

    private func historyFillViewModel(source: NSImage, current: NSImage) -> ImageEditorViewModel {
        let viewModel = ImageEditorViewModel(sourceName: "history-fill-options.png", image: source) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            source,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        if let sourceEntryID = viewModel.document.history.last?.id {
            viewModel.setHistoryFillSource(entryID: sourceEntryID)
        }
        viewModel.replaceSelectedLayerImageForTesting(
            current,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.selectAll()
        return viewModel
    }

    private func historyBrushViewModel(source: NSImage, current: NSImage) -> ImageEditorViewModel {
        let viewModel = ImageEditorViewModel(
            sourceName: "history-brush.png",
            image: source
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            source,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        if let sourceEntryID = viewModel.document.history.last?.id {
            viewModel.setHistoryFillSource(entryID: sourceEntryID)
        }
        viewModel.replaceSelectedLayerImageForTesting(
            current,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        return viewModel
    }

    private func solidImage(color: NSColor, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            color.setFill()
            rect.fill()
            return true
        }
    }
}
