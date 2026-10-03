import Foundation

@MainActor
extension ImageEditorViewModel {
    /// Like a canvas drag, a property preview owns the stack top until its
    /// release. The first history command cancels it without traversing the
    /// pre-existing history or restoring a discarded branch later on mouse-up.
    @discardableResult
    func cancelActiveLayerPropertyEdit() -> Bool {
        guard hasActiveLayerPropertyEdit else { return false }
        guard let original = undoStack.last else {
            resetLayerPropertyEditTransactions()
            return true
        }
        // Restore the owned document before comparing values, so the existing
        // no-op completion discards exactly this snapshot and restores its Redo.
        document = original
        finishActiveLayerPropertyEditForNewCommand()
        return true
    }
}
