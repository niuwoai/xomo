import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPixelMoveMaskAlphaTests {
    @Test(arguments: [CGImageAlphaInfo.premultipliedFirst, .premultipliedLast],
          [CGBitmapInfo.byteOrderDefault, .byteOrder32Big, .byteOrder32Little])
    func byteOrderAndPaddedRowsMatchPreviousRGBAConversion(info: CGImageAlphaInfo, order: CGBitmapInfo) throws {
        let width = 19, height = 17, rowBytes = width * 4 + 12
        let isLast = info == .premultipliedLast
        let offset = order == .byteOrder32Little ? (isLast ? 0 : 3) : (isLast ? 3 : 0)
        var bytes = [UInt8](repeating: 0, count: rowBytes * height)
        var expected: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                let alpha = UInt8((y * width + x) % 256)
                expected.append(alpha)
                for channel in 0..<4 { bytes[y * rowBytes + x * 4 + channel] = channel == offset ? alpha : alpha / 2 }
            }
            for padding in width * 4..<rowBytes { bytes[y * rowBytes + padding] = 231 }
        }
        let bitmap = try makeBitmap(bytes: bytes, width: width, height: height, rowBytes: rowBytes,
                                    info: info, order: order)
        let image = NSImage(cgImage: bitmap, size: CGSize(width: width, height: height))
        #expect(ImageEditorPixelMoveMaskAlpha.storedAlpha(from: bitmap, width: width, height: height) == expected)
        #expect(try previousAlpha(image, width: width, height: height) == expected)
        #expect(ImageEditorPixelMoveMaskAlpha.read(from: image, width: width, height: height) == expected)
    }

    @Test(arguments: [0.0, 1.0, 3.25])
    func renderedSoftCoverageAndFeatherUseExactDirectAlpha(radius: CGFloat) throws {
        let size = CGSize(width: 31, height: 23)
        let mask = try #require(NSImage.rendered(size: size) { _ in
            for y in 0..<23 { for x in 0..<31 {
                NSColor.white.withAlphaComponent(CGFloat((y * 31 + x) % 256) / 255).setFill()
                CGRect(x: x, y: y, width: 1, height: 1).fill()
            } }
        })
        let image = radius > 0 ? try #require(mask.blurred(radius: radius)) : mask
        let bitmap = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let stored = try #require(ImageEditorPixelMoveMaskAlpha.storedAlpha(from: bitmap, width: 31, height: 23))
        #expect(stored == (try previousAlpha(image, width: 31, height: 23)))
        #expect(ImageEditorPixelMoveMaskAlpha.read(from: image, width: 31, height: 23) == stored)
    }

    @Test func resizingAndGrayBitmapKeepOriginalRenderingFallback() throws {
        let width = 9, height = 7
        let bytes = (0..<width * height).map { UInt8($0 * 4) }
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        let bitmap = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [], provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let image = NSImage(cgImage: bitmap, size: CGSize(width: width, height: height))
        #expect(ImageEditorPixelMoveMaskAlpha.storedAlpha(from: bitmap, width: width, height: height) == nil)
        #expect(ImageEditorPixelMoveMaskAlpha.read(from: image, width: width, height: height)
            == (try previousAlpha(image, width: width, height: height)))
        let rgba = try makeBitmap(bytes: Array(repeating: [UInt8](arrayLiteral: 16, 32, 64, 128), count: 63).flatMap { $0 },
            width: width, height: height, rowBytes: width * 4, info: .premultipliedLast, order: .byteOrderDefault)
        let colored = NSImage(cgImage: rgba, size: image.size)
        #expect(ImageEditorPixelMoveMaskAlpha.storedAlpha(from: rgba, width: 13, height: 11) == nil)
        #expect(ImageEditorPixelMoveMaskAlpha.read(from: colored, width: 13, height: 11)
            == (try previousAlpha(colored, width: 13, height: 11)))
    }

    @Test func unsupportedStraightAlphaAndDecodeUseFallbackWithoutChangingInput() throws {
        let bytes: [UInt8] = [255, 90, 20, 1, 0, 255, 100, 128, 90, 10, 255, 254]
        let bitmap = try makeBitmap(bytes: bytes, width: 3, height: 1, rowBytes: 12,
                                    info: .last, order: .byteOrderDefault)
        let image = NSImage(cgImage: bitmap, size: CGSize(width: 3, height: 1))
        #expect(ImageEditorPixelMoveMaskAlpha.storedAlpha(from: bitmap, width: 3, height: 1) == nil)
        #expect(ImageEditorPixelMoveMaskAlpha.read(from: image, width: 3, height: 1)
            == (try previousAlpha(image, width: 3, height: 1)))
        let decoded = try makeBitmap(bytes: [64, 0, 0, 64], width: 1, height: 1, rowBytes: 4,
                                     info: .premultipliedLast, order: .byteOrderDefault,
                                     decode: [0, 0.5, 0, 1, 0, 1])
        #expect(ImageEditorPixelMoveMaskAlpha.storedAlpha(from: decoded, width: 1, height: 1) == nil)
        let decodedImage = NSImage(cgImage: decoded, size: CGSize(width: 1, height: 1))
        #expect(ImageEditorPixelMoveMaskAlpha.read(from: decodedImage, width: 1, height: 1)
            == (try previousAlpha(decodedImage, width: 1, height: 1)))
        #expect(Array(try #require(bitmap.dataProvider?.data) as Data) == bytes)
    }

    @Test func invalidDimensionsRejectBeforeAllocation() throws {
        let image = NSImage.opaqueMask(size: CGSize(width: 1, height: 1))
        for size in [(0, 1), (1, 0), (-1, 1), (Int.max, Int.max), (Int.max, 1), (1, Int.max)] {
            #expect(ImageEditorPixelMoveMaskAlpha.read(from: image, width: size.0, height: size.1) == nil)
        }
    }

    private func previousAlpha(_ image: NSImage, width: Int, height: Int) throws -> [UInt8] {
        let bytes = try #require(imageEditorRGBABytes(image, width: width, height: height))
        return stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
    }

    private func makeBitmap(bytes: [UInt8], width: Int, height: Int, rowBytes: Int,
                            info: CGImageAlphaInfo, order: CGBitmapInfo, decode: [CGFloat]? = nil) throws -> CGImage {
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        let flags = CGBitmapInfo(rawValue: info.rawValue).union(order)
        return try (decode ?? []).withUnsafeBufferPointer { values in
            try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: rowBytes, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: flags,
                provider: provider, decode: decode == nil ? nil : values.baseAddress,
                shouldInterpolate: false, intent: .defaultIntent))
        }
    }
}
