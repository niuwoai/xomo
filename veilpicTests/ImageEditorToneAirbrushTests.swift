//
//  ImageEditorToneAirbrushTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/19.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorToneAirbrushTests {
    private let canvasSize = CGSize(width: 40, height: 28)
    private let samplePoint = CGPoint(x: 20, y: 14)

    @Test func dwellSamplerUsesAStableCadenceAndInterpolatesMovement() {
        var stroke = ImageEditorToneAirbrushStroke()
        stroke.begin(at: CGPoint(x: 10, y: 10), time: 0)
        stroke.update(to: CGPoint(x: 22, y: 10), time: 0.30)
        let pulses = stroke.finish(at: CGPoint(x: 22, y: 10), time: 0.50)

        #expect(pulses.count == 4)
        #expect(abs(pulses[0].x - 14.8) < 0.001)
        #expect(abs(pulses[1].x - 19.6) < 0.001)
        #expect(abs(pulses[2].x - 22) < 0.001)
        #expect(abs(pulses[3].x - 22) < 0.001)
        #expect(stroke.currentDwellBeganAt == 0.30)
        #expect(ImageEditorToneAirbrushStroke.previewPulseCount(elapsed: 0.50) == 4)
        #expect(
            ImageEditorToneAirbrushStroke.previewOpacity(exposure: 0.5, elapsed: 0.50)
                > ImageEditorToneAirbrushStroke.previewOpacity(exposure: 0.5, elapsed: 0.12)
        )
        #expect(
            ImageEditorToneAirbrushStroke.paintPreviewOpacity(
                opacity: 0.7,
                flow: 0.2,
                elapsed: 0.50
            ) > ImageEditorToneAirbrushStroke.paintPreviewOpacity(
                opacity: 0.7,
                flow: 0.2,
                elapsed: 0.12
            )
        )
    }

    @Test func retouchPressureInterpolatesAcrossAirbrushDwellSamples() throws {
        var stroke = ImageEditorToneAirbrushStroke()
        stroke.begin(at: CGPoint(x: 10, y: 10), pressure: 0.2, time: 0)
        stroke.update(to: CGPoint(x: 22, y: 10), pressure: 0.8, time: 0.30)
        let pulses = stroke.finishSamples(
            at: CGPoint(x: 22, y: 10),
            pressure: 0.8,
            time: 0.50
        )

        #expect(pulses.count == 4)
        #expect(abs(try #require(pulses[0].pressure) - 0.44) < 0.001)
        #expect(abs(try #require(pulses[1].pressure) - 0.68) < 0.001)
        #expect(try #require(pulses[2].pressure) == 0.8)
        #expect(try #require(pulses[3].pressure) == 0.8)
    }

    @Test func airbrushPulsesBuildDodgeAndBurnGradually() throws {
        let source = solidImage(gray: 0.5)
        let pulses = Array(repeating: samplePoint, count: 8)
        let ordinaryDodge = try #require(source.withToneBrush(
            points: [samplePoint],
            width: 16,
            opacity: 0.4,
            hardness: 1,
            burn: false
        ))
        let airbrushDodge = try #require(source.withToneBrush(
            points: [samplePoint],
            width: 16,
            opacity: 0.4,
            hardness: 1,
            burn: false,
            airbrushPulsePoints: pulses
        ))
        let ordinaryBurn = try #require(source.withToneBrush(
            points: [samplePoint],
            width: 16,
            opacity: 0.4,
            hardness: 1,
            burn: true
        ))
        let airbrushBurn = try #require(source.withToneBrush(
            points: [samplePoint],
            width: 16,
            opacity: 0.4,
            hardness: 1,
            burn: true,
            airbrushPulsePoints: pulses
        ))

        #expect(try red(in: airbrushDodge) > red(in: ordinaryDodge) + 0.02)
        #expect(try red(in: airbrushBurn) < red(in: ordinaryBurn) - 0.02)
    }

    @Test func toneBrushStrokeMasksMatchFullFrameAtCenterAndCanvasEdge() throws {
        let source = solidImage(gray: 0.5)
        let scenarios = [
            [
                ImageEditorBrushStrokeSample(point: CGPoint(x: 16, y: 12), pressure: 0.2),
                ImageEditorBrushStrokeSample(point: CGPoint(x: 20, y: 14), pressure: 1)
            ],
            [
                ImageEditorBrushStrokeSample(point: .zero, pressure: 0.2),
                ImageEditorBrushStrokeSample(point: CGPoint(x: 12, y: 8), pressure: 1)
            ]
        ]

        for pressureSamples in scenarios {
            let sampleVariants = [pressureSamples, pressureSamples.map {
                ImageEditorBrushStrokeSample(point: $0.point)
            }]
            for samples in sampleVariants {
                let fullFrame = source.retouchStrokeAlpha(
                    width: Int(canvasSize.width),
                    height: Int(canvasSize.height),
                    samples: samples,
                    diameter: 8,
                    hardness: 0.7,
                    pressureControlsSize: true,
                    pressureSensitivity: 0.5
                )
                let mask = try #require(source.retouchStrokeMask(
                    width: Int(canvasSize.width),
                    height: Int(canvasSize.height),
                    samples: samples,
                    diameter: 8,
                    hardness: 0.7,
                    pressureControlsSize: true,
                    pressureSensitivity: 0.5
                ))
                let maskWidth = mask.width

                #expect(mask.pixels.count < fullFrame.count)
                for y in mask.bounds.minY...mask.bounds.maxY {
                    let fullStart = y * Int(canvasSize.width) + mask.bounds.minX
                    let localStart = (y - mask.bounds.minY) * maskWidth
                    #expect(Array(mask.pixels[localStart..<(localStart + maskWidth)])
                        == Array(fullFrame[fullStart..<(fullStart + maskWidth)]))
                }

                let result = try #require(source.withToneBrush(
                    samples: samples,
                    width: 8,
                    opacity: 0.8,
                    hardness: 0.7,
                    burn: false,
                    pressureControlsSize: true,
                    pressureSensitivity: 0.5
                ))
                let affectedPoint = try #require(samples.last?.point)
                #expect(try red(in: result, at: affectedPoint) > 0.5)
                #expect(abs(try red(in: result, at: CGPoint(x: 39, y: 27)) - 0.5) < 0.01)
            }
        }
    }

    @Test func toneBrushAndSpongeROIBrushesRemainSingleUndoRedoTransactions() throws {
        let toneViewModel = ImageEditorViewModel(
            sourceName: "tone-roi-undo.png",
            image: solidImage(gray: 0.5),
            onApply: { _ in }
        )
        toneViewModel.replaceSelectedLayerImageForTesting(
            solidImage(gray: 0.5),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        toneViewModel.brushSize = 16
        toneViewModel.hardness = 0.7
        toneViewModel.opacity = 0.8
        let toneBaseline = try #require(toneViewModel.document.selectedLayer?.image.qingtuPNGData())
        let initialUndoCount = toneViewModel.undoStack.count

        toneViewModel.toneBrush(points: [samplePoint], burn: false)
        let dodgedPixels = try #require(toneViewModel.document.selectedLayer?.image.qingtuPNGData())
        #expect(dodgedPixels != toneBaseline)
        #expect(toneViewModel.undoStack.count == initialUndoCount + 1)
        toneViewModel.undo()
        #expect(toneViewModel.document.selectedLayer?.image.qingtuPNGData() == toneBaseline)
        toneViewModel.redo()
        #expect(toneViewModel.document.selectedLayer?.image.qingtuPNGData() == dodgedPixels)

        let spongeViewModel = ImageEditorViewModel(
            sourceName: "sponge-roi-undo.png",
            image: coloredImage(),
            onApply: { _ in }
        )
        spongeViewModel.replaceSelectedLayerImageForTesting(
            coloredImage(),
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        spongeViewModel.brushSize = 16
        spongeViewModel.hardness = 0.7
        spongeViewModel.opacity = 0.8
        spongeViewModel.spongeMode = .desaturate
        let spongeBaseline = try #require(spongeViewModel.document.selectedLayer?.image.qingtuPNGData())
        let spongeUndoCount = spongeViewModel.undoStack.count
        spongeViewModel.spongeBrush(points: [samplePoint])
        let spongedPixels = try #require(spongeViewModel.document.selectedLayer?.image.qingtuPNGData())
        #expect(spongedPixels != spongeBaseline)
        #expect(spongeViewModel.undoStack.count == spongeUndoCount + 1)
        spongeViewModel.undo()
        #expect(spongeViewModel.document.selectedLayer?.image.qingtuPNGData() == spongeBaseline)
        spongeViewModel.redo()
        #expect(spongeViewModel.document.selectedLayer?.image.qingtuPNGData() == spongedPixels)
    }

    @Test func blurAndSharpenROIMixesMatchFullFrameAppKitReference() throws {
        let opaqueSource = NSImage.rendered(size: canvasSize) { rect in
            NSColor(deviceRed: 0.8, green: 0.12, blue: 0.08, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: rect.width / 2, height: rect.height).fill()
            NSColor(deviceRed: 0.08, green: 0.18, blue: 0.82, alpha: 1).setFill()
            NSRect(x: rect.width / 2, y: 0, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: canvasSize)
        let translucentSource = NSImage.rendered(size: canvasSize) { rect in
            NSColor.clear.setFill()
            rect.fill()
            NSColor(deviceRed: 0.8, green: 0.12, blue: 0.08, alpha: 0.4).setFill()
            NSRect(x: 0, y: 0, width: rect.width / 2, height: rect.height).fill()
            NSColor(deviceRed: 0.08, green: 0.18, blue: 0.82, alpha: 0.75).setFill()
            NSRect(x: rect.width / 2, y: 0, width: rect.width / 2, height: rect.height).fill()
        } ?? NSImage.transparent(size: canvasSize)
        let samples = [
            ImageEditorBrushStrokeSample(point: .zero),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 16, y: 12))
        ]
        try assertBlurAndSharpenMatchLegacy(for: opaqueSource, samples: samples)
        try assertBlurAndSharpenMatchLegacy(for: translucentSource, samples: samples)
    }

    @Test func smudgeStrokeROIMixesMatchSequentialFullFrameReference() throws {
        let samples = [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 6, y: 14)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 20, y: 14)),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 34, y: 14))
        ]
        for alpha in [CGFloat(1), 0.6] {
            let source = coloredPartitionImage(alpha: alpha)
            let smudged = try #require(source.withSmudgeBrush(
                samples: samples,
                width: 12,
                opacity: 0.8,
                hardness: 0.7,
                pressureControlsSize: false,
                pressureSensitivity: 0.5
            ))
            let legacySmudged = try legacySmudgeBrush(
                source,
                samples: samples,
                width: 12,
                opacity: 0.8,
                hardness: 0.7
            )
            #expect(maximumPixelDifference(smudged, legacySmudged) <= 4.0 / 255)
        }
    }

    @Test func zeroPressureSmudgeDoesNotMovePixelsOrSeedFingerPaint() throws {
        let source = coloredPartitionImage(alpha: 1)
        let samples = [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 6.5, y: 13.5), pressure: 0),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 19.5, y: 13.5), pressure: 0),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 33.5, y: 13.5), pressure: 0)
        ]

        let smudged = try #require(source.withSmudgeBrush(
            samples: samples,
            width: 12,
            opacity: 0.8,
            hardness: 0.7,
            pressureControlsSize: true,
            pressureSensitivity: 0.5
        ))
        let fingerPainted = try #require(source.withSmudgeBrush(
            samples: samples,
            width: 12,
            opacity: 0.8,
            hardness: 0.7,
            pressureControlsSize: true,
            pressureSensitivity: 0.5,
            fingerPaintingColor: .red
        ))

        #expect(try #require(smudged.qingtuPNGData()) == source.qingtuPNGData())
        #expect(try #require(fingerPainted.qingtuPNGData()) == source.qingtuPNGData())
    }

    @Test func smudgeAndFingerPaintResumeAfterPressureLeavesZero() throws {
        let source = coloredPartitionImage(alpha: 1)
        let samples = [
            ImageEditorBrushStrokeSample(point: CGPoint(x: 6.5, y: 13.5), pressure: 0),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 12.5, y: 13.5), pressure: 0),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 19.5, y: 13.5), pressure: 1),
            ImageEditorBrushStrokeSample(point: CGPoint(x: 33.5, y: 13.5), pressure: 1)
        ]

        let smudged = try #require(source.withSmudgeBrush(
            samples: samples,
            width: 12,
            opacity: 0.8,
            hardness: 0.7,
            pressureControlsSize: true,
            pressureSensitivity: 0.5
        ))
        let fingerPainted = try #require(source.withSmudgeBrush(
            samples: samples,
            width: 12,
            opacity: 0.8,
            hardness: 0.7,
            pressureControlsSize: true,
            pressureSensitivity: 0.5,
            fingerPaintingColor: .red
        ))

        #expect(try #require(smudged.qingtuPNGData()) != source.qingtuPNGData())
        #expect(try #require(fingerPainted.qingtuPNGData()) != source.qingtuPNGData())
    }

    private func assertBlurAndSharpenMatchLegacy(
        for source: NSImage,
        samples: [ImageEditorBrushStrokeSample]
    ) throws {
        let width: CGFloat = 12
        let opacity: CGFloat = 0.65
        let hardness: CGFloat = 0.6

        let blurredSource = try #require(source.blurred(radius: 3.5))
        let blurred = try #require(source.withBlurBrush(
            samples: samples,
            width: width,
            opacity: opacity,
            hardness: hardness,
            radius: 3.5,
            pressureControlsSize: false,
            pressureSensitivity: 0.5
        ))
        let legacyBlur = try legacyMixedBrushSource(
            source,
            brushSource: blurredSource,
            samples: samples,
            width: width,
            opacity: opacity,
            hardness: hardness
        )
        #expect(maximumPixelDifference(blurred, legacyBlur) <= 4.0 / 255)

        let intensity = 0.6
        let firstSharpenPass = try #require(source.filtered(
            kind: .sharpen,
            intensity: Double(intensity)
        ))
        let sharpenedSource = firstSharpenPass.filtered(
            kind: .sharpen,
            intensity: Double(intensity)
        ) ?? firstSharpenPass
        let sharpened = try #require(source.withSharpenBrush(
            samples: samples,
            width: width,
            opacity: opacity,
            hardness: hardness,
            intensity: intensity,
            pressureControlsSize: false,
            pressureSensitivity: 0.5
        ))
        let legacySharpen = try legacyMixedBrushSource(
            source,
            brushSource: sharpenedSource,
            samples: samples,
            width: width,
            opacity: opacity,
            hardness: hardness
        )
        #expect(maximumPixelDifference(sharpened, legacySharpen) <= 4.0 / 255)
    }

    @Test func airbrushStrokeCommitsAsOneHistoryStepAndDefaultsOff() throws {
        let source = solidImage(gray: 0.5)
        let viewModel = ImageEditorViewModel(
            sourceName: "Airbrush",
            image: source,
            onApply: { _ in }
        )
        #expect(!viewModel.toneBrushAirbrushEnabled)
        viewModel.replaceSelectedLayerImageForTesting(
            source,
            historyTitle: L10n.text("imageEditor.history.brush")
        )
        viewModel.toneBrushAirbrushEnabled = true
        viewModel.brushSize = 16
        viewModel.opacity = 0.4
        let historyCount = viewModel.document.history.count

        viewModel.toneBrush(
            points: [samplePoint],
            burn: false,
            airbrushPulsePoints: Array(repeating: samplePoint, count: 8)
        )

        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.dodge"))
        let selectedLayer = try #require(viewModel.document.selectedLayer)
        #expect(try red(in: selectedLayer.image) > 0.5)
    }

    private func solidImage(gray: CGFloat) -> NSImage {
        NSImage.rendered(size: canvasSize) { rect in
            NSColor(deviceWhite: gray, alpha: 1).setFill()
            rect.fill()
        } ?? NSImage.transparent(size: canvasSize)
    }

    private func coloredImage() -> NSImage {
        NSImage.rendered(size: canvasSize) { rect in
            NSColor(deviceRed: 0.76, green: 0.23, blue: 0.16, alpha: 1).setFill()
            rect.fill()
        } ?? NSImage.transparent(size: canvasSize)
    }

    private func coloredPartitionImage(alpha: CGFloat) -> NSImage {
        NSImage.rendered(size: canvasSize) { rect in
            NSColor(deviceRed: 0.9, green: 0.1, blue: 0.08, alpha: alpha).setFill()
            NSRect(x: 0, y: 0, width: rect.width / 3, height: rect.height).fill()
            NSColor(deviceRed: 0.08, green: 0.85, blue: 0.12, alpha: alpha).setFill()
            NSRect(x: rect.width / 3, y: 0, width: rect.width / 3, height: rect.height).fill()
            NSColor(deviceRed: 0.08, green: 0.16, blue: 0.9, alpha: alpha).setFill()
            NSRect(x: rect.width * 2 / 3, y: 0, width: rect.width / 3, height: rect.height).fill()
        } ?? NSImage.transparent(size: canvasSize)
    }

    private func legacyMixedBrushSource(
        _ source: NSImage,
        brushSource: NSImage,
        samples: [ImageEditorBrushStrokeSample],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat
    ) throws -> NSImage {
        let pixelWidth = Int(source.size.width.rounded())
        let pixelHeight = Int(source.size.height.rounded())
        let maskAlpha = source.retouchStrokeAlpha(
            width: pixelWidth,
            height: pixelHeight,
            samples: samples,
            diameter: width,
            hardness: hardness,
            pressureControlsSize: false,
            pressureSensitivity: 0.5
        )
        let mask = try #require(NSImage.alphaMaskImage(
            width: pixelWidth,
            height: pixelHeight,
            alpha: maskAlpha
        ))
        let clippedBrush = try #require(NSImage.rendered(size: source.size) { _ in
            brushSource.draw(
                in: CGRect(origin: .zero, size: source.size),
                from: CGRect(origin: .zero, size: brushSource.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: source.size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        })
        return try #require(NSImage.rendered(size: source.size) { _ in
            source.draw(
                in: CGRect(origin: .zero, size: source.size),
                from: CGRect(origin: .zero, size: source.size),
                operation: .copy,
                fraction: 1
            )
            clippedBrush.draw(
                in: CGRect(origin: .zero, size: source.size),
                from: CGRect(origin: .zero, size: clippedBrush.size),
                operation: .sourceOver,
                fraction: opacity
            )
        })
    }

    private func legacySmudgeBrush(
        _ source: NSImage,
        samples: [ImageEditorBrushStrokeSample],
        width: CGFloat,
        opacity: CGFloat,
        hardness: CGFloat
    ) throws -> NSImage {
        guard samples.count > 1 else { return source }
        let strokeOpacity = max(0, min(1, opacity)) * 0.86
        var workingSource = source
        var output = source
        for segmentIndex in 1..<samples.count {
            let previous = samples[segmentIndex - 1].point
            let current = samples[segmentIndex].point
            let delta = CGSize(width: current.x - previous.x, height: current.y - previous.y)
            let sourceSnapshot = workingSource
            let mask = try #require(ImageEditorHealingBrushKernel.strokeMaskImage(
                size: source.size,
                points: [previous, current],
                diameter: width,
                hardness: hardness
            ))
            let shiftedSource = try legacyShiftedSmudgeSource(
                sourceSnapshot,
                delta: delta
            )
            let clippedSource = try legacyClippedSmudgeSource(
                shiftedSource,
                mask: mask
            )
            let nextOutput = try legacySmudgeOutput(
                output,
                clippedSource: clippedSource,
                opacity: strokeOpacity
            )
            workingSource = nextOutput
            output = nextOutput
        }
        return output
    }

    private func legacyShiftedSmudgeSource(
        _ source: NSImage,
        delta: CGSize
    ) throws -> NSImage {
        try #require(NSImage.rendered(size: source.size) { _ in
            source.draw(
                in: CGRect(x: delta.width, y: -delta.height, width: source.size.width, height: source.size.height),
                from: CGRect(origin: .zero, size: source.size),
                operation: .copy,
                fraction: 1
            )
        })
    }

    private func legacyClippedSmudgeSource(
        _ shiftedSource: NSImage,
        mask: NSImage
    ) throws -> NSImage {
        try #require(NSImage.rendered(size: shiftedSource.size) { rect in
            shiftedSource.draw(
                in: rect,
                from: CGRect(origin: .zero, size: shiftedSource.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: rect,
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        })
    }

    private func legacySmudgeOutput(
        _ output: NSImage,
        clippedSource: NSImage,
        opacity: CGFloat
    ) throws -> NSImage {
        try #require(NSImage.rendered(size: output.size) { rect in
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
                fraction: opacity
            )
        })
    }

    private func maximumPixelDifference(_ lhs: NSImage, _ rhs: NSImage) -> CGFloat {
        guard let leftData = lhs.qingtuPNGData(),
              let rightData = rhs.qingtuPNGData(),
              let leftBitmap = NSBitmapImageRep(data: leftData),
              let rightBitmap = NSBitmapImageRep(data: rightData)
        else { return .infinity }
        var maximumDifference: CGFloat = 0
        for y in 0..<Int(canvasSize.height) {
            for x in 0..<Int(canvasSize.width) {
                guard let left = leftBitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      let right = rightBitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
                else { return .infinity }
                let pixelDifference = [
                    abs(left.redComponent - right.redComponent),
                    abs(left.greenComponent - right.greenComponent),
                    abs(left.blueComponent - right.blueComponent),
                    abs(left.alphaComponent - right.alphaComponent)
                ].max() ?? 0
                maximumDifference = max(maximumDifference, pixelDifference)
            }
        }
        return maximumDifference
    }

    private func red(in image: NSImage) throws -> CGFloat {
        try #require(image.color(at: samplePoint)?.usingColorSpace(.deviceRGB)).redComponent
    }

    private func red(in image: NSImage, at point: CGPoint) throws -> CGFloat {
        try #require(image.color(at: point)?.usingColorSpace(.deviceRGB)).redComponent
    }
}
