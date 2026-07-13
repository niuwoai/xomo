//
//  ImageEditorLayerStyleVisibilityScaleTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerStyleVisibilityScaleTests {
    @Test func hiddenEffectsKeepConfigurationButLeaveContentAndBoundsUnstyled() throws {
        let size = NSSize(width: 28, height: 20)
        var layer = ImageEditorLayer.blank(name: "Styled", size: size)
        layer.image = centeredRectangleImage(size: size)
        layer.frame = CGRect(x: 12, y: 9, width: size.width, height: size.height)
        layer.style.strokeEnabled = true
        layer.style.strokeWidth = 3
        layer.style.outerGlowEnabled = true
        layer.style.outerGlowBlur = 5

        let styledFrame = layer.renderedCompositingFrame(globalLightAngle: nil)
        let styledData = try #require(layer.renderedCompositingImage(globalLightAngle: nil).qingtuPNGData())
        layer.style.effectsEnabled = false
        let hiddenData = try #require(layer.renderedCompositingImage(globalLightAngle: nil).qingtuPNGData())
        let contentData = try #require(layer.visibleImage.qingtuPNGData())

        #expect(layer.style.hasConfiguredEffects)
        #expect(!layer.style.hasEffects)
        #expect(styledFrame.width > layer.frame.width)
        #expect(layer.renderedCompositingFrame(globalLightAngle: nil) == layer.frame)
        #expect(styledData != hiddenData)
        #expect(hiddenData == contentData)
    }

    @Test func effectScaleChangesRenderedDimensionsWithoutChangingStoredEffectSettings() {
        var style = ImageEditorLayerStyle()
        style.strokeEnabled = true
        style.strokeWidth = 4
        style.strokeFillType = .pattern
        style.strokePatternScale = 12
        style.shadowEnabled = true
        style.shadowBlur = 6
        style.shadowSpread = 3
        style.shadowDistance = 8
        style.shadowOffset = ImageEditorLayerStyle.shadowOffset(distance: 8, angle: 30)
        style.innerShadowEnabled = true
        style.innerShadowBlur = 5
        style.innerShadowChoke = 2
        style.innerShadowDistance = 7
        style.outerGlowEnabled = true
        style.outerGlowBlur = 9
        style.outerGlowSpread = 4
        style.innerGlowEnabled = true
        style.innerGlowBlur = 8
        style.innerGlowChoke = 2
        style.patternOverlayEnabled = true
        style.patternOverlayScale = 14
        style.satinEnabled = true
        style.satinDistance = 10
        style.satinSize = 6
        style.bevelEnabled = true
        style.bevelSize = 5
        style.bevelSoften = 2
        style.effectScale = 2

        let rendered = style.resolvedForRendering()
        var layer = ImageEditorLayer.blank(name: "Scaled", size: NSSize(width: 30, height: 20))
        layer.style = style
        let scaledFrame = layer.renderedCompositingFrame(globalLightAngle: nil)
        layer.style.effectScale = 1
        let originalFrame = layer.renderedCompositingFrame(globalLightAngle: nil)

        #expect(rendered.effectScale == 1)
        #expect(rendered.strokeWidth == 8)
        #expect(rendered.strokePatternScale == 24)
        #expect(rendered.shadowBlur == 12)
        #expect(rendered.shadowSpread == 6)
        #expect(rendered.shadowDistance == 16)
        #expect(abs(rendered.shadowOffset.width - style.shadowOffset.width * 2) < 0.001)
        #expect(rendered.innerShadowBlur == 10)
        #expect(rendered.innerShadowChoke == 4)
        #expect(rendered.innerShadowDistance == 14)
        #expect(rendered.outerGlowBlur == 18)
        #expect(rendered.outerGlowSpread == 8)
        #expect(rendered.innerGlowBlur == 16)
        #expect(rendered.innerGlowChoke == 4)
        #expect(rendered.patternOverlayScale == 28)
        #expect(rendered.satinDistance == 20)
        #expect(rendered.satinSize == 12)
        #expect(rendered.bevelSize == 10)
        #expect(rendered.bevelSoften == 4)
        #expect(rendered.shadowOpacity == style.shadowOpacity)
        #expect(rendered.strokeEnabled == style.strokeEnabled)
        #expect(style.strokeWidth == 4)
        #expect(style.shadowDistance == 8)
        #expect(scaledFrame.width > originalFrame.width)
        #expect(scaledFrame.height > originalFrame.height)
    }

    @Test func selectedAndDocumentEffectVisibilityCommandsPreserveStylesAndUndoInOneStep() throws {
        let viewModel = makeViewModel()
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[firstIndex].style.strokeEnabled = true
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[secondIndex].style.shadowEnabled = true
        viewModel.document.layers[secondIndex].isLocked = true
        viewModel.addLayer()
        let unstyledID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selectedLayerIDs = [firstID, secondID, unstyledID]

        #expect(viewModel.canToggleSelectedLayerEffects)
        #expect(viewModel.selectedLayerEffectsAreVisible)
        viewModel.toggleSelectedLayerEffects()
        #expect(viewModel.document.layers[firstIndex].style.effectsEnabled == false)
        #expect(viewModel.document.layers[secondIndex].style.effectsEnabled == false)
        #expect(viewModel.document.layers[firstIndex].style.strokeEnabled)
        #expect(viewModel.document.layers[secondIndex].style.shadowEnabled)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerEffectsHideSelected"))

        viewModel.undo()
        #expect(viewModel.document.layers[firstIndex].style.effectsEnabled)
        #expect(viewModel.document.layers[secondIndex].style.effectsEnabled)

        #expect(viewModel.canHideAllLayerEffects)
        viewModel.hideAllLayerEffects()
        #expect(viewModel.document.layers.filter(\.style.hasConfiguredEffects).allSatisfy { !$0.style.effectsEnabled })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerEffectsHideAll"))
        #expect(viewModel.canShowAllLayerEffects)
        viewModel.showAllLayerEffects()
        #expect(viewModel.document.layers.filter(\.style.hasConfiguredEffects).allSatisfy { $0.style.effectsEnabled })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerEffectsShowAll"))
    }

    @Test func scaleEffectsUsesOneAbsolutePercentageAcrossEditableStyledSelection() throws {
        let viewModel = makeViewModel()
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[firstIndex].style.strokeEnabled = true
        viewModel.document.layers[firstIndex].style.strokeWidth = 4
        viewModel.addLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        let lockedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[lockedIndex].style.outerGlowEnabled = true
        viewModel.document.layers[lockedIndex].isLocked = true
        viewModel.addLayer()
        let emptyID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selectedLayerID = firstID
        viewModel.document.selectedLayerIDs = [firstID, lockedID, emptyID]

        #expect(viewModel.canScaleSelectedLayerEffects)
        viewModel.setSelectedLayerEffectScale(200)

        #expect(viewModel.document.layers[firstIndex].style.effectScale == 2)
        #expect(viewModel.document.layers[firstIndex].style.strokeWidth == 4)
        #expect(viewModel.document.layers[lockedIndex].style.effectScale == 1)
        #expect(viewModel.selectedLayerEffectScale == 200)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerEffectsScale"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerEffectsScaled", 1, 200))

        viewModel.setSelectedLayerEffectScale(2_000)
        #expect(viewModel.document.layers[firstIndex].style.effectScale == 10)
        viewModel.setSelectedLayerEffectScale(0)
        #expect(viewModel.document.layers[firstIndex].style.effectScale == 0.01)
    }

    @Test func effectVisibilityAndScaleRoundTripWhileLegacyProjectsUseVisibleHundredPercent() throws {
        var style = ImageEditorLayerStyle()
        style.shadowEnabled = true
        style.effectsEnabled = false
        style.effectScale = 1.75
        let encoded = try JSONEncoder().encode(ImageEditorProjectLayerStyle(style: style))
        let decoded = try JSONDecoder().decode(ImageEditorProjectLayerStyle.self, from: encoded).layerStyle

        #expect(decoded.shadowEnabled)
        #expect(!decoded.effectsEnabled)
        #expect(decoded.effectScale == 1.75)

        var legacyObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "effectsEnabled")
        legacyObject.removeValue(forKey: "effectScale")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacy = try JSONDecoder().decode(ImageEditorProjectLayerStyle.self, from: legacyData).layerStyle

        #expect(legacy.effectsEnabled)
        #expect(legacy.effectScale == 1)
        #expect(legacy.shadowEnabled)
    }

    @Test func layerStyleMenusPanelAndPropertiesExposeVisibilityAndScaleCommands() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let menuSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let panelSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        let propertiesSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(menuSource.contains("viewModel.hideSelectedLayerEffects()"))
        #expect(menuSource.contains("viewModel.showSelectedLayerEffects()"))
        #expect(menuSource.contains("viewModel.hideAllLayerEffects()"))
        #expect(menuSource.contains("viewModel.showAllLayerEffects()"))
        #expect(menuSource.contains("viewModel.showLayerEffectScaleOptions()"))
        #expect(panelSource.contains("viewModel.toggleSelectedLayerEffects()"))
        #expect(panelSource.contains("viewModel.showLayerEffectScaleOptions()"))
        #expect(propertiesSource.contains("selectedLayerEffectScaleBinding"))
        #expect(propertiesSource.contains("imageEditor.properties.layerEffectScaleValue"))
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "style.png",
            image: solidImage(color: .black, size: NSSize(width: 40, height: 30))
        ) { _ in }
    }

    private func solidImage(color: NSColor, size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }

    private func centeredRectangleImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.clear.setFill()
            rect.fill()
            NSColor.systemBlue.setFill()
            rect.insetBy(dx: 7, dy: 5).fill()
        } ?? NSImage.transparent(size: size)
    }
}
