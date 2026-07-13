//
//  ImageEditorTextBoxGeometry.swift
//  veilpic
//
//  Created by Codex on 2026/7/13.
//

import CoreGraphics

enum ImageEditorTextBoxGeometry {
    static let minimumViewDrag: CGFloat = 6
    static let minimumFrameDimension = ImageEditorTextContent.drawingPadding * 2 + 1
    static let maximumFrameDimension = ImageEditorTextContent.maximumBoxDimension
        + ImageEditorTextContent.drawingPadding * 2

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
        guard rect.width >= minimumFrameDimension,
              rect.height >= minimumFrameDimension
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

    static func normalizedResizeFrame(
        _ targetFrame: CGRect,
        originalFrame: CGRect,
        handle: ImageEditorLayerResizeHandle
    ) -> CGRect {
        let original = originalFrame.standardized
        let target = targetFrame.standardized
        let width = max(minimumFrameDimension, min(maximumFrameDimension, ceil(target.width)))
        let height = max(minimumFrameDimension, min(maximumFrameDimension, ceil(target.height)))

        let x: CGFloat
        switch handle {
        case .topLeft, .left, .bottomLeft:
            x = original.maxX - width
        case .top, .topRight, .right, .bottom, .bottomRight:
            x = original.minX
        }

        let y: CGFloat
        switch handle {
        case .topLeft, .top, .topRight, .left, .right:
            y = original.minY
        case .bottomLeft, .bottom, .bottomRight:
            y = original.maxY - height
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
