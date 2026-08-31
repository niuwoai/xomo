import AppKit

extension ImageEditorLayer {
    /// Group masks use canvas coordinates; the group's transparent backing image
    /// remains canvas-sized instead of being rotated like a leaf image.
    func rotatingGroup(degrees: CGFloat, around pivot: CGPoint) -> ImageEditorLayer? {
        guard isGroup, degrees.isFinite, pivot.x.isFinite, pivot.y.isFinite else { return nil }
        let angle = degrees.truncatingRemainder(dividingBy: 360)
        guard abs(angle) > 0.01 else { return self }
        let geometry = ImageEditorGroupRotationGeometry(degrees: angle, pivot: pivot)
        guard let bounds = geometry.bounds(of: frame.standardized) else { return nil }
        var rotated = self
        rotated.frame = bounds
        guard isMaskLinked else { return rotated }
        if let mask {
            guard let rotatedMask = mask.rotatedGroupMask(canvasSize: image.size, geometry: geometry) else { return nil }
            rotated.mask = rotatedMask
        }
        rotated.vectorMask = vectorMask?.rotatedGroupMask(geometry: geometry)
        return rotated
    }
}

private struct ImageEditorGroupRotationGeometry {
    let radians: CGFloat
    let pivot: CGPoint
    let cosine: CGFloat
    let sine: CGFloat

    init(degrees: CGFloat, pivot: CGPoint) {
        radians = degrees * .pi / 180
        self.pivot = pivot
        cosine = cos(radians)
        sine = sin(radians)
    }

    func point(_ source: CGPoint) -> CGPoint {
        let offset = CGPoint(x: source.x - pivot.x, y: source.y - pivot.y)
        return CGPoint(x: pivot.x + offset.x * cosine - offset.y * sine,
                       y: pivot.y + offset.x * sine + offset.y * cosine)
    }

    func bounds(of frame: CGRect) -> CGRect? {
        let corners = [CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY),
                       CGPoint(x: frame.maxX, y: frame.maxY), CGPoint(x: frame.minX, y: frame.maxY)].map(point)
        guard corners.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              let minX = corners.map(\.x).min(), let maxX = corners.map(\.x).max(),
              let minY = corners.map(\.y).min(), let maxY = corners.map(\.y).max(),
              (maxX - minX).isFinite, (maxY - minY).isFinite else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

private extension NSImage {
    func rotatedGroupMask(canvasSize: CGSize, geometry: ImageEditorGroupRotationGeometry) -> NSImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        return NSImage.rendered(size: size) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.scaleBy(x: size.width / canvasSize.width, y: size.height / canvasSize.height)
            // Bitmap drawing is bottom-left while document geometry is top-left.
            let pivotY = canvasSize.height - geometry.pivot.y
            context.translateBy(x: geometry.pivot.x, y: pivotY)
            context.rotate(by: -geometry.radians)
            context.translateBy(x: -geometry.pivot.x, y: -pivotY)
            self.draw(in: CGRect(origin: .zero, size: canvasSize), from: .zero, operation: .copy, fraction: 1)
        }
    }
}

private extension ImageEditorShapeContent {
    func rotatedGroupMask(geometry: ImageEditorGroupRotationGeometry) -> Self {
        func anchor(_ source: ImageEditorPathAnchor) -> ImageEditorPathAnchor {
            ImageEditorPathAnchor(point: geometry.point(source.point),
                                  inControl: source.inControl.map(geometry.point),
                                  outControl: source.outControl.map(geometry.point))
        }
        var rotated = self
        rotated.pathPoints = pathPoints.map(geometry.point)
        rotated.pathAnchors = pathAnchors.map(anchor)
        rotated.pathSubpaths = pathSubpaths.map { $0.map(anchor) }
        return rotated
    }
}
