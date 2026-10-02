import AppKit

struct ImageEditorPixelSelectionMoveTransaction {
    let originalDocument: ImageEditorDocument
    let layerID: UUID
    let originalImage: NSImage
    var delta: CGSize = .zero
    var preview: ImageEditorPixelSelectionMovePreview?

    mutating func rememberPreview(layer: ImageEditorLayer, selection: ImageEditorSelection?,
                                  delta: CGSize, feather: CGFloat) {
        self.delta = delta
        preview = ImageEditorPixelSelectionMovePreview(image: layer.image, frame: layer.frame,
                                                       selection: selection, feather: feather)
    }

    func canReusePreview(delta: CGSize, feather: CGFloat, layer: ImageEditorLayer,
                         selection: ImageEditorSelection?, canvasSize: CGSize) -> Bool {
        guard let preview else { return false }
        // Retain only existing immutable preview objects, not an additional
        // bitmap. Verify current content too: an intervening edit invalidates it.
        return self.delta == delta && preview.feather == feather
            && preview.image === layer.image && preview.frame == layer.frame
            && preview.selection == selection && originalDocument.canvasSize == canvasSize
    }
}

struct ImageEditorPixelSelectionMovePreview {
    let image: NSImage
    let frame: CGRect
    let selection: ImageEditorSelection?
    let feather: CGFloat
}
