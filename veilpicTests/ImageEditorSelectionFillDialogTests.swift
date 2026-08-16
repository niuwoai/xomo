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
        #expect(ImageEditorSelectionFillContents.allCases.count == 7)
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
}
