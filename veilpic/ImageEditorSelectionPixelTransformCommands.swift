import AppKit

extension ImageEditorViewModel {
    var canFlipSelectedPixels: Bool {
        guard !isQuickMaskMode,
              !isEditingLayerMask,
              feather.isFinite,
              let selection = document.selection
        else { return false }

        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        guard !selectedIDs.isEmpty else { return false }
        let selectedIndices = document.layers.indices.filter { selectedIDs.contains(document.layers[$0].id) }
        guard selectedIndices.count == selectedIDs.count else { return false }
        return selectedIndices.allSatisfy { index in
            let layer = document.layers[index]
            return layer.kind.isPixel
                && !document.isEffectivelyPixelsLocked(layer)
                && !document.isEffectivelyTransparencyLocked(layer)
                && selection.mayAffect(
                    layerFrame: layer.frame,
                    canvasSize: document.canvasSize,
                    expansion: feather
                )
        }
    }

    func flipSelectedPixelsHorizontally() {
        flipSelectedPixels(horizontally: true)
    }

    func flipSelectedPixelsVertically() {
        flipSelectedPixels(horizontally: false)
    }

    private func flipSelectedPixels(horizontally: Bool) {
        guard canFlipSelectedPixels else { return }
        finishActiveCanvasEditForNewCommand()
        guard let selection = document.selection,
              let flippedSelection = selection.flipped(horizontal: horizontally, canvasSize: document.canvasSize)
        else {
            statusText = L10n.text("imageEditor.status.operationFailed")
            return
        }
        let selectionCoverageChanged: Bool
        if let originalMask = selection.rasterizedMask(canvasSize: document.canvasSize),
           let transformedMask = flippedSelection.rasterizedMask(canvasSize: document.canvasSize) {
            selectionCoverageChanged = originalMask != transformedMask
        } else {
            selectionCoverageChanged = flippedSelection != selection
        }
        let committedSelection = selectionCoverageChanged ? flippedSelection : selection

        let selectedIDs = document.selectedLayerIDs.isEmpty
            ? Set(document.selectedLayerID.map { [$0] } ?? [])
            : document.selectedLayerIDs
        let selectedIndices = document.layers.indices.filter { selectedIDs.contains(document.layers[$0].id) }
        var updatedLayers = document.layers
        var pixelDataChanged = false

        for index in selectedIndices {
            guard let result = flippedLayer(
                document.layers[index], selection: selection, horizontally: horizontally
            ) else {
                statusText = L10n.text("imageEditor.status.operationFailed")
                return
            }
            if result.pixelDataChanged {
                pixelDataChanged = true
                updatedLayers[index] = result.layer
            }
        }

        guard pixelDataChanged || selectionCoverageChanged else {
            statusText = L10n.text("imageEditor.status.selectionUnchanged")
            return
        }

        var updatedDocument = document
        updatedDocument.layers = updatedLayers
        updatedDocument.selection = committedSelection
        pushUndo()
        document = updatedDocument

        let historyKey = horizontally
            ? "imageEditor.history.selectionPixelsFlipHorizontal"
            : "imageEditor.history.selectionPixelsFlipVertical"
        let statusKey = horizontally
            ? "imageEditor.status.selectionPixelsFlippedHorizontal"
            : "imageEditor.status.selectionPixelsFlippedVertical"
        appendHistory(L10n.text(historyKey))
        statusText = L10n.text(statusKey)
    }

    private func flippedLayer(
        _ layer: ImageEditorLayer, selection: ImageEditorSelection, horizontally: Bool
    ) -> (layer: ImageEditorLayer, pixelDataChanged: Bool)? {
        guard let backingLayer = layer.expandedPixelSelectionTransformBacking(
            selection: selection, canvasSize: document.canvasSize, feather: feather
        ) else { return nil }
        let width = Int(backingLayer.image.size.width.rounded())
        let height = Int(backingLayer.image.size.height.rounded())
        guard let maskImage = selection.layerMask(
            layerFrame: backingLayer.frame,
            layerSize: backingLayer.image.size,
            canvasSize: document.canvasSize,
            feather: feather,
            usesNearestSampling: true
        ), let mask = ImageEditorPixelMoveMaskAlpha.read(from: maskImage, width: width, height: height),
           let source = ImageEditorRGBAImage.pixels(from: backingLayer.image, width: width, height: height),
           let output = ImageEditorPixelSelectionTransform.flipped(
               source: source, maskAlpha: mask, width: width, height: height, horizontally: horizontally
           ), let image = ImageEditorRGBAImage.image(
               width: width, height: height, pixels: output, size: backingLayer.image.size
           )
        else { return nil }

        var result = backingLayer
        result.image = image
        return (result, source != output)
    }
}
