import CoreGraphics

enum ImageEditorSelectionMaskTranslation {
    static func translated(alpha: [UInt8], width: Int, height: Int,
                           delta: CGSize, canvasSize: CGSize) -> [UInt8]? {
        guard width > 0, height > 0, height <= alpha.count / width,
              alpha.count == width * height,
              delta.width.isFinite, delta.height.isFinite,
              canvasSize.width.isFinite, canvasSize.height.isFinite,
              canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let shiftX = ((delta.width / max(canvasSize.width, 1)) * CGFloat(width)).rounded(.toNearestOrAwayFromZero)
        let shiftY = ((delta.height / max(canvasSize.height, 1)) * CGFloat(height)).rounded(.toNearestOrAwayFromZero)
        // Check the clipped result before converting to Int, including finite
        // canvas deltas whose scaled pixel offsets overflow floating point.
        guard abs(shiftX) < CGFloat(width), abs(shiftY) < CGFloat(height)
        else { return [UInt8](repeating: 0, count: alpha.count) }
        let dx = Int(shiftX), dy = Int(shiftY)
        guard dx != 0 || dy != 0 else { return alpha }
        return copyRows(alpha: alpha, width: width, height: height, dx: dx, dy: dy)
    }

    private static func copyRows(alpha: [UInt8], width: Int, height: Int, dx: Int, dy: Int) -> [UInt8] {
        let sourceX = max(0, -dx), sourceY = max(0, -dy)
        let destinationX = max(0, dx), destinationY = max(0, dy)
        let rowLength = width - abs(dx), rowCount = height - abs(dy)
        var output = [UInt8](repeating: 0, count: alpha.count)
        alpha.withUnsafeBufferPointer { source in
            output.withUnsafeMutableBufferPointer { target in
                for row in 0..<rowCount {
                    let sourceOffset = (sourceY + row) * width + sourceX
                    let targetOffset = (destinationY + row) * width + destinationX
                    // Distinct initialized buffers, with one in-range overlap
                    // interval per row. No alpha resampling or Y-axis reversal.
                    target.baseAddress!.advanced(by: targetOffset)
                        .update(from: source.baseAddress!.advanced(by: sourceOffset), count: rowLength)
                }
            }
        }
        return output
    }
}
