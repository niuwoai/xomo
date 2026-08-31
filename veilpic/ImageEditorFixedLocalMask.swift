import AppKit

extension ImageEditorLayer {
    /// Keep masks stationary in canvas space when local bounds change through
    /// scaling or raster rotation. Previews always supply the original snapshot.
    mutating func compensateUnlinkedLocalMasks(from source: ImageEditorLayer) -> Bool {
        guard !source.isGroup, !source.isMaskLinked else { return true }
        if frame == source.frame, image.size == source.image.size {
            mask = source.mask
            vectorMask = source.vectorMask
            return true
        }
        guard source.mask != nil || source.vectorMask != nil else { return true }
        guard let mapping = ImageEditorFixedMaskMapping(source: source, target: self) else { return false }
        if let mask = source.mask {
            guard let size = ImageEditorMaskSampling.fixedBitmapSize(mask: mask, originalFrame: source.frame, targetFrame: frame),
                  let bitmapMapping = ImageEditorFixedMaskMapping(source: source, target: self, outputSize: size)
            else { return false }
            if frame == source.frame, mask.size == size {
                self.mask = mask
            } else {
                guard let mapped = NSImage.rendered(size: size, actions: { _ in
                    mask.draw(in: bitmapMapping.bitmapRect, from: .zero, operation: .copy, fraction: 1)
                }) else { return false }
                self.mask = mapped
            }
        }
        vectorMask = source.vectorMask?.mappedToFixedCanvasPosition(mapping)
        return true
    }
}

private struct ImageEditorFixedMaskMapping {
    let sourceSize: CGSize
    let targetRect: CGRect
    let bitmapRect: CGRect

    init?(source: ImageEditorLayer, target: ImageEditorLayer, outputSize: CGSize? = nil) {
        sourceSize = source.image.size
        let outputSize = outputSize ?? target.image.size
        let original = source.frame.standardized
        let rotated = target.frame.standardized
        guard sourceSize.width > 0, sourceSize.height > 0,
              rotated.width > 0, rotated.height > 0 else { return nil }
        let scaleX = outputSize.width / rotated.width
        let scaleY = outputSize.height / rotated.height
        targetRect = CGRect(x: (original.minX - rotated.minX) * scaleX,
                            y: (original.minY - rotated.minY) * scaleY,
                            width: original.width * scaleX, height: original.height * scaleY)
        // Paths use top-left coordinates; AppKit bitmap drawing uses bottom-left.
        bitmapRect = CGRect(x: targetRect.minX, y: outputSize.height - targetRect.maxY,
                            width: targetRect.width, height: targetRect.height)
        guard [targetRect.minX, targetRect.minY, targetRect.maxX, targetRect.maxY,
               bitmapRect.minY, sourceSize.width, sourceSize.height].allSatisfy(\.isFinite) else { return nil }
    }

    func point(_ source: CGPoint) -> CGPoint {
        CGPoint(x: targetRect.minX + source.x / sourceSize.width * targetRect.width,
                y: targetRect.minY + source.y / sourceSize.height * targetRect.height)
    }
}

private extension ImageEditorShapeContent {
    func mappedToFixedCanvasPosition(_ mapping: ImageEditorFixedMaskMapping) -> Self {
        func anchor(_ source: ImageEditorPathAnchor) -> ImageEditorPathAnchor {
            ImageEditorPathAnchor(point: mapping.point(source.point),
                                  inControl: source.inControl.map(mapping.point),
                                  outControl: source.outControl.map(mapping.point))
        }
        var mapped = self
        mapped.pathPoints = pathPoints.map(mapping.point)
        mapped.pathAnchors = pathAnchors.map(anchor)
        mapped.pathSubpaths = pathSubpaths.map { $0.map(anchor) }
        return mapped
    }
}
