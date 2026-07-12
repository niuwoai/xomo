//
//  ImageEditorBrushDynamicsPreferences.swift
//  veilpic
//
//  Created by Codex on 2026/7/12.
//

import Foundation

struct ImageEditorBrushDynamicsPreferences: Codable, Equatable {
    static let storageKey = "im.some.xomo.imageEditor.brushDynamicsPreferences"
    static let defaultValue = ImageEditorBrushDynamicsPreferences(
        pressureControlsSize: true,
        pressureControlsFlow: true,
        pressureSensitivity: 50
    )

    var pressureControlsSize: Bool
    var pressureControlsFlow: Bool
    var pressureSensitivity: Double

    var normalized: ImageEditorBrushDynamicsPreferences {
        ImageEditorBrushDynamicsPreferences(
            pressureControlsSize: pressureControlsSize,
            pressureControlsFlow: pressureControlsFlow,
            pressureSensitivity: max(0, min(100, pressureSensitivity))
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
