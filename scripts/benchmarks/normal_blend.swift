import Foundation

@main
struct NormalBlendBenchmark {
    static func main() throws {
        let arguments = CommandLine.arguments.dropFirst()
        let sizes = arguments.first!.split(separator: ",").compactMap { Int($0) }
        let iterations = Int(arguments.dropFirst().first!)!
        try verifyAlphaPairs()
        var cases: [[String: Any]] = []
        for size in sizes { for kind in 0..<4 { cases.append(try measure(size: size, kind: kind, iterations: iterations)) } }
        let report: [String: Any] = ["cases": cases, "compiler_optimization": "-O", "alpha_pairs_exact": true,
            "alpha_pairs": 65_536, "alpha_pair_opacities": [0.0, 0.1, 1.0 / 3, 0.5, 0.7, 255.0 / 256, 1.0],
            "scope": "Frozen Normal equations reference vs current kernel, same RGBA; reference loop is not old production control flow. Native baseline measured separately."]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
    }

    private static func verifyAlphaPairs() throws {
        var base: [UInt8] = [], overlay: [UInt8] = []
        for baseAlpha in 0...255 { for overlayAlpha in 0...255 {
            base += [UInt8(baseAlpha), UInt8(baseAlpha / 2), 255, UInt8(baseAlpha)]
            overlay += [UInt8(overlayAlpha / 2), 255, UInt8(baseAlpha ^ overlayAlpha), UInt8(overlayAlpha)]
        } }
        for opacity in [0.0, 0.1, 1.0 / 3, 0.5, 0.7, 255.0 / 256, 1.0] {
            guard ImageEditorNormalBlendKernel.composite(base: base, overlay: overlay, opacity: opacity)
                == ImageEditorNormalBlendReference.composite(base: base, overlay: overlay, opacity: opacity)
            else { throw BenchmarkError.pixelMismatch }
        }
    }

    private static func measure(size: Int, kind: Int, iterations: Int) throws -> [String: Any] {
        let base = pixels(size: size, kind: kind, overlay: false)
        let overlay = pixels(size: size, kind: kind, overlay: true)
        let opacity = kind == 2 ? 0.5 : 1.0
        let expected = ImageEditorNormalBlendReference.composite(base: base, overlay: overlay, opacity: opacity)
        guard ImageEditorNormalBlendKernel.composite(base: base, overlay: overlay, opacity: opacity) == expected
        else { throw BenchmarkError.pixelMismatch }
        var reference: [Double] = [], current: [Double] = []
        for iteration in 0..<iterations {
            for optimized in iteration.isMultiple(of: 2) ? [false, true] : [true, false] {
                let start = ProcessInfo.processInfo.systemUptime
                let output = optimized
                    ? ImageEditorNormalBlendKernel.composite(base: base, overlay: overlay, opacity: opacity)
                    : ImageEditorNormalBlendReference.composite(base: base, overlay: overlay, opacity: opacity)
                let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1_000
                guard output == expected else { throw BenchmarkError.pixelMismatch }
                if optimized { current.append(milliseconds) } else { reference.append(milliseconds) }
            }
        }
        return ["size": size, "case": ["transparent-base", "opaque-overlay", "translucent", "sparse-overlay"][kind],
            "iterations": iterations, "reference_ms": reference, "kernel_ms": current,
            "reference_median_ms": reference.sorted()[iterations / 2], "kernel_median_ms": current.sorted()[iterations / 2],
            "exact_rgba": true]
    }

    private static func pixels(size: Int, kind: Int, overlay: Bool) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for pixel in 0..<(size * size) {
            let alpha: UInt8
            if kind == 0 && !overlay || kind == 3 && overlay && pixel % size >= 64 { alpha = 0 }
            else if kind == 2 { alpha = UInt8(1 + pixel % 254) }
            else { alpha = 255 }
            let offset = pixel * 4
            pixels[offset] = min(alpha, UInt8(pixel % 256))
            pixels[offset + 1] = alpha / 2
            pixels[offset + 2] = min(alpha, UInt8((pixel * 7) % 256))
            pixels[offset + 3] = alpha
        }
        return pixels
    }

    private enum BenchmarkError: Error { case pixelMismatch }
}
