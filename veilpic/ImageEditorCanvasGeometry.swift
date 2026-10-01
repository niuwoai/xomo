//
//  ImageEditorCanvasGeometry.swift
//  veilpic
//
//  Created by Codex on 2026/7/10.
//

import CoreGraphics
import Foundation

nonisolated enum ImageEditorCropHandle: String, CaseIterable, Identifiable {
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

nonisolated enum ImageEditorCropDoubleClickCommitPolicy {
    private static let clickMovementTolerance: CGFloat = 2

    static func shouldCommit(
        activeHandle: ImageEditorCropHandle?,
        clickCount: Int,
        viewTranslation: CGSize,
        hasConflictingModifiers: Bool
    ) -> Bool {
        guard activeHandle == .move,
              clickCount == 2,
              !hasConflictingModifiers
        else { return false }
        return abs(viewTranslation.width) <= clickMovementTolerance
            && abs(viewTranslation.height) <= clickMovementTolerance
    }
}

nonisolated struct ImageEditorCropGuideSegment: Equatable {
    let start: CGPoint
    let end: CGPoint
}

nonisolated enum ImageEditorCropGuideKind: String, CaseIterable, Identifiable {
    case ruleOfThirds
    case grid
    case diagonal
    case goldenRatio
    case none

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .ruleOfThirds: "imageEditor.cropGuide.ruleOfThirds"
        case .grid: "imageEditor.cropGuide.grid"
        case .diagonal: "imageEditor.cropGuide.diagonal"
        case .goldenRatio: "imageEditor.cropGuide.goldenRatio"
        case .none: "imageEditor.cropGuide.none"
        }
    }

    var next: Self {
        guard let index = Self.allCases.firstIndex(of: self) else { return .ruleOfThirds }
        return Self.allCases[(index + 1) % Self.allCases.count]
    }
}

nonisolated enum ImageEditorCropGuideVisibility: String, CaseIterable, Identifiable {
    case always
    case whileAdjusting
    case never

    var id: String { rawValue }

    var titleKey: String {
        "imageEditor.cropGuide.visibility.\(rawValue)"
    }

    var accessibilityIdentifier: String {
        "image-editor-crop-guide-visibility-\(rawValue)"
    }

    func shouldShow(isAdjusting: Bool) -> Bool {
        switch self {
        case .always: true
        case .whileAdjusting: isAdjusting
        case .never: false
        }
    }
}

nonisolated enum ImageEditorCropShieldOpacityPreset: String, CaseIterable, Identifiable {
    case light
    case standard
    case strong

    var id: String { rawValue }

    var opacity: Double {
        switch self {
        case .light: 0.25
        case .standard: 0.50
        case .strong: 0.75
        }
    }

    var titleKey: String {
        "imageEditor.cropShield.opacity.\(rawValue)"
    }

    var accessibilityIdentifier: String {
        "image-editor-crop-shield-opacity-\(rawValue)"
    }
}

nonisolated enum ImageEditorCropShieldOpacityPolicy {
    static let editingOpacity = 0.18

    static func effectiveOpacity(
        selectedOpacity: Double,
        automaticallyAdjustsWhileEditing: Bool,
        isEditing: Bool
    ) -> Double {
        let clampedOpacity = min(max(selectedOpacity, 0), 1)
        guard automaticallyAdjustsWhileEditing, isEditing else { return clampedOpacity }
        return min(clampedOpacity, editingOpacity)
    }
}

nonisolated enum ImageEditorCropSizeDimension {
    case width
    case height
}

nonisolated enum ImageEditorCropAspectPreset: String, CaseIterable, Identifiable {
    case original
    case square
    case fourFive
    case fiveSeven
    case fourThree
    case threeTwo
    case sixteenNine
    case free

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .original: "imageEditor.cropAspect.original"
        case .square: "imageEditor.cropAspect.square"
        case .fourFive: "imageEditor.cropAspect.fourFive"
        case .fiveSeven: "imageEditor.cropAspect.fiveSeven"
        case .fourThree: "imageEditor.cropAspect.fourThree"
        case .threeTwo: "imageEditor.cropAspect.threeTwo"
        case .sixteenNine: "imageEditor.cropAspect.sixteenNine"
        case .free: "imageEditor.cropAspect.free"
        }
    }

    var accessibilityIdentifier: String {
        "image-editor-crop-aspect-\(rawValue)"
    }

    func components(canvasSize: CGSize) -> CGSize? {
        switch self {
        case .original:
            guard canvasSize.width.isFinite,
                  canvasSize.height.isFinite,
                  canvasSize.width > 0,
                  canvasSize.height > 0
            else { return nil }
            let width = max(1, Int(canvasSize.width.rounded()))
            let height = max(1, Int(canvasSize.height.rounded()))
            let divisor = Self.greatestCommonDivisor(width, height)
            return CGSize(
                width: CGFloat(width / divisor),
                height: CGFloat(height / divisor)
            )
        case .square:
            return CGSize(width: 1, height: 1)
        case .fourFive:
            return CGSize(width: 4, height: 5)
        case .fiveSeven:
            return CGSize(width: 5, height: 7)
        case .fourThree:
            return CGSize(width: 4, height: 3)
        case .threeTwo:
            return CGSize(width: 3, height: 2)
        case .sixteenNine:
            return CGSize(width: 16, height: 9)
        case .free:
            return nil
        }
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return max(1, a)
    }
}

enum ImageEditorCropGeometry {
    static let minimumCommittedPixelEdge: CGFloat = 1

    static func fullCanvasFrame(canvasSize: CGSize) -> CGRect {
        CGRect(
            x: 0,
            y: 0,
            width: max(0, canvasSize.width),
            height: max(0, canvasSize.height)
        ).integral
    }

    static func committedPixelBounds(
        for cropRect: CGRect,
        canvasSize: CGSize
    ) -> CGRect {
        let canvasBounds = CGRect(
            x: 0,
            y: 0,
            width: max(0, canvasSize.width),
            height: max(0, canvasSize.height)
        )
        return cropRect.standardized.intersection(canvasBounds).integral
    }

    static func frameBySettingCommittedOrigin(
        of cropRect: CGRect,
        to targetOrigin: CGPoint,
        canvasSize: CGSize
    ) -> CGRect {
        let currentBounds = committedPixelBounds(for: cropRect, canvasSize: canvasSize)
        guard !currentBounds.isNull,
              currentBounds.width > 0,
              currentBounds.height > 0,
              targetOrigin.x.isFinite,
              targetOrigin.y.isFinite
        else { return cropRect }

        let canvasWidth = max(0, canvasSize.width)
        let canvasHeight = max(0, canvasSize.height)
        return CGRect(
            x: min(max(targetOrigin.x.rounded(), 0), max(0, canvasWidth - currentBounds.width)),
            y: min(max(targetOrigin.y.rounded(), 0), max(0, canvasHeight - currentBounds.height)),
            width: currentBounds.width,
            height: currentBounds.height
        )
    }

    static func frameBySettingCommittedSize(
        of cropRect: CGRect,
        to targetSize: CGSize,
        canvasSize: CGSize,
        minimumEdge: CGFloat = minimumCommittedPixelEdge
    ) -> CGRect {
        let currentBounds = committedPixelBounds(for: cropRect, canvasSize: canvasSize)
        guard !currentBounds.isNull,
              currentBounds.width > 0,
              currentBounds.height > 0,
              targetSize.width.isFinite,
              targetSize.height.isFinite
        else { return cropRect }

        let availableWidth = max(1, max(0, canvasSize.width) - currentBounds.minX)
        let availableHeight = max(1, max(0, canvasSize.height) - currentBounds.minY)
        let minimumWidth = min(max(1, minimumEdge), availableWidth)
        let minimumHeight = min(max(1, minimumEdge), availableHeight)
        return CGRect(
            x: currentBounds.minX,
            y: currentBounds.minY,
            width: min(max(targetSize.width.rounded(), minimumWidth), availableWidth),
            height: min(max(targetSize.height.rounded(), minimumHeight), availableHeight)
        )
    }

    static func frameBySwappingCommittedDimensions(
        of cropRect: CGRect,
        canvasSize: CGSize
    ) -> CGRect {
        let currentBounds = committedPixelBounds(for: cropRect, canvasSize: canvasSize)
        let canvasWidth = max(0, canvasSize.width)
        let canvasHeight = max(0, canvasSize.height)
        guard !currentBounds.isNull,
              currentBounds.width > 0,
              currentBounds.height > 0,
              canvasWidth > 0,
              canvasHeight > 0
        else { return cropRect }

        let targetWidth = currentBounds.height
        let targetHeight = currentBounds.width
        let fittingScale = min(1, min(canvasWidth / targetWidth, canvasHeight / targetHeight))
        let width = min(canvasWidth, max(1, (targetWidth * fittingScale).rounded(.down)))
        let height = min(canvasHeight, max(1, (targetHeight * fittingScale).rounded(.down)))
        let centeredX = (currentBounds.midX - width / 2).rounded()
        let centeredY = (currentBounds.midY - height / 2).rounded()
        return CGRect(
            x: min(max(centeredX, 0), canvasWidth - width),
            y: min(max(centeredY, 0), canvasHeight - height),
            width: width,
            height: height
        )
    }

    static func frameByApplyingAspectRatio(
        of cropRect: CGRect,
        components: CGSize,
        canvasSize: CGSize
    ) -> CGRect {
        let currentBounds = committedPixelBounds(for: cropRect, canvasSize: canvasSize)
        guard !currentBounds.isNull,
              currentBounds.width > 0,
              currentBounds.height > 0,
              components.width.isFinite,
              components.height.isFinite,
              components.width > 0,
              components.height > 0
        else { return cropRect }

        let exactScale = floor(min(
            currentBounds.width / components.width,
            currentBounds.height / components.height
        ))
        let width: CGFloat
        let height: CGFloat
        if exactScale >= 1 {
            width = components.width * exactScale
            height = components.height * exactScale
        } else {
            let aspectRatio = components.width / components.height
            if currentBounds.width / currentBounds.height > aspectRatio {
                height = currentBounds.height
                width = max(1, (height * aspectRatio).rounded(.down))
            } else {
                width = currentBounds.width
                height = max(1, (width / aspectRatio).rounded(.down))
            }
        }

        let canvasWidth = max(0, canvasSize.width)
        let canvasHeight = max(0, canvasSize.height)
        let centeredX = (currentBounds.midX - width / 2).rounded()
        let centeredY = (currentBounds.midY - height / 2).rounded()
        return CGRect(
            x: min(max(centeredX, 0), max(0, canvasWidth - width)),
            y: min(max(centeredY, 0), max(0, canvasHeight - height)),
            width: width,
            height: height
        )
    }

    static func frameBySettingCommittedDimension(
        of cropRect: CGRect,
        dimension: ImageEditorCropSizeDimension,
        value: CGFloat,
        canvasSize: CGSize,
        preservesAspectRatio: Bool,
        minimumEdge: CGFloat = minimumCommittedPixelEdge
    ) -> CGRect {
        let currentBounds = committedPixelBounds(for: cropRect, canvasSize: canvasSize)
        guard !currentBounds.isNull,
              currentBounds.width > 0,
              currentBounds.height > 0,
              value.isFinite
        else { return cropRect }

        guard preservesAspectRatio else {
            let targetSize = switch dimension {
            case .width: CGSize(width: value, height: currentBounds.height)
            case .height: CGSize(width: currentBounds.width, height: value)
            }
            return frameBySettingCommittedSize(
                of: currentBounds,
                to: targetSize,
                canvasSize: canvasSize,
                minimumEdge: minimumEdge
            )
        }

        let availableWidth = max(1, max(0, canvasSize.width) - currentBounds.minX)
        let availableHeight = max(1, max(0, canvasSize.height) - currentBounds.minY)
        let minimumWidth = min(max(1, minimumEdge), availableWidth)
        let minimumHeight = min(max(1, minimumEdge), availableHeight)
        let aspectRatio = currentBounds.width / currentBounds.height
        var width: CGFloat
        var height: CGFloat
        switch dimension {
        case .width:
            width = min(max(value.rounded(), minimumWidth), availableWidth)
            height = max(minimumHeight, (width / aspectRatio).rounded())
        case .height:
            height = min(max(value.rounded(), minimumHeight), availableHeight)
            width = max(minimumWidth, (height * aspectRatio).rounded())
        }
        if height > availableHeight {
            height = availableHeight
            width = max(minimumWidth, (height * aspectRatio).rounded())
        }
        if width > availableWidth {
            width = availableWidth
            height = max(minimumHeight, (width / aspectRatio).rounded())
        }
        return CGRect(
            x: currentBounds.minX,
            y: currentBounds.minY,
            width: min(width, availableWidth),
            height: min(height, availableHeight)
        )
    }

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
        compositionGuideSegments(for: .ruleOfThirds, in: rect)
    }

    static func compositionGuideSegments(
        for kind: ImageEditorCropGuideKind,
        in rect: CGRect
    ) -> [ImageEditorCropGuideSegment] {
        let normalized = rect.standardized
        guard normalized.width > 0, normalized.height > 0 else { return [] }

        let fractions: [CGFloat]
        switch kind {
        case .ruleOfThirds:
            fractions = [1 / 3, 2 / 3]
        case .grid:
            fractions = [1 / 4, 1 / 2, 3 / 4]
        case .diagonal:
            return diagonalGuideSegments(in: normalized)
        case .goldenRatio:
            fractions = [0.381_966_011_25, 0.618_033_988_75]
        case .none:
            return []
        }

        let vertical = fractions.map { fraction in
            let x = normalized.minX + normalized.width * fraction
            return ImageEditorCropGuideSegment(
                start: CGPoint(x: x, y: normalized.minY),
                end: CGPoint(x: x, y: normalized.maxY)
            )
        }
        let horizontal = fractions.map { fraction in
            let y = normalized.minY + normalized.height * fraction
            return ImageEditorCropGuideSegment(
                start: CGPoint(x: normalized.minX, y: y),
                end: CGPoint(x: normalized.maxX, y: y)
            )
        }
        return vertical + horizontal
    }

    private static func diagonalGuideSegments(in rect: CGRect) -> [ImageEditorCropGuideSegment] {
        let squareSide = min(rect.width, rect.height)
        let cornersAndDirections: [(CGPoint, CGVector)] = [
            (CGPoint(x: rect.minX, y: rect.minY), CGVector(dx: 1, dy: 1)),
            (CGPoint(x: rect.maxX, y: rect.minY), CGVector(dx: -1, dy: 1)),
            (CGPoint(x: rect.maxX, y: rect.maxY), CGVector(dx: -1, dy: -1)),
            (CGPoint(x: rect.minX, y: rect.maxY), CGVector(dx: 1, dy: -1)),
        ]
        let segments = cornersAndDirections.map { corner, direction in
            ImageEditorCropGuideSegment(
                start: corner,
                end: CGPoint(
                    x: corner.x + direction.dx * squareSide,
                    y: corner.y + direction.dy * squareSide
                )
            )
        }
        return rect.width == rect.height ? Array(segments.prefix(2)) : segments
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
        preservesAspectRatio: Bool = false,
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

        let unconstrained = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        guard preservesAspectRatio else { return unconstrained }

        let aspectRatio = original.width / original.height
        let minimumScale = max(minimumHeight, minimumWidth / aspectRatio)
        switch handle {
        case .topLeft, .topRight, .bottomRight, .bottomLeft:
            let anchorX = handle == .topLeft || handle == .bottomLeft
                ? original.maxX
                : original.minX
            let anchorY = handle == .topLeft || handle == .topRight
                ? original.maxY
                : original.minY
            let maximumWidth = handle == .topLeft || handle == .bottomLeft
                ? anchorX
                : canvasWidth - anchorX
            let maximumHeight = handle == .topLeft || handle == .topRight
                ? anchorY
                : canvasHeight - anchorY
            let maximumScale = min(maximumWidth / aspectRatio, maximumHeight)
            let projectedScale = (
                unconstrained.width * aspectRatio + unconstrained.height
            ) / (aspectRatio * aspectRatio + 1)
            let scale = min(max(projectedScale, min(minimumScale, maximumScale)), maximumScale)
            let width = aspectRatio * scale
            let height = scale
            return CGRect(
                x: handle == .topLeft || handle == .bottomLeft ? anchorX - width : anchorX,
                y: handle == .topLeft || handle == .topRight ? anchorY - height : anchorY,
                width: width,
                height: height
            )
        case .left, .right:
            let anchorX = handle == .left ? original.maxX : original.minX
            let maximumWidth = handle == .left ? anchorX : canvasWidth - anchorX
            let maximumHeight = 2 * min(original.midY, canvasHeight - original.midY)
            let maximumScale = min(maximumWidth / aspectRatio, maximumHeight)
            let scale = min(
                max(unconstrained.width / aspectRatio, min(minimumScale, maximumScale)),
                maximumScale
            )
            let width = aspectRatio * scale
            return CGRect(
                x: handle == .left ? anchorX - width : anchorX,
                y: original.midY - scale / 2,
                width: width,
                height: scale
            )
        case .top, .bottom:
            let anchorY = handle == .top ? original.maxY : original.minY
            let maximumWidth = 2 * min(original.midX, canvasWidth - original.midX)
            let maximumHeight = handle == .top ? anchorY : canvasHeight - anchorY
            let maximumScale = min(maximumWidth / aspectRatio, maximumHeight)
            let scale = min(
                max(unconstrained.height, min(minimumScale, maximumScale)),
                maximumScale
            )
            let width = aspectRatio * scale
            return CGRect(
                x: original.midX - width / 2,
                y: handle == .top ? anchorY - scale : anchorY,
                width: width,
                height: scale
            )
        case .move:
            return unconstrained
        }
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
