//
//  ImageEditorGradientOverlayStops.swift
//  veilpic
//
//  Created by Codex on 2026/8/16.
//

import AppKit

enum ImageEditorGradientOverlayStopDraftEditing {
    static let minimumStopSpacing = 0.01

    static func movingStop(
        _ stops: [ImageEditorGradientColorStop],
        at index: Int,
        to position: Double
    ) -> [ImageEditorGradientColorStop] {
        var normalizedStops = normalized(stops)
        guard position.isFinite,
              index > 0,
              index < normalizedStops.count - 1
        else { return normalizedStops }
        let lowerBound = normalizedStops[index - 1].position + minimumStopSpacing
        let upperBound = normalizedStops[index + 1].position - minimumStopSpacing
        guard lowerBound <= upperBound else { return normalizedStops }
        normalizedStops[index].position = max(lowerBound, min(upperBound, position))
        return normalized(normalizedStops)
    }

    static func movingMidpoint(
        _ stops: [ImageEditorGradientColorStop],
        after index: Int,
        to midpoint: Double
    ) -> [ImageEditorGradientColorStop] {
        var normalizedStops = normalized(stops)
        guard midpoint.isFinite,
              index >= 0,
              index < normalizedStops.count - 1
        else { return normalizedStops }
        normalizedStops[index].midpoint = max(0, min(1, midpoint))
        return normalized(normalizedStops)
    }

    private static func normalized(
        _ stops: [ImageEditorGradientColorStop]
    ) -> [ImageEditorGradientColorStop] {
        ImageEditorGradientFillContent.shapeLinear(
            colorStops: stops
        ).shapeColorStops
    }
}

extension ImageEditorLayerStyle {
    var resolvedGradientOverlayColorStops: [ImageEditorGradientColorStop] {
        if let gradientOverlayColorStops {
            return ImageEditorGradientFillContent.shapeLinear(
                colorStops: gradientOverlayColorStops
            ).shapeColorStops
        }
        return ImageEditorGradientFillContent.shapeLinear(
            startColor: gradientOverlayStartColor,
            endColor: gradientOverlayEndColor
        ).shapeColorStops
    }

    mutating func setGradientOverlayColorStops(
        _ stops: [ImageEditorGradientColorStop]
    ) {
        let normalizedStops = ImageEditorGradientFillContent.shapeLinear(
            colorStops: stops
        ).shapeColorStops
        gradientOverlayColorStops = normalizedStops
        if let first = normalizedStops.first {
            gradientOverlayStartColor = first.color
        }
        if let last = normalizedStops.last {
            gradientOverlayEndColor = last.color
        }
    }

    mutating func setGradientOverlayEndpointColor(
        _ color: NSColor,
        atStart: Bool
    ) {
        let resolved = color.usingColorSpace(.deviceRGB) ?? color
        let endpointColor = NSColor(
            deviceRed: resolved.redComponent,
            green: resolved.greenComponent,
            blue: resolved.blueComponent,
            alpha: 1
        )
        if atStart {
            gradientOverlayStartColor = endpointColor
        } else {
            gradientOverlayEndColor = endpointColor
        }
        guard gradientOverlayColorStops != nil else { return }

        var stops = resolvedGradientOverlayColorStops
        let index = atStart ? stops.startIndex : stops.index(before: stops.endIndex)
        stops[index].red = Double(resolved.redComponent)
        stops[index].green = Double(resolved.greenComponent)
        stops[index].blue = Double(resolved.blueComponent)
        setGradientOverlayColorStops(stops)
    }
}
