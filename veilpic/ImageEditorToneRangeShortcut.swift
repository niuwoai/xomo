//
//  ImageEditorToneRangeShortcut.swift
//  veilpic
//
//  Created by Codex on 2026/7/19.
//

import AppKit

/// Resolves Photoshop-compatible Dodge/Burn range shortcuts without turning
/// them into global editor commands. The shortcuts are valid only while a
/// tone brush is the active canvas interaction tool.
enum ImageEditorToneRangeShortcut {
    static let modifierFlags: NSEvent.ModifierFlags = [.shift, .option]

    static func resolve(
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags,
        activeTool: ImageEditorTool?
    ) -> ImageEditorToneRange? {
        guard activeTool == .dodge || activeTool == .burn else { return nil }
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])
        guard relevantFlags == Self.modifierFlags else { return nil }

        switch charactersIgnoringModifiers?.lowercased() {
        case "s": return .shadows
        case "m": return .midtones
        case "h": return .highlights
        default: return nil
        }
    }

    static func displayLabel(for range: ImageEditorToneRange) -> String {
        switch range {
        case .shadows: return "⇧⌥S"
        case .midtones: return "⇧⌥M"
        case .highlights: return "⇧⌥H"
        }
    }

    static var helpText: String {
        L10n.format(
            "imageEditor.option.toneRange.help",
            ImageEditorToneRange.shadows.title,
            displayLabel(for: .shadows),
            ImageEditorToneRange.midtones.title,
            displayLabel(for: .midtones),
            ImageEditorToneRange.highlights.title,
            displayLabel(for: .highlights)
        )
    }
}
