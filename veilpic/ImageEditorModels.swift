//
//  ImageEditorModels.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

enum ImageEditorTool: String, CaseIterable, Identifiable {
    case move
    case marquee
    case lasso
    case magicWand
    case crop
    case brush
    case eraser
    case cloneStamp
    case dodge
    case burn
    case blur
    case sharpen
    case smudge
    case healingBrush
    case paintBucket
    case gradient
    case eyedropper
    case text
    case rectangle
    case ellipse
    case pen
    case hand
    case zoom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.tool.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .move:
            "cursorarrow.motionlines"
        case .marquee:
            "rectangle.dashed"
        case .lasso:
            "lasso"
        case .magicWand:
            "wand.and.stars"
        case .crop:
            "crop"
        case .brush:
            "paintbrush.pointed"
        case .eraser:
            "eraser"
        case .cloneStamp:
            "seal"
        case .dodge:
            "sun.max"
        case .burn:
            "flame"
        case .blur:
            "drop"
        case .sharpen:
            "sparkles"
        case .smudge:
            "scribble.variable"
        case .healingBrush:
            "bandage"
        case .paintBucket:
            "paintbucket.fill"
        case .gradient:
            "square.lefthalf.filled"
        case .eyedropper:
            "eyedropper"
        case .text:
            "textformat"
        case .rectangle:
            "rectangle"
        case .ellipse:
            "circle"
        case .pen:
            "pencil.tip"
        case .hand:
            "hand.draw"
        case .zoom:
            "magnifyingglass"
        }
    }

    var isImplemented: Bool {
        switch self {
        case .move, .marquee, .lasso, .magicWand, .crop, .brush, .eraser, .cloneStamp, .dodge, .burn, .blur, .sharpen, .smudge, .healingBrush, .paintBucket, .gradient, .eyedropper, .text, .rectangle, .ellipse, .pen, .hand, .zoom:
            true
        }
    }

    var supportsSelectionMode: Bool {
        switch self {
        case .marquee, .lasso, .magicWand:
            true
        default:
            false
        }
    }

    var supportsTolerance: Bool {
        switch self {
        case .magicWand, .paintBucket:
            true
        default:
            false
        }
    }
}

enum ImageEditorSelectionMode: String, CaseIterable, Identifiable {
    case replace
    case add
    case subtract
    case intersect

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.selectionMode.\(rawValue)")
    }

    var compactTitle: String {
        L10n.text("imageEditor.selectionMode.\(rawValue).short")
    }

    var historyKey: String {
        switch self {
        case .replace:
            "imageEditor.history.selection"
        case .add:
            "imageEditor.history.selectionAdd"
        case .subtract:
            "imageEditor.history.selectionSubtract"
        case .intersect:
            "imageEditor.history.selectionIntersect"
        }
    }
}

struct ImageEditorSelectionMask: Equatable, Codable {
    var width: Int
    var height: Int
    var alpha: [UInt8]

    var size: CGSize {
        CGSize(width: width, height: height)
    }
}

struct ImageEditorAlphaChannel: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var mask: ImageEditorSelectionMask
}

struct ImageEditorSelection: Equatable, Codable {
    var points: [CGPoint]
    var isPolygon: Bool
    var isInverted = false
    var rasterMask: ImageEditorSelectionMask?

    static func rectangle(_ rect: CGRect) -> ImageEditorSelection {
        let normalized = rect.standardized
        return ImageEditorSelection(
            points: [
                CGPoint(x: normalized.minX, y: normalized.minY),
                CGPoint(x: normalized.maxX, y: normalized.minY),
                CGPoint(x: normalized.maxX, y: normalized.maxY),
                CGPoint(x: normalized.minX, y: normalized.maxY)
            ],
            isPolygon: false,
            isInverted: false,
            rasterMask: nil
        )
    }

    static func polygon(_ points: [CGPoint]) -> ImageEditorSelection? {
        guard points.count >= 3 else { return nil }
        return ImageEditorSelection(points: points, isPolygon: true, isInverted: false, rasterMask: nil)
    }

    static func raster(mask: ImageEditorSelectionMask, bounds: CGRect) -> ImageEditorSelection {
        var selection = rectangle(bounds)
        selection.rasterMask = mask
        return selection
    }

    var bounds: CGRect {
        guard let first = points.first else { return .zero }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
    }

    func path() -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: point)
        }
        path.close()
        return path
    }

    func contains(_ point: CGPoint) -> Bool {
        if isPolygon {
            return path().contains(point)
        }
        return bounds.contains(point)
    }
}

enum ImageEditorAdjustment: String, CaseIterable, Identifiable {
    case brightness
    case contrast
    case brightnessContrast
    case saturation
    case vibrance
    case exposure
    case hue
    case hueSaturation
    case shadowsHighlights
    case invert
    case threshold
    case posterize
    case levels
    case curves
    case colorBalance
    case blackWhite
    case channelMixer
    case photoFilter
    case colorLookup
    case selectiveColor
    case gradientMap
    case blur
    case sharpen

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.adjustment.\(rawValue)")
    }
}

enum ImageEditorChannelMixerOutput: String, CaseIterable, Identifiable {
    case red
    case green
    case blue
    case monochrome

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.channelMixer.output.\(rawValue)")
    }
}

enum ImageEditorPhotoFilterPreset: String, CaseIterable, Identifiable {
    case warming85
    case warming81
    case cooling80
    case cooling82
    case sepia
    case custom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.photoFilter.preset.\(rawValue)")
    }

    var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .warming85:
            return (1.0, 0.65, 0.30)
        case .warming81:
            return (0.96, 0.79, 0.48)
        case .cooling80:
            return (0.35, 0.58, 1.0)
        case .cooling82:
            return (0.55, 0.73, 1.0)
        case .sepia:
            return (0.78, 0.52, 0.28)
        case .custom:
            return (1.0, 0.65, 0.30)
        }
    }
}

enum ImageEditorColorLookupPreset: String, CaseIterable, Identifiable, Codable {
    case filmStock
    case crispWarm
    case tealOrange
    case bleachBypass
    case moonlight
    case customCube

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.colorLookup.preset.\(rawValue)")
    }
}

struct ImageEditorColorLookupCube: Equatable, Codable {
    var name: String = ""
    var dimension: Int = 0
    var values: [Double] = []

    var isValid: Bool {
        dimension >= 2 && values.count == dimension * dimension * dimension * 3
    }

    func normalized() -> ImageEditorColorLookupCube {
        let safeDimension = max(0, min(64, dimension))
        let expectedCount = safeDimension * safeDimension * safeDimension * 3
        guard safeDimension >= 2, values.count == expectedCount else {
            return ImageEditorColorLookupCube(name: name, dimension: 0, values: [])
        }
        return ImageEditorColorLookupCube(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dimension: safeDimension,
            values: values.map { max(0, min(1, $0)) }
        )
    }

    static func parse(_ text: String, fallbackName: String) -> ImageEditorColorLookupCube? {
        var title = fallbackName
        var dimension = 0
        var values: [Double] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine
                .components(separatedBy: "#")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !line.isEmpty else { continue }

            let parts = line.split { $0 == " " || $0 == "\t" }.map(String.init)
            guard let first = parts.first else { continue }
            let upper = first.uppercased()

            if upper == "TITLE" {
                let rawTitle = line.dropFirst(first.count).trimmingCharacters(in: .whitespacesAndNewlines)
                title = rawTitle.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                continue
            }
            if upper == "LUT_3D_SIZE", parts.count >= 2, let parsedDimension = Int(parts[1]) {
                dimension = parsedDimension
                continue
            }
            if upper.hasPrefix("LUT_") || upper.hasPrefix("DOMAIN_") {
                continue
            }
            guard parts.count >= 3,
                  let red = Double(parts[0]),
                  let green = Double(parts[1]),
                  let blue = Double(parts[2])
            else { continue }
            values.append(max(0, min(1, red)))
            values.append(max(0, min(1, green)))
            values.append(max(0, min(1, blue)))
        }

        let cube = ImageEditorColorLookupCube(name: title, dimension: dimension, values: values).normalized()
        return cube.isValid ? cube : nil
    }
}

enum ImageEditorGradientMapPreset: String, CaseIterable, Identifiable {
    case blackWhite
    case sepia
    case blueOrange
    case purpleTeal
    case custom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.gradientMap.preset.\(rawValue)")
    }
}

enum ImageEditorSelectiveColorRange: String, CaseIterable, Identifiable {
    case reds
    case yellows
    case greens
    case cyans
    case blues
    case magentas
    case whites
    case neutrals
    case blacks

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.selectiveColor.range.\(rawValue)")
    }
}

enum ImageEditorSelectiveColorComponent: String, CaseIterable, Identifiable {
    case cyan
    case magenta
    case yellow
    case black

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.selectiveColor.component.\(rawValue)")
    }
}

enum ImageEditorSelectiveColorMethod: String, CaseIterable, Identifiable {
    case relative
    case absolute

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.selectiveColor.method.\(rawValue)")
    }
}

struct ImageEditorSelectiveColorValues: Equatable, Codable {
    var cyan: Double = 0
    var magenta: Double = 0
    var yellow: Double = 0
    var black: Double = 0

    func normalized() -> ImageEditorSelectiveColorValues {
        ImageEditorSelectiveColorValues(
            cyan: Self.unit(cyan),
            magenta: Self.unit(magenta),
            yellow: Self.unit(yellow),
            black: Self.unit(black)
        )
    }

    private static func unit(_ value: Double) -> Double {
        max(-1, min(1, value))
    }
}

struct ImageEditorSelectiveColorSettings: Equatable, Codable {
    var reds = ImageEditorSelectiveColorValues()
    var yellows = ImageEditorSelectiveColorValues()
    var greens = ImageEditorSelectiveColorValues()
    var cyans = ImageEditorSelectiveColorValues()
    var blues = ImageEditorSelectiveColorValues()
    var magentas = ImageEditorSelectiveColorValues()
    var whites = ImageEditorSelectiveColorValues()
    var neutrals = ImageEditorSelectiveColorValues()
    var blacks = ImageEditorSelectiveColorValues()

    func values(for range: ImageEditorSelectiveColorRange) -> ImageEditorSelectiveColorValues {
        switch range {
        case .reds:
            return reds
        case .yellows:
            return yellows
        case .greens:
            return greens
        case .cyans:
            return cyans
        case .blues:
            return blues
        case .magentas:
            return magentas
        case .whites:
            return whites
        case .neutrals:
            return neutrals
        case .blacks:
            return blacks
        }
    }

    mutating func setValues(_ values: ImageEditorSelectiveColorValues, for range: ImageEditorSelectiveColorRange) {
        switch range {
        case .reds:
            reds = values
        case .yellows:
            yellows = values
        case .greens:
            greens = values
        case .cyans:
            cyans = values
        case .blues:
            blues = values
        case .magentas:
            magentas = values
        case .whites:
            whites = values
        case .neutrals:
            neutrals = values
        case .blacks:
            blacks = values
        }
    }

    func normalized() -> ImageEditorSelectiveColorSettings {
        ImageEditorSelectiveColorSettings(
            reds: reds.normalized(),
            yellows: yellows.normalized(),
            greens: greens.normalized(),
            cyans: cyans.normalized(),
            blues: blues.normalized(),
            magentas: magentas.normalized(),
            whites: whites.normalized(),
            neutrals: neutrals.normalized(),
            blacks: blacks.normalized()
        )
    }
}

struct ImageEditorAdjustmentSettings: Equatable, Codable {
    var levelsBlackPoint: Double = 0
    var levelsGamma: Double = 1
    var levelsWhitePoint: Double = 1
    var curvesShadows: Double = 0
    var curvesMidtones: Double = 0
    var curvesHighlights: Double = 0
    var colorBalanceShadowsCyanRed: Double = 0
    var colorBalanceShadowsMagentaGreen: Double = 0
    var colorBalanceShadowsYellowBlue: Double = 0
    var colorBalanceMidtonesCyanRed: Double = 0
    var colorBalanceMidtonesMagentaGreen: Double = 0
    var colorBalanceMidtonesYellowBlue: Double = 0
    var colorBalanceHighlightsCyanRed: Double = 0
    var colorBalanceHighlightsMagentaGreen: Double = 0
    var colorBalanceHighlightsYellowBlue: Double = 0
    var hueSaturationHue: Double = 0
    var hueSaturationSaturation: Double = 0
    var hueSaturationLightness: Double = 0
    var hueSaturationColorize: Bool = false
    var brightnessContrastBrightness: Double = 0
    var brightnessContrastContrast: Double = 0
    var exposureEV: Double = 0
    var exposureOffset: Double = 0
    var exposureGamma: Double = 1
    var shadowsHighlightsShadows: Double = 0
    var shadowsHighlightsHighlights: Double = 0
    var blackWhiteReds: Double = 0.40
    var blackWhiteYellows: Double = 0.60
    var blackWhiteGreens: Double = 0.40
    var blackWhiteCyans: Double = 0.60
    var blackWhiteBlues: Double = 0.20
    var blackWhiteMagentas: Double = 0.80
    var channelMixerRedRed: Double = 1
    var channelMixerRedGreen: Double = 0
    var channelMixerRedBlue: Double = 0
    var channelMixerRedConstant: Double = 0
    var channelMixerGreenRed: Double = 0
    var channelMixerGreenGreen: Double = 1
    var channelMixerGreenBlue: Double = 0
    var channelMixerGreenConstant: Double = 0
    var channelMixerBlueRed: Double = 0
    var channelMixerBlueGreen: Double = 0
    var channelMixerBlueBlue: Double = 1
    var channelMixerBlueConstant: Double = 0
    var channelMixerMonochrome: Bool = false
    var channelMixerMonoRed: Double = 0.40
    var channelMixerMonoGreen: Double = 0.40
    var channelMixerMonoBlue: Double = 0.20
    var channelMixerMonoConstant: Double = 0
    var photoFilterPreset: ImageEditorPhotoFilterPreset = .warming85
    var photoFilterDensity: Double = 0.25
    var photoFilterPreserveLuminosity: Bool = true
    var photoFilterCustomRed: Double = 1
    var photoFilterCustomGreen: Double = 0.65
    var photoFilterCustomBlue: Double = 0.30
    var colorLookupPreset: ImageEditorColorLookupPreset = .filmStock
    var colorLookupCube: ImageEditorColorLookupCube = ImageEditorColorLookupCube()
    var selectiveColorSettings = ImageEditorSelectiveColorSettings()
    var selectiveColorMethod: ImageEditorSelectiveColorMethod = .relative
    var gradientMapPreset: ImageEditorGradientMapPreset = .blackWhite
    var gradientMapReverse: Bool = false
    var gradientMapShadowRed: Double = 0
    var gradientMapShadowGreen: Double = 0
    var gradientMapShadowBlue: Double = 0
    var gradientMapHighlightRed: Double = 1
    var gradientMapHighlightGreen: Double = 1
    var gradientMapHighlightBlue: Double = 1

    func normalized() -> ImageEditorAdjustmentSettings {
        let black = max(0, min(0.98, levelsBlackPoint))
        let white = max(black + 0.01, min(1, levelsWhitePoint))
        let gamma = max(0.1, min(4, levelsGamma))
        return ImageEditorAdjustmentSettings(
            levelsBlackPoint: black,
            levelsGamma: gamma,
            levelsWhitePoint: white,
            curvesShadows: max(-1, min(1, curvesShadows)),
            curvesMidtones: max(-1, min(1, curvesMidtones)),
            curvesHighlights: max(-1, min(1, curvesHighlights)),
            colorBalanceShadowsCyanRed: Self.unit(colorBalanceShadowsCyanRed),
            colorBalanceShadowsMagentaGreen: Self.unit(colorBalanceShadowsMagentaGreen),
            colorBalanceShadowsYellowBlue: Self.unit(colorBalanceShadowsYellowBlue),
            colorBalanceMidtonesCyanRed: Self.unit(colorBalanceMidtonesCyanRed),
            colorBalanceMidtonesMagentaGreen: Self.unit(colorBalanceMidtonesMagentaGreen),
            colorBalanceMidtonesYellowBlue: Self.unit(colorBalanceMidtonesYellowBlue),
            colorBalanceHighlightsCyanRed: Self.unit(colorBalanceHighlightsCyanRed),
            colorBalanceHighlightsMagentaGreen: Self.unit(colorBalanceHighlightsMagentaGreen),
            colorBalanceHighlightsYellowBlue: Self.unit(colorBalanceHighlightsYellowBlue),
            hueSaturationHue: max(-180, min(180, hueSaturationHue)),
            hueSaturationSaturation: Self.unit(hueSaturationSaturation),
            hueSaturationLightness: Self.unit(hueSaturationLightness),
            hueSaturationColorize: hueSaturationColorize,
            brightnessContrastBrightness: Self.unit(brightnessContrastBrightness),
            brightnessContrastContrast: Self.unit(brightnessContrastContrast),
            exposureEV: max(-5, min(5, exposureEV)),
            exposureOffset: max(-0.5, min(0.5, exposureOffset)),
            exposureGamma: max(0.1, min(9.99, exposureGamma)),
            shadowsHighlightsShadows: Self.zeroOne(shadowsHighlightsShadows),
            shadowsHighlightsHighlights: Self.zeroOne(shadowsHighlightsHighlights),
            blackWhiteReds: Self.channelMix(blackWhiteReds),
            blackWhiteYellows: Self.channelMix(blackWhiteYellows),
            blackWhiteGreens: Self.channelMix(blackWhiteGreens),
            blackWhiteCyans: Self.channelMix(blackWhiteCyans),
            blackWhiteBlues: Self.channelMix(blackWhiteBlues),
            blackWhiteMagentas: Self.channelMix(blackWhiteMagentas),
            channelMixerRedRed: Self.mixerCoefficient(channelMixerRedRed),
            channelMixerRedGreen: Self.mixerCoefficient(channelMixerRedGreen),
            channelMixerRedBlue: Self.mixerCoefficient(channelMixerRedBlue),
            channelMixerRedConstant: Self.unit(channelMixerRedConstant),
            channelMixerGreenRed: Self.mixerCoefficient(channelMixerGreenRed),
            channelMixerGreenGreen: Self.mixerCoefficient(channelMixerGreenGreen),
            channelMixerGreenBlue: Self.mixerCoefficient(channelMixerGreenBlue),
            channelMixerGreenConstant: Self.unit(channelMixerGreenConstant),
            channelMixerBlueRed: Self.mixerCoefficient(channelMixerBlueRed),
            channelMixerBlueGreen: Self.mixerCoefficient(channelMixerBlueGreen),
            channelMixerBlueBlue: Self.mixerCoefficient(channelMixerBlueBlue),
            channelMixerBlueConstant: Self.unit(channelMixerBlueConstant),
            channelMixerMonochrome: channelMixerMonochrome,
            channelMixerMonoRed: Self.mixerCoefficient(channelMixerMonoRed),
            channelMixerMonoGreen: Self.mixerCoefficient(channelMixerMonoGreen),
            channelMixerMonoBlue: Self.mixerCoefficient(channelMixerMonoBlue),
            channelMixerMonoConstant: Self.unit(channelMixerMonoConstant),
            photoFilterPreset: photoFilterPreset,
            photoFilterDensity: max(0, min(1, photoFilterDensity)),
            photoFilterPreserveLuminosity: photoFilterPreserveLuminosity,
            photoFilterCustomRed: max(0, min(1, photoFilterCustomRed)),
            photoFilterCustomGreen: max(0, min(1, photoFilterCustomGreen)),
            photoFilterCustomBlue: max(0, min(1, photoFilterCustomBlue)),
            colorLookupPreset: colorLookupPreset,
            colorLookupCube: colorLookupCube.normalized(),
            selectiveColorSettings: selectiveColorSettings.normalized(),
            selectiveColorMethod: selectiveColorMethod,
            gradientMapPreset: gradientMapPreset,
            gradientMapReverse: gradientMapReverse,
            gradientMapShadowRed: Self.zeroOne(gradientMapShadowRed),
            gradientMapShadowGreen: Self.zeroOne(gradientMapShadowGreen),
            gradientMapShadowBlue: Self.zeroOne(gradientMapShadowBlue),
            gradientMapHighlightRed: Self.zeroOne(gradientMapHighlightRed),
            gradientMapHighlightGreen: Self.zeroOne(gradientMapHighlightGreen),
            gradientMapHighlightBlue: Self.zeroOne(gradientMapHighlightBlue)
        )
    }

    private static func unit(_ value: Double) -> Double {
        max(-1, min(1, value))
    }

    private static func channelMix(_ value: Double) -> Double {
        max(0, min(2, value))
    }

    private static func mixerCoefficient(_ value: Double) -> Double {
        max(-2, min(2, value))
    }

    private static func zeroOne(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}

extension ImageEditorAdjustmentSettings {
    private enum CodingKeys: String, CodingKey {
        case levelsBlackPoint
        case levelsGamma
        case levelsWhitePoint
        case curvesShadows
        case curvesMidtones
        case curvesHighlights
        case colorBalanceShadowsCyanRed
        case colorBalanceShadowsMagentaGreen
        case colorBalanceShadowsYellowBlue
        case colorBalanceMidtonesCyanRed
        case colorBalanceMidtonesMagentaGreen
        case colorBalanceMidtonesYellowBlue
        case colorBalanceHighlightsCyanRed
        case colorBalanceHighlightsMagentaGreen
        case colorBalanceHighlightsYellowBlue
        case hueSaturationHue
        case hueSaturationSaturation
        case hueSaturationLightness
        case hueSaturationColorize
        case brightnessContrastBrightness
        case brightnessContrastContrast
        case exposureEV
        case exposureOffset
        case exposureGamma
        case shadowsHighlightsShadows
        case shadowsHighlightsHighlights
        case blackWhiteReds
        case blackWhiteYellows
        case blackWhiteGreens
        case blackWhiteCyans
        case blackWhiteBlues
        case blackWhiteMagentas
        case channelMixerRedRed
        case channelMixerRedGreen
        case channelMixerRedBlue
        case channelMixerRedConstant
        case channelMixerGreenRed
        case channelMixerGreenGreen
        case channelMixerGreenBlue
        case channelMixerGreenConstant
        case channelMixerBlueRed
        case channelMixerBlueGreen
        case channelMixerBlueBlue
        case channelMixerBlueConstant
        case channelMixerMonochrome
        case channelMixerMonoRed
        case channelMixerMonoGreen
        case channelMixerMonoBlue
        case channelMixerMonoConstant
        case photoFilterPreset
        case photoFilterDensity
        case photoFilterPreserveLuminosity
        case photoFilterCustomRed
        case photoFilterCustomGreen
        case photoFilterCustomBlue
        case colorLookupPreset
        case colorLookupCube
        case selectiveColorSettings
        case selectiveColorMethod
        case gradientMapPreset
        case gradientMapReverse
        case gradientMapShadowRed
        case gradientMapShadowGreen
        case gradientMapShadowBlue
        case gradientMapHighlightRed
        case gradientMapHighlightGreen
        case gradientMapHighlightBlue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        levelsBlackPoint = try container.decodeIfPresent(Double.self, forKey: .levelsBlackPoint) ?? 0
        levelsGamma = try container.decodeIfPresent(Double.self, forKey: .levelsGamma) ?? 1
        levelsWhitePoint = try container.decodeIfPresent(Double.self, forKey: .levelsWhitePoint) ?? 1
        curvesShadows = try container.decodeIfPresent(Double.self, forKey: .curvesShadows) ?? 0
        curvesMidtones = try container.decodeIfPresent(Double.self, forKey: .curvesMidtones) ?? 0
        curvesHighlights = try container.decodeIfPresent(Double.self, forKey: .curvesHighlights) ?? 0
        colorBalanceShadowsCyanRed = try container.decodeIfPresent(Double.self, forKey: .colorBalanceShadowsCyanRed) ?? 0
        colorBalanceShadowsMagentaGreen = try container.decodeIfPresent(Double.self, forKey: .colorBalanceShadowsMagentaGreen) ?? 0
        colorBalanceShadowsYellowBlue = try container.decodeIfPresent(Double.self, forKey: .colorBalanceShadowsYellowBlue) ?? 0
        colorBalanceMidtonesCyanRed = try container.decodeIfPresent(Double.self, forKey: .colorBalanceMidtonesCyanRed) ?? 0
        colorBalanceMidtonesMagentaGreen = try container.decodeIfPresent(Double.self, forKey: .colorBalanceMidtonesMagentaGreen) ?? 0
        colorBalanceMidtonesYellowBlue = try container.decodeIfPresent(Double.self, forKey: .colorBalanceMidtonesYellowBlue) ?? 0
        colorBalanceHighlightsCyanRed = try container.decodeIfPresent(Double.self, forKey: .colorBalanceHighlightsCyanRed) ?? 0
        colorBalanceHighlightsMagentaGreen = try container.decodeIfPresent(Double.self, forKey: .colorBalanceHighlightsMagentaGreen) ?? 0
        colorBalanceHighlightsYellowBlue = try container.decodeIfPresent(Double.self, forKey: .colorBalanceHighlightsYellowBlue) ?? 0
        hueSaturationHue = try container.decodeIfPresent(Double.self, forKey: .hueSaturationHue) ?? 0
        hueSaturationSaturation = try container.decodeIfPresent(Double.self, forKey: .hueSaturationSaturation) ?? 0
        hueSaturationLightness = try container.decodeIfPresent(Double.self, forKey: .hueSaturationLightness) ?? 0
        hueSaturationColorize = try container.decodeIfPresent(Bool.self, forKey: .hueSaturationColorize) ?? false
        brightnessContrastBrightness = try container.decodeIfPresent(Double.self, forKey: .brightnessContrastBrightness) ?? 0
        brightnessContrastContrast = try container.decodeIfPresent(Double.self, forKey: .brightnessContrastContrast) ?? 0
        exposureEV = try container.decodeIfPresent(Double.self, forKey: .exposureEV) ?? 0
        exposureOffset = try container.decodeIfPresent(Double.self, forKey: .exposureOffset) ?? 0
        exposureGamma = try container.decodeIfPresent(Double.self, forKey: .exposureGamma) ?? 1
        shadowsHighlightsShadows = try container.decodeIfPresent(Double.self, forKey: .shadowsHighlightsShadows) ?? 0
        shadowsHighlightsHighlights = try container.decodeIfPresent(Double.self, forKey: .shadowsHighlightsHighlights) ?? 0
        blackWhiteReds = try container.decodeIfPresent(Double.self, forKey: .blackWhiteReds) ?? 0.40
        blackWhiteYellows = try container.decodeIfPresent(Double.self, forKey: .blackWhiteYellows) ?? 0.60
        blackWhiteGreens = try container.decodeIfPresent(Double.self, forKey: .blackWhiteGreens) ?? 0.40
        blackWhiteCyans = try container.decodeIfPresent(Double.self, forKey: .blackWhiteCyans) ?? 0.60
        blackWhiteBlues = try container.decodeIfPresent(Double.self, forKey: .blackWhiteBlues) ?? 0.20
        blackWhiteMagentas = try container.decodeIfPresent(Double.self, forKey: .blackWhiteMagentas) ?? 0.80
        channelMixerRedRed = try container.decodeIfPresent(Double.self, forKey: .channelMixerRedRed) ?? 1
        channelMixerRedGreen = try container.decodeIfPresent(Double.self, forKey: .channelMixerRedGreen) ?? 0
        channelMixerRedBlue = try container.decodeIfPresent(Double.self, forKey: .channelMixerRedBlue) ?? 0
        channelMixerRedConstant = try container.decodeIfPresent(Double.self, forKey: .channelMixerRedConstant) ?? 0
        channelMixerGreenRed = try container.decodeIfPresent(Double.self, forKey: .channelMixerGreenRed) ?? 0
        channelMixerGreenGreen = try container.decodeIfPresent(Double.self, forKey: .channelMixerGreenGreen) ?? 1
        channelMixerGreenBlue = try container.decodeIfPresent(Double.self, forKey: .channelMixerGreenBlue) ?? 0
        channelMixerGreenConstant = try container.decodeIfPresent(Double.self, forKey: .channelMixerGreenConstant) ?? 0
        channelMixerBlueRed = try container.decodeIfPresent(Double.self, forKey: .channelMixerBlueRed) ?? 0
        channelMixerBlueGreen = try container.decodeIfPresent(Double.self, forKey: .channelMixerBlueGreen) ?? 0
        channelMixerBlueBlue = try container.decodeIfPresent(Double.self, forKey: .channelMixerBlueBlue) ?? 1
        channelMixerBlueConstant = try container.decodeIfPresent(Double.self, forKey: .channelMixerBlueConstant) ?? 0
        channelMixerMonochrome = try container.decodeIfPresent(Bool.self, forKey: .channelMixerMonochrome) ?? false
        channelMixerMonoRed = try container.decodeIfPresent(Double.self, forKey: .channelMixerMonoRed) ?? 0.40
        channelMixerMonoGreen = try container.decodeIfPresent(Double.self, forKey: .channelMixerMonoGreen) ?? 0.40
        channelMixerMonoBlue = try container.decodeIfPresent(Double.self, forKey: .channelMixerMonoBlue) ?? 0.20
        channelMixerMonoConstant = try container.decodeIfPresent(Double.self, forKey: .channelMixerMonoConstant) ?? 0
        photoFilterPreset = try container.decodeIfPresent(ImageEditorPhotoFilterPreset.self, forKey: .photoFilterPreset) ?? .warming85
        photoFilterDensity = try container.decodeIfPresent(Double.self, forKey: .photoFilterDensity) ?? 0.25
        photoFilterPreserveLuminosity = try container.decodeIfPresent(Bool.self, forKey: .photoFilterPreserveLuminosity) ?? true
        photoFilterCustomRed = try container.decodeIfPresent(Double.self, forKey: .photoFilterCustomRed) ?? 1
        photoFilterCustomGreen = try container.decodeIfPresent(Double.self, forKey: .photoFilterCustomGreen) ?? 0.65
        photoFilterCustomBlue = try container.decodeIfPresent(Double.self, forKey: .photoFilterCustomBlue) ?? 0.30
        colorLookupPreset = try container.decodeIfPresent(ImageEditorColorLookupPreset.self, forKey: .colorLookupPreset) ?? .filmStock
        colorLookupCube = try container.decodeIfPresent(ImageEditorColorLookupCube.self, forKey: .colorLookupCube) ?? ImageEditorColorLookupCube()
        selectiveColorSettings = try container.decodeIfPresent(ImageEditorSelectiveColorSettings.self, forKey: .selectiveColorSettings) ?? ImageEditorSelectiveColorSettings()
        selectiveColorMethod = try container.decodeIfPresent(ImageEditorSelectiveColorMethod.self, forKey: .selectiveColorMethod) ?? .relative
        gradientMapPreset = try container.decodeIfPresent(ImageEditorGradientMapPreset.self, forKey: .gradientMapPreset) ?? .blackWhite
        gradientMapReverse = try container.decodeIfPresent(Bool.self, forKey: .gradientMapReverse) ?? false
        gradientMapShadowRed = try container.decodeIfPresent(Double.self, forKey: .gradientMapShadowRed) ?? 0
        gradientMapShadowGreen = try container.decodeIfPresent(Double.self, forKey: .gradientMapShadowGreen) ?? 0
        gradientMapShadowBlue = try container.decodeIfPresent(Double.self, forKey: .gradientMapShadowBlue) ?? 0
        gradientMapHighlightRed = try container.decodeIfPresent(Double.self, forKey: .gradientMapHighlightRed) ?? 1
        gradientMapHighlightGreen = try container.decodeIfPresent(Double.self, forKey: .gradientMapHighlightGreen) ?? 1
        gradientMapHighlightBlue = try container.decodeIfPresent(Double.self, forKey: .gradientMapHighlightBlue) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(levelsBlackPoint, forKey: .levelsBlackPoint)
        try container.encode(levelsGamma, forKey: .levelsGamma)
        try container.encode(levelsWhitePoint, forKey: .levelsWhitePoint)
        try container.encode(curvesShadows, forKey: .curvesShadows)
        try container.encode(curvesMidtones, forKey: .curvesMidtones)
        try container.encode(curvesHighlights, forKey: .curvesHighlights)
        try container.encode(colorBalanceShadowsCyanRed, forKey: .colorBalanceShadowsCyanRed)
        try container.encode(colorBalanceShadowsMagentaGreen, forKey: .colorBalanceShadowsMagentaGreen)
        try container.encode(colorBalanceShadowsYellowBlue, forKey: .colorBalanceShadowsYellowBlue)
        try container.encode(colorBalanceMidtonesCyanRed, forKey: .colorBalanceMidtonesCyanRed)
        try container.encode(colorBalanceMidtonesMagentaGreen, forKey: .colorBalanceMidtonesMagentaGreen)
        try container.encode(colorBalanceMidtonesYellowBlue, forKey: .colorBalanceMidtonesYellowBlue)
        try container.encode(colorBalanceHighlightsCyanRed, forKey: .colorBalanceHighlightsCyanRed)
        try container.encode(colorBalanceHighlightsMagentaGreen, forKey: .colorBalanceHighlightsMagentaGreen)
        try container.encode(colorBalanceHighlightsYellowBlue, forKey: .colorBalanceHighlightsYellowBlue)
        try container.encode(hueSaturationHue, forKey: .hueSaturationHue)
        try container.encode(hueSaturationSaturation, forKey: .hueSaturationSaturation)
        try container.encode(hueSaturationLightness, forKey: .hueSaturationLightness)
        try container.encode(hueSaturationColorize, forKey: .hueSaturationColorize)
        try container.encode(brightnessContrastBrightness, forKey: .brightnessContrastBrightness)
        try container.encode(brightnessContrastContrast, forKey: .brightnessContrastContrast)
        try container.encode(exposureEV, forKey: .exposureEV)
        try container.encode(exposureOffset, forKey: .exposureOffset)
        try container.encode(exposureGamma, forKey: .exposureGamma)
        try container.encode(shadowsHighlightsShadows, forKey: .shadowsHighlightsShadows)
        try container.encode(shadowsHighlightsHighlights, forKey: .shadowsHighlightsHighlights)
        try container.encode(blackWhiteReds, forKey: .blackWhiteReds)
        try container.encode(blackWhiteYellows, forKey: .blackWhiteYellows)
        try container.encode(blackWhiteGreens, forKey: .blackWhiteGreens)
        try container.encode(blackWhiteCyans, forKey: .blackWhiteCyans)
        try container.encode(blackWhiteBlues, forKey: .blackWhiteBlues)
        try container.encode(blackWhiteMagentas, forKey: .blackWhiteMagentas)
        try container.encode(channelMixerRedRed, forKey: .channelMixerRedRed)
        try container.encode(channelMixerRedGreen, forKey: .channelMixerRedGreen)
        try container.encode(channelMixerRedBlue, forKey: .channelMixerRedBlue)
        try container.encode(channelMixerRedConstant, forKey: .channelMixerRedConstant)
        try container.encode(channelMixerGreenRed, forKey: .channelMixerGreenRed)
        try container.encode(channelMixerGreenGreen, forKey: .channelMixerGreenGreen)
        try container.encode(channelMixerGreenBlue, forKey: .channelMixerGreenBlue)
        try container.encode(channelMixerGreenConstant, forKey: .channelMixerGreenConstant)
        try container.encode(channelMixerBlueRed, forKey: .channelMixerBlueRed)
        try container.encode(channelMixerBlueGreen, forKey: .channelMixerBlueGreen)
        try container.encode(channelMixerBlueBlue, forKey: .channelMixerBlueBlue)
        try container.encode(channelMixerBlueConstant, forKey: .channelMixerBlueConstant)
        try container.encode(channelMixerMonochrome, forKey: .channelMixerMonochrome)
        try container.encode(channelMixerMonoRed, forKey: .channelMixerMonoRed)
        try container.encode(channelMixerMonoGreen, forKey: .channelMixerMonoGreen)
        try container.encode(channelMixerMonoBlue, forKey: .channelMixerMonoBlue)
        try container.encode(channelMixerMonoConstant, forKey: .channelMixerMonoConstant)
        try container.encode(photoFilterPreset, forKey: .photoFilterPreset)
        try container.encode(photoFilterDensity, forKey: .photoFilterDensity)
        try container.encode(photoFilterPreserveLuminosity, forKey: .photoFilterPreserveLuminosity)
        try container.encode(photoFilterCustomRed, forKey: .photoFilterCustomRed)
        try container.encode(photoFilterCustomGreen, forKey: .photoFilterCustomGreen)
        try container.encode(photoFilterCustomBlue, forKey: .photoFilterCustomBlue)
        try container.encode(colorLookupPreset, forKey: .colorLookupPreset)
        try container.encode(colorLookupCube, forKey: .colorLookupCube)
        try container.encode(selectiveColorSettings, forKey: .selectiveColorSettings)
        try container.encode(selectiveColorMethod, forKey: .selectiveColorMethod)
        try container.encode(gradientMapPreset, forKey: .gradientMapPreset)
        try container.encode(gradientMapReverse, forKey: .gradientMapReverse)
        try container.encode(gradientMapShadowRed, forKey: .gradientMapShadowRed)
        try container.encode(gradientMapShadowGreen, forKey: .gradientMapShadowGreen)
        try container.encode(gradientMapShadowBlue, forKey: .gradientMapShadowBlue)
        try container.encode(gradientMapHighlightRed, forKey: .gradientMapHighlightRed)
        try container.encode(gradientMapHighlightGreen, forKey: .gradientMapHighlightGreen)
        try container.encode(gradientMapHighlightBlue, forKey: .gradientMapHighlightBlue)
    }
}

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

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.filter.\(rawValue)")
    }
}

struct ImageEditorSmartFilter: Identifiable, Equatable, Codable {
    var id = UUID()
    var kind: ImageEditorFilter
    var intensity: Double
    var settings = ImageEditorFilterSettings()
    var isEnabled = true

    var normalizedIntensity: Double {
        max(0, min(1, intensity))
    }

    var normalizedSettings: ImageEditorFilterSettings {
        settings.normalized()
    }
}

struct ImageEditorFilterSettings: Equatable, Codable {
    var unsharpRadius: Double = 1
    var unsharpThreshold: Double = 0

    func normalized() -> ImageEditorFilterSettings {
        ImageEditorFilterSettings(
            unsharpRadius: max(0.5, min(5, unsharpRadius)),
            unsharpThreshold: max(0, min(1, unsharpThreshold))
        )
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

    func tileImage(color: NSColor, opacity: CGFloat, scale: CGFloat) -> NSImage {
        let tileSize = max(6, min(64, scale))
        let size = CGSize(width: tileSize, height: tileSize)
        let patternColor = color.withAlphaComponent(max(0.05, min(1, opacity)))
        return NSImage.rendered(size: size) { rect in
            NSColor.clear.setFill()
            rect.fill()
            patternColor.setFill()
            patternColor.setStroke()
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

struct ImageEditorLayerStyle {
    var strokeEnabled = false
    var strokeColor = NSColor.white
    var strokeWidth: CGFloat = 3
    var strokePosition = ImageEditorStrokePosition.outside
    var strokeOpacity: CGFloat = 1
    var shadowEnabled = false
    var shadowColor = NSColor.black
    var shadowOpacity: CGFloat = 0.35
    var shadowBlur: CGFloat = 8
    var shadowSpread: CGFloat = 0
    var shadowDistance: CGFloat = 10
    var shadowAngle: CGFloat = -45
    var shadowUsesGlobalLight = true
    var shadowOffset = CGSize(width: 7, height: -7)
    var innerShadowEnabled = false
    var innerShadowColor = NSColor.black
    var innerShadowOpacity: CGFloat = 0.35
    var innerShadowBlur: CGFloat = 8
    var innerShadowDistance: CGFloat = 7
    var innerShadowAngle: CGFloat = -45
    var innerShadowUsesGlobalLight = true
    var outerGlowEnabled = false
    var outerGlowColor = NSColor.systemYellow
    var outerGlowOpacity: CGFloat = 0.42
    var outerGlowBlur: CGFloat = 10
    var outerGlowSpread: CGFloat = 3
    var innerGlowEnabled = false
    var innerGlowColor = NSColor.systemCyan
    var innerGlowOpacity: CGFloat = 0.36
    var innerGlowBlur: CGFloat = 8
    var innerGlowChoke: CGFloat = 2
    var colorOverlayEnabled = false
    var colorOverlayColor = NSColor.systemRed
    var colorOverlayOpacity: CGFloat = 0.55
    var gradientOverlayEnabled = false
    var gradientOverlayStartColor = NSColor.systemRed
    var gradientOverlayEndColor = NSColor.white
    var gradientOverlayOpacity: CGFloat = 0.55
    var gradientOverlayAngle: CGFloat = 0
    var patternOverlayEnabled = false
    var patternOverlayKind = ImageEditorPatternOverlayKind.checkerboard
    var patternOverlayColor = NSColor.white
    var patternOverlayOpacity: CGFloat = 0.45
    var patternOverlayScale: CGFloat = 14
    var satinEnabled = false
    var satinColor = NSColor.black
    var satinOpacity: CGFloat = 0.35
    var satinDistance: CGFloat = 8
    var satinSize: CGFloat = 6
    var satinAngle: CGFloat = 19
    var bevelEnabled = false
    var bevelHighlightColor = NSColor.white
    var bevelShadowColor = NSColor.black
    var bevelOpacity: CGFloat = 0.38
    var bevelSize: CGFloat = 4
    var bevelAngle: CGFloat = -45
    var bevelUsesGlobalLight = true

    var hasEffects: Bool {
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

    var padding: CGFloat {
        padding(globalLightAngle: nil)
    }

    func padding(globalLightAngle: CGFloat?) -> CGFloat {
        guard hasEffects else { return 0 }
        let strokePadding = strokeEnabled ? ceil(strokeWidth * strokePosition.paddingScale) : 0
        let effectiveShadowOffset = resolvedShadowOffset(globalLightAngle: globalLightAngle)
        let shadowPadding = shadowEnabled
            ? shadowBlur * 2 + shadowSpread + max(abs(effectiveShadowOffset.width), abs(effectiveShadowOffset.height))
            : 0
        let outerGlowPadding = outerGlowEnabled
            ? outerGlowBlur * 2 + outerGlowSpread
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
}

enum ImageEditorTextAlignment: String, CaseIterable, Identifiable {
    case left
    case center
    case right

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.textAlignment.\(rawValue)")
    }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left:
            return .left
        case .center:
            return .center
        case .right:
            return .right
        }
    }
}

struct ImageEditorTextContent {
    static let drawingPadding: CGFloat = 4

    var text: String
    var color: NSColor
    var fontSize: CGFloat
    var point: CGPoint
    var isBold = false
    var isItalic = false
    var characterSpacing: CGFloat = 0
    var lineSpacing: CGFloat = 0
    var boxWidth: CGFloat = 0
    var alignment: ImageEditorTextAlignment = .left

    var font: NSFont {
        let baseFont = NSFont.systemFont(ofSize: max(6, fontSize), weight: isBold ? .bold : .semibold)
        guard isItalic else { return baseFont }
        return NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
    }

    var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment.nsTextAlignment
        style.lineSpacing = max(0, lineSpacing)
        return style
    }

    var attributes: [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: color,
            .kern: characterSpacing,
            .paragraphStyle: paragraphStyle
        ]
    }

    var attributedString: NSAttributedString {
        NSAttributedString(string: text, attributes: attributes)
    }

    func layerSize() -> CGSize {
        let measured: CGSize
        if boxWidth > 0 {
            let bounding = attributedString.boundingRect(
                with: CGSize(width: max(1, boxWidth), height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            measured = CGSize(width: max(boxWidth, ceil(bounding.width)), height: ceil(bounding.height))
        } else {
            let lines = text.components(separatedBy: .newlines)
            let lineSizes = lines.map { (($0.isEmpty ? " " : $0) as NSString).size(withAttributes: attributes) }
            let width = lineSizes.map(\.width).max() ?? 1
            let height = lineSizes.reduce(CGFloat(0)) { partial, size in partial + size.height }
                + max(0, CGFloat(max(0, lines.count - 1)) * lineSpacing)
            measured = CGSize(width: ceil(width), height: ceil(height))
        }
        return CGSize(
            width: max(1, ceil(measured.width + Self.drawingPadding * 2)),
            height: max(1, ceil(measured.height + Self.drawingPadding * 2))
        )
    }

    func drawingRect(in size: CGSize) -> CGRect {
        CGRect(
            x: point.x,
            y: point.y,
            width: max(1, size.width - point.x - Self.drawingPadding),
            height: max(1, size.height - point.y - Self.drawingPadding)
        )
    }
}

enum ImageEditorShapeKind: String {
    case rectangle
    case ellipse
    case path

    var title: String {
        L10n.text("imageEditor.shape.\(rawValue)")
    }
}

enum ImageEditorPathControlRole {
    case anchor
    case inHandle
    case outHandle
}

struct ImageEditorPathAnchor: Equatable, Codable {
    var point: CGPoint
    var inControl: CGPoint?
    var outControl: CGPoint?

    func normalized(size: CGSize) -> ImageEditorPathAnchor {
        ImageEditorPathAnchor(
            point: point.clamped(to: size),
            inControl: inControl?.clamped(to: size),
            outControl: outControl?.clamped(to: size)
        )
    }
}

private extension CGPoint {
    func clamped(to size: CGSize) -> CGPoint {
        CGPoint(
            x: max(0, min(size.width, x)),
            y: max(0, min(size.height, y))
        )
    }
}

struct ImageEditorShapeContent {
    static let minimumStrokeWidth: CGFloat = 1

    var kind: ImageEditorShapeKind
    var fillColor: NSColor
    var fillOpacity: CGFloat
    var strokeColor: NSColor
    var strokeWidth: CGFloat
    var strokeOpacity: CGFloat
    var pathPoints: [CGPoint] = []
    var pathAnchors: [ImageEditorPathAnchor] = []
    var pathSubpaths: [[ImageEditorPathAnchor]] = []
    var isPathClosed = true

    func normalized(size: CGSize) -> ImageEditorShapeContent {
        var content = self
        content.fillOpacity = max(0, min(1, fillOpacity))
        content.strokeOpacity = max(0, min(1, strokeOpacity))
        if kind == .path {
            content.strokeWidth = max(Self.minimumStrokeWidth, min(96, strokeWidth))
        } else {
            content.strokeWidth = max(Self.minimumStrokeWidth, min(min(size.width, size.height) / 2, strokeWidth))
        }
        content.pathPoints = pathPoints.map { point in
            CGPoint(
                x: max(0, min(size.width, point.x)),
                y: max(0, min(size.height, point.y))
            )
        }
        if pathAnchors.isEmpty {
            content.pathAnchors = content.pathPoints.map { ImageEditorPathAnchor(point: $0) }
        } else {
            content.pathAnchors = pathAnchors.map { $0.normalized(size: size) }
            content.pathPoints = content.pathAnchors.map(\.point)
        }
        content.pathSubpaths = pathSubpaths.map { anchors in
            anchors.map { $0.normalized(size: size) }
        }.filter { $0.count >= 2 }
        return content
    }

    var editablePathAnchors: [ImageEditorPathAnchor] {
        if pathAnchors.isEmpty {
            return pathPoints.map { ImageEditorPathAnchor(point: $0) }
        }
        return pathAnchors
    }

    var editablePathSubpaths: [[ImageEditorPathAnchor]] {
        pathSubpaths.filter { !$0.isEmpty }
    }

    var allEditablePathSubpaths: [[ImageEditorPathAnchor]] {
        let primary = editablePathAnchors
        guard !primary.isEmpty else { return editablePathSubpaths }
        return [primary] + editablePathSubpaths
    }

    func renderedImage(size: CGSize) -> NSImage {
        let normalized = normalized(size: size)
        return NSImage.rendered(size: size) { rect in
            let path: NSBezierPath
            if normalized.kind == .path {
                path = normalized.pathBezierPath()
            } else {
                let inset = normalized.strokeWidth / 2
                let shapeRect = rect.insetBy(dx: inset, dy: inset)
                path = normalized.kind == .ellipse
                    ? NSBezierPath(ovalIn: shapeRect)
                    : NSBezierPath(rect: shapeRect)
            }
            if normalized.kind != .path || normalized.isPathClosed {
                normalized.fillColor.withAlphaComponent(normalized.fillOpacity).setFill()
                path.fill()
            }
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.lineWidth = normalized.strokeWidth
            normalized.strokeColor.withAlphaComponent(normalized.strokeOpacity).setStroke()
            path.stroke()
        } ?? NSImage.transparent(size: size)
    }

    func pathBezierPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.windingRule = .evenOdd
        let subpaths = allEditablePathSubpaths
        guard !subpaths.isEmpty else { return path }
        for anchors in subpaths {
            appendSubpath(anchors, to: path)
        }
        return path
    }

    private func appendSubpath(_ anchors: [ImageEditorPathAnchor], to path: NSBezierPath) {
        guard let first = anchors.first else { return }
        path.move(to: first.point)
        for index in anchors.indices.dropFirst() {
            let previous = anchors[index - 1]
            let current = anchors[index]
            if previous.outControl != nil || current.inControl != nil {
                path.curve(
                    to: current.point,
                    controlPoint1: previous.outControl ?? previous.point,
                    controlPoint2: current.inControl ?? current.point
                )
            } else {
                path.line(to: current.point)
            }
        }
        if isPathClosed, anchors.count > 2, let last = anchors.last {
            if last.outControl != nil || first.inControl != nil {
                path.curve(
                    to: first.point,
                    controlPoint1: last.outControl ?? last.point,
                    controlPoint2: first.inControl ?? first.point
                )
                path.close()
            } else {
                path.close()
            }
        }
    }
}

struct ImageEditorSmartObjectContent {
    var sourceName: String
    var originalSize: CGSize
    var sourceID = UUID()
}

enum ImageEditorLayerKind {
    case pixel
    case group
    case adjustment(ImageEditorAdjustment, Double)
    case filter(ImageEditorFilter, Double)
    case text(ImageEditorTextContent)
    case shape(ImageEditorShapeContent)
    case smartObject(ImageEditorSmartObjectContent)

    var isPixel: Bool {
        if case .pixel = self { return true }
        return false
    }
}

struct ImageEditorLayer: Identifiable {
    var id = UUID()
    var name: String
    var image: NSImage
    var mask: NSImage?
    var isMaskEnabled = true
    var isMaskLinked = true
    var maskDensity: Double = 1
    var maskFeather: Double = 0
    var vectorMask: ImageEditorShapeContent?
    var isVectorMaskEnabled = true
    var linkedLayerIDs: Set<UUID> = []
    var frame: CGRect
    var isVisible: Bool
    var opacity: Double
    var fillOpacity: Double = 1
    var blendIfSourceBlack: Double = 0
    var blendIfSourceWhite: Double = 1
    var blendIfUnderlyingBlack: Double = 0
    var blendIfUnderlyingWhite: Double = 1
    var blendMode: ImageEditorBlendMode
    var isLocked: Bool
    var locksPixels = false
    var locksPosition = false
    var locksTransparentPixels = false
    var style = ImageEditorLayerStyle()
    var kind: ImageEditorLayerKind = .pixel
    var smartFilters: [ImageEditorSmartFilter] = []
    var adjustmentSettings = ImageEditorAdjustmentSettings()
    var filterSettings = ImageEditorFilterSettings()
    var groupID: UUID?
    var isGroupExpanded = true
    var isClippingMask = false
    var labelColor: ImageEditorLayerLabelColor?

    static func background(image: NSImage) -> ImageEditorLayer {
        ImageEditorLayer(
            name: L10n.text("imageEditor.layer.background"),
            image: image,
            mask: nil,
            frame: CGRect(origin: .zero, size: image.size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: true
        )
    }

    static func blank(name: String, size: CGSize) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false
        )
    }

    static func group(name: String, size: CGSize) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .passThrough,
            isLocked: false,
            kind: .group
        )
    }

    static func adjustment(
        name: String,
        size: CGSize,
        kind: ImageEditorAdjustment,
        amount: Double,
        settings: ImageEditorAdjustmentSettings = ImageEditorAdjustmentSettings()
    ) -> ImageEditorLayer {
        var layer = ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .adjustment(kind, amount)
        )
        layer.adjustmentSettings = settings.normalized()
        return layer
    }

    static func filter(
        name: String,
        size: CGSize,
        kind: ImageEditorFilter,
        intensity: Double,
        settings: ImageEditorFilterSettings = ImageEditorFilterSettings()
    ) -> ImageEditorLayer {
        var layer = ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .filter(kind, intensity)
        )
        layer.filterSettings = settings.normalized()
        return layer
    }

    static func text(name: String, size: CGSize, content: ImageEditorTextContent) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .text(content)
        )
    }

    static func text(name: String, origin: CGPoint, content: ImageEditorTextContent) -> ImageEditorLayer {
        let layerSize = content.layerSize()
        return ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: layerSize),
            mask: nil,
            frame: CGRect(origin: origin, size: layerSize),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .text(content)
        )
    }

    static func shape(name: String, frame: CGRect, content: ImageEditorShapeContent) -> ImageEditorLayer {
        let size = CGSize(width: max(1, frame.width), height: max(1, frame.height))
        return ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: frame.origin, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .shape(content.normalized(size: size))
        )
    }

    static func smartObject(name: String, image: NSImage, sourceName: String) -> ImageEditorLayer {
        let normalized = image.normalizedBitmapImage()
        return ImageEditorLayer(
            name: name,
            image: normalized,
            mask: nil,
            frame: CGRect(origin: .zero, size: normalized.size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .smartObject(
                ImageEditorSmartObjectContent(
                    sourceName: sourceName,
                    originalSize: normalized.size
                )
            )
        )
    }

    var isGroup: Bool {
        if case .group = kind { return true }
        return false
    }

    var adjustment: (kind: ImageEditorAdjustment, amount: Double)? {
        guard case let .adjustment(adjustmentKind, amount) = kind else { return nil }
        return (adjustmentKind, amount)
    }

    var isAdjustment: Bool {
        adjustment != nil
    }

    var filter: (kind: ImageEditorFilter, intensity: Double)? {
        guard case let .filter(filterKind, intensity) = kind else { return nil }
        return (filterKind, intensity)
    }

    var isFilter: Bool {
        filter != nil
    }

    var textContent: ImageEditorTextContent? {
        guard case let .text(content) = kind else { return nil }
        return content
    }

    var isText: Bool {
        textContent != nil
    }

    var shapeContent: ImageEditorShapeContent? {
        guard case let .shape(content) = kind else { return nil }
        return content
    }

    var isShape: Bool {
        shapeContent != nil
    }

    var smartObjectContent: ImageEditorSmartObjectContent? {
        guard case let .smartObject(content) = kind else { return nil }
        return content
    }

    var isSmartObject: Bool {
        smartObjectContent != nil
    }

    func thumbnail(size: CGSize = CGSize(width: 44, height: 34)) -> NSImage {
        guard !isGroup else {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.18, alpha: 1).setFill()
                rect.fill()
                let folderRect = CGRect(
                    x: size.width * 0.18,
                    y: size.height * 0.23,
                    width: size.width * 0.64,
                    height: size.height * 0.5
                )
                let tabRect = CGRect(
                    x: folderRect.minX,
                    y: folderRect.maxY - 2,
                    width: folderRect.width * 0.42,
                    height: size.height * 0.18
                )
                NSColor(calibratedRed: 0.58, green: 0.67, blue: 0.78, alpha: 1).setFill()
                NSBezierPath(roundedRect: tabRect, xRadius: 3, yRadius: 3).fill()
                NSBezierPath(roundedRect: folderRect, xRadius: 4, yRadius: 4).fill()
            } ?? NSImage(size: size)
        }
        if let adjustment {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
                rect.fill()
                let inset = min(size.width, size.height) * 0.18
                let circleRect = rect.insetBy(dx: inset, dy: inset)
                NSColor(calibratedRed: 0.50, green: 0.67, blue: 0.96, alpha: 1).setFill()
                NSBezierPath(ovalIn: circleRect).fill()
                NSColor.white.withAlphaComponent(0.86).setStroke()
                let curve = NSBezierPath()
                curve.lineWidth = 2
                curve.move(to: CGPoint(x: circleRect.minX + circleRect.width * 0.18, y: circleRect.midY))
                curve.curve(
                    to: CGPoint(x: circleRect.maxX - circleRect.width * 0.18, y: circleRect.midY),
                    controlPoint1: CGPoint(x: circleRect.midX - 1, y: circleRect.maxY - circleRect.height * 0.38),
                    controlPoint2: CGPoint(x: circleRect.midX + 1, y: circleRect.minY + circleRect.height * 0.38)
                )
                curve.stroke()
                _ = adjustment
            } ?? NSImage(size: size)
        }
        if let filter {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
                rect.fill()
                let inset = min(size.width, size.height) * 0.2
                let boxRect = rect.insetBy(dx: inset, dy: inset)
                NSColor(calibratedRed: 0.62, green: 0.76, blue: 0.50, alpha: 1).setFill()
                NSBezierPath(roundedRect: boxRect, xRadius: 5, yRadius: 5).fill()
                NSColor.white.withAlphaComponent(0.88).setStroke()
                let line = NSBezierPath()
                line.lineWidth = 2
                line.move(to: CGPoint(x: boxRect.minX + 4, y: boxRect.midY))
                line.line(to: CGPoint(x: boxRect.maxX - 4, y: boxRect.midY))
                line.move(to: CGPoint(x: boxRect.midX, y: boxRect.minY + 4))
                line.line(to: CGPoint(x: boxRect.midX, y: boxRect.maxY - 4))
                line.stroke()
                _ = filter
            } ?? NSImage(size: size)
        }
        if textContent != nil {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
                rect.fill()
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: size.height * 0.62, weight: .bold),
                    .foregroundColor: NSColor.white.withAlphaComponent(0.9)
                ]
                let glyph = "T" as NSString
                let glyphSize = glyph.size(withAttributes: attributes)
                glyph.draw(
                    at: CGPoint(x: rect.midX - glyphSize.width / 2, y: rect.midY - glyphSize.height / 2),
                    withAttributes: attributes
                )
            } ?? NSImage(size: size)
        }
        if let shapeContent {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
                rect.fill()
                let inset = min(size.width, size.height) * 0.18
                let shapeRect = rect.insetBy(dx: inset, dy: inset)
                let path = shapeContent.kind == .ellipse
                    ? NSBezierPath(ovalIn: shapeRect)
                    : NSBezierPath(rect: shapeRect)
                shapeContent.fillColor.withAlphaComponent(0.86).setFill()
                path.fill()
                NSColor.white.withAlphaComponent(0.9).setStroke()
                path.lineWidth = 2
                path.stroke()
            } ?? NSImage(size: size)
        }
        if smartObjectContent != nil {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.14, alpha: 1).setFill()
                rect.fill()
                let inset = min(size.width, size.height) * 0.18
                let boxRect = rect.insetBy(dx: inset, dy: inset)
                NSColor(calibratedRed: 0.42, green: 0.66, blue: 0.95, alpha: 1).setFill()
                NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4).fill()
                NSColor.white.withAlphaComponent(0.9).setStroke()
                let innerRect = boxRect.insetBy(dx: boxRect.width * 0.2, dy: boxRect.height * 0.2)
                let path = NSBezierPath(rect: innerRect)
                path.lineWidth = 2
                path.stroke()
            } ?? NSImage(size: size)
        }
        return image.thumbnailImage(targetSize: size)
    }

    func maskThumbnail(size: CGSize = CGSize(width: 24, height: 24)) -> NSImage? {
        mask?.processedLayerMask(density: maskDensity, feather: maskFeather)?.thumbnailImage(targetSize: size)
    }

    func vectorMaskThumbnail(size: CGSize = CGSize(width: 24, height: 24)) -> NSImage? {
        vectorMaskImage()?.thumbnailImage(targetSize: size)
    }

    var effectiveMask: NSImage? {
        let rasterMask = isMaskEnabled ? mask?.processedLayerMask(density: maskDensity, feather: maskFeather) : nil
        let vectorMask = isVectorMaskEnabled ? vectorMaskImage() : nil
        switch (rasterMask, vectorMask) {
        case let (.some(rasterMask), .some(vectorMask)):
            return rasterMask.compositedWithAlphaMask(vectorMask)
        case let (.some(rasterMask), .none):
            return rasterMask
        case let (.none, .some(vectorMask)):
            return vectorMask
        case (.none, .none):
            return nil
        }
    }

    private func vectorMaskImage() -> NSImage? {
        guard let vectorMask,
              vectorMask.kind == .path,
              vectorMask.isPathClosed,
              vectorMask.editablePathAnchors.count >= 3
        else { return nil }
        return NSImage.rendered(size: image.size) { _ in
            NSColor.white.setFill()
            vectorMask.pathBezierPath().fill()
        }
    }

    var contentImage: NSImage {
        let baseImage: NSImage
        if let textContent {
            baseImage = NSImage.rendered(size: image.size) { _ in
                textContent.attributedString.draw(
                    with: textContent.drawingRect(in: image.size),
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                )
            } ?? image
        } else if let shapeContent {
            baseImage = shapeContent.renderedImage(size: image.size)
        } else {
            baseImage = image
        }
        return smartFilters.reduce(baseImage) { partial, filter in
            guard filter.isEnabled else { return partial }
            return partial.filtered(
                kind: filter.kind,
                intensity: filter.normalizedIntensity,
                settings: filter.normalizedSettings
            ) ?? partial
        }
    }

    var hasSmartFilters: Bool {
        !smartFilters.isEmpty
    }

    var visibleImage: NSImage {
        let sourceImage = contentImage
        guard let mask = effectiveMask else { return sourceImage }
        return NSImage.rendered(size: sourceImage.size) { _ in
            sourceImage.draw(
                in: CGRect(origin: .zero, size: sourceImage.size),
                from: CGRect(origin: .zero, size: sourceImage.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: sourceImage.size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        } ?? sourceImage
    }

    var hasLayerEffects: Bool {
        style.hasEffects
    }

    var compositingImage: NSImage {
        renderedCompositingImage(globalLightAngle: nil)
    }

    func renderedCompositingImage(globalLightAngle: CGFloat?) -> NSImage {
        let baseImage = visibleImage.applyingBlendIfSourceRange(
            black: blendIfSourceBlack,
            white: blendIfSourceWhite
        ) ?? visibleImage
        let normalizedFillOpacity = CGFloat(max(0, min(1, fillOpacity)))
        guard style.hasEffects else {
            guard normalizedFillOpacity < 1 else { return baseImage }
            return baseImage.withOpacity(normalizedFillOpacity) ?? baseImage
        }
        let padding = style.padding
        let outputSize = CGSize(
            width: baseImage.size.width + padding * 2,
            height: baseImage.size.height + padding * 2
        )
        let contentRect = CGRect(origin: CGPoint(x: padding, y: padding), size: baseImage.size)

        return NSImage.rendered(size: outputSize) { _ in
            if style.shadowEnabled {
                let spread = max(0, Int(style.shadowSpread.rounded()))
                let shadowOffset = style.resolvedShadowOffset(globalLightAngle: globalLightAngle)
                let shadowCanvas = NSImage.rendered(size: outputSize) { _ in
                    let shadowImage = baseImage.alphaTinted(
                        color: style.shadowColor.withAlphaComponent(style.shadowOpacity)
                    )
                    shadowImage.draw(
                        in: contentRect.offsetBy(dx: shadowOffset.width, dy: shadowOffset.height),
                        from: CGRect(origin: .zero, size: shadowImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    if spread > 0 {
                        let directions = 24
                        for radius in 1...spread {
                            for step in 0..<directions {
                                let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                                let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                                shadowImage.draw(
                                    in: contentRect.offsetBy(
                                        dx: shadowOffset.width + offset.width,
                                        dy: shadowOffset.height + offset.height
                                    ),
                                    from: CGRect(origin: .zero, size: shadowImage.size),
                                    operation: .sourceOver,
                                    fraction: 1
                                )
                            }
                        }
                    }
                } ?? NSImage(size: outputSize)
                let blurredShadow = shadowCanvas.blurred(radius: style.shadowBlur) ?? shadowCanvas
                blurredShadow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.strokeEnabled {
                let width = max(1, Int(style.strokeWidth.rounded()))
                let outsideWidth = style.strokePosition.outsideWidth(totalWidth: width)
                if outsideWidth > 0,
                   let outsideStroke = baseImage.outsideStrokeCanvas(
                       color: style.strokeColor.withAlphaComponent(style.strokeOpacity),
                       width: outsideWidth,
                       contentRect: contentRect,
                       outputSize: outputSize
                   ) {
                    outsideStroke.draw(
                        in: CGRect(origin: .zero, size: outputSize),
                        from: CGRect(origin: .zero, size: outputSize),
                        operation: .sourceOver,
                        fraction: 1
                    )
                }
            }

            if style.outerGlowEnabled {
                let glowImage = baseImage.alphaTinted(
                    color: style.outerGlowColor.withAlphaComponent(style.outerGlowOpacity)
                )
                let spread = max(0, Int(style.outerGlowSpread.rounded()))
                let glowCanvas = NSImage.rendered(size: outputSize) { _ in
                    glowImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: glowImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    if spread > 0 {
                        let directions = 24
                        for radius in 1...spread {
                            for step in 0..<directions {
                                let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                                let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                                glowImage.draw(
                                    in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                                    from: CGRect(origin: .zero, size: glowImage.size),
                                    operation: .sourceOver,
                                    fraction: 1
                                )
                            }
                        }
                    }
                } ?? NSImage(size: outputSize)
                let blurredGlow = glowCanvas.blurred(radius: style.outerGlowBlur) ?? glowCanvas
                blurredGlow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            // Fill opacity fades only layer pixels; effects keep using the original alpha mask.
            baseImage.draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: baseImage.size),
                operation: .sourceOver,
                fraction: normalizedFillOpacity
            )

            if style.strokeEnabled {
                let width = max(1, Int(style.strokeWidth.rounded()))
                let insideWidth = style.strokePosition.insideWidth(totalWidth: width)
                if insideWidth > 0,
                   let insideStroke = baseImage.insideStrokeCanvas(
                       color: style.strokeColor.withAlphaComponent(style.strokeOpacity),
                       width: insideWidth,
                       contentRect: contentRect,
                       outputSize: outputSize
                   ) {
                    insideStroke.draw(
                        in: CGRect(origin: .zero, size: outputSize),
                        from: CGRect(origin: .zero, size: outputSize),
                        operation: .sourceOver,
                        fraction: 1
                    )
                }
            }

            if style.innerShadowEnabled {
                let radians = style.resolvedInnerShadowAngle(globalLightAngle: globalLightAngle) * .pi / 180
                let distance = max(0, style.innerShadowDistance)
                let offset = CGSize(width: cos(radians) * distance, height: sin(radians) * distance)
                let innerShadowImage = baseImage.alphaTinted(
                    color: style.innerShadowColor.withAlphaComponent(style.innerShadowOpacity)
                )
                let innerShadowCanvas = NSImage.rendered(size: outputSize) { _ in
                    innerShadowImage.draw(
                        in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                        from: CGRect(origin: .zero, size: innerShadowImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                let softenedInnerShadow = innerShadowCanvas.blurred(radius: style.innerShadowBlur) ?? innerShadowCanvas
                softenedInnerShadow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .multiply,
                    fraction: 1
                )
            }

            if style.colorOverlayEnabled {
                let overlayImage = baseImage.alphaTinted(
                    color: style.colorOverlayColor.withAlphaComponent(style.colorOverlayOpacity)
                )
                overlayImage.draw(
                    in: contentRect,
                    from: CGRect(origin: .zero, size: overlayImage.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.gradientOverlayEnabled,
               let gradient = NSGradient(colors: [
                   style.gradientOverlayStartColor.withAlphaComponent(style.gradientOverlayOpacity),
                   style.gradientOverlayEndColor.withAlphaComponent(style.gradientOverlayOpacity)
               ]) {
                let gradientCanvas = NSImage.rendered(size: outputSize) { _ in
                    gradient.draw(in: contentRect, angle: style.gradientOverlayAngle)
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                gradientCanvas.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.patternOverlayEnabled {
                let patternImage = style.patternOverlayKind.tileImage(
                    color: style.patternOverlayColor,
                    opacity: style.patternOverlayOpacity,
                    scale: style.patternOverlayScale
                )
                let patternCanvas = NSImage.rendered(size: outputSize) { _ in
                    NSColor(patternImage: patternImage).setFill()
                    contentRect.fill()
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                patternCanvas.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.satinEnabled {
                let radians = style.satinAngle * .pi / 180
                let distance = max(1, style.satinDistance)
                let offset = CGSize(width: cos(radians) * distance, height: sin(radians) * distance)
                let satinImage = baseImage.alphaTinted(
                    color: style.satinColor.withAlphaComponent(style.satinOpacity)
                )
                let satinCanvas = NSImage.rendered(size: outputSize) { _ in
                    satinImage.draw(
                        in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                        from: CGRect(origin: .zero, size: satinImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    satinImage.draw(
                        in: contentRect.offsetBy(dx: -offset.width, dy: -offset.height),
                        from: CGRect(origin: .zero, size: satinImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                let softenedSatin = satinCanvas.blurred(radius: style.satinSize) ?? satinCanvas
                softenedSatin.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .multiply,
                    fraction: 1
                )
            }

            if style.bevelEnabled {
                let bevelDistance = max(1, Int(style.bevelSize.rounded()))
                let bevelOffset = ImageEditorLayerStyle.shadowOffset(
                    distance: CGFloat(bevelDistance),
                    angle: style.resolvedBevelAngle(globalLightAngle: globalLightAngle)
                )
                let highlightImage = baseImage.alphaTinted(
                    color: style.bevelHighlightColor.withAlphaComponent(style.bevelOpacity)
                )
                let shadowImage = baseImage.alphaTinted(
                    color: style.bevelShadowColor.withAlphaComponent(style.bevelOpacity)
                )
                let bevelCanvas = NSImage.rendered(size: outputSize) { _ in
                    highlightImage.draw(
                        in: contentRect.offsetBy(dx: -bevelOffset.width, dy: -bevelOffset.height),
                        from: CGRect(origin: .zero, size: highlightImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    shadowImage.draw(
                        in: contentRect.offsetBy(dx: bevelOffset.width, dy: bevelOffset.height),
                        from: CGRect(origin: .zero, size: shadowImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                bevelCanvas.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.innerGlowEnabled {
                let innerGlowImage = baseImage.alphaTinted(
                    color: style.innerGlowColor.withAlphaComponent(style.innerGlowOpacity)
                )
                let choke = max(0, Int(style.innerGlowChoke.rounded()))
                let innerGlowCanvas = NSImage.rendered(size: outputSize) { _ in
                    innerGlowImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: innerGlowImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    if choke > 0 {
                        let directions = 24
                        for radius in 1...choke {
                            for step in 0..<directions {
                                let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                                let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                                innerGlowImage.draw(
                                    in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                                    from: CGRect(origin: .zero, size: innerGlowImage.size),
                                    operation: .sourceOver,
                                    fraction: 1
                                )
                            }
                        }
                    }
                } ?? NSImage(size: outputSize)
                let blurredInnerGlow = innerGlowCanvas.blurred(radius: style.innerGlowBlur) ?? innerGlowCanvas
                blurredInnerGlow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .sourceOver,
                    fraction: 1
                )
                baseImage.draw(
                    in: contentRect,
                    from: CGRect(origin: .zero, size: baseImage.size),
                    operation: .destinationIn,
                    fraction: 1
                )
            }
        } ?? visibleImage
    }

    var compositingFrame: CGRect {
        renderedCompositingFrame(globalLightAngle: nil)
    }

    func renderedCompositingFrame(globalLightAngle: CGFloat?) -> CGRect {
        guard style.hasEffects else { return frame }
        let padding = style.padding(globalLightAngle: globalLightAngle)
        let imageSize = max(image.size.width, 1)
        let imageHeight = max(image.size.height, 1)
        let scaleX = frame.width / imageSize
        let scaleY = frame.height / imageHeight
        return CGRect(
            x: frame.minX - padding * scaleX,
            y: frame.minY - padding * scaleY,
            width: frame.width + padding * 2 * scaleX,
            height: frame.height + padding * 2 * scaleY
        )
    }
}

enum ImageEditorLayerDropPlacement: Equatable {
    case above
    case below
    case insideGroup
}

struct ImageEditorLayerDropTarget: Equatable {
    var layerID: UUID
    var placement: ImageEditorLayerDropPlacement
}

enum ImageEditorLayerLabelColor: String, CaseIterable, Identifiable, Codable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case gray

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.layer.label.\(rawValue)")
    }
}

enum ImageEditorLayerKindFilter: String, CaseIterable, Identifiable {
    case all
    case pixel
    case text
    case shape
    case adjustment
    case filter
    case smartObject
    case group

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.layer.kindFilter.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .pixel:
            return "photo"
        case .text:
            return "textformat"
        case .shape:
            return "square.on.circle"
        case .adjustment:
            return "circle.lefthalf.filled"
        case .filter:
            return "sparkles"
        case .smartObject:
            return "cube"
        case .group:
            return "folder"
        }
    }

    func matches(_ layer: ImageEditorLayer) -> Bool {
        switch self {
        case .all:
            return true
        case .pixel:
            return layer.kind.isPixel
        case .text:
            return layer.isText
        case .shape:
            return layer.isShape
        case .adjustment:
            return layer.isAdjustment
        case .filter:
            return layer.isFilter
        case .smartObject:
            return layer.isSmartObject
        case .group:
            return layer.isGroup
        }
    }
}

enum ImageEditorLayerStateFilter: String, CaseIterable, Identifiable {
    case all
    case visible
    case hidden
    case locked
    case unlocked

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.layer.stateFilter.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .all:
            return "circle.grid.2x2"
        case .visible:
            return "eye"
        case .hidden:
            return "eye.slash"
        case .locked:
            return "lock"
        case .unlocked:
            return "lock.open"
        }
    }
}

enum ImageEditorLayerAttributeFilter: String, CaseIterable, Identifiable {
    case all
    case masked
    case styled
    case clipping
    case linked
    case smartFiltered

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.layer.attributeFilter.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .all:
            return "slider.horizontal.3"
        case .masked:
            return "circle.dashed"
        case .styled:
            return "f.cursive"
        case .clipping:
            return "arrow.down.to.line.compact"
        case .linked:
            return "link"
        case .smartFiltered:
            return "camera.filters"
        }
    }

    func matches(_ layer: ImageEditorLayer) -> Bool {
        switch self {
        case .all:
            return true
        case .masked:
            return layer.mask != nil || layer.vectorMask != nil
        case .styled:
            return layer.style.hasEffects
        case .clipping:
            return layer.isClippingMask
        case .linked:
            return !layer.linkedLayerIDs.isEmpty
        case .smartFiltered:
            return !layer.smartFilters.isEmpty
        }
    }
}

struct ImageEditorHistoryEntry: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let createdAt = Date()
}

struct ImageEditorHistorySnapshot: Identifiable {
    var id = UUID()
    var name: String
    let createdAt = Date()
    var document: ImageEditorDocument
}

struct ImageEditorLayerCompLayerState: Equatable, Codable {
    var layerID: UUID
    var isVisible: Bool
    var frame: CGRect
    var opacity: Double
    var fillOpacity: Double
    var isMaskLinked: Bool
    var blendIfSourceBlack: Double
    var blendIfSourceWhite: Double
    var blendIfUnderlyingBlack: Double
    var blendIfUnderlyingWhite: Double
    var isMaskEnabled: Bool
    var maskDensity: Double
    var maskFeather: Double
    var hasMaskSnapshot: Bool
    var maskData: Data?
    var isVectorMaskEnabled: Bool
    var style: ImageEditorProjectLayerStyle
    var blendMode: ImageEditorBlendMode
    var kind: ImageEditorProjectLayerKind?
    var smartFilters: [ImageEditorSmartFilter]?
    var adjustmentSettings: ImageEditorAdjustmentSettings?
    var filterSettings: ImageEditorFilterSettings?
    var hasVectorMaskSnapshot: Bool
    var vectorMask: ImageEditorProjectShapeContent?
    var linkedLayerIDs: Set<UUID>
    var groupID: UUID?
    var isLocked: Bool
    var locksPixels: Bool
    var locksPosition: Bool
    var locksTransparentPixels: Bool
    var isGroupExpanded: Bool
    var isClippingMask: Bool
    var labelColor: ImageEditorLayerLabelColor?

    enum CodingKeys: String, CodingKey {
        case layerID
        case isVisible
        case frame
        case opacity
        case fillOpacity
        case isMaskLinked
        case blendIfSourceBlack
        case blendIfSourceWhite
        case blendIfUnderlyingBlack
        case blendIfUnderlyingWhite
        case isMaskEnabled
        case maskDensity
        case maskFeather
        case hasMaskSnapshot
        case maskData
        case isVectorMaskEnabled
        case style
        case blendMode
        case kind
        case smartFilters
        case adjustmentSettings
        case filterSettings
        case hasVectorMaskSnapshot
        case vectorMask
        case linkedLayerIDs
        case groupID
        case isLocked
        case locksPixels
        case locksPosition
        case locksTransparentPixels
        case isGroupExpanded
        case isClippingMask
        case labelColor
    }

    init(
        layerID: UUID,
        isVisible: Bool,
        frame: CGRect,
        opacity: Double,
        fillOpacity: Double,
        isMaskLinked: Bool,
        blendIfSourceBlack: Double,
        blendIfSourceWhite: Double,
        blendIfUnderlyingBlack: Double,
        blendIfUnderlyingWhite: Double,
        isMaskEnabled: Bool,
        maskDensity: Double,
        maskFeather: Double,
        hasMaskSnapshot: Bool = false,
        maskData: Data? = nil,
        isVectorMaskEnabled: Bool,
        style: ImageEditorProjectLayerStyle,
        blendMode: ImageEditorBlendMode,
        kind: ImageEditorProjectLayerKind? = nil,
        smartFilters: [ImageEditorSmartFilter]? = nil,
        adjustmentSettings: ImageEditorAdjustmentSettings? = nil,
        filterSettings: ImageEditorFilterSettings? = nil,
        hasVectorMaskSnapshot: Bool = false,
        vectorMask: ImageEditorProjectShapeContent? = nil,
        linkedLayerIDs: Set<UUID>,
        groupID: UUID?,
        isLocked: Bool,
        locksPixels: Bool,
        locksPosition: Bool,
        locksTransparentPixels: Bool,
        isGroupExpanded: Bool,
        isClippingMask: Bool,
        labelColor: ImageEditorLayerLabelColor? = nil
    ) {
        self.layerID = layerID
        self.isVisible = isVisible
        self.frame = frame
        self.opacity = opacity
        self.fillOpacity = fillOpacity
        self.isMaskLinked = isMaskLinked
        self.blendIfSourceBlack = blendIfSourceBlack
        self.blendIfSourceWhite = blendIfSourceWhite
        self.blendIfUnderlyingBlack = blendIfUnderlyingBlack
        self.blendIfUnderlyingWhite = blendIfUnderlyingWhite
        self.isMaskEnabled = isMaskEnabled
        self.maskDensity = maskDensity
        self.maskFeather = maskFeather
        self.hasMaskSnapshot = hasMaskSnapshot
        self.maskData = maskData
        self.isVectorMaskEnabled = isVectorMaskEnabled
        self.style = style
        self.blendMode = blendMode
        self.kind = kind
        self.smartFilters = smartFilters
        self.adjustmentSettings = adjustmentSettings
        self.filterSettings = filterSettings
        self.hasVectorMaskSnapshot = hasVectorMaskSnapshot
        self.vectorMask = vectorMask
        self.linkedLayerIDs = linkedLayerIDs
        self.groupID = groupID
        self.isLocked = isLocked
        self.locksPixels = locksPixels
        self.locksPosition = locksPosition
        self.locksTransparentPixels = locksTransparentPixels
        self.isGroupExpanded = isGroupExpanded
        self.isClippingMask = isClippingMask
        self.labelColor = labelColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layerID = try container.decode(UUID.self, forKey: .layerID)
        isVisible = try container.decode(Bool.self, forKey: .isVisible)
        frame = try container.decode(CGRect.self, forKey: .frame)
        opacity = try container.decode(Double.self, forKey: .opacity)
        fillOpacity = try container.decodeIfPresent(Double.self, forKey: .fillOpacity) ?? 1
        isMaskLinked = try container.decodeIfPresent(Bool.self, forKey: .isMaskLinked) ?? true
        blendIfSourceBlack = try container.decodeIfPresent(Double.self, forKey: .blendIfSourceBlack) ?? 0
        blendIfSourceWhite = try container.decodeIfPresent(Double.self, forKey: .blendIfSourceWhite) ?? 1
        blendIfUnderlyingBlack = try container.decodeIfPresent(Double.self, forKey: .blendIfUnderlyingBlack) ?? 0
        blendIfUnderlyingWhite = try container.decodeIfPresent(Double.self, forKey: .blendIfUnderlyingWhite) ?? 1
        isMaskEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMaskEnabled) ?? true
        maskDensity = try container.decodeIfPresent(Double.self, forKey: .maskDensity) ?? 1
        maskFeather = try container.decodeIfPresent(Double.self, forKey: .maskFeather) ?? 0
        hasMaskSnapshot = try container.decodeIfPresent(Bool.self, forKey: .hasMaskSnapshot) ?? false
        maskData = try container.decodeIfPresent(Data.self, forKey: .maskData)
        isVectorMaskEnabled = try container.decodeIfPresent(Bool.self, forKey: .isVectorMaskEnabled) ?? true
        style = try container.decodeIfPresent(ImageEditorProjectLayerStyle.self, forKey: .style)
            ?? ImageEditorProjectLayerStyle(style: ImageEditorLayerStyle())
        blendMode = try container.decode(ImageEditorBlendMode.self, forKey: .blendMode)
        kind = try container.decodeIfPresent(ImageEditorProjectLayerKind.self, forKey: .kind)
        smartFilters = try container.decodeIfPresent([ImageEditorSmartFilter].self, forKey: .smartFilters)
        adjustmentSettings = try container.decodeIfPresent(ImageEditorAdjustmentSettings.self, forKey: .adjustmentSettings)
        filterSettings = try container.decodeIfPresent(ImageEditorFilterSettings.self, forKey: .filterSettings)
        hasVectorMaskSnapshot = try container.decodeIfPresent(Bool.self, forKey: .hasVectorMaskSnapshot) ?? false
        vectorMask = try container.decodeIfPresent(ImageEditorProjectShapeContent.self, forKey: .vectorMask)
        linkedLayerIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .linkedLayerIDs) ?? []
        groupID = try container.decodeIfPresent(UUID.self, forKey: .groupID)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        locksPixels = try container.decodeIfPresent(Bool.self, forKey: .locksPixels) ?? false
        locksPosition = try container.decodeIfPresent(Bool.self, forKey: .locksPosition) ?? false
        locksTransparentPixels = try container.decodeIfPresent(Bool.self, forKey: .locksTransparentPixels) ?? false
        isGroupExpanded = try container.decodeIfPresent(Bool.self, forKey: .isGroupExpanded) ?? true
        isClippingMask = try container.decodeIfPresent(Bool.self, forKey: .isClippingMask) ?? false
        labelColor = try container.decodeIfPresent(ImageEditorLayerLabelColor.self, forKey: .labelColor)
    }
}

struct ImageEditorLayerComp: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var layerOrder: [UUID]
    var layerStates: [ImageEditorLayerCompLayerState]
    var selectedLayerID: UUID?
    var selectedLayerIDs: Set<UUID>
    var createdAt = Date()

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case layerOrder
        case layerStates
        case selectedLayerID
        case selectedLayerIDs
        case createdAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        layerOrder: [UUID],
        layerStates: [ImageEditorLayerCompLayerState],
        selectedLayerID: UUID?,
        selectedLayerIDs: Set<UUID>,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.layerOrder = layerOrder
        self.layerStates = layerStates
        self.selectedLayerID = selectedLayerID
        self.selectedLayerIDs = selectedLayerIDs
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        layerStates = try container.decode([ImageEditorLayerCompLayerState].self, forKey: .layerStates)
        layerOrder = try container.decodeIfPresent([UUID].self, forKey: .layerOrder)
            ?? layerStates.map(\.layerID)
        selectedLayerID = try container.decodeIfPresent(UUID.self, forKey: .selectedLayerID)
        selectedLayerIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .selectedLayerIDs) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    static func capture(name: String, document: ImageEditorDocument) -> ImageEditorLayerComp {
        ImageEditorLayerComp(
            name: name,
            layerOrder: document.layers.map(\.id),
            layerStates: document.layers.map { layer in
                ImageEditorLayerCompLayerState(
                    layerID: layer.id,
                    isVisible: layer.isVisible,
                    frame: layer.frame,
                    opacity: layer.opacity,
                    fillOpacity: layer.fillOpacity,
                    isMaskLinked: layer.isMaskLinked,
                    blendIfSourceBlack: layer.blendIfSourceBlack,
                    blendIfSourceWhite: layer.blendIfSourceWhite,
                    blendIfUnderlyingBlack: layer.blendIfUnderlyingBlack,
                    blendIfUnderlyingWhite: layer.blendIfUnderlyingWhite,
                    isMaskEnabled: layer.isMaskEnabled,
                    maskDensity: layer.maskDensity,
                    maskFeather: layer.maskFeather,
                    hasMaskSnapshot: true,
                    maskData: layer.mask?.qingtuPNGData(),
                    isVectorMaskEnabled: layer.isVectorMaskEnabled,
                    style: ImageEditorProjectLayerStyle(style: layer.style),
                    blendMode: layer.blendMode,
                    kind: ImageEditorProjectLayerKind(kind: layer.kind),
                    smartFilters: layer.smartFilters,
                    adjustmentSettings: layer.adjustmentSettings,
                    filterSettings: layer.filterSettings,
                    hasVectorMaskSnapshot: true,
                    vectorMask: layer.vectorMask.map(ImageEditorProjectShapeContent.init(content:)),
                    linkedLayerIDs: layer.linkedLayerIDs,
                    groupID: layer.groupID,
                    isLocked: layer.isLocked,
                    locksPixels: layer.locksPixels,
                    locksPosition: layer.locksPosition,
                    locksTransparentPixels: layer.locksTransparentPixels,
                    isGroupExpanded: layer.isGroupExpanded,
                    isClippingMask: layer.isClippingMask,
                    labelColor: layer.labelColor
                )
            },
            selectedLayerID: document.selectedLayerID,
            selectedLayerIDs: document.selectedLayerIDs
        )
    }
}

enum ImageEditorGuideOrientation: String, CaseIterable, Identifiable, Codable {
    case horizontal
    case vertical

    var id: String { rawValue }
}

struct ImageEditorGuide: Identifiable, Equatable, Codable {
    var id = UUID()
    var orientation: ImageEditorGuideOrientation
    var position: CGFloat
}

struct ImageEditorDocument {
    let sourceName: String
    var canvasSize: CGSize
    var layers: [ImageEditorLayer]
    var selectedLayerID: UUID?
    var selectedLayerIDs: Set<UUID>
    var selection: ImageEditorSelection?
    var savedSelection: ImageEditorSelection?
    var alphaChannels: [ImageEditorAlphaChannel]
    var layerComps: [ImageEditorLayerComp]
    var selectedLayerCompID: UUID?
    var guides: [ImageEditorGuide]
    var areGuidesVisible: Bool
    var areRulersVisible: Bool
    var isGuideSnappingEnabled: Bool
    var isGridVisible: Bool
    var isGridSnappingEnabled: Bool
    var gridSpacing: CGFloat
    var globalLightAngle: CGFloat
    var history: [ImageEditorHistoryEntry]

    init(sourceName: String, image: NSImage) {
        let normalized = image.normalizedBitmapImage()
        self.sourceName = sourceName
        canvasSize = normalized.size
        let editLayer = ImageEditorLayer.blank(name: L10n.text("imageEditor.layer.edit"), size: normalized.size)
        self.layers = [
            .background(image: normalized),
            editLayer
        ]
        selectedLayerID = editLayer.id
        selectedLayerIDs = [editLayer.id]
        selection = nil
        savedSelection = nil
        alphaChannels = []
        layerComps = []
        selectedLayerCompID = nil
        guides = []
        areGuidesVisible = true
        areRulersVisible = true
        isGuideSnappingEnabled = true
        isGridVisible = false
        isGridSnappingEnabled = false
        gridSpacing = 32
        globalLightAngle = -45
        self.history = [
            ImageEditorHistoryEntry(title: L10n.text("imageEditor.history.open"))
        ]
    }

    var selectedLayerIndex: Int? {
        guard let selectedLayerID else { return nil }
        return layers.firstIndex { $0.id == selectedLayerID }
    }

    var selectedLayer: ImageEditorLayer? {
        guard let selectedLayerIndex else { return nil }
        return layers[selectedLayerIndex]
    }

    var compositedImage: NSImage {
        compositedImage(includingOnly: nil)
    }

    func compositedImage(includingOnly includedLayerIDs: Set<UUID>) -> NSImage {
        compositedImage(includingOnly: Optional(includedLayerIDs))
    }

    private func compositedImage(includingOnly includedLayerIDs: Set<UUID>?) -> NSImage {
        var canvas = NSImage.transparent(size: canvasSize)
        for index in layers.indices {
            let layer = layers[index]
            if layer.isGroup {
                guard shouldRenderIsolatedGroup(layer, includedIn: includedLayerIDs),
                      isolatedGroupAncestor(for: layer) == nil
                else { continue }
                let groupCanvas = isolatedGroupCanvas(for: layer, includedLayerIDs: includedLayerIDs)
                let groupMask = combinedCanvasMask(layer.effectiveMask, effectiveGroupMask(for: layer))
                let maskedGroupCanvas = imageByApplyingCanvasMask(groupCanvas, mask: groupMask)
                canvas = canvas.blended(
                    with: maskedGroupCanvas,
                    mode: layer.blendMode,
                    opacity: layer.opacity * effectiveGroupOpacity(for: layer)
                ) ?? canvas
                continue
            }
            guard shouldComposite(layer, includedIn: includedLayerIDs),
                  isolatedGroupAncestor(for: layer) == nil
            else { continue }
            canvas = compositeLayer(at: index, onto: canvas, stoppingBeforeGroupID: nil, includedLayerIDs: includedLayerIDs)
        }
        return canvas
    }

    private func compositeLayer(
        at index: Int,
        onto canvas: NSImage,
        stoppingBeforeGroupID: UUID?,
        includedLayerIDs: Set<UUID>? = nil
    ) -> NSImage {
        let layer = layers[index]
        let groupOpacity = effectiveGroupOpacity(for: layer, stoppingBefore: stoppingBeforeGroupID)
        let groupMask = effectiveGroupMask(for: layer, stoppingBefore: stoppingBeforeGroupID)
        if let adjustment = layer.adjustment {
            return canvas.applyingAdjustment(
                kind: adjustment.kind,
                amount: adjustment.amount * layer.opacity * groupOpacity,
                settings: layer.adjustmentSettings,
                mask: effectiveCanvasMask(forLayerAt: index, layerMask: layer.effectiveMask, groupMask: groupMask)
            ) ?? canvas
        }
        if let filter = layer.filter {
            return canvas.applyingFilter(
                kind: filter.kind,
                intensity: filter.intensity * layer.opacity * groupOpacity,
                settings: layer.filterSettings,
                mask: effectiveCanvasMask(forLayerAt: index, layerMask: layer.effectiveMask, groupMask: groupMask)
            ) ?? canvas
        }

        let layerCanvas: NSImage
        if layer.isClippingMask,
           let clippedImage = clippedCompositingImage(forLayerAt: index) {
            layerCanvas = imageByApplyingCanvasMask(clippedImage, mask: groupMask)
        } else {
            let compositingImage = layer.renderedCompositingImage(globalLightAngle: globalLightAngle)
            let positionedCanvas = canvasImage(
                for: compositingImage,
                frame: layer.renderedCompositingFrame(globalLightAngle: globalLightAngle)
            )
            layerCanvas = imageByApplyingCanvasMask(positionedCanvas, mask: groupMask)
        }
        let blendIfCanvas = layerCanvas.applyingBlendIfUnderlyingRange(
            black: layer.blendIfUnderlyingBlack,
            white: layer.blendIfUnderlyingWhite,
            backdrop: canvas
        ) ?? layerCanvas
        return canvas.blended(
            with: blendIfCanvas,
            mode: layer.blendMode,
            opacity: layer.opacity * groupOpacity
        ) ?? canvas
    }

    private func isolatedGroupCanvas(for group: ImageEditorLayer, includedLayerIDs: Set<UUID>? = nil) -> NSImage {
        var groupCanvas = NSImage.transparent(size: canvasSize)
        for index in layers.indices {
            let layer = layers[index]
            guard layer.id != group.id,
                  isLayer(layer, descendantOf: group.id)
            else { continue }
            if layer.isGroup {
                guard shouldRenderIsolatedGroup(layer, includedIn: includedLayerIDs),
                      isolatedGroupAncestor(for: layer, stoppingBefore: group.id) == nil
                else { continue }
                let nestedCanvas = isolatedGroupCanvas(for: layer, includedLayerIDs: includedLayerIDs)
                let nestedMask = combinedCanvasMask(
                    layer.effectiveMask,
                    effectiveGroupMask(for: layer, stoppingBefore: group.id)
                )
                let maskedNestedCanvas = imageByApplyingCanvasMask(nestedCanvas, mask: nestedMask)
                groupCanvas = groupCanvas.blended(
                    with: maskedNestedCanvas,
                    mode: layer.blendMode,
                    opacity: layer.opacity * effectiveGroupOpacity(for: layer, stoppingBefore: group.id)
                ) ?? groupCanvas
                continue
            }
            guard shouldComposite(layer, includedIn: includedLayerIDs),
                  isolatedGroupAncestor(for: layer, stoppingBefore: group.id) == nil
            else { continue }
            groupCanvas = compositeLayer(
                at: index,
                onto: groupCanvas,
                stoppingBeforeGroupID: group.id,
                includedLayerIDs: includedLayerIDs
            )
        }
        return groupCanvas
    }

    func group(for layer: ImageEditorLayer) -> ImageEditorLayer? {
        guard let groupID = layer.groupID else { return nil }
        return layers.first { $0.id == groupID && $0.isGroup }
    }

    func groupDepth(for layer: ImageEditorLayer) -> Int {
        ancestorGroups(for: layer).count
    }

    func ancestorGroups(for layer: ImageEditorLayer) -> [ImageEditorLayer] {
        ancestorGroups(for: layer, stoppingBefore: nil)
    }

    private func ancestorGroups(for layer: ImageEditorLayer, stoppingBefore stopGroupID: UUID?) -> [ImageEditorLayer] {
        var ancestors: [ImageEditorLayer] = []
        var visitedIDs = Set<UUID>()
        var currentGroupID = layer.groupID
        while let groupID = currentGroupID,
              !visitedIDs.contains(groupID),
              let group = layers.first(where: { $0.id == groupID && $0.isGroup }) {
            if groupID == stopGroupID {
                break
            }
            visitedIDs.insert(groupID)
            ancestors.append(group)
            currentGroupID = group.groupID
        }
        return ancestors
    }

    func effectiveGroupOpacity(for layer: ImageEditorLayer) -> Double {
        effectiveGroupOpacity(for: layer, stoppingBefore: nil)
    }

    private func effectiveGroupOpacity(for layer: ImageEditorLayer, stoppingBefore stopGroupID: UUID?) -> Double {
        ancestorGroups(for: layer, stoppingBefore: stopGroupID).reduce(1) { partialResult, group in
            partialResult * group.opacity
        }
    }

    func effectiveGroupMask(for layer: ImageEditorLayer) -> NSImage? {
        effectiveGroupMask(for: layer, stoppingBefore: nil)
    }

    private func effectiveGroupMask(for layer: ImageEditorLayer, stoppingBefore stopGroupID: UUID?) -> NSImage? {
        let masks = ancestorGroups(for: layer, stoppingBefore: stopGroupID).compactMap(\.effectiveMask)
        guard !masks.isEmpty else { return nil }
        return masks.reduce(NSImage.opaqueMask(size: canvasSize)) { partialResult, mask in
            imageByApplyingCanvasMask(partialResult, mask: mask)
        }
    }

    private func isIsolatedGroup(_ layer: ImageEditorLayer) -> Bool {
        layer.isGroup && layer.blendMode != .passThrough && isEffectivelyVisible(layer)
    }

    private func shouldRenderIsolatedGroup(_ group: ImageEditorLayer, includedIn includedLayerIDs: Set<UUID>?) -> Bool {
        guard isIsolatedGroup(group) else { return false }
        guard let includedLayerIDs else { return true }
        if includedLayerIDs.contains(group.id) {
            return true
        }
        return layers.contains { layer in
            layer.id != group.id
                && isLayer(layer, descendantOf: group.id)
                && isLayerIncluded(layer, in: includedLayerIDs)
        }
    }

    private func isolatedGroupAncestor(for layer: ImageEditorLayer, stoppingBefore stopGroupID: UUID? = nil) -> ImageEditorLayer? {
        ancestorGroups(for: layer, stoppingBefore: stopGroupID).first(where: isIsolatedGroup)
    }

    private func isLayer(_ layer: ImageEditorLayer, descendantOf groupID: UUID) -> Bool {
        ancestorGroups(for: layer).contains { $0.id == groupID }
    }

    private func combinedCanvasMask(_ layerMask: NSImage?, _ groupMask: NSImage?) -> NSImage? {
        switch (layerMask, groupMask) {
        case (.none, .none):
            return nil
        case let (.some(layerMask), .none):
            return layerMask
        case let (.none, .some(groupMask)):
            return groupMask
        case let (.some(layerMask), .some(groupMask)):
            return imageByApplyingCanvasMask(layerMask, mask: groupMask)
        }
    }

    func clippingBaseCanvasMask(forLayerAt index: Int) -> NSImage? {
        guard layers.indices.contains(index),
              let base = clippingBase(forLayerAt: index)
        else { return nil }
        let baseImage = base.renderedCompositingImage(globalLightAngle: globalLightAngle)
        return NSImage.rendered(size: canvasSize) { _ in
            baseImage.draw(
                in: base.renderedCompositingFrame(globalLightAngle: globalLightAngle),
                from: CGRect(origin: .zero, size: baseImage.size),
                operation: .sourceOver,
                fraction: 1
            )
        }
    }

    func localEffectMask(forLayerAt index: Int) -> NSImage? {
        guard layers.indices.contains(index) else { return nil }
        let layerMask = layers[index].effectiveMask
        guard let clippingMask = clippingBaseCanvasMask(forLayerAt: index) else { return layerMask }
        return combinedCanvasMask(layerMask, clippingMask)
    }

    private func effectiveCanvasMask(forLayerAt index: Int, layerMask: NSImage?, groupMask: NSImage?) -> NSImage? {
        let localMask = combinedCanvasMask(layerMask, groupMask)
        guard let clippingMask = clippingBaseCanvasMask(forLayerAt: index) else { return localMask }
        return combinedCanvasMask(localMask, clippingMask)
    }

    private func canvasImage(for image: NSImage, frame: CGRect) -> NSImage {
        NSImage.rendered(size: canvasSize) { _ in
            image.draw(
                in: frame,
                from: CGRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1
            )
        } ?? NSImage.transparent(size: canvasSize)
    }

    private func imageByApplyingCanvasMask(_ image: NSImage, mask: NSImage?) -> NSImage {
        guard let mask else { return image }
        return NSImage.rendered(size: image.size) { _ in
            image.draw(
                in: CGRect(origin: .zero, size: image.size),
                from: CGRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: image.size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        } ?? image
    }

    func isEffectivelyLocked(_ layer: ImageEditorLayer) -> Bool {
        layer.isLocked || ancestorGroups(for: layer).contains { $0.isLocked }
    }

    func isEffectivelyPixelsLocked(_ layer: ImageEditorLayer) -> Bool {
        isEffectivelyLocked(layer)
            || layer.locksPixels
            || ancestorGroups(for: layer).contains { $0.locksPixels }
    }

    func isEffectivelyTransparencyLocked(_ layer: ImageEditorLayer) -> Bool {
        layer.locksTransparentPixels
            || ancestorGroups(for: layer).contains { $0.locksTransparentPixels }
    }

    func isEffectivelyPositionLocked(_ layer: ImageEditorLayer) -> Bool {
        isEffectivelyLocked(layer)
            || layer.locksPosition
            || ancestorGroups(for: layer).contains { $0.locksPosition }
    }

    func isEffectivelyVisible(_ layer: ImageEditorLayer) -> Bool {
        layer.isVisible && ancestorGroups(for: layer).allSatisfy(\.isVisible)
    }

    func shouldComposite(_ layer: ImageEditorLayer) -> Bool {
        !layer.isGroup && isEffectivelyVisible(layer)
    }

    private func shouldComposite(_ layer: ImageEditorLayer, includedIn includedLayerIDs: Set<UUID>?) -> Bool {
        guard shouldComposite(layer) else { return false }
        guard let includedLayerIDs else { return true }
        return isLayerIncluded(layer, in: includedLayerIDs)
    }

    private func isLayerIncluded(_ layer: ImageEditorLayer, in includedLayerIDs: Set<UUID>) -> Bool {
        includedLayerIDs.contains(layer.id)
            || ancestorGroups(for: layer).contains { includedLayerIDs.contains($0.id) }
    }

    func clippingBase(forLayerAt index: Int) -> ImageEditorLayer? {
        guard let baseIndex = clippingBaseIndex(forLayerAt: index) else { return nil }
        return layers[baseIndex]
    }

    func clippingBaseIndex(forLayerAt index: Int) -> Int? {
        guard layers.indices.contains(index) else { return nil }
        let layer = layers[index]
        guard layer.isClippingMask else { return nil }
        return layers[..<index].indices.reversed().first { candidateIndex in
            let candidate = layers[candidateIndex]
            return !candidate.isGroup
                && !candidate.isAdjustment
                && !candidate.isFilter
                && !candidate.isClippingMask
                && candidate.groupID == layer.groupID
                && isEffectivelyVisible(candidate)
        }
    }

    func hasClippingBase(below index: Int, groupID: UUID?) -> Bool {
        guard index > 0 else { return false }
        return layers[..<index].contains { candidate in
            !candidate.isGroup
                && !candidate.isAdjustment
                && !candidate.isFilter
                && !candidate.isClippingMask
                && candidate.groupID == groupID
                && isEffectivelyVisible(candidate)
        }
    }

    func clippedCompositingImage(forLayerAt index: Int) -> NSImage? {
        guard layers.indices.contains(index),
              let base = clippingBase(forLayerAt: index)
        else { return nil }
        let layer = layers[index]
        let layerImage = layer.renderedCompositingImage(globalLightAngle: globalLightAngle)
        let baseImage = base.renderedCompositingImage(globalLightAngle: globalLightAngle)
        return NSImage.rendered(size: canvasSize) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.saveGState()
            layerImage.draw(
                in: layer.renderedCompositingFrame(globalLightAngle: globalLightAngle),
                from: CGRect(origin: .zero, size: layerImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            baseImage.draw(
                in: base.renderedCompositingFrame(globalLightAngle: globalLightAngle),
                from: CGRect(origin: .zero, size: baseImage.size),
                operation: .destinationIn,
                fraction: 1
            )
            context.restoreGState()
        }
    }
}

private extension NSImage {
    func outsideStrokeCanvas(color: NSColor, width: Int, contentRect: CGRect, outputSize: CGSize) -> NSImage? {
        let strokeImage = alphaTinted(color: color)
        return NSImage.rendered(size: outputSize) { _ in
            drawExpandedAlpha(
                strokeImage,
                width: width,
                contentRect: contentRect
            )
            draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: size),
                operation: .destinationOut,
                fraction: 1
            )
        }
    }

    func insideStrokeCanvas(color: NSColor, width: Int, contentRect: CGRect, outputSize: CGSize) -> NSImage? {
        let strokeImage = alphaTinted(color: color)
        let maskImage = alphaTinted(color: .white)
        let erodedImage = NSImage.rendered(size: outputSize) { _ in
            strokeImage.draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: strokeImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            applyErosionMask(
                maskImage,
                width: width,
                contentRect: contentRect
            )
        }
        return NSImage.rendered(size: outputSize) { _ in
            strokeImage.draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: strokeImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            erodedImage?.draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: CGRect(origin: .zero, size: outputSize),
                operation: .destinationOut,
                fraction: 1
            )
        }
    }

    private func drawExpandedAlpha(_ image: NSImage, width: Int, contentRect: CGRect) {
        image.draw(
            in: contentRect,
            from: CGRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1
        )
        let directions = 24
        for radius in 1...max(1, width) {
            for step in 0..<directions {
                let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                image.draw(
                    in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                    from: CGRect(origin: .zero, size: image.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }
        }
    }

    private func applyErosionMask(_ maskImage: NSImage, width: Int, contentRect: CGRect) {
        let directions = 24
        for radius in 1...max(1, width) {
            for step in 0..<directions {
                let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                maskImage.draw(
                    in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                    from: CGRect(origin: .zero, size: maskImage.size),
                    operation: .destinationIn,
                    fraction: 1
                )
            }
        }
    }

    func compositedWithAlphaMask(_ mask: NSImage) -> NSImage? {
        NSImage.rendered(size: size) { rect in
            draw(
                in: rect,
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: rect,
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }
    }

    func processedLayerMask(density: Double, feather: Double) -> NSImage? {
        let normalizedDensity = max(0, min(1, density))
        let normalizedFeather = max(0, min(80, feather))
        let featheredMask = normalizedFeather > 0 ? (blurred(radius: normalizedFeather) ?? self) : self
        guard normalizedDensity < 1 else { return featheredMask }
        guard let alpha = featheredMask.alphaPlane() else { return featheredMask }
        let adjustedAlpha = alpha.values.map { value -> UInt8 in
            let revealed = 255 - Double(255 - Int(value)) * normalizedDensity
            return UInt8(max(0, min(255, Int(revealed.rounded()))))
        }
        return NSImage.alphaMaskImage(width: alpha.width, height: alpha.height, alpha: adjustedAlpha)
    }

    func alphaPlane() -> (width: Int, height: Int, values: [UInt8])? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                alpha[y * width + x] = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
            }
        }
        return (width, height, alpha)
    }

    func withOpacity(_ opacity: CGFloat) -> NSImage? {
        let normalizedOpacity = max(0, min(1, opacity))
        return NSImage.rendered(size: size) { rect in
            draw(
                in: rect,
                from: CGRect(origin: .zero, size: size),
                operation: .sourceOver,
                fraction: normalizedOpacity
            )
        }
    }
}

struct ImageEditorTheme {
    static let window = NSColor(calibratedWhite: 0.11, alpha: 1)
    static let chrome = NSColor(calibratedWhite: 0.18, alpha: 1)
    static let panel = NSColor(calibratedWhite: 0.23, alpha: 1)
    static let panelRaised = NSColor(calibratedWhite: 0.29, alpha: 1)
    static let border = NSColor(calibratedWhite: 0.38, alpha: 1)
    static let selected = NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.78, alpha: 1)
    static let text = NSColor(calibratedWhite: 0.92, alpha: 1)
    static let mutedText = NSColor(calibratedWhite: 0.68, alpha: 1)
}
