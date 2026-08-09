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

enum ImageEditorClippingMaskSelectionState: Equatable {
    case off
    case on
    case mixed

    var accessibilityKey: String {
        switch self {
        case .off:
            "imageEditor.layer.clippingState.off"
        case .on:
            "imageEditor.layer.clippingState.on"
        case .mixed:
            "imageEditor.layer.clippingState.mixed"
        }
    }
}

enum ImageEditorSmartFilterValueState<Value: Equatable>: Equatable {
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

private struct ImageEditorXomoThemeUndoState {
    var theme: XomoComponentTheme
    var tokenSnapshot: XomoComponentThemeTokenSnapshot?
}

@MainActor
final class ImageEditorViewModel: ObservableObject {
    static let minimumZoom: CGFloat = 0.08
    static let maximumZoom: CGFloat = 8
    static let figmaImageFillScaleModes = ["FILL", "FIT", "CROP", "TILE", "STRETCH"]

    let canvasPointerCaptureState = ImageEditorCanvasPointerCaptureState()
    private var preservesRenderedImageCachesForNextDocumentMutation = false

    @Published var document: ImageEditorDocument {
        didSet {
            refreshSelectionEdgeGeometry()
            refreshQuickMaskOverlay()
            if preservesRenderedImageCachesForNextDocumentMutation {
                preservesRenderedImageCachesForNextDocumentMutation = false
                return
            }
            invalidateRenderedImageCaches()
        }
    }
    @Published var selectedTool: ImageEditorTool = .move
    @Published var marqueeShape: ImageEditorMarqueeShape = .rectangle
    @Published var zoom: CGFloat = 1
    @Published var canvasViewportSize: CGSize = .zero
    @Published var canvasOffset: CGSize = .zero
    private var magnifyBaseZoom: CGFloat?
    private var magnifyBaseOffset: CGSize?
    @Published var brushSize: CGFloat = 18
    @Published var opacity: CGFloat = 1
    @Published var hardness: CGFloat = 0.8
    @Published var brushFlow: CGFloat = 100
    @Published var brushSpacing: CGFloat = 25
    @Published var brushPressureControlsSize = true
    @Published var brushPressureControlsOpacity = false
    @Published var brushPressureControlsFlow = true
    @Published var brushPressureSensitivity: CGFloat = 50
    @Published var brushMinimumDiameter: CGFloat = 0
    @Published var brushMinimumOpacity: CGFloat = 0
    @Published var brushMinimumFlow: CGFloat = 0
    @Published var brushTiltControlsShape = false
    @Published var brushTipRoundness: CGFloat = 100
    @Published var brushTipAngleDegrees: CGFloat = 0
    @Published var brushSmoothing: CGFloat = 0
    @Published var retouchPressureControlsSize = false
    @Published var retouchPressureSensitivity: CGFloat = 50
    @Published var toneRange: ImageEditorToneRange = .midtones
    @Published var protectToneBrushTones = true
    @Published var toneBrushAirbrushEnabled = false
    @Published var spongeMode: ImageEditorSpongeMode = .saturate
    @Published var spongeVibranceEnabled = true
    @Published var smudgeFingerPaintingEnabled = false
    @Published var smudgeSampleAllLayersEnabled = false
    @Published private(set) var customBrushPresets: [ImageEditorBrushPreset] = []
    @Published var customLayerStylePresets: [ImageEditorLayerStylePreset] = []
    @Published var favoriteLayerStylePresetIDs: [String] = []
    @Published var recentLayerStylePresetIDs: [String] = []
    @Published var patchMode: ImageEditorPatchMode = .source
    @Published var feather: CGFloat = 0
    @Published var selectionModifyAmount: CGFloat = 4
    @Published var tolerance: CGFloat = 0.22
    @Published var selectionMode: ImageEditorSelectionMode = .replace
    @Published var isQuickMaskMode = false
    @Published private(set) var quickMaskOverlayImage: NSImage?
    @Published private(set) var selectionEdgeGeometry: ImageEditorSelectionEdgeGeometry?
    @Published private(set) var quickMaskOverlayTarget: ImageEditorQuickMaskOverlayTarget
    @Published private(set) var quickMaskOverlayColor: NSColor
    @Published private(set) var quickMaskOverlayOpacity: CGFloat
    @Published var isColorRangeSheetPresented = false
    @Published var colorRangeColor: NSColor = .systemRed
    @Published var colorRangeIncludeColors: [NSColor] = [.systemRed]
    @Published var colorRangeExcludeColors: [NSColor] = []
    @Published var colorRangeSampleMode: ImageEditorColorRangeSampleMode = .replace
    @Published var colorRangeTolerance: CGFloat = 0.22
    @Published var colorRangeInverted = false
    @Published var foregroundColor: NSColor = .black
    @Published var backgroundColor: NSColor = .white
    private var screenColorSampler: NSColorSampler?
    @Published var cloneSourcePoint: CGPoint?
    @Published var isCloneStampAligned = true {
        didSet {
            guard isCloneStampAligned != oldValue else { return }
            cloneStampAlignedCanvasOffset = nil
        }
    }
    @Published var cloneStampSampleSource: ImageEditorCloneSampleSource = .currentLayer
    @Published private(set) var isSettingCloneSource = false
    @Published var healingSourcePoint: CGPoint?
    @Published var healingBrushMode: ImageEditorHealingBrushMode = .source {
        didSet {
            guard healingBrushMode != oldValue else { return }
            isSettingHealingSource = false
            healingBrushAlignedCanvasOffset = nil
        }
    }
    @Published var isHealingBrushAligned = true {
        didSet {
            guard isHealingBrushAligned != oldValue else { return }
            healingBrushAlignedCanvasOffset = nil
        }
    }
    @Published var healingBrushSampleSource: ImageEditorCloneSampleSource = .currentLayer
    @Published private(set) var isSettingHealingSource = false
    @Published private(set) var colorSamplerPoints: [ImageEditorColorSamplerPoint] = []
    @Published var reselectableSelection: ImageEditorSelection?
    @Published var statusText: String = ""
    @Published var areToolsPanelVisible = true
    @Published var selectedLeftSidebarTab: XomoLeftSidebarTab = .tools
    @Published var xomoComponentTheme: XomoComponentTheme = .native
    @Published private(set) var xomoLocalThemeTokenSnapshot: XomoComponentThemeTokenSnapshot? = nil
    @Published var xomoActiveMasterID: UUID?
    @Published var isOptionsBarVisible = true
    @Published var isNavigatorPanelVisible = true
    @Published var isHistoryPanelVisible = true
    @Published var isLayersPanelVisible = true
    @Published var isPropertiesPanelVisible = true
    @Published var isHotspotsPanelVisible = false
    @Published var isSlicesPanelVisible = false
    @Published var selectedHotspotID: UUID?
    @Published var isStatusBarVisible = true
    @Published var historyQuery = ""
    @Published private(set) var pointerCanvasPoint: CGPoint?
    @Published var textValue: String = ""
    @Published var textSize: Double = 32
    @Published var selectedFontFamilyName: String = ImageEditorTextContent.systemFontFamilyName
    @Published var textBold: Bool = false
    @Published var textItalic: Bool = false
    @Published var textUnderlined: Bool = false
    @Published var textStruckThrough: Bool = false
    @Published var textCharacterSpacing: Double = 0
    @Published var textLineSpacing: Double = 0
    @Published var textParagraphSpacing: Double = 0
    @Published var textBoxWidth: Double = 0
    @Published var textBoxHeight: Double = 0
    @Published var selectedTextAlignment: ImageEditorTextAlignment = .left
    @Published var selectedTextCase: ImageEditorTextCase = .original
    @Published var textTruncatesOverflow: Bool = false
    @Published var selectedTextVerticalAlignment: ImageEditorTextVerticalAlignment = .top
    @Published var textLeftIndent: Double = 0
    @Published var textRightIndent: Double = 0
    @Published var textFirstLineIndent: Double = 0

    var availableFontFamilyNames: [String] {
        let families = NSFontManager.shared.availableFontFamilies.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        return families.contains(ImageEditorTextContent.systemFontFamilyName)
            ? families
            : [ImageEditorTextContent.systemFontFamilyName] + families
    }

    func fontFamilyDisplayName(_ familyName: String) -> String {
        familyName == ImageEditorTextContent.systemFontFamilyName
            ? L10n.text("imageEditor.fontFamily.system")
            : familyName
    }
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
    @Published var patternFillOffsetX: Double = 0
    @Published var patternFillOffsetY: Double = 0
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
    @Published var selectedFilter: ImageEditorFilter = .gaussianBlur {
        didSet {
            if oldValue != selectedFilter {
                filterGaussianBlurRadius = nil
            }
        }
    }
    @Published private(set) var filterPanelPresentationRequest = 0
    @Published private(set) var lastAppliedFilter: ImageEditorFilterApplication?
    @Published private(set) var loadedSmartFilterID: UUID?
    @Published var filterIntensity: Double = 0.5
    @Published private(set) var filterGaussianBlurRadius: Double?
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
    @Published var filterPinchAmount: Double = 0.5
    @Published var filterSpherizeAmount: Double = 0.5
    @Published var filterLensDistortion: Double = 0.35
    @Published var selectedHistogramSource: ImageEditorHistogramSource = .composite
    @Published var selectedHistogramChannel: ImageEditorHistogramChannel = .rgb
    @Published var selectedColorSamplerReadoutMode: ImageEditorColorSamplerReadoutMode = .rgb
    @Published private(set) var selectedColorSamplerSampleSize: ImageEditorColorSamplerSampleSize = .threeByThree
    @Published private(set) var selectedColorSamplerSource: ImageEditorColorSamplerSource = .composite
    @Published var selectedChannelPreview: ImageEditorChannelPreview = .composite
    @Published var selectedAlphaChannelID: UUID?
    @Published var previewedAlphaChannelID: UUID?
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
    @Published var isNewCanvasSheetPresented = false
    @Published var isLayerStylePresetManagerPresented = false
    @Published var isPSDCompatibilityReportPresented = false
    @Published var psdCompatibilityReport: ImageEditorPSDCompatibilityReport?
    @Published var psdCompatibilityFileName = ""
    @Published var namedHistorySnapshots: [ImageEditorHistorySnapshot] = []
    @Published var selectedHistorySnapshotID: UUID?
    @Published var selectedHistoryEntryID: UUID?

    // SwiftUI reads these values from several panels in one render pass. Keep all
    // pixel work behind one document-scoped cache rather than recompositing per view.
    private var cachedCurrentImage: NSImage?
    private var cachedPointerSampleImage: NSImage?
    private var cachedPointerSamplePixels: [UInt8] = []
    private var cachedPointerSampleWidth = 0
    private var cachedPointerSampleHeight = 0
    private var cachedSelectedLayerColorSamplerImage: (
        layerID: UUID,
        image: NSImage
    )?
    private var cachedChannelPreviewImages: [String: NSImage] = [:]
    private var cachedAlphaChannelPreviewImages: [UUID: NSImage] = [:]
    private var cachedChannelThumbnailImages: [String: NSImage] = [:]
    private var cachedAlphaChannelThumbnailImages: [UUID: NSImage] = [:]
    private var cachedHistogramSummary: ImageEditorHistogramSummary?
    private var cachedSelectedLayerHistogramSummary: (
        layerID: UUID,
        summary: ImageEditorHistogramSummary
    )?
    private var cachedSelectionHistogramSummary: (
        selection: ImageEditorSelection,
        summary: ImageEditorHistogramSummary
    )?
    var cachedLayerTransparencySelectionAvailability: Bool?
    var cachedLayerTransformContentFrames: [UUID: CGRect] = [:]
    var cachedEmptyTransformLayerIDs = Set<UUID>()

    var undoStack: [ImageEditorDocument] = []
    var redoStack: [ImageEditorDocument] = []
    private var undoXomoThemeStates: [ImageEditorXomoThemeUndoState] = []
    private var redoXomoThemeStates: [ImageEditorXomoThemeUndoState] = []
    var historySnapshots: [UUID: ImageEditorDocument] = [:]
    var movingLayerIDs = Set<UUID>()
    var movingLayerDidChange = false
    var movingLayerWasDuplicated = false
    var movingOriginalTransformFrame: CGRect?
    @Published var movingObjectPreviewFrame: CGRect?
    @Published var activeAlignmentGuides: [ImageEditorAlignmentGuide] = []
    var movingGuideID: UUID?
    var movingGuideDidChange = false
    var movingPathAnchorDidChange = false
    var resizingLayerIDs = Set<UUID>()
    var resizingOriginalFrames: [UUID: CGRect] = [:]
    var resizingOriginalParagraphTextContents: [UUID: ImageEditorTextContent] = [:]
    var resizingOriginalTransformFrame: CGRect?
    var resizingLayerDidChange = false
    var rotatingLayerIDs = Set<UUID>()
    var rotatingOriginalLayers: [UUID: ImageEditorLayer] = [:]
    var rotatingOriginalTransformFrame: CGRect?
    var rotatingReferencePoint: CGPoint?
    var rotatingReferenceWasCustom = false
    var rotatingStartAngleDegrees: CGFloat = 0
    var rotatingLayerDidChange = false
    @Published var rotatingPreviewDegrees: CGFloat?
    @Published var transformReferenceUnitPoint: CGPoint?
    var transformReferenceLayerIDs = Set<UUID>()
    var isTransformReferencePointDragActive = false
    var transformReferenceDragOriginalUnitPoint: CGPoint?
    var transformReferenceDragOriginalLayerIDs = Set<UUID>()
    var editingShapeGradientLayerID: UUID?
    var editingShapeGradientOriginalContent: ImageEditorShapeContent?
    var editingShapeGradientStopIndex: Int?
    var editingShapeGradientDidChange = false
    var copiedLayerStyle: ImageEditorLayerStyle?
    var copiedLayerStyleSourceID: UUID?
    private var cloneStampAlignedCanvasOffset: CGSize?
    private var healingBrushAlignedCanvasOffset: CGSize?
    private var layerSelectionAnchorID: UUID?
    private let onApply: (NSImage) -> Void
    private let workspacePreferencesDefaults: UserDefaults
    private var selectionEdgeGeometrySource: ImageEditorSelection?
    private var selectionEdgeGeometryCanvasSize: CGSize = .zero

    init(
        sourceName: String,
        image: NSImage,
        preferencesDefaults: UserDefaults = .standard,
        onApply: @escaping (NSImage) -> Void
    ) {
        let quickMaskPreferences = ImageEditorQuickMaskPreferences.load(from: preferencesDefaults)
        let brushDynamicsPreferences = ImageEditorBrushDynamicsPreferences.load(from: preferencesDefaults)
        let retouchDynamicsPreferences = ImageEditorRetouchDynamicsPreferences.load(from: preferencesDefaults)
        let brushPresetPreferences = ImageEditorBrushPresetPreferences.load(from: preferencesDefaults)
        let layerStylePresetPreferences = ImageEditorLayerStylePresetPreferences.load(from: preferencesDefaults)
        let layerStylePresetUsagePreferences = ImageEditorLayerStylePresetUsagePreferences.load(
            from: preferencesDefaults
        )
        document = ImageEditorDocument(sourceName: sourceName, image: image)
        self.onApply = onApply
        workspacePreferencesDefaults = preferencesDefaults
        quickMaskOverlayTarget = quickMaskPreferences.target
        quickMaskOverlayColor = quickMaskPreferences.color.nsColor
        quickMaskOverlayOpacity = CGFloat(quickMaskPreferences.opacity)
        brushPressureControlsSize = brushDynamicsPreferences.pressureControlsSize
        brushPressureControlsOpacity = brushDynamicsPreferences.pressureControlsOpacity
        brushPressureControlsFlow = brushDynamicsPreferences.pressureControlsFlow
        brushPressureSensitivity = CGFloat(brushDynamicsPreferences.pressureSensitivity)
        brushMinimumDiameter = CGFloat(brushDynamicsPreferences.minimumDiameter)
        brushMinimumOpacity = CGFloat(brushDynamicsPreferences.minimumOpacity)
        brushMinimumFlow = CGFloat(brushDynamicsPreferences.minimumFlow)
        brushTiltControlsShape = brushDynamicsPreferences.tiltControlsShape
        brushTipRoundness = CGFloat(brushDynamicsPreferences.tipRoundness)
        brushTipAngleDegrees = CGFloat(brushDynamicsPreferences.tipAngleDegrees)
        brushSmoothing = CGFloat(brushDynamicsPreferences.smoothing)
        retouchPressureControlsSize = retouchDynamicsPreferences.pressureControlsSize
        retouchPressureSensitivity = CGFloat(retouchDynamicsPreferences.pressureSensitivity)
        customBrushPresets = brushPresetPreferences.presets
        customLayerStylePresets = layerStylePresetPreferences.presets
        let knownPresetIDs = Set(
            ImageEditorLayerStyleBuiltInPresetCatalog.presets.map(\.id)
                + customLayerStylePresets.map(\.id)
        )
        let prunedUsage = layerStylePresetUsagePreferences.pruned(to: knownPresetIDs)
        favoriteLayerStylePresetIDs = prunedUsage.favoriteIDs
        recentLayerStylePresetIDs = prunedUsage.recentIDs
        cachedCurrentImage = document.layers.first?.image
        refreshSelectionEdgeGeometry()
        syncSizeControlsFromDocument()
        recordCurrentHistorySnapshot()
        updateStatus()
    }

    init(
        document: ImageEditorDocument,
        initialCompositeImage: NSImage? = nil,
        preferencesDefaults: UserDefaults = .standard,
        onApply: @escaping (NSImage) -> Void
    ) {
        let quickMaskPreferences = ImageEditorQuickMaskPreferences.load(from: preferencesDefaults)
        let brushDynamicsPreferences = ImageEditorBrushDynamicsPreferences.load(from: preferencesDefaults)
        let retouchDynamicsPreferences = ImageEditorRetouchDynamicsPreferences.load(from: preferencesDefaults)
        let brushPresetPreferences = ImageEditorBrushPresetPreferences.load(from: preferencesDefaults)
        let layerStylePresetPreferences = ImageEditorLayerStylePresetPreferences.load(from: preferencesDefaults)
        let layerStylePresetUsagePreferences = ImageEditorLayerStylePresetUsagePreferences.load(
            from: preferencesDefaults
        )
        self.document = document
        self.onApply = onApply
        workspacePreferencesDefaults = preferencesDefaults
        quickMaskOverlayTarget = quickMaskPreferences.target
        quickMaskOverlayColor = quickMaskPreferences.color.nsColor
        quickMaskOverlayOpacity = CGFloat(quickMaskPreferences.opacity)
        brushPressureControlsSize = brushDynamicsPreferences.pressureControlsSize
        brushPressureControlsOpacity = brushDynamicsPreferences.pressureControlsOpacity
        brushPressureControlsFlow = brushDynamicsPreferences.pressureControlsFlow
        brushPressureSensitivity = CGFloat(brushDynamicsPreferences.pressureSensitivity)
        brushMinimumDiameter = CGFloat(brushDynamicsPreferences.minimumDiameter)
        brushMinimumOpacity = CGFloat(brushDynamicsPreferences.minimumOpacity)
        brushMinimumFlow = CGFloat(brushDynamicsPreferences.minimumFlow)
        brushTiltControlsShape = brushDynamicsPreferences.tiltControlsShape
        brushTipRoundness = CGFloat(brushDynamicsPreferences.tipRoundness)
        brushTipAngleDegrees = CGFloat(brushDynamicsPreferences.tipAngleDegrees)
        brushSmoothing = CGFloat(brushDynamicsPreferences.smoothing)
        retouchPressureControlsSize = retouchDynamicsPreferences.pressureControlsSize
        retouchPressureSensitivity = CGFloat(retouchDynamicsPreferences.pressureSensitivity)
        customBrushPresets = brushPresetPreferences.presets
        customLayerStylePresets = layerStylePresetPreferences.presets
        let knownPresetIDs = Set(
            ImageEditorLayerStyleBuiltInPresetCatalog.presets.map(\.id)
                + customLayerStylePresets.map(\.id)
        )
        let prunedUsage = layerStylePresetUsagePreferences.pruned(to: knownPresetIDs)
        favoriteLayerStylePresetIDs = prunedUsage.favoriteIDs
        recentLayerStylePresetIDs = prunedUsage.recentIDs
        cachedCurrentImage = initialCompositeImage
        refreshSelectionEdgeGeometry()
        syncSizeControlsFromDocument()
        recordCurrentHistorySnapshot()
        updateStatus()
    }

    var currentImage: NSImage {
        if let cachedCurrentImage {
            return cachedCurrentImage
        }

        let image = document.compositedImage
        cachedCurrentImage = image
        return image
    }

    func createCanvas(from draft: XomoCanvasDraft) {
        let canvasSize = draft.canvasSize
        let canvas = NSImage.rendered(size: canvasSize) { rect in
            draft.background.color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: canvasSize)
        var newDocument = ImageEditorDocument(
            sourceName: L10n.text("xomo.newCanvas.untitledName"),
            image: canvas
        )
        newDocument.isGridVisible = true
        newDocument.isGridSnappingEnabled = true
        newDocument.gridSpacing = XomoCanvasDraft.defaultGridSpacing
        newDocument.designCanvasMetadata = XomoDesignCanvasMetadata(draft: draft)

        document = newDocument
        colorSamplerPoints.removeAll()
        psdCompatibilityReport = nil
        psdCompatibilityFileName = ""
        isPSDCompatibilityReportPresented = false
        cachedCurrentImage = canvas
        exportSettings.scale = Double(draft.clampedExportScale)
        clearUndoHistory()
        historySnapshots.removeAll()
        namedHistorySnapshots.removeAll()
        selectedHistorySnapshotID = nil
        selectedHistoryEntryID = nil
        zoom = 1
        canvasOffset = .zero
        syncSizeControlsFromDocument()
        recordCurrentHistorySnapshot()
        statusText = L10n.format(
            "xomo.newCanvas.createdStatus",
            Int(canvasSize.width),
            Int(canvasSize.height),
            draft.clampedExportScale
        )
    }

    var canCreateCanvasFromClipboard: Bool {
        NSPasteboard.general.readImage() != nil
    }

    func createCanvasFromClipboard(from pasteboard: NSPasteboard = .general) {
        guard let image = pasteboard.readImage() else {
            statusText = L10n.text("imageEditor.status.clipboardImageMissing")
            return
        }

        let normalized = image.normalizedBitmapImage()
        guard normalized.size.width > 0, normalized.size.height > 0 else {
            statusText = L10n.text("imageEditor.status.layerImportFailed")
            return
        }

        document = ImageEditorDocument(
            sourceName: L10n.text("source.clipboard"),
            image: normalized
        )
        colorSamplerPoints.removeAll()
        psdCompatibilityReport = nil
        psdCompatibilityFileName = ""
        isPSDCompatibilityReportPresented = false
        cachedCurrentImage = normalized
        exportSettings.scale = 1
        selectedTool = .move
        selectedChannelPreview = .composite
        previewedAlphaChannelID = nil
        isEditingLayerMask = false
        isQuickMaskMode = false
        clearUndoHistory()
        historySnapshots.removeAll()
        namedHistorySnapshots.removeAll()
        selectedHistorySnapshotID = nil
        selectedHistoryEntryID = nil
        zoom = 1
        canvasOffset = .zero
        syncSizeControlsFromDocument()
        recordCurrentHistorySnapshot()
        statusText = L10n.format(
            "imageEditor.status.clipboardCanvasCreated",
            Int(normalized.size.width),
            Int(normalized.size.height)
        )
    }

    var previewImage: NSImage {
        if let previewedAlphaChannel {
            return alphaChannelPreviewImage(previewedAlphaChannel)
        }
        return channelPreviewImage(for: selectedChannelPreview)
    }

    func channelPreviewImage(for channel: ImageEditorChannelPreview) -> NSImage {
        let key = channel.rawValue
        if let image = cachedChannelPreviewImages[key] {
            return image
        }

        let image = currentImage.channelPreview(channel)
        cachedChannelPreviewImages[key] = image
        return image
    }

    func channelThumbnailImage(for channel: ImageEditorChannelPreview) -> NSImage {
        let key = channel.rawValue
        if let image = cachedChannelThumbnailImages[key] {
            return image
        }

        let image = currentImage
            .thumbnailImage(targetSize: Self.channelThumbnailSize)
            .channelPreview(channel)
        cachedChannelThumbnailImages[key] = image
        return image
    }

    func alphaChannelThumbnailImage(_ channel: ImageEditorAlphaChannel) -> NSImage {
        if let image = cachedAlphaChannelThumbnailImages[channel.id] {
            return image
        }

        let image = channel.mask.grayscaleThumbnailImage(targetSize: Self.channelThumbnailSize)
        cachedAlphaChannelThumbnailImages[channel.id] = image
        return image
    }

    func selectChannelPreview(_ channel: ImageEditorChannelPreview) {
        selectedChannelPreview = channel
        previewedAlphaChannelID = nil
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

    var filteredHistoryEntries: [ImageEditorHistoryEntry] {
        let query = historyQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return document.history }
        return document.history.filter { entry in
            entry.title.localizedCaseInsensitiveContains(query)
        }
    }

    var filteredHistorySnapshots: [ImageEditorHistorySnapshot] {
        let query = historyQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return namedHistorySnapshots }
        return namedHistorySnapshots.filter { snapshot in
            snapshot.name.localizedCaseInsensitiveContains(query)
        }
    }

    var canTruncateSelectedHistory: Bool {
        guard let selectedHistoryEntryID,
              let index = document.history.firstIndex(where: { $0.id == selectedHistoryEntryID }),
              index > 0
        else { return false }
        return historySnapshots[document.history[index - 1].id] != nil
    }

    var selectedHistorySnapshot: ImageEditorHistorySnapshot? {
        guard let selectedHistorySnapshotID else { return nil }
        return namedHistorySnapshots.first { $0.id == selectedHistorySnapshotID }
    }

    var canRestoreSelectedHistorySnapshot: Bool {
        selectedHistorySnapshot != nil
    }

    var canDuplicateSelectedHistorySnapshot: Bool {
        selectedHistorySnapshot != nil
    }

    var canDeleteSelectedHistorySnapshot: Bool {
        selectedHistorySnapshot != nil
    }

    var canSelectPreviousHistorySnapshot: Bool {
        selectedHistorySnapshotIndex.map { $0 > 0 } ?? false
    }

    var canSelectNextHistorySnapshot: Bool {
        selectedHistorySnapshotIndex.map { $0 < namedHistorySnapshots.count - 1 } ?? false
    }

    var zoomText: String {
        "\(Int((zoom * 100).rounded()))%"
    }

    var sizeText: String {
        let size = document.canvasSize
        return "\(Int(size.width.rounded())) x \(Int(size.height.rounded())) px"
    }

    var selectionBoundsInfoText: String {
        guard let selection = document.selection else {
            return L10n.text("imageEditor.info.selection.empty")
        }
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        let candidateBounds = selection.isInverted
            ? canvasBounds
            : selection.bounds.standardized.intersection(canvasBounds)
        guard !candidateBounds.isNull, !candidateBounds.isEmpty else {
            return L10n.text("imageEditor.info.selection.empty")
        }
        let pixelBounds = candidateBounds.integral
        return L10n.format(
            "imageEditor.info.selection.bounds",
            Int(pixelBounds.minX),
            Int(pixelBounds.minY),
            Int(pixelBounds.width),
            Int(pixelBounds.height)
        )
    }

    var activeHistogramSource: ImageEditorHistogramSource {
        canInspectHistogramSource(selectedHistogramSource) ? selectedHistogramSource : .composite
    }

    var histogramSummary: ImageEditorHistogramSummary {
        histogramSummary(for: activeHistogramSource)
    }

    func canInspectHistogramSource(_ source: ImageEditorHistogramSource) -> Bool {
        switch source {
        case .composite:
            return true
        case .selectedLayer:
            guard let layer = document.selectedLayer else { return false }
            return layer.isGroup || (!layer.isAdjustment && !layer.isFilter)
        case .selection:
            return canExportSelection
        }
    }

    func histogramSummary(for source: ImageEditorHistogramSource) -> ImageEditorHistogramSummary {
        guard canInspectHistogramSource(source) else { return .empty }

        switch source {
        case .composite:
            if let cachedHistogramSummary {
                return cachedHistogramSummary
            }
            let summary = currentImage.histogramSummary()
            cachedHistogramSummary = summary
            return summary
        case .selectedLayer:
            guard let layer = document.selectedLayer else { return .empty }
            if let cachedSelectedLayerHistogramSummary,
               cachedSelectedLayerHistogramSummary.layerID == layer.id {
                return cachedSelectedLayerHistogramSummary.summary
            }
            let image = layer.isGroup
                ? document.compositedImage(includingOnly: [layer.id])
                : selectedLayerExportImage()
            let summary = image?.histogramSummary() ?? .empty
            cachedSelectedLayerHistogramSummary = (layer.id, summary)
            return summary
        case .selection:
            guard let selection = document.selection else { return .empty }
            if let cachedSelectionHistogramSummary,
               cachedSelectionHistogramSummary.selection == selection {
                return cachedSelectionHistogramSummary.summary
            }
            let summary = selectedSelectionExportImage()?.histogramSummary() ?? .empty
            cachedSelectionHistogramSummary = (selection, summary)
            return summary
        }
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

    func selectedHistogramChannelAverageText(for summary: ImageEditorHistogramSummary) -> String {
        switch selectedHistogramChannel {
        case .rgb:
            return histogramAverageText(for: summary)
        case .luminance:
            return histogramLuminanceText(for: summary)
        case .red, .green, .blue:
            return L10n.format(
                "imageEditor.histogram.selectedChannelAverage",
                selectedHistogramChannel.title,
                Int(selectedHistogramChannel.average(in: summary).rounded())
            )
        }
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

    func selectedHistogramStatisticsText(for summary: ImageEditorHistogramSummary) -> String {
        L10n.format(
            "imageEditor.histogram.statistics",
            selectedHistogramChannel.title,
            Int(selectedHistogramChannel.median(in: summary).rounded()),
            selectedHistogramChannel.standardDeviation(in: summary)
        )
    }

    func histogramPixelCountText(for summary: ImageEditorHistogramSummary) -> String {
        L10n.format(
            "imageEditor.histogram.pixelCount",
            summary.pixelCount,
            summary.sampledPixelCount
        )
    }

    func histogramProbeText(
        for summary: ImageEditorHistogramSummary,
        binIndex: Int?,
        selectedRange: ClosedRange<Int>? = nil
    ) -> String {
        if let selectedRange,
           let probe = summary.rangeProbe(
               channel: selectedHistogramChannel,
               lowerBinIndex: selectedRange.lowerBound,
               upperBinIndex: selectedRange.upperBound
           ) {
            return L10n.format(
                "imageEditor.histogram.rangeProbe",
                probe.lowerLevel,
                probe.upperLevel,
                probe.count,
                probe.percentage * 100
            )
        }
        guard let binIndex,
              let probe = summary.probe(
                channel: selectedHistogramChannel,
                binIndex: binIndex
              )
        else {
            return L10n.text("imageEditor.histogram.probe.empty")
        }
        return L10n.format(
            "imageEditor.histogram.probe",
            probe.lowerLevel,
            probe.upperLevel,
            probe.count,
            probe.percentile * 100
        )
    }

    var pointerText: String {
        guard let point = pointerCanvasPoint else {
            return L10n.text("imageEditor.info.pointer.coordinates.empty")
        }
        return L10n.format(
            "imageEditor.info.pointer.coordinates",
            Int(point.x),
            Int(point.y)
        )
    }

    var pointerColorInfoText: String {
        guard let point = pointerCanvasPoint,
              let color = sampledCanvasColor(
                at: point,
                sampleSize: selectedColorSamplerSampleSize,
                source: activeColorSamplerSource
              )
        else {
            return L10n.text("imageEditor.info.pointer.empty")
        }

        let reading = ImageEditorColorSamplerReading(color: color)
        switch selectedColorSamplerReadoutMode {
        case .rgb:
            return L10n.format(
                "imageEditor.info.pointer.rgb",
                Int(point.x),
                Int(point.y),
                reading.red8,
                reading.green8,
                reading.blue8,
                reading.alpha8
            )
        case .hsb:
            return L10n.format(
                "imageEditor.info.pointer.hsb",
                Int(point.x),
                Int(point.y),
                reading.hueDegrees,
                reading.saturationPercent,
                reading.brightnessPercent,
                reading.alphaPercent
            )
        case .cmyk:
            return L10n.format(
                "imageEditor.info.pointer.cmyk",
                Int(point.x),
                Int(point.y),
                reading.cyanPercent,
                reading.magentaPercent,
                reading.yellowPercent,
                reading.keyPercent,
                reading.alphaPercent
            )
        case .hexadecimal:
            return L10n.format(
                "imageEditor.info.pointer.hexadecimal",
                Int(point.x),
                Int(point.y),
                reading.hexadecimalRGBA
            )
        }
    }

    func colorSamplerInfoText(
        index: Int,
        sample: ImageEditorColorSamplerPoint,
        mode requestedMode: ImageEditorColorSamplerReadoutMode? = nil
    ) -> String {
        let reading = ImageEditorColorSamplerReading(color: sample.color)
        let mode = requestedMode ?? selectedColorSamplerReadoutMode
        let sharedArguments: [CVarArg] = [
            index + 1,
            Int(sample.point.x.rounded()),
            Int(sample.point.y.rounded())
        ]

        switch mode {
        case .rgb:
            return String(
                format: L10n.text("imageEditor.info.colorSampler"),
                locale: Locale.current,
                arguments: sharedArguments + [
                    reading.red8,
                    reading.green8,
                    reading.blue8,
                    reading.alpha8
                ]
            )
        case .hsb:
            return String(
                format: L10n.text("imageEditor.info.colorSampler.hsb"),
                locale: Locale.current,
                arguments: sharedArguments + [
                    reading.hueDegrees,
                    reading.saturationPercent,
                    reading.brightnessPercent,
                    reading.alphaPercent
                ]
            )
        case .cmyk:
            return String(
                format: L10n.text("imageEditor.info.colorSampler.cmyk"),
                locale: Locale.current,
                arguments: sharedArguments + [
                    reading.cyanPercent,
                    reading.magentaPercent,
                    reading.yellowPercent,
                    reading.keyPercent,
                    reading.alphaPercent
                ]
            )
        case .hexadecimal:
            return String(
                format: L10n.text("imageEditor.info.colorSampler.hexadecimal"),
                locale: Locale.current,
                arguments: sharedArguments + [reading.hexadecimalRGBA]
            )
        }
    }

    func selectColorSamplerSampleSize(
        _ sampleSize: ImageEditorColorSamplerSampleSize
    ) {
        guard sampleSize != selectedColorSamplerSampleSize else { return }
        selectedColorSamplerSampleSize = sampleSize
        refreshColorSamplers()
    }

    var activeColorSamplerSource: ImageEditorColorSamplerSource {
        canSampleColorSamplerSource(selectedColorSamplerSource)
            ? selectedColorSamplerSource
            : .composite
    }

    func canSampleColorSamplerSource(
        _ source: ImageEditorColorSamplerSource
    ) -> Bool {
        switch source {
        case .composite:
            return true
        case .selectedLayer:
            guard let layer = document.selectedLayer else { return false }
            return layer.isGroup || (!layer.isAdjustment && !layer.isFilter)
        }
    }

    @discardableResult
    func selectColorSamplerSource(
        _ source: ImageEditorColorSamplerSource
    ) -> Bool {
        guard canSampleColorSamplerSource(source) else { return false }
        guard source != selectedColorSamplerSource else { return true }
        selectedColorSamplerSource = source
        refreshColorSamplers()
        return true
    }

    private func colorSamplerImage(
        for source: ImageEditorColorSamplerSource
    ) -> NSImage? {
        switch source {
        case .composite:
            return currentImage
        case .selectedLayer:
            guard canSampleColorSamplerSource(source),
                  let layer = document.selectedLayer
            else { return nil }
            if let cachedSelectedLayerColorSamplerImage,
               cachedSelectedLayerColorSamplerImage.layerID == layer.id {
                return cachedSelectedLayerColorSamplerImage.image
            }
            let image = layer.isGroup
                ? document.compositedImage(includingOnly: [layer.id])
                : selectedLayerExportImage()
            guard let image else { return nil }
            cachedSelectedLayerColorSamplerImage = (layer.id, image)
            return image
        }
    }

    private func sampledCanvasColor(
        at point: CGPoint,
        sampleSize: ImageEditorColorSamplerSampleSize,
        source: ImageEditorColorSamplerSource
    ) -> NSColor? {
        guard let image = colorSamplerImage(for: source) else { return nil }
        if cachedPointerSampleImage !== image {
            guard let cgImage = image.cgImage(
                forProposedRect: nil,
                context: nil,
                hints: nil
            ),
            cgImage.width > 0,
            cgImage.height > 0
            else {
                resetPointerSampleCache()
                return nil
            }

            let sampleWidth = max(Int(image.size.width.rounded()), 1)
            let sampleHeight = max(Int(image.size.height.rounded()), 1)
            let bytesPerPixel = 4
            let bytesPerRow = sampleWidth * bytesPerPixel
            var pixels = [UInt8](
                repeating: 0,
                count: bytesPerRow * sampleHeight
            )
            guard let context = CGContext(
                data: &pixels,
                width: sampleWidth,
                height: sampleHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                resetPointerSampleCache()
                return nil
            }
            context.interpolationQuality = .none
            context.draw(
                cgImage,
                in: CGRect(
                    x: 0,
                    y: 0,
                    width: sampleWidth,
                    height: sampleHeight
                )
            )

            cachedPointerSampleImage = image
            cachedPointerSamplePixels = pixels
            cachedPointerSampleWidth = sampleWidth
            cachedPointerSampleHeight = sampleHeight
        }

        guard cachedPointerSampleWidth > 0,
              cachedPointerSampleHeight > 0,
              !cachedPointerSamplePixels.isEmpty
        else { return nil }
        let x = min(
            max(
                Int(
                    point.x / max(image.size.width, 1)
                        * CGFloat(cachedPointerSampleWidth)
                ),
                0
            ),
            cachedPointerSampleWidth - 1
        )
        let y = min(
            max(
                Int(
                    point.y / max(image.size.height, 1)
                        * CGFloat(cachedPointerSampleHeight)
                ),
                0
            ),
            cachedPointerSampleHeight - 1
        )
        let radius = sampleSize.dimension / 2
        var red = 0
        var green = 0
        var blue = 0
        var alpha = 0
        var sampleCount = 0
        for yOffset in -radius...radius {
            let sampledY = min(max(y + yOffset, 0), cachedPointerSampleHeight - 1)
            for xOffset in -radius...radius {
                let sampledX = min(max(x + xOffset, 0), cachedPointerSampleWidth - 1)
                let offset = (
                    sampledY * cachedPointerSampleWidth + sampledX
                ) * 4
                guard offset + 3 < cachedPointerSamplePixels.count else {
                    continue
                }
                red += Int(cachedPointerSamplePixels[offset])
                green += Int(cachedPointerSamplePixels[offset + 1])
                blue += Int(cachedPointerSamplePixels[offset + 2])
                alpha += Int(cachedPointerSamplePixels[offset + 3])
                sampleCount += 1
            }
        }
        guard sampleCount > 0 else { return nil }
        let divisor = CGFloat(sampleCount * 255)
        return NSColor(
            deviceRed: CGFloat(red) / divisor,
            green: CGFloat(green) / divisor,
            blue: CGFloat(blue) / divisor,
            alpha: CGFloat(alpha) / divisor
        )
    }

    private func resetPointerSampleCache() {
        cachedPointerSampleImage = nil
        cachedPointerSamplePixels.removeAll(keepingCapacity: false)
        cachedPointerSampleWidth = 0
        cachedPointerSampleHeight = 0
        cachedSelectedLayerColorSamplerImage = nil
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
        selectedLayerIndices.contains { canSetLayerFillOpacity(document.layers[$0]) }
    }

    var canEditSelectedLayerBlendIf: Bool {
        selectedLayerIndices.contains { canSetLayerBlendIf(document.layers[$0]) }
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
        selectedLayerIndices.contains { canSetLayerMaskProperties(document.layers[$0]) }
    }

    var selectedLayerBlendMode: ImageEditorBlendMode {
        guard let layer = document.selectedLayer else { return .normal }
        return layer.blendMode
    }

    var selectedLayerBlendModes: [ImageEditorBlendMode] {
        let indices = selectedLayerIndices
        guard !indices.isEmpty else { return [.normal] }
        let canUsePassThrough = indices.allSatisfy { document.layers[$0].isGroup }
        return ImageEditorBlendMode.allCases.filter { canUsePassThrough || $0 != .passThrough }
    }

    var selectedLayerName: String {
        document.selectedLayer?.name ?? ""
    }

    var selectedLayerFigmaVariableBindings: [XomoFigmaVariableBinding] {
        document.selectedLayer?.xomoFigmaVariableBindings ?? []
    }

    var selectedLayersFigmaVariableBindings: [XomoFigmaVariableBinding] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        var seen = Set<String>()
        return document.layers
            .filter { selectedIDs.contains($0.id) }
            .flatMap(\.xomoFigmaVariableBindings)
            .filter { seen.insert($0.id).inserted }
    }

    var hasSelectedLayerFigmaVariableBindings: Bool {
        !selectedLayerFigmaVariableBindings.isEmpty
    }

    var selectedLayerFigmaSourceID: String? {
        document.selectedLayer?.xomoFigmaSourceID
    }

    var selectedLayerFigmaNodeType: String? {
        document.selectedLayer?.xomoFigmaNodeType
    }

    var selectedLayerFigmaSizeConstraints: XomoFigmaSizeConstraints? {
        document.selectedLayer?.xomoFigmaSizeConstraints
    }

    var selectedLayerFigmaComponentRole: XomoFigmaComponentRole? {
        document.selectedLayer?.xomoFigmaComponentRole
    }

    var selectedLayerFigmaImageFill: XomoFigmaImageFillMetadata? {
        document.selectedLayer?.xomoFigmaImageFill
    }

    var selectedLayerFigmaImageFillScaleMode: String {
        selectedLayerFigmaImageFill?.scaleMode ?? "FILL"
    }

    var selectedLayerFigmaImageFillScalingFactor: Double {
        selectedLayerFigmaImageFill?.scalingFactor ?? 1
    }

    var selectedLayerFigmaImageFillRotation: Double {
        selectedLayerFigmaImageFill?.rotation ?? 0
    }

    var selectedLayerFigmaImageFillOffsetX: Double {
        selectedLayerFigmaImageFill?.imageTransform?.translationX ?? 0
    }

    var selectedLayerFigmaImageFillOffsetY: Double {
        selectedLayerFigmaImageFill?.imageTransform?.translationY ?? 0
    }

    var selectedLayerFigmaImageFillMatrixM11: Double {
        selectedLayerFigmaImageFill?.imageTransform?.m11 ?? 1
    }

    var selectedLayerFigmaImageFillMatrixM12: Double {
        selectedLayerFigmaImageFill?.imageTransform?.m12 ?? 0
    }

    var selectedLayerFigmaImageFillMatrixM21: Double {
        selectedLayerFigmaImageFill?.imageTransform?.m21 ?? 0
    }

    var selectedLayerFigmaImageFillMatrixM22: Double {
        selectedLayerFigmaImageFill?.imageTransform?.m22 ?? 1
    }

    var canEditSelectedFigmaImageFill: Bool {
        document.selectedLayer?.xomoFigmaImageFill != nil
            && document.selectedLayer?.xomoFigmaImageFillSourceImage != nil
    }

    var selectedLayerFigmaImageFillFiltersEnabled: Bool {
        document.selectedLayer?.xomoFigmaImageFillFiltersEnabled ?? false
    }

    var selectedLayerFigmaComponentProperties: [String: XomoFigmaComponentProperty] {
        document.selectedLayer?.xomoFigmaComponentProperties ?? [:]
    }

    var selectedLayerFigmaComponentPropertyDefaults: [String: XomoFigmaComponentProperty] {
        document.selectedLayer?.xomoFigmaComponentPropertyDefaults ?? [:]
    }

    var hasSelectedLayerFigmaComponentProperties: Bool {
        !selectedLayerFigmaComponentProperties.isEmpty
    }

    func hasSelectedFigmaComponentPropertyOverride(
        _ key: String,
        property: XomoFigmaComponentProperty
    ) -> Bool {
        guard let defaultProperty = selectedLayerFigmaComponentPropertyDefaults[key] else {
            return false
        }
        return defaultProperty != property
    }

    func updateSelectedFigmaComponentProperty(_ key: String, value: String) {
        guard let index = document.selectedLayerIndex,
              var property = document.layers[index].xomoFigmaComponentProperties[key]
        else { return }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (property.type == "TEXT" || !normalizedValue.isEmpty),
              property.value != normalizedValue
        else { return }
        pushUndo()
        let previousValue = property.value
        property.value = normalizedValue
        var defaults = document.layers[index].xomoFigmaComponentPropertyDefaults
        if defaults[key] == nil {
            defaults[key] = document.layers[index].xomoFigmaComponentProperties[key]
        }
        let textOverrideIndices: [Int]
        if property.type == "TEXT" {
            let descendantIDs = document.layers[index].isGroup
                ? groupDescendantIDs(for: document.layers[index].id)
                : []
            textOverrideIndices = document.layers.indices.filter { candidateIndex in
                let candidate = document.layers[candidateIndex]
                let belongsToSelectedComponent = candidateIndex == index || descendantIDs.contains(candidate.id)
                return belongsToSelectedComponent
                    && candidate.isText
                    && candidate.textContent?.text == previousValue
                    && !document.isEffectivelyPixelsLocked(candidate)
            }
        } else {
            textOverrideIndices = []
        }
        mutateDocumentWithoutInvalidatingRenderedImageCaches { document in
            document.layers[index].xomoFigmaComponentProperties[key] = property
            document.layers[index].xomoFigmaComponentPropertyDefaults = defaults
            for textIndex in textOverrideIndices {
                guard var content = document.layers[textIndex].textContent else { continue }
                content.text = normalizedValue
                let layerSize = content.layerSize()
                if let mask = document.layers[textIndex].mask, mask.size != layerSize {
                    document.layers[textIndex].mask = mask.resized(to: layerSize)
                }
                document.layers[textIndex].image = NSImage.transparent(size: layerSize)
                document.layers[textIndex].frame.size = layerSize
                document.layers[textIndex].kind = .text(content)
                document.layers[textIndex].name = L10n.format(
                    "imageEditor.layer.textName",
                    textLayerNameFragment(content.text)
                )
            }
        }
        appendHistory(L10n.format("imageEditor.history.figmaComponentPropertyChanged", key))
        statusText = L10n.format("imageEditor.status.figmaComponentPropertyUpdated", key)
    }

    func resetSelectedFigmaComponentProperty(_ key: String) {
        guard let defaultProperty = selectedLayerFigmaComponentPropertyDefaults[key] else { return }
        updateSelectedFigmaComponentProperty(key, value: defaultProperty.value)
    }

    func updateSelectedFigmaComponentBooleanProperty(_ key: String, isEnabled: Bool) {
        updateSelectedFigmaComponentProperty(key, value: isEnabled ? "true" : "false")
    }

    var selectedLayerFigmaSourceURL: URL? {
        document.selectedLayer?.xomoFigmaSourceURL
    }

    func copySelectedFigmaSourceReference() {
        guard let sourceID = selectedLayerFigmaSourceID,
              !sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        let nodeType = selectedLayerFigmaNodeType ?? ""
        let value = nodeType.isEmpty ? sourceID : "\(nodeType):\(sourceID)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        statusText = L10n.text("imageEditor.status.figmaSourceCopied")
    }

    func copySelectedFigmaSourceURL() {
        guard let url = selectedLayerFigmaSourceURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        statusText = L10n.text("imageEditor.status.figmaSourceURLCopied")
    }

    func copySelectedFigmaImageFill() {
        guard let metadata = selectedLayerFigmaImageFill else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(metadata)
            guard let value = String(data: data, encoding: .utf8) else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            statusText = L10n.text("imageEditor.status.figmaImageFillCopied")
        } catch {
            statusText = L10n.text("imageEditor.status.figmaImageFillCopyFailed")
        }
    }

    func updateSelectedFigmaImageFillScaleMode(_ scaleMode: String) {
        let normalizedMode = scaleMode.uppercased()
        guard Self.figmaImageFillScaleModes.contains(normalizedMode),
              let index = document.selectedLayerIndex,
              var metadata = document.layers[index].xomoFigmaImageFill,
              document.layers[index].xomoFigmaImageFillSourceImage != nil,
              metadata.scaleMode != normalizedMode
        else { return }
        pushUndo()
        metadata.scaleMode = normalizedMode
        document.layers[index].xomoFigmaImageFill = metadata
        appendHistory(L10n.text("imageEditor.history.figmaImageFillScaleMode"))
        statusText = L10n.text("imageEditor.status.figmaImageFillScaleMode")
    }

    func updateSelectedFigmaImageFillScalingFactor(_ scalingFactor: Double) {
        let normalizedFactor = min(max(scalingFactor.isFinite ? scalingFactor : 1, 0.01), 100)
        guard let index = document.selectedLayerIndex,
              var metadata = document.layers[index].xomoFigmaImageFill,
              document.layers[index].xomoFigmaImageFillSourceImage != nil,
              abs((metadata.scalingFactor ?? 1) - normalizedFactor) > 0.0001
        else { return }
        pushUndo()
        metadata.scalingFactor = normalizedFactor
        document.layers[index].xomoFigmaImageFill = metadata
        appendHistory(L10n.text("imageEditor.history.figmaImageFillScalingFactor"))
        statusText = L10n.text("imageEditor.status.figmaImageFillScalingFactor")
    }

    func updateSelectedFigmaImageFillRotation(_ rotation: Double) {
        let normalizedRotation = rotation.isFinite ? rotation : 0
        guard let index = document.selectedLayerIndex,
              var metadata = document.layers[index].xomoFigmaImageFill,
              document.layers[index].xomoFigmaImageFillSourceImage != nil,
              abs((metadata.rotation ?? 0) - normalizedRotation) > 0.0001
        else { return }
        pushUndo()
        metadata.rotation = normalizedRotation
        document.layers[index].xomoFigmaImageFill = metadata
        appendHistory(L10n.text("imageEditor.history.figmaImageFillRotation"))
        statusText = L10n.text("imageEditor.status.figmaImageFillRotation")
    }

    func updateSelectedFigmaImageFillOffsetX(_ offset: Double) {
        updateSelectedFigmaImageFillTransform(
            field: .offsetX,
            value: offset
        )
    }

    func updateSelectedFigmaImageFillOffsetY(_ offset: Double) {
        updateSelectedFigmaImageFillTransform(
            field: .offsetY,
            value: offset
        )
    }

    func updateSelectedFigmaImageFillMatrixM11(_ value: Double) {
        updateSelectedFigmaImageFillTransform(field: .m11, value: value)
    }

    func updateSelectedFigmaImageFillMatrixM12(_ value: Double) {
        updateSelectedFigmaImageFillTransform(field: .m12, value: value)
    }

    func updateSelectedFigmaImageFillMatrixM21(_ value: Double) {
        updateSelectedFigmaImageFillTransform(field: .m21, value: value)
    }

    func updateSelectedFigmaImageFillMatrixM22(_ value: Double) {
        updateSelectedFigmaImageFillTransform(field: .m22, value: value)
    }

    private enum FigmaImageFillTransformField {
        case offsetX
        case offsetY
        case m11
        case m12
        case m21
        case m22

        var historyKey: String {
            switch self {
            case .offsetX: return "imageEditor.history.figmaImageFillOffsetX"
            case .offsetY: return "imageEditor.history.figmaImageFillOffsetY"
            case .m11: return "imageEditor.history.figmaImageFillMatrixM11"
            case .m12: return "imageEditor.history.figmaImageFillMatrixM12"
            case .m21: return "imageEditor.history.figmaImageFillMatrixM21"
            case .m22: return "imageEditor.history.figmaImageFillMatrixM22"
            }
        }

        var statusKey: String {
            switch self {
            case .offsetX: return "imageEditor.status.figmaImageFillOffsetX"
            case .offsetY: return "imageEditor.status.figmaImageFillOffsetY"
            case .m11: return "imageEditor.status.figmaImageFillMatrixM11"
            case .m12: return "imageEditor.status.figmaImageFillMatrixM12"
            case .m21: return "imageEditor.status.figmaImageFillMatrixM21"
            case .m22: return "imageEditor.status.figmaImageFillMatrixM22"
            }
        }
    }

    private func updateSelectedFigmaImageFillTransform(
        field: FigmaImageFillTransformField,
        value: Double
    ) {
        let normalizedValue = min(max(value.isFinite ? value : 0, -10), 10)
        guard let index = document.selectedLayerIndex,
              var metadata = document.layers[index].xomoFigmaImageFill,
              document.layers[index].xomoFigmaImageFillSourceImage != nil
        else { return }

        let identity = XomoFigmaPlanTransform([[1, 0, 0], [0, 1, 0]])!
        var nextTransform = metadata.imageTransform ?? identity
        switch field {
        case .offsetX:
            nextTransform.translationX = normalizedValue
        case .offsetY:
            nextTransform.translationY = normalizedValue
        case .m11:
            nextTransform.m11 = normalizedValue
        case .m12:
            nextTransform.m12 = normalizedValue
        case .m21:
            nextTransform.m21 = normalizedValue
        case .m22:
            nextTransform.m22 = normalizedValue
        }
        let nextImageTransform = isIdentityFigmaImageFillTransform(nextTransform)
            ? nil
            : nextTransform
        guard nextImageTransform != metadata.imageTransform else { return }

        pushUndo()
        metadata.imageTransform = nextImageTransform
        document.layers[index].xomoFigmaImageFill = metadata
        appendHistory(L10n.text(field.historyKey))
        statusText = L10n.text(field.statusKey)
    }

    private func isIdentityFigmaImageFillTransform(_ transform: XomoFigmaPlanTransform) -> Bool {
        let epsilon = 0.000_001
        return abs(transform.m11 - 1) <= epsilon
            && abs(transform.m12) <= epsilon
            && abs(transform.m21) <= epsilon
            && abs(transform.m22 - 1) <= epsilon
            && abs(transform.translationX) <= epsilon
            && abs(transform.translationY) <= epsilon
    }

    func setSelectedFigmaImageFillFiltersEnabled(_ isEnabled: Bool) {
        guard let index = document.selectedLayerIndex,
              document.layers[index].xomoFigmaImageFill != nil,
              document.layers[index].xomoFigmaImageFillFiltersEnabled != isEnabled
        else { return }
        pushUndo()
        document.layers[index].xomoFigmaImageFillFiltersEnabled = isEnabled
        appendHistory(L10n.text(isEnabled
            ? "imageEditor.history.figmaImageFillFiltersEnabled"
            : "imageEditor.history.figmaImageFillFiltersDisabled"))
        statusText = L10n.text(isEnabled
            ? "imageEditor.status.figmaImageFillFiltersEnabled"
            : "imageEditor.status.figmaImageFillFiltersDisabled")
    }

    func copySelectedFigmaComponentProperties() {
        guard hasSelectedLayerFigmaComponentProperties else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(selectedLayerFigmaComponentProperties)
            guard let value = String(data: data, encoding: .utf8) else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            statusText = L10n.text("imageEditor.status.figmaComponentPropertiesCopied")
        } catch {
            statusText = L10n.text("imageEditor.status.figmaComponentPropertiesCopyFailed")
        }
    }

    func copyFigmaVariableBinding(_ binding: XomoFigmaVariableBinding) {
        let value = binding.variableID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        statusText = L10n.format(
            "imageEditor.status.figmaVariableCopied",
            binding.field
        )
    }

    func copySelectedFigmaVariableBindings() {
        let values = selectedLayersFigmaVariableBindings
            .map(\.variableID)
            .filter { !$0.isEmpty }
        guard !values.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(values.joined(separator: "\n"), forType: .string)
        statusText = L10n.text("imageEditor.status.figmaVariablesCopied")
    }

    func copyCurrentXomoThemeTokens() {
        do {
            let json = try activeXomoComponentTokenSnapshot.encodedJSON()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
            statusText = L10n.format(
                "xomo.theme.status.tokensCopied",
                xomoComponentTheme.title
            )
        } catch {
            statusText = L10n.text("xomo.theme.status.tokensCopyFailed")
        }
    }

    func exportCurrentXomoThemeTokens(to url: URL) throws {
        let json = try activeXomoComponentTokenSnapshot.encodedJSON()
        try Data(json.utf8).write(to: url, options: .atomic)
        statusText = L10n.format(
            "xomo.theme.status.tokensExported",
            url.lastPathComponent
        )
    }

    var activeXomoComponentTokens: XomoComponentThemeTokens {
        guard let snapshot = xomoLocalThemeTokenSnapshot,
              let tokens = try? snapshot.makeTokens()
        else {
            return xomoComponentTheme.tokens
        }
        return tokens
    }

    var activeXomoComponentTokenSnapshot: XomoComponentThemeTokenSnapshot {
        xomoLocalThemeTokenSnapshot ?? xomoComponentTheme.tokenSnapshot
    }

    var hasLocalXomoThemeTokens: Bool {
        xomoLocalThemeTokenSnapshot != nil
    }

    /// Restores the design-asset context while opening a project. Loading a
    /// document is not an edit, so this intentionally bypasses the theme
    /// Undo/Redo stack and only updates the published workspace state.
    func restoreXomoThemeContext(
        theme: XomoComponentTheme,
        tokenSnapshot: XomoComponentThemeTokenSnapshot?
    ) {
        xomoComponentTheme = theme
        xomoLocalThemeTokenSnapshot = tokenSnapshot
    }

    private var currentXomoThemeUndoState: ImageEditorXomoThemeUndoState {
        ImageEditorXomoThemeUndoState(
            theme: xomoComponentTheme,
            tokenSnapshot: xomoLocalThemeTokenSnapshot
        )
    }

    private func applyXomoThemeUndoState(_ state: ImageEditorXomoThemeUndoState) {
        xomoComponentTheme = state.theme
        xomoLocalThemeTokenSnapshot = state.tokenSnapshot
    }

    func selectXomoComponentTheme(_ theme: XomoComponentTheme) {
        guard theme != xomoComponentTheme || xomoLocalThemeTokenSnapshot != nil else { return }
        pushUndo()
        xomoComponentTheme = theme
        xomoLocalThemeTokenSnapshot = nil
        appendHistory(L10n.format("xomo.theme.history.selected", theme.title))
    }

    func importXomoThemeTokens(from url: URL) throws {
        let data = try Data(contentsOf: url)
        guard data.count <= 64 * 1024 else {
            throw XomoComponentThemeTokenError.invalidMetric("fileSize")
        }
        let snapshot = try JSONDecoder().decode(XomoComponentThemeTokenSnapshot.self, from: data)
        _ = try snapshot.makeTokens()
        guard snapshot != xomoLocalThemeTokenSnapshot else { return }
        pushUndo()
        xomoLocalThemeTokenSnapshot = snapshot
        appendHistory(L10n.format("xomo.theme.history.tokensImported", snapshot.theme))
        statusText = L10n.format(
            "xomo.theme.status.tokensImported",
            snapshot.theme
        )
    }

    func chooseXomoThemeTokenImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.xomoDesignTokens]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = L10n.text("xomo.theme.importTokens")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    try self.importXomoThemeTokens(from: url)
                } catch {
                    self.statusText = L10n.text("xomo.theme.status.tokensImportFailed")
                }
            }
        }
    }

    func clearImportedXomoThemeTokens() {
        guard xomoLocalThemeTokenSnapshot != nil else { return }
        pushUndo()
        xomoLocalThemeTokenSnapshot = nil
        appendHistory(L10n.text("xomo.theme.history.tokensCleared"))
        statusText = L10n.text("xomo.theme.status.tokensCleared")
    }

    func chooseXomoThemeTokenExportFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.xomoDesignTokens]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "(xomoComponentTheme.rawValue).xomotokens.json"
        panel.prompt = L10n.text("xomo.theme.exportTokens")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    try self.exportCurrentXomoThemeTokens(to: url)
                } catch {
                    self.statusText = L10n.text("xomo.theme.status.tokensExportFailed")
                }
            }
        }
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
        !editableSelectedLayerIndices().isEmpty
    }

    var canAutoContrastSelectedLayer: Bool {
        canAutoLevelsSelectedLayer
    }

    var canAutoColorSelectedLayer: Bool {
        canAutoLevelsSelectedLayer
    }

    var canDesaturateSelectedLayer: Bool {
        canAutoLevelsSelectedLayer
    }

    var canInvertSelectedLayer: Bool {
        canAutoLevelsSelectedLayer
    }

    var canApplySelectedFilter: Bool {
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
        if filter.kind == .gaussianBlur,
           let radius = filter.normalizedSettings.gaussianBlurRadius {
            let title = L10n.format(
                filter.appliesToBackdrop
                    ? "imageEditor.properties.smartFilterBackgroundBlurItem"
                    : "imageEditor.properties.smartFilterGaussianBlurItem",
                filter.kind.title,
                String(format: "%.1f", radius)
            )
            guard !filter.isEnabled else { return title }
            return L10n.format("imageEditor.properties.smartFilterDisabled", title)
        }
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
        if filter.kind == .pinch {
            let settings = filter.normalizedSettings
            let title = L10n.format(
                "imageEditor.properties.smartFilterPinchItem",
                filter.kind.title,
                Int((filter.normalizedIntensity * 100).rounded()),
                Int((settings.pinchAmount * 100).rounded())
            )
            guard !filter.isEnabled else { return title }
            return L10n.format("imageEditor.properties.smartFilterDisabled", title)
        }
        if filter.kind == .spherize {
            let settings = filter.normalizedSettings
            let title = L10n.format(
                "imageEditor.properties.smartFilterSpherizeItem",
                filter.kind.title,
                Int((filter.normalizedIntensity * 100).rounded()),
                Int((settings.spherizeAmount * 100).rounded())
            )
            guard !filter.isEnabled else { return title }
            return L10n.format("imageEditor.properties.smartFilterDisabled", title)
        }
        if filter.kind == .lensCorrection {
            let settings = filter.normalizedSettings
            let title = L10n.format(
                "imageEditor.properties.smartFilterLensCorrectionItem",
                filter.kind.title,
                Int((filter.normalizedIntensity * 100).rounded()),
                Int((settings.lensDistortion * 100).rounded())
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

    var canSelectVisibleLayers: Bool {
        document.layers.contains { document.isEffectivelyVisible($0) }
    }

    var canSelectHiddenLayers: Bool {
        document.layers.contains { !document.isEffectivelyVisible($0) }
    }

    var canSelectLockedLayers: Bool {
        document.layers.contains { document.isEffectivelyLocked($0) }
    }

    var canSelectUnlockedLayers: Bool {
        document.layers.contains { !document.isEffectivelyLocked($0) }
    }

    var canSelectMaskedLayers: Bool {
        canSelectLayers(matching: .masked)
    }

    var canSelectStyledLayers: Bool {
        canSelectLayers(matching: .styled)
    }

    var canSelectClippingMaskLayers: Bool {
        canSelectLayers(matching: .clipping)
    }

    var canSelectSmartFilteredLayers: Bool {
        canSelectLayers(matching: .smartFiltered)
    }

    var canSelectLayersWithSameKind: Bool {
        document.selectedLayer != nil
    }

    var canSelectSimilarLayers: Bool {
        document.selectedLayer != nil
    }

    var canSelectLayersWithSameBlendMode: Bool {
        document.selectedLayer != nil
    }

    var canSelectLayersWithSameLabelColor: Bool {
        document.selectedLayer?.labelColor != nil
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

    var canShowSelectedLayers: Bool {
        selectedLayerIndices.contains { !document.layers[$0].isVisible }
    }

    var canHideSelectedLayers: Bool {
        selectedLayerIndices.contains { document.layers[$0].isVisible }
    }

    var canExpandSelectedLayerGroups: Bool {
        selectedLayerGroupBranchIDs().contains { groupID in
            document.layers.first { $0.id == groupID }?.isGroupExpanded == false
        }
    }

    var canCollapseSelectedLayerGroups: Bool {
        selectedLayerGroupBranchIDs().contains { groupID in
            document.layers.first { $0.id == groupID }?.isGroupExpanded == true
        }
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

    var selectedLayersClippingMaskState: ImageEditorClippingMaskSelectionState {
        let layers = selectedLayerIndices
            .map { document.layers[$0] }
            .filter { !$0.isGroup }
        guard !layers.isEmpty else { return .off }
        let clippedCount = layers.lazy.filter(\.isClippingMask).count
        if clippedCount == 0 { return .off }
        if clippedCount == layers.count { return .on }
        return .mixed
    }

    var selectedLayerHasMask: Bool {
        selectedLayerIndices.contains { document.layers[$0].mask != nil }
    }

    var canAddLayerMask: Bool {
        !layerMaskAddIndices.isEmpty
    }

    var canDeleteLayerMask: Bool {
        !layerMaskDeleteIndices().isEmpty
    }

    var selection: ImageEditorSelection? {
        document.selection
    }

    var hasSelection: Bool {
        document.selection != nil
    }

    var canDeleteLayer: Bool {
        let deletionIDs = ImageEditorLayerHierarchyDeletion.deletableLayerIDs(
            in: document.layers,
            selectedIDs: document.selectedLayerIDs,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) }
        )
        return !deletionIDs.isEmpty && document.layers.count - deletionIDs.count >= 1
    }

    var canMergeSelectedLayerDown: Bool {
        hierarchyMergeDownPlan != nil
    }

    var canStampVisibleLayers: Bool {
        document.layers.contains { layer in
            document.shouldComposite(layer)
        }
    }

    var canStampSelectedLayers: Bool {
        guard let plan = selectedStampPlan else { return false }
        return document.layers.contains { layer in
            plan.sourceLayerIDs.contains(layer.id) && document.shouldComposite(layer)
        }
    }

    var canGroupSelectedLayer: Bool {
        ImageEditorLayerHierarchyGrouping.groupableRootIDs(
            in: document.layers,
            selectedIDs: document.selectedLayerIDs,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) }
        ) != nil
    }

    var canSelectSelectedGroupMembers: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer,
              layer.isGroup
        else { return false }
        return !groupDescendantIndices(for: layer.id).isEmpty
    }

    var canSelectParentGroup: Bool {
        guard selectedLayerCount == 1,
              let layer = document.selectedLayer
        else { return false }
        return document.group(for: layer) != nil
    }

    var canMoveSelectedLayersIntoGroup: Bool {
        ImageEditorLayerHierarchyMovement.moveIntoGroupPlan(
            layers: document.layers,
            selectedIDs: document.selectedLayerIDs,
            primarySelectionID: document.selectedLayerID,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) }
        ) != nil
    }

    var canMoveSelectedLayersOutOfGroup: Bool {
        ImageEditorLayerHierarchyMovement.moveOutOfGroupsPlan(
            layers: document.layers,
            selectedIDs: document.selectedLayerIDs,
            primarySelectionID: document.selectedLayerID,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) }
        ) != nil
    }

    var canUngroupSelectedLayers: Bool {
        !ImageEditorLayerHierarchyGrouping.ungroupableGroupIDs(
            in: document.layers,
            selectedIDs: document.selectedLayerIDs,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) }
        ).isEmpty
    }

    var canMoveSelectedLayerUp: Bool {
        canMoveSelectedLayerUp(inVisibleOrder: visibleLayerRows.map(\.id))
    }

    var canMoveSelectedLayerDown: Bool {
        canMoveSelectedLayerDown(inVisibleOrder: visibleLayerRows.map(\.id))
    }

    var canMoveSelectedLayerToTop: Bool {
        canMoveSelectedLayerToTop(inVisibleOrder: visibleLayerRows.map(\.id))
    }

    var canMoveSelectedLayerToBottom: Bool {
        canMoveSelectedLayerToBottom(inVisibleOrder: visibleLayerRows.map(\.id))
    }

    var canToggleSelectedLayerClippingMask: Bool {
        guard let index = document.selectedLayerIndex else { return false }
        let layer = document.layers[index]
        guard !layer.isGroup, !document.isEffectivelyLocked(layer) else { return false }
        if layer.isClippingMask { return true }
        return clippingBaseExists(below: index, groupID: layer.groupID)
    }

    var canToggleClippingMasksForSelectedLayers: Bool {
        if selectedLayerCount == 1 {
            return canToggleSelectedLayerClippingMask
        }
        return canCreateClippingMasksForSelectedLayers || canReleaseSelectedClippingMasks
    }

    var canCreateClippingMasksForSelectedLayers: Bool {
        !selectedLayerClippingCreationIndices().isEmpty
    }

    var canReleaseSelectedClippingMasks: Bool {
        !selectedLayerClippingReleaseIndices().isEmpty
    }

    var canAddSmartFilterToSelectedLayer: Bool {
        !selectedLayerSmartFilterTargetIndices().isEmpty
    }

    var canUpdateLastSmartFilterOnSelectedLayer: Bool {
        !selectedLayerSmartFilterUpdateTargetIndices().isEmpty
    }

    var canUpdateLoadedSmartFilterOnSelectedLayer: Bool {
        guard let loadedSmartFilterID,
              let (loadedLayerIndex, filterIndex) = selectedSmartFilterIndex(loadedSmartFilterID)
        else {
            return selectedLayerSmartFilterUpdateTargetIndices().contains { layerIndex in
                guard let filter = document.layers[layerIndex].smartFilters.last else { return false }
                return smartFilterDiffersFromCurrentControls(filter)
            }
        }
        let targetIndices = selectedLayerSmartFilterUpdateTargetIndices().filter { layerIndex in
            document.layers[layerIndex].smartFilters.indices.contains(filterIndex)
        }
        return targetIndices.contains(loadedLayerIndex)
            && targetIndices.contains { layerIndex in
                smartFilterDiffersFromCurrentControls(document.layers[layerIndex].smartFilters[filterIndex])
            }
    }

    var loadedSmartFilterHasPendingChanges: Bool {
        guard let loadedSmartFilterID,
              let (loadedLayerIndex, filterIndex) = selectedSmartFilterIndex(loadedSmartFilterID)
        else {
            return false
        }
        let targetIndices = selectedLayerSmartFilterUpdateTargetIndices().filter { layerIndex in
            document.layers[layerIndex].smartFilters.indices.contains(filterIndex)
        }
        return targetIndices.contains(loadedLayerIndex)
            && targetIndices.contains { layerIndex in
                smartFilterDiffersFromCurrentControls(document.layers[layerIndex].smartFilters[filterIndex])
            }
    }

    var canClearSmartFiltersFromSelectedLayer: Bool {
        !selectedLayerSmartFilterClearTargetIndices().isEmpty
    }

    var canConvertSelectedLayerToSmartObject: Bool {
        smartObjectConversionCandidate() != nil
    }

    var canReplaceSelectedSmartObjectContents: Bool {
        !smartObjectReplacementTargetSourceIDs().isEmpty
    }

    var canResetSelectedSmartObjectTransform: Bool {
        !smartObjectResetTransformTargetIndices().isEmpty
    }

    var canMakeSelectedSmartObjectUnique: Bool {
        !smartObjectUniqueTargetIndices().isEmpty
    }

    var colorText: String {
        rgbText(for: foregroundColor)
    }

    var backgroundColorText: String {
        rgbText(for: backgroundColor)
    }

    var colorPanelSummaryText: String {
        L10n.format("imageEditor.status.colorPanelSummary", colorText, backgroundColorText)
    }

    var toolsPanelSummaryText: String {
        L10n.format(
            "imageEditor.status.toolsPanelSummary",
            selectedTool.title,
            ImageEditorTool.allCases.count
        )
    }

    var optionsPanelSummaryText: String {
        if selectedTool == .sponge {
            return L10n.format(
                "imageEditor.status.spongeOptionsPanelSummary",
                selectedTool.title,
                selectionMode.compactTitle,
                Int(brushSize.rounded()),
                Int((opacity * 100).rounded()),
                Int((hardness * 100).rounded())
            )
        }
        return L10n.format(
            "imageEditor.status.optionsPanelSummary",
            selectedTool.title,
            selectionMode.compactTitle,
            Int(brushSize.rounded()),
            Int((opacity * 100).rounded()),
            Int((hardness * 100).rounded()),
            Int(feather.rounded()),
            Int((tolerance * 100).rounded())
        )
    }

    var swatchesPanelSummaryText: String {
        let names = ImageEditorColorSwatch.defaultPalette
            .map(\.title)
            .joined(separator: ", ")
        return L10n.format("imageEditor.status.swatchesPanelSummary", names)
    }

    var brushesPanelSummaryText: String {
        L10n.format(
            "imageEditor.status.brushesPanelSummary",
            selectedTool.title,
            Int(brushSize.rounded()),
            Int((opacity * 100).rounded()),
            Int((hardness * 100).rounded())
        )
    }

    var brushPresets: [ImageEditorBrushPreset] {
        ImageEditorBrushPreset.defaultPresets + customBrushPresets
    }

    var activeBrushPreset: ImageEditorBrushPreset? {
        customBrushPresets.first(where: brushPresetMatchesCurrentSettings)
            ?? ImageEditorBrushPreset.defaultPresets.first(where: brushPresetMatchesCurrentSettings)
    }

    private func brushPresetMatchesCurrentSettings(_ preset: ImageEditorBrushPreset) -> Bool {
        preset.matches(
            size: brushSize,
            hardness: hardness,
            flow: brushFlow,
            spacing: brushSpacing,
            pressureControlsSize: brushPressureControlsSize,
            pressureControlsOpacity: brushPressureControlsOpacity,
            pressureControlsFlow: brushPressureControlsFlow,
            pressureSensitivity: brushPressureSensitivity,
            minimumDiameter: brushMinimumDiameter,
            minimumOpacity: brushMinimumOpacity,
            minimumFlow: brushMinimumFlow,
            tiltControlsShape: brushTiltControlsShape,
            tipRoundness: brushTipRoundness,
            tipAngleDegrees: brushTipAngleDegrees,
            smoothing: brushSmoothing
        )
    }

    var characterPanelSummaryText: String {
        let previewText = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return L10n.format(
            "imageEditor.status.characterPanelSummary",
            previewText.isEmpty ? L10n.text("imageEditor.characterPanel.emptyText") : previewText,
            Int(clampedTextSize(textSize).rounded()),
            textBold ? L10n.text("imageEditor.characterPanel.enabled") : L10n.text("imageEditor.characterPanel.disabled"),
            textItalic ? L10n.text("imageEditor.characterPanel.enabled") : L10n.text("imageEditor.characterPanel.disabled"),
            textUnderlined ? L10n.text("imageEditor.characterPanel.enabled") : L10n.text("imageEditor.characterPanel.disabled"),
            textStruckThrough ? L10n.text("imageEditor.characterPanel.enabled") : L10n.text("imageEditor.characterPanel.disabled"),
            Int(clampedTextCharacterSpacing(textCharacterSpacing).rounded()),
            Int(clampedTextLineSpacing(textLineSpacing).rounded())
        )
    }

    var paragraphPanelSummaryText: String {
        L10n.format(
            "imageEditor.status.paragraphPanelSummary",
            selectedTextAlignment.title,
            Int(clampedTextBoxWidth(textBoxWidth).rounded()),
            Int(clampedTextBoxHeight(textBoxHeight).rounded()),
            Int(clampedTextIndent(textLeftIndent).rounded()),
            Int(clampedTextIndent(textRightIndent).rounded()),
            Int(clampedTextFirstLineIndent(textFirstLineIndent).rounded())
        )
    }

    var stylesPanelSummaryText: String {
        guard let layer = document.selectedLayer else {
            return L10n.text("imageEditor.status.stylesPanelNoLayer")
        }
        let names = enabledStyleEffectNames(for: layer.style)
        let summary = names.isEmpty
            ? L10n.text("imageEditor.stylesPanel.noEffects")
            : names.joined(separator: ", ")
        return L10n.format("imageEditor.status.stylesPanelSummary", layer.name, summary)
    }

    var brushPanelTools: [ImageEditorTool] {
        [.brush, .eraser, .cloneStamp, .dodge, .burn, .blur, .sharpen, .smudge, .healingBrush]
    }

    var toolsPanelTools: [ImageEditorTool] {
        ImageEditorTool.allCases
    }

    var isRightDockVisible: Bool {
        isNavigatorPanelVisible || isHistoryPanelVisible || isLayersPanelVisible || isPropertiesPanelVisible || isHotspotsPanelVisible || isSlicesPanelVisible
    }

    var isWorkspaceChromeVisible: Bool {
        areToolsPanelVisible || isOptionsBarVisible || isRightDockVisible
    }

    func resetForegroundBackgroundColors() {
        foregroundColor = .black
        backgroundColor = .white
        statusText = L10n.text("imageEditor.status.colorDefaultForegroundBackground")
    }

    func swapForegroundBackgroundColors() {
        let previousForeground = foregroundColor
        foregroundColor = backgroundColor
        backgroundColor = previousForeground
        statusText = L10n.text("imageEditor.status.colorSwapForegroundBackground")
    }

    func selectEyedropperForColorSampling() {
        selectTool(.eyedropper)
        statusText = L10n.text("imageEditor.status.colorEyedropperReady")
    }

    func sampleScreenColorForForeground() {
        let sampler = NSColorSampler()
        screenColorSampler = sampler
        sampler.show { [weak self] color in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.screenColorSampler = nil
                guard let color else { return }
                self.applyScreenSampledForegroundColor(color)
            }
        }
    }

    func sampleScreenColorForBackground() {
        let sampler = NSColorSampler()
        screenColorSampler = sampler
        sampler.show { [weak self] color in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.screenColorSampler = nil
                guard let color else { return }
                self.applyScreenSampledBackgroundColor(color)
            }
        }
    }

    func applyScreenSampledForegroundColor(_ color: NSColor) {
        foregroundColor = color
        statusText = L10n.text("imageEditor.status.colorScreenSampledForeground")
    }

    func applyScreenSampledBackgroundColor(_ color: NSColor) {
        backgroundColor = color
        statusText = L10n.text("imageEditor.status.colorScreenSampledBackground")
    }

    func applySwatchToForeground(_ swatch: ImageEditorColorSwatch) {
        foregroundColor = swatch.color
        statusText = L10n.format("imageEditor.status.swatchForegroundApplied", swatch.title, colorText)
    }

    func applySwatchToBackground(_ swatch: ImageEditorColorSwatch) {
        backgroundColor = swatch.color
        statusText = L10n.format("imageEditor.status.swatchBackgroundApplied", swatch.title, backgroundColorText)
    }

    func selectBrushPanelTool(_ tool: ImageEditorTool) {
        selectTool(tool)
        statusText = L10n.format("imageEditor.status.brushToolSelected", tool.title, brushesPanelSummaryText)
    }

    func selectToolsPanelTool(_ tool: ImageEditorTool) {
        selectTool(tool)
        statusText = L10n.format("imageEditor.status.toolsPanelToolSelected", tool.title, optionsPanelSummaryText)
    }

    func toggleToolsPanelVisibility() {
        areToolsPanelVisible.toggle()
        statusText = L10n.text(areToolsPanelVisible ? "imageEditor.status.toolsPanelShown" : "imageEditor.status.toolsPanelHidden")
    }

    func applyBrushPreset(_ preset: ImageEditorBrushPreset) {
        brushSize = max(1, min(96, preset.size))
        hardness = max(0, min(1, preset.hardness))
        brushFlow = max(1, min(100, preset.flow))
        brushSpacing = max(1, min(200, preset.spacing))
        brushPressureControlsSize = preset.pressureControlsSize
        brushPressureControlsOpacity = preset.pressureControlsOpacity
        brushPressureControlsFlow = preset.pressureControlsFlow
        brushPressureSensitivity = max(0, min(100, preset.pressureSensitivity))
        brushMinimumDiameter = max(0, min(100, preset.minimumDiameter))
        brushMinimumOpacity = max(0, min(100, preset.minimumOpacity))
        brushMinimumFlow = max(0, min(100, preset.minimumFlow))
        brushTiltControlsShape = preset.tiltControlsShape
        brushTipRoundness = max(10, min(100, preset.tipRoundness))
        brushTipAngleDegrees = max(-180, min(180, preset.tipAngleDegrees))
        brushSmoothing = max(0, min(100, preset.smoothing))
        persistBrushDynamicsPreferences()
        statusText = L10n.format("imageEditor.status.brushPresetApplied", preset.title, brushesPanelSummaryText)
    }

    @discardableResult
    func createBrushPresetFromCurrentSettings() -> ImageEditorBrushPreset? {
        guard customBrushPresets.count < ImageEditorBrushPresetPreferences.maximumPresetCount else {
            statusText = L10n.format(
                "imageEditor.status.brushPresetLimitReached",
                ImageEditorBrushPresetPreferences.maximumPresetCount
            )
            return nil
        }

        let existingNames = Set(customBrushPresets.compactMap(\.name))
        var sequence = customBrushPresets.count + 1
        var name = L10n.format("imageEditor.brushPreset.customName", sequence)
        while existingNames.contains(name) {
            sequence += 1
            name = L10n.format("imageEditor.brushPreset.customName", sequence)
        }
        let preset = ImageEditorBrushPreset(
            id: UUID().uuidString,
            name: name,
            size: brushSize,
            hardness: hardness,
            flow: brushFlow,
            spacing: brushSpacing,
            pressureControlsSize: brushPressureControlsSize,
            pressureControlsOpacity: brushPressureControlsOpacity,
            pressureControlsFlow: brushPressureControlsFlow,
            pressureSensitivity: brushPressureSensitivity,
            minimumDiameter: brushMinimumDiameter,
            minimumOpacity: brushMinimumOpacity,
            minimumFlow: brushMinimumFlow,
            tiltControlsShape: brushTiltControlsShape,
            tipRoundness: brushTipRoundness,
            tipAngleDegrees: brushTipAngleDegrees,
            smoothing: brushSmoothing
        ).normalizedCustomPreset
        customBrushPresets.append(preset)
        persistBrushPresetPreferences()
        statusText = L10n.format("imageEditor.status.brushPresetCreated", preset.title)
        return preset
    }

    func deleteBrushPreset(_ preset: ImageEditorBrushPreset) {
        guard !preset.isBuiltIn,
              let index = customBrushPresets.firstIndex(where: { $0.id == preset.id })
        else { return }
        let removed = customBrushPresets.remove(at: index)
        persistBrushPresetPreferences()
        statusText = L10n.format("imageEditor.status.brushPresetDeleted", removed.title)
    }

    func applyOptionsSelectionMode(_ mode: ImageEditorSelectionMode) {
        selectionMode = mode
        statusText = optionsPanelSummaryText
    }

    func applyOptionsBrushSizePreset(_ size: Int) {
        brushSize = CGFloat(max(1, min(96, size)))
        statusText = optionsPanelSummaryText
    }

    func adjustBrushSizeShortcut(by delta: CGFloat) {
        brushSize = max(1, min(96, brushSize + delta))
        statusText = optionsPanelSummaryText
    }

    func adjustBrushHardnessShortcut(by delta: CGFloat) {
        hardness = max(0, min(1, hardness + delta))
        statusText = optionsPanelSummaryText
    }

    @discardableResult
    func applyToneRangeShortcut(_ range: ImageEditorToneRange) -> Bool {
        guard canvasInteractionTool == .dodge || canvasInteractionTool == .burn else {
            return false
        }
        toneRange = range
        statusText = L10n.format(
            "imageEditor.status.toneRangeShortcut",
            range.title,
            ImageEditorToneRangeShortcut.displayLabel(for: range)
        )
        return true
    }

    @discardableResult
    func applySpongeModeShortcut(_ mode: ImageEditorSpongeMode) -> Bool {
        guard canvasInteractionTool == .sponge else { return false }
        spongeMode = mode
        statusText = L10n.format(
            "imageEditor.status.spongeModeShortcut",
            mode.title,
            ImageEditorSpongeModeShortcut.displayLabel(for: mode)
        )
        return true
    }

    func applyOptionsOpacityPreset(_ percent: Int) {
        opacity = CGFloat(max(5, min(100, percent))) / 100
        statusText = optionsPanelSummaryText
    }

    func applyOpacityShortcutDigit(_ digit: Int) {
        let percent = digit == 0 ? 100 : max(1, min(9, digit)) * 10
        applyOptionsOpacityPreset(percent)
    }

    func applyOptionsHardnessPreset(_ percent: Int) {
        hardness = CGFloat(max(0, min(100, percent))) / 100
        statusText = optionsPanelSummaryText
    }

    func toggleOptionsBarVisibility() {
        isOptionsBarVisible.toggle()
        statusText = L10n.text(isOptionsBarVisible ? "imageEditor.status.optionsBarShown" : "imageEditor.status.optionsBarHidden")
    }

    func resetDefaultWorkspace() {
        areToolsPanelVisible = true
        isOptionsBarVisible = true
        isNavigatorPanelVisible = true
        isHistoryPanelVisible = true
        isLayersPanelVisible = true
        isPropertiesPanelVisible = true
        isHotspotsPanelVisible = false
        isSlicesPanelVisible = false
        selectedHotspotID = nil
        isStatusBarVisible = true
        statusText = L10n.text("imageEditor.status.workspaceDefaultRestored")
    }

    func toggleWorkspaceChromeVisibility(
        eventSignature: ImageEditorKeyboardShortcutEventSignature? = nil
    ) {
        let eventSignature = eventSignature ?? .currentKeyEvent
        guard ImageEditorPanelToggleDispatchGate.shouldDispatch(
            .workspaceChrome,
            event: eventSignature
        ) else { return }
        let shouldShow = !isWorkspaceChromeVisible
        areToolsPanelVisible = shouldShow
        isOptionsBarVisible = shouldShow
        isNavigatorPanelVisible = shouldShow
        isHistoryPanelVisible = shouldShow
        isLayersPanelVisible = shouldShow
        isPropertiesPanelVisible = shouldShow
        isHotspotsPanelVisible = shouldShow
        isSlicesPanelVisible = shouldShow
        statusText = L10n.text(shouldShow ? "imageEditor.status.workspacePanelsShown" : "imageEditor.status.workspacePanelsHidden")
    }

    func toggleRightDockVisibility(
        eventSignature: ImageEditorKeyboardShortcutEventSignature? = nil
    ) {
        let eventSignature = eventSignature ?? .currentKeyEvent
        guard ImageEditorPanelToggleDispatchGate.shouldDispatch(
            .rightDock,
            event: eventSignature
        ) else { return }
        let shouldShow = !isRightDockVisible
        isNavigatorPanelVisible = shouldShow
        isHistoryPanelVisible = shouldShow
        isLayersPanelVisible = shouldShow
        isPropertiesPanelVisible = shouldShow
        isHotspotsPanelVisible = shouldShow
        isSlicesPanelVisible = shouldShow
        statusText = L10n.text(shouldShow ? "imageEditor.status.rightDockPanelsShown" : "imageEditor.status.rightDockPanelsHidden")
    }

    func toggleStatusBarVisibility() {
        isStatusBarVisible.toggle()
        statusText = L10n.text(isStatusBarVisible ? "imageEditor.status.statusBarShown" : "imageEditor.status.statusBarHidden")
    }

    func toggleNavigatorPanelVisibility() {
        isNavigatorPanelVisible.toggle()
        statusText = L10n.text(isNavigatorPanelVisible ? "imageEditor.status.navigatorPanelShown" : "imageEditor.status.navigatorPanelHidden")
    }

    func toggleHistoryPanelVisibility() {
        isHistoryPanelVisible.toggle()
        statusText = L10n.text(isHistoryPanelVisible ? "imageEditor.status.historyPanelShown" : "imageEditor.status.historyPanelHidden")
    }

    func toggleLayersPanelVisibility() {
        isLayersPanelVisible.toggle()
        statusText = L10n.text(isLayersPanelVisible ? "imageEditor.status.layersPanelShown" : "imageEditor.status.layersPanelHidden")
    }

    func togglePropertiesPanelVisibility() {
        isPropertiesPanelVisible.toggle()
        statusText = L10n.text(isPropertiesPanelVisible ? "imageEditor.status.propertiesPanelShown" : "imageEditor.status.propertiesPanelHidden")
    }

    func toggleHotspotsPanelVisibility() {
        isHotspotsPanelVisible.toggle()
        statusText = L10n.text(isHotspotsPanelVisible ? "imageEditor.status.hotspotsPanelShown" : "imageEditor.status.hotspotsPanelHidden")
    }

    func toggleSlicesPanelVisibility() {
        isSlicesPanelVisible.toggle()
        statusText = L10n.text(isSlicesPanelVisible ? "imageEditor.status.slicesPanelShown" : "imageEditor.status.slicesPanelHidden")
    }

    func selectCharacterPanelTool() {
        selectTool(.text)
        statusText = characterPanelSummaryText
    }

    func toggleCharacterBold() {
        textBold.toggle()
        statusText = characterPanelSummaryText
    }

    func toggleCharacterItalic() {
        textItalic.toggle()
        statusText = characterPanelSummaryText
    }

    func toggleCharacterUnderline() {
        textUnderlined.toggle()
        statusText = characterPanelSummaryText
    }

    func toggleCharacterStrikethrough() {
        textStruckThrough.toggle()
        statusText = characterPanelSummaryText
    }

    func selectParagraphAlignment(_ alignment: ImageEditorTextAlignment) {
        selectedTextAlignment = alignment
        statusText = paragraphPanelSummaryText
    }

    private func enabledStyleEffectNames(for style: ImageEditorLayerStyle) -> [String] {
        var names: [String] = []
        if style.strokeEnabled { names.append(L10n.text("imageEditor.action.layerStroke")) }
        if style.shadowEnabled { names.append(L10n.text("imageEditor.action.layerShadow")) }
        if style.innerShadowEnabled { names.append(L10n.text("imageEditor.action.layerInnerShadow")) }
        if style.outerGlowEnabled { names.append(L10n.text("imageEditor.action.layerOuterGlow")) }
        if style.innerGlowEnabled { names.append(L10n.text("imageEditor.action.layerInnerGlow")) }
        if style.colorOverlayEnabled { names.append(L10n.text("imageEditor.action.layerColorOverlay")) }
        if style.gradientOverlayEnabled { names.append(L10n.text("imageEditor.action.layerGradientOverlay")) }
        if style.patternOverlayEnabled { names.append(L10n.text("imageEditor.action.layerPatternOverlay")) }
        if style.satinEnabled { names.append(L10n.text("imageEditor.action.layerSatin")) }
        if style.bevelEnabled { names.append(L10n.text("imageEditor.action.layerBevel")) }
        return names
    }

    private func rgbText(for nsColor: NSColor) -> String {
        let color = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        return "R \(Int((color.redComponent * 255).rounded()))  G \(Int((color.greenComponent * 255).rounded()))  B \(Int((color.blueComponent * 255).rounded()))"
    }

    func selectTool(_ tool: ImageEditorTool) {
        selectedTool = tool
        if tool == .pen, pendingPenPathPoints.isEmpty {
            statusText = L10n.text("imageEditor.status.penReady")
        } else {
            updateStatus()
        }
    }

    var canvasInteractionTool: ImageEditorTool {
        selectedLeftSidebarTab == .components ? .move : selectedTool
    }

    var workspaceInputMode: XomoWorkspaceInputMode {
        XomoWorkspaceInputMode.resolve(
            sidebarTab: selectedLeftSidebarTab,
            selectedTool: selectedTool,
            selectedComponent: selectedXomoObjectKind
        )
    }

    func selectLeftSidebarTab(_ tab: XomoLeftSidebarTab) {
        selectedLeftSidebarTab = tab
    }

    func selectClassicToolShortcut(_ key: Character) {
        guard let group = ImageEditorTool.classicShortcutGroup(for: key) else { return }
        selectTool(group.primaryTool)
    }

    func cycleClassicToolShortcut(_ key: Character) {
        guard let group = ImageEditorTool.classicShortcutGroup(for: key) else { return }
        guard group.tools.count > 1 else {
            selectTool(group.primaryTool)
            return
        }
        guard let currentIndex = group.tools.firstIndex(of: selectedTool) else {
            selectTool(group.primaryTool)
            return
        }
        let nextIndex = group.tools.index(after: currentIndex) == group.tools.endIndex
            ? group.tools.startIndex
            : group.tools.index(after: currentIndex)
        selectTool(group.tools[nextIndex])
    }

    func zoomIn() {
        setZoom(zoom * 1.2)
    }

    func zoomOut() {
        setZoom(zoom / 1.2)
    }

    func setZoom(_ requestedZoom: CGFloat) {
        guard requestedZoom.isFinite else { return }
        ensureToolsPanelVisibleForZoom()
        zoom = min(max(requestedZoom, Self.minimumZoom), Self.maximumZoom)
        statusText = L10n.format("imageEditor.status.zoom", zoomText)
    }

    func magnifyCanvas(_ magnification: CGFloat, at location: CGPoint, viewportSize: CGSize) {
        guard magnification.isFinite, magnification > 0 else { return }
        ensureToolsPanelVisibleForZoom()
        let baseZoom: CGFloat
        let baseOffset: CGSize
        if let anchorZoom = magnifyBaseZoom, let anchorOffset = magnifyBaseOffset {
            baseZoom = anchorZoom
            baseOffset = anchorOffset
        } else {
            baseZoom = zoom
            baseOffset = canvasOffset
            magnifyBaseZoom = zoom
            magnifyBaseOffset = canvasOffset
        }
        let newZoom = min(max(baseZoom * magnification, Self.minimumZoom), Self.maximumZoom)
        let scaleRatio = baseZoom > 0 ? newZoom / baseZoom : 1
        // Keep the image point under `location` fixed while zooming (anchor-at-cursor).
        if viewportSize.width > 0, viewportSize.height > 0, scaleRatio != 1 {
            let centerX = viewportSize.width / 2 + baseOffset.width
            let centerY = viewportSize.height / 2 + baseOffset.height
            canvasOffset = CGSize(
                width: baseOffset.width + (1 - scaleRatio) * (location.x - centerX),
                height: baseOffset.height + (1 - scaleRatio) * (location.y - centerY)
            )
        }
        zoom = newZoom
        statusText = L10n.format("imageEditor.status.zoom", zoomText)
    }

    func endCanvasMagnify() {
        magnifyBaseZoom = nil
        magnifyBaseOffset = nil
    }

    func zoomActualPixels() {
        ensureToolsPanelVisibleForZoom()
        guard let targetZoom = actualPixelsZoomFactor(for: canvasViewportSize) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        zoom = targetZoom
        canvasOffset = .zero
        statusText = L10n.text("imageEditor.status.zoomActualPixels")
    }

    func fitZoom() {
        ensureToolsPanelVisibleForZoom()
        guard let targetZoom = fitZoomFactor(for: canvasViewportSize) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        zoom = targetZoom
        canvasOffset = .zero
        statusText = L10n.text("imageEditor.status.zoomFitOnScreen")
    }

    private func ensureToolsPanelVisibleForZoom() {
        if !areToolsPanelVisible {
            areToolsPanelVisible = true
        }
    }

    func updateCanvasViewportSize(_ size: CGSize) {
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0
        else { return }
        guard abs(canvasViewportSize.width - size.width) > 0.5 ||
              abs(canvasViewportSize.height - size.height) > 0.5
        else { return }
        canvasViewportSize = size
    }

    func actualPixelsZoomFactor(for viewportSize: CGSize) -> CGFloat? {
        let imageSize = currentImage.size
        guard imageSize.width > 0,
              imageSize.height > 0,
              viewportSize.width > 0,
              viewportSize.height > 0
        else { return nil }
        let baseScale = min(
            viewportSize.width / max(imageSize.width, 1),
            viewportSize.height / max(imageSize.height, 1)
        ) * 0.74
        guard baseScale.isFinite, baseScale > 0 else { return nil }
        return min(max(1 / baseScale, Self.minimumZoom), Self.maximumZoom)
    }

    func fitZoomFactor(for viewportSize: CGSize) -> CGFloat? {
        let imageSize = currentImage.size
        guard imageSize.width > 0,
              imageSize.height > 0,
              viewportSize.width > 0,
              viewportSize.height > 0
        else { return nil }
        let baseScale = min(
            viewportSize.width / max(imageSize.width, 1),
            viewportSize.height / max(imageSize.height, 1)
        ) * 0.74
        guard baseScale.isFinite, baseScale > 0 else { return nil }
        return 1
    }

    func nudgeCanvas(by translation: CGSize) {
        canvasOffset.width += translation.width
        canvasOffset.height += translation.height
    }

    func centerCanvas(on imagePoint: CGPoint) {
        let canvasSize = document.canvasSize
        let viewportSize = canvasViewportSize
        guard canvasSize.width > 0,
              canvasSize.height > 0,
              viewportSize.width > 0,
              viewportSize.height > 0,
              zoom.isFinite,
              zoom > 0
        else { return }

        let baseScale = min(
            viewportSize.width / canvasSize.width,
            viewportSize.height / canvasSize.height
        ) * 0.74
        let scale = baseScale * zoom
        guard scale.isFinite, scale > 0 else { return }

        let boundedPoint = ImageEditorCanvasGeometry.boundedCanvasPoint(
            imagePoint,
            canvasSize: canvasSize
        )
        let canvasOrigin = CGPoint(
            x: (viewportSize.width - canvasSize.width * scale) / 2 + canvasOffset.width,
            y: (viewportSize.height - canvasSize.height * scale) / 2 + canvasOffset.height
        )
        let currentViewPoint = CGPoint(
            x: canvasOrigin.x + boundedPoint.x * scale,
            y: canvasOrigin.y + boundedPoint.y * scale
        )
        let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        nudgeCanvas(by: CGSize(
            width: viewportCenter.x - currentViewPoint.x,
            height: viewportCenter.y - currentViewPoint.y
        ))
    }

    func updatePointer(_ point: CGPoint?) {
        let normalizedPoint = point.flatMap { point -> CGPoint? in
            let bounds = CGRect(origin: .zero, size: document.canvasSize)
            guard bounds.contains(point) else { return nil }
            return CGPoint(x: floor(point.x), y: floor(point.y))
        }
        guard normalizedPoint != pointerCanvasPoint else { return }
        pointerCanvasPoint = normalizedPoint
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        clearSelectedLayerTransformReferencePoint()
        let previousThemeState = undoXomoThemeStates.popLast() ?? currentXomoThemeUndoState
        redoStack.append(document)
        redoXomoThemeStates.append(currentXomoThemeUndoState)
        document = previous
        applyXomoThemeUndoState(previousThemeState)
        selectedHistoryEntryID = document.history.last?.id
        ensureSelectedLayer()
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        syncShapeControlsFromSelection()
        refreshColorSamplers()
        updateStatus()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        clearSelectedLayerTransformReferencePoint()
        let nextThemeState = redoXomoThemeStates.popLast() ?? currentXomoThemeUndoState
        undoStack.append(document)
        undoXomoThemeStates.append(currentXomoThemeUndoState)
        document = next
        applyXomoThemeUndoState(nextThemeState)
        selectedHistoryEntryID = document.history.last?.id
        ensureSelectedLayer()
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        syncShapeControlsFromSelection()
        refreshColorSamplers()
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

    func selectHistoryEntry(_ id: UUID) {
        guard let entry = document.history.first(where: { $0.id == id }) else { return }
        selectedHistoryEntryID = id
        statusText = L10n.format("imageEditor.status.historyEntrySelected", entry.title)
    }

    func truncateSelectedHistory() {
        guard let selectedHistoryEntryID else { return }
        truncateHistory(from: selectedHistoryEntryID)
    }

    func truncateHistory(from id: UUID) {
        guard let index = document.history.firstIndex(where: { $0.id == id }),
              index > 0,
              let previousDocument = historySnapshots[document.history[index - 1].id]
        else { return }

        let removedCount = document.history.count - index
        pushUndo()
        document = previousDocument
        selectedHistoryEntryID = document.history.last?.id
        ensureSelectedLayer()
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        syncShapeControlsFromSelection()
        refreshColorSamplers()
        updateStatus()
        statusText = L10n.format("imageEditor.status.historyTruncated", removedCount)
    }

    func createHistorySnapshot() {
        let name = uniqueHistorySnapshotName(
            L10n.format("imageEditor.history.snapshotName", namedHistorySnapshots.count + 1)
        )
        let snapshot = ImageEditorHistorySnapshot(
            name: name,
            document: document,
            renderedImage: currentImage
        )
        namedHistorySnapshots.append(snapshot)
        selectedHistorySnapshotID = snapshot.id
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
        selectedHistorySnapshotID = id
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
        selectedHistorySnapshotID = id
        appendHistory(L10n.text("imageEditor.history.snapshotRestore"))
        cachedCurrentImage = snapshot.renderedImage
        statusText = L10n.format("imageEditor.status.historySnapshotRestored", snapshot.name)
    }

    func restoreSelectedHistorySnapshot() {
        guard let selectedHistorySnapshot else { return }
        restoreHistorySnapshot(selectedHistorySnapshot.id)
    }

    func duplicateSelectedHistorySnapshot() {
        guard let selectedHistorySnapshot else { return }
        var duplicated = selectedHistorySnapshot
        duplicated.id = UUID()
        duplicated.name = uniqueHistorySnapshotName(
            L10n.format("imageEditor.history.snapshotCopyName", selectedHistorySnapshot.name)
        )
        if let selectedIndex = selectedHistorySnapshotIndex {
            namedHistorySnapshots.insert(duplicated, at: selectedIndex + 1)
        } else {
            namedHistorySnapshots.append(duplicated)
        }
        selectedHistorySnapshotID = duplicated.id
        statusText = L10n.format("imageEditor.status.historySnapshotDuplicated", duplicated.name)
    }

    func deleteHistorySnapshot(_ id: UUID) {
        guard let index = namedHistorySnapshots.firstIndex(where: { $0.id == id }) else { return }
        let name = namedHistorySnapshots[index].name
        namedHistorySnapshots.remove(at: index)
        if selectedHistorySnapshotID == id {
            let fallbackIndex = min(index, namedHistorySnapshots.count - 1)
            selectedHistorySnapshotID = fallbackIndex >= 0 ? namedHistorySnapshots[fallbackIndex].id : nil
        }
        statusText = L10n.format("imageEditor.status.historySnapshotDeleted", name)
    }

    func deleteSelectedHistorySnapshot() {
        guard let selectedHistorySnapshot else { return }
        deleteHistorySnapshot(selectedHistorySnapshot.id)
    }

    func selectHistorySnapshot(_ id: UUID) {
        guard let snapshot = namedHistorySnapshots.first(where: { $0.id == id }) else { return }
        selectedHistorySnapshotID = id
        statusText = L10n.format("imageEditor.status.historySnapshotSelected", snapshot.name)
    }

    func selectPreviousHistorySnapshot() {
        guard canSelectPreviousHistorySnapshot, let selectedHistorySnapshotIndex else { return }
        selectHistorySnapshot(namedHistorySnapshots[selectedHistorySnapshotIndex - 1].id)
    }

    func selectNextHistorySnapshot() {
        guard canSelectNextHistorySnapshot, let selectedHistorySnapshotIndex else { return }
        selectHistorySnapshot(namedHistorySnapshots[selectedHistorySnapshotIndex + 1].id)
    }

    func clearHistoryStates() {
        clearUndoHistory()
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
        guard let selection = document.selection else { return }
        pushUndo()
        reselectableSelection = selection
        document.selection = nil
        isQuickMaskMode = false
        appendHistory(L10n.text("imageEditor.history.selectionCleared"))
        statusText = L10n.text("imageEditor.status.selectionCleared")
    }

    func toggleQuickMaskMode() {
        guard hasSelection else {
            isQuickMaskMode = false
            quickMaskOverlayImage = nil
            statusText = L10n.text("imageEditor.status.quickMaskNeedsSelection")
            return
        }

        isQuickMaskMode.toggle()
        refreshQuickMaskOverlay()
        statusText = L10n.text(
            isQuickMaskMode
                ? "imageEditor.status.quickMaskEnabled"
                : "imageEditor.status.quickMaskDisabled"
        )
    }

    func setQuickMaskOverlayTarget(_ target: ImageEditorQuickMaskOverlayTarget) {
        guard quickMaskOverlayTarget != target else { return }
        quickMaskOverlayTarget = target
        persistQuickMaskPreferences()
        refreshQuickMaskOverlay()
        statusText = L10n.text("imageEditor.status.quickMaskOptionsUpdated")
    }

    func setQuickMaskOverlayColor(_ color: NSColor) {
        let normalizedColor = ImageEditorProjectColor(color: color).nsColor
        guard quickMaskOverlayColor != normalizedColor else { return }
        quickMaskOverlayColor = normalizedColor
        persistQuickMaskPreferences()
        refreshQuickMaskOverlay()
        statusText = L10n.text("imageEditor.status.quickMaskOptionsUpdated")
    }

    func setQuickMaskOverlayOpacity(_ opacity: CGFloat) {
        let normalizedOpacity = CGFloat(
            max(
                ImageEditorQuickMaskPreferences.minimumOpacity,
                min(ImageEditorQuickMaskPreferences.maximumOpacity, Double(opacity))
            )
        )
        guard quickMaskOverlayOpacity != normalizedOpacity else { return }
        quickMaskOverlayOpacity = normalizedOpacity
        persistQuickMaskPreferences()
        refreshQuickMaskOverlay()
        statusText = L10n.text("imageEditor.status.quickMaskOptionsUpdated")
    }

    private func persistQuickMaskPreferences() {
        ImageEditorQuickMaskPreferences(
            target: quickMaskOverlayTarget,
            color: ImageEditorProjectColor(color: quickMaskOverlayColor),
            opacity: Double(quickMaskOverlayOpacity)
        ).save(to: workspacePreferencesDefaults)
    }

    private func persistBrushDynamicsPreferences() {
        ImageEditorBrushDynamicsPreferences(
            pressureControlsSize: brushPressureControlsSize,
            pressureControlsOpacity: brushPressureControlsOpacity,
            pressureControlsFlow: brushPressureControlsFlow,
            pressureSensitivity: Double(brushPressureSensitivity),
            minimumDiameter: Double(brushMinimumDiameter),
            minimumOpacity: Double(brushMinimumOpacity),
            minimumFlow: Double(brushMinimumFlow),
            tiltControlsShape: brushTiltControlsShape,
            tipRoundness: Double(brushTipRoundness),
            tipAngleDegrees: Double(brushTipAngleDegrees),
            smoothing: Double(brushSmoothing)
        ).save(to: workspacePreferencesDefaults)
    }

    private func persistRetouchDynamicsPreferences() {
        ImageEditorRetouchDynamicsPreferences(
            pressureControlsSize: retouchPressureControlsSize,
            pressureSensitivity: Double(retouchPressureSensitivity)
        ).save(to: workspacePreferencesDefaults)
    }

    private func persistBrushPresetPreferences() {
        ImageEditorBrushPresetPreferences(presets: customBrushPresets)
            .save(to: workspacePreferencesDefaults)
    }

    func persistLayerStylePresetPreferences() {
        ImageEditorLayerStylePresetPreferences(presets: customLayerStylePresets)
            .save(to: workspacePreferencesDefaults)
    }

    func persistLayerStylePresetUsagePreferences() {
        ImageEditorLayerStylePresetUsagePreferences(
            favoriteIDs: favoriteLayerStylePresetIDs,
            recentIDs: recentLayerStylePresetIDs
        ).save(to: workspacePreferencesDefaults)
    }

    func setBrushPressureControlsSize(_ isEnabled: Bool) {
        guard brushPressureControlsSize != isEnabled else { return }
        brushPressureControlsSize = isEnabled
        persistBrushDynamicsPreferences()
    }

    func setBrushPressureControlsOpacity(_ isEnabled: Bool) {
        guard brushPressureControlsOpacity != isEnabled else { return }
        brushPressureControlsOpacity = isEnabled
        persistBrushDynamicsPreferences()
    }

    func setBrushPressureControlsFlow(_ isEnabled: Bool) {
        guard brushPressureControlsFlow != isEnabled else { return }
        brushPressureControlsFlow = isEnabled
        persistBrushDynamicsPreferences()
    }

    func setBrushPressureSensitivity(_ sensitivity: CGFloat) {
        let normalized = max(0, min(100, sensitivity))
        guard brushPressureSensitivity != normalized else { return }
        brushPressureSensitivity = normalized
        persistBrushDynamicsPreferences()
    }

    func setBrushMinimumDiameter(_ diameter: CGFloat) {
        let normalized = max(0, min(100, diameter))
        guard brushMinimumDiameter != normalized else { return }
        brushMinimumDiameter = normalized
        persistBrushDynamicsPreferences()
    }

    func setBrushMinimumOpacity(_ opacity: CGFloat) {
        let normalized = max(0, min(100, opacity))
        guard brushMinimumOpacity != normalized else { return }
        brushMinimumOpacity = normalized
        persistBrushDynamicsPreferences()
    }

    func setBrushMinimumFlow(_ flow: CGFloat) {
        let normalized = max(0, min(100, flow))
        guard brushMinimumFlow != normalized else { return }
        brushMinimumFlow = normalized
        persistBrushDynamicsPreferences()
    }

    func setBrushTiltControlsShape(_ isEnabled: Bool) {
        guard brushTiltControlsShape != isEnabled else { return }
        brushTiltControlsShape = isEnabled
        persistBrushDynamicsPreferences()
    }

    func setBrushSmoothing(_ smoothing: CGFloat) {
        let normalized = max(0, min(100, smoothing))
        guard brushSmoothing != normalized else { return }
        brushSmoothing = normalized
        persistBrushDynamicsPreferences()
    }

    func setBrushTipRoundness(_ roundness: CGFloat) {
        let normalized = max(10, min(100, roundness))
        guard brushTipRoundness != normalized else { return }
        brushTipRoundness = normalized
        persistBrushDynamicsPreferences()
    }

    func setBrushTipAngleDegrees(_ angle: CGFloat) {
        let normalized = max(-180, min(180, angle))
        guard brushTipAngleDegrees != normalized else { return }
        brushTipAngleDegrees = normalized
        persistBrushDynamicsPreferences()
    }

    func setRetouchPressureControlsSize(_ isEnabled: Bool) {
        guard retouchPressureControlsSize != isEnabled else { return }
        retouchPressureControlsSize = isEnabled
        persistRetouchDynamicsPreferences()
    }

    func setRetouchPressureSensitivity(_ sensitivity: CGFloat) {
        let normalized = max(0, min(100, sensitivity))
        guard retouchPressureSensitivity != normalized else { return }
        retouchPressureSensitivity = normalized
        persistRetouchDynamicsPreferences()
    }

    private func refreshSelectionEdgeGeometry() {
        let selection = document.selection
        let canvasSize = document.canvasSize
        guard selection != selectionEdgeGeometrySource || canvasSize != selectionEdgeGeometryCanvasSize else {
            return
        }
        selectionEdgeGeometrySource = selection
        selectionEdgeGeometryCanvasSize = canvasSize
        selectionEdgeGeometry = selection.map {
            ImageEditorSelectionEdgeGeometry.make(selection: $0, canvasSize: canvasSize)
        }
    }

    private func refreshQuickMaskOverlay() {
        guard isQuickMaskMode, let selection = document.selection else {
            quickMaskOverlayImage = nil
            return
        }
        quickMaskOverlayImage = selection.quickMaskOverlayImage(
            canvasSize: document.canvasSize,
            color: quickMaskOverlayColor,
            opacity: quickMaskOverlayOpacity,
            target: quickMaskOverlayTarget
        )
    }

    func invertSelection() {
        guard document.selection != nil else { return }
        pushUndo()
        document.selection?.isInverted.toggle()
        appendHistory(L10n.text("imageEditor.history.selectionInverted"))
        statusText = L10n.text("imageEditor.status.selectionInverted")
    }

    func selectMarqueeShape(_ shape: ImageEditorMarqueeShape) {
        marqueeShape = shape
        selectTool(.marquee)
    }

    func marqueeSelectionRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let boundedStart = ImageEditorCanvasGeometry.boundedCanvasPoint(
            start,
            canvasSize: document.canvasSize
        )
        let boundedEnd = ImageEditorCanvasGeometry.boundedCanvasPoint(
            end,
            canvasSize: document.canvasSize
        )
        let adjustedEnd: CGPoint
        if marqueeShape.hasFixedAspectRatio {
            let side = min(abs(boundedEnd.x - boundedStart.x), abs(boundedEnd.y - boundedStart.y))
            adjustedEnd = CGPoint(
                x: boundedStart.x + (boundedEnd.x >= boundedStart.x ? side : -side),
                y: boundedStart.y + (boundedEnd.y >= boundedStart.y ? side : -side)
            )
        } else {
            adjustedEnd = boundedEnd
        }
        return CGRect(
            x: min(boundedStart.x, adjustedEnd.x),
            y: min(boundedStart.y, adjustedEnd.y),
            width: abs(adjustedEnd.x - boundedStart.x),
            height: abs(adjustedEnd.y - boundedStart.y)
        ).intersection(CGRect(origin: .zero, size: document.canvasSize))
    }

    func createMarqueeSelection(from start: CGPoint, to end: CGPoint) {
        let rect = marqueeSelectionRect(from: start, to: end)
        guard rect.width > 2, rect.height > 2 else { return }
        let selection: ImageEditorSelection?
        if marqueeShape.isEllipse {
            selection = ImageEditorSelection.ellipse(rect)
        } else {
            selection = .rectangle(rect)
        }
        guard let selection else { return }
        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.selection")
    }

    func createRectSelection(from start: CGPoint, to end: CGPoint) {
        let previousShape = marqueeShape
        marqueeShape = .rectangle
        createMarqueeSelection(from: start, to: end)
        marqueeShape = previousShape
    }

    func createLassoSelection(points: [CGPoint]) {
        let boundedPoints = points.map { point in
            ImageEditorCanvasGeometry.boundedCanvasPoint(point, canvasSize: document.canvasSize)
        }
        guard let selection = ImageEditorSelection.polygon(boundedPoints) else { return }
        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.selection")
    }

    func createMagicSelection(at point: CGPoint?, tolerance: CGFloat? = nil) {
        guard let point,
              let selection = magicSelection(at: point, tolerance: tolerance)
        else { return }
        applySelectionCandidate(selection, replaceHistoryKey: "imageEditor.history.magicSelection")
    }

    func createQuickSelection(points: [CGPoint], tolerance: CGFloat? = nil) {
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        let minimumDistance = max(8, brushSize * 0.65)
        let maximumSamples = 18
        var sampledPoints: [CGPoint] = []

        for point in points where canvasBounds.contains(point) {
            guard sampledPoints.count < maximumSamples else { break }
            guard sampledPoints.last.map({ hypot($0.x - point.x, $0.y - point.y) >= minimumDistance }) ?? true else { continue }
            sampledPoints.append(point)
        }

        guard !sampledPoints.isEmpty else { return }

        var combinedSelection: ImageEditorSelection?
        for point in sampledPoints {
            guard let candidate = magicSelection(at: point, tolerance: tolerance) else { continue }
            combinedSelection = ImageEditorSelection.combined(
                current: combinedSelection,
                candidate: candidate,
                mode: .add,
                canvasSize: document.canvasSize
            )
        }

        guard let combinedSelection else { return }
        applySelectionCandidate(combinedSelection, replaceHistoryKey: "imageEditor.history.quickSelection")
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
        mutateDocumentWithoutInvalidatingRenderedImageCaches { document in
            document.selection = nextSelection
        }
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
        let shouldEditMask = editingMask && (document.layers.first { $0.id == id }?.mask != nil)
        if !extendingSelection,
           document.selectedLayerID == id,
           document.selectedLayerIDs == [id],
           isEditingLayerMask == shouldEditMask {
            return
        }
        let selectedLayer = document.layers.first { $0.id == id }
        let isXomoComponentGroup = selectedLayer?.isGroup == true
            && selectedLayer?.xomoComponentInstance != nil
        if isXomoComponentGroup, !extendingSelection {
            mutateDocumentWithoutInvalidatingRenderedImageCaches { document in
                document.selectedLayerID = id
                document.selectedLayerIDs = [id]
            }
            layerSelectionAnchorID = id
            isEditingLayerMask = false
            return
        }
        if extendingSelection && !editingMask {
            mutateDocumentWithoutInvalidatingRenderedImageCaches { document in
                if document.selectedLayerIDs.contains(id), document.selectedLayerIDs.count > 1 {
                    document.selectedLayerIDs.remove(id)
                    if document.selectedLayerID == id {
                        document.selectedLayerID = document.layers.reversed().first {
                            document.selectedLayerIDs.contains($0.id)
                        }?.id
                    }
                } else {
                    document.selectedLayerIDs.insert(id)
                    document.selectedLayerID = id
                }
            }
            isEditingLayerMask = false
            layerSelectionAnchorID = document.selectedLayerIDs.contains(id) ? id : document.selectedLayerID
            syncAdjustmentControlsFromSelection()
            syncFilterControlsFromSelection()
            syncTextControlsFromSelection()
            syncShapeControlsFromSelection()
            syncPathControlsFromSelection()
            return
        }

        mutateDocumentWithoutInvalidatingRenderedImageCaches { document in
            document.selectedLayerID = id
            document.selectedLayerIDs = [id]
        }
        layerSelectionAnchorID = id
        if isEditingLayerMask != shouldEditMask {
            isEditingLayerMask = shouldEditMask
        }
        syncAdjustmentControlsFromSelection()
        syncFilterControlsFromSelection()
        syncTextControlsFromSelection()
        syncShapeControlsFromSelection()
        syncPathControlsFromSelection()
    }

    func syncLayerSelectionAnchorToPrimarySelection() {
        layerSelectionAnchorID = document.selectedLayerID
    }

    func selectLayerRange(
        to id: UUID,
        among visibleLayerIDs: [UUID],
        addingToSelection: Bool = false
    ) {
        let existingIDs = Set(document.layers.map(\.id))
        let orderedIDs = visibleLayerIDs.filter(existingIDs.contains)
        guard let targetIndex = orderedIDs.firstIndex(of: id) else { return }

        let anchorID = layerSelectionAnchorID.flatMap { orderedIDs.contains($0) ? $0 : nil }
            ?? document.selectedLayerID.flatMap { orderedIDs.contains($0) ? $0 : nil }
            ?? id
        guard let anchorIndex = orderedIDs.firstIndex(of: anchorID) else { return }

        let lowerIndex = min(anchorIndex, targetIndex)
        let upperIndex = max(anchorIndex, targetIndex)
        let rangeIDs = Set(orderedIDs[lowerIndex...upperIndex])
        mutateDocumentWithoutInvalidatingRenderedImageCaches { document in
            document.selectedLayerIDs = addingToSelection
                ? document.selectedLayerIDs.union(rangeIDs)
                : rangeIDs
            document.selectedLayerID = id
        }
        layerSelectionAnchorID = anchorID
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
        statusText = L10n.format(
            "imageEditor.status.layerRangeSelected",
            document.selectedLayerIDs.count
        )
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
        layerSelectionAnchorID = nil
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

    func selectVisibleLayers() {
        let layerIDs = Set(document.layers.filter { document.isEffectivelyVisible($0) }.map(\.id))
        selectLayerIDs(layerIDs, statusKey: "imageEditor.status.layerSelectVisible")
    }

    func selectHiddenLayers() {
        let layerIDs = Set(document.layers.filter { !document.isEffectivelyVisible($0) }.map(\.id))
        selectLayerIDs(layerIDs, statusKey: "imageEditor.status.layerSelectHidden")
    }

    func selectLockedLayers() {
        let layerIDs = Set(document.layers.filter { document.isEffectivelyLocked($0) }.map(\.id))
        selectLayerIDs(layerIDs, statusKey: "imageEditor.status.layerSelectLocked")
    }

    func selectUnlockedLayers() {
        let layerIDs = Set(document.layers.filter { !document.isEffectivelyLocked($0) }.map(\.id))
        selectLayerIDs(layerIDs, statusKey: "imageEditor.status.layerSelectUnlocked")
    }

    func selectMaskedLayers() {
        selectLayers(matching: .masked, statusKey: "imageEditor.status.layerSelectMasked")
    }

    func selectStyledLayers() {
        selectLayers(matching: .styled, statusKey: "imageEditor.status.layerSelectStyled")
    }

    func selectClippingMaskLayers() {
        selectLayers(matching: .clipping, statusKey: "imageEditor.status.layerSelectClipping")
    }

    func selectSmartFilteredLayers() {
        selectLayers(matching: .smartFiltered, statusKey: "imageEditor.status.layerSelectSmartFiltered")
    }

    func selectLayersWithSameKind() {
        guard let selectedLayer = document.selectedLayer else { return }
        let selectedKind = layerKindFilter(for: selectedLayer)
        let layerIDs = Set(document.layers.filter { selectedKind.matches($0) }.map(\.id))
        guard !layerIDs.isEmpty else { return }
        document.selectedLayerIDs = layerIDs
        document.selectedLayerID = topmostSelectedLayerID()
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
        statusText = L10n.format(
            "imageEditor.status.layerSelectSameKind",
            layerIDs.count,
            selectedKind.title
        )
    }

    func selectSimilarLayers() {
        guard let selectedLayer = document.selectedLayer else { return }
        let selectedKind = layerKindFilter(for: selectedLayer)
        let layerIDs = Set(document.layers.filter { layer in
            selectedKind.matches(layer)
                && layer.blendMode == selectedLayer.blendMode
                && layer.labelColor == selectedLayer.labelColor
        }.map(\.id))
        guard !layerIDs.isEmpty else { return }
        document.selectedLayerIDs = layerIDs
        document.selectedLayerID = topmostSelectedLayerID()
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
        statusText = L10n.format(
            "imageEditor.status.layerSelectSimilar",
            layerIDs.count,
            selectedKind.title,
            selectedLayer.blendMode.title
        )
    }

    func selectLayersWithSameBlendMode() {
        guard let blendMode = document.selectedLayer?.blendMode else { return }
        let layerIDs = Set(document.layers.filter { $0.blendMode == blendMode }.map(\.id))
        guard !layerIDs.isEmpty else { return }
        document.selectedLayerIDs = layerIDs
        document.selectedLayerID = topmostSelectedLayerID()
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
        statusText = L10n.format(
            "imageEditor.status.layerSelectSameBlendMode",
            layerIDs.count,
            blendMode.title
        )
    }

    func selectLayersWithSameLabelColor() {
        guard let labelColor = document.selectedLayer?.labelColor else { return }
        let layerIDs = Set(document.layers.filter { $0.labelColor == labelColor }.map(\.id))
        guard !layerIDs.isEmpty else { return }
        document.selectedLayerIDs = layerIDs
        document.selectedLayerID = topmostSelectedLayerID()
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
        statusText = L10n.format(
            "imageEditor.status.layerSelectSameLabelColor",
            layerIDs.count,
            labelColor.title
        )
    }

    private func selectLayerIDs(_ layerIDs: Set<UUID>, statusKey: String) {
        guard !layerIDs.isEmpty else { return }
        document.selectedLayerIDs = layerIDs
        document.selectedLayerID = topmostSelectedLayerID()
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
        statusText = L10n.format(statusKey, layerIDs.count)
    }

    private func canSelectLayers(matching attributeFilter: ImageEditorLayerAttributeFilter) -> Bool {
        document.layers.contains { attributeFilter.matches($0) }
    }

    private func selectLayers(matching attributeFilter: ImageEditorLayerAttributeFilter, statusKey: String) {
        let layerIDs = Set(document.layers.filter { attributeFilter.matches($0) }.map(\.id))
        selectLayerIDs(layerIDs, statusKey: statusKey)
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
              !isBackgroundLayer(at: index),
              !hasBackgroundLayer
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
        appendHistory(L10n.text("imageEditor.history.layerFromBackground"))
        statusText = L10n.text("imageEditor.status.layerFromBackground")
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
        let sourceLayer = document.layers[index]
        var backgroundLayer = ImageEditorLayer.background(image: backgroundImage)
        backgroundLayer.id = sourceLayer.id
        backgroundLayer.isVisible = sourceLayer.isVisible
        backgroundLayer.linkedLayerIDs = []
        backgroundLayer.labelColor = sourceLayer.labelColor
        document.layers.remove(at: index)
        for survivorIndex in document.layers.indices {
            document.layers[survivorIndex].linkedLayerIDs.remove(sourceLayer.id)
        }
        document.layers.insert(backgroundLayer, at: 0)
        normalizeClippingMasks()
        document.selectedLayerID = backgroundLayer.id
        document.selectedLayerIDs = [backgroundLayer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.backgroundFromLayer"))
        statusText = L10n.text("imageEditor.status.backgroundFromLayer")
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
        let groupNumber = document.layers.filter(\.isGroup).count + 1
        let group = ImageEditorLayer.group(
            name: L10n.format("imageEditor.layer.groupName", groupNumber),
            size: document.canvasSize
        )
        guard let plan = ImageEditorLayerHierarchyGrouping.groupingPlan(
            layers: document.layers,
            selectedIDs: document.selectedLayerIDs,
            group: group,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) }
        ) else { return }

        pushUndo()
        document.layers = plan.layers
        normalizeClippingMasks()
        document.selectedLayerIDs = plan.selectedLayerIDs
        document.selectedLayerID = plan.primarySelectionID
        layerSelectionAnchorID = plan.primarySelectionID
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
        syncControlsFromLayerSelection()
        statusText = L10n.format("imageEditor.status.layerGroupMembersSelected", memberIDs.count)
    }

    func selectParentGroup() {
        guard let layer = document.selectedLayer,
              let parentGroup = document.group(for: layer)
        else {
            statusText = L10n.text("imageEditor.status.layerNotInGroup")
            return
        }
        document.selectedLayerID = parentGroup.id
        document.selectedLayerIDs = [parentGroup.id]
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
        statusText = L10n.format("imageEditor.status.layerParentGroupSelected", parentGroup.name)
    }

    func moveSelectedLayersIntoGroup() {
        guard let plan = ImageEditorLayerHierarchyMovement.moveIntoGroupPlan(
            layers: document.layers,
            selectedIDs: document.selectedLayerIDs,
            primarySelectionID: document.selectedLayerID,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) }
        ) else {
            statusText = L10n.text("imageEditor.status.layerGroupTargetMissing")
            return
        }

        pushUndo()
        document.layers = plan.layers
        normalizeClippingMasks()
        document.selectedLayerIDs = plan.selectedLayerIDs
        document.selectedLayerID = plan.primarySelectionID
        layerSelectionAnchorID = plan.primarySelectionID
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMoveIntoGroup"))
    }

    func moveSelectedLayersOutOfGroup() {
        guard let plan = ImageEditorLayerHierarchyMovement.moveOutOfGroupsPlan(
            layers: document.layers,
            selectedIDs: document.selectedLayerIDs,
            primarySelectionID: document.selectedLayerID,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) }
        ) else {
            statusText = L10n.text("imageEditor.status.layerNotInGroup")
            return
        }

        pushUndo()
        document.layers = plan.layers
        normalizeClippingMasks()
        document.selectedLayerIDs = plan.selectedLayerIDs
        document.selectedLayerID = plan.primarySelectionID
        layerSelectionAnchorID = plan.primarySelectionID
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

    func ungroupSelectedLayers() {
        guard let plan = ImageEditorLayerHierarchyGrouping.ungroupingPlan(
            layers: document.layers,
            selectedIDs: document.selectedLayerIDs,
            primarySelectionID: document.selectedLayerID,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) }
        ) else { return }

        pushUndo()
        document.layers = plan.layers
        normalizeLayerLinks()
        normalizeClippingMasks()
        document.selectedLayerIDs = plan.selectedLayerIDs
        document.selectedLayerID = plan.primarySelectionID ?? document.layers.last?.id
        if document.selectedLayerIDs.isEmpty, let selectedLayerID = document.selectedLayerID {
            document.selectedLayerIDs = [selectedLayerID]
        }
        layerSelectionAnchorID = document.selectedLayerID
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerUngroup"))
    }

    var canDuplicateSelectedLayer: Bool {
        !ImageEditorLayerHierarchyDuplication.duplicableRootIDs(
            in: document.layers,
            selectedIDs: document.selectedLayerIDs
        ).isEmpty
    }

    func duplicateSelectedLayer() {
        guard let plan = ImageEditorLayerHierarchyDuplication.duplicationPlan(
            layers: document.layers,
            selectedIDs: document.selectedLayerIDs,
            primarySelectionID: document.selectedLayerID,
            duplicateName: { L10n.format("imageEditor.layer.copyName", $0) },
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        ) else { return }

        pushUndo()
        document.layers = plan.layers
        normalizeLayerLinks()
        document.selectedLayerIDs = plan.selectedLayerIDs
        document.selectedLayerID = plan.primarySelectionID
        layerSelectionAnchorID = plan.primarySelectionID
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
        let indices = smartObjectResetTransformTargetIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in indices {
            guard let content = document.layers[index].smartObjectContent else { continue }
            let currentFrame = document.layers[index].frame.standardized
            let resetSize = CGSize(
                width: max(1, content.originalSize.width),
                height: max(1, content.originalSize.height)
            )
            document.layers[index].frame = CGRect(
                x: currentFrame.midX - resetSize.width / 2,
                y: currentFrame.midY - resetSize.height / 2,
                width: resetSize.width,
                height: resetSize.height
            )
        }

        if indices.count == 1 {
            appendHistory(L10n.text("imageEditor.history.layerSmartObjectResetTransform"))
            statusText = L10n.text("imageEditor.status.layerSmartObjectTransformReset")
        } else {
            appendHistory(L10n.text("imageEditor.history.layerSmartObjectResetTransformSelected"))
            statusText = L10n.format("imageEditor.status.layerSmartObjectTransformResetSelected", indices.count)
        }
    }

    func makeSelectedSmartObjectUnique() {
        let indices = smartObjectUniqueTargetIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in indices {
            guard let content = document.layers[index].smartObjectContent else { continue }
            document.layers[index].kind = .smartObject(
                ImageEditorSmartObjectContent(
                    sourceName: content.sourceName,
                    originalSize: content.originalSize,
                    sourceID: UUID()
                )
            )
        }

        if indices.count == 1 {
            appendHistory(L10n.text("imageEditor.history.layerSmartObjectMakeUnique"))
            statusText = L10n.text("imageEditor.status.layerSmartObjectMadeUnique")
        } else {
            appendHistory(L10n.text("imageEditor.history.layerSmartObjectMakeUniqueSelected"))
            statusText = L10n.format("imageEditor.status.layerSmartObjectMadeUniqueSelected", indices.count)
        }
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
        guard let plan = ImageEditorLayerHierarchyDeletion.deletionPlan(
            layers: document.layers,
            selectedIDs: document.selectedLayerIDs,
            primarySelectionID: document.selectedLayerID,
            visibleLayerIDs: visibleLayerRows.map(\.id),
            isEffectivelyLocked: { document.isEffectivelyLocked($0) },
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        ) else { return }
        pushUndo()
        document.layers = plan.layers
        document.selectedLayerIDs = plan.selectedLayerIDs
        document.selectedLayerID = plan.primarySelectionID
        layerSelectionAnchorID = plan.primarySelectionID
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
        appendHistory(L10n.text("imageEditor.history.layerDelete"))
    }

    func toggleLayerVisibility(_ id: UUID, applyingToSelection: Bool = false) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        let targetVisibility = !document.layers[index].isVisible
        let targetIndices = layerRowPropertyTargetIndices(
            clickedLayerID: id,
            applyingToSelection: applyingToSelection
        )
        let changedIndices = targetIndices.filter { document.layers[$0].isVisible != targetVisibility }
        guard !changedIndices.isEmpty else { return }
        pushUndo()
        for targetIndex in changedIndices {
            document.layers[targetIndex].isVisible = targetVisibility
        }
        if targetIndices.count > 1 {
            appendHistory(L10n.text(
                targetVisibility
                    ? "imageEditor.history.layerShowSelected"
                    : "imageEditor.history.layerHideSelected"
            ))
            statusText = L10n.format(
                targetVisibility
                    ? "imageEditor.status.layerShowSelected"
                    : "imageEditor.status.layerHideSelected",
                targetIndices.count
            )
        } else {
            appendHistory(L10n.text("imageEditor.history.layerVisibility"))
        }
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

    func showSelectedLayers() {
        setSelectedLayersVisibility(true)
    }

    func hideSelectedLayers() {
        setSelectedLayersVisibility(false)
    }

    func toggleLayerGroupExpansion(_ id: UUID, recursively: Bool = false) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }),
              document.layers[index].isGroup
        else { return }

        let expanded = !document.layers[index].isGroupExpanded
        let groupIDs: Set<UUID> = recursively ? layerGroupBranchIDs(rootedAt: id) : [id]
        let changedCount = setLayerGroups(groupIDs, expanded: expanded)
        guard changedCount > 0 else { return }

        if !expanded {
            normalizeLayerSelectionAfterGroupCollapse(fallbackGroupIDs: [id])
        }
        if recursively {
            statusText = L10n.format(
                expanded
                    ? "imageEditor.status.layerGroupsExpanded"
                    : "imageEditor.status.layerGroupsCollapsed",
                changedCount
            )
        }
    }

    func expandSelectedLayerGroups() {
        setSelectedLayerGroupsExpanded(true)
    }

    func collapseSelectedLayerGroups() {
        setSelectedLayerGroupsExpanded(false)
    }

    func toggleLayerLock(_ id: UUID, applyingToSelection: Bool = false) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        let targetLock = !document.layers[index].isLocked
        let targetIndices = layerRowPropertyTargetIndices(
            clickedLayerID: id,
            applyingToSelection: applyingToSelection
        )
        let changedIndices = targetIndices.filter { document.layers[$0].isLocked != targetLock }
        guard !changedIndices.isEmpty else { return }
        pushUndo()
        for targetIndex in changedIndices {
            document.layers[targetIndex].isLocked = targetLock
        }
        if targetLock, targetIndices.contains(where: { document.layers[$0].id == document.selectedLayerID }) {
            isEditingLayerMask = false
        }
        if targetIndices.count > 1 {
            appendHistory(L10n.text(
                targetLock
                    ? "imageEditor.history.layerLockSelected"
                    : "imageEditor.history.layerUnlockSelected"
            ))
            statusText = L10n.text(
                targetLock
                    ? "imageEditor.status.layerLockSelected"
                    : "imageEditor.status.layerUnlockSelected"
            )
        } else {
            appendHistory(L10n.text("imageEditor.history.layerLock"))
        }
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

    func toggleLayerTransparentPixelsLock(_ id: UUID, applyingToSelection: Bool = false) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        guard canToggleTransparentPixelsLock(for: document.layers[index]) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let targetLock = !document.layers[index].locksTransparentPixels
        let targetIndices = layerRowPropertyTargetIndices(
            clickedLayerID: id,
            applyingToSelection: applyingToSelection
        )
        let changedIndices = targetIndices.filter { targetIndex in
            canToggleTransparentPixelsLock(for: document.layers[targetIndex])
                && document.layers[targetIndex].locksTransparentPixels != targetLock
        }
        guard !changedIndices.isEmpty else { return }
        pushUndo()
        for targetIndex in changedIndices {
            document.layers[targetIndex].locksTransparentPixels = targetLock
        }
        appendLayerRowLockHistory(
            isBatch: targetIndices.count > 1,
            isLocked: targetLock,
            singleHistoryKey: "imageEditor.history.layerTransparentPixelsLock",
            selectedLockHistoryKey: "imageEditor.history.layerTransparentPixelsLockSelected",
            selectedUnlockHistoryKey: "imageEditor.history.layerTransparentPixelsUnlockSelected",
            selectedLockStatusKey: "imageEditor.status.layerTransparentPixelsLockSelected",
            selectedUnlockStatusKey: "imageEditor.status.layerTransparentPixelsUnlockSelected"
        )
    }

    func toggleLayerPixelsLock(_ id: UUID, applyingToSelection: Bool = false) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        guard canTogglePixelsLock(for: document.layers[index]) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let targetLock = !document.layers[index].locksPixels
        let targetIndices = layerRowPropertyTargetIndices(
            clickedLayerID: id,
            applyingToSelection: applyingToSelection
        )
        let changedIndices = targetIndices.filter { targetIndex in
            canTogglePixelsLock(for: document.layers[targetIndex])
                && document.layers[targetIndex].locksPixels != targetLock
        }
        guard !changedIndices.isEmpty else { return }
        pushUndo()
        for targetIndex in changedIndices {
            document.layers[targetIndex].locksPixels = targetLock
        }
        appendLayerRowLockHistory(
            isBatch: targetIndices.count > 1,
            isLocked: targetLock,
            singleHistoryKey: "imageEditor.history.layerPixelsLock",
            selectedLockHistoryKey: "imageEditor.history.layerPixelsLockSelected",
            selectedUnlockHistoryKey: "imageEditor.history.layerPixelsUnlockSelected",
            selectedLockStatusKey: "imageEditor.status.layerPixelsLockSelected",
            selectedUnlockStatusKey: "imageEditor.status.layerPixelsUnlockSelected"
        )
    }

    func toggleLayerPositionLock(_ id: UUID, applyingToSelection: Bool = false) {
        guard let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        guard canTogglePositionLock(for: document.layers[index]) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let targetLock = !document.layers[index].locksPosition
        let targetIndices = layerRowPropertyTargetIndices(
            clickedLayerID: id,
            applyingToSelection: applyingToSelection
        )
        let changedIndices = targetIndices.filter { targetIndex in
            canTogglePositionLock(for: document.layers[targetIndex])
                && document.layers[targetIndex].locksPosition != targetLock
        }
        guard !changedIndices.isEmpty else { return }
        pushUndo()
        for targetIndex in changedIndices {
            document.layers[targetIndex].locksPosition = targetLock
        }
        appendLayerRowLockHistory(
            isBatch: targetIndices.count > 1,
            isLocked: targetLock,
            singleHistoryKey: "imageEditor.history.layerPositionLock",
            selectedLockHistoryKey: "imageEditor.history.layerPositionLockSelected",
            selectedUnlockHistoryKey: "imageEditor.history.layerPositionUnlockSelected",
            selectedLockStatusKey: "imageEditor.status.layerPositionLockSelected",
            selectedUnlockStatusKey: "imageEditor.status.layerPositionUnlockSelected"
        )
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
        let normalizedOpacity = max(0, min(1, opacity))
        let indices = selectedLayerOpacityTargetIndices().filter { document.layers[$0].opacity != normalizedOpacity }
        guard !indices.isEmpty else { return }
        for index in indices {
            document.layers[index].opacity = normalizedOpacity
        }
        invalidateRenderedImageCaches()
        updateStatus()
    }

    func setSelectedLayerFillOpacity(_ fillOpacity: Double) {
        let normalizedOpacity = max(0, min(1, fillOpacity))
        let indices = selectedLayerFillOpacityTargetIndices().filter { document.layers[$0].fillOpacity != normalizedOpacity }
        guard !indices.isEmpty else { return }
        for index in indices {
            document.layers[index].fillOpacity = normalizedOpacity
        }
        invalidateRenderedImageCaches()
        updateStatus()
    }

    func setSelectedLayerBlendIfSourceBlack(_ value: Double) {
        let indices = selectedLayerBlendIfTargetIndices()
        guard !indices.isEmpty else { return }
        var didChange = false
        for index in indices {
            let white = document.layers[index].blendIfSourceWhite
            let nextValue = min(max(0, value), white)
            guard document.layers[index].blendIfSourceBlack != nextValue else { continue }
            document.layers[index].blendIfSourceBlack = nextValue
            didChange = true
        }
        if didChange {
            updateStatus()
        }
    }

    func setSelectedLayerBlendIfSourceWhite(_ value: Double) {
        let indices = selectedLayerBlendIfTargetIndices()
        guard !indices.isEmpty else { return }
        var didChange = false
        for index in indices {
            let black = document.layers[index].blendIfSourceBlack
            let nextValue = max(black, min(1, value))
            guard document.layers[index].blendIfSourceWhite != nextValue else { continue }
            document.layers[index].blendIfSourceWhite = nextValue
            didChange = true
        }
        if didChange {
            updateStatus()
        }
    }

    func setSelectedLayerBlendIfUnderlyingBlack(_ value: Double) {
        let indices = selectedLayerBlendIfTargetIndices()
        guard !indices.isEmpty else { return }
        var didChange = false
        for index in indices {
            let white = document.layers[index].blendIfUnderlyingWhite
            let nextValue = min(max(0, value), white)
            guard document.layers[index].blendIfUnderlyingBlack != nextValue else { continue }
            document.layers[index].blendIfUnderlyingBlack = nextValue
            didChange = true
        }
        if didChange {
            updateStatus()
        }
    }

    func setSelectedLayerBlendIfUnderlyingWhite(_ value: Double) {
        let indices = selectedLayerBlendIfTargetIndices()
        guard !indices.isEmpty else { return }
        var didChange = false
        for index in indices {
            let black = document.layers[index].blendIfUnderlyingBlack
            let nextValue = max(black, min(1, value))
            guard document.layers[index].blendIfUnderlyingWhite != nextValue else { continue }
            document.layers[index].blendIfUnderlyingWhite = nextValue
            didChange = true
        }
        if didChange {
            updateStatus()
        }
    }

    func setSelectedLayerMaskDensity(_ density: Double) {
        let normalizedDensity = max(0, min(1, density))
        let indices = selectedLayerMaskPropertyTargetIndices().filter { document.layers[$0].maskDensity != normalizedDensity }
        guard !indices.isEmpty else { return }
        for index in indices {
            document.layers[index].maskDensity = normalizedDensity
        }
        updateStatus()
    }

    func setSelectedLayerMaskFeather(_ feather: Double) {
        let normalizedFeather = max(0, min(80, feather))
        let indices = selectedLayerMaskPropertyTargetIndices().filter { document.layers[$0].maskFeather != normalizedFeather }
        guard !indices.isEmpty else { return }
        for index in indices {
            document.layers[index].maskFeather = normalizedFeather
        }
        updateStatus()
    }

    func setSelectedLayerBlendMode(_ blendMode: ImageEditorBlendMode) {
        let indices = selectedLayerBlendModeTargetIndices(for: blendMode).filter { document.layers[$0].blendMode != blendMode }
        guard !indices.isEmpty else { return }
        pushUndo()
        for index in indices {
            document.layers[index].blendMode = blendMode
        }
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

    func toggleClippingMasksForSelectedLayers() {
        guard selectedLayerCount > 0 else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        if selectedLayerCount == 1 {
            toggleSelectedLayerClippingMask()
        } else if canCreateClippingMasksForSelectedLayers {
            createClippingMasksForSelectedLayers()
        } else if canReleaseSelectedClippingMasks {
            releaseSelectedClippingMasks()
        } else {
            statusText = L10n.text("imageEditor.status.operationFailed")
        }
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
        guard let sourcePlan = hierarchyMergeDownPlan,
              let selectedIndex = document.layers.firstIndex(where: {
                $0.id == sourcePlan.primarySourceLayerID
              })
        else { return }

        if sourcePlan.kind == .group {
            let group = document.layers[selectedIndex]
            let merged = flattenedLayer(
                name: group.name,
                image: document.compositedImage(includingOnly: sourcePlan.sourceLayerIDs)
            )
            applyHierarchyMerge(
                sourcePlan,
                mergedLayer: merged,
                historyKey: "imageEditor.history.layerMergeGroup",
                statusKey: "imageEditor.status.layerMergeGroup"
            )
            return
        }

        guard let lowerSourceLayerID = sourcePlan.lowerSourceLayerID,
              let lowerIndex = document.layers.firstIndex(where: { $0.id == lowerSourceLayerID })
        else { return }
        let selectedLayer = document.layers[selectedIndex]
        let merged: ImageEditorLayer?
        if selectedLayer.isAdjustment {
            merged = mergedAdjustmentLayer(lowerIndex: lowerIndex, adjustmentIndex: selectedIndex)
        } else if selectedLayer.isFilter {
            merged = mergedFilterLayer(lowerIndex: lowerIndex, filterIndex: selectedIndex)
        } else {
            merged = mergedLayer(lowerIndex: lowerIndex, upperIndex: selectedIndex)
        }
        guard let merged else { return }
        applyHierarchyMerge(
            sourcePlan,
            mergedLayer: merged,
            historyKey: "imageEditor.history.layerMergeDown"
        )
    }

    func stampVisibleLayers() {
        let sourceLayerIDs = ImageEditorLayerCompositeHierarchy.visibleSourceIDs(
            in: document.layers,
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        )
        guard let plan = ImageEditorLayerCompositeHierarchy.stampVisiblePlan(
            layers: document.layers,
            sourceLayerIDs: sourceLayerIDs
        ) else { return }
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
        pushUndo()
        document.layers.insert(layer, at: plan.insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerStampVisible"))
    }

    func stampSelectedLayers() {
        guard let plan = selectedStampPlan,
              document.layers.contains(where: { layer in
                plan.sourceLayerIDs.contains(layer.id) && document.shouldComposite(layer)
              })
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        var layer = ImageEditorLayer.blank(
            name: L10n.text("imageEditor.layer.selectedStampName"),
            size: document.canvasSize
        )
        layer.image = document.compositedImage(
            includingOnly: plan.sourceLayerIDs,
            within: plan.parentGroupID
        ).normalizedBitmapImage()
        layer.frame = CGRect(origin: .zero, size: document.canvasSize)
        layer.opacity = 1
        layer.fillOpacity = 1
        layer.blendMode = .normal
        layer.groupID = plan.parentGroupID
        layer.isClippingMask = false
        pushUndo()
        document.layers.insert(layer, at: plan.insertionIndex)
        expandGroupIfNeeded(plan.parentGroupID)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerStampSelected"))
        statusText = L10n.text("imageEditor.status.layerStampSelected")
    }

    func addLayerMask() {
        let indices = layerMaskAddIndices
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        for index in indices {
            document.layers[index].mask = NSImage.opaqueMask(size: maskSize(for: document.layers[index]))
            document.layers[index].isMaskEnabled = true
            document.layers[index].isMaskLinked = true
            document.layers[index].isVectorMaskEnabled = true
            document.layers[index].maskDensity = 1
            document.layers[index].maskFeather = 0
        }
        isEditingLayerMask = true

        if indices.count == 1 {
            appendHistory(L10n.text("imageEditor.history.layerMaskAdd"))
        } else {
            appendHistory(L10n.text("imageEditor.history.layerMaskAddSelected"))
            statusText = L10n.format("imageEditor.status.layerMaskAddedSelected", indices.count)
        }
    }

    func deleteLayerMask() {
        let indices = layerMaskDeleteIndices()
        guard !indices.isEmpty else { return }
        pushUndo()
        for index in indices {
            document.layers[index].mask = nil
            document.layers[index].isMaskEnabled = true
            document.layers[index].isMaskLinked = true
            document.layers[index].maskDensity = 1
            document.layers[index].maskFeather = 0
        }
        isEditingLayerMask = document.selectedLayer?.mask != nil

        if indices.count == 1 {
            appendHistory(L10n.text("imageEditor.history.layerMaskDelete"))
            statusText = L10n.text("imageEditor.status.layerMaskDeleted")
        } else {
            appendHistory(L10n.text("imageEditor.history.layerMaskDeleteSelected"))
            statusText = L10n.format("imageEditor.status.layerMaskDeletedSelected", indices.count)
        }
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
        transformCanvas(historyTitle: L10n.text("imageEditor.history.rotateClockwise")) { layer, canvasSize in
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

    func rotateCounterclockwise() {
        transformCanvas(historyTitle: L10n.text("imageEditor.history.rotateCounterclockwise")) { layer, canvasSize in
            guard let rotated = layer.image.rotated(degrees: -90) else { return nil }
            var output = layer
            output.image = rotated
            output.frame = CGRect(
                x: layer.frame.minY,
                y: canvasSize.width - layer.frame.maxX,
                width: layer.frame.height,
                height: layer.frame.width
            )
            if let mask = layer.mask {
                output.mask = mask.rotated(degrees: -90)
            }
            return output
        } canvasSize: { size in
            CGSize(width: size.height, height: size.width)
        }
    }

    func rotate180() {
        transformCanvas(historyTitle: L10n.text("imageEditor.history.rotate180")) { layer, canvasSize in
            guard let rotated = layer.image.rotated(degrees: 180) else { return nil }
            var output = layer
            output.image = rotated
            output.frame = CGRect(
                x: canvasSize.width - layer.frame.maxX,
                y: canvasSize.height - layer.frame.maxY,
                width: layer.frame.width,
                height: layer.frame.height
            )
            if let mask = layer.mask {
                output.mask = mask.rotated(degrees: 180)
            }
            return output
        } canvasSize: { $0 }
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
        let boxWidth = CGFloat(clampedTextBoxWidth(textBoxWidth))
        let content = ImageEditorTextContent(
            text: text,
            color: foregroundColor,
            fontSize: CGFloat(clampedTextSize(textSize)),
            fontFamilyName: selectedFontFamilyName,
            point: CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding),
            isBold: textBold,
            isItalic: textItalic,
            isUnderlined: textUnderlined,
            isStruckThrough: textStruckThrough,
            characterSpacing: CGFloat(clampedTextCharacterSpacing(textCharacterSpacing)),
            lineSpacing: CGFloat(clampedTextLineSpacing(textLineSpacing)),
            boxWidth: boxWidth,
            boxHeight: boxWidth > 0 ? CGFloat(clampedTextBoxHeight(textBoxHeight)) : 0,
            alignment: selectedTextAlignment,
            leftIndent: CGFloat(clampedTextIndent(textLeftIndent)),
            rightIndent: CGFloat(clampedTextIndent(textRightIndent)),
            firstLineIndent: CGFloat(clampedTextFirstLineIndent(textFirstLineIndent)),
            paragraphSpacing: CGFloat(clampedTextParagraphSpacing(textParagraphSpacing)),
            textCase: selectedTextCase,
            truncatesOverflow: boxWidth > 0 && textBoxHeight > 0 && textTruncatesOverflow,
            verticalAlignment: selectedTextVerticalAlignment
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
        let indices = selectedLayerIndices.filter { document.layers[$0].isText && !document.isEffectivelyPixelsLocked(document.layers[$0]) }
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let updatesTextContent = indices.count == 1
        let color = foregroundColor
        let fontSize = CGFloat(clampedTextSize(textSize))
        let characterSpacing = CGFloat(clampedTextCharacterSpacing(textCharacterSpacing))
        let lineSpacing = CGFloat(clampedTextLineSpacing(textLineSpacing))
        let paragraphSpacing = CGFloat(clampedTextParagraphSpacing(textParagraphSpacing))
        let boxWidth = CGFloat(clampedTextBoxWidth(textBoxWidth))
        let boxHeight = boxWidth > 0 ? CGFloat(clampedTextBoxHeight(textBoxHeight)) : 0
        let alignment = selectedTextAlignment
        let leftIndent = CGFloat(clampedTextIndent(textLeftIndent))
        let rightIndent = CGFloat(clampedTextIndent(textRightIndent))
        let firstLineIndent = CGFloat(clampedTextFirstLineIndent(textFirstLineIndent))
        pushUndo()
        for index in indices {
            guard var content = document.layers[index].textContent else { continue }
            if updatesTextContent {
                content.text = text
            }
            content.color = color
            content.fontSize = fontSize
            content.fontFamilyName = selectedFontFamilyName
            content.point = CGPoint(x: ImageEditorTextContent.drawingPadding, y: ImageEditorTextContent.drawingPadding)
            content.isBold = textBold
            content.isItalic = textItalic
            content.isUnderlined = textUnderlined
            content.isStruckThrough = textStruckThrough
            content.characterSpacing = characterSpacing
            content.lineSpacing = lineSpacing
            content.boxWidth = boxWidth
            content.boxHeight = boxHeight
            content.alignment = alignment
            content.leftIndent = leftIndent
            content.rightIndent = rightIndent
            content.firstLineIndent = firstLineIndent
            content.paragraphSpacing = paragraphSpacing
            content.textCase = selectedTextCase
            content.truncatesOverflow = boxWidth > 0 && boxHeight > 0 && textTruncatesOverflow
            content.verticalAlignment = selectedTextVerticalAlignment
            let layerSize = content.layerSize()
            if let mask = document.layers[index].mask, mask.size != layerSize {
                document.layers[index].mask = mask.resized(to: layerSize)
            }
            document.layers[index].image = NSImage.transparent(size: layerSize)
            document.layers[index].frame.size = layerSize
            document.layers[index].kind = .text(content)
            document.layers[index].name = L10n.format("imageEditor.layer.textName", textLayerNameFragment(content.text))
        }
        appendHistory(L10n.text(indices.count == 1 ? "imageEditor.history.layerTextUpdate" : "imageEditor.history.layerTextUpdateSelected"))
        if indices.count > 1 { statusText = L10n.format("imageEditor.status.layerTextUpdatedSelected", indices.count) }
    }

    func drawBrush(points: [CGPoint], erase: Bool = false) {
        drawBrush(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            erase: erase
        )
    }

    func drawBrush(samples: [ImageEditorBrushStrokeSample], erase: Bool = false) {
        guard !samples.isEmpty else { return }
        if isQuickMaskMode {
            paintQuickMask(samples: samples, reveal: erase)
            return
        }
        if isEditingLayerMask {
            paintSelectedLayerMask(samples: samples, reveal: erase)
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let localSamples = rasterLocalSamples(samples, layer: layer)
        guard let output = layer.image.withBrushStroke(
            samples: localSamples,
            color: foregroundColor,
            settings: ImageEditorBrushStrokeSettings(
                diameter: rasterLocalBrushWidth(brushSize, layer: layer),
                hardness: hardness,
                opacity: opacity,
                flow: brushFlow / 100,
                spacing: brushSpacing / 100,
                pressureControlsSize: brushPressureControlsSize,
                pressureControlsOpacity: brushPressureControlsOpacity,
                pressureControlsFlow: brushPressureControlsFlow,
                pressureSensitivity: brushPressureSensitivity / 100,
                minimumDiameter: brushMinimumDiameter / 100,
                minimumOpacity: brushMinimumOpacity / 100,
                minimumFlow: brushMinimumFlow / 100,
                tiltControlsShape: brushTiltControlsShape,
                tipRoundness: brushTipRoundness / 100,
                tipAngleDegrees: brushTipAngleDegrees,
                smoothing: brushSmoothing / 100
            ),
            erase: erase
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        replaceSelectedLayerRenderedPixels(
            output,
            historyTitle: erase ? L10n.text("imageEditor.history.erase") : L10n.text("imageEditor.history.brush"),
            resetFrame: false
        )
    }

    private func paintQuickMask(samples: [ImageEditorBrushStrokeSample], reveal: Bool) {
        guard let selection = document.selection,
              let currentMask = selection.rasterizedMask(canvasSize: document.canvasSize),
              let updatedMask = currentMask.paintedByQuickMaskStroke(
                samples: samples,
                canvasSize: document.canvasSize,
                diameter: brushSize,
                opacity: opacity,
                hardness: hardness,
                flow: brushFlow / 100,
                spacing: brushSpacing / 100,
                pressureControlsSize: brushPressureControlsSize,
                pressureControlsOpacity: brushPressureControlsOpacity,
                pressureControlsFlow: brushPressureControlsFlow,
                pressureSensitivity: brushPressureSensitivity / 100,
                minimumDiameter: brushMinimumDiameter / 100,
                minimumOpacity: brushMinimumOpacity / 100,
                minimumFlow: brushMinimumFlow / 100,
                tiltControlsShape: brushTiltControlsShape,
                tipRoundness: brushTipRoundness / 100,
                tipAngleDegrees: brushTipAngleDegrees,
                smoothing: brushSmoothing / 100,
                reveal: reveal
              )
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let bounds = updatedMask.selectedBounds(in: document.canvasSize)
            ?? CGRect(origin: .zero, size: document.canvasSize)
        pushUndo()
        document.selection = .raster(mask: updatedMask, bounds: bounds)
        appendHistory(
            L10n.text(
                reveal
                    ? "imageEditor.history.quickMaskReveal"
                    : "imageEditor.history.quickMaskHide"
            )
        )
        statusText = L10n.text(
            reveal
                ? "imageEditor.status.quickMaskRevealed"
                : "imageEditor.status.quickMaskHidden"
        )
    }

    func setCloneSource(at point: CGPoint?) {
        cloneSourcePoint = point
        cloneStampAlignedCanvasOffset = nil
        isSettingCloneSource = false
        statusText = point == nil
            ? L10n.text("imageEditor.status.cloneSourceMissing")
            : L10n.text("imageEditor.status.cloneSourceSet")
    }

    func beginSettingCloneSource() {
        isSettingCloneSource = true
        statusText = L10n.text("imageEditor.status.cloneSourcePending")
    }

    func sampledBrushPreviewSourcePoint(
        for tool: ImageEditorTool,
        strokeStart: CGPoint,
        currentDestination: CGPoint
    ) -> CGPoint? {
        let sourcePoint: CGPoint
        let isAligned: Bool
        let alignedOffset: CGSize?
        switch tool {
        case .cloneStamp:
            guard let cloneSourcePoint else { return nil }
            sourcePoint = cloneSourcePoint
            isAligned = isCloneStampAligned
            alignedOffset = cloneStampAlignedCanvasOffset
        case .healingBrush:
            guard healingBrushMode == .source else { return nil }
            guard let healingSourcePoint else { return nil }
            sourcePoint = healingSourcePoint
            isAligned = isHealingBrushAligned
            alignedOffset = healingBrushAlignedCanvasOffset
        default:
            return nil
        }

        return ImageEditorSampledBrushOffsetResolution.resolve(
            sourcePoint: sourcePoint,
            destinationStart: strokeStart,
            isAligned: isAligned,
            alignedOffset: alignedOffset
        ).sourcePreviewPoint(at: currentDestination)
    }

    func cloneStamp(points: [CGPoint]) {
        cloneStamp(samples: points.map { ImageEditorBrushStrokeSample(point: $0) })
    }

    func cloneStamp(samples: [ImageEditorBrushStrokeSample]) {
        guard !samples.isEmpty else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let sourcePoint = cloneSourcePoint, let destinationStart = samples.first?.point else {
            statusText = L10n.text("imageEditor.status.cloneSourceMissing")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        let offsetResolution = ImageEditorSampledBrushOffsetResolution.resolve(
            sourcePoint: sourcePoint,
            destinationStart: destinationStart,
            isAligned: isCloneStampAligned,
            alignedOffset: cloneStampAlignedCanvasOffset
        )
        guard let samplingInput = sampledBrushInput(
            for: layer,
            canvasOffset: offsetResolution.canvasOffset,
            sampleSource: cloneStampSampleSource
        ),
              let output = layer.image.normalizedBitmapImage().withCloneStamp(
            samples: rasterLocalSamples(samples, layer: layer),
            sourceOffset: samplingInput.localOffset,
            sourceImage: samplingInput.image,
            width: rasterLocalBrushWidth(brushSize, layer: layer),
            opacity: opacity,
            hardness: hardness,
            pressureControlsSize: retouchPressureControlsSize,
            pressureSensitivity: retouchPressureSensitivity / 100
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        cloneStampAlignedCanvasOffset = offsetResolution.nextAlignedOffset

        replaceSelectedLayerRenderedPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.cloneStamp"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.cloneStamped")
    }

    func toneBrush(
        points: [CGPoint],
        burn: Bool,
        airbrushPulsePoints: [CGPoint] = []
    ) {
        toneBrush(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            burn: burn,
            airbrushPulseSamples: airbrushPulsePoints.map {
                ImageEditorBrushStrokeSample(point: $0)
            }
        )
    }

    func toneBrush(
        samples: [ImageEditorBrushStrokeSample],
        burn: Bool,
        airbrushPulseSamples: [ImageEditorBrushStrokeSample] = []
    ) {
        guard !samples.isEmpty else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let sourceImage = layer.image.normalizedBitmapImage()
        let localSamples = rasterLocalSamples(samples, layer: layer)
        let localAirbrushPulseSamples = rasterLocalSamples(airbrushPulseSamples, layer: layer)
        guard let output = sourceImage.withToneBrush(
            samples: localSamples,
            width: rasterLocalBrushWidth(brushSize, layer: layer),
            opacity: opacity,
            hardness: hardness,
            burn: burn,
            range: toneRange,
            protectTones: protectToneBrushTones,
            pressureControlsSize: retouchPressureControlsSize,
            pressureSensitivity: retouchPressureSensitivity / 100,
            airbrushPulseSamples: toneBrushAirbrushEnabled ? localAirbrushPulseSamples : []
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerRenderedPixels(
            output,
            historyTitle: burn ? L10n.text("imageEditor.history.burn") : L10n.text("imageEditor.history.dodge"),
            resetFrame: false
        )
        statusText = burn
            ? L10n.text("imageEditor.status.burnApplied")
            : L10n.text("imageEditor.status.dodgeApplied")
    }

    func spongeBrush(points: [CGPoint]) {
        spongeBrush(samples: points.map { ImageEditorBrushStrokeSample(point: $0) })
    }

    func spongeBrush(samples: [ImageEditorBrushStrokeSample]) {
        guard !samples.isEmpty else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let sourceImage = layer.image.normalizedBitmapImage()
        let localSamples = rasterLocalSamples(samples, layer: layer)
        guard let output = sourceImage.withSpongeBrush(
            samples: localSamples,
            width: rasterLocalBrushWidth(brushSize, layer: layer),
            opacity: opacity,
            hardness: hardness,
            mode: spongeMode,
            vibrance: spongeVibranceEnabled,
            pressureControlsSize: retouchPressureControlsSize,
            pressureSensitivity: retouchPressureSensitivity / 100
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerRenderedPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.sponge"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.spongeApplied")
    }

    func blurBrush(points: [CGPoint]) {
        blurBrush(samples: points.map { ImageEditorBrushStrokeSample(point: $0) })
    }

    func blurBrush(samples: [ImageEditorBrushStrokeSample]) {
        guard !samples.isEmpty else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let sourceImage = layer.image.normalizedBitmapImage()
        let localBrushWidth = rasterLocalBrushWidth(brushSize, layer: layer)
        let radius = max(1, min(18, localBrushWidth * 0.35))
        guard let output = sourceImage.withBlurBrush(
            samples: rasterLocalSamples(samples, layer: layer),
            width: localBrushWidth,
            opacity: opacity,
            hardness: hardness,
            radius: radius,
            pressureControlsSize: retouchPressureControlsSize,
            pressureSensitivity: retouchPressureSensitivity / 100
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerRenderedPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.blur"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.blurApplied")
    }

    func sharpenBrush(points: [CGPoint]) {
        sharpenBrush(samples: points.map { ImageEditorBrushStrokeSample(point: $0) })
    }

    func sharpenBrush(samples: [ImageEditorBrushStrokeSample]) {
        guard !samples.isEmpty else { return }
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
            samples: rasterLocalSamples(samples, layer: layer),
            width: rasterLocalBrushWidth(brushSize, layer: layer),
            opacity: opacity,
            hardness: hardness,
            intensity: intensity,
            pressureControlsSize: retouchPressureControlsSize,
            pressureSensitivity: retouchPressureSensitivity / 100
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerRenderedPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.sharpen"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.sharpenApplied")
    }

    func smudgeBrush(points: [CGPoint]) {
        smudgeBrush(samples: points.map { ImageEditorBrushStrokeSample(point: $0) })
    }

    func smudgeBrush(samples: [ImageEditorBrushStrokeSample]) {
        guard samples.count > 1 else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        let sourceImage = layer.image.normalizedBitmapImage()
        let sampledSourceImage: NSImage?
        if smudgeSampleAllLayersEnabled {
            guard let sampledInput = sampledBrushInput(
                for: layer,
                canvasOffset: .zero,
                sampleSource: .allVisible
            ) else {
                statusText = L10n.text("imageEditor.status.operationFailed")
                return
            }
            sampledSourceImage = sampledInput.image
        } else {
            sampledSourceImage = nil
        }
        guard let output = sourceImage.withSmudgeBrush(
            samples: rasterLocalSamples(samples, layer: layer),
            width: rasterLocalBrushWidth(brushSize, layer: layer),
            opacity: opacity,
            hardness: hardness,
            pressureControlsSize: retouchPressureControlsSize,
            pressureSensitivity: retouchPressureSensitivity / 100,
            sourceImage: sampledSourceImage,
            fingerPaintingColor: smudgeFingerPaintingEnabled ? foregroundColor : nil
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerRenderedPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.smudge"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.smudgeApplied")
    }

    func healingBrush(points: [CGPoint]) {
        healingBrush(samples: points.map { ImageEditorBrushStrokeSample(point: $0) })
    }

    func healingBrush(samples: [ImageEditorBrushStrokeSample]) {
        guard !samples.isEmpty else { return }
        guard !isEditingLayerMask else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        guard let layer = editableSelectedLayer() else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        if healingBrushMode == .spot {
            guard let targetContext = sampledBrushInput(
                for: layer,
                canvasOffset: .zero,
                sampleSource: healingBrushSampleSource
            ),
            let output = layer.image.normalizedBitmapImage().withSpotHealingBrush(
                samples: rasterLocalSamples(samples, layer: layer),
                sourceImage: targetContext.image,
                targetContextImage: targetContext.image,
                width: rasterLocalBrushWidth(brushSize, layer: layer),
                opacity: opacity,
                hardness: hardness,
                pressureControlsSize: retouchPressureControlsSize,
                pressureSensitivity: retouchPressureSensitivity / 100
            ) else {
                statusText = L10n.text("imageEditor.status.operationFailed")
                return
            }
            replaceSelectedLayerRenderedPixels(
                output,
                historyTitle: L10n.text("imageEditor.history.spotHealingBrush"),
                resetFrame: false
            )
            statusText = L10n.text("imageEditor.status.spotHealingApplied")
            return
        }

        guard let sourcePoint = healingSourcePoint, let destinationStart = samples.first?.point else {
            statusText = L10n.text("imageEditor.status.healingSourceMissing")
            return
        }

        let offsetResolution = ImageEditorSampledBrushOffsetResolution.resolve(
            sourcePoint: sourcePoint,
            destinationStart: destinationStart,
            isAligned: isHealingBrushAligned,
            alignedOffset: healingBrushAlignedCanvasOffset
        )
        guard let samplingInput = sampledBrushInput(
            for: layer,
            canvasOffset: offsetResolution.canvasOffset,
            sampleSource: healingBrushSampleSource
        ),
        let targetContext = sampledBrushInput(
            for: layer,
            canvasOffset: .zero,
            sampleSource: healingBrushSampleSource
        ),
        let output = layer.image.normalizedBitmapImage().withHealingBrush(
            samples: rasterLocalSamples(samples, layer: layer),
            sourceOffset: samplingInput.localOffset,
            sourceImage: samplingInput.image,
            targetContextImage: targetContext.image,
            width: rasterLocalBrushWidth(brushSize, layer: layer),
            opacity: opacity,
            hardness: hardness,
            pressureControlsSize: retouchPressureControlsSize,
            pressureSensitivity: retouchPressureSensitivity / 100
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        healingBrushAlignedCanvasOffset = offsetResolution.nextAlignedOffset

        replaceSelectedLayerRenderedPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.healingBrush"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.healingApplied")
    }

    func setHealingSource(at point: CGPoint?) {
        healingSourcePoint = point
        healingBrushAlignedCanvasOffset = nil
        isSettingHealingSource = false
        statusText = point == nil
            ? L10n.text("imageEditor.status.healingSourceMissing")
            : L10n.text("imageEditor.status.healingSourceSet")
    }

    func beginSettingHealingSource() {
        guard healingBrushMode == .source else { return }
        isSettingHealingSource = true
        statusText = L10n.text("imageEditor.status.healingSourcePending")
    }

    func reduceRedEye(at point: CGPoint?) {
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
        guard let output = sourceImage.withRedEyeReduction(
            at: rasterLocalPoint(point, layer: layer),
            radius: rasterLocalBrushWidth(brushSize, layer: layer),
            opacity: opacity
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        replaceSelectedLayerPixels(
            output,
            historyTitle: L10n.text("imageEditor.history.redEye"),
            resetFrame: false
        )
        statusText = L10n.text("imageEditor.status.redEyeApplied")
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
            at: rasterLocalPoint(point, layer: layer),
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

    func drawShape(
        from start: CGPoint,
        to end: CGPoint,
        ellipse: Bool,
        cornerRadius: Double? = nil,
        cornerRadii: ImageEditorRectangleCornerRadii? = nil,
        cornerSmoothing: Double? = nil,
        fillColor: NSColor? = nil,
        fillGradient: ImageEditorGradientFillContent? = nil,
        fillGradientCenter: CGPoint? = nil,
        fillOpacity: Double? = nil,
        strokeColor: NSColor? = nil,
        strokeOpacity: Double? = nil,
        strokeWidth: Double? = nil,
        strokePosition: ImageEditorStrokePosition? = nil,
        strokeCap: ImageEditorStrokeCap? = nil,
        strokeJoin: ImageEditorStrokeJoin? = nil,
        strokeMiterLimit: Double? = nil,
        strokeDashPattern: [CGFloat]? = nil
    ) {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        guard rect.width > 3, rect.height > 3 else { return }
        addShapeLayer(
            frame: rect,
            kind: ellipse ? .ellipse : .rectangle,
            cornerRadius: cornerRadius,
            cornerRadii: cornerRadii,
            cornerSmoothing: cornerSmoothing,
            fillColor: fillColor,
            fillGradient: fillGradient,
            fillGradientCenter: fillGradientCenter,
            fillOpacity: fillOpacity,
            strokeColor: strokeColor,
            strokeOpacity: strokeOpacity,
            strokeWidth: strokeWidth,
            strokePosition: strokePosition,
            strokeCap: strokeCap,
            strokeJoin: strokeJoin,
            strokeMiterLimit: strokeMiterLimit,
            strokeDashPattern: strokeDashPattern
        )
    }

    func updateSelectedShapeLayer(
        cornerRadius: Double? = nil,
        cornerRadii: ImageEditorRectangleCornerRadii? = nil,
        cornerSmoothing: Double? = nil
    ) {
        let indices = selectedLayerIndices.filter { document.layers[$0].isShape && !document.isEffectivelyPixelsLocked(document.layers[$0]) }
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let fillColor = foregroundColor
        let fillOpacity = opacity
        let strokeOpacity = min(1, max(0.15, opacity))
        let strokeWidth = max(1, min(96, brushSize * 0.35))
        pushUndo()
        for index in indices {
            guard var shapeContent = document.layers[index].shapeContent else { continue }
            shapeContent.fillColor = fillColor
            shapeContent.fillOpacity = fillOpacity
            shapeContent.strokeColor = fillColor
            shapeContent.strokeOpacity = strokeOpacity
            shapeContent.strokeWidth = strokeWidth
            if shapeContent.kind == .rectangle,
               let cornerRadius,
               cornerRadius.isFinite {
                shapeContent.cornerRadius = CGFloat(max(0, cornerRadius))
                shapeContent.cornerRadii = nil
            } else if shapeContent.kind == .rectangle,
                      let cornerRadii {
                shapeContent.cornerRadii = cornerRadii
            }
            if shapeContent.kind == .rectangle,
               let cornerSmoothing,
               cornerSmoothing.isFinite {
                shapeContent.cornerSmoothing = CGFloat(max(0, min(1, cornerSmoothing)))
            }
            document.layers[index].kind = .shape(shapeContent.normalized(size: document.layers[index].image.size))
            document.layers[index].name = L10n.format("imageEditor.layer.shapeName", shapeContent.kind.title)
        }
        appendHistory(L10n.text(indices.count == 1 ? "imageEditor.history.layerShapeUpdate" : "imageEditor.history.layerShapeUpdateSelected"))
        if indices.count > 1 { statusText = L10n.format("imageEditor.status.layerShapeUpdatedSelected", indices.count) }
    }

    func sampleColor(at point: CGPoint) {
        guard let color = document.compositedImage.color(at: point) else { return }
        foregroundColor = color
        statusText = L10n.text("imageEditor.status.colorSampled")
    }

    @discardableResult
    func addColorSampler(
        at point: CGPoint,
        sampleSize requestedSampleSize: ImageEditorColorSamplerSampleSize? = nil,
        source requestedSource: ImageEditorColorSamplerSource? = nil
    ) -> Bool {
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        guard canvasBounds.contains(point) else { return false }
        let sampleSize = requestedSampleSize ?? selectedColorSamplerSampleSize
        let source = requestedSource ?? activeColorSamplerSource
        guard canSampleColorSamplerSource(source) else { return false }
        guard let color = sampledCanvasColor(
            at: point,
            sampleSize: sampleSize,
            source: source
        ) else { return false }
        let shouldRefreshExistingSamples =
            sampleSize != selectedColorSamplerSampleSize
                || source != selectedColorSamplerSource
        selectedColorSamplerSampleSize = sampleSize
        selectedColorSamplerSource = source
        if shouldRefreshExistingSamples {
            refreshColorSamplers()
        }
        let sample = ImageEditorColorSamplerPoint(point: point, color: color)
        colorSamplerPoints = Array(
            (colorSamplerPoints + [sample]).suffix(
                ImageEditorColorSamplerPoint.maximumCount
            )
        )
        statusText = L10n.format("imageEditor.status.colorSamplerAdded", colorSamplerPoints.count)
        return true
    }

    func restoreColorSamplerState(
        points: [ImageEditorProjectColorSamplerPoint],
        readoutMode: ImageEditorColorSamplerReadoutMode,
        sampleSize: ImageEditorColorSamplerSampleSize,
        source: ImageEditorColorSamplerSource
    ) {
        selectedColorSamplerReadoutMode = readoutMode
        selectedColorSamplerSampleSize = sampleSize
        selectedColorSamplerSource = canSampleColorSamplerSource(source)
            ? source
            : .composite

        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        var restoredPoints: [ImageEditorColorSamplerPoint] = []
        var restoredIDs = Set<UUID>()
        for storedPoint in points {
            guard restoredPoints.count < ImageEditorColorSamplerPoint.maximumCount else {
                break
            }
            guard canvasBounds.contains(storedPoint.point),
                  let color = sampledCanvasColor(
                      at: storedPoint.point,
                      sampleSize: sampleSize,
                      source: selectedColorSamplerSource
                  )
            else { continue }

            let id = restoredIDs.insert(storedPoint.id).inserted
                ? storedPoint.id
                : UUID()
            restoredIDs.insert(id)
            restoredPoints.append(
                ImageEditorColorSamplerPoint(
                    id: id,
                    point: storedPoint.point,
                    color: color
                )
            )
        }
        colorSamplerPoints = restoredPoints
    }

    @discardableResult
    func moveColorSampler(id: UUID, to point: CGPoint) -> Bool {
        guard let index = colorSamplerPoints.firstIndex(where: { $0.id == id }) else {
            return false
        }
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        guard canvasBounds.contains(point),
              let color = sampledCanvasColor(
                  at: point,
                  sampleSize: selectedColorSamplerSampleSize,
                  source: activeColorSamplerSource
              )
        else { return false }
        colorSamplerPoints[index] = ImageEditorColorSamplerPoint(
            id: id,
            point: point,
            color: color
        )
        statusText = L10n.format(
            "imageEditor.status.colorSamplerMoved",
            index + 1
        )
        return true
    }

    @discardableResult
    func removeColorSampler(id: UUID) -> ImageEditorColorSamplerPoint? {
        guard let index = colorSamplerPoints.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        let removedSample = colorSamplerPoints.remove(at: index)
        statusText = L10n.format(
            "imageEditor.status.colorSamplerRemoved",
            index + 1
        )
        return removedSample
    }

    @discardableResult
    func refreshColorSamplers() -> Int {
        guard !colorSamplerPoints.isEmpty else { return 0 }
        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        colorSamplerPoints = colorSamplerPoints.compactMap { sample in
            guard canvasBounds.contains(sample.point),
                  let color = sampledCanvasColor(
                    at: sample.point,
                    sampleSize: selectedColorSamplerSampleSize,
                    source: activeColorSamplerSource
                  )
            else { return nil }
            return ImageEditorColorSamplerPoint(
                id: sample.id,
                point: sample.point,
                color: color
            )
        }
        return colorSamplerPoints.count
    }

    @discardableResult
    func clearColorSamplers() -> Int {
        let clearedCount = colorSamplerPoints.count
        guard clearedCount > 0 else { return 0 }
        colorSamplerPoints.removeAll()
        statusText = L10n.text("imageEditor.status.colorSamplerCleared")
        return clearedCount
    }

    func selectAdjustment(_ adjustment: ImageEditorAdjustment) {
        selectedAdjustment = adjustment
        isPropertiesPanelVisible = true
        statusText = L10n.format("imageEditor.status.adjustmentReady", adjustment.title)
    }

    func selectFilter(_ filter: ImageEditorFilter) {
        loadedSmartFilterID = nil
        selectedFilter = filter
        filterPanelPresentationRequest &+= 1
        isPropertiesPanelVisible = true
        statusText = L10n.format("imageEditor.status.filterReady", filter.title)
    }

    func applyAdjustment() {
        let title = selectedAdjustment.title
        let indices = editableSelectedLayerIndices()
        let settings = currentAdjustmentSettings()
        let outputs = indices.reduce(into: [Int: NSImage]()) { result, index in
            if let image = document.layers[index].image.adjusted(
                kind: selectedAdjustment,
                amount: adjustmentValue,
                settings: settings
            ) {
                result[index] = image
            }
        }
        guard !indices.isEmpty, outputs.count == indices.count else {
            statusText = L10n.text("imageEditor.status.adjustmentFailed")
            return
        }

        pushUndo()
        for index in indices {
            guard let normalized = outputs[index]?.normalizedBitmapImage() else { continue }
            let original = document.layers[index].image
            let clipped = clippedToSelection(
                original: original,
                output: normalized,
                layerFrame: document.layers[index].frame
            )
            document.layers[index].image = document.isEffectivelyTransparencyLocked(document.layers[index])
                ? (clipped.preservingAlpha(from: original) ?? clipped)
                : clipped
        }
        if indices.count == 1 {
            appendHistory(title)
        } else {
            appendHistory(L10n.format("imageEditor.history.adjustmentSelected", title))
            statusText = L10n.format("imageEditor.status.adjustmentSelected", title, indices.count)
        }
        resetAdjustmentControls()
    }

    func applySelectedFilter() {
        let application = ImageEditorFilterApplication(
            kind: selectedFilter,
            intensity: filterIntensity,
            settings: currentFilterSettings()
        )
        applyFilter(application, remembersAsLastFilter: true)
    }

    var canApplyLastFilter: Bool {
        lastAppliedFilter != nil && !editableSelectedLayerIndices().isEmpty
    }

    func applyLastFilter() {
        guard let lastAppliedFilter else {
            statusText = L10n.text("imageEditor.status.lastFilterUnavailable")
            return
        }
        applyFilter(lastAppliedFilter, remembersAsLastFilter: false)
    }

    private func applyFilter(
        _ application: ImageEditorFilterApplication,
        remembersAsLastFilter: Bool
    ) {
        let title = application.kind.title
        let indices = editableSelectedLayerIndices()
        let outputs = indices.reduce(into: [Int: NSImage]()) { result, index in
            if let image = document.layers[index].image.filtered(
                kind: application.kind,
                intensity: application.intensity,
                settings: application.settings
            ) {
                result[index] = image
            }
        }
        guard !indices.isEmpty, outputs.count == indices.count else {
            statusText = L10n.text("imageEditor.status.filterFailed")
            return
        }

        pushUndo()
        for index in indices {
            guard let normalized = outputs[index]?.normalizedBitmapImage() else { continue }
            let original = document.layers[index].image
            let clipped = clippedToSelection(
                original: original,
                output: normalized,
                layerFrame: document.layers[index].frame
            )
            document.layers[index].image = document.isEffectivelyTransparencyLocked(document.layers[index])
                ? (clipped.preservingAlpha(from: original) ?? clipped)
                : clipped
        }
        if indices.count == 1 {
            appendHistory(L10n.format("imageEditor.history.filter", title))
            statusText = L10n.format("imageEditor.status.filter", title)
        } else {
            appendHistory(L10n.format("imageEditor.history.filterSelected", title))
            statusText = L10n.format("imageEditor.status.filterSelected", title, indices.count)
        }
        if remembersAsLastFilter {
            lastAppliedFilter = application
        }
    }

    func autoLevelsSelectedLayer() {
        applyAutoCorrection({ $0.autoLeveled() }, history: "imageEditor.history.autoLevels", selectedHistory: "imageEditor.history.autoLevelsSelected", status: "imageEditor.status.autoLevels", selectedStatus: "imageEditor.status.autoLevelsSelected")
    }

    func autoContrastSelectedLayer() {
        applyAutoCorrection({ $0.autoContrasted() }, history: "imageEditor.history.autoContrast", selectedHistory: "imageEditor.history.autoContrastSelected", status: "imageEditor.status.autoContrast", selectedStatus: "imageEditor.status.autoContrastSelected")
    }

    func autoColorSelectedLayer() {
        applyAutoCorrection({ $0.autoColored() }, history: "imageEditor.history.autoColor", selectedHistory: "imageEditor.history.autoColorSelected", status: "imageEditor.status.autoColor", selectedStatus: "imageEditor.status.autoColorSelected")
    }

    func desaturateSelectedLayer() {
        applyAutoCorrection(
            { $0.adjusted(kind: .saturation, amount: -1) },
            history: "imageEditor.history.desaturate",
            selectedHistory: "imageEditor.history.desaturateSelected",
            status: "imageEditor.status.desaturate",
            selectedStatus: "imageEditor.status.desaturateSelected"
        )
    }

    func invertSelectedLayer() {
        applyAutoCorrection(
            { $0.adjusted(kind: .invert, amount: 0) },
            history: "imageEditor.history.invert",
            selectedHistory: "imageEditor.history.invertSelected",
            status: "imageEditor.status.invert",
            selectedStatus: "imageEditor.status.invertSelected"
        )
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
        let indices = selectedLayerIndices.filter { document.layers[$0].isAdjustment && !document.isEffectivelyPixelsLocked(document.layers[$0]) }
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let settings = currentAdjustmentSettings()
        pushUndo()
        for index in indices {
            document.layers[index].kind = .adjustment(selectedAdjustment, adjustmentValue)
            document.layers[index].adjustmentSettings = settings
            document.layers[index].name = L10n.format("imageEditor.layer.adjustmentName", selectedAdjustment.title)
        }
        appendHistory(L10n.text(indices.count == 1 ? "imageEditor.history.layerAdjustmentUpdate" : "imageEditor.history.layerAdjustmentUpdateSelected"))
        if indices.count > 1 { statusText = L10n.format("imageEditor.status.layerAdjustmentUpdatedSelected", indices.count) }
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
        addSolidColorFillLayer(content: currentSolidColorFillContent())
    }

    func addSolidColorFillLayer(content: ImageEditorSolidColorFillContent) {
        pushUndo()
        let layer = ImageEditorLayer.solidColorFill(
            name: L10n.text("imageEditor.layer.solidColorFillName"),
            size: document.canvasSize,
            content: content.normalized()
        )
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerSolidColorFillNew"))
    }

    func updateSelectedSolidColorFillLayer() {
        let indices = selectedLayerIndices.filter { document.layers[$0].isSolidColorFill && !document.isEffectivelyPixelsLocked(document.layers[$0]) }
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let content = currentSolidColorFillContent()
        pushUndo()
        for index in indices {
            document.layers[index].kind = .solidColorFill(content)
            document.layers[index].name = L10n.text("imageEditor.layer.solidColorFillName")
        }
        appendHistory(L10n.text(indices.count == 1 ? "imageEditor.history.layerSolidColorFillUpdate" : "imageEditor.history.layerSolidColorFillUpdateSelected"))
        if indices.count > 1 { statusText = L10n.format("imageEditor.status.layerSolidColorFillUpdatedSelected", indices.count) }
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
        let indices = selectedLayerIndices.filter { document.layers[$0].isPatternFill && !document.isEffectivelyPixelsLocked(document.layers[$0]) }
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let content = currentPatternFillContent()
        pushUndo()
        for index in indices {
            document.layers[index].kind = .patternFill(content)
            document.layers[index].name = L10n.text("imageEditor.layer.patternFillName")
        }
        appendHistory(L10n.text(indices.count == 1 ? "imageEditor.history.layerPatternFillUpdate" : "imageEditor.history.layerPatternFillUpdateSelected"))
        if indices.count > 1 { statusText = L10n.format("imageEditor.status.layerPatternFillUpdatedSelected", indices.count) }
    }

    func addGradientFillLayer() {
        addGradientFillLayer(content: currentGradientFillContent())
    }

    func addGradientFillLayer(content: ImageEditorGradientFillContent) {
        pushUndo()
        let layer = ImageEditorLayer.gradientFill(
            name: L10n.text("imageEditor.layer.gradientFillName"),
            size: document.canvasSize,
            content: content.normalized()
        )
        let insertionIndex = min((document.selectedLayerIndex ?? (document.layers.count - 1)) + 1, document.layers.count)
        document.layers.insert(layer, at: insertionIndex)
        document.selectedLayerID = layer.id
        document.selectedLayerIDs = [layer.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerGradientFillNew"))
    }

    func updateSelectedGradientFillLayer() {
        let indices = selectedLayerIndices.filter { document.layers[$0].isGradientFill && !document.isEffectivelyPixelsLocked(document.layers[$0]) }
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let content = currentGradientFillContent()
        pushUndo()
        for index in indices {
            document.layers[index].kind = .gradientFill(content)
            document.layers[index].name = L10n.text("imageEditor.layer.gradientFillName")
        }
        appendHistory(L10n.text(indices.count == 1 ? "imageEditor.history.layerGradientFillUpdate" : "imageEditor.history.layerGradientFillUpdateSelected"))
        if indices.count > 1 { statusText = L10n.format("imageEditor.status.layerGradientFillUpdatedSelected", indices.count) }
    }

    @discardableResult
    func addSmartFilterToSelectedLayer(
        opacity: Double = 1,
        blendMode: ImageEditorBlendMode = .normal
    ) -> Int {
        let targetIndices = selectedLayerSmartFilterTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        pushUndo()
        for index in targetIndices {
            let smartFilter = ImageEditorSmartFilter(
                kind: selectedFilter,
                intensity: filterIntensity,
                settings: currentFilterSettings(),
                opacity: opacity,
                blendMode: blendMode
            )
            document.layers[index].smartFilters.append(smartFilter)
        }
        if let selectedLayerIndex = document.selectedLayerIndex,
           targetIndices.contains(selectedLayerIndex) {
            loadedSmartFilterID = document.layers[selectedLayerIndex].smartFilters.last?.id
        }
        guard targetIndices.count > 1 else {
            appendHistory(L10n.text("imageEditor.history.layerSmartFilterAdd"))
            return targetIndices.count
        }
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterAddSelected"))
        statusText = L10n.format(
            "imageEditor.status.layerSmartFilterAddedSelected",
            targetIndices.count
        )
        return targetIndices.count
    }

    @discardableResult
    func updateLastSmartFilterOnSelectedLayer() -> Int {
        let targetIndices = selectedLayerSmartFilterUpdateTargetIndices().filter { layerIndex in
            guard let filter = document.layers[layerIndex].smartFilters.last else { return false }
            return smartFilterDiffersFromCurrentControls(filter)
        }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.smartFilterUnchanged")
            return 0
        }
        pushUndo()
        for index in targetIndices {
            guard let lastIndex = document.layers[index].smartFilters.indices.last else { continue }
            updateSmartFilterFromCurrentControls(&document.layers[index].smartFilters[lastIndex])
        }
        if let selectedLayerIndex = document.selectedLayerIndex,
           targetIndices.contains(selectedLayerIndex) {
            loadedSmartFilterID = document.layers[selectedLayerIndex].smartFilters.last?.id
        }
        return finishSmartFilterUpdate(targetCount: targetIndices.count)
    }

    @discardableResult
    func updateLoadedSmartFilterOnSelectedLayer() -> Int {
        guard let loadedSmartFilterID,
              let (loadedLayerIndex, filterIndex) = selectedSmartFilterIndex(loadedSmartFilterID)
        else {
            return updateLastSmartFilterOnSelectedLayer()
        }
        let matchingTargetIndices = selectedLayerSmartFilterUpdateTargetIndices().filter { layerIndex in
            document.layers[layerIndex].smartFilters.indices.contains(filterIndex)
        }
        guard matchingTargetIndices.contains(loadedLayerIndex) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let targetIndices = matchingTargetIndices.filter { layerIndex in
            smartFilterDiffersFromCurrentControls(document.layers[layerIndex].smartFilters[filterIndex])
        }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.smartFilterUnchanged")
            return 0
        }
        pushUndo()
        for layerIndex in targetIndices {
            updateSmartFilterFromCurrentControls(&document.layers[layerIndex].smartFilters[filterIndex])
        }
        self.loadedSmartFilterID = document.layers[loadedLayerIndex].smartFilters[filterIndex].id
        return finishSmartFilterUpdate(targetCount: targetIndices.count)
    }

    @discardableResult
    func updateSmartFilterOnSelectedLayer(_ filterID: UUID) -> Int {
        guard let (_, filterIndex) = selectedSmartFilterIndex(filterID) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let targetIndices = selectedSmartFilterTargetIndices(at: filterIndex).filter { layerIndex in
            smartFilterDiffersFromCurrentControls(document.layers[layerIndex].smartFilters[filterIndex])
        }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.smartFilterUnchanged")
            return 0
        }
        pushUndo()
        for layerIndex in targetIndices {
            updateSmartFilterFromCurrentControls(&document.layers[layerIndex].smartFilters[filterIndex])
        }
        loadedSmartFilterID = filterID
        return finishSmartFilterUpdate(targetCount: targetIndices.count)
    }

    private func finishSmartFilterUpdate(targetCount: Int) -> Int {
        guard targetCount > 1 else {
            appendHistory(L10n.text("imageEditor.history.layerSmartFilterUpdate"))
            return targetCount
        }
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterUpdateSelected"))
        statusText = L10n.format(
            "imageEditor.status.layerSmartFilterUpdatedSelected",
            targetCount
        )
        return targetCount
    }

    @discardableResult
    func loadSmartFilterIntoControls(_ filterID: UUID) -> Bool {
        guard let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return false
        }
        let filter = document.layers[layerIndex].smartFilters[filterIndex]
        syncSmartFilterControls(filter)
        filterPanelPresentationRequest &+= 1
        isPropertiesPanelVisible = true
        statusText = L10n.format("imageEditor.status.filterReady", filter.kind.title)
        return true
    }

    /// Restores the persisted filter parameters without changing the document
    /// or creating an undo/history entry. This is the inspector equivalent of
    /// cancelling edits in a modal filter dialog.
    @discardableResult
    func discardSmartFilterControlChanges(_ filterID: UUID) -> Bool {
        guard canDiscardSmartFilterControlChanges(filterID),
              loadSmartFilterIntoControls(filterID)
        else { return false }
        statusText = L10n.text("imageEditor.status.smartFilterChangesDiscarded")
        return true
    }

    func canDiscardSmartFilterControlChanges(_ filterID: UUID) -> Bool {
        guard loadedSmartFilterID == filterID,
              let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID)
        else { return false }
        return smartFilterDiffersFromCurrentControls(
            document.layers[layerIndex].smartFilters[filterIndex]
        )
    }

    var canDiscardLoadedSmartFilterControlChanges: Bool {
        guard let loadedSmartFilterID else { return false }
        return canDiscardSmartFilterControlChanges(loadedSmartFilterID)
    }

    @discardableResult
    func discardLoadedSmartFilterControlChanges() -> Bool {
        guard let loadedSmartFilterID else { return false }
        return discardSmartFilterControlChanges(loadedSmartFilterID)
    }

    private func updateSmartFilterFromCurrentControls(_ filter: inout ImageEditorSmartFilter) {
        let keepsBackdropRouting = filter.appliesToBackdrop && selectedFilter == .gaussianBlur
        filter.kind = selectedFilter
        filter.intensity = filterIntensity
        filter.settings = currentFilterSettings()
        filter.isEnabled = true
        filter.appliesToBackdrop = keepsBackdropRouting
    }

    private func smartFilterDiffersFromCurrentControls(_ filter: ImageEditorSmartFilter) -> Bool {
        filter.kind != selectedFilter
            || abs(filter.normalizedIntensity - max(0, min(1, filterIntensity))) > 0.000_001
            || filter.normalizedSettings != currentFilterSettings().normalized()
    }

    func smartFilterHasPendingControlChanges(_ filterID: UUID) -> Bool {
        loadedSmartFilterID == filterID && loadedSmartFilterHasPendingChanges
    }

    @discardableResult
    func toggleSmartFilterOnSelectedLayer(_ filterID: UUID) -> Int {
        guard let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let isEnabled = !document.layers[layerIndex].smartFilters[filterIndex].isEnabled
        let targetIndices = selectedSmartFilterTargetIndices(at: filterIndex).filter { targetIndex in
            document.layers[targetIndex].smartFilters[filterIndex].isEnabled != isEnabled
        }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        pushUndo()
        for targetIndex in targetIndices {
            document.layers[targetIndex].smartFilters[filterIndex].isEnabled = isEnabled
        }
        guard targetIndices.count > 1 else {
            appendHistory(L10n.text("imageEditor.history.layerSmartFilterToggle"))
            return targetIndices.count
        }
        appendHistory(
            L10n.text(
                isEnabled
                    ? "imageEditor.history.layerSmartFilterEnableSelected"
                    : "imageEditor.history.layerSmartFilterDisableSelected"
            )
        )
        statusText = L10n.format(
            isEnabled
                ? "imageEditor.status.layerSmartFilterEnabledSelected"
                : "imageEditor.status.layerSmartFilterDisabledSelected",
            targetIndices.count
        )
        return targetIndices.count
    }

    func smartFilterOpacity(_ filterID: UUID) -> Double? {
        guard let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID) else { return nil }
        return document.layers[layerIndex].smartFilters[filterIndex].normalizedOpacity
    }

    func smartFilterOpacityState(_ filterID: UUID) -> ImageEditorSmartFilterValueState<Double> {
        guard let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID),
              canEditSmartFilters(on: document.layers[layerIndex])
        else { return .unavailable }
        let targetIndices = selectedSmartFilterTargetIndices(at: filterIndex)
        guard targetIndices.contains(layerIndex), let firstIndex = targetIndices.first else {
            return .unavailable
        }
        let firstOpacity = document.layers[firstIndex].smartFilters[filterIndex].normalizedOpacity
        let allMatch = targetIndices.dropFirst().allSatisfy { targetIndex in
            abs(
                document.layers[targetIndex].smartFilters[filterIndex].normalizedOpacity - firstOpacity
            ) <= 0.000_001
        }
        return allMatch ? .value(firstOpacity) : .mixed
    }

    func smartFilterBlendMode(_ filterID: UUID) -> ImageEditorBlendMode? {
        guard let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID) else { return nil }
        return document.layers[layerIndex].smartFilters[filterIndex].normalizedBlendMode
    }

    func smartFilterBlendModeState(
        _ filterID: UUID
    ) -> ImageEditorSmartFilterValueState<ImageEditorBlendMode> {
        guard let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID),
              canEditSmartFilters(on: document.layers[layerIndex])
        else { return .unavailable }
        let targetIndices = selectedSmartFilterTargetIndices(at: filterIndex)
        guard targetIndices.contains(layerIndex), let firstIndex = targetIndices.first else {
            return .unavailable
        }
        let firstBlendMode = document.layers[firstIndex].smartFilters[filterIndex].normalizedBlendMode
        let allMatch = targetIndices.dropFirst().allSatisfy { targetIndex in
            document.layers[targetIndex].smartFilters[filterIndex].normalizedBlendMode == firstBlendMode
        }
        return allMatch ? .value(firstBlendMode) : .mixed
    }

    func isSmartFilterLoadedForEditing(_ filterID: UUID) -> Bool {
        loadedSmartFilterID == filterID
            && document.selectedLayer?.smartFilters.contains(where: { $0.id == filterID }) == true
    }

    @discardableResult
    func setSmartFilterOpacityOnSelectedLayer(_ filterID: UUID, opacity: Double) -> Int {
        guard let (_, filterIndex) = selectedSmartFilterIndex(filterID) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let normalizedOpacity = max(0, min(1, opacity))
        let matchingTargetIndices = selectedSmartFilterTargetIndices(at: filterIndex)
        guard !matchingTargetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let targetIndices = matchingTargetIndices.filter { targetIndex in
            abs(
                document.layers[targetIndex].smartFilters[filterIndex].normalizedOpacity - normalizedOpacity
            ) > 0.000_001
        }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        pushUndo()
        for targetIndex in targetIndices {
            document.layers[targetIndex].smartFilters[filterIndex].opacity = normalizedOpacity
        }
        guard matchingTargetIndices.count > 1 else {
            appendHistory(L10n.text("imageEditor.history.layerSmartFilterOpacity"))
            return targetIndices.count
        }
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterOpacitySelected"))
        statusText = L10n.format(
            "imageEditor.status.layerSmartFilterOpacitySelected",
            Int((normalizedOpacity * 100).rounded()),
            targetIndices.count
        )
        return targetIndices.count
    }

    @discardableResult
    func setSmartFilterBlendModeOnSelectedLayer(
        _ filterID: UUID,
        blendMode: ImageEditorBlendMode
    ) -> Int {
        guard blendMode != .passThrough,
              let (_, filterIndex) = selectedSmartFilterIndex(filterID)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let matchingTargetIndices = selectedSmartFilterTargetIndices(at: filterIndex)
        guard !matchingTargetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let targetIndices = matchingTargetIndices.filter { targetIndex in
            document.layers[targetIndex].smartFilters[filterIndex].normalizedBlendMode != blendMode
        }
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        pushUndo()
        for targetIndex in targetIndices {
            document.layers[targetIndex].smartFilters[filterIndex].blendMode = blendMode
        }
        guard matchingTargetIndices.count > 1 else {
            appendHistory(L10n.text("imageEditor.history.layerSmartFilterBlendMode"))
            return targetIndices.count
        }
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterBlendModeSelected"))
        statusText = L10n.format(
            "imageEditor.status.layerSmartFilterBlendModeSelected",
            blendMode.title,
            targetIndices.count
        )
        return targetIndices.count
    }

    @discardableResult
    func removeSmartFilterFromSelectedLayer(_ filterID: UUID) -> Int {
        guard let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let targetIndices = selectedSmartFilterTargetIndices(at: filterIndex)
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let removesLoadedFilter = loadedSmartFilterID == filterID && targetIndices.contains(layerIndex)
        pushUndo()
        for targetIndex in targetIndices {
            document.layers[targetIndex].smartFilters.remove(at: filterIndex)
        }
        if removesLoadedFilter {
            let filters = document.layers[layerIndex].smartFilters
            if !filters.isEmpty {
                syncSmartFilterControls(filters[min(filterIndex, filters.count - 1)])
            } else {
                loadedSmartFilterID = nil
            }
        }
        guard targetIndices.count > 1 else {
            appendHistory(L10n.text("imageEditor.history.layerSmartFilterRemove"))
            return targetIndices.count
        }
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterRemoveSelected"))
        statusText = L10n.format(
            "imageEditor.status.layerSmartFilterRemovedSelected",
            targetIndices.count
        )
        return targetIndices.count
    }

    @discardableResult
    func duplicateSmartFilterOnSelectedLayer(
        _ filterID: UUID
    ) -> (primaryDuplicateID: UUID?, duplicatedLayerCount: Int)? {
        guard let (layerIndex, filterIndex) = selectedSmartFilterIndex(filterID) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return nil
        }
        let targetIndices = selectedSmartFilterTargetIndices(at: filterIndex)
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return nil
        }
        pushUndo()
        var primaryDuplicateID: UUID?
        for targetIndex in targetIndices {
            var duplicate = document.layers[targetIndex].smartFilters[filterIndex]
            duplicate.id = UUID()
            document.layers[targetIndex].smartFilters.insert(duplicate, at: filterIndex + 1)
            if targetIndex == layerIndex {
                primaryDuplicateID = duplicate.id
            }
        }
        if let primaryDuplicateID {
            loadedSmartFilterID = primaryDuplicateID
        }
        guard targetIndices.count > 1 else {
            appendHistory(L10n.text("imageEditor.history.layerSmartFilterDuplicate"))
            return (primaryDuplicateID, targetIndices.count)
        }
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterDuplicateSelected"))
        statusText = L10n.format(
            "imageEditor.status.layerSmartFilterDuplicatedSelected",
            targetIndices.count
        )
        return (primaryDuplicateID, targetIndices.count)
    }

    func canMoveSmartFilterOnSelectedLayer(_ filterID: UUID, offset: Int) -> Bool {
        guard offset != 0,
              let (_, filterIndex) = selectedSmartFilterIndex(filterID)
        else { return false }
        return !selectedSmartFilterMoveTargetIndices(at: filterIndex, offset: offset).isEmpty
    }

    @discardableResult
    func moveSmartFilterOnSelectedLayer(_ filterID: UUID, offset: Int) -> Int {
        guard offset != 0,
              let (_, filterIndex) = selectedSmartFilterIndex(filterID)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let targetIndex = filterIndex + offset
        let targetIndices = selectedSmartFilterMoveTargetIndices(at: filterIndex, offset: offset)
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        pushUndo()
        for selectedLayerIndex in targetIndices {
            let filter = document.layers[selectedLayerIndex].smartFilters.remove(at: filterIndex)
            document.layers[selectedLayerIndex].smartFilters.insert(filter, at: targetIndex)
        }
        guard targetIndices.count > 1 else {
            appendHistory(L10n.text("imageEditor.history.layerSmartFilterMove"))
            return targetIndices.count
        }
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterMoveSelected"))
        statusText = L10n.format(
            "imageEditor.status.layerSmartFilterMovedSelected",
            targetIndices.count
        )
        return targetIndices.count
    }

    @discardableResult
    func clearSmartFiltersFromSelectedLayer() -> Int {
        let targetIndices = selectedLayerSmartFilterClearTargetIndices()
        guard !targetIndices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return 0
        }
        let removesLoadedFilter = loadedSmartFilterID.map { loadedFilterID in
            targetIndices.contains { layerIndex in
                document.layers[layerIndex].smartFilters.contains { $0.id == loadedFilterID }
            }
        } ?? false
        pushUndo()
        for index in targetIndices {
            document.layers[index].smartFilters.removeAll()
        }
        if removesLoadedFilter {
            loadedSmartFilterID = nil
        }
        guard targetIndices.count > 1 else {
            appendHistory(L10n.text("imageEditor.history.layerSmartFilterClear"))
            return targetIndices.count
        }
        appendHistory(L10n.text("imageEditor.history.layerSmartFilterClearSelected"))
        statusText = L10n.format(
            "imageEditor.status.layerSmartFilterClearedSelected",
            targetIndices.count
        )
        return targetIndices.count
    }

    private func selectedSmartFilterIndex(_ filterID: UUID) -> (layerIndex: Int, filterIndex: Int)? {
        guard let layerIndex = document.selectedLayerIndex else { return nil }
        guard let filterIndex = document.layers[layerIndex].smartFilters.firstIndex(where: { $0.id == filterID }) else {
            return nil
        }
        return (layerIndex, filterIndex)
    }

    func updateSelectedFilterLayer() {
        let indices = selectedLayerIndices.filter { document.layers[$0].isFilter && !document.isEffectivelyPixelsLocked(document.layers[$0]) }
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let settings = currentFilterSettings()
        pushUndo()
        for index in indices {
            document.layers[index].kind = .filter(selectedFilter, filterIntensity)
            document.layers[index].filterSettings = settings
            document.layers[index].name = L10n.format("imageEditor.layer.filterName", selectedFilter.title)
        }
        appendHistory(L10n.text(indices.count == 1 ? "imageEditor.history.layerFilterUpdate" : "imageEditor.history.layerFilterUpdateSelected"))
        if indices.count > 1 { statusText = L10n.format("imageEditor.status.layerFilterUpdatedSelected", indices.count) }
    }

    private func currentFilterSettings() -> ImageEditorFilterSettings {
        ImageEditorFilterSettings(
            gaussianBlurRadius: selectedFilter == .gaussianBlur ? filterGaussianBlurRadius : nil,
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
            rippleFrequency: filterRippleFrequency,
            pinchAmount: filterPinchAmount,
            spherizeAmount: filterSpherizeAmount,
            lensDistortion: filterLensDistortion
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

    private func replaceSelectedLayerRenderedPixels(_ image: NSImage, historyTitle: String, resetFrame: Bool) {
        replaceSelectedLayerPixels(
            image,
            historyTitle: historyTitle,
            resetFrame: resetFrame,
            isRenderedBitmap: true
        )
    }

    private func replaceSelectedLayerPixels(
        _ image: NSImage,
        historyTitle: String,
        resetFrame: Bool,
        isRenderedBitmap: Bool = false
    ) {
        guard let index = document.selectedLayerIndex else { return }
        guard !document.isEffectivelyPixelsLocked(document.layers[index]) else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }
        pushUndo()
        let original = document.layers[index].image
        let normalized = isRenderedBitmap ? image : image.normalizedBitmapImage()
        let clippedOutput = clippedToSelection(
            original: original,
            output: normalized,
            layerFrame: document.layers[index].frame
        )
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

    private func paintSelectedLayerMask(samples: [ImageEditorBrushStrokeSample], reveal: Bool) {
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
        let layer = document.layers[index]
        let maskFrame = layer.isGroup ? CGRect(origin: .zero, size: document.canvasSize) : layer.frame
        var maskLayer = layer
        maskLayer.image = mask
        maskLayer.frame = maskFrame
        guard let updated = mask.withMaskStroke(
            samples: rasterLocalSamples(samples, layer: maskLayer),
            width: rasterLocalBrushWidth(brushSize, layer: maskLayer),
            opacity: opacity,
            hardness: hardness,
            flow: brushFlow / 100,
            spacing: brushSpacing / 100,
            pressureControlsSize: brushPressureControlsSize,
            pressureControlsOpacity: brushPressureControlsOpacity,
            pressureControlsFlow: brushPressureControlsFlow,
            pressureSensitivity: brushPressureSensitivity / 100,
            minimumDiameter: brushMinimumDiameter / 100,
            minimumOpacity: brushMinimumOpacity / 100,
            minimumFlow: brushMinimumFlow / 100,
            tiltControlsShape: brushTiltControlsShape,
            tipRoundness: brushTipRoundness / 100,
            tipAngleDegrees: brushTipAngleDegrees,
            smoothing: brushSmoothing / 100,
            reveal: reveal
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers[index].mask = clippedToSelection(original: mask, output: updated, layerFrame: maskFrame)
        appendHistory(reveal ? L10n.text("imageEditor.history.layerMaskReveal") : L10n.text("imageEditor.history.layerMaskHide"))
    }

    func maskSize(for layer: ImageEditorLayer) -> CGSize {
        layer.isGroup ? document.canvasSize : layer.image.size
    }

    private func clippedToSelection(original: NSImage, output: NSImage, layerFrame: CGRect) -> NSImage {
        guard let selection = document.selection else { return output }
        guard let mask = selectionMask(
            for: selection,
            layerFrame: layerFrame,
            layerSize: original.size
        ) else { return output }
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

    private func selectionMask(
        for selection: ImageEditorSelection,
        layerFrame: CGRect,
        layerSize: CGSize
    ) -> NSImage? {
        let canvasSize = document.canvasSize
        let canvasMask: NSImage?
        if let rasterMask = selection.rasterMask,
           let image = NSImage.selectionMaskImage(
            rasterMask,
            inverted: selection.isInverted,
            targetSize: canvasSize
           ) {
            canvasMask = feather > 0 ? (image.blurred(radius: feather) ?? image) : image
        } else {
            let hardMask = NSImage.rendered(size: canvasSize) { rect in
                let path = selection.path()
                if selection.isInverted {
                    NSColor.white.setFill()
                    rect.fill()
                    NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: canvasSize.height) {
                        guard let context = NSGraphicsContext.current?.cgContext else { return }
                        context.saveGState()
                        context.setBlendMode(.clear)
                        NSColor.clear.setFill()
                        path.fill()
                        context.restoreGState()
                    }
                } else {
                    NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: canvasSize.height) {
                        NSColor.white.setFill()
                        path.fill()
                    }
                }
            }
            canvasMask = feather > 0 ? (hardMask?.blurred(radius: feather) ?? hardMask) : hardMask
        }
        guard let canvasMask else { return nil }
        return NSImage.rendered(size: layerSize) { _ in
            canvasMask.draw(
                in: CGRect(origin: .zero, size: layerSize),
                from: layerFrame,
                operation: .copy,
                fraction: 1
            )
        }
    }

    private func rasterLocalPoints(_ points: [CGPoint], layer: ImageEditorLayer) -> [CGPoint] {
        points.map { rasterLocalPoint($0, layer: layer) }
    }

    private func rasterLocalSamples(
        _ samples: [ImageEditorBrushStrokeSample],
        layer: ImageEditorLayer
    ) -> [ImageEditorBrushStrokeSample] {
        samples.map {
            ImageEditorBrushStrokeSample(
                point: rasterLocalPoint($0.point, layer: layer),
                pressure: $0.pressure,
                tilt: $0.tilt
            )
        }
    }

    private func rasterLocalPoint(_ point: CGPoint, layer: ImageEditorLayer) -> CGPoint {
        CGPoint(
            x: (point.x - layer.frame.minX) / max(layer.frame.width, 1) * layer.image.size.width,
            y: (point.y - layer.frame.minY) / max(layer.frame.height, 1) * layer.image.size.height
        )
    }

    private func rasterLocalBrushWidth(_ width: CGFloat, layer: ImageEditorLayer) -> CGFloat {
        let scaleX = layer.image.size.width / max(layer.frame.width, 1)
        let scaleY = layer.image.size.height / max(layer.frame.height, 1)
        return width * sqrt(max(0.0001, scaleX * scaleY))
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
            scale: CGFloat(patternFillScale),
            offsetX: CGFloat(patternFillOffsetX),
            offsetY: CGFloat(patternFillOffsetY)
        ).normalized()
    }

    private func currentGradientFillContent() -> ImageEditorGradientFillContent {
        var retainedColorStops: [ImageEditorGradientColorStop]?
        if selectedGradientFillPreset == .custom,
           var stops = document.selectedLayer?.gradientFillContent?.normalized().colorStops,
           stops.count >= 2 {
            stops[0].red = gradientFillStartRed
            stops[0].green = gradientFillStartGreen
            stops[0].blue = gradientFillStartBlue
            let lastIndex = stops.count - 1
            stops[lastIndex].red = gradientFillEndRed
            stops[lastIndex].green = gradientFillEndGreen
            stops[lastIndex].blue = gradientFillEndBlue
            retainedColorStops = stops
        }
        return ImageEditorGradientFillContent(
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
            endBlue: gradientFillEndBlue,
            colorStops: retainedColorStops
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
        patternFillOffsetX = 0
        patternFillOffsetY = 0
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

    private func editableSelectedLayerIndices() -> [Int] {
        guard !isEditingLayerMask else { return [] }
        return selectedLayerIndices.filter { index in
            let layer = document.layers[index]
            return !layer.isGroup && !layer.isAdjustment && !layer.isFilter && !layer.isSolidColorFill && !layer.isPatternFill && !layer.isGradientFill && !layer.isText && !layer.isShape && !document.isEffectivelyPixelsLocked(layer)
        }
    }

    private func applyAutoCorrection(_ transform: (NSImage) -> NSImage?, history: String, selectedHistory: String, status: String, selectedStatus: String) {
        let indices = editableSelectedLayerIndices()
        let outputs = indices.reduce(into: [Int: NSImage]()) { result, index in
            if let image = transform(document.layers[index].image) { result[index] = image }
        }
        guard !indices.isEmpty, outputs.count == indices.count else { statusText = L10n.text("imageEditor.status.adjustmentFailed"); return }
        pushUndo()
        for index in indices {
            guard let normalized = outputs[index]?.normalizedBitmapImage() else { continue }
            let original = document.layers[index].image
            let clipped = clippedToSelection(
                original: original,
                output: normalized,
                layerFrame: document.layers[index].frame
            )
            document.layers[index].image = document.isEffectivelyTransparencyLocked(document.layers[index]) ? (clipped.preservingAlpha(from: original) ?? clipped) : clipped
        }
        if indices.count == 1 { appendHistory(L10n.text(history)); statusText = L10n.text(status) }
        else { appendHistory(L10n.text(selectedHistory)); statusText = L10n.format(selectedStatus, indices.count) }
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
              let smartSource = sourceCanvas.croppedUsingImagePixelCoordinates(to: cropBounds)?.normalizedBitmapImage()
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

    private func layerRowPropertyTargetIndices(
        clickedLayerID: UUID,
        applyingToSelection: Bool
    ) -> [Int] {
        guard let clickedIndex = document.layers.firstIndex(where: { $0.id == clickedLayerID }) else {
            return []
        }
        guard applyingToSelection,
              document.selectedLayerIDs.contains(clickedLayerID),
              document.selectedLayerIDs.count > 1
        else {
            return [clickedIndex]
        }
        return selectedLayerIndices
    }

    private func appendLayerRowLockHistory(
        isBatch: Bool,
        isLocked: Bool,
        singleHistoryKey: String,
        selectedLockHistoryKey: String,
        selectedUnlockHistoryKey: String,
        selectedLockStatusKey: String,
        selectedUnlockStatusKey: String
    ) {
        guard isBatch else {
            appendHistory(L10n.text(singleHistoryKey))
            return
        }
        appendHistory(L10n.text(isLocked ? selectedLockHistoryKey : selectedUnlockHistoryKey))
        statusText = L10n.text(isLocked ? selectedLockStatusKey : selectedUnlockStatusKey)
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

    private func canSetLayerMaskProperties(_ layer: ImageEditorLayer) -> Bool {
        layer.mask != nil && !document.isEffectivelyLocked(layer)
    }

    private func canEditSmartFilters(on layer: ImageEditorLayer) -> Bool {
        !layer.isGroup
            && !layer.isAdjustment
            && !layer.isFilter
            && !document.isEffectivelyPixelsLocked(layer)
    }

    private func selectedLayerOpacityTargetIndices() -> [Int] {
        selectedLayerIndices.filter { !document.isEffectivelyLocked(document.layers[$0]) }
    }

    private func selectedLayerFillOpacityTargetIndices() -> [Int] {
        selectedLayerIndices.filter { canSetLayerFillOpacity(document.layers[$0]) }
    }

    private func selectedLayerBlendIfTargetIndices() -> [Int] {
        selectedLayerIndices.filter { canSetLayerBlendIf(document.layers[$0]) }
    }

    private func selectedLayerMaskPropertyTargetIndices() -> [Int] {
        selectedLayerIndices.filter { canSetLayerMaskProperties(document.layers[$0]) }
    }

    private func selectedLayerSmartFilterTargetIndices() -> [Int] {
        selectedLayerIndices.filter { canEditSmartFilters(on: document.layers[$0]) }
    }

    private func selectedLayerSmartFilterUpdateTargetIndices() -> [Int] {
        selectedLayerSmartFilterTargetIndices().filter { !document.layers[$0].smartFilters.isEmpty }
    }

    private func selectedSmartFilterTargetIndices(at filterIndex: Int) -> [Int] {
        selectedLayerSmartFilterUpdateTargetIndices().filter {
            document.layers[$0].smartFilters.indices.contains(filterIndex)
        }
    }

    private func selectedSmartFilterMoveTargetIndices(at filterIndex: Int, offset: Int) -> [Int] {
        let destinationIndex = filterIndex + offset
        return selectedSmartFilterTargetIndices(at: filterIndex).filter {
            document.layers[$0].smartFilters.indices.contains(destinationIndex)
        }
    }

    private func selectedLayerSmartFilterClearTargetIndices() -> [Int] {
        selectedLayerSmartFilterUpdateTargetIndices()
    }

    private func selectedLayerBlendModeTargetIndices(for blendMode: ImageEditorBlendMode) -> [Int] {
        selectedLayerIndices.filter { index in
            canSetLayerBlendMode(document.layers[index], to: blendMode)
        }
    }

    private func canSetLayerBlendMode(_ layer: ImageEditorLayer, to blendMode: ImageEditorBlendMode) -> Bool {
        !layer.isAdjustment
            && !layer.isFilter
            && !document.isEffectivelyLocked(layer)
            && (layer.isGroup || blendMode != .passThrough)
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

    func layerIDsExpandingGroups(_ ids: Set<UUID>) -> Set<UUID> {
        var expandedIDs = ids
        for index in document.layers.indices where ids.contains(document.layers[index].id) && document.layers[index].isGroup {
            expandedIDs.formUnion(groupDescendantIDs(for: document.layers[index].id))
        }
        return expandedIDs
    }

    private func selectedLayerGroupBranchIDs() -> Set<UUID> {
        selectedLayerIndices.reduce(into: Set<UUID>()) { result, index in
            let layer = document.layers[index]
            guard layer.isGroup else { return }
            result.formUnion(layerGroupBranchIDs(rootedAt: layer.id))
        }
    }

    private func layerGroupBranchIDs(rootedAt rootID: UUID) -> Set<UUID> {
        var groupIDs: Set<UUID> = [rootID]
        for descendantID in groupDescendantIDs(for: rootID) {
            guard document.layers.contains(where: { $0.id == descendantID && $0.isGroup }) else { continue }
            groupIDs.insert(descendantID)
        }
        return groupIDs
    }

    @discardableResult
    private func setLayerGroups(_ groupIDs: Set<UUID>, expanded: Bool) -> Int {
        let changedIndices = document.layers.indices.filter { index in
            groupIDs.contains(document.layers[index].id)
                && document.layers[index].isGroup
                && document.layers[index].isGroupExpanded != expanded
        }
        for index in changedIndices {
            document.layers[index].isGroupExpanded = expanded
        }
        return changedIndices.count
    }

    private func setSelectedLayerGroupsExpanded(_ expanded: Bool) {
        let selectedGroupIDs = Set(selectedLayerIndices.compactMap { index in
            let layer = document.layers[index]
            return layer.isGroup ? layer.id : nil
        })
        let changedCount = setLayerGroups(selectedLayerGroupBranchIDs(), expanded: expanded)
        guard changedCount > 0 else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        if !expanded {
            normalizeLayerSelectionAfterGroupCollapse(fallbackGroupIDs: selectedGroupIDs)
        }
        statusText = L10n.format(
            expanded
                ? "imageEditor.status.layerGroupsExpanded"
                : "imageEditor.status.layerGroupsCollapsed",
            changedCount
        )
    }

    private func normalizeLayerSelectionAfterGroupCollapse(fallbackGroupIDs: Set<UUID>) {
        let visibleIDs = Set(visibleLayerRows.map(\.id))
        let hiddenSelectedIDs = document.selectedLayerIDs.subtracting(visibleIDs)
        guard !hiddenSelectedIDs.isEmpty else { return }

        var nextSelectedIDs = document.selectedLayerIDs.intersection(visibleIDs)
        nextSelectedIDs.formUnion(fallbackGroupIDs.intersection(visibleIDs))
        document.selectedLayerIDs = nextSelectedIDs
        if let selectedLayerID = document.selectedLayerID,
           nextSelectedIDs.contains(selectedLayerID) {
            return
        }

        document.selectedLayerID = document.layers.reversed().first { nextSelectedIDs.contains($0.id) }?.id
        isEditingLayerMask = false
        syncControlsFromLayerSelection()
    }

    func isBackgroundLayer(at index: Int) -> Bool {
        guard document.layers.indices.contains(index) else { return false }
        let layer = document.layers[index]
        return index == 0
            && layer.groupID == nil
            && layer.isLocked
            && layer.name == L10n.text("imageEditor.layer.background")
    }

    private var hasBackgroundLayer: Bool {
        document.layers.indices.contains { isBackgroundLayer(at: $0) }
    }

    private func backgroundImage(from layer: ImageEditorLayer) -> NSImage? {
        let fillColor = (backgroundColor.usingColorSpace(.deviceRGB) ?? backgroundColor).withAlphaComponent(1)
        let layerImage = layer.renderedCompositingImage(globalLightAngle: document.globalLightAngle)
        let renderedFrame = layer.renderedCompositingFrame(globalLightAngle: document.globalLightAngle)
        let appKitFrame = CGRect(
            x: renderedFrame.minX,
            y: document.canvasSize.height - renderedFrame.maxY,
            width: renderedFrame.width,
            height: renderedFrame.height
        )
        guard let solidCanvas = NSImage.rendered(size: document.canvasSize, actions: { rect in
            fillColor.setFill()
            rect.fill()
        })?.normalizedBitmapImage(),
              let layerCanvas = NSImage.rendered(size: document.canvasSize, actions: { _ in
            layerImage.draw(
                in: appKitFrame,
                from: CGRect(origin: .zero, size: layerImage.size),
                operation: .sourceOver,
                fraction: 1
            )
        })?.normalizedBitmapImage()
        else { return nil }

        let blendIfCanvas = layerCanvas.applyingBlendIfUnderlyingRange(
            black: layer.blendIfUnderlyingBlack,
            white: layer.blendIfUnderlyingWhite,
            backdrop: solidCanvas
        ) ?? layerCanvas
        let blendMode = layer.blendMode == .passThrough ? ImageEditorBlendMode.normal : layer.blendMode
        return solidCanvas.blended(
            with: blendIfCanvas,
            mode: blendMode,
            opacity: layer.opacity
        )?.normalizedBitmapImage()
    }

    private var selectedLayerIndices: [Int] {
        document.layers.indices.filter { document.selectedLayerIDs.contains(document.layers[$0].id) }
    }

    private func smartObjectUniqueTargetIndices() -> [Int] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            guard selectedIDs.contains(layer.id),
                  let content = layer.smartObjectContent,
                  !document.isEffectivelyPixelsLocked(layer)
            else { return false }
            return document.layers.contains { otherLayer in
                otherLayer.id != layer.id && otherLayer.smartObjectContent?.sourceID == content.sourceID
            }
        }
    }

    func smartObjectReplacementTargetSourceIDs() -> Set<UUID> {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return Set(document.layers.compactMap { layer in
            guard selectedIDs.contains(layer.id),
                  let content = layer.smartObjectContent,
                  !document.isEffectivelyPixelsLocked(layer)
            else { return nil }
            return content.sourceID
        })
    }

    private func smartObjectResetTransformTargetIndices() -> [Int] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && layer.smartObjectContent != nil
                && !document.isEffectivelyPositionLocked(layer)
        }
    }

    var layerMaskAddIndices: [Int] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
                && layer.mask == nil
        }
    }

    private func layerMaskDeleteIndices() -> [Int] {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        return document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && !document.isEffectivelyLocked(layer)
                && layer.mask != nil
        }
    }

    private func topmostSelectedLayerID() -> UUID? {
        document.layers.reversed().first { document.selectedLayerIDs.contains($0.id) }?.id
    }

    private func layerKindFilter(for layer: ImageEditorLayer) -> ImageEditorLayerKindFilter {
        if layer.isText { return .text }
        if layer.isShape { return .shape }
        if layer.isAdjustment { return .adjustment }
        if layer.isFilter { return .filter }
        if layer.isSolidColorFill { return .solidColorFill }
        if layer.isPatternFill { return .patternFill }
        if layer.isGradientFill { return .gradientFill }
        if layer.isSmartObject { return .smartObject }
        if layer.isGroup { return .group }
        return .pixel
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

    private var selectedStampPlan: ImageEditorLayerStampPlan? {
        ImageEditorLayerCompositeHierarchy.stampSelectedPlan(
            layers: document.layers,
            selectedLayerIDs: document.selectedLayerIDs
        )
    }

    private func expandGroupIfNeeded(_ groupID: UUID?) {
        guard let groupID,
              let groupIndex = document.layers.firstIndex(where: { $0.id == groupID && $0.isGroup })
        else { return }
        document.layers[groupIndex].isGroupExpanded = true
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

    private func setSelectedLayersVisibility(_ isVisible: Bool) {
        let indices = selectedLayerIndices.filter { document.layers[$0].isVisible != isVisible }
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        for index in indices {
            document.layers[index].isVisible = isVisible
        }
        appendHistory(L10n.text(isVisible ? "imageEditor.history.layerShowSelected" : "imageEditor.history.layerHideSelected"))
        statusText = L10n.format(
            isVisible ? "imageEditor.status.layerShowSelected" : "imageEditor.status.layerHideSelected",
            indices.count
        )
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

    func normalizeClippingMasks() {
        for index in document.layers.indices where document.layers[index].isClippingMask {
            if document.clippingBaseIndex(forLayerAt: index) == nil {
                document.layers[index].isClippingMask = false
            }
        }
    }

    func mergedAdjustmentLayer(lowerIndex: Int, adjustmentIndex: Int) -> ImageEditorLayer? {
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
                amount: adjustment.amount,
                settings: adjustmentLayer.adjustmentSettings,
                mask: document.localEffectMask(forLayerAt: adjustmentIndex),
                opacity: adjustmentLayer.opacity
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

    func mergedFilterLayer(lowerIndex: Int, filterIndex: Int) -> ImageEditorLayer? {
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
                intensity: filter.intensity,
                settings: filterLayer.filterSettings,
                mask: document.localEffectMask(forLayerAt: filterIndex),
                opacity: filterLayer.opacity
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

    func mergedLayer(lowerIndex: Int, upperIndex: Int) -> ImageEditorLayer? {
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
        undoXomoThemeStates.append(currentXomoThemeUndoState)
        redoStack.removeAll()
        redoXomoThemeStates.removeAll()
    }

    @discardableResult
    func discardLastUndoSnapshot() -> ImageEditorDocument? {
        let snapshot = undoStack.popLast()
        if !undoXomoThemeStates.isEmpty {
            undoXomoThemeStates.removeLast()
        }
        return snapshot
    }

    func clearUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        undoXomoThemeStates.removeAll()
        redoXomoThemeStates.removeAll()
    }

    func appendHistory(_ title: String) {
        let entry = ImageEditorHistoryEntry(title: title)
        mutateDocumentWithoutInvalidatingRenderedImageCaches { document in
            document.history.append(entry)
        }
        historySnapshots[entry.id] = document
        selectedHistoryEntryID = entry.id
        refreshColorSamplers()
        updateStatus()
    }

    private func mutateDocumentWithoutInvalidatingRenderedImageCaches(
        _ mutation: (inout ImageEditorDocument) -> Void
    ) {
        preservesRenderedImageCachesForNextDocumentMutation = true
        mutation(&document)
    }

    private func recordCurrentHistorySnapshot() {
        guard let entry = document.history.last else { return }
        historySnapshots[entry.id] = document
        selectedHistoryEntryID = entry.id
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

    private var selectedHistorySnapshotIndex: Int? {
        guard let selectedHistorySnapshotID else { return nil }
        return namedHistorySnapshots.firstIndex { $0.id == selectedHistorySnapshotID }
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

    func syncAdjustmentControlsFromSelection() {
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

    func syncFilterControlsFromSelection() {
        if let smartFilter = document.selectedLayer?.smartFilters.last {
            syncSmartFilterControls(smartFilter)
            return
        }
        loadedSmartFilterID = nil
        guard let filter = document.selectedLayer?.filter else { return }
        selectedFilter = filter.kind
        filterIntensity = filter.intensity
        syncFilterSettings(document.selectedLayer?.filterSettings.normalized() ?? ImageEditorFilterSettings())
    }

    private func syncSmartFilterControls(_ smartFilter: ImageEditorSmartFilter) {
        loadedSmartFilterID = smartFilter.id
        selectedFilter = smartFilter.kind
        filterIntensity = smartFilter.normalizedIntensity
        syncFilterSettings(smartFilter.normalizedSettings)
    }

    private func syncFilterSettings(_ settings: ImageEditorFilterSettings) {
        let normalized = settings.normalized()
        filterGaussianBlurRadius = normalized.gaussianBlurRadius
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
        filterPinchAmount = normalized.pinchAmount
        filterSpherizeAmount = normalized.spherizeAmount
        filterLensDistortion = normalized.lensDistortion
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
        patternFillOffsetX = Double(content.offsetX)
        patternFillOffsetY = Double(content.offsetY)
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
        selectedFontFamilyName = content.fontFamilyName
        foregroundColor = content.color
        textBold = content.isBold
        textItalic = content.isItalic
        textUnderlined = content.isUnderlined
        textStruckThrough = content.isStruckThrough
        textCharacterSpacing = Double(content.characterSpacing)
        textLineSpacing = Double(content.lineSpacing)
        textParagraphSpacing = Double(content.paragraphSpacing)
        textBoxWidth = Double(content.boxWidth)
        textBoxHeight = Double(content.boxHeight)
        selectedTextAlignment = content.alignment
        selectedTextCase = content.textCase
        textTruncatesOverflow = content.truncatesOverflow
        selectedTextVerticalAlignment = content.verticalAlignment
        textLeftIndent = Double(content.leftIndent)
        textRightIndent = Double(content.rightIndent)
        textFirstLineIndent = Double(content.firstLineIndent)
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
            if selectedPathSubpathIndex != 0 {
                selectedPathSubpathIndex = 0
            }
            if selectedPathAnchorIndex != nil {
                selectedPathAnchorIndex = nil
            }
            if selectedPathControlRole != .anchor {
                selectedPathControlRole = .anchor
            }
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

    private func addShapeLayer(
        frame: CGRect,
        kind: ImageEditorShapeKind,
        cornerRadius: Double?,
        cornerRadii: ImageEditorRectangleCornerRadii?,
        cornerSmoothing: Double?,
        fillColor: NSColor?,
        fillGradient: ImageEditorGradientFillContent?,
        fillGradientCenter: CGPoint?,
        fillOpacity: Double?,
        strokeColor: NSColor?,
        strokeOpacity: Double?,
        strokeWidth: Double?,
        strokePosition: ImageEditorStrokePosition?,
        strokeCap: ImageEditorStrokeCap?,
        strokeJoin: ImageEditorStrokeJoin?,
        strokeMiterLimit: Double?,
        strokeDashPattern: [CGFloat]?
    ) {
        let requestedCornerRadius = cornerRadius?.isFinite == true ? CGFloat(cornerRadius ?? 0) : 0
        let requestedCornerSmoothing = cornerSmoothing?.isFinite == true
            ? CGFloat(cornerSmoothing ?? 0)
            : 0
        let maximumCornerRadius = max(0, min(frame.width, frame.height) / 2)
        let content = ImageEditorShapeContent(
            kind: kind,
            fillColor: fillColor ?? foregroundColor,
            fillGradient: fillGradient,
            fillGradientCenter: fillGradientCenter ?? CGPoint(x: 0.5, y: 0.5),
            fillOpacity: CGFloat(clampedShapeOpacity(fillOpacity, fallback: opacity)),
            strokeColor: strokeColor ?? foregroundColor,
            strokeWidth: CGFloat(clampedShapeStrokeWidth(strokeWidth)),
            strokeOpacity: CGFloat(
                clampedShapeOpacity(strokeOpacity, fallback: min(1, max(0.15, opacity)))
            ),
            strokePosition: strokePosition ?? .inside,
            strokeCap: strokeCap ?? .round,
            strokeJoin: strokeJoin ?? .round,
            strokeMiterLimit: CGFloat(
                strokeMiterLimit?.isFinite == true
                    ? strokeMiterLimit ?? Double(ImageEditorShapeContent.defaultStrokeMiterLimit)
                    : Double(ImageEditorShapeContent.defaultStrokeMiterLimit)
            ),
            strokeDashPattern: strokeDashPattern ?? [],
            cornerRadius: kind == .rectangle
                ? min(maximumCornerRadius, max(0, requestedCornerRadius))
                : 0,
            cornerRadii: kind == .rectangle
                ? cornerRadii?.normalized(size: frame.size)
                : nil,
            cornerSmoothing: kind == .rectangle
                ? max(0, min(1, requestedCornerSmoothing))
                : 0
        ).normalized(size: frame.size)
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

    private func clampedShapeOpacity(_ value: Double?, fallback: Double) -> Double {
        guard let value, value.isFinite else { return fallback }
        return max(0, min(1, value))
    }

    private func clampedShapeStrokeWidth(_ value: Double?) -> Double {
        let resolved = value?.isFinite == true ? value ?? 1 : brushSize * 0.35
        return max(
            Double(ImageEditorShapeContent.minimumStrokeWidth),
            min(Double(ImageEditorShapeContent.maximumStrokeWidth), resolved)
        )
    }

    private func clampedTextSize(_ size: Double) -> Double {
        max(
            Double(ImageEditorTextContent.minimumFontSize),
            min(Double(ImageEditorTextContent.maximumFontSize), size)
        )
    }

    private func clampedTextCharacterSpacing(_ spacing: Double) -> Double {
        max(
            Double(ImageEditorTextContent.minimumCharacterSpacing),
            min(Double(ImageEditorTextContent.maximumCharacterSpacing), spacing)
        )
    }

    private func clampedTextLineSpacing(_ spacing: Double) -> Double {
        max(0, min(Double(ImageEditorTextContent.maximumLineSpacing), spacing))
    }

    private func clampedTextParagraphSpacing(_ spacing: Double) -> Double {
        max(0, min(Double(ImageEditorTextContent.maximumParagraphSpacing), spacing))
    }

    private func clampedTextBoxWidth(_ width: Double) -> Double {
        max(0, min(Double(ImageEditorTextContent.maximumBoxDimension), width))
    }

    private func clampedTextBoxHeight(_ height: Double) -> Double {
        max(0, min(Double(ImageEditorTextContent.maximumBoxDimension), height))
    }

    private func clampedTextIndent(_ indent: Double) -> Double {
        max(0, min(800, indent))
    }

    private func clampedTextFirstLineIndent(_ indent: Double) -> Double {
        let limit = Double(ImageEditorTextContent.maximumFirstLineIndent)
        return max(-limit, min(limit, indent))
    }

    private func textLayerNameFragment(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(trimmed.prefix(18))
        return prefix.isEmpty ? L10n.text("imageEditor.layer.textFallbackName") : prefix
    }

    func updateStatus() {
        statusText = L10n.format("imageEditor.status.ready", sizeText, zoomText)
    }

    func cachedAlphaChannelPreviewImage(_ channel: ImageEditorAlphaChannel) -> NSImage {
        if let image = cachedAlphaChannelPreviewImages[channel.id] {
            return image
        }

        let image = channel.mask.grayscalePreviewImage(targetSize: document.canvasSize)
        cachedAlphaChannelPreviewImages[channel.id] = image
        return image
    }

    private func invalidateRenderedImageCaches() {
        cachedCurrentImage = nil
        resetPointerSampleCache()
        cachedChannelPreviewImages.removeAll(keepingCapacity: true)
        cachedAlphaChannelPreviewImages.removeAll(keepingCapacity: true)
        cachedChannelThumbnailImages.removeAll(keepingCapacity: true)
        cachedAlphaChannelThumbnailImages.removeAll(keepingCapacity: true)
        cachedHistogramSummary = nil
        cachedSelectedLayerHistogramSummary = nil
        cachedSelectionHistogramSummary = nil
        cachedLayerTransparencySelectionAvailability = nil
        cachedLayerTransformContentFrames.removeAll(keepingCapacity: true)
        cachedEmptyTransformLayerIDs.removeAll(keepingCapacity: true)
    }

    private static let channelThumbnailSize = CGSize(width: 84, height: 56)

}

extension NSImage {
    func normalizedBitmapImage() -> NSImage {
        let targetSize = size.width > 0 && size.height > 0 ? size : CGSize(width: 1, height: 1)
        return Self.rendered(size: targetSize) { _ in
            draw(
                in: CGRect(origin: .zero, size: targetSize),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
        } ?? self
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

    func withCloneStamp(
        points: [CGPoint],
        sourceOffset: CGSize,
        sourceImage: NSImage,
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat
    ) -> NSImage? {
        withCloneStamp(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            sourceOffset: sourceOffset,
            sourceImage: sourceImage,
            width: width,
            opacity: opacity,
            hardness: hardness,
            pressureControlsSize: false,
            pressureSensitivity: 0.5
        )
    }

    func withCloneStamp(
        samples: [ImageEditorBrushStrokeSample],
        sourceOffset: CGSize,
        sourceImage: NSImage,
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> NSImage? {
        guard !samples.isEmpty else { return nil }

        let shiftedSource = NSImage.rendered(size: size) { _ in
            sourceImage.draw(
                in: CGRect(
                    x: -sourceOffset.width,
                    y: sourceOffset.height,
                    width: sourceImage.size.width,
                    height: sourceImage.size.height
                ),
                from: CGRect(origin: .zero, size: sourceImage.size),
                operation: .copy,
                fraction: 1
            )
        }
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        let maskAlpha = retouchStrokeAlpha(
            width: pixelWidth,
            height: pixelHeight,
            samples: samples,
            diameter: width,
            hardness: hardness,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        )
        let strokeMask = NSImage.alphaMaskImage(
            width: pixelWidth,
            height: pixelHeight,
            alpha: maskAlpha
        )
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

    func withMaskStroke(
        points: [CGPoint],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat = 1,
        flow: CGFloat = 1,
        spacing: CGFloat = 0.25,
        reveal: Bool
    ) -> NSImage? {
        withMaskStroke(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            width: width,
            opacity: opacity,
            hardness: hardness,
            flow: flow,
            spacing: spacing,
            reveal: reveal
        )
    }

    func withMaskStroke(
        samples: [ImageEditorBrushStrokeSample],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat = 1,
        flow: CGFloat = 1,
        spacing: CGFloat = 0.25,
        pressureControlsSize: Bool = false,
        pressureControlsOpacity: Bool = false,
        pressureControlsFlow: Bool = false,
        pressureSensitivity: CGFloat = 0.5,
        minimumDiameter: CGFloat = 0,
        minimumOpacity: CGFloat = 0,
        minimumFlow: CGFloat = 0,
        tiltControlsShape: Bool = false,
        tipRoundness: CGFloat = 1,
        tipAngleDegrees: CGFloat = 0,
        smoothing: CGFloat = 0,
        reveal: Bool
    ) -> NSImage? {
        withBrushStroke(
            samples: samples,
            color: .white,
            settings: ImageEditorBrushStrokeSettings(
                diameter: width,
                hardness: hardness,
                opacity: opacity,
                flow: flow,
                spacing: spacing,
                pressureControlsSize: pressureControlsSize,
                pressureControlsOpacity: pressureControlsOpacity,
                pressureControlsFlow: pressureControlsFlow,
                pressureSensitivity: pressureSensitivity,
                minimumDiameter: minimumDiameter,
                minimumOpacity: minimumOpacity,
                minimumFlow: minimumFlow,
                tiltControlsShape: tiltControlsShape,
                tipRoundness: tipRoundness,
                tipAngleDegrees: tipAngleDegrees,
                smoothing: smoothing
            ),
            erase: !reveal
        )
    }

    func withShape(rect: CGRect, color: NSColor, width: CGFloat, opacity: CGFloat, ellipse: Bool) -> NSImage? {
        rendered(size: size) { _ in
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                let path = ellipse ? NSBezierPath(ovalIn: rect) : NSBezierPath(rect: rect)
                path.lineWidth = width
                color.withAlphaComponent(opacity).setStroke()
                path.stroke()
            }
        }
    }

    func withText(_ text: String, at point: CGPoint, color: NSColor, opacity: CGFloat) -> NSImage? {
        rendered(size: size) { _ in
            draw(in: CGRect(origin: .zero, size: size), from: CGRect(origin: .zero, size: size), operation: .copy, fraction: 1)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(18, min(size.width, size.height) * 0.055), weight: .semibold),
                .foregroundColor: color.withAlphaComponent(opacity)
            ]
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                text.draw(at: point, withAttributes: attributes)
            }
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

    func color(at point: CGPoint, coordinateSize: CGSize? = nil) -> NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let logicalSize = coordinateSize ?? size
        let x = max(0, min(cgImage.width - 1, Int((point.x / max(logicalSize.width, 1)) * CGFloat(cgImage.width))))
        let y = max(0, min(cgImage.height - 1, Int((point.y / max(logicalSize.height, 1)) * CGFloat(cgImage.height))))
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let color = bitmap.colorAt(x: x, y: y) else { return nil }
        return color.usingColorSpace(.deviceRGB) ?? color
    }

    static func rendered(size outputSize: CGSize, actions: (CGRect) -> Void) -> NSImage? {
        guard outputSize.width > 0, outputSize.height > 0 else { return nil }
        let pixelWidth = max(1, Int(outputSize.width.rounded()))
        let pixelHeight = max(1, Int(outputSize.height.rounded()))
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: pixelWidth * 4,
            bitsPerPixel: 32
        ),
              let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else { return nil }

        bitmap.size = outputSize
        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.current = previousContext }

        let rect = CGRect(origin: .zero, size: outputSize)
        context.saveGraphicsState()
        defer { context.restoreGraphicsState() }
        NSColor.clear.setFill()
        rect.fill()
        actions(rect)

        let image = NSImage(size: outputSize)
        image.addRepresentation(bitmap)
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

extension NSGraphicsContext {
    func withImageEditorTopLeftCoordinates(height: CGFloat, actions: () -> Void) {
        saveGraphicsState()
        cgContext.translateBy(x: 0, y: height)
        cgContext.scaleBy(x: 1, y: -1)
        actions()
        restoreGraphicsState()
    }
}
