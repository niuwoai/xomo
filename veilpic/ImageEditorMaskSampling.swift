import AppKit

enum ImageEditorMaskSampling {
    // Bound additional mask/render allocations; rejected edits keep the original document.
    static let maximumPixelCount: CGFloat = 64 * 1024 * 1024

    static func bitmapSize(_ proposed: CGSize) -> CGSize? {
        guard proposed.width.isFinite, proposed.height.isFinite,
              proposed.width > 0, proposed.height > 0 else { return nil }
        func pixelLength(_ value: CGFloat) -> CGFloat {
            let nearest = value.rounded()
            // Rotated integer dimensions can carry a few floating-point ULPs.
            // Do not allocate an extra column/row and resample an otherwise exact grid.
            return max(1, abs(value - nearest) < 0.000000001 ? nearest : ceil(value))
        }
        let size = CGSize(width: pixelLength(proposed.width), height: pixelLength(proposed.height))
        guard size.width * size.height <= maximumPixelCount else { return nil }
        return size
    }

    static func fixedBitmapSize(mask: NSImage, originalFrame: CGRect, targetFrame: CGRect) -> CGSize? {
        let original = originalFrame.standardized
        let target = targetFrame.standardized
        guard original.width > 0, original.height > 0 else { return nil }
        let density = max(mask.size.width / original.width, mask.size.height / original.height)
        // Nearest-pixel rounding prevents ceil feedback from inflating the mask
        // every time a fractional fit/fill frame is resized back to its origin.
        return bitmapSize(CGSize(width: max(1, (target.width * density).rounded()),
                                 height: max(1, (target.height * density).rounded())))
    }
}

extension ImageEditorLayer {
    /// Render a temporary pixel copy at sufficient density. Neither the retained
    /// source pixels nor the editable layer kind/project data are mutated.
    func highResolutionMaskRenderingLayer() -> (layer: ImageEditorLayer, scale: CGFloat)? {
        guard !isGroup, image.size.width > 0, image.size.height > 0,
              (isMaskEnabled && mask != nil) || (isVectorMaskEnabled && vectorMask != nil) else { return nil }
        let bounds = frame.standardized
        let rasterSize = isMaskEnabled ? (mask?.size ?? .zero) : .zero
        // Only stored raster detail needs promotion; enlarging the frame alone
        // cannot recover bitmap samples. Vector masks remain resolution-independent.
        let vectorSize = isVectorMaskEnabled && vectorMask != nil ? bounds.size : .zero
        let requiredSize = CGSize(width: max(image.size.width, vectorSize.width, rasterSize.width),
                                  height: max(image.size.height, vectorSize.height, rasterSize.height))
        let requiredScale = max(requiredSize.width / image.size.width, requiredSize.height / image.size.height)
        // Right-angle rotation/reload can leave a ratio like 1.0000000000000002.
        // Do not double the render grid for floating-point roundoff alone.
        let scale = ceil(requiredScale - 0.000000001)
        // Without effects, use the independent X/Y sampling grids. Promoting both
        // axes by the larger ratio forces needless downsampling on one axis and
        // can make a stationary vector edge shimmer during nonuniform movement.
        // Effects retain a uniform grid so radius/distance lengths stay isotropic.
        let proposedSize = style.hasEffects
            ? CGSize(width: image.size.width * scale, height: image.size.height * scale) : requiredSize
        guard scale > 1,
              let outputSize = ImageEditorMaskSampling.bitmapSize(proposedSize),
              let pixels = contentImage.resized(to: outputSize) else { return nil }
        var rendering = self
        rendering.image = pixels
        rendering.kind = .pixel
        rendering.smartFilters = []
        rendering.xomoFigmaImageFill = nil
        rendering.xomoFigmaImageFillSourceImage = nil
        // The frame is unchanged in a render copy, so raster masks already use
        // the correct normalized rectangle. Only vector-local coordinates scale.
        var vectorSource = self
        vectorSource.mask = nil
        // This maps local coordinates into a rendering grid, not a document
        // transform. It is required for both linked and unlinked vector masks.
        vectorSource.isMaskLinked = false
        rendering.mask = nil
        guard rendering.compensateUnlinkedLocalMasks(from: vectorSource) else { return nil }
        rendering.mask = mask
        rendering.style = style.scaled(by: scale)
        // The copy already meets the requested sampling size, so scale > 1 above
        // prevents recursion without using the user's link state as a sentinel.
        return (rendering, scale)
    }
}
