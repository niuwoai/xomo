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

    private func red(in image: NSImage) throws -> CGFloat {
        try #require(image.color(at: samplePoint)?.usingColorSpace(.deviceRGB)).redComponent
    }

    private func red(in image: NSImage, at point: CGPoint) throws -> CGFloat {
        try #require(image.color(at: point)?.usingColorSpace(.deviceRGB)).redComponent
    }
}
