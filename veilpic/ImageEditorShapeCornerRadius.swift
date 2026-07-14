//
//  ImageEditorShapeCornerRadius.swift
//  veilpic
//
//  Created by Codex on 2026/7/15.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    var selectedRectangleCornerRadius: Double? {
        guard selectedLayerCount == 1,
              let content = document.selectedLayer?.shapeContent,
              content.kind == .rectangle
        else { return nil }
        return Double(content.cornerRadius)
    }

    var selectedRectangleMaximumCornerRadius: Double {
        guard let layer = document.selectedLayer else { return 0 }
        return Double(max(0, min(layer.image.size.width, layer.image.size.height) / 2))
    }

    var selectedRectangleUsesIndependentCornerRadii: Bool? {
        guard selectedLayerCount == 1,
              let content = document.selectedLayer?.shapeContent,
              content.kind == .rectangle
        else { return nil }
        return content.cornerRadii != nil
    }

    var selectedRectangleCornerSmoothingPercent: Double? {
        guard selectedLayerCount == 1,
              let content = document.selectedLayer?.shapeContent,
              content.kind == .rectangle
        else { return nil }
        return Double(content.cornerSmoothing * 100)
    }

    func selectedRectangleCornerRadius(at corner: ImageEditorRectangleCorner) -> Double {
        guard let content = document.selectedLayer?.shapeContent else { return 0 }
        return Double(content.effectiveCornerRadii.radius(at: corner))
    }

    func setSelectedRectangleCornerRadius(_ radius: Double) {
        guard selectedLayerCount == 1,
              let selectedLayerID = document.selectedLayerID,
              let index = document.layers.firstIndex(where: { $0.id == selectedLayerID }),
              !document.isEffectivelyPixelsLocked(document.layers[index]),
              var content = document.layers[index].shapeContent,
              content.kind == .rectangle
        else { return }

        let maximum = max(0, min(document.layers[index].image.size.width, document.layers[index].image.size.height) / 2)
        let clamped = min(maximum, max(0, CGFloat(radius.isFinite ? radius : 0)))
        guard abs(content.cornerRadius - clamped) > 0.001 else { return }

        pushUndo()
        content.cornerRadius = clamped
        content.cornerRadii = nil
        document.layers[index].kind = .shape(content.normalized(size: document.layers[index].image.size))
        appendHistory(L10n.text("imageEditor.history.shapeCornerRadius"))
        statusText = L10n.format("imageEditor.status.shapeCornerRadius", Int(clamped.rounded()))
    }

    func setSelectedRectangleUsesIndependentCornerRadii(_ usesIndependentRadii: Bool) {
        guard let context = selectedEditableRectangleContext() else { return }
        var content = context.content
        guard (content.cornerRadii != nil) != usesIndependentRadii else { return }

        pushUndo()
        if usesIndependentRadii {
            content.cornerRadii = .uniform(content.cornerRadius)
        } else if let radii = content.cornerRadii {
            content.cornerRadius = radii.topLeft
            content.cornerRadii = nil
        }
        document.layers[context.index].kind = .shape(
            content.normalized(size: document.layers[context.index].image.size)
        )
        appendHistory(L10n.text("imageEditor.history.shapeCornerRadius"))
        statusText = L10n.text(
            usesIndependentRadii
                ? "imageEditor.status.shapeCornerRadiiIndependent"
                : "imageEditor.status.shapeCornerRadiiLinked"
        )
    }

    func setSelectedRectangleCornerRadius(
        _ radius: Double,
        at corner: ImageEditorRectangleCorner
    ) {
        guard let context = selectedEditableRectangleContext(),
              var radii = context.content.cornerRadii
        else { return }

        let maximum = max(
            0,
            min(
                document.layers[context.index].image.size.width,
                document.layers[context.index].image.size.height
            ) / 2
        )
        let clamped = min(maximum, max(0, CGFloat(radius.isFinite ? radius : 0)))
        guard abs(radii.radius(at: corner) - clamped) > 0.001 else { return }

        pushUndo()
        radii.setRadius(clamped, at: corner)
        var content = context.content
        content.cornerRadii = radii
        document.layers[context.index].kind = .shape(
            content.normalized(size: document.layers[context.index].image.size)
        )
        appendHistory(L10n.text("imageEditor.history.shapeCornerRadius"))
        statusText = L10n.format(
            "imageEditor.status.shapeCornerRadiusAtCorner",
            corner.title,
            Int(clamped.rounded())
        )
    }

    func setSelectedRectangleCornerSmoothingPercent(_ percent: Double) {
        guard let context = selectedEditableRectangleContext() else { return }
        let clampedPercent = min(100, max(0, percent.isFinite ? percent : 0))
        let smoothing = CGFloat(clampedPercent / 100)
        guard abs(context.content.cornerSmoothing - smoothing) > 0.000_1 else { return }

        pushUndo()
        var content = context.content
        content.cornerSmoothing = smoothing
        document.layers[context.index].kind = .shape(
            content.normalized(size: document.layers[context.index].image.size)
        )
        appendHistory(L10n.text("imageEditor.history.shapeCornerSmoothing"))
        statusText = L10n.format(
            "imageEditor.status.shapeCornerSmoothing",
            Int(clampedPercent.rounded())
        )
    }

    private func selectedEditableRectangleContext() -> (
        index: Int,
        content: ImageEditorShapeContent
    )? {
        guard selectedLayerCount == 1,
              let selectedLayerID = document.selectedLayerID,
              let index = document.layers.firstIndex(where: { $0.id == selectedLayerID }),
              !document.isEffectivelyPixelsLocked(document.layers[index]),
              let content = document.layers[index].shapeContent,
              content.kind == .rectangle
        else { return nil }
        return (index, content)
    }
}
