import CoreGraphics

struct ImageEditorPixelMoveCoverageBounds: Equatable {
    let columns: Range<Int>
    let rows: Range<Int>

    init?(maskAlpha: [UInt8], width: Int, height: Int) {
        guard width > 0, height > 0, height <= maskAlpha.count / width else { return nil }
        var left = width, right = 0, top = height, bottom = 0
        for pixel in 0..<(width * height) where maskAlpha[pixel] > 0 {
            let x = pixel % width
            let y = pixel / width
            left = min(left, x)
            right = max(right, x + 1)
            top = min(top, y)
            bottom = max(bottom, y + 1)
        }
        guard left < right, top < bottom else { return nil }
        columns = left..<right
        rows = top..<bottom
    }

    private init(columns: Range<Int>, rows: Range<Int>) {
        self.columns = columns
        self.rows = rows
    }

    func samplingDestination(width: Int, height: Int, delta: CGSize) -> Self? {
        guard delta.width.isFinite, delta.height.isFinite else { return nil }
        // One extra sample on both sides conservatively includes the complete
        // bilinear footprint, including subpixel coverage at image edges.
        func limits(_ range: Range<Int>, shift: CGFloat, length: Int) -> Range<Int> {
            let lower = max(0, min(CGFloat(length), floor(CGFloat(range.lowerBound) + shift) - 1))
            let upper = max(0, min(CGFloat(length), ceil(CGFloat(range.upperBound) + shift) + 1))
            return Int(lower)..<max(Int(lower), Int(upper))
        }
        let x = limits(columns, shift: delta.width, length: width)
        let y = limits(rows, shift: delta.height, length: height)
        guard !x.isEmpty, !y.isEmpty else { return nil }
        return Self(columns: x, rows: y)
    }
}

enum ImageEditorPixelSelectionMovePixels {
    private static let componentsPerPixel = 4
    private static let maximumComponent: CGFloat = 255

    static func moved(source: [UInt8], maskAlpha: [UInt8], width: Int, height: Int, delta: CGSize) -> [UInt8]? {
        guard width > 0, height > 0, height <= maskAlpha.count / width,
              maskAlpha.count == width * height,
              source.count.isMultiple(of: componentsPerPixel), source.count / componentsPerPixel == maskAlpha.count,
              delta.width.isFinite, delta.height.isFinite else { return nil }
        let localDelta = CGSize(width: max(-CGFloat(width), min(CGFloat(width), delta.width)),
                                height: max(-CGFloat(height), min(CGFloat(height), delta.height)))
        guard localDelta != .zero,
              let bounds = ImageEditorPixelMoveCoverageBounds(maskAlpha: maskAlpha, width: width, height: height)
        else { return source }
        var output = source
        clear(source: source, maskAlpha: maskAlpha, width: width, bounds: bounds, into: &output)
        if abs(localDelta.width - localDelta.width.rounded()) > ImageEditorFractionalPixelMove.gridTolerance
            || abs(localDelta.height - localDelta.height.rounded()) > ImageEditorFractionalPixelMove.gridTolerance {
            ImageEditorFractionalPixelMove.composite(source: source, maskAlpha: maskAlpha, width: width, height: height,
                delta: localDelta, coverageBounds: bounds, into: &output)
        } else {
            compositeInteger(source: source, maskAlpha: maskAlpha, width: width, height: height,
                             delta: localDelta, bounds: bounds, into: &output)
        }
        return output
    }

    private static func clear(source: [UInt8], maskAlpha: [UInt8], width: Int,
                              bounds: ImageEditorPixelMoveCoverageBounds, into output: inout [UInt8]) {
        for y in bounds.rows {
            for x in bounds.columns {
                let pixel = y * width + x
                guard maskAlpha[pixel] > 0 else { continue }
                let inverse = 1 - CGFloat(maskAlpha[pixel]) / 255
                for channel in 0..<componentsPerPixel {
                    let offset = pixel * componentsPerPixel + channel
                    output[offset] = UInt8((CGFloat(source[offset]) * inverse).rounded())
                }
            }
        }
    }

    private static func compositeInteger(source: [UInt8], maskAlpha: [UInt8], width: Int, height: Int,
                                         delta: CGSize, bounds: ImageEditorPixelMoveCoverageBounds,
                                         into output: inout [UInt8]) {
        let dx = Int(delta.width.rounded()), dy = Int(delta.height.rounded())
        for y in bounds.rows {
            for x in bounds.columns {
                let pixel = y * width + x
                guard maskAlpha[pixel] > 0 else { continue }
                let tx = x + dx, ty = y + dy
                guard (0..<width).contains(tx), (0..<height).contains(ty) else { continue }
                let coverage = CGFloat(maskAlpha[pixel]) / maximumComponent
                ImageEditorPremultipliedPixelCompositing.composite(
                    source: source, sourcePixel: pixel, targetPixel: ty * width + tx,
                    coverage: coverage, into: &output
                )
            }
        }
    }

}

enum ImageEditorPremultipliedPixelCompositing {
    private static let componentsPerPixel = 4
    private static let maximumComponent: CGFloat = 255

    static func composite(
        source: [UInt8], sourcePixel: Int, targetPixel: Int, coverage: CGFloat, into output: inout [UInt8]
    ) {
        guard sourcePixel >= 0, targetPixel >= 0,
              sourcePixel < source.count / componentsPerPixel,
              targetPixel < output.count / componentsPerPixel,
              coverage.isFinite
        else { return }
        let sourceOffset = sourcePixel * componentsPerPixel
        let targetOffset = targetPixel * componentsPerPixel
        let clampedCoverage = max(0, min(1, coverage))
        let inverse = 1 - CGFloat(source[sourceOffset + 3]) / maximumComponent * clampedCoverage
        for channel in 0..<componentsPerPixel {
            let value = CGFloat(source[sourceOffset + channel]) * clampedCoverage
                + CGFloat(output[targetOffset + channel]) * inverse
            output[targetOffset + channel] = UInt8(max(0, min(maximumComponent, value.rounded())))
        }
    }
}
