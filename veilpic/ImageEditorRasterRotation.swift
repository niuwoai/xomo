import AppKit

extension ImageEditorLayer {
    /// Preserve canvas geometry separately from the retained source pixel density.
    /// A nonuniformly scaled image must be stretched before rotation, not after it.
    func rotatingRaster(degrees: CGFloat, around pivot: CGPoint) -> ImageEditorLayer? {
        let bounds = frame.standardized
        guard degrees.isFinite, pivot.x.isFinite, pivot.y.isFinite,
              bounds.width > 0, bounds.height > 0, image.size.width > 0, image.size.height > 0 else { return nil }
        let density = max(image.size.width / bounds.width, image.size.height / bounds.height)
        let sourceSize = CGSize(width: bounds.width * density, height: bounds.height * density)
        let angle = degrees.truncatingRemainder(dividingBy: 360)
        let radians = angle * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        let outputPixelSize = CGSize(
            width: sourceSize.width * abs(cosine) + sourceSize.height * abs(sine),
            height: sourceSize.width * abs(sine) + sourceSize.height * abs(cosine)
        )
        guard density.isFinite, sourceSize.isRepresentableRotationBitmap, outputPixelSize.isRepresentableRotationBitmap,
              let pixels = image.rotationSource(size: sourceSize),
              let rotatedImage = pixels.rotated(degrees: -angle) else { return nil }
        let offset = CGPoint(x: bounds.midX - pivot.x, y: bounds.midY - pivot.y)
        let center = CGPoint(
            x: pivot.x + offset.x * cosine - offset.y * sine,
            y: pivot.y + offset.x * sine + offset.y * cosine
        )
        let size = CGSize(width: rotatedImage.size.width / density, height: rotatedImage.size.height / density)
        var rotated = self
        rotated.image = rotatedImage
        rotated.frame = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
        if isMaskLinked {
            if let mask {
                guard let source = mask.rotationSource(size: sourceSize),
                      let rotatedMask = source.rotated(degrees: -angle) else { return nil }
                rotated.mask = rotatedMask
            }
            rotated.vectorMask = vectorMask?.rotatedRasterMask(
                from: image.size, stretchedSize: sourceSize, outputSize: rotatedImage.size, cosine: cosine, sine: sine
            )
        } else if !rotated.compensateUnlinkedLocalMasks(from: self) {
            return nil
        }
        if let cutoutMask = postFilterCutoutMask {
            guard let source = cutoutMask.rotationSource(size: sourceSize),
                  let rotatedMask = source.rotated(degrees: -angle) else { return nil }
            rotated.postFilterCutoutMask = rotatedMask
        }
        return rotated
    }
}

private extension CGSize {
    var isRepresentableRotationBitmap: Bool {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return false }
        let rgbaBytesPerPixel = 4
        let maximumPixelCount = CGFloat(Int.max / rgbaBytesPerPixel)
        let pixelWidth = max(1, width.rounded())
        let pixelHeight = max(1, height.rounded())
        return pixelWidth < maximumPixelCount && pixelHeight < maximumPixelCount
            && pixelWidth * pixelHeight < maximumPixelCount
    }
}

private extension NSImage {
    func rotationSource(size targetSize: CGSize) -> NSImage? {
        size == targetSize ? self : resized(to: targetSize)
    }
}

private extension ImageEditorShapeContent {
    func rotatedRasterMask(
        from sourceSize: CGSize,
        stretchedSize: CGSize,
        outputSize: CGSize,
        cosine: CGFloat,
        sine: CGFloat
    ) -> Self {
        func point(_ source: CGPoint) -> CGPoint {
            let x = source.x * stretchedSize.width / sourceSize.width - stretchedSize.width / 2
            let y = source.y * stretchedSize.height / sourceSize.height - stretchedSize.height / 2
            return CGPoint(x: outputSize.width / 2 + x * cosine - y * sine, y: outputSize.height / 2 + x * sine + y * cosine)
        }
        func anchor(_ source: ImageEditorPathAnchor) -> ImageEditorPathAnchor {
            ImageEditorPathAnchor(
                point: point(source.point), inControl: source.inControl.map(point), outControl: source.outControl.map(point)
            )
        }
        var rotated = self
        rotated.pathPoints = pathPoints.map(point)
        rotated.pathAnchors = pathAnchors.map(anchor)
        rotated.pathSubpaths = pathSubpaths.map { $0.map(anchor) }
        return rotated
    }
}
