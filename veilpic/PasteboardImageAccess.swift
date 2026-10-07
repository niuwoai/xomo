import AppKit
import UniformTypeIdentifiers

extension NSPasteboard {
    func readImage() -> NSImage? {
        if let image = readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            return image
        }

        for type in [NSPasteboard.PasteboardType.png, .tiff, NSPasteboard.PasteboardType("public.jpeg")] {
            if let data = data(forType: type), let image = NSImage(data: data) {
                return image
            }
        }

        let fileURLReadingOptions: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        if let urls = readObjects(forClasses: [NSURL.self], options: fileURLReadingOptions) as? [URL] {
            for url in urls where Self.isSupportedImageFile(url) {
                if let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }

        return nil
    }

    private static func isSupportedImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type == .png || type == .jpeg
    }
}

extension NSImage {
    func normalizedImportedBitmapImage() -> NSImage {
        guard let source = cgImage(forProposedRect: nil, context: nil, hints: nil),
              source.width > 0,
              source.height > 0
        else { return normalizedBitmapImage() }

        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: source.width,
                height: source.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: sRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return normalizedBitmapImage() }
        context.interpolationQuality = .none
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        guard let normalized = context.makeImage() else { return normalizedBitmapImage() }

        let pixelSize = CGSize(width: source.width, height: source.height)
        return NSImage(cgImage: normalized, size: pixelSize)
    }
}
