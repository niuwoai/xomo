import AppKit
import CoreImage
import Foundation
import simd

enum ImageEditorFilter: String, CaseIterable, Identifiable {
    case gaussianBlur
    case sharpen
    case pixelate
    case motionBlur
    case addNoise
    case median
    case unsharpMask
    case highPass
    case emboss
    case findEdges
    case minimum
    case maximum
    case oilPaint
    case vignette
    case offset
    case wave
    case ripple
    case pinch
    case spherize
    case lensCorrection
    case liquifyPush
    case liquifyTwirl
    case liquifyPuckerBloat

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.filter.\(rawValue)")
    }
}

enum ImageEditorOffsetUndefinedAreaMode: String, CaseIterable, Identifiable, Codable {
    case wrapAround
    case repeatEdgePixels
    case transparent

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.filter.offsetUndefinedArea.\(rawValue)")
    }
}

enum ImageEditorAddNoiseDistribution: String, CaseIterable, Identifiable, Codable {
    case uniform
    case gaussian

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.filter.addNoiseDistribution.\(rawValue)")
    }
}

struct ImageEditorFilterApplication: Equatable {
    var kind: ImageEditorFilter
    var intensity: Double
    var settings: ImageEditorFilterSettings
}

struct ImageEditorSmartFilter: Identifiable, Equatable, Codable {
    var id = UUID()
    var kind: ImageEditorFilter
    var intensity: Double
    var settings = ImageEditorFilterSettings()
    var isEnabled = true
    /// Blends the complete filter result back over its input without weakening filter parameters.
    var opacity = 1.0
    /// Applies a Photoshop-style blend mode between the filter input and its complete result.
    var blendMode = ImageEditorBlendMode.normal
    /// When true, a Gaussian blur samples the already-composited pixels behind the layer.
    /// This keeps Figma BACKGROUND_BLUR non-destructive instead of baking the backdrop.
    var appliesToBackdrop = false
    /// Per-filter grayscale coverage stored in the filtered layer's pixel space.
    /// Nil means the filter applies everywhere, preserving older project files.
    var mask: ImageEditorSelectionMask?
    /// Photoshop-style mask density; 1 preserves authored coverage and 0 reveals the full filter result.
    var maskDensity = 1.0
    /// Gaussian feather radius in filter-local pixels.
    var maskFeather = 0.0
    var isMaskInverted = false
    /// Retained samples per original filter pixel unit after a pixel edit promotes its backing.
    var pixelSamplingScale: Double?

    init(
        id: UUID = UUID(),
        kind: ImageEditorFilter,
        intensity: Double,
        settings: ImageEditorFilterSettings = ImageEditorFilterSettings(),
        isEnabled: Bool = true,
        opacity: Double = 1,
        blendMode: ImageEditorBlendMode = .normal,
        appliesToBackdrop: Bool = false,
        mask: ImageEditorSelectionMask? = nil,
        maskDensity: Double = 1,
        maskFeather: Double = 0,
        isMaskInverted: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.intensity = intensity
        self.settings = settings
        self.isEnabled = isEnabled
        self.opacity = max(0, min(1, opacity))
        self.blendMode = blendMode == .passThrough ? .normal : blendMode
        self.appliesToBackdrop = appliesToBackdrop
        self.mask = mask
        self.maskDensity = Self.normalizedMaskDensity(maskDensity)
        self.maskFeather = Self.normalizedMaskFeather(maskFeather)
        self.isMaskInverted = isMaskInverted
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case intensity
        case settings
        case isEnabled
        case opacity
        case blendMode
        case appliesToBackdrop
        case pixelSamplingScale
        case mask
        case maskDensity
        case maskFeather
        case isMaskInverted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decode(ImageEditorFilter.self, forKey: .kind)
        intensity = try container.decode(Double.self, forKey: .intensity)
        settings = try container.decodeIfPresent(ImageEditorFilterSettings.self, forKey: .settings) ?? ImageEditorFilterSettings()
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        opacity = max(0, min(1, try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1))
        blendMode = try container.decodeIfPresent(ImageEditorBlendMode.self, forKey: .blendMode) ?? .normal
        if blendMode == .passThrough { blendMode = .normal }
        appliesToBackdrop = try container.decodeIfPresent(Bool.self, forKey: .appliesToBackdrop) ?? false
        pixelSamplingScale = try container.decodeIfPresent(Double.self, forKey: .pixelSamplingScale)
        mask = try container.decodeIfPresent(ImageEditorSelectionMask.self, forKey: .mask)
        maskDensity = Self.normalizedMaskDensity(try container.decodeIfPresent(Double.self, forKey: .maskDensity) ?? 1)
        maskFeather = Self.normalizedMaskFeather(try container.decodeIfPresent(Double.self, forKey: .maskFeather) ?? 0)
        isMaskInverted = try container.decodeIfPresent(Bool.self, forKey: .isMaskInverted) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(settings, forKey: .settings)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(normalizedBlendMode, forKey: .blendMode)
        try container.encode(appliesToBackdrop, forKey: .appliesToBackdrop)
        try container.encodeIfPresent(pixelSamplingScale, forKey: .pixelSamplingScale)
        try container.encodeIfPresent(mask, forKey: .mask)
        try container.encode(normalizedMaskDensity, forKey: .maskDensity)
        try container.encode(normalizedMaskFeather, forKey: .maskFeather)
        try container.encode(isMaskInverted, forKey: .isMaskInverted)
    }

    var normalizedMaskDensity: Double {
        Self.normalizedMaskDensity(maskDensity)
    }

    var normalizedMaskFeather: Double {
        Self.normalizedMaskFeather(maskFeather)
    }

    private static func normalizedMaskDensity(_ value: Double) -> Double {
        value.isFinite ? max(0, min(1, value)) : 1
    }

    private static func normalizedMaskFeather(_ value: Double) -> Double {
        value.isFinite ? max(0, min(80, value)) : 0
    }

    var normalizedIntensity: Double {
        max(0, min(1, intensity))
    }

    var normalizedOpacity: Double {
        max(0, min(1, opacity))
    }

    var normalizedBlendMode: ImageEditorBlendMode {
        blendMode == .passThrough ? .normal : blendMode
    }

    var normalizedSettings: ImageEditorFilterSettings {
        var normalized = settings.normalized()
        normalized.renderingScale = 1
        return normalized
    }

    var renderingSettings: ImageEditorFilterSettings {
        var normalized = normalizedSettings
        normalized.renderingScale = appliesToBackdrop ? 1 : ImageEditorMaskSampling.featherScale(pixelSamplingScale)
        return normalized
    }
}

struct ImageEditorFilterSettings: Equatable, Codable {
    /// Transient render-grid multiplier; not an editable setting or an encoded key.
    var renderingScale: Double = 1
    /// When present, Gaussian blur uses this pixel radius instead of the UI's normalized intensity.
    /// Figma layer-blur imports use this to retain the source radius across project round-trips.
    var gaussianBlurRadius: Double?
    /// Explicit Sharpen amount from 0% to 200%. Nil preserves the legacy intensity-derived amount.
    var sharpenAmountPercent: Double?
    /// Explicit High Pass radius in pixels. Nil preserves the legacy intensity-derived radius.
    var highPassRadius: Double?
    /// High Pass detail gain from 0% to 400%. Nil preserves the legacy intensity-derived gain.
    /// New UI-created filters persist 100% for Photoshop-style radius-only behavior.
    var highPassGainPercent: Double?
    /// Explicit Minimum/Maximum radius in pixels. Nil preserves the legacy intensity-derived radius.
    var morphologyRadius: Double?
    /// Explicit Pixelate/Mosaic cell size in pixels. Nil preserves the legacy intensity-derived scale.
    var pixelateCellSize: Double?
    /// Add Noise amount from 0.1% to 400%. Nil preserves the legacy intensity-derived amount.
    var addNoiseAmountPercent: Double?
    /// Whether Add Noise uses one shared value for RGB. Nil preserves the legacy monochromatic result.
    var addNoiseMonochromatic: Bool?
    /// Nil preserves the legacy uniform Add Noise distribution.
    var addNoiseDistribution: ImageEditorAddNoiseDistribution?
    /// Explicit Motion Blur angle in degrees. Nil preserves the legacy horizontal direction.
    var motionBlurAngleDegrees: Double?
    /// Explicit Motion Blur distance in pixels. Nil preserves the legacy intensity-derived distance.
    var motionBlurDistance: Double?
    /// Explicit Emboss light angle in degrees. Nil preserves the legacy fixed diagonal kernel.
    var embossAngleDegrees: Double?
    /// Explicit Emboss relief height in pixels. Nil preserves the legacy one-pixel diagonal kernel.
    var embossHeight: Double?
    /// Vignette amount from -100% (darken edges) to 100% (lighten edges).
    /// Nil preserves the legacy intensity-derived darkening amount.
    var vignetteAmountPercent: Double?
    /// Vignette feather start as a normalized radius. Nil preserves the legacy 28% midpoint.
    var vignetteMidpoint: Double?
    /// Oil Paint neighborhood radius in pixels. Nil preserves the legacy intensity-derived radius.
    var oilPaintRadius: Double?
    /// Oil Paint luminance bucket count. Nil preserves the legacy intensity-derived count.
    var oilPaintTonalLevels: Double?
    /// Oil Paint stylization from 0 to 10. Nil preserves the legacy fully stylized result.
    var oilPaintStylization: Double?
    /// Oil Paint cleanliness from 0 to 10. Nil preserves the legacy dominant-bucket result.
    var oilPaintCleanliness: Double?
    /// Oil Paint bristle detail from 0 to 10. Nil preserves the legacy texture-free result.
    var oilPaintBristleDetail: Double?
    /// Oil Paint directional shine from 0 to 10. Nil preserves the legacy unlit result.
    var oilPaintShine: Double?
    /// Oil Paint lighting angle in degrees. Nil preserves the legacy fixed 135-degree direction.
    var oilPaintLightingAngleDegrees: Double?
    /// Whether Oil Paint lighting is active. Nil preserves the legacy enabled behavior.
    var oilPaintLightingEnabled: Bool?
    /// Unsharp Mask amount from 1% to 500%. Nil preserves the legacy intensity-derived amount.
    var unsharpAmountPercent: Double?
    /// Precise Unsharp Mask radius from 0.1 to 250 pixels. Nil preserves legacy rounded-radius rendering.
    var unsharpRadiusPixels: Double?
    /// Precise Unsharp Mask threshold from 0 to 255 levels. Nil preserves the legacy normalized threshold.
    var unsharpThresholdLevels: Double?
    var unsharpRadius: Double = 1
    var unsharpThreshold: Double = 0
    /// Explicit horizontal Liquify Push displacement at the effect center in pixels.
    /// Nil preserves legacy normalized X × intensity × effect radius.
    var liquifyPushXPixels: Double?
    /// Explicit vertical Liquify Push displacement at the effect center in pixels.
    /// Nil preserves legacy normalized Y × intensity × effect radius.
    var liquifyPushYPixels: Double?
    var liquifyPushX: Double = 0.25
    var liquifyPushY: Double = 0
    /// Twirl angle from -999° to 999°. Nil preserves legacy angle × intensity × 270°.
    var liquifyTwirlAngleDegrees: Double?
    var liquifyTwirlAngle: Double = 0.5
    /// Pucker/Bloat amount from -100% to 100%. Nil preserves legacy amount × intensity.
    var liquifyBulgeAmountPercent: Double?
    var liquifyBulgeAmount: Double = 0.5
    /// Explicit horizontal Offset in pixels. Nil preserves legacy normalized X × intensity.
    var offsetXPixels: Double?
    /// Explicit vertical Offset in pixels. Nil preserves legacy normalized Y × intensity.
    var offsetYPixels: Double?
    var offsetX: Double = 0.25
    var offsetY: Double = 0
    var offsetUndefinedAreaMode = ImageEditorOffsetUndefinedAreaMode.wrapAround
    /// Wave amplitude from -100% to 100%. Nil preserves legacy amplitude × intensity.
    var waveAmplitudePercent: Double?
    var waveAmplitude: Double = 0.5
    var waveFrequency: Double = 0.25
    /// Ripple amount from -100% to 100%. Nil preserves legacy amount × intensity.
    var rippleAmountPercent: Double?
    var rippleAmount: Double = 0.5
    var rippleFrequency: Double = 0.25
    /// Pinch amount from -100% to 100%. Nil preserves legacy amount × intensity.
    var pinchAmountPercent: Double?
    var pinchAmount: Double = 0.5
    /// Spherize amount from -100% to 100%. Nil preserves legacy amount × intensity.
    var spherizeAmountPercent: Double?
    var spherizeAmount: Double = 0.5
    /// Lens distortion amount from -100% to 100%. Nil preserves legacy distortion × intensity.
    var lensDistortionAmountPercent: Double?
    var lensDistortion: Double = 0.35

    init(
        gaussianBlurRadius: Double? = nil,
        sharpenAmountPercent: Double? = nil,
        highPassRadius: Double? = nil,
        highPassGainPercent: Double? = nil,
        morphologyRadius: Double? = nil,
        pixelateCellSize: Double? = nil,
        addNoiseAmountPercent: Double? = nil,
        addNoiseMonochromatic: Bool? = nil,
        addNoiseDistribution: ImageEditorAddNoiseDistribution? = nil,
        motionBlurAngleDegrees: Double? = nil,
        motionBlurDistance: Double? = nil,
        embossAngleDegrees: Double? = nil,
        embossHeight: Double? = nil,
        vignetteAmountPercent: Double? = nil,
        vignetteMidpoint: Double? = nil,
        oilPaintRadius: Double? = nil,
        oilPaintTonalLevels: Double? = nil,
        oilPaintStylization: Double? = nil,
        oilPaintCleanliness: Double? = nil,
        oilPaintBristleDetail: Double? = nil,
        oilPaintShine: Double? = nil,
        oilPaintLightingAngleDegrees: Double? = nil,
        oilPaintLightingEnabled: Bool? = nil,
        unsharpAmountPercent: Double? = nil,
        unsharpRadiusPixels: Double? = nil,
        unsharpThresholdLevels: Double? = nil,
        unsharpRadius: Double = 1,
        unsharpThreshold: Double = 0,
        liquifyPushXPixels: Double? = nil,
        liquifyPushYPixels: Double? = nil,
        liquifyPushX: Double = 0.25,
        liquifyPushY: Double = 0,
        liquifyTwirlAngleDegrees: Double? = nil,
        liquifyTwirlAngle: Double = 0.5,
        liquifyBulgeAmountPercent: Double? = nil,
        liquifyBulgeAmount: Double = 0.5,
        offsetXPixels: Double? = nil,
        offsetYPixels: Double? = nil,
        offsetX: Double = 0.25,
        offsetY: Double = 0,
        offsetUndefinedAreaMode: ImageEditorOffsetUndefinedAreaMode = .wrapAround,
        waveAmplitudePercent: Double? = nil,
        waveAmplitude: Double = 0.5,
        waveFrequency: Double = 0.25,
        rippleAmountPercent: Double? = nil,
        rippleAmount: Double = 0.5,
        rippleFrequency: Double = 0.25,
        pinchAmountPercent: Double? = nil,
        pinchAmount: Double = 0.5,
        spherizeAmountPercent: Double? = nil,
        spherizeAmount: Double = 0.5,
        lensDistortionAmountPercent: Double? = nil,
        lensDistortion: Double = 0.35
    ) {
        self.gaussianBlurRadius = gaussianBlurRadius
        self.sharpenAmountPercent = sharpenAmountPercent
        self.highPassRadius = highPassRadius
        self.highPassGainPercent = highPassGainPercent
        self.morphologyRadius = morphologyRadius
        self.pixelateCellSize = pixelateCellSize
        self.addNoiseAmountPercent = addNoiseAmountPercent
        self.addNoiseMonochromatic = addNoiseMonochromatic
        self.addNoiseDistribution = addNoiseDistribution
        self.motionBlurAngleDegrees = motionBlurAngleDegrees
        self.motionBlurDistance = motionBlurDistance
        self.embossAngleDegrees = embossAngleDegrees
        self.embossHeight = embossHeight
        self.vignetteAmountPercent = vignetteAmountPercent
        self.vignetteMidpoint = vignetteMidpoint
        self.oilPaintRadius = oilPaintRadius
        self.oilPaintTonalLevels = oilPaintTonalLevels
        self.oilPaintStylization = oilPaintStylization
        self.oilPaintCleanliness = oilPaintCleanliness
        self.oilPaintBristleDetail = oilPaintBristleDetail
        self.oilPaintShine = oilPaintShine
        self.oilPaintLightingAngleDegrees = oilPaintLightingAngleDegrees
        self.oilPaintLightingEnabled = oilPaintLightingEnabled
        self.unsharpAmountPercent = unsharpAmountPercent
        self.unsharpRadiusPixels = unsharpRadiusPixels
        self.unsharpThresholdLevels = unsharpThresholdLevels
        self.unsharpRadius = unsharpRadius
        self.unsharpThreshold = unsharpThreshold
        self.liquifyPushXPixels = liquifyPushXPixels
        self.liquifyPushYPixels = liquifyPushYPixels
        self.liquifyPushX = liquifyPushX
        self.liquifyPushY = liquifyPushY
        self.liquifyTwirlAngleDegrees = liquifyTwirlAngleDegrees
        self.liquifyTwirlAngle = liquifyTwirlAngle
        self.liquifyBulgeAmountPercent = liquifyBulgeAmountPercent
        self.liquifyBulgeAmount = liquifyBulgeAmount
        self.offsetXPixels = offsetXPixels
        self.offsetYPixels = offsetYPixels
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.offsetUndefinedAreaMode = offsetUndefinedAreaMode
        self.waveAmplitudePercent = waveAmplitudePercent
        self.waveAmplitude = waveAmplitude
        self.waveFrequency = waveFrequency
        self.rippleAmountPercent = rippleAmountPercent
        self.rippleAmount = rippleAmount
        self.rippleFrequency = rippleFrequency
        self.pinchAmountPercent = pinchAmountPercent
        self.pinchAmount = pinchAmount
        self.spherizeAmountPercent = spherizeAmountPercent
        self.spherizeAmount = spherizeAmount
        self.lensDistortionAmountPercent = lensDistortionAmountPercent
        self.lensDistortion = lensDistortion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gaussianBlurRadius = try container.decodeIfPresent(Double.self, forKey: .gaussianBlurRadius)
        sharpenAmountPercent = try container.decodeIfPresent(Double.self, forKey: .sharpenAmountPercent)
        highPassRadius = try container.decodeIfPresent(Double.self, forKey: .highPassRadius)
        highPassGainPercent = try container.decodeIfPresent(Double.self, forKey: .highPassGainPercent)
        morphologyRadius = try container.decodeIfPresent(Double.self, forKey: .morphologyRadius)
        pixelateCellSize = try container.decodeIfPresent(Double.self, forKey: .pixelateCellSize)
        addNoiseAmountPercent = try container.decodeIfPresent(Double.self, forKey: .addNoiseAmountPercent)
        addNoiseMonochromatic = try container.decodeIfPresent(Bool.self, forKey: .addNoiseMonochromatic)
        addNoiseDistribution = try container.decodeIfPresent(
            ImageEditorAddNoiseDistribution.self,
            forKey: .addNoiseDistribution
        )
        motionBlurAngleDegrees = try container.decodeIfPresent(Double.self, forKey: .motionBlurAngleDegrees)
        motionBlurDistance = try container.decodeIfPresent(Double.self, forKey: .motionBlurDistance)
        embossAngleDegrees = try container.decodeIfPresent(Double.self, forKey: .embossAngleDegrees)
        embossHeight = try container.decodeIfPresent(Double.self, forKey: .embossHeight)
        vignetteAmountPercent = try container.decodeIfPresent(Double.self, forKey: .vignetteAmountPercent)
        vignetteMidpoint = try container.decodeIfPresent(Double.self, forKey: .vignetteMidpoint)
        oilPaintRadius = try container.decodeIfPresent(Double.self, forKey: .oilPaintRadius)
        oilPaintTonalLevels = try container.decodeIfPresent(Double.self, forKey: .oilPaintTonalLevels)
        oilPaintStylization = try container.decodeIfPresent(Double.self, forKey: .oilPaintStylization)
        oilPaintCleanliness = try container.decodeIfPresent(Double.self, forKey: .oilPaintCleanliness)
        oilPaintBristleDetail = try container.decodeIfPresent(Double.self, forKey: .oilPaintBristleDetail)
        oilPaintShine = try container.decodeIfPresent(Double.self, forKey: .oilPaintShine)
        oilPaintLightingAngleDegrees = try container.decodeIfPresent(Double.self, forKey: .oilPaintLightingAngleDegrees)
        oilPaintLightingEnabled = try container.decodeIfPresent(Bool.self, forKey: .oilPaintLightingEnabled)
        unsharpAmountPercent = try container.decodeIfPresent(Double.self, forKey: .unsharpAmountPercent)
        unsharpRadiusPixels = try container.decodeIfPresent(Double.self, forKey: .unsharpRadiusPixels)
        unsharpThresholdLevels = try container.decodeIfPresent(Double.self, forKey: .unsharpThresholdLevels)
        unsharpRadius = try container.decodeIfPresent(Double.self, forKey: .unsharpRadius) ?? 1
        unsharpThreshold = try container.decodeIfPresent(Double.self, forKey: .unsharpThreshold) ?? 0
        liquifyPushXPixels = try container.decodeIfPresent(Double.self, forKey: .liquifyPushXPixels)
        liquifyPushYPixels = try container.decodeIfPresent(Double.self, forKey: .liquifyPushYPixels)
        liquifyPushX = try container.decodeIfPresent(Double.self, forKey: .liquifyPushX) ?? 0.25
        liquifyPushY = try container.decodeIfPresent(Double.self, forKey: .liquifyPushY) ?? 0
        liquifyTwirlAngleDegrees = try container.decodeIfPresent(Double.self, forKey: .liquifyTwirlAngleDegrees)
        liquifyTwirlAngle = try container.decodeIfPresent(Double.self, forKey: .liquifyTwirlAngle) ?? 0.5
        liquifyBulgeAmountPercent = try container.decodeIfPresent(Double.self, forKey: .liquifyBulgeAmountPercent)
        liquifyBulgeAmount = try container.decodeIfPresent(Double.self, forKey: .liquifyBulgeAmount) ?? 0.5
        offsetXPixels = try container.decodeIfPresent(Double.self, forKey: .offsetXPixels)
        offsetYPixels = try container.decodeIfPresent(Double.self, forKey: .offsetYPixels)
        offsetX = try container.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0.25
        offsetY = try container.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0
        offsetUndefinedAreaMode = try container.decodeIfPresent(
            ImageEditorOffsetUndefinedAreaMode.self,
            forKey: .offsetUndefinedAreaMode
        ) ?? .wrapAround
        waveAmplitudePercent = try container.decodeIfPresent(Double.self, forKey: .waveAmplitudePercent)
        waveAmplitude = try container.decodeIfPresent(Double.self, forKey: .waveAmplitude) ?? 0.5
        waveFrequency = try container.decodeIfPresent(Double.self, forKey: .waveFrequency) ?? 0.25
        rippleAmountPercent = try container.decodeIfPresent(Double.self, forKey: .rippleAmountPercent)
        rippleAmount = try container.decodeIfPresent(Double.self, forKey: .rippleAmount) ?? 0.5
        rippleFrequency = try container.decodeIfPresent(Double.self, forKey: .rippleFrequency) ?? 0.25
        pinchAmountPercent = try container.decodeIfPresent(Double.self, forKey: .pinchAmountPercent)
        pinchAmount = try container.decodeIfPresent(Double.self, forKey: .pinchAmount) ?? 0.5
        spherizeAmountPercent = try container.decodeIfPresent(Double.self, forKey: .spherizeAmountPercent)
        spherizeAmount = try container.decodeIfPresent(Double.self, forKey: .spherizeAmount) ?? 0.5
        lensDistortionAmountPercent = try container.decodeIfPresent(
            Double.self,
            forKey: .lensDistortionAmountPercent
        )
        lensDistortion = try container.decodeIfPresent(Double.self, forKey: .lensDistortion) ?? 0.35
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(gaussianBlurRadius, forKey: .gaussianBlurRadius)
        try container.encodeIfPresent(sharpenAmountPercent, forKey: .sharpenAmountPercent)
        try container.encodeIfPresent(highPassRadius, forKey: .highPassRadius)
        try container.encodeIfPresent(highPassGainPercent, forKey: .highPassGainPercent)
        try container.encodeIfPresent(morphologyRadius, forKey: .morphologyRadius)
        try container.encodeIfPresent(pixelateCellSize, forKey: .pixelateCellSize)
        try container.encodeIfPresent(addNoiseAmountPercent, forKey: .addNoiseAmountPercent)
        try container.encodeIfPresent(addNoiseMonochromatic, forKey: .addNoiseMonochromatic)
        try container.encodeIfPresent(addNoiseDistribution, forKey: .addNoiseDistribution)
        try container.encodeIfPresent(motionBlurAngleDegrees, forKey: .motionBlurAngleDegrees)
        try container.encodeIfPresent(motionBlurDistance, forKey: .motionBlurDistance)
        try container.encodeIfPresent(embossAngleDegrees, forKey: .embossAngleDegrees)
        try container.encodeIfPresent(embossHeight, forKey: .embossHeight)
        try container.encodeIfPresent(vignetteAmountPercent, forKey: .vignetteAmountPercent)
        try container.encodeIfPresent(vignetteMidpoint, forKey: .vignetteMidpoint)
        try container.encodeIfPresent(oilPaintRadius, forKey: .oilPaintRadius)
        try container.encodeIfPresent(oilPaintTonalLevels, forKey: .oilPaintTonalLevels)
        try container.encodeIfPresent(oilPaintStylization, forKey: .oilPaintStylization)
        try container.encodeIfPresent(oilPaintCleanliness, forKey: .oilPaintCleanliness)
        try container.encodeIfPresent(oilPaintBristleDetail, forKey: .oilPaintBristleDetail)
        try container.encodeIfPresent(oilPaintShine, forKey: .oilPaintShine)
        try container.encodeIfPresent(oilPaintLightingAngleDegrees, forKey: .oilPaintLightingAngleDegrees)
        try container.encodeIfPresent(oilPaintLightingEnabled, forKey: .oilPaintLightingEnabled)
        try container.encodeIfPresent(unsharpAmountPercent, forKey: .unsharpAmountPercent)
        try container.encodeIfPresent(unsharpRadiusPixels, forKey: .unsharpRadiusPixels)
        try container.encodeIfPresent(unsharpThresholdLevels, forKey: .unsharpThresholdLevels)
        try container.encode(unsharpRadius, forKey: .unsharpRadius)
        try container.encode(unsharpThreshold, forKey: .unsharpThreshold)
        try container.encodeIfPresent(liquifyPushXPixels, forKey: .liquifyPushXPixels)
        try container.encodeIfPresent(liquifyPushYPixels, forKey: .liquifyPushYPixels)
        try container.encode(liquifyPushX, forKey: .liquifyPushX)
        try container.encode(liquifyPushY, forKey: .liquifyPushY)
        try container.encodeIfPresent(liquifyTwirlAngleDegrees, forKey: .liquifyTwirlAngleDegrees)
        try container.encode(liquifyTwirlAngle, forKey: .liquifyTwirlAngle)
        try container.encodeIfPresent(liquifyBulgeAmountPercent, forKey: .liquifyBulgeAmountPercent)
        try container.encode(liquifyBulgeAmount, forKey: .liquifyBulgeAmount)
        try container.encodeIfPresent(offsetXPixels, forKey: .offsetXPixels)
        try container.encodeIfPresent(offsetYPixels, forKey: .offsetYPixels)
        try container.encode(offsetX, forKey: .offsetX)
        try container.encode(offsetY, forKey: .offsetY)
        try container.encode(offsetUndefinedAreaMode, forKey: .offsetUndefinedAreaMode)
        try container.encodeIfPresent(waveAmplitudePercent, forKey: .waveAmplitudePercent)
        try container.encode(waveAmplitude, forKey: .waveAmplitude)
        try container.encode(waveFrequency, forKey: .waveFrequency)
        try container.encodeIfPresent(rippleAmountPercent, forKey: .rippleAmountPercent)
        try container.encode(rippleAmount, forKey: .rippleAmount)
        try container.encode(rippleFrequency, forKey: .rippleFrequency)
        try container.encodeIfPresent(pinchAmountPercent, forKey: .pinchAmountPercent)
        try container.encode(pinchAmount, forKey: .pinchAmount)
        try container.encodeIfPresent(spherizeAmountPercent, forKey: .spherizeAmountPercent)
        try container.encode(spherizeAmount, forKey: .spherizeAmount)
        try container.encodeIfPresent(lensDistortionAmountPercent, forKey: .lensDistortionAmountPercent)
        try container.encode(lensDistortion, forKey: .lensDistortion)
    }

    func normalized() -> ImageEditorFilterSettings {
        var normalized = ImageEditorFilterSettings(
            gaussianBlurRadius: gaussianBlurRadius.map { max(0, min(1_000, $0)) },
            sharpenAmountPercent: sharpenAmountPercent.map { max(0, min(200, $0)) },
            highPassRadius: highPassRadius.map { max(1, min(1_000, $0)) },
            highPassGainPercent: highPassGainPercent.map { max(0, min(400, $0)) },
            morphologyRadius: morphologyRadius.map { max(1, min(256, $0)) },
            pixelateCellSize: pixelateCellSize.map { max(2, min(200, $0)) },
            addNoiseAmountPercent: addNoiseAmountPercent.map { max(0.1, min(400, $0)) },
            addNoiseMonochromatic: addNoiseMonochromatic,
            addNoiseDistribution: addNoiseDistribution,
            motionBlurAngleDegrees: motionBlurAngleDegrees.map { max(-180, min(180, $0)) },
            motionBlurDistance: motionBlurDistance.map { max(1, min(999, $0)) },
            embossAngleDegrees: embossAngleDegrees.map { max(-180, min(180, $0)) },
            embossHeight: embossHeight.map { max(1, min(10, $0)) },
            vignetteAmountPercent: vignetteAmountPercent.map { max(-100, min(100, $0)) },
            vignetteMidpoint: vignetteMidpoint.map { max(0, min(0.95, $0)) },
            oilPaintRadius: oilPaintRadius.map { max(1, min(10, $0)) },
            oilPaintTonalLevels: oilPaintTonalLevels.map { max(6, min(18, $0)) },
            oilPaintStylization: oilPaintStylization.map { max(0, min(10, $0)) },
            oilPaintCleanliness: oilPaintCleanliness.map { max(0, min(10, $0)) },
            oilPaintBristleDetail: oilPaintBristleDetail.map { max(0, min(10, $0)) },
            oilPaintShine: oilPaintShine.map { max(0, min(10, $0)) },
            oilPaintLightingAngleDegrees: oilPaintLightingAngleDegrees.map { max(-180, min(180, $0)) },
            oilPaintLightingEnabled: oilPaintLightingEnabled,
            unsharpAmountPercent: unsharpAmountPercent.map { max(1, min(500, $0)) },
            unsharpRadiusPixels: unsharpRadiusPixels.map { max(0.1, min(250, $0)) },
            unsharpThresholdLevels: unsharpThresholdLevels.map { max(0, min(255, $0)) },
            unsharpRadius: max(0.5, min(5, unsharpRadius)),
            unsharpThreshold: max(0, min(1, unsharpThreshold)),
            liquifyPushXPixels: liquifyPushXPixels.map { max(-9_999, min(9_999, $0)) },
            liquifyPushYPixels: liquifyPushYPixels.map { max(-9_999, min(9_999, $0)) },
            liquifyPushX: max(-1, min(1, liquifyPushX)),
            liquifyPushY: max(-1, min(1, liquifyPushY)),
            liquifyTwirlAngleDegrees: liquifyTwirlAngleDegrees.map { max(-999, min(999, $0)) },
            liquifyTwirlAngle: max(-1, min(1, liquifyTwirlAngle)),
            liquifyBulgeAmountPercent: liquifyBulgeAmountPercent.map { max(-100, min(100, $0)) },
            liquifyBulgeAmount: max(-1, min(1, liquifyBulgeAmount)),
            offsetXPixels: offsetXPixels.map { max(-9_999, min(9_999, $0)) },
            offsetYPixels: offsetYPixels.map { max(-9_999, min(9_999, $0)) },
            offsetX: max(-1, min(1, offsetX)),
            offsetY: max(-1, min(1, offsetY)),
            offsetUndefinedAreaMode: offsetUndefinedAreaMode,
            waveAmplitudePercent: waveAmplitudePercent.map { max(-100, min(100, $0)) },
            waveAmplitude: max(-1, min(1, waveAmplitude)),
            waveFrequency: max(0, min(1, waveFrequency)),
            rippleAmountPercent: rippleAmountPercent.map { max(-100, min(100, $0)) },
            rippleAmount: max(-1, min(1, rippleAmount)),
            rippleFrequency: max(0, min(1, rippleFrequency)),
            pinchAmountPercent: pinchAmountPercent.map { max(-100, min(100, $0)) },
            pinchAmount: max(-1, min(1, pinchAmount)),
            spherizeAmountPercent: spherizeAmountPercent.map { max(-100, min(100, $0)) },
            spherizeAmount: max(-1, min(1, spherizeAmount)),
            lensDistortionAmountPercent: lensDistortionAmountPercent.map { max(-100, min(100, $0)) },
            lensDistortion: max(-1, min(1, lensDistortion))
        )
        normalized.renderingScale = ImageEditorMaskSampling.featherScale(renderingScale)
        return normalized
    }

    private enum CodingKeys: String, CodingKey {
        case gaussianBlurRadius
        case sharpenAmountPercent
        case highPassRadius
        case highPassGainPercent
        case morphologyRadius
        case pixelateCellSize
        case addNoiseAmountPercent
        case addNoiseMonochromatic
        case addNoiseDistribution
        case motionBlurAngleDegrees
        case motionBlurDistance
        case embossAngleDegrees
        case embossHeight
        case vignetteAmountPercent
        case vignetteMidpoint
        case oilPaintRadius
        case oilPaintTonalLevels
        case oilPaintStylization
        case oilPaintCleanliness
        case oilPaintBristleDetail
        case oilPaintShine
        case oilPaintLightingAngleDegrees
        case oilPaintLightingEnabled
        case unsharpAmountPercent
        case unsharpRadiusPixels
        case unsharpThresholdLevels
        case unsharpRadius
        case unsharpThreshold
        case liquifyPushXPixels
        case liquifyPushYPixels
        case liquifyPushX
        case liquifyPushY
        case liquifyTwirlAngleDegrees
        case liquifyTwirlAngle
        case liquifyBulgeAmountPercent
        case liquifyBulgeAmount
        case offsetXPixels
        case offsetYPixels
        case offsetX
        case offsetY
        case offsetUndefinedAreaMode
        case waveAmplitudePercent
        case waveAmplitude
        case waveFrequency
        case rippleAmountPercent
        case rippleAmount
        case rippleFrequency
        case pinchAmountPercent
        case pinchAmount
        case spherizeAmountPercent
        case spherizeAmount
        case lensDistortionAmountPercent
        case lensDistortion
    }
}

enum ImageEditorLayerResizeHandle: String, CaseIterable, Identifiable {
    case topLeft
    case top
    case topRight
    case left
    case right
    case bottomLeft
    case bottom
    case bottomRight

    var id: String { rawValue }

    var affectsWidth: Bool {
        switch self {
        case .top, .bottom:
            false
        case .topLeft, .topRight, .left, .right, .bottomLeft, .bottomRight:
            true
        }
    }

    var affectsHeight: Bool {
        switch self {
        case .left, .right:
            false
        case .topLeft, .top, .topRight, .bottomLeft, .bottom, .bottomRight:
            true
        }
    }
}

enum ImageEditorBlendMode: String, CaseIterable, Identifiable {
    case passThrough
    case normal
    case dissolve
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case darkerColor
    case lighterColor
    case colorDodge
    case colorBurn
    case linearDodge
    case linearBurn
    case subtract
    case divide
    case softLight
    case hardLight
    case vividLight
    case linearLight
    case pinLight
    case hardMix
    case difference
    case exclusion
    case hue
    case saturation
    case color
    case luminosity

    var id: String { rawValue }

    static var smartFilterCases: [ImageEditorBlendMode] {
        allCases.filter { $0 != .passThrough }
    }

    /// Brush and Pencil share the paint modes backed by the pixel compositor.
    /// Pass-through belongs to groups, while Dissolve needs stochastic per-dab
    /// semantics that the continuous stroke kernel does not currently promise.
    static var paintCases: [ImageEditorBlendMode] {
        allCases.filter { $0 != .passThrough && $0 != .dissolve }
    }

    var title: String {
        L10n.text("imageEditor.blend.\(rawValue)")
    }

    var operation: NSCompositingOperation {
        switch self {
        case .passThrough, .normal, .dissolve:
            .sourceOver
        case .multiply:
            .multiply
        case .screen:
            .screen
        case .overlay:
            .overlay
        case .darken:
            .darken
        case .lighten:
            .lighten
        case .darkerColor:
            .darken
        case .lighterColor:
            .lighten
        case .colorDodge:
            .colorDodge
        case .colorBurn:
            .colorBurn
        case .linearDodge:
            .plusLighter
        case .linearBurn, .subtract, .divide:
            .sourceOver
        case .softLight:
            .softLight
        case .hardLight:
            .hardLight
        case .vividLight, .linearLight, .pinLight, .hardMix:
            .sourceOver
        case .difference:
            .difference
        case .exclusion, .hue, .saturation, .color, .luminosity:
            .sourceOver
        }
    }
}

enum ImageEditorPatternOverlayKind: String, CaseIterable, Identifiable {
    case checkerboard
    case diagonalStripes
    case dots

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.patternOverlay.\(rawValue)")
    }

    func tileImage(
        color: NSColor,
        opacity: CGFloat,
        scale: CGFloat,
        invertsCoverage: Bool = false
    ) -> NSImage {
        let tileSize = max(6, min(64, scale))
        let size = CGSize(width: tileSize, height: tileSize)
        let patternColor = color.withAlphaComponent(max(0.05, min(1, opacity)))
        return NSImage.rendered(size: size) { rect in
            NSColor.clear.setFill()
            rect.fill()
            let context = NSGraphicsContext.current
            let originalOperation = context?.compositingOperation
            if invertsCoverage {
                patternColor.setFill()
                rect.fill()
                context?.compositingOperation = .destinationOut
                NSColor.black.setFill()
                NSColor.black.setStroke()
            } else {
                patternColor.setFill()
                patternColor.setStroke()
            }
            defer {
                if let originalOperation {
                    context?.compositingOperation = originalOperation
                }
            }
            switch self {
            case .checkerboard:
                let half = tileSize / 2
                CGRect(x: 0, y: 0, width: half, height: half).fill()
                CGRect(x: half, y: half, width: half, height: half).fill()
            case .diagonalStripes:
                let path = NSBezierPath()
                path.lineWidth = max(2, tileSize / 5)
                for offset in stride(from: -tileSize, through: tileSize * 2, by: tileSize / 2) {
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.line(to: CGPoint(x: offset + tileSize, y: tileSize))
                }
                path.stroke()
            case .dots:
                let diameter = max(2, tileSize / 3)
                let inset = (tileSize - diameter) / 2
                NSBezierPath(ovalIn: CGRect(x: inset, y: inset, width: diameter, height: diameter)).fill()
            }
        } ?? NSImage(size: size)
    }
}

enum ImageEditorStrokePosition: String, CaseIterable, Identifiable, Codable {
    case outside
    case center
    case inside

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.strokePosition.\(rawValue)")
    }

    func outsideWidth(totalWidth: Int) -> Int {
        switch self {
        case .outside:
            totalWidth
        case .center:
            Int(ceil(CGFloat(totalWidth) / 2))
        case .inside:
            0
        }
    }

    func insideWidth(totalWidth: Int) -> Int {
        switch self {
        case .outside:
            0
        case .center:
            max(0, totalWidth - outsideWidth(totalWidth: totalWidth))
        case .inside:
            totalWidth
        }
    }

    var paddingScale: CGFloat {
        switch self {
        case .outside:
            1
        case .center:
            0.5
        case .inside:
            0
        }
    }
}

enum ImageEditorStrokeFillType: String, CaseIterable, Identifiable, Codable {
    case color
    case gradient
    case pattern

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.strokeFillType.\(rawValue)")
    }
}

enum ImageEditorInnerGlowSource: String, CaseIterable, Identifiable, Codable {
    case edge
    case center

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.innerGlowSource.\(rawValue)")
    }
}

enum ImageEditorBevelDirection: String, CaseIterable, Identifiable, Codable {
    case up
    case down

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.bevelDirection.\(rawValue)")
    }
}

enum ImageEditorLayerEffectContour: String, CaseIterable, Identifiable, Codable {
    case linear
    case soft
    case steep
    case cone
    case ring

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.layerEffectContour.\(rawValue)")
    }

    func mappedAlpha(_ alpha: CGFloat) -> CGFloat {
        let value = max(0, min(1, alpha))
        switch self {
        case .linear:
            return value
        case .soft:
            return pow(value, 1.7)
        case .steep:
            return pow(value, 0.55)
        case .cone:
            return sin(value * .pi)
        case .ring:
            return pow(sin(value * .pi * 2), 2)
        }
    }
}

struct ImageEditorLayerStyle {
    var effectsEnabled = true
    var effectScale: CGFloat = 1
    var strokeEnabled = false
    var strokeColor = NSColor.white
    var strokeWidth: CGFloat = 3
    var strokePosition = ImageEditorStrokePosition.outside
    var strokeOpacity: CGFloat = 1
    var strokeFillType = ImageEditorStrokeFillType.color
    var strokeGradientStartColor = NSColor.white
    var strokeGradientEndColor = NSColor.black
    var strokeGradientStyle = ImageEditorGradientFillStyle.linear
    var strokeGradientAngle: CGFloat = 0
    var strokePatternKind = ImageEditorPatternOverlayKind.checkerboard
    var strokePatternColor = NSColor.white
    var strokePatternScale: CGFloat = 14
    var strokePatternOffset = CGSize.zero
    var shadowEnabled = false
    var shadowColor = NSColor.black
    var shadowOpacity: CGFloat = 0.35
    var shadowBlur: CGFloat = 8
    var shadowSpread: CGFloat = 0
    var shadowNoise: CGFloat = 0
    var shadowContour = ImageEditorLayerEffectContour.linear
    var shadowDistance: CGFloat = 10
    var shadowAngle: CGFloat = -45
    var shadowUsesGlobalLight = true
    var shadowOffset = CGSize(width: 7, height: -7)
    var innerShadowEnabled = false
    var innerShadowColor = NSColor.black
    var innerShadowOpacity: CGFloat = 0.35
    var innerShadowBlur: CGFloat = 8
    var innerShadowChoke: CGFloat = 0
    var innerShadowNoise: CGFloat = 0
    var innerShadowContour = ImageEditorLayerEffectContour.linear
    var innerShadowDistance: CGFloat = 7
    var innerShadowAngle: CGFloat = -45
    var innerShadowUsesGlobalLight = true
    var outerGlowEnabled = false
    var outerGlowColor = NSColor.systemYellow
    var outerGlowOpacity: CGFloat = 0.42
    var outerGlowBlur: CGFloat = 10
    var outerGlowSpread: CGFloat = 3
    var outerGlowTechnique = ImageEditorGlowTechnique.softer
    var outerGlowNoise: CGFloat = 0
    var outerGlowContour = ImageEditorLayerEffectContour.linear
    var outerGlowRange: CGFloat = 0.5
    var outerGlowJitter: CGFloat = 0
    var innerGlowEnabled = false
    var innerGlowColor = NSColor.systemCyan
    var innerGlowOpacity: CGFloat = 0.36
    var innerGlowBlur: CGFloat = 8
    var innerGlowChoke: CGFloat = 2
    var innerGlowTechnique = ImageEditorGlowTechnique.softer
    var innerGlowNoise: CGFloat = 0
    var innerGlowSource = ImageEditorInnerGlowSource.edge
    var innerGlowContour = ImageEditorLayerEffectContour.linear
    var innerGlowRange: CGFloat = 0.5
    var innerGlowJitter: CGFloat = 0
    var colorOverlayEnabled = false
    var colorOverlayColor = NSColor.systemRed
    var colorOverlayOpacity: CGFloat = 0.55
    var gradientOverlayEnabled = false
    var gradientOverlayStartColor = NSColor.systemRed
    var gradientOverlayEndColor = NSColor.white
    var gradientOverlayOpacity: CGFloat = 0.55
    var gradientOverlayBlendMode = ImageEditorBlendMode.normal
    var gradientOverlayStyle = ImageEditorGradientFillStyle.linear
    var gradientOverlayScale: CGFloat = 1
    var gradientOverlayAngle: CGFloat = 0
    var gradientOverlayReverse = false
    var gradientOverlayDither = false
    var gradientOverlayColorStops: [ImageEditorGradientColorStop]? = nil
    var gradientOverlayCenter = CGPoint(x: 0.5, y: 0.5)
    var patternOverlayEnabled = false
    var patternOverlayKind = ImageEditorPatternOverlayKind.checkerboard
    var patternOverlayColor = NSColor.white
    var patternOverlayOpacity: CGFloat = 0.45
    var patternOverlayScale: CGFloat = 14
    var patternOverlayOffset = CGSize.zero
    var satinEnabled = false
    var satinColor = NSColor.black
    var satinOpacity: CGFloat = 0.35
    var satinDistance: CGFloat = 8
    var satinSize: CGFloat = 6
    var satinAngle: CGFloat = 19
    var satinInvert = false
    var satinContour = ImageEditorLayerEffectContour.linear
    var bevelEnabled = false
    var bevelHighlightColor = NSColor.white
    var bevelShadowColor = NSColor.black
    var bevelOpacity: CGFloat = 0.38
    var bevelSize: CGFloat = 4
    var bevelSoften: CGFloat = 0
    var bevelAngle: CGFloat = -45
    var bevelUsesGlobalLight = true
    var bevelDirection = ImageEditorBevelDirection.up

    var hasConfiguredEffects: Bool {
        strokeEnabled
            || shadowEnabled
            || innerShadowEnabled
            || outerGlowEnabled
            || innerGlowEnabled
            || colorOverlayEnabled
            || gradientOverlayEnabled
            || patternOverlayEnabled
            || satinEnabled
            || bevelEnabled
    }

    var hasEffects: Bool {
        effectsEnabled && hasConfiguredEffects
    }

    func resolvedForRendering() -> ImageEditorLayerStyle {
        let scale = max(0.01, min(10, effectScale))
        guard abs(scale - 1) > 0.0001 else { return self }

        var style = self
        style.effectScale = 1
        style.strokeWidth *= scale
        style.strokePatternScale *= scale
        style.strokePatternOffset = CGSize(
            width: strokePatternOffset.width * scale,
            height: strokePatternOffset.height * scale
        )
        style.shadowBlur *= scale
        style.shadowSpread *= scale
        style.shadowDistance *= scale
        style.shadowOffset = CGSize(width: shadowOffset.width * scale, height: shadowOffset.height * scale)
        style.innerShadowBlur *= scale
        style.innerShadowChoke *= scale
        style.innerShadowDistance *= scale
        style.outerGlowBlur *= scale
        style.outerGlowSpread *= scale
        style.innerGlowBlur *= scale
        style.innerGlowChoke *= scale
        style.gradientOverlayScale *= scale
        style.patternOverlayScale *= scale
        style.patternOverlayOffset = CGSize(
            width: patternOverlayOffset.width * scale,
            height: patternOverlayOffset.height * scale
        )
        style.satinDistance *= scale
        style.satinSize *= scale
        style.bevelSize *= scale
        style.bevelSoften *= scale
        return style
    }

    var padding: CGFloat {
        padding(globalLightAngle: nil)
    }

    func padding(globalLightAngle: CGFloat?) -> CGFloat {
        let style = resolvedForRendering()
        guard hasEffects else { return 0 }
        let strokePadding = style.strokeEnabled ? ceil(style.strokeWidth * style.strokePosition.paddingScale) : 0
        let effectiveShadowOffset = style.resolvedShadowOffset(globalLightAngle: globalLightAngle)
        let shadowPadding = style.shadowEnabled
            ? style.shadowBlur * 2 + style.shadowSpread + max(abs(effectiveShadowOffset.width), abs(effectiveShadowOffset.height))
            : 0
        let outerGlowPadding = style.outerGlowEnabled
            ? style.outerGlowBlur * 2 + style.outerGlowSpread
            : 0
        return ceil(max(strokePadding, shadowPadding, outerGlowPadding) + 2)
    }

    var shadowOffsetForCurrentLight: CGSize {
        resolvedShadowOffset(globalLightAngle: nil)
    }

    func resolvedShadowOffset(globalLightAngle: CGFloat?) -> CGSize {
        Self.shadowOffset(
            distance: shadowDistance,
            angle: resolvedShadowAngle(globalLightAngle: globalLightAngle)
        )
    }

    func resolvedShadowAngle(globalLightAngle: CGFloat?) -> CGFloat {
        shadowUsesGlobalLight ? (globalLightAngle ?? shadowAngle) : shadowAngle
    }

    func resolvedInnerShadowAngle(globalLightAngle: CGFloat?) -> CGFloat {
        innerShadowUsesGlobalLight ? (globalLightAngle ?? innerShadowAngle) : innerShadowAngle
    }

    func resolvedBevelAngle(globalLightAngle: CGFloat?) -> CGFloat {
        bevelUsesGlobalLight ? (globalLightAngle ?? bevelAngle) : bevelAngle
    }

    static func shadowOffset(distance: CGFloat, angle: CGFloat) -> CGSize {
        let radians = angle * .pi / 180
        return CGSize(width: cos(radians) * distance, height: sin(radians) * distance)
    }

    static func shadowDistance(from offset: CGSize) -> CGFloat {
        sqrt(offset.width * offset.width + offset.height * offset.height)
    }

    static func shadowAngle(from offset: CGSize) -> CGFloat {
        atan2(offset.height, offset.width) * 180 / .pi
    }

    func strokeFillImage(size: CGSize) -> NSImage {
        switch strokeFillType {
        case .color:
            return NSImage.rendered(size: size) { rect in
                let color = strokeColor.usingColorSpace(.deviceRGB) ?? .white
                color.withAlphaComponent(strokeOpacity).setFill()
                rect.fill()
            } ?? NSImage.transparent(size: size)
        case .gradient:
            let start = strokeGradientStartColor.usingColorSpace(.deviceRGB) ?? .white
            let end = strokeGradientEndColor.usingColorSpace(.deviceRGB) ?? .black
            return ImageEditorGradientFillContent(
                preset: .custom,
                style: strokeGradientStyle,
                angle: strokeGradientAngle,
                scale: 1,
                startRed: Double(start.redComponent),
                startGreen: Double(start.greenComponent),
                startBlue: Double(start.blueComponent),
                endRed: Double(end.redComponent),
                endGreen: Double(end.greenComponent),
                endBlue: Double(end.blueComponent)
            ).renderedImage(size: size).withOpacity(strokeOpacity) ?? NSImage.transparent(size: size)
        case .pattern:
            let tile = strokePatternKind.tileImage(
                color: strokePatternColor,
                opacity: strokeOpacity,
                scale: strokePatternScale
            )
            return NSImage.rendered(size: size) { rect in
                let context = NSGraphicsContext.current
                let originalPatternPhase = context?.patternPhase ?? .zero
                context?.patternPhase = CGPoint(
                    x: strokePatternOffset.width,
                    y: strokePatternOffset.height
                )
                defer {
                    context?.patternPhase = originalPatternPhase
                }
                NSColor(patternImage: tile).setFill()
                rect.fill()
            } ?? NSImage.transparent(size: size)
        }
    }
}
