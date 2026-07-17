//
//  ImageEditorCanvasGeometry.swift
//  veilpic
//
//  Created by Codex on 2026/7/10.
//

import CoreGraphics
import Foundation

enum ImageEditorCanvasGeometry {
    static func aspectFitRect(contentSize: CGSize, in bounds: CGRect) -> CGRect {
        guard contentSize.width > 0,
              contentSize.height > 0,
              bounds.width > 0,
              bounds.height > 0
        else { return .zero }

        let scale = min(
            bounds.width / contentSize.width,
            bounds.height / contentSize.height
        )
        let size = CGSize(
            width: contentSize.width * scale,
            height: contentSize.height * scale
        )
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    static func navigatorViewportRect(
        canvasSize: CGSize,
        canvasViewportSize: CGSize,
        zoom: CGFloat,
        canvasOffset: CGSize,
        previewBounds: CGRect
    ) -> CGRect? {
        guard canvasSize.width > 0,
              canvasSize.height > 0,
              canvasViewportSize.width > 0,
              canvasViewportSize.height > 0
        else { return nil }

        let canvasRect = fittedImageRect(
            canvasSize: canvasSize,
            viewportSize: canvasViewportSize,
            zoom: zoom,
            canvasOffset: canvasOffset
        )
        let visibleRect = canvasRect.intersection(
            CGRect(origin: .zero, size: canvasViewportSize)
        )
        guard !visibleRect.isNull,
              visibleRect.width > 0,
              visibleRect.height > 0
        else { return nil }

        let thumbnailRect = aspectFitRect(contentSize: canvasSize, in: previewBounds)
        guard thumbnailRect.width > 0, thumbnailRect.height > 0 else { return nil }

        let minX = min(
            max(0, (visibleRect.minX - canvasRect.minX) / canvasRect.width * canvasSize.width),
            canvasSize.width
        )
        let minY = min(
            max(0, (visibleRect.minY - canvasRect.minY) / canvasRect.height * canvasSize.height),
            canvasSize.height
        )
        let maxX = min(
            max(0, (visibleRect.maxX - canvasRect.minX) / canvasRect.width * canvasSize.width),
            canvasSize.width
        )
        let maxY = min(
            max(0, (visibleRect.maxY - canvasRect.minY) / canvasRect.height * canvasSize.height),
            canvasSize.height
        )

        return CGRect(
            x: thumbnailRect.minX + minX / canvasSize.width * thumbnailRect.width,
            y: thumbnailRect.minY + minY / canvasSize.height * thumbnailRect.height,
            width: max(1, (maxX - minX) / canvasSize.width * thumbnailRect.width),
            height: max(1, (maxY - minY) / canvasSize.height * thumbnailRect.height)
        )
    }

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

    static func boundedImagePoint(
        from viewPoint: CGPoint,
        imageRect: CGRect,
        canvasSize: CGSize
    ) -> CGPoint {
        let point = unboundedImagePoint(
            from: viewPoint,
            imageRect: imageRect,
            canvasSize: canvasSize
        )
        return boundedCanvasPoint(point, canvasSize: canvasSize)
    }

    static func boundedCanvasPoint(_ point: CGPoint, canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(0, point.x), max(0, canvasSize.width)),
            y: min(max(0, point.y), max(0, canvasSize.height))
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
