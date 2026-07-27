//
//  ImageEditorAdjustmentLayerTransactions.swift
//  veilpic
//

import Foundation

@MainActor
extension ImageEditorViewModel {
    @discardableResult
    func replaceSelectedAdjustmentLayerValues(
        amount: Double?,
        settings: ImageEditorAdjustmentSettings?
    ) -> Int {
        guard amount != nil || settings != nil else { return 0 }

        let selectedIDs = document.selectedLayerIDs
        let normalizedSettings = settings?.normalized()
        let changes = document.layers.indices.compactMap { index -> AdjustmentLayerChange? in
            let layer = document.layers[index]
            guard
                selectedIDs.contains(layer.id),
                !document.isEffectivelyPixelsLocked(layer),
                let adjustment = layer.adjustment
            else {
                return nil
            }

            let targetAmount = amount.map {
                Self.normalizedAdjustmentAmount($0, for: adjustment.kind)
            } ?? adjustment.amount
            let targetSettings = normalizedSettings ?? layer.adjustmentSettings.normalized()
            guard
                targetAmount != adjustment.amount
                    || targetSettings != layer.adjustmentSettings.normalized()
            else {
                return nil
            }
            return AdjustmentLayerChange(
                index: index,
                kind: adjustment.kind,
                amount: targetAmount,
                settings: targetSettings
            )
        }
        guard !changes.isEmpty else { return 0 }

        pushUndo()
        for change in changes {
            document.layers[change.index].kind = .adjustment(change.kind, change.amount)
            document.layers[change.index].adjustmentSettings = change.settings
        }
        syncAdjustmentControlsFromSelection()
        appendHistory(
            L10n.text(
                changes.count == 1
                    ? "imageEditor.history.layerAdjustmentUpdate"
                    : "imageEditor.history.layerAdjustmentUpdateSelected"
            )
        )
        if changes.count > 1 {
            statusText = L10n.format(
                "imageEditor.status.layerAdjustmentUpdatedSelected",
                changes.count
            )
        }
        return changes.count
    }

    private static func normalizedAdjustmentAmount(
        _ amount: Double,
        for adjustment: ImageEditorAdjustment
    ) -> Double {
        switch adjustment {
        case .posterize:
            return Double(max(2, min(32, Int(amount.rounded()))))
        default:
            return max(-1, min(1, amount))
        }
    }
}

private struct AdjustmentLayerChange {
    let index: Int
    let kind: ImageEditorAdjustment
    let amount: Double
    let settings: ImageEditorAdjustmentSettings
}
