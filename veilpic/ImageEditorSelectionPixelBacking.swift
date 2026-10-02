import AppKit

extension ImageEditorLayer {
    /// A destructive canvas-pixel edit needs at least one retained sample per
    /// displayed pixel. A uniform multiplier preserves local effect lengths.
    func selectionPixelEditingBacking() -> ImageEditorLayer? {
        guard [frame.minX, frame.minY, frame.width, frame.height,
               image.size.width, image.size.height].allSatisfy(\.isFinite),
              frame.width > 0, frame.height > 0,
              let outputSize = ImageEditorMaskSampling.promotedMaskSize(image.size, minimum: frame.size)
        else { return nil }
        guard outputSize != image.size else { return self }
        guard let pixels = image.resized(to: outputSize) else { return nil }

        var backing = self
        backing.image = pixels
        let scale = outputSize.width / image.size.width
        backing.style = style.scaled(by: scale)
        backing.smartFilters = smartFilters.map { $0.rescaledForPixelBacking(by: Double(scale)) }
        // Pixel editing does not move either kind of mask, regardless of its
        // whole-layer link state. Map vector-local coordinates to the new grid.
        var stationaryMasks = self
        stationaryMasks.isMaskLinked = false
        guard backing.compensateUnlinkedLocalMasks(from: stationaryMasks) else { return nil }
        return backing
    }
}

private extension ImageEditorSmartFilter {
    func rescaledForPixelBacking(by scale: Double) -> Self {
        // Backdrop filters use canvas units, not this layer's local bitmap grid.
        guard !appliesToBackdrop else { return self }
        var filter = self
        filter.pixelSamplingScale = renderingSettings.renderingScale * scale
        return filter
    }
}
