import AppKit

/// Coverage is independent of RGB colour conversion. Read supported, exact-size
/// bitmap alpha without rendering another full RGBA copy; keep the old rendering
/// path for resized, decoded or nonstandard images.
enum ImageEditorPixelMoveMaskAlpha {
    static func read(from image: NSImage, width: Int, height: Int) -> [UInt8]? {
        guard validSize(width: width, height: height),
              let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        if let alpha = storedAlpha(from: bitmap, width: width, height: height) { return alpha }
        return renderedAlpha(from: bitmap, width: width, height: height)
    }

    static func storedAlpha(from image: CGImage, width: Int, height: Int) -> [UInt8]? {
        guard validSize(width: width, height: height),
              image.width == width, image.height == height,
              image.bitsPerComponent == 8, image.bitsPerPixel == 32,
              image.colorSpace?.model == .rgb, image.decode == nil,
              !image.bitmapInfo.contains(.floatComponents),
              image.bytesPerRow >= width * 4,
              let alphaOffset = alphaOffset(in: image),
              let data = image.dataProvider?.data,
              image.bytesPerRow <= CFDataGetLength(data) / height,
              let bytes = CFDataGetBytePtr(data)
        else { return nil }

        var alpha = [UInt8](repeating: 0, count: width * height)
        for row in 0..<height {
            let sourceRow = row * image.bytesPerRow + alphaOffset
            let targetRow = row * width
            for column in 0..<width { alpha[targetRow + column] = bytes[sourceRow + column * 4] }
        }
        return alpha
    }

    private static func alphaOffset(in image: CGImage) -> Int? {
        let order = image.bitmapInfo.intersection(.byteOrderMask)
        guard order == .byteOrderDefault || order == .byteOrder32Big || order == .byteOrder32Little
        else { return nil }
        let littleEndian = order == .byteOrder32Little
        switch image.alphaInfo {
        case .premultipliedLast: return littleEndian ? 0 : 3
        case .premultipliedFirst: return littleEndian ? 3 : 0
        default: return nil
        }
    }

    private static func validSize(width: Int, height: Int) -> Bool {
        let limit = Int(ImageEditorMaskSampling.maximumPixelCount)
        return width > 0 && height > 0 && width <= limit / height
    }

    private static func renderedAlpha(from image: CGImage, width: Int, height: Int) -> [UInt8]? {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(data: &pixels, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }
}
