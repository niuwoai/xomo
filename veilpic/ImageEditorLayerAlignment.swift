//
//  ImageEditorLayerAlignment.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import CoreGraphics
import Foundation

enum ImageEditorMoveAlignmentTarget: String, CaseIterable, Identifiable {
    case selectedLayers
    case canvas
    case pixelSelection

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.option.moveAlignmentTarget.\(rawValue)")
    }
}

enum ImageEditorLayerAlignment: CaseIterable, Hashable, Identifiable {
    case left
    case horizontalCenter
    case right
    case top
    case verticalCenter
    case bottom

    var id: Self { self }

    var optionBarSystemImage: String {
        switch self {
        case .left: "align.horizontal.left"
        case .horizontalCenter: "align.horizontal.center"
        case .right: "align.horizontal.right"
        case .top: "align.vertical.top"
        case .verticalCenter: "align.vertical.center"
        case .bottom: "align.vertical.bottom"
        }
    }

    var actionTitleKey: String {
        actionTitleKey(for: .selectedLayers)
    }

    func actionTitleKey(for target: ImageEditorMoveAlignmentTarget) -> String {
        let targetName = switch target {
        case .selectedLayers: "layerAlign"
        case .canvas: "layerAlignCanvas"
        case .pixelSelection: "layerAlignSelection"
        }
        let edgeName = switch self {
        case .left: "Left"
        case .horizontalCenter: "HorizontalCenter"
        case .right: "Right"
        case .top: "Top"
        case .verticalCenter: "VerticalCenter"
        case .bottom: "Bottom"
        }
        return "imageEditor.action.\(targetName)\(edgeName)"
    }

    var accessibilityIdentifier: String {
        switch self {
        case .left: "image-editor-move-align-left"
        case .horizontalCenter: "image-editor-move-align-horizontal-center"
        case .right: "image-editor-move-align-right"
        case .top: "image-editor-move-align-top"
        case .verticalCenter: "image-editor-move-align-vertical-center"
        case .bottom: "image-editor-move-align-bottom"
        }
    }
}

enum ImageEditorLayerDistribution: String, CaseIterable, Identifiable {
    case left
    case horizontalCenter
    case right
    case top
    case verticalCenter
    case bottom

    var id: String { rawValue }

    var optionBarSystemImage: String {
        switch self {
        case .left: "distribute.horizontal.left"
        case .horizontalCenter: "arrow.left.and.right"
        case .right: "distribute.horizontal.right"
        case .top: "distribute.vertical.top"
        case .verticalCenter: "arrow.up.and.down"
        case .bottom: "distribute.vertical.bottom"
        }
    }

    var actionTitleKey: String {
        switch self {
        case .left: "imageEditor.action.layerDistributeLeft"
        case .horizontalCenter: "imageEditor.action.layerDistributeHorizontalCenter"
        case .right: "imageEditor.action.layerDistributeRight"
        case .top: "imageEditor.action.layerDistributeTop"
        case .verticalCenter: "imageEditor.action.layerDistributeVerticalCenter"
        case .bottom: "imageEditor.action.layerDistributeBottom"
        }
    }

    var accessibilityIdentifier: String {
        "image-editor-move-distribute-\(rawValue)"
    }
}

enum ImageEditorLayerSpacingDistribution: String, CaseIterable, Identifiable {
    case horizontal
    case vertical

    var id: String { rawValue }

    var optionBarSystemImage: String {
        switch self {
        case .horizontal: "rectangle.split.3x1"
        case .vertical: "rectangle.split.1x3"
        }
    }

    var actionTitleKey: String {
        switch self {
        case .horizontal: "imageEditor.action.layerDistributeHorizontalSpacing"
        case .vertical: "imageEditor.action.layerDistributeVerticalSpacing"
        }
    }

    var accessibilityIdentifier: String {
        "image-editor-move-distribute-\(rawValue)-spacing"
    }
}

@MainActor
extension ImageEditorViewModel {
    var canApplyMoveToolAlignment: Bool {
        switch moveToolAlignmentTarget {
        case .selectedLayers:
            canAlignSelectedLayers
        case .canvas:
            canAlignSelectedLayersToCanvas
        case .pixelSelection:
            canAlignSelectedLayersToSelection
        }
    }

    func applyMoveToolAlignment(_ alignment: ImageEditorLayerAlignment) {
        switch moveToolAlignmentTarget {
        case .selectedLayers:
            alignSelectedLayers(alignment)
        case .canvas:
            alignSelectedLayersToCanvas(alignment)
        case .pixelSelection:
            alignSelectedLayersToSelection(alignment)
        }
    }

    var canAlignSelectedLayers: Bool {
        editableTransformLayerIndices().count >= 2
    }

    var canAlignSelectedLayersToCanvas: Bool {
        !editableTransformLayerIndices().isEmpty
    }

    var canAlignSelectedLayersToSelection: Bool {
        !editableTransformLayerIndices().isEmpty && selectionAlignmentTargetBounds() != nil
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

    func alignSelectedLayersToSelection(_ alignment: ImageEditorLayerAlignment) {
        guard let targetBounds = selectionAlignmentTargetBounds() else {
            statusText = L10n.text("imageEditor.status.noSelection")
            return
        }
        alignSelectedLayers(
            alignment,
            to: targetBounds,
            historyTitle: L10n.text("imageEditor.history.layerAlignSelection"),
            status: L10n.text("imageEditor.status.layerAlignedToSelection")
        )
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

    func distributeSelectedLayerSpacing(_ distribution: ImageEditorLayerSpacingDistribution) {
        let indices = editableTransformLayerIndices()
        guard indices.count >= 3 else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        let sortedLayers = indices
            .map { document.layers[$0] }
            .sorted { lhs, rhs in
                distribution.sortValue(for: lhs.frame.standardized) < distribution.sortValue(for: rhs.frame.standardized)
            }

        guard let bounds = transformFrame(for: indices) else { return }
        let totalLength = sortedLayers.reduce(CGFloat.zero) { partialResult, layer in
            partialResult + distribution.length(of: layer.frame.standardized)
        }
        let availableLength = distribution.length(of: bounds)
        let spacing = (availableLength - totalLength) / CGFloat(sortedLayers.count - 1)

        var cursor = distribution.minimum(of: sortedLayers[0].frame.standardized)
        var distributedFrames: [UUID: CGRect] = [:]
        for offset in 0..<sortedLayers.count {
            let layer = sortedLayers[offset]
            var frame = layer.frame.standardized
            if offset > 0 && offset < sortedLayers.count - 1 {
                distribution.apply(origin: cursor, to: &frame)
                distributedFrames[layer.id] = frame
            }
            cursor += distribution.length(of: frame) + spacing
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
        appendHistory(L10n.text("imageEditor.history.layerDistributeSpacing"))
        statusText = L10n.text("imageEditor.status.layerSpacingDistributed")
    }

    private func alignSelectedLayers(
        _ alignment: ImageEditorLayerAlignment,
        to targetBounds: CGRect,
        historyTitle: String,
        status: String
    ) {
        let indices = editableTransformLayerIndices()
        guard !indices.isEmpty else {
            statusText = L10n.text("imageEditor.status.layerLocked")
            return
        }

        var alignedFrames: [UUID: CGRect] = [:]
        for index in indices {
            let layer = document.layers[index]
            var frame = layer.frame.standardized
            switch alignment {
            case .left:
                frame.origin.x = targetBounds.minX
            case .horizontalCenter:
                frame.origin.x = targetBounds.midX - frame.width / 2
            case .right:
                frame.origin.x = targetBounds.maxX - frame.width
            case .top:
                frame.origin.y = targetBounds.maxY - frame.height
            case .verticalCenter:
                frame.origin.y = targetBounds.midY - frame.height / 2
            case .bottom:
                frame.origin.y = targetBounds.minY
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
        appendHistory(historyTitle)
        statusText = status
    }

    private func selectionAlignmentTargetBounds() -> CGRect? {
        guard let selection = document.selection else { return nil }
        guard let selectedBounds = selection.effectiveSelectedBounds(in: document.canvasSize) else { return nil }
        let bounds = selectedBounds.standardized
        guard !bounds.isNull, bounds.width > 0.1, bounds.height > 0.1 else { return nil }
        return bounds
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

private extension ImageEditorLayerSpacingDistribution {
    func sortValue(for frame: CGRect) -> CGFloat {
        switch self {
        case .horizontal:
            frame.minX
        case .vertical:
            frame.minY
        }
    }

    func minimum(of frame: CGRect) -> CGFloat {
        switch self {
        case .horizontal:
            frame.minX
        case .vertical:
            frame.minY
        }
    }

    func length(of frame: CGRect) -> CGFloat {
        switch self {
        case .horizontal:
            frame.width
        case .vertical:
            frame.height
        }
    }

    func apply(origin: CGFloat, to frame: inout CGRect) {
        switch self {
        case .horizontal:
            frame.origin.x = origin
        case .vertical:
            frame.origin.y = origin
        }
    }
}
