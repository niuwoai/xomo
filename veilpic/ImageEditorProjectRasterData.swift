import AppKit

/// Project rasters are already encoded bitmaps. Redrawing them during loading
/// can resample fractional logical sizes and change the saved pixels or alpha.
enum ImageEditorProjectRasterData {
    static func decodedImage(_ data: Data) -> NSImage? {
        guard let bitmap = NSBitmapImageRep(data: data),
              bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0,
              bitmap.size.width.isFinite, bitmap.size.height.isFinite,
              bitmap.size.width > 0, bitmap.size.height > 0 else { return nil }
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }
}
