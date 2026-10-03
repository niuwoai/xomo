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
        // A new editor command owns a separate undo step. Commit the last
        // successful transform preview before capturing that command's input;
        // otherwise cancellation would pop the command's snapshot instead.
        finishSelectedLayerTransformForNewEdit()
        appendUndoSnapshot()
    }

    /// Deferred commands must call this before capturing their own original
    /// document, not after replaying that document at commit time.
    func finishSelectedLayerTransformForNewEdit() {
        if !rotatingLayerIDs.isEmpty {
            finishRotatingSelectedLayer()
        } else if !resizingLayerIDs.isEmpty {
            finishResizingSelectedLayer()
        }
    }

    private func appendUndoSnapshot() {
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
        // Begin must not route through pushUndo's ordinary-command boundary.
        appendUndoSnapshot()
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
