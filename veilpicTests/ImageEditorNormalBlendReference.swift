// Frozen rc1707 Normal compositor equations; test and benchmark reference only.
enum ImageEditorNormalBlendReference {
    static func composite(base: [UInt8], overlay: [UInt8], opacity: Double) -> [UInt8] {
        let sourceOpacity = max(0, min(1, opacity))
        guard sourceOpacity > 0 else { return base }
        var output = [UInt8](repeating: 0, count: base.count)
        for offset in stride(from: 0, to: base.count, by: 4) {
            let baseAlpha = Double(base[offset + 3]) / 255
            let originalOverlayAlpha = Double(overlay[offset + 3]) / 255
            let overlayAlpha = originalOverlayAlpha * sourceOpacity
            let outputAlpha = overlayAlpha + baseAlpha * (1 - overlayAlpha)
            guard outputAlpha > 0 else { continue }
            for channel in 0..<3 {
                let baseColor = unpremultiplied(base[offset + channel], alpha: baseAlpha)
                let overlayColor = unpremultiplied(overlay[offset + channel], alpha: originalOverlayAlpha)
                let color = overlayAlpha * ((1 - baseAlpha) * overlayColor + baseAlpha * overlayColor)
                    + baseAlpha * baseColor * (1 - overlayAlpha)
                output[offset + channel] = byte(color)
            }
            output[offset + 3] = byte(outputAlpha)
        }
        return output
    }

    private static func unpremultiplied(_ value: UInt8, alpha: Double) -> Double {
        guard alpha > 0 else { return 0 }
        return max(0, min(1, Double(value) / 255 / alpha))
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, (value * 255).rounded())))
    }
}
