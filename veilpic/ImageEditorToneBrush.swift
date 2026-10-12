//
//  ImageEditorToneBrush.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation

private enum ImageEditorRetouchTuning {
    static let toneEffectScale: CGFloat = 0.82
    static let spongeEffectScale: CGFloat = 0.9
    static let spongeDesaturateVibranceBoost: CGFloat = 1.1
    static let sharpenSecondPassScale: CGFloat = 1
}

enum ImageEditorToneRange: String, CaseIterable, Identifiable {
    case shadows
    case midtones
    case highlights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shadows:
            L10n.text("imageEditor.toneRange.shadows")
        case .midtones:
            L10n.text("imageEditor.toneRange.midtones")
        case .highlights:
            L10n.text("imageEditor.toneRange.highlights")
        }
    }

    /// Smooth, overlapping tonal masks avoid visible bands while retaining the
    /// familiar Photoshop distinction between dark, middle, and light values.
    func weight(for luminance: CGFloat) -> CGFloat {
        let value = max(0, min(1, luminance))
        switch self {
        case .shadows:
            return (1 - value) * (1 - value)
        case .midtones:
            let centered = max(0, 1 - abs(value - 0.5) * 2)
            return centered * centered
        case .highlights:
            return value * value
        }
    }
}

enum ImageEditorSpongeMode: String, CaseIterable, Identifiable {
    case saturate
    case desaturate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saturate:
            L10n.text("imageEditor.spongeMode.saturate")
        case .desaturate:
            L10n.text("imageEditor.spongeMode.desaturate")
        }
    }
}

extension NSImage {
    func withToneBrush(
        points: [CGPoint],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        burn: Bool,
        range: ImageEditorToneRange = .midtones,
        protectTones: Bool = true,
        airbrushPulsePoints: [CGPoint] = []
    ) -> NSImage? {
        withToneBrush(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            width: width,
            opacity: opacity,
            hardness: hardness,
            burn: burn,
            range: range,
            protectTones: protectTones,
            pressureControlsSize: false,
            pressureSensitivity: 0.5,
            airbrushPulseSamples: airbrushPulsePoints.map {
                ImageEditorBrushStrokeSample(point: $0)
            }
        )
    }

    func withToneBrush(
        samples: [ImageEditorBrushStrokeSample],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        burn: Bool,
        range: ImageEditorToneRange = .midtones,
        protectTones: Bool = true,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat,
        airbrushPulseSamples: [ImageEditorBrushStrokeSample] = []
    ) -> NSImage? {
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        if airbrushPulseSamples.isEmpty {
            guard let mask = retouchStrokeMask(
                width: pixelWidth,
                height: pixelHeight,
                samples: samples,
                diameter: width,
                hardness: hardness,
                pressureControlsSize: pressureControlsSize,
                pressureSensitivity: pressureSensitivity
            ) else { return nil }
            return toneAdjusted(
                maskAlpha: mask.pixels,
                maskBounds: mask.bounds,
                airbrushMaskAlpha: nil,
                opacity: opacity,
                burn: burn,
                range: range,
                protectTones: protectTones
            )
        }

        let maskAlpha = retouchStrokeAlpha(
            width: pixelWidth,
            height: pixelHeight,
            samples: samples,
            diameter: width,
            hardness: hardness,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        )
        guard maskAlpha.count == pixelWidth * pixelHeight else { return nil }
        let airbrushMaskAlpha = airbrushPulseSamples.isEmpty
            ? nil
            : ImageEditorBrushStrokeKernel.coverage(
                width: pixelWidth,
                height: pixelHeight,
                stamps: airbrushPulseSamples,
                settings: ImageEditorBrushStrokeSettings(
                    diameter: width,
                    hardness: hardness,
                    opacity: 1,
                    flow: ImageEditorToneAirbrushStroke.pulseFlow,
                    spacing: 1,
                    pressureControlsSize: pressureControlsSize,
                    pressureControlsFlow: false,
                    pressureSensitivity: pressureSensitivity
                )
            )
        return toneAdjusted(
            maskAlpha: maskAlpha,
            maskBounds: (0, pixelWidth - 1, 0, pixelHeight - 1),
            airbrushMaskAlpha: airbrushMaskAlpha,
            opacity: opacity,
            burn: burn,
            range: range,
            protectTones: protectTones
        )
    }

    func withSpongeBrush(
        points: [CGPoint],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        mode: ImageEditorSpongeMode,
        vibrance: Bool = true
    ) -> NSImage? {
        withSpongeBrush(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            width: width,
            opacity: opacity,
            hardness: hardness,
            mode: mode,
            vibrance: vibrance,
            pressureControlsSize: false,
            pressureSensitivity: 0.5
        )
    }

    func withSpongeBrush(
        samples: [ImageEditorBrushStrokeSample],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        mode: ImageEditorSpongeMode,
        vibrance: Bool = true,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> NSImage? {
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        guard let mask = retouchStrokeMask(
            width: pixelWidth,
            height: pixelHeight,
            samples: samples,
            diameter: width,
            hardness: hardness,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        ) else { return nil }
        return saturationAdjusted(
            maskAlpha: mask.pixels,
            maskBounds: mask.bounds,
            opacity: opacity,
            mode: mode,
            vibrance: vibrance
        )
    }

    func retouchStrokeMask(
        width pixelWidth: Int,
        height pixelHeight: Int,
        samples: [ImageEditorBrushStrokeSample],
        diameter: CGFloat,
        hardness: CGFloat,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> ImageEditorHealingBrushKernel.StrokeMask? {
        guard pixelWidth > 0, pixelHeight > 0, !samples.isEmpty else { return nil }
        let hasPressureSamples = pressureControlsSize && samples.contains { $0.pressure != nil }
        let points = samples.map(\.point)
        guard let bounds = ImageEditorHealingBrushKernel.strokeBounds(
            width: pixelWidth,
            height: pixelHeight,
            points: points,
            diameter: maximumRetouchDiameter(
                samples: samples,
                diameter: diameter,
                pressureControlsSize: hasPressureSamples,
                pressureSensitivity: pressureSensitivity
            )
        ) else { return nil }

        guard hasPressureSamples else {
            return ImageEditorHealingBrushKernel.strokeMask(
                width: pixelWidth,
                height: pixelHeight,
                points: points,
                diameter: diameter,
                hardness: hardness,
                bounds: bounds
            )
        }
        return pressureAwareRetouchStrokeMask(
            width: pixelWidth,
            height: pixelHeight,
            samples: samples,
            diameter: diameter,
            hardness: hardness,
            pressureSensitivity: pressureSensitivity,
            bounds: bounds
        )
    }

    private func pressureAwareRetouchStrokeMask(
        width: Int,
        height: Int,
        samples: [ImageEditorBrushStrokeSample],
        diameter: CGFloat,
        hardness: CGFloat,
        pressureSensitivity: CGFloat,
        bounds: ImageEditorHealingBrushKernel.MaskBounds
    ) -> ImageEditorHealingBrushKernel.StrokeMask? {
        let settings = ImageEditorBrushStrokeSettings(
            diameter: diameter,
            hardness: hardness,
            opacity: 1,
            flow: 1,
            spacing: 0.1,
            pressureControlsSize: true,
            pressureControlsFlow: false,
            pressureSensitivity: pressureSensitivity
        )
        let stamps = ImageEditorBrushStrokeKernel.stampSamples(
            samples: samples,
            diameter: settings.diameter,
            spacing: settings.spacing,
            canvasSize: CGSize(width: width, height: height)
        )
        guard let region = ImageEditorBrushStrokeKernel.coverageRegion(
            width: width,
            height: height,
            stamps: stamps,
            settings: settings,
            bounds: bounds
        ) else { return nil }
        return ImageEditorHealingBrushKernel.StrokeMask(
            bounds: bounds,
            pixels: region.pixels
        )
    }

    private func maximumRetouchDiameter(
        samples: [ImageEditorBrushStrokeSample],
        diameter: CGFloat,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> CGFloat {
        guard pressureControlsSize else { return max(1, diameter) }
        let maximumScale = samples.map {
            ImageEditorBrushStrokeKernel.mappedPressure(
                $0.pressure ?? 1,
                sensitivity: pressureSensitivity
            )
        }.max() ?? 1
        return max(1, diameter * maximumScale)
    }

    func retouchStrokeAlpha(
        width pixelWidth: Int,
        height pixelHeight: Int,
        samples: [ImageEditorBrushStrokeSample],
        diameter: CGFloat,
        hardness: CGFloat,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> [UInt8] {
        guard pressureControlsSize, samples.contains(where: { $0.pressure != nil }) else {
            return ImageEditorHealingBrushKernel.strokeAlpha(
                width: pixelWidth,
                height: pixelHeight,
                points: samples.map(\.point),
                diameter: diameter,
                hardness: hardness
            )
        }
        let settings = ImageEditorBrushStrokeSettings(
            diameter: diameter,
            hardness: hardness,
            opacity: 1,
            flow: 1,
            spacing: 0.1,
            pressureControlsSize: true,
            pressureControlsFlow: false,
            pressureSensitivity: pressureSensitivity
        )
        return ImageEditorBrushStrokeKernel.coverage(
            width: pixelWidth,
            height: pixelHeight,
            stamps: ImageEditorBrushStrokeKernel.stampSamples(
                samples: samples,
                diameter: settings.diameter,
                spacing: settings.spacing,
                canvasSize: CGSize(width: pixelWidth, height: pixelHeight)
            ),
            settings: settings
        )
    }

    func withBlurBrush(
        points: [CGPoint],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        radius: CGFloat
    ) -> NSImage? {
        withBlurBrush(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            width: width,
            opacity: opacity,
            hardness: hardness,
            radius: radius,
            pressureControlsSize: false,
            pressureSensitivity: 0.5
        )
    }

    func withBlurBrush(
        samples: [ImageEditorBrushStrokeSample],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        radius: CGFloat,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> NSImage? {
        guard let blurredSource = blurred(radius: max(0.5, radius)) else { return nil }
        return mixingBrushSource(
            blurredSource,
            samples: samples,
            width: width,
            opacity: opacity,
            hardness: hardness,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        )
    }

    func withSharpenBrush(
        points: [CGPoint],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        intensity: CGFloat
    ) -> NSImage? {
        withSharpenBrush(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            width: width,
            opacity: opacity,
            hardness: hardness,
            intensity: intensity,
            pressureControlsSize: false,
            pressureSensitivity: 0.5
        )
    }

    func withSharpenBrush(
        samples: [ImageEditorBrushStrokeSample],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        intensity: CGFloat,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> NSImage? {
        let clampedIntensity = max(0.1, min(1, intensity))
        guard let firstPass = filtered(kind: .sharpen, intensity: Double(clampedIntensity)) else {
            return nil
        }
        let sharpenedSource = firstPass.filtered(
            kind: .sharpen,
            intensity: Double(clampedIntensity * ImageEditorRetouchTuning.sharpenSecondPassScale)
        ) ?? firstPass
        return mixingBrushSource(
            sharpenedSource,
            samples: samples,
            width: width,
            opacity: opacity,
            hardness: hardness,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        )
    }

    func withSmudgeBrush(
        points: [CGPoint],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        sourceImage: NSImage? = nil,
        fingerPaintingColor: NSColor? = nil
    ) -> NSImage? {
        withSmudgeBrush(
            samples: points.map { ImageEditorBrushStrokeSample(point: $0) },
            width: width,
            opacity: opacity,
            hardness: hardness,
            pressureControlsSize: false,
            pressureSensitivity: 0.5,
            sourceImage: sourceImage,
            fingerPaintingColor: fingerPaintingColor
        )
    }

    func withSmudgeBrush(
        samples: [ImageEditorBrushStrokeSample],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat,
        sourceImage: NSImage? = nil,
        fingerPaintingColor: NSColor? = nil
    ) -> NSImage? {
        guard samples.count > 1 else { return nil }
        let resolvedSamples = resolvedSmudgePressureSamples(samples)
        let points = resolvedSamples.map(\.point)
        let usesPressureSize = pressureControlsSize && samples.contains { $0.pressure != nil }
        let clampedOpacity = max(0, min(1, opacity)) * 0.86
        let usesIndependentSource = sourceImage != nil
        var workingSource = sourceImage ?? self
        var output = self
        if let fingerPaintingColor {
            guard let firstPoint = points.first,
                  let seededSource = workingSource.withBrushStroke(
                    points: [firstPoint],
                    color: fingerPaintingColor,
                    settings: ImageEditorBrushStrokeSettings(
                        diameter: smudgeDiameter(
                            baseWidth: width,
                            pressure: resolvedSamples.first?.pressure,
                            controlsSize: usesPressureSize,
                            sensitivity: pressureSensitivity
                        ),
                        hardness: hardness,
                        opacity: clampedOpacity,
                        flow: 1,
                        spacing: 1
                    ),
                    erase: false
                  )
            else { return nil }
            workingSource = seededSource
            if usesIndependentSource {
                guard let seededOutput = output.withBrushStroke(
                    points: [firstPoint],
                    color: fingerPaintingColor,
                    settings: ImageEditorBrushStrokeSettings(
                        diameter: smudgeDiameter(
                            baseWidth: width,
                            pressure: resolvedSamples.first?.pressure,
                            controlsSize: usesPressureSize,
                            sensitivity: pressureSensitivity
                        ),
                        hardness: hardness,
                        opacity: clampedOpacity,
                        flow: 1,
                        spacing: 1
                    ),
                    erase: false
                ) else { return nil }
                output = seededOutput
            } else {
                output = seededSource
            }
        }

        for segmentIndex in 1..<points.count {
            let previous = points[segmentIndex - 1]
            let current = points[segmentIndex]
            let delta = CGSize(width: current.x - previous.x, height: current.y - previous.y)
            guard abs(delta.width) > 0.1 || abs(delta.height) > 0.1 else { continue }
            let segmentPressure = (
                (resolvedSamples[segmentIndex - 1].pressure ?? 1)
                    + (resolvedSamples[segmentIndex].pressure ?? 1)
            ) / 2
            let segmentDiameter = smudgeDiameter(
                baseWidth: width,
                pressure: segmentPressure,
                controlsSize: usesPressureSize,
                sensitivity: pressureSensitivity
            )

            let sourceSnapshot = workingSource
            let segmentSamples = [
                ImageEditorBrushStrokeSample(point: previous),
                ImageEditorBrushStrokeSample(point: current)
            ]
            let pixelWidth = max(1, Int(size.width.rounded()))
            let pixelHeight = max(1, Int(size.height.rounded()))
            guard let segmentMask = retouchStrokeMask(
                width: pixelWidth,
                height: pixelHeight,
                samples: segmentSamples,
                diameter: segmentDiameter,
                hardness: hardness,
                pressureControlsSize: false,
                pressureSensitivity: pressureSensitivity
            ) else { return nil }
            guard let shiftedSource = NSImage.rendered(size: size, actions: { _ in
                sourceSnapshot.draw(
                    in: CGRect(x: delta.width, y: -delta.height, width: size.width, height: size.height),
                    from: CGRect(origin: .zero, size: sourceSnapshot.size),
                    operation: .copy,
                    fraction: 1
                )
            }),
            let nextOutput = output.mixingBrushSource(
                shiftedSource,
                strokeMask: segmentMask,
                opacity: clampedOpacity
            ) else {
                return nil
            }
            if usesIndependentSource {
                guard let nextWorkingSource = workingSource.mixingBrushSource(
                    shiftedSource,
                    strokeMask: segmentMask,
                    opacity: clampedOpacity
                ) else { return nil }
                workingSource = nextWorkingSource
            } else {
                workingSource = nextOutput
            }
            output = nextOutput
        }

        return output
    }

    private func resolvedSmudgePressureSamples(
        _ samples: [ImageEditorBrushStrokeSample]
    ) -> [ImageEditorBrushStrokeSample] {
        let firstKnownPressure = samples.compactMap(\.pressure).first ?? 1
        var previousPressure = max(0, min(1, firstKnownPressure))
        return samples.map { sample in
            if let pressure = sample.pressure {
                previousPressure = max(0, min(1, pressure))
            }
            return ImageEditorBrushStrokeSample(
                point: sample.point,
                pressure: previousPressure,
                tilt: sample.tilt
            )
        }
    }

    private func smudgeDiameter(
        baseWidth: CGFloat,
        pressure: CGFloat?,
        controlsSize: Bool,
        sensitivity: CGFloat
    ) -> CGFloat {
        guard controlsSize else { return max(1, baseWidth) }
        let scale = ImageEditorBrushStrokeKernel.mappedPressure(
            pressure ?? 1,
            sensitivity: sensitivity
        )
        return max(1, baseWidth * scale)
    }

    private func mixingBrushSource(
        _ brushSource: NSImage,
        samples: [ImageEditorBrushStrokeSample],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat,
        pressureControlsSize: Bool,
        pressureSensitivity: CGFloat
    ) -> NSImage? {
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        guard let mask = retouchStrokeMask(
            width: pixelWidth,
            height: pixelHeight,
            samples: samples,
            diameter: width,
            hardness: hardness,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        ) else { return nil }
        return mixingBrushSource(brushSource, strokeMask: mask, opacity: opacity)
    }

    private func mixingBrushSource(
        _ brushSource: NSImage,
        strokeMask mask: ImageEditorHealingBrushKernel.StrokeMask,
        opacity: CGFloat
    ) -> NSImage? {
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))
        let bounds = mask.bounds
        let maskWidth = mask.width
        let maskHeight = bounds.maxY - bounds.minY + 1
        let bytesPerPixel = 4
        let bytesPerRow = pixelWidth * bytesPerPixel
        guard Int(brushSource.size.width.rounded()) == pixelWidth,
              Int(brushSource.size.height.rounded()) == pixelHeight,
              bounds.minX >= 0, bounds.minY >= 0,
              bounds.maxX < pixelWidth, bounds.maxY < pixelHeight,
              maskWidth == bounds.maxX - bounds.minX + 1,
              maskHeight == bounds.maxY - bounds.minY + 1,
              mask.pixels.count == maskWidth * maskHeight,
              var destinationPixels = rgbaPixels(
                width: pixelWidth,
                height: pixelHeight,
                bytesPerRow: bytesPerRow
              ),
              let sourcePixels = brushSource.rgbaPixels(
                width: pixelWidth,
                height: pixelHeight,
                bytesPerRow: bytesPerRow
              ) else { return nil }

        let opacityScale = max(0, min(1, opacity))
        for localY in 0..<maskHeight {
            for localX in 0..<maskWidth {
                let sourceScale = CGFloat(mask.pixels[localY * maskWidth + localX])
                    / 255 * opacityScale
                guard sourceScale > 0 else { continue }

                let pixelOffset = ((bounds.minY + localY) * pixelWidth + bounds.minX + localX)
                    * bytesPerPixel
                let destinationAlpha = CGFloat(destinationPixels[pixelOffset + 3]) / 255
                let sourceAlpha = CGFloat(sourcePixels[pixelOffset + 3]) / 255 * sourceScale
                let destinationScale = 1 - sourceAlpha
                for channel in 0..<3 {
                    destinationPixels[pixelOffset + channel] = blendedChannel(
                        source: sourcePixels[pixelOffset + channel],
                        sourceScale: sourceScale,
                        destination: destinationPixels[pixelOffset + channel],
                        destinationScale: destinationScale
                    )
                }
                destinationPixels[pixelOffset + 3] = UInt8(clamping: Int(
                    ((sourceAlpha + destinationAlpha * destinationScale) * 255).rounded()
                ))
            }
        }
        return Self.fromRGBA(
            pixels: destinationPixels,
            width: pixelWidth,
            height: pixelHeight,
            bytesPerRow: bytesPerRow,
            size: size
        )
    }

    private func blendedChannel(
        source: UInt8,
        sourceScale: CGFloat,
        destination: UInt8,
        destinationScale: CGFloat
    ) -> UInt8 {
        UInt8(clamping: Int((CGFloat(source) * sourceScale
            + CGFloat(destination) * destinationScale).rounded()))
    }

    private func toneAdjusted(
        maskAlpha: [UInt8],
        maskBounds: ImageEditorHealingBrushKernel.MaskBounds,
        airbrushMaskAlpha: [UInt8]?,
        opacity: CGFloat,
        burn: Bool,
        range: ImageEditorToneRange,
        protectTones: Bool
    ) -> NSImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let maskWidth = maskBounds.maxX - maskBounds.minX + 1
        let maskHeight = maskBounds.maxY - maskBounds.minY + 1
        guard var sourcePixels = rgbaPixels(width: width, height: height, bytesPerRow: bytesPerRow),
              maskBounds.minX >= 0, maskBounds.minY >= 0,
              maskBounds.maxX < width, maskBounds.maxY < height,
              maskWidth > 0, maskHeight > 0,
              maskAlpha.count == maskWidth * maskHeight,
              airbrushMaskAlpha == nil || airbrushMaskAlpha?.count == maskAlpha.count
        else {
            return nil
        }

        let clampedOpacity = max(0, min(1, opacity))
        let effectScale = ImageEditorRetouchTuning.toneEffectScale
        for localY in 0..<maskHeight {
            for localX in 0..<maskWidth {
                let y = maskBounds.minY + localY
                let x = maskBounds.minX + localX
                let offset = y * bytesPerRow + x * bytesPerPixel
                let maskIndex = localY * maskWidth + localX
                let maskStrength = CGFloat(maskAlpha[maskIndex]) / 255
                let red = CGFloat(sourcePixels[offset]) / 255
                let green = CGFloat(sourcePixels[offset + 1]) / 255
                let blue = CGFloat(sourcePixels[offset + 2]) / 255
                let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
                let toneWeight = range.weight(for: luminance)
                let baseStrength = clampedOpacity * maskStrength * toneWeight * effectScale
                let airbrushMaskStrength = CGFloat(airbrushMaskAlpha?[maskIndex] ?? 0) / 255
                let airbrushStrength = clampedOpacity * airbrushMaskStrength * toneWeight * effectScale
                let strength = 1 - (1 - baseStrength) * (1 - airbrushStrength)
                guard strength > 0 else { continue }

                if protectTones {
                    let protected = Self.protectedToneComponents(
                        red: red,
                        green: green,
                        blue: blue,
                        luminance: luminance,
                        strength: strength,
                        burn: burn
                    )
                    sourcePixels[offset] = UInt8((protected.red * 255).rounded())
                    sourcePixels[offset + 1] = UInt8((protected.green * 255).rounded())
                    sourcePixels[offset + 2] = UInt8((protected.blue * 255).rounded())
                } else {
                    for channel in 0..<3 {
                        let value = CGFloat(sourcePixels[offset + channel])
                        let adjusted = burn
                            ? value * (1 - strength)
                            : value + (255 - value) * strength
                        sourcePixels[offset + channel] = UInt8(max(0, min(255, adjusted.rounded())))
                    }
                }
            }
        }

        return NSImage.fromRGBA(
            pixels: sourcePixels,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            size: size
        )
    }

    private static func protectedToneComponents(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        luminance: CGFloat,
        strength: CGFloat,
        burn: Bool
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let clipInset = 1 / CGFloat(255)
        let upperLimit = 1 - clipInset
        let targetLuminance = burn
            ? luminance * (1 - strength)
            : luminance + (1 - luminance) * strength
        let protectedLuminance = max(clipInset, min(upperLimit, targetLuminance))
        let redChroma = red - luminance
        let greenChroma = green - luminance
        let blueChroma = blue - luminance
        let redScale = maximumChromaScale(
            for: redChroma,
            luminance: protectedLuminance,
            lowerLimit: clipInset,
            upperLimit: upperLimit
        )
        let greenScale = maximumChromaScale(
            for: greenChroma,
            luminance: protectedLuminance,
            lowerLimit: clipInset,
            upperLimit: upperLimit
        )
        let blueScale = maximumChromaScale(
            for: blueChroma,
            luminance: protectedLuminance,
            lowerLimit: clipInset,
            upperLimit: upperLimit
        )
        let chromaScale = max(0, min(1, min(redScale, min(greenScale, blueScale))))

        return (
            max(clipInset, min(upperLimit, protectedLuminance + redChroma * chromaScale)),
            max(clipInset, min(upperLimit, protectedLuminance + greenChroma * chromaScale)),
            max(clipInset, min(upperLimit, protectedLuminance + blueChroma * chromaScale))
        )
    }

    private static func maximumChromaScale(
        for component: CGFloat,
        luminance: CGFloat,
        lowerLimit: CGFloat,
        upperLimit: CGFloat
    ) -> CGFloat {
        if component > 0 {
            return (upperLimit - luminance) / component
        }
        if component < 0 {
            return (luminance - lowerLimit) / -component
        }
        return 1
    }

    private func saturationAdjusted(
        maskAlpha: [UInt8],
        maskBounds: ImageEditorHealingBrushKernel.MaskBounds,
        opacity: CGFloat,
        mode: ImageEditorSpongeMode,
        vibrance: Bool
    ) -> NSImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let maskWidth = maskBounds.maxX - maskBounds.minX + 1
        let maskHeight = maskBounds.maxY - maskBounds.minY + 1
        guard var sourcePixels = rgbaPixels(width: width, height: height, bytesPerRow: bytesPerRow),
              maskBounds.minX >= 0, maskBounds.minY >= 0,
              maskBounds.maxX < width, maskBounds.maxY < height,
              maskWidth > 0, maskHeight > 0,
              maskAlpha.count == maskWidth * maskHeight
        else { return nil }

        let clampedOpacity = max(0, min(1, opacity))
        for localY in 0..<maskHeight {
            for localX in 0..<maskWidth {
                let y = maskBounds.minY + localY
                let x = maskBounds.minX + localX
                let offset = y * bytesPerRow + x * bytesPerPixel
                let maskIndex = localY * maskWidth + localX
                let baseStrength = CGFloat(maskAlpha[maskIndex]) / 255
                    * clampedOpacity
                    * ImageEditorRetouchTuning.spongeEffectScale
                guard baseStrength > 0 else { continue }

                let red = CGFloat(sourcePixels[offset])
                let green = CGFloat(sourcePixels[offset + 1])
                let blue = CGFloat(sourcePixels[offset + 2])
                let chroma = (max(red, max(green, blue)) - min(red, min(green, blue))) / 255
                let vibranceWeight: CGFloat
                switch mode {
                case .saturate:
                    let endpointDistance = 1 - chroma
                    vibranceWeight = endpointDistance * endpointDistance
                case .desaturate:
                    vibranceWeight = sqrt(chroma)
                        * ImageEditorRetouchTuning.spongeDesaturateVibranceBoost
                }
                let strength = vibrance
                    ? baseStrength * max(0, min(1, vibranceWeight))
                    : baseStrength
                let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
                let multiplier = mode == .saturate ? 1 + strength : 1 - strength
                sourcePixels[offset] = UInt8(max(0, min(255, (luminance + (red - luminance) * multiplier).rounded())))
                sourcePixels[offset + 1] = UInt8(max(0, min(255, (luminance + (green - luminance) * multiplier).rounded())))
                sourcePixels[offset + 2] = UInt8(max(0, min(255, (luminance + (blue - luminance) * multiplier).rounded())))
            }
        }

        return NSImage.fromRGBA(
            pixels: sourcePixels,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            size: size
        )
    }

    private func rgbaPixels(width: Int, height: Int, bytesPerRow: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return nil
        }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private static func fromRGBA(
        pixels: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int,
        size: CGSize
    ) -> NSImage? {
        var outputPixels = pixels
        guard let context = CGContext(
            data: &outputPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgImage = context.makeImage()
        else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: size)
    }
}
