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

@MainActor
extension ImageEditorViewModel {
    var selectedLayerGradientOverlayCanvasCenterPoint: CGPoint? {
        guard !isEditingLayerMask,
              let layer = singleSelectedGradientOverlayCenterLayer
        else { return nil }
        return ImageEditorGradientOverlayCenterGeometry.canvasPoint(
            center: layer.style.gradientOverlayCenter,
            layerFrame: layer.frame
        )
    }

    var canEditSelectedLayerGradientOverlayCanvasCenter: Bool {
        guard let layer = singleSelectedGradientOverlayCenterLayer else { return false }
        return !document.isEffectivelyLocked(layer)
    }

    var hasActiveGradientOverlayCenterTransaction: Bool {
        editingGradientOverlayCenterLayerID != nil
    }

    @discardableResult
    func beginEditingSelectedLayerGradientOverlayCanvasCenter() -> Bool {
        guard editingGradientOverlayCenterLayerID == nil,
              canEditSelectedLayerGradientOverlayCanvasCenter,
              let layer = singleSelectedGradientOverlayCenterLayer
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

    private var singleSelectedGradientOverlayCenterLayer: ImageEditorLayer? {
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
}
