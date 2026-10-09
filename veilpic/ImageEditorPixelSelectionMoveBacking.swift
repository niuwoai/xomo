import AppKit

extension ImageEditorLayer {
    /// Grow the local bitmap without rescaling retained pixels or moving masks
    /// in canvas space. Every preview starts from the original layer snapshot.
    func expandedPixelSelectionMoveBacking(
        selection: ImageEditorSelection, by delta: CGSize,
        canvasSize: CGSize, feather: CGFloat
    ) -> ImageEditorLayer? {
        guard delta.width.isFinite, delta.height.isFinite, feather.isFinite else { return nil }
        guard let selectedBounds = selection.effectiveSelectedBounds(in: canvasSize) else { return self }
        let affected = feather > 0 ? frame : selectedBounds.intersection(frame)
        guard !affected.isNull, !affected.isEmpty else { return self }
        let destination = affected.offsetBy(dx: delta.width, dy: delta.height)
        guard let expansion = ImageEditorPixelMoveExpansion(layer: self, destination: destination) else { return nil }
        guard expansion.frame != frame else { return self }
        guard let expandedImage = image.canvasResized(
            to: expansion.size, oldCanvasSize: image.size, offset: expansion.bitmapOffset
        ) else { return nil }

        var expanded = self
        expanded.image = expandedImage
        expanded.frame = expansion.frame
        // Link state governs whole-layer moves, not a selection's pixel edit.
        var stationaryMasks = self
        stationaryMasks.isMaskLinked = false
        guard expanded.compensateUnlinkedLocalMasks(from: stationaryMasks) else { return nil }
        return expanded
    }

    func expandedPixelSelectionTransformBacking(
        selection: ImageEditorSelection, canvasSize: CGSize, feather: CGFloat
    ) -> ImageEditorLayer? {
        guard feather.isFinite,
              let selectedBounds = selection.effectiveSelectedBounds(in: canvasSize)
        else { return nil }
        let expandedBounds = feather > 0
            ? selectedBounds.insetBy(dx: -feather * 3, dy: -feather * 3)
            : selectedBounds
        let destination = expandedBounds.intersection(CGRect(origin: .zero, size: canvasSize))
        guard !destination.isNull, !destination.isEmpty,
              let geometry = ImageEditorPixelMoveExpansion(layer: self, destination: destination)
        else { return nil }
        guard geometry.frame != frame else { return self }
        guard let expandedImage = image.canvasResized(
            to: geometry.size, oldCanvasSize: image.size, offset: geometry.bitmapOffset
        ) else { return nil }

        var expanded = self
        expanded.image = expandedImage
        expanded.frame = geometry.frame
        var stationaryMasks = self
        stationaryMasks.isMaskLinked = false
        guard expanded.compensateUnlinkedLocalMasks(from: stationaryMasks) else { return nil }
        return expanded
    }
}

private struct ImageEditorPixelMoveExpansion {
    let frame: CGRect
    let size: CGSize
    let bitmapOffset: CGSize

    init?(layer: ImageEditorLayer, destination: CGRect) {
        let original = layer.frame
        let imageSize = layer.image.size
        guard [original.minX, original.minY, original.width, original.height,
               destination.minX, destination.minY, destination.maxX, destination.maxY,
               imageSize.width, imageSize.height].allSatisfy(\.isFinite),
              original.width > 0, original.height > 0,
              imageSize.width > 0, imageSize.height > 0 else { return nil }
        let bounds = original.union(destination)
        let scaleX = imageSize.width / original.width
        let scaleY = imageSize.height / original.height
        let left = ceil(max(0, (original.minX - bounds.minX) * scaleX))
        let right = ceil(max(0, (bounds.maxX - original.maxX) * scaleX))
        let top = ceil(max(0, (original.minY - bounds.minY) * scaleY))
        let bottom = ceil(max(0, (bounds.maxY - original.maxY) * scaleY))
        let proposedSize = CGSize(width: imageSize.width + left + right,
                                  height: imageSize.height + top + bottom)
        guard let bitmapSize = ImageEditorMaskSampling.bitmapSize(proposedSize) else { return nil }
        size = bitmapSize
        frame = CGRect(x: original.minX - left / scaleX,
                       y: original.minY - top / scaleY,
                       width: size.width / scaleX, height: size.height / scaleY)
        bitmapOffset = CGSize(width: left, height: bottom)
    }
}
