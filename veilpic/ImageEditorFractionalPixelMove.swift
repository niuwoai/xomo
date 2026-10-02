import CoreGraphics

enum ImageEditorFractionalPixelMove {
    private static let componentsPerPixel = 4
    private static let maximumComponent: CGFloat = 255
    static let gridTolerance: CGFloat = 0.000000001

    /// Sample selected premultiplied pixels backwards, then composite once per
    /// destination. Forward splatting would source-over neighbouring samples
    /// and incorrectly reduce their combined coverage.
    static func composite(
        source: [UInt8], maskAlpha: [UInt8], width: Int, height: Int,
        delta: CGSize, coverageBounds: ImageEditorPixelMoveCoverageBounds? = nil, into background: inout [UInt8]
    ) {
        guard width > 0, height > 0, height <= maskAlpha.count / width,
              width * height <= source.count / componentsPerPixel,
              width * height <= background.count / componentsPerPixel,
              delta.width.isFinite, delta.height.isFinite,
              let sourceBounds = coverageBounds ?? ImageEditorPixelMoveCoverageBounds(maskAlpha: maskAlpha, width: width, height: height),
              let destination = sourceBounds.samplingDestination(width: width, height: height, delta: delta)
        else { return }
        for y in destination.rows {
            for x in destination.columns {
                let sample = selectedSample(source: source, maskAlpha: maskAlpha, width: width, height: height,
                                            x: CGFloat(x) - delta.width, y: CGFloat(y) - delta.height)
                guard sample.alpha > 0 else { continue }
                let offset = (y * width + x) * componentsPerPixel
                let inverseAlpha = 1 - sample.alpha / maximumComponent
                background[offset] = byte(sample.red + CGFloat(background[offset]) * inverseAlpha)
                background[offset + 1] = byte(sample.green + CGFloat(background[offset + 1]) * inverseAlpha)
                background[offset + 2] = byte(sample.blue + CGFloat(background[offset + 2]) * inverseAlpha)
                background[offset + 3] = byte(sample.alpha + CGFloat(background[offset + 3]) * inverseAlpha)
            }
        }
    }

    private static func selectedSample(
        source: [UInt8], maskAlpha: [UInt8], width: Int, height: Int, x: CGFloat, y: CGFloat
    ) -> Sample {
        let left = Int(floor(x))
        let top = Int(floor(y))
        let fractionX = x - CGFloat(left)
        let fractionY = y - CGFloat(top)
        var sample = Sample()
        for dy in 0...1 {
            for dx in 0...1 {
                let sourceX = left + dx
                let sourceY = top + dy
                guard (0..<width).contains(sourceX), (0..<height).contains(sourceY) else { continue }
                let pixel = sourceY * width + sourceX
                let weight = (dx == 0 ? 1 - fractionX : fractionX)
                    * (dy == 0 ? 1 - fractionY : fractionY)
                    * CGFloat(maskAlpha[pixel]) / maximumComponent
                sample.add(source, offset: pixel * componentsPerPixel, weight: weight)
            }
        }
        return sample
    }

    private static func byte(_ value: CGFloat) -> UInt8 {
        UInt8(max(0, min(maximumComponent, value.rounded())))
    }

    private struct Sample {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        mutating func add(_ source: [UInt8], offset: Int, weight: CGFloat) {
            red += CGFloat(source[offset]) * weight
            green += CGFloat(source[offset + 1]) * weight
            blue += CGFloat(source[offset + 2]) * weight
            alpha += CGFloat(source[offset + 3]) * weight
        }
    }
}
