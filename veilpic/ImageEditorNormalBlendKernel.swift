import Foundation

enum ImageEditorNormalBlendKernel {
    static func composite(base: [UInt8], overlay: [UInt8], opacity: Double) -> [UInt8]? {
        guard !base.isEmpty, base.count == overlay.count, base.count.isMultiple(of: 4),
              opacity.isFinite else { return nil }
        let sourceOpacity = max(0, min(1, opacity))
        guard sourceOpacity > 0 else { return base }
        var output = [UInt8](repeating: 0, count: base.count)
        base.withUnsafeBufferPointer { baseBytes in
            overlay.withUnsafeBufferPointer { overlayBytes in
                output.withUnsafeMutableBufferPointer { target in
                    render(base: baseBytes, overlay: overlayBytes, opacity: sourceOpacity, into: target)
                }
            }
        }
        return output
    }

    private static func render(base: UnsafeBufferPointer<UInt8>, overlay: UnsafeBufferPointer<UInt8>,
                               opacity: Double, into output: UnsafeMutableBufferPointer<UInt8>) {
        // Equal, complete RGBA buffers are validated before entering the loop.
        for offset in stride(from: 0, to: base.count, by: 4) {
            let baseAlphaByte = base[offset + 3], overlayAlphaByte = overlay[offset + 3]
            if overlayAlphaByte == 0 {
                copyClampedPixel(base, offset: offset, into: output)
            } else if opacity == 1 && (baseAlphaByte == 0 || overlayAlphaByte == 255) {
                copyClampedPixel(overlay, offset: offset, into: output)
            } else {
                compositeTranslucentPixel(base: base, overlay: overlay, offset: offset,
                    opacity: opacity, into: output)
            }
        }
    }

    private static func copyClampedPixel(_ source: UnsafeBufferPointer<UInt8>, offset: Int,
                                         into output: UnsafeMutableBufferPointer<UInt8>) {
        let alpha = source[offset + 3]
        for channel in 0..<3 { output[offset + channel] = min(source[offset + channel], alpha) }
        output[offset + 3] = alpha
    }

    private static func compositeTranslucentPixel(base: UnsafeBufferPointer<UInt8>,
        overlay: UnsafeBufferPointer<UInt8>, offset: Int, opacity: Double,
        into output: UnsafeMutableBufferPointer<UInt8>) {
        let baseAlpha = Double(base[offset + 3]) / 255
        let originalOverlayAlpha = Double(overlay[offset + 3]) / 255
        let overlayAlpha = originalOverlayAlpha * opacity
        let outputAlpha = overlayAlpha + baseAlpha * (1 - overlayAlpha)
        for channel in 0..<3 {
            let baseColor = unpremultiplied(base[offset + channel], alpha: baseAlpha)
            let overlayColor = unpremultiplied(overlay[offset + channel], alpha: originalOverlayAlpha)
            // Retain rc1707's operation grouping and rounding for partial alpha.
            let color = overlayAlpha * ((1 - baseAlpha) * overlayColor + baseAlpha * overlayColor)
                + baseAlpha * baseColor * (1 - overlayAlpha)
            output[offset + channel] = byte(color)
        }
        output[offset + 3] = byte(outputAlpha)
    }

    private static func unpremultiplied(_ value: UInt8, alpha: Double) -> Double {
        guard alpha > 0 else { return 0 }
        return max(0, min(1, Double(value) / 255 / alpha))
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, (value * 255).rounded())))
    }
}
