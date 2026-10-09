import AppKit

@MainActor
extension ImageEditorViewModel {
    var smartFilterMaskSoloPreviewImage: NSImage? {
        guard let filterID = previewedSmartFilterMaskID,
              let layerIndex = document.selectedLayerIndex,
              document.layers.indices.contains(layerIndex),
              let layer = document.selectedLayer,
              let mask = layer.smartFilters.first(where: { $0.id == filterID })?.mask,
              mask.width > 0,
              mask.height > 0,
              mask.width <= Int.max / mask.height,
              mask.alpha.count == mask.width * mask.height
        else { return nil }
        if let cached = cachedSmartFilterMaskSoloPreviewImages[filterID] {
            return cached
        }

        guard let localMask = NSImage.selectionMaskImage(
            mask,
            inverted: false,
            targetSize: layer.image.size
        ), let canvasMask = canvasMaskImage(fromLayerMask: localMask, layer: layer),
           let preview = canvasMask.grayscaleAlphaPreviewImage(targetSize: document.canvasSize)
        else { return nil }
        cachedSmartFilterMaskSoloPreviewImages[filterID] = preview
        return preview
    }

    var smartFilterMaskOverlayImage: NSImage? {
        guard let filterID = editingSmartFilterMaskID,
              let layerIndex = document.selectedLayerIndex,
              document.layers.indices.contains(layerIndex),
              let filter = document.layers[layerIndex].smartFilters.first(where: { $0.id == filterID }),
              !filter.appliesToBackdrop,
              let mask = filter.mask,
              mask.width > 0,
              mask.height > 0,
              mask.width <= Int.max / mask.height,
              mask.alpha.count == mask.width * mask.height
        else { return nil }
        if let cached = cachedSmartFilterMaskOverlayImages[filterID] {
            return cached
        }

        let layer = document.layers[layerIndex]
        guard layer.image.size.width > 0,
              layer.image.size.height > 0,
              let sourceMask = NSImage.selectionMaskImage(
                mask,
                inverted: filter.isMaskInverted,
                targetSize: layer.image.size
              ),
              let processedMask = sourceMask.processedLayerMask(
                density: filter.normalizedMaskDensity,
                feather: filter.normalizedMaskFeather,
                samplingScale: filter.pixelSamplingScale
              ),
              let alphaMask = processedMask.imageEditorSelectionMask(targetSize: layer.image.size)
        else { return nil }

        let maskSelection = ImageEditorSelection.raster(
            mask: alphaMask,
            bounds: CGRect(origin: .zero, size: layer.image.size)
        )
        let preferences = ImageEditorQuickMaskPreferences.defaultValue
        guard let overlay = maskSelection.quickMaskOverlayImage(
            canvasSize: layer.image.size,
            color: preferences.color.nsColor,
            opacity: CGFloat(preferences.opacity),
            target: .maskedAreas
        ) else { return nil }
        cachedSmartFilterMaskOverlayImages[filterID] = overlay
        return overlay
    }
}
