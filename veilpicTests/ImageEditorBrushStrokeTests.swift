//
//  ImageEditorBrushStrokeTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorBrushStrokeTests {
    @Test func paintingBlendModesUseUnpremultipliedBaseColorAndSourceOverAlpha() {
        let opaqueBlue: [UInt8] = [0, 0, 255, 255]
        let coverage: [UInt8] = [.max]
        let multiply = ImageEditorBrushStrokeKernel.composite(
            targetPixels: opaqueBlue,
            coverage: coverage,
            color: .red,
            erase: false,
            blendMode: .multiply
        )
        let screen = ImageEditorBrushStrokeKernel.composite(
            targetPixels: opaqueBlue,
            coverage: coverage,
            color: .red,
            erase: false,
            blendMode: .screen
        )

        #expect(multiply == [0, 0, 0, 255])
        #expect(screen == [255, 0, 255, 255])

        let halfTransparentBlue: [UInt8] = [0, 0, 128, 128]
        let screenOverTransparency = ImageEditorBrushStrokeKernel.composite(
            targetPixels: halfTransparentBlue,
            coverage: coverage,
            color: .red,
            erase: false,
            blendMode: .screen
        )
        #expect(screenOverTransparency[0] == 255)
        #expect(screenOverTransparency[1] == 0)
        #expect(abs(Int(screenOverTransparency[2]) - 128) <= 1)
        #expect(screenOverTransparency[3] == 255)
    }

    @Test func quickAndLayerMaskStrokeMathUsesTheSelectedPaintingBlendMode() throws {
        let base = ImageEditorSelectionMask(
            width: 8,
            height: 8,
            alpha: [UInt8](repeating: 128, count: 64)
        )
        let sample = ImageEditorBrushStrokeSample(point: CGPoint(x: 4, y: 4))
        let multiply = try #require(base.paintedByQuickMaskStroke(
            samples: [sample],
            canvasSize: CGSize(width: 8, height: 8),
            diameter: 6,
            opacity: 1,
            hardness: 1,
            flow: 1,
            edgeStyle: .aliased,
            targetAlpha: .max,
            blendMode: .multiply
        ))
        let screen = try #require(base.paintedByQuickMaskStroke(
            samples: [sample],
            canvasSize: CGSize(width: 8, height: 8),
            diameter: 6,
            opacity: 1,
            hardness: 1,
            flow: 1,
            edgeStyle: .aliased,
            targetAlpha: .max,
            blendMode: .screen
        ))
        let center = 4 * 8 + 4

        #expect(multiply.alpha[center] == 128)
        #expect(screen.alpha[center] == .max)
    }

    @Test func airbrushTimePulsesRemainDiscreteAndBuildUpToTheOpacityLimit() throws {
        let size = CGSize(width: 24, height: 24)
        let point = CGPoint(x: 12, y: 12)
        let source = NSImage.transparent(size: size)
        let settings = ImageEditorBrushStrokeSettings(
            diameter: 8,
            hardness: 1,
            opacity: 0.7,
            flow: 0.2,
            spacing: 0.25
        )
        let ordinary = try #require(source.withBrushStroke(
            samples: [ImageEditorBrushStrokeSample(point: point)],
            color: .red,
            settings: settings,
            erase: false
        ))
        let airbrushed = try #require(source.withBrushStroke(
            samples: [ImageEditorBrushStrokeSample(point: point)],
            color: .red,
            settings: settings,
            erase: false,
            airbrushPulseSamples: Array(
                repeating: ImageEditorBrushStrokeSample(point: point),
                count: 4
            )
        ))
        let ordinaryAlpha = try #require(ordinary.color(at: point)).alphaComponent
        let airbrushAlpha = try #require(airbrushed.color(at: point)).alphaComponent

        #expect(ordinaryAlpha > 0.18 && ordinaryAlpha < 0.23)
        #expect(airbrushAlpha > 0.64 && airbrushAlpha < 0.70)
        #expect(airbrushAlpha > ordinaryAlpha + 0.4)
        #expect(airbrushAlpha <= 0.71)
    }

    @Test func brushAirbrushBuildsPixelsAndBothMaskTargetsAsOneHistoryStep() throws {
        let size = CGSize(width: 24, height: 24)
        let point = CGPoint(x: 12, y: 12)
        let samples = [ImageEditorBrushStrokeSample(point: point)]
        let pulses = Array(repeating: ImageEditorBrushStrokeSample(point: point), count: 4)
        let suiteName = "ImageEditorBrushStrokeTests.airbrush.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let pixels = ImageEditorViewModel(
            sourceName: "airbrush-pixels.png",
            image: NSImage.transparent(size: size),
            preferencesDefaults: defaults
        ) { _ in }
        pixels.foregroundColor = .red
        pixels.brushSize = 8
        pixels.hardness = 1
        pixels.opacity = 0.7
        pixels.brushFlow = 20
        let pixelHistoryCount = pixels.document.history.count
        pixels.drawBrush(samples: samples, airbrushPulseSamples: pulses)
        let pixelAlpha = try #require(
            pixels.document.selectedLayer?.image.color(at: point)
        ).alphaComponent
        #expect(pixelAlpha > 0.64 && pixelAlpha < 0.70)
        #expect(pixels.document.history.count == pixelHistoryCount + 1)

        let quickMask = ImageEditorViewModel(
            sourceName: "airbrush-quick-mask.png",
            image: NSImage.transparent(size: size),
            preferencesDefaults: defaults
        ) { _ in }
        quickMask.document.selection = .raster(
            mask: ImageEditorSelectionMask(
                width: 24,
                height: 24,
                alpha: [UInt8](repeating: .min, count: 24 * 24)
            ),
            bounds: CGRect(origin: .zero, size: size)
        )
        quickMask.isQuickMaskMode = true
        quickMask.foregroundColor = .white
        quickMask.brushSize = 8
        quickMask.hardness = 1
        quickMask.opacity = 0.7
        quickMask.brushFlow = 20
        let quickHistoryCount = quickMask.document.history.count
        quickMask.drawBrush(samples: samples, airbrushPulseSamples: pulses)
        let quickAlpha = try #require(
            quickMask.document.selection?.rasterizedMask(canvasSize: size)
        ).alpha[12 * 24 + 12]
        #expect(quickAlpha > 160 && quickAlpha < 180)
        #expect(quickMask.document.history.count == quickHistoryCount + 1)

        let whiteMask = NSImage.rendered(size: size) { rect in
            NSColor.white.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
        let layerMask = ImageEditorViewModel(
            sourceName: "airbrush-layer-mask.png",
            image: NSImage.transparent(size: size),
            preferencesDefaults: defaults
        ) { _ in }
        let layerIndex = try #require(layerMask.document.selectedLayerIndex)
        layerMask.document.layers[layerIndex].mask = whiteMask
        layerMask.isEditingLayerMask = true
        layerMask.brushSize = 8
        layerMask.hardness = 1
        layerMask.opacity = 0.7
        layerMask.brushFlow = 20
        let maskHistoryCount = layerMask.document.history.count
        layerMask.drawBrush(samples: samples, airbrushPulseSamples: pulses)
        let maskAlpha = try #require(
            layerMask.document.selectedLayer?.mask?.color(at: point)
        ).alphaComponent
        #expect(maskAlpha > 0.30 && maskAlpha < 0.36)
        #expect(layerMask.document.history.count == maskHistoryCount + 1)
    }

    @Test func stampSpacingIsStableAcrossSparseAndDensePointerSamples() {
        let sparse = ImageEditorBrushStrokeKernel.stampCenters(
            points: [CGPoint(x: 5, y: 10), CGPoint(x: 95, y: 10)],
            diameter: 20,
            spacing: 0.25
        )
        let dense = ImageEditorBrushStrokeKernel.stampCenters(
            points: [
                CGPoint(x: 5, y: 10), CGPoint(x: 20, y: 10), CGPoint(x: 35, y: 10),
                CGPoint(x: 50, y: 10), CGPoint(x: 65, y: 10), CGPoint(x: 80, y: 10),
                CGPoint(x: 95, y: 10)
            ],
            diameter: 20,
            spacing: 0.25
        )

        #expect(sparse.count == 19)
        #expect(dense.count == sparse.count)
        for (sparsePoint, densePoint) in zip(sparse, dense) {
            #expect(abs(sparsePoint.x - densePoint.x) < 0.0001)
            #expect(abs(sparsePoint.y - densePoint.y) < 0.0001)
        }

        let settings = ImageEditorBrushStrokeSettings(
            diameter: 20,
            hardness: 0.7,
            opacity: 0.8,
            flow: 0.35,
            spacing: 0.25
        )
        #expect(
            ImageEditorBrushStrokeKernel.coverage(
                width: 100,
                height: 24,
                centers: sparse,
                settings: settings
            ) == ImageEditorBrushStrokeKernel.coverage(
                width: 100,
                height: 24,
                centers: dense,
                settings: settings
            )
        )
    }

    @Test func flowAccumulatesPerStampWithoutExceedingOpacityCap() {
        let settings = ImageEditorBrushStrokeSettings(
            diameter: 10,
            hardness: 1,
            opacity: 0.6,
            flow: 0.2,
            spacing: 0.25
        )
        let oneStamp = ImageEditorBrushStrokeKernel.coverage(
            width: 24,
            height: 24,
            centers: [CGPoint(x: 12, y: 12)],
            settings: settings
        )
        let repeated = ImageEditorBrushStrokeKernel.coverage(
            width: 24,
            height: 24,
            centers: Array(repeating: CGPoint(x: 12, y: 12), count: 12),
            settings: settings
        )
        let center = 12 * 24 + 12

        #expect(oneStamp[center] >= 50 && oneStamp[center] <= 52)
        #expect(repeated[center] > oneStamp[center])
        #expect(repeated[center] == UInt8((0.6 * 255).rounded()))
    }

    @Test func wideSpacingCreatesGapsWhileTightSpacingProducesAContinuousStroke() {
        let points = [CGPoint(x: 10, y: 15), CGPoint(x: 70, y: 15)]
        let settings = ImageEditorBrushStrokeSettings(
            diameter: 10,
            hardness: 1,
            opacity: 1,
            flow: 1,
            spacing: 2
        )
        let wide = ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 30,
            centers: ImageEditorBrushStrokeKernel.stampCenters(
                points: points,
                diameter: settings.diameter,
                spacing: settings.spacing
            ),
            settings: settings
        )
        var tightSettings = settings
        tightSettings.spacing = 0.25
        let tight = ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 30,
            centers: ImageEditorBrushStrokeKernel.stampCenters(
                points: points,
                diameter: tightSettings.diameter,
                spacing: tightSettings.spacing
            ),
            settings: tightSettings
        )
        let betweenWideStamps = 15 * 80 + 20

        #expect(wide[betweenWideStamps] == 0)
        #expect(tight[betweenWideStamps] > 240)
    }

    @Test func hardnessControlsTheBrushEdgeFalloff() {
        let center = CGPoint(x: 12, y: 12)
        var softSettings = ImageEditorBrushStrokeSettings(
            diameter: 10,
            hardness: 0,
            opacity: 1,
            flow: 1,
            spacing: 0.25
        )
        let soft = ImageEditorBrushStrokeKernel.coverage(
            width: 24,
            height: 24,
            centers: [center],
            settings: softSettings
        )
        softSettings.hardness = 1
        let hard = ImageEditorBrushStrokeKernel.coverage(
            width: 24,
            height: 24,
            centers: [center],
            settings: softSettings
        )
        let edge = 15 * 24 + 12

        #expect(soft[edge] > 0 && soft[edge] < 220)
        #expect(hard[edge] > soft[edge])
    }

    @Test func aliasedEdgeStyleProducesOnlyHardPixelCoverage() {
        let center = CGPoint(x: 10.75, y: 10.75)
        let antialiasedSettings = ImageEditorBrushStrokeSettings(
            diameter: 6,
            hardness: 1,
            opacity: 1,
            flow: 1,
            spacing: 0.25
        )
        var aliasedSettings = antialiasedSettings
        aliasedSettings.hardness = 0
        aliasedSettings.edgeStyle = .aliased

        let antialiased = ImageEditorBrushStrokeKernel.coverage(
            width: 24,
            height: 24,
            centers: [center],
            settings: antialiasedSettings
        )
        let aliased = ImageEditorBrushStrokeKernel.coverage(
            width: 24,
            height: 24,
            centers: [center],
            settings: aliasedSettings
        )

        #expect(antialiased.contains { $0 > 0 && $0 < .max })
        #expect(aliased.allSatisfy { $0 == 0 || $0 == .max })
        #expect(aliased != antialiased)
    }

    @Test func pressureCurveRespondsToSensitivityAndClampsInput() {
        let lowSensitivity = ImageEditorBrushStrokeKernel.mappedPressure(0.25, sensitivity: 0)
        let neutral = ImageEditorBrushStrokeKernel.mappedPressure(0.25, sensitivity: 0.5)
        let highSensitivity = ImageEditorBrushStrokeKernel.mappedPressure(0.25, sensitivity: 1)

        #expect(lowSensitivity < neutral)
        #expect(neutral < highSensitivity)
        #expect(ImageEditorBrushStrokeKernel.mappedPressure(-1, sensitivity: 0.5) == 0.05)
        #expect(ImageEditorBrushStrokeKernel.mappedPressure(2, sensitivity: 0.5) == 1)
    }

    @Test func resamplingInterpolatesPressureAlongThePointerPath() throws {
        let stamps = ImageEditorBrushStrokeKernel.stampSamples(
            samples: [
                ImageEditorBrushStrokeSample(point: CGPoint(x: 0, y: 10), pressure: 0.2),
                ImageEditorBrushStrokeSample(point: CGPoint(x: 20, y: 10), pressure: 1)
            ],
            diameter: 10,
            spacing: 0.5
        )

        #expect(stamps.map(\.point.x) == [0, 5, 10, 15, 20])
        #expect(abs((try #require(stamps[2].pressure)) - 0.6) < 0.0001)
    }

    @Test func smoothingReducesJitterWhilePreservingEndpointsAndStylusDynamics() throws {
        let samples = [
            ImageEditorBrushStrokeSample(
                point: CGPoint(x: 0, y: 10),
                pressure: 0.1,
                tilt: ImageEditorStylusTilt(x: 0.1, y: 0)
            ),
            ImageEditorBrushStrokeSample(
                point: CGPoint(x: 10, y: 18),
                pressure: 0.3,
                tilt: ImageEditorStylusTilt(x: 0.3, y: 0)
            ),
            ImageEditorBrushStrokeSample(
                point: CGPoint(x: 20, y: 2),
                pressure: 0.5,
                tilt: ImageEditorStylusTilt(x: 0.5, y: 0)
            ),
            ImageEditorBrushStrokeSample(
                point: CGPoint(x: 30, y: 18),
                pressure: 0.7,
                tilt: ImageEditorStylusTilt(x: 0.7, y: 0)
            ),
            ImageEditorBrushStrokeSample(
                point: CGPoint(x: 40, y: 10),
                pressure: 0.9,
                tilt: ImageEditorStylusTilt(x: 0.9, y: 0)
            )
        ]

        let smoothed = ImageEditorBrushStrokeKernel.smoothedSamples(
            samples,
            amount: 1
        )

        #expect(smoothed.first == samples.first)
        #expect(smoothed.last == samples.last)
        #expect(smoothed.map(\.pressure) == samples.map(\.pressure))
        #expect(smoothed.map(\.tilt) == samples.map(\.tilt))
        let originalDeviation = samples.dropFirst().dropLast().reduce(CGFloat.zero) {
            $0 + abs($1.point.y - 10)
        }
        let smoothedDeviation = smoothed.dropFirst().dropLast().reduce(CGFloat.zero) {
            $0 + abs($1.point.y - 10)
        }
        #expect(smoothedDeviation < originalDeviation * 0.35)
    }

    @Test func zeroSmoothingAndShortStrokesRemainExactlyCompatible() {
        let samples = [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 0, y: 4), pressure: 0.2),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 10, y: 12), pressure: 0.6),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 20, y: 4), pressure: 1)
        ]
        #expect(ImageEditorBrushStrokeKernel.smoothedSamples(
            samples,
            amount: 0
        ) == samples)
        #expect(ImageEditorBrushStrokeKernel.smoothedSamples(
            Array(samples.prefix(2)),
            amount: 1
        ) == Array(samples.prefix(2)))
        #expect(ImageEditorBrushStrokeSettings(
            diameter: 12,
            hardness: 1,
            opacity: 1,
            flow: 1,
            spacing: 0.25,
            smoothing: -1
        ).normalized.smoothing == 0)
        #expect(ImageEditorBrushStrokeSettings(
            diameter: 12,
            hardness: 1,
            opacity: 1,
            flow: 1,
            spacing: 0.25,
            smoothing: 2
        ).normalized.smoothing == 1)
    }

    @Test func pressureCanControlDiameterOpacityAndFlowIndependently() {
        #expect(ImageEditorBrushStrokeKernel.pressureDiameterScale(
            mappedPressure: 0.05,
            minimumDiameter: 0.4
        ) == 0.4)
        #expect(ImageEditorBrushStrokeKernel.pressureDiameterScale(
            mappedPressure: 0.75,
            minimumDiameter: 0.4
        ) == 0.75)
        #expect(ImageEditorBrushStrokeKernel.pressureDiameterScale(
            mappedPressure: 2,
            minimumDiameter: -1
        ) == 1)
        #expect(ImageEditorBrushStrokeKernel.pressureFlowScale(
            mappedPressure: 0.05,
            minimumFlow: 0.4
        ) == 0.4)
        #expect(ImageEditorBrushStrokeKernel.pressureFlowScale(
            mappedPressure: 0.75,
            minimumFlow: 0.4
        ) == 0.75)
        #expect(ImageEditorBrushStrokeKernel.pressureFlowScale(
            mappedPressure: 2,
            minimumFlow: -1
        ) == 1)
        #expect(ImageEditorBrushStrokeKernel.pressureOpacityScale(
            mappedPressure: 0.05,
            minimumOpacity: 0.4
        ) == 0.4)
        #expect(ImageEditorBrushStrokeKernel.pressureOpacityScale(
            mappedPressure: 0.75,
            minimumOpacity: 0.4
        ) == 0.75)
        #expect(ImageEditorBrushStrokeKernel.pressureOpacityScale(
            mappedPressure: 2,
            minimumOpacity: -1
        ) == 1)
        let stamps = [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 15, y: 20), pressure: 0.2),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 55, y: 20), pressure: 1)
        ]
        let sizeSettings = ImageEditorBrushStrokeSettings(
            diameter: 20,
            hardness: 1,
            opacity: 1,
            flow: 1,
            spacing: 0.25,
            pressureControlsSize: true,
            pressureControlsFlow: false,
            pressureSensitivity: 0.5
        )
        let sized = ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 40,
            stamps: stamps,
            settings: sizeSettings
        )
        let lowPressureOuterPixel = 20 * 80 + 21
        let fullPressureOuterPixel = 20 * 80 + 61
        #expect(sized[lowPressureOuterPixel] == 0)
        #expect(sized[fullPressureOuterPixel] > 200)

        var minimumDiameterSettings = sizeSettings
        minimumDiameterSettings.minimumDiameter = 0.5
        let minimumSized = ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 40,
            stamps: stamps,
            settings: minimumDiameterSettings
        )
        #expect(minimumSized[20 * 80 + 19] > 200)
        #expect(minimumSized[fullPressureOuterPixel] == sized[fullPressureOuterPixel])

        var opacitySettings = sizeSettings
        opacitySettings.pressureControlsSize = false
        opacitySettings.pressureControlsOpacity = true
        opacitySettings.opacity = 0.8
        let opacityControlled = ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 40,
            stamps: stamps,
            settings: opacitySettings
        )
        #expect(opacityControlled[20 * 80 + 15] < opacityControlled[20 * 80 + 55])
        #expect(opacityControlled[20 * 80 + 55] == UInt8((0.8 * 255).rounded()))

        var minimumOpacitySettings = opacitySettings
        minimumOpacitySettings.minimumOpacity = 0.5
        let minimumOpacityControlled = ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 40,
            stamps: stamps,
            settings: minimumOpacitySettings
        )
        #expect(minimumOpacityControlled[20 * 80 + 15] > opacityControlled[20 * 80 + 15])
        #expect(minimumOpacityControlled[20 * 80 + 55] == opacityControlled[20 * 80 + 55])

        var flowSettings = sizeSettings
        flowSettings.pressureControlsSize = false
        flowSettings.pressureControlsFlow = true
        flowSettings.flow = 0.8
        let flowed = ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 40,
            stamps: stamps,
            settings: flowSettings
        )
        #expect(flowed[20 * 80 + 15] < flowed[20 * 80 + 55])
        #expect(flowed[20 * 80 + 55] == UInt8((0.8 * 255).rounded()))

        var minimumFlowSettings = flowSettings
        minimumFlowSettings.minimumFlow = 0.5
        let minimumFlowed = ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 40,
            stamps: stamps,
            settings: minimumFlowSettings
        )
        #expect(minimumFlowed[20 * 80 + 15] > flowed[20 * 80 + 15])
        #expect(minimumFlowed[20 * 80 + 55] == flowed[20 * 80 + 55])
    }

    @Test func sizeJitterIsDeterministicAndZeroRemainsPixelCompatible() {
        let stamps = (0..<8).map {
            ImageEditorBrushStrokeSample(point: CGPoint(x: 8 + $0 * 8, y: 16))
        }
        let baseline = ImageEditorBrushStrokeSettings(
            diameter: 12,
            hardness: 0.75,
            opacity: 0.8,
            flow: 0.6,
            spacing: 0.25
        )
        var explicitZero = baseline
        explicitZero.sizeJitter = 0
        explicitZero.minimumDiameter = 1
        let original = ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 32,
            stamps: stamps,
            settings: baseline
        )
        let zeroJitter = ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 32,
            stamps: stamps,
            settings: explicitZero
        )

        #expect(original == zeroJitter)
        let sequence = stamps.indices.map {
            ImageEditorBrushStrokeKernel.sizeJitterScale(stampIndex: $0, amount: 0.75)
        }
        #expect(sequence == stamps.indices.map {
            ImageEditorBrushStrokeKernel.sizeJitterScale(stampIndex: $0, amount: 0.75)
        })
        #expect(Set(sequence).count > 4)
        #expect(sequence.allSatisfy { $0 >= 0.25 && $0 <= 1 })
    }

    @Test func sizeJitterAndPressureShareTheMinimumDiameterFloor() {
        let jitterOnly = (0..<32).map {
            ImageEditorBrushStrokeKernel.resolvedDiameterScale(
                mappedPressure: 1,
                pressureControlsSize: false,
                stampIndex: $0,
                sizeJitter: 1,
                minimumDiameter: 0.4
            )
        }
        let pressureAndJitter = (0..<32).map {
            ImageEditorBrushStrokeKernel.resolvedDiameterScale(
                mappedPressure: 0.2,
                pressureControlsSize: true,
                stampIndex: $0,
                sizeJitter: 1,
                minimumDiameter: 0.4
            )
        }

        #expect(jitterOnly.allSatisfy { $0 >= 0.4 && $0 <= 1 })
        #expect(jitterOnly.contains(0.4))
        #expect(pressureAndJitter.allSatisfy { $0 == 0.4 })
        #expect(ImageEditorBrushStrokeKernel.resolvedDiameterScale(
            mappedPressure: 0.1,
            pressureControlsSize: false,
            stampIndex: 7,
            sizeJitter: 0,
            minimumDiameter: 1
        ) == 1)
    }

    @Test func angleJitterIsDeterministicBoundedAndIndependentFromSizeJitter() {
        let first = (0..<32).map {
            ImageEditorBrushStrokeKernel.angleJitterOffsetDegrees(
                stampIndex: $0,
                amount: 0.5
            )
        }
        let replay = (0..<32).map {
            ImageEditorBrushStrokeKernel.angleJitterOffsetDegrees(
                stampIndex: $0,
                amount: 0.5
            )
        }
        let sizeSequence = (0..<32).map {
            ImageEditorBrushStrokeKernel.sizeJitterScale(stampIndex: $0, amount: 0.5)
        }

        #expect(first == replay)
        #expect(first.allSatisfy { $0 >= -90 && $0 <= 90 })
        #expect(first.contains(where: { $0 < 0 }))
        #expect(first.contains(where: { $0 > 0 }))
        #expect(ImageEditorBrushStrokeKernel.angleJitterOffsetDegrees(
            stampIndex: 7,
            amount: 0
        ) == 0)
        #expect(zip(first, sizeSequence).contains {
            abs(($0.0 / 180 + 0.5) - $0.1) > 0.01
        })
    }

    @Test func flattenedTipAngleJitterReplaysIdenticalPixelsAndZeroKeepsBaseline() {
        let stamps = (0..<7).map {
            ImageEditorBrushStrokeSample(point: CGPoint(x: 12 + $0 * 16, y: 24))
        }
        let baseline = ImageEditorBrushStrokeSettings(
            diameter: 14,
            hardness: 1,
            opacity: 1,
            flow: 1,
            spacing: 1,
            tipRoundness: 0.25,
            tipAngleDegrees: 30
        )
        var explicitZero = baseline
        explicitZero.angleJitter = 0
        var jittered = baseline
        jittered.angleJitter = 1
        var circular = jittered
        circular.tipRoundness = 1
        var circularBaseline = baseline
        circularBaseline.tipRoundness = 1

        let original = ImageEditorBrushStrokeKernel.coverage(
            width: 124,
            height: 48,
            stamps: stamps,
            settings: baseline
        )
        let zero = ImageEditorBrushStrokeKernel.coverage(
            width: 124,
            height: 48,
            stamps: stamps,
            settings: explicitZero
        )
        let first = ImageEditorBrushStrokeKernel.coverage(
            width: 124,
            height: 48,
            stamps: stamps,
            settings: jittered
        )
        let replay = ImageEditorBrushStrokeKernel.coverage(
            width: 124,
            height: 48,
            stamps: stamps,
            settings: jittered
        )

        #expect(original == zero)
        #expect(first == replay)
        #expect(first != original)
        #expect(ImageEditorBrushStrokeKernel.coverage(
            width: 124,
            height: 48,
            stamps: stamps,
            settings: circular
        ) == ImageEditorBrushStrokeKernel.coverage(
            width: 124,
            height: 48,
            stamps: stamps,
            settings: circularBaseline
        ))
    }

    @Test func roundnessJitterIsDeterministicBoundedAndIndependentFromOtherDynamics() {
        let first = (0..<32).map {
            ImageEditorBrushStrokeKernel.roundnessJitterAspectRatio(
                stampIndex: $0,
                baseRoundness: 0.8,
                amount: 1,
                minimumRoundness: 0.2
            )
        }
        let replay = (0..<32).map {
            ImageEditorBrushStrokeKernel.roundnessJitterAspectRatio(
                stampIndex: $0,
                baseRoundness: 0.8,
                amount: 1,
                minimumRoundness: 0.2
            )
        }
        let sizeSequence = (0..<32).map {
            ImageEditorBrushStrokeKernel.sizeJitterScale(stampIndex: $0, amount: 1)
        }

        #expect(first == replay)
        #expect(first.allSatisfy { $0 >= 0.2 && $0 <= 0.8 })
        #expect(Set(first).count > 16)
        #expect(ImageEditorBrushStrokeKernel.roundnessJitterAspectRatio(
            stampIndex: 7,
            baseRoundness: 0.8,
            amount: 0,
            minimumRoundness: 0.01
        ) == 0.8)
        #expect(ImageEditorBrushStrokeKernel.roundnessJitterAspectRatio(
            stampIndex: 7,
            baseRoundness: 0.4,
            amount: 1,
            minimumRoundness: 0.75
        ) == 0.4)
        #expect(zip(first, sizeSequence).contains { abs($0.0 - $0.1) > 0.01 })
    }

    @Test func roundnessJitterReplaysPixelsAndMinimumRoundnessLimitsFlattening() {
        let stamps = (0..<7).map {
            ImageEditorBrushStrokeSample(point: CGPoint(x: 12 + $0 * 16, y: 24))
        }
        let baseline = ImageEditorBrushStrokeSettings(
            diameter: 14,
            hardness: 1,
            opacity: 1,
            flow: 1,
            spacing: 1,
            tipRoundness: 1,
            tipAngleDegrees: 25
        )
        var jittered = baseline
        jittered.roundnessJitter = 1
        jittered.minimumRoundness = 0.1
        var constrained = jittered
        constrained.minimumRoundness = 0.75

        let original = ImageEditorBrushStrokeKernel.coverage(
            width: 124,
            height: 48,
            stamps: stamps,
            settings: baseline
        )
        let first = ImageEditorBrushStrokeKernel.coverage(
            width: 124,
            height: 48,
            stamps: stamps,
            settings: jittered
        )
        let replay = ImageEditorBrushStrokeKernel.coverage(
            width: 124,
            height: 48,
            stamps: stamps,
            settings: jittered
        )
        let limited = ImageEditorBrushStrokeKernel.coverage(
            width: 124,
            height: 48,
            stamps: stamps,
            settings: constrained
        )

        #expect(first == replay)
        #expect(first != original)
        #expect(limited != first)
        #expect(limited.filter { $0 > 0 }.count > first.filter { $0 > 0 }.count)
    }

    @Test func scatteringUsesStrokeNormalAndOptionalBothAxesDeterministically() {
        let stamps = [30, 50, 70].map {
            ImageEditorBrushStrokeSample(point: CGPoint(x: $0, y: 40))
        }
        var settings = ImageEditorBrushStrokeSettings(
            diameter: 12,
            hardness: 1,
            opacity: 1,
            flow: 1,
            spacing: 1,
            scatter: 0.75
        )
        let transverse = ImageEditorBrushStrokeKernel.renderedStamps(
            from: stamps,
            settings: settings
        )
        let replay = ImageEditorBrushStrokeKernel.renderedStamps(
            from: stamps,
            settings: settings
        )

        #expect(transverse == replay)
        #expect(transverse.map(\.sample.point.x) == stamps.map(\.point.x))
        #expect(zip(transverse, stamps).allSatisfy {
            abs($0.0.sample.point.y - $0.1.point.y) <= 9
        })
        #expect(zip(transverse, stamps).contains {
            abs($0.0.sample.point.y - $0.1.point.y) > 0.1
        })

        settings.scatterBothAxes = true
        let bothAxes = ImageEditorBrushStrokeKernel.renderedStamps(
            from: stamps,
            settings: settings
        )
        #expect(bothAxes.map(\.sample.point.y) == transverse.map(\.sample.point.y))
        #expect(zip(bothAxes, stamps).contains {
            abs($0.0.sample.point.x - $0.1.point.x) > 0.1
        })
        #expect(zip(bothAxes, stamps).allSatisfy {
            abs($0.0.sample.point.x - $0.1.point.x) <= 9
        })

        let normalized = ImageEditorBrushStrokeSettings(
            diameter: 12,
            hardness: 1,
            opacity: 1,
            flow: 1,
            spacing: 1,
            scatter: 20,
            scatterCount: 99,
            scatterCountJitter: -1
        ).normalized
        #expect(normalized.scatter == 10)
        #expect(normalized.scatterCount == 16)
        #expect(normalized.scatterCountJitter == 0)
    }

    @Test func scatterCountJitterIsStableBoundedAndDoesNotShiftExistingCopies() {
        let counts = (0..<64).map {
            ImageEditorBrushStrokeKernel.resolvedScatterCount(
                stampIndex: $0,
                count: 4,
                jitter: 1
            )
        }
        #expect(counts == (0..<64).map {
            ImageEditorBrushStrokeKernel.resolvedScatterCount(
                stampIndex: $0,
                count: 4,
                jitter: 1
            )
        })
        #expect(counts.allSatisfy { (1...4).contains($0) })
        #expect(Set(counts).count == 4)
        #expect(ImageEditorBrushStrokeKernel.resolvedScatterCount(
            stampIndex: 12,
            count: 4,
            jitter: 0
        ) == 4)

        let stamp = ImageEditorBrushStrokeSample(point: CGPoint(x: 40, y: 40))
        var fourSettings = ImageEditorBrushStrokeSettings(
            diameter: 10,
            hardness: 1,
            opacity: 1,
            flow: 0.25,
            spacing: 1,
            scatter: 0.6,
            scatterBothAxes: true,
            scatterCount: 4
        )
        let four = ImageEditorBrushStrokeKernel.renderedStamps(
            from: [stamp],
            settings: fourSettings
        )
        fourSettings.scatterCount = 8
        let eight = ImageEditorBrushStrokeKernel.renderedStamps(
            from: [stamp],
            settings: fourSettings
        )
        #expect(four == Array(eight.prefix(4)))

        let baseline = ImageEditorBrushStrokeSettings(
            diameter: 10,
            hardness: 1,
            opacity: 1,
            flow: 0.25,
            spacing: 1
        )
        var irrelevant = baseline
        irrelevant.scatterBothAxes = true
        irrelevant.scatterCountJitter = 1
        #expect(ImageEditorBrushStrokeKernel.renderedStamps(
            from: [stamp],
            settings: irrelevant
        ) == [ImageEditorBrushRenderedStamp(sample: stamp, dynamicIndex: 0)])
        #expect(ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 80,
            stamps: [stamp],
            settings: baseline
        ) == ImageEditorBrushStrokeKernel.coverage(
            width: 80,
            height: 80,
            stamps: [stamp],
            settings: irrelevant
        ))
    }

    @Test func scatteringReplaysPixelsAndQuickMaskUsesTheSameExpandedTips() throws {
        let samples = [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 18, y: 40)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 98, y: 40))
        ]
        let stamps = ImageEditorBrushStrokeKernel.stampSamples(
            samples: samples,
            diameter: 10,
            spacing: 1
        )
        let baseline = ImageEditorBrushStrokeSettings(
            diameter: 10,
            hardness: 1,
            opacity: 0.8,
            flow: 0.35,
            spacing: 1
        )
        var scatteredSettings = baseline
        scatteredSettings.scatter = 0.8
        scatteredSettings.scatterBothAxes = true
        scatteredSettings.scatterCount = 4
        scatteredSettings.scatterCountJitter = 0.5

        let original = ImageEditorBrushStrokeKernel.coverage(
            width: 120,
            height: 80,
            stamps: stamps,
            settings: baseline
        )
        let scattered = ImageEditorBrushStrokeKernel.coverage(
            width: 120,
            height: 80,
            stamps: stamps,
            settings: scatteredSettings
        )
        #expect(scattered == ImageEditorBrushStrokeKernel.coverage(
            width: 120,
            height: 80,
            stamps: stamps,
            settings: scatteredSettings
        ))
        #expect(scattered != original)
        #expect(scattered.filter { $0 > 0 }.count > original.filter { $0 > 0 }.count)

        let mask = ImageEditorSelectionMask(
            width: 120,
            height: 80,
            alpha: [UInt8](repeating: 0, count: 120 * 80)
        )
        let quickMask = try #require(mask.paintedByQuickMaskStroke(
            samples: samples,
            canvasSize: CGSize(width: 120, height: 80),
            diameter: 10,
            opacity: 0.8,
            hardness: 1,
            flow: 0.35,
            spacing: 1,
            scatter: 0.8,
            scatterBothAxes: true,
            scatterCount: 4,
            scatterCountJitter: 0.5,
            targetAlpha: .max
        ))
        #expect(quickMask == mask.paintedByQuickMaskStroke(
            samples: samples,
            canvasSize: CGSize(width: 120, height: 80),
            diameter: 10,
            opacity: 0.8,
            hardness: 1,
            flow: 0.35,
            spacing: 1,
            scatter: 0.8,
            scatterBothAxes: true,
            scatterCount: 4,
            scatterCountJitter: 0.5,
            targetAlpha: .max
        ))
        #expect(quickMask.alpha.filter { $0 > 0 }.count > original.filter { $0 > 0 }.count)
    }

    @Test func missingPressureFallsBackToFullPressureWithoutChangingMouseStrokes() {
        let settings = ImageEditorBrushStrokeSettings(
            diameter: 12,
            hardness: 0.8,
            opacity: 0.75,
            flow: 0.4,
            spacing: 0.25,
            pressureControlsSize: true,
            pressureControlsOpacity: true,
            pressureControlsFlow: true
        )
        let mouseStamps = ImageEditorBrushStrokeKernel.stampSamples(
            samples: [
                ImageEditorBrushStrokeSample(point: CGPoint(x: 8, y: 12)),
                ImageEditorBrushStrokeSample(point: CGPoint(x: 40, y: 12))
            ],
            diameter: settings.diameter,
            spacing: settings.spacing
        )
        let explicitFullPressure = mouseStamps.map {
            ImageEditorBrushStrokeSample(point: $0.point, pressure: 1)
        }

        #expect(ImageEditorBrushStrokeKernel.coverage(
            width: 48,
            height: 24,
            stamps: mouseStamps,
            settings: settings
        ) == ImageEditorBrushStrokeKernel.coverage(
            width: 48,
            height: 24,
            stamps: explicitFullPressure,
            settings: settings
        ))
    }

    @Test func pressureInputRejectsOrdinaryMouseValuesAndClampsSupportedDevices() {
        #expect(ImageEditorBrushPressureInput.normalizedPressure(
            rawPressure: 0,
            supportsPressure: false
        ) == nil)
        #expect(ImageEditorBrushPressureInput.normalizedPressure(
            rawPressure: -0.2,
            supportsPressure: true
        ) == 0)
        #expect(ImageEditorBrushPressureInput.normalizedPressure(
            rawPressure: 1.3,
            supportsPressure: true
        ) == 1)
    }

    @Test func livePressureDisplayClampsAndDistinguishesMissingInput() {
        let missing = ImageEditorBrushPressureDisplay(pressure: nil)
        #expect(missing.percent == nil)
        #expect(missing.fraction == 0)

        let invalid = ImageEditorBrushPressureDisplay(pressure: .nan)
        #expect(invalid.percent == nil)
        #expect(invalid.fraction == 0)

        let measured = ImageEditorBrushPressureDisplay(pressure: 0.426)
        #expect(measured.percent == 43)
        #expect(abs(measured.fraction - 0.426) < 0.0001)

        #expect(ImageEditorBrushPressureDisplay(pressure: -1).percent == 0)
        #expect(ImageEditorBrushPressureDisplay(pressure: 2).percent == 100)
    }

    @Test func stylusTiltNormalizesDirectionsAndRejectsOrdinaryMouseInput() throws {
        #expect(ImageEditorStylusInput.normalizedTilt(
            rawX: 0.4,
            rawY: -0.2,
            supportsTilt: false
        ) == nil)
        #expect(ImageEditorStylusInput.normalizedTilt(
            rawX: .nan,
            rawY: 0,
            supportsTilt: true
        ) == nil)

        let clamped = try #require(ImageEditorStylusInput.normalizedTilt(
            rawX: 1.4,
            rawY: -1.2,
            supportsTilt: true
        ))
        #expect(clamped.x == 1)
        #expect(clamped.y == -1)
        #expect(clamped.magnitude == 1)

        #expect(ImageEditorStylusTilt(x: 1, y: 0).azimuthDegrees == 0)
        #expect(ImageEditorStylusTilt(x: 0, y: 1).azimuthDegrees == 90)
        #expect(ImageEditorStylusTilt(x: -1, y: 0).azimuthDegrees == 180)
        #expect(ImageEditorStylusTilt(x: 0, y: -1).azimuthDegrees == 270)
        #expect(ImageEditorStylusTilt(x: 0, y: 0).azimuthDegrees == nil)

        let missingDisplay = ImageEditorStylusTiltDisplay(tilt: nil)
        #expect(missingDisplay.magnitudePercent == nil)
        #expect(missingDisplay.azimuthDegrees == nil)
    }

    @Test func brushStampInterpolationPreservesTiltSamples() throws {
        let stamps = ImageEditorBrushStrokeKernel.stampSamples(
            samples: [
                ImageEditorBrushStrokeSample(
                    point: CGPoint(x: 0, y: 0),
                    pressure: 0.2,
                    tilt: ImageEditorStylusTilt(x: 0, y: 0)
                ),
                ImageEditorBrushStrokeSample(
                    point: CGPoint(x: 10, y: 0),
                    pressure: 0.8,
                    tilt: ImageEditorStylusTilt(x: 1, y: 0)
                )
            ],
            diameter: 10,
            spacing: 0.5
        )

        #expect(stamps.count == 3)
        let middle = try #require(stamps.dropFirst().first)
        #expect(abs((middle.pressure ?? 0) - 0.5) < 0.0001)
        #expect(abs((middle.tilt?.x ?? 0) - 0.5) < 0.0001)
        #expect(abs(middle.tilt?.y ?? 1) < 0.0001)
    }

    @Test func tiltShapeFlattensAndOrientsTheBrushTipOnlyWhenEnabled() {
        let stamp = ImageEditorBrushStrokeSample(
            point: CGPoint(x: 20.5, y: 20.5),
            pressure: 1,
            tilt: ImageEditorStylusTilt(x: 1, y: 0)
        )
        var settings = ImageEditorBrushStrokeSettings(
            diameter: 20,
            hardness: 1,
            opacity: 1,
            flow: 1,
            spacing: 0.25,
            tiltControlsShape: true
        )
        let tilted = ImageEditorBrushStrokeKernel.coverage(
            width: 41,
            height: 41,
            stamps: [stamp],
            settings: settings
        )
        let horizontalEdge = 20 * 41 + 28
        let verticalEdge = 28 * 41 + 20

        #expect(tilted[horizontalEdge] > 240)
        #expect(tilted[verticalEdge] == 0)
        #expect(ImageEditorBrushStrokeKernel.tiltTipAspectRatio(
            tilt: stamp.tilt,
            isEnabled: true
        ) == 0.25)

        settings.tiltControlsShape = false
        let circular = ImageEditorBrushStrokeKernel.coverage(
            width: 41,
            height: 41,
            stamps: [stamp],
            settings: settings
        )
        #expect(circular[horizontalEdge] == circular[verticalEdge])
        #expect(circular[verticalEdge] > 240)
    }

    @Test func manualRoundnessAndAngleCreateAFlatTipWhileTiltTakesPriority() {
        let mouseStamp = ImageEditorBrushStrokeSample(
            point: CGPoint(x: 20.5, y: 20.5),
            pressure: 1
        )
        var settings = ImageEditorBrushStrokeSettings(
            diameter: 20,
            hardness: 1,
            opacity: 1,
            flow: 1,
            spacing: 0.25,
            tipRoundness: 0.25
        )
        let horizontal = ImageEditorBrushStrokeKernel.coverage(
            width: 41,
            height: 41,
            stamps: [mouseStamp],
            settings: settings
        )
        let horizontalEdge = 20 * 41 + 28
        let verticalEdge = 28 * 41 + 20
        #expect(horizontal[horizontalEdge] > 240)
        #expect(horizontal[verticalEdge] == 0)
        #expect(ImageEditorBrushStrokeKernel.effectiveTipAspectRatio(
            roundness: 0.25,
            tilt: nil,
            tiltControlsShape: false
        ) == 0.25)
        #expect(ImageEditorBrushStrokeKernel.resolvedTipAngleDegrees(
            manualAngleDegrees: 0,
            tilt: nil,
            tiltControlsShape: false
        ) == 0)

        settings.tipAngleDegrees = 90
        let manualVertical = ImageEditorBrushStrokeKernel.coverage(
            width: 41,
            height: 41,
            stamps: [mouseStamp],
            settings: settings
        )
        #expect(manualVertical[horizontalEdge] == 0)
        #expect(manualVertical[verticalEdge] > 240)

        settings.tipRoundness = 0.5
        settings.tipAngleDegrees = -45
        settings.tiltControlsShape = true
        let vertical = ImageEditorBrushStrokeKernel.coverage(
            width: 41,
            height: 41,
            stamps: [
                ImageEditorBrushStrokeSample(
                    point: mouseStamp.point,
                    pressure: 1,
                    tilt: ImageEditorStylusTilt(x: 0, y: 0.2)
                )
            ],
            settings: settings
        )
        #expect(vertical[horizontalEdge] == 0)
        #expect(vertical[verticalEdge] > 240)
        #expect(ImageEditorBrushStrokeKernel.effectiveTipAspectRatio(
            roundness: 0.5,
            tilt: ImageEditorStylusTilt(x: 0, y: 0.2),
            tiltControlsShape: true
        ) == 0.5)
        #expect(ImageEditorBrushStrokeKernel.resolvedTipAngleDegrees(
            manualAngleDegrees: -45,
            tilt: ImageEditorStylusTilt(x: 0, y: 0.2),
            tiltControlsShape: true
        ) == 90)
        #expect(ImageEditorBrushStrokeKernel.resolvedTipAngleDegrees(
            manualAngleDegrees: 250,
            tilt: nil,
            tiltControlsShape: true
        ) == 180)
    }

    @Test func missingOrPerpendicularTiltPreservesTheCircularMouseFootprint() {
        let settings = ImageEditorBrushStrokeSettings(
            diameter: 16,
            hardness: 0.65,
            opacity: 0.8,
            flow: 0.7,
            spacing: 0.25,
            tiltControlsShape: true
        )
        let mouse = ImageEditorBrushStrokeKernel.coverage(
            width: 32,
            height: 32,
            stamps: [ImageEditorBrushStrokeSample(point: CGPoint(x: 16, y: 16))],
            settings: settings
        )
        let perpendicular = ImageEditorBrushStrokeKernel.coverage(
            width: 32,
            height: 32,
            stamps: [
                ImageEditorBrushStrokeSample(
                    point: CGPoint(x: 16, y: 16),
                    tilt: ImageEditorStylusTilt(x: 0, y: 0)
                )
            ],
            settings: settings
        )

        #expect(mouse == perpendicular)
        #expect(ImageEditorBrushStrokeKernel.tiltTipAspectRatio(
            tilt: nil,
            isEnabled: true
        ) == 1)
    }

    @Test func stylusProximityReportsPenAndEraserWithoutOverridingComponents() {
        #expect(
            ImageEditorStylusProximity.device(from: .pen) == .pen
        )
        #expect(
            ImageEditorStylusProximity.device(from: .eraser) == .eraser
        )
        #expect(
            ImageEditorStylusProximity.device(from: .cursor) == nil
        )

        var proximity = ImageEditorStylusProximity.none
        proximity = ImageEditorStylusProximity.nextState(
            current: proximity,
            device: .pen,
            enteringProximity: true
        )
        #expect(proximity == .pen)
        proximity = ImageEditorStylusProximity.nextState(
            current: proximity,
            device: .eraser,
            enteringProximity: true
        )
        #expect(proximity == .eraser)
        #expect(ImageEditorStylusToolOverride.effectiveTool(
            baseTool: .brush,
            sidebarTab: .tools,
            isEraserInProximity: proximity.isEraser
        ) == .eraser)
        #expect(ImageEditorStylusToolOverride.effectiveTool(
            baseTool: .move,
            sidebarTab: .components,
            isEraserInProximity: proximity.isEraser
        ) == .move)

        // A leaving event for an unrelated pen cannot cancel the eraser; a
        // pen tip entering does replace the old active device.
        #expect(ImageEditorStylusProximity.nextState(
            current: .eraser,
            device: .pen,
            enteringProximity: false
        ) == .eraser)
        #expect(ImageEditorStylusProximity.nextState(
            current: .eraser,
            device: .pen,
            enteringProximity: true
        ) == .pen)
        #expect(ImageEditorStylusProximity.nextState(
            current: .eraser,
            device: .eraser,
            enteringProximity: false
        ) == .none)
        #expect(ImageEditorStylusProximity.nextState(
            current: .pen,
            device: nil,
            enteringProximity: true
        ) == .pen)

        let captureState = ImageEditorCanvasPointerCaptureState()
        captureState.activeTool = .eraser
        #expect(captureState.activeTool == .eraser)
        captureState.reset()
        #expect(captureState.activeTool == nil)
    }

    @Test func viewModelBrushUsesFlowSpacingSelectionAndHistory() throws {
        let size = CGSize(width: 80, height: 30)
        let viewModel = ImageEditorViewModel(
            sourceName: "brush.png",
            image: NSImage.transparent(size: size)
        ) { _ in }
        viewModel.foregroundColor = .systemRed
        viewModel.brushSize = 10
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.brushFlow = 20
        viewModel.brushSpacing = 200
        viewModel.createRectSelection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 30, y: 30))

        viewModel.drawBrush(points: [CGPoint(x: 10, y: 15), CGPoint(x: 70, y: 15)])

        let image = try #require(viewModel.document.selectedLayer?.image)
        let firstStamp = try #require(image.color(at: CGPoint(x: 10, y: 15)))
        let gap = try #require(image.color(at: CGPoint(x: 20, y: 15)))
        let outsideSelection = try #require(image.color(at: CGPoint(x: 50, y: 15)))
        #expect(firstStamp.alphaComponent > 0.15 && firstStamp.alphaComponent < 0.25)
        #expect(gap.alphaComponent < 0.03)
        #expect(outsideSelection.alphaComponent < 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.brush"))

        viewModel.undo()
        let undone = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 15)))
        #expect(undone.alphaComponent < 0.03)
    }

    @Test func pencilPaintsCrispPixelsAsOneUndoableHistoryStep() throws {
        let size = CGSize(width: 24, height: 24)
        let viewModel = ImageEditorViewModel(
            sourceName: "pencil.png",
            image: NSImage.transparent(size: size)
        ) { _ in }
        viewModel.foregroundColor = .systemRed
        viewModel.brushSize = 6
        viewModel.hardness = 0
        viewModel.opacity = 1
        viewModel.brushFlow = 100

        viewModel.drawPencil(samples: [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 10.75, y: 10.75))
        ])

        let image = try #require(viewModel.document.selectedLayer?.image)
        var paintedPixelCount = 0
        for y in 0..<24 {
            for x in 0..<24 {
                let color = try #require(image.color(at: CGPoint(x: x, y: y)))
                #expect(color.alphaComponent < 0.01 || color.alphaComponent > 0.99)
                if color.alphaComponent > 0.99 {
                    paintedPixelCount += 1
                }
            }
        }
        #expect(paintedPixelCount > 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.pencil"))

        viewModel.undo()
        let undone = try #require(
            viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 10, y: 10))
        )
        #expect(undone.alphaComponent < 0.01)
    }

    @Test func pencilAutoErasePolicyRequiresAnOpaqueForegroundMatch() {
        let foreground = NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1)
        #expect(ImageEditorPencilAutoErasePolicy.usesBackgroundColor(
            isEnabled: true,
            sampledColor: foreground,
            foregroundColor: foreground
        ))
        #expect(!ImageEditorPencilAutoErasePolicy.usesBackgroundColor(
            isEnabled: false,
            sampledColor: foreground,
            foregroundColor: foreground
        ))
        #expect(!ImageEditorPencilAutoErasePolicy.usesBackgroundColor(
            isEnabled: true,
            sampledColor: .clear,
            foregroundColor: .black
        ))
        #expect(!ImageEditorPencilAutoErasePolicy.usesBackgroundColor(
            isEnabled: true,
            sampledColor: .systemGreen,
            foregroundColor: foreground
        ))
        #expect(ImageEditorPencilAutoErasePolicy.usesBackgroundTone(
            isEnabled: true,
            sampledValue: 0,
            foregroundValue: 0
        ))
    }

    @Test func pencilAutoEraseLatchesBackgroundOrForegroundFromStrokeStart() throws {
        let size = CGSize(width: 48, height: 20)
        let foreground = NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1)
        let background = NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
        let source = NSImage.rendered(size: size) { rect in
            foreground.setFill()
            CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
            NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1).setFill()
            CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: size)

        let backgroundStroke = ImageEditorViewModel(
            sourceName: "pencil-auto-erase-background.png",
            image: source
        ) { _ in }
        let backgroundLayerIndex = try #require(backgroundStroke.document.selectedLayerIndex)
        backgroundStroke.document.layers[backgroundLayerIndex].image = source
        backgroundStroke.foregroundColor = foreground
        backgroundStroke.backgroundColor = background
        backgroundStroke.pencilAutoEraseEnabled = true
        backgroundStroke.brushSize = 4
        backgroundStroke.opacity = 1
        backgroundStroke.brushFlow = 100
        let historyCount = backgroundStroke.document.history.count
        let undoCount = backgroundStroke.undoStack.count
        backgroundStroke.drawPencil(samples: [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 8, y: 10)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 40, y: 10))
        ])
        let crossedGreenWithBackground = try #require(
            backgroundStroke.document.selectedLayer?.image.color(at: CGPoint(x: 36, y: 10))
        )
        #expect(crossedGreenWithBackground.blueComponent > 0.98)
        #expect(crossedGreenWithBackground.alphaComponent > 0.98)
        #expect(backgroundStroke.document.history.count == historyCount + 1)
        #expect(backgroundStroke.undoStack.count == undoCount + 1)
        #expect(backgroundStroke.document.history.last?.title == L10n.text("imageEditor.history.pencil"))

        let foregroundStroke = ImageEditorViewModel(
            sourceName: "pencil-auto-erase-foreground.png",
            image: source
        ) { _ in }
        let foregroundLayerIndex = try #require(foregroundStroke.document.selectedLayerIndex)
        foregroundStroke.document.layers[foregroundLayerIndex].image = source
        foregroundStroke.foregroundColor = foreground
        foregroundStroke.backgroundColor = background
        foregroundStroke.pencilAutoEraseEnabled = true
        foregroundStroke.brushSize = 4
        foregroundStroke.opacity = 1
        foregroundStroke.brushFlow = 100
        foregroundStroke.drawPencil(samples: [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 40, y: 10)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 8, y: 10))
        ])
        let paintedGreenWithForeground = try #require(
            foregroundStroke.document.selectedLayer?.image.color(at: CGPoint(x: 36, y: 10))
        )
        #expect(paintedGreenWithForeground.redComponent > 0.98)
        #expect(paintedGreenWithForeground.alphaComponent > 0.98)
    }

    @Test func pencilAutoEraseUsesBackgroundToneInQuickMaskAndLayerMask() throws {
        let size = CGSize(width: 32, height: 20)
        let suiteName = "ImageEditorBrushStrokeTests.pencilAutoErase.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let samples = [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 6, y: 10)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 26, y: 10))
        ]

        let quickMaskModel = ImageEditorViewModel(
            sourceName: "pencil-auto-erase-quick-mask.png",
            image: NSImage.transparent(size: size),
            preferencesDefaults: defaults
        ) { _ in }
        quickMaskModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(
                width: 32,
                height: 20,
                alpha: [UInt8](repeating: .min, count: 32 * 20)
            ),
            bounds: CGRect(origin: .zero, size: size)
        )
        quickMaskModel.isQuickMaskMode = true
        quickMaskModel.foregroundColor = .black
        quickMaskModel.backgroundColor = .white
        quickMaskModel.pencilAutoEraseEnabled = true
        quickMaskModel.brushSize = 4
        quickMaskModel.opacity = 1
        quickMaskModel.brushFlow = 100
        quickMaskModel.drawPencil(samples: samples)
        let quickMask = try #require(
            quickMaskModel.document.selection?.rasterizedMask(canvasSize: size)
        )
        #expect(quickMask.alpha[10 * 32 + 24] == .max)

        let layerMaskModel = ImageEditorViewModel(
            sourceName: "pencil-auto-erase-layer-mask.png",
            image: NSImage.transparent(size: size),
            preferencesDefaults: defaults
        ) { _ in }
        let layerIndex = try #require(layerMaskModel.document.selectedLayerIndex)
        layerMaskModel.document.layers[layerIndex].mask = NSImage.transparent(size: size)
        layerMaskModel.isEditingLayerMask = true
        layerMaskModel.pencilAutoEraseEnabled = true
        layerMaskModel.brushSize = 4
        layerMaskModel.opacity = 1
        layerMaskModel.brushFlow = 100
        layerMaskModel.drawPencil(samples: samples)
        let revealedMaskPixel = try #require(
            layerMaskModel.document.selectedLayer?.mask?.color(at: CGPoint(x: 24, y: 10))
        )
        #expect(revealedMaskPixel.alphaComponent > 0.98)
    }

    @Test func viewModelPressureStrokeSupportsSingleStampHistoryAndUndo() throws {
        let size = CGSize(width: 80, height: 40)
        let viewModel = ImageEditorViewModel(
            sourceName: "pressure.png",
            image: NSImage.transparent(size: size)
        ) { _ in }
        viewModel.foregroundColor = .systemBlue
        viewModel.brushSize = 20
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.brushFlow = 100
        viewModel.brushPressureControlsSize = true
        viewModel.brushPressureControlsFlow = true
        viewModel.brushPressureSensitivity = 50

        viewModel.drawBrush(samples: [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 20, y: 20), pressure: 0.25)
        ])

        let center = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20)))
        let outsideSmallTip = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 27, y: 20)))
        #expect(center.alphaComponent > 0.25 && center.alphaComponent < 0.35)
        #expect(outsideSmallTip.alphaComponent < 0.03)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.brush"))

        viewModel.undo()
        let undone = try #require(viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 20, y: 20)))
        #expect(undone.alphaComponent < 0.03)
    }

    @Test func quickMaskEditingUsesTheSameFlowAndSpacingModel() throws {
        let mask = ImageEditorSelectionMask(
            width: 80,
            height: 30,
            alpha: [UInt8](repeating: .max, count: 80 * 30)
        )
        let output = try #require(mask.paintedByQuickMaskStroke(
            points: [CGPoint(x: 10, y: 15), CGPoint(x: 70, y: 15)],
            canvasSize: CGSize(width: 80, height: 30),
            diameter: 10,
            opacity: 1,
            hardness: 1,
            flow: 0.2,
            spacing: 2,
            reveal: false
        ))

        #expect(output.alpha[15 * 80 + 10] >= 202 && output.alpha[15 * 80 + 10] <= 205)
        #expect(output.alpha[15 * 80 + 20] == .max)
    }

    @Test func layerMaskStrokeUsesTheSameFlowAndSpacingModel() throws {
        let size = CGSize(width: 80, height: 30)
        let mask = NSImage.rendered(size: size) { rect in
            NSColor.white.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
        let output = try #require(mask.withMaskStroke(
            points: [CGPoint(x: 10, y: 15), CGPoint(x: 70, y: 15)],
            width: 10,
            opacity: 1,
            hardness: 1,
            flow: 0.2,
            spacing: 2,
            reveal: false
        ))
        let firstStamp = try #require(output.color(at: CGPoint(x: 10, y: 15)))
        let gap = try #require(output.color(at: CGPoint(x: 20, y: 15)))

        #expect(firstStamp.alphaComponent > 0.75 && firstStamp.alphaComponent < 0.85)
        #expect(gap.alphaComponent > 0.97)
    }

    @Test func pencilEdgeStyleStaysAliasedInQuickMaskAndLayerMask() throws {
        let size = CGSize(width: 24, height: 24)
        let samples = [ImageEditorBrushStrokeSample(point: CGPoint(x: 10.75, y: 10.75))]
        let selectionMask = ImageEditorSelectionMask(
            width: 24,
            height: 24,
            alpha: [UInt8](repeating: .max, count: 24 * 24)
        )
        let quickMask = try #require(selectionMask.paintedByQuickMaskStroke(
            samples: samples,
            canvasSize: size,
            diameter: 6,
            opacity: 1,
            hardness: 0,
            flow: 1,
            edgeStyle: .aliased,
            reveal: false
        ))
        #expect(quickMask.alpha.allSatisfy { $0 == 0 || $0 == .max })

        let sourceMask = NSImage.rendered(size: size) { rect in
            NSColor.white.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
        let layerMask = try #require(sourceMask.withMaskStroke(
            samples: samples,
            width: 6,
            opacity: 1,
            hardness: 0,
            flow: 1,
            edgeStyle: .aliased,
            reveal: false
        ))
        for y in 0..<24 {
            for x in 0..<24 {
                let alpha = try #require(layerMask.color(at: CGPoint(x: x, y: y))).alphaComponent
                #expect(alpha < 0.01 || alpha > 0.99)
            }
        }
    }

    @Test func quickMaskAndLayerMaskSharePressureDynamics() throws {
        let samples = [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 15, y: 15), pressure: 0.2),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 55, y: 15), pressure: 1)
        ]
        let selectionMask = ImageEditorSelectionMask(
            width: 70,
            height: 30,
            alpha: [UInt8](repeating: .max, count: 70 * 30)
        )
        let quickMask = try #require(selectionMask.paintedByQuickMaskStroke(
            samples: samples,
            canvasSize: CGSize(width: 70, height: 30),
            diameter: 12,
            opacity: 1,
            hardness: 1,
            flow: 1,
            spacing: 2,
            pressureControlsSize: true,
            pressureControlsOpacity: true,
            pressureControlsFlow: true,
            pressureSensitivity: 0.5,
            minimumDiameter: 0.5,
            minimumOpacity: 0.5,
            minimumFlow: 0.5,
            reveal: false
        ))
        #expect(quickMask.alpha[15 * 70 + 15] > quickMask.alpha[15 * 70 + 55])
        #expect(quickMask.alpha[15 * 70 + 17] < .max)

        let sourceMask = NSImage.rendered(size: CGSize(width: 70, height: 30)) { rect in
            NSColor.white.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: CGSize(width: 70, height: 30))
        let layerMask = try #require(sourceMask.withMaskStroke(
            samples: samples,
            width: 12,
            opacity: 1,
            hardness: 1,
            flow: 1,
            spacing: 2,
            pressureControlsSize: true,
            pressureControlsOpacity: true,
            pressureControlsFlow: true,
            pressureSensitivity: 0.5,
            minimumDiameter: 0.5,
            minimumOpacity: 0.5,
            minimumFlow: 0.5,
            reveal: false
        ))
        let lowPressure = try #require(layerMask.color(at: CGPoint(x: 15, y: 15)))
        let fullPressure = try #require(layerMask.color(at: CGPoint(x: 55, y: 15)))
        let minimumDiameterEdge = try #require(layerMask.color(at: CGPoint(x: 17, y: 15)))
        #expect(lowPressure.alphaComponent > fullPressure.alphaComponent)
        #expect(minimumDiameterEdge.alphaComponent < 1)
    }

    @Test func quickMaskAndLayerMaskShareTiltShapeDynamics() throws {
        let size = CGSize(width: 41, height: 41)
        let samples = [
            ImageEditorBrushStrokeSample(
                point: CGPoint(x: 20.5, y: 20.5),
                pressure: 1,
                tilt: ImageEditorStylusTilt(x: 1, y: 0)
            )
        ]
        let horizontalEdge = 20 * 41 + 28
        let verticalEdge = 28 * 41 + 20
        let selectionMask = ImageEditorSelectionMask(
            width: 41,
            height: 41,
            alpha: [UInt8](repeating: .max, count: 41 * 41)
        )
        let quickMask = try #require(selectionMask.paintedByQuickMaskStroke(
            samples: samples,
            canvasSize: size,
            diameter: 20,
            opacity: 1,
            hardness: 1,
            flow: 1,
            tiltControlsShape: true,
            reveal: false
        ))
        #expect(quickMask.alpha[horizontalEdge] < 15)
        #expect(quickMask.alpha[verticalEdge] == .max)

        let sourceMask = NSImage.rendered(size: size) { rect in
            NSColor.white.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
        let layerMask = try #require(sourceMask.withMaskStroke(
            samples: samples,
            width: 20,
            opacity: 1,
            hardness: 1,
            flow: 1,
            tiltControlsShape: true,
            reveal: false
        ))
        let horizontalColor = try #require(layerMask.color(at: CGPoint(x: 28, y: 20)))
        let verticalColor = try #require(layerMask.color(at: CGPoint(x: 20, y: 28)))
        #expect(horizontalColor.alphaComponent < 0.06)
        #expect(verticalColor.alphaComponent > 0.95)
    }

    @Test func quickMaskAndLayerMaskShareManualBrushRoundnessAndAngle() throws {
        let size = CGSize(width: 41, height: 41)
        let samples = [
            ImageEditorBrushStrokeSample(
                point: CGPoint(x: 20.5, y: 20.5),
                pressure: 1
            )
        ]
        let horizontalEdge = 20 * 41 + 28
        let verticalEdge = 28 * 41 + 20
        let selectionMask = ImageEditorSelectionMask(
            width: 41,
            height: 41,
            alpha: [UInt8](repeating: .max, count: 41 * 41)
        )
        let quickMask = try #require(selectionMask.paintedByQuickMaskStroke(
            samples: samples,
            canvasSize: size,
            diameter: 20,
            opacity: 1,
            hardness: 1,
            flow: 1,
            tipRoundness: 0.25,
            tipAngleDegrees: 90,
            reveal: false
        ))
        #expect(quickMask.alpha[horizontalEdge] == .max)
        #expect(quickMask.alpha[verticalEdge] < 15)

        let sourceMask = NSImage.rendered(size: size) { rect in
            NSColor.white.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
        let layerMask = try #require(sourceMask.withMaskStroke(
            samples: samples,
            width: 20,
            opacity: 1,
            hardness: 1,
            flow: 1,
            tipRoundness: 0.25,
            tipAngleDegrees: 90,
            reveal: false
        ))
        let horizontalColor = try #require(layerMask.color(at: CGPoint(x: 28, y: 20)))
        let verticalColor = try #require(layerMask.color(at: CGPoint(x: 20, y: 28)))
        #expect(horizontalColor.alphaComponent > 0.95)
        #expect(verticalColor.alphaComponent < 0.06)
    }

    @Test func quickMaskAndLayerMaskShareEndpointPreservingSmoothing() throws {
        let size = CGSize(width: 60, height: 40)
        let samples = [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 10, y: 20)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 20, y: 30)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 30, y: 10)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 40, y: 30)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 50, y: 20))
        ]
        let selectionMask = ImageEditorSelectionMask(
            width: 60,
            height: 40,
            alpha: [UInt8](repeating: .max, count: 60 * 40)
        )
        let quickMask = try #require(selectionMask.paintedByQuickMaskStroke(
            samples: samples,
            canvasSize: size,
            diameter: 4,
            opacity: 1,
            hardness: 1,
            flow: 1,
            spacing: 0.25,
            smoothing: 1,
            reveal: false
        ))
        #expect(quickMask.alpha[10 * 60 + 30] == .max)
        #expect(quickMask.alpha[20 * 60 + 30] < 20)

        let sourceMask = NSImage.rendered(size: size) { rect in
            NSColor.white.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
        let layerMask = try #require(sourceMask.withMaskStroke(
            samples: samples,
            width: 4,
            opacity: 1,
            hardness: 1,
            flow: 1,
            spacing: 0.25,
            smoothing: 1,
            reveal: false
        ))
        let formerSpike = try #require(
            layerMask.color(at: CGPoint(x: 30, y: 10))
        )
        let smoothedCenter = try #require(
            layerMask.color(at: CGPoint(x: 30, y: 20))
        )
        #expect(formerSpike.alphaComponent > 0.95)
        #expect(smoothedCenter.alphaComponent < 0.08)
    }

    @Test func brushAndPencilApplyTheSharedPaintingBlendModeToSelectedLayerPixels() throws {
        let size = CGSize(width: 24, height: 24)
        let blue = NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
        let red = NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1)
        let defaultsSuite = "ImageEditorBrushStrokeTests.paintBlendMode.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsSuite))
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let source = NSImage.rendered(size: size) { rect in
            blue.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
        let viewModel = ImageEditorViewModel(
            sourceName: "paint-mode.png",
            image: source,
            preferencesDefaults: defaults
        ) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            source,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.foregroundColor = red
        viewModel.brushSize = 10
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.brushFlow = 100
        viewModel.paintBlendMode = .multiply

        viewModel.drawBrush(points: [CGPoint(x: 12, y: 12)])

        let multiplied = try #require(
            viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 12, y: 12))
        )
        #expect(multiplied.redComponent < 0.03)
        #expect(multiplied.greenComponent < 0.03)
        #expect(multiplied.blueComponent < 0.03)

        viewModel.replaceSelectedLayerImageForTesting(
            source,
            historyTitle: L10n.text("imageEditor.history.pencil")
        )
        viewModel.paintBlendMode = .screen
        viewModel.drawPencil(samples: [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 12, y: 12))
        ])

        let screened = try #require(
            viewModel.document.selectedLayer?.image.color(at: CGPoint(x: 12, y: 12))
        )
        #expect(screened.redComponent > 0.97)
        #expect(screened.greenComponent < 0.03)
        #expect(screened.blueComponent > 0.97)
    }

    @Test func brushStrokeRespectsTransparentPixelLock() throws {
        let size = CGSize(width: 80, height: 30)
        let source = NSImage.rendered(size: size) { _ in
            NSColor.systemRed.setFill()
            CGRect(x: 0, y: 0, width: 30, height: 30).fill()
        } ?? NSImage.transparent(size: size)
        let viewModel = ImageEditorViewModel(sourceName: "locked.png", image: source) { _ in }
        viewModel.replaceSelectedLayerImageForTesting(
            source,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        if let selectedIndex = viewModel.document.selectedLayerIndex {
            viewModel.document.layers[selectedIndex].locksTransparentPixels = true
        }
        viewModel.foregroundColor = .systemGreen
        viewModel.brushSize = 10
        viewModel.hardness = 1
        viewModel.opacity = 1
        viewModel.brushFlow = 100
        viewModel.brushSpacing = 25
        viewModel.paintBlendMode = .normal

        viewModel.drawBrush(points: [CGPoint(x: 10, y: 15), CGPoint(x: 70, y: 15)])

        let image = try #require(viewModel.document.selectedLayer?.image)
        let existingPixel = try #require(image.color(at: CGPoint(x: 10, y: 15)))
        let transparentPixel = try #require(image.color(at: CGPoint(x: 50, y: 15)))
        #expect(existingPixel.alphaComponent > 0.95)
        #expect(existingPixel.greenComponent > existingPixel.redComponent)
        #expect(transparentPixel.alphaComponent < 0.03)
    }
}
