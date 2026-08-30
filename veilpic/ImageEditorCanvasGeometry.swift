//
//  ImageEditorCanvasGeometry.swift
//  veilpic
//
//  Created by Codex on 2026/7/10.
//

import CoreGraphics
import Foundation

enum ImageEditorCropHandle: String, CaseIterable, Identifiable {
    case move
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var id: String { rawValue }

    var isResizeHandle: Bool { self != .move }

    static var resizeHandles: [Self] {
        allCases.filter(\.isResizeHandle)
    }

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .move:
            CGPoint(x: rect.midX, y: rect.midY)
        case .topLeft:
            CGPoint(x: rect.minX, y: rect.minY)
        case .top:
            CGPoint(x: rect.midX, y: rect.minY)
        case .topRight:
            CGPoint(x: rect.maxX, y: rect.minY)
        case .right:
            CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight:
            CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom:
            CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft:
            CGPoint(x: rect.minX, y: rect.maxY)
        case .left:
            CGPoint(x: rect.minX, y: rect.midY)
        }
    }
}

nonisolated struct ImageEditorCropGuideSegment: Equatable {
    let start: CGPoint
    let end: CGPoint
}

enum ImageEditorCropGeometry {
    static func shieldRects(
        in canvasBounds: CGRect,
        excluding cropRect: CGRect
    ) -> [CGRect] {
        let canvas = canvasBounds.standardized
        guard canvas.width > 0, canvas.height > 0 else { return [] }

        let crop = canvas.intersection(cropRect.standardized)
        guard !crop.isNull, crop.width > 0, crop.height > 0 else { return [canvas] }

        return [
            CGRect(x: canvas.minX, y: canvas.minY, width: canvas.width, height: crop.minY - canvas.minY),
            CGRect(x: canvas.minX, y: crop.maxY, width: canvas.width, height: canvas.maxY - crop.maxY),
            CGRect(x: canvas.minX, y: crop.minY, width: crop.minX - canvas.minX, height: crop.height),
            CGRect(x: crop.maxX, y: crop.minY, width: canvas.maxX - crop.maxX, height: crop.height)
        ].filter { $0.width > 0 && $0.height > 0 }
    }

    static func ruleOfThirdsSegments(in rect: CGRect) -> [ImageEditorCropGuideSegment] {
        let normalized = rect.standardized
        guard normalized.width > 0, normalized.height > 0 else { return [] }

        let firstX = normalized.minX + normalized.width / 3
        let secondX = normalized.minX + normalized.width * 2 / 3
        let firstY = normalized.minY + normalized.height / 3
        let secondY = normalized.minY + normalized.height * 2 / 3
        return [
            ImageEditorCropGuideSegment(
                start: CGPoint(x: firstX, y: normalized.minY),
                end: CGPoint(x: firstX, y: normalized.maxY)
            ),
            ImageEditorCropGuideSegment(
                start: CGPoint(x: secondX, y: normalized.minY),
                end: CGPoint(x: secondX, y: normalized.maxY)
            ),
            ImageEditorCropGuideSegment(
                start: CGPoint(x: normalized.minX, y: firstY),
                end: CGPoint(x: normalized.maxX, y: firstY)
            ),
            ImageEditorCropGuideSegment(
                start: CGPoint(x: normalized.minX, y: secondY),
                end: CGPoint(x: normalized.maxX, y: secondY)
            )
        ]
    }

    static func hitHandle(
        at point: CGPoint,
        in rect: CGRect,
        tolerance: CGFloat
    ) -> ImageEditorCropHandle? {
        let normalized = rect.standardized
        let safeTolerance = max(1, tolerance)
        guard normalized.width > 0, normalized.height > 0 else { return nil }

        for handle in ImageEditorCropHandle.resizeHandles {
            let handlePoint = handle.point(in: normalized)
            if hypot(point.x - handlePoint.x, point.y - handlePoint.y) <= safeTolerance {
                return handle
            }
        }

        let edgeMatches = [
            (ImageEditorCropHandle.top, abs(point.y - normalized.minY) <= safeTolerance
                && point.x >= normalized.minX - safeTolerance
                && point.x <= normalized.maxX + safeTolerance),
            (ImageEditorCropHandle.right, abs(point.x - normalized.maxX) <= safeTolerance
                && point.y >= normalized.minY - safeTolerance
                && point.y <= normalized.maxY + safeTolerance),
            (ImageEditorCropHandle.bottom, abs(point.y - normalized.maxY) <= safeTolerance
                && point.x >= normalized.minX - safeTolerance
                && point.x <= normalized.maxX + safeTolerance),
            (ImageEditorCropHandle.left, abs(point.x - normalized.minX) <= safeTolerance
                && point.y >= normalized.minY - safeTolerance
                && point.y <= normalized.maxY + safeTolerance)
        ]
        if let match = edgeMatches.first(where: { $0.1 }) {
            return match.0
        }

        return normalized.insetBy(dx: -safeTolerance, dy: -safeTolerance).contains(point)
            ? .move
            : nil
    }

    static func adjustedFrame(
        from originalFrame: CGRect,
        handle: ImageEditorCropHandle,
        delta: CGSize,
        canvasSize: CGSize,
        minimumEdge: CGFloat = 4
    ) -> CGRect {
        let canvasWidth = max(0, canvasSize.width)
        let canvasHeight = max(0, canvasSize.height)
        let canvasBounds = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
        let original = originalFrame.standardized.intersection(canvasBounds)
        guard original.width > 0, original.height > 0 else { return .zero }
        if handle == .move {
            let width = min(original.width, canvasWidth)
            let height = min(original.height, canvasHeight)
            return CGRect(
                x: min(max(original.minX + delta.width, 0), max(0, canvasWidth - width)),
                y: min(max(original.minY + delta.height, 0), max(0, canvasHeight - height)),
                width: width,
                height: height
            )
        }

        let minimumWidth = min(max(1, minimumEdge), canvasWidth)
        let minimumHeight = min(max(1, minimumEdge), canvasHeight)
        var minX = original.minX
        var minY = original.minY
        var maxX = original.maxX
        var maxY = original.maxY

        switch handle {
        case .topLeft, .left, .bottomLeft:
            minX = min(max(original.minX + delta.width, 0), maxX - minimumWidth)
        case .topRight, .right, .bottomRight:
            maxX = max(min(original.maxX + delta.width, canvasWidth), minX + minimumWidth)
        default:
            break
        }
        switch handle {
        case .topLeft, .top, .topRight:
            minY = min(max(original.minY + delta.height, 0), maxY - minimumHeight)
        case .bottomLeft, .bottom, .bottomRight:
            maxY = max(min(original.maxY + delta.height, canvasHeight), minY + minimumHeight)
        default:
            break
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

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

    static func visibleCanvasCenter(
        canvasSize: CGSize,
        viewportSize: CGSize,
        zoom: CGFloat,
        canvasOffset: CGSize
    ) -> CGPoint {
        let canvasCenter = CGPoint(
            x: max(0, canvasSize.width) / 2,
            y: max(0, canvasSize.height) / 2
        )
        guard canvasSize.width > 0,
              canvasSize.height > 0,
              viewportSize.width > 0,
              viewportSize.height > 0,
              zoom.isFinite,
              zoom > 0
        else { return canvasCenter }
        let imageRect = fittedImageRect(
            canvasSize: canvasSize,
            viewportSize: viewportSize,
            zoom: zoom,
            canvasOffset: canvasOffset
        )
        return boundedImagePoint(
            from: CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2),
            imageRect: imageRect,
            canvasSize: canvasSize
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
