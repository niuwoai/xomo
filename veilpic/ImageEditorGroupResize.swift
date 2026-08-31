import AppKit

@MainActor
extension ImageEditorViewModel {
    /// Prepare the complete edit before publishing any child frame or group mask.
    func resizedLayerChanges(
        _ frames: [UUID: CGRect],
        originalLayers: [ImageEditorLayer],
        originalTransformFrame: CGRect,
        targetFrame: CGRect
    ) -> [UUID: ImageEditorLayer]? {
        let sources = originalLayers.reduce(into: [UUID: ImageEditorLayer]()) { $0[$1.id] = $1 }
        var changes: [UUID: ImageEditorLayer] = [:]
        for layer in document.layers {
            guard let frame = frames[layer.id] else { continue }
            var resized = layer
            resized.frame = frame
            if layer.isGroup {
                guard let original = sources[layer.id],
                      resized.resizeLinkedGroupMasks(
                          from: original, originalBounds: originalTransformFrame, targetBounds: targetFrame
                      ) else { return nil }
            } else if !layer.isMaskLinked {
                guard let original = sources[layer.id],
                      resized.compensateUnlinkedLocalMasks(from: original) else { return nil }
            }
            changes[layer.id] = resized
        }
        return changes
    }
}

private extension ImageEditorLayer {
    mutating func resizeLinkedGroupMasks(
        from original: ImageEditorLayer,
        originalBounds: CGRect,
        targetBounds: CGRect
    ) -> Bool {
        guard original.isMaskLinked else { return true }
        if originalBounds == targetBounds {
            mask = original.mask
            vectorMask = original.vectorMask
            return true
        }
        let scaleX = targetBounds.width / originalBounds.width
        let scaleY = targetBounds.height / originalBounds.height
        let offset = CGPoint(
            x: targetBounds.minX - originalBounds.minX * scaleX,
            y: targetBounds.minY - originalBounds.minY * scaleY
        )
        guard scaleX.isFinite, scaleY.isFinite, offset.x.isFinite, offset.y.isFinite else { return false }
        if let source = original.mask {
            guard let resized = source.resizedGroupMask(
                canvasSize: original.image.size, scaleX: scaleX, scaleY: scaleY, offset: offset
            ) else { return false }
            mask = resized
        }
        vectorMask = original.vectorMask?.resizedGroupMask(scaleX: scaleX, scaleY: scaleY, offset: offset)
        return true
    }
}

private extension NSImage {
    func resizedGroupMask(canvasSize: CGSize, scaleX: CGFloat, scaleY: CGFloat, offset: CGPoint) -> NSImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let maskOffset = CGPoint(
            x: offset.x * size.width / canvasSize.width,
            y: offset.y * size.height / canvasSize.height
        )
        let destination = CGRect(
            x: maskOffset.x,
            y: size.height - maskOffset.y - size.height * scaleY,
            width: size.width * scaleX,
            height: size.height * scaleY
        )
        guard [destination.minX, destination.minY, destination.width, destination.height].allSatisfy(\.isFinite)
        else { return nil }
        return NSImage.rendered(size: size) { _ in
            self.draw(in: destination, from: .zero, operation: .copy, fraction: 1)
        }
    }
}

private extension ImageEditorShapeContent {
    func resizedGroupMask(scaleX: CGFloat, scaleY: CGFloat, offset: CGPoint) -> Self {
        func point(_ source: CGPoint) -> CGPoint {
            CGPoint(x: source.x * scaleX + offset.x, y: source.y * scaleY + offset.y)
        }
        func anchor(_ source: ImageEditorPathAnchor) -> ImageEditorPathAnchor {
            ImageEditorPathAnchor(
                point: point(source.point), inControl: source.inControl.map(point), outControl: source.outControl.map(point)
            )
        }
        var resized = self
        resized.pathPoints = pathPoints.map(point)
        resized.pathAnchors = pathAnchors.map(anchor)
        resized.pathSubpaths = pathSubpaths.map { $0.map(anchor) }
        return resized
    }
}
