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

    private func red(in image: NSImage) throws -> CGFloat {
        try #require(image.color(at: samplePoint)?.usingColorSpace(.deviceRGB)).redComponent
    }
}
