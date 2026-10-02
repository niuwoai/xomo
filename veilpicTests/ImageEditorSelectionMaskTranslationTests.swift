import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionMaskTranslationTests {
    private nonisolated static let offsets = [CGSize.zero, CGSize(width: 1, height: -1), CGSize(width: -2, height: 3),
        CGSize(width: 0.49, height: -0.49), CGSize(width: 0.5, height: -0.5), CGSize(width: -0.5, height: 0.5),
        CGSize(width: 0.75, height: -0.75), CGSize(width: 19, height: -13), CGSize(width: -19, height: 13)]

    @Test(arguments: [1, 2, 3], offsets)
    func rowCopyMatchesScalarForSoftDenseAndDisconnectedCoverage(scale: Int, delta: CGSize) throws {
        let width = 19, height = 13
        let canvas = CGSize(width: width * scale, height: height * scale)
        for kind in 0..<4 {
            let alpha = coverage(width: width, height: height, kind: kind)
            let expected = ImageEditorMaskTranslationReference.translated(alpha: alpha, width: width,
                height: height, delta: delta, canvasSize: canvas)
            let actual = try #require(ImageEditorSelectionMaskTranslation.translated(alpha: alpha,
                width: width, height: height, delta: delta, canvasSize: canvas))
            #expect(actual == expected)
            #expect(alpha == coverage(width: width, height: height, kind: kind))
            let mask = ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
            #expect(mask.translated(by: delta, canvasSize: canvas)?.alpha == expected)
        }
    }

    @Test(arguments: [CGSize(width: 1, height: 9), CGSize(width: 9, height: 1)])
    func onePixelAxesAndClippedOffsetsPreserveEveryByte(size: CGSize) throws {
        let width = Int(size.width), height = Int(size.height)
        let alpha = (0..<(width * height)).map { UInt8(1 + $0 * 13) }
        for delta in [CGSize(width: 1, height: 0), CGSize(width: 0, height: -1), CGSize(width: -0.5, height: 0.5)] {
            #expect(try #require(ImageEditorSelectionMaskTranslation.translated(alpha: alpha, width: width,
                height: height, delta: delta, canvasSize: size))
                == ImageEditorMaskTranslationReference.translated(alpha: alpha, width: width, height: height,
                    delta: delta, canvasSize: size))
        }
    }

    @Test func finiteHugeOffsetsSafelyProduceFullyClippedCoverage() throws {
        for delta in [CGSize(width: CGFloat.greatestFiniteMagnitude, height: 0),
                      CGSize(width: -CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)] {
            #expect(try #require(ImageEditorSelectionMaskTranslation.translated(alpha: [1, 128, 255, 0],
                width: 2, height: 2, delta: delta, canvasSize: CGSize(width: 1, height: 1))) == [0, 0, 0, 0])
        }
    }

    @Test func invalidGeometryAndBuffersRejectWithoutMutation() {
        let alpha: [UInt8] = [1, 128, 255, 0]
        for delta in [CGSize(width: CGFloat.nan, height: 0), CGSize(width: 0, height: CGFloat.infinity)] {
            #expect(ImageEditorSelectionMaskTranslation.translated(alpha: alpha, width: 2, height: 2,
                delta: delta, canvasSize: CGSize(width: 2, height: 2)) == nil)
        }
        for size in [CGSize.zero, CGSize(width: CGFloat.nan, height: 2), CGSize(width: -1, height: 2)] {
            #expect(ImageEditorSelectionMaskTranslation.translated(alpha: alpha, width: 2, height: 2,
                delta: CGSize(width: 1, height: 0), canvasSize: size) == nil)
        }
        #expect(ImageEditorSelectionMaskTranslation.translated(alpha: alpha, width: Int.max, height: Int.max,
            delta: .zero, canvasSize: CGSize(width: 2, height: 2)) == nil)
        #expect(ImageEditorSelectionMaskTranslation.translated(alpha: alpha, width: 2, height: 3,
            delta: .zero, canvasSize: CGSize(width: 2, height: 2)) == nil)
        #expect(alpha == [1, 128, 255, 0])
    }

    @Test(arguments: [false, true])
    func translatedRasterSelectionKeepsSoftAndInvertedCoverage(inverted: Bool) throws {
        let canvas = CGSize(width: 19, height: 13)
        let mask = ImageEditorSelectionMask(width: 19, height: 13, alpha: coverage(width: 19, height: 13, kind: 2))
        var selection = ImageEditorSelection.raster(mask: mask, bounds: CGRect(origin: .zero, size: canvas))
        selection.isInverted = inverted
        let actualSource = try #require(selection.rasterizedMask(canvasSize: canvas))
        let expected = ImageEditorMaskTranslationReference.translated(alpha: actualSource.alpha, width: 19,
            height: 13, delta: CGSize(width: 1, height: -1), canvasSize: canvas)
        let translated = try #require(selection.translated(by: CGSize(width: 1, height: -1), canvasSize: canvas))
        #expect(translated.rasterMask?.alpha == expected)
        #expect(!translated.isInverted)
        #expect(translated.bounds == ImageEditorSelectionMask(width: 19, height: 13, alpha: expected).selectedBounds(in: canvas))
    }

    private func coverage(width: Int, height: Int, kind: Int) -> [UInt8] {
        (0..<(width * height)).map { pixel in
            let x = pixel % width, y = pixel / width
            switch kind {
            case 0: return UInt8(pixel % 256)
            case 1: return (4..<11).contains(x) && (3..<8).contains(y) ? UInt8(1 + pixel % 254) : 0
            case 2: return pixel.isMultiple(of: 7) ? UInt8(1 + pixel % 254) : 0
            default: return 0
            }
        }
    }
}
