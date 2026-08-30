import Foundation

@MainActor
extension ImageEditorViewModel {
    /// Pointer previews own the top undo snapshot until they finish. Do not
    /// insert a second document transaction underneath their cleanup.
    var canImportFigmaNodePlan: Bool {
        !hasActiveLayerMoveTransaction
            && resizingLayerIDs.isEmpty
            && rotatingLayerIDs.isEmpty
            && movingGuideID == nil
            && !hasActivePathAnchorMoveTransaction
            && !hasPendingPenPathTransaction
            && !hasActiveGradientOverlayCenterTransaction
            && !hasActiveGradientOverlayAxisTransaction
            && !hasActiveGradientOverlayStopTransaction
            && !hasActiveGradientOverlayMidpointTransaction
    }

    var figmaImportEditingInProgressMessage: String {
        NSLocalizedString("finishEditing", tableName: "FigmaImport", comment: "")
    }
}
