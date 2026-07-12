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
