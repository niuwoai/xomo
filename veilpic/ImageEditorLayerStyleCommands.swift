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

struct ImageEditorGlobalLightUpdateResult: Equatable {
    let didUpdate: Bool
    let affectedLayerCount: Int
    let affectedEffectCount: Int
    let shadowLayerCount: Int
    let innerShadowLayerCount: Int
    let bevelLayerCount: Int

    static let unchanged = ImageEditorGlobalLightUpdateResult(
        didUpdate: false,
        affectedLayerCount: 0,
        affectedEffectCount: 0,
        shadowLayerCount: 0,
        innerShadowLayerCount: 0,
        bevelLayerCount: 0
    )
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
        guard let copiedLayerStyle else { return false }
        return !selectedLayerStylePasteTargetIndices(for: copiedLayerStyle).isEmpty
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

    var canHideSelectedLayerEffects: Bool {
        selectedLayerEffectVisibilityTargetIndices().contains {
            document.layers[$0].style.effectsEnabled
        }
    }

    var canShowSelectedLayerEffects: Bool {
        selectedLayerEffectVisibilityTargetIndices().contains {
            !document.layers[$0].style.effectsEnabled
        }
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

    var selectedLayerStrokeWidthState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.strokeWidth)
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

    var selectedLayerStrokeOpacityState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.strokeOpacity)
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

    var selectedLayerStrokeColorState: ImageEditorLayerStyleValueState<ImageEditorProjectColor> {
        selectedLayerStyleValueState { ImageEditorProjectColor(color: $0.strokeColor) }
    }

    var selectedLayerStrokeGradientStartColor: NSColor {
        document.selectedLayer?.style.strokeGradientStartColor ?? .white
    }

    var selectedLayerStrokeGradientStartColorState: ImageEditorLayerStyleValueState<ImageEditorProjectColor> {
        selectedLayerStyleValueState {
            ImageEditorProjectColor(color: $0.strokeGradientStartColor)
        }
    }

    var selectedLayerStrokeGradientEndColor: NSColor {
        document.selectedLayer?.style.strokeGradientEndColor ?? .black
    }

    var selectedLayerStrokeGradientEndColorState: ImageEditorLayerStyleValueState<ImageEditorProjectColor> {
        selectedLayerStyleValueState {
            ImageEditorProjectColor(color: $0.strokeGradientEndColor)
        }
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

    var selectedLayerStrokeGradientAngleState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.strokeGradientAngle)
    }

    var selectedLayerStrokePatternKind: ImageEditorPatternOverlayKind {
        document.selectedLayer?.style.strokePatternKind ?? .checkerboard
    }

    var selectedLayerStrokePatternKindState: ImageEditorLayerStyleValueState<ImageEditorPatternOverlayKind> {
        selectedLayerStyleValueState(\.strokePatternKind)
    }

    var selectedLayerStrokePatternColor: NSColor {
        document.selectedLayer?.style.strokePatternColor ?? .white
    }

    var selectedLayerStrokePatternColorState: ImageEditorLayerStyleValueState<ImageEditorProjectColor> {
        selectedLayerStyleValueState {
            ImageEditorProjectColor(color: $0.strokePatternColor)
        }
    }

    var selectedLayerStrokePatternScale: Double {
        Double(document.selectedLayer?.style.strokePatternScale ?? 14)
    }

    var selectedLayerStrokePatternScaleState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.strokePatternScale)
    }

    var selectedLayerStrokePatternOffsetX: Double {
        Double(document.selectedLayer?.style.strokePatternOffset.width ?? 0)
    }

    var selectedLayerStrokePatternOffsetXState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState { $0.strokePatternOffset.width }
    }

    var selectedLayerStrokePatternOffsetY: Double {
        Double(document.selectedLayer?.style.strokePatternOffset.height ?? 0)
    }

    var selectedLayerStrokePatternOffsetYState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState { $0.strokePatternOffset.height }
    }

    var selectedLayerShadowOpacity: Double {
        Double(document.selectedLayer?.style.shadowOpacity ?? 0.35)
    }

    var selectedLayerShadowOpacityState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.shadowOpacity)
    }

    var selectedLayerShadowColor: NSColor {
        document.selectedLayer?.style.shadowColor ?? .black
    }

    var selectedLayerShadowColorState: ImageEditorLayerStyleValueState<ImageEditorProjectColor> {
        selectedLayerStyleValueState { ImageEditorProjectColor(color: $0.shadowColor) }
    }

    var selectedLayerOuterGlowColor: NSColor {
        document.selectedLayer?.style.outerGlowColor ?? .systemYellow
    }

    var selectedLayerOuterGlowColorState: ImageEditorLayerStyleValueState<ImageEditorProjectColor> {
        selectedLayerStyleValueState { ImageEditorProjectColor(color: $0.outerGlowColor) }
    }

    var selectedLayerInnerGlowColor: NSColor {
        document.selectedLayer?.style.innerGlowColor ?? .systemCyan
    }

    var selectedLayerInnerGlowColorState: ImageEditorLayerStyleValueState<ImageEditorProjectColor> {
        selectedLayerStyleValueState { ImageEditorProjectColor(color: $0.innerGlowColor) }
    }

    var selectedLayerColorOverlayColor: NSColor {
        document.selectedLayer?.style.colorOverlayColor ?? .systemRed
    }

    var selectedLayerShadowBlur: Double {
        Double(document.selectedLayer?.style.shadowBlur ?? 8)
    }

    var selectedLayerShadowBlurState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.shadowBlur)
    }

    var selectedLayerShadowSpread: Double {
        Double(document.selectedLayer?.style.shadowSpread ?? 0)
    }

    var selectedLayerShadowSpreadState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.shadowSpread)
    }

    var selectedLayerShadowNoise: Double {
        Double(document.selectedLayer?.style.shadowNoise ?? 0)
    }

    var selectedLayerShadowNoiseState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.shadowNoise)
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

    var selectedLayerShadowDistanceState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.shadowDistance)
    }

    var selectedLayerShadowAngle: Double {
        guard let style = document.selectedLayer?.style else { return -45 }
        return Double(style.resolvedShadowAngle(globalLightAngle: document.globalLightAngle))
    }

    var selectedLayerShadowAngleState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState {
            $0.resolvedShadowAngle(globalLightAngle: document.globalLightAngle)
        }
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

    var selectedLayerInnerShadowOpacityState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.innerShadowOpacity)
    }

    var selectedLayerInnerShadowBlur: Double {
        Double(document.selectedLayer?.style.innerShadowBlur ?? 8)
    }

    var selectedLayerInnerShadowBlurState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.innerShadowBlur)
    }

    var selectedLayerInnerShadowChoke: Double {
        Double(document.selectedLayer?.style.innerShadowChoke ?? 0)
    }

    var selectedLayerInnerShadowChokeState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.innerShadowChoke)
    }

    var selectedLayerInnerShadowNoise: Double {
        Double(document.selectedLayer?.style.innerShadowNoise ?? 0)
    }

    var selectedLayerInnerShadowNoiseState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.innerShadowNoise)
    }

    var selectedLayerInnerShadowContour: ImageEditorLayerEffectContour {
        document.selectedLayer?.style.innerShadowContour ?? .linear
    }

    var selectedLayerInnerShadowContourState: ImageEditorLayerStyleValueState<ImageEditorLayerEffectContour> {
        selectedLayerStyleValueState(\.innerShadowContour)
    }

    var selectedLayerInnerShadowDistance: Double {
        Double(document.selectedLayer?.style.innerShadowDistance ?? 7)
    }

    var selectedLayerInnerShadowDistanceState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.innerShadowDistance)
    }

    var selectedLayerInnerShadowAngle: Double {
        guard let style = document.selectedLayer?.style else { return -45 }
        return Double(style.resolvedInnerShadowAngle(globalLightAngle: document.globalLightAngle))
    }

    var selectedLayerInnerShadowAngleState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState {
            $0.resolvedInnerShadowAngle(globalLightAngle: document.globalLightAngle)
        }
    }

    var selectedLayerInnerShadowUsesGlobalLight: Bool {
        document.selectedLayer?.style.innerShadowUsesGlobalLight == true
    }

    var selectedLayerOuterGlowOpacity: Double {
        Double(document.selectedLayer?.style.outerGlowOpacity ?? 0.42)
    }

    var selectedLayerOuterGlowOpacityState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.outerGlowOpacity)
    }

    var selectedLayerOuterGlowBlur: Double {
        Double(document.selectedLayer?.style.outerGlowBlur ?? 10)
    }

    var selectedLayerOuterGlowBlurState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.outerGlowBlur)
    }

    var selectedLayerOuterGlowSpread: Double {
        Double(document.selectedLayer?.style.outerGlowSpread ?? 3)
    }

    var selectedLayerOuterGlowSpreadState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.outerGlowSpread)
    }

    var selectedLayerOuterGlowTechnique: ImageEditorGlowTechnique {
        document.selectedLayer?.style.outerGlowTechnique ?? .softer
    }

    var selectedLayerOuterGlowTechniqueState: ImageEditorLayerStyleValueState<ImageEditorGlowTechnique> {
        selectedLayerStyleValueState(\.outerGlowTechnique)
    }

    var selectedLayerOuterGlowNoise: Double {
        Double(document.selectedLayer?.style.outerGlowNoise ?? 0)
    }

    var selectedLayerOuterGlowNoiseState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.outerGlowNoise)
    }

    var selectedLayerOuterGlowContour: ImageEditorLayerEffectContour {
        document.selectedLayer?.style.outerGlowContour ?? .linear
    }

    var selectedLayerOuterGlowContourState: ImageEditorLayerStyleValueState<ImageEditorLayerEffectContour> {
        selectedLayerStyleValueState(\.outerGlowContour)
    }

    var selectedLayerOuterGlowRange: Double {
        Double(document.selectedLayer?.style.outerGlowRange ?? 0.5)
    }

    var selectedLayerOuterGlowRangeState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.outerGlowRange)
    }

    var selectedLayerOuterGlowJitter: Double {
        Double(document.selectedLayer?.style.outerGlowJitter ?? 0)
    }

    var selectedLayerOuterGlowJitterState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.outerGlowJitter)
    }

    var selectedLayerInnerGlowOpacity: Double {
        Double(document.selectedLayer?.style.innerGlowOpacity ?? 0.36)
    }

    var selectedLayerInnerGlowOpacityState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.innerGlowOpacity)
    }

    var selectedLayerInnerGlowBlur: Double {
        Double(document.selectedLayer?.style.innerGlowBlur ?? 8)
    }

    var selectedLayerInnerGlowBlurState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.innerGlowBlur)
    }

    var selectedLayerInnerGlowChoke: Double {
        Double(document.selectedLayer?.style.innerGlowChoke ?? 2)
    }

    var selectedLayerInnerGlowChokeState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.innerGlowChoke)
    }

    var selectedLayerInnerGlowTechnique: ImageEditorGlowTechnique {
        document.selectedLayer?.style.innerGlowTechnique ?? .softer
    }

    var selectedLayerInnerGlowTechniqueState: ImageEditorLayerStyleValueState<ImageEditorGlowTechnique> {
        selectedLayerStyleValueState(\.innerGlowTechnique)
    }

    var selectedLayerInnerGlowNoise: Double {
        Double(document.selectedLayer?.style.innerGlowNoise ?? 0)
    }

    var selectedLayerInnerGlowNoiseState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.innerGlowNoise)
    }

    var selectedLayerInnerGlowSource: ImageEditorInnerGlowSource {
        document.selectedLayer?.style.innerGlowSource ?? .edge
    }

    var selectedLayerInnerGlowSourceState: ImageEditorLayerStyleValueState<ImageEditorInnerGlowSource> {
        selectedLayerStyleValueState(\.innerGlowSource)
    }

    var selectedLayerInnerGlowContour: ImageEditorLayerEffectContour {
        document.selectedLayer?.style.innerGlowContour ?? .linear
    }

    var selectedLayerInnerGlowContourState: ImageEditorLayerStyleValueState<ImageEditorLayerEffectContour> {
        selectedLayerStyleValueState(\.innerGlowContour)
    }

    var selectedLayerInnerGlowRange: Double {
        Double(document.selectedLayer?.style.innerGlowRange ?? 0.5)
    }

    var selectedLayerInnerGlowRangeState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.innerGlowRange)
    }

    var selectedLayerInnerGlowJitter: Double {
        Double(document.selectedLayer?.style.innerGlowJitter ?? 0)
    }

    var selectedLayerInnerGlowJitterState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.innerGlowJitter)
    }

    var selectedLayerColorOverlayOpacity: Double {
        Double(document.selectedLayer?.style.colorOverlayOpacity ?? 0.55)
    }

    var selectedLayerColorOverlayOpacityState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.colorOverlayOpacity)
    }

    var selectedLayerGradientOverlayOpacity: Double {
        Double(document.selectedLayer?.style.gradientOverlayOpacity ?? 0.55)
    }

    var selectedLayerGradientOverlayOpacityState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.gradientOverlayOpacity)
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

    var selectedLayerGradientOverlayScaleState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.gradientOverlayScale)
    }

    var selectedLayerGradientOverlayAngle: Double {
        Double(document.selectedLayer?.style.gradientOverlayAngle ?? 0)
    }

    var selectedLayerGradientOverlayAngleState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.gradientOverlayAngle)
    }

    var selectedLayerPatternOverlayKind: ImageEditorPatternOverlayKind {
        document.selectedLayer?.style.patternOverlayKind ?? .checkerboard
    }

    var selectedLayerPatternOverlayKindState: ImageEditorLayerStyleValueState<ImageEditorPatternOverlayKind> {
        selectedLayerStyleValueState(\.patternOverlayKind)
    }

    var selectedLayerPatternOverlayColor: NSColor {
        document.selectedLayer?.style.patternOverlayColor ?? .white
    }

    var selectedLayerPatternOverlayColorState: ImageEditorLayerStyleValueState<ImageEditorProjectColor> {
        selectedLayerStyleValueState { ImageEditorProjectColor(color: $0.patternOverlayColor) }
    }

    var selectedLayerPatternOverlayOpacity: Double {
        Double(document.selectedLayer?.style.patternOverlayOpacity ?? 0.45)
    }

    var selectedLayerPatternOverlayOpacityState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.patternOverlayOpacity)
    }

    var selectedLayerPatternOverlayScale: Double {
        Double(document.selectedLayer?.style.patternOverlayScale ?? 14)
    }

    var selectedLayerPatternOverlayScaleState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.patternOverlayScale)
    }

    var selectedLayerPatternOverlayOffsetX: Double {
        Double(document.selectedLayer?.style.patternOverlayOffset.width ?? 0)
    }

    var selectedLayerPatternOverlayOffsetXState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState { $0.patternOverlayOffset.width }
    }

    var selectedLayerPatternOverlayOffsetY: Double {
        Double(document.selectedLayer?.style.patternOverlayOffset.height ?? 0)
    }

    var selectedLayerPatternOverlayOffsetYState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState { $0.patternOverlayOffset.height }
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

    var selectedLayerSatinContourState: ImageEditorLayerStyleValueState<ImageEditorLayerEffectContour> {
        selectedLayerStyleValueState(\.satinContour)
    }

    var selectedLayerBevelSize: Double {
        Double(document.selectedLayer?.style.bevelSize ?? 4)
    }

    var selectedLayerBevelSizeState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.bevelSize)
    }

    var selectedLayerBevelOpacity: Double {
        Double(document.selectedLayer?.style.bevelOpacity ?? 0.38)
    }

    var selectedLayerBevelOpacityState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.bevelOpacity)
    }

    var selectedLayerBevelHighlightColor: NSColor {
        document.selectedLayer?.style.bevelHighlightColor ?? .white
    }

    var selectedLayerBevelHighlightColorState: ImageEditorLayerStyleValueState<ImageEditorProjectColor> {
        selectedLayerStyleValueState { ImageEditorProjectColor(color: $0.bevelHighlightColor) }
    }

    var selectedLayerBevelShadowColor: NSColor {
        document.selectedLayer?.style.bevelShadowColor ?? .black
    }

    var selectedLayerBevelShadowColorState: ImageEditorLayerStyleValueState<ImageEditorProjectColor> {
        selectedLayerStyleValueState { ImageEditorProjectColor(color: $0.bevelShadowColor) }
    }

    var selectedLayerBevelSoften: Double {
        Double(document.selectedLayer?.style.bevelSoften ?? 0)
    }

    var selectedLayerBevelSoftenState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState(\.bevelSoften)
    }

    var selectedLayerBevelAngle: Double {
        guard let style = document.selectedLayer?.style else { return -45 }
        return Double(style.resolvedBevelAngle(globalLightAngle: document.globalLightAngle))
    }

    var selectedLayerBevelAngleState: ImageEditorLayerStyleValueState<CGFloat> {
        selectedLayerStyleValueState {
            $0.resolvedBevelAngle(globalLightAngle: document.globalLightAngle)
        }
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

    @discardableResult
    func copySelectedLayerStyle() -> Bool {
        guard canCopySelectedLayerStyle,
              let style = document.selectedLayer?.style
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }
        copiedLayerStyle = style
        copiedLayerStyleSourceID = document.selectedLayerID
        statusText = L10n.text("imageEditor.status.layerStyleCopied")
        return true
    }

    @discardableResult
    func pasteLayerStyleToSelectedLayers() -> Int {
        guard let style = copiedLayerStyle else {
            statusText = L10n.text("imageEditor.status.layerStyleClipboardEmpty")
            return 0
        }
        let targetIndices = selectedLayerStylePasteTargetIndices(for: style)
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }

        pushUndo()
        for index in targetIndices {
            document.layers[index].style = style
        }
        appendHistory(L10n.text("imageEditor.history.layerStylePaste"))
        statusText = L10n.format("imageEditor.status.layerStylePasted", targetIndices.count)
        return targetIndices.count
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

    @discardableResult
    func clearSelectedLayerStyles() -> Int {
        let targetIndices = selectedLayerStyleTargetIndices().filter { document.layers[$0].style.hasConfiguredEffects }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }

        pushUndo()
        for index in targetIndices {
            document.layers[index].style = ImageEditorLayerStyle()
        }
        appendHistory(L10n.text("imageEditor.history.layerStyleClear"))
        statusText = L10n.format("imageEditor.status.layerStyleCleared", targetIndices.count)
        return targetIndices.count
    }

    @discardableResult
    func toggleSelectedLayerEffects() -> Int {
        let targetIndices = selectedLayerEffectVisibilityTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let shouldEnable = targetIndices.contains { !document.layers[$0].style.effectsEnabled }
        if shouldEnable {
            return showSelectedLayerEffects()
        } else {
            return hideSelectedLayerEffects()
        }
    }

    @discardableResult
    func hideSelectedLayerEffects() -> Int {
        setLayerEffectsEnabled(
            false,
            indices: selectedLayerEffectVisibilityTargetIndices(),
            historyKey: "imageEditor.history.layerEffectsHideSelected",
            statusKey: "imageEditor.status.layerEffectsHiddenSelected"
        )
    }

    @discardableResult
    func showSelectedLayerEffects() -> Int {
        setLayerEffectsEnabled(
            true,
            indices: selectedLayerEffectVisibilityTargetIndices(),
            historyKey: "imageEditor.history.layerEffectsShowSelected",
            statusKey: "imageEditor.status.layerEffectsShownSelected"
        )
    }

    @discardableResult
    func hideAllLayerEffects() -> Int {
        setAllLayerEffectsEnabled(
            false,
            historyKey: "imageEditor.history.layerEffectsHideAll",
            statusKey: "imageEditor.status.layerEffectsHiddenAll"
        )
    }

    @discardableResult
    func showAllLayerEffects() -> Int {
        setAllLayerEffectsEnabled(
            true,
            historyKey: "imageEditor.history.layerEffectsShowAll",
            statusKey: "imageEditor.status.layerEffectsShownAll"
        )
    }

    @discardableResult
    func setSelectedLayerEffectScale(_ percentage: Double) -> Int {
        guard percentage.isFinite else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let targetIndices = selectedLayerEffectScaleTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return 0
        }
        let normalizedPercentage = max(1, min(1_000, percentage))
        let normalizedScale = CGFloat(normalizedPercentage / 100)
        let changedIndices = targetIndices.filter {
            abs(document.layers[$0].style.effectScale - normalizedScale) > 0.0001
        }
        guard !changedIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }

        pushUndo()
        for index in changedIndices {
            document.layers[index].style.effectScale = normalizedScale
        }
        let roundedPercentage = Int(normalizedPercentage.rounded())
        appendHistory(L10n.text("imageEditor.history.layerEffectsScale"))
        statusText = L10n.format(
            "imageEditor.status.layerEffectsScaled",
            changedIndices.count,
            roundedPercentage
        )
        return changedIndices.count
    }

    @discardableResult
    func setSelectedLayerStrokeWidth(_ width: Double) -> Int {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeWidth = max(1, min(24, CGFloat(width)))
        }
    }

    @discardableResult
    func setSelectedLayerStrokePosition(_ position: ImageEditorStrokePosition) -> Int {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokePosition = position
        }
    }

    @discardableResult
    func setSelectedLayerStrokeOpacity(_ opacity: Double) -> Int {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    @discardableResult
    func setSelectedLayerStrokeFillType(_ fillType: ImageEditorStrokeFillType) -> Int {
        updateSelectedLayerStyle {
            let fillTypeChanged = $0.strokeFillType != fillType
            $0.strokeEnabled = true
            $0.strokeFillType = fillType
            if fillTypeChanged {
                updateStrokeFillDefaults(style: &$0)
            }
        }
    }

    @discardableResult
    func setSelectedLayerStrokeColorFromForeground() -> Int {
        setSelectedLayerStrokeColor(strokeColor())
    }

    @discardableResult
    func setSelectedLayerStrokeColor(_ color: NSColor) -> Int {
        updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeFillType = .color
            $0.strokeColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    @discardableResult
    func setSelectedLayerStrokeGradientStartColor(_ color: NSColor) -> Int {
        let normalizedColor = color.usingColorSpace(.sRGB) ?? color
        let defaultEndColor = strokeGradientEndColor().usingColorSpace(.sRGB)
            ?? strokeGradientEndColor()
        return updateSelectedLayerStyle {
            if $0.strokeFillType != .gradient {
                $0.strokeGradientEndColor = defaultEndColor
            }
            $0.strokeEnabled = true
            $0.strokeFillType = .gradient
            $0.strokeGradientStartColor = normalizedColor
        }
    }

    @discardableResult
    func setSelectedLayerStrokeGradientEndColor(_ color: NSColor) -> Int {
        let normalizedColor = color.usingColorSpace(.sRGB) ?? color
        let defaultStartColor = foregroundColor.usingColorSpace(.sRGB) ?? foregroundColor
        return updateSelectedLayerStyle {
            if $0.strokeFillType != .gradient {
                $0.strokeGradientStartColor = defaultStartColor
            }
            $0.strokeEnabled = true
            $0.strokeFillType = .gradient
            $0.strokeGradientEndColor = normalizedColor
        }
    }

    @discardableResult
    func setSelectedLayerStrokeGradientStyle(_ style: ImageEditorGradientFillStyle) -> Int {
        updateSelectedLayerStyle {
            let fillTypeChanged = $0.strokeFillType != .gradient
            $0.strokeEnabled = true
            $0.strokeFillType = .gradient
            if fillTypeChanged {
                $0.strokeGradientStartColor = foregroundColor
                $0.strokeGradientEndColor = strokeGradientEndColor()
            }
            $0.strokeGradientStyle = style
        }
    }

    @discardableResult
    func setSelectedLayerStrokeGradientAngle(_ angle: Double) -> Int {
        updateSelectedLayerStyle {
            let fillTypeChanged = $0.strokeFillType != .gradient
            $0.strokeEnabled = true
            $0.strokeFillType = .gradient
            if fillTypeChanged {
                $0.strokeGradientStartColor = foregroundColor
                $0.strokeGradientEndColor = strokeGradientEndColor()
            }
            $0.strokeGradientAngle = CGFloat(angle).truncatingRemainder(dividingBy: 360)
        }
    }

    @discardableResult
    func setSelectedLayerStrokePatternKind(_ kind: ImageEditorPatternOverlayKind) -> Int {
        updateSelectedLayerStyle {
            let fillTypeChanged = $0.strokeFillType != .pattern
            $0.strokeEnabled = true
            $0.strokeFillType = .pattern
            $0.strokePatternKind = kind
            if fillTypeChanged {
                $0.strokePatternColor = strokePatternColor()
            }
        }
    }

    @discardableResult
    func setSelectedLayerStrokePatternColor(_ color: NSColor) -> Int {
        let normalizedColor = color.usingColorSpace(.sRGB) ?? color
        return updateSelectedLayerStyle {
            $0.strokeEnabled = true
            $0.strokeFillType = .pattern
            $0.strokePatternColor = normalizedColor
        }
    }

    @discardableResult
    func setSelectedLayerStrokePatternScale(_ scale: Double) -> Int {
        updateSelectedLayerStyle {
            let fillTypeChanged = $0.strokeFillType != .pattern
            $0.strokeEnabled = true
            $0.strokeFillType = .pattern
            if fillTypeChanged {
                $0.strokePatternColor = strokePatternColor()
            }
            $0.strokePatternScale = max(6, min(64, CGFloat(scale)))
        }
    }

    @discardableResult
    func setSelectedLayerStrokePatternOffsetX(_ offset: Double) -> Int {
        updateSelectedLayerStyle {
            let fillTypeChanged = $0.strokeFillType != .pattern
            $0.strokeEnabled = true
            $0.strokeFillType = .pattern
            if fillTypeChanged {
                $0.strokePatternColor = strokePatternColor()
            }
            $0.strokePatternOffset.width = max(-128, min(128, CGFloat(offset)))
        }
    }

    @discardableResult
    func setSelectedLayerStrokePatternOffsetY(_ offset: Double) -> Int {
        updateSelectedLayerStyle {
            let fillTypeChanged = $0.strokeFillType != .pattern
            $0.strokeEnabled = true
            $0.strokeFillType = .pattern
            if fillTypeChanged {
                $0.strokePatternColor = strokePatternColor()
            }
            $0.strokePatternOffset.height = max(-128, min(128, CGFloat(offset)))
        }
    }

    @discardableResult
    func setSelectedLayerShadowOpacity(_ opacity: Double) -> Int {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    @discardableResult
    func setSelectedLayerShadowColorFromForeground() -> Int {
        setSelectedLayerShadowColor(shadowColor())
    }

    @discardableResult
    func setSelectedLayerShadowColor(_ color: NSColor) -> Int {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    @discardableResult
    func setSelectedLayerOuterGlowColor(_ color: NSColor) -> Int {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    @discardableResult
    func setSelectedLayerInnerGlowColor(_ color: NSColor) -> Int {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    @discardableResult
    func setSelectedLayerColorOverlayColor(_ color: NSColor) -> Int {
        updateSelectedLayerStyle {
            $0.colorOverlayEnabled = true
            $0.colorOverlayColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    @discardableResult
    func setSelectedLayerShadowBlur(_ blur: Double) -> Int {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowBlur = max(0, min(30, CGFloat(blur)))
        }
    }

    @discardableResult
    func setSelectedLayerShadowSpread(_ spread: Double) -> Int {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowSpread = max(0, min(24, CGFloat(spread)))
        }
    }

    @discardableResult
    func setSelectedLayerShadowNoise(_ noise: Double) -> Int {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowNoise = max(0, min(1, CGFloat(noise)))
        }
    }

    @discardableResult
    func setSelectedLayerShadowContour(_ contour: ImageEditorLayerEffectContour) -> Int {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowContour = contour
        }
    }

    @discardableResult
    func setSelectedLayerShadowDistance(_ distance: Double) -> Int {
        updateSelectedLayerStyle {
            $0.shadowEnabled = true
            $0.shadowDistance = max(0, min(80, CGFloat(distance)))
            $0.shadowOffset = ImageEditorLayerStyle.shadowOffset(
                distance: $0.shadowDistance,
                angle: $0.resolvedShadowAngle(globalLightAngle: document.globalLightAngle)
            )
        }
    }

    @discardableResult
    func setSelectedLayerShadowAngle(_ angle: Double) -> Int {
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

    @discardableResult
    func setSelectedLayerShadowUsesGlobalLight(_ enabled: Bool) -> Int {
        setSelectedLayerUsesGlobalLight(enabled, effect: .shadow)
    }

    @discardableResult
    func setGlobalLightAngle(_ angle: Double) -> ImageEditorGlobalLightUpdateResult {
        let normalizedAngle = normalizedLayerStyleAngle(CGFloat(angle))
        guard abs(document.globalLightAngle - normalizedAngle) > 0.001 else { return .unchanged }
        let result = globalLightUpdateResult()
        pushUndo()
        document.globalLightAngle = normalizedAngle
        appendHistory(L10n.text("imageEditor.history.globalLight"))
        statusText = L10n.format("imageEditor.status.globalLight", Int(normalizedAngle.rounded()))
        return result
    }

    @discardableResult
    func setSelectedLayerInnerShadowOpacity(_ opacity: Double) -> Int {
        updateSelectedLayerStyle {
            let wasEnabled = $0.innerShadowEnabled
            $0.innerShadowEnabled = true
            if !wasEnabled {
                $0.innerShadowColor = innerShadowColor()
            }
            $0.innerShadowOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    @discardableResult
    func setSelectedLayerInnerShadowBlur(_ blur: Double) -> Int {
        updateSelectedLayerStyle {
            let wasEnabled = $0.innerShadowEnabled
            $0.innerShadowEnabled = true
            if !wasEnabled {
                $0.innerShadowColor = innerShadowColor()
            }
            $0.innerShadowBlur = max(0, min(40, CGFloat(blur)))
        }
    }

    @discardableResult
    func setSelectedLayerInnerShadowChoke(_ choke: Double) -> Int {
        updateSelectedLayerStyle {
            let wasEnabled = $0.innerShadowEnabled
            $0.innerShadowEnabled = true
            if !wasEnabled {
                $0.innerShadowColor = innerShadowColor()
            }
            $0.innerShadowChoke = max(0, min(24, CGFloat(choke)))
        }
    }

    @discardableResult
    func setSelectedLayerInnerShadowNoise(_ noise: Double) -> Int {
        updateSelectedLayerStyle {
            let wasEnabled = $0.innerShadowEnabled
            $0.innerShadowEnabled = true
            if !wasEnabled {
                $0.innerShadowColor = innerShadowColor()
            }
            $0.innerShadowNoise = max(0, min(1, CGFloat(noise)))
        }
    }

    @discardableResult
    func setSelectedLayerInnerShadowContour(_ contour: ImageEditorLayerEffectContour) -> Int {
        updateSelectedLayerStyle {
            let wasEnabled = $0.innerShadowEnabled
            $0.innerShadowEnabled = true
            if !wasEnabled {
                $0.innerShadowColor = innerShadowColor()
            }
            $0.innerShadowContour = contour
        }
    }

    @discardableResult
    func setSelectedLayerInnerShadowDistance(_ distance: Double) -> Int {
        updateSelectedLayerStyle {
            let wasEnabled = $0.innerShadowEnabled
            $0.innerShadowEnabled = true
            if !wasEnabled {
                $0.innerShadowColor = innerShadowColor()
            }
            $0.innerShadowDistance = max(0, min(48, CGFloat(distance)))
        }
    }

    @discardableResult
    func setSelectedLayerInnerShadowAngle(_ angle: Double) -> Int {
        setSelectedLayerLightAngle(angle, effect: .innerShadow)
    }

    @discardableResult
    func setSelectedLayerInnerShadowUsesGlobalLight(_ enabled: Bool) -> Int {
        setSelectedLayerUsesGlobalLight(enabled, effect: .innerShadow)
    }

    @discardableResult
    func setSelectedLayerOuterGlowOpacity(_ opacity: Double) -> Int {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    @discardableResult
    func setSelectedLayerOuterGlowBlur(_ blur: Double) -> Int {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowBlur = max(0, min(40, CGFloat(blur)))
        }
    }

    @discardableResult
    func setSelectedLayerOuterGlowSpread(_ spread: Double) -> Int {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowSpread = max(0, min(24, CGFloat(spread)))
        }
    }

    @discardableResult
    func setSelectedLayerOuterGlowTechnique(_ technique: ImageEditorGlowTechnique) -> Int {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowTechnique = technique
        }
    }

    @discardableResult
    func setSelectedLayerOuterGlowNoise(_ noise: Double) -> Int {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowNoise = max(0, min(1, CGFloat(noise)))
        }
    }

    @discardableResult
    func setSelectedLayerOuterGlowContour(_ contour: ImageEditorLayerEffectContour) -> Int {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowContour = contour
        }
    }

    @discardableResult
    func setSelectedLayerOuterGlowRange(_ range: Double) -> Int {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowRange = max(0.01, min(1, CGFloat(range)))
        }
    }

    @discardableResult
    func setSelectedLayerOuterGlowJitter(_ jitter: Double) -> Int {
        updateSelectedLayerStyle {
            $0.outerGlowEnabled = true
            $0.outerGlowJitter = max(0, min(1, CGFloat(jitter)))
        }
    }

    @discardableResult
    func setSelectedLayerInnerGlowOpacity(_ opacity: Double) -> Int {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    @discardableResult
    func setSelectedLayerInnerGlowBlur(_ blur: Double) -> Int {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowBlur = max(0, min(40, CGFloat(blur)))
        }
    }

    @discardableResult
    func setSelectedLayerInnerGlowChoke(_ choke: Double) -> Int {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowChoke = max(0, min(24, CGFloat(choke)))
        }
    }

    @discardableResult
    func setSelectedLayerInnerGlowTechnique(_ technique: ImageEditorGlowTechnique) -> Int {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowTechnique = technique
        }
    }

    @discardableResult
    func setSelectedLayerInnerGlowNoise(_ noise: Double) -> Int {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowNoise = max(0, min(1, CGFloat(noise)))
        }
    }

    @discardableResult
    func setSelectedLayerInnerGlowSource(_ source: ImageEditorInnerGlowSource) -> Int {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowSource = source
        }
    }

    @discardableResult
    func setSelectedLayerInnerGlowContour(_ contour: ImageEditorLayerEffectContour) -> Int {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowContour = contour
        }
    }

    @discardableResult
    func setSelectedLayerInnerGlowRange(_ range: Double) -> Int {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowRange = max(0.01, min(1, CGFloat(range)))
        }
    }

    @discardableResult
    func setSelectedLayerInnerGlowJitter(_ jitter: Double) -> Int {
        updateSelectedLayerStyle {
            $0.innerGlowEnabled = true
            $0.innerGlowJitter = max(0, min(1, CGFloat(jitter)))
        }
    }

    @discardableResult
    func setSelectedLayerColorOverlayOpacity(_ opacity: Double) -> Int {
        updateSelectedLayerStyle {
            $0.colorOverlayEnabled = true
            $0.colorOverlayOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    @discardableResult
    func setSelectedLayerGradientOverlayOpacity(_ opacity: Double) -> Int {
        updateSelectedLayerStyle {
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    @discardableResult
    func setSelectedLayerGradientOverlayStartColor(_ color: NSColor) -> Int {
        updateSelectedLayerStyle {
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayStartColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    @discardableResult
    func setSelectedLayerGradientOverlayEndColor(_ color: NSColor) -> Int {
        updateSelectedLayerStyle {
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayEndColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    @discardableResult
    func setSelectedLayerGradientOverlayStyle(_ style: ImageEditorGradientFillStyle) -> Int {
        updateSelectedLayerStyle {
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayStyle = style
        }
    }

    @discardableResult
    func setSelectedLayerGradientOverlayScale(_ scale: Double) -> Int {
        updateSelectedLayerStyle {
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayScale = max(0.25, min(4, CGFloat(scale)))
        }
    }

    @discardableResult
    func setSelectedLayerGradientOverlayAngle(_ angle: Double) -> Int {
        updateSelectedLayerStyle {
            $0.gradientOverlayEnabled = true
            $0.gradientOverlayAngle = normalizedLayerStyleAngle(CGFloat(angle))
        }
    }

    @discardableResult
    func setSelectedLayerPatternOverlayKind(_ kind: ImageEditorPatternOverlayKind) -> Int {
        updateSelectedLayerStyle {
            $0.patternOverlayEnabled = true
            $0.patternOverlayKind = kind
        }
    }

    @discardableResult
    func setSelectedLayerPatternOverlayColor(_ color: NSColor) -> Int {
        updateSelectedLayerStyle {
            $0.patternOverlayEnabled = true
            $0.patternOverlayColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    @discardableResult
    func setSelectedLayerPatternOverlayOpacity(_ opacity: Double) -> Int {
        updateSelectedLayerStyle {
            $0.patternOverlayEnabled = true
            $0.patternOverlayOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    @discardableResult
    func setSelectedLayerPatternOverlayScale(_ scale: Double) -> Int {
        updateSelectedLayerStyle {
            $0.patternOverlayEnabled = true
            $0.patternOverlayScale = max(6, min(64, CGFloat(scale)))
        }
    }

    @discardableResult
    func setSelectedLayerPatternOverlayOffsetX(_ offset: Double) -> Int {
        updateSelectedLayerStyle {
            $0.patternOverlayEnabled = true
            $0.patternOverlayOffset.width = max(-128, min(128, CGFloat(offset)))
        }
    }

    @discardableResult
    func setSelectedLayerPatternOverlayOffsetY(_ offset: Double) -> Int {
        updateSelectedLayerStyle {
            $0.patternOverlayEnabled = true
            $0.patternOverlayOffset.height = max(-128, min(128, CGFloat(offset)))
        }
    }

    @discardableResult
    func setSelectedLayerSatinOpacity(_ opacity: Double) -> Int {
        let defaultColor = satinColor()
        return updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    @discardableResult
    func setSelectedLayerSatinColorFromForeground() -> Int {
        updateSelectedLayerStyle {
            $0.satinEnabled = true
            $0.satinColor = satinColor()
        }
    }

    @discardableResult
    func setSelectedLayerSatinColor(_ color: NSColor) -> Int {
        updateSelectedLayerStyle {
            $0.satinEnabled = true
            $0.satinColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    @discardableResult
    func setSelectedLayerSatinDistance(_ distance: Double) -> Int {
        let defaultColor = satinColor()
        return updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinDistance = max(1, min(48, CGFloat(distance)))
        }
    }

    @discardableResult
    func setSelectedLayerSatinSize(_ size: Double) -> Int {
        let defaultColor = satinColor()
        return updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinSize = max(0, min(40, CGFloat(size)))
        }
    }

    @discardableResult
    func setSelectedLayerSatinAngle(_ angle: Double) -> Int {
        let defaultColor = satinColor()
        return updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinAngle = CGFloat(angle).truncatingRemainder(dividingBy: 360)
        }
    }

    @discardableResult
    func setSelectedLayerSatinInvert(_ enabled: Bool) -> Int {
        let defaultColor = satinColor()
        return updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinInvert = enabled
        }
    }

    func toggleSelectedLayerSatinInvert() {
        _ = setSelectedLayerSatinInvert(selectedLayerSatinInvertState != .on)
    }

    @discardableResult
    func setSelectedLayerSatinContour(_ contour: ImageEditorLayerEffectContour) -> Int {
        let defaultColor = satinColor()
        return updateSelectedLayerStyle {
            if !$0.satinEnabled {
                $0.satinColor = defaultColor
            }
            $0.satinEnabled = true
            $0.satinContour = contour
        }
    }

    @discardableResult
    func setSelectedLayerBevelSize(_ size: Double) -> Int {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelSize = max(1, min(24, CGFloat(size)))
        }
    }

    @discardableResult
    func setSelectedLayerBevelOpacity(_ opacity: Double) -> Int {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelOpacity = max(0.05, min(1, CGFloat(opacity)))
        }
    }

    @discardableResult
    func setSelectedLayerBevelHighlightColor(_ color: NSColor) -> Int {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelHighlightColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    @discardableResult
    func setSelectedLayerBevelShadowColor(_ color: NSColor) -> Int {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelShadowColor = color.usingColorSpace(.sRGB) ?? color
        }
    }

    @discardableResult
    func setSelectedLayerBevelSoften(_ soften: Double) -> Int {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelSoften = max(0, min(24, CGFloat(soften)))
        }
    }

    @discardableResult
    func setSelectedLayerBevelAngle(_ angle: Double) -> Int {
        setSelectedLayerLightAngle(angle, effect: .bevel)
    }

    @discardableResult
    func setSelectedLayerBevelUsesGlobalLight(_ enabled: Bool) -> Int {
        setSelectedLayerUsesGlobalLight(enabled, effect: .bevel)
    }

    func toggleSelectedLayerUsesGlobalLight(_ effect: ImageEditorLayerLightEffect) {
        _ = setSelectedLayerUsesGlobalLight(
            selectedLayerGlobalLightState(effect) != .on,
            effect: effect
        )
    }

    @discardableResult
    func setSelectedLayerBevelDirection(_ direction: ImageEditorBevelDirection) -> Int {
        updateSelectedLayerStyle {
            $0.bevelEnabled = true
            $0.bevelDirection = direction
        }
    }

    private func normalizedLayerStyleAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle.truncatingRemainder(dividingBy: 360)
        if normalized > 180 {
            normalized -= 360
        } else if normalized < -180 {
            normalized += 360
        }
        return normalized
    }

    private func globalLightUpdateResult() -> ImageEditorGlobalLightUpdateResult {
        var affectedLayerIDs = Set<UUID>()
        var shadowLayerCount = 0
        var innerShadowLayerCount = 0
        var bevelLayerCount = 0

        for layer in document.layers {
            let style = layer.style
            if style.shadowEnabled && style.shadowUsesGlobalLight {
                shadowLayerCount += 1
                affectedLayerIDs.insert(layer.id)
            }
            if style.innerShadowEnabled && style.innerShadowUsesGlobalLight {
                innerShadowLayerCount += 1
                affectedLayerIDs.insert(layer.id)
            }
            if style.bevelEnabled && style.bevelUsesGlobalLight {
                bevelLayerCount += 1
                affectedLayerIDs.insert(layer.id)
            }
        }

        return ImageEditorGlobalLightUpdateResult(
            didUpdate: true,
            affectedLayerCount: affectedLayerIDs.count,
            affectedEffectCount: shadowLayerCount + innerShadowLayerCount + bevelLayerCount,
            shadowLayerCount: shadowLayerCount,
            innerShadowLayerCount: innerShadowLayerCount,
            bevelLayerCount: bevelLayerCount
        )
    }

    @discardableResult
    private func setSelectedLayerLightAngle(
        _ angle: Double,
        effect: ImageEditorLayerLightEffect
    ) -> Int {
        let targetIndices = selectedLayerStyleTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return 0
        }
        let normalizedAngle = normalizedLayerStyleAngle(CGFloat(angle))
        let updatesGlobalLight = targetIndices.contains {
            effect.usesGlobalLight(in: self.document.layers[$0].style)
        }
        let globalLightChanged = updatesGlobalLight
            && abs(document.globalLightAngle - normalizedAngle) > 0.001
        let updates = targetIndices.compactMap { index -> (Int, ImageEditorLayerStyle)? in
            let originalStyle = document.layers[index].style
            var style = originalStyle
            setLayerStyleLightAngle(normalizedAngle, effect: effect, style: &style)
            let storedStyleChanged = ImageEditorProjectLayerStyle(style: style)
                != ImageEditorProjectLayerStyle(style: originalStyle)
            let linkedGlobalLightChanged = globalLightChanged
                && effect.usesGlobalLight(in: originalStyle)
            guard storedStyleChanged || linkedGlobalLightChanged else { return nil }
            return (index, style)
        }
        guard globalLightChanged || !updates.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }

        pushUndo()
        if globalLightChanged {
            document.globalLightAngle = normalizedAngle
        }
        for (index, style) in updates {
            document.layers[index].style = style
        }
        appendHistory(L10n.text("imageEditor.history.layerStyle"))
        statusText = L10n.text("imageEditor.status.layerStyleUpdated")
        return updates.count
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
            style.shadowOffset = ImageEditorLayerStyle.shadowOffset(
                distance: style.shadowDistance,
                angle: angle
            )
        case .innerShadow:
            let wasEnabled = style.innerShadowEnabled
            style.innerShadowEnabled = true
            if !wasEnabled {
                style.innerShadowColor = innerShadowColor()
            }
            style.innerShadowAngle = angle
        case .bevel:
            style.bevelEnabled = true
            style.bevelAngle = angle
        }
    }

    @discardableResult
    private func setSelectedLayerUsesGlobalLight(
        _ enabled: Bool,
        effect: ImageEditorLayerLightEffect
    ) -> Int {
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

    @discardableResult
    private func updateSelectedLayerStyle(
        _ mutate: (inout ImageEditorLayerStyle) -> Void
    ) -> Int {
        let targetIndices = selectedLayerStyleTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return 0
        }
        let updates = targetIndices.compactMap { index -> (Int, ImageEditorLayerStyle)? in
            var style = document.layers[index].style
            mutate(&style)
            guard ImageEditorProjectLayerStyle(style: style)
                != ImageEditorProjectLayerStyle(style: document.layers[index].style)
            else { return nil }
            return (index, style)
        }
        guard !updates.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        pushUndo()
        for (index, style) in updates {
            document.layers[index].style = style
        }
        appendHistory(L10n.text("imageEditor.history.layerStyle"))
        return updates.count
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

    private func selectedLayerStylePasteTargetIndices(
        for copiedStyle: ImageEditorLayerStyle
    ) -> [Int] {
        let copiedProjectStyle = ImageEditorProjectLayerStyle(style: copiedStyle)
        return selectedLayerStyleTargetIndices().filter { index in
            document.layers[index].id != copiedLayerStyleSourceID
                && ImageEditorProjectLayerStyle(style: document.layers[index].style) != copiedProjectStyle
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
    ) -> Int {
        let targetIndices = document.layers.indices.filter { index in
            document.layers[index].style.hasConfiguredEffects
                && document.layers[index].style.effectsEnabled != enabled
        }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        return setLayerEffectsEnabled(
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
    ) -> Int {
        let changedIndices = indices.filter { document.layers[$0].style.effectsEnabled != enabled }
        guard !changedIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        pushUndo()
        for index in changedIndices {
            document.layers[index].style.effectsEnabled = enabled
        }
        appendHistory(L10n.text(historyKey))
        statusText = L10n.format(statusKey, changedIndices.count)
        return changedIndices.count
    }

    private func gradientOverlayEndColor() -> NSColor {
        let color = backgroundColor.usingColorSpace(.deviceRGB) ?? backgroundColor
        guard color.alphaComponent > 0.01 else { return .white }
        return backgroundColor
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
