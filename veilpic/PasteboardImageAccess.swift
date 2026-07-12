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
