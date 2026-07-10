//
//  ImageEditorLayerStyleCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    var selectedLayerHasStroke: Bool {
        document.selectedLayer?.style.strokeEnabled == true
    }

    var selectedLayerHasShadow: Bool {
        document.selectedLayer?.style.shadowEnabled == true
    }

    var selectedLayerHasInnerShadow: Bool {
        document.selectedLayer?.style.innerShadowEnabled == true
    }

    var selectedLayerHasOuterGlow: Bool {
        document.selectedLayer?.style.outerGlowEnabled == true
    }

    var selectedLayerHasInnerGlow: Bool {
        document.selectedLayer?.style.innerGlowEnabled == true
    }

    var selectedLayerHasColorOverlay: Bool {
        document.selectedLayer?.style.colorOverlayEnabled == true
    }

    var selectedLayerHasGradientOverlay: Bool {
        document.selectedLayer?.style.gradientOverlayEnabled == true
    }

    var selectedLayerHasPatternOverlay: Bool {
        document.selectedLayer?.style.patternOverlayEnabled == true
    }

    var selectedLayerHasSatin: Bool {
        document.selectedLayer?.style.satinEnabled == true
    }

    var selectedLayerHasBevel: Bool {
        document.selectedLayer?.style.bevelEnabled == true
    }

    var canCopySelectedLayerStyle: Bool {
        guard let layer = document.selectedLayer else { return false }
        return canCopyLayerStyle(layer)
    }

    var canPasteLayerStyleToSelectedLayers: Bool {
        copiedLayerStyle != nil && !selectedLayerStylePasteTargetIndices().isEmpty
    }

    var canClearSelectedLayerStyles: Bool {
        selectedLayerStyleTargetIndices().contains { document.layers[$0].style.hasEffects }
    }

    var canEditSelectedLayerStyle: Bool {
        !selectedLayerStyleTargetIndices().isEmpty
    }

    var selectedLayerStrokeWidth: Double {
        Double(document.selectedLayer?.style.strokeWidth ?? 3)
    }

    var selectedLayerStrokePosition: ImageEditorStrokePosition {
        document.selectedLayer?.style.strokePosition ?? .outside
    }

    var selectedLayerStrokeOpacity: Double {
        Double(document.selectedLayer?.style.strokeOpacity ?? 1)
    }

    var selectedLayerStrokeFillType: ImageEditorStrokeFillType {
        document.selectedLayer?.style.strokeFillType ?? .color
    }

    var selectedLayerStrokeColor: NSColor {
        document.selectedLayer?.style.strokeColor ?? .white
    }

    var selectedLayerStrokeGradientStyle: ImageEditorGradientFillStyle {
        document.selectedLayer?.style.strokeGradientStyle ?? .linear
    }

    var selectedLayerStrokeGradientAngle: Double {
        Double(document.selectedLayer?.style.strokeGradientAngle ?? 0)
    }

    var selectedLayerStrokePatternKind: ImageEditorPatternOverlayKind {
        document.selectedLayer?.style.strokePatternKind ?? .checkerboard
    }

    var selectedLayerStrokePatternScale: Double {
        Double(document.selectedLayer?.style.strokePatternScale ?? 14)
    }

    var selectedLayerShadowOpacity: Double {
        Double(document.selectedLayer?.style.shadowOpacity ?? 0.35)
    }

    var selectedLayerShadowColor: NSColor {
        document.selectedLayer?.style.shadowColor ?? .black
    }

    var selectedLayerOuterGlowColor: NSColor {
        document.selectedLayer?.style.outerGlowColor ?? .systemYellow
    }

    var selectedLayerInnerGlowColor: NSColor {
        document.selectedLayer?.style.innerGlowColor ?? .systemCyan
    }

    var selectedLayerColorOverlayColor: NSColor {
        document.selectedLayer?.style.colorOverlayColor ?? .systemRed
    }

    var selectedLayerShadowBlur: Double {
        Double(document.selectedLayer?.style.shadowBlur ?? 8)
    }

    var selectedLayerShadowSpread: Double {
        Double(document.selectedLayer?.style.shadowSpread ?? 0)
    }

    var selectedLayerShadowNoise: Double {
        Double(document.selectedLayer?.style.shadowNoise ?? 0)
    }

    var selectedLayerShadowContour: ImageEditorLayerEffectContour {
        document.selectedLayer?.style.shadowContour ?? .linear
    }

    var globalLightAngle: Double {
        Double(document.globalLightAngle)
    }

    var selectedLayerShadowUsesGlobalLight: Bool {
        document.selectedLayer?.style.shadowUsesGlobalLight == true
    }

    var selectedLayerShadowDistance: Double {
        guard let style = document.selectedLayer?.style else { return 10 }
        return Double(ImageEditorLayerStyle.shadowDistance(from: style.resolvedShadowOffset(globalLightAngle: document.globalLightAngle)))
    }

    var selectedLayerShadowAngle: Double {
        guard let style = document.selectedLayer?.style else { return -45 }
        return Double(style.resolvedShadowAngle(globalLightAngle: document.globalLightAngle))
    }

    var selectedLayerShadowOffsetX: Double {
        Double(document.selectedLayer?.style.resolvedShadowOffset(globalLightAngle: document.globalLightAngle).width ?? 7)
    }

    var selectedLayerShadowOffsetY: Double {
        Double(document.selectedLayer?.style.resolvedShadowOffset(globalLightAngle: document.globalLightAngle).height ?? -7)
    }

    var selectedLayerInnerShadowOpacity: Double {
        Double(document.selectedLayer?.style.innerShadowOpacity ?? 0.35)
    }

    var selectedLayerInnerShadowBlur: Double {
        Double(document.selectedLayer?.style.innerShadowBlur ?? 8)
    }

    var selectedLayerInnerShadowChoke: Double {
        Double(document.selectedLayer?.style.innerShadowChoke ?? 0)
    }

    var selectedLayerInnerShadowNoise: Double {
        Double(document.selectedLayer?.style.innerShadowNoise ?? 0)
    }

    var selectedLayerInnerShadowContour: ImageEditorLayerEffectContour {
        document.selectedLayer?.style.innerShadowContour ?? .linear
    }

    var selectedLayerInnerShadowDistance: Double {
        Double(document.selectedLayer?.style.innerShadowDistance ?? 7)
    }

    var selectedLayerInnerShadowAngle: Double {
        guard let style = document.selectedLayer?.style else { return -45 }
        return Double(style.resolvedInnerShadowAngle(globalLightAngle: document.globalLightAngle))
    }

    var selectedLayerInnerShadowUsesGlobalLight: Bool {
        document.selectedLayer?.style.innerShadowUsesGlobalLight == true
    }

    var selectedLayerOuterGlowOpacity: Double {
        Double(document.selectedLayer?.style.outerGlowOpacity ?? 0.42)
    }

    var selectedLayerOuterGlowBlur: Double {
        Double(document.selectedLayer?.style.outerGlowBlur ?? 10)
    }

    var selectedLayerOuterGlowSpread: Double {
        Double(document.selectedLayer?.style.outerGlowSpread ?? 3)
    }

    var selectedLayerOuterGlowNoise: Double {
        Double(document.selectedLayer?.style.outerGlowNoise ?? 0)
    }

    var selectedLayerOuterGlowContour: ImageEditorLayerEffectContour {
        document.selectedLayer?.style.outerGlowContour ?? .linear
    }

    var selectedLayerInnerGlowOpacity: Double {
        Double(document.selectedLayer?.style.innerGlowOpacity ?? 0.36)
    }

    var selectedLayerInnerGlowBlur: Double {
        Double(document.selectedLayer?.style.innerGlowBlur ?? 8)
    }

    var selectedLayerInnerGlowChoke: Double {
        Double(document.selectedLayer?.style.innerGlowChoke ?? 2)
    }

    var selectedLayerInnerGlowNoise: Double {
        Double(document.selectedLayer?.style.innerGlowNoise ?? 0)
    }

    var selectedLayerInnerGlowSource: ImageEditorInnerGlowSource {
        document.selectedLayer?.style.innerGlowSource ?? .edge
    }

    var selectedLayerColorOverlayOpacity: Double {
        Double(document.selectedLayer?.style.colorOverlayOpacity ?? 0.55)
    }

    var selectedLayerGradientOverlayOpacity: Double {
        Double(document.selectedLayer?.style.gradientOverlayOpacity ?? 0.55)
    }

    var selectedLayerGradientOverlayStartColor: NSColor {
        document.selectedLayer?.style.gradientOverlayStartColor ?? .systemRed
    }

    var selectedLayerGradientOverlayEndColor: NSColor {
        document.selectedLayer?.style.gradientOverlayEndColor ?? .white
    }

    var selectedLayerGradientOverlayStyle: ImageEditorGradientFillStyle {
        document.selectedLayer?.style.gradientOverlayStyle ?? .linear
    }

    var selectedLayerGradientOverlayScale: Double {
        Double(document.selectedLayer?.style.gradientOverlayScale ?? 1)
    }

    var selectedLayerGradientOverlayAngle: Double {
        Double(document.selectedLayer?.style.gradientOverlayAngle ?? 0)
    }

    var selectedLayerPatternOverlayKind: ImageEditorPatternOverlayKind {
        document.selectedLayer?.style.patternOverlayKind ?? .checkerboard
    }

    var selectedLayerPatternOverlayOpacity: Double {
        Double(document.selectedLayer?.style.patternOverlayOpacity ?? 0.45)
    }

    var selectedLayerPatternOverlayScale: Double {
        Double(document.selectedLayer?.style.patternOverlayScale ?? 14)
    }

    var selectedLayerSatinOpacity: Double {
        Double(document.selectedLayer?.style.satinOpacity ?? 0.35)
    }

    var selectedLayerSatinColor: NSColor {
        document.selectedLayer?.style.satinColor ?? .black
    }

    var selectedLayerSatinDistance: Double {
        Double(document.selectedLayer?.style.satinDistance ?? 8)
    }

    var selectedLayerSatinSize: Double {
        Double(document.selectedLayer?.style.satinSize ?? 6)
    }

    var selectedLayerSatinAngle: Double {
        Double(document.selectedLayer?.style.satinAngle ?? 19)
    }

    var selectedLayerSatinInvert: Bool {
        document.selectedLayer?.style.satinInvert == true
    }

    var selectedLayerSatinContour: ImageEditorLayerEffectContour {
        document.selectedLayer?.style.satinContour ?? .linear
    }

    var selectedLayerBevelSize: Double {
        Double(document.selectedLayer?.style.bevelSize ?? 4)
    }

    var selectedLayerBevelOpacity: Double {
        Double(document.selectedLayer?.style.bevelOpacity ?? 0.38)
    }

    var selectedLayerBevelSoften: Double {
        Double(document.selectedLayer?.style.bevelSoften ?? 0)
    }

    var selectedLayerBevelAngle: Double {
        guard let style = document.selectedLayer?.style else { return -45 }
        return Double(style.resolvedBevelAngle(globalLightAngle: document.globalLightAngle))
    }

    var selectedLayerBevelUsesGlobalLight: Bool {
        document.selectedLayer?.style.bevelUsesGlobalLight == true
    }

    var selectedLayerBevelDirection: ImageEditorBevelDirection {
        document.selectedLayer?.style.bevelDirection ?? .up
    }

    func toggleSelectedLayerStroke() {
        toggleSelectedLayerStyleEffect(historyKey: "imageEditor.history.layerStroke") {
            $0.strokeEnabled.toggle()
            updateStrokeFillDefaults(style: &$0)
        }
    }

    func toggleSelectedLayerShadow() {
        toggleSelectedLayerStyleEffect(historyKey: "imageEditor.history.layerShadow") {
            $0.shadowEnabled.toggle()
        }
    }

    func toggleSelectedLayerInnerShadow() {
        toggleSelectedLayerStyleEffect(historyKey: "imageEditor.history.layerInnerShadow") {
            $0.innerShadowEnabled.toggle()
            $0.innerShadowColor = innerShadowColor()
        }
    }

    func toggleSelectedLayerOuterGlow() {
        toggleSelectedLayerStyleEffect(historyKey: "imageEditor.history.layerOuterGlow") {
            $0.outerGlowEnabled.toggle()
        }
    }

    func toggleSelectedLayerInnerGlow() {
        toggleSelectedLayerStyleEffect(historyKey: "imageEditor.history.layerInnerGlow") {
            $0.innerGlowEnabled.toggle()
        }
    }

    func toggleSelectedLayerColorOverlay() {
        toggleSelectedLayerStyleEffect(historyKey: "imageEditor.history.layerColorOverlay") {
            $0.colorOverlayEnabled.toggle()
            $0.colorOverlayColor = foregroundColor
        }
    }

    func toggleSelectedLayerGradientOverlay() {
        toggleSelectedLayerStyleEffect(historyKey: "imageEditor.history.layerGradientOverlay") {
            $0.gradientOverlayEnabled.toggle()
            if $0.gradientOverlayEnabled {
                $0.gradientOverlayStartColor = foregroundColor
                $0.gradientOverlayEndColor = gradientOverlayEndColor()
            }
        }
    }

    func toggleSelectedLayerPatternOverlay() {
        toggleSelectedLayerStyleEffect(historyKey: "imageEditor.history.layerPatternOverlay") {
            $0.patternOverlayEnabled.toggle()
            $0.patternOverlayColor = patternOverlayColor()
        }
    }

    func toggleSelectedLayerSatin() {
        toggleSelectedLayerStyleEffect(historyKey: "imageEditor.history.layerSatin") {
            $0.satinEnabled.toggle()
            if $0.satinEnabled {
                $0.satinColor = satinColor()
            }
        }
    }

    func toggleSelectedLayerBevel() {
        toggleSelectedLayerStyleEffect(historyKey: "imageEditor.history.layerBevel") {
            $0.bevelEnabled.toggle()
        }
    }

    func showLayerStyleBlendingOptions() {
        guard canEditSelectedLayerStyle else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        isPropertiesPanelVisible = true
        statusText = L10n.text("imageEditor.status.layerStyleReady")
    }

    func copySelectedLayerStyle() {
        guard canCopySelectedLayerStyle,
              let style = document.selectedLayer?.style
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        copiedLayerStyle = style
        copiedLayerStyleSourceID = document.selectedLayerID
        statusText = L10n.text("imageEditor.status.layerStyleCopied")
    }

    func pasteLayerStyleToSelectedLayers() {
        guard let style = copiedLayerStyle else {
            statusText = L10n.text("imageEditor.status.layerStyleClipboardEmpty")
            return
        }
        let targetIndices = selectedLayerStylePasteTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        pushUndo()
        for index in targetIndices {
            document.layers[index].style = style
        }
        appendHistory(L10n.text("imageEditor.history.layerStylePaste"))
        statusText = L10n.format("imageEditor.status.layerStylePasted", targetIndices.count)
    }

    func clearSelectedLayerStyles() {
        let targetIndices = selectedLayerStyleTargetIndices().filter { document.layers[$0].style.hasEffects }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in targetIndices {
            document.layers[index].style = ImageEditorLayerStyle()
        }
        appendHistory(L10n.text("imageEditor.history.layerStyleClear"))
        statusText = L10n.format("imageEditor.status.layerStyleCleared", targetIndices.count)
    }

    func setSelectedLayerStrokeWidth(_ width: Double) {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeWidth = max(1, min(24, CGFloat(width)))
        }
    }

    func setSelectedLayerStrokePosition(_ position: ImageEditorStrokePosition) {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokePosition = position
        }
    }

    func setSelectedLayerStrokeOpacity(_ opacity: Double) {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    func setSelectedLayerStrokeFillType(_ fillType: ImageEditorStrokeFillType) {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeFillType = fillType
            updateStrokeFillDefaults(style: &$0)
        }
    }

    func setSelectedLayerStrokeColorFromForeground() {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeFillType = .color
            $0.strokeColor = strokeColor()
        }
    }

    func setSelectedLayerStrokeColor(_ color: NSColor) {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeFillType = .color
            $0.strokeColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    func setSelectedLayerStrokeGradientStyle(_ style: ImageEditorGradientFillStyle) {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeFillType = .gradient
            $0.strokeGradientStartColor = foregroundColor
            $0.strokeGradientEndColor = strokeGradientEndColor()
            $0.strokeGradientStyle = style
        }
    }

    func setSelectedLayerStrokeGradientAngle(_ angle: Double) {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeFillType = .gradient
            $0.strokeGradientStartColor = foregroundColor
            $0.strokeGradientEndColor = strokeGradientEndColor()
            $0.strokeGradientAngle = CGFloat(angle).truncatingRemainder(dividingBy: 360)
        }
    }

    func setSelectedLayerStrokePatternKind(_ kind: ImageEditorPatternOverlayKind) {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeFillType = .pattern
            $0.strokePatternKind = kind
            $0.strokePatternColor = strokePatternColor()
        }
    }

    func setSelectedLayerStrokePatternScale(_ scale: Double) {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeFillType = .pattern
            $0.strokePatternColor = strokePatternColor()
            $0.strokePatternScale = max(6, min(64, CGFloat(scale)))
        }
    }

    func setSelectedLayerShadowOpacity(_ opacity: Double) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    func setSelectedLayerShadowColorFromForeground() {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowColor = shadowColor()
        }
    }

    func setSelectedLayerShadowColor(_ color: NSColor) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    func setSelectedLayerOuterGlowColor(_ color: NSColor) {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    func setSelectedLayerInnerGlowColor(_ color: NSColor) {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    func setSelectedLayerColorOverlayColor(_ color: NSColor) {
        updateSelectedLayerStyle {
            $0.colorOverlayEnabled = true
            $0.colorOverlayColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    func setSelectedLayerShadowBlur(_ blur: Double) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowBlur = max(0, min(30, CGFloat(blur)))
        }
    }

    func setSelectedLayerShadowSpread(_ spread: Double) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowSpread = max(0, min(24, CGFloat(spread)))
        }
    }

    func setSelectedLayerShadowNoise(_ noise: Double) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowNoise = max(0, min(1, CGFloat(noise)))
        }
    }

    func setSelectedLayerShadowContour(_ contour: ImageEditorLayerEffectContour) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowContour = contour
        }
    }

    func setSelectedLayerShadowDistance(_ distance: Double) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowDistance = max(0, min(80, CGFloat(distance)))
            $0.shadowOffset = ImageEditorLayerStyle.shadowOffset(
                distance: $0.shadowDistance,
                angle: $0.resolvedShadowAngle(globalLightAngle: document.globalLightAngle)
            )
        }
    }

    func setSelectedLayerShadowAngle(_ angle: Double) {
        guard let index = document.selectedLayerIndex,
              canEditLayerStyle(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let normalizedAngle = normalizedLightAngle(CGFloat(angle))
        pushUndo()
        document.layers[index].style.shadowEnabled = true
        if document.layers[index].style.shadowUsesGlobalLight {
            document.globalLightAngle = normalizedAngle
        }
        document.layers[index].style.shadowAngle = normalizedAngle
        document.layers[index].style.shadowOffset = document.layers[index].style.resolvedShadowOffset(
            globalLightAngle: document.globalLightAngle
        )
        appendHistory(L10n.text("imageEditor.history.layerStyle"))
        statusText = L10n.text("imageEditor.status.layerStyleUpdated")
    }

    func setSelectedLayerShadowOffsetX(_ offset: Double) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            var resolvedOffset = $0.resolvedShadowOffset(globalLightAngle: document.globalLightAngle)
            resolvedOffset.width = max(-40, min(40, CGFloat(offset)))
            $0.shadowUsesGlobalLight = false
            $0.shadowOffset = resolvedOffset
            $0.shadowDistance = min(80, ImageEditorLayerStyle.shadowDistance(from: $0.shadowOffset))
            $0.shadowAngle = max(-180, min(180, ImageEditorLayerStyle.shadowAngle(from: $0.shadowOffset)))
        }
    }

    func setSelectedLayerShadowOffsetY(_ offset: Double) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            var resolvedOffset = $0.resolvedShadowOffset(globalLightAngle: document.globalLightAngle)
            resolvedOffset.height = max(-40, min(40, CGFloat(offset)))
            $0.shadowUsesGlobalLight = false
            $0.shadowOffset = resolvedOffset
            $0.shadowDistance = min(80, ImageEditorLayerStyle.shadowDistance(from: $0.shadowOffset))
            $0.shadowAngle = max(-180, min(180, ImageEditorLayerStyle.shadowAngle(from: $0.shadowOffset)))
        }
    }

    func setSelectedLayerShadowUsesGlobalLight(_ enabled: Bool) {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            let resolvedAngle = $0.resolvedShadowAngle(globalLightAngle: document.globalLightAngle)
            $0.shadowUsesGlobalLight = enabled
            $0.shadowAngle = enabled ? document.globalLightAngle : resolvedAngle
            $0.shadowOffset = $0.resolvedShadowOffset(globalLightAngle: enabled ? document.globalLightAngle : nil)
        }
    }

    func setGlobalLightAngle(_ angle: Double) {
        let normalizedAngle = normalizedLightAngle(CGFloat(angle))
        guard abs(document.globalLightAngle - normalizedAngle) > 0.001 else { return }
        pushUndo()
        document.globalLightAngle = normalizedAngle
        appendHistory(L10n.text("imageEditor.history.globalLight"))
        statusText = L10n.format("imageEditor.status.globalLight", Int(normalizedAngle.rounded()))
    }

    func setSelectedLayerInnerShadowOpacity(_ opacity: Double) {
        updateSelectedLayerStyle {
            $0.innerShadowEnabled = true
            $0.innerShadowColor = innerShadowColor()
            $0.innerShadowOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    func setSelectedLayerInnerShadowBlur(_ blur: Double) {
        updateSelectedLayerStyle {
            $0.innerShadowEnabled = true
            $0.innerShadowColor = innerShadowColor()
            $0.innerShadowBlur = max(0, min(40, CGFloat(blur)))
        }
    }

    func setSelectedLayerInnerShadowChoke(_ choke: Double) {
        updateSelectedLayerStyle {
            $0.innerShadowEnabled = true
            $0.innerShadowColor = innerShadowColor()
            $0.innerShadowChoke = max(0, min(24, CGFloat(choke)))
        }
    }

    func setSelectedLayerInnerShadowNoise(_ noise: Double) {
        updateSelectedLayerStyle {
            $0.innerShadowEnabled = true
            $0.innerShadowColor = innerShadowColor()
            $0.innerShadowNoise = max(0, min(1, CGFloat(noise)))
        }
    }

    func setSelectedLayerInnerShadowContour(_ contour: ImageEditorLayerEffectContour) {
        updateSelectedLayerStyle {
            $0.innerShadowEnabled = true
            $0.innerShadowColor = innerShadowColor()
            $0.innerShadowContour = contour
        }
    }

    func setSelectedLayerInnerShadowDistance(_ distance: Double) {
        updateSelectedLayerStyle {
            $0.innerShadowEnabled = true
            $0.innerShadowColor = innerShadowColor()
            $0.innerShadowDistance = max(0, min(48, CGFloat(distance)))
        }
    }

    func setSelectedLayerInnerShadowAngle(_ angle: Double) {
        guard let index = document.selectedLayerIndex,
              canEditLayerStyle(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let normalizedAngle = normalizedLightAngle(CGFloat(angle))
        pushUndo()
        document.layers[index].style.innerShadowEnabled = true
        document.layers[index].style.innerShadowColor = innerShadowColor()
        if document.layers[index].style.innerShadowUsesGlobalLight {
            document.globalLightAngle = normalizedAngle
        }
        document.layers[index].style.innerShadowAngle = normalizedAngle
        appendHistory(L10n.text("imageEditor.history.layerStyle"))
        statusText = L10n.text("imageEditor.status.layerStyleUpdated")
    }

    func setSelectedLayerInnerShadowUsesGlobalLight(_ enabled: Bool) {
        updateSelectedLayerStyle {
            $0.innerShadowEnabled = true
            $0.innerShadowColor = innerShadowColor()
            let resolvedAngle = $0.resolvedInnerShadowAngle(globalLightAngle: document.globalLightAngle)
            $0.innerShadowUsesGlobalLight = enabled
            $0.innerShadowAngle = enabled
                ? document.globalLightAngle
                : resolvedAngle
        }
    }

    func setSelectedLayerOuterGlowOpacity(_ opacity: Double) {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    func setSelectedLayerOuterGlowBlur(_ blur: Double) {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowBlur = max(0, min(40, CGFloat(blur)))
        }
    }

    func setSelectedLayerOuterGlowSpread(_ spread: Double) {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowSpread = max(0, min(24, CGFloat(spread)))
        }
    }

    func setSelectedLayerOuterGlowNoise(_ noise: Double) {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowNoise = max(0, min(1, CGFloat(noise)))
        }
    }

    func setSelectedLayerOuterGlowContour(_ contour: ImageEditorLayerEffectContour) {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowContour = contour
        }
    }

    func setSelectedLayerInnerGlowOpacity(_ opacity: Double) {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    func setSelectedLayerInnerGlowBlur(_ blur: Double) {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowBlur = max(0, min(40, CGFloat(blur)))
        }
    }

    func setSelectedLayerInnerGlowChoke(_ choke: Double) {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowChoke = max(0, min(24, CGFloat(choke)))
        }
    }

    func setSelectedLayerInnerGlowNoise(_ noise: Double) {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowNoise = max(0, min(1, CGFloat(noise)))
        }
    }

    func setSelectedLayerInnerGlowSource(_ source: ImageEditorInnerGlowSource) {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowSource = source
        }
    }

    func setSelectedLayerColorOverlayOpacity(_ opacity: Double) {
        updateSelectedLayerStyle {
            $0.colorOverlayEnabled = true
            $0.colorOverlayColor = foregroundColor
            $0.colorOverlayOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    func setSelectedLayerGradientOverlayOpacity(_ opacity: Double) {
        updateSelectedLayerStyle {
            setGradientOverlayDefaultColorsIfNeeded(style: &$0)
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    func setSelectedLayerGradientOverlayStartColor(_ color: NSColor) {
        updateSelectedLayerStyle {
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayStartColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    func setSelectedLayerGradientOverlayEndColor(_ color: NSColor) {
        updateSelectedLayerStyle {
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayEndColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    func setSelectedLayerGradientOverlayStyle(_ style: ImageEditorGradientFillStyle) {
        updateSelectedLayerStyle {
            setGradientOverlayDefaultColorsIfNeeded(style: &$0)
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayStyle = style
        }
    }

    func setSelectedLayerGradientOverlayScale(_ scale: Double) {
        updateSelectedLayerStyle {
            setGradientOverlayDefaultColorsIfNeeded(style: &$0)
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayScale = max(0.25, min(4, CGFloat(scale)))
        }
    }

    func setSelectedLayerGradientOverlayAngle(_ angle: Double) {
        updateSelectedLayerStyle {
            setGradientOverlayDefaultColorsIfNeeded(style: &$0)
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayAngle = CGFloat(angle).truncatingRemainder(dividingBy: 360)
        }
    }

    func setSelectedLayerPatternOverlayKind(_ kind: ImageEditorPatternOverlayKind) {
        updateSelectedLayerStyle {
            $0.patternOverlayEnabled = true
            $0.patternOverlayKind = kind
            $0.patternOverlayColor = patternOverlayColor()
        }
    }

    func setSelectedLayerPatternOverlayOpacity(_ opacity: Double) {
        updateSelectedLayerStyle {
            $0.patternOverlayEnabled = true
            $0.patternOverlayColor = patternOverlayColor()
            $0.patternOverlayOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    func setSelectedLayerPatternOverlayScale(_ scale: Double) {
        updateSelectedLayerStyle {
            $0.patternOverlayEnabled = true
            $0.patternOverlayColor = patternOverlayColor()
            $0.patternOverlayScale = max(6, min(64, CGFloat(scale)))
        }
    }

    func setSelectedLayerSatinOpacity(_ opacity: Double) {
        let defaultColor = satinColor()
        updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    func setSelectedLayerSatinColorFromForeground() {
        updateSelectedLayerStyle {
            $0.satinEnabled = true
            $0.satinColor = satinColor()
        }
    }

    func setSelectedLayerSatinColor(_ color: NSColor) {
        updateSelectedLayerStyle {
            $0.satinEnabled = true
            $0.satinColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    func setSelectedLayerSatinDistance(_ distance: Double) {
        let defaultColor = satinColor()
        updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinDistance = max(1, min(48, CGFloat(distance)))
        }
    }

    func setSelectedLayerSatinSize(_ size: Double) {
        let defaultColor = satinColor()
        updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinSize = max(0, min(40, CGFloat(size)))
        }
    }

    func setSelectedLayerSatinAngle(_ angle: Double) {
        let defaultColor = satinColor()
        updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinAngle = CGFloat(angle).truncatingRemainder(dividingBy: 360)
        }
    }

    func setSelectedLayerSatinInvert(_ enabled: Bool) {
        let defaultColor = satinColor()
        updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinInvert = enabled
        }
    }

    func setSelectedLayerSatinContour(_ contour: ImageEditorLayerEffectContour) {
        let defaultColor = satinColor()
        updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinContour = contour
        }
    }

    func setSelectedLayerBevelSize(_ size: Double) {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelSize = max(1, min(24, CGFloat(size)))
        }
    }

    func setSelectedLayerBevelOpacity(_ opacity: Double) {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    func setSelectedLayerBevelSoften(_ soften: Double) {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelSoften = max(0, min(24, CGFloat(soften)))
        }
    }

    func setSelectedLayerBevelAngle(_ angle: Double) {
        guard let index = document.selectedLayerIndex,
              canEditLayerStyle(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let normalizedAngle = normalizedLightAngle(CGFloat(angle))
        pushUndo()
        document.layers[index].style.bevelEnabled = true
        if document.layers[index].style.bevelUsesGlobalLight {
            document.globalLightAngle = normalizedAngle
        }
        document.layers[index].style.bevelAngle = normalizedAngle
        appendHistory(L10n.text("imageEditor.history.layerStyle"))
        statusText = L10n.text("imageEditor.status.layerStyleUpdated")
    }

    func setSelectedLayerBevelUsesGlobalLight(_ enabled: Bool) {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            let resolvedAngle = $0.resolvedBevelAngle(globalLightAngle: document.globalLightAngle)
            $0.bevelUsesGlobalLight = enabled
            $0.bevelAngle = enabled ? document.globalLightAngle : resolvedAngle
        }
    }

    func setSelectedLayerBevelDirection(_ direction: ImageEditorBevelDirection) {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelDirection = direction
        }
    }

    private func normalizedLightAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle.truncatingRemainder(dividingBy: 360)
        if normalized > 180 {
            normalized -= 360
        } else if normalized < -180 {
            normalized += 360
        }
        return normalized
    }

    private func toggleSelectedLayerStyleEffect(
        historyKey: String,
        mutate: (inout ImageEditorLayerStyle) -> Void
    ) {
        let targetIndices = selectedLayerStyleTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        for index in targetIndices {
            mutate(&document.layers[index].style)
        }
        appendHistory(L10n.text(historyKey))
    }

    private func updateSelectedLayerStyle(_ mutate: (inout ImageEditorLayerStyle) -> Void) {
        let targetIndices = selectedLayerStyleTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        for index in targetIndices {
            mutate(&document.layers[index].style)
        }
        appendHistory(L10n.text("imageEditor.history.layerStyle"))
    }

    private func canEditLayerStyle(_ layer: ImageEditorLayer) -> Bool {
        !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && !document.isEffectivelyLocked(layer)
    }

    private func canCopyLayerStyle(_ layer: ImageEditorLayer) -> Bool {
        !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
    }

    private func selectedLayerStyleTargetIndices() -> [Int] {
        document.layers.indices.filter { index in
            document.selectedLayerIDs.contains(document.layers[index].id)
                && canEditLayerStyle(document.layers[index])
        }
    }

    private func selectedLayerStylePasteTargetIndices() -> [Int] {
        selectedLayerStyleTargetIndices().filter { index in
            document.layers[index].id != copiedLayerStyleSourceID
        }
    }

    private func gradientOverlayEndColor() -> NSColor {
        let color = backgroundColor.usingColorSpace(.deviceRGB) ?? backgroundColor
        guard color.alphaComponent > 0.01 else { return .white }
        return backgroundColor
    }

    private func setGradientOverlayDefaultColorsIfNeeded(style: inout ImageEditorLayerStyle) {
        guard !style.gradientOverlayEnabled else { return }
        style.gradientOverlayStartColor = foregroundColor
        style.gradientOverlayEndColor = gradientOverlayEndColor()
    }

    private func patternOverlayColor() -> NSColor {
        let color = foregroundColor.usingColorSpace(.deviceRGB) ?? foregroundColor
        guard color.alphaComponent > 0.01 else { return .white }
        return foregroundColor
    }

    private func satinColor() -> NSColor {
        let color = foregroundColor.usingColorSpace(.deviceRGB) ?? foregroundColor
        guard color.alphaComponent > 0.01 else { return .black }
        return foregroundColor
    }

    private func innerShadowColor() -> NSColor {
        let color = foregroundColor.usingColorSpace(.deviceRGB) ?? foregroundColor
        guard color.alphaComponent > 0.01 else { return .black }
        return foregroundColor
    }

    private func shadowColor() -> NSColor {
        let color = foregroundColor.usingColorSpace(.deviceRGB) ?? foregroundColor
        guard color.alphaComponent > 0.01 else { return .black }
        return foregroundColor
    }

    private func strokeColor() -> NSColor {
        let color = foregroundColor.usingColorSpace(.deviceRGB) ?? foregroundColor
        guard color.alphaComponent > 0.01 else { return .white }
        return foregroundColor
    }

    private func strokeGradientEndColor() -> NSColor {
        let color = backgroundColor.usingColorSpace(.deviceRGB) ?? backgroundColor
        guard color.alphaComponent > 0.01 else { return .black }
        return backgroundColor
    }

    private func strokePatternColor() -> NSColor {
        let color = foregroundColor.usingColorSpace(.deviceRGB) ?? foregroundColor
        guard color.alphaComponent > 0.01 else { return .white }
        return foregroundColor
    }

    private func updateStrokeFillDefaults(style: inout ImageEditorLayerStyle) {
        switch style.strokeFillType {
        case .color:
            style.strokeColor = strokeColor()
        case .gradient:
            style.strokeGradientStartColor = foregroundColor
            style.strokeGradientEndColor = strokeGradientEndColor()
        case .pattern:
            style.strokePatternColor = strokePatternColor()
        }
    }
}
