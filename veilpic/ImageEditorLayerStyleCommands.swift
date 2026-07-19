//
//  ImageEditorLayerStyleCommands.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

enum ImageEditorLayerStyleEffect: CaseIterable {
    case stroke
    case shadow
    case innerShadow
    case outerGlow
    case innerGlow
    case colorOverlay
    case gradientOverlay
    case patternOverlay
    case satin
    case bevel

    var historyKey: String {
        switch self {
        case .stroke: "imageEditor.history.layerStroke"
        case .shadow: "imageEditor.history.layerShadow"
        case .innerShadow: "imageEditor.history.layerInnerShadow"
        case .outerGlow: "imageEditor.history.layerOuterGlow"
        case .innerGlow: "imageEditor.history.layerInnerGlow"
        case .colorOverlay: "imageEditor.history.layerColorOverlay"
        case .gradientOverlay: "imageEditor.history.layerGradientOverlay"
        case .patternOverlay: "imageEditor.history.layerPatternOverlay"
        case .satin: "imageEditor.history.layerSatin"
        case .bevel: "imageEditor.history.layerBevel"
        }
    }

    func isEnabled(in style: ImageEditorLayerStyle) -> Bool {
        switch self {
        case .stroke: style.strokeEnabled
        case .shadow: style.shadowEnabled
        case .innerShadow: style.innerShadowEnabled
        case .outerGlow: style.outerGlowEnabled
        case .innerGlow: style.innerGlowEnabled
        case .colorOverlay: style.colorOverlayEnabled
        case .gradientOverlay: style.gradientOverlayEnabled
        case .patternOverlay: style.patternOverlayEnabled
        case .satin: style.satinEnabled
        case .bevel: style.bevelEnabled
        }
    }
}

enum ImageEditorLayerStyleSelectionState: Equatable {
    case off
    case on
    case mixed

    var accessibilityKey: String {
        switch self {
        case .off: "imageEditor.layer.effectState.off"
        case .on: "imageEditor.layer.effectState.on"
        case .mixed: "imageEditor.layer.effectState.mixed"
        }
    }
}

enum ImageEditorLayerStyleValueState<Value: Equatable>: Equatable {
    case unavailable
    case value(Value)
    case mixed

    var value: Value? {
        guard case .value(let value) = self else { return nil }
        return value
    }

    var isMixed: Bool {
        self == .mixed
    }
}

enum ImageEditorLayerLightEffect: CaseIterable {
    case shadow
    case innerShadow
    case bevel

    func usesGlobalLight(in style: ImageEditorLayerStyle) -> Bool {
        switch self {
        case .shadow: style.shadowUsesGlobalLight
        case .innerShadow: style.innerShadowUsesGlobalLight
        case .bevel: style.bevelUsesGlobalLight
        }
    }
}

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
        selectedLayerStyleTargetIndices().contains { document.layers[$0].style.hasConfiguredEffects }
    }

    var canEditSelectedLayerStyle: Bool {
        !selectedLayerStyleTargetIndices().isEmpty
    }

    func selectedLayerStyleEffectState(
        _ effect: ImageEditorLayerStyleEffect
    ) -> ImageEditorLayerStyleSelectionState {
        selectedLayerStyleBooleanState { effect.isEnabled(in: $0) }
    }

    func selectedLayerGlobalLightState(
        _ effect: ImageEditorLayerLightEffect
    ) -> ImageEditorLayerStyleSelectionState {
        selectedLayerStyleBooleanState { effect.usesGlobalLight(in: $0) }
    }

    var selectedLayerSatinInvertState: ImageEditorLayerStyleSelectionState {
        selectedLayerStyleBooleanState(\.satinInvert)
    }

    var canCreateLayerStylePreset: Bool {
        guard customLayerStylePresets.count < ImageEditorLayerStylePresetPreferences.maximumPresetCount,
              let layer = document.selectedLayer
        else { return false }
        return canCopyLayerStyle(layer) && layer.style.hasConfiguredEffects
    }

    var canApplyLayerStylePreset: Bool {
        !selectedLayerStyleTargetIndices().isEmpty
    }

    var activeLayerStylePreset: ImageEditorLayerStylePreset? {
        guard let style = document.selectedLayer?.style else { return nil }
        return customLayerStylePresets.first { $0.matches(style) }
            ?? builtInLayerStylePresets.first { $0.matches(style) }
    }

    var canToggleSelectedLayerEffects: Bool {
        !selectedLayerEffectVisibilityTargetIndices().isEmpty
    }

    var selectedLayerEffectsAreVisible: Bool {
        let targetIndices = selectedLayerEffectVisibilityTargetIndices()
        return !targetIndices.isEmpty
            && targetIndices.allSatisfy { document.layers[$0].style.effectsEnabled }
    }

    var canHideAllLayerEffects: Bool {
        document.layers.contains { $0.style.hasConfiguredEffects && $0.style.effectsEnabled }
    }

    var canShowAllLayerEffects: Bool {
        document.layers.contains { $0.style.hasConfiguredEffects && !$0.style.effectsEnabled }
    }

    var canScaleSelectedLayerEffects: Bool {
        !selectedLayerEffectScaleTargetIndices().isEmpty
    }

    var selectedLayerEffectScale: Double {
        guard let index = selectedLayerEffectVisibilityTargetIndices().first else { return 100 }
        return Double(document.layers[index].style.effectScale) * 100
    }

    var selectedLayerStrokeWidth: Double {
        Double(document.selectedLayer?.style.strokeWidth ?? 3)
    }

    var selectedLayerStrokePosition: ImageEditorStrokePosition {
        document.selectedLayer?.style.strokePosition ?? .outside
    }

    var selectedLayerStrokePositionState: ImageEditorLayerStyleValueState<ImageEditorStrokePosition> {
        selectedLayerStyleValueState(\.strokePosition)
    }

    var selectedLayerStrokeOpacity: Double {
        Double(document.selectedLayer?.style.strokeOpacity ?? 1)
    }

    var selectedLayerStrokeFillType: ImageEditorStrokeFillType {
        document.selectedLayer?.style.strokeFillType ?? .color
    }

    var selectedLayerStrokeFillTypeState: ImageEditorLayerStyleValueState<ImageEditorStrokeFillType> {
        selectedLayerStyleValueState(\.strokeFillType)
    }

    var selectedLayerStrokeColor: NSColor {
        document.selectedLayer?.style.strokeColor ?? .white
    }

    var selectedLayerStrokeGradientStyle: ImageEditorGradientFillStyle {
        document.selectedLayer?.style.strokeGradientStyle ?? .linear
    }

    var selectedLayerStrokeGradientStyleState: ImageEditorLayerStyleValueState<ImageEditorGradientFillStyle> {
        selectedLayerStyleValueState(\.strokeGradientStyle)
    }

    var selectedLayerStrokeGradientAngle: Double {
        Double(document.selectedLayer?.style.strokeGradientAngle ?? 0)
    }

    var selectedLayerStrokePatternKind: ImageEditorPatternOverlayKind {
        document.selectedLayer?.style.strokePatternKind ?? .checkerboard
    }

    var selectedLayerStrokePatternKindState: ImageEditorLayerStyleValueState<ImageEditorPatternOverlayKind> {
        selectedLayerStyleValueState(\.strokePatternKind)
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

    var selectedLayerShadowContourState: ImageEditorLayerStyleValueState<ImageEditorLayerEffectContour> {
        selectedLayerStyleValueState(\.shadowContour)
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

    var selectedLayerInnerGlowSourceState: ImageEditorLayerStyleValueState<ImageEditorInnerGlowSource> {
        selectedLayerStyleValueState(\.innerGlowSource)
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

    var selectedLayerGradientOverlayStyleState: ImageEditorLayerStyleValueState<ImageEditorGradientFillStyle> {
        selectedLayerStyleValueState(\.gradientOverlayStyle)
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

    var selectedLayerPatternOverlayKindState: ImageEditorLayerStyleValueState<ImageEditorPatternOverlayKind> {
        selectedLayerStyleValueState(\.patternOverlayKind)
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

    var selectedLayerBevelHighlightColor: NSColor {
        document.selectedLayer?.style.bevelHighlightColor ?? .white
    }

    var selectedLayerBevelShadowColor: NSColor {
        document.selectedLayer?.style.bevelShadowColor ?? .black
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

    var selectedLayerBevelDirectionState: ImageEditorLayerStyleValueState<ImageEditorBevelDirection> {
        selectedLayerStyleValueState(\.bevelDirection)
    }

    func toggleSelectedLayerStroke() {
        toggleSelectedLayerStyleEffect(.stroke)
    }

    func toggleSelectedLayerShadow() {
        toggleSelectedLayerStyleEffect(.shadow)
    }

    func toggleSelectedLayerInnerShadow() {
        toggleSelectedLayerStyleEffect(.innerShadow)
    }

    func toggleSelectedLayerOuterGlow() {
        toggleSelectedLayerStyleEffect(.outerGlow)
    }

    func toggleSelectedLayerInnerGlow() {
        toggleSelectedLayerStyleEffect(.innerGlow)
    }

    func toggleSelectedLayerColorOverlay() {
        toggleSelectedLayerStyleEffect(.colorOverlay)
    }

    func toggleSelectedLayerGradientOverlay() {
        toggleSelectedLayerStyleEffect(.gradientOverlay)
    }

    func toggleSelectedLayerPatternOverlay() {
        toggleSelectedLayerStyleEffect(.patternOverlay)
    }

    func toggleSelectedLayerSatin() {
        toggleSelectedLayerStyleEffect(.satin)
    }

    func toggleSelectedLayerBevel() {
        toggleSelectedLayerStyleEffect(.bevel)
    }

    func showLayerStyleBlendingOptions() {
        guard canEditSelectedLayerStyle else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        isPropertiesPanelVisible = true
        statusText = L10n.text("imageEditor.status.layerStyleReady")
    }

    func showLayerEffectScaleOptions() {
        guard canScaleSelectedLayerEffects else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        isPropertiesPanelVisible = true
        statusText = L10n.text("imageEditor.status.layerEffectsScaleReady")
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

    @discardableResult
    func createLayerStylePresetFromSelectedLayer(
        name requestedName: String? = nil
    ) -> ImageEditorLayerStylePreset? {
        guard customLayerStylePresets.count < ImageEditorLayerStylePresetPreferences.maximumPresetCount else {
            statusText = L10n.format(
                "imageEditor.status.layerStylePresetLimitReached",
                ImageEditorLayerStylePresetPreferences.maximumPresetCount
            )
            return nil
        }
        guard let layer = document.selectedLayer,
              canCopyLayerStyle(layer),
              layer.style.hasConfiguredEffects
        else {
            statusText = L10n.text("imageEditor.status.layerStylePresetRequiresStyle")
            return nil
        }

        let trimmedName = requestedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name: String
        if let trimmedName, !trimmedName.isEmpty {
            name = trimmedName
        } else {
            let existingNames = Set(customLayerStylePresets.map(\.name))
            var sequence = customLayerStylePresets.count + 1
            var candidate = L10n.format("imageEditor.layerStylePreset.customName", sequence)
            while existingNames.contains(candidate) {
                sequence += 1
                candidate = L10n.format("imageEditor.layerStylePreset.customName", sequence)
            }
            name = candidate
        }

        let preset = ImageEditorLayerStylePreset(
            id: UUID().uuidString,
            name: name,
            style: ImageEditorProjectLayerStyle(style: layer.style)
        ).normalizedCustomPreset
        customLayerStylePresets.append(preset)
        persistLayerStylePresetPreferences()
        statusText = L10n.format("imageEditor.status.layerStylePresetCreated", preset.title)
        return preset
    }

    func applyLayerStylePreset(_ preset: ImageEditorLayerStylePreset) {
        if canApplyLayerStylePreset {
            recordLayerStylePresetUse(id: preset.id)
        }
        let targetIndices = selectedLayerStyleTargetIndices().filter { index in
            !preset.matches(document.layers[index].style)
        }
        guard !targetIndices.isEmpty else {
            statusText = canApplyLayerStylePreset
                ? L10n.format("imageEditor.status.layerStylePresetAlreadyApplied", preset.title)
                : L10n.text("imageEditor.status.layerLocked")
            return
        }

        pushUndo()
        let style = preset.layerStyle
        for index in targetIndices {
            document.layers[index].style = style
        }
        appendHistory(L10n.text("imageEditor.history.layerStylePresetApply"))
        statusText = L10n.format(
            "imageEditor.status.layerStylePresetApplied",
            preset.title,
            targetIndices.count
        )
    }

    func deleteLayerStylePreset(_ preset: ImageEditorLayerStylePreset) {
        guard let index = customLayerStylePresets.firstIndex(where: { $0.id == preset.id }) else {
            return
        }
        let removed = customLayerStylePresets.remove(at: index)
        persistLayerStylePresetPreferences()
        removeLayerStylePresetUsage(id: removed.id)
        statusText = L10n.format("imageEditor.status.layerStylePresetDeleted", removed.title)
    }

    func clearSelectedLayerStyles() {
        let targetIndices = selectedLayerStyleTargetIndices().filter { document.layers[$0].style.hasConfiguredEffects }
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

    func toggleSelectedLayerEffects() {
        let targetIndices = selectedLayerEffectVisibilityTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let shouldEnable = !targetIndices.contains { document.layers[$0].style.effectsEnabled }
        if shouldEnable {
            showSelectedLayerEffects()
        } else {
            hideSelectedLayerEffects()
        }
    }

    func hideSelectedLayerEffects() {
        setLayerEffectsEnabled(
            false,
            indices: selectedLayerEffectVisibilityTargetIndices(),
            historyKey: "imageEditor.history.layerEffectsHideSelected",
            statusKey: "imageEditor.status.layerEffectsHiddenSelected"
        )
    }

    func showSelectedLayerEffects() {
        setLayerEffectsEnabled(
            true,
            indices: selectedLayerEffectVisibilityTargetIndices(),
            historyKey: "imageEditor.history.layerEffectsShowSelected",
            statusKey: "imageEditor.status.layerEffectsShownSelected"
        )
    }

    func hideAllLayerEffects() {
        setAllLayerEffectsEnabled(
            false,
            historyKey: "imageEditor.history.layerEffectsHideAll",
            statusKey: "imageEditor.status.layerEffectsHiddenAll"
        )
    }

    func showAllLayerEffects() {
        setAllLayerEffectsEnabled(
            true,
            historyKey: "imageEditor.history.layerEffectsShowAll",
            statusKey: "imageEditor.status.layerEffectsShownAll"
        )
    }

    func setSelectedLayerEffectScale(_ percentage: Double) {
        guard percentage.isFinite else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let targetIndices = selectedLayerEffectScaleTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let normalizedPercentage = max(1, min(1_000, percentage))
        let normalizedScale = CGFloat(normalizedPercentage / 100)
        guard targetIndices.contains(where: {
            abs(document.layers[$0].style.effectScale - normalizedScale) > 0.0001
        }) else { return }

        pushUndo()
        for index in targetIndices {
            document.layers[index].style.effectScale = normalizedScale
        }
        let roundedPercentage = Int(normalizedPercentage.rounded())
        appendHistory(L10n.text("imageEditor.history.layerEffectsScale"))
        statusText = L10n.format(
            "imageEditor.status.layerEffectsScaled",
            targetIndices.count,
            roundedPercentage
        )
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
        setSelectedLayerLightAngle(angle, effect: .shadow)
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
        setSelectedLayerUsesGlobalLight(enabled, effect: .shadow)
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
        setSelectedLayerLightAngle(angle, effect: .innerShadow)
    }

    func setSelectedLayerInnerShadowUsesGlobalLight(_ enabled: Bool) {
        setSelectedLayerUsesGlobalLight(enabled, effect: .innerShadow)
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

    func toggleSelectedLayerSatinInvert() {
        setSelectedLayerSatinInvert(selectedLayerSatinInvertState != .on)
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

    func setSelectedLayerBevelHighlightColor(_ color: NSColor) {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelHighlightColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    func setSelectedLayerBevelShadowColor(_ color: NSColor) {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelShadowColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    func setSelectedLayerBevelSoften(_ soften: Double) {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelSoften = max(0, min(24, CGFloat(soften)))
        }
    }

    func setSelectedLayerBevelAngle(_ angle: Double) {
        setSelectedLayerLightAngle(angle, effect: .bevel)
    }

    func setSelectedLayerBevelUsesGlobalLight(_ enabled: Bool) {
        setSelectedLayerUsesGlobalLight(enabled, effect: .bevel)
    }

    func toggleSelectedLayerUsesGlobalLight(_ effect: ImageEditorLayerLightEffect) {
        setSelectedLayerUsesGlobalLight(selectedLayerGlobalLightState(effect) != .on, effect: effect)
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

    private func setSelectedLayerLightAngle(
        _ angle: Double,
        effect: ImageEditorLayerLightEffect
    ) {
        let targetIndices = selectedLayerStyleTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let normalizedAngle = normalizedLightAngle(CGFloat(angle))
        let updatesGlobalLight = targetIndices.contains {
            effect.usesGlobalLight(in: self.document.layers[$0].style)
        }
        pushUndo()
        if updatesGlobalLight {
            document.globalLightAngle = normalizedAngle
        }
        for index in targetIndices {
            var style = document.layers[index].style
            setLayerStyleLightAngle(normalizedAngle, effect: effect, style: &style)
            document.layers[index].style = style
        }
        appendHistory(L10n.text("imageEditor.history.layerStyle"))
        statusText = L10n.text("imageEditor.status.layerStyleUpdated")
    }

    private func setLayerStyleLightAngle(
        _ angle: CGFloat,
        effect: ImageEditorLayerLightEffect,
        style: inout ImageEditorLayerStyle
    ) {
        switch effect {
        case .shadow:
            style.shadowEnabled = true
            style.shadowAngle = angle
            style.shadowOffset = style.resolvedShadowOffset(globalLightAngle: document.globalLightAngle)
        case .innerShadow:
            style.innerShadowEnabled = true
            style.innerShadowColor = innerShadowColor()
            style.innerShadowAngle = angle
        case .bevel:
            style.bevelEnabled = true
            style.bevelAngle = angle
        }
    }

    private func setSelectedLayerUsesGlobalLight(
        _ enabled: Bool,
        effect: ImageEditorLayerLightEffect
    ) {
        updateSelectedLayerStyle { style in
            let resolvedAngle = resolvedLayerStyleLightAngle(style, effect: effect)
            setLayerStyleUsesGlobalLight(enabled, effect: effect, style: &style)
            let targetAngle = enabled ? document.globalLightAngle : resolvedAngle
            setLayerStyleLightAngle(targetAngle, effect: effect, style: &style)
        }
    }

    private func resolvedLayerStyleLightAngle(
        _ style: ImageEditorLayerStyle,
        effect: ImageEditorLayerLightEffect
    ) -> CGFloat {
        switch effect {
        case .shadow: style.resolvedShadowAngle(globalLightAngle: document.globalLightAngle)
        case .innerShadow: style.resolvedInnerShadowAngle(globalLightAngle: document.globalLightAngle)
        case .bevel: style.resolvedBevelAngle(globalLightAngle: document.globalLightAngle)
        }
    }

    private func setLayerStyleUsesGlobalLight(
        _ enabled: Bool,
        effect: ImageEditorLayerLightEffect,
        style: inout ImageEditorLayerStyle
    ) {
        switch effect {
        case .shadow: style.shadowUsesGlobalLight = enabled
        case .innerShadow: style.innerShadowUsesGlobalLight = enabled
        case .bevel: style.bevelUsesGlobalLight = enabled
        }
    }

    private func toggleSelectedLayerStyleEffect(_ effect: ImageEditorLayerStyleEffect) {
        let targetIndices = selectedLayerStyleTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let shouldEnable = targetIndices.contains {
            !effect.isEnabled(in: self.document.layers[$0].style)
        }
        pushUndo()
        for index in targetIndices {
            var style = document.layers[index].style
            setLayerStyleEffect(effect, enabled: shouldEnable, style: &style)
            document.layers[index].style = style
        }
        appendHistory(L10n.text(effect.historyKey))
    }

    private func setLayerStyleEffect(
        _ effect: ImageEditorLayerStyleEffect,
        enabled: Bool,
        style: inout ImageEditorLayerStyle
    ) {
        switch effect {
        case .stroke:
            style.strokeEnabled = enabled
            if enabled { updateStrokeFillDefaults(style: &style) }
        case .shadow:
            style.shadowEnabled = enabled
        case .innerShadow:
            style.innerShadowEnabled = enabled
            if enabled { style.innerShadowColor = innerShadowColor() }
        case .outerGlow:
            style.outerGlowEnabled = enabled
        case .innerGlow:
            style.innerGlowEnabled = enabled
        case .colorOverlay:
            style.colorOverlayEnabled = enabled
            if enabled { style.colorOverlayColor = foregroundColor }
        case .gradientOverlay:
            style.gradientOverlayEnabled = enabled
            if enabled {
                style.gradientOverlayStartColor = foregroundColor
                style.gradientOverlayEndColor = gradientOverlayEndColor()
            }
        case .patternOverlay:
            style.patternOverlayEnabled = enabled
            if enabled { style.patternOverlayColor = patternOverlayColor() }
        case .satin:
            style.satinEnabled = enabled
            if enabled { style.satinColor = satinColor() }
        case .bevel:
            style.bevelEnabled = enabled
        }
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

    private func selectedLayerStyleBooleanState(
        _ isEnabled: (ImageEditorLayerStyle) -> Bool
    ) -> ImageEditorLayerStyleSelectionState {
        let targetIndices = selectedLayerStyleTargetIndices()
        guard !targetIndices.isEmpty else { return .off }
        let enabledCount = targetIndices.reduce(into: 0) { count, index in
            if isEnabled(document.layers[index].style) { count += 1 }
        }
        if enabledCount == 0 { return .off }
        if enabledCount == targetIndices.count { return .on }
        return .mixed
    }

    private func selectedLayerStyleValueState<Value: Equatable>(
        _ value: (ImageEditorLayerStyle) -> Value
    ) -> ImageEditorLayerStyleValueState<Value> {
        let targetIndices = selectedLayerStyleTargetIndices()
        guard let firstIndex = targetIndices.first else { return .unavailable }
        let firstValue = value(document.layers[firstIndex].style)
        let allMatch = targetIndices.dropFirst().allSatisfy {
            value(document.layers[$0].style) == firstValue
        }
        return allMatch ? .value(firstValue) : .mixed
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

    private func selectedLayerEffectVisibilityTargetIndices() -> [Int] {
        document.layers.indices.filter { index in
            document.selectedLayerIDs.contains(document.layers[index].id)
                && document.layers[index].style.hasConfiguredEffects
        }
    }

    private func selectedLayerEffectScaleTargetIndices() -> [Int] {
        selectedLayerStyleTargetIndices().filter { index in
            document.layers[index].style.hasConfiguredEffects
        }
    }

    private func setAllLayerEffectsEnabled(
        _ enabled: Bool,
        historyKey: String,
        statusKey: String
    ) {
        let targetIndices = document.layers.indices.filter { index in
            document.layers[index].style.hasConfiguredEffects
                && document.layers[index].style.effectsEnabled != enabled
        }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        setLayerEffectsEnabled(
            enabled,
            indices: targetIndices,
            historyKey: historyKey,
            statusKey: statusKey
        )
    }

    private func setLayerEffectsEnabled(
        _ enabled: Bool,
        indices: [Int],
        historyKey: String,
        statusKey: String
    ) {
        let changedIndices = indices.filter { document.layers[$0].style.effectsEnabled != enabled }
        guard !changedIndices.isEmpty else { return }
        pushUndo()
        for index in changedIndices {
            document.layers[index].style.effectsEnabled = enabled
        }
        appendHistory(L10n.text(historyKey))
        statusText = L10n.format(statusKey, changedIndices.count)
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
