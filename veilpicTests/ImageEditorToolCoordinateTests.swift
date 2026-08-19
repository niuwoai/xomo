//
//  ImageEditorToolCoordinateTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorToolCoordinateTests {
    private let canvasSize = NSSize(width: 96, height: 72)

    @Test func everyToolIsIncludedInTheCoordinateAudit() {
        let canvasGeometryTools: Set<ImageEditorTool> = [
            .move, .marquee, .lasso, .crop, .text, .rectangle, .ellipse, .pen,
            .pathSelection, .directSelection, .hand, .zoom,
        ]
        let rasterStrokeTools: Set<ImageEditorTool> = [
            .quickSelection, .brush, .pencil, .historyBrush, .eraser, .cloneStamp, .dodge, .burn, .sponge,
            .blur, .sharpen, .smudge, .healingBrush,
        ]
        let rasterPointAndRegionTools: Set<ImageEditorTool> = [
            .magicWand, .patchTool, .redEye, .paintBucket, .gradient, .eyedropper, .colorSampler,
        ]

        #expect(canvasGeometryTools.union(rasterStrokeTools).union(rasterPointAndRegionTools) == Set(ImageEditorTool.allCases))
    }

    @Test func brushAndEraserUseTopLeftCanvasCoordinates() throws {
        let viewModel = editableViewModel(image: topLeftImage(background: .clear))
        viewModel.foregroundColor = .systemRed
        viewModel.brushSize = 6
        viewModel.opacity = 1

        viewModel.drawBrush(points: [CGPoint(x: 10, y: 8), CGPoint(x: 78, y: 50)])

        let paintedStart = try color(viewModel, at: CGPoint(x: 12, y: 9))
        let paintedEnd = try color(viewModel, at: CGPoint(x: 76, y: 49))
        let mirroredStart = try color(viewModel, at: CGPoint(x: 12, y: 63))
        let mirroredEnd = try color(viewModel, at: CGPoint(x: 76, y: 23))
        #expect(paintedStart.alphaComponent > 0.7)
        #expect(paintedEnd.alphaComponent > 0.7)
        #expect(mirroredStart.alphaComponent < 0.1)
        #expect(mirroredEnd.alphaComponent < 0.1)

        viewModel.drawBrush(
            points: [CGPoint(x: 10, y: 8), CGPoint(x: 28, y: 19)],
            erase: true
        )
        let erased = try color(viewModel, at: CGPoint(x: 12, y: 9))
        let retained = try color(viewModel, at: CGPoint(x: 76, y: 49))
        #expect(erased.alphaComponent < 0.1)
        #expect(retained.alphaComponent > 0.7)
    }

    @Test func toneAndSpongeBrushesUseTopLeftCanvasCoordinates() throws {
        let gray = NSColor(deviceWhite: 0.45, alpha: 1)
        let dodge = editableViewModel(image: topLeftImage(background: gray))
        dodge.brushSize = 10
        dodge.opacity = 1
        dodge.toneBrush(points: [CGPoint(x: 12, y: 8), CGPoint(x: 36, y: 18)], burn: false)
        #expect(try color(dodge, at: CGPoint(x: 16, y: 10)).redComponent > 0.6)
        #expect(abs(try color(dodge, at: CGPoint(x: 16, y: 62)).redComponent - 0.45) < 0.08)

        let burn = editableViewModel(image: topLeftImage(background: gray))
        burn.brushSize = 10
        burn.opacity = 1
        burn.toneBrush(points: [CGPoint(x: 12, y: 8), CGPoint(x: 36, y: 18)], burn: true)
        #expect(try color(burn, at: CGPoint(x: 16, y: 10)).redComponent < 0.3)
        #expect(abs(try color(burn, at: CGPoint(x: 16, y: 62)).redComponent - 0.45) < 0.08)

        let muted = NSColor(deviceRed: 0.58, green: 0.50, blue: 0.42, alpha: 1)
        let sponge = editableViewModel(image: topLeftImage(background: muted))
        sponge.brushSize = 10
        sponge.opacity = 1
        sponge.spongeBrush(points: [CGPoint(x: 12, y: 8), CGPoint(x: 36, y: 18)])
        let saturated = try color(sponge, at: CGPoint(x: 16, y: 10))
        let untouched = try color(sponge, at: CGPoint(x: 16, y: 62))
        #expect((saturated.redComponent - saturated.blueComponent) > (untouched.redComponent - untouched.blueComponent) + 0.05)
    }

    @Test func cloneStampUsesTopLeftSourceAndDestinationCoordinates() throws {
        let image = topLeftImage(background: .systemBlue, fills: [
            (CGRect(x: 8, y: 6, width: 18, height: 14), .systemRed),
        ])
        let viewModel = editableViewModel(image: image)
        viewModel.brushSize = 10
        viewModel.opacity = 1
        viewModel.setCloneSource(at: CGPoint(x: 14, y: 10))
        viewModel.cloneStamp(points: [CGPoint(x: 66, y: 44), CGPoint(x: 78, y: 52)])

        let destination = try color(viewModel, at: CGPoint(x: 68, y: 45))
        let verticalMirror = try color(viewModel, at: CGPoint(x: 68, y: 27))
        #expect(destination.redComponent > destination.blueComponent + 0.25)
        #expect(verticalMirror.blueComponent > verticalMirror.redComponent + 0.25)
    }

    @Test func pixelPointToolsUseTopLeftRows() throws {
        let image = topLeftImage(background: .systemBlue, fills: [
            (CGRect(x: 6, y: 5, width: 28, height: 18), .systemRed),
            (CGRect(x: 58, y: 48, width: 28, height: 16), .systemGreen),
        ])

        let eyedropper = viewModel(image: image)
        eyedropper.sampleColor(at: CGPoint(x: 12, y: 10))
        let sampled = try #require(eyedropper.foregroundColor.usingColorSpace(.deviceRGB))
        #expect(sampled.redComponent > sampled.blueComponent + 0.4)
        eyedropper.addColorSampler(at: CGPoint(x: 70, y: 54))
        let retainedSample = try #require(eyedropper.colorSamplerPoints.last?.color.usingColorSpace(.deviceRGB))
        #expect(retainedSample.greenComponent > retainedSample.redComponent + 0.2)

        let bucket = editableViewModel(image: image)
        bucket.foregroundColor = .systemYellow
        bucket.opacity = 1
        bucket.tolerance = 0.02
        bucket.paintBucketFill(at: CGPoint(x: 12, y: 10))
        let filledTop = try color(bucket, at: CGPoint(x: 12, y: 10))
        let untouchedBottom = try color(bucket, at: CGPoint(x: 70, y: 54))
        #expect(filledTop.redComponent > 0.7 && filledTop.greenComponent > 0.6)
        #expect(untouchedBottom.greenComponent > untouchedBottom.redComponent + 0.2)

        let wand = viewModel(image: image)
        let selection = try #require(wand.magicSelection(at: CGPoint(x: 12, y: 10)))
        #expect(selection.contains(CGPoint(x: 12, y: 10)))
        #expect(!selection.contains(CGPoint(x: 12, y: 62)))
        #expect(!selection.contains(CGPoint(x: 70, y: 54)))
    }

    @Test func redEyeAndGradientUseTopLeftDirection() throws {
        let redEyeImage = topLeftImage(background: NSColor(deviceWhite: 0.35, alpha: 1), fills: [
            (CGRect(x: 12, y: 8, width: 12, height: 12), NSColor(deviceRed: 1, green: 0.02, blue: 0.02, alpha: 1)),
        ])
        let redEye = editableViewModel(image: redEyeImage)
        redEye.brushSize = 12
        redEye.opacity = 1
        let before = try color(redEye, at: CGPoint(x: 18, y: 14)).redComponent
        redEye.reduceRedEye(at: CGPoint(x: 18, y: 14))
        #expect(try color(redEye, at: CGPoint(x: 18, y: 14)).redComponent < before - 0.15)
        #expect(abs(try color(redEye, at: CGPoint(x: 18, y: 58)).redComponent - 0.35) < 0.08)

        let gradient = editableViewModel(image: topLeftImage(background: .clear))
        gradient.foregroundColor = .systemRed
        gradient.backgroundColor = .systemBlue
        gradient.opacity = 1
        gradient.drawGradient(from: CGPoint(x: 48, y: 0), to: CGPoint(x: 48, y: 72))
        let top = try color(gradient, at: CGPoint(x: 48, y: 6))
        let bottom = try color(gradient, at: CGPoint(x: 48, y: 66))
        #expect(top.redComponent > top.blueComponent + 0.4)
        #expect(bottom.blueComponent > bottom.redComponent + 0.4)
    }

    @Test func blurSharpenSmudgeAndHealingStayOnTheTopStroke() throws {
        let edgeImage = topLeftImage(background: .systemBlue, fills: [
            (CGRect(x: 0, y: 0, width: 48, height: 30), .systemRed),
        ])

        let blur = editableViewModel(image: edgeImage)
        blur.brushSize = 16
        blur.opacity = 1
        blur.blurBrush(points: [CGPoint(x: 48, y: 6), CGPoint(x: 48, y: 24)])
        let blurredTop = try color(blur, at: CGPoint(x: 48, y: 15))
        let untouchedMirror = try color(blur, at: CGPoint(x: 48, y: 57))
        #expect(blurredTop.redComponent > 0.1 && blurredTop.blueComponent > 0.1)
        #expect(untouchedMirror.blueComponent > untouchedMirror.redComponent + 0.5)

        let softened = try #require(edgeImage.blurred(radius: 4))
        let sharpen = editableViewModel(image: softened)
        sharpen.brushSize = 18
        sharpen.opacity = 1
        let beforeTopContrast = try color(sharpen, at: CGPoint(x: 53, y: 15)).blueComponent
            - color(sharpen, at: CGPoint(x: 43, y: 15)).blueComponent
        let beforeMirror = try color(sharpen, at: CGPoint(x: 48, y: 57))
        sharpen.sharpenBrush(points: [CGPoint(x: 48, y: 6), CGPoint(x: 48, y: 24)])
        let afterTopContrast = try color(sharpen, at: CGPoint(x: 53, y: 15)).blueComponent
            - color(sharpen, at: CGPoint(x: 43, y: 15)).blueComponent
        let afterMirror = try color(sharpen, at: CGPoint(x: 48, y: 57))
        #expect(afterTopContrast > beforeTopContrast + 0.02)
        #expect(abs(afterMirror.blueComponent - beforeMirror.blueComponent) < 0.03)

        let smudge = editableViewModel(image: edgeImage)
        smudge.brushSize = 16
        smudge.opacity = 1
        smudge.smudgeBrush(points: [
            CGPoint(x: 40, y: 15),
            CGPoint(x: 48, y: 15),
            CGPoint(x: 56, y: 15),
            CGPoint(x: 64, y: 15),
        ])
        let draggedTop = try color(smudge, at: CGPoint(x: 58, y: 15))
        let smudgeMirror = try color(smudge, at: CGPoint(x: 58, y: 57))
        #expect(draggedTop.redComponent > draggedTop.blueComponent)
        #expect(smudgeMirror.blueComponent > smudgeMirror.redComponent + 0.5)

        let blemish = topLeftImage(background: NSColor(deviceWhite: 0.45, alpha: 1), fills: [
            (CGRect(x: 38, y: 8, width: 12, height: 12), .systemRed),
        ])
        let healing = editableViewModel(image: blemish)
        healing.brushSize = 14
        healing.opacity = 1
        healing.setHealingSource(at: CGPoint(x: 16, y: 14))
        healing.healingBrush(points: [CGPoint(x: 38, y: 14), CGPoint(x: 50, y: 14)])
        let healedTop = try color(healing, at: CGPoint(x: 44, y: 14))
        let healingMirror = try color(healing, at: CGPoint(x: 44, y: 58))
        #expect(healedTop.redComponent < 0.7)
        #expect(abs(healingMirror.redComponent - 0.45) < 0.08)
    }

    @Test func quickSelectionAndPatchUseTopLeftRegions() throws {
        let regionImage = topLeftImage(background: .systemBlue, fills: [
            (CGRect(x: 8, y: 6, width: 28, height: 18), .systemRed),
            (CGRect(x: 8, y: 42, width: 28, height: 18), .systemGreen),
        ])

        let quick = viewModel(image: regionImage)
        quick.tolerance = 0.03
        quick.brushSize = 6
        quick.createQuickSelection(points: [CGPoint(x: 14, y: 12)])
        let quickSelection = try #require(quick.document.selection)
        #expect(quickSelection.contains(CGPoint(x: 14, y: 12)))
        #expect(!quickSelection.contains(CGPoint(x: 14, y: 60)))

        let patch = editableViewModel(image: regionImage)
        patch.opacity = 1
        patch.createRectSelection(from: CGPoint(x: 8, y: 6), to: CGPoint(x: 36, y: 24))
        patch.patchSelection(from: CGPoint(x: 14, y: 12), to: CGPoint(x: 14, y: 48))
        let patchedTop = try color(patch, at: CGPoint(x: 14, y: 12))
        let sourceBottom = try color(patch, at: CGPoint(x: 14, y: 48))
        #expect(patchedTop.greenComponent > patchedTop.redComponent + 0.2)
        #expect(sourceBottom.greenComponent > sourceBottom.redComponent + 0.2)
    }

    @Test func moveCropTextAndPenKeepTopLeftCanvasGeometry() throws {
        let image = topLeftImage(background: .clear, fills: [
            (CGRect(x: 10, y: 8, width: 20, height: 14), .systemRed),
        ])
        let move = editableViewModel(image: image)
        move.beginMovingSelectedLayer()
        move.moveSelectedLayer(by: CGSize(width: 12, height: 9))
        move.finishMovingSelectedLayer()
        #expect(try color(move, at: CGPoint(x: 24, y: 19)).redComponent > 0.8)
        #expect(try color(move, at: CGPoint(x: 24, y: 53)).alphaComponent < 0.1)

        let crop = editableViewModel(image: image)
        crop.crop(to: CGRect(x: 0, y: 0, width: 48, height: 32))
        #expect(crop.document.canvasSize == CGSize(width: 48, height: 32))
        #expect(try color(crop, at: CGPoint(x: 18, y: 14)).redComponent > 0.8)
        #expect(crop.document.selection?.bounds == CGRect(origin: .zero, size: CGSize(width: 48, height: 32)))

        let text = viewModel(image: topLeftImage(background: .clear))
        text.textValue = "Top"
        text.textSize = 18
        text.foregroundColor = .systemRed
        text.addText(at: CGPoint(x: 12, y: 7))
        let textLayer = try #require(text.document.selectedLayer)
        #expect(textLayer.frame.minX == 12)
        #expect(textLayer.frame.minY == 7)
        #expect(try maximumAlpha(text, in: CGRect(x: 12, y: 7, width: 45, height: 26)) > 0.05)
        #expect(try maximumAlpha(text, in: CGRect(x: 12, y: 39, width: 45, height: 26)) < 0.05)

        let pen = viewModel(image: topLeftImage(background: .clear))
        pen.foregroundColor = .systemRed
        pen.brushSize = 5
        pen.addPenPoint(CGPoint(x: 8, y: 8))
        pen.addPenPoint(CGPoint(x: 44, y: 18))
        pen.addPenPoint(CGPoint(x: 28, y: 34))
        pen.finishPenPath(closed: true)
        #expect(try color(pen, at: CGPoint(x: 27, y: 19)).alphaComponent > 0.05)
        #expect(try color(pen, at: CGPoint(x: 27, y: 53)).alphaComponent < 0.05)
    }

    @Test func handAndZoomPreserveThePointerAnchorDirection() {
        let viewModel = self.viewModel(image: topLeftImage(background: .clear))
        viewModel.canvasViewportSize = CGSize(width: 600, height: 400)
        viewModel.canvasOffset = CGSize(width: 18, height: 12)
        let pointer = CGPoint(x: 140, y: 90)
        let oldZoom = viewModel.zoom
        let oldOffset = viewModel.canvasOffset
        let oldImagePoint = imagePoint(
            under: pointer,
            zoom: oldZoom,
            offset: oldOffset,
            viewportSize: viewModel.canvasViewportSize
        )

        viewModel.magnifyCanvas(1.5, at: pointer, viewportSize: viewModel.canvasViewportSize)

        #expect(viewModel.zoom > oldZoom)
        #expect(viewModel.canvasOffset.width != oldOffset.width)
        #expect(viewModel.canvasOffset.height != oldOffset.height)
        let newImagePoint = imagePoint(
            under: pointer,
            zoom: viewModel.zoom,
            offset: viewModel.canvasOffset,
            viewportSize: viewModel.canvasViewportSize
        )
        #expect(abs(newImagePoint.x - oldImagePoint.x) < 0.001)
        #expect(abs(newImagePoint.y - oldImagePoint.y) < 0.001)
        viewModel.endCanvasMagnify()
    }

    @Test func shapeLayersStayAtTheirTopLeftCanvasFrame() throws {
        let viewModel = self.viewModel(image: topLeftImage(background: .clear))
        viewModel.foregroundColor = .systemRed
        viewModel.drawShape(from: CGPoint(x: 8, y: 6), to: CGPoint(x: 34, y: 22), ellipse: false)

        #expect(try color(viewModel, at: CGPoint(x: 18, y: 14)).redComponent > 0.8)
        #expect(try color(viewModel, at: CGPoint(x: 18, y: 58)).alphaComponent < 0.1)
    }

    private func viewModel(image: NSImage) -> ImageEditorViewModel {
        ImageEditorViewModel(sourceName: "coordinate-audit.png", image: image) { _ in }
    }

    private func editableViewModel(image: NSImage) -> ImageEditorViewModel {
        let model = viewModel(image: image)
        model.replaceSelectedLayerImageForTesting(image, historyTitle: L10n.text("imageEditor.history.brush"))
        return model
    }

    private func topLeftImage(
        background: NSColor,
        fills: [(CGRect, NSColor)] = []
    ) -> NSImage {
        NSImage.rendered(size: canvasSize) { rect in
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: canvasSize.height) {
                background.setFill()
                rect.fill()
                for (fillRect, color) in fills {
                    color.setFill()
                    fillRect.fill()
                }
            }
        } ?? NSImage.transparent(size: canvasSize)
    }

    private func color(_ viewModel: ImageEditorViewModel, at point: CGPoint) throws -> NSColor {
        try #require(viewModel.currentImage.color(at: point)?.usingColorSpace(.deviceRGB))
    }

    private func maximumAlpha(_ viewModel: ImageEditorViewModel, in rect: CGRect) throws -> CGFloat {
        var maximum: CGFloat = 0
        for y in stride(from: Int(rect.minY), to: Int(rect.maxY), by: 2) {
            for x in stride(from: Int(rect.minX), to: Int(rect.maxX), by: 2) {
                maximum = max(maximum, try color(viewModel, at: CGPoint(x: x, y: y)).alphaComponent)
            }
        }
        return maximum
    }

    private func imagePoint(
        under pointer: CGPoint,
        zoom: CGFloat,
        offset: CGSize,
        viewportSize: CGSize
    ) -> CGPoint {
        let center = CGPoint(
            x: viewportSize.width / 2 + offset.width,
            y: viewportSize.height / 2 + offset.height
        )
        return CGPoint(
            x: (pointer.x - center.x) / zoom,
            y: (pointer.y - center.y) / zoom
        )
    }
}
