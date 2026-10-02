import Foundation

@main
struct SelectionMaskBoundsBenchmark {
    static func main() throws {
        let arguments = CommandLine.arguments.dropFirst()
        let sizes = arguments.first!.split(separator: ",").compactMap { Int($0) }
        let iterations = Int(arguments.dropFirst().first!)!
        var cases: [[String: Any]] = []
        for size in sizes { for kind in 0..<4 { cases.append(try measure(size: size, kind: kind, iterations: iterations)) } }
        let report: [String: Any] = ["cases": cases, "compiler_optimization": "-O",
            "scope": "One-channel alpha bounds only; excludes rasterization, model updates and UI"]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
    }

    private static func measure(size: Int, kind: Int, iterations: Int) throws -> [String: Any] {
        let inverted = kind == 2
        let alpha = coverage(size: size, kind: kind)
        let expected = components(ImageEditorMaskBoundsReference.bounds(alpha: alpha,
            width: size, height: size, inverted: inverted))
        guard components(ImageEditorSelectionMaskBounds.pixelBounds(alpha: alpha, width: size,
            height: size, inverted: inverted)) == expected else { throw BenchmarkError.boundsMismatch }
        var scalar: [Double] = [], words: [Double] = []
        for iteration in 0..<iterations {
            for useWords in iteration.isMultiple(of: 2) ? [false, true] : [true, false] {
                let start = ProcessInfo.processInfo.systemUptime
                let output = useWords
                    ? ImageEditorSelectionMaskBounds.pixelBounds(alpha: alpha, width: size, height: size, inverted: inverted)
                    : ImageEditorMaskBoundsReference.bounds(alpha: alpha, width: size, height: size, inverted: inverted)
                let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1_000
                guard components(output) == expected else { throw BenchmarkError.boundsMismatch }
                if useWords { words.append(milliseconds) } else { scalar.append(milliseconds) }
            }
        }
        return ["size": size, "coverage": ["dense", "64x64-soft", "inverted-soft", "empty"][kind],
            "iterations": iterations, "scalar_ms": scalar, "word_ms": words,
            "scalar_median_ms": scalar.sorted()[iterations / 2], "word_median_ms": words.sorted()[iterations / 2],
            "exact_bounds": true]
    }

    private static func coverage(size: Int, kind: Int) -> [UInt8] {
        var alpha = [UInt8](repeating: kind == 0 || kind == 2 ? 255 : 0, count: size * size)
        guard kind != 3 else { return alpha }
        let origin = (size - 64) / 2
        let interval = kind == 0 ? 0..<size : origin..<(origin + 64)
        for y in interval { for x in interval { alpha[y * size + x] = UInt8(1 + (x + y) % 254) } }
        return alpha
    }

    private static func components(_ bounds: ImageEditorSelectionMaskBounds.PixelBounds?) -> [Int]? {
        bounds.map { [$0.minX, $0.minY, $0.maxX, $0.maxY] }
    }

    private enum BenchmarkError: Error { case boundsMismatch }
}
