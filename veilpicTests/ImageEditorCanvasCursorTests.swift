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
    }

    @Test func arrowNudgeUsesPhotoshopStyleModifierDistances() {
        #expect(ImageEditorArrowNudge.delta(for: 123, modifierFlags: []) == CGSize(width: -1, height: 0))
        #expect(ImageEditorArrowNudge.delta(for: 124, modifierFlags: [.option]) == CGSize(width: 5, height: 0))
        #expect(ImageEditorArrowNudge.delta(for: 126, modifierFlags: [.shift]) == CGSize(width: 0, height: -10))
        #expect(ImageEditorArrowNudge.delta(for: 125, modifierFlags: [.command]) == nil)
    }

    @Test func samplingAndPaintBucketCursorsUseDistinctSemanticShapes() {
        #expect(ImageEditorCanvasCursor.family(for: .paintBucket) == .paintBucket)
        #expect(ImageEditorCanvasCursor.family(for: .eyedropper) == .eyedropper)
        #expect(ImageEditorCanvasCursor.family(for: .colorSampler) == .samplingScope)
        #expect(ImageEditorCanvasCursor.cursor(for: .eyedropper, brushDiameter: 18) === NSCursor.crosshair)

        let bucket = ImageEditorCanvasCursor.cursor(for: .paintBucket, brushDiameter: 18)
        let sampler = ImageEditorCanvasCursor.cursor(for: .colorSampler, brushDiameter: 18)
        #expect(bucket.image.tiffRepresentation != sampler.image.tiffRepresentation)
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
