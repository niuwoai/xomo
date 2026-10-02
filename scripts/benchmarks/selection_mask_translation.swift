import Foundation
import CoreGraphics

@main
struct SelectionMaskTranslationBenchmark {
    static func main() throws {
        let arguments = CommandLine.arguments.dropFirst()
        let sizes = arguments.first!.split(separator: ",").compactMap { Int($0) }
        let iterations = Int(arguments.dropFirst().first!)!
        var cases: [[String: Any]] = []
        for size in sizes { for dense in [false, true] { cases.append(try measure(size: size, dense: dense, iterations: iterations)) } }
        let report: [String: Any] = ["cases": cases, "compiler_optimization": "-O",
            "scope": "One-channel alpha translation only; excludes rasterization, bounds scanning, model updates and UI"]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
    }

    private static func measure(size: Int, dense: Bool, iterations: Int) throws -> [String: Any] {
        let alpha = coverage(size: size, dense: dense)
        let canvas = CGSize(width: size * 2, height: size * 2)
        let delta = CGSize(width: 2, height: -1)
        let expected = ImageEditorMaskTranslationReference.translated(alpha: alpha, width: size, height: size,
                                                                      delta: delta, canvasSize: canvas)
        guard ImageEditorSelectionMaskTranslation.translated(alpha: alpha, width: size, height: size,
            delta: delta, canvasSize: canvas) == expected else { throw BenchmarkError.pixelMismatch }
        var scalar: [Double] = [], rows: [Double] = []
        for iteration in 0..<iterations {
            for useRows in iteration.isMultiple(of: 2) ? [false, true] : [true, false] {
                let start = ProcessInfo.processInfo.systemUptime
                let output = useRows
                    ? ImageEditorSelectionMaskTranslation.translated(alpha: alpha, width: size, height: size, delta: delta, canvasSize: canvas)
                    : ImageEditorMaskTranslationReference.translated(alpha: alpha, width: size, height: size, delta: delta, canvasSize: canvas)
                let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1_000
                guard output == expected else { throw BenchmarkError.pixelMismatch }
                if useRows { rows.append(milliseconds) } else { scalar.append(milliseconds) }
            }
        }
        return ["size": size, "coverage": dense ? "dense" : "64x64-soft", "iterations": iterations,
                "scalar_ms": scalar, "row_copy_ms": rows, "scalar_median_ms": scalar.sorted()[iterations / 2],
                "row_copy_median_ms": rows.sorted()[iterations / 2], "exact_alpha": true]
    }

    private static func coverage(size: Int, dense: Bool) -> [UInt8] {
        var alpha = [UInt8](repeating: dense ? 255 : 0, count: size * size)
        let origin = (size - 64) / 2
        let interval = dense ? 0..<size : origin..<(origin + 64)
        for y in interval { for x in interval { alpha[y * size + x] = UInt8(1 + (x + y) % 254) } }
        return alpha
    }

    private enum BenchmarkError: Error { case pixelMismatch }
}
