//
//  ImageEditorLayerAlignment.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import CoreGraphics
import Foundation

enum ImageEditorLayerAlignment {
    case left
    case horizontalCenter
    case right
    case top
    case verticalCenter
    case bottom
}

@MainActor
extension ImageEditorViewModel {
    var canAlignSelectedLayers: Bool {
        editableTransformLayerIndices().count >= 2
    }

    func alignSelectedLayers(_ alignment: ImageEditorLayerAlignment) {
        let indices = editableTransformLayerIndices()
        guard indices.count >= 2,
              let bounds = transformFrame(for: indices)
        else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        var alignedFrames: [UUID: CGRect] = [:]
        for index in indices {
            let layer = document.layers[index]
            var frame = layer.frame.standardized
            switch alignment {
            case .left:
                frame.origin.x = bounds.minX
            case .horizontalCenter:
                frame.origin.x = bounds.midX - frame.width / 2
            case .right:
                frame.origin.x = bounds.maxX - frame.width
            case .top:
                frame.origin.y = bounds.maxY - frame.height
            case .verticalCenter:
                frame.origin.y = bounds.midY - frame.height / 2
            case .bottom:
                frame.origin.y = bounds.minY
            }
            alignedFrames[layer.id] = frame
        }

        guard alignedFrames.contains(where: { item in
            guard let current = document.layers.first(where: { $0.id == item.key })?.frame.standardized else { return false }
            return current != item.value
        }) else { return }

        pushUndo()
        for index in document.layers.indices {
            let id = document.layers[index].id
            if let frame = alignedFrames[id] {
                document.layers[index].frame = frame
            }
        }
        appendHistory(L10n.text("imageEditor.history.layerAlign"))
    }
}
