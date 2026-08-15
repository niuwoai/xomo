//
//  ImageEditorShapeGradientHandles.swift
//  veilpic
//
//  Created by Codex on 2026/7/15.
//

import AppKit
import Foundation

enum ImageEditorShapeGradientHandle: String, CaseIterable, Identifiable {
    case start
    case end

    var id: String { rawValue }
}

struct ImageEditorShapeGradientHandlePoints: Equatable {
    var start: CGPoint
    var end: CGPoint

    func point(for handle: ImageEditorShapeGradientHandle) -> CGPoint {
        handle == .start ? start : end
    }
}

enum ImageEditorShapeRadialGradientHandle: String, CaseIterable, Identifiable {
    case center
    case radius

    var id: String { rawValue }
}

struct ImageEditorShapeRadialGradientCanvasGeometry: Equatable {
    var center: CGPoint
    var radius: CGPoint
    var boundaryRect: CGRect

    func point(for handle: ImageEditorShapeRadialGradientHandle) -> CGPoint {
        handle == .center ? center : radius
    }
}

struct ImageEditorShapeGradientStopHandlePoint: Identifiable, Equatable {
    var index: Int
    var stop: ImageEditorGradientColorStop
    var canvasPoint: CGPoint

    var id: Int { index }
}

struct ImageEditorShapeGradientMidpointHandlePoint: Identifiable, Equatable {
    var lowerStopIndex: Int
    var midpoint: Double
    var canvasPoint: CGPoint

    var id: Int { lowerStopIndex }
}

enum ImageEditorShapeGradientGeometry {
    static let angleSnapStep: CGFloat = 15

    static func displayedEndpointColor(
        gradient: ImageEditorGradientFillContent,
        handle: ImageEditorShapeGradientHandle
    ) -> NSColor {
        let normalizedGradient = gradient.normalized()
        let stops = normalizedGradient.shapeColorStops
        let useLastStop = normalizedGradient.reverse
            ? handle == .start
            : handle == .end
        return (useLastStop ? stops.last : stops.first)?.color ?? .gray
    }

    static func canvasHandlePoints(
        content: ImageEditorShapeContent,
        imageSize: CGSize,
        layerFrame: CGRect
    ) -> ImageEditorShapeGradientHandlePoints? {
        guard let gradient = content.fillGradient?.normalized(),
              gradient.style == .linear,
              imageSize.width > 0,
              imageSize.height > 0,
              layerFrame.width > 0,
              layerFrame.height > 0
        else { return nil }

        let localPoints = localHandlePoints(
            gradient: gradient,
            centerNormalized: content.fillGradientCenter,
            imageSize: imageSize
        )
        return ImageEditorShapeGradientHandlePoints(
            start: canvasPoint(localPoints.start, imageSize: imageSize, layerFrame: layerFrame),
            end: canvasPoint(localPoints.end, imageSize: imageSize, layerFrame: layerFrame)
        )
    }

    static func updatedContent(
        from originalContent: ImageEditorShapeContent,
        imageSize: CGSize,
        layerFrame: CGRect,
        moving handle: ImageEditorShapeGradientHandle,
        to canvasPoint: CGPoint,
        snappingAngle: Bool
    ) -> ImageEditorShapeContent? {
        guard var gradient = originalContent.fillGradient?.normalized(),
              gradient.style == .linear,
              imageSize.width > 0,
              imageSize.height > 0,
              layerFrame.width > 0,
              layerFrame.height > 0
        else { return nil }

        let originalPoints = localHandlePoints(
            gradient: gradient,
            centerNormalized: originalContent.fillGradientCenter,
            imageSize: imageSize
        )
        let draggedPoint = localPoint(canvasPoint, imageSize: imageSize, layerFrame: layerFrame)
        let fixedPoint = handle == .start ? originalPoints.end : originalPoints.start
        var directionVector = handle == .start
            ? CGSize(width: fixedPoint.x - draggedPoint.x, height: fixedPoint.y - draggedPoint.y)
            : CGSize(width: draggedPoint.x - fixedPoint.x, height: draggedPoint.y - fixedPoint.y)
        var length = hypot(directionVector.width, directionVector.height)
        guard length > 0.001 else { return nil }

        var angle = atan2(directionVector.height, directionVector.width) * 180 / .pi
        if snappingAngle {
            angle = (angle / angleSnapStep).rounded() * angleSnapStep
            let radians = angle * .pi / 180
            directionVector = CGSize(width: cos(radians), height: sin(radians))
        } else {
            directionVector = CGSize(
                width: directionVector.width / length,
                height: directionVector.height / length
            )
        }

        let baseSpan = span(angle: angle, imageSize: imageSize)
        length = max(baseSpan * 0.25, min(baseSpan * 4, length))
        let movedPoint = handle == .start
            ? CGPoint(
                x: fixedPoint.x - directionVector.width * length,
                y: fixedPoint.y - directionVector.height * length
            )
            : CGPoint(
                x: fixedPoint.x + directionVector.width * length,
                y: fixedPoint.y + directionVector.height * length
            )
        let center = CGPoint(
            x: (fixedPoint.x + movedPoint.x) / 2,
            y: (fixedPoint.y + movedPoint.y) / 2
        )

        gradient.angle = normalizedAngle(angle)
        gradient.scale = length / baseSpan
        gradient.style = .linear
        var content = originalContent
        content.fillGradient = gradient.normalized()
        content.fillGradientCenter = CGPoint(
            x: center.x / imageSize.width,
            y: center.y / imageSize.height
        )
        return content.normalized(size: imageSize)
    }

    static func radialCanvasGeometry(
        content: ImageEditorShapeContent,
        imageSize: CGSize,
        layerFrame: CGRect
    ) -> ImageEditorShapeRadialGradientCanvasGeometry? {
        guard let gradient = content.fillGradient?.normalized(),
              gradient.style == .radial,
              imageSize.width > 0,
              imageSize.height > 0,
              layerFrame.width > 0,
              layerFrame.height > 0
        else { return nil }

        let localCenter = CGPoint(
            x: content.fillGradientCenter.x * imageSize.width,
            y: content.fillGradientCenter.y * imageSize.height
        )
        let localRadius = radialReferenceRadius(imageSize: imageSize) * gradient.scale
        let center = canvasPoint(localCenter, imageSize: imageSize, layerFrame: layerFrame)
        let radius = canvasPoint(
            CGPoint(x: localCenter.x + localRadius, y: localCenter.y),
            imageSize: imageSize,
            layerFrame: layerFrame
        )
        let verticalBoundary = canvasPoint(
            CGPoint(x: localCenter.x, y: localCenter.y + localRadius),
            imageSize: imageSize,
            layerFrame: layerFrame
        )
        let horizontalRadius = abs(radius.x - center.x)
        let verticalRadius = abs(verticalBoundary.y - center.y)
        return ImageEditorShapeRadialGradientCanvasGeometry(
            center: center,
            radius: radius,
            boundaryRect: CGRect(
                x: center.x - horizontalRadius,
                y: center.y - verticalRadius,
                width: horizontalRadius * 2,
                height: verticalRadius * 2
            )
        )
    }

    static func updatedRadialContent(
        from originalContent: ImageEditorShapeContent,
        imageSize: CGSize,
        layerFrame: CGRect,
        moving handle: ImageEditorShapeRadialGradientHandle,
        to canvasPoint: CGPoint
    ) -> ImageEditorShapeContent? {
        guard var gradient = originalContent.fillGradient?.normalized(),
              gradient.style == .radial,
              imageSize.width > 0,
              imageSize.height > 0,
              layerFrame.width > 0,
              layerFrame.height > 0,
              canvasPoint.x.isFinite,
              canvasPoint.y.isFinite
        else { return nil }

        let draggedPoint = localPoint(canvasPoint, imageSize: imageSize, layerFrame: layerFrame)
        var content = originalContent
        switch handle {
        case .center:
            content.fillGradientCenter = CGPoint(
                x: draggedPoint.x / imageSize.width,
                y: draggedPoint.y / imageSize.height
            )
        case .radius:
            let center = CGPoint(
                x: originalContent.fillGradientCenter.x * imageSize.width,
                y: originalContent.fillGradientCenter.y * imageSize.height
            )
            let radius = hypot(draggedPoint.x - center.x, draggedPoint.y - center.y)
            let referenceRadius = radialReferenceRadius(imageSize: imageSize)
            gradient.scale = max(0.25, min(4, radius / referenceRadius))
            gradient.style = .radial
            content.fillGradient = gradient.normalized()
        }
        return content.normalized(size: imageSize)
    }

    static func canvasStopHandlePoints(
        content: ImageEditorShapeContent,
        imageSize: CGSize,
        layerFrame: CGRect
    ) -> [ImageEditorShapeGradientStopHandlePoint] {
        guard let gradient = content.fillGradient?.normalized(),
              let axis = canvasStopAxis(
                content: content,
                imageSize: imageSize,
                layerFrame: layerFrame
              )
        else { return [] }
        let stops = gradient.shapeColorStops
        guard stops.count > 2 else { return [] }
        return stops.indices.dropFirst().dropLast().map { index in
            let stop = stops[index]
            let displayedPosition = gradient.reverse ? 1 - stop.position : stop.position
            return ImageEditorShapeGradientStopHandlePoint(
                index: index,
                stop: stop,
                canvasPoint: CGPoint(
                    x: axis.start.x + (axis.end.x - axis.start.x) * displayedPosition,
                    y: axis.start.y + (axis.end.y - axis.start.y) * displayedPosition
                )
            )
        }
    }

    static func canvasMidpointHandlePoints(
        content: ImageEditorShapeContent,
        imageSize: CGSize,
        layerFrame: CGRect
    ) -> [ImageEditorShapeGradientMidpointHandlePoint] {
        guard let gradient = content.fillGradient?.normalized(),
              let axis = canvasStopAxis(
                  content: content,
                  imageSize: imageSize,
                  layerFrame: layerFrame
              )
        else { return [] }
        let stops = gradient.shapeColorStops
        guard stops.count >= 2 else { return [] }
        return stops.indices.dropLast().map { index in
            let lower = stops[index]
            let upper = stops[index + 1]
            let logicalPosition = lower.position
                + (upper.position - lower.position) * lower.midpoint
            let displayedPosition = gradient.reverse ? 1 - logicalPosition : logicalPosition
            return ImageEditorShapeGradientMidpointHandlePoint(
                lowerStopIndex: index,
                midpoint: lower.midpoint,
                canvasPoint: CGPoint(
                    x: axis.start.x + (axis.end.x - axis.start.x) * displayedPosition,
                    y: axis.start.y + (axis.end.y - axis.start.y) * displayedPosition
                )
            )
        }
    }

    static func updatedContent(
        from originalContent: ImageEditorShapeContent,
        imageSize: CGSize,
        layerFrame: CGRect,
        movingStopAt index: Int,
        to canvasPoint: CGPoint
    ) -> ImageEditorShapeContent? {
        guard var gradient = originalContent.fillGradient?.normalized(),
              let logicalPosition = logicalStopPosition(
                content: originalContent,
                imageSize: imageSize,
                layerFrame: layerFrame,
                canvasPoint: canvasPoint
              )
        else { return nil }
        var stops = gradient.shapeColorStops
        guard stops.count > 2, index > 0, index < stops.count - 1 else { return nil }
        let lowerBound = stops[index - 1].position + 0.01
        let upperBound = stops[index + 1].position - 0.01
        guard lowerBound <= upperBound else { return nil }
        stops[index].position = max(lowerBound, min(upperBound, logicalPosition))
        gradient.colorStops = stops
        var content = originalContent
        content.fillGradient = gradient.normalized()
        return content.normalized(size: imageSize)
    }

    static func updatedContent(
        from originalContent: ImageEditorShapeContent,
        imageSize: CGSize,
        layerFrame: CGRect,
        movingMidpointAfter lowerStopIndex: Int,
        to canvasPoint: CGPoint
    ) -> ImageEditorShapeContent? {
        guard var gradient = originalContent.fillGradient?.normalized(),
              let logicalPosition = logicalStopPosition(
                  content: originalContent,
                  imageSize: imageSize,
                  layerFrame: layerFrame,
                  canvasPoint: canvasPoint
              )
        else { return nil }
        var stops = gradient.shapeColorStops
        guard stops.indices.contains(lowerStopIndex), lowerStopIndex < stops.count - 1 else {
            return nil
        }
        let lowerPosition = stops[lowerStopIndex].position
        let upperPosition = stops[lowerStopIndex + 1].position
        let distance = upperPosition - lowerPosition
        guard distance > 0.000_001 else { return nil }
        stops[lowerStopIndex].midpoint = max(
            0,
            min(1, (logicalPosition - lowerPosition) / distance)
        )
        gradient.colorStops = stops
        var content = originalContent
        content.fillGradient = gradient.normalized()
        return content.normalized(size: imageSize)
    }

    static func logicalStopPosition(
        content: ImageEditorShapeContent,
        imageSize: CGSize,
        layerFrame: CGRect,
        canvasPoint: CGPoint
    ) -> Double? {
        guard let gradient = content.fillGradient?.normalized(),
              let axis = canvasStopAxis(
                content: content,
                imageSize: imageSize,
                layerFrame: layerFrame
              )
        else { return nil }
        let axisVector = CGVector(dx: axis.end.x - axis.start.x, dy: axis.end.y - axis.start.y)
        let lengthSquared = axisVector.dx * axisVector.dx + axisVector.dy * axisVector.dy
        guard lengthSquared > 0.000_001 else { return nil }
        let pointerVector = CGVector(dx: canvasPoint.x - axis.start.x, dy: canvasPoint.y - axis.start.y)
        var displayedPosition = (
            pointerVector.dx * axisVector.dx + pointerVector.dy * axisVector.dy
        ) / lengthSquared
        displayedPosition = max(0, min(1, displayedPosition))
        return gradient.reverse ? 1 - displayedPosition : displayedPosition
    }

    private static func canvasStopAxis(
        content: ImageEditorShapeContent,
        imageSize: CGSize,
        layerFrame: CGRect
    ) -> ImageEditorShapeGradientHandlePoints? {
        guard let style = content.fillGradient?.normalized().style else { return nil }
        switch style {
        case .linear:
            return canvasHandlePoints(
                content: content,
                imageSize: imageSize,
                layerFrame: layerFrame
            )
        case .radial:
            guard let geometry = radialCanvasGeometry(
                content: content,
                imageSize: imageSize,
                layerFrame: layerFrame
            ) else { return nil }
            return ImageEditorShapeGradientHandlePoints(
                start: geometry.center,
                end: geometry.radius
            )
        default:
            return nil
        }
    }

    private static func localHandlePoints(
        gradient: ImageEditorGradientFillContent,
        centerNormalized: CGPoint,
        imageSize: CGSize
    ) -> ImageEditorShapeGradientHandlePoints {
        let radians = gradient.angle * .pi / 180
        let direction = CGSize(width: cos(radians), height: sin(radians))
        let length = span(angle: gradient.angle, imageSize: imageSize) * gradient.scale
        let center = CGPoint(
            x: centerNormalized.x * imageSize.width,
            y: centerNormalized.y * imageSize.height
        )
        return ImageEditorShapeGradientHandlePoints(
            start: CGPoint(
                x: center.x - direction.width * length / 2,
                y: center.y - direction.height * length / 2
            ),
            end: CGPoint(
                x: center.x + direction.width * length / 2,
                y: center.y + direction.height * length / 2
            )
        )
    }

    private static func span(angle: CGFloat, imageSize: CGSize) -> CGFloat {
        let radians = angle * .pi / 180
        return max(
            1,
            abs(cos(radians)) * imageSize.width + abs(sin(radians)) * imageSize.height
        )
    }

    private static func radialReferenceRadius(imageSize: CGSize) -> CGFloat {
        max(1, hypot(imageSize.width / 2, imageSize.height / 2))
    }

    private static func canvasPoint(
        _ point: CGPoint,
        imageSize: CGSize,
        layerFrame: CGRect
    ) -> CGPoint {
        CGPoint(
            x: layerFrame.minX + point.x / imageSize.width * layerFrame.width,
            y: layerFrame.minY + point.y / imageSize.height * layerFrame.height
        )
    }

    private static func localPoint(
        _ point: CGPoint,
        imageSize: CGSize,
        layerFrame: CGRect
    ) -> CGPoint {
        CGPoint(
            x: (point.x - layerFrame.minX) / layerFrame.width * imageSize.width,
            y: (point.y - layerFrame.minY) / layerFrame.height * imageSize.height
        )
    }

    private static func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        var value = angle.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }
}

@MainActor
extension ImageEditorViewModel {
    var selectedShapeGradientCanvasHandlePoints: ImageEditorShapeGradientHandlePoints? {
        guard !isEditingLayerMask,
              let layer = singleSelectedShapeGradientLayer,
              let content = layer.shapeContent
        else { return nil }
        return ImageEditorShapeGradientGeometry.canvasHandlePoints(
            content: content,
            imageSize: layer.image.size,
            layerFrame: layer.frame.standardized
        )
    }

    var selectedShapeGradientCanvasStopHandlePoints: [ImageEditorShapeGradientStopHandlePoint] {
        guard !isEditingLayerMask,
              let layer = singleSelectedShapeGradientLayer,
              let content = layer.shapeContent
        else { return [] }
        return ImageEditorShapeGradientGeometry.canvasStopHandlePoints(
            content: content,
            imageSize: layer.image.size,
            layerFrame: layer.frame.standardized
        )
    }

    var selectedShapeGradientCanvasMidpointHandlePoints: [ImageEditorShapeGradientMidpointHandlePoint] {
        guard !isEditingLayerMask,
              let layer = singleSelectedShapeGradientLayer,
              let content = layer.shapeContent
        else { return [] }
        return ImageEditorShapeGradientGeometry.canvasMidpointHandlePoints(
            content: content,
            imageSize: layer.image.size,
            layerFrame: layer.frame.standardized
        )
    }

    var selectedShapeRadialGradientCanvasGeometry: ImageEditorShapeRadialGradientCanvasGeometry? {
        guard !isEditingLayerMask,
              let layer = singleSelectedShapeGradientLayer,
              let content = layer.shapeContent
        else { return nil }
        return ImageEditorShapeGradientGeometry.radialCanvasGeometry(
            content: content,
            imageSize: layer.image.size,
            layerFrame: layer.frame.standardized
        )
    }

    var canEditSelectedShapeGradient: Bool {
        guard let layer = singleSelectedShapeGradientLayer,
              layer.shapeContent?.fillGradient?.style == .linear
        else { return false }
        return !document.isEffectivelyPixelsLocked(layer)
    }

    var canEditSelectedShapeRadialGradient: Bool {
        guard let layer = singleSelectedShapeGradientLayer,
              layer.shapeContent?.fillGradient?.style == .radial
        else { return false }
        return !document.isEffectivelyPixelsLocked(layer)
    }

    var canEditSelectedShapeGradientStops: Bool {
        guard let layer = singleSelectedShapeGradientLayer,
              layer.shapeContent?.fillGradient != nil
        else { return false }
        return !document.isEffectivelyPixelsLocked(layer)
    }

    func beginEditingSelectedShapeGradient(handle: ImageEditorShapeGradientHandle) -> Bool {
        guard editingShapeGradientLayerID == nil,
              canEditSelectedShapeGradient,
              let layer = singleSelectedShapeGradientLayer,
              let content = layer.shapeContent
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        _ = handle
        beginShapeGradientUndoTransaction()
        editingShapeGradientLayerID = layer.id
        editingShapeGradientOriginalContent = content
        editingShapeGradientStopIndex = nil
        editingShapeGradientMidpointIndex = nil
        editingShapeGradientDidChange = false
        return true
    }

    func updateSelectedShapeGradient(
        handle: ImageEditorShapeGradientHandle,
        to canvasPoint: CGPoint,
        snappingAngle: Bool
    ) {
        guard let layerID = editingShapeGradientLayerID,
              let originalContent = editingShapeGradientOriginalContent,
              let index = document.layers.firstIndex(where: { $0.id == layerID }),
              let content = ImageEditorShapeGradientGeometry.updatedContent(
                from: originalContent,
                imageSize: document.layers[index].image.size,
                layerFrame: document.layers[index].frame.standardized,
                moving: handle,
                to: canvasPoint,
                snappingAngle: snappingAngle
              )
        else { return }
        guard document.layers[index].shapeContent?.fillGradient != content.fillGradient
                || document.layers[index].shapeContent?.fillGradientCenter != content.fillGradientCenter
        else { return }
        document.layers[index].kind = .shape(content)
        editingShapeGradientDidChange = true
        statusText = L10n.text("imageEditor.status.shapeGradientHandleMoved")
    }

    func beginEditingSelectedShapeRadialGradient(
        handle: ImageEditorShapeRadialGradientHandle
    ) -> Bool {
        guard editingShapeGradientLayerID == nil,
              canEditSelectedShapeRadialGradient,
              let layer = singleSelectedShapeGradientLayer,
              let content = layer.shapeContent
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        _ = handle
        beginShapeGradientUndoTransaction()
        editingShapeGradientLayerID = layer.id
        editingShapeGradientOriginalContent = content
        editingShapeGradientStopIndex = nil
        editingShapeGradientMidpointIndex = nil
        editingShapeGradientDidChange = false
        return true
    }

    func updateSelectedShapeRadialGradient(
        handle: ImageEditorShapeRadialGradientHandle,
        to canvasPoint: CGPoint
    ) {
        guard let layerID = editingShapeGradientLayerID,
              let originalContent = editingShapeGradientOriginalContent,
              let index = document.layers.firstIndex(where: { $0.id == layerID }),
              let content = ImageEditorShapeGradientGeometry.updatedRadialContent(
                from: originalContent,
                imageSize: document.layers[index].image.size,
                layerFrame: document.layers[index].frame.standardized,
                moving: handle,
                to: canvasPoint
              )
        else { return }
        guard document.layers[index].shapeContent?.fillGradient != content.fillGradient
                || document.layers[index].shapeContent?.fillGradientCenter != content.fillGradientCenter
        else { return }
        document.layers[index].kind = .shape(content)
        editingShapeGradientDidChange = true
        statusText = L10n.text("imageEditor.status.shapeGradientHandleMoved")
    }

    func beginEditingSelectedShapeGradientStop(at index: Int) -> Bool {
        guard editingShapeGradientLayerID == nil,
              canEditSelectedShapeGradientStops,
              let layer = singleSelectedShapeGradientLayer,
              let content = layer.shapeContent,
              index > 0,
              index < (content.fillGradient?.shapeColorStops.count ?? 0) - 1
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        beginShapeGradientUndoTransaction()
        editingShapeGradientLayerID = layer.id
        editingShapeGradientOriginalContent = content
        editingShapeGradientStopIndex = index
        editingShapeGradientMidpointIndex = nil
        editingShapeGradientDidChange = false
        return true
    }

    func updateSelectedShapeGradientStop(to canvasPoint: CGPoint) {
        guard let layerID = editingShapeGradientLayerID,
              let stopIndex = editingShapeGradientStopIndex,
              let originalContent = editingShapeGradientOriginalContent,
              let index = document.layers.firstIndex(where: { $0.id == layerID }),
              let content = ImageEditorShapeGradientGeometry.updatedContent(
                from: originalContent,
                imageSize: document.layers[index].image.size,
                layerFrame: document.layers[index].frame.standardized,
                movingStopAt: stopIndex,
                to: canvasPoint
              ),
              document.layers[index].shapeContent?.fillGradient != content.fillGradient
        else { return }
        document.layers[index].kind = .shape(content)
        editingShapeGradientDidChange = true
        statusText = L10n.text("imageEditor.status.shapeGradientStopMoved")
    }

    func updateSelectedShapeGradientStop(toLogicalPosition position: Double) {
        guard position.isFinite,
              let layerID = editingShapeGradientLayerID,
              let stopIndex = editingShapeGradientStopIndex,
              var content = editingShapeGradientOriginalContent,
              var gradient = content.fillGradient,
              let index = document.layers.firstIndex(where: { $0.id == layerID })
        else { return }
        var stops = gradient.shapeColorStops
        guard stops.indices.contains(stopIndex),
              stopIndex > 0,
              stopIndex < stops.count - 1
        else { return }
        let lowerBound = stops[stopIndex - 1].position + 0.01
        let upperBound = stops[stopIndex + 1].position - 0.01
        guard lowerBound <= upperBound else { return }
        stops[stopIndex].position = max(lowerBound, min(upperBound, position))
        gradient.colorStops = stops
        content.fillGradient = gradient.normalized()
        guard document.layers[index].shapeContent?.fillGradient != content.fillGradient else {
            return
        }
        document.layers[index].kind = .shape(content)
        editingShapeGradientDidChange = true
        statusText = L10n.text("imageEditor.status.shapeGradientStopMoved")
    }

    func beginEditingSelectedShapeGradientMidpoint(after lowerStopIndex: Int) -> Bool {
        guard editingShapeGradientLayerID == nil,
              canEditSelectedShapeGradientStops,
              let layer = singleSelectedShapeGradientLayer,
              let content = layer.shapeContent,
              lowerStopIndex >= 0,
              lowerStopIndex < (content.fillGradient?.shapeColorStops.count ?? 0) - 1
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        beginShapeGradientUndoTransaction()
        editingShapeGradientLayerID = layer.id
        editingShapeGradientOriginalContent = content
        editingShapeGradientStopIndex = nil
        editingShapeGradientMidpointIndex = lowerStopIndex
        editingShapeGradientDidChange = false
        return true
    }

    func updateSelectedShapeGradientMidpoint(to canvasPoint: CGPoint) {
        guard let layerID = editingShapeGradientLayerID,
              let lowerStopIndex = editingShapeGradientMidpointIndex,
              let originalContent = editingShapeGradientOriginalContent,
              let index = document.layers.firstIndex(where: { $0.id == layerID }),
              let content = ImageEditorShapeGradientGeometry.updatedContent(
                  from: originalContent,
                  imageSize: document.layers[index].image.size,
                  layerFrame: document.layers[index].frame.standardized,
                  movingMidpointAfter: lowerStopIndex,
                  to: canvasPoint
              ),
              document.layers[index].shapeContent?.fillGradient != content.fillGradient
        else { return }
        document.layers[index].kind = .shape(content)
        editingShapeGradientDidChange = true
        statusText = L10n.text("imageEditor.status.shapeGradientMidpointMoved")
    }

    func updateSelectedShapeGradientMidpoint(toLogicalMidpoint midpoint: Double) {
        guard midpoint.isFinite,
              let layerID = editingShapeGradientLayerID,
              let lowerStopIndex = editingShapeGradientMidpointIndex,
              var content = editingShapeGradientOriginalContent,
              var gradient = content.fillGradient,
              let index = document.layers.firstIndex(where: { $0.id == layerID })
        else { return }
        var stops = gradient.shapeColorStops
        guard stops.indices.contains(lowerStopIndex), lowerStopIndex < stops.count - 1 else {
            return
        }
        stops[lowerStopIndex].midpoint = max(0, min(1, midpoint))
        gradient.colorStops = stops
        content.fillGradient = gradient.normalized()
        guard document.layers[index].shapeContent?.fillGradient != content.fillGradient else {
            return
        }
        document.layers[index].kind = .shape(content)
        editingShapeGradientDidChange = true
        statusText = L10n.text("imageEditor.status.shapeGradientMidpointMoved")
    }

    func addSelectedShapeGradientStop(atCanvasPoint canvasPoint: CGPoint) -> Int? {
        guard canEditSelectedShapeGradientStops,
              let layer = singleSelectedShapeGradientLayer,
              let content = layer.shapeContent,
              let position = ImageEditorShapeGradientGeometry.logicalStopPosition(
                content: content,
                imageSize: layer.image.size,
                layerFrame: layer.frame.standardized,
                canvasPoint: canvasPoint
              )
        else { return nil }
        return addSelectedShapeGradientStop(at: position)
    }

    func removeSelectedShapeGradientCanvasStop(at index: Int) -> Int? {
        guard canEditSelectedShapeGradientStops else { return nil }
        return removeSelectedShapeGradientStop(at: index)
    }

    func finishEditingSelectedShapeGradient() {
        guard let layerID = editingShapeGradientLayerID else { return }
        let didChange: Bool
        if let originalContent = editingShapeGradientOriginalContent,
           let currentContent = document.layers.first(where: { $0.id == layerID })?.shapeContent {
            didChange = currentContent.fillGradient != originalContent.fillGradient
                || currentContent.fillGradientCenter != originalContent.fillGradientCenter
        } else {
            didChange = editingShapeGradientDidChange
        }
        if didChange {
            let historyKey: String
            if editingShapeGradientMidpointIndex != nil {
                historyKey = "imageEditor.history.shapeGradientMidpoint"
            } else if editingShapeGradientStopIndex != nil {
                historyKey = "imageEditor.history.shapeGradientStop"
            } else {
                historyKey = "imageEditor.history.shapeGradientHandle"
            }
            appendHistory(L10n.text(historyKey))
        } else {
            updateStatus()
        }
        finishShapeGradientUndoTransaction(didChange: didChange)
        editingShapeGradientLayerID = nil
        editingShapeGradientOriginalContent = nil
        editingShapeGradientStopIndex = nil
        editingShapeGradientMidpointIndex = nil
        editingShapeGradientDidChange = false
    }

    private var singleSelectedShapeGradientLayer: ImageEditorLayer? {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        guard selectedIDs.count == 1,
              let selectedID = selectedIDs.first
        else { return nil }
        return document.layers.first { $0.id == selectedID }
    }
}
