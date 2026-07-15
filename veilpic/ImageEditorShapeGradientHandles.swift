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

enum ImageEditorShapeGradientGeometry {
    static let angleSnapStep: CGFloat = 15

    static func canvasHandlePoints(
        content: ImageEditorShapeContent,
        imageSize: CGSize,
        layerFrame: CGRect
    ) -> ImageEditorShapeGradientHandlePoints? {
        guard let gradient = content.fillGradient?.normalized(),
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

    var canEditSelectedShapeGradient: Bool {
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
        pushUndo()
        editingShapeGradientLayerID = layer.id
        editingShapeGradientOriginalContent = content
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
        document.layers[index].kind = .shape(content)
        editingShapeGradientDidChange = true
        statusText = L10n.text("imageEditor.status.shapeGradientHandleMoved")
    }

    func finishEditingSelectedShapeGradient() {
        guard editingShapeGradientLayerID != nil else { return }
        if editingShapeGradientDidChange {
            appendHistory(L10n.text("imageEditor.history.shapeGradientHandle"))
        } else {
            _ = undoStack.popLast()
            updateStatus()
        }
        editingShapeGradientLayerID = nil
        editingShapeGradientOriginalContent = nil
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
