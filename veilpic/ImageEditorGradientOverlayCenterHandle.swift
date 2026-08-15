//
//  ImageEditorGradientOverlayCenterHandle.swift
//  veilpic
//
//  Created by Codex on 2026/8/16.
//

import CoreGraphics
import Foundation

enum ImageEditorGradientOverlayCenterGeometry {
    static func canvasPoint(center: CGPoint, layerFrame: CGRect) -> CGPoint? {
        let frame = layerFrame.standardized
        guard frame.width > 0, frame.height > 0 else { return nil }
        let normalized = ImageEditorGradientOverlayCenterPolicy.normalized(center)
        return CGPoint(
            x: frame.minX + normalized.x * frame.width,
            y: frame.minY + normalized.y * frame.height
        )
    }

    static func normalizedCenter(canvasPoint: CGPoint, layerFrame: CGRect) -> CGPoint? {
        let frame = layerFrame.standardized
        guard frame.width > 0,
              frame.height > 0,
              canvasPoint.x.isFinite,
              canvasPoint.y.isFinite
        else { return nil }
        return ImageEditorGradientOverlayCenterPolicy.normalized(
            CGPoint(
                x: (canvasPoint.x - frame.minX) / frame.width,
                y: (canvasPoint.y - frame.minY) / frame.height
            )
        )
    }
}

struct ImageEditorGradientOverlayCanvasGeometry: Equatable {
    var center: CGPoint
    var axisEndpoint: CGPoint
}

struct ImageEditorGradientOverlayAxisValues: Equatable {
    var angle: CGFloat
    var scale: CGFloat
}

enum ImageEditorGradientOverlayAxisGeometry {
    static let angleSnapStep: CGFloat = 15

    static func canvasGeometry(
        style: ImageEditorGradientFillStyle,
        center: CGPoint,
        angle: CGFloat,
        scale: CGFloat,
        layerFrame: CGRect
    ) -> ImageEditorGradientOverlayCanvasGeometry? {
        let frame = layerFrame.standardized
        guard frame.width > 0, frame.height > 0 else { return nil }
        let normalizedCenter = ImageEditorGradientOverlayCenterPolicy.normalized(center)
        let canvasCenter = CGPoint(
            x: frame.minX + normalizedCenter.x * frame.width,
            y: frame.minY + normalizedCenter.y * frame.height
        )
        let normalizedAngle = normalizedAngle(angle)
        let radians = normalizedAngle * .pi / 180
        let direction = style == .radial
            ? CGSize(width: 1, height: 0)
            : CGSize(width: cos(radians), height: sin(radians))
        let resolvedScale = max(0.25, min(4, scale))
        let length: CGFloat
        switch style {
        case .linear, .reflected:
            length = span(angle: normalizedAngle, size: frame.size) * resolvedScale / 2
        case .radial, .diamond:
            length = referenceRadius(size: frame.size) * resolvedScale
        }
        return ImageEditorGradientOverlayCanvasGeometry(
            center: canvasCenter,
            axisEndpoint: CGPoint(
                x: canvasCenter.x + direction.width * length,
                y: canvasCenter.y + direction.height * length
            )
        )
    }

    static func updatedAxis(
        style: ImageEditorGradientFillStyle,
        center: CGPoint,
        currentAngle: CGFloat,
        layerFrame: CGRect,
        canvasPoint: CGPoint,
        snappingAngle: Bool
    ) -> ImageEditorGradientOverlayAxisValues? {
        let frame = layerFrame.standardized
        guard frame.width > 0,
              frame.height > 0,
              canvasPoint.x.isFinite,
              canvasPoint.y.isFinite,
              let canvasCenter = ImageEditorGradientOverlayCenterGeometry.canvasPoint(
                  center: center,
                  layerFrame: frame
              )
        else { return nil }
        let delta = CGSize(
            width: canvasPoint.x - canvasCenter.x,
            height: canvasPoint.y - canvasCenter.y
        )
        let distance = hypot(delta.width, delta.height)
        guard distance > 0.001 else { return nil }

        if style == .radial {
            return ImageEditorGradientOverlayAxisValues(
                angle: normalizedAngle(currentAngle),
                scale: max(0.25, min(4, distance / referenceRadius(size: frame.size)))
            )
        }

        var angle = atan2(delta.height, delta.width) * 180 / .pi
        if snappingAngle {
            angle = (angle / angleSnapStep).rounded() * angleSnapStep
        }
        angle = normalizedAngle(angle)
        let referenceLength: CGFloat
        switch style {
        case .linear, .reflected:
            referenceLength = span(angle: angle, size: frame.size) / 2
        case .diamond:
            referenceLength = referenceRadius(size: frame.size)
        case .radial:
            return nil
        }
        return ImageEditorGradientOverlayAxisValues(
            angle: angle,
            scale: max(0.25, min(4, distance / referenceLength))
        )
    }

    static func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        var value = angle.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }

    private static func span(angle: CGFloat, size: CGSize) -> CGFloat {
        let radians = angle * .pi / 180
        return max(1, abs(cos(radians)) * size.width + abs(sin(radians)) * size.height)
    }

    private static func referenceRadius(size: CGSize) -> CGFloat {
        max(1, hypot(size.width / 2, size.height / 2))
    }
}

@MainActor
extension ImageEditorViewModel {
    var selectedLayerGradientOverlayCanvasGeometry: ImageEditorGradientOverlayCanvasGeometry? {
        guard !isEditingLayerMask,
              let layer = singleSelectedGradientOverlayCanvasLayer
        else { return nil }
        return ImageEditorGradientOverlayAxisGeometry.canvasGeometry(
            style: layer.style.gradientOverlayStyle,
            center: layer.style.gradientOverlayCenter,
            angle: layer.style.gradientOverlayAngle,
            scale: layer.style.gradientOverlayScale,
            layerFrame: layer.frame
        )
    }

    var selectedLayerGradientOverlayCanvasCenterPoint: CGPoint? {
        selectedLayerGradientOverlayCanvasGeometry?.center
    }

    var canEditSelectedLayerGradientOverlayCanvasCenter: Bool {
        guard let layer = singleSelectedGradientOverlayCanvasLayer else { return false }
        return !document.isEffectivelyLocked(layer)
    }

    var hasActiveGradientOverlayCenterTransaction: Bool {
        editingGradientOverlayCenterLayerID != nil
    }

    @discardableResult
    func beginEditingSelectedLayerGradientOverlayCanvasCenter() -> Bool {
        guard editingGradientOverlayCenterLayerID == nil,
              editingGradientOverlayAxisLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCanvasLayer
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        beginGradientOverlayCenterUndoTransaction()
        editingGradientOverlayCenterLayerID = layer.id
        editingGradientOverlayCenterOriginalPoint = ImageEditorGradientOverlayCenterPolicy
            .normalized(layer.style.gradientOverlayCenter)
        return true
    }

    func updateSelectedLayerGradientOverlayCanvasCenter(to canvasPoint: CGPoint) {
        guard let layerID = editingGradientOverlayCenterLayerID,
              let index = document.layers.firstIndex(where: { $0.id == layerID }),
              let center = ImageEditorGradientOverlayCenterGeometry.normalizedCenter(
                canvasPoint: canvasPoint,
                layerFrame: document.layers[index].frame
              ),
              document.layers[index].style.gradientOverlayCenter != center
        else { return }
        document.layers[index].style.gradientOverlayCenter = center
        statusText = L10n.text("imageEditor.status.gradientOverlayCenterMoved")
    }

    func finishEditingSelectedLayerGradientOverlayCanvasCenter() {
        guard let layerID = editingGradientOverlayCenterLayerID else { return }
        let currentCenter = document.layers.first(where: { $0.id == layerID }).map {
            ImageEditorGradientOverlayCenterPolicy.normalized($0.style.gradientOverlayCenter)
        }
        let didChange = currentCenter != editingGradientOverlayCenterOriginalPoint
        if didChange {
            appendHistory(L10n.text("imageEditor.history.gradientOverlayCenter"))
        } else {
            updateStatus()
        }
        finishGradientOverlayCenterUndoTransaction(didChange: didChange)
        clearGradientOverlayCenterEditingState()
    }

    @discardableResult
    func cancelEditingSelectedLayerGradientOverlayCanvasCenter() -> Bool {
        guard editingGradientOverlayCenterLayerID != nil else { return false }
        let cancelled = cancelGradientOverlayCenterUndoTransaction()
        clearGradientOverlayCenterEditingState()
        if cancelled { updateStatus() }
        return cancelled
    }

    var hasActiveGradientOverlayAxisTransaction: Bool {
        editingGradientOverlayAxisLayerID != nil
    }

    @discardableResult
    func beginEditingSelectedLayerGradientOverlayCanvasAxis() -> Bool {
        guard editingGradientOverlayAxisLayerID == nil,
              editingGradientOverlayCenterLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCanvasLayer
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return false
        }
        beginGradientOverlayAxisUndoTransaction()
        editingGradientOverlayAxisLayerID = layer.id
        editingGradientOverlayAxisOriginalAngle = ImageEditorGradientOverlayAxisGeometry
            .normalizedAngle(layer.style.gradientOverlayAngle)
        editingGradientOverlayAxisOriginalScale = layer.style.gradientOverlayScale
        return true
    }

    func updateSelectedLayerGradientOverlayCanvasAxis(
        to canvasPoint: CGPoint,
        snappingAngle: Bool
    ) {
        guard let layerID = editingGradientOverlayAxisLayerID,
              let index = document.layers.firstIndex(where: { $0.id == layerID }),
              let values = ImageEditorGradientOverlayAxisGeometry.updatedAxis(
                  style: document.layers[index].style.gradientOverlayStyle,
                  center: document.layers[index].style.gradientOverlayCenter,
                  currentAngle: document.layers[index].style.gradientOverlayAngle,
                  layerFrame: document.layers[index].frame,
                  canvasPoint: canvasPoint,
                  snappingAngle: snappingAngle
              )
        else { return }
        let currentAngle = ImageEditorGradientOverlayAxisGeometry.normalizedAngle(
            document.layers[index].style.gradientOverlayAngle
        )
        guard currentAngle != values.angle
                || document.layers[index].style.gradientOverlayScale != values.scale
        else { return }
        document.layers[index].style.gradientOverlayAngle = values.angle
        document.layers[index].style.gradientOverlayScale = values.scale
        statusText = L10n.text("imageEditor.status.gradientOverlayAxisMoved")
    }

    func finishEditingSelectedLayerGradientOverlayCanvasAxis() {
        guard let layerID = editingGradientOverlayAxisLayerID else { return }
        let style = document.layers.first(where: { $0.id == layerID })?.style
        let angle = style.map {
            ImageEditorGradientOverlayAxisGeometry.normalizedAngle($0.gradientOverlayAngle)
        }
        let angleDelta = angle.map {
            abs(ImageEditorGradientOverlayAxisGeometry.normalizedAngle(
                $0 - (editingGradientOverlayAxisOriginalAngle ?? $0)
            ))
        } ?? 0
        let scaleDelta = style.map {
            abs($0.gradientOverlayScale - (editingGradientOverlayAxisOriginalScale ?? $0.gradientOverlayScale))
        } ?? 0
        let didChange = angleDelta > 0.000_001 || scaleDelta > 0.000_001
        if didChange {
            appendHistory(L10n.text("imageEditor.history.gradientOverlayAxis"))
        }
        finishGradientOverlayAxisUndoTransaction(didChange: didChange)
        clearGradientOverlayAxisEditingState()
        if !didChange { updateStatus() }
    }

    @discardableResult
    func cancelEditingSelectedLayerGradientOverlayCanvasAxis() -> Bool {
        guard editingGradientOverlayAxisLayerID != nil else { return false }
        let cancelled = cancelGradientOverlayAxisUndoTransaction()
        clearGradientOverlayAxisEditingState()
        if cancelled { updateStatus() }
        return cancelled
    }

    private var singleSelectedGradientOverlayCanvasLayer: ImageEditorLayer? {
        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        guard selectedIDs.count == 1,
              let selectedID = selectedIDs.first,
              let layer = document.layers.first(where: { $0.id == selectedID }),
              !layer.isGroup,
              !layer.isAdjustment,
              !layer.isFilter,
              layer.style.effectsEnabled,
              layer.style.gradientOverlayEnabled,
              layer.shapeContent?.fillGradient == nil
        else { return nil }
        return layer
    }

    private func clearGradientOverlayCenterEditingState() {
        editingGradientOverlayCenterLayerID = nil
        editingGradientOverlayCenterOriginalPoint = nil
    }

    private func clearGradientOverlayAxisEditingState() {
        editingGradientOverlayAxisLayerID = nil
        editingGradientOverlayAxisOriginalAngle = nil
        editingGradientOverlayAxisOriginalScale = nil
    }
}
