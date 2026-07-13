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
    let id: String
    let name: String?
    let size: CGFloat
    let hardness: CGFloat
    let flow: CGFloat
    let spacing: CGFloat
    let pressureControlsSize: Bool
    let pressureControlsFlow: Bool
    let pressureSensitivity: CGFloat
    let isBuiltIn: Bool

    init(
        id: String,
        name: String? = nil,
        size: CGFloat,
        hardness: CGFloat = 0.8,
        flow: CGFloat = 100,
        spacing: CGFloat = 25,
        pressureControlsSize: Bool = true,
        pressureControlsFlow: Bool = true,
        pressureSensitivity: CGFloat = 50,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.hardness = hardness
        self.flow = flow
        self.spacing = spacing
        self.pressureControlsSize = pressureControlsSize
        self.pressureControlsFlow = pressureControlsFlow
        self.pressureSensitivity = pressureSensitivity
        self.isBuiltIn = isBuiltIn
    }

    var title: String {
        name ?? L10n.format("imageEditor.brushPreset.size", Int(size.rounded()))
    }

    var normalizedCustomPreset: ImageEditorBrushPreset {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = (trimmedName?.isEmpty == false ? trimmedName : nil)
            ?? L10n.text("imageEditor.brushPreset.untitled")
        return ImageEditorBrushPreset(
            id: id.isEmpty ? UUID().uuidString : id,
            name: String(normalizedName.prefix(80)),
            size: max(1, min(96, size)),
            hardness: max(0, min(1, hardness)),
            flow: max(1, min(100, flow)),
            spacing: max(1, min(200, spacing)),
            pressureControlsSize: pressureControlsSize,
            pressureControlsFlow: pressureControlsFlow,
            pressureSensitivity: max(0, min(100, pressureSensitivity)),
            isBuiltIn: false
        )
    }

    func matches(
        size: CGFloat,
        hardness: CGFloat,
        flow: CGFloat,
        spacing: CGFloat,
        pressureControlsSize: Bool,
        pressureControlsFlow: Bool,
        pressureSensitivity: CGFloat
    ) -> Bool {
        let tolerance = CGFloat(0.0001)
        return abs(self.size - size) < tolerance
            && abs(self.hardness - hardness) < tolerance
            && abs(self.flow - flow) < tolerance
            && abs(self.spacing - spacing) < tolerance
            && self.pressureControlsSize == pressureControlsSize
            && self.pressureControlsFlow == pressureControlsFlow
            && abs(self.pressureSensitivity - pressureSensitivity) < tolerance
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
        ImageEditorToolShortcutGroup(key: "b", tools: [.brush]),
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
    let id = UUID()
    let point: CGPoint
    let color: NSColor
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
        return NSColor(calibratedRed: content.red, green: content.green, blue: content.blue, alpha: 1)
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

    func normalized() -> ImageEditorPatternFillContent {
        ImageEditorPatternFillContent(
            kind: kind,
            red: Self.zeroOne(red),
            green: Self.zeroOne(green),
            blue: Self.zeroOne(blue),
            opacity: max(0.05, min(1, opacity)),
            scale: max(6, min(64, scale))
        )
    }

    var color: NSColor {
        let content = normalized()
        return NSColor(calibratedRed: content.red, green: content.green, blue: content.blue, alpha: 1)
    }

    func renderedImage(size: CGSize) -> NSImage {
        let content = normalized()
        return NSImage.rendered(size: size) { rect in
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
    case reflected
    case diamond

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.gradientFill.style.\(rawValue)")
    }
}

struct ImageEditorGradientFillContent: Equatable, Codable {
    var preset: ImageEditorGradientFillPreset = .blueOrange
    var style: ImageEditorGradientFillStyle = .linear
    var reverse: Bool = false
    var angle: CGFloat = 0
    var scale: CGFloat = 1
    var startRed: Double = 0.12
    var startGreen: Double = 0.20
    var startBlue: Double = 0.95
    var endRed: Double = 1.0
    var endGreen: Double = 0.50
    var endBlue: Double = 0.10

    enum CodingKeys: String, CodingKey {
        case preset
        case style
        case reverse
        case angle
        case scale
        case startRed
        case startGreen
        case startBlue
        case endRed
        case endGreen
        case endBlue
    }

    init(
        preset: ImageEditorGradientFillPreset = .blueOrange,
        style: ImageEditorGradientFillStyle = .linear,
        reverse: Bool = false,
        angle: CGFloat = 0,
        scale: CGFloat = 1,
        startRed: Double = 0.12,
        startGreen: Double = 0.20,
        startBlue: Double = 0.95,
        endRed: Double = 1.0,
        endGreen: Double = 0.50,
        endBlue: Double = 0.10
    ) {
        self.preset = preset
        self.style = style
        self.reverse = reverse
        self.angle = angle
        self.scale = scale
        self.startRed = startRed
        self.startGreen = startGreen
        self.startBlue = startBlue
        self.endRed = endRed
        self.endGreen = endGreen
        self.endBlue = endBlue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preset = try container.decodeIfPresent(ImageEditorGradientFillPreset.self, forKey: .preset) ?? .blueOrange
        style = try container.decodeIfPresent(ImageEditorGradientFillStyle.self, forKey: .style) ?? .linear
        reverse = try container.decodeIfPresent(Bool.self, forKey: .reverse) ?? false
        angle = try container.decodeIfPresent(CGFloat.self, forKey: .angle) ?? 0
        scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1
        startRed = try container.decodeIfPresent(Double.self, forKey: .startRed) ?? 0.12
        startGreen = try container.decodeIfPresent(Double.self, forKey: .startGreen) ?? 0.20
        startBlue = try container.decodeIfPresent(Double.self, forKey: .startBlue) ?? 0.95
        endRed = try container.decodeIfPresent(Double.self, forKey: .endRed) ?? 1.0
        endGreen = try container.decodeIfPresent(Double.self, forKey: .endGreen) ?? 0.50
        endBlue = try container.decodeIfPresent(Double.self, forKey: .endBlue) ?? 0.10
    }

    func normalized() -> ImageEditorGradientFillContent {
        ImageEditorGradientFillContent(
            preset: preset,
            style: style,
            reverse: reverse,
            angle: max(-180, min(180, angle)),
            scale: max(0.25, min(4, scale)),
            startRed: Self.zeroOne(startRed),
            startGreen: Self.zeroOne(startGreen),
            startBlue: Self.zeroOne(startBlue),
            endRed: Self.zeroOne(endRed),
            endGreen: Self.zeroOne(endGreen),
            endBlue: Self.zeroOne(endBlue)
        )
    }

    func colors(foreground: NSColor = .systemRed, background: NSColor = .clear) -> (start: SIMD3<Double>, end: SIMD3<Double>) {
        switch normalized().preset {
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
            let content = normalized()
            return (
                SIMD3<Double>(content.startRed, content.startGreen, content.startBlue),
                SIMD3<Double>(content.endRed, content.endGreen, content.endBlue)
            )
        }
    }

    func renderedImage(size: CGSize, foreground: NSColor = .systemRed, background: NSColor = .clear) -> NSImage {
        let content = normalized()
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let resolvedColors = content.colors(foreground: foreground, background: background)
        let start = content.reverse ? resolvedColors.end : resolvedColors.start
        let end = content.reverse ? resolvedColors.start : resolvedColors.end
        let radians = Double(content.angle) * Double.pi / 180
        let direction = SIMD2<Double>(cos(radians), sin(radians))
        let span = max(1, abs(direction.x) * Double(width) + abs(direction.y) * Double(height)) * Double(content.scale)
        let center = SIMD2<Double>(Double(width - 1) / 2, Double(height - 1) / 2)
        let cornerDistance = max(
            1,
            hypot(Double(width - 1) / 2, Double(height - 1) / 2) * Double(content.scale)
        )

        for y in 0..<height {
            for x in 0..<width {
                let point = SIMD2<Double>(Double(x), Double(y))
                let t = content.progress(at: point, center: center, direction: direction, span: span, cornerDistance: cornerDistance)
                let color = start + (end - start) * t
                let offset = y * bytesPerRow + x * bytesPerPixel
                pixels[offset] = Self.byte(color.x)
                pixels[offset + 1] = Self.byte(color.y)
                pixels[offset + 2] = Self.byte(color.z)
                pixels[offset + 3] = 255
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
    case liquifyPush
    case liquifyTwirl
    case liquifyPuckerBloat

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
    var liquifyPushX: Double = 0.25
    var liquifyPushY: Double = 0
    var liquifyTwirlAngle: Double = 0.5
    var liquifyBulgeAmount: Double = 0.5
    var offsetX: Double = 0.25
    var offsetY: Double = 0
    var waveAmplitude: Double = 0.5
    var waveFrequency: Double = 0.25
    var rippleAmount: Double = 0.5
    var rippleFrequency: Double = 0.25
    var pinchAmount: Double = 0.5
    var spherizeAmount: Double = 0.5

    init(
        unsharpRadius: Double = 1,
        unsharpThreshold: Double = 0,
        liquifyPushX: Double = 0.25,
        liquifyPushY: Double = 0,
        liquifyTwirlAngle: Double = 0.5,
        liquifyBulgeAmount: Double = 0.5,
        offsetX: Double = 0.25,
        offsetY: Double = 0,
        waveAmplitude: Double = 0.5,
        waveFrequency: Double = 0.25,
        rippleAmount: Double = 0.5,
        rippleFrequency: Double = 0.25,
        pinchAmount: Double = 0.5,
        spherizeAmount: Double = 0.5
    ) {
        self.unsharpRadius = unsharpRadius
        self.unsharpThreshold = unsharpThreshold
        self.liquifyPushX = liquifyPushX
        self.liquifyPushY = liquifyPushY
        self.liquifyTwirlAngle = liquifyTwirlAngle
        self.liquifyBulgeAmount = liquifyBulgeAmount
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.waveAmplitude = waveAmplitude
        self.waveFrequency = waveFrequency
        self.rippleAmount = rippleAmount
        self.rippleFrequency = rippleFrequency
        self.pinchAmount = pinchAmount
        self.spherizeAmount = spherizeAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unsharpRadius = try container.decodeIfPresent(Double.self, forKey: .unsharpRadius) ?? 1
        unsharpThreshold = try container.decodeIfPresent(Double.self, forKey: .unsharpThreshold) ?? 0
        liquifyPushX = try container.decodeIfPresent(Double.self, forKey: .liquifyPushX) ?? 0.25
        liquifyPushY = try container.decodeIfPresent(Double.self, forKey: .liquifyPushY) ?? 0
        liquifyTwirlAngle = try container.decodeIfPresent(Double.self, forKey: .liquifyTwirlAngle) ?? 0.5
        liquifyBulgeAmount = try container.decodeIfPresent(Double.self, forKey: .liquifyBulgeAmount) ?? 0.5
        offsetX = try container.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0.25
        offsetY = try container.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0
        waveAmplitude = try container.decodeIfPresent(Double.self, forKey: .waveAmplitude) ?? 0.5
        waveFrequency = try container.decodeIfPresent(Double.self, forKey: .waveFrequency) ?? 0.25
        rippleAmount = try container.decodeIfPresent(Double.self, forKey: .rippleAmount) ?? 0.5
        rippleFrequency = try container.decodeIfPresent(Double.self, forKey: .rippleFrequency) ?? 0.25
        pinchAmount = try container.decodeIfPresent(Double.self, forKey: .pinchAmount) ?? 0.5
        spherizeAmount = try container.decodeIfPresent(Double.self, forKey: .spherizeAmount) ?? 0.5
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(unsharpRadius, forKey: .unsharpRadius)
        try container.encode(unsharpThreshold, forKey: .unsharpThreshold)
        try container.encode(liquifyPushX, forKey: .liquifyPushX)
        try container.encode(liquifyPushY, forKey: .liquifyPushY)
        try container.encode(liquifyTwirlAngle, forKey: .liquifyTwirlAngle)
        try container.encode(liquifyBulgeAmount, forKey: .liquifyBulgeAmount)
        try container.encode(offsetX, forKey: .offsetX)
        try container.encode(offsetY, forKey: .offsetY)
        try container.encode(waveAmplitude, forKey: .waveAmplitude)
        try container.encode(waveFrequency, forKey: .waveFrequency)
        try container.encode(rippleAmount, forKey: .rippleAmount)
        try container.encode(rippleFrequency, forKey: .rippleFrequency)
        try container.encode(pinchAmount, forKey: .pinchAmount)
        try container.encode(spherizeAmount, forKey: .spherizeAmount)
    }

    func normalized() -> ImageEditorFilterSettings {
        ImageEditorFilterSettings(
            unsharpRadius: max(0.5, min(5, unsharpRadius)),
            unsharpThreshold: max(0, min(1, unsharpThreshold)),
            liquifyPushX: max(-1, min(1, liquifyPushX)),
            liquifyPushY: max(-1, min(1, liquifyPushY)),
            liquifyTwirlAngle: max(-1, min(1, liquifyTwirlAngle)),
            liquifyBulgeAmount: max(-1, min(1, liquifyBulgeAmount)),
            offsetX: max(-1, min(1, offsetX)),
            offsetY: max(-1, min(1, offsetY)),
            waveAmplitude: max(-1, min(1, waveAmplitude)),
            waveFrequency: max(0, min(1, waveFrequency)),
            rippleAmount: max(-1, min(1, rippleAmount)),
            rippleFrequency: max(0, min(1, rippleFrequency)),
            pinchAmount: max(-1, min(1, pinchAmount)),
            spherizeAmount: max(-1, min(1, spherizeAmount))
        )
    }

    private enum CodingKeys: String, CodingKey {
        case unsharpRadius
        case unsharpThreshold
        case liquifyPushX
        case liquifyPushY
        case liquifyTwirlAngle
        case liquifyBulgeAmount
        case offsetX
        case offsetY
        case waveAmplitude
        case waveFrequency
        case rippleAmount
        case rippleFrequency
        case pinchAmount
        case spherizeAmount
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
    var outerGlowNoise: CGFloat = 0
    var outerGlowContour = ImageEditorLayerEffectContour.linear
    var innerGlowEnabled = false
    var innerGlowColor = NSColor.systemCyan
    var innerGlowOpacity: CGFloat = 0.36
    var innerGlowBlur: CGFloat = 8
    var innerGlowChoke: CGFloat = 2
    var innerGlowNoise: CGFloat = 0
    var innerGlowSource = ImageEditorInnerGlowSource.edge
    var colorOverlayEnabled = false
    var colorOverlayColor = NSColor.systemRed
    var colorOverlayOpacity: CGFloat = 0.55
    var gradientOverlayEnabled = false
    var gradientOverlayStartColor = NSColor.systemRed
    var gradientOverlayEndColor = NSColor.white
    var gradientOverlayOpacity: CGFloat = 0.55
    var gradientOverlayStyle = ImageEditorGradientFillStyle.linear
    var gradientOverlayScale: CGFloat = 1
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

struct ImageEditorTextContent {
    static let drawingPadding: CGFloat = 4
    static let maximumBoxDimension: CGFloat = 12_000
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

    var font: NSFont {
        let size = max(6, fontSize)
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
        return style
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
        NSAttributedString(string: text, attributes: attributes)
    }

    func layerSize() -> CGSize {
        let measured: CGSize
        if boxWidth > 0 {
            let bounding = attributedString.boundingRect(
                with: CGSize(width: max(1, boxWidth), height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            measured = CGSize(
                width: max(boxWidth, ceil(bounding.width)),
                height: boxHeight > 0 ? boxHeight : ceil(bounding.height)
            )
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
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
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
            }
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
    var xomoComponentInstance: XomoComponentInstance?
    var isXomoThemeOverride = false

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
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: image.size.height) {
                NSColor.white.setFill()
                vectorMask.pathBezierPath().fill()
            }
        }
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
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
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
                let blurredGlow = glowCanvas.blurred(radius: style.outerGlowBlur) ?? glowCanvas
                let contouredGlow = blurredGlow.applyingEffectContour(style.outerGlowContour) ?? blurredGlow
                contouredGlow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: contouredGlow.size),
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

            if style.gradientOverlayEnabled,
               let gradientImage = ImageEditorGradientFillContent(
                   preset: .custom,
                   style: style.gradientOverlayStyle,
                   angle: style.gradientOverlayAngle,
                   scale: style.gradientOverlayScale,
                   startRed: Double(style.gradientOverlayStartColor.usingColorSpace(.deviceRGB)?.redComponent ?? 1),
                   startGreen: Double(style.gradientOverlayStartColor.usingColorSpace(.deviceRGB)?.greenComponent ?? 0),
                   startBlue: Double(style.gradientOverlayStartColor.usingColorSpace(.deviceRGB)?.blueComponent ?? 0),
                   endRed: Double(style.gradientOverlayEndColor.usingColorSpace(.deviceRGB)?.redComponent ?? 1),
                   endGreen: Double(style.gradientOverlayEndColor.usingColorSpace(.deviceRGB)?.greenComponent ?? 1),
                   endBlue: Double(style.gradientOverlayEndColor.usingColorSpace(.deviceRGB)?.blueComponent ?? 1)
               ).renderedImage(size: contentRect.size).withOpacity(style.gradientOverlayOpacity) {
                let gradientCanvas = NSImage.rendered(size: outputSize) { _ in
                    gradientImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: gradientImage.size),
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
                let innerGlowCanvas = style.innerGlowSource == .center
                    ? rawInnerGlowCanvas.shadowNoised(amount: style.innerGlowNoise) ?? rawInnerGlowCanvas
                    : rawInnerGlowCanvas
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
    func applyingEffectContour(_ contour: ImageEditorLayerEffectContour) -> NSImage? {
        guard contour != .linear else { return self }
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
                let mappedAlpha = contour.mappedAlpha(alpha)
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
