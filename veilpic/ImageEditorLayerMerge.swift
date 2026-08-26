//
//  ImageEditorLayerMerge.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

enum ImageEditorLayerContextMergeAction: Equatable {
    case down
    case group
    case selected

    var titleKey: String {
        switch self {
        case .down:
            return "imageEditor.action.layerMergeDown"
        case .group:
            return "imageEditor.action.layerMergeGroup"
        case .selected:
            return "imageEditor.action.layerMergeSelected"
        }
    }
}

@MainActor
extension ImageEditorViewModel {
    var mergeDownActionTitleKey: String {
        document.selectedLayer?.isGroup == true
            ? "imageEditor.action.layerMergeGroup"
            : "imageEditor.action.layerMergeDown"
    }

    var canMergeVisibleLayers: Bool {
        mergeVisibleLayerIDs.count > 1
    }

    var canMergeSelectedLayers: Bool {
        hierarchyMergeSelectedPlan != nil
    }

    func layerMergeActionFromContext(
        _ clickedLayerID: UUID
    ) -> ImageEditorLayerContextMergeAction? {
        let selectedIDs = layerContextSelectionIDs(for: clickedLayerID)
        guard !selectedIDs.isEmpty else { return nil }
        let primarySelectionID = document.selectedLayerID.flatMap { selectedID in
            selectedIDs.contains(selectedID) ? selectedID : nil
        } ?? clickedLayerID

        if selectedIDs.count > 1 {
            guard makeHierarchyMergeSelectedPlan(
                selectedIDs: selectedIDs,
                primarySelectionID: primarySelectionID
            ) != nil else { return nil }
            return .selected
        }

        guard let plan = makeHierarchyMergeDownPlan(
            selectedIDs: selectedIDs,
            primarySelectionID: primarySelectionID
        ) else { return nil }
        return plan.kind == .group ? .group : .down
    }

    func layerMergeTitleKeyFromContext(_ clickedLayerID: UUID) -> String {
        if let action = layerMergeActionFromContext(clickedLayerID) {
            return action.titleKey
        }
        let selectedIDs = layerContextSelectionIDs(for: clickedLayerID)
        if selectedIDs.count > 1 {
            return ImageEditorLayerContextMergeAction.selected.titleKey
        }
        if document.layers.first(where: { $0.id == clickedLayerID })?.isGroup == true {
            return ImageEditorLayerContextMergeAction.group.titleKey
        }
        return ImageEditorLayerContextMergeAction.down.titleKey
    }

    @discardableResult
    func applyLayerMergeActionFromContext(_ clickedLayerID: UUID) -> Bool {
        guard let action = layerMergeActionFromContext(clickedLayerID) else { return false }
        prepareLayerContextSelection(for: clickedLayerID)
        switch action {
        case .down, .group:
            mergeSelectedLayerDown()
        case .selected:
            mergeSelectedLayers()
        }
        return true
    }

    var canFlattenImage: Bool {
        document.layers.contains { layer in
            document.shouldComposite(layer)
        }
    }

    func mergeVisibleLayers() {
        let sourceIDs = Set(mergeVisibleLayerIDs)
        guard sourceIDs.count > 1 else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let mergedLayer = flattenedLayer(
            name: L10n.text("imageEditor.layer.visibleMergedName"),
            image: document.compositedImage
        )
        guard let resultPlan = ImageEditorLayerCompositeHierarchy.applyingMergeVisible(
            layers: document.layers,
            sourceLayerIDs: sourceIDs,
            mergedLayer: mergedLayer,
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        ) else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        document.layers = resultPlan.layers
        document.selectedLayerID = resultPlan.primarySelectionID
        document.selectedLayerIDs = [resultPlan.primarySelectionID]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMergeVisible"))
        statusText = L10n.text("imageEditor.status.layerMergeVisible")
    }

    func mergeSelectedLayers() {
        guard let sourcePlan = hierarchyMergeSelectedPlan else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        let mergedLayer = flattenedLayer(
            name: L10n.text("imageEditor.layer.selectedMergedName"),
            image: document.compositedImage(includingOnly: sourcePlan.sourceLayerIDs)
        )
        let resultPlan = ImageEditorLayerHierarchyMerge.applying(
            sourcePlan,
            mergedLayer: mergedLayer,
            to: document.layers,
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        )
        pushUndo()
        document.layers = resultPlan.layers
        document.selectedLayerID = resultPlan.primarySelectionID
        document.selectedLayerIDs = resultPlan.selectedLayerIDs
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerMergeSelected"))
        statusText = L10n.text("imageEditor.status.layerMergeSelected")
    }

    func flattenImage() {
        guard canFlattenImage else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }

        pushUndo()
        let whiteComposite = opaqueWhiteComposite(document.compositedImage)
        let background = ImageEditorLayer.background(image: whiteComposite)
        document.layers = [background]
        document.selectedLayerID = background.id
        document.selectedLayerIDs = [background.id]
        isEditingLayerMask = false
        appendHistory(L10n.text("imageEditor.history.layerFlatten"))
        statusText = L10n.text("imageEditor.status.layerFlattened")
    }

    private var mergeVisibleLayerIDs: [UUID] {
        document.layers
            .filter { layer in document.shouldComposite(layer) }
            .map(\.id)
    }

    var hierarchyMergeDownPlan: ImageEditorLayerMergeSourcePlan? {
        makeHierarchyMergeDownPlan(
            selectedIDs: document.selectedLayerIDs,
            primarySelectionID: document.selectedLayerID
        )
    }

    func makeHierarchyMergeDownPlan(
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?
    ) -> ImageEditorLayerMergeSourcePlan? {
        ImageEditorLayerHierarchyMerge.mergeDownPlan(
            layers: document.layers,
            selectedIDs: selectedIDs,
            primarySelectionID: primarySelectionID,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) },
            isEffectivelyPixelsLocked: { layer in
                guard let index = document.layers.firstIndex(where: { $0.id == layer.id }) else {
                    return true
                }
                return isBackgroundLayer(at: index)
                    ? false
                    : document.isEffectivelyPixelsLocked(layer)
            },
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        )
    }

    var hierarchyMergeSelectedPlan: ImageEditorLayerMergeSourcePlan? {
        makeHierarchyMergeSelectedPlan(
            selectedIDs: document.selectedLayerIDs,
            primarySelectionID: document.selectedLayerID
        )
    }

    func makeHierarchyMergeSelectedPlan(
        selectedIDs: Set<UUID>,
        primarySelectionID: UUID?
    ) -> ImageEditorLayerMergeSourcePlan? {
        ImageEditorLayerHierarchyMerge.mergeSelectedPlan(
            layers: document.layers,
            selectedIDs: selectedIDs,
            primarySelectionID: primarySelectionID,
            isEffectivelyLocked: { document.isEffectivelyLocked($0) },
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        )
    }

    func applyHierarchyMerge(
        _ sourcePlan: ImageEditorLayerMergeSourcePlan,
        mergedLayer: ImageEditorLayer,
        historyKey: String,
        statusKey: String? = nil
    ) {
        let resultPlan = ImageEditorLayerHierarchyMerge.applying(
            sourcePlan,
            mergedLayer: mergedLayer,
            to: document.layers,
            isEffectivelyVisible: { document.isEffectivelyVisible($0) }
        )
        pushUndo()
        document.layers = resultPlan.layers
        document.selectedLayerID = resultPlan.primarySelectionID
        document.selectedLayerIDs = resultPlan.selectedLayerIDs
        isEditingLayerMask = false
        appendHistory(L10n.text(historyKey))
        if let statusKey {
            statusText = L10n.text(statusKey)
        }
    }

    func flattenedLayer(name: String, image: NSImage) -> ImageEditorLayer {
        var layer = ImageEditorLayer.blank(name: name, size: document.canvasSize)
        layer.image = image.normalizedBitmapImage()
        layer.frame = CGRect(origin: .zero, size: document.canvasSize)
        layer.opacity = 1
        layer.fillOpacity = 1
        layer.blendMode = .normal
        layer.isVisible = true
        layer.isLocked = false
        layer.mask = nil
        layer.vectorMask = nil
        layer.isVectorMaskEnabled = true
        layer.isVectorMaskInverted = false
        layer.style = ImageEditorLayerStyle()
        layer.smartFilters = []
        layer.kind = .pixel
        layer.groupID = nil
        layer.isClippingMask = false
        return layer
    }

    private func opaqueWhiteComposite(_ image: NSImage) -> NSImage {
        NSImage.rendered(size: document.canvasSize) { _ in
            NSColor.white.setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: document.canvasSize)).fill()
            image.draw(
                in: CGRect(origin: .zero, size: document.canvasSize),
                from: CGRect(origin: .zero, size: image.size),
                operation: .sourceOver,
                fraction: 1
            )
        }?.normalizedBitmapImage() ?? image.normalizedBitmapImage()
    }

}
