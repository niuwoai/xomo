import Foundation

fileprivate enum ImageEditorLayerMaskPropertyEditKind {
    case density
    case feather

    var historyKey: String {
        switch self {
        case .density: "imageEditor.history.layerMaskDensity"
        case .feather: "imageEditor.history.layerMaskFeather"
        }
    }
}

fileprivate enum ImageEditorLayerOpacityEditKind {
    case opacity
    case fillOpacity

    var historyKey: String {
        switch self {
        case .opacity: "imageEditor.history.layerOpacity"
        case .fillOpacity: "imageEditor.history.layerFillOpacity"
        }
    }
}

@MainActor
final class ImageEditorLayerPropertyTransactionState {
    var activeGesture: ImageEditorLayerPropertyGesture?
    fileprivate var activeLayerMaskPropertyEdit: ImageEditorLayerMaskPropertyEditKind?
    fileprivate var activeLayerMaskPropertyTargetIDs = Set<UUID>()
    fileprivate var activeLayerMaskPropertyRedoStack: [ImageEditorDocument] = []
    fileprivate var activeLayerMaskPropertyRedoThemeStates: [ImageEditorXomoThemeUndoState] = []
    fileprivate var activeLayerOpacityEdit: ImageEditorLayerOpacityEditKind?
    fileprivate var activeLayerOpacityTargetIDs = Set<UUID>()
    fileprivate var activeLayerOpacityRedoStack: [ImageEditorDocument] = []
    fileprivate var activeLayerOpacityRedoThemeStates: [ImageEditorXomoThemeUndoState] = []
    fileprivate var activeLayerBlendIfEdit: ImageEditorLayerBlendIfEditKind?
    fileprivate var activeLayerBlendIfTargetIDs = Set<UUID>()
    fileprivate var activeLayerBlendIfRedoStack: [ImageEditorDocument] = []
    fileprivate var activeLayerBlendIfRedoThemeStates: [ImageEditorXomoThemeUndoState] = []
}

@MainActor
extension ImageEditorViewModel {
    func setSelectedLayerOpacity(_ opacity: Double) {
        let normalizedOpacity = max(0, min(1, opacity))
        let indices = layerOpacityTargetIndices(for: .opacity).filter {
            document.layers[$0].opacity != normalizedOpacity
        }
        guard !indices.isEmpty else { return }
        for index in indices {
            document.layers[index].opacity = normalizedOpacity
        }
        invalidateRenderedImageCaches()
        updateStatus()
    }

    func setSelectedLayerFillOpacity(_ fillOpacity: Double) {
        let normalizedOpacity = max(0, min(1, fillOpacity))
        let indices = layerOpacityTargetIndices(for: .fillOpacity).filter {
            document.layers[$0].fillOpacity != normalizedOpacity
        }
        guard !indices.isEmpty else { return }
        for index in indices {
            document.layers[index].fillOpacity = normalizedOpacity
        }
        invalidateRenderedImageCaches()
        updateStatus()
    }

    func setSelectedLayerBlendIfSourceBlack(_ value: Double) {
        let indices = layerBlendIfTargetIndices(for: .sourceBlack)
        guard !indices.isEmpty else { return }
        var didChange = false
        for index in indices {
            let white = document.layers[index].blendIfSourceWhite
            let nextValue = min(max(0, value), white)
            guard document.layers[index].blendIfSourceBlack != nextValue else { continue }
            document.layers[index].blendIfSourceBlack = nextValue
            didChange = true
        }
        if didChange {
            updateStatus()
        }
    }

    func setSelectedLayerBlendIfSourceWhite(_ value: Double) {
        let indices = layerBlendIfTargetIndices(for: .sourceWhite)
        guard !indices.isEmpty else { return }
        var didChange = false
        for index in indices {
            let black = document.layers[index].blendIfSourceBlack
            let nextValue = max(black, min(1, value))
            guard document.layers[index].blendIfSourceWhite != nextValue else { continue }
            document.layers[index].blendIfSourceWhite = nextValue
            didChange = true
        }
        if didChange {
            updateStatus()
        }
    }

    func setSelectedLayerBlendIfUnderlyingBlack(_ value: Double) {
        let indices = layerBlendIfTargetIndices(for: .underlyingBlack)
        guard !indices.isEmpty else { return }
        var didChange = false
        for index in indices {
            let white = document.layers[index].blendIfUnderlyingWhite
            let nextValue = min(max(0, value), white)
            guard document.layers[index].blendIfUnderlyingBlack != nextValue else { continue }
            document.layers[index].blendIfUnderlyingBlack = nextValue
            didChange = true
        }
        if didChange {
            updateStatus()
        }
    }

    func setSelectedLayerBlendIfUnderlyingWhite(_ value: Double) {
        let indices = layerBlendIfTargetIndices(for: .underlyingWhite)
        guard !indices.isEmpty else { return }
        var didChange = false
        for index in indices {
            let black = document.layers[index].blendIfUnderlyingBlack
            let nextValue = max(black, min(1, value))
            guard document.layers[index].blendIfUnderlyingWhite != nextValue else { continue }
            document.layers[index].blendIfUnderlyingWhite = nextValue
            didChange = true
        }
        if didChange {
            updateStatus()
        }
    }

    func setSelectedLayerMaskDensity(_ density: Double) {
        let normalizedDensity = max(0, min(1, density))
        let indices = layerMaskPropertyTargetIndices(for: .density).filter {
            document.layers[$0].maskDensity != normalizedDensity
        }
        guard !indices.isEmpty else { return }
        for index in indices {
            document.layers[index].maskDensity = normalizedDensity
        }
        updateStatus()
    }

    func setSelectedLayerMaskFeather(_ feather: Double) {
        let normalizedFeather = max(0, min(80, feather))
        let indices = layerMaskPropertyTargetIndices(for: .feather).filter {
            document.layers[$0].maskFeather != normalizedFeather
        }
        guard !indices.isEmpty else { return }
        for index in indices {
            document.layers[index].maskFeather = normalizedFeather
        }
        updateStatus()
    }

    func setSelectedLayerBlendMode(_ blendMode: ImageEditorBlendMode) {
        let indices = selectedLayerBlendModeTargetIndices(for: blendMode).filter { document.layers[$0].blendMode != blendMode }
        guard !indices.isEmpty else { return }
        pushUndo()
        for index in indices {
            document.layers[index].blendMode = blendMode
        }
        appendHistory(L10n.text("imageEditor.history.layerBlendMode"))
    }

    var hasActiveLayerPropertyEdit: Bool {
        layerPropertyTransactionState.activeLayerOpacityEdit != nil || layerPropertyTransactionState.activeLayerBlendIfEdit != nil || layerPropertyTransactionState.activeLayerMaskPropertyEdit != nil
    }

    func finishActiveLayerPropertyEditForNewCommand() {
        layerPropertyTransactionState.activeGesture = nil
        finishActiveLayerOpacityPropertyChange()
        finishActiveLayerBlendIfChange()
        finishActiveLayerMaskPropertyChange()
    }

    func resetLayerPropertyEditTransactions() {
        layerPropertyTransactionState.activeGesture = nil
        layerPropertyTransactionState.activeLayerOpacityEdit = nil
        layerPropertyTransactionState.activeLayerOpacityTargetIDs = []
        layerPropertyTransactionState.activeLayerOpacityRedoStack = []
        layerPropertyTransactionState.activeLayerOpacityRedoThemeStates = []
        layerPropertyTransactionState.activeLayerBlendIfEdit = nil
        layerPropertyTransactionState.activeLayerBlendIfTargetIDs = []
        layerPropertyTransactionState.activeLayerBlendIfRedoStack = []
        layerPropertyTransactionState.activeLayerBlendIfRedoThemeStates = []
        layerPropertyTransactionState.activeLayerMaskPropertyEdit = nil
        layerPropertyTransactionState.activeLayerMaskPropertyTargetIDs = []
        layerPropertyTransactionState.activeLayerMaskPropertyRedoStack = []
        layerPropertyTransactionState.activeLayerMaskPropertyRedoThemeStates = []
    }

    func beginSelectedLayerOpacityChange() {
        beginSelectedLayerOpacityPropertyChange(.opacity)
    }

    func commitSelectedLayerOpacityChange() {
        finishSelectedLayerOpacityPropertyChange(.opacity)
    }

    func beginSelectedLayerFillOpacityChange() {
        beginSelectedLayerOpacityPropertyChange(.fillOpacity)
    }

    func commitSelectedLayerFillOpacityChange() {
        finishSelectedLayerOpacityPropertyChange(.fillOpacity)
    }

    func beginSelectedLayerBlendIfSourceBlackChange() {
        beginSelectedLayerBlendIfChange(.sourceBlack)
    }

    func beginSelectedLayerBlendIfSourceWhiteChange() {
        beginSelectedLayerBlendIfChange(.sourceWhite)
    }

    func beginSelectedLayerBlendIfUnderlyingBlackChange() {
        beginSelectedLayerBlendIfChange(.underlyingBlack)
    }

    func beginSelectedLayerBlendIfUnderlyingWhiteChange() {
        beginSelectedLayerBlendIfChange(.underlyingWhite)
    }

    func commitSelectedLayerBlendIfChange(_ kind: ImageEditorLayerBlendIfEditKind) {
        guard ImageEditorLayerBlendIfCompletionOwnership.mayFinish(
            active: layerPropertyTransactionState.activeLayerBlendIfEdit, ending: kind
        ) else { return }
        finishActiveLayerBlendIfChange()
    }

    private func beginSelectedLayerBlendIfChange(_ kind: ImageEditorLayerBlendIfEditKind) {
        layerPropertyTransactionState.activeGesture = nil
        if layerPropertyTransactionState.activeLayerBlendIfEdit == kind { return }
        finishActiveLayerBlendIfChange()

        let indices = selectedLayerBlendIfTargetIndices()
        guard !indices.isEmpty else { return }
        finishActiveCanvasEditForNewCommand()
        layerPropertyTransactionState.activeLayerBlendIfRedoStack = redoStack
        layerPropertyTransactionState.activeLayerBlendIfRedoThemeStates = undoTransactionState.redoThemes
        pushUndo()
        layerPropertyTransactionState.activeLayerBlendIfEdit = kind
        layerPropertyTransactionState.activeLayerBlendIfTargetIDs = Set(indices.map { document.layers[$0].id })
    }

    private func finishActiveLayerBlendIfChange() {
        guard let kind = layerPropertyTransactionState.activeLayerBlendIfEdit else { return }
        layerPropertyTransactionState.activeGesture = nil
        let targetIDs = layerPropertyTransactionState.activeLayerBlendIfTargetIDs
        let snapshot = undoStack.last
        let didChange = snapshot.map {
            layerBlendIfValuesDiffer(kind, targetIDs: targetIDs, from: $0)
        } ?? false

        layerPropertyTransactionState.activeLayerBlendIfEdit = nil
        layerPropertyTransactionState.activeLayerBlendIfTargetIDs = []
        if didChange {
            appendHistory(L10n.text("imageEditor.history.layerBlendIf"))
        } else {
            _ = discardLastUndoSnapshot()
            redoStack = layerPropertyTransactionState.activeLayerBlendIfRedoStack
            undoTransactionState.redoThemes = layerPropertyTransactionState.activeLayerBlendIfRedoThemeStates
            updateStatus()
        }
        layerPropertyTransactionState.activeLayerBlendIfRedoStack = []
        layerPropertyTransactionState.activeLayerBlendIfRedoThemeStates = []
    }

    private func layerBlendIfTargetIndices(for kind: ImageEditorLayerBlendIfEditKind) -> [Int] {
        guard layerPropertyTransactionState.activeLayerBlendIfEdit == kind else {
            return selectedLayerBlendIfTargetIndices()
        }
        return document.layers.indices.filter {
            layerPropertyTransactionState.activeLayerBlendIfTargetIDs.contains(document.layers[$0].id)
                && !document.isEffectivelyLocked(document.layers[$0])
                && !document.layers[$0].isGroup
        }
    }

    private func layerBlendIfValuesDiffer(
        _ kind: ImageEditorLayerBlendIfEditKind,
        targetIDs: Set<UUID>,
        from snapshot: ImageEditorDocument
    ) -> Bool {
        for id in targetIDs {
            guard let current = document.layers.first(where: { $0.id == id }),
                  let previous = snapshot.layers.first(where: { $0.id == id })
            else { return true }
            switch kind {
            case .sourceBlack:
                if current.blendIfSourceBlack != previous.blendIfSourceBlack { return true }
            case .sourceWhite:
                if current.blendIfSourceWhite != previous.blendIfSourceWhite { return true }
            case .underlyingBlack:
                if current.blendIfUnderlyingBlack != previous.blendIfUnderlyingBlack { return true }
            case .underlyingWhite:
                if current.blendIfUnderlyingWhite != previous.blendIfUnderlyingWhite { return true }
            }
        }
        return false
    }

    private func beginSelectedLayerOpacityPropertyChange(_ kind: ImageEditorLayerOpacityEditKind) {
        layerPropertyTransactionState.activeGesture = nil
        if layerPropertyTransactionState.activeLayerOpacityEdit == kind { return }
        finishActiveLayerOpacityPropertyChange()

        let indices = kind == .opacity
            ? selectedLayerOpacityTargetIndices()
            : selectedLayerFillOpacityTargetIndices()
        guard !indices.isEmpty else { return }
        // Finalize the preceding preview's branch before saving the Redo
        // state that this property's no-op completion may later restore.
        finishActiveCanvasEditForNewCommand()
        layerPropertyTransactionState.activeLayerOpacityRedoStack = redoStack
        layerPropertyTransactionState.activeLayerOpacityRedoThemeStates = undoTransactionState.redoThemes
        pushUndo()
        layerPropertyTransactionState.activeLayerOpacityEdit = kind
        layerPropertyTransactionState.activeLayerOpacityTargetIDs = Set(indices.map { document.layers[$0].id })
    }

    private func finishSelectedLayerOpacityPropertyChange(_ kind: ImageEditorLayerOpacityEditKind) {
        guard layerPropertyTransactionState.activeLayerOpacityEdit == kind else { return }
        finishActiveLayerOpacityPropertyChange()
    }

    private func finishActiveLayerOpacityPropertyChange() {
        guard let kind = layerPropertyTransactionState.activeLayerOpacityEdit else { return }
        layerPropertyTransactionState.activeGesture = nil
        let targetIDs = layerPropertyTransactionState.activeLayerOpacityTargetIDs
        let snapshot = undoStack.last
        let didChange = snapshot.map {
            layerOpacityValuesDiffer(kind, targetIDs: targetIDs, from: $0)
        } ?? false

        layerPropertyTransactionState.activeLayerOpacityEdit = nil
        layerPropertyTransactionState.activeLayerOpacityTargetIDs = []
        if didChange {
            appendHistory(L10n.text(kind.historyKey))
        } else {
            _ = discardLastUndoSnapshot()
            redoStack = layerPropertyTransactionState.activeLayerOpacityRedoStack
            undoTransactionState.redoThemes = layerPropertyTransactionState.activeLayerOpacityRedoThemeStates
            updateStatus()
        }
        layerPropertyTransactionState.activeLayerOpacityRedoStack = []
        layerPropertyTransactionState.activeLayerOpacityRedoThemeStates = []
    }

    private func layerOpacityTargetIndices(for kind: ImageEditorLayerOpacityEditKind) -> [Int] {
        guard layerPropertyTransactionState.activeLayerOpacityEdit == kind else {
            return kind == .opacity
                ? selectedLayerOpacityTargetIndices()
                : selectedLayerFillOpacityTargetIndices()
        }
        return document.layers.indices.filter {
            layerPropertyTransactionState.activeLayerOpacityTargetIDs.contains(document.layers[$0].id)
                && !document.isEffectivelyLocked(document.layers[$0])
                && (kind == .opacity || !document.layers[$0].isGroup)
        }
    }

    private func layerOpacityValuesDiffer(
        _ kind: ImageEditorLayerOpacityEditKind,
        targetIDs: Set<UUID>,
        from snapshot: ImageEditorDocument
    ) -> Bool {
        for id in targetIDs {
            guard let current = document.layers.first(where: { $0.id == id }),
                  let previous = snapshot.layers.first(where: { $0.id == id })
            else { return true }
            switch kind {
            case .opacity:
                if current.opacity != previous.opacity { return true }
            case .fillOpacity:
                if current.fillOpacity != previous.fillOpacity { return true }
            }
        }
        return false
    }

    func beginSelectedLayerMaskDensityChange() {
        beginSelectedLayerMaskPropertyChange(.density)
    }

    func commitSelectedLayerMaskDensityChange() {
        finishSelectedLayerMaskPropertyChange(.density)
    }

    func beginSelectedLayerMaskFeatherChange() {
        beginSelectedLayerMaskPropertyChange(.feather)
    }

    func commitSelectedLayerMaskFeatherChange() {
        finishSelectedLayerMaskPropertyChange(.feather)
    }

    private func beginSelectedLayerMaskPropertyChange(_ kind: ImageEditorLayerMaskPropertyEditKind) {
        layerPropertyTransactionState.activeGesture = nil
        if layerPropertyTransactionState.activeLayerMaskPropertyEdit == kind { return }
        finishActiveLayerMaskPropertyChange()

        let indices = selectedLayerMaskPropertyTargetIndices()
        guard !indices.isEmpty else { return }
        finishActiveCanvasEditForNewCommand()
        layerPropertyTransactionState.activeLayerMaskPropertyRedoStack = redoStack
        layerPropertyTransactionState.activeLayerMaskPropertyRedoThemeStates = undoTransactionState.redoThemes
        pushUndo()
        layerPropertyTransactionState.activeLayerMaskPropertyEdit = kind
        layerPropertyTransactionState.activeLayerMaskPropertyTargetIDs = Set(indices.map { document.layers[$0].id })
    }

    private func finishSelectedLayerMaskPropertyChange(_ kind: ImageEditorLayerMaskPropertyEditKind) {
        guard layerPropertyTransactionState.activeLayerMaskPropertyEdit == kind else { return }
        finishActiveLayerMaskPropertyChange()
    }

    private func finishActiveLayerMaskPropertyChange() {
        guard let kind = layerPropertyTransactionState.activeLayerMaskPropertyEdit else { return }
        layerPropertyTransactionState.activeGesture = nil
        let targetIDs = layerPropertyTransactionState.activeLayerMaskPropertyTargetIDs
        let snapshot = undoStack.last
        let didChange = snapshot.map {
            layerMaskPropertyValuesDiffer(kind, targetIDs: targetIDs, from: $0)
        } ?? false

        layerPropertyTransactionState.activeLayerMaskPropertyEdit = nil
        layerPropertyTransactionState.activeLayerMaskPropertyTargetIDs = []
        if didChange {
            appendHistory(L10n.text(kind.historyKey))
        } else {
            _ = discardLastUndoSnapshot()
            redoStack = layerPropertyTransactionState.activeLayerMaskPropertyRedoStack
            undoTransactionState.redoThemes = layerPropertyTransactionState.activeLayerMaskPropertyRedoThemeStates
            updateStatus()
        }
        layerPropertyTransactionState.activeLayerMaskPropertyRedoStack = []
        layerPropertyTransactionState.activeLayerMaskPropertyRedoThemeStates = []
    }

    private func layerMaskPropertyTargetIndices(
        for kind: ImageEditorLayerMaskPropertyEditKind
    ) -> [Int] {
        guard layerPropertyTransactionState.activeLayerMaskPropertyEdit == kind else {
            return selectedLayerMaskPropertyTargetIndices()
        }
        return document.layers.indices.filter {
            layerPropertyTransactionState.activeLayerMaskPropertyTargetIDs.contains(document.layers[$0].id)
                && !document.isEffectivelyLocked(document.layers[$0])
                && document.layers[$0].mask != nil
        }
    }

    private func layerMaskPropertyValuesDiffer(
        _ kind: ImageEditorLayerMaskPropertyEditKind,
        targetIDs: Set<UUID>,
        from snapshot: ImageEditorDocument
    ) -> Bool {
        for id in targetIDs {
            guard let current = document.layers.first(where: { $0.id == id }),
                  let previous = snapshot.layers.first(where: { $0.id == id })
            else { return true }
            switch kind {
            case .density:
                if current.maskDensity != previous.maskDensity { return true }
            case .feather:
                if current.maskFeather != previous.maskFeather { return true }
            }
        }
        return false
    }

}
