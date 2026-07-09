//
//  ImageEditorViewModel.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UniformTypeIdentifiers

enum ImageEditorImageProcessing {
    static let ciContext = CIContext(options: nil)
}

private struct ImageEditorSmartObjectConversionCandidate {
    var removedLayerIDs: Set<UUID>
    var insertionIndex: Int
    var parentGroupID: UUID?
    var sourceName: String
}

private struct ImageEditorSmartObjectConversionPlan {
    var replacementLayer: ImageEditorLayer
    var removedLayerIDs: Set<UUID>
    var insertionIndex: Int
}

@MainActor
final class ImageEditorViewModel: ObservableObject {
    @Published var document: ImageEditorDocument
    @Published var selectedTool: ImageEditorTool = .move
    @Published var zoom: CGFloat = 1
    @Published var canvasOffset: CGSize = .zero
    @Published var brushSize: CGFloat = 18
    @Published var opacity: CGFloat = 1
    @Published var hardness: CGFloat = 0.8
    @Published var feather: CGFloat = 0
    @Published var selectionModifyAmount: CGFloat = 4
    @Published var tolerance: CGFloat = 0.22
    @Published var selectionMode: ImageEditorSelectionMode = .replace
    @Published var isColorRangeSheetPresented = false
    @Published var colorRangeColor: NSColor = .systemRed
    @Published var colorRangeIncludeColors: [NSColor] = [.systemRed]
    @Published var colorRangeExcludeColors: [NSColor] = []
    @Published var colorRangeSampleMode: ImageEditorColorRangeSampleMode = .replace
    @Published var colorRangeTolerance: CGFloat = 0.22
    @Published var colorRangeInverted = false
    @Published var foregroundColor: NSColor = .systemRed
    @Published var backgroundColor: NSColor = .clear
    @Published var cloneSourcePoint: CGPoint?
    @Published var statusText: String = ""
    @Published var pointerText: String = "X: 0 Y: 0"
    @Published var textValue: String = ""
    @Published var textSize: Double = 32
    @Published var textBold: Bool = false
    @Published var textItalic: Bool = false
    @Published var textCharacterSpacing: Double = 0
    @Published var textLineSpacing: Double = 0
    @Published var textBoxWidth: Double = 0
    @Published var selectedTextAlignment: ImageEditorTextAlignment = .left
    @Published var selectedAdjustment: ImageEditorAdjustment = .brightness
    @Published var adjustmentValue: Double = 0
    @Published var levelsBlackPoint: Double = 0
    @Published var levelsGamma: Double = 1
    @Published var levelsWhitePoint: Double = 1
    @Published var curvesShadows: Double = 0
    @Published var curvesMidtones: Double = 0
    @Published var curvesHighlights: Double = 0
    @Published var colorBalanceShadowsCyanRed: Double = 0
    @Published var colorBalanceShadowsMagentaGreen: Double = 0
    @Published var colorBalanceShadowsYellowBlue: Double = 0
    @Published var colorBalanceMidtonesCyanRed: Double = 0
    @Published var colorBalanceMidtonesMagentaGreen: Double = 0
    @Published var colorBalanceMidtonesYellowBlue: Double = 0
    @Published var colorBalanceHighlightsCyanRed: Double = 0
    @Published var colorBalanceHighlightsMagentaGreen: Double = 0
    @Published var colorBalanceHighlightsYellowBlue: Double = 0
    @Published var hueSaturationHue: Double = 0
    @Published var hueSaturationSaturation: Double = 0
    @Published var hueSaturationLightness: Double = 0
    @Published var hueSaturationColorize: Bool = false
    @Published var brightnessContrastBrightness: Double = 0
    @Published var brightnessContrastContrast: Double = 0
    @Published var exposureEV: Double = 0
    @Published var exposureOffset: Double = 0
    @Published var exposureGamma: Double = 1
    @Published var shadowsHighlightsShadows: Double = 0
    @Published var shadowsHighlightsHighlights: Double = 0
    @Published var vibranceAmount: Double = 0
    @Published var vibranceSaturation: Double = 0
    @Published var blackWhiteReds: Double = 0.40
    @Published var blackWhiteYellows: Double = 0.60
    @Published var blackWhiteGreens: Double = 0.40
    @Published var blackWhiteCyans: Double = 0.60
    @Published var blackWhiteBlues: Double = 0.20
    @Published var blackWhiteMagentas: Double = 0.80
    @Published var selectedChannelMixerOutput: ImageEditorChannelMixerOutput = .red
    @Published var channelMixerRedRed: Double = 1
    @Published var channelMixerRedGreen: Double = 0
    @Published var channelMixerRedBlue: Double = 0
    @Published var channelMixerRedConstant: Double = 0
    @Published var channelMixerGreenRed: Double = 0
    @Published var channelMixerGreenGreen: Double = 1
    @Published var channelMixerGreenBlue: Double = 0
    @Published var channelMixerGreenConstant: Double = 0
    @Published var channelMixerBlueRed: Double = 0
    @Published var channelMixerBlueGreen: Double = 0
    @Published var channelMixerBlueBlue: Double = 1
    @Published var channelMixerBlueConstant: Double = 0
    @Published var channelMixerMonochrome: Bool = false
    @Published var channelMixerMonoRed: Double = 0.40
    @Published var channelMixerMonoGreen: Double = 0.40
    @Published var channelMixerMonoBlue: Double = 0.20
    @Published var channelMixerMonoConstant: Double = 0
    @Published var selectedPhotoFilterPreset: ImageEditorPhotoFilterPreset = .warming85
    @Published var photoFilterDensity: Double = 0.25
    @Published var photoFilterPreserveLuminosity: Bool = true
    @Published var photoFilterCustomRed: Double = 1
    @Published var photoFilterCustomGreen: Double = 0.65
    @Published var photoFilterCustomBlue: Double = 0.30
    @Published var selectedColorLookupPreset: ImageEditorColorLookupPreset = .filmStock
    @Published var selectedColorLookupCube: ImageEditorColorLookupCube = ImageEditorColorLookupCube()
    @Published var selectedSelectiveColorRange: ImageEditorSelectiveColorRange = .reds
    @Published var selectiveColorSettings = ImageEditorSelectiveColorSettings()
    @Published var selectiveColorMethod: ImageEditorSelectiveColorMethod = .relative
    @Published var selectedGradientMapPreset: ImageEditorGradientMapPreset = .blackWhite
    @Published var gradientMapReverse: Bool = false
    @Published var gradientMapDither: Bool = false
    @Published var gradientMapShadowRed: Double = 0
    @Published var gradientMapShadowGreen: Double = 0
    @Published var gradientMapShadowBlue: Double = 0
    @Published var gradientMapHighlightRed: Double = 1
    @Published var gradientMapHighlightGreen: Double = 1
    @Published var gradientMapHighlightBlue: Double = 1
    @Published var solidColorFillRed: Double = 1
    @Published var solidColorFillGreen: Double = 0
    @Published var solidColorFillBlue: Double = 0
    @Published var selectedPatternFillKind: ImageEditorPatternOverlayKind = .checkerboard
    @Published var patternFillRed: Double = 0.10
    @Published var patternFillGreen: Double = 0.24
    @Published var patternFillBlue: Double = 0.95
    @Published var patternFillOpacity: Double = 0.55
    @Published var patternFillScale: Double = 16
    @Published var selectedGradientFillPreset: ImageEditorGradientFillPreset = .blueOrange
    @Published var selectedGradientFillStyle: ImageEditorGradientFillStyle = .linear
    @Published var gradientFillReverse: Bool = false
    @Published var gradientFillAngle: Double = 0
    @Published var gradientFillScale: Double = 1
    @Published var gradientFillStartRed: Double = 0.10
    @Published var gradientFillStartGreen: Double = 0.24
    @Published var gradientFillStartBlue: Double = 0.95
    @Published var gradientFillEndRed: Double = 1
    @Published var gradientFillEndGreen: Double = 0.50
    @Published var gradientFillEndBlue: Double = 0.12
    @Published var selectedFilter: ImageEditorFilter = .gaussianBlur
    @Published var filterIntensity: Double = 0.5
    @Published var filterUnsharpRadius: Double = 1
    @Published var filterUnsharpThreshold: Double = 0
    @Published var filterLiquifyPushX: Double = 0.25
    @Published var filterLiquifyPushY: Double = 0
    @Published var filterLiquifyTwirlAngle: Double = 0.5
    @Published var filterLiquifyBulgeAmount: Double = 0.5
    @Published var filterOffsetX: Double = 0.25
    @Published var filterOffsetY: Double = 0
    @Published var filterWaveAmplitude: Double = 0.5
    @Published var filterWaveFrequency: Double = 0.25
    @Published var filterRippleAmount: Double = 0.5
    @Published var filterRippleFrequency: Double = 0.25
    @Published var selectedChannelPreview: ImageEditorChannelPreview = .composite
    @Published var isEditingLayerMask: Bool = false
    @Published var pendingPenPathPoints: [CGPoint] = []
    @Published var selectedPathSubpathIndex: Int = 0
    @Published var selectedPathAnchorIndex: Int?
    @Published var selectedPathControlRole: ImageEditorPathControlRole = .anchor
    @Published var targetImageWidth: Double = 0
    @Published var targetImageHeight: Double = 0
    @Published var targetCanvasWidth: Double = 0
    @Published var targetCanvasHeight: Double = 0
    @Published var selectedCanvasAnchor: ImageEditorCanvasAnchor = .center
    @Published var exportSettings = ImageEditorExportSettings()
    @Published var isExportSheetPresented = false
    @Published var namedHistorySnapshots: [ImageEditorHistorySnapshot] = []

    var undoStack: [ImageEditorDocument] = []
    var redoStack: [ImageEditorDocument] = []
    var historySnapshots: [UUID: ImageEditorDocument] = [:]
    var movingLayerIDs = Set<UUID>()
    var movingLayerDidChange = false
    var movingGuideID: UUID?
    var movingGuideDidChange = false
    var movingPathAnchorDidChange = false
    var resizingLayerIDs = Set<UUID>()
    var resizingOriginalFrames: [UUID: CGRect] = [:]
    var resizingOriginalTransformFrame: CGRect?
    var resizingLayerDidChange = false
    var rotatingLayerIDs = Set<UUID>()
    var rotatingOriginalLayers: [UUID: ImageEditorLayer] = [:]
    var rotatingOriginalTransformFrame: CGRect?
    var rotatingStartAngleDegrees: CGFloat = 0
    var rotatingLayerDidChange = false
    var copiedLayerStyle: ImageEditorLayerStyle?
    private let onApply: (NSImage) -> Void

    init(sourceName: String, image: NSImage, onApply: @escaping (NSImage) -> Void) {
        document = ImageEditorDocument(sourceName: sourceName, image: image.normalizedBitmapImage())
        self.onApply = onApply
        syncSizeControlsFromDocument()
        recordCurrentHistorySnapshot()
        updateStatus()
    }

    var currentImage: NSImage {
        document.compositedImage
    }

    var previewImage: NSImage {
        currentImage.channelPreview(selectedChannelPreview)
    }

    func channelPreviewImage(for channel: ImageEditorChannelPreview) -> NSImage {
        currentImage.channelPreview(channel)
    }

    func selectChannelPreview(_ channel: ImageEditorChannelPreview) {
        selectedChannelPreview = channel
        statusText = L10n.format("imageEditor.status.channelPreview", channel.title)
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    var historyStateSummary: String {
        L10n.format(
            "imageEditor.history.summary",
            document.history.count,
            undoStack.count,
            redoStack.count
        )
    }

    var zoomText: String {
        "\(Int((zoom * 100).rounded()))%"
    }

    var sizeText: String {
        let size = document.canvasSize
        return "\(Int(size.width.rounded())) x \(Int(size.height.rounded())) px"
    }

    var histogramSummary: ImageEditorHistogramSummary {
        currentImage.histogramSummary()
    }

    var histogramAverageText: String {
        histogramAverageText(for: histogramSummary)
    }

    func histogramAverageText(for summary: ImageEditorHistogramSummary) -> String {
        return L10n.format(
            "imageEditor.histogram.average",
            Int(summary.averageRed.rounded()),
            Int(summary.averageGreen.rounded()),
            Int(summary.averageBlue.rounded())
        )
    }

    var histogramLuminanceText: String {
        histogramLuminanceText(for: histogramSummary)
    }

    func histogramLuminanceText(for summary: ImageEditorHistogramSummary) -> String {
        return L10n.format("imageEditor.histogram.luminance", Int(summary.averageLuminance.rounded()))
    }

    var histogramClippingText: String {
        histogramClippingText(for: histogramSummary)
    }

    func histogramClippingText(for summary: ImageEditorHistogramSummary) -> String {
        return L10n.format(
            "imageEditor.histogram.clipping",
            Int((summary.clippedShadowRatio * 100).rounded()),
            Int((summary.clippedHighlightRatio * 100).rounded())
        )
    }

    var selectedLayerOpacity: Double {
        guard let layer = document.selectedLayer else { return 1 }
        return layer.opacity
    }

    var selectedLayerFillOpacity: Double {
        guard let layer = document.selectedLayer else { return 1 }
        return layer.fillOpacity
    }

    var selectedLayerBlendIfSourceBlack: Double {
        guard let layer = document.selectedLayer else { return 0 }
        return layer.blendIfSourceBlack
    }

    var selectedLayerBlendIfSourceWhite: Double {
        guard let layer = document.selectedLayer else { return 1 }
        return layer.blendIfSourceWhite
    }

    var selectedLayerBlendIfUnderlyingBlack: Double {
        guard let layer = document.selectedLayer else { return 0 }
        return layer.blendIfUnderlyingBlack
    }

    var selectedLayerBlendIfUnderlyingWhite: Double {
        guard let layer = document.selectedLayer else { return 1 }
        return layer.blendIfUnderlyingWhite
    }

    var canEditSelectedLayerFillOpacity: Bool {
        guard let layer = document.selectedLayer else { return false }
        return canSetLayerFillOpacity(layer)
    }

    var canEditSelectedLayerBlendIf: Bool {
        guard let layer = document.selectedLayer else { return false }
        return canSetLayerBlendIf(layer)
    }

    var selectedLayerMaskDensity: Double {
        guard let layer = document.selectedLayer else { return 1 }
        return layer.maskDensity
    }

    var selectedLayerMaskFeather: Double {
        guard let layer = document.selectedLayer else { return 0 }
        return layer.maskFeather
    }

    var canEditSelectedLayerMaskProperties: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return layer.mask != nil && !document.isEffectivelyLocked(layer)
    }

    var selectedLayerBlendMode: ImageEditorBlendMode {
        guard let layer = document.selectedLayer else { return .normal }
        return layer.blendMode
    }

    var selectedLayerBlendModes: [ImageEditorBlendMode] {
        guard let layer = document.selectedLayer else { return [.normal] }
        return ImageEditorBlendMode.allCases.filter { layer.isGroup || $0 != .passThrough }
    }

    var selectedLayerName: String {
        document.selectedLayer?.name ?? ""
    }

    var selectedLayerIsGroup: Bool {
        document.selectedLayer?.isGroup == true
    }

    var selectedLayerIsAdjustment: Bool {
        document.selectedLayer?.isAdjustment == true
    }

    var selectedLayerIsFilter: Bool {
        document.selectedLayer?.isFilter == true
    }

    var selectedLayerIsSolidColorFill: Bool {
        document.selectedLayer?.isSolidColorFill == true
    }

    var selectedLayerIsPatternFill: Bool {
        document.selectedLayer?.isPatternFill == true
    }

    var selectedLayerIsGradientFill: Bool {
        document.selectedLayer?.isGradientFill == true
    }

    var selectedLayerIsText: Bool {
        document.selectedLayer?.isText == true
    }

    var selectedLayerIsShape: Bool {
        document.selectedLayer?.isShape == true
    }

    var canFinishPenPath: Bool {
        pendingPenPathPoints.count >= 2
    }

    var canEditSelectedPathAnchors: Bool {
        guard selectedLayerCount == 1,
              let content = document.selectedLayer?.shapeContent,
              content.kind == .path
        else { return false }
        return content.allEditablePathSubpaths.contains { !$0.isEmpty }
    }

    var selectedPathAnchorCanvasPoint: CGPoint? {
        guard let index = selectedPathAnchorIndex,
              let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              content.allEditablePathSubpaths[selectedPathSubpathIndex].indices.contains(index)
        else { return nil }
        return canvasPoint(for: content.allEditablePathSubpaths[selectedPathSubpathIndex][index].point, in: layer)
    }

    var selectedPathInControlCanvasPoint: CGPoint? {
        selectedPathControlCanvasPoint(role: .inHandle)
    }

    var selectedPathOutControlCanvasPoint: CGPoint? {
        selectedPathControlCanvasPoint(role: .outHandle)
    }

    var selectedLayerHasSmartFilters: Bool {
        document.selectedLayer?.hasSmartFilters == true
    }

    var canAutoLevelsSelectedLayer: Bool {
        !isEditingLayerMask && editableSelectedLayer() != nil
    }

    var canAutoContrastSelectedLayer: Bool {
        canAutoLevelsSelectedLayer
    }

    var canAutoColorSelectedLayer: Bool {
        canAutoLevelsSelectedLayer
    }

    var selectedLayerSmartFilters: [ImageEditorSmartFilter] {
        document.selectedLayer?.smartFilters ?? []
    }

    var selectedLayerSmartFilterText: String {
        guard let filters = document.selectedLayer?.smartFilters,
              !filters.isEmpty
        else {
            return L10n.text("imageEditor.properties.smartFiltersEmpty")
        }
        let names = filters.map { smartFilterLabel($0) }
        return names.joined(separator: L10n.text("imageEditor.properties.smartFilterSeparator"))
    }

    func smartFilterLabel(_ filter: ImageEditorSmartFilter) -> String {
        if filter.kind == .unsharpMask {
            let settings = filter.normalizedSettings
            let title = L10n.format(
                "imageEditor.properties.smartFilterUnsharpItem",
                filter.kind.title,
                Int((filter.normalizedIntensity * 100).rounded()),
                String(format: "%.1f", settings.unsharpRadius),
                Int((settings.unsharpThreshold * 255).rounded())
            )
            guard !filter.isEnabled else { return title }
            return L10n.format("imageEditor.properties.smartFilterDisabled", title)
        }
        if filter.kind == .liquifyPush {
            let settings = filter.normalizedSettings
            let title = L10n.format(
                "imageEditor.properties.smartFilterLiquifyPushItem",
                filter.kind.title,
                Int((filter.normalizedIntensity * 100).rounded()),
                Int((settings.liquifyPushX * 100).rounded()),
                Int((settings.liquifyPushY * 100).rounded())
            )
            guard !filter.isEnabled else { return title }
            return L10n.format("imageEditor.properties.smartFilterDisabled", title)
        }
        if filter.kind == .liquifyTwirl {
            let settings = filter.normalizedSettings
            let title = L10n.format(
                "imageEditor.properties.smartFilterLiquifyTwirlItem",
                filter.kind.title,
                Int((filter.normalizedIntensity * 100).rounded()),
                Int((settings.liquifyTwirlAngle * 100).rounded())
            )
            guard !filter.isEnabled else { return title }
            return L10n.format("imageEditor.properties.smartFilterDisabled", title)
        }
        if filter.kind == .liquifyPuckerBloat {
            let settings = filter.normalizedSettings
            let title = L10n.format(
                "imageEditor.properties.smartFilterLiquifyPuckerBloatItem",
                filter.kind.title,
                Int((filter.normalizedIntensity * 100).rounded()),
                Int((settings.liquifyBulgeAmount * 100).rounded())
            )
            guard !filter.isEnabled else { return title }
            return L10n.format("imageEditor.properties.smartFilterDisabled", title)
        }
        if filter.kind == .wave {
            let settings = filter.normalizedSettings
            let title = L10n.format(
                "imageEditor.properties.smartFilterWaveItem",
                filter.kind.title,
                Int((filter.normalizedIntensity * 100).rounded()),
                Int((settings.waveAmplitude * 100).rounded()),
                Int((settings.waveFrequency * 100).rounded())
            )
            guard !filter.isEnabled else { return title }
            return L10n.format("imageEditor.properties.smartFilterDisabled", title)
        }
        if filter.kind == .offset {
            let settings = filter.normalizedSettings
            let title = L10n.format(
                "imageEditor.properties.smartFilterOffsetItem",
                filter.kind.title,
                Int((filter.normalizedIntensity * 100).rounded()),
                Int((settings.offsetX * 100).rounded()),
                Int((settings.offsetY * 100).rounded())
            )
            guard !filter.isEnabled else { return title }
            return L10n.format("imageEditor.properties.smartFilterDisabled", title)
        }
        if filter.kind == .ripple {
            let settings = filter.normalizedSettings
            let title = L10n.format(
                "imageEditor.properties.smartFilterRippleItem",
                filter.kind.title,
                Int((filter.normalizedIntensity * 100).rounded()),
                Int((settings.rippleAmount * 100).rounded()),
                Int((settings.rippleFrequency * 100).rounded())
            )
            guard !filter.isEnabled else { return title }
            return L10n.format("imageEditor.properties.smartFilterDisabled", title)
        }
        let title = L10n.format(
            "imageEditor.properties.smartFilterItem",
            filter.kind.title,
            Int((filter.normalizedIntensity * 100).rounded())
        )
        guard !filter.isEnabled else { return title }
        return L10n.format("imageEditor.properties.smartFilterDisabled", title)
    }

    var selectedLayerCount: Int {
        selectedLayerIndices.count
    }

    var hasMultiLayerSelection: Bool {
        selectedLayerCount > 1
    }

    var canSelectAllLayers: Bool {
        selectedLayerCount < document.layers.count
    }

    var canClearLayerSelection: Bool {
        selectedLayerCount > 0
    }

    var canInvertLayerSelection: Bool {
        !document.layers.isEmpty
    }

    var canSetSelectedLayerLabelColor: Bool {
        selectedLayerCount > 0
    }

    var canIsolateSelectedLayers: Bool {
        let visibleIDs = isolatedLayerVisibilityIDs()
        guard !visibleIDs.isEmpty else { return false }
        return document.layers.contains { layer in
            layer.isVisible != visibleIDs.contains(layer.id)
        }
    }

    var canShowAllLayers: Bool {
        document.layers.contains { !$0.isVisible }
    }

    var visibleLayerRows: [ImageEditorLayer] {
        document.layers.reversed().filter { layer in
            document.ancestorGroups(for: layer).allSatisfy(\.isGroupExpanded)
        }
    }

    func visibleLayerRows(matching query: String) -> [ImageEditorLayer] {
        visibleLayerRows(matching: query, kindFilter: .all, labelFilter: nil, stateFilter: .all, attributeFilter: .all)
    }

    func visibleLayerRows(matching query: String, kindFilter: ImageEditorLayerKindFilter) -> [ImageEditorLayer] {
        visibleLayerRows(matching: query, kindFilter: kindFilter, labelFilter: nil, stateFilter: .all, attributeFilter: .all)
    }

    func visibleLayerRows(
        matching query: String,
        kindFilter: ImageEditorLayerKindFilter,
        labelFilter: ImageEditorLayerLabelColor?
    ) -> [ImageEditorLayer] {
        visibleLayerRows(matching: query, kindFilter: kindFilter, labelFilter: labelFilter, stateFilter: .all, attributeFilter: .all)
    }

    func visibleLayerRows(
        matching query: String,
        kindFilter: ImageEditorLayerKindFilter,
        labelFilter: ImageEditorLayerLabelColor?,
        stateFilter: ImageEditorLayerStateFilter
    ) -> [ImageEditorLayer] {
        visibleLayerRows(
            matching: query,
            kindFilter: kindFilter,
            labelFilter: labelFilter,
            stateFilter: stateFilter,
            attributeFilter: .all
        )
    }

    func visibleLayerRows(
        matching query: String,
        kindFilter: ImageEditorLayerKindFilter,
        labelFilter: ImageEditorLayerLabelColor?,
        stateFilter: ImageEditorLayerStateFilter,
        attributeFilter: ImageEditorLayerAttributeFilter
    ) -> [ImageEditorLayer] {
        let rows = visibleLayerRows
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return rows.filter { layer in
            let matchesQuery = trimmedQuery.isEmpty || layer.name.localizedCaseInsensitiveContains(trimmedQuery)
            let matchesLabel = labelFilter.map { layer.labelColor == $0 } ?? true
            return matchesQuery
                && kindFilter.matches(layer)
                && matchesLabel
                && layerMatchesStateFilter(layer, stateFilter)
                && attributeFilter.matches(layer)
        }
    }

    private func layerMatchesStateFilter(
        _ layer: ImageEditorLayer,
        _ stateFilter: ImageEditorLayerStateFilter
    ) -> Bool {
        switch stateFilter {
        case .all:
            return true
        case .visible:
            return document.isEffectivelyVisible(layer)
        case .hidden:
            return !document.isEffectivelyVisible(layer)
        case .locked:
            return document.isEffectivelyLocked(layer)
        case .unlocked:
            return !document.isEffectivelyLocked(layer)
        }
    }

    var selectedLayerIsClippingMask: Bool {
        document.selectedLayer?.isClippingMask == true
    }

    var selectedLayerHasMask: Bool {
        guard let layer = document.selectedLayer else { return false }
        return layer.mask != nil
    }

    var canAddLayerMask: Bool {
        guard let layer = document.selectedLayer else { return false }
        return !document.isEffectivelyLocked(layer) && layer.mask == nil
    }

    var canDeleteLayerMask: Bool {
        guard let layer = document.selectedLayer else { return false }
        return !document.isEffectivelyLocked(layer) && layer.mask != nil
    }

    var selection: ImageEditorSelection? {
        document.selection
    }

    var hasSelection: Bool {
        document.selection != nil
    }

    var canDeleteLayer: Bool {
        let deletionIDs = deletionIDsForCurrentSelection()
        return !deletionIDs.isEmpty && document.layers.count - deletionIDs.count >= 1
    }

    var canMergeSelectedLayerDown: Bool {
        guard selectedLayerCount == 1,
              let index = document.selectedLayerIndex,
              index > 0
        else { return false }
        let layer = document.layers[index]
        let lower = document.layers[index - 1]
        if layer.isAdjustment {
            return !lower.isGroup
                && !lower.isAdjustment
                && !lower.isFilter
                && !lower.isSolidColorFill
                && !lower.isPatternFill
                && !lower.isGradientFill
                && !document.isEffectivelyLocked(layer)
                && !document.isEffectivelyPixelsLocked(lower)
        }
        if layer.isFilter {
            return !lower.isGroup
                && !lower.isAdjustment
                && !lower.isFilter
                && !lower.isSolidColorFill
                && !lower.isPatternFill
                && !lower.isGradientFill
                && !document.isEffectivelyLocked(layer)
                && !document.isEffectivelyPixelsLocked(lower)
        }
        if layer.isSolidColorFill || layer.isPatternFill || layer.isGradientFill {
            return !lower.isGroup
                && !lower.isAdjustment
                && !lower.isFilter
                && !lower.isSolidColorFill
                && !lower.isPatternFill
                && !lower.isGradientFill
                && !document.isEffectivelyLocked(layer)
                && !document.isEffectivelyPixelsLocked(lower)
        }
        return !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && !layer.isSolidColorFill
            && !layer.isPatternFill
            && !layer.isGradientFill
            && !lower.isGroup
            && !lower.isAdjustment
            && !lower.isFilter
            && !lower.isSolidColorFill
            && !lower.isPatternFill
            && !lower.isGradientFill
            && !document.isEffectivelyPixelsLocked(layer)
            && !document.isEffectivelyPixelsLocked(lower)
    }

    var canStampVisibleLayers: Bool {
        document.layers.contains { layer in
            document.shouldComposite(layer)
        }
    }

    var canGroupSelectedLayer: Bool {
        let indices = selectedLayerIndices
        guard !indices.isEmpty else { return false }
        let selectedLayers = indices.map { document.layers[$0] }
        let parentIDs = Set(selectedLayers.map(\.groupID))
        guard parentIDs.count == 1 else { return false }
        return indices.allSatisfy { index in
            let layer = document.layers[index]
            return !document.isEffectivelyLocked(layer)
        }
    }

    var canSelectSelectedGroupMembers: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              layer.isGroup
        else { return false }
        return !groupDescendantIndices(for: layer.id).isEmpty
    }

    var canMoveSelectedLayersIntoGroup: Bool {
        let indices = movableSelectedLayerIndicesForHierarchyChange()
        return !indices.isEmpty && groupTargetForMovingSelectionIntoGroup() != nil
    }

    var canMoveSelectedLayersOutOfGroup: Bool {
        let indices = movableSelectedLayerIndicesForHierarchyChange()
        guard !indices.isEmpty else { return false }
        return indices.allSatisfy { document.layers[$0].groupID != nil }
    }

    var canUngroupSelectedLayers: Bool {
        selectedLayerIndices.contains { index in
            let layer = document.layers[index]
            return layer.isGroup && !document.isEffectivelyLocked(layer)
        }
    }

    var canMoveSelectedLayerUp: Bool {
        canMoveSelectedLayers(direction: 1)
    }

    var canMoveSelectedLayerDown: Bool {
        canMoveSelectedLayers(direction: -1)
    }

    var canMoveSelectedLayerToTop: Bool {
        canMoveSelectedLayers(to: .top)
    }

    var canMoveSelectedLayerToBottom: Bool {
        canMoveSelectedLayers(to: .bottom)
    }

    var canToggleSelectedLayerClippingMask: Bool {
        guard let index = document.selectedLayerIndex else { return false }
        let layer = document.layers[index]
        guard !layer.isGroup, !document.isEffectivelyLocked(layer) else { return false }
        if layer.isClippingMask { return true }
        return clippingBaseExists(below: index, groupID: layer.groupID)
    }

    var canCreateClippingMasksForSelectedLayers: Bool {
        !selectedLayerClippingCreationIndices().isEmpty
    }

    var canReleaseSelectedClippingMasks: Bool {
        !selectedLayerClippingReleaseIndices().isEmpty
    }

    var canAddSmartFilterToSelectedLayer: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        return !layer.isGroup && !layer.isAdjustment && !layer.isFilter
    }

    var canConvertSelectedLayerToSmartObject: Bool {
        smartObjectConversionCandidate() != nil
    }

    var canReplaceSelectedSmartObjectContents: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              layer.isSmartObject,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        return true
    }

    var canResetSelectedSmartObjectTransform: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              layer.isSmartObject,
              !document.isEffectivelyPositionLocked(layer)
        else { return false }
        return true
    }

    var canMakeSelectedSmartObjectUnique: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              let content = layer.smartObjectContent,
              !document.isEffectivelyPixelsLocked(layer)
        else { return false }
        return document.layers.contains { otherLayer in
            otherLayer.id != layer.id && otherLayer.smartObjectContent?.sourceID == content.sourceID
        }
    }

    var colorText: String {
        let color = foregroundColor.usingColorSpace(.deviceRGB) ?? foregroundColor
        return "R \(Int((color.redComponent * 255).rounded()))  G \(Int((color.greenComponent * 255).rounded()))  B \(Int((color.blueComponent * 255).rounded()))"
    }

    func selectTool(_ tool: ImageEditorTool) {
        selectedTool = tool
        if !tool.isImplemented {
            statusText = L10n.text("imageEditor.status.toolSoon")
        } else if tool == .pen, pendingPenPathPoints.isEmpty {
            statusText = L10n.text("imageEditor.status.penReady")
        } else {
            updateStatus()
        }
    }

    func zoomIn() {
        zoom = min(zoom * 1.2, 8)
    }

    func zoomOut() {
        zoom = max(zoom / 1.2, 0.08)
    }

    func fitZoom() {
        zoom = 1
        canvasOffset = .zero
    }

    func nudgeCanvas(by translation: CGSize) {
        canvasOffset.width += translation.width
        canvasOffset.height += translation.height
    }

    func updatePointer(_ point: CGPoint?) {
        guard let point else {
            pointerText = "X: 0 Y: 0"
            return
        }
        pointerText = "X: \(Int(point.x.rounded())) Y: \(Int(point.y.rounded()))"
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(document)
        document = previous
        ensureSelectedLayer()
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        syncShapeControlsFromSelection()
        updateStatus()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(document)
        document = next
        ensureSelectedLayer()
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        syncShapeControlsFromSelection()
        updateStatus()
    }

    func restoreHistoryEntry(_ id: UUID) {
        guard let snapshot = historySnapshots[id],
              document.history.last?.id != id
        else { return }
        pushUndo()
        document = snapshot
        ensureSelectedLayer()
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        syncShapeControlsFromSelection()
        appendHistory(L10n.text("imageEditor.history.revert"))
    }

    func createHistorySnapshot() {
        let name = uniqueHistorySnapshotName(
            L10n.format("imageEditor.history.snapshotName", namedHistorySnapshots.count + 1)
        )
        namedHistorySnapshots.append(ImageEditorHistorySnapshot(name: name, document: document))
        statusText = L10n.format("imageEditor.status.historySnapshotCreated", name)
    }

    func renameHistorySnapshot(_ id: UUID, to proposedName: String) {
        guard let index = namedHistorySnapshots.firstIndex(where: { $0.id == id }) else { return }
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusText = L10n.text("imageEditor.status.historySnapshotNameInvalid")
            return
        }
        guard namedHistorySnapshots[index].name != trimmedName else { return }

        namedHistorySnapshots[index].name = uniqueHistorySnapshotName(trimmedName, excluding: id)
        statusText = L10n.format("imageEditor.status.historySnapshotRenamed", namedHistorySnapshots[index].name)
    }

    func restoreHistorySnapshot(_ id: UUID) {
        guard let snapshot = namedHistorySnapshots.first(where: { $0.id == id }) else { return }

        pushUndo()
        document = snapshot.document
        ensureSelectedLayer()
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        syncShapeControlsFromSelection()
        appendHistory(L10n.text("imageEditor.history.snapshotRestore"))
        statusText = L10n.format("imageEditor.status.historySnapshotRestored", snapshot.name)
    }

    func deleteHistorySnapshot(_ id: UUID) {
        guard let index = namedHistorySnapshots.firstIndex(where: { $0.id == id }) else { return }
        let name = namedHistorySnapshots[index].name
        namedHistorySnapshots.remove(at: index)
        statusText = L10n.format("imageEditor.status.historySnapshotDeleted", name)
    }

    func clearHistoryStates() {
        undoStack.removeAll()
        redoStack.removeAll()
        historySnapshots.removeAll()
        document.history = [
            ImageEditorHistoryEntry(title: L10n.text("imageEditor.history.currentState"))
        ]
        recordCurrentHistorySnapshot()
        updateStatus()
        statusText = L10n.text("imageEditor.status.historyCleared")
    }

    func applyAndClose(close: () -> Void) {
        onApply(document.compositedImage)
        close()
    }

    func clearSelection() {
        guard document.selection != nil else { return }
        pushUndo()
        document.selection = nil
        appendHistory(L10n.text("imageEditor.history.selectionCleared"))
    }

    func invertSelection() {
        guard document.selection != nil else { return }
        pushUndo()
        document.selection?.isInverted.toggle()
        appendHistory(L10n.text("imageEditor.history.selectionInverted"))
        statusText = L10n.text("imageEditor.status.selectionInverted")
    }

    func createRectSelection(from start: CGPoint, to end: CGPoint) {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ).intersection(CGRect(origin: .zero, size: document.canvasSize))
        guard rect.width > 2, rect.height > 2 else { return }
        applySelectionCandidate(.rectangle(rect), replaceHistoryKey: "imageEditor.history.selection")
    }

    func createLassoSelection(points: [CGPoint]) {
        let boundedPoints = points.filter { point in
            CGRect(origin: .zero, size: document.canvasSize).contains(point)
        }
        guard let selection = ImageEditorSelection.polygon(boundedPoints) else { return }
        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.selection")
    }

    func createMagicSelection(at point: CGPoint?) {
        guard let point,
              let selection = magicSelection(at: point)
        else { return }
        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.magicSelection")
    }

    func applySelectionCandidate(_ selection: ImageEditorSelection, replaceHistoryKey: String) {
        let existingSelection = document.selection
        guard existingSelection != nil || selectionMode == .replace || selectionMode == .add else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }

        let nextSelection = ImageEditorSelection.combined(
            current: existingSelection,
            candidate: selection,
            mode: selectionMode,
            canvasSize: document.canvasSize
        )

        pushUndo()
        document.selection = nextSelection
        let historyKey = selectionMode == .replace ? replaceHistoryKey : selectionMode.historyKey
        appendHistory(L10n.text(historyKey))
        statusText = nextSelection == nil
            ? L10n.text("imageEditor.status.selectionEmpty")
            : L10n.text("imageEditor.status.selectionCreated")
    }

    func isLayerSelected(_ id: UUID) -> Bool {
        document.selectedLayerIDs.contains(id)
    }

    func isPrimaryLayer(_ id: UUID) -> Bool {
        document.selectedLayerID == id
    }

    func selectLayer(_ id: UUID, editingMask: Bool = false, extendingSelection: Bool = false) {
        guard document.layers.contains(where: { $0.id == id }) else { return }
        if extendingSelection && !editingMask {
            if document.selectedLayerIDs.contains(id), document.selectedLayerIDs.count > 1 {
                document.selectedLayerIDs.remove(id)
                if document.selectedLayerID == id {
                    document.selectedLayerID = topmostSelectedLayerID()
                }
            } else {
                document.selectedLayerIDs.insert(id)
                document.selectedLayerID = id
            }
            isEditingLayerMask = false
            syncAdjustmentControlsFromSelection()
            syncFilterControlsFromSelection()
            syncTextControlsFromSelection()
            syncShapeControlsFromSelection()
            syncPathControlsFromSelection()
            return
        }

        document.selectedLayerID = id
        document.selectedLayerIDs = [id]
        isEditingLayerMask = editingMask && (document.selectedLayer?.mask != nil)
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        syncShapeControlsFromSelection()
        syncPathControlsFromSelection()
    }

    func selectAllLayers() {
        let layerIDs = Set(document.layers.map(\.id))
        guard document.selectedLayerIDs != layerIDs else { return }
        document.selectedLayerIDs = layerIDs
        document.selectedLayerID = topmostSelectedLayerID()
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
        statusText = L10n.format("imageEditor.status.layerSelectAll", layerIDs.count)
    }

    func clearLayerSelection() {
        guard !document.selectedLayerIDs.isEmpty || document.selectedLayerID != nil else { return }
        document.selectedLayerID = nil
        document.selectedLayerIDs = []
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
        statusText = L10n.text("imageEditor.status.layerSelectionCleared")
    }

    func invertLayerSelection() {
        let layerIDs = Set(document.layers.map(\.id))
        guard !layerIDs.isEmpty else { return }
        document.selectedLayerIDs = layerIDs.subtracting(document.selectedLayerIDs)
        document.selectedLayerID = topmostSelectedLayerID()
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
        statusText = document.selectedLayerIDs.isEmpty
            ? L10n.text("imageEditor.status.layerSelectionCleared")
            : L10n.format("imageEditor.status.layerSelectionInverted", document.selectedLayerIDs.count)
    }

    func addLayer() {
        pushUndo()
        let layerNumber = document.layers.count
        var layer = ImageEditorLayer.blank(
            name: L10n.format("imageEditor.layer.newName", layerNumber),
            size: document.canvasSize
        )
        let insertionContext = newLayerInsertionContext()
        layer.groupID = insertionContext.parentGroupID
        document.layers.insert(layer, at: insertionContext.index)
        expandGroupIfNeeded(insertionContext.parentGroupID)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerNew"))
    }

    var canConvertBackgroundToLayer: Bool {
        guard let index = document.selectedLayerIndex else { return false }
        return isBackgroundLayer(at: index)
    }

    var canConvertSelectedLayerToBackground: Bool {
        guard selectedLayerCount == 1,
              let index = document.selectedLayerIndex,
              !isBackgroundLayer(at: index)
        else { return false }
        let layer = document.layers[index]
        return !layer.isGroup && !layer.isAdjustment && !layer.isFilter
    }

    func convertBackgroundToLayer() {
        guard canConvertBackgroundToLayer,
              let index = document.selectedLayerIndex
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].name = L10n.text("imageEditor.layer.unlockedBackground")
        document.layers[index].isLocked = false
        document.layers[index].locksPixels = false
        document.layers[index].locksPosition = false
        document.layers[index].locksTransparentPixels = false
        document.selectedLayerID = document.layers[index].id
        document.selectedLayerIDs = [document.layers[index].id]
        isEditingLayerMask = false
        statusText = L10n.text("imageEditor.status.layerFromBackground")
        appendHistory(L10n.text("imageEditor.history.layerFromBackground"))
    }

    func convertSelectedLayerToBackground() {
        guard canConvertSelectedLayerToBackground,
              let index = document.selectedLayerIndex,
              let backgroundImage = backgroundImage(from: document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        var backgroundLayer = ImageEditorLayer.background(image: backgroundImage)
        backgroundLayer.id = document.layers[index].id
        backgroundLayer.linkedLayerIDs = []
        backgroundLayer.labelColor = document.layers[index].labelColor
        document.layers.remove(at: index)
        document.layers.insert(backgroundLayer, at: 0)
        normalizeClippingMasks()
        document.selectedLayerID = backgroundLayer.id
        document.selectedLayerIDs = [backgroundLayer.id]
        isEditingLayerMask = false
        statusText = L10n.text("imageEditor.status.backgroundFromLayer")
        appendHistory(L10n.text("imageEditor.history.backgroundFromLayer"))
    }

    func addLayerGroup() {
        pushUndo()
        let groupNumber = document.layers.filter(\.isGroup).count + 1
        var group = ImageEditorLayer.group(
            name: L10n.format("imageEditor.layer.groupName", groupNumber),
            size: document.canvasSize
        )
        let insertionContext = newLayerInsertionContext()
        group.groupID = insertionContext.parentGroupID
        document.layers.insert(group, at: insertionContext.index)
        expandGroupIfNeeded(insertionContext.parentGroupID)
        document.selectedLayerID = group.id
        document.selectedLayerIDs = [group.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerGroupNew"))
    }

    func groupSelectedLayer() {
        let indices = selectedLayerIndices
        guard canGroupSelectedLayer, let insertionIndex = indices.last else { return }
        pushUndo()
        let groupNumber = document.layers.filter(\.isGroup).count + 1
        var group = ImageEditorLayer.group(
            name: L10n.format("imageEditor.layer.groupName", groupNumber),
            size: document.canvasSize
        )
        group.groupID = document.layers[indices[0]].groupID
        for index in indices {
            document.layers[index].groupID = group.id
        }
        document.layers.insert(group, at: insertionIndex + 1)
        normalizeClippingMasks()
        document.selectedLayerID = group.id
        document.selectedLayerIDs = [group.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerGroupSelected"))
    }

    func selectSelectedGroupMembers() {
        guard canSelectSelectedGroupMembers,
              let groupID = document.selectedLayerID
        else {
            statusText = L10n.text("imageEditor.status.layerGroupEmpty")
            return
        }
        let memberIDs = Set(groupDescendantIndices(for: groupID).map { document.layers[$0].id })
        guard !memberIDs.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerGroupEmpty")
            return
        }
        document.selectedLayerIDs = memberIDs
        document.selectedLayerID = document.layers.reversed().first { memberIDs.contains($0.id) }?.id
        isEditingLayerMask = false
        updateStatus()
    }

    func moveSelectedLayersIntoGroup() {
        guard let targetGroupID = groupTargetForMovingSelectionIntoGroup() else {
            statusText = L10n.text("imageEditor.status.layerGroupTargetMissing")
            return
        }
        let indices = movableSelectedLayerIndicesForHierarchyChange()
        guard !indices.isEmpty else { return }
        pushUndo()
        for index in indices {
            document.layers[index].groupID = targetGroupID
        }
        if let targetIndex = document.layers.firstIndex(where: { $0.id == targetGroupID }) {
            document.layers[targetIndex].isGroupExpanded = true
        }
        normalizeClippingMasks()
        document.selectedLayerID = document.layers.reversed().first { document.selectedLayerIDs.contains($0.id) }?.id
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMoveIntoGroup"))
    }

    func moveSelectedLayersOutOfGroup() {
        let indices = movableSelectedLayerIndicesForHierarchyChange()
        guard !indices.isEmpty,
              indices.allSatisfy({ document.layers[$0].groupID != nil })
        else {
            statusText = L10n.text("imageEditor.status.layerNotInGroup")
            return
        }
        let replacementParents: [UUID: UUID?] = Dictionary(uniqueKeysWithValues: indices.map { index in
            let layer = document.layers[index]
            let replacementParentID = layer.groupID.flatMap { parentID in
                document.layers.first { $0.id == parentID && $0.isGroup }?.groupID
            }
            return (layer.id, replacementParentID)
        })

        pushUndo()
        for index in indices {
            let layerID = document.layers[index].id
            document.layers[index].groupID = replacementParents[layerID] ?? nil
        }
        normalizeClippingMasks()
        document.selectedLayerID = document.layers.reversed().first { document.selectedLayerIDs.contains($0.id) }?.id
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMoveOutOfGroup"))
    }

    func layerDragSourceIDs(for layerID: UUID) -> Set<UUID> {
        guard document.layers.contains(where: { $0.id == layerID }) else { return [] }
        if document.selectedLayerIDs.contains(layerID) {
            return document.selectedLayerIDs
        }
        return [layerID]
    }

    @discardableResult
    func moveLayerIDs(_ sourceIDs: Set<UUID>, toDropTarget target: ImageEditorLayerDropTarget) -> Bool {
        guard let targetLayer = document.layers.first(where: { $0.id == target.layerID }) else { return false }
        guard target.placement != .insideGroup || targetLayer.isGroup else { return false }

        let rootSourceIDs = movableRootLayerIDs(for: sourceIDs)
        guard !rootSourceIDs.isEmpty else { return false }

        let movingBlockIDs = movingLayerBlockIDs(for: rootSourceIDs)
        guard !movingBlockIDs.contains(target.layerID) else { return false }

        let nextParentID: UUID? = target.placement == .insideGroup ? target.layerID : targetLayer.groupID
        guard canMoveLayerRoots(rootSourceIDs, toParent: nextParentID) else { return false }

        var movingLayers = document.layers.filter { movingBlockIDs.contains($0.id) }
        for index in movingLayers.indices where rootSourceIDs.contains(movingLayers[index].id) {
            movingLayers[index].groupID = nextParentID
        }

        var remainingLayers = document.layers.filter { !movingBlockIDs.contains($0.id) }
        guard let targetIndex = remainingLayers.firstIndex(where: { $0.id == target.layerID }) else { return false }
        let insertionIndex: Int
        switch target.placement {
        case .above:
            insertionIndex = targetIndex + 1
        case .below, .insideGroup:
            insertionIndex = targetIndex
        }

        guard wouldChangeLayerOrderOrParent(movingLayers, remainingLayers: remainingLayers, insertionIndex: insertionIndex) else {
            return false
        }

        pushUndo()
        remainingLayers.insert(contentsOf: movingLayers, at: insertionIndex)
        document.layers = remainingLayers
        expandGroupIfNeeded(nextParentID)
        normalizeClippingMasks()

        let retainedSelectionIDs = sourceIDs.intersection(movingBlockIDs)
        document.selectedLayerIDs = retainedSelectionIDs.isEmpty ? rootSourceIDs : retainedSelectionIDs
        if let selectedLayerID = document.selectedLayerID,
           document.selectedLayerIDs.contains(selectedLayerID) {
            // Keep the primary selection when it moved with the dragged block.
        } else {
            document.selectedLayerID = document.layers.reversed().first { document.selectedLayerIDs.contains($0.id) }?.id
        }
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerReorder"))
        statusText = L10n.text("imageEditor.status.layerReordered")
        return true
    }

    func ungroupSelectedLayers() {
        let groupIDs = selectedUnlockedGroupIDs()
        guard !groupIDs.isEmpty else { return }
        pushUndo()
        let memberIDs = Set(document.layers.filter { layer in
            layer.groupID.map(groupIDs.contains) == true
        }.map(\.id))
        let replacementParents = groupReplacementParents(forRemoving: groupIDs)
        for index in document.layers.indices {
            guard let groupID = document.layers[index].groupID,
                  groupIDs.contains(groupID)
            else { continue }
            document.layers[index].groupID = replacementParents[groupID] ?? nil
        }
        document.layers.removeAll { groupIDs.contains($0.id) }
        normalizeLayerLinks()
        normalizeClippingMasks()
        document.selectedLayerIDs = memberIDs
        document.selectedLayerID = document.layers.reversed().first { memberIDs.contains($0.id) }?.id ?? document.layers.last?.id
        if document.selectedLayerIDs.isEmpty, let selectedLayerID = document.selectedLayerID {
            document.selectedLayerIDs = [selectedLayerID]
        }
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerUngroup"))
    }

    func duplicateSelectedLayer() {
        let sourceIndices = duplicateSourceLayerIndices()
        guard !sourceIndices.isEmpty else { return }
        pushUndo()
        var duplicatedLayers: [ImageEditorLayer] = []
        var duplicatedIDs: [UUID] = []
        var idMap: [UUID: UUID] = [:]
        let selectedGroupIDs = Set(selectedLayerIndices.compactMap { index in
            let layer = document.layers[index]
            return layer.isGroup ? layer.id : nil
        })

        for index in sourceIndices {
            let originalLayer = document.layers[index]
            var layer = originalLayer
            layer.id = UUID()
            layer.linkedLayerIDs = []
            layer.name = L10n.format("imageEditor.layer.copyName", layer.name)
            if layer.isGroup {
                idMap[originalLayer.id] = layer.id
            }
            duplicatedIDs.append(layer.id)
            duplicatedLayers.append(layer)
        }

        for index in duplicatedLayers.indices {
            if let groupID = duplicatedLayers[index].groupID,
               (selectedGroupIDs.contains(groupID) || idMap[groupID] != nil),
               let duplicatedGroupID = idMap[groupID] {
                duplicatedLayers[index].groupID = duplicatedGroupID
            }
        }

        let insertionIndex = min((sourceIndices.last ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(contentsOf: duplicatedLayers, at: insertionIndex)
        let duplicatedIDSet = Set(duplicatedIDs)
        document.selectedLayerID = duplicatedLayers.reversed().first { duplicatedIDSet.contains($0.id) }?.id
        document.selectedLayerIDs = duplicatedIDSet
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerDuplicate"))
    }

    func convertSelectedLayerToSmartObject() {
        guard let plan = smartObjectConversionPlan()
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers.removeAll { plan.removedLayerIDs.contains($0.id) }
        let insertionIndex = min(plan.insertionIndex, document.layers.count)
        document.layers.insert(plan.replacementLayer, at: insertionIndex)
        normalizeLayerLinks()
        normalizeClippingMasks()
        document.selectedLayerID = plan.replacementLayer.id
        document.selectedLayerIDs = [plan.replacementLayer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerSmartObject"))
        statusText = L10n.text("imageEditor.status.layerSmartObject")
    }

    func resetSelectedSmartObjectTransform() {
        guard canResetSelectedSmartObjectTransform,
              let index = document.selectedLayerIndex,
              let content = document.layers[index].smartObjectContent
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let currentFrame = document.layers[index].frame.standardized
        let resetSize = CGSize(
            width: max(1, content.originalSize.width),
            height: max(1, content.originalSize.height)
        )
        let resetFrame = CGRect(
            x: currentFrame.midX - resetSize.width / 2,
            y: currentFrame.midY - resetSize.height / 2,
            width: resetSize.width,
            height: resetSize.height
        )

        pushUndo()
        document.layers[index].frame = resetFrame
        appendHistory(L10n.text("imageEditor.history.layerSmartObjectResetTransform"))
        statusText = L10n.text("imageEditor.status.layerSmartObjectTransformReset")
    }

    func makeSelectedSmartObjectUnique() {
        guard canMakeSelectedSmartObjectUnique,
              let index = document.selectedLayerIndex,
              let content = document.layers[index].smartObjectContent
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].kind = .smartObject(
            ImageEditorSmartObjectContent(
                sourceName: content.sourceName,
                originalSize: content.originalSize,
                sourceID: UUID()
            )
        )
        appendHistory(L10n.text("imageEditor.history.layerSmartObjectMakeUnique"))
        statusText = L10n.text("imageEditor.status.layerSmartObjectMadeUnique")
    }

    func renameSelectedLayer(to proposedName: String) {
        guard let index = document.selectedLayerIndex else { return }
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerNameInvalid")
            return
        }
        guard document.layers[index].name != trimmedName else { return }
        pushUndo()
        document.layers[index].name = trimmedName
        appendHistory(L10n.text("imageEditor.history.layerRename"))
        statusText = L10n.text("imageEditor.status.layerRenamed")
    }

    func deleteSelectedLayer() {
        let deletionIDs = deletionIDsForCurrentSelection()
        guard canDeleteLayer, !deletionIDs.isEmpty else { return }
        let fallbackIndex = document.selectedLayerIndex ?? 0
        pushUndo()
        document.layers.removeAll { deletionIDs.contains($0.id) }
        normalizeLayerLinks()
        normalizeClippingMasks()
        let nextIndex = min(max(0, fallbackIndex - 1), max(0, document.layers.count - 1))
        document.selectedLayerID = document.layers.indices.contains(nextIndex)
            ? document.layers[nextIndex].id
            : document.layers.last?.id
        document.selectedLayerIDs = document.selectedLayerID.map { Set([$0]) } ?? []
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerDelete"))
    }

    func moveSelectedLayerUp() {
        moveSelectedLayers(direction: 1)
    }

    func moveSelectedLayerDown() {
        moveSelectedLayers(direction: -1)
    }

    func moveSelectedLayerToTop() {
        moveSelectedLayers(to: .top)
    }

    func moveSelectedLayerToBottom() {
        moveSelectedLayers(to: .bottom)
    }

    func toggleLayerVisibility(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        document.layers[index].isVisible.toggle()
        appendHistory(L10n.text("imageEditor.history.layerVisibility"))
    }

    func isolateSelectedLayers() {
        let visibleIDs = isolatedLayerVisibilityIDs()
        guard !visibleIDs.isEmpty, canIsolateSelectedLayers else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        for index in document.layers.indices {
            document.layers[index].isVisible = visibleIDs.contains(document.layers[index].id)
        }
        appendHistory(L10n.text("imageEditor.history.layerIsolateSelected"))
        statusText = L10n.format("imageEditor.status.layerIsolateSelected", selectedLayerCount)
    }

    func showAllLayers() {
        guard canShowAllLayers else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        for index in document.layers.indices {
            document.layers[index].isVisible = true
        }
        appendHistory(L10n.text("imageEditor.history.layerShowAll"))
        statusText = L10n.text("imageEditor.status.layerShowAll")
    }

    func toggleLayerGroupExpansion(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }),
              document.layers[index].isGroup
        else { return }
        document.layers[index].isGroupExpanded.toggle()
        if !document.layers[index].isGroupExpanded {
            let memberIDs = Set(groupDescendantIndices(for: id).map { document.layers[$0].id })
            if !document.selectedLayerIDs.isDisjoint(with: memberIDs) {
                document.selectedLayerID = id
                document.selectedLayerIDs = [id]
                isEditingLayerMask = false
            }
        }
    }

    func toggleLayerLock(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        document.layers[index].isLocked.toggle()
        if document.layers[index].isLocked, document.layers[index].id == document.selectedLayerID {
            isEditingLayerMask = false
        }
        appendHistory(L10n.text("imageEditor.history.layerLock"))
    }

    var canLockSelectedLayers: Bool {
        selectedLayerIndices.contains { !document.layers[$0].isLocked }
    }

    var canUnlockSelectedLayers: Bool {
        selectedLayerIndices.contains { index in
            let layer = document.layers[index]
            return layer.isLocked || layer.locksPixels || layer.locksPosition || layer.locksTransparentPixels
        }
    }

    var canLockSelectedLayerPixels: Bool {
        selectedLayerIndices.contains { canTogglePixelsLock(for: document.layers[$0]) && !document.layers[$0].locksPixels }
    }

    var canUnlockSelectedLayerPixels: Bool {
        selectedLayerIndices.contains { canTogglePixelsLock(for: document.layers[$0]) && document.layers[$0].locksPixels }
    }

    var canLockSelectedLayerPosition: Bool {
        selectedLayerIndices.contains { canTogglePositionLock(for: document.layers[$0]) && !document.layers[$0].locksPosition }
    }

    var canUnlockSelectedLayerPosition: Bool {
        selectedLayerIndices.contains { canTogglePositionLock(for: document.layers[$0]) && document.layers[$0].locksPosition }
    }

    var canLockSelectedLayerTransparentPixels: Bool {
        selectedLayerIndices.contains {
            canToggleTransparentPixelsLock(for: document.layers[$0]) && !document.layers[$0].locksTransparentPixels
        }
    }

    var canUnlockSelectedLayerTransparentPixels: Bool {
        selectedLayerIndices.contains {
            canToggleTransparentPixelsLock(for: document.layers[$0]) && document.layers[$0].locksTransparentPixels
        }
    }

    func lockSelectedLayers() {
        setSelectedLayerLocks(
            fullLock: true,
            historyKey: "imageEditor.history.layerLockSelected",
            statusKey: "imageEditor.status.layerLockSelected"
        )
    }

    func unlockSelectedLayers() {
        let indices = selectedLayerIndices.filter { index in
            let layer = document.layers[index]
            return layer.isLocked || layer.locksPixels || layer.locksPosition || layer.locksTransparentPixels
        }
        guard !indices.isEmpty else { return }

        pushUndo()
        for index in indices {
            document.layers[index].isLocked = false
            document.layers[index].locksPixels = false
            document.layers[index].locksPosition = false
            document.layers[index].locksTransparentPixels = false
        }
        appendHistory(L10n.text("imageEditor.history.layerUnlockSelected"))
        statusText = L10n.text("imageEditor.status.layerUnlockSelected")
    }

    func lockSelectedLayerPixels() {
        setSelectedLayerLocks(
            pixels: true,
            historyKey: "imageEditor.history.layerPixelsLockSelected",
            statusKey: "imageEditor.status.layerPixelsLockSelected"
        )
    }

    func unlockSelectedLayerPixels() {
        setSelectedLayerLocks(
            pixels: false,
            historyKey: "imageEditor.history.layerPixelsUnlockSelected",
            statusKey: "imageEditor.status.layerPixelsUnlockSelected"
        )
    }

    func lockSelectedLayerPosition() {
        setSelectedLayerLocks(
            position: true,
            historyKey: "imageEditor.history.layerPositionLockSelected",
            statusKey: "imageEditor.status.layerPositionLockSelected"
        )
    }

    func unlockSelectedLayerPosition() {
        setSelectedLayerLocks(
            position: false,
            historyKey: "imageEditor.history.layerPositionUnlockSelected",
            statusKey: "imageEditor.status.layerPositionUnlockSelected"
        )
    }

    func lockSelectedLayerTransparentPixels() {
        setSelectedLayerLocks(
            transparentPixels: true,
            historyKey: "imageEditor.history.layerTransparentPixelsLockSelected",
            statusKey: "imageEditor.status.layerTransparentPixelsLockSelected"
        )
    }

    func unlockSelectedLayerTransparentPixels() {
        setSelectedLayerLocks(
            transparentPixels: false,
            historyKey: "imageEditor.history.layerTransparentPixelsUnlockSelected",
            statusKey: "imageEditor.status.layerTransparentPixelsUnlockSelected"
        )
    }

    func toggleLayerTransparentPixelsLock(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        guard canToggleTransparentPixelsLock(for: document.layers[index]) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].locksTransparentPixels.toggle()
        appendHistory(L10n.text("imageEditor.history.layerTransparentPixelsLock"))
    }

    func toggleLayerPixelsLock(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        guard canTogglePixelsLock(for: document.layers[index]) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].locksPixels.toggle()
        appendHistory(L10n.text("imageEditor.history.layerPixelsLock"))
    }

    func toggleLayerPositionLock(_ id: UUID) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        guard canTogglePositionLock(for: document.layers[index]) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].locksPosition.toggle()
        appendHistory(L10n.text("imageEditor.history.layerPositionLock"))
    }

    func setSelectedLayersLabelColor(_ labelColor: ImageEditorLayerLabelColor?) {
        let indices = selectedLayerIndices
        guard !indices.isEmpty,
              indices.contains(where: { document.layers[$0].labelColor != labelColor })
        else { return }

        pushUndo()
        for index in indices {
            document.layers[index].labelColor = labelColor
        }
        appendHistory(L10n.text("imageEditor.history.layerLabelColor"))
        statusText = labelColor.map { L10n.format("imageEditor.status.layerLabelColor", $0.title) }
            ?? L10n.text("imageEditor.status.layerLabelColorCleared")
    }

    func setSelectedLayerOpacity(_ opacity: Double) {
        guard let index = document.selectedLayerIndex,
              !document.isEffectivelyLocked(document.layers[index])
        else { return }
        document.layers[index].opacity = max(0, min(1, opacity))
        updateStatus()
    }

    func setSelectedLayerFillOpacity(_ fillOpacity: Double) {
        guard let index = document.selectedLayerIndex,
              canSetLayerFillOpacity(document.layers[index])
        else { return }
        document.layers[index].fillOpacity = max(0, min(1, fillOpacity))
        updateStatus()
    }

    func setSelectedLayerBlendIfSourceBlack(_ value: Double) {
        guard let index = document.selectedLayerIndex,
              canSetLayerBlendIf(document.layers[index])
        else { return }
        let white = document.layers[index].blendIfSourceWhite
        document.layers[index].blendIfSourceBlack = min(max(0, value), white)
        updateStatus()
    }

    func setSelectedLayerBlendIfSourceWhite(_ value: Double) {
        guard let index = document.selectedLayerIndex,
              canSetLayerBlendIf(document.layers[index])
        else { return }
        let black = document.layers[index].blendIfSourceBlack
        document.layers[index].blendIfSourceWhite = max(black, min(1, value))
        updateStatus()
    }

    func setSelectedLayerBlendIfUnderlyingBlack(_ value: Double) {
        guard let index = document.selectedLayerIndex,
              canSetLayerBlendIf(document.layers[index])
        else { return }
        let white = document.layers[index].blendIfUnderlyingWhite
        document.layers[index].blendIfUnderlyingBlack = min(max(0, value), white)
        updateStatus()
    }

    func setSelectedLayerBlendIfUnderlyingWhite(_ value: Double) {
        guard let index = document.selectedLayerIndex,
              canSetLayerBlendIf(document.layers[index])
        else { return }
        let black = document.layers[index].blendIfUnderlyingBlack
        document.layers[index].blendIfUnderlyingWhite = max(black, min(1, value))
        updateStatus()
    }

    func setSelectedLayerMaskDensity(_ density: Double) {
        guard let index = document.selectedLayerIndex,
              canEditSelectedLayerMaskProperties
        else { return }
        document.layers[index].maskDensity = max(0, min(1, density))
        updateStatus()
    }

    func setSelectedLayerMaskFeather(_ feather: Double) {
        guard let index = document.selectedLayerIndex,
              canEditSelectedLayerMaskProperties
        else { return }
        document.layers[index].maskFeather = max(0, min(80, feather))
        updateStatus()
    }

    func setSelectedLayerBlendMode(_ blendMode: ImageEditorBlendMode) {
        guard let index = document.selectedLayerIndex,
              !document.layers[index].isAdjustment,
              !document.layers[index].isFilter,
              !document.isEffectivelyLocked(document.layers[index]),
              document.layers[index].isGroup || blendMode != .passThrough,
              document.layers[index].blendMode != blendMode
        else { return }
        pushUndo()
        document.layers[index].blendMode = blendMode
        appendHistory(L10n.text("imageEditor.history.layerBlendMode"))
    }

    func commitSelectedLayerOpacityChange() {
        appendHistory(L10n.text("imageEditor.history.layerOpacity"))
    }

    func commitSelectedLayerFillOpacityChange() {
        appendHistory(L10n.text("imageEditor.history.layerFillOpacity"))
    }

    func commitSelectedLayerBlendIfChange() {
        appendHistory(L10n.text("imageEditor.history.layerBlendIf"))
    }

    func commitSelectedLayerMaskDensityChange() {
        appendHistory(L10n.text("imageEditor.history.layerMaskDensity"))
    }

    func commitSelectedLayerMaskFeatherChange() {
        appendHistory(L10n.text("imageEditor.history.layerMaskFeather"))
    }

    func toggleSelectedLayerClippingMask() {
        guard let index = document.selectedLayerIndex else { return }
        guard canToggleSelectedLayerClippingMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].isClippingMask.toggle()
        appendHistory(L10n.text("imageEditor.history.layerClippingMask"))
    }

    func createClippingMasksForSelectedLayers() {
        let indices = selectedLayerClippingCreationIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        for index in indices {
            document.layers[index].isClippingMask = true
        }
        normalizeClippingMasks()
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerClippingMaskCreateSelected"))
        statusText = L10n.format("imageEditor.status.layerClippingMaskCreatedSelected", indices.count)
    }

    func releaseSelectedClippingMasks() {
        let indices = selectedLayerClippingReleaseIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        for index in indices {
            document.layers[index].isClippingMask = false
        }
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerClippingMaskReleaseSelected"))
        statusText = L10n.format("imageEditor.status.layerClippingMaskReleasedSelected", indices.count)
    }

    func mergeSelectedLayerDown() {
        guard canMergeSelectedLayerDown, let index = document.selectedLayerIndex else { return }
        pushUndo()
        if document.layers[index].isAdjustment {
            guard let merged = mergedAdjustmentLayer(lowerIndex: index - 1, adjustmentIndex: index) else { return }
            document.layers[index - 1] = merged
            document.layers.remove(at: index)
            normalizeClippingMasks()
            document.selectedLayerID = merged.id
            document.selectedLayerIDs = [merged.id]
            isEditingLayerMask = false
            appendHistory(L10n.text("imageEditor.history.layerMergeDown"))
            return
        }
        if document.layers[index].isFilter {
            guard let merged = mergedFilterLayer(lowerIndex: index - 1, filterIndex: index) else { return }
            document.layers[index - 1] = merged
            document.layers.remove(at: index)
            normalizeClippingMasks()
            document.selectedLayerID = merged.id
            document.selectedLayerIDs = [merged.id]
            isEditingLayerMask = false
            appendHistory(L10n.text("imageEditor.history.layerMergeDown"))
            return
        }
        guard let merged = mergedLayer(lowerIndex: index - 1, upperIndex: index) else { return }
        document.layers[index - 1] = merged
        document.layers.remove(at: index)
        normalizeClippingMasks()
        document.selectedLayerID = merged.id
        document.selectedLayerIDs = [merged.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMergeDown"))
    }

    func stampVisibleLayers() {
        guard canStampVisibleLayers else { return }
        pushUndo()
        var layer = ImageEditorLayer.blank(
            name: L10n.text("imageEditor.layer.visibleStampName"),
            size: document.canvasSize
        )
        layer.image = document.compositedImage
        layer.frame = CGRect(origin: .zero, size: document.canvasSize)
        layer.opacity = 1
        layer.fillOpacity = 1
        layer.blendMode = .normal
        layer.groupID = nil
        layer.isClippingMask = false
        document.layers.append(layer)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerStampVisible"))
    }

    func addLayerMask() {
        guard canAddLayerMask, let index = document.selectedLayerIndex else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        document.layers[index].mask = NSImage.opaqueMask(size: maskSize(for: document.layers[index]))
        document.layers[index].isMaskEnabled = true
        document.layers[index].isMaskLinked = true
        document.layers[index].isVectorMaskEnabled = true
        document.layers[index].maskDensity = 1
        document.layers[index].maskFeather = 0
        isEditingLayerMask = true
        appendHistory(L10n.text("imageEditor.history.layerMaskAdd"))
    }

    func deleteLayerMask() {
        guard canDeleteLayerMask, let index = document.selectedLayerIndex else { return }
        pushUndo()
        document.layers[index].mask = nil
        document.layers[index].isMaskEnabled = true
        document.layers[index].isMaskLinked = true
        document.layers[index].maskDensity = 1
        document.layers[index].maskFeather = 0
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMaskDelete"))
    }

    func editLayerPixels() {
        isEditingLayerMask = false
        statusText = L10n.text("imageEditor.status.editingLayer")
    }

    func editLayerMask() {
        guard selectedLayerHasMask else {
            statusText = L10n.text("imageEditor.status.noLayerMask")
            return
        }
        isEditingLayerMask = true
        statusText = L10n.text("imageEditor.status.editingMask")
    }

    func rotateClockwise() {
        transformCanvas(historyTitle: L10n.text("imageEditor.history.rotate")) { layer, canvasSize in
            guard let rotated = layer.image.rotatedClockwise() else { return nil }
            var output = layer
            output.image = rotated
            output.frame = CGRect(
                x: canvasSize.height - layer.frame.maxY,
                y: layer.frame.minX,
                width: layer.frame.height,
                height: layer.frame.width
            )
            if let mask = layer.mask {
                output.mask = mask.rotatedClockwise()
            }
            return output
        } canvasSize: { size in
            CGSize(width: size.height, height: size.width)
        }
    }

    func flipHorizontal() {
        transformCanvas(historyTitle: L10n.text("imageEditor.history.flipHorizontal")) { layer, canvasSize in
            guard let flipped = layer.image.flipped(horizontal: true) else { return nil }
            var output = layer
            output.image = flipped
            output.frame = CGRect(
                x: canvasSize.width - layer.frame.maxX,
                y: layer.frame.minY,
                width: layer.frame.width,
                height: layer.frame.height
            )
            if let mask = layer.mask {
                output.mask = mask.flipped(horizontal: true)
            }
            return output
        } canvasSize: { $0 }
    }

    func flipVertical() {
        transformCanvas(historyTitle: L10n.text("imageEditor.history.flipVertical")) { layer, canvasSize in
            guard let flipped = layer.image.flipped(horizontal: false) else { return nil }
            var output = layer
            output.image = flipped
            output.frame = CGRect(
                x: layer.frame.minX,
                y: canvasSize.height - layer.frame.maxY,
                width: layer.frame.width,
                height: layer.frame.height
            )
            if let mask = layer.mask {
                output.mask = mask.flipped(horizontal: false)
            }
            return output
        } canvasSize: { $0 }
    }

    func addText(at point: CGPoint? = nil) {
        let text = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusText = L10n.text("imageEditor.status.textEmpty")
            return
        }
        let targetPoint = point ?? CGPoint(x: document.canvasSize.width * 0.12, y: document.canvasSize.height * 0.16)
        let content = ImageEditorTextContent(
            text: text,
            color: foregroundColor,
            fontSize: CGFloat(clampedTextSize(textSize)),
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            isBold: textBold,
            isItalic: textItalic,
            characterSpacing: CGFloat(clampedTextCharacterSpacing(textCharacterSpacing)),
            lineSpacing: CGFloat(clampedTextLineSpacing(textLineSpacing)),
            boxWidth: CGFloat(clampedTextBoxWidth(textBoxWidth)),
            alignment: selectedTextAlignment
        )
        pushUndo()
        var layer = ImageEditorLayer.text(
            name: L10n.format("imageEditor.layer.textName", textLayerNameFragment(text)),
            origin: targetPoint,
            content: content
        )
        layer.opacity = Double(opacity)
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerTextNew"))
    }

    func updateSelectedTextLayer() {
        let text = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusText = L10n.text("imageEditor.status.textEmpty")
            return
        }
        guard let index = document.selectedLayerIndex,
              var content = document.layers[index].textContent,
              !document.isEffectivelyPixelsLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        content.text = text
        content.color = foregroundColor
        content.fontSize = CGFloat(clampedTextSize(textSize))
        content.point = CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding)
        content.isBold = textBold
        content.isItalic = textItalic
        content.characterSpacing = CGFloat(clampedTextCharacterSpacing(textCharacterSpacing))
        content.lineSpacing = CGFloat(clampedTextLineSpacing(textLineSpacing))
        content.boxWidth = CGFloat(clampedTextBoxWidth(textBoxWidth))
        content.alignment = selectedTextAlignment
        let layerSize = content.layerSize()
        if let mask = document.layers[index].mask, mask.size != layerSize {
            document.layers[index].mask = mask.resized(to: layerSize)
        }
        document.layers[index].image = NSImage.transparent(size: layerSize)
        document.layers[index].frame.size = layerSize
        document.layers[index].kind = .text(content)
        document.layers[index].name = L10n.format("imageEditor.layer.textName", textLayerNameFragment(text))
        appendHistory(L10n.text("imageEditor.history.layerTextUpdate"))
    }

    func drawBrush(points: [CGPoint], erase: Bool = false) {
        guard points.count > 1 else { return }
        if isEditingLayerMask {
            paintSelectedLayerMask(points: points, reveal: erase)
            return
        }
        transformSelectedLayer(historyTitle: erase ? L10n.text("imageEditor.history.erase") : L10n.text("imageEditor.history.brush")) { image in
            image.withStroke(points: points, color: foregroundColor, width: brushSize, opacity: opacity, erase: erase)
        }
    }

    func setCloneSource(at point: CGPoint?) {
        cloneSourcePoint = point
        statusText = point == nil
            ? L10n.text("imageEditor.status.cloneSourceMissing")
            : L10n.text("imageEditor.status.cloneSourceSet")
    }

    func cloneStamp(points: [CGPoint]) {
        guard points.count > 1 else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let sourcePoint = cloneSourcePoint, let destinationStart = points.first else {
            statusText = L10n.text("imageEditor.status.cloneSourceMissing")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        let sourceOffset = CGSize(
            width: sourcePoint.x - destinationStart.x,
            height: sourcePoint.y - destinationStart.y
        )
        let sourceImage = layer.image.normalizedBitmapImage()
        guard let output = sourceImage.withCloneStamp(
            points: points,
            sourceOffset: sourceOffset,
            sourceImage: sourceImage,
            width: brushSize,
            opacity: opacity
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.cloneStamp"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.cloneStamped")
    }

    func toneBrush(points: [CGPoint], burn: Bool) {
        guard points.count > 1 else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let sourceImage = layer.image.normalizedBitmapImage()
        guard let output = sourceImage.withToneBrush(
            points: points,
            width: brushSize,
            opacity: opacity,
            burn: burn
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerPixels(
            output,
            historyTitle: burn ? L10n.text("imageEditor.history.burn") : L10n.text("imageEditor.history.dodge"),
            resetFrame: false
        )
        statusText = burn
            ? L10n.text("imageEditor.status.burnApplied")
            : L10n.text("imageEditor.status.dodgeApplied")
    }

    func blurBrush(points: [CGPoint]) {
        guard points.count > 1 else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let sourceImage = layer.image.normalizedBitmapImage()
        let radius = max(1, min(18, brushSize * 0.35))
        guard let output = sourceImage.withBlurBrush(
            points: points,
            width: brushSize,
            opacity: opacity,
            radius: radius
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.blur"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.blurApplied")
    }

    func sharpenBrush(points: [CGPoint]) {
        guard points.count > 1 else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let sourceImage = layer.image.normalizedBitmapImage()
        let intensity = max(0.35, min(1, opacity))
        guard let output = sourceImage.withSharpenBrush(
            points: points,
            width: brushSize,
            opacity: opacity,
            intensity: intensity
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.sharpen"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.sharpenApplied")
    }

    func smudgeBrush(points: [CGPoint]) {
        guard points.count > 1 else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let sourceImage = layer.image.normalizedBitmapImage()
        guard let output = sourceImage.withSmudgeBrush(
            points: points,
            width: brushSize,
            opacity: opacity
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.smudge"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.smudgeApplied")
    }

    func healingBrush(points: [CGPoint]) {
        guard points.count > 1 else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let sourceImage = layer.image.normalizedBitmapImage()
        guard let output = sourceImage.withHealingBrush(
            points: points,
            width: brushSize,
            opacity: opacity
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.healingBrush"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.healingApplied")
    }

    func paintBucketFill(at point: CGPoint?) {
        guard let point else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let sourceImage = layer.image.normalizedBitmapImage()
        guard let output = sourceImage.withPaintBucketFill(
            at: point,
            color: foregroundColor,
            opacity: opacity,
            tolerance: tolerance
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.paintBucket"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.paintBucketFilled")
    }

    func drawShape(from start: CGPoint, to end: CGPoint, ellipse: Bool) {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        guard rect.width > 3, rect.height > 3 else { return }
        addShapeLayer(frame: rect, kind: ellipse ? .ellipse : .rectangle)
    }

    func updateSelectedShapeLayer() {
        guard let index = document.selectedLayerIndex,
              var shapeContent = document.layers[index].shapeContent,
              !document.isEffectivelyPixelsLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        shapeContent.fillColor = foregroundColor
        shapeContent.fillOpacity = opacity
        shapeContent.strokeColor = foregroundColor
        shapeContent.strokeOpacity = min(1, max(0.15, opacity))
        shapeContent.strokeWidth = max(1, min(96, brushSize * 0.35))
        document.layers[index].kind = .shape(shapeContent.normalized(size: document.layers[index].image.size))
        document.layers[index].name = L10n.format("imageEditor.layer.shapeName", shapeContent.kind.title)
        appendHistory(L10n.text("imageEditor.history.layerShapeUpdate"))
    }

    func sampleColor(at point: CGPoint) {
        guard let color = document.compositedImage.color(at: point) else { return }
        foregroundColor = color
        statusText = L10n.text("imageEditor.status.colorSampled")
    }

    func applyAdjustment() {
        let title = selectedAdjustment.title
        guard let output = adjustedImage(
            kind: selectedAdjustment,
            amount: adjustmentValue,
            settings: currentAdjustmentSettings()
        ) else {
            statusText = L10n.text("imageEditor.status.adjustmentFailed")
            return
        }
        replaceSelectedLayerImage(output, historyTitle: title)
        resetAdjustmentControls()
    }

    func autoLevelsSelectedLayer() {
        guard canAutoLevelsSelectedLayer,
              let layer = editableSelectedLayer(),
              let output = layer.image.autoLeveled()
        else {
            statusText = L10n.text("imageEditor.status.adjustmentFailed")
            return
        }
        replaceSelectedLayerPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.autoLevels"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.autoLevels")
    }

    func autoContrastSelectedLayer() {
        guard canAutoContrastSelectedLayer,
              let layer = editableSelectedLayer(),
              let output = layer.image.autoContrasted()
        else {
            statusText = L10n.text("imageEditor.status.adjustmentFailed")
            return
        }
        replaceSelectedLayerPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.autoContrast"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.autoContrast")
    }

    func autoColorSelectedLayer() {
        guard canAutoColorSelectedLayer,
              let layer = editableSelectedLayer(),
              let output = layer.image.autoColored()
        else {
            statusText = L10n.text("imageEditor.status.adjustmentFailed")
            return
        }
        replaceSelectedLayerPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.autoColor"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.autoColor")
    }

    func addAdjustmentLayer() {
        pushUndo()
        let layer = ImageEditorLayer.adjustment(
            name: L10n.format("imageEditor.layer.adjustmentName", selectedAdjustment.title),
            size: document.canvasSize,
            kind: selectedAdjustment,
            amount: adjustmentValue,
            settings: currentAdjustmentSettings()
        )
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerAdjustmentNew"))
    }

    func updateSelectedAdjustmentLayer() {
        guard let index = document.selectedLayerIndex,
              document.layers[index].isAdjustment,
              !document.isEffectivelyPixelsLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].kind = .adjustment(selectedAdjustment, adjustmentValue)
        document.layers[index].adjustmentSettings = currentAdjustmentSettings()
        document.layers[index].name = L10n.format("imageEditor.layer.adjustmentName", selectedAdjustment.title)
        appendHistory(L10n.text("imageEditor.history.layerAdjustmentUpdate"))
    }

    func addFilterLayer() {
        pushUndo()
        let layer = ImageEditorLayer.filter(
            name: L10n.format("imageEditor.layer.filterName", selectedFilter.title),
            size: document.canvasSize,
            kind: selectedFilter,
            intensity: filterIntensity,
            settings: currentFilterSettings()
        )
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerFilterNew"))
    }

    func addSolidColorFillLayer() {
        pushUndo()
        let layer = ImageEditorLayer.solidColorFill(
            name: L10n.text("imageEditor.layer.solidColorFillName"),
            size: document.canvasSize,
            content: currentSolidColorFillContent()
        )
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerSolidColorFillNew"))
    }

    func updateSelectedSolidColorFillLayer() {
        guard let index = document.selectedLayerIndex,
              document.layers[index].isSolidColorFill,
              !document.isEffectivelyPixelsLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].kind = .solidColorFill(currentSolidColorFillContent())
        document.layers[index].name = L10n.text("imageEditor.layer.solidColorFillName")
        appendHistory(L10n.text("imageEditor.history.layerSolidColorFillUpdate"))
    }

    func addPatternFillLayer() {
        pushUndo()
        let layer = ImageEditorLayer.patternFill(
            name: L10n.text("imageEditor.layer.patternFillName"),
            size: document.canvasSize,
            content: currentPatternFillContent()
        )
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerPatternFillNew"))
    }

    func updateSelectedPatternFillLayer() {
        guard let index = document.selectedLayerIndex,
              document.layers[index].isPatternFill,
              !document.isEffectivelyPixelsLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].kind = .patternFill(currentPatternFillContent())
        document.layers[index].name = L10n.text("imageEditor.layer.patternFillName")
        appendHistory(L10n.text("imageEditor.history.layerPatternFillUpdate"))
    }

    func addGradientFillLayer() {
        pushUndo()
        let layer = ImageEditorLayer.gradientFill(
            name: L10n.text("imageEditor.layer.gradientFillName"),
            size: document.canvasSize,
            content: currentGradientFillContent()
        )
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerGradientFillNew"))
    }

    func updateSelectedGradientFillLayer() {
        guard let index = document.selectedLayerIndex,
              document.layers[index].isGradientFill,
              !document.isEffectivelyPixelsLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].kind = .gradientFill(currentGradientFillContent())
        document.layers[index].name = L10n.text("imageEditor.layer.gradientFillName")
        appendHistory(L10n.text("imageEditor.history.layerGradientFillUpdate"))
    }

    func addSmartFilterToSelectedLayer() {
        guard canAddSmartFilterToSelectedLayer,
              let index = document.selectedLayerIndex
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        let smartFilter = ImageEditorSmartFilter(
            kind: selectedFilter,
            intensity: filterIntensity,
            settings: currentFilterSettings()
        )
        document.layers[index].smartFilters.append(smartFilter)
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterAdd"))
    }

    func updateLastSmartFilterOnSelectedLayer() {
        guard canAddSmartFilterToSelectedLayer,
              let index = document.selectedLayerIndex,
              let lastIndex = document.layers[index].smartFilters.indices.last
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].smartFilters[lastIndex].kind = selectedFilter
        document.layers[index].smartFilters[lastIndex].intensity = filterIntensity
        document.layers[index].smartFilters[lastIndex].settings = currentFilterSettings()
        document.layers[index].smartFilters[lastIndex].isEnabled = true
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterUpdate"))
    }

    func updateSmartFilterOnSelectedLayer(_ filterID: UUID) {
        guard canAddSmartFilterToSelectedLayer,
              let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[layerIndex].smartFilters[filterIndex].kind = selectedFilter
        document.layers[layerIndex].smartFilters[filterIndex].intensity = filterIntensity
        document.layers[layerIndex].smartFilters[filterIndex].settings = currentFilterSettings()
        document.layers[layerIndex].smartFilters[filterIndex].isEnabled = true
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterUpdate"))
    }

    func toggleSmartFilterOnSelectedLayer(_ filterID: UUID) {
        guard canAddSmartFilterToSelectedLayer,
              let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[layerIndex].smartFilters[filterIndex].isEnabled.toggle()
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterToggle"))
    }

    func removeSmartFilterFromSelectedLayer(_ filterID: UUID) {
        guard canAddSmartFilterToSelectedLayer,
              let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[layerIndex].smartFilters.remove(at: filterIndex)
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterRemove"))
    }

    func moveSmartFilterOnSelectedLayer(_ filterID: UUID, offset: Int) {
        guard offset != 0,
              canAddSmartFilterToSelectedLayer,
              let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let targetIndex = filterIndex + offset
        guard document.layers[layerIndex].smartFilters.indices.contains(targetIndex) else { return }
        pushUndo()
        let filter = document.layers[layerIndex].smartFilters.remove(at: filterIndex)
        document.layers[layerIndex].smartFilters.insert(filter, at: targetIndex)
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterMove"))
    }

    func clearSmartFiltersFromSelectedLayer() {
        guard canAddSmartFilterToSelectedLayer,
              let index = document.selectedLayerIndex,
              !document.layers[index].smartFilters.isEmpty
        else { return }
        pushUndo()
        document.layers[index].smartFilters.removeAll()
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterClear"))
    }

    private func selectedSmartFilterIndex(_ filterID: UUID) -> (layerIndex: Int, filterIndex: Int)? {
        guard let layerIndex = document.selectedLayerIndex else { return nil }
        guard let filterIndex = document.layers[layerIndex].smartFilters.firstIndex(where: { $0.id == filterID }) else {
            return nil
        }
        return (layerIndex, filterIndex)
    }

    func updateSelectedFilterLayer() {
        guard let index = document.selectedLayerIndex,
              document.layers[index].isFilter,
              !document.isEffectivelyPixelsLocked(document.layers[index])
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        pushUndo()
        document.layers[index].kind = .filter(selectedFilter, filterIntensity)
        document.layers[index].filterSettings = currentFilterSettings()
        document.layers[index].name = L10n.format("imageEditor.layer.filterName", selectedFilter.title)
        appendHistory(L10n.text("imageEditor.history.layerFilterUpdate"))
    }

    private func currentFilterSettings() -> ImageEditorFilterSettings {
        ImageEditorFilterSettings(
            unsharpRadius: filterUnsharpRadius,
            unsharpThreshold: filterUnsharpThreshold,
            liquifyPushX: filterLiquifyPushX,
            liquifyPushY: filterLiquifyPushY,
            liquifyTwirlAngle: filterLiquifyTwirlAngle,
            liquifyBulgeAmount: filterLiquifyBulgeAmount,
            offsetX: filterOffsetX,
            offsetY: filterOffsetY,
            waveAmplitude: filterWaveAmplitude,
            waveFrequency: filterWaveFrequency,
            rippleAmount: filterRippleAmount,
            rippleFrequency: filterRippleFrequency
        ).normalized()
    }

    private func transformSelectedLayer(historyTitle: String, transform: (NSImage) -> NSImage?) {
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        guard let output = transform(layer.image) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        replaceSelectedLayerImage(output, historyTitle: historyTitle)
    }

    private func transformCanvas(
        historyTitle: String,
        transform: (ImageEditorLayer, CGSize) -> ImageEditorLayer?,
        canvasSize newCanvasSize: (CGSize) -> CGSize
    ) {
        let originalCanvasSize = document.canvasSize
        let transformedLayers = document.layers.compactMap { transform($0, originalCanvasSize) }
        guard transformedLayers.count == document.layers.count else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.canvasSize = newCanvasSize(originalCanvasSize)
        document.layers = transformedLayers
        appendHistory(historyTitle)
    }

    private func replaceSelectedLayerImage(_ image: NSImage, historyTitle: String) {
        replaceSelectedLayerPixels(image, historyTitle: historyTitle, resetFrame: true)
    }

    private func replaceSelectedLayerPixels(_ image: NSImage, historyTitle: String, resetFrame: Bool) {
        guard let index = document.selectedLayerIndex else { return }
        guard !document.isEffectivelyPixelsLocked(document.layers[index]) else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        let original = document.layers[index].image
        let normalized = image.normalizedBitmapImage()
        let clippedOutput = clippedToSelection(original: original, output: normalized)
        let output = document.isEffectivelyTransparencyLocked(document.layers[index])
            ? (clippedOutput.preservingAlpha(from: original) ?? clippedOutput)
            : clippedOutput
        document.layers[index].image = output
        if resetFrame {
            document.layers[index].frame = CGRect(origin: .zero, size: output.size)
        }
        appendHistory(historyTitle)
    }

    #if DEBUG
    func replaceSelectedLayerImageForTesting(_ image: NSImage, historyTitle: String) {
        replaceSelectedLayerImage(image, historyTitle: historyTitle)
    }
    #endif

    private func paintSelectedLayerMask(points: [CGPoint], reveal: Bool) {
        guard let index = document.selectedLayerIndex else { return }
        guard !document.isEffectivelyLocked(document.layers[index]) else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        guard let mask = document.layers[index].mask else {
            statusText = L10n.text("imageEditor.status.noLayerMask")
            isEditingLayerMask = false
            return
        }
        guard let updated = mask.withMaskStroke(points: points, width: brushSize, opacity: opacity, reveal: reveal) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].mask = clippedToSelection(original: mask, output: updated)
        appendHistory(reveal ? L10n.text("imageEditor.history.layerMaskReveal") : L10n.text("imageEditor.history.layerMaskHide"))
    }

    func maskSize(for layer: ImageEditorLayer) -> CGSize {
        layer.isGroup ? document.canvasSize : layer.image.size
    }

    private func clippedToSelection(original: NSImage, output: NSImage) -> NSImage {
        guard let selection = document.selection else { return output }
        guard let mask = selectionMask(for: selection, size: original.size) else { return output }
        let maskedOutput = NSImage.rendered(size: original.size) { _ in
            output.draw(
                in: CGRect(origin: .zero, size: output.size),
                from: CGRect(origin: .zero, size: output.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: original.size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
        guard let maskedOutput else { return output }
        return NSImage.rendered(size: original.size) { _ in
            original.draw(
                in: CGRect(origin: .zero, size: original.size),
                from: CGRect(origin: .zero, size: original.size),
                operation: .copy,
                fraction: 1
            )
            maskedOutput.draw(
                in: CGRect(origin: .zero, size: original.size),
                from: CGRect(origin: .zero, size: maskedOutput.size),
                operation: .sourceOver,
                fraction: 1
            )
        } ?? output
    }

    private func selectionMask(for selection: ImageEditorSelection, size: CGSize) -> NSImage? {
        if let rasterMask = selection.rasterMask,
           let image = NSImage.selectionMaskImage(
            rasterMask,
            inverted: selection.isInverted,
            targetSize: size
           ) {
            guard feather > 0 else { return image }
            return image.blurred(radius: feather) ?? image
        }
        let hardMask = NSImage.rendered(size: size) { rect in
            let path = selection.path()
            if selection.isInverted {
                NSColor.white.setFill()
                rect.fill()
                guard let context = NSGraphicsContext.current?.cgContext else { return }
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setFill()
                path.fill()
                context.restoreGState()
            } else {
                NSColor.white.setFill()
                path.fill()
            }
        }
        guard let hardMask, feather > 0 else { return hardMask }
        return hardMask.blurred(radius: feather) ?? hardMask
    }

    private func adjustedImage(
        kind: ImageEditorAdjustment,
        amount: Double,
        settings: ImageEditorAdjustmentSettings
    ) -> NSImage? {
        guard let layer = editableSelectedLayer() else { return nil }
        return layer.image.adjusted(kind: kind, amount: amount, settings: settings)
    }

    private func currentAdjustmentSettings() -> ImageEditorAdjustmentSettings {
        ImageEditorAdjustmentSettings(
            levelsBlackPoint: levelsBlackPoint,
            levelsGamma: levelsGamma,
            levelsWhitePoint: levelsWhitePoint,
            curvesShadows: curvesShadows,
            curvesMidtones: curvesMidtones,
            curvesHighlights: curvesHighlights,
            colorBalanceShadowsCyanRed: colorBalanceShadowsCyanRed,
            colorBalanceShadowsMagentaGreen: colorBalanceShadowsMagentaGreen,
            colorBalanceShadowsYellowBlue: colorBalanceShadowsYellowBlue,
            colorBalanceMidtonesCyanRed: colorBalanceMidtonesCyanRed,
            colorBalanceMidtonesMagentaGreen: colorBalanceMidtonesMagentaGreen,
            colorBalanceMidtonesYellowBlue: colorBalanceMidtonesYellowBlue,
            colorBalanceHighlightsCyanRed: colorBalanceHighlightsCyanRed,
            colorBalanceHighlightsMagentaGreen: colorBalanceHighlightsMagentaGreen,
            colorBalanceHighlightsYellowBlue: colorBalanceHighlightsYellowBlue,
            hueSaturationHue: hueSaturationHue,
            hueSaturationSaturation: hueSaturationSaturation,
            hueSaturationLightness: hueSaturationLightness,
            hueSaturationColorize: hueSaturationColorize,
            brightnessContrastBrightness: brightnessContrastBrightness,
            brightnessContrastContrast: brightnessContrastContrast,
            exposureEV: exposureEV,
            exposureOffset: exposureOffset,
            exposureGamma: exposureGamma,
            shadowsHighlightsShadows: shadowsHighlightsShadows,
            shadowsHighlightsHighlights: shadowsHighlightsHighlights,
            vibranceAmount: vibranceAmount,
            vibranceSaturation: vibranceSaturation,
            blackWhiteReds: blackWhiteReds,
            blackWhiteYellows: blackWhiteYellows,
            blackWhiteGreens: blackWhiteGreens,
            blackWhiteCyans: blackWhiteCyans,
            blackWhiteBlues: blackWhiteBlues,
            blackWhiteMagentas: blackWhiteMagentas,
            channelMixerRedRed: channelMixerRedRed,
            channelMixerRedGreen: channelMixerRedGreen,
            channelMixerRedBlue: channelMixerRedBlue,
            channelMixerRedConstant: channelMixerRedConstant,
            channelMixerGreenRed: channelMixerGreenRed,
            channelMixerGreenGreen: channelMixerGreenGreen,
            channelMixerGreenBlue: channelMixerGreenBlue,
            channelMixerGreenConstant: channelMixerGreenConstant,
            channelMixerBlueRed: channelMixerBlueRed,
            channelMixerBlueGreen: channelMixerBlueGreen,
            channelMixerBlueBlue: channelMixerBlueBlue,
            channelMixerBlueConstant: channelMixerBlueConstant,
            channelMixerMonochrome: channelMixerMonochrome,
            channelMixerMonoRed: channelMixerMonoRed,
            channelMixerMonoGreen: channelMixerMonoGreen,
            channelMixerMonoBlue: channelMixerMonoBlue,
            channelMixerMonoConstant: channelMixerMonoConstant,
            photoFilterPreset: selectedPhotoFilterPreset,
            photoFilterDensity: photoFilterDensity,
            photoFilterPreserveLuminosity: photoFilterPreserveLuminosity,
            photoFilterCustomRed: photoFilterCustomRed,
            photoFilterCustomGreen: photoFilterCustomGreen,
            photoFilterCustomBlue: photoFilterCustomBlue,
            colorLookupPreset: selectedColorLookupPreset,
            colorLookupCube: selectedColorLookupCube,
            selectiveColorSettings: selectiveColorSettings,
            selectiveColorMethod: selectiveColorMethod,
            gradientMapPreset: selectedGradientMapPreset,
            gradientMapReverse: gradientMapReverse,
            gradientMapDither: gradientMapDither,
            gradientMapShadowRed: gradientMapShadowRed,
            gradientMapShadowGreen: gradientMapShadowGreen,
            gradientMapShadowBlue: gradientMapShadowBlue,
            gradientMapHighlightRed: gradientMapHighlightRed,
            gradientMapHighlightGreen: gradientMapHighlightGreen,
            gradientMapHighlightBlue: gradientMapHighlightBlue
        ).normalized()
    }

    private func currentSolidColorFillContent() -> ImageEditorSolidColorFillContent {
        ImageEditorSolidColorFillContent(
            red: solidColorFillRed,
            green: solidColorFillGreen,
            blue: solidColorFillBlue
        ).normalized()
    }

    private func currentPatternFillContent() -> ImageEditorPatternFillContent {
        ImageEditorPatternFillContent(
            kind: selectedPatternFillKind,
            red: patternFillRed,
            green: patternFillGreen,
            blue: patternFillBlue,
            opacity: patternFillOpacity,
            scale: CGFloat(patternFillScale)
        ).normalized()
    }

    private func currentGradientFillContent() -> ImageEditorGradientFillContent {
        ImageEditorGradientFillContent(
            preset: selectedGradientFillPreset,
            style: selectedGradientFillStyle,
            reverse: gradientFillReverse,
            angle: CGFloat(gradientFillAngle),
            scale: CGFloat(gradientFillScale),
            startRed: gradientFillStartRed,
            startGreen: gradientFillStartGreen,
            startBlue: gradientFillStartBlue,
            endRed: gradientFillEndRed,
            endGreen: gradientFillEndGreen,
            endBlue: gradientFillEndBlue
        ).normalized()
    }

    private func resetAdjustmentControls() {
        adjustmentValue = 0
        levelsBlackPoint = 0
        levelsGamma = 1
        levelsWhitePoint = 1
        curvesShadows = 0
        curvesMidtones = 0
        curvesHighlights = 0
        colorBalanceShadowsCyanRed = 0
        colorBalanceShadowsMagentaGreen = 0
        colorBalanceShadowsYellowBlue = 0
        colorBalanceMidtonesCyanRed = 0
        colorBalanceMidtonesMagentaGreen = 0
        colorBalanceMidtonesYellowBlue = 0
        colorBalanceHighlightsCyanRed = 0
        colorBalanceHighlightsMagentaGreen = 0
        colorBalanceHighlightsYellowBlue = 0
        hueSaturationHue = 0
        hueSaturationSaturation = 0
        hueSaturationLightness = 0
        hueSaturationColorize = false
        brightnessContrastBrightness = 0
        brightnessContrastContrast = 0
        exposureEV = 0
        exposureOffset = 0
        exposureGamma = 1
        shadowsHighlightsShadows = 0
        shadowsHighlightsHighlights = 0
        vibranceAmount = 0
        vibranceSaturation = 0
        blackWhiteReds = 0.40
        blackWhiteYellows = 0.60
        blackWhiteGreens = 0.40
        blackWhiteCyans = 0.60
        blackWhiteBlues = 0.20
        blackWhiteMagentas = 0.80
        selectedChannelMixerOutput = .red
        channelMixerRedRed = 1
        channelMixerRedGreen = 0
        channelMixerRedBlue = 0
        channelMixerRedConstant = 0
        channelMixerGreenRed = 0
        channelMixerGreenGreen = 1
        channelMixerGreenBlue = 0
        channelMixerGreenConstant = 0
        channelMixerBlueRed = 0
        channelMixerBlueGreen = 0
        channelMixerBlueBlue = 1
        channelMixerBlueConstant = 0
        channelMixerMonochrome = false
        channelMixerMonoRed = 0.40
        channelMixerMonoGreen = 0.40
        channelMixerMonoBlue = 0.20
        channelMixerMonoConstant = 0
        selectedPhotoFilterPreset = .warming85
        photoFilterDensity = 0.25
        photoFilterPreserveLuminosity = true
        photoFilterCustomRed = 1
        photoFilterCustomGreen = 0.65
        photoFilterCustomBlue = 0.30
        selectedColorLookupPreset = .filmStock
        selectedColorLookupCube = ImageEditorColorLookupCube()
        selectedSelectiveColorRange = .reds
        selectiveColorSettings = ImageEditorSelectiveColorSettings()
        selectiveColorMethod = .relative
        selectedGradientMapPreset = .blackWhite
        gradientMapReverse = false
        gradientMapDither = false
        gradientMapShadowRed = 0
        gradientMapShadowGreen = 0
        gradientMapShadowBlue = 0
        gradientMapHighlightRed = 1
        gradientMapHighlightGreen = 1
        gradientMapHighlightBlue = 1
        solidColorFillRed = 1
        solidColorFillGreen = 0
        solidColorFillBlue = 0
        selectedPatternFillKind = .checkerboard
        patternFillRed = 0.10
        patternFillGreen = 0.24
        patternFillBlue = 0.95
        patternFillOpacity = 0.55
        patternFillScale = 16
        selectedGradientFillPreset = .blueOrange
        selectedGradientFillStyle = .linear
        gradientFillReverse = false
        gradientFillAngle = 0
        gradientFillScale = 1
        gradientFillStartRed = 0.10
        gradientFillStartGreen = 0.24
        gradientFillStartBlue = 0.95
        gradientFillEndRed = 1
        gradientFillEndGreen = 0.50
        gradientFillEndBlue = 0.12
    }

    private func editableSelectedLayer() -> ImageEditorLayer? {
        guard let index = document.selectedLayerIndex else { return nil }
        let layer = document.layers[index]
        return layer.isGroup || layer.isAdjustment || layer.isFilter || layer.isSolidColorFill || layer.isPatternFill || layer.isGradientFill || layer.isText || layer.isShape || document.isEffectivelyPixelsLocked(layer) ? nil : layer
    }

    private func smartObjectConversionCandidate() -> ImageEditorSmartObjectConversionCandidate? {
        let rootIndices = smartObjectConversionRootIndices()
        guard !rootIndices.isEmpty else { return nil }

        let rootLayers = rootIndices.map { document.layers[$0] }
        let parentGroupID = rootLayers[0].groupID
        guard rootLayers.allSatisfy({ $0.groupID == parentGroupID }) else { return nil }
        guard rootLayers.allSatisfy({
            !document.isEffectivelyPixelsLocked($0)
                && !document.isEffectivelyPositionLocked($0)
        }) else { return nil }

        if rootLayers.count == 1,
           let rootLayer = rootLayers.first {
            guard !rootLayer.isSmartObject,
                  !rootLayer.isAdjustment,
                  !rootLayer.isFilter,
                  !rootLayer.isSolidColorFill,
                  !rootLayer.isPatternFill,
                  !rootLayer.isGradientFill
            else { return nil }
        }

        let blockIDs = smartObjectConversionBlockIDs(rootLayers: rootLayers)
        guard !blockIDs.isEmpty else { return nil }
        for index in rootIndices {
            guard document.layers.indices.contains(index) else { return nil }
            let layer = document.layers[index]
            if layer.isClippingMask {
                guard let base = document.clippingBase(forLayerAt: index),
                      blockIDs.contains(base.id)
                else { return nil }
            }
        }

        let insertionIndex = document.layers.indices.first { blockIDs.contains(document.layers[$0].id) } ?? 0
        let sourceName: String
        if rootLayers.count == 1,
           let rootLayer = rootLayers.first {
            sourceName = rootLayer.name
        } else {
            sourceName = L10n.format("imageEditor.layer.smartObjectSelectionName", rootLayers.count)
        }

        return ImageEditorSmartObjectConversionCandidate(
            removedLayerIDs: blockIDs,
            insertionIndex: insertionIndex,
            parentGroupID: parentGroupID,
            sourceName: sourceName
        )
    }

    private func smartObjectConversionPlan() -> ImageEditorSmartObjectConversionPlan? {
        guard let candidate = smartObjectConversionCandidate() else { return nil }
        var sourceDocument = document
        sourceDocument.layers = document.layers.filter { candidate.removedLayerIDs.contains($0.id) }
        sourceDocument.selectedLayerID = nil
        sourceDocument.selectedLayerIDs = []

        let sourceCanvas = sourceDocument.compositedImage
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        let contentBounds = sourceCanvas.nonTransparentPixelBounds(alphaThreshold: 0)?
            .integral
            .intersection(canvasBounds)
        let fallbackBounds = smartObjectFallbackBounds(for: candidate.removedLayerIDs)
        let cropBounds = normalizedSmartObjectBounds(contentBounds ?? fallbackBounds, canvasBounds: canvasBounds)
        guard cropBounds.width > 0,
              cropBounds.height > 0,
              let smartSource = sourceCanvas.cropped(to: cropBounds)?.normalizedBitmapImage()
        else { return nil }

        var replacement = ImageEditorLayer.blank(
            name: L10n.format("imageEditor.layer.smartObjectName", candidate.sourceName),
            size: smartSource.size
        )
        replacement.image = smartSource
        replacement.frame = cropBounds
        replacement.groupID = candidate.parentGroupID
        replacement.kind = .smartObject(
            ImageEditorSmartObjectContent(
                sourceName: candidate.sourceName,
                originalSize: smartSource.size
            )
        )

        return ImageEditorSmartObjectConversionPlan(
            replacementLayer: replacement,
            removedLayerIDs: candidate.removedLayerIDs,
            insertionIndex: candidate.insertionIndex
        )
    }

    private func smartObjectConversionRootIndices() -> [Int] {
        let selectedIndices = selectedLayerIndices.sorted()
        let selectedGroupIDs = Set(selectedIndices.compactMap { index in
            let layer = document.layers[index]
            return layer.isGroup ? layer.id : nil
        })
        let selectedGroupDescendantIDs = selectedGroupIDs.reduce(into: Set<UUID>()) { result, groupID in
            result.formUnion(groupDescendantIDs(for: groupID))
        }
        return selectedIndices.filter { index in
            !selectedGroupDescendantIDs.contains(document.layers[index].id)
        }
    }

    private func smartObjectConversionBlockIDs(rootLayers: [ImageEditorLayer]) -> Set<UUID> {
        rootLayers.reduce(into: Set<UUID>()) { result, layer in
            result.insert(layer.id)
            if layer.isGroup {
                result.formUnion(groupDescendantIDs(for: layer.id))
            }
        }
    }

    private func smartObjectFallbackBounds(for layerIDs: Set<UUID>) -> CGRect {
        let bounds = document.layers
            .filter { layerIDs.contains($0.id) && !$0.isGroup && !($0.isAdjustment || $0.isFilter || $0.isSolidColorFill || $0.isPatternFill || $0.isGradientFill) }
            .map { $0.renderedCompositingFrame(globalLightAngle: document.globalLightAngle) }
            .reduce(nil as CGRect?) { partial, rect in
                partial.map { $0.union(rect) } ?? rect
            }
        return bounds ?? CGRect(origin: .zero, size: document.canvasSize)
    }

    private func normalizedSmartObjectBounds(_ bounds: CGRect, canvasBounds: CGRect) -> CGRect {
        let bounded = bounds.standardized
            .intersection(canvasBounds)
            .integral
        guard bounded.width > 0, bounded.height > 0 else {
            return CGRect(x: 0, y: 0, width: max(1, canvasBounds.width), height: max(1, canvasBounds.height))
        }
        return CGRect(
            x: bounded.minX,
            y: bounded.minY,
            width: max(1, bounded.width),
            height: max(1, bounded.height)
        )
    }

    private func canToggleTransparentPixelsLock(for layer: ImageEditorLayer) -> Bool {
        !layer.isGroup && !layer.isAdjustment && !layer.isFilter && !layer.isSolidColorFill && !layer.isPatternFill && !layer.isGradientFill && !layer.isText && !layer.isShape
    }

    private func canTogglePixelsLock(for layer: ImageEditorLayer) -> Bool {
        !layer.isAdjustment && !layer.isFilter && !layer.isSolidColorFill && !layer.isPatternFill && !layer.isGradientFill
    }

    private func canTogglePositionLock(for layer: ImageEditorLayer) -> Bool {
        !layer.isAdjustment && !layer.isFilter && !layer.isSolidColorFill && !layer.isPatternFill && !layer.isGradientFill
    }

    private func setSelectedLayerLocks(
        fullLock: Bool? = nil,
        pixels: Bool? = nil,
        position: Bool? = nil,
        transparentPixels: Bool? = nil,
        historyKey: String,
        statusKey: String
    ) {
        let indices = selectedLayerIndices.filter { index in
            let layer = document.layers[index]
            if let fullLock, layer.isLocked != fullLock {
                return true
            }
            if let pixels, canTogglePixelsLock(for: layer), layer.locksPixels != pixels {
                return true
            }
            if let position, canTogglePositionLock(for: layer), layer.locksPosition != position {
                return true
            }
            if let transparentPixels,
               canToggleTransparentPixelsLock(for: layer),
               layer.locksTransparentPixels != transparentPixels {
                return true
            }
            return false
        }
        guard !indices.isEmpty else { return }

        pushUndo()
        for index in indices {
            let layer = document.layers[index]
            if let fullLock {
                document.layers[index].isLocked = fullLock
            }
            if let pixels, canTogglePixelsLock(for: layer) {
                document.layers[index].locksPixels = pixels
            }
            if let position, canTogglePositionLock(for: layer) {
                document.layers[index].locksPosition = position
            }
            if let transparentPixels, canToggleTransparentPixelsLock(for: layer) {
                document.layers[index].locksTransparentPixels = transparentPixels
            }
        }
        if fullLock == true, selectedLayerIndices.contains(where: { document.layers[$0].id == document.selectedLayerID }) {
            isEditingLayerMask = false
        }
        appendHistory(L10n.text(historyKey))
        statusText = L10n.text(statusKey)
    }

    private func canSetLayerFillOpacity(_ layer: ImageEditorLayer) -> Bool {
        !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && !document.isEffectivelyLocked(layer)
    }

    private func canSetLayerBlendIf(_ layer: ImageEditorLayer) -> Bool {
        !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && !document.isEffectivelyLocked(layer)
    }

    private func groupMemberIndices(for groupID: UUID) -> [Int] {
        document.layers.indices.filter { document.layers[$0].groupID == groupID }
    }

    private func groupDescendantIndices(for groupID: UUID) -> [Int] {
        let descendantIDs = groupDescendantIDs(for: groupID)
        return document.layers.indices.filter { descendantIDs.contains(document.layers[$0].id) }
    }

    private func groupDescendantIDs(for groupID: UUID) -> Set<UUID> {
        var descendantIDs = Set<UUID>()
        var pendingGroupIDs = [groupID]
        while let currentGroupID = pendingGroupIDs.popLast() {
            for layer in document.layers where layer.groupID == currentGroupID && !descendantIDs.contains(layer.id) {
                descendantIDs.insert(layer.id)
                if layer.isGroup {
                    pendingGroupIDs.append(layer.id)
                }
            }
        }
        return descendantIDs
    }

    private func movableRootLayerIDs(for sourceIDs: Set<UUID>) -> Set<UUID> {
        let existingSourceIDs = sourceIDs.filter { id in
            document.layers.contains { $0.id == id }
        }
        let selectedGroupIDs = Set(document.layers.compactMap { layer in
            existingSourceIDs.contains(layer.id) && layer.isGroup ? layer.id : nil
        })
        let selectedGroupDescendantIDs = selectedGroupIDs.reduce(into: Set<UUID>()) { result, groupID in
            result.formUnion(groupDescendantIDs(for: groupID))
        }

        return Set(document.layers.compactMap { layer in
            guard existingSourceIDs.contains(layer.id),
                  !selectedGroupDescendantIDs.contains(layer.id),
                  !document.isEffectivelyLocked(layer)
            else { return nil }
            return layer.id
        })
    }

    private func movingLayerBlockIDs(for rootSourceIDs: Set<UUID>) -> Set<UUID> {
        rootSourceIDs.reduce(into: rootSourceIDs) { result, layerID in
            guard let layer = document.layers.first(where: { $0.id == layerID }),
                  layer.isGroup
            else { return }
            result.formUnion(groupDescendantIDs(for: layer.id))
        }
    }

    private func canMoveLayerRoots(_ rootSourceIDs: Set<UUID>, toParent parentID: UUID?) -> Bool {
        guard let parentID else { return true }
        guard let parentLayer = document.layers.first(where: { $0.id == parentID && $0.isGroup }),
              !document.isEffectivelyLocked(parentLayer)
        else { return false }

        for rootID in rootSourceIDs {
            guard let rootLayer = document.layers.first(where: { $0.id == rootID }) else { return false }
            if rootID == parentID {
                return false
            }
            if rootLayer.isGroup, groupDescendantIDs(for: rootLayer.id).contains(parentID) {
                return false
            }
        }
        return true
    }

    private func wouldChangeLayerOrderOrParent(
        _ movingLayers: [ImageEditorLayer],
        remainingLayers: [ImageEditorLayer],
        insertionIndex: Int
    ) -> Bool {
        var reorderedLayers = remainingLayers
        reorderedLayers.insert(contentsOf: movingLayers, at: insertionIndex)
        guard reorderedLayers.map(\.id) == document.layers.map(\.id) else { return true }
        for layer in movingLayers {
            guard let currentLayer = document.layers.first(where: { $0.id == layer.id }),
                  currentLayer.groupID == layer.groupID
            else { return true }
        }
        return false
    }

    func layerIDsExpandingGroups(_ ids: Set<UUID>) -> Set<UUID> {
        var expandedIDs = ids
        for index in document.layers.indices where ids.contains(document.layers[index].id) && document.layers[index].isGroup {
            expandedIDs.formUnion(groupDescendantIDs(for: document.layers[index].id))
        }
        return expandedIDs
    }

    private func movableSelectedLayerIndicesForHierarchyChange() -> [Int] {
        let selectedGroupIDs = Set(selectedLayerIndices.compactMap { index in
            let layer = document.layers[index]
            return layer.isGroup ? layer.id : nil
        })
        let selectedGroupDescendantIDs = selectedGroupIDs.reduce(into: Set<UUID>()) { result, groupID in
            result.formUnion(groupDescendantIDs(for: groupID))
        }
        return selectedLayerIndices.filter { index in
            let layer = document.layers[index]
            return !selectedGroupDescendantIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
        }
    }

    private func groupTargetForMovingSelectionIntoGroup() -> UUID? {
        let indices = movableSelectedLayerIndicesForHierarchyChange()
        guard let firstIndex = indices.first,
              let topIndex = indices.max()
        else { return nil }
        let parentID = document.layers[firstIndex].groupID
        guard indices.allSatisfy({ document.layers[$0].groupID == parentID }) else { return nil }

        let movingIDs = Set(indices.map { document.layers[$0].id })
        let movingDescendantIDs = movingIDs.reduce(into: Set<UUID>()) { result, layerID in
            guard let layer = document.layers.first(where: { $0.id == layerID }),
                  layer.isGroup
            else { return }
            result.formUnion(groupDescendantIDs(for: layer.id))
        }

        guard topIndex + 1 < document.layers.count else { return nil }
        for candidateIndex in (topIndex + 1)..<document.layers.count {
            let candidate = document.layers[candidateIndex]
            guard candidate.isGroup,
                  candidate.groupID == parentID,
                  !movingIDs.contains(candidate.id),
                  !movingDescendantIDs.contains(candidate.id),
                  !document.isEffectivelyLocked(candidate)
            else { continue }
            return candidate.id
        }
        return nil
    }

    private func selectedUnlockedGroupIDs() -> Set<UUID> {
        Set(selectedLayerIndices.compactMap { index in
            let layer = document.layers[index]
            guard layer.isGroup, !document.isEffectivelyLocked(layer) else { return nil }
            return layer.id
        })
    }

    private func isBackgroundLayer(at index: Int) -> Bool {
        guard document.layers.indices.contains(index) else { return false }
        let layer = document.layers[index]
        return index == 0
            && layer.groupID == nil
            && layer.isLocked
            && layer.name == L10n.text("imageEditor.layer.background")
    }

    private func backgroundImage(from layer: ImageEditorLayer) -> NSImage? {
        let fillColor = (backgroundColor.usingColorSpace(.deviceRGB) ?? backgroundColor).withAlphaComponent(1)
        let layerImage = layer.renderedCompositingImage(globalLightAngle: document.globalLightAngle)
        return NSImage.rendered(size: document.canvasSize) { rect in
            fillColor.setFill()
            rect.fill()
            layerImage.draw(
                in: layer.renderedCompositingFrame(globalLightAngle: document.globalLightAngle),
                from: CGRect(origin: .zero, size: layerImage.size),
                operation: .sourceOver,
                fraction: 1
            )
        }?.normalizedBitmapImage()
    }

    private func duplicateSourceLayerIndices() -> [Int] {
        let selectedIDs = document.selectedLayerIDs
        let selectedGroupIDs = Set(selectedLayerIndices.compactMap { index in
            let layer = document.layers[index]
            return layer.isGroup ? layer.id : nil
        })
        let descendantIDs = selectedGroupIDs.reduce(into: Set<UUID>()) { result, groupID in
            result.formUnion(groupDescendantIDs(for: groupID))
        }
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                || descendantIDs.contains(layer.id)
        }
    }

    private var selectedLayerIndices: [Int] {
        document.layers.indices.filter { document.selectedLayerIDs.contains(document.layers[$0].id) }
    }

    private func topmostSelectedLayerID() -> UUID? {
        document.layers.reversed().first { document.selectedLayerIDs.contains($0.id) }?.id
    }

    private enum LayerStackBoundary {
        case top
        case bottom
    }

    private struct NewLayerInsertionContext {
        var parentGroupID: UUID?
        var index: Int
    }

    private func newLayerInsertionContext() -> NewLayerInsertionContext {
        guard let selectedLayerID = document.selectedLayerID,
              let selectedIndex = document.layers.firstIndex(where: { $0.id == selectedLayerID })
        else {
            return NewLayerInsertionContext(parentGroupID: nil, index: document.layers.count)
        }

        let selectedLayer = document.layers[selectedIndex]
        if selectedLayer.isGroup {
            return NewLayerInsertionContext(parentGroupID: selectedLayer.id, index: selectedIndex)
        }

        return NewLayerInsertionContext(
            parentGroupID: selectedLayer.groupID,
            index: min(selectedIndex + 1, document.layers.count)
        )
    }

    private func expandGroupIfNeeded(_ groupID: UUID?) {
        guard let groupID,
              let groupIndex = document.layers.firstIndex(where: { $0.id == groupID && $0.isGroup })
        else { return }
        document.layers[groupIndex].isGroupExpanded = true
    }

    private func deletionIDsForCurrentSelection() -> Set<UUID> {
        var deletionIDs = Set<UUID>()
        for index in selectedLayerIndices {
            let layer = document.layers[index]
            if layer.isGroup {
                guard !document.isEffectivelyLocked(layer) else { continue }
                deletionIDs.insert(layer.id)
                deletionIDs.formUnion(groupDescendantIDs(for: layer.id))
            } else if !document.isEffectivelyLocked(layer) {
                deletionIDs.insert(layer.id)
            }
        }
        return deletionIDs
    }

    private func groupReplacementParents(forRemoving groupIDs: Set<UUID>) -> [UUID: UUID?] {
        var replacements: [UUID: UUID?] = [:]
        for groupID in groupIDs {
            var parentID = document.layers.first { $0.id == groupID }?.groupID
            var visitedIDs = Set<UUID>([groupID])
            while let candidateID = parentID,
                  groupIDs.contains(candidateID),
                  !visitedIDs.contains(candidateID) {
                visitedIDs.insert(candidateID)
                parentID = document.layers.first { $0.id == candidateID }?.groupID
            }
            replacements[groupID] = parentID
        }
        return replacements
    }

    private func canMoveSelectedLayers(direction: Int) -> Bool {
        let selectedIDs = document.selectedLayerIDs
        guard !selectedIDs.isEmpty else { return false }
        for index in document.layers.indices where selectedIDs.contains(document.layers[index].id) {
            let targetIndex = index + direction
            guard document.layers.indices.contains(targetIndex) else { continue }
            if !selectedIDs.contains(document.layers[targetIndex].id) {
                return true
            }
        }
        return false
    }

    private func moveSelectedLayers(direction: Int) {
        guard direction == 1 || direction == -1, canMoveSelectedLayers(direction: direction) else { return }
        pushUndo()
        let selectedIDs = document.selectedLayerIDs
        let indices: [Int] = direction > 0
            ? Array(document.layers.indices.reversed())
            : Array(document.layers.indices)
        for index in indices where selectedIDs.contains(document.layers[index].id) {
            let targetIndex = index + direction
            guard document.layers.indices.contains(targetIndex),
                  !selectedIDs.contains(document.layers[targetIndex].id)
            else { continue }
            document.layers.swapAt(index, targetIndex)
        }
        normalizeClippingMasks()
        appendHistory(L10n.text("imageEditor.history.layerMove"))
    }

    private func canMoveSelectedLayers(to boundary: LayerStackBoundary) -> Bool {
        guard !document.selectedLayerIDs.isEmpty else { return false }
        return reorderedLayers(movingSelectionTo: boundary).map(\.id) != document.layers.map(\.id)
    }

    private func moveSelectedLayers(to boundary: LayerStackBoundary) {
        guard canMoveSelectedLayers(to: boundary) else { return }
        pushUndo()
        document.layers = reorderedLayers(movingSelectionTo: boundary)
        normalizeClippingMasks()
        let historyKey = boundary == .top
            ? "imageEditor.history.layerMoveToTop"
            : "imageEditor.history.layerMoveToBottom"
        appendHistory(L10n.text(historyKey))
    }

    private func reorderedLayers(movingSelectionTo boundary: LayerStackBoundary) -> [ImageEditorLayer] {
        let selectedIDs = document.selectedLayerIDs
        let selectedLayers = document.layers.filter { selectedIDs.contains($0.id) }
        let remainingLayers = document.layers.filter { !selectedIDs.contains($0.id) }
        switch boundary {
        case .top:
            return remainingLayers + selectedLayers
        case .bottom:
            return selectedLayers + remainingLayers
        }
    }

    private func clippingBaseExists(below index: Int, groupID: UUID?) -> Bool {
        document.hasClippingBase(below: index, groupID: groupID)
    }

    private func isolatedLayerVisibilityIDs() -> Set<UUID> {
        var visibleIDs = document.selectedLayerIDs
        for index in selectedLayerIndices {
            let layer = document.layers[index]
            if layer.isGroup {
                visibleIDs.formUnion(groupDescendantIDs(for: layer.id))
            }
        }

        var ancestorIDs = Set<UUID>()
        for layer in document.layers where visibleIDs.contains(layer.id) {
            ancestorIDs.formUnion(document.ancestorGroups(for: layer).map(\.id))
        }
        visibleIDs.formUnion(ancestorIDs)
        return visibleIDs
    }

    private func selectedLayerClippingCreationIndices() -> [Int] {
        selectedLayerIndices.filter { index in
            let layer = document.layers[index]
            return !layer.isGroup
                && !layer.isClippingMask
                && !document.isEffectivelyLocked(layer)
                && clippingBaseExists(below: index, groupID: layer.groupID)
        }
    }

    private func selectedLayerClippingReleaseIndices() -> [Int] {
        selectedLayerIndices.filter { index in
            let layer = document.layers[index]
            return layer.isClippingMask && !document.isEffectivelyLocked(layer)
        }
    }

    private func normalizeClippingMasks() {
        for index in document.layers.indices where document.layers[index].isClippingMask {
            if document.clippingBaseIndex(forLayerAt: index) == nil {
                document.layers[index].isClippingMask = false
            }
        }
    }

    private func mergedAdjustmentLayer(lowerIndex: Int, adjustmentIndex: Int) -> ImageEditorLayer? {
        guard document.layers.indices.contains(lowerIndex),
              document.layers.indices.contains(adjustmentIndex),
              let adjustment = document.layers[adjustmentIndex].adjustment
        else { return nil }
        let lower = document.layers[lowerIndex]
        let adjustmentLayer = document.layers[adjustmentIndex]
        let canvasSize = document.canvasSize
        guard let renderedLower = NSImage.rendered(size: canvasSize, actions: { _ in
            drawMergedLayer(at: lowerIndex)
        }),
              let adjustedImage = renderedLower.applyingAdjustment(
                kind: adjustment.kind,
                amount: adjustment.amount * adjustmentLayer.opacity,
                settings: adjustmentLayer.adjustmentSettings,
                mask: document.localEffectMask(forLayerAt: adjustmentIndex)
              )
        else { return nil }

        var merged = lower
        merged.id = UUID()
        merged.name = L10n.format("imageEditor.layer.mergedName", lower.name)
        merged.image = adjustedImage
        merged.frame = CGRect(origin: .zero, size: canvasSize)
        merged.opacity = 1
        merged.fillOpacity = 1
        merged.blendMode = .normal
        merged.isVisible = lower.isVisible || adjustmentLayer.isVisible
        merged.isLocked = false
        merged.mask = nil
        merged.style = ImageEditorLayerStyle()
        merged.smartFilters = []
        merged.kind = .pixel
        merged.adjustmentSettings = ImageEditorAdjustmentSettings()
        merged.isClippingMask = false
        return merged
    }

    private func mergedFilterLayer(lowerIndex: Int, filterIndex: Int) -> ImageEditorLayer? {
        guard document.layers.indices.contains(lowerIndex),
              document.layers.indices.contains(filterIndex),
              let filter = document.layers[filterIndex].filter
        else { return nil }
        let lower = document.layers[lowerIndex]
        let filterLayer = document.layers[filterIndex]
        let canvasSize = document.canvasSize
        guard let renderedLower = NSImage.rendered(size: canvasSize, actions: { _ in
            drawMergedLayer(at: lowerIndex)
        }),
              let filteredImage = renderedLower.applyingFilter(
                kind: filter.kind,
                intensity: filter.intensity * filterLayer.opacity,
                settings: filterLayer.filterSettings,
                mask: document.localEffectMask(forLayerAt: filterIndex)
              )
        else { return nil }

        var merged = lower
        merged.id = UUID()
        merged.name = L10n.format("imageEditor.layer.mergedName", lower.name)
        merged.image = filteredImage
        merged.frame = CGRect(origin: .zero, size: canvasSize)
        merged.opacity = 1
        merged.fillOpacity = 1
        merged.blendMode = .normal
        merged.isVisible = lower.isVisible || filterLayer.isVisible
        merged.isLocked = false
        merged.mask = nil
        merged.style = ImageEditorLayerStyle()
        merged.smartFilters = []
        merged.kind = .pixel
        merged.isClippingMask = false
        return merged
    }

    private func mergedLayer(lowerIndex: Int, upperIndex: Int) -> ImageEditorLayer? {
        guard document.layers.indices.contains(lowerIndex),
              document.layers.indices.contains(upperIndex)
        else { return nil }
        let lower = document.layers[lowerIndex]
        let upper = document.layers[upperIndex]
        let canvasSize = document.canvasSize
        guard let image = NSImage.rendered(size: canvasSize, actions: { _ in
            drawMergedLayer(at: lowerIndex)
            drawMergedLayer(at: upperIndex)
        }) else { return nil }

        var merged = lower
        merged.id = UUID()
        merged.name = L10n.format("imageEditor.layer.mergedName", lower.name)
        merged.image = image
        merged.frame = CGRect(origin: .zero, size: canvasSize)
        merged.opacity = 1
        merged.fillOpacity = 1
        merged.blendMode = .normal
        merged.isVisible = lower.isVisible || upper.isVisible
        merged.isLocked = false
        merged.mask = nil
        merged.style = ImageEditorLayerStyle()
        merged.smartFilters = []
        merged.kind = .pixel
        merged.isClippingMask = false
        return merged
    }

    private func drawMergedLayer(at index: Int) {
        let layer = document.layers[index]
        if layer.isClippingMask,
           let clippedImage = document.clippedCompositingImage(forLayerAt: index) {
            clippedImage.draw(
                in: CGRect(origin: .zero, size: document.canvasSize),
                from: CGRect(origin: .zero, size: document.canvasSize),
                operation: layer.blendMode.operation,
                fraction: layer.opacity
            )
            return
        }

        let image = layer.renderedCompositingImage(globalLightAngle: document.globalLightAngle)
        image.draw(
            in: layer.renderedCompositingFrame(globalLightAngle: document.globalLightAngle),
            from: CGRect(origin: .zero, size: image.size),
            operation: layer.blendMode.operation,
            fraction: layer.opacity
        )
    }

    func pushUndo() {
        undoStack.append(document)
        redoStack.removeAll()
    }

    func appendHistory(_ title: String) {
        let entry = ImageEditorHistoryEntry(title: title)
        document.history.append(entry)
        historySnapshots[entry.id] = document
        updateStatus()
    }

    private func recordCurrentHistorySnapshot() {
        guard let entry = document.history.last else { return }
        historySnapshots[entry.id] = document
    }

    private func uniqueHistorySnapshotName(_ baseName: String, excluding id: UUID? = nil) -> String {
        let existingNames = Set(
            namedHistorySnapshots
                .filter { $0.id != id }
                .map(\.name)
        )
        guard existingNames.contains(baseName) else { return baseName }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)") {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }

    private func ensureSelectedLayer() {
        let existingIDs = Set(document.layers.map(\.id))
        document.selectedLayerIDs = document.selectedLayerIDs.intersection(existingIDs)
        if let selectedLayerID = document.selectedLayerID,
           existingIDs.contains(selectedLayerID) {
            document.selectedLayerIDs.insert(selectedLayerID)
            if document.selectedLayer?.mask == nil {
                isEditingLayerMask = false
            }
            return
        }
        document.selectedLayerID = topmostSelectedLayerID() ?? document.layers.last?.id
        document.selectedLayerIDs = document.selectedLayerID.map { Set([$0]) } ?? []
        isEditingLayerMask = false
    }

    private func syncControlsFromLayerSelection() {
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncSolidColorFillControlsFromSelection()
        syncPatternFillControlsFromSelection()
        syncGradientFillControlsFromSelection()
        syncTextControlsFromSelection()
        syncShapeControlsFromSelection()
        syncPathControlsFromSelection()
    }

    private func syncAdjustmentControlsFromSelection() {
        guard let adjustment = document.selectedLayer?.adjustment else { return }
        selectedAdjustment = adjustment.kind
        adjustmentValue = adjustment.amount
        let settings = (document.selectedLayer?.adjustmentSettings ?? ImageEditorAdjustmentSettings()).normalized()
        levelsBlackPoint = settings.levelsBlackPoint
        levelsGamma = settings.levelsGamma
        levelsWhitePoint = settings.levelsWhitePoint
        curvesShadows = settings.curvesShadows
        curvesMidtones = settings.curvesMidtones
        curvesHighlights = settings.curvesHighlights
        colorBalanceShadowsCyanRed = settings.colorBalanceShadowsCyanRed
        colorBalanceShadowsMagentaGreen = settings.colorBalanceShadowsMagentaGreen
        colorBalanceShadowsYellowBlue = settings.colorBalanceShadowsYellowBlue
        colorBalanceMidtonesCyanRed = settings.colorBalanceMidtonesCyanRed
        colorBalanceMidtonesMagentaGreen = settings.colorBalanceMidtonesMagentaGreen
        colorBalanceMidtonesYellowBlue = settings.colorBalanceMidtonesYellowBlue
        colorBalanceHighlightsCyanRed = settings.colorBalanceHighlightsCyanRed
        colorBalanceHighlightsMagentaGreen = settings.colorBalanceHighlightsMagentaGreen
        colorBalanceHighlightsYellowBlue = settings.colorBalanceHighlightsYellowBlue
        hueSaturationHue = settings.hueSaturationHue
        hueSaturationSaturation = settings.hueSaturationSaturation
        hueSaturationLightness = settings.hueSaturationLightness
        hueSaturationColorize = settings.hueSaturationColorize
        brightnessContrastBrightness = settings.brightnessContrastBrightness
        brightnessContrastContrast = settings.brightnessContrastContrast
        exposureEV = settings.exposureEV
        exposureOffset = settings.exposureOffset
        exposureGamma = settings.exposureGamma
        shadowsHighlightsShadows = settings.shadowsHighlightsShadows
        shadowsHighlightsHighlights = settings.shadowsHighlightsHighlights
        vibranceAmount = settings.vibranceAmount
        vibranceSaturation = settings.vibranceSaturation
        blackWhiteReds = settings.blackWhiteReds
        blackWhiteYellows = settings.blackWhiteYellows
        blackWhiteGreens = settings.blackWhiteGreens
        blackWhiteCyans = settings.blackWhiteCyans
        blackWhiteBlues = settings.blackWhiteBlues
        blackWhiteMagentas = settings.blackWhiteMagentas
        channelMixerRedRed = settings.channelMixerRedRed
        channelMixerRedGreen = settings.channelMixerRedGreen
        channelMixerRedBlue = settings.channelMixerRedBlue
        channelMixerRedConstant = settings.channelMixerRedConstant
        channelMixerGreenRed = settings.channelMixerGreenRed
        channelMixerGreenGreen = settings.channelMixerGreenGreen
        channelMixerGreenBlue = settings.channelMixerGreenBlue
        channelMixerGreenConstant = settings.channelMixerGreenConstant
        channelMixerBlueRed = settings.channelMixerBlueRed
        channelMixerBlueGreen = settings.channelMixerBlueGreen
        channelMixerBlueBlue = settings.channelMixerBlueBlue
        channelMixerBlueConstant = settings.channelMixerBlueConstant
        channelMixerMonochrome = settings.channelMixerMonochrome
        channelMixerMonoRed = settings.channelMixerMonoRed
        channelMixerMonoGreen = settings.channelMixerMonoGreen
        channelMixerMonoBlue = settings.channelMixerMonoBlue
        channelMixerMonoConstant = settings.channelMixerMonoConstant
        selectedChannelMixerOutput = settings.channelMixerMonochrome ? .monochrome : .red
        selectedPhotoFilterPreset = settings.photoFilterPreset
        photoFilterDensity = settings.photoFilterDensity
        photoFilterPreserveLuminosity = settings.photoFilterPreserveLuminosity
        photoFilterCustomRed = settings.photoFilterCustomRed
        photoFilterCustomGreen = settings.photoFilterCustomGreen
        photoFilterCustomBlue = settings.photoFilterCustomBlue
        selectedColorLookupPreset = settings.colorLookupPreset
        selectedColorLookupCube = settings.colorLookupCube
        selectedSelectiveColorRange = .reds
        selectiveColorSettings = settings.selectiveColorSettings
        selectiveColorMethod = settings.selectiveColorMethod
        selectedGradientMapPreset = settings.gradientMapPreset
        gradientMapReverse = settings.gradientMapReverse
        gradientMapDither = settings.gradientMapDither
        gradientMapShadowRed = settings.gradientMapShadowRed
        gradientMapShadowGreen = settings.gradientMapShadowGreen
        gradientMapShadowBlue = settings.gradientMapShadowBlue
        gradientMapHighlightRed = settings.gradientMapHighlightRed
        gradientMapHighlightGreen = settings.gradientMapHighlightGreen
        gradientMapHighlightBlue = settings.gradientMapHighlightBlue
    }

    private func syncFilterControlsFromSelection() {
        if let smartFilter = document.selectedLayer?.smartFilters.last {
            selectedFilter = smartFilter.kind
            filterIntensity = smartFilter.normalizedIntensity
            syncFilterSettings(smartFilter.normalizedSettings)
            return
        }
        guard let filter = document.selectedLayer?.filter else { return }
        selectedFilter = filter.kind
        filterIntensity = filter.intensity
        syncFilterSettings(document.selectedLayer?.filterSettings.normalized() ?? ImageEditorFilterSettings())
    }

    private func syncFilterSettings(_ settings: ImageEditorFilterSettings) {
        let normalized = settings.normalized()
        filterUnsharpRadius = normalized.unsharpRadius
        filterUnsharpThreshold = normalized.unsharpThreshold
        filterLiquifyPushX = normalized.liquifyPushX
        filterLiquifyPushY = normalized.liquifyPushY
        filterLiquifyTwirlAngle = normalized.liquifyTwirlAngle
        filterLiquifyBulgeAmount = normalized.liquifyBulgeAmount
        filterOffsetX = normalized.offsetX
        filterOffsetY = normalized.offsetY
        filterWaveAmplitude = normalized.waveAmplitude
        filterWaveFrequency = normalized.waveFrequency
        filterRippleAmount = normalized.rippleAmount
        filterRippleFrequency = normalized.rippleFrequency
    }

    private func syncSolidColorFillControlsFromSelection() {
        guard let content = document.selectedLayer?.solidColorFillContent?.normalized() else { return }
        solidColorFillRed = content.red
        solidColorFillGreen = content.green
        solidColorFillBlue = content.blue
    }

    private func syncPatternFillControlsFromSelection() {
        guard let content = document.selectedLayer?.patternFillContent?.normalized() else { return }
        selectedPatternFillKind = content.kind
        patternFillRed = content.red
        patternFillGreen = content.green
        patternFillBlue = content.blue
        patternFillOpacity = content.opacity
        patternFillScale = Double(content.scale)
    }

    private func syncGradientFillControlsFromSelection() {
        guard let content = document.selectedLayer?.gradientFillContent?.normalized() else { return }
        selectedGradientFillPreset = content.preset
        selectedGradientFillStyle = content.style
        gradientFillReverse = content.reverse
        gradientFillAngle = Double(content.angle)
        gradientFillScale = Double(content.scale)
        gradientFillStartRed = content.startRed
        gradientFillStartGreen = content.startGreen
        gradientFillStartBlue = content.startBlue
        gradientFillEndRed = content.endRed
        gradientFillEndGreen = content.endGreen
        gradientFillEndBlue = content.endBlue
    }

    private func syncTextControlsFromSelection() {
        guard let content = document.selectedLayer?.textContent else { return }
        textValue = content.text
        textSize = Double(content.fontSize)
        foregroundColor = content.color
        textBold = content.isBold
        textItalic = content.isItalic
        textCharacterSpacing = Double(content.characterSpacing)
        textLineSpacing = Double(content.lineSpacing)
        textBoxWidth = Double(content.boxWidth)
        selectedTextAlignment = content.alignment
    }

    private func syncShapeControlsFromSelection() {
        guard let content = document.selectedLayer?.shapeContent else { return }
        foregroundColor = content.fillColor
        opacity = content.fillOpacity
        brushSize = max(1, content.strokeWidth / 0.35)
    }

    private func syncPathControlsFromSelection() {
        guard let content = document.selectedLayer?.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.contains(where: { !$0.isEmpty })
        else {
            selectedPathSubpathIndex = 0
            selectedPathAnchorIndex = nil
            selectedPathControlRole = .anchor
            return
        }
        let subpaths = content.allEditablePathSubpaths
        if let selectedPathAnchorIndex,
           subpaths.indices.contains(selectedPathSubpathIndex),
           subpaths[selectedPathSubpathIndex].indices.contains(selectedPathAnchorIndex) {
            return
        }
        selectedPathSubpathIndex = subpaths.firstIndex { !$0.isEmpty } ?? 0
        selectedPathAnchorIndex = 0
        selectedPathControlRole = .anchor
    }

    private func selectedPathControlCanvasPoint(role: ImageEditorPathControlRole) -> CGPoint? {
        guard let index = selectedPathAnchorIndex,
              let layer = document.selectedLayer,
              let content = layer.shapeContent,
              content.kind == .path,
              content.allEditablePathSubpaths.indices.contains(selectedPathSubpathIndex),
              content.allEditablePathSubpaths[selectedPathSubpathIndex].indices.contains(index)
        else { return nil }
        let anchor = content.allEditablePathSubpaths[selectedPathSubpathIndex][index]
        switch role {
        case .anchor:
            return canvasPoint(for: anchor.point, in: layer)
        case .inHandle:
            guard let inControl = anchor.inControl else { return nil }
            return canvasPoint(for: inControl, in: layer)
        case .outHandle:
            guard let outControl = anchor.outControl else { return nil }
            return canvasPoint(for: outControl, in: layer)
        }
    }

    private func canvasPoint(for localPoint: CGPoint, in layer: ImageEditorLayer) -> CGPoint {
        CGPoint(x: layer.frame.minX + localPoint.x, y: layer.frame.minY + localPoint.y)
    }

    private func addShapeLayer(frame: CGRect, kind: ImageEditorShapeKind) {
        let content = ImageEditorShapeContent(
            kind: kind,
            fillColor: foregroundColor,
            fillOpacity: opacity,
            strokeColor: foregroundColor,
            strokeWidth: max(1, min(96, brushSize * 0.35)),
            strokeOpacity: min(1, max(0.15, opacity))
        )
        pushUndo()
        var layer = ImageEditorLayer.shape(
            name: L10n.format("imageEditor.layer.shapeName", kind.title),
            frame: frame,
            content: content
        )
        layer.opacity = 1
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        selectedPathSubpathIndex = 0
        selectedPathAnchorIndex = nil
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerShapeNew"))
    }

    private func clampedTextSize(_ size: Double) -> Double {
        max(6, min(240, size))
    }

    private func clampedTextCharacterSpacing(_ spacing: Double) -> Double {
        max(-8, min(48, spacing))
    }

    private func clampedTextLineSpacing(_ spacing: Double) -> Double {
        max(0, min(96, spacing))
    }

    private func clampedTextBoxWidth(_ width: Double) -> Double {
        max(0, min(1600, width))
    }

    private func textLayerNameFragment(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(trimmed.prefix(18))
        return prefix.isEmpty ? L10n.text("imageEditor.layer.textFallbackName") : prefix
    }

    func updateStatus() {
        statusText = L10n.format("imageEditor.status.ready", sizeText, zoomText)
    }

}

extension NSImage {
    func normalizedBitmapImage() -> NSImage {
        let targetSize = size.width > 0 && size.height > 0 ? size : CGSize(width: 1, height: 1)
        let image = NSImage(size: targetSize)
        image.lockFocus()
        draw(in: CGRect(origin: .zero, size: targetSize), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        image.unlockFocus()
        return image
    }

    func rotatedClockwise() -> NSImage? {
        let outputSize = CGSize(width: size.height, height: size.width)
        return rendered(size: outputSize) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.translateBy(x: outputSize.width, y: 0)
            context.rotate(by: .pi / 2)
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            _ = rect
        }
    }

    func rotated(degrees: CGFloat) -> NSImage? {
        let radians = degrees * .pi / 180
        let sine = abs(sin(radians))
        let cosine = abs(cos(radians))
        let outputSize = CGSize(
            width: max(1, size.width * cosine + size.height * sine),
            height: max(1, size.width * sine + size.height * cosine)
        )

        return rendered(size: outputSize) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.rotate(by: radians)
            draw(
                in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
        }
    }

    func flipped(horizontal: Bool) -> NSImage? {
        rendered(size: size) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            if horizontal {
                context.translateBy(x: size.width, y: 0)
                context.scaleBy(x: -1, y: 1)
            } else {
                context.translateBy(x: 0, y: size.height)
                context.scaleBy(x: 1, y: -1)
            }
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        }
    }

    func cropped(to rect: CGRect) -> NSImage? {
        let bounded = rect.intersection(CGRect(origin: .zero, size: size))
        guard bounded.width > 0, bounded.height > 0 else { return nil }
        return rendered(size: bounded.size) { _ in
            draw(
                in: CGRect(x: -bounded.minX, y: -bounded.minY, width: size.width, height: size.height),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
        }
    }

    func withStroke(points: [CGPoint], color: NSColor, width: CGFloat, opacity: CGFloat, erase: Bool) -> NSImage? {
        rendered(size: size) { _ in
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            guard let first = points.first else { return }
            let path = NSBezierPath()
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.lineWidth = width
            path.move(to: first)
            for point in points.dropFirst() {
                path.line(to: point)
            }
            if erase, let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setStroke()
                path.stroke()
                context.restoreGState()
            } else {
                color.withAlphaComponent(opacity).setStroke()
                path.stroke()
            }
        }
    }

    func withCloneStamp(
        points: [CGPoint],
        sourceOffset: CGSize,
        sourceImage: NSImage,
        width: CGFloat,
        opacity: CGFloat
    ) -> NSImage? {
        guard let first = points.first else { return nil }
        let path = NSBezierPath()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = width
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: point)
        }

        let shiftedSource = NSImage.rendered(size: size) { _ in
            sourceImage.draw(
                in: CGRect(
                    x: -sourceOffset.width,
                    y: -sourceOffset.height,
                    width: sourceImage.size.width,
                    height: sourceImage.size.height
                ),
                from: CGRect(origin: .zero, size: sourceImage.size),
                operation: .copy,
                fraction: 1
            )
        }
        let strokeMask = NSImage.rendered(size: size) { _ in
            NSColor.white.setStroke()
            path.stroke()
        }
        guard let shiftedSource, let strokeMask else { return nil }

        let clippedStamp = NSImage.rendered(size: size) { _ in
            shiftedSource.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: shiftedSource.size),
                operation: .copy,
                fraction: 1
            )
            strokeMask.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: strokeMask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
        guard let clippedStamp else { return nil }

        return rendered(size: size) { _ in
            draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
            clippedStamp.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: clippedStamp.size),
                operation: .sourceOver,
                fraction: opacity
            )
        }
    }

    func withMaskStroke(points: [CGPoint], width: CGFloat, opacity: CGFloat, reveal: Bool) -> NSImage? {
        rendered(size: size) { _ in
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            guard let first = points.first else { return }
            let path = NSBezierPath()
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.lineWidth = width
            path.move(to: first)
            for point in points.dropFirst() {
                path.line(to: point)
            }
            if reveal {
                NSColor.white.withAlphaComponent(opacity).setStroke()
                path.stroke()
            } else if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.setBlendMode(.clear)
                NSColor.clear.setStroke()
                path.stroke()
                context.restoreGState()
            }
        }
    }

    func withShape(rect: CGRect, color: NSColor, width: CGFloat, opacity: CGFloat, ellipse: Bool) -> NSImage? {
        rendered(size: size) { _ in
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            let path = ellipse ? NSBezierPath(ovalIn: rect) : NSBezierPath(rect: rect)
            path.lineWidth = width
            color.withAlphaComponent(opacity).setStroke()
            path.stroke()
        }
    }

    func withText(_ text: String, at point: CGPoint, color: NSColor, opacity: CGFloat) -> NSImage? {
        rendered(size: size) { _ in
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(18, min(size.width, size.height) * 0.055), weight: .semibold),
                .foregroundColor: color.withAlphaComponent(opacity)
            ]
            text.draw(at: point, withAttributes: attributes)
        }
    }

    func alphaTinted(color: NSColor) -> NSImage {
        rendered(size: size) { rect in
            color.setFill()
            rect.fill()
            draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: size),
                operation: .destinationIn,
                fraction: 1
            )
        } ?? NSImage(size: size)
    }

    func blurred(radius: CGFloat) -> NSImage? {
        guard radius > 0 else { return self }
        guard let ciImage = ciImageForEditing() else { return nil }
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = ciImage.clampedToExtent()
        filter.radius = Float(radius)
        guard let output = filter.outputImage?.cropped(to: ciImage.extent),
              let cgImage = CIContext(options: nil).createCGImage(output, from: ciImage.extent)
        else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: size)
    }

    func resized(to targetSize: CGSize) -> NSImage? {
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        return rendered(size: targetSize) { _ in
            draw(
                in: CGRect(origin: .zero, size: targetSize),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
        }
    }

    func color(at point: CGPoint) -> NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let x = max(0, min(cgImage.width - 1, Int((point.x / max(size.width, 1)) * CGFloat(cgImage.width))))
        let y = max(0, min(cgImage.height - 1, Int((point.y / max(size.height, 1)) * CGFloat(cgImage.height))))
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * cgImage.height)
        guard let context = CGContext(
            data: &pixels,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(cgImage.height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        let offset = y * bytesPerRow + x * bytesPerPixel
        return NSColor(
            calibratedRed: CGFloat(pixels[offset]) / 255,
            green: CGFloat(pixels[offset + 1]) / 255,
            blue: CGFloat(pixels[offset + 2]) / 255,
            alpha: CGFloat(pixels[offset + 3]) / 255
        )
    }

    static func rendered(size outputSize: CGSize, actions: (CGRect) -> Void) -> NSImage? {
        guard outputSize.width > 0, outputSize.height > 0 else { return nil }
        let image = NSImage(size: outputSize)
        image.lockFocus()
        let rect = CGRect(origin: .zero, size: outputSize)
        let context = NSGraphicsContext.current
        context?.saveGraphicsState()
        NSColor.clear.setFill()
        rect.fill()
        actions(rect)
        context?.restoreGraphicsState()
        image.unlockFocus()
        return image
    }

    static func transparent(size outputSize: CGSize) -> NSImage {
        rendered(size: outputSize) { rect in
            NSColor.clear.setFill()
            rect.fill()
        } ?? NSImage(size: outputSize)
    }

    static func opaqueMask(size outputSize: CGSize) -> NSImage {
        rendered(size: outputSize) { rect in
            NSColor.white.setFill()
            rect.fill()
        } ?? NSImage(size: outputSize)
    }

    func thumbnailImage(targetSize: CGSize) -> NSImage {
        let scale = min(targetSize.width / max(size.width, 1), targetSize.height / max(size.height, 1))
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        return Self.rendered(size: targetSize) { rect in
            NSColor.clear.setFill()
            rect.fill()
            draw(
                in: CGRect(
                    x: (targetSize.width - drawSize.width) / 2,
                    y: (targetSize.height - drawSize.height) / 2,
                    width: drawSize.width,
                    height: drawSize.height
                ),
                from: CGRect(origin: .zero, size: size),
                operation: .sourceOver,
                fraction: 1
            )
        } ?? NSImage(size: targetSize)
    }

    private func rendered(size outputSize: CGSize, actions: (CGRect) -> Void) -> NSImage? {
        Self.rendered(size: outputSize, actions: actions)
    }
}
