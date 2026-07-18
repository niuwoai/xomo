//
//  ImageEditorSpongeModeShortcut.swift
//  veilpic
//
//  Created by Codex on 2026/7/19.
//

import AppKit

/// Resolves Photoshop-compatible Sponge mode shortcuts only while the Sponge
/// tool is the active canvas interaction tool.
enum ImageEditorSpongeModeShortcut {
    static let modifierFlags: NSEvent.ModifierFlags = [.shift, .option]

    static func resolve(
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags,
        activeTool: ImageEditorTool?
    ) -> ImageEditorSpongeMode? {
        guard activeTool == .sponge else { return nil }
        let relevantFlags = modifierFlags.intersection([.command, .option, .shift, .control])
        guard relevantFlags == Self.modifierFlags else { return nil }

        switch charactersIgnoringModifiers?.lowercased() {
        case "s": return .saturate
        case "d": return .desaturate
        default: return nil
        }
    }

    static func displayLabel(for mode: ImageEditorSpongeMode) -> String {
        switch mode {
        case .saturate: return "⇧⌥S"
        case .desaturate: return "⇧⌥D"
        }
    }

    static var helpText: String {
        L10n.format(
            "imageEditor.option.spongeMode.help",
            ImageEditorSpongeMode.saturate.title,
            displayLabel(for: .saturate),
            ImageEditorSpongeMode.desaturate.title,
            displayLabel(for: .desaturate)
        )
    }
}
