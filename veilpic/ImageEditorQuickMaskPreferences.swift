//
//  ImageEditorQuickMaskPreferences.swift
//  veilpic
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import Foundation

enum ImageEditorQuickMaskOverlayTarget: String, CaseIterable, Codable, Identifiable {
    case maskedAreas
    case selectedAreas

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.quickMask.target.\(rawValue)")
    }
}

enum ImageEditorQuickMaskControlAction: Equatable {
    case toggleMode
    case toggleOverlayTarget

    static func resolve(modifierFlags: NSEvent.ModifierFlags) -> Self {
        let relevantFlags = modifierFlags.intersection([.command, .control, .option, .shift])
        return relevantFlags == [.option] ? .toggleOverlayTarget : .toggleMode
    }
}

enum ImageEditorQuickMaskPreviewMode: String, CaseIterable, Identifiable {
    case overlay
    case grayscale

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.quickMask.preview.\(rawValue)")
    }
}

struct ImageEditorQuickMaskPreferences: Codable, Equatable {
    static let storageKey = "im.some.xomo.imageEditor.quickMaskPreferences"
    static let minimumOpacity = 0.05
    static let maximumOpacity = 1.0
    static let defaultValue = ImageEditorQuickMaskPreferences(
        target: .maskedAreas,
        color: ImageEditorProjectColor(
            color: NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        ),
        opacity: 0.5
    )

    var target: ImageEditorQuickMaskOverlayTarget
    var color: ImageEditorProjectColor
    var opacity: Double

    var normalized: ImageEditorQuickMaskPreferences {
        ImageEditorQuickMaskPreferences(
            target: target,
            color: ImageEditorProjectColor(color: color.nsColor),
            opacity: max(Self.minimumOpacity, min(Self.maximumOpacity, opacity))
        )
    }

    static func load(from defaults: UserDefaults) -> ImageEditorQuickMaskPreferences {
        guard let data = defaults.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(ImageEditorQuickMaskPreferences.self, from: data)
        else { return defaultValue }
        return preferences.normalized
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
