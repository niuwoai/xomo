//
//  ImageEditorGradientOverlayStops.swift
//  veilpic
//
//  Created by Codex on 2026/8/16.
//

import AppKit

enum ImageEditorGradientOverlayCenterPolicy {
    static let minimumComponent: CGFloat = -4
    static let maximumComponent: CGFloat = 5
    static let defaultCenter = CGPoint(x: 0.5, y: 0.5)

    static func normalized(_ center: CGPoint) -> CGPoint {
        CGPoint(
            x: normalizedComponent(center.x),
            y: normalizedComponent(center.y)
        )
    }

    static func normalizedComponent(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0.5 }
        return max(minimumComponent, min(maximumComponent, value))
    }
}

enum ImageEditorGradientOverlayStopDraftEditing {
    static let minimumStopSpacing = 0.01

    struct DuplicationResult: Equatable {
        var stops: [ImageEditorGradientColorStop]
        var duplicateIndex: Int
    }

    struct ReorderingResult: Equatable {
        var stops: [ImageEditorGradientColorStop]
        var movedIndex: Int
    }

    static func duplicatingStop(
        _ stops: [ImageEditorGradientColorStop],
        at index: Int,
        toward position: Double
    ) -> DuplicationResult? {
        let normalizedStops = normalized(stops)
        guard position.isFinite,
              normalizedStops.count < ImageEditorGradientFillContent.maximumColorStopCount,
              index > 0,
              index < normalizedStops.count - 1
        else { return nil }

        let source = normalizedStops[index]
        let prefersLowerSegment = position < source.position
        let segmentOrder = prefersLowerSegment ? [index - 1, index] : [index, index - 1]
        for lowerIndex in segmentOrder {
            let lowerBound = normalizedStops[lowerIndex].position + minimumStopSpacing
            let upperBound = normalizedStops[lowerIndex + 1].position - minimumStopSpacing
            guard lowerBound <= upperBound else { continue }
            let duplicateIndex = lowerIndex + 1
            var duplicatedStops = normalizedStops
            var duplicate = source
            duplicate.position = max(lowerBound, min(upperBound, position))
            duplicatedStops.insert(duplicate, at: duplicateIndex)
            return DuplicationResult(
                stops: normalized(duplicatedStops),
                duplicateIndex: duplicateIndex
            )
        }
        return nil
    }

    static func reorderingStop(
        _ stops: [ImageEditorGradientColorStop],
        at index: Int,
        to position: Double
    ) -> ReorderingResult {
        let normalizedStops = normalized(stops)
        guard position.isFinite,
              index > 0,
              index < normalizedStops.count - 1
        else {
            return ReorderingResult(stops: normalizedStops, movedIndex: index)
        }

        let source = normalizedStops[index]
        var remainingStops = normalizedStops
        remainingStops.remove(at: index)
        let movesTowardLowerPositions = position < source.position
        var bestLowerIndex: Int?
        var bestPosition = source.position
        var bestDistance = Double.greatestFiniteMagnitude
        for lowerIndex in remainingStops.indices.dropLast() {
            let lowerBound = remainingStops[lowerIndex].position + minimumStopSpacing
            let upperBound = remainingStops[lowerIndex + 1].position - minimumStopSpacing
            guard lowerBound <= upperBound else { continue }
            let candidate = max(lowerBound, min(upperBound, position))
            let distance = abs(candidate - position)
            let isCloser = distance < bestDistance - 0.000_001
            let isDirectionalTie = abs(distance - bestDistance) <= 0.000_001
                && bestLowerIndex.map {
                    movesTowardLowerPositions ? lowerIndex > $0 : lowerIndex < $0
                } == true
            if isCloser || isDirectionalTie {
                bestLowerIndex = lowerIndex
                bestPosition = candidate
                bestDistance = distance
            }
        }
        guard let bestLowerIndex else {
            return ReorderingResult(stops: normalizedStops, movedIndex: index)
        }

        var movedStop = source
        movedStop.position = bestPosition
        let movedIndex = bestLowerIndex + 1
        remainingStops.insert(movedStop, at: movedIndex)
        return ReorderingResult(
            stops: normalized(remainingStops),
            movedIndex: movedIndex
        )
    }

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
