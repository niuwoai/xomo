import AppKit

extension NSPasteboard {
    func readImage() -> NSImage? {
        if let image = readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            return image
        }

        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = data(forType: type), let image = NSImage(data: data) {
                return image
            }
        }

        return nil
    }
}
