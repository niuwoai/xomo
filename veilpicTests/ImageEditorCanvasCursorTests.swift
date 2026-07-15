import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorCanvasCursorTests {
    @Test func componentLibraryAlwaysRoutesToSystemArrowUnlessPanning() {
        #expect(
            ImageEditorCanvasCursor.tool(
                for: .components,
                selectedTool: .brush,
                isSpacebarPanning: false,
                isCanvasPanGestureActive: false
            ) == .move
        )
        #expect(
            ImageEditorCanvasCursor.cursor(for: .move, brushDiameter: 18) === NSCursor.arrow
        )
        #expect(
            ImageEditorCanvasCursor.tool(
                for: .components,
                selectedTool: .brush,
                isSpacebarPanning: true,
                isCanvasPanGestureActive: false
            ) == .hand
        )

        #expect(
            ImageEditorCanvasCursor.cursor(
                for: .components,
                selectedTool: .brush,
                brushDiameter: 18
            ) === NSCursor.arrow
        )
        #expect(
            ImageEditorCanvasCursor.cursor(
                for: .components,
                selectedTool: .brush,
                brushDiameter: 18,
                isSpacebarPanning: true
            ) === NSCursor.openHand
        )
        #expect(
            ImageEditorCanvasCursor.cursor(
                for: .components,
                selectedTool: .brush,
                brushDiameter: 18,
                handIsDragging: true,
                isCanvasPanGestureActive: true
            ) === NSCursor.closedHand
        )
    }

    @Test func toolsTabPreservesSelectedToolCursorAndPanOverride() {
        #expect(
            ImageEditorCanvasCursor.tool(
                for: .tools,
                selectedTool: .brush,
                isSpacebarPanning: false,
                isCanvasPanGestureActive: false
            ) == .brush
        )
        #expect(
            ImageEditorCanvasCursor.tool(
                for: .tools,
                selectedTool: .zoom,
                isSpacebarPanning: false,
                isCanvasPanGestureActive: true
            ) == .hand
        )
        let move = ImageEditorCanvasCursor.cursor(
            for: .tools,
            selectedTool: .move,
            brushDiameter: 18
        )
        #expect(move !== NSCursor.arrow)
        #expect(move.image.tiffRepresentation != NSCursor.arrow.image.tiffRepresentation)
    }

    @Test func arrowNudgeUsesPhotoshopStyleModifierDistances() {
        #expect(ImageEditorArrowNudge.delta(for: 123, modifierFlags: []) == CGSize(width: -1, height: 0))
        #expect(ImageEditorArrowNudge.delta(for: 124, modifierFlags: [.option]) == CGSize(width: 5, height: 0))
        #expect(ImageEditorArrowNudge.delta(for: 126, modifierFlags: [.shift]) == CGSize(width: 0, height: -10))
        #expect(ImageEditorArrowNudge.delta(for: 125, modifierFlags: [.command]) == nil)
    }

    @Test func selectionCursorModesReflectPhotoshopModifierSemantics() {
        #expect(ImageEditorSelectionCursorMode.from(modifierFlags: []) == .replace)
        #expect(ImageEditorSelectionCursorMode.from(modifierFlags: [.shift]) == .add)
        #expect(ImageEditorSelectionCursorMode.from(modifierFlags: [.option]) == .subtract)
        #expect(ImageEditorSelectionCursorMode.from(modifierFlags: [.shift, .option]) == .intersect)

        let replace = ImageEditorCanvasCursor.cursor(for: .marquee, brushDiameter: 18)
        let add = ImageEditorCanvasCursor.cursor(for: .marquee, brushDiameter: 18, modifierFlags: [.shift])
        let subtract = ImageEditorCanvasCursor.cursor(for: .marquee, brushDiameter: 18, modifierFlags: [.option])
        let intersect = ImageEditorCanvasCursor.cursor(for: .marquee, brushDiameter: 18, modifierFlags: [.shift, .option])
        #expect(replace.image.tiffRepresentation != add.image.tiffRepresentation)
        #expect(add.image.tiffRepresentation != subtract.image.tiffRepresentation)
        #expect(subtract.image.tiffRepresentation != intersect.image.tiffRepresentation)
    }

    @Test func zoomCursorReflectsOptionZoomOutMode() {
        let zoomIn = ImageEditorCanvasCursor.cursor(for: .zoom, brushDiameter: 18)
        let zoomOut = ImageEditorCanvasCursor.cursor(
            for: .zoom,
            brushDiameter: 18,
            modifierFlags: [.option]
        )

        #expect(zoomIn.image.tiffRepresentation != zoomOut.image.tiffRepresentation)
        #expect(
            ImageEditorCanvasCursor.cursor(
                for: .tools,
                selectedTool: .zoom,
                brushDiameter: 18,
                modifierFlags: [.option]
            ).image.tiffRepresentation == zoomOut.image.tiffRepresentation
        )
    }

    @Test func zoomDirectionUsesOptionForZoomOut() {
        #expect(ImageEditorZoomDirection.from(modifierFlags: []) == .zoomIn)
        #expect(ImageEditorZoomDirection.from(modifierFlags: [.shift]) == .zoomIn)
        #expect(ImageEditorZoomDirection.from(modifierFlags: [.option]) == .zoomOut)
        #expect(ImageEditorZoomDirection.from(modifierFlags: [.option, .shift]) == .zoomOut)
    }

    @Test func samplingAndPaintBucketCursorsUseDistinctSemanticShapes() {
        #expect(ImageEditorCanvasCursor.family(for: .paintBucket) == .paintBucket)
        #expect(ImageEditorCanvasCursor.family(for: .eyedropper) == .eyedropper)
        #expect(ImageEditorCanvasCursor.family(for: .redEye) == .redEye)
        #expect(ImageEditorCanvasCursor.family(for: .quickSelection) == .quickSelection)
        #expect(ImageEditorCanvasCursor.family(for: .cloneStamp) == .cloneStamp)
        #expect(ImageEditorCanvasCursor.family(for: .healingBrush) == .healingBrush)
        #expect(ImageEditorCanvasCursor.family(for: .colorSampler) == .samplingScope)
        #expect(ImageEditorCanvasCursor.family(for: .brush) == .brushTool)
        #expect(ImageEditorCanvasCursor.family(for: .eraser) == .eraserTool)
        #expect(ImageEditorCanvasCursor.family(for: .rectangle) == .rectangleOutline)
        #expect(ImageEditorCanvasCursor.family(for: .ellipse) == .ellipseOutline)
        #expect(ImageEditorCanvasCursor.family(for: .dodge) == .toneBrush)
        #expect(ImageEditorCanvasCursor.family(for: .burn) == .toneBrush)
        #expect(ImageEditorCanvasCursor.family(for: .sponge) == .toneBrush)
        #expect(ImageEditorCanvasCursor.family(for: .blur) == .retouchBrush)
        #expect(ImageEditorCanvasCursor.family(for: .sharpen) == .retouchBrush)
        #expect(ImageEditorCanvasCursor.family(for: .smudge) == .retouchBrush)

        let bucket = ImageEditorCanvasCursor.cursor(for: .paintBucket, brushDiameter: 18)
        let eyedropper = ImageEditorCanvasCursor.cursor(for: .eyedropper, brushDiameter: 18)
        let redEye = ImageEditorCanvasCursor.cursor(for: .redEye, brushDiameter: 18)
        let quickSelection = ImageEditorCanvasCursor.cursor(for: .quickSelection, brushDiameter: 18)
        let cloneStamp = ImageEditorCanvasCursor.cursor(for: .cloneStamp, brushDiameter: 18)
        let healingBrush = ImageEditorCanvasCursor.cursor(for: .healingBrush, brushDiameter: 18)
        let sampler = ImageEditorCanvasCursor.cursor(for: .colorSampler, brushDiameter: 18)
        let dodge = ImageEditorCanvasCursor.cursor(for: .dodge, brushDiameter: 18)
        let burn = ImageEditorCanvasCursor.cursor(for: .burn, brushDiameter: 18)
        let sponge = ImageEditorCanvasCursor.cursor(for: .sponge, brushDiameter: 18)
        let brush = ImageEditorCanvasCursor.cursor(for: .brush, brushDiameter: 18)
        let eraser = ImageEditorCanvasCursor.cursor(for: .eraser, brushDiameter: 18)
        let blur = ImageEditorCanvasCursor.cursor(for: .blur, brushDiameter: 18)
        let sharpen = ImageEditorCanvasCursor.cursor(for: .sharpen, brushDiameter: 18)
        let smudge = ImageEditorCanvasCursor.cursor(for: .smudge, brushDiameter: 18)
        #expect(bucket.image.tiffRepresentation != eyedropper.image.tiffRepresentation)
        #expect(eyedropper.image.tiffRepresentation != sampler.image.tiffRepresentation)
        #expect(redEye.image.tiffRepresentation != eyedropper.image.tiffRepresentation)
        #expect(redEye.image.tiffRepresentation != sampler.image.tiffRepresentation)
        #expect(quickSelection.image.tiffRepresentation != redEye.image.tiffRepresentation)
        #expect(quickSelection.image.tiffRepresentation != sampler.image.tiffRepresentation)
        #expect(cloneStamp.image.tiffRepresentation != quickSelection.image.tiffRepresentation)
        #expect(cloneStamp.image.tiffRepresentation != sampler.image.tiffRepresentation)
        #expect(healingBrush.image.tiffRepresentation != cloneStamp.image.tiffRepresentation)
        #expect(healingBrush.image.tiffRepresentation != sampler.image.tiffRepresentation)
        #expect(dodge.image.tiffRepresentation != burn.image.tiffRepresentation)
        #expect(burn.image.tiffRepresentation != sponge.image.tiffRepresentation)
        #expect(sponge.image.tiffRepresentation != sampler.image.tiffRepresentation)
        #expect(brush.image.tiffRepresentation != eraser.image.tiffRepresentation)
        #expect(brush.image.tiffRepresentation != sampler.image.tiffRepresentation)
        #expect(blur.image.tiffRepresentation != sharpen.image.tiffRepresentation)
        #expect(sharpen.image.tiffRepresentation != smudge.image.tiffRepresentation)
        #expect(smudge.image.tiffRepresentation != sampler.image.tiffRepresentation)
        #expect(eyedropper !== NSCursor.crosshair)
    }

    @Test func precisionToolsUseDistinctSemanticArtwork() {
        let tools: [ImageEditorTool] = [
            .marquee, .lasso, .magicWand, .crop, .patchTool,
            .gradient, .rectangle, .ellipse
        ]
        let representations = tools.compactMap {
            ImageEditorCanvasCursor.cursor(for: $0, brushDiameter: 18).image.tiffRepresentation
        }
        #expect(representations.count == tools.count)
        #expect(Set(representations).count == tools.count)
    }
}
