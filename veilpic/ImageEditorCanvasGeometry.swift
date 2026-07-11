//
//  ImageEditorCanvasGeometry.swift
//  veilpic
//
//  Created by Codex on 2026/7/10.
//

import CoreGraphics
import Foundation

enum ImageEditorCanvasGeometry {
    static func fittedImageRect(
        canvasSize: CGSize,
        viewportSize: CGSize,
        zoom: CGFloat,
        canvasOffset: CGSize
    ) -> CGRect {
        let baseScale = min(
            viewportSize.width / max(canvasSize.width, 1),
            viewportSize.height / max(canvasSize.height, 1)
        ) * 0.74
        let scale = max(0.01, baseScale * zoom)
        let displaySize = CGSize(
            width: canvasSize.width * scale,
            height: canvasSize.height * scale
        )

        return CGRect(
            x: (viewportSize.width - displaySize.width) / 2 + canvasOffset.width,
            y: (viewportSize.height - displaySize.height) / 2 + canvasOffset.height,
            width: displaySize.width,
            height: displaySize.height
        )
    }

    static func imagePoint(
        from viewPoint: CGPoint,
        imageRect: CGRect,
        canvasSize: CGSize
    ) -> CGPoint? {
        guard imageRect.contains(viewPoint), imageRect.width > 0, imageRect.height > 0 else {
            return nil
        }

        return CGPoint(
            x: (viewPoint.x - imageRect.minX) / imageRect.width * canvasSize.width,
            y: (viewPoint.y - imageRect.minY) / imageRect.height * canvasSize.height
        )
    }

    static func unboundedImagePoint(
        from viewPoint: CGPoint,
        imageRect: CGRect,
        canvasSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: (viewPoint.x - imageRect.minX) / max(imageRect.width, 1) * canvasSize.width,
            y: (viewPoint.y - imageRect.minY) / max(imageRect.height, 1) * canvasSize.height
        )
    }

    static func viewPoint(
        from imagePoint: CGPoint,
        imageRect: CGRect,
        canvasSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: imageRect.minX + imagePoint.x / max(canvasSize.width, 1) * imageRect.width,
            y: imageRect.minY + imagePoint.y / max(canvasSize.height, 1) * imageRect.height
        )
    }

    static func viewRect(
        from canvasRect: CGRect,
        imageRect: CGRect,
        canvasSize: CGSize
    ) -> CGRect {
        let minPoint = viewPoint(
            from: CGPoint(x: canvasRect.minX, y: canvasRect.minY),
            imageRect: imageRect,
            canvasSize: canvasSize
        )
        let maxPoint = viewPoint(
            from: CGPoint(x: canvasRect.maxX, y: canvasRect.maxY),
            imageRect: imageRect,
            canvasSize: canvasSize
        )

        return CGRect(
            x: min(minPoint.x, maxPoint.x),
            y: min(minPoint.y, maxPoint.y),
            width: abs(maxPoint.x - minPoint.x),
            height: abs(maxPoint.y - minPoint.y)
        )
    }
}
