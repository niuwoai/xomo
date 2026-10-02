import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPixelMoveCoverageTests {
    private nonisolated static let deltas = [CGSize(width: 0.25, height: -0.75), CGSize(width: -0.75, height: 0.25),
        CGSize(width: 0.5, height: 0.5), CGSize(width: -3.5, height: 2.25),
        CGSize(width: 1, height: -1), CGSize(width: -2, height: 3),
        CGSize(width: 23, height: -17), CGSize.zero]

    @Test(arguments: [0, 1, 2, 3], deltas)
    func boundedMoveMatchesFrozenWholeGridWithPremultipliedPixels(kind: Int, delta: CGSize) throws {
        let width = 23, height = 17
        let source = pixels(width: width, height: height)
        let mask = coverage(width: width, height: height, kind: kind)
        let original = source
        let expected = ImageEditorPixelMoveReference.moved(source: source, mask: mask,
                                                          width: width, height: height, delta: delta)
        let actual = try #require(ImageEditorPixelSelectionMovePixels.moved(source: source, maskAlpha: mask,
                                                                           width: width, height: height, delta: delta))
        #expect(actual == expected)
        #expect(source == original)
    }

    @Test(arguments: [CGSize(width: 0.25, height: -0.75), CGSize(width: -0.75, height: 0.25),
                      CGSize(width: 0.5, height: 0.5), CGSize(width: -0.5, height: -0.5)])
    func directFractionalSamplingMatchesWholeGridAtAllEdges(delta: CGSize) {
        let width = 9, height = 7
        let source = pixels(width: width, height: height)
        let mask = coverage(width: width, height: height, kind: 3)
        var expected = ImageEditorPixelMoveReference.cleared(source: source, mask: mask)
        var actual = expected
        ImageEditorPixelMoveReference.composite(source: source, mask: mask, width: width, height: height,
                                                delta: delta, into: &expected)
        ImageEditorFractionalPixelMove.composite(source: source, maskAlpha: mask, width: width, height: height,
                                                 delta: delta, into: &actual)
        #expect(actual == expected)
    }

    @Test func smallCoverageBoundsLimitFourTapSamplingOnLargeBitmap() throws {
        let width = 2_048
        var mask = [UInt8](repeating: 0, count: width * width)
        for y in 992..<1_056 { for x in 992..<1_056 { mask[y * width + x] = 1 } }
        let bounds = try #require(ImageEditorPixelMoveCoverageBounds(maskAlpha: mask, width: width, height: width))
        #expect(bounds.columns == 992..<1_056)
        #expect(bounds.rows == 992..<1_056)
        let destination = try #require(bounds.samplingDestination(width: width, height: width,
                                                                 delta: CGSize(width: 0.75, height: -0.25)))
        #expect(destination.columns == 991..<1_058)
        #expect(destination.rows == 990..<1_057)
        #expect(destination.columns.count * destination.rows.count == 4_489)
    }

    @Test func disconnectedSoftTailAndDestinationClippingAreRetained() throws {
        let width = 128
        var mask = [UInt8](repeating: 0, count: width * width)
        mask[7 * width + 5] = 128
        mask[30 * width + 20] = 255
        mask[31 * width + 23] = 1
        let bounds = try #require(ImageEditorPixelMoveCoverageBounds(maskAlpha: mask, width: width, height: width))
        #expect(bounds.columns == 5..<24)
        #expect(bounds.rows == 7..<32)
        let destination = try #require(bounds.samplingDestination(width: width, height: width,
                                                                 delta: CGSize(width: -0.25, height: 0.5)))
        #expect(destination.columns == 3..<25)
        #expect(destination.rows == 6..<34)
        #expect(bounds.samplingDestination(width: width, height: width, delta: CGSize(width: 1_000, height: 0)) == nil)
    }

    @Test func emptyCoverageAndZeroDeltaPreserveOriginalBuffer() throws {
        let source = pixels(width: 8, height: 6)
        let empty = [UInt8](repeating: 0, count: 48)
        #expect(ImageEditorPixelMoveCoverageBounds(maskAlpha: empty, width: 8, height: 6) == nil)
        #expect(try #require(ImageEditorPixelSelectionMovePixels.moved(source: source, maskAlpha: empty,
            width: 8, height: 6, delta: CGSize(width: 0.5, height: -0.5))) == source)
        #expect(ImageEditorPixelSelectionMovePixels.moved(source: source,
            maskAlpha: [UInt8](repeating: 128, count: 48), width: 8, height: 6, delta: .zero) == source)
    }

    @Test func invalidInputsRejectBeforeAnyBackgroundMutation() {
        let source = pixels(width: 2, height: 2)
        for delta in [CGSize(width: CGFloat.nan, height: 0), CGSize(width: CGFloat.infinity, height: 0)] {
            #expect(ImageEditorPixelSelectionMovePixels.moved(source: source, maskAlpha: [255, 0, 0, 0],
                                                              width: 2, height: 2, delta: delta) == nil)
            var background = source
            ImageEditorFractionalPixelMove.composite(source: source, maskAlpha: [255, 0, 0, 0],
                                                     width: 2, height: 2, delta: delta, into: &background)
            #expect(background == source)
        }
        #expect(ImageEditorPixelSelectionMovePixels.moved(source: source, maskAlpha: [255],
            width: 2, height: 2, delta: CGSize(width: 1, height: 0)) == nil)
        #expect(ImageEditorPixelMoveCoverageBounds(maskAlpha: [255], width: Int.max, height: Int.max) == nil)
        #expect(ImageEditorPixelMoveCoverageBounds(maskAlpha: [255], width: 0, height: 1) == nil)
    }

    @MainActor
    @Test func largerNativePreviewReturnToZeroHistoryReloadAndExportPreserveExactPixels() throws {
        let size = CGSize(width: 256, height: 256)
        let image = try #require(NSImage.rendered(size: size) { rect in
            NSColor.red.setFill()
            rect.fill()
            NSColor.blue.setFill()
            CGRect(x: 224, y: 0, width: 16, height: 256).fill()
        })
        var layer = ImageEditorLayer.blank(name: "Large move", size: size)
        layer.image = image
        layer.frame = CGRect(x: 64, y: 64, width: 512, height: 512)
        let canvas = CGSize(width: 640, height: 640)
        let selection = ImageEditorSelection.rectangle(CGRect(x: 288, y: 288, width: 64, height: 64))
        let model = ImageEditorViewModel(sourceName: "large-move.png", image: .transparent(size: canvas)) { _ in }
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        model.selectedTool = .move
        model.document.selection = selection
        let original = try model.projectData()
        let undoCount = model.undoStack.count
        let pixels = try #require(imageEditorRGBABytes(image, width: 256, height: 256))
        // Independent local coverage: frame origin 64, canvas selection 288,
        // and 2x display scale map to native columns/rows 112..<144.
        var mask = [UInt8](repeating: 0, count: 256 * 256)
        for y in 112..<144 { for x in 112..<144 { mask[y * 256 + x] = 255 } }
        #expect(mask.filter { $0 > 0 }.count == 1_024)
        let expected = ImageEditorPixelMoveReference.moved(source: pixels, mask: mask,
            width: 256, height: 256, delta: CGSize(width: 0.5, height: -0.5))

        #expect(model.beginPixelSelectionMove(at: CGPoint(x: 320, y: 320)))
        model.updatePixelSelectionMove(by: CGSize(width: 1, height: -1))
        #expect(imageEditorRGBABytes(try #require(model.document.selectedLayer?.image), width: 256, height: 256) == expected)
        #expect(model.undoStack.count == undoCount)
        model.updatePixelSelectionMove(by: .zero)
        model.finishPixelSelectionMove()
        #expect(try model.projectData() == original)
        #expect(model.undoStack.count == undoCount)
        model.nudgePixelSelection(by: CGSize(width: 1, height: -1))
        #expect(model.undoStack.count == undoCount + 1)
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        let reopened = ImageEditorViewModel(sourceName: "reopened.png", image: .transparent(size: canvas)) { _ in }
        try reopened.loadProjectData(model.projectData())
        #expect(imageEditorRGBABytes(try #require(reopened.document.selectedLayer?.image), width: 256, height: 256) == expected)
        let png = try #require(reopened.exportData(settings: .init(format: .png, scope: .composited)))
        #expect(imageEditorRGBABytes(try #require(NSImage(data: png)), width: 640, height: 640)
            == imageEditorRGBABytes(model.document.compositedImage, width: 640, height: 640))
    }

    private func pixels(width: Int, height: Int) -> [UInt8] {
        (0..<(width * height)).flatMap { pixel -> [UInt8] in
            let alpha = UInt8(pixel.isMultiple(of: 7) ? 0 : 64 + pixel % 192)
            return [min(alpha, UInt8(pixel % 256)), alpha / 2, alpha / 3, alpha]
        }
    }

    private func coverage(width: Int, height: Int, kind: Int) -> [UInt8] {
        (0..<(width * height)).map { pixel in
            let x = pixel % width, y = pixel / width
            switch kind {
            case 0: return 255
            case 1: return (5..<10).contains(x) && (4..<9).contains(y) ? UInt8(32 + (x + y) % 192) : 0
            case 2: return pixel.isMultiple(of: 13) ? UInt8(1 + pixel % 255) : 0
            default: return x == 0 || y == 0 || x == width - 1 || y == height - 1 ? 128 : 0
            }
        }
    }
}
