import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorNormalBlendKernelTests {
    @Test(arguments: [0.0, 0.1, 1.0 / 3, 0.5, 0.7, 255.0 / 256, 1.0])
    func allAlphaPairsMatchFrozenEquationsIncludingNoncanonicalColors(opacity: Double) throws {
        var base: [UInt8] = [], overlay: [UInt8] = []
        for baseAlpha in 0...255 {
            for overlayAlpha in 0...255 {
                base += [UInt8(baseAlpha), UInt8(baseAlpha / 2), 255, UInt8(baseAlpha)]
                overlay += [UInt8(overlayAlpha / 2), 255, UInt8(baseAlpha ^ overlayAlpha), UInt8(overlayAlpha)]
            }
        }
        #expect(try #require(ImageEditorNormalBlendKernel.composite(base: base, overlay: overlay, opacity: opacity))
            == ImageEditorNormalBlendReference.composite(base: base, overlay: overlay, opacity: opacity))
    }

    @Test(arguments: [0.13, 0.5, 1.0])
    func everyColorByteMatchesAtSoftAndOpaqueAlphaExtremes(opacity: Double) throws {
        var base: [UInt8] = [], overlay: [UInt8] = []
        for baseAlpha in [0, 1, 127, 255] { for overlayAlpha in [0, 1, 254, 255] { for color in 0...255 {
            base += [UInt8(color), UInt8(255 - color), UInt8(baseAlpha / 2), UInt8(baseAlpha)]
            overlay += [UInt8(255 - color), UInt8(color), UInt8(overlayAlpha / 2), UInt8(overlayAlpha)]
        } } }
        #expect(try #require(ImageEditorNormalBlendKernel.composite(base: base, overlay: overlay, opacity: opacity))
            == ImageEditorNormalBlendReference.composite(base: base, overlay: overlay, opacity: opacity))
    }

    @Test(arguments: [0.0, 0.2, 0.5, 1.0])
    func nativeImageEntryMatchesFrozenPixelsAndRowDirection(opacity: Double) throws {
        let size = CGSize(width: 17, height: 11)
        let base = try image(size: size, seed: 1)
        let overlay = try image(size: size, seed: 7)
        let baseBytes = try pixels(base), overlayBytes = try pixels(overlay)
        let expected = try image(size: size, bytes: ImageEditorNormalBlendReference.composite(
            base: baseBytes, overlay: overlayBytes, opacity: opacity))
        let actual = try #require(base.blended(with: overlay, mode: .normal, opacity: opacity))
        #expect(actual.size == size)
        #expect(try pixels(actual) == pixels(expected))
        #expect(try pixels(base) == baseBytes && pixels(overlay) == overlayBytes)
    }

    @Test func zeroOpacityAndClampedOpacityDoNotMutateSourceBuffers() throws {
        let base: [UInt8] = [200, 100, 50, 0, 70, 50, 40, 127]
        let overlay: [UInt8] = [20, 30, 40, 128, 60, 70, 80, 255]
        #expect(ImageEditorNormalBlendKernel.composite(base: base, overlay: overlay, opacity: -1) == base)
        #expect(try #require(ImageEditorNormalBlendKernel.composite(base: base, overlay: overlay, opacity: 2))
            == ImageEditorNormalBlendReference.composite(base: base, overlay: overlay, opacity: 2))
        #expect(base == [200, 100, 50, 0, 70, 50, 40, 127])
        #expect(overlay == [20, 30, 40, 128, 60, 70, 80, 255])
    }

    @Test func malformedBuffersAndNonfiniteOpacityReject() {
        for (base, overlay) in [([UInt8](), [UInt8]()), ([1, 2, 3], [4, 5, 6]), ([1, 2, 3, 4], [1, 2])] {
            #expect(ImageEditorNormalBlendKernel.composite(base: base, overlay: overlay, opacity: 1) == nil)
        }
        for opacity in [Double.nan, .infinity, -.infinity] {
            #expect(ImageEditorNormalBlendKernel.composite(base: [1, 2, 3, 4], overlay: [1, 2, 3, 4], opacity: opacity) == nil)
        }
    }

    private func image(size: CGSize, seed: Int) throws -> NSImage {
        var bytes: [UInt8] = []
        for pixel in 0..<(Int(size.width) * Int(size.height)) {
            let alpha = UInt8((pixel * seed * 13) % 256)
            bytes += [min(alpha, UInt8(pixel % 256)), alpha / 2, min(alpha, UInt8((pixel * 7) % 256)), alpha]
        }
        return try image(size: size, bytes: bytes)
    }

    private func image(size: CGSize, bytes: [UInt8]) throws -> NSImage {
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        let cgImage = try #require(CGImage(width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        return NSImage(cgImage: cgImage, size: size)
    }

    private func pixels(_ image: NSImage) throws -> [UInt8] {
        let width = Int(image.size.width), height = Int(image.size.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let cgImage = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let context = try #require(CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
        return bytes
    }
}
