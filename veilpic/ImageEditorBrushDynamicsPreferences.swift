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

struct ImageEditorBrushDynamicsPreferences: Codable, Equatable {
    static let storageKey = "im.some.xomo.imageEditor.brushDynamicsPreferences"
    static let defaultValue = ImageEditorBrushDynamicsPreferences(
        pressureControlsSize: true,
        pressureControlsOpacity: false,
        pressureControlsFlow: true,
        pressureSensitivity: 50,
        minimumDiameter: 0,
        minimumFlow: 0,
        tiltControlsShape: false,
        tipRoundness: 100,
        tipAngleDegrees: 0,
        smoothing: 0
    )

    var pressureControlsSize: Bool
    var pressureControlsOpacity: Bool
    var pressureControlsFlow: Bool
    var pressureSensitivity: Double
    var minimumDiameter: Double
    var minimumFlow: Double
    var tiltControlsShape: Bool
    var tipRoundness: Double
    var tipAngleDegrees: Double
    var smoothing: Double

    init(
        pressureControlsSize: Bool,
        pressureControlsOpacity: Bool = false,
        pressureControlsFlow: Bool,
        pressureSensitivity: Double,
        minimumDiameter: Double = 0,
        minimumFlow: Double = 0,
        tiltControlsShape: Bool = false,
        tipRoundness: Double = 100,
        tipAngleDegrees: Double = 0,
        smoothing: Double = 0
    ) {
        self.pressureControlsSize = pressureControlsSize
        self.pressureControlsOpacity = pressureControlsOpacity
        self.pressureControlsFlow = pressureControlsFlow
        self.pressureSensitivity = pressureSensitivity
        self.minimumDiameter = minimumDiameter
        self.minimumFlow = minimumFlow
        self.tiltControlsShape = tiltControlsShape
        self.tipRoundness = tipRoundness
        self.tipAngleDegrees = tipAngleDegrees
        self.smoothing = smoothing
    }

    private enum CodingKeys: String, CodingKey {
        case pressureControlsSize
        case pressureControlsOpacity
        case pressureControlsFlow
        case pressureSensitivity
        case minimumDiameter
        case minimumFlow
        case tiltControlsShape
        case tipRoundness
        case tipAngleDegrees
        case smoothing
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
        minimumDiameter = try values.decodeIfPresent(
            Double.self,
            forKey: .minimumDiameter
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
    }

    var normalized: ImageEditorBrushDynamicsPreferences {
        ImageEditorBrushDynamicsPreferences(
            pressureControlsSize: pressureControlsSize,
            pressureControlsOpacity: pressureControlsOpacity,
            pressureControlsFlow: pressureControlsFlow,
            pressureSensitivity: max(0, min(100, pressureSensitivity)),
            minimumDiameter: max(0, min(100, minimumDiameter)),
            minimumFlow: max(0, min(100, minimumFlow)),
            tiltControlsShape: tiltControlsShape,
            tipRoundness: max(10, min(100, tipRoundness)),
            tipAngleDegrees: max(-180, min(180, tipAngleDegrees)),
            smoothing: max(0, min(100, smoothing))
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
