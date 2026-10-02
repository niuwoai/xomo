import CoreGraphics

/// Frozen rc1703 full-grid algorithm. Used only by tests and the standalone
/// benchmark, never by the application or as a production fallback.
enum ImageEditorPixelMoveReference {
    static func moved(source: [UInt8], mask: [UInt8], width: Int, height: Int, delta: CGSize) -> [UInt8] {
        guard delta != .zero else { return source }
        var output = cleared(source: source, mask: mask)
        let tolerance: CGFloat = 0.000000001
        if abs(delta.width - delta.width.rounded()) > tolerance
            || abs(delta.height - delta.height.rounded()) > tolerance {
            composite(source: source, mask: mask, width: width, height: height, delta: delta, into: &output)
        } else {
            compositeInteger(source: source, mask: mask, width: width, height: height, delta: delta, into: &output)
        }
        return output
    }

    static func cleared(source: [UInt8], mask: [UInt8]) -> [UInt8] {
        source.enumerated().map { index, component in
            let inverse = 1 - CGFloat(mask[index / 4]) / 255
            return UInt8((CGFloat(component) * inverse).rounded())
        }
    }

    static func composite(source: [UInt8], mask: [UInt8], width: Int, height: Int,
                          delta: CGSize, into output: inout [UInt8]) {
        for y in 0..<height {
            for x in 0..<width {
                let values = sample(source: source, mask: mask, width: width, height: height,
                                    x: CGFloat(x) - delta.width, y: CGFloat(y) - delta.height)
                guard values[3] > 0 else { continue }
                let offset = (y * width + x) * 4
                let inverse = 1 - values[3] / 255
                for channel in 0..<4 {
                    output[offset + channel] = byte(values[channel] + CGFloat(output[offset + channel]) * inverse)
                }
            }
        }
    }

    private static func sample(source: [UInt8], mask: [UInt8], width: Int, height: Int,
                               x: CGFloat, y: CGFloat) -> [CGFloat] {
        let left = Int(floor(x))
        let top = Int(floor(y))
        let fractionX = x - CGFloat(left)
        let fractionY = y - CGFloat(top)
        var result = [CGFloat](repeating: 0, count: 4)
        for dy in 0...1 {
            for dx in 0...1 {
                let sx = left + dx
                let sy = top + dy
                guard (0..<width).contains(sx), (0..<height).contains(sy) else { continue }
                let pixel = sy * width + sx
                let weight = (dx == 0 ? 1 - fractionX : fractionX)
                    * (dy == 0 ? 1 - fractionY : fractionY) * CGFloat(mask[pixel]) / 255
                for channel in 0..<4 { result[channel] += CGFloat(source[pixel * 4 + channel]) * weight }
            }
        }
        return result
    }

    static func compositeInteger(source: [UInt8], mask: [UInt8], width: Int, height: Int,
                                 delta: CGSize, into output: inout [UInt8]) {
        let dx = Int(delta.width.rounded())
        let dy = Int(delta.height.rounded())
        for y in 0..<height {
            for x in 0..<width {
                let coverage = CGFloat(mask[y * width + x]) / 255
                guard coverage > 0 else { continue }
                let tx = x + dx
                let ty = y + dy
                guard (0..<width).contains(tx), (0..<height).contains(ty) else { continue }
                let sourceOffset = (y * width + x) * 4
                let targetOffset = (ty * width + tx) * 4
                let inverse = 1 - CGFloat(source[sourceOffset + 3]) / 255 * coverage
                for channel in 0..<4 {
                    output[targetOffset + channel] = byte(CGFloat(source[sourceOffset + channel]) * coverage
                        + CGFloat(output[targetOffset + channel]) * inverse)
                }
            }
        }
    }

    private static func byte(_ value: CGFloat) -> UInt8 {
        UInt8(max(0, min(255, value.rounded())))
    }
}
