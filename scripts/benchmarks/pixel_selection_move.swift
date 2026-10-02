import Foundation
import CoreGraphics

@main
struct PixelSelectionMoveBenchmark {
    static func main() throws {
        let arguments = CommandLine.arguments.dropFirst()
        let sizes = arguments.first.map { $0.split(separator: ",").compactMap { Int($0) } } ?? [512, 1_024, 2_048]
        let iterations = max(1, arguments.dropFirst().first.flatMap { Int($0) } ?? 3)
        var cases: [[String: Any]] = []
        for size in sizes {
            for dense in [false, true] {
                cases.append(try measure(size: size, dense: dense, iterations: iterations))
            }
        }
        let result: [String: Any] = ["cases": cases, "compiler_optimization": "-O",
            "includes_image_conversion_or_ui": false, "current_algorithm": algorithmName]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }

    private static var algorithmName: String {
        #if XOMO_BOUNDED_PIXEL_MOVE
        "coverage-bounded"
        #else
        "rc1703-full-grid"
        #endif
    }

    private static func measure(size: Int, dense: Bool, iterations: Int) throws -> [String: Any] {
        guard size >= 64, size <= 4_096 else { throw BenchmarkError.invalidSize }
        let source = pixels(size: size)
        let mask = coverage(size: size, dense: dense)
        let delta = CGSize(width: 0.75, height: -0.25)
        let reference = ImageEditorPixelMoveReference.moved(source: source, mask: mask, width: size, height: size, delta: delta)
        let current = currentMove(source: source, mask: mask, size: size, delta: delta)
        guard reference == current else { throw BenchmarkError.pixelMismatch }
        var oldTimes: [Double] = []
        var newTimes: [Double] = []
        for iteration in 0..<iterations {
            // Alternate ordering to avoid always giving one path the warm CPU.
            for useCurrent in iteration.isMultiple(of: 2) ? [false, true] : [true, false] {
                let start = ProcessInfo.processInfo.systemUptime
                let output = useCurrent ? currentMove(source: source, mask: mask, size: size, delta: delta)
                    : ImageEditorPixelMoveReference.moved(source: source, mask: mask, width: size, height: size, delta: delta)
                let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1_000
                guard output == reference else { throw BenchmarkError.pixelMismatch }
                if useCurrent { newTimes.append(elapsed) } else { oldTimes.append(elapsed) }
            }
        }
        let oldMedian = median(oldTimes)
        let newMedian = median(newTimes)
        return ["width": size, "height": size, "coverage": dense ? "dense" : "64x64-soft-selection",
                "iterations": iterations, "reference_ms": oldTimes, "current_ms": newTimes,
                "reference_median_ms": oldMedian, "current_median_ms": newMedian,
                "reference_over_current": oldMedian / max(newMedian, Double.leastNonzeroMagnitude),
                "exact_pixels": true, "rgba_buffer_bytes": size * size * 4,
                "mask_buffer_bytes": size * size]
    }

    private static func currentMove(source: [UInt8], mask: [UInt8], size: Int, delta: CGSize) -> [UInt8] {
        #if XOMO_BOUNDED_PIXEL_MOVE
        ImageEditorPixelSelectionMovePixels.moved(source: source, maskAlpha: mask,
            width: size, height: size, delta: delta)!
        #else
        var output = ImageEditorPixelMoveReference.cleared(source: source, mask: mask)
        ImageEditorFractionalPixelMove.composite(source: source, maskAlpha: mask, width: size, height: size,
                                                delta: delta, into: &output)
        return output
        #endif
    }

    private static func pixels(size: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        for pixel in 0..<(size * size) {
            let alpha = UInt8(64 + pixel % 192)
            bytes[pixel * 4] = alpha
            bytes[pixel * 4 + 1] = alpha / 2
            bytes[pixel * 4 + 2] = alpha / 3
            bytes[pixel * 4 + 3] = alpha
        }
        return bytes
    }

    private static func coverage(size: Int, dense: Bool) -> [UInt8] {
        var mask = [UInt8](repeating: dense ? 255 : 0, count: size * size)
        guard !dense else { return mask }
        let origin = (size - 64) / 2
        for y in origin..<(origin + 64) {
            for x in origin..<(origin + 64) { mask[y * size + x] = UInt8(32 + (x + y) % 224) }
        }
        return mask
    }

    private static func median(_ values: [Double]) -> Double { values.sorted()[values.count / 2] }
    private enum BenchmarkError: Error { case invalidSize, pixelMismatch }
}
