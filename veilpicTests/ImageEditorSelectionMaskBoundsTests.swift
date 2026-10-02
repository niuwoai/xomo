import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionMaskBoundsTests {
    private nonisolated static let shapes = [CGSize(width: 1, height: 1), CGSize(width: 1, height: 17),
        CGSize(width: 17, height: 1), CGSize(width: 7, height: 9), CGSize(width: 8, height: 9),
        CGSize(width: 9, height: 7), CGSize(width: 15, height: 9), CGSize(width: 16, height: 9),
        CGSize(width: 17, height: 9), CGSize(width: 65, height: 5)]

    @Test(arguments: shapes, [false, true])
    func wordScanMatchesEveryScalarExtreme(size: CGSize, inverted: Bool) {
        let width = Int(size.width), height = Int(size.height)
        for kind in 0..<6 {
            let alpha = (0..<(width * height)).map { pixel -> UInt8 in
                switch kind {
                case 0: return 0
                case 1: return 255
                case 2: return UInt8(pixel % 256)
                case 3: return pixel.isMultiple(of: 13) ? 1 : 0
                case 4: return pixel.isMultiple(of: 17) ? 254 : 255
                default: return pixel / width == height / 2 ? 127 : 0
                }
            }
            compare(alpha: alpha, width: width, height: height, inverted: inverted)
        }
    }

    @Test(arguments: [false, true])
    func eachIsolatedPixelIncludingUnalignedTailsHasExactBounds(inverted: Bool) throws {
        let width = 17, height = 9
        for y in 0..<height {
            for x in 0..<width {
                var alpha = [UInt8](repeating: inverted ? 255 : 0, count: width * height)
                alpha[y * width + x] = inverted ? 254 : 1
                let bounds = try #require(ImageEditorSelectionMaskBounds.pixelBounds(alpha: alpha,
                    width: width, height: height, inverted: inverted))
                #expect(bounds.minX == x && bounds.maxX == x && bounds.minY == y && bounds.maxY == y)
            }
        }
    }

    @Test(arguments: [false, true])
    func distantSoftIslandsKeepAllFourExtremesAndCanvasScaling(inverted: Bool) throws {
        let width = 65, height = 5
        var alpha = [UInt8](repeating: inverted ? 255 : 0, count: width * height)
        for (x, y) in [(63, 0), (1, 2), (64, 4), (0, 3)] { alpha[y * width + x] = inverted ? 254 : 1 }
        let bounds = try #require(ImageEditorSelectionMaskBounds.pixelBounds(alpha: alpha,
            width: width, height: height, inverted: inverted))
        #expect(bounds.minX == 0 && bounds.maxX == 64 && bounds.minY == 0 && bounds.maxY == 4)
        let mask = ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
        #expect(mask.selectedBounds(in: CGSize(width: 32.5, height: 2.5), inverted: inverted)
            == CGRect(x: 0, y: 0, width: 32.5, height: 2.5))
        compare(alpha: alpha, width: width, height: height, inverted: inverted)
    }

    @Test func invalidShapeRejectsWithoutOverflowOrMutation() {
        let alpha: [UInt8] = [0, 1, 254, 255]
        for (width, height) in [(0, 4), (-1, 4), (2, 3), (Int.max, Int.max), (4, 0)] {
            #expect(ImageEditorSelectionMaskBounds.pixelBounds(alpha: alpha, width: width, height: height) == nil)
        }
        #expect(alpha == [0, 1, 254, 255])
    }

    private func compare(alpha: [UInt8], width: Int, height: Int, inverted: Bool) {
        let expected = ImageEditorMaskBoundsReference.bounds(alpha: alpha, width: width, height: height, inverted: inverted)
        let actual = ImageEditorSelectionMaskBounds.pixelBounds(alpha: alpha, width: width, height: height, inverted: inverted)
        #expect(actual?.minX == expected?.minX && actual?.minY == expected?.minY
            && actual?.maxX == expected?.maxX && actual?.maxY == expected?.maxY)
        let canvas = CGSize(width: CGFloat(width) * 1.5, height: CGFloat(height) * 0.5)
        let expectedRect = expected.map { CGRect(x: CGFloat($0.minX) * 1.5, y: CGFloat($0.minY) * 0.5,
            width: CGFloat($0.maxX - $0.minX + 1) * 1.5, height: CGFloat($0.maxY - $0.minY + 1) * 0.5) }
        #expect(ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
            .selectedBounds(in: canvas, inverted: inverted) == expectedRect)
    }
}
