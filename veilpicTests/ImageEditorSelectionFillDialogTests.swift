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
        #expect(ImageEditorSelectionFillContents.allCases.count == 8)
        #expect(ImageEditorSelectionFillContents.availableCases(isQuickMaskMode: false).contains(.contentAware))
        #expect(!ImageEditorSelectionFillContents.availableCases(isQuickMaskMode: true).contains(.contentAware))
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
}
