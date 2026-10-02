import AppKit
import CoreImage
import Foundation
import simd

struct ImageEditorLayer: Identifiable {
    var id = UUID()
    var name: String
    var image: NSImage
    var mask: NSImage? {
        didSet { if mask == nil { maskFeatherSamplingScale = nil } }
    }
    var isMaskEnabled = true
    var isMaskLinked = true
    var maskDensity: Double = 1
    var maskFeather: Double = 0
    /// Additional bitmap samples per original feather unit; nil is legacy 1x.
    var maskFeatherSamplingScale: Double?
    var vectorMask: ImageEditorShapeContent?
    var isVectorMaskEnabled = true
    var isVectorMaskInverted = false
    var linkedLayerIDs: Set<UUID> = []
    var frame: CGRect
    var isVisible: Bool
    var opacity: Double
    var fillOpacity: Double = 1
    var blendIfSourceBlack: Double = 0
    var blendIfSourceWhite: Double = 1
    var blendIfUnderlyingBlack: Double = 0
    var blendIfUnderlyingWhite: Double = 1
    var blendMode: ImageEditorBlendMode
    var isLocked: Bool
    var locksPixels = false
    var locksPosition = false
    var locksTransparentPixels = false
    var style = ImageEditorLayerStyle()
    var kind: ImageEditorLayerKind = .pixel
    var smartFilters: [ImageEditorSmartFilter] = []
    var adjustmentSettings = ImageEditorAdjustmentSettings()
    var filterSettings = ImageEditorFilterSettings()
    var groupID: UUID?
    var isGroupExpanded = true
    var stackLayout: ImageEditorStackLayout?
    var stackChildLayout: ImageEditorStackChildLayout?
    var isStackLayoutExcluded = false
    var isStackLayoutBackground = false
    var isClippingMask = false
    var labelColor: ImageEditorLayerLabelColor?
    var xomoComponentInstance: XomoComponentInstance?
    var isXomoThemeOverride = false
    var xomoFigmaVariableBindings: [XomoFigmaVariableBinding] = []
    /// Effective Figma min/max dimensions, including local inspector overrides.
    var xomoFigmaSizeConstraints: XomoFigmaSizeConstraints?
    /// Imported values retained separately so local overrides can be reset.
    /// A non-nil empty value means the source node originally had no constraints.
    var xomoFigmaSizeConstraintDefaults: XomoFigmaSizeConstraints?
    /// Original Figma node identity retained for inspectable, traceable imports.
    var xomoFigmaSourceID: String?
    var xomoFigmaNodeType: String?
    var xomoFigmaComponentRole: XomoFigmaComponentRole?
    var xomoFigmaComponentProperties: [String: XomoFigmaComponentProperty] = [:]
    /// Figma's imported component values before any local override is applied.
    /// Keeping this snapshot lets the property inspector restore one override
    /// without re-importing the source document.
    var xomoFigmaComponentPropertyDefaults: [String: XomoFigmaComponentProperty] = [:]
    /// Original Figma image-fill parameters retained for non-destructive rendering.
    var xomoFigmaImageFill: XomoFigmaImageFillMetadata?
    /// Original Figma image asset used to re-render crop/tile/rotation parameters.
    var xomoFigmaImageFillSourceImage: NSImage?
    /// Allows the imported Figma image-fill filters to be toggled without changing pixels.
    var xomoFigmaImageFillFiltersEnabled = true
    var xomoFigmaSourceURL: URL?

    static func background(image: NSImage) -> ImageEditorLayer {
        ImageEditorLayer(
            name: L10n.text("imageEditor.layer.background"),
            image: image,
            mask: nil,
            frame: CGRect(origin: .zero, size: image.size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: true
        )
    }

    static func blank(name: String, size: CGSize) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false
        )
    }

    static func group(name: String, size: CGSize) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .passThrough,
            isLocked: false,
            kind: .group
        )
    }

    static func adjustment(
        name: String,
        size: CGSize,
        kind: ImageEditorAdjustment,
        amount: Double,
        settings: ImageEditorAdjustmentSettings = ImageEditorAdjustmentSettings()
    ) -> ImageEditorLayer {
        var layer = ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .adjustment(kind, amount)
        )
        layer.adjustmentSettings = settings.normalized()
        return layer
    }

    static func filter(
        name: String,
        size: CGSize,
        kind: ImageEditorFilter,
        intensity: Double,
        settings: ImageEditorFilterSettings = ImageEditorFilterSettings()
    ) -> ImageEditorLayer {
        var layer = ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .filter(kind, intensity)
        )
        layer.filterSettings = settings.normalized()
        return layer
    }

    static func solidColorFill(name: String, size: CGSize, content: ImageEditorSolidColorFillContent) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .solidColorFill(content.normalized())
        )
    }

    static func patternFill(name: String, size: CGSize, content: ImageEditorPatternFillContent) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .patternFill(content.normalized())
        )
    }

    static func gradientFill(name: String, size: CGSize, content: ImageEditorGradientFillContent) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .gradientFill(content.normalized())
        )
    }

    static func text(name: String, size: CGSize, content: ImageEditorTextContent) -> ImageEditorLayer {
        ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: .zero, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .text(content)
        )
    }

    static func text(name: String, origin: CGPoint, content: ImageEditorTextContent) -> ImageEditorLayer {
        let layerSize = content.layerSize()
        return ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: layerSize),
            mask: nil,
            frame: CGRect(origin: origin, size: layerSize),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .text(content)
        )
    }

    static func shape(name: String, frame: CGRect, content: ImageEditorShapeContent) -> ImageEditorLayer {
        let size = CGSize(width: max(1, frame.width), height: max(1, frame.height))
        return ImageEditorLayer(
            name: name,
            image: NSImage.transparent(size: size),
            mask: nil,
            frame: CGRect(origin: frame.origin, size: size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .shape(content.normalized(size: size))
        )
    }

    static func smartObject(name: String, image: NSImage, sourceName: String) -> ImageEditorLayer {
        let normalized = image.normalizedBitmapImage()
        return ImageEditorLayer(
            name: name,
            image: normalized,
            mask: nil,
            frame: CGRect(origin: .zero, size: normalized.size),
            isVisible: true,
            opacity: 1,
            blendMode: .normal,
            isLocked: false,
            kind: .smartObject(
                ImageEditorSmartObjectContent(
                    sourceName: sourceName,
                    originalSize: normalized.size
                )
            )
        )
    }

    var isGroup: Bool {
        if case .group = kind { return true }
        return false
    }

    var adjustment: (kind: ImageEditorAdjustment, amount: Double)? {
        guard case let .adjustment(adjustmentKind, amount) = kind else { return nil }
        return (adjustmentKind, amount)
    }

    var isAdjustment: Bool {
        adjustment != nil
    }

    var filter: (kind: ImageEditorFilter, intensity: Double)? {
        guard case let .filter(filterKind, intensity) = kind else { return nil }
        return (filterKind, intensity)
    }

    var isFilter: Bool {
        filter != nil
    }

    var solidColorFillContent: ImageEditorSolidColorFillContent? {
        guard case let .solidColorFill(content) = kind else { return nil }
        return content
    }

    var isSolidColorFill: Bool {
        solidColorFillContent != nil
    }

    var patternFillContent: ImageEditorPatternFillContent? {
        guard case let .patternFill(content) = kind else { return nil }
        return content
    }

    var isPatternFill: Bool {
        patternFillContent != nil
    }

    var gradientFillContent: ImageEditorGradientFillContent? {
        guard case let .gradientFill(content) = kind else { return nil }
        return content
    }

    var isGradientFill: Bool {
        gradientFillContent != nil
    }

    var textContent: ImageEditorTextContent? {
        guard case let .text(content) = kind else { return nil }
        return content
    }

    var isText: Bool {
        textContent != nil
    }

    var shapeContent: ImageEditorShapeContent? {
        guard case let .shape(content) = kind else { return nil }
        return content
    }

    var isShape: Bool {
        shapeContent != nil
    }

    var smartObjectContent: ImageEditorSmartObjectContent? {
        guard case let .smartObject(content) = kind else { return nil }
        return content
    }

    var isSmartObject: Bool {
        smartObjectContent != nil
    }

    func thumbnail(size: CGSize = CGSize(width: 44, height: 34)) -> NSImage {
        guard !isGroup else {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.18, alpha: 1).setFill()
                rect.fill()
                let folderRect = CGRect(
                    x: size.width * 0.18,
                    y: size.height * 0.23,
                    width: size.width * 0.64,
                    height: size.height * 0.5
                )
                let tabRect = CGRect(
                    x: folderRect.minX,
                    y: folderRect.maxY - 2,
                    width: folderRect.width * 0.42,
                    height: size.height * 0.18
                )
                NSColor(calibratedRed: 0.58, green: 0.67, blue: 0.78, alpha: 1).setFill()
                NSBezierPath(roundedRect: tabRect, xRadius: 3, yRadius: 3).fill()
                NSBezierPath(roundedRect: folderRect, xRadius: 4, yRadius: 4).fill()
            } ?? NSImage(size: size)
        }
        if let adjustment {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
                rect.fill()
                let inset = min(size.width, size.height) * 0.18
                let circleRect = rect.insetBy(dx: inset, dy: inset)
                NSColor(calibratedRed: 0.50, green: 0.67, blue: 0.96, alpha: 1).setFill()
                NSBezierPath(ovalIn: circleRect).fill()
                NSColor.white.withAlphaComponent(0.86).setStroke()
                let curve = NSBezierPath()
                curve.lineWidth = 2
                curve.move(to: CGPoint(x: circleRect.minX + circleRect.width * 0.18, y: circleRect.midY))
                curve.curve(
                    to: CGPoint(x: circleRect.maxX - circleRect.width * 0.18, y: circleRect.midY),
                    controlPoint1: CGPoint(x: circleRect.midX - 1, y: circleRect.maxY - circleRect.height * 0.38),
                    controlPoint2: CGPoint(x: circleRect.midX + 1, y: circleRect.minY + circleRect.height * 0.38)
                )
                curve.stroke()
                _ = adjustment
            } ?? NSImage(size: size)
        }
        if let filter {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
                rect.fill()
                let inset = min(size.width, size.height) * 0.2
                let boxRect = rect.insetBy(dx: inset, dy: inset)
                NSColor(calibratedRed: 0.62, green: 0.76, blue: 0.50, alpha: 1).setFill()
                NSBezierPath(roundedRect: boxRect, xRadius: 5, yRadius: 5).fill()
                NSColor.white.withAlphaComponent(0.88).setStroke()
                let line = NSBezierPath()
                line.lineWidth = 2
                line.move(to: CGPoint(x: boxRect.minX + 4, y: boxRect.midY))
                line.line(to: CGPoint(x: boxRect.maxX - 4, y: boxRect.midY))
                line.move(to: CGPoint(x: boxRect.midX, y: boxRect.minY + 4))
                line.line(to: CGPoint(x: boxRect.midX, y: boxRect.maxY - 4))
                line.stroke()
                _ = filter
            } ?? NSImage(size: size)
        }
        if let solidColorFillContent {
            return solidColorFillContent.renderedImage(size: size)
        }
        if let patternFillContent {
            return patternFillContent.renderedImage(size: size)
        }
        if let gradientFillContent {
            return gradientFillContent.renderedImage(size: size)
        }
        if textContent != nil {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
                rect.fill()
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: size.height * 0.62, weight: .bold),
                    .foregroundColor: NSColor.white.withAlphaComponent(0.9)
                ]
                let glyph = "T" as NSString
                let glyphSize = glyph.size(withAttributes: attributes)
                glyph.draw(
                    at: CGPoint(x: rect.midX - glyphSize.width / 2, y: rect.midY - glyphSize.height / 2),
                    withAttributes: attributes
                )
            } ?? NSImage(size: size)
        }
        if let shapeContent {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
                rect.fill()
                let inset = min(size.width, size.height) * 0.18
                let shapeRect = rect.insetBy(dx: inset, dy: inset)
                let path = shapeContent.kind == .ellipse
                    ? NSBezierPath(ovalIn: shapeRect)
                    : NSBezierPath(rect: shapeRect)
                shapeContent.fillColor.withAlphaComponent(0.86).setFill()
                path.fill()
                NSColor.white.withAlphaComponent(0.9).setStroke()
                path.lineWidth = 2
                path.stroke()
            } ?? NSImage(size: size)
        }
        if smartObjectContent != nil {
            return NSImage.rendered(size: size) { rect in
                NSColor(calibratedWhite: 0.14, alpha: 1).setFill()
                rect.fill()
                let inset = min(size.width, size.height) * 0.18
                let boxRect = rect.insetBy(dx: inset, dy: inset)
                NSColor(calibratedRed: 0.42, green: 0.66, blue: 0.95, alpha: 1).setFill()
                NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4).fill()
                NSColor.white.withAlphaComponent(0.9).setStroke()
                let innerRect = boxRect.insetBy(dx: boxRect.width * 0.2, dy: boxRect.height * 0.2)
                let path = NSBezierPath(rect: innerRect)
                path.lineWidth = 2
                path.stroke()
            } ?? NSImage(size: size)
        }
        return image.thumbnailImage(targetSize: size)
    }

    func maskThumbnail(size: CGSize = CGSize(width: 24, height: 24)) -> NSImage? {
        mask?.processedLayerMask(density: maskDensity, feather: maskFeather, samplingScale: maskFeatherSamplingScale)?.thumbnailImage(targetSize: size)
    }

    func vectorMaskThumbnail(size: CGSize = CGSize(width: 24, height: 24)) -> NSImage? {
        vectorMaskImage()?.thumbnailImage(targetSize: size)
    }

    var effectiveRasterMask: NSImage? {
        isMaskEnabled ? mask?.processedLayerMask(density: maskDensity, feather: maskFeather, samplingScale: maskFeatherSamplingScale) : nil
    }

    var effectiveMask: NSImage? {
        let rasterMask = effectiveRasterMask
        let vectorMask = isVectorMaskEnabled ? vectorMaskImage() : nil
        switch (rasterMask, vectorMask) {
        case let (.some(rasterMask), .some(vectorMask)):
            return rasterMask.compositedWithAlphaMask(vectorMask)
        case let (.some(rasterMask), .none):
            return rasterMask
        case let (.none, .some(vectorMask)):
            return vectorMask
        case (.none, .none):
            return nil
        }
    }

    private func vectorMaskImage() -> NSImage? {
        vectorMask?.renderedVectorMask(
            size: image.size,
            inverted: isVectorMaskInverted
        )
    }

    var contentImage: NSImage {
        let baseImage: NSImage
        if let textContent {
            baseImage = NSImage.rendered(size: image.size) { _ in
                let drawingRect = textContent.drawingRect(in: image.size)
                let appKitDrawingRect = CGRect(
                    x: drawingRect.minX,
                    y: image.size.height - drawingRect.maxY,
                    width: drawingRect.width,
                    height: drawingRect.height
                )
                textContent.attributedString.draw(
                    with: appKitDrawingRect,
                    options: textContent.drawingOptions
                )
            } ?? image
        } else if let solidColorFillContent {
            baseImage = solidColorFillContent.renderedImage(size: image.size)
        } else if let patternFillContent {
            baseImage = patternFillContent.renderedImage(size: image.size)
        } else if let gradientFillContent {
            baseImage = gradientFillContent.renderedImage(size: image.size)
        } else if let shapeContent {
            baseImage = shapeContent.renderedImage(size: image.size)
        } else {
            baseImage = image
        }
        let imageFillRendered: NSImage
        if let imageFill = xomoFigmaImageFill,
           let sourceImage = xomoFigmaImageFillSourceImage {
            imageFillRendered = XomoFigmaNodeMaterializer.renderImageFill(
                sourceImage,
                metadata: imageFill,
                size: baseImage.size
            )
        } else {
            imageFillRendered = baseImage
        }
        let imageFillFiltered: NSImage
        if xomoFigmaImageFillFiltersEnabled,
           let imageFill = xomoFigmaImageFill {
            imageFillFiltered = XomoFigmaImageFilterBaker.apply(imageFill.filters, to: imageFillRendered)
        } else {
            imageFillFiltered = imageFillRendered
        }
        return smartFilters.reduce(imageFillFiltered) { partial, filter in
            guard filter.isEnabled, !filter.appliesToBackdrop else { return partial }
            return partial.applyingFilter(
                kind: filter.kind,
                intensity: filter.normalizedIntensity,
                settings: filter.renderingSettings,
                mask: nil,
                opacity: filter.normalizedOpacity,
                blendMode: filter.normalizedBlendMode
            ) ?? partial
        }
    }

    var hasSmartFilters: Bool {
        !smartFilters.isEmpty
    }

    var visibleImage: NSImage {
        if let rendering = highResolutionMaskRenderingLayer() {
            let result = rendering.layer.visibleImage
            result.size = image.size
            return result
        }
        let sourceImage = contentImage
        guard let mask = effectiveMask else { return sourceImage }
        return NSImage.rendered(size: sourceImage.size) { _ in
            sourceImage.draw(
                in: CGRect(origin: .zero, size: sourceImage.size),
                from: CGRect(origin: .zero, size: sourceImage.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: sourceImage.size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        } ?? sourceImage
    }

    var hasLayerEffects: Bool {
        style.hasConfiguredEffects
    }

    var compositingImage: NSImage {
        renderedCompositingImage(globalLightAngle: nil)
    }

    func renderedCompositingImage(globalLightAngle: CGFloat?) -> NSImage {
        if let rendering = highResolutionMaskRenderingLayer() {
            let result = rendering.layer.renderedCompositingImage(
                globalLightAngle: globalLightAngle,
                style: rendering.layer.style.resolvedForRendering(),
                paddingOverride: style.padding(globalLightAngle: globalLightAngle) * rendering.scale
            )
            let padding = style.padding(globalLightAngle: globalLightAngle)
            result.size = CGSize(width: image.size.width + padding * 2, height: image.size.height + padding * 2)
            return result
        }
        return renderedCompositingImage(
            globalLightAngle: globalLightAngle,
            style: style.resolvedForRendering()
        )
    }

    private func renderedCompositingImage(
        globalLightAngle: CGFloat?,
        style: ImageEditorLayerStyle,
        paddingOverride: CGFloat? = nil
    ) -> NSImage {
        let baseImage = visibleImage.applyingBlendIfSourceRange(
            black: blendIfSourceBlack,
            white: blendIfSourceWhite
        ) ?? visibleImage
        let normalizedFillOpacity = CGFloat(max(0, min(1, fillOpacity)))
        guard style.hasEffects else {
            guard normalizedFillOpacity < 1 else { return baseImage }
            return baseImage.withOpacity(normalizedFillOpacity) ?? baseImage
        }
        let padding = paddingOverride ?? style.padding(globalLightAngle: globalLightAngle)
        let outputSize = CGSize(
            width: baseImage.size.width + padding * 2,
            height: baseImage.size.height + padding * 2
        )
        let contentRect = CGRect(origin: CGPoint(x: padding, y: padding), size: baseImage.size)

        return NSImage.rendered(size: outputSize) { _ in
            if style.shadowEnabled {
                let spread = max(0, Int(style.shadowSpread.rounded()))
                let shadowOffset = style.resolvedShadowOffset(globalLightAngle: globalLightAngle)
                let shadowCanvas = NSImage.rendered(size: outputSize) { _ in
                    let rawShadowImage = baseImage.alphaTinted(
                        color: style.shadowColor.withAlphaComponent(style.shadowOpacity)
                    )
                    let shadowImage = rawShadowImage.shadowNoised(amount: style.shadowNoise) ?? rawShadowImage
                    shadowImage.draw(
                        in: contentRect.offsetBy(dx: shadowOffset.width, dy: shadowOffset.height),
                        from: CGRect(origin: .zero, size: shadowImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    if spread > 0 {
                        let directions = 24
                        for radius in 1...spread {
                            for step in 0..<directions {
                                let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                                let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                                shadowImage.draw(
                                    in: contentRect.offsetBy(
                                        dx: shadowOffset.width + offset.width,
                                        dy: shadowOffset.height + offset.height
                                    ),
                                    from: CGRect(origin: .zero, size: shadowImage.size),
                                    operation: .sourceOver,
                                    fraction: 1
                                )
                            }
                        }
                    }
                } ?? NSImage(size: outputSize)
                let blurredShadow = shadowCanvas.blurred(radius: style.shadowBlur) ?? shadowCanvas
                let contouredShadow = blurredShadow.applyingEffectContour(style.shadowContour) ?? blurredShadow
                contouredShadow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: contouredShadow.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.strokeEnabled {
                let width = max(1, Int(style.strokeWidth.rounded()))
                let outsideWidth = style.strokePosition.outsideWidth(totalWidth: width)
                let strokeFillImage = style.strokeFillImage(size: outputSize)
                if outsideWidth > 0,
                   let outsideStroke = baseImage.outsideStrokeCanvas(
                       fillImage: strokeFillImage,
                       width: outsideWidth,
                       contentRect: contentRect,
                       outputSize: outputSize
                   ) {
                    outsideStroke.draw(
                        in: CGRect(origin: .zero, size: outputSize),
                        from: CGRect(origin: .zero, size: outputSize),
                        operation: .sourceOver,
                        fraction: 1
                    )
                }
            }

            if style.outerGlowEnabled {
                let rawGlowImage = baseImage.alphaTinted(
                    color: style.outerGlowColor.withAlphaComponent(style.outerGlowOpacity)
                )
                let glowImage = rawGlowImage.shadowNoised(amount: style.outerGlowNoise) ?? rawGlowImage
                let spread = max(0, Int(style.outerGlowSpread.rounded()))
                let glowCanvas = NSImage.rendered(size: outputSize) { _ in
                    glowImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: glowImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    if spread > 0 {
                        let directions = 24
                        for radius in 1...spread {
                            for step in 0..<directions {
                                let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                                let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                                glowImage.draw(
                                    in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                                    from: CGRect(origin: .zero, size: glowImage.size),
                                    operation: .sourceOver,
                                    fraction: 1
                                )
                            }
                        }
                    }
                } ?? NSImage(size: outputSize)
                let diffusedGlow: NSImage
                switch style.outerGlowTechnique {
                case .softer:
                    diffusedGlow = glowCanvas.blurred(radius: style.outerGlowBlur) ?? glowCanvas
                case .precise:
                    diffusedGlow = glowCanvas.preciseOuterGlow(radius: style.outerGlowBlur) ?? glowCanvas
                }
                let contouredGlow = diffusedGlow.applyingEffectContour(
                    style.outerGlowContour,
                    range: style.outerGlowRange
                ) ?? diffusedGlow
                let jitteredGlow = contouredGlow.shadowNoised(
                    amount: style.outerGlowJitter
                ) ?? contouredGlow
                jitteredGlow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: jitteredGlow.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            // Fill opacity fades only layer pixels; effects keep using the original alpha mask.
            baseImage.draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: baseImage.size),
                operation: .sourceOver,
                fraction: normalizedFillOpacity
            )

            if style.strokeEnabled {
                let width = max(1, Int(style.strokeWidth.rounded()))
                let insideWidth = style.strokePosition.insideWidth(totalWidth: width)
                let strokeFillImage = style.strokeFillImage(size: outputSize)
                if insideWidth > 0,
                   let insideStroke = baseImage.insideStrokeCanvas(
                       fillImage: strokeFillImage,
                       width: insideWidth,
                       contentRect: contentRect,
                       outputSize: outputSize
                   ) {
                    insideStroke.draw(
                        in: CGRect(origin: .zero, size: outputSize),
                        from: CGRect(origin: .zero, size: outputSize),
                        operation: .sourceOver,
                        fraction: 1
                    )
                }
            }

            if style.innerShadowEnabled {
                let radians = style.resolvedInnerShadowAngle(globalLightAngle: globalLightAngle) * .pi / 180
                let distance = max(0, style.innerShadowDistance)
                let offset = CGSize(width: cos(radians) * distance, height: sin(radians) * distance)
                let rawInnerShadowImage = baseImage.alphaTinted(
                    color: style.innerShadowColor.withAlphaComponent(style.innerShadowOpacity)
                )
                let innerShadowImage = rawInnerShadowImage.shadowNoised(amount: style.innerShadowNoise) ?? rawInnerShadowImage
                let choke = max(0, Int(style.innerShadowChoke.rounded()))
                let innerShadowCanvas = NSImage.rendered(size: outputSize) { _ in
                    innerShadowImage.draw(
                        in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                        from: CGRect(origin: .zero, size: innerShadowImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    if choke > 0 {
                        let directions = 24
                        for radius in 1...choke {
                            for step in 0..<directions {
                                let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                                let expansion = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                                innerShadowImage.draw(
                                    in: contentRect.offsetBy(
                                        dx: offset.width + expansion.width,
                                        dy: offset.height + expansion.height
                                    ),
                                    from: CGRect(origin: .zero, size: innerShadowImage.size),
                                    operation: .sourceOver,
                                    fraction: 1
                                )
                            }
                        }
                    }
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                let softenedInnerShadow = innerShadowCanvas.blurred(radius: style.innerShadowBlur) ?? innerShadowCanvas
                let contouredInnerShadow = softenedInnerShadow.applyingEffectContour(style.innerShadowContour) ?? softenedInnerShadow
                contouredInnerShadow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: contouredInnerShadow.size),
                    operation: .multiply,
                    fraction: 1
                )
            }

            if style.colorOverlayEnabled {
                let overlayImage = baseImage.alphaTinted(
                    color: style.colorOverlayColor.withAlphaComponent(style.colorOverlayOpacity)
                )
                overlayImage.draw(
                    in: contentRect,
                    from: CGRect(origin: .zero, size: overlayImage.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.gradientOverlayEnabled {
                let gradientImage = ImageEditorGradientFillContent(
                    preset: .custom,
                    style: style.gradientOverlayStyle,
                    reverse: style.gradientOverlayReverse,
                    dither: style.gradientOverlayDither,
                    angle: style.gradientOverlayAngle,
                    scale: style.gradientOverlayScale,
                    startRed: Double(style.gradientOverlayStartColor.usingColorSpace(.deviceRGB)?.redComponent ?? 1),
                    startGreen: Double(style.gradientOverlayStartColor.usingColorSpace(.deviceRGB)?.greenComponent ?? 0),
                    startBlue: Double(style.gradientOverlayStartColor.usingColorSpace(.deviceRGB)?.blueComponent ?? 0),
                    endRed: Double(style.gradientOverlayEndColor.usingColorSpace(.deviceRGB)?.redComponent ?? 1),
                    endGreen: Double(style.gradientOverlayEndColor.usingColorSpace(.deviceRGB)?.greenComponent ?? 1),
                    endBlue: Double(style.gradientOverlayEndColor.usingColorSpace(.deviceRGB)?.blueComponent ?? 1),
                    colorStops: style.gradientOverlayColorStops
                ).renderedImage(
                    size: contentRect.size,
                    centerNormalized: ImageEditorGradientOverlayCenterPolicy.normalized(
                        style.gradientOverlayCenter
                    ),
                    opacity: Double(style.gradientOverlayOpacity)
                )
                let gradientCanvas = NSImage.rendered(size: outputSize) { _ in
                    let context = NSGraphicsContext.current
                    let previousInterpolation = context?.imageInterpolation
                    let previousInterpolationQuality = context?.cgContext.interpolationQuality
                    context?.imageInterpolation = .none
                    defer {
                        context?.imageInterpolation = previousInterpolation ?? .default
                        context?.cgContext.interpolationQuality = previousInterpolationQuality ?? .default
                    }
                    if let gradientCGImage = gradientImage.cgImage(
                        forProposedRect: nil,
                        context: context,
                        hints: nil
                    ) {
                        context?.cgContext.interpolationQuality = .none
                        context?.cgContext.draw(gradientCGImage, in: contentRect)
                    } else {
                        gradientImage.draw(
                            in: contentRect,
                            from: CGRect(origin: .zero, size: gradientImage.size),
                            operation: .sourceOver,
                            fraction: 1
                        )
                    }
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                let outputRect = CGRect(origin: .zero, size: outputSize)
                if style.gradientOverlayBlendMode == .normal,
                   let context = NSGraphicsContext.current,
                   let gradientCanvasCGImage = gradientCanvas.cgImage(
                    forProposedRect: nil,
                    context: context,
                    hints: nil
                ) {
                    let previousInterpolationQuality = context.cgContext.interpolationQuality
                    context.cgContext.interpolationQuality = .none
                    defer { context.cgContext.interpolationQuality = previousInterpolationQuality }
                    context.cgContext.draw(gradientCanvasCGImage, in: outputRect)
                } else if let backdropCGImage = NSGraphicsContext.current?.cgContext.makeImage(),
                   let compositedImage = NSImage(
                       cgImage: backdropCGImage,
                       size: outputSize
                   ).blended(
                       with: gradientCanvas,
                       mode: style.gradientOverlayBlendMode,
                       opacity: 1
                   ) {
                    compositedImage.draw(
                        in: outputRect,
                        from: outputRect,
                        operation: .copy,
                        fraction: 1
                    )
                } else {
                    gradientCanvas.draw(
                        in: outputRect,
                        from: outputRect,
                        operation: .sourceOver,
                        fraction: 1
                    )
                }
            }

            if style.patternOverlayEnabled {
                let patternImage = style.patternOverlayKind.tileImage(
                    color: style.patternOverlayColor,
                    opacity: style.patternOverlayOpacity,
                    scale: style.patternOverlayScale
                )
                let patternCanvas = NSImage.rendered(size: outputSize) { _ in
                    let context = NSGraphicsContext.current
                    let originalPatternPhase = context?.patternPhase ?? .zero
                    context?.patternPhase = CGPoint(
                        x: style.patternOverlayOffset.width,
                        y: style.patternOverlayOffset.height
                    )
                    defer {
                        context?.patternPhase = originalPatternPhase
                    }
                    NSColor(patternImage: patternImage).setFill()
                    contentRect.fill()
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                patternCanvas.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.satinEnabled {
                let radians = style.satinAngle * .pi / 180
                let distance = max(1, style.satinDistance)
                let offset = CGSize(width: cos(radians) * distance, height: sin(radians) * distance)
                let satinImage = baseImage.alphaTinted(
                    color: style.satinColor.withAlphaComponent(style.satinOpacity)
                )
                let satinCanvas = NSImage.rendered(size: outputSize) { _ in
                    satinImage.draw(
                        in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                        from: CGRect(origin: .zero, size: satinImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    satinImage.draw(
                        in: contentRect.offsetBy(dx: -offset.width, dy: -offset.height),
                        from: CGRect(origin: .zero, size: satinImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                let softenedSatin = satinCanvas.blurred(radius: style.satinSize) ?? satinCanvas
                let contouredSatin = softenedSatin.applyingEffectContour(style.satinContour) ?? softenedSatin
                let baseSatinMask = NSImage.rendered(size: outputSize) { _ in
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                }
                let satinOutput: NSImage
                if style.satinInvert,
                   let baseMask = baseSatinMask,
                   let inverted = contouredSatin.invertedAlphaTinted(
                       within: baseMask,
                       color: style.satinColor.withAlphaComponent(style.satinOpacity)
                   ) {
                    satinOutput = inverted
                } else {
                    satinOutput = contouredSatin
                }
                satinOutput.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .multiply,
                    fraction: 1
                )
            }

            if style.bevelEnabled {
                let bevelDistance = max(1, Int(style.bevelSize.rounded()))
                let bevelOffset = ImageEditorLayerStyle.shadowOffset(
                    distance: CGFloat(bevelDistance),
                    angle: style.resolvedBevelAngle(globalLightAngle: globalLightAngle)
                )
                let highlightImage = baseImage.alphaTinted(
                    color: style.bevelHighlightColor.withAlphaComponent(style.bevelOpacity)
                )
                let shadowImage = baseImage.alphaTinted(
                    color: style.bevelShadowColor.withAlphaComponent(style.bevelOpacity)
                )
                let highlightOffset = style.bevelDirection == .up
                    ? CGSize(width: -bevelOffset.width, height: -bevelOffset.height)
                    : bevelOffset
                let shadowOffset = style.bevelDirection == .up
                    ? bevelOffset
                    : CGSize(width: -bevelOffset.width, height: -bevelOffset.height)
                let bevelCanvas = NSImage.rendered(size: outputSize) { _ in
                    highlightImage.draw(
                        in: contentRect.offsetBy(dx: highlightOffset.width, dy: highlightOffset.height),
                        from: CGRect(origin: .zero, size: highlightImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    shadowImage.draw(
                        in: contentRect.offsetBy(dx: shadowOffset.width, dy: shadowOffset.height),
                        from: CGRect(origin: .zero, size: shadowImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                    baseImage.draw(
                        in: contentRect,
                        from: CGRect(origin: .zero, size: baseImage.size),
                        operation: .destinationIn,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                let softenedBevel = style.bevelSoften > 0
                    ? bevelCanvas.blurred(radius: style.bevelSoften) ?? bevelCanvas
                    : bevelCanvas
                softenedBevel.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: softenedBevel.size),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.innerGlowEnabled {
                let rawInnerGlowImage = baseImage.alphaTinted(
                    color: style.innerGlowColor.withAlphaComponent(style.innerGlowOpacity)
                )
                let innerGlowImage = rawInnerGlowImage.shadowNoised(amount: style.innerGlowNoise) ?? rawInnerGlowImage
                let choke = max(0, Int(style.innerGlowChoke.rounded()))
                let rawInnerGlowCanvas = NSImage.rendered(size: outputSize) { _ in
                    switch style.innerGlowSource {
                    case .edge:
                        innerGlowImage.draw(
                            in: contentRect,
                            from: CGRect(origin: .zero, size: innerGlowImage.size),
                            operation: .sourceOver,
                            fraction: 1
                        )
                        if choke > 0 {
                            let directions = 24
                            for radius in 1...choke {
                                for step in 0..<directions {
                                    let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                                    let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                                    innerGlowImage.draw(
                                        in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                                        from: CGRect(origin: .zero, size: innerGlowImage.size),
                                        operation: .sourceOver,
                                        fraction: 1
                                    )
                                }
                            }
                        }
                    case .center where style.innerGlowTechnique == .precise:
                        innerGlowImage.draw(
                            in: contentRect,
                            from: CGRect(origin: .zero, size: innerGlowImage.size),
                            operation: .sourceOver,
                            fraction: 1
                        )
                        if choke > 0 {
                            let directions = 24
                            for radius in 1...choke {
                                for step in 0..<directions {
                                    let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                                    let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                                    innerGlowImage.draw(
                                        in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                                        from: CGRect(origin: .zero, size: innerGlowImage.size),
                                        operation: .sourceOver,
                                        fraction: 1
                                    )
                                }
                            }
                        }
                    case .center:
                        let glowColor = style.innerGlowColor.withAlphaComponent(style.innerGlowOpacity)
                        let clearColor = style.innerGlowColor.withAlphaComponent(0)
                        let center = CGPoint(x: contentRect.midX, y: contentRect.midY)
                        let radius = max(contentRect.width, contentRect.height) * 0.5 + CGFloat(choke)
                        NSGradient(starting: glowColor, ending: clearColor)?.draw(
                            fromCenter: center,
                            radius: 0,
                            toCenter: center,
                            radius: max(1, radius),
                            options: []
                        )
                    }
                } ?? NSImage(size: outputSize)
                let innerGlowCanvas = style.innerGlowSource == .center && style.innerGlowTechnique == .softer
                    ? rawInnerGlowCanvas.shadowNoised(amount: style.innerGlowNoise) ?? rawInnerGlowCanvas
                    : rawInnerGlowCanvas
                let diffusedInnerGlow: NSImage
                switch style.innerGlowTechnique {
                case .softer:
                    diffusedInnerGlow = innerGlowCanvas.blurred(radius: style.innerGlowBlur) ?? innerGlowCanvas
                case .precise:
                    diffusedInnerGlow = innerGlowCanvas.preciseInnerGlow(
                        radius: style.innerGlowBlur,
                        source: style.innerGlowSource
                    ) ?? innerGlowCanvas
                }
                let contouredInnerGlow = diffusedInnerGlow.applyingEffectContour(
                    style.innerGlowContour,
                    range: style.innerGlowRange
                ) ?? diffusedInnerGlow
                // Photoshop applies Jitter in the inner-glow quality stage,
                // after the smooth contour has been resolved.  Keeping it
                // here makes it visibly distinct from Noise, which textures
                // the source before blur, while stableNoise keeps rendering
                // deterministic across redraws and project reopen.
                let jitteredInnerGlow = contouredInnerGlow.shadowNoised(
                    amount: style.innerGlowJitter
                ) ?? contouredInnerGlow
                jitteredInnerGlow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: jitteredInnerGlow.size),
                    operation: .sourceOver,
                    fraction: 1
                )
                baseImage.draw(
                    in: contentRect,
                    from: CGRect(origin: .zero, size: baseImage.size),
                    operation: .destinationIn,
                    fraction: 1
                )
            }
        } ?? visibleImage
    }

    var compositingFrame: CGRect {
        renderedCompositingFrame(globalLightAngle: nil)
    }

    func renderedCompositingFrame(globalLightAngle: CGFloat?) -> CGRect {
        guard style.hasEffects else { return frame }
        let padding = style.padding(globalLightAngle: globalLightAngle)
        let imageSize = max(image.size.width, 1)
        let imageHeight = max(image.size.height, 1)
        let scaleX = frame.width / imageSize
        let scaleY = frame.height / imageHeight
        return CGRect(
            x: frame.minX - padding * scaleX,
            y: frame.minY - padding * scaleY,
            width: frame.width + padding * 2 * scaleX,
            height: frame.height + padding * 2 * scaleY
        )
    }
}
