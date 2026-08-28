//
//  ImageEditorModels.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation
import simd

struct ImageEditorColorSwatch: Identifiable {
    let id: String
    let nameKey: String
    let color: NSColor

    var title: String {
        L10n.text(nameKey)
    }

    static let defaultPalette: [ImageEditorColorSwatch] = [
        ImageEditorColorSwatch(id: "black", nameKey: "imageEditor.swatch.black", color: rgb(0, 0, 0)),
        ImageEditorColorSwatch(id: "white", nameKey: "imageEditor.swatch.white", color: rgb(255, 255, 255)),
        ImageEditorColorSwatch(id: "gray", nameKey: "imageEditor.swatch.gray", color: rgb(128, 128, 128)),
        ImageEditorColorSwatch(id: "red", nameKey: "imageEditor.swatch.red", color: rgb(255, 0, 0)),
        ImageEditorColorSwatch(id: "orange", nameKey: "imageEditor.swatch.orange", color: rgb(255, 128, 0)),
        ImageEditorColorSwatch(id: "yellow", nameKey: "imageEditor.swatch.yellow", color: rgb(255, 230, 0)),
        ImageEditorColorSwatch(id: "green", nameKey: "imageEditor.swatch.green", color: rgb(0, 170, 70)),
        ImageEditorColorSwatch(id: "cyan", nameKey: "imageEditor.swatch.cyan", color: rgb(0, 190, 210)),
        ImageEditorColorSwatch(id: "blue", nameKey: "imageEditor.swatch.blue", color: rgb(0, 92, 255)),
        ImageEditorColorSwatch(id: "magenta", nameKey: "imageEditor.swatch.magenta", color: rgb(210, 0, 180))
    ]

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(deviceRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }
}

struct ImageEditorBrushPreset: Identifiable, Codable, Equatable {
    nonisolated static let maximumCustomNameLength = 80

    let id: String
    let name: String?
    let size: CGFloat
    let hardness: CGFloat
    let flow: CGFloat
    let spacing: CGFloat
    let pressureControlsSize: Bool
    let pressureControlsOpacity: Bool
    let pressureControlsFlow: Bool
    let pressureSensitivity: CGFloat
    let sizeJitter: CGFloat
    let angleJitter: CGFloat
    let angleFollowsStrokeDirection: Bool
    let roundnessJitter: CGFloat
    let opacityJitter: CGFloat
    let flowJitter: CGFloat
    let minimumRoundness: CGFloat
    let scatter: CGFloat
    let scatterBothAxes: Bool
    let scatterCount: Int
    let scatterCountJitter: CGFloat
    let noiseEnabled: Bool
    let wetEdgesEnabled: Bool
    let minimumDiameter: CGFloat
    let minimumOpacity: CGFloat
    let minimumFlow: CGFloat
    let tiltControlsShape: Bool
    let tipRoundness: CGFloat
    let tipAngleDegrees: CGFloat
    let smoothing: CGFloat
    let isBuiltIn: Bool

    init(
        id: String,
        name: String? = nil,
        size: CGFloat,
        hardness: CGFloat = 0.8,
        flow: CGFloat = 100,
        spacing: CGFloat = 25,
        pressureControlsSize: Bool = true,
        pressureControlsOpacity: Bool = false,
        pressureControlsFlow: Bool = true,
        pressureSensitivity: CGFloat = 50,
        sizeJitter: CGFloat = 0,
        angleJitter: CGFloat = 0,
        angleFollowsStrokeDirection: Bool = false,
        roundnessJitter: CGFloat = 0,
        opacityJitter: CGFloat = 0,
        flowJitter: CGFloat = 0,
        minimumRoundness: CGFloat = 1,
        scatter: CGFloat = 0,
        scatterBothAxes: Bool = false,
        scatterCount: Int = 1,
        scatterCountJitter: CGFloat = 0,
        noiseEnabled: Bool = false,
        wetEdgesEnabled: Bool = false,
        minimumDiameter: CGFloat = 0,
        minimumOpacity: CGFloat = 0,
        minimumFlow: CGFloat = 0,
        tiltControlsShape: Bool = false,
        tipRoundness: CGFloat = 100,
        tipAngleDegrees: CGFloat = 0,
        smoothing: CGFloat = 0,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.hardness = hardness
        self.flow = flow
        self.spacing = spacing
        self.pressureControlsSize = pressureControlsSize
        self.pressureControlsOpacity = pressureControlsOpacity
        self.pressureControlsFlow = pressureControlsFlow
        self.pressureSensitivity = pressureSensitivity
        self.sizeJitter = sizeJitter
        self.angleJitter = angleJitter
        self.angleFollowsStrokeDirection = angleFollowsStrokeDirection
        self.roundnessJitter = roundnessJitter
        self.opacityJitter = opacityJitter
        self.flowJitter = flowJitter
        self.minimumRoundness = minimumRoundness
        self.scatter = scatter
        self.scatterBothAxes = scatterBothAxes
        self.scatterCount = scatterCount
        self.scatterCountJitter = scatterCountJitter
        self.noiseEnabled = noiseEnabled
        self.wetEdgesEnabled = wetEdgesEnabled
        self.minimumDiameter = minimumDiameter
        self.minimumOpacity = minimumOpacity
        self.minimumFlow = minimumFlow
        self.tiltControlsShape = tiltControlsShape
        self.tipRoundness = tipRoundness
        self.tipAngleDegrees = tipAngleDegrees
        self.smoothing = smoothing
        self.isBuiltIn = isBuiltIn
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case hardness
        case flow
        case spacing
        case pressureControlsSize
        case pressureControlsOpacity
        case pressureControlsFlow
        case pressureSensitivity
        case sizeJitter
        case angleJitter
        case angleFollowsStrokeDirection
        case roundnessJitter
        case opacityJitter
        case flowJitter
        case minimumRoundness
        case scatter
        case scatterBothAxes
        case scatterCount
        case scatterCountJitter
        case noiseEnabled
        case wetEdgesEnabled
        case minimumDiameter
        case minimumOpacity
        case minimumFlow
        case tiltControlsShape
        case tipRoundness
        case tipAngleDegrees
        case smoothing
        case isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        size = try values.decode(CGFloat.self, forKey: .size)
        hardness = try values.decode(CGFloat.self, forKey: .hardness)
        flow = try values.decode(CGFloat.self, forKey: .flow)
        spacing = try values.decode(CGFloat.self, forKey: .spacing)
        pressureControlsSize = try values.decode(
            Bool.self,
            forKey: .pressureControlsSize
        )
        pressureControlsOpacity = try values.decodeIfPresent(
            Bool.self,
            forKey: .pressureControlsOpacity
        ) ?? false
        pressureControlsFlow = try values.decode(
            Bool.self,
            forKey: .pressureControlsFlow
        )
        pressureSensitivity = try values.decode(
            CGFloat.self,
            forKey: .pressureSensitivity
        )
        sizeJitter = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .sizeJitter
        ) ?? 0
        angleJitter = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .angleJitter
        ) ?? 0
        angleFollowsStrokeDirection = try values.decodeIfPresent(
            Bool.self,
            forKey: .angleFollowsStrokeDirection
        ) ?? false
        roundnessJitter = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .roundnessJitter
        ) ?? 0
        opacityJitter = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .opacityJitter
        ) ?? 0
        flowJitter = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .flowJitter
        ) ?? 0
        minimumRoundness = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .minimumRoundness
        ) ?? 1
        scatter = try values.decodeIfPresent(CGFloat.self, forKey: .scatter) ?? 0
        scatterBothAxes = try values.decodeIfPresent(
            Bool.self,
            forKey: .scatterBothAxes
        ) ?? false
        scatterCount = try values.decodeIfPresent(Int.self, forKey: .scatterCount) ?? 1
        scatterCountJitter = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .scatterCountJitter
        ) ?? 0
        noiseEnabled = try values.decodeIfPresent(Bool.self, forKey: .noiseEnabled) ?? false
        wetEdgesEnabled = try values.decodeIfPresent(
            Bool.self,
            forKey: .wetEdgesEnabled
        ) ?? false
        minimumDiameter = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .minimumDiameter
        ) ?? 0
        minimumOpacity = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .minimumOpacity
        ) ?? 0
        minimumFlow = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .minimumFlow
        ) ?? 0
        tiltControlsShape = try values.decodeIfPresent(
            Bool.self,
            forKey: .tiltControlsShape
        ) ?? false
        tipRoundness = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .tipRoundness
        ) ?? 100
        tipAngleDegrees = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .tipAngleDegrees
        ) ?? 0
        smoothing = try values.decodeIfPresent(
            CGFloat.self,
            forKey: .smoothing
        ) ?? 0
        isBuiltIn = try values.decode(Bool.self, forKey: .isBuiltIn)
    }

    var title: String {
        name ?? L10n.format("imageEditor.brushPreset.size", Int(size.rounded()))
    }

    nonisolated static func normalizedCustomName(_ proposedName: String) -> String? {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        return String(trimmedName.prefix(maximumCustomNameLength))
    }

    func renamingCustomPreset(to normalizedName: String) -> ImageEditorBrushPreset {
        copyingCustomPreset(id: id, name: normalizedName)
    }

    func copyingCustomPreset(id copyID: String, name copyName: String) -> ImageEditorBrushPreset {
        ImageEditorBrushPreset(
            id: copyID,
            name: copyName,
            size: size,
            hardness: hardness,
            flow: flow,
            spacing: spacing,
            pressureControlsSize: pressureControlsSize,
            pressureControlsOpacity: pressureControlsOpacity,
            pressureControlsFlow: pressureControlsFlow,
            pressureSensitivity: pressureSensitivity,
            sizeJitter: sizeJitter,
            angleJitter: angleJitter,
            angleFollowsStrokeDirection: angleFollowsStrokeDirection,
            roundnessJitter: roundnessJitter,
            opacityJitter: opacityJitter,
            flowJitter: flowJitter,
            minimumRoundness: minimumRoundness,
            scatter: scatter,
            scatterBothAxes: scatterBothAxes,
            scatterCount: scatterCount,
            scatterCountJitter: scatterCountJitter,
            noiseEnabled: noiseEnabled,
            wetEdgesEnabled: wetEdgesEnabled,
            minimumDiameter: minimumDiameter,
            minimumOpacity: minimumOpacity,
            minimumFlow: minimumFlow,
            tiltControlsShape: tiltControlsShape,
            tipRoundness: tipRoundness,
            tipAngleDegrees: tipAngleDegrees,
            smoothing: smoothing,
            isBuiltIn: false
        ).normalizedCustomPreset
    }

    var normalizedCustomPreset: ImageEditorBrushPreset {
        let normalizedName = name.flatMap(Self.normalizedCustomName)
            ?? L10n.text("imageEditor.brushPreset.untitled")
        return ImageEditorBrushPreset(
            id: id.isEmpty ? UUID().uuidString : id,
            name: normalizedName,
            size: max(1, min(96, size)),
            hardness: max(0, min(1, hardness)),
            flow: max(1, min(100, flow)),
            spacing: max(1, min(200, spacing)),
            pressureControlsSize: pressureControlsSize,
            pressureControlsOpacity: pressureControlsOpacity,
            pressureControlsFlow: pressureControlsFlow,
            pressureSensitivity: max(0, min(100, pressureSensitivity)),
            sizeJitter: max(0, min(100, sizeJitter)),
            angleJitter: max(0, min(100, angleJitter)),
            angleFollowsStrokeDirection: angleFollowsStrokeDirection,
            roundnessJitter: max(0, min(100, roundnessJitter)),
            opacityJitter: max(0, min(100, opacityJitter)),
            flowJitter: max(0, min(100, flowJitter)),
            minimumRoundness: max(1, min(100, minimumRoundness)),
            scatter: max(0, min(1_000, scatter)),
            scatterBothAxes: scatterBothAxes,
            scatterCount: max(1, min(16, scatterCount)),
            scatterCountJitter: max(0, min(100, scatterCountJitter)),
            noiseEnabled: noiseEnabled,
            wetEdgesEnabled: wetEdgesEnabled,
            minimumDiameter: max(0, min(100, minimumDiameter)),
            minimumOpacity: max(0, min(100, minimumOpacity)),
            minimumFlow: max(0, min(100, minimumFlow)),
            tiltControlsShape: tiltControlsShape,
            tipRoundness: max(10, min(100, tipRoundness)),
            tipAngleDegrees: max(-180, min(180, tipAngleDegrees)),
            smoothing: max(0, min(100, smoothing)),
            isBuiltIn: false
        )
    }

    func matches(
        size: CGFloat,
        hardness: CGFloat,
        flow: CGFloat,
        spacing: CGFloat,
        pressureControlsSize: Bool,
        pressureControlsOpacity: Bool,
        pressureControlsFlow: Bool,
        pressureSensitivity: CGFloat,
        sizeJitter: CGFloat,
        angleJitter: CGFloat,
        angleFollowsStrokeDirection: Bool,
        roundnessJitter: CGFloat,
        opacityJitter: CGFloat,
        flowJitter: CGFloat,
        minimumRoundness: CGFloat,
        scatter: CGFloat,
        scatterBothAxes: Bool,
        scatterCount: Int,
        scatterCountJitter: CGFloat,
        noiseEnabled: Bool,
        wetEdgesEnabled: Bool,
        minimumDiameter: CGFloat,
        minimumOpacity: CGFloat,
        minimumFlow: CGFloat,
        tiltControlsShape: Bool,
        tipRoundness: CGFloat,
        tipAngleDegrees: CGFloat,
        smoothing: CGFloat
    ) -> Bool {
        let tolerance = CGFloat(0.0001)
        return abs(self.size - size) < tolerance
            && abs(self.hardness - hardness) < tolerance
            && abs(self.flow - flow) < tolerance
            && abs(self.spacing - spacing) < tolerance
            && self.pressureControlsSize == pressureControlsSize
            && self.pressureControlsOpacity == pressureControlsOpacity
            && self.pressureControlsFlow == pressureControlsFlow
            && abs(self.pressureSensitivity - pressureSensitivity) < tolerance
            && abs(self.sizeJitter - sizeJitter) < tolerance
            && abs(self.angleJitter - angleJitter) < tolerance
            && self.angleFollowsStrokeDirection == angleFollowsStrokeDirection
            && abs(self.roundnessJitter - roundnessJitter) < tolerance
            && abs(self.opacityJitter - opacityJitter) < tolerance
            && abs(self.flowJitter - flowJitter) < tolerance
            && abs(self.minimumRoundness - minimumRoundness) < tolerance
            && abs(self.scatter - scatter) < tolerance
            && self.scatterBothAxes == scatterBothAxes
            && self.scatterCount == scatterCount
            && abs(self.scatterCountJitter - scatterCountJitter) < tolerance
            && self.noiseEnabled == noiseEnabled
            && self.wetEdgesEnabled == wetEdgesEnabled
            && abs(self.minimumDiameter - minimumDiameter) < tolerance
            && abs(self.minimumOpacity - minimumOpacity) < tolerance
            && abs(self.minimumFlow - minimumFlow) < tolerance
            && self.tiltControlsShape == tiltControlsShape
            && abs(self.tipRoundness - tipRoundness) < tolerance
            && abs(self.tipAngleDegrees - tipAngleDegrees) < tolerance
            && abs(self.smoothing - smoothing) < tolerance
    }

    static let defaultPresets: [ImageEditorBrushPreset] = [3, 9, 18, 36, 72].map { size in
        ImageEditorBrushPreset(id: "built-in-\(size)-px", size: CGFloat(size), isBuiltIn: true)
    }
}

struct ImageEditorToolShortcutGroup: Identifiable, Equatable {
    let key: Character
    let tools: [ImageEditorTool]

    var id: String {
        String(key)
    }

    var primaryTool: ImageEditorTool {
        tools[0]
    }
}

enum ImageEditorTool: String, CaseIterable, Identifiable {
    case move
    case marquee
    case lasso
    case magicWand
    case quickSelection
    case crop
    case brush
    case pencil
    case historyBrush
    case eraser
    case cloneStamp
    case dodge
    case burn
    case sponge
    case blur
    case sharpen
    case smudge
    case healingBrush
    case patchTool
    case redEye
    case paintBucket
    case gradient
    case eyedropper
    case colorSampler
    case text
    case rectangle
    case ellipse
    case pen
    case pathSelection
    case directSelection
    case hand
    case zoom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.tool.\(rawValue)")
    }

    var helpText: String {
        L10n.text("imageEditor.tool.\(rawValue).help")
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
        case .quickSelection:
            "circle.dashed.inset.filled"
        case .crop:
            "crop"
        case .brush:
            "paintbrush.pointed"
        case .pencil:
            "pencil"
        case .historyBrush:
            "clock.arrow.circlepath"
        case .eraser:
            "eraser"
        case .cloneStamp:
            "seal"
        case .dodge:
            "sun.max"
        case .burn:
            "flame"
        case .sponge:
            "circle.lefthalf.filled"
        case .blur:
            "drop"
        case .sharpen:
            "sparkles"
        case .smudge:
            "scribble.variable"
        case .healingBrush:
            "bandage"
        case .patchTool:
            "square.dashed"
        case .redEye:
            "eye"
        case .paintBucket:
            "paintpalette.fill"
        case .gradient:
            "square.lefthalf.filled"
        case .eyedropper:
            "eyedropper"
        case .colorSampler:
            "scope"
        case .text:
            "textformat"
        case .rectangle:
            "rectangle"
        case .ellipse:
            "circle"
        case .pen:
            "point.topleft.down.curvedto.point.bottomright.up"
        case .pathSelection:
            "cursorarrow"
        case .directSelection:
            "arrow.up.right"
        case .hand:
            "hand.draw"
        case .zoom:
            "magnifyingglass"
        }
    }

    var classicShortcutKey: Character? {
        Self.classicShortcutGroups.first { $0.tools.contains(self) }?.key
    }

    var isClassicShortcutPrimary: Bool {
        Self.classicShortcutGroups.first { $0.tools.contains(self) }?.primaryTool == self
    }

    static let classicShortcutGroups: [ImageEditorToolShortcutGroup] = [
        ImageEditorToolShortcutGroup(key: "v", tools: [.move]),
        ImageEditorToolShortcutGroup(key: "m", tools: [.marquee]),
        ImageEditorToolShortcutGroup(key: "l", tools: [.lasso]),
        ImageEditorToolShortcutGroup(key: "w", tools: [.magicWand, .quickSelection]),
        ImageEditorToolShortcutGroup(key: "c", tools: [.crop]),
        ImageEditorToolShortcutGroup(key: "b", tools: [.brush, .pencil]),
        ImageEditorToolShortcutGroup(key: "y", tools: [.historyBrush]),
        ImageEditorToolShortcutGroup(key: "e", tools: [.eraser]),
        ImageEditorToolShortcutGroup(key: "s", tools: [.cloneStamp]),
        ImageEditorToolShortcutGroup(key: "j", tools: [.healingBrush, .patchTool, .redEye]),
        ImageEditorToolShortcutGroup(key: "o", tools: [.dodge, .burn, .sponge]),
        ImageEditorToolShortcutGroup(key: "r", tools: [.blur, .sharpen, .smudge]),
        ImageEditorToolShortcutGroup(key: "g", tools: [.paintBucket, .gradient]),
        ImageEditorToolShortcutGroup(key: "i", tools: [.eyedropper, .colorSampler]),
        ImageEditorToolShortcutGroup(key: "t", tools: [.text]),
        ImageEditorToolShortcutGroup(key: "u", tools: [.rectangle, .ellipse]),
        ImageEditorToolShortcutGroup(key: "p", tools: [.pen]),
        ImageEditorToolShortcutGroup(key: "a", tools: [.pathSelection, .directSelection]),
        ImageEditorToolShortcutGroup(key: "h", tools: [.hand]),
        ImageEditorToolShortcutGroup(key: "z", tools: [.zoom])
    ]

    static func classicShortcutGroup(for key: Character) -> ImageEditorToolShortcutGroup? {
        classicShortcutGroups.first { $0.key == Character(String(key).lowercased()) }
    }

    var supportsSelectionMode: Bool {
        switch self {
        case .marquee, .lasso, .magicWand, .quickSelection:
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

enum ImageEditorMarqueeShape: String, CaseIterable, Identifiable {
    case rectangle
    case square
    case ellipse
    case circle

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.marqueeShape.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .rectangle:
            "rectangle.dashed"
        case .square:
            "square.dashed"
        case .ellipse:
            "oval"
        case .circle:
            "circle.dashed"
        }
    }

    var isEllipse: Bool {
        self == .ellipse || self == .circle
    }

    var hasFixedAspectRatio: Bool {
        self == .square || self == .circle
    }
}

struct ImageEditorColorSamplerPoint: Identifiable {
    static let maximumCount = 4

    let id: UUID
    let point: CGPoint
    let color: NSColor

    init(
        id: UUID = UUID(),
        point: CGPoint,
        color: NSColor
    ) {
        self.id = id
        self.point = point
        self.color = color
    }
}

enum ImageEditorColorSamplerReadoutMode: String, CaseIterable, Identifiable {
    case rgb
    case hsb
    case cmyk
    case hexadecimal

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.info.colorSampler.mode.\(rawValue)")
    }

    var shortTitle: String {
        L10n.text("imageEditor.info.colorSampler.mode.\(rawValue).short")
    }
}

enum ImageEditorColorSamplerSampleSize: String, CaseIterable, Identifiable {
    case oneByOne = "1x1"
    case threeByThree = "3x3"
    case fiveByFive = "5x5"

    var id: String { rawValue }

    var dimension: Int {
        switch self {
        case .oneByOne: 1
        case .threeByThree: 3
        case .fiveByFive: 5
        }
    }

    var title: String {
        L10n.text("imageEditor.info.colorSampler.sampleSize.\(rawValue)")
    }

    var shortTitle: String {
        L10n.text("imageEditor.info.colorSampler.sampleSize.\(rawValue).short")
    }
}

enum ImageEditorColorSamplerSource: String, CaseIterable, Identifiable {
    case composite
    case selectedLayer
    case currentAndBelow

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.info.colorSampler.source.\(rawValue)")
    }

    var shortTitle: String {
        L10n.text("imageEditor.info.colorSampler.source.\(rawValue).short")
    }
}

struct ImageEditorColorSamplerReading {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat
    let cyan: CGFloat
    let magenta: CGFloat
    let yellow: CGFloat
    let key: CGFloat

    init(color: NSColor) {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        red = rgb.redComponent
        green = rgb.greenComponent
        blue = rgb.blueComponent
        alpha = rgb.alphaComponent

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var ignoredAlpha: CGFloat = 0
        rgb.getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &ignoredAlpha
        )
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness

        let key = 1 - max(red, max(green, blue))
        self.key = key
        if key >= 1 - 0.000_001 {
            cyan = 0
            magenta = 0
            yellow = 0
        } else {
            let printableRange = 1 - key
            cyan = (1 - red - key) / printableRange
            magenta = (1 - green - key) / printableRange
            yellow = (1 - blue - key) / printableRange
        }
    }

    var red8: Int { Self.byte(red) }
    var green8: Int { Self.byte(green) }
    var blue8: Int { Self.byte(blue) }
    var alpha8: Int { Self.byte(alpha) }
    var hueDegrees: Int {
        let roundedDegrees = Int((hue * 360).rounded())
        return ((roundedDegrees % 360) + 360) % 360
    }
    var saturationPercent: Int { Self.percent(saturation) }
    var brightnessPercent: Int { Self.percent(brightness) }
    var alphaPercent: Int { Self.percent(alpha) }
    var cyanPercent: Int { Self.percent(cyan) }
    var magentaPercent: Int { Self.percent(magenta) }
    var yellowPercent: Int { Self.percent(yellow) }
    var keyPercent: Int { Self.percent(key) }

    var hexadecimalRGBA: String {
        String(
            format: "#%02X%02X%02X%02X",
            red8,
            green8,
            blue8,
            alpha8
        )
    }

    private static func byte(_ value: CGFloat) -> Int {
        min(max(Int((value * 255).rounded()), 0), 255)
    }

    private static func percent(_ value: CGFloat) -> Int {
        min(max(Int((value * 100).rounded()), 0), 100)
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

enum ImageEditorPatchMode: String, CaseIterable, Identifiable {
    case source
    case destination

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.patchMode.\(rawValue)")
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

nonisolated enum ImageEditorAlphaChannelKind: String, CaseIterable, Codable, Hashable, Sendable {
    case alpha
    case spot

    var titleKey: String {
        "imageEditor.channel.kind.\(rawValue)"
    }
}

nonisolated struct ImageEditorPSDSpotColor: Equatable, Codable, Sendable {
    /// PSD DisplayInfo color space identifier.
    var colorSpace: UInt16
    /// The four 16-bit PSD color components, kept losslessly for round-trip export.
    var components: [UInt16]
    /// PSD opacity value (0...65535).
    var opacity: UInt16

    init(
        colorSpace: UInt16 = 0,
        components: [UInt16] = [0, 0, 0, 0],
        opacity: UInt16 = UInt16.max
    ) {
        self.colorSpace = colorSpace
        self.components = Array(components.prefix(4)) + Array(repeating: 0, count: max(0, 4 - components.count))
        self.opacity = opacity
    }
}

nonisolated struct ImageEditorAlphaChannel: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var mask: ImageEditorSelectionMask
    var kind: ImageEditorAlphaChannelKind = .alpha
    var spotColor: ImageEditorPSDSpotColor?

    init(
        id: UUID = UUID(),
        name: String,
        mask: ImageEditorSelectionMask,
        kind: ImageEditorAlphaChannelKind = .alpha,
        spotColor: ImageEditorPSDSpotColor? = nil
    ) {
        self.id = id
        self.name = name
        self.mask = mask
        self.kind = kind
        self.spotColor = spotColor
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, mask, kind, spotColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        mask = try container.decode(ImageEditorSelectionMask.self, forKey: .mask)
        kind = try container.decodeIfPresent(ImageEditorAlphaChannelKind.self, forKey: .kind) ?? .alpha
        spotColor = try container.decodeIfPresent(ImageEditorPSDSpotColor.self, forKey: .spotColor)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(mask, forKey: .mask)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(spotColor, forKey: .spotColor)
    }
}

struct ImageEditorSelection: Equatable, Codable {
    private static let polygonCollinearityTolerance: CGFloat = 0.000_001

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
        guard points.count >= 3,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              containsNoncollinearPoints(points)
        else { return nil }
        return ImageEditorSelection(points: points, isPolygon: true, isInverted: false, rasterMask: nil)
    }

    private static func containsNoncollinearPoints(_ points: [CGPoint]) -> Bool {
        guard let origin = points.first,
              let directionPoint = points.dropFirst().first(where: { point in
                  let deltaX = point.x - origin.x
                  let deltaY = point.y - origin.y
                  return deltaX * deltaX + deltaY * deltaY > polygonCollinearityTolerance
              })
        else { return false }

        let directionX = directionPoint.x - origin.x
        let directionY = directionPoint.y - origin.y
        return points.dropFirst().contains { point in
            let candidateX = point.x - origin.x
            let candidateY = point.y - origin.y
            let crossProduct = directionX * candidateY - directionY * candidateX
            return abs(crossProduct) > polygonCollinearityTolerance
        }
    }

    static func ellipse(_ rect: CGRect, segmentCount: Int = 64) -> ImageEditorSelection? {
        let normalized = rect.standardized
        guard normalized.width > 0, normalized.height > 0 else { return nil }
        let segments = max(16, segmentCount)
        let center = CGPoint(x: normalized.midX, y: normalized.midY)
        let radiusX = normalized.width / 2
        let radiusY = normalized.height / 2
        let points = (0..<segments).map { index in
            let angle = CGFloat(index) / CGFloat(segments) * 2 * .pi
            return CGPoint(
                x: center.x + cos(angle) * radiusX,
                y: center.y + sin(angle) * radiusY
            )
        }
        return polygon(points)
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

    /// Fast canvas-space hit testing for pointer feedback. Raster selections
    /// already store a complete mask, so sampling it directly avoids
    /// re-rendering the entire canvas for every mouse-move event.
    func contains(_ point: CGPoint, canvasSize: CGSize) -> Bool {
        guard point.x >= 0,
              point.y >= 0,
              point.x < canvasSize.width,
              point.y < canvasSize.height
        else { return false }

        let containsPoint: Bool
        if let rasterMask,
           rasterMask.width > 0,
           rasterMask.height > 0,
           rasterMask.alpha.count == rasterMask.width * rasterMask.height {
            let x = min(
                rasterMask.width - 1,
                Int(point.x / max(canvasSize.width, 1) * CGFloat(rasterMask.width))
            )
            let y = min(
                rasterMask.height - 1,
                Int(point.y / max(canvasSize.height, 1) * CGFloat(rasterMask.height))
            )
            containsPoint = rasterMask.alpha[y * rasterMask.width + x] > 0
        } else {
            containsPoint = contains(point)
        }
        return isInverted ? !containsPoint : containsPoint
    }

    /// A conservative canvas-space coverage check used to avoid rendering
    /// pixel edits that cannot touch a layer. Expansion preserves feathered
    /// or stroked edges, while malformed raster masks fail open so the real
    /// operation can report its validation error instead of hiding it.
    func mayAffect(
        layerFrame: CGRect,
        canvasSize: CGSize,
        expansion: CGFloat = 0
    ) -> Bool {
        if let rasterMask {
            guard rasterMask.width > 0, rasterMask.height > 0 else { return true }
            let (pixelCount, overflow) = rasterMask.width.multipliedReportingOverflow(
                by: rasterMask.height
            )
            guard !overflow, rasterMask.alpha.count == pixelCount else { return true }
        }
        guard let selectedBounds = effectiveSelectedBounds(in: canvasSize) else {
            return false
        }
        let radius = max(0, expansion)
        return selectedBounds.standardized
            .insetBy(dx: -radius, dy: -radius)
            .intersects(layerFrame.standardized)
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

struct ImageEditorSolidColorFillContent: Equatable, Codable {
    var red: Double = 1
    var green: Double = 0
    var blue: Double = 0

    func normalized() -> ImageEditorSolidColorFillContent {
        ImageEditorSolidColorFillContent(
            red: Self.zeroOne(red),
            green: Self.zeroOne(green),
            blue: Self.zeroOne(blue)
        )
    }

    var color: NSColor {
        let content = normalized()
        return NSColor(deviceRed: content.red, green: content.green, blue: content.blue, alpha: 1)
    }

    func renderedImage(size: CGSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }

    private static func zeroOne(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}

struct ImageEditorPatternFillContent: Equatable, Codable {
    var kind: ImageEditorPatternOverlayKind = .checkerboard
    var red: Double = 0.10
    var green: Double = 0.24
    var blue: Double = 0.95
    var opacity: Double = 0.55
    var scale: CGFloat = 16
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0

    init(
        kind: ImageEditorPatternOverlayKind = .checkerboard,
        red: Double = 0.10,
        green: Double = 0.24,
        blue: Double = 0.95,
        opacity: Double = 0.55,
        scale: CGFloat = 16,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0
    ) {
        self.kind = kind
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    func normalized() -> ImageEditorPatternFillContent {
        ImageEditorPatternFillContent(
            kind: kind,
            red: Self.zeroOne(red),
            green: Self.zeroOne(green),
            blue: Self.zeroOne(blue),
            opacity: max(0.05, min(1, opacity)),
            scale: max(6, min(64, scale)),
            offsetX: Self.normalizedOffset(offsetX),
            offsetY: Self.normalizedOffset(offsetY)
        )
    }

    var color: NSColor {
        let content = normalized()
        return NSColor(calibratedRed: content.red, green: content.green, blue: content.blue, alpha: 1)
    }

    func renderedImage(size: CGSize) -> NSImage {
        let content = normalized()
        return NSImage.rendered(size: size) { rect in
            let context = NSGraphicsContext.current
            let originalPatternPhase = context?.patternPhase ?? .zero
            context?.patternPhase = CGPoint(x: content.offsetX, y: content.offsetY)
            defer {
                context?.patternPhase = originalPatternPhase
            }
            NSColor(patternImage: content.kind.tileImage(
                color: content.color,
                opacity: CGFloat(content.opacity),
                scale: content.scale
            )).setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }

    private static func zeroOne(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private static func normalizedOffset(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return max(-128, min(128, value))
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case red
        case green
        case blue
        case opacity
        case scale
        case offsetX
        case offsetY
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(ImageEditorPatternOverlayKind.self, forKey: .kind)
        red = try container.decode(Double.self, forKey: .red)
        green = try container.decode(Double.self, forKey: .green)
        blue = try container.decode(Double.self, forKey: .blue)
        opacity = try container.decode(Double.self, forKey: .opacity)
        scale = try container.decode(CGFloat.self, forKey: .scale)
        offsetX = try container.decodeIfPresent(CGFloat.self, forKey: .offsetX) ?? 0
        offsetY = try container.decodeIfPresent(CGFloat.self, forKey: .offsetY) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        let content = normalized()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content.kind, forKey: .kind)
        try container.encode(content.red, forKey: .red)
        try container.encode(content.green, forKey: .green)
        try container.encode(content.blue, forKey: .blue)
        try container.encode(content.opacity, forKey: .opacity)
        try container.encode(content.scale, forKey: .scale)
        try container.encode(content.offsetX, forKey: .offsetX)
        try container.encode(content.offsetY, forKey: .offsetY)
    }
}

enum ImageEditorGradientFillPreset: String, CaseIterable, Identifiable {
    case blackWhite
    case sunset
    case blueOrange
    case purpleTeal
    case foregroundBackground
    case custom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.gradientFill.preset.\(rawValue)")
    }
}

enum ImageEditorGradientFillStyle: String, CaseIterable, Identifiable {
    case linear
    case radial
    case angle
    case reflected
    case diamond

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.gradientFill.style.\(rawValue)")
    }
}

struct ImageEditorGradientColorStop: Equatable, Codable, Sendable {
    static let defaultMidpoint = 0.5
    static let defaultAlpha = 1.0

    var position: Double
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    var midpoint: Double

    enum CodingKeys: String, CodingKey {
        case position
        case red
        case green
        case blue
        case alpha
        case midpoint
    }

    init(
        position: Double,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = Self.defaultAlpha,
        midpoint: Double = Self.defaultMidpoint
    ) {
        self.position = position
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.midpoint = midpoint
    }

    init(
        position: Double,
        color: NSColor,
        midpoint: Double = Self.defaultMidpoint
    ) {
        let resolved = color.usingColorSpace(.deviceRGB) ?? .black
        self.init(
            position: position,
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent),
            alpha: Double(resolved.alphaComponent),
            midpoint: midpoint
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decode(Double.self, forKey: .position)
        red = try container.decode(Double.self, forKey: .red)
        green = try container.decode(Double.self, forKey: .green)
        blue = try container.decode(Double.self, forKey: .blue)
        alpha = try container.decodeIfPresent(Double.self, forKey: .alpha)
            ?? Self.defaultAlpha
        midpoint = try container.decodeIfPresent(Double.self, forKey: .midpoint)
            ?? Self.defaultMidpoint
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position, forKey: .position)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(alpha, forKey: .alpha)
        try container.encode(midpoint, forKey: .midpoint)
    }

    var color: NSColor {
        NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
    }

    func normalized() -> ImageEditorGradientColorStop {
        ImageEditorGradientColorStop(
            position: max(0, min(1, position.isFinite ? position : 0)),
            red: max(0, min(1, red.isFinite ? red : 0)),
            green: max(0, min(1, green.isFinite ? green : 0)),
            blue: max(0, min(1, blue.isFinite ? blue : 0)),
            alpha: max(0, min(1, alpha.isFinite ? alpha : Self.defaultAlpha)),
            midpoint: max(
                0,
                min(1, midpoint.isFinite ? midpoint : Self.defaultMidpoint)
            )
        )
    }

    var vector: SIMD3<Double> {
        let value = normalized()
        return SIMD3<Double>(value.red, value.green, value.blue)
    }

    var rgbaVector: SIMD4<Double> {
        let value = normalized()
        return SIMD4<Double>(value.red, value.green, value.blue, value.alpha)
    }

    func interpolationAmount(to upper: ImageEditorGradientColorStop, at position: Double) -> Double {
        let lower = normalized()
        let upper = upper.normalized()
        let distance = upper.position - lower.position
        guard distance > 0.000_001 else { return 1 }
        let linearAmount = max(0, min(1, (position - lower.position) / distance))
        if linearAmount <= lower.midpoint {
            guard lower.midpoint > 0.000_001 else { return linearAmount == 0 ? 0 : 0.5 }
            return 0.5 * linearAmount / lower.midpoint
        }
        guard lower.midpoint < 0.999_999 else { return linearAmount == 1 ? 1 : 0.5 }
        return 0.5 + 0.5 * (linearAmount - lower.midpoint) / (1 - lower.midpoint)
    }
}

struct ImageEditorGradientFillContent: Equatable, Codable {
    static let maximumColorStopCount = 16
    private static let bayer4x4 = [
        0, 8, 2, 10,
        12, 4, 14, 6,
        3, 11, 1, 9,
        15, 7, 13, 5
    ]

    var preset: ImageEditorGradientFillPreset = .blueOrange
    var style: ImageEditorGradientFillStyle = .linear
    var reverse: Bool = false
    var dither: Bool = false
    var angle: CGFloat = 0
    var scale: CGFloat = 1
    var startRed: Double = 0.12
    var startGreen: Double = 0.20
    var startBlue: Double = 0.95
    var endRed: Double = 1.0
    var endGreen: Double = 0.50
    var endBlue: Double = 0.10
    var colorStops: [ImageEditorGradientColorStop]? = nil

    enum CodingKeys: String, CodingKey {
        case preset
        case style
        case reverse
        case dither
        case angle
        case scale
        case startRed
        case startGreen
        case startBlue
        case endRed
        case endGreen
        case endBlue
        case colorStops
    }

    init(
        preset: ImageEditorGradientFillPreset = .blueOrange,
        style: ImageEditorGradientFillStyle = .linear,
        reverse: Bool = false,
        dither: Bool = false,
        angle: CGFloat = 0,
        scale: CGFloat = 1,
        startRed: Double = 0.12,
        startGreen: Double = 0.20,
        startBlue: Double = 0.95,
        endRed: Double = 1.0,
        endGreen: Double = 0.50,
        endBlue: Double = 0.10,
        colorStops: [ImageEditorGradientColorStop]? = nil
    ) {
        self.preset = preset
        self.style = style
        self.reverse = reverse
        self.dither = dither
        self.angle = angle
        self.scale = scale
        self.startRed = startRed
        self.startGreen = startGreen
        self.startBlue = startBlue
        self.endRed = endRed
        self.endGreen = endGreen
        self.endBlue = endBlue
        self.colorStops = colorStops
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preset = try container.decodeIfPresent(ImageEditorGradientFillPreset.self, forKey: .preset) ?? .blueOrange
        style = try container.decodeIfPresent(ImageEditorGradientFillStyle.self, forKey: .style) ?? .linear
        reverse = try container.decodeIfPresent(Bool.self, forKey: .reverse) ?? false
        dither = try container.decodeIfPresent(Bool.self, forKey: .dither) ?? false
        angle = try container.decodeIfPresent(CGFloat.self, forKey: .angle) ?? 0
        scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1
        startRed = try container.decodeIfPresent(Double.self, forKey: .startRed) ?? 0.12
        startGreen = try container.decodeIfPresent(Double.self, forKey: .startGreen) ?? 0.20
        startBlue = try container.decodeIfPresent(Double.self, forKey: .startBlue) ?? 0.95
        endRed = try container.decodeIfPresent(Double.self, forKey: .endRed) ?? 1.0
        endGreen = try container.decodeIfPresent(Double.self, forKey: .endGreen) ?? 0.50
        endBlue = try container.decodeIfPresent(Double.self, forKey: .endBlue) ?? 0.10
        colorStops = try container.decodeIfPresent(
            [ImageEditorGradientColorStop].self,
            forKey: .colorStops
        )
    }

    func normalized() -> ImageEditorGradientFillContent {
        let stops = Self.normalizedColorStops(colorStops)
        let first = stops?.first
        let last = stops?.last
        return ImageEditorGradientFillContent(
            preset: preset,
            style: style,
            reverse: reverse,
            dither: dither,
            angle: max(-180, min(180, angle)),
            scale: max(0.25, min(4, scale)),
            startRed: first?.red ?? Self.zeroOne(startRed),
            startGreen: first?.green ?? Self.zeroOne(startGreen),
            startBlue: first?.blue ?? Self.zeroOne(startBlue),
            endRed: last?.red ?? Self.zeroOne(endRed),
            endGreen: last?.green ?? Self.zeroOne(endGreen),
            endBlue: last?.blue ?? Self.zeroOne(endBlue),
            colorStops: stops
        )
    }

    func colors(foreground: NSColor = .systemRed, background: NSColor = .clear) -> (start: SIMD3<Double>, end: SIMD3<Double>) {
        let content = normalized()
        if let stops = content.colorStops, let first = stops.first, let last = stops.last {
            return (first.vector, last.vector)
        }
        switch content.preset {
        case .blackWhite:
            return (SIMD3<Double>(0, 0, 0), SIMD3<Double>(1, 1, 1))
        case .sunset:
            return (SIMD3<Double>(0.15, 0.04, 0.35), SIMD3<Double>(1.0, 0.55, 0.10))
        case .blueOrange:
            return (SIMD3<Double>(0.10, 0.24, 0.95), SIMD3<Double>(1.0, 0.50, 0.12))
        case .purpleTeal:
            return (SIMD3<Double>(0.45, 0.16, 0.80), SIMD3<Double>(0.05, 0.78, 0.72))
        case .foregroundBackground:
            return (Self.rgbVector(foreground), Self.rgbVector(background))
        case .custom:
            return (
                SIMD3<Double>(content.startRed, content.startGreen, content.startBlue),
                SIMD3<Double>(content.endRed, content.endGreen, content.endBlue)
            )
        }
    }

    func renderedImage(
        size: CGSize,
        foreground: NSColor = .systemRed,
        background: NSColor = .clear,
        centerNormalized: CGPoint = CGPoint(x: 0.5, y: 0.5),
        opacity: Double = 1
    ) -> NSImage {
        let content = normalized()
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let resolvedColors = content.colors(foreground: foreground, background: background)
        var stops = content.colorStops ?? [
            ImageEditorGradientColorStop(
                position: 0,
                red: resolvedColors.start.x,
                green: resolvedColors.start.y,
                blue: resolvedColors.start.z
            ),
            ImageEditorGradientColorStop(
                position: 1,
                red: resolvedColors.end.x,
                green: resolvedColors.end.y,
                blue: resolvedColors.end.z
            )
        ]
        if content.reverse {
            let forwardStops = stops
            stops = forwardStops.indices.reversed().map { index in
                let stop = forwardStops[index]
                return ImageEditorGradientColorStop(
                    position: 1 - stop.position,
                    red: stop.red,
                    green: stop.green,
                    blue: stop.blue,
                    alpha: stop.alpha,
                    midpoint: index > forwardStops.startIndex
                        ? 1 - forwardStops[index - 1].midpoint
                        : 0.5
                )
            }
        }
        let radians = Double(content.angle) * Double.pi / 180
        let direction = SIMD2<Double>(cos(radians), sin(radians))
        let span = max(1, abs(direction.x) * Double(width) + abs(direction.y) * Double(height)) * Double(content.scale)
        let center = SIMD2<Double>(
            Double(width) * Double(centerNormalized.x) - 0.5,
            Double(height) * Double(centerNormalized.y) - 0.5
        )
        let cornerDistance = max(
            1,
            hypot(Double(width - 1) / 2, Double(height - 1) / 2) * Double(content.scale)
        )

        for y in 0..<height {
            for x in 0..<width {
                let point = SIMD2<Double>(Double(x), Double(y))
                let rawProgress = content.progress(
                    at: point,
                    center: center,
                    direction: direction,
                    span: span,
                    cornerDistance: cornerDistance
                )
                let t = content.dither
                    ? Self.ditheredProgress(rawProgress, x: x, y: y)
                    : rawProgress
                let color = Self.interpolatedColor(at: t, stops: stops)
                let alpha = Self.zeroOne(color.w * opacity)
                let offset = y * bytesPerRow + x * bytesPerPixel
                pixels[offset] = Self.byte(color.x * alpha)
                pixels[offset + 1] = Self.byte(color.y * alpha)
                pixels[offset + 2] = Self.byte(color.z * alpha)
                pixels[offset + 3] = Self.byte(alpha)
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return NSImage.transparent(size: size) }

        return NSImage(cgImage: image, size: size)
    }

    static func ditheredProgress(_ progress: Double, x: Int, y: Int) -> Double {
        let threshold = (Double(bayer4x4[(y & 3) * 4 + (x & 3)]) + 0.5) / 16
        return max(0, min(1, progress + (threshold - 0.5) / 96))
    }

    private func progress(
        at point: SIMD2<Double>,
        center: SIMD2<Double>,
        direction: SIMD2<Double>,
        span: Double,
        cornerDistance: Double
    ) -> Double {
        let delta = point - center
        switch style {
        case .linear:
            let projection = simd_dot(delta, direction)
            return Self.zeroOne(0.5 + projection / span)
        case .radial:
            return Self.zeroOne(hypot(delta.x, delta.y) / cornerDistance)
        case .angle:
            guard abs(delta.x) > 0.000_001 || abs(delta.y) > 0.000_001 else { return 0 }
            let startAngle = atan2(direction.y, direction.x)
            let turns = (atan2(delta.y, delta.x) - startAngle) / (2 * Double.pi)
            return turns - floor(turns)
        case .reflected:
            let projection = abs(simd_dot(delta, direction))
            return Self.zeroOne((projection * 2) / span)
        case .diamond:
            let xAxis = direction
            let yAxis = SIMD2<Double>(-direction.y, direction.x)
            let projectedX = abs(simd_dot(delta, xAxis))
            let projectedY = abs(simd_dot(delta, yAxis))
            return Self.zeroOne((projectedX + projectedY) / cornerDistance)
        }
    }

    private static func rgbVector(_ color: NSColor) -> SIMD3<Double> {
        let rgb = color.usingColorSpace(.deviceRGB) ?? .black
        return SIMD3<Double>(
            zeroOne(Double(rgb.redComponent)),
            zeroOne(Double(rgb.greenComponent)),
            zeroOne(Double(rgb.blueComponent))
        )
    }

    private static func normalizedColorStops(
        _ stops: [ImageEditorGradientColorStop]?
    ) -> [ImageEditorGradientColorStop]? {
        guard let stops, stops.count >= 2 else { return nil }
        return Array(stops.prefix(maximumColorStopCount))
            .map { $0.normalized() }
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.position == rhs.element.position {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.position < rhs.element.position
            }
            .map(\.element)
    }

    private static func interpolatedColor(
        at progress: Double,
        stops: [ImageEditorGradientColorStop]
    ) -> SIMD4<Double> {
        guard let first = stops.first, let last = stops.last else { return .zero }
        if progress <= first.position { return first.rgbaVector }
        if progress >= last.position { return last.rgbaVector }
        for index in 1..<stops.count {
            let upper = stops[index]
            guard progress <= upper.position else { continue }
            let lower = stops[index - 1]
            let amount = lower.interpolationAmount(to: upper, at: progress)
            return lower.rgbaVector + (upper.rgbaVector - lower.rgbaVector) * amount
        }
        return last.rgbaVector
    }

    private static func zeroOne(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, (zeroOne(value) * 255).rounded())))
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
    var vibranceAmount: Double = 0
    var vibranceSaturation: Double = 0
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
    var gradientMapDither: Bool = false
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
            vibranceAmount: Self.unit(vibranceAmount),
            vibranceSaturation: Self.unit(vibranceSaturation),
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
            gradientMapDither: gradientMapDither,
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
        case vibranceAmount
        case vibranceSaturation
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
        case gradientMapDither
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
        vibranceAmount = try container.decodeIfPresent(Double.self, forKey: .vibranceAmount) ?? 0
        vibranceSaturation = try container.decodeIfPresent(Double.self, forKey: .vibranceSaturation) ?? 0
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
        gradientMapDither = try container.decodeIfPresent(Bool.self, forKey: .gradientMapDither) ?? false
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
        try container.encode(vibranceAmount, forKey: .vibranceAmount)
        try container.encode(vibranceSaturation, forKey: .vibranceSaturation)
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
        try container.encode(gradientMapDither, forKey: .gradientMapDither)
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

    init(
        id: UUID = UUID(),
        kind: ImageEditorFilter,
        intensity: Double,
        settings: ImageEditorFilterSettings = ImageEditorFilterSettings(),
        isEnabled: Bool = true,
        opacity: Double = 1,
        blendMode: ImageEditorBlendMode = .normal,
        appliesToBackdrop: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.intensity = intensity
        self.settings = settings
        self.isEnabled = isEnabled
        self.opacity = max(0, min(1, opacity))
        self.blendMode = blendMode == .passThrough ? .normal : blendMode
        self.appliesToBackdrop = appliesToBackdrop
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
        settings.normalized()
    }
}

struct ImageEditorFilterSettings: Equatable, Codable {
    /// When present, Gaussian blur uses this pixel radius instead of the UI's normalized intensity.
    /// Figma layer-blur imports use this to retain the source radius across project round-trips.
    var gaussianBlurRadius: Double?
    /// Explicit High Pass radius in pixels. Nil preserves the legacy intensity-derived radius.
    var highPassRadius: Double?
    /// Explicit Minimum/Maximum radius in pixels. Nil preserves the legacy intensity-derived radius.
    var morphologyRadius: Double?
    /// Explicit Pixelate/Mosaic cell size in pixels. Nil preserves the legacy intensity-derived scale.
    var pixelateCellSize: Double?
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
    /// Vignette feather start as a normalized radius. Nil preserves the legacy 28% midpoint.
    var vignetteMidpoint: Double?
    /// Oil Paint neighborhood radius in pixels. Nil preserves the legacy intensity-derived radius.
    var oilPaintRadius: Double?
    var unsharpRadius: Double = 1
    var unsharpThreshold: Double = 0
    var liquifyPushX: Double = 0.25
    var liquifyPushY: Double = 0
    var liquifyTwirlAngle: Double = 0.5
    var liquifyBulgeAmount: Double = 0.5
    var offsetX: Double = 0.25
    var offsetY: Double = 0
    var offsetUndefinedAreaMode = ImageEditorOffsetUndefinedAreaMode.wrapAround
    var waveAmplitude: Double = 0.5
    var waveFrequency: Double = 0.25
    var rippleAmount: Double = 0.5
    var rippleFrequency: Double = 0.25
    var pinchAmount: Double = 0.5
    var spherizeAmount: Double = 0.5
    var lensDistortion: Double = 0.35

    init(
        gaussianBlurRadius: Double? = nil,
        highPassRadius: Double? = nil,
        morphologyRadius: Double? = nil,
        pixelateCellSize: Double? = nil,
        addNoiseMonochromatic: Bool? = nil,
        addNoiseDistribution: ImageEditorAddNoiseDistribution? = nil,
        motionBlurAngleDegrees: Double? = nil,
        motionBlurDistance: Double? = nil,
        embossAngleDegrees: Double? = nil,
        embossHeight: Double? = nil,
        vignetteMidpoint: Double? = nil,
        oilPaintRadius: Double? = nil,
        unsharpRadius: Double = 1,
        unsharpThreshold: Double = 0,
        liquifyPushX: Double = 0.25,
        liquifyPushY: Double = 0,
        liquifyTwirlAngle: Double = 0.5,
        liquifyBulgeAmount: Double = 0.5,
        offsetX: Double = 0.25,
        offsetY: Double = 0,
        offsetUndefinedAreaMode: ImageEditorOffsetUndefinedAreaMode = .wrapAround,
        waveAmplitude: Double = 0.5,
        waveFrequency: Double = 0.25,
        rippleAmount: Double = 0.5,
        rippleFrequency: Double = 0.25,
        pinchAmount: Double = 0.5,
        spherizeAmount: Double = 0.5,
        lensDistortion: Double = 0.35
    ) {
        self.gaussianBlurRadius = gaussianBlurRadius
        self.highPassRadius = highPassRadius
        self.morphologyRadius = morphologyRadius
        self.pixelateCellSize = pixelateCellSize
        self.addNoiseMonochromatic = addNoiseMonochromatic
        self.addNoiseDistribution = addNoiseDistribution
        self.motionBlurAngleDegrees = motionBlurAngleDegrees
        self.motionBlurDistance = motionBlurDistance
        self.embossAngleDegrees = embossAngleDegrees
        self.embossHeight = embossHeight
        self.vignetteMidpoint = vignetteMidpoint
        self.oilPaintRadius = oilPaintRadius
        self.unsharpRadius = unsharpRadius
        self.unsharpThreshold = unsharpThreshold
        self.liquifyPushX = liquifyPushX
        self.liquifyPushY = liquifyPushY
        self.liquifyTwirlAngle = liquifyTwirlAngle
        self.liquifyBulgeAmount = liquifyBulgeAmount
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.offsetUndefinedAreaMode = offsetUndefinedAreaMode
        self.waveAmplitude = waveAmplitude
        self.waveFrequency = waveFrequency
        self.rippleAmount = rippleAmount
        self.rippleFrequency = rippleFrequency
        self.pinchAmount = pinchAmount
        self.spherizeAmount = spherizeAmount
        self.lensDistortion = lensDistortion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gaussianBlurRadius = try container.decodeIfPresent(Double.self, forKey: .gaussianBlurRadius)
        highPassRadius = try container.decodeIfPresent(Double.self, forKey: .highPassRadius)
        morphologyRadius = try container.decodeIfPresent(Double.self, forKey: .morphologyRadius)
        pixelateCellSize = try container.decodeIfPresent(Double.self, forKey: .pixelateCellSize)
        addNoiseMonochromatic = try container.decodeIfPresent(Bool.self, forKey: .addNoiseMonochromatic)
        addNoiseDistribution = try container.decodeIfPresent(
            ImageEditorAddNoiseDistribution.self,
            forKey: .addNoiseDistribution
        )
        motionBlurAngleDegrees = try container.decodeIfPresent(Double.self, forKey: .motionBlurAngleDegrees)
        motionBlurDistance = try container.decodeIfPresent(Double.self, forKey: .motionBlurDistance)
        embossAngleDegrees = try container.decodeIfPresent(Double.self, forKey: .embossAngleDegrees)
        embossHeight = try container.decodeIfPresent(Double.self, forKey: .embossHeight)
        vignetteMidpoint = try container.decodeIfPresent(Double.self, forKey: .vignetteMidpoint)
        oilPaintRadius = try container.decodeIfPresent(Double.self, forKey: .oilPaintRadius)
        unsharpRadius = try container.decodeIfPresent(Double.self, forKey: .unsharpRadius) ?? 1
        unsharpThreshold = try container.decodeIfPresent(Double.self, forKey: .unsharpThreshold) ?? 0
        liquifyPushX = try container.decodeIfPresent(Double.self, forKey: .liquifyPushX) ?? 0.25
        liquifyPushY = try container.decodeIfPresent(Double.self, forKey: .liquifyPushY) ?? 0
        liquifyTwirlAngle = try container.decodeIfPresent(Double.self, forKey: .liquifyTwirlAngle) ?? 0.5
        liquifyBulgeAmount = try container.decodeIfPresent(Double.self, forKey: .liquifyBulgeAmount) ?? 0.5
        offsetX = try container.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0.25
        offsetY = try container.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0
        offsetUndefinedAreaMode = try container.decodeIfPresent(
            ImageEditorOffsetUndefinedAreaMode.self,
            forKey: .offsetUndefinedAreaMode
        ) ?? .wrapAround
        waveAmplitude = try container.decodeIfPresent(Double.self, forKey: .waveAmplitude) ?? 0.5
        waveFrequency = try container.decodeIfPresent(Double.self, forKey: .waveFrequency) ?? 0.25
        rippleAmount = try container.decodeIfPresent(Double.self, forKey: .rippleAmount) ?? 0.5
        rippleFrequency = try container.decodeIfPresent(Double.self, forKey: .rippleFrequency) ?? 0.25
        pinchAmount = try container.decodeIfPresent(Double.self, forKey: .pinchAmount) ?? 0.5
        spherizeAmount = try container.decodeIfPresent(Double.self, forKey: .spherizeAmount) ?? 0.5
        lensDistortion = try container.decodeIfPresent(Double.self, forKey: .lensDistortion) ?? 0.35
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(gaussianBlurRadius, forKey: .gaussianBlurRadius)
        try container.encodeIfPresent(highPassRadius, forKey: .highPassRadius)
        try container.encodeIfPresent(morphologyRadius, forKey: .morphologyRadius)
        try container.encodeIfPresent(pixelateCellSize, forKey: .pixelateCellSize)
        try container.encodeIfPresent(addNoiseMonochromatic, forKey: .addNoiseMonochromatic)
        try container.encodeIfPresent(addNoiseDistribution, forKey: .addNoiseDistribution)
        try container.encodeIfPresent(motionBlurAngleDegrees, forKey: .motionBlurAngleDegrees)
        try container.encodeIfPresent(motionBlurDistance, forKey: .motionBlurDistance)
        try container.encodeIfPresent(embossAngleDegrees, forKey: .embossAngleDegrees)
        try container.encodeIfPresent(embossHeight, forKey: .embossHeight)
        try container.encodeIfPresent(vignetteMidpoint, forKey: .vignetteMidpoint)
        try container.encodeIfPresent(oilPaintRadius, forKey: .oilPaintRadius)
        try container.encode(unsharpRadius, forKey: .unsharpRadius)
        try container.encode(unsharpThreshold, forKey: .unsharpThreshold)
        try container.encode(liquifyPushX, forKey: .liquifyPushX)
        try container.encode(liquifyPushY, forKey: .liquifyPushY)
        try container.encode(liquifyTwirlAngle, forKey: .liquifyTwirlAngle)
        try container.encode(liquifyBulgeAmount, forKey: .liquifyBulgeAmount)
        try container.encode(offsetX, forKey: .offsetX)
        try container.encode(offsetY, forKey: .offsetY)
        try container.encode(offsetUndefinedAreaMode, forKey: .offsetUndefinedAreaMode)
        try container.encode(waveAmplitude, forKey: .waveAmplitude)
        try container.encode(waveFrequency, forKey: .waveFrequency)
        try container.encode(rippleAmount, forKey: .rippleAmount)
        try container.encode(rippleFrequency, forKey: .rippleFrequency)
        try container.encode(pinchAmount, forKey: .pinchAmount)
        try container.encode(spherizeAmount, forKey: .spherizeAmount)
        try container.encode(lensDistortion, forKey: .lensDistortion)
    }

    func normalized() -> ImageEditorFilterSettings {
        ImageEditorFilterSettings(
            gaussianBlurRadius: gaussianBlurRadius.map { max(0, min(256, $0)) },
            highPassRadius: highPassRadius.map { max(1, min(256, $0)) },
            morphologyRadius: morphologyRadius.map { max(1, min(256, $0)) },
            pixelateCellSize: pixelateCellSize.map { max(2, min(200, $0)) },
            addNoiseMonochromatic: addNoiseMonochromatic,
            addNoiseDistribution: addNoiseDistribution,
            motionBlurAngleDegrees: motionBlurAngleDegrees.map { max(-180, min(180, $0)) },
            motionBlurDistance: motionBlurDistance.map { max(1, min(999, $0)) },
            embossAngleDegrees: embossAngleDegrees.map { max(-180, min(180, $0)) },
            embossHeight: embossHeight.map { max(1, min(10, $0)) },
            vignetteMidpoint: vignetteMidpoint.map { max(0, min(0.95, $0)) },
            oilPaintRadius: oilPaintRadius.map { max(1, min(10, $0)) },
            unsharpRadius: max(0.5, min(5, unsharpRadius)),
            unsharpThreshold: max(0, min(1, unsharpThreshold)),
            liquifyPushX: max(-1, min(1, liquifyPushX)),
            liquifyPushY: max(-1, min(1, liquifyPushY)),
            liquifyTwirlAngle: max(-1, min(1, liquifyTwirlAngle)),
            liquifyBulgeAmount: max(-1, min(1, liquifyBulgeAmount)),
            offsetX: max(-1, min(1, offsetX)),
            offsetY: max(-1, min(1, offsetY)),
            offsetUndefinedAreaMode: offsetUndefinedAreaMode,
            waveAmplitude: max(-1, min(1, waveAmplitude)),
            waveFrequency: max(0, min(1, waveFrequency)),
            rippleAmount: max(-1, min(1, rippleAmount)),
            rippleFrequency: max(0, min(1, rippleFrequency)),
            pinchAmount: max(-1, min(1, pinchAmount)),
            spherizeAmount: max(-1, min(1, spherizeAmount)),
            lensDistortion: max(-1, min(1, lensDistortion))
        )
    }

    private enum CodingKeys: String, CodingKey {
        case gaussianBlurRadius
        case highPassRadius
        case morphologyRadius
        case pixelateCellSize
        case addNoiseMonochromatic
        case addNoiseDistribution
        case motionBlurAngleDegrees
        case motionBlurDistance
        case embossAngleDegrees
        case embossHeight
        case vignetteMidpoint
        case oilPaintRadius
        case unsharpRadius
        case unsharpThreshold
        case liquifyPushX
        case liquifyPushY
        case liquifyTwirlAngle
        case liquifyBulgeAmount
        case offsetX
        case offsetY
        case offsetUndefinedAreaMode
        case waveAmplitude
        case waveFrequency
        case rippleAmount
        case rippleFrequency
        case pinchAmount
        case spherizeAmount
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

enum ImageEditorTextAlignment: String, CaseIterable, Identifiable {
    case left
    case center
    case right
    case justified

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
        case .justified:
            return .justified
        }
    }
}

enum ImageEditorTextCase: String, CaseIterable, Codable, Sendable, Identifiable {
    case original
    case uppercase
    case lowercase
    case titleCase
    case smallCaps

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.textCase.\(rawValue)")
    }

    func applying(to text: String) -> String {
        switch self {
        case .original:
            text
        case .uppercase:
            text.uppercased()
        case .lowercase:
            text.lowercased()
        case .titleCase:
            text.capitalized
        case .smallCaps:
            text.uppercased()
        }
    }
}

enum ImageEditorTextVerticalAlignment: String, CaseIterable, Codable, Sendable, Identifiable {
    case top
    case center
    case bottom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.textVerticalAlignment.\(rawValue)")
    }
}

struct ImageEditorTextContent {
    static let drawingPadding: CGFloat = 4
    static let maximumBoxDimension: CGFloat = 12_000
    static let minimumFontSize: CGFloat = 6
    static let maximumFontSize: CGFloat = 240
    static let minimumCharacterSpacing: CGFloat = -8
    static let maximumCharacterSpacing: CGFloat = 48
    static let maximumLineSpacing: CGFloat = 96
    static let maximumFirstLineIndent: CGFloat = 800
    static let maximumParagraphSpacing: CGFloat = 400
    static let smallCapsScale: CGFloat = 0.8
    static let systemFontFamilyName = NSFont.systemFont(ofSize: NSFont.systemFontSize).familyName ?? "System"

    var text: String
    var color: NSColor
    var fontSize: CGFloat
    var fontFamilyName: String = Self.systemFontFamilyName
    var point: CGPoint
    var isBold = false
    var isItalic = false
    var isUnderlined = false
    var isStruckThrough = false
    var characterSpacing: CGFloat = 0
    var lineSpacing: CGFloat = 0
    var boxWidth: CGFloat = 0
    var boxHeight: CGFloat = 0
    var alignment: ImageEditorTextAlignment = .left
    var leftIndent: CGFloat = 0
    var rightIndent: CGFloat = 0
    var firstLineIndent: CGFloat = 0
    var paragraphSpacing: CGFloat = 0
    var textCase: ImageEditorTextCase = .original
    var truncatesOverflow = false
    var verticalAlignment: ImageEditorTextVerticalAlignment = .top

    var displayText: String {
        textCase.applying(to: text)
    }

    var font: NSFont {
        let size = max(Self.minimumFontSize, min(Self.maximumFontSize, fontSize))
        var traits: NSFontTraitMask = []
        if isBold { traits.insert(.boldFontMask) }
        if isItalic { traits.insert(.italicFontMask) }
        let familyFont = fontFamilyName == Self.systemFontFamilyName ? nil : NSFontManager.shared.font(
            withFamily: fontFamilyName,
            traits: traits,
            weight: isBold ? 9 : 5,
            size: size
        )
        if let familyFont {
            return familyFont
        }
        let fallback = NSFont.systemFont(ofSize: size, weight: isBold ? .bold : .regular)
        guard isItalic else { return fallback }
        return NSFontManager.shared.convert(fallback, toHaveTrait: .italicFontMask)
    }

    var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment.nsTextAlignment
        style.lineSpacing = max(0, lineSpacing)
        style.headIndent = max(0, leftIndent)
        style.firstLineHeadIndent = max(0, leftIndent + firstLineIndent)
        style.tailIndent = rightIndent > 0 ? -rightIndent : 0
        style.paragraphSpacing = max(0, paragraphSpacing)
        return style
    }

    var drawingOptions: NSString.DrawingOptions {
        var options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        if truncatesOverflow {
            options.insert(.truncatesLastVisibleLine)
        }
        return options
    }

    var attributes: [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .kern: characterSpacing,
            .paragraphStyle: paragraphStyle
        ]
        if isUnderlined {
            result[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if isStruckThrough {
            result[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        return result
    }

    var attributedString: NSAttributedString {
        guard textCase == .smallCaps else {
            return NSAttributedString(string: displayText, attributes: attributes)
        }
        let result = NSMutableAttributedString()
        for character in text {
            let source = String(character)
            let displayed = source.uppercased()
            var characterAttributes = attributes
            if source != displayed, source == source.lowercased() {
                characterAttributes[.font] = font.withSize(max(6, font.pointSize * Self.smallCapsScale))
            }
            result.append(NSAttributedString(string: displayed, attributes: characterAttributes))
        }
        return result
    }

    var requiredParagraphHeight: CGFloat {
        guard boxWidth > 0 else { return 0 }
        let bounding = attributedString.boundingRect(
            with: CGSize(width: max(1, boxWidth), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return max(1, ceil(bounding.height))
    }

    var hasOverflow: Bool {
        boxWidth > 0 && boxHeight > 0 && requiredParagraphHeight > boxHeight + 0.5
    }

    func layerSize() -> CGSize {
        let measured: CGSize
        if boxWidth > 0 {
            measured = CGSize(
                width: boxWidth,
                height: boxHeight > 0 ? boxHeight : requiredParagraphHeight
            )
        } else {
            let lines = displayText.components(separatedBy: .newlines)
            let lineSizes = lines.map { (($0.isEmpty ? " " : $0) as NSString).size(withAttributes: attributes) }
            let width = lineSizes.map(\.width).max() ?? 1
            let height = lineSizes.reduce(CGFloat(0)) { partial, size in partial + size.height }
                + max(0, CGFloat(max(0, lines.count - 1)) * lineSpacing)
                + max(0, CGFloat(max(0, lines.count - 1)) * paragraphSpacing)
            measured = CGSize(width: ceil(width), height: ceil(height))
        }
        return CGSize(
            width: max(1, ceil(measured.width + Self.drawingPadding * 2)),
            height: max(1, ceil(measured.height + Self.drawingPadding * 2))
        )
    }

    func drawingRect(in size: CGSize) -> CGRect {
        let availableHeight = max(1, size.height - point.y - Self.drawingPadding)
        let verticalOffset: CGFloat
        guard boxWidth > 0, boxHeight > 0 else {
            return CGRect(
                x: point.x,
                y: point.y,
                width: max(1, size.width - point.x - Self.drawingPadding),
                height: availableHeight
            )
        }
        let remainingHeight = max(0, boxHeight - requiredParagraphHeight)
        switch verticalAlignment {
        case .top:
            verticalOffset = 0
        case .center:
            verticalOffset = remainingHeight / 2
        case .bottom:
            verticalOffset = remainingHeight
        }
        return CGRect(
            x: point.x,
            y: point.y + verticalOffset,
            width: max(1, size.width - point.x - Self.drawingPadding),
            height: max(1, availableHeight - verticalOffset)
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

enum ImageEditorStrokeCap: String, Codable, CaseIterable {
    case butt
    case round
    case square

    init(figmaValue: String?) {
        switch figmaValue?.uppercased() {
        case "NONE": self = .butt
        case "ROUND": self = .round
        case "SQUARE": self = .square
        default: self = .round
        }
    }

    var nsStyle: NSBezierPath.LineCapStyle {
        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }
}

enum ImageEditorStrokeDecoration: String, Codable, CaseIterable, Identifiable {
    case none
    case openArrow
    case filledArrow
    case filledTriangle
    case filledDiamond
    case filledCircle

    var id: String { rawValue }

    init(figmaValue: String?) {
        switch figmaValue?.uppercased() {
        case "ARROW_LINES": self = .openArrow
        case "ARROW_EQUILATERAL": self = .filledArrow
        case "TRIANGLE_FILLED": self = .filledTriangle
        case "DIAMOND_FILLED": self = .filledDiamond
        case "CIRCLE_FILLED": self = .filledCircle
        default: self = .none
        }
    }
}

enum ImageEditorStrokeJoin: String, Codable, CaseIterable {
    case miter
    case round
    case bevel

    init(figmaValue: String?) {
        switch figmaValue?.uppercased() {
        case "MITER": self = .miter
        case "BEVEL": self = .bevel
        case "ROUND": self = .round
        default: self = .round
        }
    }

    var nsStyle: NSBezierPath.LineJoinStyle {
        switch self {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        }
    }
}

nonisolated enum ImageEditorPathComponentOperation: String, Codable, Equatable, Sendable {
    case exclude
    case combine
    case subtract
    case intersect
    case continuePrevious
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
    static let minimumStrokeWidth: CGFloat = 0.1
    static let maximumStrokeWidth: CGFloat = 96
    static let defaultStrokeMiterLimit: CGFloat = 10
    static let minimumStrokeMiterLimit: CGFloat = 1
    static let maximumStrokeMiterLimit: CGFloat = 1_000
    static let minimumStrokeDashOffset: CGFloat = -2_048
    static let maximumStrokeDashOffset: CGFloat = 2_048

    var kind: ImageEditorShapeKind
    var fillColor: NSColor
    var fillGradient: ImageEditorGradientFillContent? = nil
    var fillGradientCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var fillOpacity: CGFloat
    var strokeColor: NSColor
    var strokeWidth: CGFloat
    var strokeOpacity: CGFloat
    var strokePosition: ImageEditorStrokePosition = .inside
    var strokeCap: ImageEditorStrokeCap = .round
    var strokeStartDecoration: ImageEditorStrokeDecoration = .none
    var strokeEndDecoration: ImageEditorStrokeDecoration = .none
    var strokeJoin: ImageEditorStrokeJoin = .round
    var strokeMiterLimit: CGFloat = Self.defaultStrokeMiterLimit
    var strokeDashPattern: [CGFloat] = []
    var strokeDashOffset: CGFloat = 0
    var cornerRadius: CGFloat = 0
    var cornerRadii: ImageEditorRectangleCornerRadii? = nil
    var cornerSmoothing: CGFloat = 0
    var pathPoints: [CGPoint] = []
    var pathAnchors: [ImageEditorPathAnchor] = []
    var pathSubpaths: [[ImageEditorPathAnchor]] = []
    var pathComponentOperations: [ImageEditorPathComponentOperation] = []
    var pathStartsWithAllPixels = false
    var isPathClosed = true

    func normalized(size: CGSize) -> ImageEditorShapeContent {
        var content = self
        content.fillGradient = fillGradient?.normalized()
        content.fillGradientCenter = CGPoint(
            x: Self.normalizedGradientCenterComponent(fillGradientCenter.x),
            y: Self.normalizedGradientCenterComponent(fillGradientCenter.y)
        )
        content.fillOpacity = max(0, min(1, fillOpacity))
        content.strokeOpacity = max(0, min(1, strokeOpacity))
        content.strokeMiterLimit = max(
            Self.minimumStrokeMiterLimit,
            min(
                Self.maximumStrokeMiterLimit,
                strokeMiterLimit.isFinite ? strokeMiterLimit : Self.defaultStrokeMiterLimit
            )
        )
        content.strokeDashPattern = strokeDashPattern
            .filter { $0.isFinite && $0 > 0 }
            .map { min(2_048, $0) }
        if content.strokeDashPattern.count < 2 {
            content.strokeDashPattern = []
        }
        content.strokeDashOffset = max(
            Self.minimumStrokeDashOffset,
            min(
                Self.maximumStrokeDashOffset,
                strokeDashOffset.isFinite ? strokeDashOffset : 0
            )
        )
        if kind == .path {
            content.strokeWidth = max(Self.minimumStrokeWidth, min(Self.maximumStrokeWidth, strokeWidth))
        } else {
            content.strokeWidth = max(
                Self.minimumStrokeWidth,
                min(Self.maximumStrokeWidth, min(min(size.width, size.height) / 2, strokeWidth))
            )
        }
        if kind == .rectangle {
            content.cornerRadius = max(0, min(min(size.width, size.height) / 2, cornerRadius))
            content.cornerRadii = cornerRadii?.normalized(size: size)
            content.cornerSmoothing = max(0, min(1, cornerSmoothing.isFinite ? cornerSmoothing : 0))
            if let cornerRadii = content.cornerRadii {
                content.cornerRadius = cornerRadii.topLeft
            }
        } else {
            content.cornerRadius = 0
            content.cornerRadii = nil
            content.cornerSmoothing = 0
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
            let booleanMask = normalized.kind == .path
                && normalized.isPathClosed
                && normalized.hasExplicitPathComponentOperations
                ? normalized.renderedPathComponentMask(size: size, inverted: false)
                : nil
            if let booleanMask {
                if let gradient = normalized.fillGradient {
                    gradient.renderedImage(
                        size: size,
                        centerNormalized: normalized.fillGradientCenter
                    ).draw(
                        in: rect,
                        from: .zero,
                        operation: .sourceOver,
                        fraction: normalized.fillOpacity,
                        respectFlipped: true,
                        hints: nil
                    )
                } else {
                    normalized.fillColor.withAlphaComponent(normalized.fillOpacity).setFill()
                    rect.fill()
                }
                booleanMask.draw(
                    in: rect,
                    from: .zero,
                    operation: .destinationIn,
                    fraction: 1,
                    respectFlipped: true,
                    hints: nil
                )
            }
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                let path: NSBezierPath
                if normalized.kind == .path {
                    path = normalized.pathBezierPath()
                } else {
                    let fillInset = normalized.strokeWidth / 2
                    let shapeRect = rect.insetBy(dx: fillInset, dy: fillInset)
                    if normalized.kind == .ellipse {
                        path = NSBezierPath(ovalIn: shapeRect)
                    } else {
                        path = normalized.rectangleBezierPath(in: shapeRect)
                    }
                }
                if normalized.kind != .path || normalized.isPathClosed {
                    if let gradient = normalized.fillGradient {
                        if booleanMask == nil {
                            NSGraphicsContext.saveGraphicsState()
                            path.addClip()
                            gradient.renderedImage(
                                size: size,
                                centerNormalized: normalized.fillGradientCenter
                            ).draw(
                                in: rect,
                                from: .zero,
                                operation: .sourceOver,
                                fraction: normalized.fillOpacity,
                                respectFlipped: true,
                                hints: nil
                            )
                            NSGraphicsContext.restoreGraphicsState()
                        }
                    } else if booleanMask == nil {
                        normalized.fillColor.withAlphaComponent(normalized.fillOpacity).setFill()
                        path.fill()
                    }
                }
                let strokePath: NSBezierPath
                if normalized.kind == .path {
                    strokePath = path
                } else {
                    let strokeInset: CGFloat
                    switch normalized.strokePosition {
                    case .inside: strokeInset = normalized.strokeWidth / 2
                    case .center: strokeInset = 0
                    case .outside: strokeInset = -normalized.strokeWidth / 2
                    }
                    let strokeRect = rect.insetBy(dx: strokeInset, dy: strokeInset)
                    strokePath = normalized.kind == .ellipse
                        ? NSBezierPath(ovalIn: strokeRect)
                        : normalized.rectangleBezierPath(in: strokeRect)
                }
                strokePath.lineJoinStyle = normalized.strokeJoin.nsStyle
                strokePath.miterLimit = normalized.strokeMiterLimit
                strokePath.lineCapStyle = normalized.strokeCap.nsStyle
                if normalized.strokeDashPattern.isEmpty {
                    strokePath.setLineDash(nil, count: 0, phase: 0)
                } else {
                    normalized.strokeDashPattern.withUnsafeBufferPointer { pattern in
                        strokePath.setLineDash(
                            pattern.baseAddress,
                            count: pattern.count,
                            phase: normalized.strokeDashOffset
                        )
                    }
                }
                strokePath.lineWidth = normalized.strokeWidth
                normalized.strokeColor.withAlphaComponent(normalized.strokeOpacity).setStroke()
                strokePath.stroke()
                normalized.drawStrokeDecorations()
            }
        } ?? NSImage.transparent(size: size)
    }

    private static func normalizedGradientCenterComponent(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0.5 }
        return max(-4, min(5, value))
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

    func renderedVectorMask(size: CGSize, inverted: Bool) -> NSImage? {
        guard kind == .path,
              isPathClosed,
              editablePathAnchors.count >= 3,
              size.width > 0,
              size.height > 0
        else { return nil }
        if hasExplicitPathComponentOperations {
            return renderedPathComponentMask(size: size, inverted: inverted)
        }
        return NSImage.rendered(size: size) { rect in
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                NSColor.white.setFill()
                let path = pathBezierPath()
                guard inverted else {
                    path.fill()
                    return
                }
                let inversePath = NSBezierPath(rect: rect)
                inversePath.append(path)
                inversePath.windingRule = .evenOdd
                inversePath.fill()
            }
        }
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

    private func drawStrokeDecorations() {
        guard kind == .path, !isPathClosed, strokeOpacity > 0 else { return }
        let color = strokeColor.withAlphaComponent(strokeOpacity)
        for anchors in allEditablePathSubpaths where anchors.count >= 2 {
            if let first = anchors.first,
               let direction = endpointDirection(anchors: anchors, isStart: true) {
                drawStrokeDecoration(
                    strokeStartDecoration,
                    at: first.point,
                    outwardDirection: direction,
                    color: color
                )
            }
            if let last = anchors.last,
               let direction = endpointDirection(anchors: anchors, isStart: false) {
                drawStrokeDecoration(
                    strokeEndDecoration,
                    at: last.point,
                    outwardDirection: direction,
                    color: color
                )
            }
        }
    }

    private func endpointDirection(
        anchors: [ImageEditorPathAnchor],
        isStart: Bool
    ) -> CGVector? {
        let delta: CGVector
        if isStart {
            let first = anchors[0]
            let second = anchors[1]
            let inward = first.outControl ?? second.inControl ?? second.point
            delta = CGVector(dx: first.point.x - inward.x, dy: first.point.y - inward.y)
        } else {
            let last = anchors[anchors.count - 1]
            let previous = anchors[anchors.count - 2]
            let inward = last.inControl ?? previous.outControl ?? previous.point
            delta = CGVector(dx: last.point.x - inward.x, dy: last.point.y - inward.y)
        }
        let length = hypot(delta.dx, delta.dy)
        guard length > 0.000_1 else { return nil }
        return CGVector(dx: delta.dx / length, dy: delta.dy / length)
    }

    private func drawStrokeDecoration(
        _ decoration: ImageEditorStrokeDecoration,
        at endpoint: CGPoint,
        outwardDirection: CGVector,
        color: NSColor
    ) {
        guard decoration != .none else { return }
        let halfWidth = max(2.5, strokeWidth / 2 + 2.5)
        let length = max(6, strokeWidth * 4)
        let perpendicular = CGVector(dx: -outwardDirection.dy, dy: outwardDirection.dx)
        func point(back: CGFloat, side: CGFloat = 0) -> CGPoint {
            CGPoint(
                x: endpoint.x - outwardDirection.dx * back + perpendicular.dx * side,
                y: endpoint.y - outwardDirection.dy * back + perpendicular.dy * side
            )
        }

        let marker = NSBezierPath()
        marker.lineJoinStyle = .round
        marker.lineCapStyle = .round
        marker.lineWidth = max(1, strokeWidth)
        switch decoration {
        case .none:
            return
        case .openArrow:
            marker.move(to: point(back: length, side: halfWidth))
            marker.line(to: endpoint)
            marker.line(to: point(back: length, side: -halfWidth))
            color.setStroke()
            marker.stroke()
        case .filledArrow:
            marker.move(to: endpoint)
            marker.line(to: point(back: length, side: halfWidth))
            marker.line(to: point(back: length * 0.72))
            marker.line(to: point(back: length, side: -halfWidth))
            marker.close()
            color.setFill()
            marker.fill()
        case .filledTriangle:
            marker.move(to: point(back: 0, side: halfWidth))
            marker.line(to: point(back: 0, side: -halfWidth))
            marker.line(to: point(back: length))
            marker.close()
            color.setFill()
            marker.fill()
        case .filledDiamond:
            marker.move(to: endpoint)
            marker.line(to: point(back: length * 0.5, side: halfWidth))
            marker.line(to: point(back: length))
            marker.line(to: point(back: length * 0.5, side: -halfWidth))
            marker.close()
            color.setFill()
            marker.fill()
        case .filledCircle:
            let radius = halfWidth
            let center = point(back: radius)
            color.setFill()
            NSBezierPath(
                ovalIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            ).fill()
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
    case solidColorFill(ImageEditorSolidColorFillContent)
    case patternFill(ImageEditorPatternFillContent)
    case gradientFill(ImageEditorGradientFillContent)
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
    var isVectorMaskInverted = false
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
    var stackLayout: ImageEditorStackLayout?
    var stackChildLayout: ImageEditorStackChildLayout?
    var isStackLayoutExcluded = false
    var isStackLayoutBackground = false
    var isClippingMask = false
    var labelColor: ImageEditorLayerLabelColor?
    var xomoComponentInstance: XomoComponentInstance?
    var isXomoThemeOverride = false
    var xomoFigmaVariableBindings: [XomoFigmaVariableBinding] = []
    /// Effective Figma min/max dimensions, including local inspector overrides.
    var xomoFigmaSizeConstraints: XomoFigmaSizeConstraints?
    /// Imported values retained separately so local overrides can be reset.
    /// A non-nil empty value means the source node originally had no constraints.
    var xomoFigmaSizeConstraintDefaults: XomoFigmaSizeConstraints?
    /// Original Figma node identity retained for inspectable, traceable imports.
    var xomoFigmaSourceID: String?
    var xomoFigmaNodeType: String?
    var xomoFigmaComponentRole: XomoFigmaComponentRole?
    var xomoFigmaComponentProperties: [String: XomoFigmaComponentProperty] = [:]
    /// Figma's imported component values before any local override is applied.
    /// Keeping this snapshot lets the property inspector restore one override
    /// without re-importing the source document.
    var xomoFigmaComponentPropertyDefaults: [String: XomoFigmaComponentProperty] = [:]
    /// Original Figma image-fill parameters retained for non-destructive rendering.
    var xomoFigmaImageFill: XomoFigmaImageFillMetadata?
    /// Original Figma image asset used to re-render crop/tile/rotation parameters.
    var xomoFigmaImageFillSourceImage: NSImage?
    /// Allows the imported Figma image-fill filters to be toggled without changing pixels.
    var xomoFigmaImageFillFiltersEnabled = true
    var xomoFigmaSourceURL: URL?

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

    static func solidColorFill(name: String, size: CGSize, content: ImageEditorSolidColorFillContent) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .solidColorFill(content.normalized())
        )
    }

    static func patternFill(name: String, size: CGSize, content: ImageEditorPatternFillContent) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .patternFill(content.normalized())
        )
    }

    static func gradientFill(name: String, size: CGSize, content: ImageEditorGradientFillContent) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .gradientFill(content.normalized())
        )
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

    var solidColorFillContent: ImageEditorSolidColorFillContent? {
        guard case let .solidColorFill(content) = kind else { return nil }
        return content
    }

    var isSolidColorFill: Bool {
        solidColorFillContent != nil
    }

    var patternFillContent: ImageEditorPatternFillContent? {
        guard case let .patternFill(content) = kind else { return nil }
        return content
    }

    var isPatternFill: Bool {
        patternFillContent != nil
    }

    var gradientFillContent: ImageEditorGradientFillContent? {
        guard case let .gradientFill(content) = kind else { return nil }
        return content
    }

    var isGradientFill: Bool {
        gradientFillContent != nil
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
        if let solidColorFillContent {
            return solidColorFillContent.renderedImage(size: size)
        }
        if let patternFillContent {
            return patternFillContent.renderedImage(size: size)
        }
        if let gradientFillContent {
            return gradientFillContent.renderedImage(size: size)
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

    var effectiveRasterMask: NSImage? {
        isMaskEnabled ? mask?.processedLayerMask(density: maskDensity, feather: maskFeather) : nil
    }

    var effectiveMask: NSImage? {
        let rasterMask = effectiveRasterMask
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
        vectorMask?.renderedVectorMask(
            size: image.size,
            inverted: isVectorMaskInverted
        )
    }

    var contentImage: NSImage {
        let baseImage: NSImage
        if let textContent {
            baseImage = NSImage.rendered(size: image.size) { _ in
                let drawingRect = textContent.drawingRect(in: image.size)
                let appKitDrawingRect = CGRect(
                    x: drawingRect.minX,
                    y: image.size.height - drawingRect.maxY,
                    width: drawingRect.width,
                    height: drawingRect.height
                )
                textContent.attributedString.draw(
                    with: appKitDrawingRect,
                    options: textContent.drawingOptions
                )
            } ?? image
        } else if let solidColorFillContent {
            baseImage = solidColorFillContent.renderedImage(size: image.size)
        } else if let patternFillContent {
            baseImage = patternFillContent.renderedImage(size: image.size)
        } else if let gradientFillContent {
            baseImage = gradientFillContent.renderedImage(size: image.size)
        } else if let shapeContent {
            baseImage = shapeContent.renderedImage(size: image.size)
        } else {
            baseImage = image
        }
        let imageFillRendered: NSImage
        if let imageFill = xomoFigmaImageFill,
           let sourceImage = xomoFigmaImageFillSourceImage {
            imageFillRendered = XomoFigmaNodeMaterializer.renderImageFill(
                sourceImage,
                metadata: imageFill,
                size: baseImage.size
            )
        } else {
            imageFillRendered = baseImage
        }
        let imageFillFiltered: NSImage
        if xomoFigmaImageFillFiltersEnabled,
           let imageFill = xomoFigmaImageFill {
            imageFillFiltered = XomoFigmaImageFilterBaker.apply(imageFill.filters, to: imageFillRendered)
        } else {
            imageFillFiltered = imageFillRendered
        }
        return smartFilters.reduce(imageFillFiltered) { partial, filter in
            guard filter.isEnabled, !filter.appliesToBackdrop else { return partial }
            return partial.applyingFilter(
                kind: filter.kind,
                intensity: filter.normalizedIntensity,
                settings: filter.normalizedSettings,
                mask: nil,
                opacity: filter.normalizedOpacity,
                blendMode: filter.normalizedBlendMode
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
        style.hasConfiguredEffects
    }

    var compositingImage: NSImage {
        renderedCompositingImage(globalLightAngle: nil)
    }

    func renderedCompositingImage(globalLightAngle: CGFloat?) -> NSImage {
        renderedCompositingImage(
            globalLightAngle: globalLightAngle,
            style: style.resolvedForRendering()
        )
    }

    private func renderedCompositingImage(
        globalLightAngle: CGFloat?,
        style: ImageEditorLayerStyle
    ) -> NSImage {
        let baseImage = visibleImage.applyingBlendIfSourceRange(
            black: blendIfSourceBlack,
            white: blendIfSourceWhite
        ) ?? visibleImage
        let normalizedFillOpacity = CGFloat(max(0, min(1, fillOpacity)))
        guard style.hasEffects else {
            guard normalizedFillOpacity < 1 else { return baseImage }
            return baseImage.withOpacity(normalizedFillOpacity) ?? baseImage
        }
        let padding = style.padding(globalLightAngle: globalLightAngle)
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
                    let rawShadowImage = baseImage.alphaTinted(
                        color: style.shadowColor.withAlphaComponent(style.shadowOpacity)
                    )
                    let shadowImage = rawShadowImage.shadowNoised(amount: style.shadowNoise) ?? rawShadowImage
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
                let contouredShadow = blurredShadow.applyingEffectContour(style.shadowContour) ?? blurredShadow
                contouredShadow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: contouredShadow.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.strokeEnabled {
                let width = max(1, Int(style.strokeWidth.rounded()))
                let outsideWidth = style.strokePosition.outsideWidth(totalWidth: width)
                let strokeFillImage = style.strokeFillImage(size: outputSize)
                if outsideWidth > 0,
                   let outsideStroke = baseImage.outsideStrokeCanvas(
                       fillImage: strokeFillImage,
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
                let rawGlowImage = baseImage.alphaTinted(
                    color: style.outerGlowColor.withAlphaComponent(style.outerGlowOpacity)
                )
                let glowImage = rawGlowImage.shadowNoised(amount: style.outerGlowNoise) ?? rawGlowImage
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
                let diffusedGlow: NSImage
                switch style.outerGlowTechnique {
                case .softer:
                    diffusedGlow = glowCanvas.blurred(radius: style.outerGlowBlur) ?? glowCanvas
                case .precise:
                    diffusedGlow = glowCanvas.preciseOuterGlow(radius: style.outerGlowBlur) ?? glowCanvas
                }
                let contouredGlow = diffusedGlow.applyingEffectContour(
                    style.outerGlowContour,
                    range: style.outerGlowRange
                ) ?? diffusedGlow
                let jitteredGlow = contouredGlow.shadowNoised(
                    amount: style.outerGlowJitter
                ) ?? contouredGlow
                jitteredGlow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: jitteredGlow.size),
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
                let strokeFillImage = style.strokeFillImage(size: outputSize)
                if insideWidth > 0,
                   let insideStroke = baseImage.insideStrokeCanvas(
                       fillImage: strokeFillImage,
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
                let rawInnerShadowImage = baseImage.alphaTinted(
                    color: style.innerShadowColor.withAlphaComponent(style.innerShadowOpacity)
                )
                let innerShadowImage = rawInnerShadowImage.shadowNoised(amount: style.innerShadowNoise) ?? rawInnerShadowImage
                let choke = max(0, Int(style.innerShadowChoke.rounded()))
                let innerShadowCanvas = NSImage.rendered(size: outputSize) { _ in
                    innerShadowImage.draw(
                        in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                        from: CGRect(origin: .zero, size: innerShadowImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    if choke > 0 {
                        let directions = 24
                        for radius in 1...choke {
                            for step in 0..<directions {
                                let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                                let expansion = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                                innerShadowImage.draw(
                                    in: contentRect.offsetBy(
                                        dx: offset.width + expansion.width,
                                        dy: offset.height + expansion.height
                                    ),
                                    from: CGRect(origin: .zero, size: innerShadowImage.size),
                                    operation: .sourceOver,
                                    fraction: 1
                                )
                            }
                        }
                    }
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                let softenedInnerShadow = innerShadowCanvas.blurred(radius: style.innerShadowBlur) ?? innerShadowCanvas
                let contouredInnerShadow = softenedInnerShadow.applyingEffectContour(style.innerShadowContour) ?? softenedInnerShadow
                contouredInnerShadow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: contouredInnerShadow.size),
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

            if style.gradientOverlayEnabled {
                let gradientImage = ImageEditorGradientFillContent(
                    preset: .custom,
                    style: style.gradientOverlayStyle,
                    reverse: style.gradientOverlayReverse,
                    dither: style.gradientOverlayDither,
                    angle: style.gradientOverlayAngle,
                    scale: style.gradientOverlayScale,
                    startRed: Double(style.gradientOverlayStartColor.usingColorSpace(.deviceRGB)?.redComponent ?? 1),
                    startGreen: Double(style.gradientOverlayStartColor.usingColorSpace(.deviceRGB)?.greenComponent ?? 0),
                    startBlue: Double(style.gradientOverlayStartColor.usingColorSpace(.deviceRGB)?.blueComponent ?? 0),
                    endRed: Double(style.gradientOverlayEndColor.usingColorSpace(.deviceRGB)?.redComponent ?? 1),
                    endGreen: Double(style.gradientOverlayEndColor.usingColorSpace(.deviceRGB)?.greenComponent ?? 1),
                    endBlue: Double(style.gradientOverlayEndColor.usingColorSpace(.deviceRGB)?.blueComponent ?? 1),
                    colorStops: style.gradientOverlayColorStops
                ).renderedImage(
                    size: contentRect.size,
                    centerNormalized: ImageEditorGradientOverlayCenterPolicy.normalized(
                        style.gradientOverlayCenter
                    ),
                    opacity: Double(style.gradientOverlayOpacity)
                )
                let gradientCanvas = NSImage.rendered(size: outputSize) { _ in
                    let context = NSGraphicsContext.current
                    let previousInterpolation = context?.imageInterpolation
                    let previousInterpolationQuality = context?.cgContext.interpolationQuality
                    context?.imageInterpolation = .none
                    defer {
                        context?.imageInterpolation = previousInterpolation ?? .default
                        context?.cgContext.interpolationQuality = previousInterpolationQuality ?? .default
                    }
                    if let gradientCGImage = gradientImage.cgImage(
                        forProposedRect: nil,
                        context: context,
                        hints: nil
                    ) {
                        context?.cgContext.interpolationQuality = .none
                        context?.cgContext.draw(gradientCGImage, in: contentRect)
                    } else {
                        gradientImage.draw(
                            in: contentRect,
                            from: CGRect(origin: .zero, size: gradientImage.size),
                            operation: .sourceOver,
                            fraction: 1
                        )
                    }
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                let outputRect = CGRect(origin: .zero, size: outputSize)
                if style.gradientOverlayBlendMode == .normal,
                   let context = NSGraphicsContext.current,
                   let gradientCanvasCGImage = gradientCanvas.cgImage(
                    forProposedRect: nil,
                    context: context,
                    hints: nil
                ) {
                    let previousInterpolationQuality = context.cgContext.interpolationQuality
                    context.cgContext.interpolationQuality = .none
                    defer { context.cgContext.interpolationQuality = previousInterpolationQuality }
                    context.cgContext.draw(gradientCanvasCGImage, in: outputRect)
                } else if let backdropCGImage = NSGraphicsContext.current?.cgContext.makeImage(),
                   let compositedImage = NSImage(
                       cgImage: backdropCGImage,
                       size: outputSize
                   ).blended(
                       with: gradientCanvas,
                       mode: style.gradientOverlayBlendMode,
                       opacity: 1
                   ) {
                    compositedImage.draw(
                        in: outputRect,
                        from: outputRect,
                        operation: .copy,
                        fraction: 1
                    )
                } else {
                    gradientCanvas.draw(
                        in: outputRect,
                        from: outputRect,
                        operation: .sourceOver,
                        fraction: 1
                    )
                }
            }

            if style.patternOverlayEnabled {
                let patternImage = style.patternOverlayKind.tileImage(
                    color: style.patternOverlayColor,
                    opacity: style.patternOverlayOpacity,
                    scale: style.patternOverlayScale
                )
                let patternCanvas = NSImage.rendered(size: outputSize) { _ in
                    let context = NSGraphicsContext.current
                    let originalPatternPhase = context?.patternPhase ?? .zero
                    context?.patternPhase = CGPoint(
                        x: style.patternOverlayOffset.width,
                        y: style.patternOverlayOffset.height
                    )
                    defer {
                        context?.patternPhase = originalPatternPhase
                    }
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
                let contouredSatin = softenedSatin.applyingEffectContour(style.satinContour) ?? softenedSatin
                let baseSatinMask = NSImage.rendered(size: outputSize) { _ in
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                }
                let satinOutput: NSImage
                if style.satinInvert,
                   let baseMask = baseSatinMask,
                   let inverted = contouredSatin.invertedAlphaTinted(
                       within: baseMask,
                       color: style.satinColor.withAlphaComponent(style.satinOpacity)
                   ) {
                    satinOutput = inverted
                } else {
                    satinOutput = contouredSatin
                }
                satinOutput.draw(
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
                let highlightOffset = style.bevelDirection == .up
                    ? CGSize(width: -bevelOffset.width, height: -bevelOffset.height)
                    : bevelOffset
                let shadowOffset = style.bevelDirection == .up
                    ? bevelOffset
                    : CGSize(width: -bevelOffset.width, height: -bevelOffset.height)
                let bevelCanvas = NSImage.rendered(size: outputSize) { _ in
                    highlightImage.draw(
                        in: contentRect.offsetBy(dx: highlightOffset.width, dy: highlightOffset.height),
                        from: CGRect(origin: .zero, size: highlightImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    shadowImage.draw(
                        in: contentRect.offsetBy(dx: shadowOffset.width, dy: shadowOffset.height),
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
                let softenedBevel = style.bevelSoften > 0
                    ? bevelCanvas.blurred(radius: style.bevelSoften) ?? bevelCanvas
                    : bevelCanvas
                softenedBevel.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: softenedBevel.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.innerGlowEnabled {
                let rawInnerGlowImage = baseImage.alphaTinted(
                    color: style.innerGlowColor.withAlphaComponent(style.innerGlowOpacity)
                )
                let innerGlowImage = rawInnerGlowImage.shadowNoised(amount: style.innerGlowNoise) ?? rawInnerGlowImage
                let choke = max(0, Int(style.innerGlowChoke.rounded()))
                let rawInnerGlowCanvas = NSImage.rendered(size: outputSize) { _ in
                    switch style.innerGlowSource {
                    case .edge:
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
                    case .center where style.innerGlowTechnique == .precise:
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
                    case .center:
                        let glowColor = style.innerGlowColor.withAlphaComponent(style.innerGlowOpacity)
                        let clearColor = style.innerGlowColor.withAlphaComponent(0)
                        let center = CGPoint(x: contentRect.midX, y: contentRect.midY)
                        let radius = max(contentRect.width, contentRect.height) * 0.5 + CGFloat(choke)
                        NSGradient(starting: glowColor, ending: clearColor)?.draw(
                            fromCenter: center,
                            radius: 0,
                            toCenter: center,
                            radius: max(1, radius),
                            options: []
                        )
                    }
                } ?? NSImage(size: outputSize)
                let innerGlowCanvas = style.innerGlowSource == .center && style.innerGlowTechnique == .softer
                    ? rawInnerGlowCanvas.shadowNoised(amount: style.innerGlowNoise) ?? rawInnerGlowCanvas
                    : rawInnerGlowCanvas
                let diffusedInnerGlow: NSImage
                switch style.innerGlowTechnique {
                case .softer:
                    diffusedInnerGlow = innerGlowCanvas.blurred(radius: style.innerGlowBlur) ?? innerGlowCanvas
                case .precise:
                    diffusedInnerGlow = innerGlowCanvas.preciseInnerGlow(
                        radius: style.innerGlowBlur,
                        source: style.innerGlowSource
                    ) ?? innerGlowCanvas
                }
                let contouredInnerGlow = diffusedInnerGlow.applyingEffectContour(
                    style.innerGlowContour,
                    range: style.innerGlowRange
                ) ?? diffusedInnerGlow
                // Photoshop applies Jitter in the inner-glow quality stage,
                // after the smooth contour has been resolved.  Keeping it
                // here makes it visibly distinct from Noise, which textures
                // the source before blur, while stableNoise keeps rendering
                // deterministic across redraws and project reopen.
                let jitteredInnerGlow = contouredInnerGlow.shadowNoised(
                    amount: style.innerGlowJitter
                ) ?? contouredInnerGlow
                jitteredInnerGlow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: jitteredInnerGlow.size),
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
    case solidColorFill
    case patternFill
    case gradientFill
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
        case .solidColorFill:
            return "paintbrush.pointed"
        case .patternFill:
            return "square.grid.3x3.fill"
        case .gradientFill:
            return "paintpalette"
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
        case .solidColorFill:
            return layer.isSolidColorFill
        case .patternFill:
            return layer.isPatternFill
        case .gradientFill:
            return layer.isGradientFill
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
            return layer.style.hasConfiguredEffects
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
    var renderedImage: NSImage
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
    var isVectorMaskInverted: Bool
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
        case isVectorMaskInverted
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
        isVectorMaskInverted: Bool = false,
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
        self.isVectorMaskInverted = isVectorMaskInverted
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
        isVectorMaskInverted = try container.decodeIfPresent(Bool.self, forKey: .isVectorMaskInverted) ?? false
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
    var comment: String
    var isFavorite: Bool
    var capturesVisibility: Bool
    var capturesPosition: Bool
    var capturesAppearance: Bool
    var acknowledgedMissingLayerIDs: Set<UUID>
    var layerOrder: [UUID]
    var layerStates: [ImageEditorLayerCompLayerState]
    var selectedLayerID: UUID?
    var selectedLayerIDs: Set<UUID>
    var createdAt = Date()

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case comment
        case isFavorite
        case capturesVisibility
        case capturesPosition
        case capturesAppearance
        case acknowledgedMissingLayerIDs
        case layerOrder
        case layerStates
        case selectedLayerID
        case selectedLayerIDs
        case createdAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        comment: String = "",
        isFavorite: Bool = false,
        capturesVisibility: Bool = true,
        capturesPosition: Bool = true,
        capturesAppearance: Bool = true,
        acknowledgedMissingLayerIDs: Set<UUID> = [],
        layerOrder: [UUID],
        layerStates: [ImageEditorLayerCompLayerState],
        selectedLayerID: UUID?,
        selectedLayerIDs: Set<UUID>,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.comment = comment
        self.isFavorite = isFavorite
        self.capturesVisibility = capturesVisibility
        self.capturesPosition = capturesPosition
        self.capturesAppearance = capturesAppearance
        self.acknowledgedMissingLayerIDs = acknowledgedMissingLayerIDs
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
        comment = try container.decodeIfPresent(String.self, forKey: .comment) ?? ""
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        capturesVisibility = try container.decodeIfPresent(
            Bool.self,
            forKey: .capturesVisibility
        ) ?? true
        capturesPosition = try container.decodeIfPresent(
            Bool.self,
            forKey: .capturesPosition
        ) ?? true
        capturesAppearance = try container.decodeIfPresent(
            Bool.self,
            forKey: .capturesAppearance
        ) ?? true
        acknowledgedMissingLayerIDs = try container.decodeIfPresent(
            Set<UUID>.self,
            forKey: .acknowledgedMissingLayerIDs
        ) ?? []
        layerStates = try container.decode([ImageEditorLayerCompLayerState].self, forKey: .layerStates)
        layerOrder = try container.decodeIfPresent([UUID].self, forKey: .layerOrder)
            ?? layerStates.map(\.layerID)
        selectedLayerID = try container.decodeIfPresent(UUID.self, forKey: .selectedLayerID)
        selectedLayerIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .selectedLayerIDs) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    @MainActor
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
                    isVectorMaskInverted: layer.isVectorMaskInverted,
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

/// A named rectangular delivery region inspired by Fireworks slices.
/// Slices are document metadata: they do not alter pixels or layer geometry.
enum ImageEditorSliceExportConstraint: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case scale
    case width
    case height

    var id: String { rawValue }
}

struct ImageEditorSliceExportPreset: Codable, Equatable, Sendable {
    static let maximumSuffixLength = 40

    var suffix: String
    var format: ImageEditorExportFormat
    var constraint: ImageEditorSliceExportConstraint
    var value: Double

    init(
        suffix: String = "",
        format: ImageEditorExportFormat,
        constraint: ImageEditorSliceExportConstraint,
        value: Double
    ) {
        self.suffix = Self.sanitizedSuffix(suffix)
        self.format = format
        self.constraint = constraint
        self.value = value
    }

    func resolvedScale(for frame: CGRect) -> Double? {
        guard value.isFinite, value > 0 else { return nil }
        let scale: Double
        switch constraint {
        case .scale:
            scale = value
        case .width:
            guard frame.width > 0 else { return nil }
            scale = value / Double(frame.width)
        case .height:
            guard frame.height > 0 else { return nil }
            scale = value / Double(frame.height)
        }
        guard scale.isFinite,
              ImageEditorExportSettings.supportedScaleRange.contains(scale)
        else {
            return nil
        }
        return scale
    }

    static func sanitizedSuffix(_ rawValue: String) -> String {
        String(sanitizedFilenameComponent(rawValue).prefix(maximumSuffixLength))
    }

    static func sanitizedFilenameComponent(_ rawValue: String) -> String {
        let forbidden = CharacterSet.controlCharacters.union(
            CharacterSet(charactersIn: "/\\:")
        )
        let scalars = rawValue.unicodeScalars.map { scalar -> Character in
            forbidden.contains(scalar) ? "-" : Character(String(scalar))
        }
        return String(scalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func defaultSuffix(forScale scale: Double) -> String {
        guard scale.isFinite, scale != 1 else { return "" }
        let label: String
        if scale.rounded() == scale {
            label = String(Int(scale))
        } else if (scale * 10).rounded() == scale * 10 {
            label = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), scale)
        } else {
            label = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), scale)
        }
        return "@\(label)x"
    }
}

struct ImageEditorSlice: Identifiable, Equatable, Codable {
    static let maximumCount = 256
    static let maximumNameLength = 80
    static let maximumExportPresetCount = 16

    var id = UUID()
    var name: String
    var frame: CGRect
    /// Optional keeps projects created before export presets source-compatible.
    var exportPresets: [ImageEditorSliceExportPreset]?

    init(
        id: UUID = UUID(),
        name: String,
        frame: CGRect,
        exportPresets: [ImageEditorSliceExportPreset] = []
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.exportPresets = exportPresets.isEmpty ? nil : exportPresets
    }

    func normalized(canvasSize: CGSize) -> ImageEditorSlice? {
        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        let bounded = frame.standardized.integral.intersection(canvasBounds)
        guard bounded.width > 0, bounded.height > 0 else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let normalizedPresets = (exportPresets ?? [])
            .prefix(Self.maximumExportPresetCount)
            .compactMap { preset -> ImageEditorSliceExportPreset? in
                guard preset.format.supportsSliceExportPreset else { return nil }
                let normalized = ImageEditorSliceExportPreset(
                    suffix: preset.suffix,
                    format: preset.format,
                    constraint: preset.constraint,
                    value: preset.value
                )
                return normalized.resolvedScale(for: bounded) == nil ? nil : normalized
            }
        return ImageEditorSlice(
            id: id,
            name: String(trimmedName.prefix(Self.maximumNameLength)),
            frame: bounded,
            exportPresets: normalizedPresets
        )
    }
}

/// A rectangular interactive region inspired by Fireworks hotspots.
/// Hotspots are document metadata and do not alter pixels or layer geometry.
struct ImageEditorHotspot: Identifiable, Equatable, Codable {
    static let maximumCount = 256
    static let maximumNameLength = 80
    static let maximumURLLength = 2_048

    var id = UUID()
    var name: String
    var frame: CGRect
    var url: String

    init(id: UUID = UUID(), name: String, frame: CGRect, url: String = "") {
        self.id = id
        self.name = name
        self.frame = frame
        self.url = url
    }

    func normalized(canvasSize: CGSize) -> ImageEditorHotspot? {
        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        let bounded = frame.standardized.integral.intersection(canvasBounds)
        guard bounded.width > 0, bounded.height > 0 else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let trimmedURL = String(url.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maximumURLLength))
        return ImageEditorHotspot(
            id: id,
            name: String(trimmedName.prefix(Self.maximumNameLength)),
            frame: bounded,
            url: trimmedURL
        )
    }
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
    var savedPaths: [ImageEditorSavedPath]
    var selectedSavedPathID: UUID?
    var guides: [ImageEditorGuide]
    var slices: [ImageEditorSlice] = []
    var hotspots: [ImageEditorHotspot] = []
    var areExtrasVisible: Bool
    var areGuidesVisible: Bool
    var areGuidesLocked: Bool
    var areRulersVisible: Bool
    var isGuideSnappingEnabled: Bool
    var areSelectionEdgesVisible: Bool
    var areTransformControlsVisible: Bool
    var isGridVisible: Bool
    var isGridSnappingEnabled: Bool
    var gridSpacing: CGFloat
    var designCanvasMetadata: XomoDesignCanvasMetadata?
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
        savedPaths = []
        selectedSavedPathID = nil
        guides = []
        areExtrasVisible = true
        areGuidesVisible = true
        areGuidesLocked = false
        areRulersVisible = true
        isGuideSnappingEnabled = true
        areSelectionEdgesVisible = true
        areTransformControlsVisible = true
        isGridVisible = false
        isGridSnappingEnabled = false
        gridSpacing = 32
        designCanvasMetadata = nil
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

    func colorSamplingLayerIDs(
        for source: ImageEditorColorSamplerSource,
        ignoringAdjustmentLayers: Bool
    ) -> Set<UUID>? {
        let candidates: [ImageEditorLayer]
        switch source {
        case .composite:
            candidates = layers
        case .selectedLayer:
            guard let selectedLayer else { return nil }
            if selectedLayer.isGroup {
                candidates = layers.filter { layer in
                    layer.id == selectedLayer.id
                        || isLayer(layer, descendantOf: selectedLayer.id)
                }
            } else {
                candidates = [selectedLayer]
            }
        case .currentAndBelow:
            guard let selectedLayerIndex else { return nil }
            candidates = Array(layers[...selectedLayerIndex])
        }

        // Keep only eligible leaves while filtering. Including a group ID would
        // make the compositor include every descendant, including adjustments.
        let sampledLayers = ignoringAdjustmentLayers
            ? candidates.filter { !$0.isGroup && !$0.isAdjustment }
            : candidates
        return Set(sampledLayers.map(\.id))
    }

    func layerIDsThroughSelectedLayer() -> Set<UUID>? {
        colorSamplingLayerIDs(
            for: .currentAndBelow,
            ignoringAdjustmentLayers: false
        )
    }

    var compositedImage: NSImage {
        compositedImage(includingOnly: nil)
    }

    func compositedImage(includingOnly includedLayerIDs: Set<UUID>) -> NSImage {
        compositedImage(includingOnly: Optional(includedLayerIDs))
    }

    func compositedImage(
        includingOnly includedLayerIDs: Set<UUID>,
        within parentGroupID: UUID?
    ) -> NSImage {
        guard let parentGroupID,
              let parentGroup = layers.first(where: { $0.id == parentGroupID && $0.isGroup })
        else {
            return compositedImage(includingOnly: includedLayerIDs)
        }
        return isolatedGroupCanvas(for: parentGroup, includedLayerIDs: includedLayerIDs)
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
                amount: adjustment.amount,
                settings: layer.adjustmentSettings,
                mask: effectiveCanvasMask(forLayerAt: index, layerMask: layer.effectiveMask, groupMask: groupMask),
                opacity: layer.opacity * groupOpacity
            ) ?? canvas
        }
        if let filter = layer.filter {
            return canvas.applyingFilter(
                kind: filter.kind,
                intensity: filter.intensity,
                settings: layer.filterSettings,
                mask: effectiveCanvasMask(forLayerAt: index, layerMask: layer.effectiveMask, groupMask: groupMask),
                opacity: layer.opacity * groupOpacity
            ) ?? canvas
        }

        let layerCanvas: NSImage
        let backdropMask: NSImage?
        if layer.isClippingMask,
           let clippedImage = clippedCompositingImage(forLayerAt: index) {
            layerCanvas = imageByApplyingCanvasMask(clippedImage, mask: groupMask)
            backdropMask = nil
        } else {
            let compositingImage = layer.renderedCompositingImage(globalLightAngle: globalLightAngle)
            let positionedCanvas = canvasImage(
                for: compositingImage,
                frame: layer.renderedCompositingFrame(globalLightAngle: globalLightAngle)
            )
            layerCanvas = imageByApplyingCanvasMask(positionedCanvas, mask: groupMask)
            backdropMask = layerCanvas
        }
        let backdropCanvas = canvasByApplyingBackdropBlur(
            for: layer,
            to: canvas,
            mask: backdropMask
        )
        let blendIfCanvas = layerCanvas.applyingBlendIfUnderlyingRange(
            black: layer.blendIfUnderlyingBlack,
            white: layer.blendIfUnderlyingWhite,
            backdrop: backdropCanvas
        ) ?? layerCanvas
        return backdropCanvas.blended(
            with: blendIfCanvas,
            mode: layer.blendMode,
            opacity: layer.opacity * groupOpacity
        ) ?? backdropCanvas
    }

    private func canvasByApplyingBackdropBlur(
        for layer: ImageEditorLayer,
        to canvas: NSImage,
        mask: NSImage?
    ) -> NSImage {
        guard let mask else { return canvas }
        return layer.smartFilters
            .filter { $0.isEnabled && $0.appliesToBackdrop && $0.kind == .gaussianBlur }
            .reduce(canvas) { partial, filter in
                partial.applyingFilter(
                    kind: .gaussianBlur,
                    intensity: filter.normalizedIntensity,
                    settings: filter.normalizedSettings,
                    mask: mask,
                    opacity: filter.normalizedOpacity,
                    blendMode: filter.normalizedBlendMode
                ) ?? partial
            }
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
        let appKitFrame = CGRect(
            x: frame.minX,
            y: canvasSize.height - frame.maxY,
            width: frame.width,
            height: frame.height
        )
        return NSImage.rendered(size: canvasSize) { _ in
            image.draw(
                in: appKitFrame,
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
    func applyingEffectContour(
        _ contour: ImageEditorLayerEffectContour,
        range: CGFloat = 1
    ) -> NSImage? {
        let normalizedRange = max(0.01, min(1, range))
        guard contour != .linear || abs(normalizedRange - 1) > 0.0001 else { return self }
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
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = CGFloat(pixels[offset + 3]) / 255
                guard alpha > 0 else { continue }
                let rangedAlpha = min(1, alpha / normalizedRange)
                let mappedAlpha = contour.mappedAlpha(rangedAlpha)
                let multiplier = mappedAlpha / alpha
                pixels[offset] = Self.scaledByte(pixels[offset], multiplier: multiplier)
                pixels[offset + 1] = Self.scaledByte(pixels[offset + 1], multiplier: multiplier)
                pixels[offset + 2] = Self.scaledByte(pixels[offset + 2], multiplier: multiplier)
                pixels[offset + 3] = UInt8(max(0, min(255, (mappedAlpha * 255).rounded())))
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return nil }

        return NSImage(cgImage: output, size: size)
    }

    func invertedAlphaTinted(within mask: NSImage, color: NSColor) -> NSImage? {
        guard let effectCGImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let maskCGImage = mask.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        let width = max(1, effectCGImage.width)
        let height = max(1, effectCGImage.height)
        guard maskCGImage.width == width, maskCGImage.height == height else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var effectPixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        var maskPixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let effectContext = CGContext(
            data: &effectPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ),
              let maskContext = CGContext(
                data: &maskPixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
              )
        else { return nil }

        for context in [effectContext, maskContext] {
            context.interpolationQuality = .none
        }
        effectContext.draw(effectCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        maskContext.draw(maskCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let tint = color.usingColorSpace(.deviceRGB) ?? color
        let tintAlpha = max(0, min(1, tint.alphaComponent))
        var outputPixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let maskAlpha = CGFloat(maskPixels[offset + 3]) / 255
                guard maskAlpha > 0 else { continue }

                let effectAlpha = CGFloat(effectPixels[offset + 3]) / 255
                let outputAlpha = max(0, min(1, maskAlpha - min(maskAlpha, effectAlpha))) * tintAlpha
                guard outputAlpha > 0 else { continue }

                outputPixels[offset] = UInt8(max(0, min(255, (tint.redComponent * outputAlpha * 255).rounded())))
                outputPixels[offset + 1] = UInt8(max(0, min(255, (tint.greenComponent * outputAlpha * 255).rounded())))
                outputPixels[offset + 2] = UInt8(max(0, min(255, (tint.blueComponent * outputAlpha * 255).rounded())))
                outputPixels[offset + 3] = UInt8(max(0, min(255, (outputAlpha * 255).rounded())))
            }
        }

        guard let provider = CGDataProvider(data: Data(outputPixels) as CFData),
              let output = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return nil }

        return NSImage(cgImage: output, size: size)
    }

    func shadowNoised(amount: CGFloat) -> NSImage? {
        let normalizedAmount = max(0, min(1, amount))
        guard normalizedAmount > 0,
              let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return self }

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
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = pixels[offset + 3]
                guard alpha > 0 else { continue }
                let noise = Self.stableNoise(x: x, y: y)
                let multiplier = 1 - normalizedAmount + normalizedAmount * noise
                let adjustedAlpha = CGFloat(alpha) * multiplier
                pixels[offset] = Self.scaledByte(pixels[offset], multiplier: multiplier)
                pixels[offset + 1] = Self.scaledByte(pixels[offset + 1], multiplier: multiplier)
                pixels[offset + 2] = Self.scaledByte(pixels[offset + 2], multiplier: multiplier)
                pixels[offset + 3] = UInt8(max(0, min(255, adjustedAlpha.rounded())))
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let output = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else { return nil }

        return NSImage(cgImage: output, size: size)
    }

    static func stableNoise(x: Int, y: Int) -> CGFloat {
        var value = UInt32(truncatingIfNeeded: x)
        value &*= 374_761_393
        value &+= UInt32(truncatingIfNeeded: y) &* 668_265_263
        value = (value ^ (value >> 13)) &* 1_274_126_177
        value ^= value >> 16
        return CGFloat(value & 0xff) / 255
    }

    static func scaledByte(_ value: UInt8, multiplier: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, (CGFloat(value) * multiplier).rounded())))
    }

    func outsideStrokeCanvas(fillImage: NSImage, width: Int, contentRect: CGRect, outputSize: CGSize) -> NSImage? {
        let maskImage = alphaTinted(color: .white)
        let strokeMask = NSImage.rendered(size: outputSize) { _ in
            drawExpandedAlpha(
                maskImage,
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
        return NSImage.rendered(size: outputSize) { _ in
            fillImage.draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: CGRect(origin: .zero, size: fillImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            strokeMask?.draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: CGRect(origin: .zero, size: outputSize),
                operation: .destinationIn,
                fraction: 1
            )
        }
    }

    func insideStrokeCanvas(fillImage: NSImage, width: Int, contentRect: CGRect, outputSize: CGSize) -> NSImage? {
        let maskImage = alphaTinted(color: .white)
        let erodedImage = NSImage.rendered(size: outputSize) { _ in
            maskImage.draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: maskImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            applyErosionMask(
                maskImage,
                width: width,
                contentRect: contentRect
            )
        }
        let strokeMask = NSImage.rendered(size: outputSize) { _ in
            maskImage.draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: maskImage.size),
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
        return NSImage.rendered(size: outputSize) { _ in
            fillImage.draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: CGRect(origin: .zero, size: fillImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            strokeMask?.draw(
                in: CGRect(origin: .zero, size: outputSize),
                from: CGRect(origin: .zero, size: outputSize),
                operation: .destinationIn,
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

extension NSImage {
    func grayscaleAlphaPreviewImage(targetSize: CGSize) -> NSImage? {
        guard let alpha = alphaPlane() else { return nil }
        return ImageEditorSelectionMask(
            width: alpha.width,
            height: alpha.height,
            alpha: alpha.values
        ).grayscalePreviewImage(targetSize: targetSize)
    }
}

struct ImageEditorTheme {
    static let window = NSColor(calibratedWhite: 0.11, alpha: 1)
    static let chrome = NSColor(calibratedRed: 0.105, green: 0.118, blue: 0.145, alpha: 1)
    static let panel = NSColor(calibratedWhite: 0.23, alpha: 1)
    static let panelRaised = NSColor(calibratedWhite: 0.29, alpha: 1)
    static let border = NSColor(calibratedWhite: 0.38, alpha: 1)
    static let selected = NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.78, alpha: 1)
    static let text = NSColor(calibratedWhite: 0.92, alpha: 1)
    static let mutedText = NSColor(calibratedWhite: 0.68, alpha: 1)
    static let menuText = NSColor(calibratedRed: 0.84, green: 0.88, blue: 0.94, alpha: 1)
    static let menuMutedText = NSColor(calibratedRed: 0.63, green: 0.68, blue: 0.77, alpha: 1)
    static let exportAccent = NSColor(calibratedRed: 0.18, green: 0.66, blue: 0.95, alpha: 1)
    static let exportAccentPressed = NSColor(calibratedRed: 0.12, green: 0.49, blue: 0.79, alpha: 1)
}
