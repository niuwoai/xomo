//
//  ImageEditorBrushStroke.swift
//  veilpic
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import Foundation

struct ImageEditorBrushStrokeSample: Equatable {
    var point: CGPoint
    var pressure: CGFloat?
    var tilt: ImageEditorStylusTilt?

    init(
        point: CGPoint,
        pressure: CGFloat? = nil,
        tilt: ImageEditorStylusTilt? = nil
    ) {
        self.point = point
        self.pressure = pressure
        self.tilt = tilt
    }
}

struct ImageEditorBrushRenderedStamp: Equatable {
    var sample: ImageEditorBrushStrokeSample
    var dynamicIndex: Int
}

enum ImageEditorBrushEdgeStyle: Equatable {
    case antialiased
    case aliased
}

enum ImageEditorPencilAutoErasePolicy {
    private static let componentTolerance = CGFloat(1) / CGFloat(UInt8.max)

    static func usesBackgroundColor(
        isEnabled: Bool,
        sampledColor: NSColor?,
        foregroundColor: NSColor
    ) -> Bool {
        guard isEnabled,
              let sampled = sampledColor?.usingColorSpace(.deviceRGB),
              let foreground = foregroundColor.usingColorSpace(.deviceRGB)
        else { return false }
        return abs(sampled.redComponent - foreground.redComponent) <= componentTolerance
            && abs(sampled.greenComponent - foreground.greenComponent) <= componentTolerance
            && abs(sampled.blueComponent - foreground.blueComponent) <= componentTolerance
            && abs(sampled.alphaComponent - foreground.alphaComponent) <= componentTolerance
    }

    static func usesBackgroundTone(
        isEnabled: Bool,
        sampledValue: UInt8?,
        foregroundValue: UInt8
    ) -> Bool {
        isEnabled && sampledValue == foregroundValue
    }

}

struct ImageEditorBrushStrokeSettings: Equatable {
    var diameter: CGFloat
    var hardness: CGFloat
    var opacity: CGFloat
    var flow: CGFloat
    var spacing: CGFloat
    var pressureControlsSize: Bool
    var pressureControlsOpacity: Bool
    var pressureControlsFlow: Bool
    var pressureSensitivity: CGFloat
    var sizeJitter: CGFloat
    var angleJitter: CGFloat
    var roundnessJitter: CGFloat
    var minimumRoundness: CGFloat
    var scatter: CGFloat
    var scatterBothAxes: Bool
    var scatterCount: Int
    var scatterCountJitter: CGFloat
    var minimumDiameter: CGFloat
    var minimumOpacity: CGFloat
    var minimumFlow: CGFloat
    var tiltControlsShape: Bool
    var tipRoundness: CGFloat
    var tipAngleDegrees: CGFloat
    var smoothing: CGFloat
    var edgeStyle: ImageEditorBrushEdgeStyle

    init(
        diameter: CGFloat,
        hardness: CGFloat,
        opacity: CGFloat,
        flow: CGFloat,
        spacing: CGFloat,
        pressureControlsSize: Bool = false,
        pressureControlsOpacity: Bool = false,
        pressureControlsFlow: Bool = false,
        pressureSensitivity: CGFloat = 0.5,
        sizeJitter: CGFloat = 0,
        angleJitter: CGFloat = 0,
        roundnessJitter: CGFloat = 0,
        minimumRoundness: CGFloat = 0.01,
        scatter: CGFloat = 0,
        scatterBothAxes: Bool = false,
        scatterCount: Int = 1,
        scatterCountJitter: CGFloat = 0,
        minimumDiameter: CGFloat = 0,
        minimumOpacity: CGFloat = 0,
        minimumFlow: CGFloat = 0,
        tiltControlsShape: Bool = false,
        tipRoundness: CGFloat = 1,
        tipAngleDegrees: CGFloat = 0,
        smoothing: CGFloat = 0,
        edgeStyle: ImageEditorBrushEdgeStyle = .antialiased
    ) {
        self.diameter = diameter
        self.hardness = hardness
        self.opacity = opacity
        self.flow = flow
        self.spacing = spacing
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
        self.edgeStyle = edgeStyle
    }

    var normalized: ImageEditorBrushStrokeSettings {
        ImageEditorBrushStrokeSettings(
            diameter: max(1, diameter),
            hardness: max(0, min(1, hardness)),
            opacity: max(0, min(1, opacity)),
            flow: max(0.01, min(1, flow)),
            spacing: max(0.01, min(2, spacing)),
            pressureControlsSize: pressureControlsSize,
            pressureControlsOpacity: pressureControlsOpacity,
            pressureControlsFlow: pressureControlsFlow,
            pressureSensitivity: max(0, min(1, pressureSensitivity)),
            sizeJitter: max(0, min(1, sizeJitter)),
            angleJitter: max(0, min(1, angleJitter)),
            roundnessJitter: max(0, min(1, roundnessJitter)),
            minimumRoundness: max(0.01, min(1, minimumRoundness)),
            scatter: max(0, min(10, scatter)),
            scatterBothAxes: scatterBothAxes,
            scatterCount: max(1, min(16, scatterCount)),
            scatterCountJitter: max(0, min(1, scatterCountJitter)),
            minimumDiameter: max(0, min(1, minimumDiameter)),
            minimumOpacity: max(0, min(1, minimumOpacity)),
            minimumFlow: max(0, min(1, minimumFlow)),
            tiltControlsShape: tiltControlsShape,
            tipRoundness: max(0.1, min(1, tipRoundness)),
            tipAngleDegrees: max(-180, min(180, tipAngleDegrees)),
            smoothing: max(0, min(1, smoothing)),
            edgeStyle: edgeStyle
        )
    }
}

enum ImageEditorBrushStrokeKernel {
    static let bytesPerPixel = 4
    private static let maximumSmoothingRadius = 8
    private static let maximumScatterCount = 16

    static func stampCenters(
        points: [CGPoint],
        diameter: CGFloat,
        spacing: CGFloat
    ) -> [CGPoint] {
        stampSamples(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            diameter: diameter,
            spacing: spacing
        ).map(\.point)
    }

    static func stampSamples(
        samples: [ImageEditorBrushStrokeSample],
        diameter: CGFloat,
        spacing: CGFloat,
        smoothing: CGFloat = 0
    ) -> [ImageEditorBrushStrokeSample] {
        let normalizedSamples = normalizedStylusSamples(
            smoothedSamples(samples, amount: smoothing)
        )
        guard let first = normalizedSamples.first else { return [] }
        let step = max(0.5, max(1, diameter) * max(0.01, min(2, spacing)))
        var stamps = [first]
        var distanceUntilNextStamp = step

        for (start, end) in zip(normalizedSamples, normalizedSamples.dropFirst()) {
            let deltaX = end.point.x - start.point.x
            let deltaY = end.point.y - start.point.y
            let segmentLength = hypot(deltaX, deltaY)
            guard segmentLength > 0.0001 else { continue }

            while distanceUntilNextStamp <= segmentLength {
                let progress = distanceUntilNextStamp / segmentLength
                let startPressure = start.pressure ?? 1
                let endPressure = end.pressure ?? startPressure
                let interpolatedTilt = interpolatedTilt(
                    from: start.tilt,
                    to: end.tilt,
                    progress: progress
                )
                stamps.append(ImageEditorBrushStrokeSample(
                    point: CGPoint(
                        x: start.point.x + deltaX * progress,
                        y: start.point.y + deltaY * progress
                    ),
                    pressure: startPressure + (endPressure - startPressure) * progress,
                    tilt: interpolatedTilt
                ))
                distanceUntilNextStamp += step
            }
            distanceUntilNextStamp -= segmentLength
        }

        if let lastSample = normalizedSamples.last,
           let lastStamp = stamps.last,
           hypot(
            lastSample.point.x - lastStamp.point.x,
            lastSample.point.y - lastStamp.point.y
           ) > step * 0.5 {
            stamps.append(lastSample)
        }
        return stamps
    }

    /// Applies an endpoint-preserving triangular moving average to pointer
    /// geometry before spacing resampling. Pressure and tilt stay attached to
    /// their original samples so smoothing never invents tablet dynamics.
    static func smoothedSamples(
        _ samples: [ImageEditorBrushStrokeSample],
        amount: CGFloat
    ) -> [ImageEditorBrushStrokeSample] {
        let normalizedAmount = max(0, min(1, amount))
        guard samples.count > 2, normalizedAmount > 0 else { return samples }
        let radius = max(
            1,
            Int(ceil(normalizedAmount * CGFloat(maximumSmoothingRadius)))
        )
        let lastIndex = samples.index(before: samples.endIndex)

        return samples.indices.map { index in
            guard index != samples.startIndex, index != lastIndex else {
                return samples[index]
            }
            let lowerBound = max(samples.startIndex, index - radius)
            let upperBound = min(lastIndex, index + radius)
            var weightedX: CGFloat = 0
            var weightedY: CGFloat = 0
            var totalWeight: CGFloat = 0

            for neighborIndex in lowerBound...upperBound {
                let distance = abs(neighborIndex - index)
                let weight = CGFloat(radius + 1 - distance)
                weightedX += samples[neighborIndex].point.x * weight
                weightedY += samples[neighborIndex].point.y * weight
                totalWeight += weight
            }

            let average = CGPoint(
                x: weightedX / totalWeight,
                y: weightedY / totalWeight
            )
            var output = samples[index]
            output.point = CGPoint(
                x: output.point.x + (average.x - output.point.x) * normalizedAmount,
                y: output.point.y + (average.y - output.point.y) * normalizedAmount
            )
            return output
        }
    }

    static func coverage(
        width: Int,
        height: Int,
        centers: [CGPoint],
        settings: ImageEditorBrushStrokeSettings
    ) -> [UInt8] {
        coverage(
            width: width,
            height: height,
            stamps: centers.map { ImageEditorBrushStrokeSample(point: $0, pressure: 1) },
            settings: settings
        )
    }

    static func coverage(
        width: Int,
        height: Int,
        stamps: [ImageEditorBrushStrokeSample],
        settings: ImageEditorBrushStrokeSettings
    ) -> [UInt8] {
        guard width > 0, height > 0, !stamps.isEmpty else { return [] }
        let settings = settings.normalized
        var accumulated = [CGFloat](repeating: 0, count: width * height)

        for renderedStamp in renderedStamps(from: stamps, settings: settings) {
            let stamp = renderedStamp.sample
            let stampIndex = renderedStamp.dynamicIndex
            let mappedPressure = mappedPressure(
                stamp.pressure ?? 1,
                sensitivity: settings.pressureSensitivity
            )
            let diameterScale = resolvedDiameterScale(
                mappedPressure: mappedPressure,
                pressureControlsSize: settings.pressureControlsSize,
                stampIndex: stampIndex,
                sizeJitter: settings.sizeJitter,
                minimumDiameter: settings.minimumDiameter
            )
            let flowScale = settings.pressureControlsFlow
                ? pressureFlowScale(
                    mappedPressure: mappedPressure,
                    minimumFlow: settings.minimumFlow
                )
                : 1
            let opacityLimit = settings.opacity * (
                settings.pressureControlsOpacity
                    ? pressureOpacityScale(
                        mappedPressure: mappedPressure,
                        minimumOpacity: settings.minimumOpacity
                    )
                    : 1
            )
            let radius = max(1, settings.diameter * diameterScale) / 2
            let innerRadius = radius * settings.hardness
            let tipAspectRatio = effectiveTipAspectRatio(
                roundness: roundnessJitterAspectRatio(
                    stampIndex: stampIndex,
                    baseRoundness: settings.tipRoundness,
                    amount: settings.roundnessJitter,
                    minimumRoundness: settings.minimumRoundness
                ),
                tilt: stamp.tilt,
                tiltControlsShape: settings.tiltControlsShape
            )
            let tipDirection = resolvedTipDirection(
                manualAngleDegrees: settings.tipAngleDegrees,
                jitterOffsetDegrees: angleJitterOffsetDegrees(
                    stampIndex: stampIndex,
                    amount: settings.angleJitter
                ),
                tilt: stamp.tilt,
                tiltControlsShape: settings.tiltControlsShape
            )
            let minX = max(0, Int(floor(stamp.point.x - radius - 1)))
            let maxX = min(width - 1, Int(ceil(stamp.point.x + radius + 1)))
            let minY = max(0, Int(floor(stamp.point.y - radius - 1)))
            let maxY = min(height - 1, Int(ceil(stamp.point.y + radius + 1)))
            guard minX <= maxX, minY <= maxY else { continue }

            for y in minY...maxY {
                for x in minX...maxX {
                    let deltaX = CGFloat(x) + 0.5 - stamp.point.x
                    let deltaY = CGFloat(y) + 0.5 - stamp.point.y
                    let distance = tipDistance(
                        deltaX: deltaX,
                        deltaY: deltaY,
                        direction: tipDirection,
                        aspectRatio: tipAspectRatio
                    )
                    let stampCoverage = radialCoverage(
                        distance: distance,
                        innerRadius: innerRadius,
                        outerRadius: radius,
                        edgeStyle: settings.edgeStyle
                    )
                    guard stampCoverage > 0 else { continue }
                    let index = y * width + x
                    let deposited = stampCoverage * settings.flow * flowScale
                    accumulated[index] = min(
                        opacityLimit,
                        accumulated[index] + (1 - accumulated[index]) * deposited
                    )
                }
            }
        }

        return accumulated.map { UInt8(($0 * 255).rounded()) }
    }

    static func renderedStamps(
        from stamps: [ImageEditorBrushStrokeSample],
        settings: ImageEditorBrushStrokeSettings
    ) -> [ImageEditorBrushRenderedStamp] {
        let settings = settings.normalized
        guard settings.scatter > 0 || settings.scatterCount > 1 else {
            return stamps.enumerated().map {
                ImageEditorBrushRenderedStamp(sample: $0.element, dynamicIndex: $0.offset)
            }
        }

        return stamps.indices.flatMap { stampIndex -> [ImageEditorBrushRenderedStamp] in
            let stamp = stamps[stampIndex]
            let count = resolvedScatterCount(
                stampIndex: stampIndex,
                count: settings.scatterCount,
                jitter: settings.scatterCountJitter
            )
            let tangent = strokeTangent(at: stampIndex, stamps: stamps)
            let normal = CGVector(dx: -tangent.dy, dy: tangent.dx)

            return (0..<count).map { copyIndex in
                let dynamicIndex = stampIndex * maximumScatterCount + copyIndex
                let normalOffset = scatterOffset(
                    dynamicIndex: dynamicIndex,
                    amount: settings.scatter,
                    diameter: settings.diameter,
                    salt: 0x8EBC6AF09C88C6E3
                )
                let tangentOffset = settings.scatterBothAxes
                    ? scatterOffset(
                        dynamicIndex: dynamicIndex,
                        amount: settings.scatter,
                        diameter: settings.diameter,
                        salt: 0x589965CC75374CC3
                    )
                    : 0
                var scattered = stamp
                scattered.point = CGPoint(
                    x: stamp.point.x
                        + normal.dx * normalOffset
                        + tangent.dx * tangentOffset,
                    y: stamp.point.y
                        + normal.dy * normalOffset
                        + tangent.dy * tangentOffset
                )
                return ImageEditorBrushRenderedStamp(
                    sample: scattered,
                    dynamicIndex: dynamicIndex
                )
            }
        }
    }

    static func resolvedScatterCount(
        stampIndex: Int,
        count: Int,
        jitter: CGFloat
    ) -> Int {
        let maximum = max(1, min(maximumScatterCount, count))
        let normalizedJitter = max(0, min(1, jitter))
        guard maximum > 1, normalizedJitter > 0 else { return maximum }
        let unit = deterministicUnit(
            stampIndex: stampIndex,
            salt: 0x1D8E4E27C47D124F
        )
        let reduction = Int(floor(unit * normalizedJitter * CGFloat(maximum)))
        return max(1, maximum - reduction)
    }

    private static func scatterOffset(
        dynamicIndex: Int,
        amount: CGFloat,
        diameter: CGFloat,
        salt: UInt64
    ) -> CGFloat {
        let unit = deterministicUnit(stampIndex: dynamicIndex, salt: salt)
        return (unit * 2 - 1) * max(0, amount) * max(1, diameter)
    }

    private static func strokeTangent(
        at index: Int,
        stamps: [ImageEditorBrushStrokeSample]
    ) -> CGVector {
        let point = stamps[index].point
        let previous = distinctNeighborPoint(
            from: index,
            step: -1,
            stamps: stamps
        ) ?? point
        let next = distinctNeighborPoint(
            from: index,
            step: 1,
            stamps: stamps
        ) ?? point
        let deltaX = next.x - previous.x
        let deltaY = next.y - previous.y
        let length = hypot(deltaX, deltaY)
        guard length > 0.0001 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: deltaX / length, dy: deltaY / length)
    }

    private static func distinctNeighborPoint(
        from index: Int,
        step: Int,
        stamps: [ImageEditorBrushStrokeSample]
    ) -> CGPoint? {
        let origin = stamps[index].point
        var candidateIndex = index + step
        while stamps.indices.contains(candidateIndex) {
            let candidate = stamps[candidateIndex].point
            if hypot(candidate.x - origin.x, candidate.y - origin.y) > 0.0001 {
                return candidate
            }
            candidateIndex += step
        }
        return nil
    }

    /// Returns a stable per-tip scale so replay, Undo/Redo, masks, and
    /// airbrush pulses render identically without shared mutable RNG state.
    static func sizeJitterScale(stampIndex: Int, amount: CGFloat) -> CGFloat {
        let normalizedAmount = max(0, min(1, amount))
        guard normalizedAmount > 0 else { return 1 }
        let unit = deterministicUnit(stampIndex: stampIndex, salt: 0)
        return 1 - normalizedAmount * unit
    }

    /// Returns a stable signed orientation offset. A value of 100% spans the
    /// full 360-degree orientation range without changing the base tip cursor.
    static func angleJitterOffsetDegrees(stampIndex: Int, amount: CGFloat) -> CGFloat {
        let normalizedAmount = max(0, min(1, amount))
        guard normalizedAmount > 0 else { return 0 }
        let unit = deterministicUnit(
            stampIndex: stampIndex,
            salt: 0xA0761D6478BD642F
        )
        return (unit * 2 - 1) * 180 * normalizedAmount
    }

    /// Varies the short-to-long axis ratio without mutable RNG state. Jitter
    /// scales the available range from the base tip down to the configured floor.
    static func roundnessJitterAspectRatio(
        stampIndex: Int,
        baseRoundness: CGFloat,
        amount: CGFloat,
        minimumRoundness: CGFloat
    ) -> CGFloat {
        let base = max(0.1, min(1, baseRoundness))
        let normalizedAmount = max(0, min(1, amount))
        guard normalizedAmount > 0 else { return base }
        let minimum = min(base, max(0.01, min(1, minimumRoundness)))
        let unit = deterministicUnit(
            stampIndex: stampIndex,
            salt: 0xE7037ED1A0B428DB
        )
        return base - (base - minimum) * normalizedAmount * unit
    }

    private static func deterministicUnit(stampIndex: Int, salt: UInt64) -> CGFloat {
        var value = UInt64(truncatingIfNeeded: stampIndex) ^ salt
        value &+= 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return CGFloat(value & ((UInt64(1) << 53) - 1)) / CGFloat(UInt64(1) << 53)
    }

    static func resolvedDiameterScale(
        mappedPressure: CGFloat,
        pressureControlsSize: Bool,
        stampIndex: Int,
        sizeJitter: CGFloat,
        minimumDiameter: CGFloat
    ) -> CGFloat {
        let minimum = max(0, min(1, minimumDiameter))
        let pressureScale = pressureControlsSize
            ? pressureDiameterScale(
                mappedPressure: mappedPressure,
                minimumDiameter: minimum
            )
            : 1
        let jitter = max(0, min(1, sizeJitter))
        guard pressureControlsSize || jitter > 0 else { return 1 }
        return max(
            minimum,
            pressureScale * sizeJitterScale(stampIndex: stampIndex, amount: jitter)
        )
    }

    static func mappedPressure(_ pressure: CGFloat, sensitivity: CGFloat) -> CGFloat {
        let normalizedPressure = max(0, min(1, pressure))
        let normalizedSensitivity = max(0, min(1, sensitivity))
        let exponent = pow(4, 0.5 - normalizedSensitivity)
        let curved = pow(normalizedPressure, exponent)
        return 0.05 + curved * 0.95
    }

    static func pressureDiameterScale(
        mappedPressure: CGFloat,
        minimumDiameter: CGFloat
    ) -> CGFloat {
        max(
            max(0, min(1, mappedPressure)),
            max(0, min(1, minimumDiameter))
        )
    }

    static func pressureFlowScale(
        mappedPressure: CGFloat,
        minimumFlow: CGFloat
    ) -> CGFloat {
        max(
            max(0, min(1, mappedPressure)),
            max(0, min(1, minimumFlow))
        )
    }

    static func pressureOpacityScale(
        mappedPressure: CGFloat,
        minimumOpacity: CGFloat = 0
    ) -> CGFloat {
        max(
            max(0, min(1, mappedPressure)),
            max(0, min(1, minimumOpacity))
        )
    }

    static func tiltTipAspectRatio(
        tilt: ImageEditorStylusTilt?,
        isEnabled: Bool
    ) -> CGFloat {
        guard isEnabled, let tilt else { return 1 }
        return max(0.25, 1 - tilt.magnitude * 0.75)
    }

    static func effectiveTipAspectRatio(
        roundness: CGFloat,
        tilt: ImageEditorStylusTilt?,
        tiltControlsShape: Bool
    ) -> CGFloat {
        min(
            max(0.01, min(1, roundness)),
            tiltTipAspectRatio(tilt: tilt, isEnabled: tiltControlsShape)
        )
    }

    static func composite(
        targetPixels: [UInt8],
        coverage: [UInt8],
        color: NSColor,
        erase: Bool,
        blendMode: ImageEditorBlendMode = .normal
    ) -> [UInt8] {
        guard coverage.count * bytesPerPixel == targetPixels.count else { return targetPixels }
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        let sourceRed = rgb.redComponent
        let sourceGreen = rgb.greenComponent
        let sourceBlue = rgb.blueComponent
        let sourceColorAlpha = rgb.alphaComponent
        let sourceColors = [sourceRed, sourceGreen, sourceBlue]
        var output = targetPixels

        for index in coverage.indices where coverage[index] > 0 {
            let amount = CGFloat(coverage[index]) / 255
            let offset = index * bytesPerPixel
            if erase {
                let remaining = 1 - amount
                for channel in 0..<bytesPerPixel {
                    output[offset + channel] = byte(CGFloat(targetPixels[offset + channel]) / 255 * remaining)
                }
                continue
            }

            let sourceAlpha = amount * sourceColorAlpha
            let remaining = 1 - sourceAlpha
            let targetAlpha = CGFloat(targetPixels[offset + 3]) / 255
            let targetColors = (0..<3).map { channel -> Double in
                guard targetAlpha > 0 else { return 0 }
                return Double(CGFloat(targetPixels[offset + channel]) / 255 / targetAlpha)
            }
            let blended = blendMode.blend(
                baseRed: targetColors[0],
                baseGreen: targetColors[1],
                baseBlue: targetColors[2],
                overlayRed: Double(sourceRed),
                overlayGreen: Double(sourceGreen),
                overlayBlue: Double(sourceBlue)
            )
            let blendedColors = [blended.red, blended.green, blended.blue]
            for channel in 0..<3 {
                let targetPremultiplied = CGFloat(targetPixels[offset + channel]) / 255
                let sourceContribution = sourceAlpha * (
                    (1 - targetAlpha) * sourceColors[channel]
                        + targetAlpha * CGFloat(blendedColors[channel])
                )
                output[offset + channel] = byte(sourceContribution + targetPremultiplied * remaining)
            }
            output[offset + 3] = byte(sourceAlpha + targetAlpha * remaining)
        }
        return output
    }

    private static func radialCoverage(
        distance: CGFloat,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        edgeStyle: ImageEditorBrushEdgeStyle
    ) -> CGFloat {
        if edgeStyle == .aliased {
            return distance <= outerRadius ? 1 : 0
        }
        let antialiasedEdge = max(0, min(1, outerRadius + 0.5 - distance))
        guard antialiasedEdge > 0 else { return 0 }
        guard distance > innerRadius, innerRadius < outerRadius else { return antialiasedEdge }
        let linear = max(0, min(1, (outerRadius - distance) / (outerRadius - innerRadius)))
        let softened = linear * linear * (3 - 2 * linear)
        return min(antialiasedEdge, softened)
    }

    private static func tipDistance(
        deltaX: CGFloat,
        deltaY: CGFloat,
        direction: CGVector,
        aspectRatio: CGFloat
    ) -> CGFloat {
        guard aspectRatio < 0.9999 else { return hypot(deltaX, deltaY) }
        let alongTilt = deltaX * direction.dx + deltaY * direction.dy
        let acrossTilt = -deltaX * direction.dy + deltaY * direction.dx
        return hypot(alongTilt, acrossTilt / aspectRatio)
    }

    static func resolvedTipAngleDegrees(
        manualAngleDegrees: CGFloat,
        tilt: ImageEditorStylusTilt?,
        tiltControlsShape: Bool
    ) -> CGFloat {
        if tiltControlsShape,
           let tilt,
           tilt.magnitude > 0.0001 {
            return CGFloat(tilt.azimuthDegrees ?? 0)
        }
        return max(-180, min(180, manualAngleDegrees))
    }

    private static func resolvedTipDirection(
        manualAngleDegrees: CGFloat,
        jitterOffsetDegrees: CGFloat,
        tilt: ImageEditorStylusTilt?,
        tiltControlsShape: Bool
    ) -> CGVector {
        let angle = resolvedTipAngleDegrees(
            manualAngleDegrees: manualAngleDegrees,
            tilt: tilt,
            tiltControlsShape: tiltControlsShape
        )
        let radians = (angle + jitterOffsetDegrees) * .pi / 180
        return CGVector(
            dx: cos(radians),
            dy: sin(radians)
        )
    }

    private static func byte(_ value: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, (value * 255).rounded())))
    }

    private static func normalizedStylusSamples(
        _ samples: [ImageEditorBrushStrokeSample]
    ) -> [ImageEditorBrushStrokeSample] {
        let firstKnownPressure = samples.compactMap(\.pressure).first.map { max(0, min(1, $0)) } ?? 1
        let firstKnownTilt = samples.compactMap(\.tilt).first
        var previousPressure = firstKnownPressure
        var previousTilt = firstKnownTilt
        return samples.map { sample in
            if let pressure = sample.pressure {
                previousPressure = max(0, min(1, pressure))
            }
            if let tilt = sample.tilt {
                previousTilt = tilt
            }
            return ImageEditorBrushStrokeSample(
                point: sample.point,
                pressure: previousPressure,
                tilt: previousTilt
            )
        }
    }

    private static func interpolatedTilt(
        from start: ImageEditorStylusTilt?,
        to end: ImageEditorStylusTilt?,
        progress: CGFloat
    ) -> ImageEditorStylusTilt? {
        guard let fallback = start ?? end else { return nil }
        let start = start ?? fallback
        let end = end ?? fallback
        return ImageEditorStylusInput.normalizedTilt(
            rawX: start.x + (end.x - start.x) * progress,
            rawY: start.y + (end.y - start.y) * progress,
            supportsTilt: true
        )
    }
}

extension NSImage {
    func withBrushStroke(
        points: [CGPoint],
        color: NSColor,
        settings: ImageEditorBrushStrokeSettings,
        erase: Bool,
        blendMode: ImageEditorBlendMode = .normal,
        airbrushPulseSamples: [ImageEditorBrushStrokeSample] = []
    ) -> NSImage? {
        withBrushStroke(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            color: color,
            settings: settings,
            erase: erase,
            blendMode: blendMode,
            airbrushPulseSamples: airbrushPulseSamples
        )
    }

    func withBrushStroke(
        samples: [ImageEditorBrushStrokeSample],
        color: NSColor,
        settings: ImageEditorBrushStrokeSettings,
        erase: Bool,
        blendMode: ImageEditorBlendMode = .normal,
        airbrushPulseSamples: [ImageEditorBrushStrokeSample] = []
    ) -> NSImage? {
        guard !samples.isEmpty || !airbrushPulseSamples.isEmpty else { return nil }
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        let bytesPerRow = pixelWidth * ImageEditorBrushStrokeKernel.bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * pixelHeight)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: &pixels,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        let normalized = settings.normalized
        let pathStamps = ImageEditorBrushStrokeKernel.stampSamples(
            samples: samples,
            diameter: normalized.diameter,
            spacing: normalized.spacing,
            smoothing: normalized.smoothing
        )
        let strokeCoverage = ImageEditorBrushStrokeKernel.coverage(
            width: pixelWidth,
            height: pixelHeight,
            // Time-based airbrush pulses are already discrete stamps. Keeping
            // them outside spatial resampling preserves repeated stationary
            // points instead of collapsing a held pointer to one mark.
            stamps: pathStamps + airbrushPulseSamples,
            settings: normalized
        )
        var outputPixels = ImageEditorBrushStrokeKernel.composite(
            targetPixels: pixels,
            coverage: strokeCoverage,
            color: color,
            erase: erase,
            blendMode: blendMode
        )
        guard let outputContext = CGContext(
            data: &outputPixels,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let outputCGImage = outputContext.makeImage()
        else { return nil }

        let output = NSImage(size: size)
        output.addRepresentation(NSBitmapImageRep(cgImage: outputCGImage))
        return output
    }
}
