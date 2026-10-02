import Foundation

enum ImageEditorSelectionMaskBounds {
    typealias PixelBounds = (minX: Int, minY: Int, maxX: Int, maxY: Int)
    private static let wordBytes = MemoryLayout<UInt64>.size

    static func pixelBounds(alpha: [UInt8], width: Int, height: Int, inverted: Bool = false) -> PixelBounds? {
        guard width > 0, height > 0, height <= alpha.count / width,
              alpha.count == width * height else { return nil }
        let background: UInt64 = inverted ? .max : 0
        return alpha.withUnsafeBytes { bytes -> PixelBounds? in
            guard let base = bytes.baseAddress else { return nil }
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                let row = base.advanced(by: y * width)
                guard let first = firstSelected(in: row, count: width, background: background, inverted: inverted)
                else { continue }
                let last = lastSelected(in: row, count: width, first: first, background: background, inverted: inverted)
                minX = min(minX, first)
                maxX = max(maxX, last)
                minY = min(minY, y)
                maxY = y
            }
            return maxX >= minX ? (minX, minY, maxX, maxY) : nil
        }
    }

    private static func firstSelected(in row: UnsafeRawPointer, count: Int,
                                      background: UInt64, inverted: Bool) -> Int? {
        var x = 0
        // Uniform background words can be skipped without inspecting each byte.
        // Unaligned loads stay entirely inside this row, including narrow/tail rows.
        while x <= count - wordBytes,
              row.loadUnaligned(fromByteOffset: x, as: UInt64.self) == background { x += wordBytes }
        while x < count {
            if isSelected(row.load(fromByteOffset: x, as: UInt8.self), inverted: inverted) { return x }
            x += 1
        }
        return nil
    }

    private static func lastSelected(in row: UnsafeRawPointer, count: Int, first: Int,
                                     background: UInt64, inverted: Bool) -> Int {
        var end = count
        while end - first >= wordBytes,
              row.loadUnaligned(fromByteOffset: end - wordBytes, as: UInt64.self) == background { end -= wordBytes }
        var x = end - 1
        while x > first {
            if isSelected(row.load(fromByteOffset: x, as: UInt8.self), inverted: inverted) { return x }
            x -= 1
        }
        return first
    }

    private static func isSelected(_ value: UInt8, inverted: Bool) -> Bool {
        inverted ? value < UInt8.max : value > 0
    }
}
