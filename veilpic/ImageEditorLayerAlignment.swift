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

enum ImageEditorLayerDistribution {
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

    var canAlignSelectedLayersToCanvas: Bool {
        !editableTransformLayerIndices().isEmpty
    }

    var canDistributeSelectedLayers: Bool {
        editableTransformLayerIndices().count >= 3
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

    func alignSelectedLayersToCanvas(_ alignment: ImageEditorLayerAlignment) {
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        let canvasBounds = CGRect(origin: .zero, size: document.canvasSize)
        var alignedFrames: [UUID: CGRect] = [:]
        for index in indices {
            let layer = document.layers[index]
            var frame = layer.frame.standardized
            switch alignment {
            case .left:
                frame.origin.x = canvasBounds.minX
            case .horizontalCenter:
                frame.origin.x = canvasBounds.midX - frame.width / 2
            case .right:
                frame.origin.x = canvasBounds.maxX - frame.width
            case .top:
                frame.origin.y = canvasBounds.maxY - frame.height
            case .verticalCenter:
                frame.origin.y = canvasBounds.midY - frame.height / 2
            case .bottom:
                frame.origin.y = canvasBounds.minY
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
        appendHistory(L10n.text("imageEditor.history.layerAlignCanvas"))
        statusText = L10n.text("imageEditor.status.layerAlignedToCanvas")
    }

    func distributeSelectedLayers(_ distribution: ImageEditorLayerDistribution) {
        let indices = editableTransformLayerIndices()
        guard indices.count >= 3 else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        let sortedLayers = indices
            .map { document.layers[$0] }
            .sorted { lhs, rhs in
                distribution.anchorValue(for: lhs.frame.standardized) < distribution.anchorValue(for: rhs.frame.standardized)
            }

        let firstFrame = sortedLayers[0].frame.standardized
        let lastFrame = sortedLayers[sortedLayers.count - 1].frame.standardized
        let firstAnchor = distribution.anchorValue(for: firstFrame)
        let lastAnchor = distribution.anchorValue(for: lastFrame)

        let step = (lastAnchor - firstAnchor) / CGFloat(sortedLayers.count - 1)
        var distributedFrames: [UUID: CGRect] = [:]
        for offset in 1..<(sortedLayers.count - 1) {
            let layer = sortedLayers[offset]
            var frame = layer.frame.standardized
            let targetAnchor = firstAnchor + CGFloat(offset) * step
            distribution.apply(anchor: targetAnchor, to: &frame)
            distributedFrames[layer.id] = frame
        }

        guard distributedFrames.contains(where: { item in
            guard let current = document.layers.first(where: { $0.id == item.key })?.frame.standardized else { return false }
            return current != item.value
        }) else { return }

        pushUndo()
        for index in document.layers.indices {
            let id = document.layers[index].id
            if let frame = distributedFrames[id] {
                document.layers[index].frame = frame
            }
        }
        appendHistory(L10n.text("imageEditor.history.layerDistribute"))
    }
}

private extension ImageEditorLayerDistribution {
    func anchorValue(for frame: CGRect) -> CGFloat {
        switch self {
        case .left:
            frame.minX
        case .horizontalCenter:
            frame.midX
        case .right:
            frame.maxX
        case .top:
            frame.maxY
        case .verticalCenter:
            frame.midY
        case .bottom:
            frame.minY
        }
    }

    func apply(anchor: CGFloat, to frame: inout CGRect) {
        switch self {
        case .left:
            frame.origin.x = anchor
        case .horizontalCenter:
            frame.origin.x = anchor - frame.width / 2
        case .right:
            frame.origin.x = anchor - frame.width
        case .top:
            frame.origin.y = anchor - frame.height
        case .verticalCenter:
            frame.origin.y = anchor - frame.height / 2
        case .bottom:
            frame.origin.y = anchor
        }
    }
}
