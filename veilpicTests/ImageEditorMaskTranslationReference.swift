import CoreGraphics

/// Frozen rc1705 scalar loop, with the same byte representation and rounding.
/// Test/benchmark oracle only; never a production fallback.
enum ImageEditorMaskTranslationReference {
    static func translated(alpha: [UInt8], width: Int, height: Int,
                           delta: CGSize, canvasSize: CGSize) -> [UInt8] {
        let dx = Int(((delta.width / max(canvasSize.width, 1)) * CGFloat(width)).rounded(.toNearestOrAwayFromZero))
        let dy = Int(((delta.height / max(canvasSize.height, 1)) * CGFloat(height)).rounded(.toNearestOrAwayFromZero))
        guard dx != 0 || dy != 0 else { return alpha }
        var output = [UInt8](repeating: 0, count: alpha.count)
        for y in 0..<height {
            for x in 0..<width {
                let sourceX = x - dx
                let sourceY = y - dy
                guard sourceX >= 0, sourceY >= 0, sourceX < width, sourceY < height else { continue }
                output[y * width + x] = alpha[sourceY * width + sourceX]
            }
        }
        return output
    }
}
