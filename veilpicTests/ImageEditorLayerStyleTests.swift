//
//  ImageEditorLayerStyleTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerStyleTests {
    @Test func imageEditorBatchEditsLayerStyleEffectsAcrossEditableSelection() async throws {
        let canvasSize = NSSize(width: 32, height: 24)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .black, size: canvasSize)
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

        #expect(viewModel.canEditSelectedLayerStyle)
        viewModel.toggleSelectedLayerStroke()
        #expect(viewModel.setSelectedLayerStrokeWidth(9) == 2)
        let historyAfterStrokeWidth = viewModel.document.history.count
        #expect(viewModel.setSelectedLayerStrokeWidth(9) == 0)
        #expect(viewModel.document.history.count == historyAfterStrokeWidth)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
        #expect(viewModel.setSelectedLayerStrokeOpacity(0.45) == 2)
        let historyAfterStrokeOpacity = viewModel.document.history.count
        #expect(viewModel.setSelectedLayerStrokeOpacity(0.45) == 0)
        #expect(viewModel.document.history.count == historyAfterStrokeOpacity)
        viewModel.toggleSelectedLayerShadow()
        viewModel.setSelectedLayerShadowDistance(14)
        viewModel.setSelectedLayerShadowAngle(35)

        let first = try #require(layer(firstID, in: viewModel))
        let second = try #require(layer(secondID, in: viewModel))
        let locked = try #require(layer(lockedID, in: viewModel))
        let group = try #require(layer(groupID, in: viewModel))

        #expect(first.style.strokeEnabled)
        #expect(first.style.strokeWidth == 9)
        #expect(first.style.strokeOpacity == 0.45)
        #expect(first.style.shadowEnabled)
        #expect(first.style.shadowDistance == 14)
        #expect(first.style.shadowAngle == 35)
        #expect(second.style.strokeEnabled)
        #expect(second.style.strokeWidth == 9)
        #expect(second.style.strokeOpacity == 0.45)
        #expect(second.style.shadowEnabled)
        #expect(second.style.shadowDistance == 14)
        #expect(second.style.shadowAngle == 35)
        #expect(!locked.style.hasEffects)
        #expect(!group.style.hasEffects)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        viewModel.selectLayer(groupID)
        #expect(!viewModel.canEditSelectedLayerStyle)
    }

    @Test func imageEditorCopiesPastesAndClearsLayerStyleAcrossEditableSelection() async throws {
        let canvasSize = NSSize(width: 32, height: 24)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .black, size: canvasSize)
        ) { _ in }

        viewModel.addLayer()
        let sourceID = try #require(viewModel.document.selectedLayerID)
        viewModel.foregroundColor = .systemYellow
        viewModel.toggleSelectedLayerStroke()
        viewModel.setSelectedLayerStrokeWidth(11)
        viewModel.setSelectedLayerStrokePosition(.inside)
        viewModel.setSelectedLayerStrokeOpacity(0.4)
        viewModel.toggleSelectedLayerShadow()
        viewModel.setSelectedLayerShadowDistance(17)
        viewModel.setSelectedLayerShadowAngle(30)
        let sourceIndex = try #require(viewModel.document.layers.firstIndex { $0.id == sourceID })
        let sourceStyle = viewModel.document.layers[sourceIndex].style

        #expect(viewModel.canCopySelectedLayerStyle)
        viewModel.copySelectedLayerStyle()
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerStyleCopied"))

        viewModel.addLayer()
        let editableTargetID = try #require(viewModel.document.selectedLayerID)
        viewModel.addLayer()
        let lockedTargetID = try #require(viewModel.document.selectedLayerID)
        let lockedTargetIndex = try #require(viewModel.document.layers.firstIndex { $0.id == lockedTargetID })
        viewModel.document.layers[lockedTargetIndex].isLocked = true

        viewModel.document.selectedLayerID = editableTargetID
        viewModel.document.selectedLayerIDs = [editableTargetID, lockedTargetID]

        #expect(viewModel.canPasteLayerStyleToSelectedLayers)
        viewModel.pasteLayerStyleToSelectedLayers()

        let editableIndex = try #require(viewModel.document.layers.firstIndex { $0.id == editableTargetID })
        let lockedIndexAfterPaste = try #require(viewModel.document.layers.firstIndex { $0.id == lockedTargetID })
        let pastedStyle = viewModel.document.layers[editableIndex].style
        let lockedStyle = viewModel.document.layers[lockedIndexAfterPaste].style

        #expect(pastedStyle.strokeEnabled)
        #expect(pastedStyle.strokeWidth == sourceStyle.strokeWidth)
        #expect(pastedStyle.strokePosition == sourceStyle.strokePosition)
        #expect(pastedStyle.strokeOpacity == sourceStyle.strokeOpacity)
        #expect(pastedStyle.shadowEnabled)
        #expect(pastedStyle.shadowDistance == sourceStyle.shadowDistance)
        #expect(pastedStyle.shadowAngle == sourceStyle.shadowAngle)
        #expect(!lockedStyle.hasEffects)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStylePaste"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerStylePasted", 1))

        #expect(viewModel.canClearSelectedLayerStyles)
        viewModel.clearSelectedLayerStyles()

        let clearedEditableIndex = try #require(viewModel.document.layers.firstIndex { $0.id == editableTargetID })
        let lockedIndexAfterClear = try #require(viewModel.document.layers.firstIndex { $0.id == lockedTargetID })
        #expect(!viewModel.document.layers[clearedEditableIndex].style.hasEffects)
        #expect(!viewModel.document.layers[lockedIndexAfterClear].style.hasEffects)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyleClear"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerStyleCleared", 1))
    }

    @Test func layerStylePasteAndClearCountOnlyChangedEditableTargetsAndSkipNoOps() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .black, size: NSSize(width: 32, height: 24))
        ) { _ in }
        let sourceID = try #require(viewModel.document.selectedLayerID)
        let sourceIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[sourceIndex].style.strokeEnabled = true
        viewModel.document.layers[sourceIndex].style.strokeWidth = 9
        let copiedStyle = viewModel.document.layers[sourceIndex].style
        #expect(viewModel.copySelectedLayerStyle())

        viewModel.addLayer()
        let matchingID = try #require(viewModel.document.selectedLayerID)
        let matchingIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[matchingIndex].style = copiedStyle

        viewModel.addLayer()
        let changedID = try #require(viewModel.document.selectedLayerID)
        let changedIndex = try #require(viewModel.document.selectedLayerIndex)

        viewModel.addLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        let lockedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[lockedIndex].style.shadowEnabled = true
        viewModel.document.layers[lockedIndex].isLocked = true

        viewModel.document.selectedLayerID = sourceID
        viewModel.document.selectedLayerIDs = [sourceID, matchingID, changedID, lockedID]
        let historyBeforePaste = viewModel.document.history.count

        #expect(viewModel.canPasteLayerStyleToSelectedLayers)
        #expect(viewModel.pasteLayerStyleToSelectedLayers() == 1)
        #expect(viewModel.document.layers[changedIndex].style.strokeEnabled)
        #expect(viewModel.document.layers[changedIndex].style.strokeWidth == 9)
        #expect(viewModel.document.layers[matchingIndex].style.strokeEnabled)
        #expect(viewModel.document.layers[lockedIndex].style.shadowEnabled)
        #expect(viewModel.document.history.count == historyBeforePaste + 1)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerStylePasted", 1))

        let historyAfterPaste = viewModel.document.history.count
        #expect(!viewModel.canPasteLayerStyleToSelectedLayers)
        #expect(viewModel.pasteLayerStyleToSelectedLayers() == 0)
        #expect(viewModel.document.history.count == historyAfterPaste)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))

        viewModel.document.selectedLayerID = matchingID
        viewModel.document.selectedLayerIDs = [matchingID, changedID, lockedID]
        #expect(viewModel.canClearSelectedLayerStyles)
        #expect(viewModel.clearSelectedLayerStyles() == 2)
        #expect(!viewModel.document.layers[matchingIndex].style.hasConfiguredEffects)
        #expect(!viewModel.document.layers[changedIndex].style.hasConfiguredEffects)
        #expect(viewModel.document.layers[lockedIndex].style.shadowEnabled)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerStyleCleared", 2))

        let historyAfterClear = viewModel.document.history.count
        #expect(!viewModel.canClearSelectedLayerStyles)
        #expect(viewModel.clearSelectedLayerStyles() == 0)
        #expect(viewModel.document.history.count == historyAfterClear)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @Test func imageEditorBlendIfUnderlyingHidesLayerOverBackdropLuminanceOutsideRange() async throws {
        let canvasSize = NSSize(width: 16, height: 8)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: horizontalGrayscaleImage(size: canvasSize)
        ) { _ in }

        viewModel.addLayer()
        viewModel.replaceSelectedLayerImageForTesting(
            solidImage(color: .systemRed, size: canvasSize),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.setSelectedLayerBlendIfUnderlyingBlack(0.5)
        viewModel.commitSelectedLayerBlendIfChange()

        let darkBackdrop = try #require(viewModel.currentImage.color(at: CGPoint(x: 2, y: 4))?.usingColorSpace(.deviceRGB))
        let brightBackdrop = try #require(viewModel.currentImage.color(at: CGPoint(x: 14, y: 4))?.usingColorSpace(.deviceRGB))
        let layer = try #require(viewModel.document.selectedLayer)

        #expect(darkBackdrop.redComponent < 0.25)
        #expect(darkBackdrop.greenComponent < 0.25)
        #expect(darkBackdrop.blueComponent < 0.25)
        #expect(brightBackdrop.redComponent > 0.75)
        #expect(brightBackdrop.greenComponent < 0.25)
        #expect(brightBackdrop.blueComponent < 0.25)
        #expect(layer.blendIfUnderlyingBlack == 0.5)
        #expect(layer.blendIfUnderlyingWhite == 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerBlendIf"))
    }

    @Test func imageEditorBlendIfHidesSourceLuminanceOutsideSelectedRange() async throws {
        let canvasSize = NSSize(width: 16, height: 8)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .systemBlue, size: canvasSize)
        ) { _ in }

        viewModel.addLayer()
        viewModel.replaceSelectedLayerImageForTesting(
            horizontalRedGradientImage(size: canvasSize),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.setSelectedLayerBlendIfSourceBlack(0.5)
        viewModel.commitSelectedLayerBlendIfChange()

        let darkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 2, y: 4))?.usingColorSpace(.deviceRGB))
        let brightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 14, y: 4))?.usingColorSpace(.deviceRGB))
        let layer = try #require(viewModel.document.selectedLayer)

        #expect(darkSide.blueComponent > 0.75)
        #expect(darkSide.redComponent < 0.25)
        #expect(brightSide.redComponent > 0.75)
        #expect(brightSide.blueComponent < 0.25)
        #expect(layer.blendIfSourceBlack == 0.5)
        #expect(layer.blendIfSourceWhite == 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerBlendIf"))
    }

    @Test func imageEditorDissolveBlendModeDithersLayerOpacityDeterministically() async throws {
        let canvasSize = NSSize(width: 16, height: 16)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .systemBlue, size: canvasSize)
        ) { _ in }

        viewModel.addLayer()
        viewModel.replaceSelectedLayerImageForTesting(
            solidImage(color: .systemRed, size: canvasSize),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.setSelectedLayerBlendMode(.dissolve)
        viewModel.setSelectedLayerOpacity(0.5)

        let firstComposite = viewModel.currentImage
        let secondComposite = viewModel.currentImage
        var redPixels = 0
        var bluePixels = 0
        var blendedPixels = 0

        for y in 0..<Int(canvasSize.height) {
            for x in 0..<Int(canvasSize.width) {
                let point = CGPoint(x: x, y: y)
                let firstColor = try #require(firstComposite.color(at: point)?.usingColorSpace(.deviceRGB))
                let secondColor = try #require(secondComposite.color(at: point)?.usingColorSpace(.deviceRGB))
                #expect(abs(firstColor.redComponent - secondColor.redComponent) < 0.01)
                #expect(abs(firstColor.greenComponent - secondColor.greenComponent) < 0.01)
                #expect(abs(firstColor.blueComponent - secondColor.blueComponent) < 0.01)

                if firstColor.redComponent > 0.8 && firstColor.blueComponent < 0.25 {
                    redPixels += 1
                } else if firstColor.blueComponent > 0.8 && firstColor.redComponent < 0.25 {
                    bluePixels += 1
                } else {
                    blendedPixels += 1
                }
            }
        }

        #expect(redPixels > 80)
        #expect(bluePixels > 80)
        #expect(blendedPixels == 0)
        #expect(viewModel.selectedLayerBlendMode == .dissolve)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerBlendMode"))
    }

    @Test func imageEditorColorOverlayIsNonDestructiveAndBakesOnMerge() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.document.layers[0].isLocked = false
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        viewModel.foregroundColor = NSColor(
            calibratedRed: 1,
            green: 0,
            blue: 0,
            alpha: 1
        )
        viewModel.setSelectedLayerColorOverlayOpacity(1)

        let layerPixelsAfterStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedOverlay = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(viewModel.selectedLayerHasColorOverlay)
        #expect(compositedOverlay.redComponent > 0.75)
        #expect(compositedOverlay.greenComponent < 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        viewModel.mergeSelectedLayerDown()

        let mergedLayer = try #require(viewModel.document.selectedLayer)
        let bakedOverlay = try #require(mergedLayer.image.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(!mergedLayer.hasLayerEffects)
        #expect(bakedOverlay.redComponent > 0.75)
        #expect(bakedOverlay.greenComponent < 0.25)
    }

    @Test func imageEditorColorOverlayRemainsVisibleWhenFillOpacityIsZero() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))

        viewModel.foregroundColor = .systemRed
        viewModel.setSelectedLayerColorOverlayOpacity(1)
        viewModel.setSelectedLayerFillOpacity(0)

        let center = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(center.redComponent > 0.75)
        #expect(center.blueComponent < 0.35)
    }

    @Test func imageEditorStrokeSupportsGradientAndPatternFillTypesAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .black, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.foregroundColor = .systemRed
        viewModel.backgroundColor = .systemBlue
        viewModel.setSelectedLayerStrokeWidth(6)
        viewModel.setSelectedLayerStrokeFillType(.gradient)
        viewModel.setSelectedLayerStrokeGradientStyle(.linear)
        viewModel.setSelectedLayerStrokeGradientAngle(0)

        let gradientLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterGradientStroke = try #require(gradientLayer.image.qingtuPNGData())
        let gradientLeft = try #require(viewModel.currentImage.color(at: CGPoint(x: 21, y: 30))?.usingColorSpace(.deviceRGB))
        let gradientRight = try #require(viewModel.currentImage.color(at: CGPoint(x: 59, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(gradientLayer.style.strokeEnabled)
        #expect(gradientLayer.style.strokeFillType == .gradient)
        #expect(gradientLayer.style.strokeGradientStyle == .linear)
        #expect(gradientLayer.style.strokeGradientAngle == 0)
        #expect(layerPixelsAfterGradientStroke == layerPixelsBeforeStyle)
        #expect(gradientLeft.redComponent > gradientRight.redComponent + 0.20)
        #expect(gradientRight.blueComponent > gradientLeft.blueComponent + 0.20)

        viewModel.setSelectedLayerStrokeFillType(.pattern)
        viewModel.setSelectedLayerStrokePatternKind(.dots)
        viewModel.setSelectedLayerStrokePatternScale(12)

        let patternLayer = try #require(viewModel.document.selectedLayer)
        let patternPixel = try #require(viewModel.currentImage.color(at: CGPoint(x: 21, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(patternLayer.style.strokeFillType == .pattern)
        #expect(patternLayer.style.strokePatternKind == .dots)
        #expect(patternLayer.style.strokePatternScale == 12)
        #expect(patternPixel.alphaComponent > 0.9)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == patternLayer.id })
        #expect(restoredLayer.style.strokeEnabled)
        #expect(restoredLayer.style.strokeFillType == .pattern)
        #expect(restoredLayer.style.strokePatternKind == .dots)
        #expect(restoredLayer.style.strokePatternScale == 12)
    }

    @Test func imageEditorDropShadowRemainsVisibleWhenFillOpacityIsZero() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseColor = NSColor(srgbRed: 0.04, green: 0.1, blue: 0.92, alpha: 1)
        let baseImage = solidImage(color: baseColor, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerShadowOpacity(1)
        viewModel.setSelectedLayerShadowBlur(0)
        viewModel.setSelectedLayerShadowSpread(0)
        viewModel.setSelectedLayerShadowDistance(12)
        viewModel.setSelectedLayerShadowAngle(0)
        viewModel.setSelectedLayerFillOpacity(0)
        viewModel.commitSelectedLayerFillOpacityChange()

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let hiddenFill = try #require(viewModel.currentImage.color(at: CGPoint(x: 26, y: 30))?.usingColorSpace(.deviceRGB))
        let visibleShadow = try #require(viewModel.currentImage.color(at: CGPoint(x: 64, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(styledLayer.style.shadowEnabled)
        #expect(styledLayer.fillOpacity == 0)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(hiddenFill.blueComponent > 0.75)
        #expect(hiddenFill.greenComponent < 0.25)
        #expect(visibleShadow.blueComponent < 0.35)
        #expect(visibleShadow.redComponent < 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFillOpacity"))
    }

    @Test func imageEditorDropShadowSpreadExpandsShadowBeforeBlur() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let outsideBeforeSpread = try #require(viewModel.currentImage.color(at: CGPoint(x: 21, y: 30))?.usingColorSpace(.deviceRGB))

        viewModel.setSelectedLayerShadowOpacity(1)
        viewModel.setSelectedLayerShadowBlur(0)
        viewModel.setSelectedLayerShadowOffsetX(0)
        viewModel.setSelectedLayerShadowOffsetY(0)
        viewModel.setSelectedLayerShadowSpread(6)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let outsideAfterSpread = try #require(viewModel.currentImage.color(at: CGPoint(x: 21, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(styledLayer.style.shadowEnabled)
        #expect(styledLayer.style.shadowSpread == 6)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(outsideBeforeSpread.blueComponent > 0.75)
        #expect(outsideAfterSpread.blueComponent < 0.35)
        #expect(outsideAfterSpread.redComponent < 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func imageEditorDropShadowNoiseVariesShadowAlphaAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerShadowOpacity(1)
        viewModel.setSelectedLayerShadowBlur(0)
        viewModel.setSelectedLayerShadowSpread(0)
        viewModel.setSelectedLayerShadowDistance(12)
        viewModel.setSelectedLayerShadowAngle(0)
        viewModel.setSelectedLayerShadowNoise(0)
        let smoothShadowData = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.setSelectedLayerShadowNoise(1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let noisyShadowData = try #require(viewModel.currentImage.qingtuPNGData())
        let lowNoiseShadow = try #require(viewModel.currentImage.color(at: CGPoint(x: 64, y: 30))?.usingColorSpace(.deviceRGB))
        let highNoiseShadow = try #require(viewModel.currentImage.color(at: CGPoint(x: 64, y: 36))?.usingColorSpace(.deviceRGB))

        #expect(styledLayer.style.shadowEnabled)
        #expect(styledLayer.style.shadowNoise == 1)
        #expect(viewModel.selectedLayerShadowNoise == 1)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(noisyShadowData != smoothShadowData)
        #expect(lowNoiseShadow.blueComponent > highNoiseShadow.blueComponent + 0.45)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.shadowEnabled)
        #expect(restoredLayer.style.shadowNoise == 1)
    }

    @Test func imageEditorOuterGlowNoiseChangesGlowAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let glowColor = NSColor(srgbRed: 0.92, green: 0.16, blue: 0.08, alpha: 1)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerOuterGlowOpacity(1)
        viewModel.setSelectedLayerOuterGlowColor(glowColor)
        viewModel.setSelectedLayerOuterGlowBlur(0)
        viewModel.setSelectedLayerOuterGlowSpread(8)
        #expect(viewModel.setSelectedLayerOuterGlowNoise(0) == 0)
        let smoothGlowData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.setSelectedLayerOuterGlowNoise(1) == 1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let noisyGlowData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(styledLayer.style.outerGlowEnabled)
        #expect(styledLayer.style.outerGlowNoise == 1)
        #expect(styledLayer.style.outerGlowOpacity == 1)
        #expect(styledLayer.style.outerGlowBlur == 0)
        #expect(styledLayer.style.outerGlowSpread == 8)
        #expect(styledLayer.style.outerGlowColor.isEqual(glowColor))
        #expect(viewModel.selectedLayerOuterGlowNoise == 1)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(noisyGlowData != smoothGlowData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.outerGlowEnabled)
        #expect(restoredLayer.style.outerGlowNoise == 1)
        #expect(restoredLayer.style.outerGlowOpacity == 1)
        #expect(restoredLayer.style.outerGlowBlur == 0)
        #expect(restoredLayer.style.outerGlowSpread == 8)
        #expect(restoredLayer.style.outerGlowColor.isEqual(glowColor))
    }

    @Test func imageEditorOuterGlowOpacityChangesCompositeWithoutReplacingExistingColor() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            layerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerPixelsBeforeStyle = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )

        viewModel.setSelectedLayerOuterGlowColor(.systemRed)
        viewModel.setSelectedLayerOuterGlowBlur(0)
        viewModel.setSelectedLayerOuterGlowSpread(8)
        #expect(viewModel.setSelectedLayerOuterGlowOpacity(0.05) == 1)
        let faintGlow = try #require(viewModel.currentImage.qingtuPNGData())
        let originalColor = ImageEditorProjectColor(
            color: try #require(viewModel.document.selectedLayer).style.outerGlowColor
        )

        viewModel.foregroundColor = .systemYellow
        #expect(viewModel.setSelectedLayerOuterGlowOpacity(1) == 1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let strongGlow = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(styledLayer.style.outerGlowEnabled)
        #expect(styledLayer.style.outerGlowOpacity == 1)
        #expect(ImageEditorProjectColor(color: styledLayer.style.outerGlowColor) == originalColor)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(strongGlow != faintGlow)
    }

    @Test func imageEditorOuterGlowColorChangesCompositeAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let redColor = NSColor(srgbRed: 0.9, green: 0.08, blue: 0.05, alpha: 1)
        let yellowColor = NSColor(srgbRed: 0.95, green: 0.78, blue: 0.04, alpha: 1)
        let baseImage = solidImage(color: .black, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .white)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            layerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerPixelsBeforeStyle = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )

        viewModel.setSelectedLayerOuterGlowOpacity(1)
        viewModel.setSelectedLayerOuterGlowBlur(0)
        viewModel.setSelectedLayerOuterGlowSpread(8)
        #expect(viewModel.setSelectedLayerOuterGlowColor(redColor) == 1)
        let redGlow = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.setSelectedLayerOuterGlowColor(yellowColor) == 1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let yellowGlow = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(styledLayer.style.outerGlowEnabled)
        #expect(styledLayer.style.outerGlowColor.isEqual(yellowColor))
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(yellowGlow != redGlow)

        let historyCount = viewModel.document.history.count
        #expect(viewModel.setSelectedLayerOuterGlowColor(yellowColor) == 0)
        #expect(viewModel.document.history.count == historyCount)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.outerGlowEnabled)
        #expect(restoredLayer.style.outerGlowColor.isEqual(yellowColor))
    }

    @Test func imageEditorOuterGlowBlurChangesFalloffAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let glowColor = NSColor(srgbRed: 0.92, green: 0.12, blue: 0.08, alpha: 1)
        let baseImage = solidImage(color: .black, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .white)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            layerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerPixelsBeforeStyle = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )

        viewModel.setSelectedLayerOuterGlowOpacity(1)
        viewModel.setSelectedLayerOuterGlowColor(glowColor)
        viewModel.setSelectedLayerOuterGlowSpread(0)
        #expect(viewModel.setSelectedLayerOuterGlowBlur(0) == 1)
        let hardGlow = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.setSelectedLayerOuterGlowBlur(12) == 1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let softGlow = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(styledLayer.style.outerGlowEnabled)
        #expect(styledLayer.style.outerGlowBlur == 12)
        #expect(styledLayer.style.outerGlowColor.isEqual(glowColor))
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(softGlow != hardGlow)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.outerGlowEnabled)
        #expect(restoredLayer.style.outerGlowBlur == 12)
        #expect(restoredLayer.style.outerGlowColor.isEqual(glowColor))
    }

    @Test func imageEditorOuterGlowSpreadExpandsGlowAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let glowColor = NSColor(srgbRed: 0.92, green: 0.12, blue: 0.08, alpha: 1)
        let baseImage = solidImage(color: .black, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .white)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            layerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerPixelsBeforeStyle = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )

        viewModel.setSelectedLayerOuterGlowOpacity(1)
        viewModel.setSelectedLayerOuterGlowColor(glowColor)
        viewModel.setSelectedLayerOuterGlowBlur(0)
        #expect(viewModel.setSelectedLayerOuterGlowSpread(0) == 1)
        let compactGlow = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.setSelectedLayerOuterGlowSpread(8) == 1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let expandedGlow = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(styledLayer.style.outerGlowEnabled)
        #expect(styledLayer.style.outerGlowSpread == 8)
        #expect(styledLayer.style.outerGlowBlur == 0)
        #expect(styledLayer.style.outerGlowColor.isEqual(glowColor))
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(expandedGlow != compactGlow)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.outerGlowEnabled)
        #expect(restoredLayer.style.outerGlowSpread == 8)
        #expect(restoredLayer.style.outerGlowBlur == 0)
        #expect(restoredLayer.style.outerGlowColor.isEqual(glowColor))
    }

    @Test func imageEditorOuterGlowContourChangesAlphaFalloffAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let glowColor = NSColor(srgbRed: 0.92, green: 0.16, blue: 0.08, alpha: 1)
        let baseImage = solidImage(color: .clear, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .white)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            layerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerPixelsBeforeStyle = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )

        viewModel.setSelectedLayerOuterGlowOpacity(1)
        viewModel.setSelectedLayerOuterGlowColor(glowColor)
        viewModel.setSelectedLayerOuterGlowBlur(10)
        viewModel.setSelectedLayerOuterGlowSpread(0)
        viewModel.setSelectedLayerOuterGlowNoise(0)
        #expect(viewModel.setSelectedLayerOuterGlowContour(.linear) == 0)
        let linearGlow = viewModel.currentImage
        let linearGlowData = try #require(linearGlow.qingtuPNGData())

        #expect(viewModel.setSelectedLayerOuterGlowContour(.steep) == 1)
        let steepGlow = viewModel.currentImage
        let steepGlowData = try #require(steepGlow.qingtuPNGData())

        var maximumAlphaIncrease: CGFloat = 0
        for x in 0..<24 {
            let point = CGPoint(x: CGFloat(x), y: 30)
            let linearAlpha = try #require(
                linearGlow.color(at: point)?.usingColorSpace(.deviceRGB)?.alphaComponent
            )
            let steepAlpha = try #require(
                steepGlow.color(at: point)?.usingColorSpace(.deviceRGB)?.alphaComponent
            )
            maximumAlphaIncrease = max(maximumAlphaIncrease, steepAlpha - linearAlpha)
        }

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        #expect(styledLayer.style.outerGlowEnabled)
        #expect(styledLayer.style.outerGlowContour == .steep)
        #expect(styledLayer.style.outerGlowOpacity == 1)
        #expect(styledLayer.style.outerGlowBlur == 10)
        #expect(styledLayer.style.outerGlowSpread == 0)
        #expect(styledLayer.style.outerGlowNoise == 0)
        #expect(styledLayer.style.outerGlowColor.isEqual(glowColor))
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(steepGlowData != linearGlowData)
        #expect(maximumAlphaIncrease > 0.05)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.outerGlowEnabled)
        #expect(restoredLayer.style.outerGlowContour == .steep)
        #expect(restoredLayer.style.outerGlowOpacity == 1)
        #expect(restoredLayer.style.outerGlowBlur == 10)
        #expect(restoredLayer.style.outerGlowSpread == 0)
        #expect(restoredLayer.style.outerGlowNoise == 0)
        #expect(restoredLayer.style.outerGlowColor.isEqual(glowColor))
    }

    @Test func imageEditorInnerGlowContourChangesFalloffAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let glowColor = NSColor(srgbRed: 0.9, green: 0.08, blue: 0.12, alpha: 1)
        let baseImage = solidImage(color: .clear, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .white)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            layerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerPixelsBeforeStyle = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )

        viewModel.setSelectedLayerInnerGlowOpacity(1)
        viewModel.setSelectedLayerInnerGlowColor(glowColor)
        viewModel.setSelectedLayerInnerGlowBlur(10)
        viewModel.setSelectedLayerInnerGlowChoke(0)
        viewModel.setSelectedLayerInnerGlowNoise(0)
        viewModel.setSelectedLayerInnerGlowSource(.edge)
        #expect(viewModel.setSelectedLayerInnerGlowContour(.linear) == 0)
        let linearGlow = viewModel.currentImage
        let linearGlowData = try #require(linearGlow.qingtuPNGData())

        #expect(viewModel.setSelectedLayerInnerGlowContour(.steep) == 1)
        let steepGlow = viewModel.currentImage
        let steepGlowData = try #require(steepGlow.qingtuPNGData())

        var maximumGreenReduction: CGFloat = 0
        for x in 24...40 {
            let point = CGPoint(x: CGFloat(x), y: 30)
            let linearColor = try #require(
                linearGlow.color(at: point)?.usingColorSpace(.deviceRGB)
            )
            let steepColor = try #require(
                steepGlow.color(at: point)?.usingColorSpace(.deviceRGB)
            )
            maximumGreenReduction = max(
                maximumGreenReduction,
                linearColor.greenComponent - steepColor.greenComponent
            )
        }

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        #expect(styledLayer.style.innerGlowEnabled)
        #expect(styledLayer.style.innerGlowContour == .steep)
        #expect(styledLayer.style.innerGlowOpacity == 1)
        #expect(styledLayer.style.innerGlowBlur == 10)
        #expect(styledLayer.style.innerGlowChoke == 0)
        #expect(styledLayer.style.innerGlowNoise == 0)
        #expect(styledLayer.style.innerGlowSource == .edge)
        #expect(styledLayer.style.innerGlowColor.isEqual(glowColor))
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(steepGlowData != linearGlowData)
        #expect(maximumGreenReduction > 0.03)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.innerGlowEnabled)
        #expect(restoredLayer.style.innerGlowContour == .steep)
        #expect(restoredLayer.style.innerGlowOpacity == 1)
        #expect(restoredLayer.style.innerGlowBlur == 10)
        #expect(restoredLayer.style.innerGlowChoke == 0)
        #expect(restoredLayer.style.innerGlowNoise == 0)
        #expect(restoredLayer.style.innerGlowSource == .edge)
        #expect(restoredLayer.style.innerGlowColor.isEqual(glowColor))
    }

    @Test func imageEditorInnerGlowRangeChangesFalloffAndPreservesLegacyProjects() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let glowColor = NSColor(srgbRed: 0.88, green: 0.06, blue: 0.1, alpha: 1)
        let baseImage = solidImage(color: .clear, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .white)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            layerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerPixelsBeforeStyle = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )

        viewModel.setSelectedLayerInnerGlowOpacity(1)
        viewModel.setSelectedLayerInnerGlowColor(glowColor)
        viewModel.setSelectedLayerInnerGlowBlur(10)
        viewModel.setSelectedLayerInnerGlowChoke(0)
        viewModel.setSelectedLayerInnerGlowNoise(0)
        viewModel.setSelectedLayerInnerGlowSource(.edge)
        viewModel.setSelectedLayerInnerGlowContour(.linear)
        #expect(viewModel.setSelectedLayerInnerGlowRange(1) == 1)
        let fullRange = viewModel.currentImage
        let fullRangeData = try #require(fullRange.qingtuPNGData())

        #expect(viewModel.setSelectedLayerInnerGlowRange(0.25) == 1)
        let narrowRange = viewModel.currentImage
        let narrowRangeData = try #require(narrowRange.qingtuPNGData())

        var maximumGreenReduction: CGFloat = 0
        for x in 24...40 {
            let point = CGPoint(x: CGFloat(x), y: 30)
            let fullColor = try #require(
                fullRange.color(at: point)?.usingColorSpace(.deviceRGB)
            )
            let narrowColor = try #require(
                narrowRange.color(at: point)?.usingColorSpace(.deviceRGB)
            )
            maximumGreenReduction = max(
                maximumGreenReduction,
                fullColor.greenComponent - narrowColor.greenComponent
            )
        }

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        #expect(styledLayer.style.innerGlowEnabled)
        #expect(styledLayer.style.innerGlowRange == 0.25)
        #expect(styledLayer.style.innerGlowContour == .linear)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(narrowRangeData != fullRangeData)
        #expect(maximumGreenReduction > 0.03)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.innerGlowRange == 0.25)

        let encodedStyle = try JSONEncoder().encode(ImageEditorProjectLayerStyle(style: styledLayer.style))
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedStyle) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "innerGlowRange")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyStyle = try JSONDecoder().decode(ImageEditorProjectLayerStyle.self, from: legacyData)
        #expect(legacyStyle.layerStyle.innerGlowRange == 1)
    }

    @Test func imageEditorLayerEffectContoursChangeFalloffAndRoundTripProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerShadowOpacity(1)
        viewModel.setSelectedLayerShadowBlur(8)
        viewModel.setSelectedLayerShadowDistance(12)
        viewModel.setSelectedLayerShadowAngle(0)
        viewModel.setSelectedLayerShadowContour(.linear)
        let linearShadowData = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.setSelectedLayerShadowContour(.ring)
        let ringShadowData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.setSelectedLayerInnerShadowOpacity(1)
        viewModel.setSelectedLayerInnerShadowBlur(8)
        viewModel.setSelectedLayerInnerShadowDistance(10)
        viewModel.setSelectedLayerInnerShadowAngle(0)
        viewModel.setSelectedLayerInnerShadowContour(.linear)
        let linearInnerShadowData = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.setSelectedLayerInnerShadowContour(.cone)
        let coneInnerShadowData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.setSelectedLayerOuterGlowOpacity(1)
        viewModel.setSelectedLayerOuterGlowBlur(8)
        viewModel.setSelectedLayerOuterGlowSpread(6)
        viewModel.setSelectedLayerOuterGlowContour(.linear)
        let linearGlowData = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.setSelectedLayerOuterGlowContour(.steep)
        let steepGlowData = try #require(viewModel.currentImage.qingtuPNGData())

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        #expect(styledLayer.style.shadowContour == .ring)
        #expect(styledLayer.style.innerShadowContour == .cone)
        #expect(styledLayer.style.outerGlowContour == .steep)
        #expect(viewModel.selectedLayerShadowContour == .ring)
        #expect(viewModel.selectedLayerInnerShadowContour == .cone)
        #expect(viewModel.selectedLayerOuterGlowContour == .steep)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(ringShadowData != linearShadowData)
        #expect(coneInnerShadowData != linearInnerShadowData)
        #expect(steepGlowData != linearGlowData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.shadowContour == .ring)
        #expect(restoredLayer.style.innerShadowContour == .cone)
        #expect(restoredLayer.style.outerGlowContour == .steep)
    }

    @Test func imageEditorInnerGlowColorChangesCompositeAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let blueGlow = NSColor(srgbRed: 0.08, green: 0.22, blue: 0.92, alpha: 1)
        let redGlow = NSColor(srgbRed: 0.92, green: 0.12, blue: 0.08, alpha: 1)
        let baseImage = solidImage(color: .black, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .white)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            layerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerPixelsBeforeStyle = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )

        viewModel.setSelectedLayerInnerGlowOpacity(1)
        viewModel.setSelectedLayerInnerGlowBlur(0)
        viewModel.setSelectedLayerInnerGlowChoke(0)
        viewModel.setSelectedLayerInnerGlowNoise(0)
        viewModel.setSelectedLayerInnerGlowSource(.edge)
        #expect(viewModel.setSelectedLayerInnerGlowColor(blueGlow) == 1)
        let blueComposite = try #require(viewModel.currentImage.qingtuPNGData())
        let blueEdge = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB)
        )

        #expect(viewModel.setSelectedLayerInnerGlowColor(redGlow) == 1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let redComposite = try #require(viewModel.currentImage.qingtuPNGData())
        let redEdge = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB)
        )
        #expect(styledLayer.style.innerGlowEnabled)
        #expect(styledLayer.style.innerGlowColor.isEqual(redGlow))
        #expect(styledLayer.style.innerGlowOpacity == 1)
        #expect(styledLayer.style.innerGlowBlur == 0)
        #expect(styledLayer.style.innerGlowChoke == 0)
        #expect(styledLayer.style.innerGlowNoise == 0)
        #expect(styledLayer.style.innerGlowSource == .edge)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(redComposite != blueComposite)
        #expect(blueEdge.blueComponent > redEdge.blueComponent + 0.5)
        #expect(redEdge.redComponent > blueEdge.redComponent + 0.5)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.innerGlowEnabled)
        #expect(restoredLayer.style.innerGlowColor.isEqual(redGlow))
        #expect(restoredLayer.style.innerGlowOpacity == 1)
        #expect(restoredLayer.style.innerGlowBlur == 0)
        #expect(restoredLayer.style.innerGlowChoke == 0)
        #expect(restoredLayer.style.innerGlowNoise == 0)
        #expect(restoredLayer.style.innerGlowSource == .edge)
    }

    @Test func imageEditorInnerGlowOpacityChangesCompositeWithoutReplacingExistingColor() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let glowColor = NSColor(srgbRed: 0.92, green: 0.12, blue: 0.08, alpha: 1)
        let baseImage = solidImage(color: .black, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .white)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            layerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerPixelsBeforeStyle = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )

        viewModel.setSelectedLayerInnerGlowColor(glowColor)
        viewModel.setSelectedLayerInnerGlowBlur(0)
        viewModel.setSelectedLayerInnerGlowChoke(0)
        viewModel.setSelectedLayerInnerGlowNoise(0)
        viewModel.setSelectedLayerInnerGlowSource(.edge)
        #expect(viewModel.setSelectedLayerInnerGlowOpacity(0.05) == 1)
        let faintGlow = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB)
        )
        let faintGlowData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.setSelectedLayerInnerGlowOpacity(1) == 1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let strongGlow = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB)
        )
        let strongGlowData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(styledLayer.style.innerGlowEnabled)
        #expect(styledLayer.style.innerGlowOpacity == 1)
        #expect(styledLayer.style.innerGlowBlur == 0)
        #expect(styledLayer.style.innerGlowChoke == 0)
        #expect(styledLayer.style.innerGlowNoise == 0)
        #expect(styledLayer.style.innerGlowSource == .edge)
        #expect(styledLayer.style.innerGlowColor.isEqual(glowColor))
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(strongGlowData != faintGlowData)
        #expect(strongGlow.greenComponent < faintGlow.greenComponent - 0.5)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.innerGlowEnabled)
        #expect(restoredLayer.style.innerGlowOpacity == 1)
        #expect(restoredLayer.style.innerGlowBlur == 0)
        #expect(restoredLayer.style.innerGlowChoke == 0)
        #expect(restoredLayer.style.innerGlowNoise == 0)
        #expect(restoredLayer.style.innerGlowSource == .edge)
        #expect(restoredLayer.style.innerGlowColor.isEqual(glowColor))
    }

    @Test func imageEditorInnerGlowNoiseChangesGlowAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerInnerGlowOpacity(1)
        viewModel.setSelectedLayerInnerGlowBlur(0)
        viewModel.setSelectedLayerInnerGlowChoke(8)
        viewModel.setSelectedLayerInnerGlowNoise(0)
        let smoothGlowData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.setSelectedLayerInnerGlowNoise(1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let noisyGlowData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(styledLayer.style.innerGlowEnabled)
        #expect(styledLayer.style.innerGlowNoise == 1)
        #expect(viewModel.selectedLayerInnerGlowNoise == 1)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(noisyGlowData != smoothGlowData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        viewModel.setSelectedLayerInnerGlowSource(.center)
        let centeredLayer = try #require(viewModel.document.selectedLayer)
        #expect(centeredLayer.style.innerGlowSource == .center)
        #expect(viewModel.selectedLayerInnerGlowSource == .center)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == centeredLayer.id })
        #expect(restoredLayer.style.innerGlowEnabled)
        #expect(restoredLayer.style.innerGlowNoise == 1)
        #expect(restoredLayer.style.innerGlowSource == .center)
    }

    @Test func imageEditorInnerGlowSourceChangesRenderedGlow() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerInnerGlowOpacity(1)
        viewModel.setSelectedLayerInnerGlowBlur(0)
        viewModel.setSelectedLayerInnerGlowChoke(8)
        viewModel.setSelectedLayerInnerGlowSource(.edge)
        let edgeGlowData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.setSelectedLayerInnerGlowSource(.center)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let centerGlowData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(styledLayer.style.innerGlowSource == .center)
        #expect(viewModel.selectedLayerInnerGlowSource == .center)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(centerGlowData != edgeGlowData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func imageEditorDropShadowAngleAndDistanceMoveShadowDirectionally() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerShadowOpacity(1)
        viewModel.setSelectedLayerShadowBlur(0)
        viewModel.setSelectedLayerShadowSpread(0)
        viewModel.setSelectedLayerShadowDistance(12)
        viewModel.setSelectedLayerShadowAngle(0)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let rightShadow = try #require(viewModel.currentImage.color(at: CGPoint(x: 64, y: 30))?.usingColorSpace(.deviceRGB))
        let leftOutside = try #require(viewModel.currentImage.color(at: CGPoint(x: 20, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(styledLayer.style.shadowEnabled)
        #expect(styledLayer.style.shadowDistance == 12)
        #expect(styledLayer.style.shadowAngle == 0)
        #expect(abs(styledLayer.style.shadowOffset.width - 12) < 0.001)
        #expect(abs(styledLayer.style.shadowOffset.height) < 0.001)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(rightShadow.blueComponent < 0.35)
        #expect(rightShadow.redComponent < 0.25)
        #expect(leftOutside.blueComponent > 0.75)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func imageEditorGlobalLightDrivesLinkedShadowAngles() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .systemBlue, size: canvasSize)
        ) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.setSelectedLayerShadowDistance(12)
        viewModel.setSelectedLayerShadowAngle(30)

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        viewModel.document.layers[secondIndex].style.shadowEnabled = true
        viewModel.document.layers[secondIndex].style.shadowUsesGlobalLight = true
        viewModel.document.layers[secondIndex].style.shadowDistance = 8
        viewModel.document.layers[secondIndex].style.shadowAngle = -45

        #expect(viewModel.document.globalLightAngle == 30)
        #expect(viewModel.document.layers[secondIndex].style.resolvedShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == 30)

        viewModel.document.selectedLayerID = firstID
        viewModel.document.selectedLayerIDs = [firstID]
        viewModel.setSelectedLayerShadowAngle(-60)
        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })

        #expect(viewModel.document.globalLightAngle == -60)
        #expect(viewModel.document.layers[firstIndex].style.resolvedShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == -60)
        #expect(viewModel.document.layers[secondIndex].style.resolvedShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == -60)

        viewModel.setSelectedLayerShadowUsesGlobalLight(false)
        viewModel.setSelectedLayerShadowAngle(15)

        #expect(viewModel.document.globalLightAngle == -60)
        #expect(!viewModel.document.layers[firstIndex].style.shadowUsesGlobalLight)
        #expect(viewModel.document.layers[firstIndex].style.resolvedShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == 15)
        #expect(viewModel.document.layers[secondIndex].style.resolvedShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == -60)
    }

    @Test func imageEditorGlobalLightDrivesLinkedBevelAngles() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .systemBlue, size: canvasSize)
        ) { _ in }

        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        viewModel.setSelectedLayerBevelSize(8)
        viewModel.setSelectedLayerBevelAngle(45)

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        viewModel.document.layers[secondIndex].style.bevelEnabled = true
        viewModel.document.layers[secondIndex].style.bevelUsesGlobalLight = true
        viewModel.document.layers[secondIndex].style.bevelAngle = -45

        #expect(viewModel.document.globalLightAngle == 45)
        #expect(viewModel.document.layers[secondIndex].style.resolvedBevelAngle(globalLightAngle: viewModel.document.globalLightAngle) == 45)

        viewModel.document.selectedLayerID = firstID
        viewModel.document.selectedLayerIDs = [firstID]
        viewModel.setSelectedLayerBevelAngle(-75)
        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })

        #expect(viewModel.document.globalLightAngle == -75)
        #expect(viewModel.document.layers[firstIndex].style.resolvedBevelAngle(globalLightAngle: viewModel.document.globalLightAngle) == -75)
        #expect(viewModel.document.layers[secondIndex].style.resolvedBevelAngle(globalLightAngle: viewModel.document.globalLightAngle) == -75)

        viewModel.setSelectedLayerBevelUsesGlobalLight(false)
        viewModel.setSelectedLayerBevelAngle(20)

        #expect(viewModel.document.globalLightAngle == -75)
        #expect(!viewModel.document.layers[firstIndex].style.bevelUsesGlobalLight)
        #expect(viewModel.document.layers[firstIndex].style.resolvedBevelAngle(globalLightAngle: viewModel.document.globalLightAngle) == 20)
        #expect(viewModel.document.layers[secondIndex].style.resolvedBevelAngle(globalLightAngle: viewModel.document.globalLightAngle) == -75)
    }

    @Test func imageEditorDropShadowColorUsesForegroundColor() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.foregroundColor = .systemRed
        viewModel.setSelectedLayerShadowColorFromForeground()
        viewModel.setSelectedLayerShadowOpacity(1)
        viewModel.setSelectedLayerShadowBlur(0)
        viewModel.setSelectedLayerShadowSpread(0)
        viewModel.setSelectedLayerShadowDistance(12)
        viewModel.setSelectedLayerShadowAngle(0)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let shadowColor = try #require(styledLayer.style.shadowColor.usingColorSpace(.deviceRGB))
        let rightShadow = try #require(viewModel.currentImage.color(at: CGPoint(x: 64, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(styledLayer.style.shadowEnabled)
        #expect(shadowColor.redComponent > 0.75)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(rightShadow.redComponent > 0.75)
        #expect(rightShadow.greenComponent < 0.35)
        #expect(rightShadow.blueComponent < 0.35)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func imageEditorInsideStrokeStaysInsideLayerAlpha() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerStrokeWidth(6)
        viewModel.setSelectedLayerStrokePosition(.inside)
        viewModel.setSelectedLayerFillOpacity(0)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let outside = try #require(viewModel.currentImage.color(at: CGPoint(x: 21, y: 30))?.usingColorSpace(.deviceRGB))
        let edge = try #require(viewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB))
        let center = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(styledLayer.style.strokeEnabled)
        #expect(styledLayer.style.strokePosition == .inside)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(outside.blueComponent > 0.75)
        #expect(outside.redComponent < 0.25)
        #expect(edge.redComponent > 0.75)
        #expect(edge.greenComponent > 0.75)
        #expect(edge.blueComponent > 0.75)
        #expect(center.blueComponent > 0.75)
        #expect(center.greenComponent < 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFillOpacity"))
    }

    @Test func imageEditorStrokeOpacityBlendsStrokeIndependentlyFromFill() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerStrokeWidth(6)
        viewModel.setSelectedLayerStrokePosition(.inside)
        viewModel.setSelectedLayerStrokeOpacity(0.5)
        viewModel.setSelectedLayerFillOpacity(0)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let edge = try #require(viewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB))
        let center = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(styledLayer.style.strokeEnabled)
        #expect(styledLayer.style.strokeOpacity == 0.5)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(edge.redComponent > 0.35)
        #expect(edge.greenComponent > 0.35)
        #expect(edge.blueComponent > 0.75)
        #expect(edge.redComponent < 0.75)
        #expect(edge.greenComponent < 0.75)
        #expect(center.blueComponent > 0.75)
        #expect(center.redComponent < 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerFillOpacity"))
    }

    @Test func imageEditorStrokeColorUsesForegroundColor() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerFillOpacity(0)
        viewModel.setSelectedLayerStrokeWidth(6)
        viewModel.setSelectedLayerStrokePosition(.inside)
        viewModel.foregroundColor = .systemRed
        viewModel.setSelectedLayerStrokeColorFromForeground()

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let strokeColor = try #require(styledLayer.style.strokeColor.usingColorSpace(.deviceRGB))
        let edge = try #require(viewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB))
        let center = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(styledLayer.style.strokeEnabled)
        #expect(strokeColor.redComponent > 0.75)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(edge.redComponent > 0.75)
        #expect(edge.greenComponent < 0.35)
        #expect(edge.blueComponent < 0.35)
        #expect(center.blueComponent > 0.75)
        #expect(center.redComponent < 0.25)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func imageEditorStrokeGradientFillRendersAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerFillOpacity(0)
        viewModel.setSelectedLayerStrokeWidth(6)
        viewModel.setSelectedLayerStrokePosition(.inside)
        viewModel.foregroundColor = .systemRed
        viewModel.backgroundColor = .systemBlue
        viewModel.setSelectedLayerStrokeFillType(.gradient)
        viewModel.setSelectedLayerStrokeGradientStyle(.linear)
        viewModel.setSelectedLayerStrokeGradientAngle(0)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let leftEdge = try #require(viewModel.currentImage.color(at: CGPoint(x: 25, y: 30))?.usingColorSpace(.deviceRGB))
        let rightEdge = try #require(viewModel.currentImage.color(at: CGPoint(x: 54, y: 30))?.usingColorSpace(.deviceRGB))
        let center = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))

        #expect(styledLayer.style.strokeEnabled)
        #expect(styledLayer.style.strokeFillType == .gradient)
        #expect(styledLayer.style.strokeGradientStyle == .linear)
        #expect(styledLayer.style.strokeGradientAngle == 0)
        #expect(viewModel.selectedLayerStrokeFillType == .gradient)
        #expect(viewModel.selectedLayerStrokeGradientStyle == .linear)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(leftEdge.redComponent > rightEdge.redComponent + 0.20)
        #expect(rightEdge.blueComponent > leftEdge.blueComponent + 0.20)
        #expect(center.blueComponent > 0.75)
        #expect(center.redComponent < 0.25)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.strokeFillType == .gradient)
        #expect(restoredLayer.style.strokeGradientStyle == .linear)
        #expect(restoredLayer.style.strokeGradientAngle == 0)
    }

    @Test func imageEditorStrokePatternFillRendersAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedBeforeStyle = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.setSelectedLayerFillOpacity(0)
        viewModel.setSelectedLayerStrokeWidth(8)
        viewModel.setSelectedLayerStrokePosition(.inside)
        viewModel.foregroundColor = .white
        viewModel.setSelectedLayerStrokePatternKind(.diagonalStripes)
        viewModel.setSelectedLayerStrokePatternScale(12)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let compositedAfterStyle = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(styledLayer.style.strokeEnabled)
        #expect(styledLayer.style.strokeFillType == .pattern)
        #expect(styledLayer.style.strokePatternKind == .diagonalStripes)
        #expect(styledLayer.style.strokePatternScale == 12)
        #expect(viewModel.selectedLayerStrokePatternKind == .diagonalStripes)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(compositedAfterStyle != compositedBeforeStyle)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.strokeFillType == .pattern)
        #expect(restoredLayer.style.strokePatternKind == .diagonalStripes)
        #expect(restoredLayer.style.strokePatternScale == 12)
    }

    @Test func imageEditorBevelIsNonDestructiveAndUpdatesStyleParameters() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedBeforeStyle = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.setSelectedLayerBevelSize(8)
        viewModel.setSelectedLayerBevelOpacity(0.8)
        viewModel.setSelectedLayerBevelHighlightColor(.systemRed)
        viewModel.setSelectedLayerBevelShadowColor(.systemBlue)
        viewModel.setSelectedLayerBevelAngle(45)
        viewModel.setSelectedLayerBevelDirection(.up)
        let upBevelData = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.setSelectedLayerBevelDirection(.down)
        let hardDownBevelData = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.setSelectedLayerBevelSoften(4)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let compositedAfterStyle = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(styledLayer.style.bevelEnabled)
        #expect(styledLayer.style.bevelSize == 8)
        #expect(styledLayer.style.bevelOpacity == 0.8)
        #expect(styledLayer.style.bevelDirection == .down)
        #expect(styledLayer.style.bevelSoften == 4)
        let bevelHighlightColor = try #require(styledLayer.style.bevelHighlightColor.usingColorSpace(.deviceRGB))
        let bevelShadowColor = try #require(styledLayer.style.bevelShadowColor.usingColorSpace(.deviceRGB))
        #expect(bevelHighlightColor.redComponent > 0.85)
        #expect(bevelHighlightColor.greenComponent < 0.3)
        #expect(bevelShadowColor.blueComponent > 0.85)
        #expect(bevelShadowColor.redComponent < 0.3)
        #expect(viewModel.selectedLayerBevelDirection == .down)
        #expect(viewModel.selectedLayerBevelSoften == 4)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(compositedAfterStyle != compositedBeforeStyle)
        #expect(compositedAfterStyle != upBevelData)
        #expect(compositedAfterStyle != hardDownBevelData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.bevelEnabled)
        #expect(restoredLayer.style.bevelDirection == .down)
        #expect(restoredLayer.style.bevelSoften == 4)
        let restoredHighlightColor = try #require(restoredLayer.style.bevelHighlightColor.usingColorSpace(.deviceRGB))
        let restoredShadowColor = try #require(restoredLayer.style.bevelShadowColor.usingColorSpace(.deviceRGB))
        #expect(restoredHighlightColor.redComponent > 0.85)
        #expect(restoredShadowColor.blueComponent > 0.85)
    }

    @Test func imageEditorInnerShadowIsNonDestructiveAndUpdatesStyleParameters() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedBeforeStyle = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.foregroundColor = .black
        viewModel.setSelectedLayerInnerShadowOpacity(0.75)
        viewModel.setSelectedLayerInnerShadowBlur(9)
        viewModel.setSelectedLayerInnerShadowAngle(-30)
        viewModel.setSelectedLayerInnerShadowDistance(0)
        let zeroDistanceData = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.setSelectedLayerInnerShadowDistance(11)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let compositedAfterStyle = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(styledLayer.style.innerShadowEnabled)
        #expect(styledLayer.style.innerShadowOpacity == 0.75)
        #expect(styledLayer.style.innerShadowBlur == 9)
        #expect(styledLayer.style.innerShadowDistance == 11)
        #expect(styledLayer.style.innerShadowAngle == -30)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(compositedAfterStyle != compositedBeforeStyle)
        #expect(compositedAfterStyle != zeroDistanceData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))
    }

    @Test func imageEditorInnerShadowAngleUsesGlobalLightWithoutReplacingExistingColor() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            layerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )

        viewModel.foregroundColor = .systemRed
        viewModel.setSelectedLayerInnerShadowOpacity(1)
        viewModel.setSelectedLayerInnerShadowBlur(0)
        viewModel.setSelectedLayerInnerShadowDistance(10)
        viewModel.setSelectedLayerInnerShadowUsesGlobalLight(true)
        viewModel.setSelectedLayerInnerShadowAngle(0)
        let rightwardShadow = try #require(viewModel.currentImage.qingtuPNGData())
        let originalColor = ImageEditorProjectColor(
            color: try #require(viewModel.document.selectedLayer).style.innerShadowColor
        )

        viewModel.foregroundColor = .systemYellow
        #expect(viewModel.setSelectedLayerInnerShadowAngle(180) == 1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let leftwardShadow = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(viewModel.document.globalLightAngle == 180)
        #expect(styledLayer.style.resolvedInnerShadowAngle(globalLightAngle: viewModel.document.globalLightAngle) == 180)
        #expect(ImageEditorProjectColor(color: styledLayer.style.innerShadowColor) == originalColor)
        #expect(leftwardShadow != rightwardShadow)
    }

    @Test func imageEditorInnerShadowChokeAndNoiseRoundTripProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.foregroundColor = .black
        viewModel.setSelectedLayerInnerShadowOpacity(1)
        viewModel.setSelectedLayerInnerShadowBlur(0)
        viewModel.setSelectedLayerInnerShadowDistance(12)
        viewModel.setSelectedLayerInnerShadowAngle(0)
        viewModel.setSelectedLayerInnerShadowChoke(0)
        viewModel.setSelectedLayerInnerShadowNoise(0)
        let smoothShadowData = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.setSelectedLayerInnerShadowChoke(8)
        viewModel.setSelectedLayerInnerShadowNoise(1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let noisyShadowData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(styledLayer.style.innerShadowEnabled)
        #expect(styledLayer.style.innerShadowChoke == 8)
        #expect(styledLayer.style.innerShadowNoise == 1)
        #expect(viewModel.selectedLayerInnerShadowChoke == 8)
        #expect(viewModel.selectedLayerInnerShadowNoise == 1)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(noisyShadowData != smoothShadowData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.innerShadowEnabled)
        #expect(restoredLayer.style.innerShadowChoke == 8)
        #expect(restoredLayer.style.innerShadowNoise == 1)
    }

    @Test func imageEditorGradientOverlayIsNonDestructiveAndUpdatesStyleParameters() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedBeforeStyle = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.foregroundColor = .systemRed
        viewModel.backgroundColor = .systemBlue
        viewModel.setSelectedLayerGradientOverlayOpacity(1)
        viewModel.setSelectedLayerGradientOverlayStartColor(.systemRed)
        viewModel.setSelectedLayerGradientOverlayEndColor(.systemBlue)
        viewModel.foregroundColor = .systemGreen
        viewModel.backgroundColor = .systemYellow
        viewModel.setSelectedLayerGradientOverlayStyle(.radial)
        viewModel.setSelectedLayerGradientOverlayScale(2)
        viewModel.setSelectedLayerGradientOverlayAngle(45)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let compositedAfterStyle = try #require(viewModel.currentImage.qingtuPNGData())
        let centerColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB))
        let edgeColor = try #require(viewModel.currentImage.color(at: CGPoint(x: 24, y: 30))?.usingColorSpace(.deviceRGB))
        #expect(styledLayer.style.gradientOverlayEnabled)
        #expect(styledLayer.style.gradientOverlayOpacity == 1)
        #expect(styledLayer.style.gradientOverlayStyle == .radial)
        #expect(styledLayer.style.gradientOverlayScale == 2)
        #expect(styledLayer.style.gradientOverlayAngle == 45)
        let startColor = try #require(styledLayer.style.gradientOverlayStartColor.usingColorSpace(.deviceRGB))
        let endColor = try #require(styledLayer.style.gradientOverlayEndColor.usingColorSpace(.deviceRGB))
        #expect(startColor.redComponent > 0.85)
        #expect(startColor.greenComponent < 0.3)
        #expect(endColor.blueComponent > 0.85)
        #expect(endColor.redComponent < 0.3)
        #expect(viewModel.selectedLayerGradientOverlayStyle == .radial)
        #expect(viewModel.selectedLayerGradientOverlayScale == 2)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(compositedAfterStyle != compositedBeforeStyle)
        #expect(centerColor.redComponent > edgeColor.redComponent + 0.25)
        #expect(edgeColor.blueComponent > centerColor.blueComponent + 0.20)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        let restoredStartColor = try #require(restoredLayer.style.gradientOverlayStartColor.usingColorSpace(.deviceRGB))
        let restoredEndColor = try #require(restoredLayer.style.gradientOverlayEndColor.usingColorSpace(.deviceRGB))
        #expect(restoredStartColor.redComponent > 0.85)
        #expect(restoredEndColor.blueComponent > 0.85)
        #expect(restoredLayer.style.gradientOverlayEnabled)
        #expect(restoredLayer.style.gradientOverlayStyle == .radial)
        #expect(restoredLayer.style.gradientOverlayScale == 2)
        #expect(restoredLayer.style.gradientOverlayOpacity == 1)
    }

    @Test func imageEditorPatternOverlayIsNonDestructiveAndRemainsVisibleWithZeroFill() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedBeforeStyle = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.foregroundColor = .white
        viewModel.setSelectedLayerPatternOverlayKind(.diagonalStripes)
        viewModel.setSelectedLayerPatternOverlayOpacity(0.9)
        viewModel.setSelectedLayerPatternOverlayScale(18)
        viewModel.setSelectedLayerFillOpacity(0)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let compositedAfterStyle = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(styledLayer.style.patternOverlayEnabled)
        #expect(styledLayer.style.patternOverlayKind == .diagonalStripes)
        #expect(styledLayer.style.patternOverlayOpacity == 0.9)
        #expect(styledLayer.style.patternOverlayScale == 18)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(compositedAfterStyle != compositedBeforeStyle)
    }

    @Test func imageEditorSatinIsNonDestructiveAndUpdatesStyleParameters() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let baseImage = solidImage(color: .systemBlue, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let compositedBeforeStyle = try #require(viewModel.currentImage.qingtuPNGData())

        viewModel.setSelectedLayerSatinColor(.systemRed)
        viewModel.foregroundColor = .black
        viewModel.setSelectedLayerSatinOpacity(0.8)
        viewModel.setSelectedLayerSatinDistance(12)
        viewModel.setSelectedLayerSatinSize(5)
        viewModel.setSelectedLayerSatinAngle(45)
        viewModel.setSelectedLayerSatinContour(.linear)
        let linearSatinData = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.setSelectedLayerSatinContour(.ring)
        let contouredSatinData = try #require(viewModel.currentImage.qingtuPNGData())
        viewModel.setSelectedLayerSatinInvert(true)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let layerPixelsAfterStyle = try #require(styledLayer.image.qingtuPNGData())
        let compositedAfterStyle = try #require(viewModel.currentImage.qingtuPNGData())
        let satinColor = try #require(styledLayer.style.satinColor.usingColorSpace(.deviceRGB))
        #expect(styledLayer.style.satinEnabled)
        #expect(satinColor.redComponent > 0.85)
        #expect(satinColor.greenComponent < 0.30)
        #expect(styledLayer.style.satinOpacity == 0.8)
        #expect(styledLayer.style.satinDistance == 12)
        #expect(styledLayer.style.satinSize == 5)
        #expect(styledLayer.style.satinAngle == 45)
        #expect(styledLayer.style.satinInvert)
        #expect(styledLayer.style.satinContour == .ring)
        #expect(viewModel.selectedLayerSatinInvert)
        #expect(viewModel.selectedLayerSatinContour == .ring)
        #expect(layerPixelsAfterStyle == layerPixelsBeforeStyle)
        #expect(compositedAfterStyle != compositedBeforeStyle)
        #expect(contouredSatinData != linearSatinData)
        #expect(compositedAfterStyle != contouredSatinData)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.satinInvert)
        #expect(restoredLayer.style.satinContour == .ring)
    }

    private func solidImage(color: NSColor, size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }

    private func layer(_ id: UUID, in viewModel: ImageEditorViewModel) -> ImageEditorLayer? {
        viewModel.document.layers.first { $0.id == id }
    }

    private func centerRectImage(size: NSSize, color: NSColor) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.clear.setFill()
            rect.fill()
            color.setFill()
            CGRect(x: 24, y: 18, width: 32, height: 24).fill()
        } ?? NSImage.transparent(size: size)
    }

    private func horizontalRedGradientImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.clear.setFill()
            rect.fill()
            for x in 0..<Int(size.width) {
                let component = CGFloat(x) / max(1, size.width - 1)
                NSColor(calibratedRed: component, green: 0, blue: 0, alpha: 1).setFill()
                CGRect(x: CGFloat(x), y: 0, width: 1, height: size.height).fill()
            }
        } ?? NSImage.transparent(size: size)
    }

    private func horizontalGrayscaleImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.clear.setFill()
            rect.fill()
            for x in 0..<Int(size.width) {
                let component = CGFloat(x) / max(1, size.width - 1)
                NSColor(calibratedWhite: component, alpha: 1).setFill()
                CGRect(x: CGFloat(x), y: 0, width: 1, height: size.height).fill()
            }
        } ?? NSImage.transparent(size: size)
    }
}
