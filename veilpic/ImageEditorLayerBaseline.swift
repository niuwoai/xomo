import AppKit

extension ImageEditorLayer {
    var stackBaselineOffset: CGFloat? {
        guard let textContent else { return nil }
        let sourceHeight = max(1, image.size.height)
        let nativeOffset = min(
            max(textContent.point.y + textContent.font.ascender, 0),
            sourceHeight
        )
        return nativeOffset * max(0, frame.height) / sourceHeight
    }
}
