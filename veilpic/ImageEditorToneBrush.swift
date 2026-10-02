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
        return saturationAdjusted(
            maskAlpha: maskAlpha,
            opacity: opacity,
            mode: mode,
            vibrance: vibrance
        )
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
            guard let strokeMask = ImageEditorHealingBrushKernel.strokeMaskImage(
                size: size,
                points: [previous, current],
                diameter: segmentDiameter,
                hardness: hardness
            ),
            let shiftedSource = NSImage.rendered(size: size, actions: { _ in
                sourceSnapshot.draw(
                    in: CGRect(x: delta.width, y: -delta.height, width: size.width, height: size.height),
                    from: CGRect(origin: .zero, size: sourceSnapshot.size),
                    operation: .copy,
                    fraction: 1
                )
            }),
            let clippedSource = NSImage.rendered(size: size, actions: { rect in
                shiftedSource.draw(
                    in: rect,
                    from: CGRect(origin: .zero, size: shiftedSource.size),
                    operation: .copy,
                    fraction: 1
                )
                strokeMask.draw(
                    in: rect,
                    from: CGRect(origin: .zero, size: strokeMask.size),
                    operation: .destinationIn,
                    fraction: 1
                )
            }),
            let nextOutput = NSImage.rendered(size: size, actions: { rect in
                output.draw(
                    in: rect,
                    from: CGRect(origin: .zero, size: output.size),
                    operation: .copy,
                    fraction: 1
                )
                clippedSource.draw(
                    in: rect,
                    from: CGRect(origin: .zero, size: clippedSource.size),
                    operation: .sourceOver,
                    fraction: clampedOpacity
                )
            }) else {
                return nil
            }
            if usesIndependentSource {
                guard let nextWorkingSource = NSImage.rendered(size: size, actions: { rect in
                    workingSource.draw(
                        in: rect,
                        from: CGRect(origin: .zero, size: workingSource.size),
                        operation: .copy,
                        fraction: 1
                    )
                    clippedSource.draw(
                        in: rect,
                        from: CGRect(origin: .zero, size: clippedSource.size),
                        operation: .sourceOver,
                        fraction: clampedOpacity
                    )
                }) else { return nil }
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
        let maskAlpha = retouchStrokeAlpha(
            width: pixelWidth,
            height: pixelHeight,
            samples: samples,
            diameter: width,
            hardness: hardness,
            pressureControlsSize: pressureControlsSize,
            pressureSensitivity: pressureSensitivity
        )
        guard let strokeMask = NSImage.alphaMaskImage(
            width: pixelWidth,
            height: pixelHeight,
            alpha: maskAlpha
        ) else { return nil }

        guard let clippedBlur = NSImage.rendered(size: size, actions: { _ in
            brushSource.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: brushSource.size),
                operation: .copy,
                fraction: 1
            )
            strokeMask.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: strokeMask.size),
                operation: .destinationIn,
                fraction: 1
            )
        }) else {
            return nil
        }

        return NSImage.rendered(size: size, actions: { _ in
            draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: size),
                operation: .copy,
                fraction: 1
            )
            clippedBlur.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: clippedBlur.size),
                operation: .sourceOver,
                fraction: max(0, min(1, opacity))
            )
        })
    }

    private func toneAdjusted(
        maskAlpha: [UInt8],
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
        guard var sourcePixels = rgbaPixels(width: width, height: height, bytesPerRow: bytesPerRow),
              maskAlpha.count == width * height,
              airbrushMaskAlpha == nil || airbrushMaskAlpha?.count == width * height
        else {
            return nil
        }

        let clampedOpacity = max(0, min(1, opacity))
        let effectScale = ImageEditorRetouchTuning.toneEffectScale
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let maskIndex = y * width + x
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
        opacity: CGFloat,
        mode: ImageEditorSpongeMode,
        vibrance: Bool
    ) -> NSImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        guard var sourcePixels = rgbaPixels(width: width, height: height, bytesPerRow: bytesPerRow),
              maskAlpha.count == width * height
        else { return nil }

        let clampedOpacity = max(0, min(1, opacity))
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let maskIndex = y * width + x
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
