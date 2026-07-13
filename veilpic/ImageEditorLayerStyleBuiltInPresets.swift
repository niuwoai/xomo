//
//  ImageEditorLayerStyleBuiltInPresets.swift
//  veilpic
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import Foundation

enum ImageEditorLayerStyleBuiltInPresetCatalog {
    static var presets: [ImageEditorLayerStylePreset] {
        [
            preset("softShadow", nameKey: "imageEditor.layerStylePreset.builtIn.softShadow", style: softShadow()),
            preset("cleanOutline", nameKey: "imageEditor.layerStylePreset.builtIn.cleanOutline", style: cleanOutline()),
            preset("glassButton", nameKey: "imageEditor.layerStylePreset.builtIn.glassButton", style: glassButton()),
            preset("goldBevel", nameKey: "imageEditor.layerStylePreset.builtIn.goldBevel", style: goldBevel()),
            preset("neonGlow", nameKey: "imageEditor.layerStylePreset.builtIn.neonGlow", style: neonGlow()),
            preset("sticker", nameKey: "imageEditor.layerStylePreset.builtIn.sticker", style: sticker())
        ]
    }

    private static func preset(
        _ identifier: String,
        nameKey: String,
        style: ImageEditorLayerStyle
    ) -> ImageEditorLayerStylePreset {
        ImageEditorLayerStylePreset(
            id: ImageEditorLayerStylePreset.builtInIDPrefix + identifier,
            name: L10n.text(nameKey),
            style: ImageEditorProjectLayerStyle(style: style)
        )
    }

    private static func softShadow() -> ImageEditorLayerStyle {
        var style = ImageEditorLayerStyle()
        style.shadowEnabled = true
        style.shadowColor = .black
        style.shadowOpacity = 0.28
        style.shadowBlur = 9
        style.shadowDistance = 6
        style.shadowAngle = -48
        style.shadowUsesGlobalLight = false
        return style
    }

    private static func cleanOutline() -> ImageEditorLayerStyle {
        var style = ImageEditorLayerStyle()
        style.strokeEnabled = true
        style.strokeColor = color(red: 0.08, green: 0.42, blue: 0.92)
        style.strokeWidth = 3
        style.strokePosition = .inside
        style.strokeOpacity = 1
        return style
    }

    private static func glassButton() -> ImageEditorLayerStyle {
        var style = ImageEditorLayerStyle()
        style.strokeEnabled = true
        style.strokeColor = color(red: 0.72, green: 0.90, blue: 1)
        style.strokeWidth = 2
        style.strokePosition = .inside
        style.gradientOverlayEnabled = true
        style.gradientOverlayStartColor = color(red: 0.82, green: 0.96, blue: 1)
        style.gradientOverlayEndColor = color(red: 0.05, green: 0.42, blue: 0.78)
        style.gradientOverlayOpacity = 0.82
        style.gradientOverlayAngle = -90
        style.innerShadowEnabled = true
        style.innerShadowColor = .white
        style.innerShadowOpacity = 0.48
        style.innerShadowBlur = 4
        style.innerShadowDistance = 2
        style.innerShadowAngle = 90
        style.innerShadowUsesGlobalLight = false
        style.bevelEnabled = true
        style.bevelSize = 3
        style.bevelOpacity = 0.32
        return style
    }

    private static func goldBevel() -> ImageEditorLayerStyle {
        var style = ImageEditorLayerStyle()
        style.gradientOverlayEnabled = true
        style.gradientOverlayStartColor = color(red: 1, green: 0.91, blue: 0.38)
        style.gradientOverlayEndColor = color(red: 0.52, green: 0.20, blue: 0.03)
        style.gradientOverlayOpacity = 0.95
        style.gradientOverlayAngle = -90
        style.strokeEnabled = true
        style.strokeColor = color(red: 0.38, green: 0.13, blue: 0.01)
        style.strokeWidth = 2
        style.strokePosition = .inside
        style.bevelEnabled = true
        style.bevelHighlightColor = color(red: 1, green: 0.98, blue: 0.72)
        style.bevelShadowColor = color(red: 0.20, green: 0.06, blue: 0)
        style.bevelOpacity = 0.72
        style.bevelSize = 5
        style.bevelSoften = 1
        style.shadowEnabled = true
        style.shadowOpacity = 0.28
        style.shadowBlur = 5
        style.shadowDistance = 3
        return style
    }

    private static func neonGlow() -> ImageEditorLayerStyle {
        let magenta = color(red: 1, green: 0.08, blue: 0.72)
        var style = ImageEditorLayerStyle()
        style.colorOverlayEnabled = true
        style.colorOverlayColor = color(red: 0.26, green: 0.02, blue: 0.24)
        style.colorOverlayOpacity = 0.88
        style.strokeEnabled = true
        style.strokeColor = magenta
        style.strokeWidth = 2
        style.strokePosition = .outside
        style.outerGlowEnabled = true
        style.outerGlowColor = magenta
        style.outerGlowOpacity = 0.82
        style.outerGlowBlur = 9
        style.outerGlowSpread = 3
        return style
    }

    private static func sticker() -> ImageEditorLayerStyle {
        var style = ImageEditorLayerStyle()
        style.strokeEnabled = true
        style.strokeColor = .white
        style.strokeWidth = 6
        style.strokePosition = .outside
        style.shadowEnabled = true
        style.shadowColor = .black
        style.shadowOpacity = 0.32
        style.shadowBlur = 5
        style.shadowDistance = 5
        style.shadowAngle = -55
        style.shadowUsesGlobalLight = false
        return style
    }

    private static func color(red: CGFloat, green: CGFloat, blue: CGFloat) -> NSColor {
        NSColor(deviceRed: red, green: green, blue: blue, alpha: 1)
    }
}

@MainActor
extension ImageEditorViewModel {
    var builtInLayerStylePresets: [ImageEditorLayerStylePreset] {
        ImageEditorLayerStyleBuiltInPresetCatalog.presets
    }

    var availableLayerStylePresets: [ImageEditorLayerStylePreset] {
        builtInLayerStylePresets + customLayerStylePresets
    }

    func layerStylePreset(id: String) -> ImageEditorLayerStylePreset? {
        availableLayerStylePresets.first { $0.id == id }
    }

    @discardableResult
    func duplicateLayerStylePresetToCustom(
        _ source: ImageEditorLayerStylePreset
    ) -> ImageEditorLayerStylePreset? {
        guard customLayerStylePresets.count < ImageEditorLayerStylePresetPreferences.maximumPresetCount else {
            statusText = L10n.format(
                "imageEditor.status.layerStylePresetLimitReached",
                ImageEditorLayerStylePresetPreferences.maximumPresetCount
            )
            return nil
        }

        let existingNames = Set(customLayerStylePresets.map(\.name))
        let firstCandidate = L10n.format("imageEditor.layerStylePreset.copyName", source.title)
        var candidate = firstCandidate
        var sequence = 2
        while existingNames.contains(candidate) {
            candidate = L10n.format(
                "imageEditor.layerStylePreset.copyNameNumbered",
                source.title,
                sequence
            )
            sequence += 1
        }

        let copy = ImageEditorLayerStylePreset(
            id: UUID().uuidString,
            name: candidate,
            style: source.style
        ).normalizedCustomPreset
        customLayerStylePresets.append(copy)
        persistLayerStylePresetPreferences()
        statusText = L10n.format("imageEditor.status.layerStylePresetDuplicated", copy.title)
        return copy
    }
}
