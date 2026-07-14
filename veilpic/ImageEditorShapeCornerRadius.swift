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
        document.layers[index].kind = .shape(content.normalized(size: document.layers[index].image.size))
        appendHistory(L10n.text("imageEditor.history.shapeCornerRadius"))
        statusText = L10n.format("imageEditor.status.shapeCornerRadius", Int(clamped.rounded()))
    }
}
