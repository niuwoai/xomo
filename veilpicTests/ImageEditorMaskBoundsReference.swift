// Frozen rc1706 scalar bounds algorithm; tests and benchmarks only.
enum ImageEditorMaskBoundsReference {
    static func bounds(alpha: [UInt8], width: Int, height: Int, inverted: Bool = false)
        -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let value = alpha[y * width + x]
                guard inverted ? value < UInt8.max : value > 0 else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        return maxX >= minX ? (minX, minY, maxX, maxY) : nil
    }
}
