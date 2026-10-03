import Foundation

enum ImageEditorTransformCommitPolicy {
    static let minimumRotationDegrees: CGFloat = 0.01
    static let frameRoundingTolerance: CGFloat = 1e-9
}

struct ImageEditorXomoThemeUndoState {
    var theme: XomoComponentTheme
    var tokenSnapshot: XomoComponentThemeTokenSnapshot?
}

struct ImageEditorTransformRedoSnapshot {
    var documents: [ImageEditorDocument]
    var themes: [ImageEditorXomoThemeUndoState]
}

struct ImageEditorUndoTransactionState {
    var undoThemes: [ImageEditorXomoThemeUndoState] = []
    var redoThemes: [ImageEditorXomoThemeUndoState] = []
    // nil means no transaction; an empty Redo stack is still a valid snapshot.
    var transformRedo: ImageEditorTransformRedoSnapshot?
}

@MainActor
extension ImageEditorViewModel {
    var hasActiveSelectedLayerTransformTransaction: Bool {
        undoTransactionState.transformRedo != nil
    }

    func pushUndo() {
        undoStack.append(document)
        undoTransactionState.undoThemes.append(ImageEditorXomoThemeUndoState(
            theme: xomoComponentTheme, tokenSnapshot: xomoLocalThemeTokenSnapshot
        ))
        redoStack.removeAll()
        undoTransactionState.redoThemes.removeAll()
    }

    @discardableResult
    func beginTransformUndoTransaction() -> Bool {
        guard !hasActiveSelectedLayerTransformTransaction else { return false }
        undoTransactionState.transformRedo = ImageEditorTransformRedoSnapshot(
            documents: redoStack, themes: undoTransactionState.redoThemes
        )
        pushUndo()
        return true
    }

    func finishTransformUndoTransaction(didChange: Bool) {
        guard let snapshot = undoTransactionState.transformRedo else { return }
        if !didChange {
            if let originalDocument = discardLastUndoSnapshot() {
                document = originalDocument
            }
            redoStack = snapshot.documents
            undoTransactionState.redoThemes = snapshot.themes
        }
        undoTransactionState.transformRedo = nil
    }

    @discardableResult
    func discardLastUndoSnapshot() -> ImageEditorDocument? {
        let snapshot = undoStack.popLast()
        if !undoTransactionState.undoThemes.isEmpty {
            undoTransactionState.undoThemes.removeLast()
        }
        return snapshot
    }
}
