//
//  ImageEditorModels.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import CoreImage
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
        case .marquee, .lasso, .magicWand, .quickSelection, .patchTool:
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
