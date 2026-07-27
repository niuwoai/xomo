//
//  ImageEditorLayerSummary.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import Foundation
import CoreGraphics
import AppKit

extension ImageEditorViewModel {
    var selectedLayerGeometryText: String {
        guard let layer = document.selectedLayer else { return "W 0 H 0" }
        guard !layer.isGroup else { return L10n.text("imageEditor.properties.groupLayer") }
        if let adjustment = layer.adjustment {
            return adjustmentLayerSummary(layer: layer, adjustment: adjustment)
        }
        if let filter = layer.filter {
            if filter.kind == .unsharpMask {
                let settings = layer.filterSettings.normalized()
                return L10n.format(
                    "imageEditor.properties.unsharpFilterLayerValue",
                    Int((filter.intensity * 100).rounded()),
                    String(format: "%.1f", settings.unsharpRadius),
                    Int((settings.unsharpThreshold * 255).rounded())
                )
            }
            return L10n.format(
                "imageEditor.properties.filterLayerValue",
                filter.kind.title,
                Int((filter.intensity * 100).rounded())
            )
        }
        if let solidColorFillContent = layer.solidColorFillContent?.normalized() {
            return L10n.format(
                "imageEditor.properties.solidColorFillLayerValue",
                Int((solidColorFillContent.red * 255).rounded()),
                Int((solidColorFillContent.green * 255).rounded()),
                Int((solidColorFillContent.blue * 255).rounded())
            )
        }
        if let patternFillContent = layer.patternFillContent?.normalized() {
            return L10n.format(
                "imageEditor.properties.patternFillLayerValue",
                patternFillContent.kind.title,
                Int((patternFillContent.opacity * 100).rounded()),
                Int(patternFillContent.scale.rounded()),
                Int(patternFillContent.offsetX.rounded()),
                Int(patternFillContent.offsetY.rounded())
            )
        }
        if let gradientFillContent = layer.gradientFillContent?.normalized() {
            return L10n.format(
                "imageEditor.properties.gradientFillLayerValue",
                gradientFillContent.preset.title,
                gradientFillContent.style.title,
                Int(gradientFillContent.angle.rounded()),
                Int((gradientFillContent.scale * 100).rounded())
            )
        }
        if let textContent = layer.textContent {
            return L10n.format(
                "imageEditor.properties.textLayerValue",
                textContent.text,
                Int(textContent.fontSize.rounded())
            )
        }
        if let shapeContent = layer.shapeContent {
            return L10n.format(
                "imageEditor.properties.shapeLayerValue",
                shapeContent.kind.title,
                Int(layer.frame.width.rounded()),
                Int(layer.frame.height.rounded())
            )
        }
        return "X \(Int(layer.frame.minX.rounded()))  Y \(Int(layer.frame.minY.rounded()))  W \(Int(layer.frame.width.rounded()))  H \(Int(layer.frame.height.rounded()))"
    }

    private func adjustmentLayerSummary(
        layer: ImageEditorLayer,
        adjustment: (kind: ImageEditorAdjustment, amount: Double)
    ) -> String {
        let settings = layer.adjustmentSettings.normalized()
        switch adjustment.kind {
        case .levels:
            return L10n.format(
                "imageEditor.properties.levelsLayerValue",
                Int((settings.levelsBlackPoint * 255).rounded()),
                String(format: "%.2f", settings.levelsGamma),
                Int((settings.levelsWhitePoint * 255).rounded())
            )
        case .curves:
            return L10n.format(
                "imageEditor.properties.curvesLayerValue",
                Int((settings.curvesShadows * 100).rounded()),
                Int((settings.curvesMidtones * 100).rounded()),
                Int((settings.curvesHighlights * 100).rounded())
            )
        case .colorBalance:
            return L10n.text("imageEditor.properties.colorBalanceLayerValue")
        case .hueSaturation:
            return L10n.format(
                "imageEditor.properties.hueSaturationLayerValue",
                Int(settings.hueSaturationHue.rounded()),
                Int((settings.hueSaturationSaturation * 100).rounded()),
                Int((settings.hueSaturationLightness * 100).rounded())
            )
        case .brightnessContrast:
            return L10n.format(
                "imageEditor.properties.brightnessContrastLayerValue",
                Int((settings.brightnessContrastBrightness * 100).rounded()),
                Int((settings.brightnessContrastContrast * 100).rounded())
            )
        case .exposure:
            return L10n.format(
                "imageEditor.properties.exposureLayerValue",
                settings.exposureEV,
                settings.exposureOffset,
                settings.exposureGamma
            )
        case .shadowsHighlights:
            return L10n.format(
                "imageEditor.properties.shadowsHighlightsLayerValue",
                Int((settings.shadowsHighlightsShadows * 100).rounded()),
                Int((settings.shadowsHighlightsHighlights * 100).rounded())
            )
        case .vibrance:
            return L10n.format(
                "imageEditor.properties.vibranceLayerValue",
                Int((settings.vibranceAmount * 100).rounded()),
                Int((settings.vibranceSaturation * 100).rounded())
            )
        case .posterize:
            return L10n.format(
                "imageEditor.properties.posterizeLayerValue",
                NSImage.posterizeLevelCount(from: adjustment.amount)
            )
        case .blackWhite:
            return L10n.text("imageEditor.properties.blackWhiteLayerValue")
        case .channelMixer:
            return channelMixerLayerSummary(settings)
        case .photoFilter:
            return L10n.format(
                "imageEditor.properties.photoFilterLayerValue",
                settings.photoFilterPreset.title,
                Int((settings.photoFilterDensity * 100).rounded())
            )
        case .colorLookup:
            return L10n.format(
                "imageEditor.properties.colorLookupLayerValue",
                Self.colorLookupTitle(settings)
            )
        case .selectiveColor:
            return L10n.format(
                "imageEditor.properties.selectiveColorLayerValue",
                settings.selectiveColorMethod.title
            )
        case .gradientMap:
            if settings.gradientMapDither {
                return L10n.format(
                    "imageEditor.properties.gradientMapDitherLayerValue",
                    settings.gradientMapPreset.title
                )
            }
            return L10n.format(
                "imageEditor.properties.gradientMapLayerValue",
                settings.gradientMapPreset.title
            )
        default:
            return L10n.format(
                "imageEditor.properties.adjustmentLayerValue",
                adjustment.kind.title,
                Int((adjustment.amount * 100).rounded())
            )
        }
    }

    private func channelMixerLayerSummary(_ settings: ImageEditorAdjustmentSettings) -> String {
        if settings.channelMixerMonochrome {
            return L10n.format(
                "imageEditor.properties.channelMixerMonoLayerValue",
                Int((settings.channelMixerMonoRed * 100).rounded()),
                Int((settings.channelMixerMonoGreen * 100).rounded()),
                Int((settings.channelMixerMonoBlue * 100).rounded())
            )
        }
        return L10n.text("imageEditor.properties.channelMixerLayerValue")
    }

    private static func colorLookupTitle(_ settings: ImageEditorAdjustmentSettings) -> String {
        if settings.colorLookupPreset == .customCube, settings.colorLookupCube.isValid {
            return settings.colorLookupCube.name
        }
        return settings.colorLookupPreset.title
    }
}
