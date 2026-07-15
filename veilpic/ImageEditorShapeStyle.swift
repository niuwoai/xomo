//
//  ImageEditorShapeStyle.swift
//  veilpic
//
//  Created by Codex on 2026/7/15.
//

import AppKit
import Foundation

@MainActor
extension ImageEditorViewModel {
    var selectedShapeFillColor: NSColor {
        document.selectedLayer?.shapeContent?.fillColor ?? .clear
    }

    var selectedShapeFillOpacity: Double {
        Double(document.selectedLayer?.shapeContent?.fillOpacity ?? 0)
    }

    var selectedShapeStrokeColor: NSColor {
        document.selectedLayer?.shapeContent?.strokeColor ?? .clear
    }

    var selectedShapeStrokeOpacity: Double {
        Double(document.selectedLayer?.shapeContent?.strokeOpacity ?? 0)
    }

    var selectedShapeStrokeWidth: Double {
        Double(document.selectedLayer?.shapeContent?.strokeWidth ?? 1)
    }

    func setSelectedShapeFillColor(_ color: NSColor) {
        updateSelectedShapeProperties(fillColor: color)
    }

    func setSelectedShapeFillOpacity(_ opacity: Double) {
        updateSelectedShapeProperties(fillOpacity: opacity)
    }

    func setSelectedShapeStrokeColor(_ color: NSColor) {
        updateSelectedShapeProperties(strokeColor: color)
    }

    func setSelectedShapeStrokeOpacity(_ opacity: Double) {
        updateSelectedShapeProperties(strokeOpacity: opacity)
    }

    func setSelectedShapeStrokeWidth(_ width: Double) {
        updateSelectedShapeProperties(strokeWidth: width)
    }

    func updateSelectedShapeProperties(
        fillColor: NSColor? = nil,
        fillOpacity: Double? = nil,
        strokeColor: NSColor? = nil,
        strokeOpacity: Double? = nil,
        strokeWidth: Double? = nil,
        cornerRadius: Double? = nil,
        cornerRadii: ImageEditorRectangleCornerRadii? = nil,
        cornerSmoothing: Double? = nil
    ) {
        let selectedIDs: Set<UUID>
        if document.selectedLayerIDs.isEmpty,
           let selectedLayerID = document.selectedLayerID {
            selectedIDs = [selectedLayerID]
        } else {
            selectedIDs = document.selectedLayerIDs
        }
        let indices = document.layers.indices.filter { index in
            let layer = document.layers[index]
            return selectedIDs.contains(layer.id)
                && layer.isShape
                && !document.isEffectivelyPixelsLocked(layer)
        }
        guard !indices.isEmpty else { return }

        var updates: [(index: Int, content: ImageEditorShapeContent)] = []
        for index in indices {
            guard var content = document.layers[index].shapeContent else { continue }
            let previous = content
            if let fillColor { content.fillColor = fillColor }
            if let fillOpacity, fillOpacity.isFinite {
                content.fillOpacity = CGFloat(max(0, min(1, fillOpacity)))
            }
            if let strokeColor { content.strokeColor = strokeColor }
            if let strokeOpacity, strokeOpacity.isFinite {
                content.strokeOpacity = CGFloat(max(0, min(1, strokeOpacity)))
            }
            if let strokeWidth, strokeWidth.isFinite {
                content.strokeWidth = CGFloat(max(1, min(96, strokeWidth)))
            }
            if content.kind == .rectangle,
               let cornerRadius,
               cornerRadius.isFinite {
                content.cornerRadius = CGFloat(max(0, cornerRadius))
                content.cornerRadii = nil
            } else if content.kind == .rectangle,
                      let cornerRadii {
                content.cornerRadii = cornerRadii
            }
            if content.kind == .rectangle,
               let cornerSmoothing,
               cornerSmoothing.isFinite {
                content.cornerSmoothing = CGFloat(max(0, min(1, cornerSmoothing)))
            }
            content = content.normalized(size: document.layers[index].image.size)
            guard !shapeAppearanceEqual(previous, content) else { continue }
            updates.append((index, content))
        }
        guard !updates.isEmpty else { return }

        pushUndo()
        for update in updates {
            document.layers[update.index].kind = .shape(update.content)
        }
        appendHistory(L10n.text("imageEditor.history.shapeStyle"))
        statusText = L10n.format("imageEditor.status.shapeStyle", updates.count)
    }

    private func shapeAppearanceEqual(
        _ lhs: ImageEditorShapeContent,
        _ rhs: ImageEditorShapeContent
    ) -> Bool {
        lhs.fillColor.isEqual(rhs.fillColor)
            && abs(lhs.fillOpacity - rhs.fillOpacity) <= 0.000_1
            && lhs.strokeColor.isEqual(rhs.strokeColor)
            && abs(lhs.strokeOpacity - rhs.strokeOpacity) <= 0.000_1
            && abs(lhs.strokeWidth - rhs.strokeWidth) <= 0.000_1
            && abs(lhs.cornerRadius - rhs.cornerRadius) <= 0.000_1
            && lhs.cornerRadii == rhs.cornerRadii
            && abs(lhs.cornerSmoothing - rhs.cornerSmoothing) <= 0.000_1
    }
}
