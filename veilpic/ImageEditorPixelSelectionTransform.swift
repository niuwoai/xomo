import CoreGraphics

enum ImageEditorPixelSelectionTransform {
    private static let componentsPerPixel = 4
    private static let maximumComponent: CGFloat = 255

    static func flipped(
        source: [UInt8], maskAlpha: [UInt8], width: Int, height: Int, horizontally: Bool
    ) -> [UInt8]? {
        guard width > 0, height > 0,
              height <= maskAlpha.count / width,
              maskAlpha.count == width * height,
              source.count.isMultiple(of: componentsPerPixel),
              source.count / componentsPerPixel == maskAlpha.count,
              let bounds = ImageEditorPixelMoveCoverageBounds(maskAlpha: maskAlpha, width: width, height: height)
        else { return nil }

        var output = source
        clear(source: source, maskAlpha: maskAlpha, width: width, bounds: bounds, into: &output)
        for y in bounds.rows {
            for x in bounds.columns {
                let sourcePixel = y * width + x
                let coverage = CGFloat(maskAlpha[sourcePixel]) / maximumComponent
                guard coverage > 0 else { continue }
                let targetX = horizontally
                    ? bounds.columns.upperBound - (x - bounds.columns.lowerBound) - 1
                    : x
                let targetY = horizontally
                    ? y
                    : bounds.rows.upperBound - (y - bounds.rows.lowerBound) - 1
                ImageEditorPremultipliedPixelCompositing.composite(
                    source: source,
                    sourcePixel: sourcePixel,
                    targetPixel: targetY * width + targetX,
                    coverage: coverage,
                    into: &output
                )
            }
        }
        return output
    }

    private static func clear(
        source: [UInt8], maskAlpha: [UInt8], width: Int,
        bounds: ImageEditorPixelMoveCoverageBounds, into output: inout [UInt8]
    ) {
        for y in bounds.rows {
            for x in bounds.columns {
                let pixel = y * width + x
                let inverse = 1 - CGFloat(maskAlpha[pixel]) / maximumComponent
                guard inverse < 1 else { continue }
                let offset = pixel * componentsPerPixel
                for channel in 0..<componentsPerPixel {
                    output[offset + channel] = UInt8((CGFloat(source[offset + channel]) * inverse).rounded())
                }
            }
        }
    }
}
