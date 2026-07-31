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

    @Test func pressureCanControlDiameterAndFlowIndependently() {
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
    }

    @Test func missingPressureFallsBackToFullPressureWithoutChangingMouseStrokes() {
        let settings = ImageEditorBrushStrokeSettings(
            diameter: 12,
            hardness: 0.8,
            opacity: 0.75,
            flow: 0.4,
            spacing: 0.25,
            pressureControlsSize: true,
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

    @Test func manualRoundnessCreatesAFlatMouseTipAndTiltCanOrientIt() {
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

        settings.tipRoundness = 0.5
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

    @Test func stylusEraserProximityTemporarilyOverridesOnlyToolMode() {
        var isEraserInProximity = false
        isEraserInProximity = ImageEditorStylusEraserProximity.nextState(
            current: isEraserInProximity,
            isEraserDevice: true,
            enteringProximity: true
        )
        #expect(isEraserInProximity)
        #expect(ImageEditorStylusToolOverride.effectiveTool(
            baseTool: .brush,
            sidebarTab: .tools,
            isEraserInProximity: isEraserInProximity
        ) == .eraser)
        #expect(ImageEditorStylusToolOverride.effectiveTool(
            baseTool: .move,
            sidebarTab: .components,
            isEraserInProximity: isEraserInProximity
        ) == .move)

        // An unrelated leaving event cannot cancel the eraser; a pen tip
        // entering does replace the old device state.
        #expect(ImageEditorStylusEraserProximity.nextState(
            current: true,
            isEraserDevice: false,
            enteringProximity: false
        ))
        #expect(!ImageEditorStylusEraserProximity.nextState(
            current: true,
            isEraserDevice: false,
            enteringProximity: true
        ))
        #expect(!ImageEditorStylusEraserProximity.nextState(
            current: true,
            isEraserDevice: true,
            enteringProximity: false
        ))

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
            pressureControlsFlow: true,
            pressureSensitivity: 0.5,
            reveal: false
        ))
        #expect(quickMask.alpha[15 * 70 + 15] > quickMask.alpha[15 * 70 + 55])

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
            pressureControlsFlow: true,
            pressureSensitivity: 0.5,
            reveal: false
        ))
        let lowPressure = try #require(layerMask.color(at: CGPoint(x: 15, y: 15)))
        let fullPressure = try #require(layerMask.color(at: CGPoint(x: 55, y: 15)))
        #expect(lowPressure.alphaComponent > fullPressure.alphaComponent)
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

    @Test func quickMaskAndLayerMaskShareManualBrushRoundness() throws {
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
            tipRoundness: 0.25,
            reveal: false
        ))
        let horizontalColor = try #require(layerMask.color(at: CGPoint(x: 28, y: 20)))
        let verticalColor = try #require(layerMask.color(at: CGPoint(x: 20, y: 28)))
        #expect(horizontalColor.alphaComponent < 0.06)
        #expect(verticalColor.alphaComponent > 0.95)
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

        viewModel.drawBrush(points: [CGPoint(x: 10, y: 15), CGPoint(x: 70, y: 15)])

        let image = try #require(viewModel.document.selectedLayer?.image)
        let existingPixel = try #require(image.color(at: CGPoint(x: 10, y: 15)))
        let transparentPixel = try #require(image.color(at: CGPoint(x: 50, y: 15)))
        #expect(existingPixel.alphaComponent > 0.95)
        #expect(existingPixel.greenComponent > existingPixel.redComponent)
        #expect(transparentPixel.alphaComponent < 0.03)
    }
}
