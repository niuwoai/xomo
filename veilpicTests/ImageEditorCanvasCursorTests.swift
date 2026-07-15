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

    @Test func samplingAndPaintBucketCursorsUseDistinctSemanticShapes() {
        #expect(ImageEditorCanvasCursor.family(for: .paintBucket) == .paintBucket)
        #expect(ImageEditorCanvasCursor.family(for: .eyedropper) == .eyedropper)
        #expect(ImageEditorCanvasCursor.family(for: .colorSampler) == .samplingScope)
        #expect(ImageEditorCanvasCursor.cursor(for: .eyedropper, brushDiameter: 18) === NSCursor.crosshair)

        let bucket = ImageEditorCanvasCursor.cursor(for: .paintBucket, brushDiameter: 18)
        let sampler = ImageEditorCanvasCursor.cursor(for: .colorSampler, brushDiameter: 18)
        #expect(bucket.image.tiffRepresentation != sampler.image.tiffRepresentation)
    }
}
