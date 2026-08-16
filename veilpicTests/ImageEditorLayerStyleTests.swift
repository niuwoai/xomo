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
        viewModel.beginSelectedLayerBlendIfUnderlyingBlackChange()
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
        // Pure red has a Rec. 709 luminance of at most ~0.21, so use a
        // threshold that still separates the dark and bright gradient ends.
        viewModel.beginSelectedLayerBlendIfSourceBlackChange()
        viewModel.setSelectedLayerBlendIfSourceBlack(0.1)
        viewModel.commitSelectedLayerBlendIfChange()

        let darkSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 2, y: 4))?.usingColorSpace(.deviceRGB))
        let brightSide = try #require(viewModel.currentImage.color(at: CGPoint(x: 14, y: 4))?.usingColorSpace(.deviceRGB))
        let layer = try #require(viewModel.document.selectedLayer)

        #expect(darkSide.blueComponent > 0.75)
        #expect(darkSide.redComponent < 0.25)
        #expect(brightSide.redComponent > 0.75)
        #expect(brightSide.blueComponent < 0.25)
        #expect(layer.blendIfSourceBlack == 0.1)
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

    @Test func strokePatternOffsetChangesRenderedPhaseAndRoundTripsProjectState() throws {
        var style = ImageEditorLayerStyle()
        style.strokeEnabled = true
        style.strokeFillType = .pattern
        style.strokePatternKind = .checkerboard
        style.strokePatternColor = .white
        style.strokePatternScale = 8
        style.strokePatternOffset = .zero
        let original = style.strokeFillImage(size: CGSize(width: 24, height: 24))
        let originalData = try #require(original.qingtuPNGData())

        style.strokePatternOffset = CGSize(width: 4, height: 0)
        let shifted = style.strokeFillImage(size: CGSize(width: 24, height: 24))
        let shiftedData = try #require(shifted.qingtuPNGData())
        #expect(shiftedData != originalData)

        let encoded = try JSONEncoder().encode(ImageEditorProjectLayerStyle(style: style))
        let decoded = try JSONDecoder().decode(ImageEditorProjectLayerStyle.self, from: encoded).layerStyle
        #expect(decoded.strokePatternOffset == CGSize(width: 4, height: 0))

        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "strokePatternOffset")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacy = try JSONDecoder().decode(ImageEditorProjectLayerStyle.self, from: legacyData).layerStyle
        #expect(legacy.strokePatternOffset == .zero)
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
        viewModel.beginSelectedLayerFillOpacityChange()
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

    @Test func imageEditorOuterGlowRangeChangesFalloffAndPreservesLegacyProjects() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let glowColor = NSColor(srgbRed: 0.92, green: 0.16, blue: 0.08, alpha: 1)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .clear, size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            centerRectImage(size: canvasSize, color: .white),
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
        viewModel.setSelectedLayerOuterGlowContour(.linear)
        #expect(viewModel.setSelectedLayerOuterGlowRange(1) == 1)
        let fullRange = viewModel.currentImage
        let fullRangeData = try #require(fullRange.qingtuPNGData())

        #expect(viewModel.setSelectedLayerOuterGlowRange(0.25) == 1)
        let narrowRange = viewModel.currentImage
        let narrowRangeData = try #require(narrowRange.qingtuPNGData())

        var maximumAlphaIncrease: CGFloat = 0
        for x in 0..<24 {
            let point = CGPoint(x: CGFloat(x), y: 30)
            let fullAlpha = try #require(
                fullRange.color(at: point)?.usingColorSpace(.deviceRGB)?.alphaComponent
            )
            let narrowAlpha = try #require(
                narrowRange.color(at: point)?.usingColorSpace(.deviceRGB)?.alphaComponent
            )
            maximumAlphaIncrease = max(maximumAlphaIncrease, narrowAlpha - fullAlpha)
        }

        let styledLayer = try #require(viewModel.document.selectedLayer)
        #expect(styledLayer.style.outerGlowEnabled)
        #expect(styledLayer.style.outerGlowRange == 0.25)
        #expect(styledLayer.style.outerGlowContour == .linear)
        #expect(try #require(styledLayer.image.qingtuPNGData()) == layerPixelsBeforeStyle)
        #expect(narrowRangeData != fullRangeData)
        #expect(maximumAlphaIncrease > 0.03)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.outerGlowRange == 0.25)

        let encodedStyle = try JSONEncoder().encode(ImageEditorProjectLayerStyle(style: styledLayer.style))
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedStyle) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "outerGlowRange")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyStyle = try JSONDecoder().decode(ImageEditorProjectLayerStyle.self, from: legacyData)
        #expect(legacyStyle.layerStyle.outerGlowRange == 1)
    }

    @Test func imageEditorOuterGlowJitterTexturesQualityAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let glowColor = NSColor(srgbRed: 0.92, green: 0.16, blue: 0.08, alpha: 1)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .clear, size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            centerRectImage(size: canvasSize, color: .white),
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
        viewModel.setSelectedLayerOuterGlowContour(.linear)
        viewModel.setSelectedLayerOuterGlowRange(1)
        let smoothData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.setSelectedLayerOuterGlowJitter(1) == 1)
        let jitteredData = try #require(viewModel.currentImage.qingtuPNGData())
        let repeatedRenderData = try #require(viewModel.currentImage.qingtuPNGData())

        let styledLayer = try #require(viewModel.document.selectedLayer)
        #expect(styledLayer.style.outerGlowEnabled)
        #expect(styledLayer.style.outerGlowJitter == 1)
        #expect(styledLayer.style.outerGlowNoise == 0)
        #expect(styledLayer.style.outerGlowContour == .linear)
        #expect(try #require(styledLayer.image.qingtuPNGData()) == layerPixelsBeforeStyle)
        #expect(jitteredData != smoothData)
        #expect(repeatedRenderData == jitteredData)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.outerGlowJitter == 1)

        let encodedStyle = try JSONEncoder().encode(ImageEditorProjectLayerStyle(style: styledLayer.style))
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedStyle) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "outerGlowJitter")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyStyle = try JSONDecoder().decode(ImageEditorProjectLayerStyle.self, from: legacyData)
        #expect(legacyStyle.layerStyle.outerGlowJitter == 0)
    }

    @Test func imageEditorOuterGlowTechniqueChangesDiffusionAndPreservesLegacyProjects() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .clear, size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            centerRectImage(size: canvasSize, color: .white),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerPixelsBeforeStyle = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )

        viewModel.setSelectedLayerOuterGlowOpacity(1)
        viewModel.setSelectedLayerOuterGlowColor(.systemOrange)
        viewModel.setSelectedLayerOuterGlowBlur(12)
        viewModel.setSelectedLayerOuterGlowSpread(0)
        viewModel.setSelectedLayerOuterGlowNoise(0)
        viewModel.setSelectedLayerOuterGlowContour(.linear)
        viewModel.setSelectedLayerOuterGlowRange(1)
        #expect(viewModel.setSelectedLayerOuterGlowTechnique(.softer) == 0)
        let softerData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.setSelectedLayerOuterGlowTechnique(.precise) == 1)
        let preciseData = try #require(viewModel.currentImage.qingtuPNGData())
        let repeatedPreciseData = try #require(viewModel.currentImage.qingtuPNGData())

        let styledLayer = try #require(viewModel.document.selectedLayer)
        #expect(styledLayer.style.outerGlowTechnique == .precise)
        #expect(styledLayer.style.outerGlowBlur == 12)
        #expect(try #require(styledLayer.image.qingtuPNGData()) == layerPixelsBeforeStyle)
        #expect(preciseData != softerData)
        #expect(repeatedPreciseData == preciseData)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.outerGlowTechnique == .precise)

        let encodedStyle = try JSONEncoder().encode(ImageEditorProjectLayerStyle(style: styledLayer.style))
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedStyle) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "outerGlowTechnique")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyStyle = try JSONDecoder().decode(ImageEditorProjectLayerStyle.self, from: legacyData)
        #expect(legacyStyle.layerStyle.outerGlowTechnique == .softer)
    }

    @Test func imageEditorInnerGlowTechniqueFollowsAlphaAndPreservesLegacyProjects() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .clear, size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            centerRectImage(size: canvasSize, color: .white),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        let layerPixelsBeforeStyle = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )

        viewModel.setSelectedLayerInnerGlowOpacity(1)
        viewModel.setSelectedLayerInnerGlowColor(.systemOrange)
        viewModel.setSelectedLayerInnerGlowBlur(12)
        viewModel.setSelectedLayerInnerGlowChoke(0)
        viewModel.setSelectedLayerInnerGlowNoise(0)
        viewModel.setSelectedLayerInnerGlowSource(.edge)
        viewModel.setSelectedLayerInnerGlowContour(.linear)
        viewModel.setSelectedLayerInnerGlowRange(1)
        #expect(viewModel.setSelectedLayerInnerGlowTechnique(.softer) == 0)
        let softerData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.setSelectedLayerInnerGlowTechnique(.precise) == 1)
        let preciseImage = viewModel.currentImage
        let preciseData = try #require(preciseImage.qingtuPNGData())
        let repeatedPreciseData = try #require(viewModel.currentImage.qingtuPNGData())
        let edgeColor = try #require(
            preciseImage.color(at: CGPoint(x: 24, y: 30))?.usingColorSpace(.deviceRGB)
        )
        let centerColor = try #require(
            preciseImage.color(at: CGPoint(x: 40, y: 30))?.usingColorSpace(.deviceRGB)
        )

        let styledLayer = try #require(viewModel.document.selectedLayer)
        #expect(styledLayer.style.innerGlowTechnique == .precise)
        #expect(styledLayer.style.innerGlowBlur == 12)
        #expect(try #require(styledLayer.image.qingtuPNGData()) == layerPixelsBeforeStyle)
        #expect(preciseData != softerData)
        #expect(repeatedPreciseData == preciseData)
        #expect(edgeColor.greenComponent < centerColor.greenComponent - 0.08)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.innerGlowTechnique == .precise)

        let encodedStyle = try JSONEncoder().encode(ImageEditorProjectLayerStyle(style: styledLayer.style))
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedStyle) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "innerGlowTechnique")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyStyle = try JSONDecoder().decode(ImageEditorProjectLayerStyle.self, from: legacyData)
        #expect(legacyStyle.layerStyle.innerGlowTechnique == .softer)
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

    @Test func imageEditorInnerGlowJitterTexturesQualityAndRoundTripsProjectState() async throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let glowColor = NSColor(srgbRed: 0.9, green: 0.08, blue: 0.12, alpha: 1)
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: solidImage(color: .clear, size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            centerRectImage(size: canvasSize, color: .white),
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
        viewModel.setSelectedLayerInnerGlowRange(1)
        let smoothData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.setSelectedLayerInnerGlowJitter(1) == 1)
        let jitteredData = try #require(viewModel.currentImage.qingtuPNGData())
        let repeatedRenderData = try #require(viewModel.currentImage.qingtuPNGData())

        let styledLayer = try #require(viewModel.document.selectedLayer)
        #expect(styledLayer.style.innerGlowEnabled)
        #expect(styledLayer.style.innerGlowJitter == 1)
        #expect(styledLayer.style.innerGlowNoise == 0)
        #expect(styledLayer.style.innerGlowContour == .linear)
        #expect(try #require(styledLayer.image.qingtuPNGData()) == layerPixelsBeforeStyle)
        #expect(jitteredData != smoothData)
        #expect(repeatedRenderData == jitteredData)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.innerGlowJitter == 1)

        let encodedStyle = try JSONEncoder().encode(ImageEditorProjectLayerStyle(style: styledLayer.style))
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedStyle) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "innerGlowJitter")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyStyle = try JSONDecoder().decode(ImageEditorProjectLayerStyle.self, from: legacyData)
        #expect(legacyStyle.layerStyle.innerGlowJitter == 0)
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
        let baseImage = solidImage(
            color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1),
            size: canvasSize
        )
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerStrokeWidth(6)
        viewModel.setSelectedLayerStrokePosition(.inside)
        viewModel.beginSelectedLayerFillOpacityChange()
        viewModel.setSelectedLayerFillOpacity(0)
        viewModel.commitSelectedLayerFillOpacityChange()

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
        let baseImage = solidImage(
            color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1),
            size: canvasSize
        )
        let layerImage = centerRectImage(size: canvasSize, color: .systemGreen)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(layerImage, historyTitle: L10n.text("imageEditor.history.brush"))
        let layerPixelsBeforeStyle = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())

        viewModel.setSelectedLayerStrokeWidth(6)
        viewModel.setSelectedLayerStrokePosition(.inside)
        viewModel.setSelectedLayerStrokeOpacity(0.5)
        viewModel.beginSelectedLayerFillOpacityChange()
        viewModel.setSelectedLayerFillOpacity(0)
        viewModel.commitSelectedLayerFillOpacityChange()

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
        viewModel.setSelectedLayerGradientOverlayDither(true)
        viewModel.setSelectedLayerGradientOverlayReverse(true)

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
        #expect(styledLayer.style.gradientOverlayDither)
        #expect(styledLayer.style.gradientOverlayReverse)
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
        #expect(centerColor.blueComponent > edgeColor.blueComponent + 0.10)
        #expect(edgeColor.redComponent > centerColor.redComponent + 0.10)
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
        #expect(restoredLayer.style.gradientOverlayDither)
        #expect(restoredLayer.style.gradientOverlayReverse)
    }

    @Test func gradientOverlayColorStopsRenderRoundTripAndPreserveLegacyEndpoints() throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "gradient-overlay-stops.png",
            image: solidImage(color: .black, size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            centerRectImage(size: canvasSize, color: .white),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.setSelectedLayerGradientOverlayOpacity(1)
        viewModel.setSelectedLayerGradientOverlayStyle(.linear)
        viewModel.setSelectedLayerGradientOverlayAngle(0)
        viewModel.setSelectedLayerGradientOverlayScale(1)
        let sourcePixels = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let twoStopPixels = try #require(viewModel.currentImage.qingtuPNGData())
        let stops = [
            ImageEditorGradientColorStop(
                position: 0,
                red: 1,
                green: 0,
                blue: 0,
                alpha: 1,
                midpoint: 0.25
            ),
            ImageEditorGradientColorStop(
                position: 0.5,
                red: 0,
                green: 1,
                blue: 0,
                alpha: 0.35,
                midpoint: 0.7
            ),
            ImageEditorGradientColorStop(
                position: 1,
                red: 0,
                green: 0,
                blue: 1,
                alpha: 1,
                midpoint: 0.5
            )
        ]
        let historyCount = viewModel.document.history.count

        #expect(viewModel.setSelectedLayerGradientOverlayColorStops(stops) == 1)
        let styledLayer = try #require(viewModel.document.selectedLayer)
        let multiStopPixels = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(styledLayer.style.gradientOverlayColorStops == stops)
        #expect(styledLayer.style.resolvedGradientOverlayColorStops == stops)
        #expect(ImageEditorProjectColor(color: styledLayer.style.gradientOverlayStartColor)
            == ImageEditorProjectColor(color: stops[0].color))
        #expect(ImageEditorProjectColor(color: styledLayer.style.gradientOverlayEndColor)
            == ImageEditorProjectColor(color: stops[2].color))
        #expect(styledLayer.image.qingtuPNGData() == sourcePixels)
        #expect(multiStopPixels != twoStopPixels)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.setSelectedLayerGradientOverlayColorStops(stops) == 0)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.style.gradientOverlayColorStops == nil)
        #expect(viewModel.currentImage.qingtuPNGData() == twoStopPixels)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.style.gradientOverlayColorStops == stops)
        #expect(viewModel.currentImage.qingtuPNGData() == multiStopPixels)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredLayer = try #require(
            try project.restoredDocument().layers.first { $0.id == styledLayer.id }
        )
        #expect(restoredLayer.style.gradientOverlayColorStops == stops)

        let encodedStyle = try JSONEncoder().encode(
            ImageEditorProjectLayerStyle(style: styledLayer.style)
        )
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedStyle) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "gradientOverlayColorStops")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyStyle = try JSONDecoder().decode(
            ImageEditorProjectLayerStyle.self,
            from: legacyData
        ).layerStyle
        #expect(legacyStyle.gradientOverlayColorStops == nil)
        #expect(legacyStyle.resolvedGradientOverlayColorStops.count == 2)
        #expect(ImageEditorProjectColor(color: legacyStyle.resolvedGradientOverlayColorStops[0].color)
            == ImageEditorProjectColor(color: legacyStyle.gradientOverlayStartColor))
        #expect(ImageEditorProjectColor(color: legacyStyle.resolvedGradientOverlayColorStops[1].color)
            == ImageEditorProjectColor(color: legacyStyle.gradientOverlayEndColor))
    }

    @Test func gradientOverlayCenterMovesRenderingAndLegacyProjectsDefaultToLayerCenter() throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "gradient-overlay-center.png",
            image: solidImage(color: .black, size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            centerRectImage(size: canvasSize, color: .white),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.setSelectedLayerGradientOverlayOpacity(1)
        viewModel.setSelectedLayerGradientOverlayStartColor(.systemRed)
        viewModel.setSelectedLayerGradientOverlayEndColor(.systemBlue)
        viewModel.setSelectedLayerGradientOverlayStyle(.radial)
        viewModel.setSelectedLayerGradientOverlayScale(1)
        let sourcePixels = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let centeredPixels = try #require(viewModel.currentImage.qingtuPNGData())
        let historyCount = viewModel.document.history.count

        #expect(viewModel.setSelectedLayerGradientOverlayCenterX(0.25) == 1)
        #expect(viewModel.selectedLayerGradientOverlayCenterX == 0.25)
        #expect(viewModel.selectedLayerGradientOverlayCenterY == 0.5)
        let movedPixels = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(movedPixels != centeredPixels)
        #expect(viewModel.document.selectedLayer?.image.qingtuPNGData() == sourcePixels)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.setSelectedLayerGradientOverlayCenterX(0.25) == 0)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.selectedLayerGradientOverlayCenterX == 0.5)
        #expect(viewModel.currentImage.qingtuPNGData() == centeredPixels)
        viewModel.redo()
        #expect(viewModel.selectedLayerGradientOverlayCenterX == 0.25)
        #expect(viewModel.currentImage.qingtuPNGData() == movedPixels)

        #expect(viewModel.setSelectedLayerGradientOverlayCenterY(0.75) == 1)
        let styledLayer = try #require(viewModel.document.selectedLayer)
        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.gradientOverlayCenter == CGPoint(x: 0.25, y: 0.75))

        let encodedStyle = try JSONEncoder().encode(
            ImageEditorProjectLayerStyle(style: styledLayer.style)
        )
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedStyle) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "gradientOverlayCenter")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyStyle = try JSONDecoder().decode(
            ImageEditorProjectLayerStyle.self,
            from: legacyData
        ).layerStyle
        #expect(legacyStyle.gradientOverlayCenter
            == ImageEditorGradientOverlayCenterPolicy.defaultCenter)
        #expect(ImageEditorGradientOverlayCenterPolicy.normalized(
            CGPoint(x: -9, y: 12)
        ) == CGPoint(x: -4, y: 5))
        #expect(ImageEditorGradientOverlayCenterPolicy.normalized(
            CGPoint(x: CGFloat.nan, y: CGFloat.infinity)
        ) == ImageEditorGradientOverlayCenterPolicy.defaultCenter)
    }

    @Test func gradientOverlayBlendModeChangesPixelsAndLegacyProjectsDefaultToNormal() throws {
        let canvasSize = NSSize(width: 32, height: 24)
        let viewModel = ImageEditorViewModel(
            sourceName: "gradient-overlay-blend.png",
            image: solidImage(color: .black, size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            solidImage(color: .black, size: canvasSize),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        #expect(viewModel.setSelectedLayerGradientOverlayOpacity(1) == 1)
        #expect(viewModel.setSelectedLayerGradientOverlayStartColor(.white) == 1)
        viewModel.setSelectedLayerGradientOverlayEndColor(.white)
        #expect(viewModel.document.selectedLayer?.style.gradientOverlayEnabled == true)
        let sourcePixels = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let normalPixels = try #require(viewModel.currentImage.qingtuPNGData())
        let normalColor = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 16, y: 12))?.usingColorSpace(.deviceRGB)
        )
        let directlyRenderedColor = try #require(
            viewModel.document.compositedImage
                .color(at: CGPoint(x: 16, y: 12))?
                .usingColorSpace(.deviceRGB)
        )
        #expect(directlyRenderedColor.redComponent > 0.9)
        let historyCount = viewModel.document.history.count

        #expect(ImageEditorBlendMode.layerEffectCases.contains(.multiply))
        #expect(ImageEditorBlendMode.layerEffectCases.contains(.hardMix))
        #expect(!ImageEditorBlendMode.layerEffectCases.contains(.passThrough))
        #expect(viewModel.setSelectedLayerGradientOverlayBlendMode(.multiply) == 1)
        #expect(viewModel.selectedLayerGradientOverlayBlendMode == .multiply)
        let multipliedPixels = try #require(viewModel.currentImage.qingtuPNGData())
        let multipliedColor = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 16, y: 12))?.usingColorSpace(.deviceRGB)
        )
        #expect(normalColor.redComponent > 0.9)
        #expect(multipliedColor.redComponent < 0.1)
        #expect(multipliedPixels != normalPixels)
        #expect(viewModel.document.selectedLayer?.image.qingtuPNGData() == sourcePixels)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.setSelectedLayerGradientOverlayBlendMode(.screen) == 1)
        let screenedColor = try #require(
            viewModel.currentImage.color(at: CGPoint(x: 16, y: 12))?.usingColorSpace(.deviceRGB)
        )
        #expect(screenedColor.redComponent > 0.9)
        viewModel.undo()
        #expect(viewModel.selectedLayerGradientOverlayBlendMode == .multiply)
        #expect(viewModel.setSelectedLayerGradientOverlayBlendMode(.multiply) == 0)
        #expect(viewModel.setSelectedLayerGradientOverlayBlendMode(.passThrough) == 0)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.selectedLayerGradientOverlayBlendMode == .normal)
        #expect(viewModel.currentImage.qingtuPNGData() == normalPixels)
        viewModel.redo()
        #expect(viewModel.selectedLayerGradientOverlayBlendMode == .multiply)
        #expect(viewModel.currentImage.qingtuPNGData() == multipliedPixels)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredLayer = try #require(
            try project.restoredDocument().layers.first { $0.id == styledLayer.id }
        )
        #expect(restoredLayer.style.gradientOverlayBlendMode == .multiply)

        let encodedStyle = try JSONEncoder().encode(
            ImageEditorProjectLayerStyle(style: styledLayer.style)
        )
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedStyle) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "gradientOverlayBlendMode")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyStyle = try JSONDecoder().decode(
            ImageEditorProjectLayerStyle.self,
            from: legacyData
        ).layerStyle
        #expect(legacyStyle.gradientOverlayBlendMode == .normal)
    }

    @Test func gradientOverlayCenterGeometryMapsCanvasAndClampsExtendedRange() throws {
        let frame = CGRect(x: 10, y: 20, width: 100, height: 50)
        #expect(
            ImageEditorGradientOverlayCenterGeometry.canvasPoint(
                center: CGPoint(x: 0.5, y: 0.5),
                layerFrame: frame
            ) == CGPoint(x: 60, y: 45)
        )
        #expect(
            ImageEditorGradientOverlayCenterGeometry.normalizedCenter(
                canvasPoint: CGPoint(x: -500, y: 500),
                layerFrame: frame
            ) == CGPoint(x: -4, y: 5)
        )
        #expect(
            ImageEditorGradientOverlayCenterGeometry.canvasPoint(
                center: .zero,
                layerFrame: .zero
            ) == nil
        )
        #expect(
            ImageEditorGradientOverlayCenterGeometry.normalizedCenter(
                canvasPoint: CGPoint(x: CGFloat.nan, y: 0),
                layerFrame: frame
            ) == nil
        )
    }

    @Test func gradientOverlayAxisGeometryMatchesAllStylesAndSnapsAngles() throws {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        let center = CGPoint(x: 0.5, y: 0.5)
        let linear = try #require(
            ImageEditorGradientOverlayAxisGeometry.canvasGeometry(
                style: .linear,
                center: center,
                angle: 0,
                scale: 1,
                layerFrame: frame
            )
        )
        #expect(linear.center == CGPoint(x: 50, y: 25))
        #expect(linear.axisStart == CGPoint(x: 0, y: 25))
        #expect(linear.axisEndpoint == CGPoint(x: 100, y: 25))

        let reflected = try #require(
            ImageEditorGradientOverlayAxisGeometry.canvasGeometry(
                style: .reflected,
                center: center,
                angle: 0,
                scale: 1,
                layerFrame: frame
            )
        )
        #expect(reflected.center == linear.center)
        #expect(reflected.axisStart == reflected.center)
        #expect(reflected.axisEndpoint == linear.axisEndpoint)

        let radius = hypot(CGFloat(50), CGFloat(25))
        let radial = try #require(
            ImageEditorGradientOverlayAxisGeometry.canvasGeometry(
                style: .radial,
                center: center,
                angle: 90,
                scale: 1,
                layerFrame: frame
            )
        )
        #expect(radial.center == linear.center)
        #expect(radial.axisStart == radial.center)
        #expect(abs(radial.axisEndpoint.x - (50 + radius)) < 0.000_001)
        #expect(abs(radial.axisEndpoint.y - 25) < 0.000_001)

        let diamond = try #require(
            ImageEditorGradientOverlayAxisGeometry.canvasGeometry(
                style: .diamond,
                center: center,
                angle: 90,
                scale: 1,
                layerFrame: frame
            )
        )
        #expect(abs(diamond.axisEndpoint.x - 50) < 0.000_001)
        #expect(abs(diamond.axisEndpoint.y - (25 + radius)) < 0.000_001)

        let snapped = try #require(
            ImageEditorGradientOverlayAxisGeometry.updatedAxis(
                style: .linear,
                center: center,
                currentAngle: 0,
                layerFrame: frame,
                canvasPoint: CGPoint(x: 90, y: 55),
                snappingAngle: true
            )
        )
        #expect(snapped.angle == 30)
        #expect(snapped.scale >= 0.25 && snapped.scale <= 4)

        let radialUpdate = try #require(
            ImageEditorGradientOverlayAxisGeometry.updatedAxis(
                style: .radial,
                center: center,
                currentAngle: 73,
                layerFrame: frame,
                canvasPoint: CGPoint(x: 50, y: 25 + radius * 2),
                snappingAngle: true
            )
        )
        #expect(radialUpdate.angle == 73)
        #expect(abs(radialUpdate.scale - 2) < 0.000_001)
    }

    @Test func gradientOverlayCanvasStopsMapAcrossStylesAndReverse() throws {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        let center = CGPoint(x: 0.5, y: 0.5)
        let stops = [
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.25, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ]
        let linearHandles = ImageEditorGradientOverlayAxisGeometry.stopHandlePoints(
            style: .linear,
            center: center,
            angle: 0,
            scale: 1,
            reverse: false,
            stops: stops,
            layerFrame: frame
        )
        #expect(linearHandles.map(\.index) == [0, 1, 2])
        #expect(linearHandles.map(\.isEndpoint) == [true, false, true])
        #expect(linearHandles.map(\.canvasPoint) == [
            CGPoint(x: 0, y: 25),
            CGPoint(x: 25, y: 25),
            CGPoint(x: 100, y: 25)
        ])
        let linear = try #require(linearHandles.first { $0.index == 1 })
        #expect(linear.index == 1)
        #expect(linear.canvasPoint == CGPoint(x: 25, y: 25))

        let reversedHandles = ImageEditorGradientOverlayAxisGeometry.stopHandlePoints(
            style: .linear,
            center: center,
            angle: 0,
            scale: 1,
            reverse: true,
            stops: stops,
            layerFrame: frame
        )
        #expect(reversedHandles.map(\.canvasPoint) == [
            CGPoint(x: 100, y: 25),
            CGPoint(x: 75, y: 25),
            CGPoint(x: 0, y: 25)
        ])
        let reversed = try #require(reversedHandles.first { $0.index == 1 })
        #expect(reversed.canvasPoint == CGPoint(x: 75, y: 25))
        #expect(
            ImageEditorGradientOverlayAxisGeometry.logicalStopPosition(
                style: .linear,
                center: center,
                angle: 0,
                scale: 1,
                reverse: true,
                layerFrame: frame,
                canvasPoint: CGPoint(x: 25, y: 25)
            ) == 0.75
        )

        for style in [
            ImageEditorGradientFillStyle.radial,
            .reflected,
            .diamond
        ] {
            let handle = try #require(
                ImageEditorGradientOverlayAxisGeometry.stopHandlePoints(
                    style: style,
                    center: center,
                    angle: 0,
                    scale: 1,
                    reverse: false,
                    stops: stops,
                    layerFrame: frame
                ).first { $0.index == 1 }
            )
            let logical = try #require(
                ImageEditorGradientOverlayAxisGeometry.logicalStopPosition(
                    style: style,
                    center: center,
                    angle: 0,
                    scale: 1,
                    reverse: false,
                    layerFrame: frame,
                    canvasPoint: handle.canvasPoint
                )
            )
            #expect(abs(logical - 0.25) < 0.000_001)
        }
    }

    @Test func gradientOverlayCanvasPercentageDraftParsesAndFormatsExactValues() {
        #expect(ImageEditorPercentageDraft.normalizedValue(from: "37.5") == 0.375)
        #expect(ImageEditorPercentageDraft.normalizedValue(from: " 37,5% ") == 0.375)
        #expect(ImageEditorPercentageDraft.normalizedValue(from: "-5") == 0)
        #expect(ImageEditorPercentageDraft.normalizedValue(from: "125") == 1)
        #expect(ImageEditorPercentageDraft.normalizedValue(from: "") == nil)
        #expect(ImageEditorPercentageDraft.normalizedValue(from: "not-a-number") == nil)
        #expect(ImageEditorPercentageDraft.normalizedValue(from: "nan") == nil)
        #expect(ImageEditorPercentageDraft.text(for: 0) == "0")
        #expect(ImageEditorPercentageDraft.text(for: 0.375) == "37.5")
        #expect(ImageEditorPercentageDraft.text(for: 1) == "100")
        #expect(ImageEditorPercentageDraft.text(for: 0.333_333) == "33.33")
    }

    @Test func settingGradientOverlayCanvasHandlePercentagesReordersOnceAndPreservesRedo() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        let movingStop = ImageEditorGradientColorStop(
            position: 0.2,
            color: NSColor(srgbRed: 0.8, green: 0.2, blue: 0.4, alpha: 0.6),
            midpoint: 0.35
        )
        let originalStops = [
            ImageEditorGradientColorStop(position: 0, color: .black),
            movingStop,
            ImageEditorGradientColorStop(
                position: 0.6,
                color: .systemGreen,
                midpoint: 0.65
            ),
            ImageEditorGradientColorStop(position: 1, color: .white)
        ]
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops(
            originalStops
        )
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(
            viewModel.setSelectedLayerGradientOverlayCanvasStopDisplayedPosition(
                at: 1,
                to: 0.8
            ) == 2
        )
        let reordered = viewModel.selectedLayerGradientOverlayColorStops
        #expect(reordered[2].position == 0.8)
        #expect(reordered[2].red == movingStop.red)
        #expect(reordered[2].green == movingStop.green)
        #expect(reordered[2].blue == movingStop.blue)
        #expect(reordered[2].alpha == movingStop.alpha)
        #expect(reordered[2].midpoint == movingStop.midpoint)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(!viewModel.canRedo)

        viewModel.undo()
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.canRedo)
        let noOpHistoryCount = viewModel.document.history.count
        let noOpUndoCount = viewModel.undoStack.count
        #expect(
            viewModel.setSelectedLayerGradientOverlayCanvasStopDisplayedPosition(
                at: 1,
                to: 0.2
            ) == 1
        )
        #expect(viewModel.document.history.count == noOpHistoryCount)
        #expect(viewModel.undoStack.count == noOpUndoCount)
        #expect(viewModel.canRedo)
        #expect(
            viewModel.setSelectedLayerGradientOverlayCanvasStopDisplayedPosition(
                at: 0,
                to: 0.5
            ) == nil
        )

        viewModel.document.layers[selectedIndex].style.gradientOverlayReverse = true
        #expect(
            viewModel.setSelectedLayerGradientOverlayCanvasStopDisplayedPosition(
                at: 1,
                to: 0.25
            ) == 2
        )
        #expect(viewModel.selectedLayerGradientOverlayColorStops[2].position == 0.75)

        let midpointViewModel = gradientOverlayCenterViewModel()
        let midpointIndex = try #require(midpointViewModel.document.selectedLayerIndex)
        midpointViewModel.document.layers[midpointIndex].style.setGradientOverlayColorStops(
            originalStops
        )
        let midpointHistoryCount = midpointViewModel.document.history.count
        let midpointUndoCount = midpointViewModel.undoStack.count
        #expect(
            midpointViewModel.setSelectedLayerGradientOverlayCanvasMidpoint(
                after: 0,
                to: 0.22
            )
        )
        #expect(midpointViewModel.selectedLayerGradientOverlayColorStops[0].midpoint == 0.22)
        #expect(midpointViewModel.document.history.count == midpointHistoryCount + 1)
        #expect(midpointViewModel.undoStack.count == midpointUndoCount + 1)
        #expect(
            !midpointViewModel.setSelectedLayerGradientOverlayCanvasMidpoint(
                after: 0,
                to: 0.22
            )
        )
        #expect(midpointViewModel.document.history.count == midpointHistoryCount + 1)
        midpointViewModel.undo()
        #expect(midpointViewModel.selectedLayerGradientOverlayColorStops == originalStops)
    }

    @Test func settingGradientOverlayCanvasStopOpacitySupportsEndpointsAndPreservesRedo() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        let originalStops = [
            ImageEditorGradientColorStop(
                position: 0,
                red: 0.2,
                green: 0.4,
                blue: 0.6,
                alpha: 0.8,
                midpoint: 0.35
            ),
            ImageEditorGradientColorStop(
                position: 0.45,
                red: 0.7,
                green: 0.3,
                blue: 0.1,
                alpha: 0.65,
                midpoint: 0.7
            ),
            ImageEditorGradientColorStop(position: 1, color: .white)
        ]
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops(
            originalStops
        )
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(
            viewModel.setSelectedLayerGradientOverlayCanvasStopOpacity(
                at: 0,
                to: 0.4
            )
        )
        let changedStops = viewModel.selectedLayerGradientOverlayColorStops
        #expect(changedStops[0].alpha == 0.4)
        #expect(changedStops[0].position == originalStops[0].position)
        #expect(changedStops[0].red == originalStops[0].red)
        #expect(changedStops[0].green == originalStops[0].green)
        #expect(changedStops[0].blue == originalStops[0].blue)
        #expect(changedStops[0].midpoint == originalStops[0].midpoint)
        #expect(changedStops[1] == originalStops[1])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(!viewModel.canRedo)

        viewModel.undo()
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.canRedo)
        let noOpHistoryCount = viewModel.document.history.count
        let noOpUndoCount = viewModel.undoStack.count
        #expect(
            !viewModel.setSelectedLayerGradientOverlayCanvasStopOpacity(
                at: 0,
                to: 0.8
            )
        )
        #expect(viewModel.document.history.count == noOpHistoryCount)
        #expect(viewModel.undoStack.count == noOpUndoCount)
        #expect(viewModel.canRedo)
        #expect(
            !viewModel.setSelectedLayerGradientOverlayCanvasStopOpacity(
                at: 0,
                to: .nan
            )
        )
        #expect(
            !viewModel.setSelectedLayerGradientOverlayCanvasStopOpacity(
                at: originalStops.count,
                to: 0.5
            )
        )

        #expect(
            viewModel.setSelectedLayerGradientOverlayCanvasStopOpacity(
                at: 2,
                to: -1
            )
        )
        #expect(viewModel.selectedLayerGradientOverlayColorStops[2].alpha == 0)
    }

    @Test func addingGradientOverlayCanvasStopInterpolatesAndHonorsLimits() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.gradientOverlayStartColor = .black
        viewModel.document.layers[selectedIndex].style.gradientOverlayEndColor = .white
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let layerPixels = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let inserted = try #require(
            viewModel.addSelectedLayerGradientOverlayCanvasStop(at: geometry.center)
        )
        let stops = try #require(viewModel.document.selectedLayer?.style.gradientOverlayColorStops)
        #expect(inserted == 1)
        #expect(stops.count == 3)
        #expect(stops[1].position == 0.5)
        #expect(stops[1].red > 0 && stops[1].red < 1)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.document.selectedLayer?.image.qingtuPNGData() == layerPixels)
        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.style.gradientOverlayColorStops == nil)

        let reversed = gradientOverlayCenterViewModel()
        let reversedIndex = try #require(reversed.document.selectedLayerIndex)
        reversed.document.layers[reversedIndex].style.gradientOverlayReverse = true
        let reversedGeometry = try #require(reversed.selectedLayerGradientOverlayCanvasGeometry)
        let quarterPoint = CGPoint(
            x: reversedGeometry.axisStart.x
                + (reversedGeometry.axisEndpoint.x - reversedGeometry.axisStart.x) * 0.25,
            y: reversedGeometry.axisStart.y
                + (reversedGeometry.axisEndpoint.y - reversedGeometry.axisStart.y) * 0.25
        )
        _ = try #require(reversed.addSelectedLayerGradientOverlayCanvasStop(at: quarterPoint))
        let reversedStops = try #require(
            reversed.document.selectedLayer?.style.gradientOverlayColorStops
        )
        #expect(reversedStops[1].position == 0.75)

        let maximum = gradientOverlayCenterViewModel()
        let maximumIndex = try #require(maximum.document.selectedLayerIndex)
        maximum.document.layers[maximumIndex].style.setGradientOverlayColorStops(
            (0..<ImageEditorGradientFillContent.maximumColorStopCount).map { index in
                ImageEditorGradientColorStop(
                    position: Double(index)
                        / Double(ImageEditorGradientFillContent.maximumColorStopCount - 1),
                    color: .white
                )
            }
        )
        let maximumHistory = maximum.document.history.count
        #expect(maximum.addSelectedLayerGradientOverlayCanvasStop(at: geometry.center) == nil)
        #expect(maximum.document.history.count == maximumHistory)
    }

    @Test func editingGradientOverlayCanvasStopColorIsOneLiveUndoTransaction() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        let originalStops = [
            ImageEditorGradientColorStop(
                position: 0,
                color: NSColor(srgbRed: 0.1, green: 0.2, blue: 0.3, alpha: 0.4),
                midpoint: 0.35
            ),
            ImageEditorGradientColorStop(
                position: 0.45,
                color: NSColor(srgbRed: 0.4, green: 0.5, blue: 0.6, alpha: 0.7),
                midpoint: 0.65
            ),
            ImageEditorGradientColorStop(position: 1, color: .white)
        ]
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops(
            originalStops
        )
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasStopColor(at: 0))
        #expect(viewModel.updateSelectedLayerGradientOverlayCanvasStopColor(.systemOrange))
        #expect(
            viewModel.updateSelectedLayerGradientOverlayCanvasStopColor(
                originalStops[0].color
            )
        )
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)

        let previewColor = NSColor(srgbRed: 0.9, green: 0.15, blue: 0.25, alpha: 0.5)
        let finalColor = NSColor(srgbRed: 0.2, green: 0.75, blue: 0.35, alpha: 0.6)
        let finalDeviceColor = try #require(finalColor.usingColorSpace(.deviceRGB))
        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasStopColor(at: 1))
        #expect(viewModel.updateSelectedLayerGradientOverlayCanvasStopColor(previewColor))
        #expect(viewModel.updateSelectedLayerGradientOverlayCanvasStopColor(finalColor))
        #expect(viewModel.document.history.count == historyCount)
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()

        let changedStops = viewModel.selectedLayerGradientOverlayColorStops
        #expect(changedStops[0] == originalStops[0])
        #expect(changedStops[1].position == originalStops[1].position)
        #expect(changedStops[1].midpoint == originalStops[1].midpoint)
        #expect(changedStops[1].color.isEqual(finalDeviceColor))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(!viewModel.canRedo)

        viewModel.undo()
        #expect(viewModel.selectedLayerGradientOverlayColorStops == originalStops)
        viewModel.redo()
        #expect(
            viewModel.selectedLayerGradientOverlayColorStops[1].color.isEqual(finalDeviceColor)
        )

        let locked = gradientOverlayCenterViewModel()
        let lockedIndex = try #require(locked.document.selectedLayerIndex)
        locked.document.layers[lockedIndex].isLocked = true
        #expect(!locked.beginEditingSelectedLayerGradientOverlayCanvasStopColor(at: 0))
        #expect(!locked.hasActiveGradientOverlayStopTransaction)
        #expect(locked.undoStack.isEmpty)
    }

    @Test func gradientOverlayCanvasMidpointsMapAcrossStylesAndReverse() throws {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        let center = CGPoint(x: 0.5, y: 0.5)
        let stops = [
            ImageEditorGradientColorStop(
                position: 0,
                color: .systemRed,
                midpoint: 0.25
            ),
            ImageEditorGradientColorStop(
                position: 0.4,
                color: .systemGreen,
                midpoint: 0.75
            ),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ]
        let linear = ImageEditorGradientOverlayAxisGeometry.midpointHandlePoints(
            style: .linear,
            center: center,
            angle: 0,
            scale: 1,
            reverse: false,
            stops: stops,
            layerFrame: frame
        )
        #expect(linear.count == 2)
        #expect(linear[0].lowerStopIndex == 0)
        #expect(abs(linear[0].canvasPoint.x - 10) < 0.000_001)
        #expect(abs(linear[0].canvasPoint.y - 25) < 0.000_001)
        #expect(abs(linear[1].canvasPoint.x - 85) < 0.000_001)
        #expect(abs(linear[1].canvasPoint.y - 25) < 0.000_001)

        let reversed = ImageEditorGradientOverlayAxisGeometry.midpointHandlePoints(
            style: .linear,
            center: center,
            angle: 0,
            scale: 1,
            reverse: true,
            stops: stops,
            layerFrame: frame
        )
        #expect(abs(reversed[0].canvasPoint.x - 90) < 0.000_001)
        #expect(abs(reversed[0].canvasPoint.y - 25) < 0.000_001)
        #expect(abs(reversed[1].canvasPoint.x - 15) < 0.000_001)
        #expect(abs(reversed[1].canvasPoint.y - 25) < 0.000_001)
        let reversedMidpoint = try #require(
            ImageEditorGradientOverlayAxisGeometry.logicalMidpoint(
                after: 0,
                style: .linear,
                center: center,
                angle: 0,
                scale: 1,
                reverse: true,
                stops: stops,
                layerFrame: frame,
                canvasPoint: CGPoint(x: 80, y: 25)
            )
        )
        #expect(abs(reversedMidpoint - 0.5) < 0.000_001)

        for style in [
            ImageEditorGradientFillStyle.radial,
            .reflected,
            .diamond
        ] {
            let handle = try #require(
                ImageEditorGradientOverlayAxisGeometry.midpointHandlePoints(
                    style: style,
                    center: center,
                    angle: 0,
                    scale: 1,
                    reverse: false,
                    stops: stops,
                    layerFrame: frame
                ).first
            )
            let midpoint = try #require(
                ImageEditorGradientOverlayAxisGeometry.logicalMidpoint(
                    after: 0,
                    style: style,
                    center: center,
                    angle: 0,
                    scale: 1,
                    reverse: false,
                    stops: stops,
                    layerFrame: frame,
                    canvasPoint: handle.canvasPoint
                )
            )
            #expect(abs(midpoint - 0.25) < 0.000_001)
        }
    }

    @Test func removingGradientOverlayCanvasStopCommitsOnceAndUndoRestores() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.25, color: .systemGreen),
            ImageEditorGradientColorStop(position: 0.6, color: .systemBlue),
            ImageEditorGradientColorStop(position: 1, color: .white)
        ])
        let originalProjectData = try viewModel.projectData()
        let originalPixels = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        let result = try #require(
            viewModel.removeSelectedLayerGradientOverlayCanvasStop(at: 1)
        )
        let stops = try #require(
            viewModel.document.selectedLayer?.style.gradientOverlayColorStops
        )
        #expect(result.removedIndex == 1)
        #expect(result.nextSelectedIndex == 1)
        #expect(stops.count == 3)
        #expect(stops[1].position == 0.6)
        #expect(stops[1].blue == 1)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.document.selectedLayer?.image.qingtuPNGData() == originalPixels)

        viewModel.undo()
        #expect(try viewModel.projectData() == originalProjectData)

        let finalRemoval = try #require(
            viewModel.removeSelectedLayerGradientOverlayCanvasStop(at: 2)
        )
        #expect(finalRemoval.nextSelectedIndex == 1)
    }

    @Test func removingGradientOverlayCanvasStopProtectsEndpointsLocksAndTransactions() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.4, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.removeSelectedLayerGradientOverlayCanvasStop(at: 0) == nil)
        #expect(viewModel.removeSelectedLayerGradientOverlayCanvasStop(at: 2) == nil)
        #expect(!viewModel.beginEditingSelectedLayerGradientOverlayCanvasStop(at: 0))
        #expect(
            !viewModel.nudgeSelectedLayerGradientOverlayCanvasStop(
                at: 0,
                displayedDelta: 0.1
            )
        )
        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasStop(at: 1))
        #expect(viewModel.removeSelectedLayerGradientOverlayCanvasStop(at: 1) == nil)
        #expect(viewModel.cancelEditingSelectedLayerGradientOverlayCanvasStop())
        viewModel.document.layers[selectedIndex].isLocked = true
        #expect(viewModel.removeSelectedLayerGradientOverlayCanvasStop(at: 1) == nil)
        viewModel.document.layers[selectedIndex].isLocked = false

        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)

        let twoStops = gradientOverlayCenterViewModel()
        #expect(twoStops.removeSelectedLayerGradientOverlayCanvasStop(at: 1) == nil)
        #expect(twoStops.undoStack.isEmpty)
    }

    @Test func gradientOverlayCanvasStopKeyboardNudgeUsesDisplayedDirectionAndSteps() throws {
        let left = try #require(
            ImageEditorArrowNudge.delta(for: 123, modifierFlags: [])
        )
        let optionRight = try #require(
            ImageEditorArrowNudge.delta(for: 124, modifierFlags: [.option])
        )
        let shiftRight = try #require(
            ImageEditorArrowNudge.delta(for: 124, modifierFlags: [.shift])
        )
        #expect(
            ImageEditorGradientOverlayStopKeyboardAction.resolve(delta: left)
                == .nudge(-0.01)
        )
        #expect(
            ImageEditorGradientOverlayStopKeyboardAction.resolve(delta: optionRight)
                == .nudge(0.05)
        )
        #expect(
            ImageEditorGradientOverlayStopKeyboardAction.resolve(delta: shiftRight)
                == .nudge(0.1)
        )
        #expect(
            ImageEditorGradientOverlayStopKeyboardAction.resolve(
                delta: CGSize(width: 0, height: 1)
            ) == .consume
        )

        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.5, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(
            viewModel.nudgeSelectedLayerGradientOverlayCanvasStop(
                at: 1,
                displayedDelta: 0.01
            )
        )
        #expect(
            abs(viewModel.selectedLayerGradientOverlayColorStops[1].position - 0.51)
                < 0.000_001
        )
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        viewModel.undo()

        viewModel.document.layers[selectedIndex].style.gradientOverlayReverse = true
        #expect(
            viewModel.nudgeSelectedLayerGradientOverlayCanvasStop(
                at: 1,
                displayedDelta: 0.1
            )
        )
        #expect(
            abs(viewModel.selectedLayerGradientOverlayColorStops[1].position - 0.4)
                < 0.000_001
        )
    }

    @Test func gradientOverlayCanvasHandleTabSelectionCyclesInDisplayedOrder() {
        typealias Selection = ImageEditorGradientOverlayCanvasHandleSelection
        typealias Policy = ImageEditorGradientOverlayCanvasHandleSelectionPolicy

        #expect(
            Policy.next(
                current: nil,
                stopCount: 1,
                isReversed: false,
                movesBackward: false
            ) == nil
        )
        #expect(
            Policy.next(
                current: nil,
                stopCount: 4,
                isReversed: false,
                movesBackward: false
            ) == Selection.stop(0)
        )
        #expect(
            Policy.next(
                current: .stop(0),
                stopCount: 4,
                isReversed: false,
                movesBackward: false
            ) == Selection.midpoint(after: 0)
        )
        #expect(
            Policy.next(
                current: .midpoint(after: 0),
                stopCount: 4,
                isReversed: false,
                movesBackward: false
            ) == Selection.stop(1)
        )
        #expect(
            Policy.next(
                current: .midpoint(after: 2),
                stopCount: 4,
                isReversed: false,
                movesBackward: false
            ) == Selection.stop(3)
        )
        #expect(
            Policy.next(
                current: .stop(3),
                stopCount: 4,
                isReversed: false,
                movesBackward: false
            ) == Selection.stop(0)
        )
        #expect(
            Policy.next(
                current: nil,
                stopCount: 4,
                isReversed: false,
                movesBackward: true
            ) == Selection.stop(3)
        )
        #expect(
            Policy.next(
                current: nil,
                stopCount: 4,
                isReversed: true,
                movesBackward: false
            ) == Selection.stop(3)
        )
        #expect(
            Policy.next(
                current: .stop(3),
                stopCount: 4,
                isReversed: true,
                movesBackward: false
            ) == Selection.midpoint(after: 2)
        )
        #expect(
            Policy.next(
                current: .midpoint(after: 2),
                stopCount: 4,
                isReversed: true,
                movesBackward: false
            ) == Selection.stop(2)
        )
        #expect(
            Policy.next(
                current: nil,
                stopCount: 2,
                isReversed: false,
                movesBackward: false
            ) == Selection.stop(0)
        )
        #expect(
            ImageEditorGradientOverlayCanvasTabKeyPolicy.matches(
                keyCode: 48,
                modifierFlags: [],
                isTextInputActive: false
            )
        )
        #expect(
            ImageEditorGradientOverlayCanvasTabKeyPolicy.matches(
                keyCode: 48,
                modifierFlags: [.shift],
                isTextInputActive: false
            )
        )
        #expect(
            !ImageEditorGradientOverlayCanvasTabKeyPolicy.matches(
                keyCode: 48,
                modifierFlags: [.option],
                isTextInputActive: false
            )
        )
        #expect(
            !ImageEditorGradientOverlayCanvasTabKeyPolicy.matches(
                keyCode: 48,
                modifierFlags: [],
                isTextInputActive: true
            )
        )
        #expect(
            !ImageEditorGradientOverlayCanvasTabKeyPolicy.matches(
                keyCode: 49,
                modifierFlags: [],
                isTextInputActive: false
            )
        )
    }

    @Test func gradientOverlayCanvasHandleHomeEndUsesDisplayedBoundariesAndReverse() throws {
        #expect(
            ImageEditorGradientOverlayCanvasBoundaryKeyPolicy.displayedDelta(
                keyCode: 115,
                modifierFlags: [],
                isTextInputActive: false
            ) == -1
        )
        #expect(
            ImageEditorGradientOverlayCanvasBoundaryKeyPolicy.displayedDelta(
                keyCode: 119,
                modifierFlags: [],
                isTextInputActive: false
            ) == 1
        )
        #expect(
            ImageEditorGradientOverlayCanvasBoundaryKeyPolicy.displayedDelta(
                keyCode: 115,
                modifierFlags: [.shift],
                isTextInputActive: false
            ) == nil
        )
        #expect(
            ImageEditorGradientOverlayCanvasBoundaryKeyPolicy.displayedDelta(
                keyCode: 119,
                modifierFlags: [],
                isTextInputActive: true
            ) == nil
        )

        let stopViewModel = gradientOverlayCenterViewModel()
        let stopLayerIndex = try #require(stopViewModel.document.selectedLayerIndex)
        stopViewModel.document.layers[stopLayerIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.5, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        #expect(
            stopViewModel.nudgeSelectedLayerGradientOverlayCanvasStop(
                at: 1,
                displayedDelta: -1
            )
        )
        #expect(
            abs(stopViewModel.selectedLayerGradientOverlayColorStops[1].position - 0.01)
                < 0.000_001
        )

        let reversedViewModel = gradientOverlayCenterViewModel()
        let reversedLayerIndex = try #require(reversedViewModel.document.selectedLayerIndex)
        reversedViewModel.document.layers[reversedLayerIndex].style.gradientOverlayReverse = true
        #expect(
            reversedViewModel.nudgeSelectedLayerGradientOverlayCanvasMidpoint(
                after: 0,
                displayedDelta: -1
            )
        )
        #expect(
            abs(reversedViewModel.selectedLayerGradientOverlayColorStops[0].midpoint - 1)
                < 0.000_001
        )
    }

    @Test func gradientOverlayCanvasStopKeyboardNudgeAtBoundaryIsHistoryNoOp() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.99, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(
            !viewModel.nudgeSelectedLayerGradientOverlayCanvasStop(
                at: 1,
                displayedDelta: 0.1
            )
        )
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasMidpoint(after: 0))
        #expect(
            !viewModel.nudgeSelectedLayerGradientOverlayCanvasStop(
                at: 1,
                displayedDelta: -0.01
            )
        )
        #expect(viewModel.cancelEditingSelectedLayerGradientOverlayCanvasMidpoint())
        #expect(try viewModel.projectData() == originalProjectData)
    }

    @Test func gradientOverlayCanvasMidpointKeyboardNudgeUsesDisplayedDistanceAndReverse() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(
                position: 0,
                color: .systemRed,
                midpoint: 0.5
            ),
            ImageEditorGradientColorStop(position: 0.25, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(
            viewModel.nudgeSelectedLayerGradientOverlayCanvasMidpoint(
                after: 0,
                displayedDelta: 0.01
            )
        )
        #expect(
            abs(viewModel.selectedLayerGradientOverlayColorStops[0].midpoint - 0.54)
                < 0.000_001
        )
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        viewModel.undo()

        viewModel.document.layers[selectedIndex].style.gradientOverlayReverse = true
        #expect(
            viewModel.nudgeSelectedLayerGradientOverlayCanvasMidpoint(
                after: 0,
                displayedDelta: 0.05
            )
        )
        #expect(
            abs(viewModel.selectedLayerGradientOverlayColorStops[0].midpoint - 0.3)
                < 0.000_001
        )
    }

    @Test func gradientOverlayCanvasMidpointKeyboardBoundaryIsHistoryNoOp() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(
                position: 0,
                color: .systemRed,
                midpoint: 1
            ),
            ImageEditorGradientColorStop(position: 0.5, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(
            !viewModel.nudgeSelectedLayerGradientOverlayCanvasMidpoint(
                after: 0,
                displayedDelta: 0.1
            )
        )
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasStop(at: 1))
        #expect(
            !viewModel.nudgeSelectedLayerGradientOverlayCanvasMidpoint(
                after: 0,
                displayedDelta: -0.01
            )
        )
        #expect(viewModel.cancelEditingSelectedLayerGradientOverlayCanvasStop())
        #expect(try viewModel.projectData() == originalProjectData)
    }

    @Test func gradientOverlayCanvasMidpointResetCommitsOnceAndSupportsUndoRedo() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(
                position: 0,
                color: .systemRed,
                midpoint: 0.2
            ),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.resetSelectedLayerGradientOverlayCanvasMidpoint(after: 0))
        #expect(
            abs(viewModel.selectedLayerGradientOverlayColorStops[0].midpoint - 0.5)
                < 0.000_001
        )
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)

        viewModel.undo()
        #expect(
            abs(viewModel.selectedLayerGradientOverlayColorStops[0].midpoint - 0.2)
                < 0.000_001
        )
        viewModel.redo()
        #expect(
            abs(viewModel.selectedLayerGradientOverlayColorStops[0].midpoint - 0.5)
                < 0.000_001
        )
    }

    @Test func gradientOverlayCanvasMidpointResetAtDefaultPreservesHistoryAndRedo() throws {
        let viewModel = gradientOverlayCenterViewModel()
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(!viewModel.resetSelectedLayerGradientOverlayCanvasMidpoint(after: 0))
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)
    }

    @Test func draggingGradientOverlayCanvasStopCommitsOnceAndRoundTripPreservesRedo() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.4, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let originalHandle = try #require(
            viewModel.selectedLayerGradientOverlayCanvasStopHandlePoints.first {
                $0.index == 1
            }
        )
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let target = CGPoint(
            x: geometry.axisStart.x
                + (geometry.axisEndpoint.x - geometry.axisStart.x) * 0.7,
            y: geometry.axisStart.y
                + (geometry.axisEndpoint.y - geometry.axisStart.y) * 0.7
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasStop(at: 1))
        viewModel.updateSelectedLayerGradientOverlayCanvasStop(to: target)
        viewModel.updateSelectedLayerGradientOverlayCanvasStop(to: originalHandle.canvasPoint)
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasStop(at: 1))
        viewModel.updateSelectedLayerGradientOverlayCanvasStop(to: target)
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()
        let movedStops = try #require(
            viewModel.document.selectedLayer?.style.gradientOverlayColorStops
        )
        #expect(abs(movedStops[1].position - 0.7) < 0.000_001)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(!viewModel.canRedo)
        viewModel.undo()
        #expect(
            viewModel.document.selectedLayer?.style.resolvedGradientOverlayColorStops[1].position
                == 0.4
        )
    }

    @Test func gradientOverlayCanvasStopShiftSnapUsesFivePercentGridAndReverse() throws {
        #expect(
            abs(
                ImageEditorGradientOverlayCanvasHandleSnap.value(
                    0.373,
                    snappingToStep: true
                ) - 0.35
            ) < 0.000_001
        )
        #expect(
            ImageEditorGradientOverlayCanvasHandleSnap.value(
                0.373,
                snappingToStep: false
            ) == 0.373
        )
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.gradientOverlayReverse = true
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.5, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let target = CGPoint(
            x: geometry.axisStart.x
                + (geometry.axisEndpoint.x - geometry.axisStart.x) * 0.373,
            y: geometry.axisStart.y
                + (geometry.axisEndpoint.y - geometry.axisStart.y) * 0.373
        )

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasStop(at: 1))
        viewModel.updateSelectedLayerGradientOverlayCanvasStop(
            to: target,
            snappingToStep: true
        )
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()
        #expect(
            abs(viewModel.selectedLayerGradientOverlayColorStops[1].position - 0.65)
                < 0.000_001
        )
    }

    @Test func gradientOverlayCanvasMidpointShiftSnapUsesSegmentPercentGrid() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.4, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let target = CGPoint(
            x: geometry.axisStart.x
                + (geometry.axisEndpoint.x - geometry.axisStart.x) * 0.133,
            y: geometry.axisStart.y
                + (geometry.axisEndpoint.y - geometry.axisStart.y) * 0.133
        )

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasMidpoint(after: 0))
        viewModel.updateSelectedLayerGradientOverlayCanvasMidpoint(
            to: target,
            snappingToStep: true
        )
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasMidpoint()
        #expect(
            abs(viewModel.selectedLayerGradientOverlayColorStops[0].midpoint - 0.35)
                < 0.000_001
        )
    }

    @Test func gradientOverlayCanvasStopDuplicationChoosesDragSideAndHonorsLimits() throws {
        let source = ImageEditorGradientColorStop(
            position: 0.4,
            red: 0.2,
            green: 0.7,
            blue: 0.3,
            alpha: 0.6,
            midpoint: 0.35
        )
        let stops = [
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            source,
            ImageEditorGradientColorStop(position: 0.41, color: .systemYellow),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ]
        let result = try #require(
            ImageEditorGradientOverlayStopDraftEditing.duplicatingStop(
                stops,
                at: 1,
                toward: 0.8
            )
        )
        #expect(result.duplicateIndex == 1)
        #expect(abs(result.stops[1].position - 0.39) < 0.000_001)
        #expect(result.stops[1].red == source.red)
        #expect(result.stops[1].green == source.green)
        #expect(result.stops[1].blue == source.blue)
        #expect(result.stops[1].alpha == source.alpha)
        #expect(result.stops[1].midpoint == source.midpoint)

        let maximumStops = (0..<ImageEditorGradientFillContent.maximumColorStopCount).map {
            ImageEditorGradientColorStop(
                position: Double($0)
                    / Double(ImageEditorGradientFillContent.maximumColorStopCount - 1),
                color: .systemRed
            )
        }
        #expect(
            ImageEditorGradientOverlayStopDraftEditing.duplicatingStop(
                maximumStops,
                at: 1,
                toward: 0.2
            ) == nil
        )
        #expect(
            !ImageEditorGradientOverlayStopDuplicateGesturePolicy.hasStartedDrag(
                from: .zero,
                to: CGPoint(x: 1.9, y: 0)
            )
        )
        #expect(
            ImageEditorGradientOverlayStopDuplicateGesturePolicy.hasStartedDrag(
                from: .zero,
                to: CGPoint(x: 2, y: 0)
            )
        )

        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops(
            maximumStops
        )
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let target = CGPoint(
            x: geometry.axisStart.x
                + (geometry.axisEndpoint.x - geometry.axisStart.x) * 0.2,
            y: geometry.axisStart.y
                + (geometry.axisEndpoint.y - geometry.axisStart.y) * 0.2
        )
        let originalProjectData = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        #expect(
            viewModel.beginDuplicatingSelectedLayerGradientOverlayCanvasStop(
                at: 1,
                toward: target
            ) == nil
        )
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func optionDraggingGradientOverlayCanvasStopDuplicatesOnceWithReverseAndSnap() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        let source = ImageEditorGradientColorStop(
            position: 0.4,
            red: 0.2,
            green: 0.7,
            blue: 0.3,
            alpha: 0.6,
            midpoint: 0.35
        )
        viewModel.document.layers[selectedIndex].style.gradientOverlayReverse = true
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            source,
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let target = CGPoint(
            x: geometry.axisStart.x
                + (geometry.axisEndpoint.x - geometry.axisStart.x) * 0.73,
            y: geometry.axisStart.y
                + (geometry.axisEndpoint.y - geometry.axisStart.y) * 0.73
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(
            viewModel.beginDuplicatingSelectedLayerGradientOverlayCanvasStop(
                at: 1,
                toward: target
            ) == 1
        )
        viewModel.updateSelectedLayerGradientOverlayCanvasStop(
            to: target,
            snappingToStep: true
        )
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()

        let duplicatedStops = viewModel.selectedLayerGradientOverlayColorStops
        #expect(duplicatedStops.count == 4)
        #expect(abs(duplicatedStops[1].position - 0.25) < 0.000_001)
        #expect(duplicatedStops[1].red == source.red)
        #expect(duplicatedStops[1].green == source.green)
        #expect(duplicatedStops[1].blue == source.blue)
        #expect(duplicatedStops[1].alpha == source.alpha)
        #expect(duplicatedStops[1].midpoint == source.midpoint)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.text("imageEditor.history.gradientOverlayStopDuplicated")
        )

        viewModel.undo()
        #expect(viewModel.selectedLayerGradientOverlayColorStops.count == 3)
        #expect(viewModel.selectedLayerGradientOverlayColorStops[1] == source)
    }

    @Test func cancellingGradientOverlayCanvasStopDuplicationRestoresRedo() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.4, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let target = CGPoint(
            x: geometry.axisStart.x
                + (geometry.axisEndpoint.x - geometry.axisStart.x) * 0.7,
            y: geometry.axisStart.y
                + (geometry.axisEndpoint.y - geometry.axisStart.y) * 0.7
        )

        #expect(
            viewModel.beginDuplicatingSelectedLayerGradientOverlayCanvasStop(
                at: 1,
                toward: target
            ) == 2
        )
        viewModel.updateSelectedLayerGradientOverlayCanvasStop(to: target)
        #expect(viewModel.cancelEditingSelectedLayerGradientOverlayCanvasStop())
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)
    }

    @Test func gradientOverlayCanvasStopReorderingCrossesNeighborsAndResolvesDirectionalTies() throws {
        let source = ImageEditorGradientColorStop(
            position: 0.25,
            red: 0.2,
            green: 0.7,
            blue: 0.3,
            alpha: 0.6,
            midpoint: 0.35
        )
        let stops = [
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            source,
            ImageEditorGradientColorStop(position: 0.5, color: .systemYellow),
            ImageEditorGradientColorStop(position: 0.75, color: .systemPurple),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ]
        let crossed = ImageEditorGradientOverlayStopDraftEditing.reorderingStop(
            stops,
            at: 1,
            to: 0.8
        )
        #expect(crossed.movedIndex == 3)
        #expect(crossed.stops.map(\.position) == [0, 0.5, 0.75, 0.8, 1])
        #expect(crossed.stops[3].red == source.red)
        #expect(crossed.stops[3].green == source.green)
        #expect(crossed.stops[3].blue == source.blue)
        #expect(crossed.stops[3].alpha == source.alpha)
        #expect(crossed.stops[3].midpoint == source.midpoint)

        let rightwardTie = ImageEditorGradientOverlayStopDraftEditing.reorderingStop(
            stops,
            at: 1,
            to: 0.5
        )
        #expect(rightwardTie.movedIndex == 1)
        #expect(abs(rightwardTie.stops[1].position - 0.49) < 0.000_001)

        let leftwardTie = ImageEditorGradientOverlayStopDraftEditing.reorderingStop(
            stops,
            at: 3,
            to: 0.5
        )
        #expect(leftwardTie.movedIndex == 3)
        #expect(abs(leftwardTie.stops[3].position - 0.51) < 0.000_001)
    }

    @Test func draggingGradientOverlayCanvasStopAcrossNeighborsTracksIndexAndUndo() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        let source = ImageEditorGradientColorStop(
            position: 0.25,
            red: 0.2,
            green: 0.7,
            blue: 0.3,
            alpha: 0.6,
            midpoint: 0.35
        )
        let originalStops = [
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            source,
            ImageEditorGradientColorStop(position: 0.5, color: .systemYellow),
            ImageEditorGradientColorStop(position: 0.75, color: .systemPurple),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ]
        viewModel.document.layers[selectedIndex].style.gradientOverlayReverse = true
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops(originalStops)
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let target = CGPoint(
            x: geometry.axisStart.x
                + (geometry.axisEndpoint.x - geometry.axisStart.x) * 0.17,
            y: geometry.axisStart.y
                + (geometry.axisEndpoint.y - geometry.axisStart.y) * 0.17
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasStop(at: 1))
        #expect(
            viewModel.updateSelectedLayerGradientOverlayCanvasStop(
                to: target,
                snappingToStep: true
            ) == 3
        )
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()

        let reorderedStops = viewModel.selectedLayerGradientOverlayColorStops
        let expectedPositions = [0.0, 0.5, 0.75, 0.85, 1.0]
        #expect(
            zip(reorderedStops.map(\.position), expectedPositions).allSatisfy {
                abs($0 - $1) < 0.000_001
            }
        )
        #expect(reorderedStops[3].red == source.red)
        #expect(reorderedStops[3].green == source.green)
        #expect(reorderedStops[3].blue == source.blue)
        #expect(reorderedStops[3].alpha == source.alpha)
        #expect(reorderedStops[3].midpoint == source.midpoint)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)

        viewModel.undo()
        #expect(viewModel.selectedLayerGradientOverlayColorStops == originalStops)
    }

    @Test func gradientOverlayCanvasStopRemovalUsesPerpendicularInfiniteAxisDistance() {
        let axisStart = CGPoint(x: 0, y: 0)
        let axisEnd = CGPoint(x: 100, y: 0)
        #expect(
            !ImageEditorGradientOverlayStopRemovalGesturePolicy.shouldRemove(
                pointer: CGPoint(x: 180, y: 0),
                axisStart: axisStart,
                axisEnd: axisEnd
            )
        )
        #expect(
            !ImageEditorGradientOverlayStopRemovalGesturePolicy.shouldRemove(
                pointer: CGPoint(x: 50, y: 35.9),
                axisStart: axisStart,
                axisEnd: axisEnd
            )
        )
        #expect(
            ImageEditorGradientOverlayStopRemovalGesturePolicy.shouldRemove(
                pointer: CGPoint(x: 50, y: 36),
                axisStart: axisStart,
                axisEnd: axisEnd
            )
        )
        #expect(
            !ImageEditorGradientOverlayStopRemovalGesturePolicy.shouldRemove(
                pointer: CGPoint(x: 50, y: 100),
                axisStart: axisStart,
                axisEnd: axisStart
            )
        )
    }

    @Test func draggingGradientOverlayCanvasStopAwayRemovesOnceAndUndoRestores() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        let originalStops = [
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.25, color: .systemGreen),
            ImageEditorGradientColorStop(position: 0.5, color: .systemYellow),
            ImageEditorGradientColorStop(position: 0.75, color: .systemPurple),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ]
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops(originalStops)
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let target = CGPoint(
            x: geometry.axisStart.x
                + (geometry.axisEndpoint.x - geometry.axisStart.x) * 0.8,
            y: geometry.axisStart.y
                + (geometry.axisEndpoint.y - geometry.axisStart.y) * 0.8
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasStop(at: 1))
        #expect(viewModel.updateSelectedLayerGradientOverlayCanvasStop(to: target) == 3)
        #expect(viewModel.removeEditingSelectedLayerGradientOverlayCanvasStop() == 1)
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()

        #expect(
            viewModel.selectedLayerGradientOverlayColorStops
                == [originalStops[0], originalStops[2], originalStops[3], originalStops[4]]
        )
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(
            viewModel.document.history.last?.title
                == L10n.text("imageEditor.history.gradientOverlayStopRemoved")
        )

        viewModel.undo()
        #expect(viewModel.selectedLayerGradientOverlayColorStops == originalStops)
    }

    @Test func draggingDuplicatedGradientOverlayStopAwayCancelsCopyAndPreservesRedo() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.4, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let target = CGPoint(
            x: geometry.axisStart.x
                + (geometry.axisEndpoint.x - geometry.axisStart.x) * 0.7,
            y: geometry.axisStart.y
                + (geometry.axisEndpoint.y - geometry.axisStart.y) * 0.7
        )

        #expect(
            viewModel.beginDuplicatingSelectedLayerGradientOverlayCanvasStop(
                at: 1,
                toward: target
            ) == 2
        )
        viewModel.updateSelectedLayerGradientOverlayCanvasStop(to: target)
        #expect(viewModel.removeEditingSelectedLayerGradientOverlayCanvasStop() == 1)
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()

        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)
    }

    @Test func undoCancelsActiveGradientOverlayCanvasStopBeforeHistory() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(position: 0.4, color: .systemGreen),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        #expect(viewModel.setSelectedLayerGradientOverlayScale(1.5) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let target = CGPoint(x: geometry.axisEndpoint.x, y: geometry.axisEndpoint.y)
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasStop(at: 1))
        viewModel.updateSelectedLayerGradientOverlayCanvasStop(to: target)
        #expect(viewModel.canRedo)
        viewModel.undo()
        #expect(!viewModel.hasActiveGradientOverlayStopTransaction)
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(viewModel.selectedLayerGradientOverlayScale == 1.5)
    }

    @Test func draggingGradientOverlayCanvasMidpointCommitsOnceAndPreservesRedo() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(
                position: 0,
                color: .systemRed,
                midpoint: 0.3
            ),
            ImageEditorGradientColorStop(
                position: 0.4,
                color: .systemGreen,
                midpoint: 0.6
            ),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let originalHandle = try #require(
            viewModel.selectedLayerGradientOverlayCanvasMidpointHandlePoints.first
        )
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let target = CGPoint(
            x: geometry.axisStart.x
                + (geometry.axisEndpoint.x - geometry.axisStart.x) * 0.32,
            y: geometry.axisStart.y
                + (geometry.axisEndpoint.y - geometry.axisStart.y) * 0.32
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(
            viewModel.beginEditingSelectedLayerGradientOverlayCanvasMidpoint(after: 0)
        )
        viewModel.updateSelectedLayerGradientOverlayCanvasMidpoint(to: target)
        viewModel.updateSelectedLayerGradientOverlayCanvasMidpoint(
            to: originalHandle.canvasPoint
        )
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasMidpoint()
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)

        #expect(
            viewModel.beginEditingSelectedLayerGradientOverlayCanvasMidpoint(after: 0)
        )
        viewModel.updateSelectedLayerGradientOverlayCanvasMidpoint(to: target)
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasMidpoint()
        let movedStops = try #require(
            viewModel.document.selectedLayer?.style.gradientOverlayColorStops
        )
        #expect(abs(movedStops[0].midpoint - 0.8) < 0.000_001)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(!viewModel.canRedo)
        viewModel.undo()
        let restoredMidpoint = try #require(
            viewModel.document.selectedLayer?.style.resolvedGradientOverlayColorStops[0]
                .midpoint
        )
        #expect(abs(restoredMidpoint - 0.3) < 0.000_001)
    }

    @Test func undoCancelsActiveGradientOverlayCanvasMidpointBeforeHistory() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].style.setGradientOverlayColorStops([
            ImageEditorGradientColorStop(position: 0, color: .systemRed),
            ImageEditorGradientColorStop(
                position: 0.4,
                color: .systemGreen,
                midpoint: 0.6
            ),
            ImageEditorGradientColorStop(position: 1, color: .systemBlue)
        ])
        #expect(viewModel.setSelectedLayerGradientOverlayScale(1.5) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        let undoCount = viewModel.undoStack.count

        #expect(
            viewModel.beginEditingSelectedLayerGradientOverlayCanvasMidpoint(after: 1)
        )
        viewModel.updateSelectedLayerGradientOverlayCanvasMidpoint(
            to: geometry.axisEndpoint
        )
        #expect(viewModel.canRedo)
        viewModel.undo()
        #expect(!viewModel.hasActiveGradientOverlayMidpointTransaction)
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(viewModel.selectedLayerGradientOverlayScale == 1.5)
    }

    @Test func gradientOverlayAxisGeometryClampsScaleAndRejectsDegenerateInput() throws {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        let center = CGPoint(x: 0.5, y: 0.5)
        let minimum = try #require(
            ImageEditorGradientOverlayAxisGeometry.updatedAxis(
                style: .diamond,
                center: center,
                currentAngle: 0,
                layerFrame: frame,
                canvasPoint: CGPoint(x: 51, y: 25),
                snappingAngle: false
            )
        )
        #expect(minimum.scale == 0.25)
        let maximum = try #require(
            ImageEditorGradientOverlayAxisGeometry.updatedAxis(
                style: .linear,
                center: center,
                currentAngle: 0,
                layerFrame: frame,
                canvasPoint: CGPoint(x: 5000, y: 25),
                snappingAngle: false
            )
        )
        #expect(maximum.scale == 4)
        #expect(
            ImageEditorGradientOverlayAxisGeometry.updatedAxis(
                style: .linear,
                center: center,
                currentAngle: 0,
                layerFrame: frame,
                canvasPoint: CGPoint(x: 50, y: 25),
                snappingAngle: false
            ) == nil
        )
        #expect(
            ImageEditorGradientOverlayAxisGeometry.canvasGeometry(
                style: .linear,
                center: center,
                angle: 0,
                scale: 1,
                layerFrame: .zero
            ) == nil
        )
    }

    @Test func draggingGradientOverlayAxisCommitsOnceAndRoundTripPreservesRedo() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let originalGeometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        #expect(viewModel.setSelectedLayerGradientOverlayAngle(15) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let undoCount = viewModel.undoStack.count
        let historyCount = viewModel.document.history.count
        #expect(viewModel.canRedo)

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasAxis())
        viewModel.updateSelectedLayerGradientOverlayCanvasAxis(
            to: CGPoint(x: originalGeometry.center.x, y: originalGeometry.center.y + 80),
            snappingAngle: true
        )
        viewModel.updateSelectedLayerGradientOverlayCanvasAxis(
            to: originalGeometry.axisEndpoint,
            snappingAngle: false
        )
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasAxis()
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.canRedo)

        viewModel.redo()
        #expect(viewModel.selectedLayerGradientOverlayAngle == 15)
        let historyAfterRedo = viewModel.document.history.count
        let undoAfterRedo = viewModel.undoStack.count
        let centerPoint = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry?.center)
        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasAxis())
        viewModel.updateSelectedLayerGradientOverlayCanvasAxis(
            to: CGPoint(x: centerPoint.x, y: centerPoint.y + 80),
            snappingAngle: true
        )
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasAxis()
        #expect(viewModel.selectedLayerGradientOverlayAngle == 90)
        #expect(viewModel.document.history.count == historyAfterRedo + 1)
        #expect(viewModel.undoStack.count == undoAfterRedo + 1)
        #expect(!viewModel.canRedo)
        viewModel.undo()
        #expect(viewModel.selectedLayerGradientOverlayAngle == 15)
    }

    @Test func undoAndRedoCancelActiveGradientOverlayAxisBeforeHistory() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let geometry = try #require(viewModel.selectedLayerGradientOverlayCanvasGeometry)
        #expect(viewModel.setSelectedLayerGradientOverlayScale(1.5) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let undoCount = viewModel.undoStack.count
        let historyCount = viewModel.document.history.count

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasAxis())
        viewModel.updateSelectedLayerGradientOverlayCanvasAxis(
            to: CGPoint(x: geometry.center.x, y: geometry.center.y + 60),
            snappingAngle: false
        )
        #expect(viewModel.canRedo)
        viewModel.undo()
        #expect(!viewModel.hasActiveGradientOverlayAxisTransaction)
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.canRedo)

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasAxis())
        viewModel.updateSelectedLayerGradientOverlayCanvasAxis(
            to: CGPoint(x: geometry.center.x - 60, y: geometry.center.y),
            snappingAngle: false
        )
        viewModel.redo()
        #expect(!viewModel.hasActiveGradientOverlayAxisTransaction)
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.canRedo)
        viewModel.redo()
        #expect(viewModel.selectedLayerGradientOverlayScale == 1.5)
    }

    @Test func draggingGradientOverlayCenterCommitsOnceAndRoundTripPreservesRedo() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let layerFrame = try #require(viewModel.document.selectedLayer?.frame)
        #expect(viewModel.setSelectedLayerGradientOverlayCenterX(0.6) == 1)
        viewModel.undo()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        #expect(viewModel.canRedo)

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasCenter())
        viewModel.updateSelectedLayerGradientOverlayCanvasCenter(
            to: try #require(
                ImageEditorGradientOverlayCenterGeometry.canvasPoint(
                    center: CGPoint(x: 0.8, y: 0.7),
                    layerFrame: layerFrame
                )
            )
        )
        viewModel.updateSelectedLayerGradientOverlayCanvasCenter(
            to: try #require(
                ImageEditorGradientOverlayCenterGeometry.canvasPoint(
                    center: CGPoint(x: 0.5, y: 0.5),
                    layerFrame: layerFrame
                )
            )
        )
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasCenter()
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)

        viewModel.redo()
        #expect(viewModel.selectedLayerGradientOverlayCenterX == 0.6)
        let historyAfterRedo = viewModel.document.history.count
        let undoAfterRedo = viewModel.undoStack.count
        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasCenter())
        viewModel.updateSelectedLayerGradientOverlayCanvasCenter(
            to: try #require(
                ImageEditorGradientOverlayCenterGeometry.canvasPoint(
                    center: CGPoint(x: 0.8, y: 0.7),
                    layerFrame: layerFrame
                )
            )
        )
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasCenter()
        #expect(viewModel.selectedLayerGradientOverlayCenterX == 0.8)
        #expect(viewModel.selectedLayerGradientOverlayCenterY == 0.7)
        #expect(viewModel.document.history.count == historyAfterRedo + 1)
        #expect(viewModel.undoStack.count == undoAfterRedo + 1)
        #expect(!viewModel.canRedo)
        viewModel.undo()
        #expect(viewModel.selectedLayerGradientOverlayCenterX == 0.6)
        #expect(viewModel.selectedLayerGradientOverlayCenterY == 0.5)
    }

    @Test func cancellingGradientOverlayCenterRestoresDocumentRedoAndNextGesture() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let layerFrame = try #require(viewModel.document.selectedLayer?.frame)
        #expect(viewModel.setSelectedLayerGradientOverlayCenterX(0.6) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let undoCount = viewModel.undoStack.count
        #expect(viewModel.canRedo)

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasCenter())
        viewModel.updateSelectedLayerGradientOverlayCanvasCenter(
            to: CGPoint(x: layerFrame.maxX, y: layerFrame.maxY)
        )
        #expect(viewModel.hasActiveGradientOverlayCenterTransaction)
        #expect(viewModel.cancelEditingSelectedLayerGradientOverlayCanvasCenter())
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.canRedo)
        #expect(!viewModel.hasActiveGradientOverlayCenterTransaction)
        #expect(!viewModel.cancelEditingSelectedLayerGradientOverlayCanvasCenter())

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasCenter())
        viewModel.updateSelectedLayerGradientOverlayCanvasCenter(
            to: CGPoint(x: layerFrame.midX, y: layerFrame.maxY)
        )
        viewModel.finishEditingSelectedLayerGradientOverlayCanvasCenter()
        #expect(viewModel.selectedLayerGradientOverlayCenterY == 1)
        #expect(!viewModel.canRedo)
    }

    @Test func undoAndRedoCancelActiveGradientOverlayCenterDragBeforeHistory() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let layerFrame = try #require(viewModel.document.selectedLayer?.frame)
        #expect(viewModel.setSelectedLayerGradientOverlayCenterX(0.6) == 1)
        viewModel.undo()
        let originalProjectData = try viewModel.projectData()
        let undoCount = viewModel.undoStack.count
        let historyCount = viewModel.document.history.count

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasCenter())
        viewModel.updateSelectedLayerGradientOverlayCanvasCenter(
            to: CGPoint(x: layerFrame.maxX, y: layerFrame.maxY)
        )
        #expect(viewModel.canUndo)
        #expect(viewModel.canRedo)
        viewModel.undo()
        #expect(!viewModel.hasActiveGradientOverlayCenterTransaction)
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.canRedo)

        #expect(viewModel.beginEditingSelectedLayerGradientOverlayCanvasCenter())
        viewModel.updateSelectedLayerGradientOverlayCanvasCenter(
            to: CGPoint(x: layerFrame.minX, y: layerFrame.minY)
        )
        viewModel.redo()
        #expect(!viewModel.hasActiveGradientOverlayCenterTransaction)
        #expect(try viewModel.projectData() == originalProjectData)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.canRedo)

        viewModel.redo()
        #expect(viewModel.selectedLayerGradientOverlayCenterX == 0.6)
        #expect(!viewModel.canRedo)
    }

    @Test func gradientOverlayCenterCanvasWiringStaysOutOfComponentMode() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let percentageFieldSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "veilpic/ImageEditorPercentageField.swift"
            ),
            encoding: .utf8
        )
        #expect(source.contains("gradientOverlayCenterControlOverlay(in: geometry.size)"))
        #expect(source.contains("viewModel.selectedLeftSidebarTab == .tools"))
        #expect(source.contains("beginEditingSelectedLayerGradientOverlayCanvasCenter"))
        #expect(source.contains("updateSelectedLayerGradientOverlayCanvasCenter"))
        #expect(source.contains("finishEditingSelectedLayerGradientOverlayCanvasCenter"))
        #expect(source.contains("beginEditingSelectedLayerGradientOverlayCanvasAxis"))
        #expect(source.contains("updateSelectedLayerGradientOverlayCanvasAxis"))
        #expect(source.contains("finishEditingSelectedLayerGradientOverlayCanvasAxis"))
        #expect(source.contains("addSelectedLayerGradientOverlayCanvasStop"))
        #expect(source.contains("removeSelectedLayerGradientOverlayCanvasStop"))
        #expect(source.contains("nudgeSelectedLayerGradientOverlayCanvasStop"))
        #expect(source.contains("nudgeSelectedLayerGradientOverlayCanvasMidpoint"))
        #expect(source.contains("beginEditingSelectedLayerGradientOverlayCanvasStop"))
        #expect(source.contains("updateSelectedLayerGradientOverlayCanvasStop"))
        #expect(source.contains("finishEditingSelectedLayerGradientOverlayCanvasStop"))
        #expect(source.contains("gradientOverlayCanvasStopColorWell(at: stopIndex)"))
        #expect(source.contains("beginEditingSelectedLayerGradientOverlayCanvasStopColor"))
        #expect(source.contains("updateSelectedLayerGradientOverlayCanvasStopColor"))
        #expect(source.contains("image-editor-gradient-overlay-canvas-stop-color-"))
        #expect(source.contains("if !stopHandle.isEndpoint"))
        #expect(source.contains("ImageEditorPercentageField("))
        #expect(source.contains("imageEditor.option.gradientOverlayStopPosition"))
        #expect(source.contains("image-editor-gradient-overlay-canvas-stop-position-"))
        #expect(source.contains("setSelectedLayerGradientOverlayCanvasStopDisplayedPosition"))
        #expect(source.contains("imageEditor.option.gradientOverlayStopOpacity"))
        #expect(source.contains("image-editor-gradient-overlay-canvas-stop-opacity-"))
        #expect(source.contains("setSelectedLayerGradientOverlayCanvasStopOpacity"))
        #expect(source.contains("imageEditor.option.gradientOverlayMidpoint"))
        #expect(source.contains("image-editor-gradient-overlay-canvas-midpoint-position-"))
        #expect(source.contains("setSelectedLayerGradientOverlayCanvasMidpoint"))
        #expect(percentageFieldSource.contains(".onSubmit"))
        #expect(percentageFieldSource.contains(".onChange(of: isFocused)"))
        #expect(percentageFieldSource.contains("commitDraft()"))
        #expect(percentageFieldSource.contains("guard let value = ImageEditorPercentageDraft"))
        #expect(percentageFieldSource.contains("synchronizeDraft()"))
        #expect(source.contains("beginEditingSelectedLayerGradientOverlayCanvasMidpoint"))
        #expect(source.contains("updateSelectedLayerGradientOverlayCanvasMidpoint"))
        #expect(source.contains("finishEditingSelectedLayerGradientOverlayCanvasMidpoint"))
        #expect(source.contains("cancelGradientOverlayMidpointDragForLifecycle"))
        #expect(source.contains("selectedGradientOverlayStopIndex"))
        #expect(source.contains("deleteSelectedGradientOverlayStopIfNeeded"))
        #expect(source.contains("selectedGradientOverlayMidpointIndex"))
        #expect(source.contains("nudgeSelectedGradientOverlayHandleIfNeeded"))
        #expect(source.contains("resetSelectedGradientOverlayMidpointIfNeeded"))
        #expect(source.contains("imageEditor.action.resetGradientOverlayMidpoint"))
        #expect(source.contains("selectNextGradientOverlayCanvasHandle"))
        #expect(source.contains("selectNextCanvasHandle"))
        #expect(source.contains("ImageEditorGradientOverlayCanvasTabKeyPolicy.matches"))
        #expect(source.contains("ImageEditorGradientOverlayCanvasBoundaryKeyPolicy.displayedDelta"))
        #expect(source.contains("moveSelectedCanvasHandleToBoundary"))
        #expect(source.contains("beginDuplicatingSelectedLayerGradientOverlayCanvasStop"))
        #expect(source.contains("gradientOverlayStopDragDuplicates"))
        #expect(source.contains("NSEvent.modifierFlags.contains(.option)"))
        #expect(source.contains("ImageEditorGradientOverlayStopDuplicateGesturePolicy"))
        #expect(source.contains("isGradientOverlayStopDuplicateDragBlocked"))
        #expect(source.contains("isGradientOverlayStopDragRemovalPreview"))
        #expect(source.contains("Color.red.opacity(0.82)"))
        #expect(
            source.components(
                separatedBy: "ImageEditorGradientOverlayStopRemovalGesturePolicy\n                        .shouldRemove("
            ).count - 1 == 1
        )
        #expect(source.contains("ImageEditorGradientOverlayStopRemovalGesturePolicy.shouldRemove("))
        #expect(source.contains("removeEditingSelectedLayerGradientOverlayCanvasStop"))
        #expect(
            source.components(
                separatedBy: ".updateSelectedLayerGradientOverlayCanvasStop("
            ).count - 1 == 2
        )
        #expect(
            source.components(
                separatedBy: "snappingToStep: NSEvent.modifierFlags.contains(.shift)"
            ).count - 1 == 5
        )
        #expect(source.contains(".contextMenu"))
        #expect(source.contains("cancelGradientOverlayCanvasHandleDragForLifecycle"))
        #expect(source.contains("image-editor-gradient-overlay-center-handle"))
        #expect(source.contains("image-editor-gradient-overlay-axis-handle"))
        #expect(source.contains("image-editor-gradient-overlay-axis"))
        #expect(source.contains("image-editor-gradient-overlay-canvas-stop-"))
        #expect(source.contains("image-editor-gradient-overlay-canvas-midpoint-"))

        let toolOptionStart = try #require(source.range(of: "private var toolOptionBar:"))
        let toolOptionEnd = try #require(
            source.range(
                of: "private func componentLibraryOptionBar(",
                range: toolOptionStart.upperBound..<source.endIndex
            )
        )
        let toolOptionBlock = source[
            toolOptionStart.lowerBound..<toolOptionEnd.lowerBound
        ]
        #expect(toolOptionBlock.contains("viewModel.selectedTool == .move"))
        #expect(toolOptionBlock.contains("selectedGradientOverlayStopIndex"))
        #expect(toolOptionBlock.contains("viewModel.document.areExtrasVisible"))
        #expect(
            toolOptionBlock.contains(
                "viewModel.canEditSelectedLayerGradientOverlayCanvasCenter"
            )
        )
        #expect(toolOptionBlock.contains("gradientOverlayCanvasStopColorWell(at: stopIndex)"))

        let colorWellStart = try #require(
            source.range(of: "private func gradientOverlayCanvasStopColorWell")
        )
        let colorWellEnd = try #require(
            source.range(
                of: "private var canvasWorkspace:",
                range: colorWellStart.upperBound..<source.endIndex
            )
        )
        let colorWellBlock = source[colorWellStart.lowerBound..<colorWellEnd.lowerBound]
        #expect(
            colorWellBlock.contains(
                "beginEditingSelectedLayerGradientOverlayCanvasStopColor"
            )
        )
        #expect(
            colorWellBlock.contains("updateSelectedLayerGradientOverlayCanvasStopColor")
        )
        #expect(colorWellBlock.contains("finishEditingSelectedLayerGradientOverlayCanvasStop"))

        let stopHandleStart = try #require(
            source.range(of: "private func gradientOverlayStopHandleView")
        )
        let stopHandleEnd = try #require(
            source.range(
                of: "private func gradientOverlayMidpointHandleView",
                range: stopHandleStart.upperBound..<source.endIndex
            )
        )
        let stopHandleBlock = source[stopHandleStart.lowerBound..<stopHandleEnd.lowerBound]
        #expect(stopHandleBlock.contains("let isEndpoint = point.isEndpoint"))
        #expect(stopHandleBlock.contains("isEndpoint ? 20 : 14"))
        #expect(stopHandleBlock.contains("isEndpoint ? -3 : -7"))
        #expect(stopHandleBlock.contains("guard !isEndpoint else { return }"))
        #expect(stopHandleBlock.contains("if !isEndpoint {"))
        #expect(stopHandleBlock.contains("imageEditor.help.gradientOverlayEndpointHandle"))
        #expect(stopHandleBlock.contains("imageEditor.properties.shapeGradientStopAccessibility"))
        let optionCapture = try #require(
            stopHandleBlock.range(
                of: "gradientOverlayStopDragDuplicates = NSEvent.modifierFlags.contains(.option)"
            )
        )
        let dragThreshold = try #require(
            stopHandleBlock.range(of: ".hasStartedDrag(")
        )
        let duplicateBegin = try #require(
            stopHandleBlock.range(
                of: ".beginDuplicatingSelectedLayerGradientOverlayCanvasStop("
            )
        )
        #expect(optionCapture.lowerBound < dragThreshold.lowerBound)
        #expect(dragThreshold.lowerBound < duplicateBegin.lowerBound)
        let removalBranch = try #require(
            stopHandleBlock.range(of: "if shouldRemove {")
        )
        let removalCommit = try #require(
            stopHandleBlock.range(
                of: ".removeEditingSelectedLayerGradientOverlayCanvasStop()",
                range: removalBranch.upperBound..<stopHandleBlock.endIndex
            )
        )
        let stopFinish = try #require(
            stopHandleBlock.range(
                of: "viewModel.finishEditingSelectedLayerGradientOverlayCanvasStop()",
                range: removalCommit.upperBound..<stopHandleBlock.endIndex
            )
        )
        #expect(removalBranch.lowerBound < removalCommit.lowerBound)
        #expect(removalCommit.lowerBound < stopFinish.lowerBound)

        let endpointDeleteStart = try #require(
            source.range(of: "private func deleteSelectedGradientOverlayStopIfNeeded()")
        )
        let endpointDeleteEnd = try #require(
            source.range(
                of: "private func resetSelectedGradientOverlayMidpointIfNeeded()",
                range: endpointDeleteStart.upperBound..<source.endIndex
            )
        )
        let endpointDeleteBlock = source[
            endpointDeleteStart.lowerBound..<endpointDeleteEnd.lowerBound
        ]
        let endpointProtection = try #require(
            endpointDeleteBlock.range(of: "if selectedHandle.isEndpoint {")
        )
        let consumedDelete = try #require(
            endpointDeleteBlock.range(
                of: "return true",
                range: endpointProtection.upperBound..<endpointDeleteBlock.endIndex
            )
        )
        let actualRemoval = try #require(
            endpointDeleteBlock.range(
                of: "return removeGradientOverlayCanvasStop",
                range: consumedDelete.upperBound..<endpointDeleteBlock.endIndex
            )
        )
        #expect(consumedDelete.lowerBound < actualRemoval.lowerBound)

        let deleteStart = try #require(source.range(of: "deleteSelectedObject: {"))
        let deleteEnd = try #require(
            source.range(
                of: "finishPendingPenPath:",
                range: deleteStart.upperBound..<source.endIndex
            )
        )
        let deleteBlock = source[deleteStart.lowerBound..<deleteEnd.lowerBound]
        let cancelPosition = try #require(
            deleteBlock.range(of: "cancelGradientOverlayCanvasHandleDragForLifecycle()")
        )
        let removalPosition = try #require(
            deleteBlock.range(of: "deleteSelectedGradientOverlayStopIfNeeded()")
        )
        #expect(cancelPosition.lowerBound < removalPosition.lowerBound)

        let nudgeStart = try #require(source.range(of: "nudgeSelected: { delta in"))
        let nudgeEnd = try #require(
            source.range(
                of: "deleteSelectedObject:",
                range: nudgeStart.upperBound..<source.endIndex
            )
        )
        let nudgeBlock = source[nudgeStart.lowerBound..<nudgeEnd.lowerBound]
        let nudgeCancelPosition = try #require(
            nudgeBlock.range(of: "cancelGradientOverlayCanvasHandleDragForLifecycle()")
        )
        let nudgePosition = try #require(
            nudgeBlock.range(of: "nudgeSelectedGradientOverlayHandleIfNeeded(by: delta)")
        )
        #expect(nudgeCancelPosition.lowerBound < nudgePosition.lowerBound)
    }

    @Test func gradientOverlayCenterHandleRejectsLockedAndMultiLayerSelections() throws {
        let viewModel = gradientOverlayCenterViewModel()
        let selectedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[selectedIndex].isLocked = true
        let undoCount = viewModel.undoStack.count
        #expect(viewModel.selectedLayerGradientOverlayCanvasCenterPoint != nil)
        #expect(!viewModel.canEditSelectedLayerGradientOverlayCanvasCenter)
        #expect(!viewModel.beginEditingSelectedLayerGradientOverlayCanvasCenter())
        #expect(viewModel.undoStack.count == undoCount)

        viewModel.document.layers[selectedIndex].isLocked = false
        let second = ImageEditorLayer.blank(
            name: "Second",
            size: viewModel.document.canvasSize
        )
        viewModel.document.layers.append(second)
        let firstID = viewModel.document.layers[selectedIndex].id
        viewModel.document.selectedLayerIDs = [firstID, second.id]
        #expect(viewModel.selectedLayerGradientOverlayCanvasCenterPoint == nil)
        #expect(!viewModel.canEditSelectedLayerGradientOverlayCanvasCenter)
    }

    @Test func gradientOverlayReverseIsUndoableAndLegacyProjectsDefaultForward() throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "gradient-overlay-reverse.png",
            image: solidImage(color: .black, size: canvasSize)
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            centerRectImage(size: canvasSize, color: .white),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.setSelectedLayerGradientOverlayOpacity(1)
        viewModel.setSelectedLayerGradientOverlayStartColor(.systemRed)
        viewModel.setSelectedLayerGradientOverlayEndColor(.systemBlue)
        viewModel.setSelectedLayerGradientOverlayStyle(.linear)
        viewModel.setSelectedLayerGradientOverlayAngle(0)
        let sourcePixels = try #require(viewModel.document.selectedLayer?.image.qingtuPNGData())
        let forwardPixels = try #require(viewModel.currentImage.qingtuPNGData())
        let historyCount = viewModel.document.history.count

        #expect(viewModel.setSelectedLayerGradientOverlayReverse(true) == 1)
        #expect(viewModel.document.selectedLayer?.style.gradientOverlayReverse == true)
        let reversedPixels = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(reversedPixels != forwardPixels)
        #expect(viewModel.document.selectedLayer?.image.qingtuPNGData() == sourcePixels)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.setSelectedLayerGradientOverlayReverse(true) == 0)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.selectedLayer?.style.gradientOverlayReverse == false)
        #expect(viewModel.currentImage.qingtuPNGData() == forwardPixels)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.style.gradientOverlayReverse == true)
        #expect(viewModel.currentImage.qingtuPNGData() == reversedPixels)

        let encodedStyle = try JSONEncoder().encode(
            ImageEditorProjectLayerStyle(style: viewModel.document.selectedLayer!.style)
        )
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encodedStyle) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "gradientOverlayReverse")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyStyle = try JSONDecoder().decode(
            ImageEditorProjectLayerStyle.self,
            from: legacyData
        )
        #expect(!legacyStyle.layerStyle.gradientOverlayReverse)
    }

    @Test func gradientOverlayDitherIsUndoableNonDestructiveAndTransparentSafe() throws {
        let canvasSize = NSSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "gradient-overlay-dither.png",
            image: centerRectImage(size: canvasSize, color: .white)
        ) { _ in }
        viewModel.setSelectedLayerGradientOverlayOpacity(1)
        viewModel.setSelectedLayerGradientOverlayStartColor(.black)
        viewModel.setSelectedLayerGradientOverlayEndColor(.white)
        viewModel.setSelectedLayerGradientOverlayStyle(.linear)
        viewModel.setSelectedLayerGradientOverlayScale(1)
        viewModel.setSelectedLayerGradientOverlayAngle(0)
        var sharedGradient = ImageEditorGradientFillContent.shapeLinear(
            startColor: .black,
            endColor: .white
        )
        let plainGradientPixels = sharedGradient.renderedImage(size: canvasSize).qingtuPNGData()
        sharedGradient.dither = true
        #expect(sharedGradient.renderedImage(size: canvasSize).qingtuPNGData() != plainGradientPixels)
        let sourcePixels = try #require(
            viewModel.document.selectedLayer?.image.qingtuPNGData()
        )
        let plainPixels = try #require(viewModel.currentImage.qingtuPNGData())
        let historyCount = viewModel.document.history.count

        #expect(viewModel.setSelectedLayerGradientOverlayDither(true) == 1)
        #expect(viewModel.document.selectedLayer?.style.gradientOverlayDither == true)
        let ditheredPixels = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(viewModel.currentImage.color(at: .zero)?.alphaComponent == 0)
        #expect(viewModel.document.selectedLayer?.image.qingtuPNGData() == sourcePixels)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.setSelectedLayerGradientOverlayDither(true) == 0)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(!viewModel.document.selectedLayer!.style.gradientOverlayDither)
        #expect(viewModel.currentImage.qingtuPNGData() == plainPixels)
        viewModel.redo()
        #expect(viewModel.document.selectedLayer?.style.gradientOverlayDither == true)
        #expect(viewModel.currentImage.qingtuPNGData() == ditheredPixels)
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

    @Test func patternOverlayOffsetChangesRenderedPhaseAndRoundTripsProjectState() throws {
        let canvasSize = NSSize(width: 48, height: 40)
        let baseImage = solidImage(color: .black, size: canvasSize)
        let layerImage = centerRectImage(size: canvasSize, color: .white)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: baseImage) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            layerImage,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.setSelectedLayerPatternOverlayKind(.checkerboard)
        viewModel.setSelectedLayerPatternOverlayColor(.systemRed)
        viewModel.setSelectedLayerPatternOverlayOpacity(1)
        viewModel.setSelectedLayerPatternOverlayScale(8)
        let originalData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.setSelectedLayerPatternOverlayOffsetX(4) == 1)
        let shiftedData = try #require(viewModel.currentImage.qingtuPNGData())
        #expect(shiftedData != originalData)
        #expect(viewModel.setSelectedLayerPatternOverlayOffsetY(-3) == 1)

        let styledLayer = try #require(viewModel.document.selectedLayer)
        #expect(styledLayer.style.patternOverlayOffset == CGSize(width: 4, height: -3))
        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restoredDocument = try project.restoredDocument()
        let restoredLayer = try #require(restoredDocument.layers.first { $0.id == styledLayer.id })
        #expect(restoredLayer.style.patternOverlayOffset == CGSize(width: 4, height: -3))

        let encoded = try JSONEncoder().encode(ImageEditorProjectLayerStyle(style: styledLayer.style))
        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "patternOverlayOffset")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyStyle = try JSONDecoder().decode(ImageEditorProjectLayerStyle.self, from: legacyData)
        #expect(legacyStyle.layerStyle.patternOverlayOffset == .zero)
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

    private func gradientOverlayCenterViewModel() -> ImageEditorViewModel {
        let canvasSize = NSSize(width: 120, height: 80)
        let viewModel = ImageEditorViewModel(
            sourceName: "gradient-overlay-center.png",
            image: solidImage(color: .white, size: canvasSize)
        ) { _ in }
        guard let selectedIndex = viewModel.document.selectedLayerIndex else { return viewModel }
        viewModel.document.layers[selectedIndex].style.gradientOverlayEnabled = true
        viewModel.document.layers[selectedIndex].style.gradientOverlayCenter = CGPoint(x: 0.5, y: 0.5)
        return viewModel
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
