nonisolated enum ImageEditorLayerBlendIfEditKind: String, CaseIterable, Sendable {
    case sourceBlack
    case sourceWhite
    case underlyingBlack
    case underlyingWhite
}

enum ImageEditorLayerBlendIfCompletionOwnership {
    nonisolated static func mayFinish(
        active: ImageEditorLayerBlendIfEditKind?,
        ending: ImageEditorLayerBlendIfEditKind
    ) -> Bool {
        active == ending
    }
}
