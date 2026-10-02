import AppKit

extension ImageEditorViewModel {
    /// Prepare whole layers before committing: promotion also changes local
    /// mask/effect units, and a failed target must not leave a partial clear.
    func applySelectionPixelClear(at indices: [Int], render: (ImageEditorLayer) -> NSImage?) {
        var edits: [(index: Int, layer: ImageEditorLayer)] = []
        for index in indices {
            guard var backing = document.layers[index].selectionPixelEditingBacking(),
                  let output = render(backing)?.normalizedBitmapImage(),
                  let sourceData = backing.image.normalizedBitmapImage().qingtuPNGData(),
                  let outputData = output.qingtuPNGData()
            else {
                statusText = L10n.text("imageEditor.status.operationFailed")
                return
            }
            // Compare on the promoted grid. An equivalent result must not
            // retain a new backing, mutate metadata, or discard pending Redo.
            guard sourceData != outputData else { continue }
            backing.image = output
            edits.append((index, backing))
        }
        guard !edits.isEmpty else {
            statusText = L10n.text("imageEditor.status.selectionEmpty")
            return
        }

        pushUndo()
        for edit in edits { document.layers[edit.index] = edit.layer }
        appendHistory(L10n.text(edits.count == 1
            ? "imageEditor.history.selectionClearPixels"
            : "imageEditor.history.selectionClearPixelsSelected"))
        statusText = edits.count == 1
            ? L10n.text("imageEditor.status.selectionPixelsCleared")
            : L10n.format("imageEditor.status.selectionPixelsClearedSelected", edits.count)
    }
}
