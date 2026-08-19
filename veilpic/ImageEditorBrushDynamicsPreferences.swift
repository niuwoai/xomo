//
//  ImageEditorBrushDynamicsPreferences.swift
//  veilpic
//
//  Created by Codex on 2026/7/12.
//

import Foundation

enum ImageEditorPressureSensitivityPresets {
    static let values: [CGFloat] = [0, 25, 50, 75, 100]
}

enum ImageEditorBrushMinimumDiameterPresets {
    static let values: [CGFloat] = [0, 10, 25, 50, 75, 100]
}

enum ImageEditorBrushSizeJitterPresets {
    static let values: [CGFloat] = [0, 10, 25, 50, 75, 100]
}

enum ImageEditorBrushMinimumOpacityPresets {
    static let values: [CGFloat] = [0, 10, 25, 50, 75, 100]
}

enum ImageEditorBrushMinimumFlowPresets {
    static let values: [CGFloat] = [0, 10, 25, 50, 75, 100]
}

enum ImageEditorBrushSmoothingPresets {
    static let values: [CGFloat] = [0, 10, 25, 50, 75, 100]
}

enum ImageEditorBrushRoundnessPresets {
    static let values: [CGFloat] = [10, 25, 50, 75, 100]
}

enum ImageEditorBrushAnglePresets {
    static let values: [CGFloat] = [-90, -45, 0, 45, 90]
}

enum ImageEditorBrushAngleJitterPresets {
    static let values: [CGFloat] = [0, 10, 25, 50, 75, 100]
}

enum ImageEditorBrushRoundnessJitterPresets {
    static let values: [CGFloat] = [0, 10, 25, 50, 75, 100]
}

enum ImageEditorBrushMinimumRoundnessPresets {
    static let values: [CGFloat] = [1, 10, 25, 50, 75, 100]
}

enum ImageEditorBrushScatterPresets {
    static let values: [CGFloat] = [0, 25, 50, 100, 200, 500, 1_000]
}

enum ImageEditorBrushScatterCountPresets {
    static let values: [Int] = [1, 2, 3, 4, 8, 16]
}

enum ImageEditorBrushScatterCountJitterPresets {
    static let values: [CGFloat] = [0, 10, 25, 50, 75, 100]
}

struct ImageEditorBrushDynamicsPreferences: Codable, Equatable {
    static let storageKey = "im.some.xomo.imageEditor.brushDynamicsPreferences"
    static let defaultValue = ImageEditorBrushDynamicsPreferences(
        pressureControlsSize: true,
        pressureControlsOpacity: false,
        pressureControlsFlow: true,
        pressureSensitivity: 50,
        sizeJitter: 0,
        angleJitter: 0,
        roundnessJitter: 0,
        minimumRoundness: 1,
        scatter: 0,
        scatterBothAxes: false,
        scatterCount: 1,
        scatterCountJitter: 0,
        minimumDiameter: 0,
        minimumOpacity: 0,
        minimumFlow: 0,
        tiltControlsShape: false,
        tipRoundness: 100,
        tipAngleDegrees: 0,
        smoothing: 0,
        paintBlendMode: .normal,
        paintAirbrushEnabled: false,
        historyBrushBlendMode: .normal,
        pencilAutoEraseEnabled: false
    )

    var pressureControlsSize: Bool
    var pressureControlsOpacity: Bool
    var pressureControlsFlow: Bool
    var pressureSensitivity: Double
    var sizeJitter: Double
    var angleJitter: Double
    var roundnessJitter: Double
    var minimumRoundness: Double
    var scatter: Double
    var scatterBothAxes: Bool
    var scatterCount: Int
    var scatterCountJitter: Double
    var minimumDiameter: Double
    var minimumOpacity: Double
    var minimumFlow: Double
    var tiltControlsShape: Bool
    var tipRoundness: Double
    var tipAngleDegrees: Double
    var smoothing: Double
    var paintBlendMode: ImageEditorBlendMode
    var paintAirbrushEnabled: Bool
    var historyBrushBlendMode: ImageEditorBlendMode
    var pencilAutoEraseEnabled: Bool

    init(
        pressureControlsSize: Bool,
        pressureControlsOpacity: Bool = false,
        pressureControlsFlow: Bool,
        pressureSensitivity: Double,
        sizeJitter: Double = 0,
        angleJitter: Double = 0,
        roundnessJitter: Double = 0,
        minimumRoundness: Double = 1,
        scatter: Double = 0,
        scatterBothAxes: Bool = false,
        scatterCount: Int = 1,
        scatterCountJitter: Double = 0,
        minimumDiameter: Double = 0,
        minimumOpacity: Double = 0,
        minimumFlow: Double = 0,
        tiltControlsShape: Bool = false,
        tipRoundness: Double = 100,
        tipAngleDegrees: Double = 0,
        smoothing: Double = 0,
        paintBlendMode: ImageEditorBlendMode = .normal,
        paintAirbrushEnabled: Bool = false,
        historyBrushBlendMode: ImageEditorBlendMode = .normal,
        pencilAutoEraseEnabled: Bool = false
    ) {
        self.pressureControlsSize = pressureControlsSize
        self.pressureControlsOpacity = pressureControlsOpacity
        self.pressureControlsFlow = pressureControlsFlow
        self.pressureSensitivity = pressureSensitivity
        self.sizeJitter = sizeJitter
        self.angleJitter = angleJitter
        self.roundnessJitter = roundnessJitter
        self.minimumRoundness = minimumRoundness
        self.scatter = scatter
        self.scatterBothAxes = scatterBothAxes
        self.scatterCount = scatterCount
        self.scatterCountJitter = scatterCountJitter
        self.minimumDiameter = minimumDiameter
        self.minimumOpacity = minimumOpacity
        self.minimumFlow = minimumFlow
        self.tiltControlsShape = tiltControlsShape
        self.tipRoundness = tipRoundness
        self.tipAngleDegrees = tipAngleDegrees
        self.smoothing = smoothing
        self.paintBlendMode = paintBlendMode
        self.paintAirbrushEnabled = paintAirbrushEnabled
        self.historyBrushBlendMode = historyBrushBlendMode
        self.pencilAutoEraseEnabled = pencilAutoEraseEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case pressureControlsSize
        case pressureControlsOpacity
        case pressureControlsFlow
        case pressureSensitivity
        case sizeJitter
        case angleJitter
        case roundnessJitter
        case minimumRoundness
        case scatter
        case scatterBothAxes
        case scatterCount
        case scatterCountJitter
        case minimumDiameter
        case minimumOpacity
        case minimumFlow
        case tiltControlsShape
        case tipRoundness
        case tipAngleDegrees
        case smoothing
        case paintBlendMode
        case paintAirbrushEnabled
        case historyBrushBlendMode
        case pencilAutoEraseEnabled
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        pressureControlsSize = try values.decode(Bool.self, forKey: .pressureControlsSize)
        pressureControlsOpacity = try values.decodeIfPresent(
            Bool.self,
            forKey: .pressureControlsOpacity
        ) ?? false
        pressureControlsFlow = try values.decode(Bool.self, forKey: .pressureControlsFlow)
        pressureSensitivity = try values.decode(Double.self, forKey: .pressureSensitivity)
        sizeJitter = try values.decodeIfPresent(Double.self, forKey: .sizeJitter) ?? 0
        angleJitter = try values.decodeIfPresent(Double.self, forKey: .angleJitter) ?? 0
        roundnessJitter = try values.decodeIfPresent(Double.self, forKey: .roundnessJitter) ?? 0
        minimumRoundness = try values.decodeIfPresent(
            Double.self,
            forKey: .minimumRoundness
        ) ?? 1
        scatter = try values.decodeIfPresent(Double.self, forKey: .scatter) ?? 0
        scatterBothAxes = try values.decodeIfPresent(
            Bool.self,
            forKey: .scatterBothAxes
        ) ?? false
        scatterCount = try values.decodeIfPresent(Int.self, forKey: .scatterCount) ?? 1
        scatterCountJitter = try values.decodeIfPresent(
            Double.self,
            forKey: .scatterCountJitter
        ) ?? 0
        minimumDiameter = try values.decodeIfPresent(
            Double.self,
            forKey: .minimumDiameter
        ) ?? 0
        minimumOpacity = try values.decodeIfPresent(
            Double.self,
            forKey: .minimumOpacity
        ) ?? 0
        minimumFlow = try values.decodeIfPresent(
            Double.self,
            forKey: .minimumFlow
        ) ?? 0
        tiltControlsShape = try values.decodeIfPresent(
            Bool.self,
            forKey: .tiltControlsShape
        ) ?? false
        tipRoundness = try values.decodeIfPresent(
            Double.self,
            forKey: .tipRoundness
        ) ?? 100
        tipAngleDegrees = try values.decodeIfPresent(
            Double.self,
            forKey: .tipAngleDegrees
        ) ?? 0
        smoothing = try values.decodeIfPresent(
            Double.self,
            forKey: .smoothing
        ) ?? 0
        paintBlendMode = try values.decodeIfPresent(
            ImageEditorBlendMode.self,
            forKey: .paintBlendMode
        ) ?? .normal
        paintAirbrushEnabled = try values.decodeIfPresent(
            Bool.self,
            forKey: .paintAirbrushEnabled
        ) ?? false
        historyBrushBlendMode = try values.decodeIfPresent(
            ImageEditorBlendMode.self,
            forKey: .historyBrushBlendMode
        ) ?? .normal
        pencilAutoEraseEnabled = try values.decodeIfPresent(
            Bool.self,
            forKey: .pencilAutoEraseEnabled
        ) ?? false
    }

    var normalized: ImageEditorBrushDynamicsPreferences {
        ImageEditorBrushDynamicsPreferences(
            pressureControlsSize: pressureControlsSize,
            pressureControlsOpacity: pressureControlsOpacity,
            pressureControlsFlow: pressureControlsFlow,
            pressureSensitivity: max(0, min(100, pressureSensitivity)),
            sizeJitter: max(0, min(100, sizeJitter)),
            angleJitter: max(0, min(100, angleJitter)),
            roundnessJitter: max(0, min(100, roundnessJitter)),
            minimumRoundness: max(1, min(100, minimumRoundness)),
            scatter: max(0, min(1_000, scatter)),
            scatterBothAxes: scatterBothAxes,
            scatterCount: max(1, min(16, scatterCount)),
            scatterCountJitter: max(0, min(100, scatterCountJitter)),
            minimumDiameter: max(0, min(100, minimumDiameter)),
            minimumOpacity: max(0, min(100, minimumOpacity)),
            minimumFlow: max(0, min(100, minimumFlow)),
            tiltControlsShape: tiltControlsShape,
            tipRoundness: max(10, min(100, tipRoundness)),
            tipAngleDegrees: max(-180, min(180, tipAngleDegrees)),
            smoothing: max(0, min(100, smoothing)),
            paintBlendMode: ImageEditorBlendMode.paintCases.contains(paintBlendMode)
                ? paintBlendMode
                : .normal,
            paintAirbrushEnabled: paintAirbrushEnabled,
            historyBrushBlendMode: historyBrushBlendMode == .passThrough
                ? .normal
                : historyBrushBlendMode,
            pencilAutoEraseEnabled: pencilAutoEraseEnabled
        )
    }

    static func load(from defaults: UserDefaults) -> ImageEditorBrushDynamicsPreferences {
        guard let data = defaults.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(
                ImageEditorBrushDynamicsPreferences.self,
                from: data
              )
        else { return defaultValue }
        return preferences.normalized
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// Keeps Dodge, Burn, and Sponge tablet dynamics independent from the paint
/// brush. Photoshop exposes this as a tool-option toggle and leaves it off by
/// default, so changing a retouch tool must not silently alter Brush dynamics.
struct ImageEditorRetouchDynamicsPreferences: Codable, Equatable {
    static let storageKey = "im.some.xomo.imageEditor.retouchDynamicsPreferences"
    static let defaultValue = ImageEditorRetouchDynamicsPreferences(
        pressureControlsSize: false,
        pressureSensitivity: 50
    )

    var pressureControlsSize: Bool
    var pressureSensitivity: Double

    var normalized: ImageEditorRetouchDynamicsPreferences {
        ImageEditorRetouchDynamicsPreferences(
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: max(0, min(100, pressureSensitivity))
        )
    }

    static func load(from defaults: UserDefaults) -> ImageEditorRetouchDynamicsPreferences {
        guard let data = defaults.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(
                ImageEditorRetouchDynamicsPreferences.self,
                from: data
              )
        else { return defaultValue }
        return preferences.normalized
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

struct ImageEditorBrushPresetPreferences: Codable, Equatable {
    static let storageKey = "im.some.xomo.imageEditor.customBrushPresets"
    static let maximumPresetCount = 100

    var presets: [ImageEditorBrushPreset]

    var normalized: ImageEditorBrushPresetPreferences {
        var seenIDs = Set<String>()
        let normalizedPresets = presets.compactMap { preset -> ImageEditorBrushPreset? in
            let normalized = preset.normalizedCustomPreset
            guard seenIDs.insert(normalized.id).inserted else { return nil }
            return normalized
        }
        return ImageEditorBrushPresetPreferences(
            presets: Array(normalizedPresets.prefix(Self.maximumPresetCount))
        )
    }

    static func load(from defaults: UserDefaults) -> ImageEditorBrushPresetPreferences {
        guard let data = defaults.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(
                ImageEditorBrushPresetPreferences.self,
                from: data
              )
        else { return ImageEditorBrushPresetPreferences(presets: []) }
        return preferences.normalized
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
