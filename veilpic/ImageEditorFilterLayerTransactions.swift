//
//  ImageEditorFilterLayerTransactions.swift
//  veilpic
//

import Foundation

@MainActor
extension ImageEditorViewModel {
    @discardableResult
    func replaceSelectedFilterLayerValues(
        intensity: Double?,
        settings: ImageEditorFilterSettings?
    ) -> Int {
        guard intensity != nil || settings != nil else { return 0 }

        let selectedIDs = document.selectedLayerIDs
        let normalizedSettings = settings?.normalized()
        let changes = document.layers.indices.compactMap { index -> FilterLayerChange? in
            let layer = document.layers[index]
            guard
                selectedIDs.contains(layer.id),
                !document.isEffectivelyPixelsLocked(layer),
                let filter = layer.filter
            else {
                return nil
            }

            let targetIntensity = intensity.map { max(0, min(1, $0)) } ?? filter.intensity
            let targetSettings = normalizedSettings ?? layer.filterSettings.normalized()
            guard
                targetIntensity != filter.intensity
                    || targetSettings != layer.filterSettings.normalized()
            else {
                return nil
            }
            return FilterLayerChange(
                index: index,
                kind: filter.kind,
                intensity: targetIntensity,
                settings: targetSettings
            )
        }
        guard !changes.isEmpty else { return 0 }

        pushUndo()
        for change in changes {
            document.layers[change.index].kind = .filter(change.kind, change.intensity)
            document.layers[change.index].filterSettings = change.settings
        }
        syncFilterControlsFromSelection()
        appendHistory(
            L10n.text(
                changes.count == 1
                    ? "imageEditor.history.layerFilterUpdate"
                    : "imageEditor.history.layerFilterUpdateSelected"
            )
        )
        if changes.count > 1 {
            statusText = L10n.format(
                "imageEditor.status.layerFilterUpdatedSelected",
                changes.count
            )
        }
        return changes.count
    }
}

private struct FilterLayerChange {
    let index: Int
    let kind: ImageEditorFilter
    let intensity: Double
    let settings: ImageEditorFilterSettings
}
