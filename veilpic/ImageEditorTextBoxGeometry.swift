//
//  ImageEditorTextBoxGeometry.swift
//  veilpic
//
//  Created by Codex on 2026/7/13.
//

import CoreGraphics

enum ImageEditorTextBoxGeometry {
    static let minimumViewDrag: CGFloat = 6

    static func paragraphRect(
        from start: CGPoint?,
        to end: CGPoint?,
        viewTranslation: CGSize
    ) -> CGRect? {
        guard abs(viewTranslation.width) >= minimumViewDrag,
              abs(viewTranslation.height) >= minimumViewDrag,
              let start,
              let end
        else { return nil }

        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        let minimumCanvasDimension = ImageEditorTextContent.drawingPadding * 2 + 1
        guard rect.width >= minimumCanvasDimension,
              rect.height >= minimumCanvasDimension
        else { return nil }
        return rect
    }

    static func contentSize(for paragraphRect: CGRect) -> CGSize {
        let padding = ImageEditorTextContent.drawingPadding * 2
        return CGSize(
            width: max(1, paragraphRect.width - padding),
            height: max(1, paragraphRect.height - padding)
        )
    }
}
