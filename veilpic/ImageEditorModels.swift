//
//  ImageEditorModels.swift
//  veilpic
//
//  Created by Codex on 2026/7/8.
//

import AppKit
import Foundation

enum ImageEditorTool: String, CaseIterable, Identifiable {
    case move
    case marquee
    case lasso
    case magicWand
    case crop
    case brush
    case eraser
    case cloneStamp
    case gradient
    case eyedropper
    case text
    case rectangle
    case ellipse
    case hand
    case zoom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.tool.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .move:
            "cursorarrow.motionlines"
        case .marquee:
            "rectangle.dashed"
        case .lasso:
            "lasso"
        case .magicWand:
            "wand.and.stars"
        case .crop:
            "crop"
        case .brush:
            "paintbrush.pointed"
        case .eraser:
            "eraser"
        case .cloneStamp:
            "seal"
        case .gradient:
            "square.lefthalf.filled"
        case .eyedropper:
            "eyedropper"
        case .text:
            "textformat"
        case .rectangle:
            "rectangle"
        case .ellipse:
            "circle"
        case .hand:
            "hand.draw"
        case .zoom:
            "magnifyingglass"
        }
    }

    var isImplemented: Bool {
        switch self {
        case .move, .marquee, .lasso, .magicWand, .crop, .brush, .eraser, .cloneStamp, .gradient, .eyedropper, .text, .rectangle, .ellipse, .hand, .zoom:
            true
        }
    }

    var supportsSelectionMode: Bool {
        switch self {
        case .marquee, .lasso, .magicWand:
            true
        default:
            false
        }
    }
}

enum ImageEditorSelectionMode: String, CaseIterable, Identifiable {
    case replace
    case add
    case subtract
    case intersect

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.selectionMode.\(rawValue)")
    }

    var compactTitle: String {
        L10n.text("imageEditor.selectionMode.\(rawValue).short")
    }

    var historyKey: String {
        switch self {
        case .replace:
            "imageEditor.history.selection"
        case .add:
            "imageEditor.history.selectionAdd"
        case .subtract:
            "imageEditor.history.selectionSubtract"
        case .intersect:
            "imageEditor.history.selectionIntersect"
        }
    }
}

struct ImageEditorSelectionMask: Equatable {
    var width: Int
    var height: Int
    var alpha: [UInt8]

    var size: CGSize {
        CGSize(width: width, height: height)
    }
}

struct ImageEditorSelection: Equatable {
    var points: [CGPoint]
    var isPolygon: Bool
    var isInverted = false
    var rasterMask: ImageEditorSelectionMask?

    static func rectangle(_ rect: CGRect) -> ImageEditorSelection {
        let normalized = rect.standardized
        return ImageEditorSelection(
            points: [
                CGPoint(x: normalized.minX, y: normalized.minY),
                CGPoint(x: normalized.maxX, y: normalized.minY),
                CGPoint(x: normalized.maxX, y: normalized.maxY),
                CGPoint(x: normalized.minX, y: normalized.maxY)
            ],
            isPolygon: false,
            isInverted: false,
            rasterMask: nil
        )
    }

    static func polygon(_ points: [CGPoint]) -> ImageEditorSelection? {
        guard points.count >= 3 else { return nil }
        return ImageEditorSelection(points: points, isPolygon: true, isInverted: false, rasterMask: nil)
    }

    static func raster(mask: ImageEditorSelectionMask, bounds: CGRect) -> ImageEditorSelection {
        var selection = rectangle(bounds)
        selection.rasterMask = mask
        return selection
    }

    var bounds: CGRect {
        guard let first = points.first else { return .zero }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
    }

    func path() -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: point)
        }
        path.close()
        return path
    }

    func contains(_ point: CGPoint) -> Bool {
        if isPolygon {
            return path().contains(point)
        }
        return bounds.contains(point)
    }
}

enum ImageEditorAdjustment: String, CaseIterable, Identifiable {
    case brightness
    case contrast
    case saturation
    case exposure
    case hue
    case invert
    case threshold
    case levels
    case curves
    case colorBalance
    case blur
    case sharpen

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.adjustment.\(rawValue)")
    }
}

struct ImageEditorAdjustmentSettings: Equatable {
    var levelsBlackPoint: Double = 0
    var levelsGamma: Double = 1
    var levelsWhitePoint: Double = 1
    var curvesShadows: Double = 0
    var curvesMidtones: Double = 0
    var curvesHighlights: Double = 0
    var colorBalanceShadowsCyanRed: Double = 0
    var colorBalanceShadowsMagentaGreen: Double = 0
    var colorBalanceShadowsYellowBlue: Double = 0
    var colorBalanceMidtonesCyanRed: Double = 0
    var colorBalanceMidtonesMagentaGreen: Double = 0
    var colorBalanceMidtonesYellowBlue: Double = 0
    var colorBalanceHighlightsCyanRed: Double = 0
    var colorBalanceHighlightsMagentaGreen: Double = 0
    var colorBalanceHighlightsYellowBlue: Double = 0

    func normalized() -> ImageEditorAdjustmentSettings {
        let black = max(0, min(0.98, levelsBlackPoint))
        let white = max(black + 0.01, min(1, levelsWhitePoint))
        let gamma = max(0.1, min(4, levelsGamma))
        return ImageEditorAdjustmentSettings(
            levelsBlackPoint: black,
            levelsGamma: gamma,
            levelsWhitePoint: white,
            curvesShadows: max(-1, min(1, curvesShadows)),
            curvesMidtones: max(-1, min(1, curvesMidtones)),
            curvesHighlights: max(-1, min(1, curvesHighlights)),
            colorBalanceShadowsCyanRed: Self.unit(colorBalanceShadowsCyanRed),
            colorBalanceShadowsMagentaGreen: Self.unit(colorBalanceShadowsMagentaGreen),
            colorBalanceShadowsYellowBlue: Self.unit(colorBalanceShadowsYellowBlue),
            colorBalanceMidtonesCyanRed: Self.unit(colorBalanceMidtonesCyanRed),
            colorBalanceMidtonesMagentaGreen: Self.unit(colorBalanceMidtonesMagentaGreen),
            colorBalanceMidtonesYellowBlue: Self.unit(colorBalanceMidtonesYellowBlue),
            colorBalanceHighlightsCyanRed: Self.unit(colorBalanceHighlightsCyanRed),
            colorBalanceHighlightsMagentaGreen: Self.unit(colorBalanceHighlightsMagentaGreen),
            colorBalanceHighlightsYellowBlue: Self.unit(colorBalanceHighlightsYellowBlue)
        )
    }

    private static func unit(_ value: Double) -> Double {
        max(-1, min(1, value))
    }
}

enum ImageEditorFilter: String, CaseIterable, Identifiable {
    case gaussianBlur
    case sharpen

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.filter.\(rawValue)")
    }
}

struct ImageEditorSmartFilter: Identifiable {
    var id = UUID()
    var kind: ImageEditorFilter
    var intensity: Double
    var isEnabled = true

    var normalizedIntensity: Double {
        max(0, min(1, intensity))
    }
}

enum ImageEditorLayerResizeHandle: String, CaseIterable, Identifiable {
    case topLeft
    case top
    case topRight
    case left
    case right
    case bottomLeft
    case bottom
    case bottomRight

    var id: String { rawValue }

    var affectsWidth: Bool {
        switch self {
        case .top, .bottom:
            false
        case .topLeft, .topRight, .left, .right, .bottomLeft, .bottomRight:
            true
        }
    }

    var affectsHeight: Bool {
        switch self {
        case .left, .right:
            false
        case .topLeft, .top, .topRight, .bottomLeft, .bottom, .bottomRight:
            true
        }
    }
}

enum ImageEditorBlendMode: String, CaseIterable, Identifiable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case colorDodge
    case colorBurn
    case linearDodge
    case linearBurn
    case softLight
    case hardLight
    case vividLight
    case linearLight
    case pinLight
    case difference
    case exclusion
    case hue
    case saturation
    case color
    case luminosity

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.blend.\(rawValue)")
    }

    var operation: NSCompositingOperation {
        switch self {
        case .normal:
            .sourceOver
        case .multiply:
            .multiply
        case .screen:
            .screen
        case .overlay:
            .overlay
        case .darken:
            .darken
        case .lighten:
            .lighten
        case .colorDodge:
            .colorDodge
        case .colorBurn:
            .colorBurn
        case .linearDodge:
            .plusLighter
        case .linearBurn:
            .sourceOver
        case .softLight:
            .softLight
        case .hardLight:
            .hardLight
        case .vividLight, .linearLight, .pinLight:
            .sourceOver
        case .difference:
            .difference
        case .exclusion, .hue, .saturation, .color, .luminosity:
            .sourceOver
        }
    }
}

struct ImageEditorLayerStyle {
    var strokeEnabled = false
    var strokeColor = NSColor.white
    var strokeWidth: CGFloat = 3
    var shadowEnabled = false
    var shadowColor = NSColor.black
    var shadowOpacity: CGFloat = 0.35
    var shadowBlur: CGFloat = 8
    var shadowOffset = CGSize(width: 7, height: -7)
    var outerGlowEnabled = false
    var outerGlowColor = NSColor.systemYellow
    var outerGlowOpacity: CGFloat = 0.42
    var outerGlowBlur: CGFloat = 10
    var outerGlowSpread: CGFloat = 3
    var innerGlowEnabled = false
    var innerGlowColor = NSColor.systemCyan
    var innerGlowOpacity: CGFloat = 0.36
    var innerGlowBlur: CGFloat = 8
    var innerGlowChoke: CGFloat = 2

    var hasEffects: Bool {
        strokeEnabled || shadowEnabled || outerGlowEnabled || innerGlowEnabled
    }

    var padding: CGFloat {
        guard hasEffects else { return 0 }
        let strokePadding = strokeEnabled ? strokeWidth : 0
        let shadowPadding = shadowEnabled
            ? shadowBlur * 2 + max(abs(shadowOffset.width), abs(shadowOffset.height))
            : 0
        let outerGlowPadding = outerGlowEnabled
            ? outerGlowBlur * 2 + outerGlowSpread
            : 0
        return ceil(max(strokePadding, shadowPadding, outerGlowPadding) + 2)
    }
}

struct ImageEditorTextContent {
    static let drawingPadding: CGFloat = 4

    var text: String
    var color: NSColor
    var fontSize: CGFloat
    var point: CGPoint

    var font: NSFont {
        NSFont.systemFont(ofSize: max(6, fontSize), weight: .semibold)
    }

    func layerSize() -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let measured = (text as NSString).size(withAttributes: attributes)
        return CGSize(
            width: max(1, ceil(measured.width + Self.drawingPadding * 2)),
            height: max(1, ceil(measured.height + Self.drawingPadding * 2))
        )
    }
}

enum ImageEditorShapeKind: String {
    case rectangle
    case ellipse

    var title: String {
        L10n.text("imageEditor.shape.\(rawValue)")
    }
}

struct ImageEditorShapeContent {
    static let minimumStrokeWidth: CGFloat = 1

    var kind: ImageEditorShapeKind
    var fillColor: NSColor
    var fillOpacity: CGFloat
    var strokeColor: NSColor
    var strokeWidth: CGFloat
    var strokeOpacity: CGFloat

    func normalized(size: CGSize) -> ImageEditorShapeContent {
        var content = self
        content.fillOpacity = max(0, min(1, fillOpacity))
        content.strokeOpacity = max(0, min(1, strokeOpacity))
        content.strokeWidth = max(Self.minimumStrokeWidth, min(min(size.width, size.height) / 2, strokeWidth))
        return content
    }

    func renderedImage(size: CGSize) -> NSImage {
        let normalized = normalized(size: size)
        return NSImage.rendered(size: size) { rect in
            let inset = normalized.strokeWidth / 2
            let shapeRect = rect.insetBy(dx: inset, dy: inset)
            let path = normalized.kind == .ellipse
                ? NSBezierPath(ovalIn: shapeRect)
                : NSBezierPath(rect: shapeRect)
            normalized.fillColor.withAlphaComponent(normalized.fillOpacity).setFill()
            path.fill()
            path.lineWidth = normalized.strokeWidth
            normalized.strokeColor.withAlphaComponent(normalized.strokeOpacity).setStroke()
            path.stroke()
        } ?? NSImage.transparent(size: size)
    }
}

enum ImageEditorLayerKind {
    case pixel
    case group
    case adjustment(ImageEditorAdjustment, Double)
    case filter(ImageEditorFilter, Double)
    case text(ImageEditorTextContent)
    case shape(ImageEditorShapeContent)
}

struct ImageEditorLayer: Identifiable {
    var id = UUID()
    var name: String
    var image: NSImage
    var mask: NSImage?
    var isMaskEnabled = true
    var isMaskLinked = true
    var maskDensity: Double = 1
    var maskFeather: Double = 0
    var linkedLayerIDs: Set<UUID> = []
    var frame: CGRect
    var isVisible: Bool
    var opacity: Double
    var fillOpacity: Double = 1
    var blendMode: ImageEditorBlendMode
    var isLocked: Bool
    var locksPixels = false
    var locksPosition = false
    var locksTransparentPixels = false
    var style = ImageEditorLayerStyle()
    var kind: ImageEditorLayerKind = .pixel
    var smartFilters: [ImageEditorSmartFilter] = []
    var adjustmentSettings = ImageEditorAdjustmentSettings()
    var groupID: UUID?
    var isGroupExpanded = true
    var isClippingMask = false

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
            blendMode: .normal,
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

    static func filter(name: String, size: CGSize, kind: ImageEditorFilter, intensity: Double) -> ImageEditorLayer {
        ImageEditorLayer(
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
        return image.thumbnailImage(targetSize: size)
    }

    func maskThumbnail(size: CGSize = CGSize(width: 24, height: 24)) -> NSImage? {
        mask?.thumbnailImage(targetSize: size)
    }

    var effectiveMask: NSImage? {
        guard isMaskEnabled else { return nil }
        return mask?.processedLayerMask(density: maskDensity, feather: maskFeather)
    }

    var contentImage: NSImage {
        let baseImage: NSImage
        if let textContent {
            baseImage = NSImage.rendered(size: image.size) { _ in
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: textContent.font,
                    .foregroundColor: textContent.color
                ]
                textContent.text.draw(at: textContent.point, withAttributes: attributes)
            } ?? image
        } else if let shapeContent {
            baseImage = shapeContent.renderedImage(size: image.size)
        } else {
            baseImage = image
        }
        return smartFilters.reduce(baseImage) { partial, filter in
            guard filter.isEnabled else { return partial }
            return partial.filtered(kind: filter.kind, intensity: filter.normalizedIntensity) ?? partial
        }
    }

    var hasSmartFilters: Bool {
        !smartFilters.isEmpty
    }

    var visibleImage: NSImage {
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
        style.hasEffects
    }

    var compositingImage: NSImage {
        let baseImage = visibleImage
        let normalizedFillOpacity = CGFloat(max(0, min(1, fillOpacity)))
        guard style.hasEffects else {
            guard normalizedFillOpacity < 1 else { return baseImage }
            return baseImage.withOpacity(normalizedFillOpacity) ?? baseImage
        }
        let padding = style.padding
        let outputSize = CGSize(
            width: baseImage.size.width + padding * 2,
            height: baseImage.size.height + padding * 2
        )
        let contentRect = CGRect(origin: CGPoint(x: padding, y: padding), size: baseImage.size)

        return NSImage.rendered(size: outputSize) { _ in
            if style.shadowEnabled {
                let shadowCanvas = NSImage.rendered(size: outputSize) { _ in
                    let shadowImage = baseImage.alphaTinted(
                        color: style.shadowColor.withAlphaComponent(style.shadowOpacity)
                    )
                    shadowImage.draw(
                        in: contentRect.offsetBy(dx: style.shadowOffset.width, dy: style.shadowOffset.height),
                        from: CGRect(origin: .zero, size: shadowImage.size),
                        operation: .sourceOver,
                        fraction: 1
                    )
                } ?? NSImage(size: outputSize)
                let blurredShadow = shadowCanvas.blurred(radius: style.shadowBlur) ?? shadowCanvas
                blurredShadow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            if style.strokeEnabled {
                let strokeImage = baseImage.alphaTinted(color: style.strokeColor)
                let width = max(1, Int(style.strokeWidth.rounded()))
                let directions = 24
                for radius in 1...width {
                    for step in 0..<directions {
                        let angle = CGFloat(step) / CGFloat(directions) * .pi * 2
                        let offset = CGSize(width: cos(angle) * CGFloat(radius), height: sin(angle) * CGFloat(radius))
                        strokeImage.draw(
                            in: contentRect.offsetBy(dx: offset.width, dy: offset.height),
                            from: CGRect(origin: .zero, size: strokeImage.size),
                            operation: .sourceOver,
                            fraction: 1
                        )
                    }
                }
            }

            if style.outerGlowEnabled {
                let glowImage = baseImage.alphaTinted(
                    color: style.outerGlowColor.withAlphaComponent(style.outerGlowOpacity)
                )
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
                let blurredGlow = glowCanvas.blurred(radius: style.outerGlowBlur) ?? glowCanvas
                blurredGlow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            baseImage.draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: baseImage.size),
                operation: .sourceOver,
                fraction: normalizedFillOpacity
            )

            if style.innerGlowEnabled {
                let innerGlowImage = baseImage.alphaTinted(
                    color: style.innerGlowColor.withAlphaComponent(style.innerGlowOpacity)
                )
                let choke = max(0, Int(style.innerGlowChoke.rounded()))
                let innerGlowCanvas = NSImage.rendered(size: outputSize) { _ in
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
                } ?? NSImage(size: outputSize)
                let blurredInnerGlow = innerGlowCanvas.blurred(radius: style.innerGlowBlur) ?? innerGlowCanvas
                blurredInnerGlow.draw(
                    in: CGRect(origin: .zero, size: outputSize),
                    from: CGRect(origin: .zero, size: outputSize),
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
        guard style.hasEffects else { return frame }
        let padding = style.padding
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

struct ImageEditorHistoryEntry: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let createdAt = Date()
}

struct ImageEditorDocument {
    let sourceName: String
    var canvasSize: CGSize
    var layers: [ImageEditorLayer]
    var selectedLayerID: UUID?
    var selectedLayerIDs: Set<UUID>
    var selection: ImageEditorSelection?
    var savedSelection: ImageEditorSelection?
    var history: [ImageEditorHistoryEntry]

    init(sourceName: String, image: NSImage) {
        let normalized = image.normalizedBitmapImage()
        self.sourceName = sourceName
        canvasSize = normalized.size
        let editLayer = ImageEditorLayer.blank(name: L10n.text("imageEditor.layer.edit"), size: normalized.size)
        self.layers = [
            .background(image: normalized),
            editLayer
        ]
        selectedLayerID = editLayer.id
        selectedLayerIDs = [editLayer.id]
        selection = nil
        savedSelection = nil
        self.history = [
            ImageEditorHistoryEntry(title: L10n.text("imageEditor.history.open"))
        ]
    }

    var selectedLayerIndex: Int? {
        guard let selectedLayerID else { return nil }
        return layers.firstIndex { $0.id == selectedLayerID }
    }

    var selectedLayer: ImageEditorLayer? {
        guard let selectedLayerIndex else { return nil }
        return layers[selectedLayerIndex]
    }

    var compositedImage: NSImage {
        var canvas = NSImage.transparent(size: canvasSize)
        for index in layers.indices {
            let layer = layers[index]
            guard shouldComposite(layer) else { continue }
            let groupOpacity = effectiveGroupOpacity(for: layer)
            let groupMask = effectiveGroupMask(for: layer)
            if let adjustment = layer.adjustment {
                canvas = canvas.applyingAdjustment(
                    kind: adjustment.kind,
                    amount: adjustment.amount * layer.opacity * groupOpacity,
                    settings: layer.adjustmentSettings,
                    mask: effectiveCanvasMask(forLayerAt: index, layerMask: layer.effectiveMask, groupMask: groupMask)
                ) ?? canvas
                continue
            }
            if let filter = layer.filter {
                canvas = canvas.applyingFilter(
                    kind: filter.kind,
                    intensity: filter.intensity * layer.opacity * groupOpacity,
                    mask: effectiveCanvasMask(forLayerAt: index, layerMask: layer.effectiveMask, groupMask: groupMask)
                ) ?? canvas
                continue
            }

            let layerCanvas: NSImage
            if layer.isClippingMask,
               let clippedImage = clippedCompositingImage(forLayerAt: index) {
                layerCanvas = imageByApplyingCanvasMask(clippedImage, mask: groupMask)
            } else {
                let compositingImage = layer.compositingImage
                let positionedCanvas = canvasImage(for: compositingImage, frame: layer.compositingFrame)
                layerCanvas = imageByApplyingCanvasMask(positionedCanvas, mask: groupMask)
            }
            canvas = canvas.blended(
                with: layerCanvas,
                mode: layer.blendMode,
                opacity: layer.opacity * groupOpacity
            ) ?? canvas
        }
        return canvas
    }

    func group(for layer: ImageEditorLayer) -> ImageEditorLayer? {
        guard let groupID = layer.groupID else { return nil }
        return layers.first { $0.id == groupID && $0.isGroup }
    }

    func groupDepth(for layer: ImageEditorLayer) -> Int {
        ancestorGroups(for: layer).count
    }

    func ancestorGroups(for layer: ImageEditorLayer) -> [ImageEditorLayer] {
        var ancestors: [ImageEditorLayer] = []
        var visitedIDs = Set<UUID>()
        var currentGroupID = layer.groupID
        while let groupID = currentGroupID,
              !visitedIDs.contains(groupID),
              let group = layers.first(where: { $0.id == groupID && $0.isGroup }) {
            visitedIDs.insert(groupID)
            ancestors.append(group)
            currentGroupID = group.groupID
        }
        return ancestors
    }

    func effectiveGroupOpacity(for layer: ImageEditorLayer) -> Double {
        ancestorGroups(for: layer).reduce(1) { partialResult, group in
            partialResult * group.opacity
        }
    }

    func effectiveGroupMask(for layer: ImageEditorLayer) -> NSImage? {
        let masks = ancestorGroups(for: layer).compactMap(\.effectiveMask)
        guard !masks.isEmpty else { return nil }
        return masks.reduce(NSImage.opaqueMask(size: canvasSize)) { partialResult, mask in
            imageByApplyingCanvasMask(partialResult, mask: mask)
        }
    }

    private func combinedCanvasMask(_ layerMask: NSImage?, _ groupMask: NSImage?) -> NSImage? {
        switch (layerMask, groupMask) {
        case (.none, .none):
            return nil
        case let (.some(layerMask), .none):
            return layerMask
        case let (.none, .some(groupMask)):
            return groupMask
        case let (.some(layerMask), .some(groupMask)):
            return imageByApplyingCanvasMask(layerMask, mask: groupMask)
        }
    }

    func clippingBaseCanvasMask(forLayerAt index: Int) -> NSImage? {
        guard layers.indices.contains(index),
              let base = clippingBase(forLayerAt: index)
        else { return nil }
        let baseImage = base.compositingImage
        return NSImage.rendered(size: canvasSize) { _ in
            baseImage.draw(
                in: base.compositingFrame,
                from: CGRect(origin: .zero, size: baseImage.size),
                operation: .sourceOver,
                fraction: 1
            )
        }
    }

    func localEffectMask(forLayerAt index: Int) -> NSImage? {
        guard layers.indices.contains(index) else { return nil }
        let layerMask = layers[index].effectiveMask
        guard let clippingMask = clippingBaseCanvasMask(forLayerAt: index) else { return layerMask }
        return combinedCanvasMask(layerMask, clippingMask)
    }

    private func effectiveCanvasMask(forLayerAt index: Int, layerMask: NSImage?, groupMask: NSImage?) -> NSImage? {
        let localMask = combinedCanvasMask(layerMask, groupMask)
        guard let clippingMask = clippingBaseCanvasMask(forLayerAt: index) else { return localMask }
        return combinedCanvasMask(localMask, clippingMask)
    }

    private func canvasImage(for image: NSImage, frame: CGRect) -> NSImage {
        NSImage.rendered(size: canvasSize) { _ in
            image.draw(
                in: frame,
                from: CGRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1
            )
        } ?? NSImage.transparent(size: canvasSize)
    }

    private func imageByApplyingCanvasMask(_ image: NSImage, mask: NSImage?) -> NSImage {
        guard let mask else { return image }
        return NSImage.rendered(size: image.size) { _ in
            image.draw(
                in: CGRect(origin: .zero, size: image.size),
                from: CGRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: image.size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        } ?? image
    }

    func isEffectivelyLocked(_ layer: ImageEditorLayer) -> Bool {
        layer.isLocked || ancestorGroups(for: layer).contains { $0.isLocked }
    }

    func isEffectivelyPixelsLocked(_ layer: ImageEditorLayer) -> Bool {
        isEffectivelyLocked(layer)
            || layer.locksPixels
            || ancestorGroups(for: layer).contains { $0.locksPixels }
    }

    func isEffectivelyPositionLocked(_ layer: ImageEditorLayer) -> Bool {
        isEffectivelyLocked(layer)
            || layer.locksPosition
            || ancestorGroups(for: layer).contains { $0.locksPosition }
    }

    func isEffectivelyVisible(_ layer: ImageEditorLayer) -> Bool {
        layer.isVisible && ancestorGroups(for: layer).allSatisfy(\.isVisible)
    }

    func shouldComposite(_ layer: ImageEditorLayer) -> Bool {
        !layer.isGroup && isEffectivelyVisible(layer)
    }

    func clippingBase(forLayerAt index: Int) -> ImageEditorLayer? {
        guard let baseIndex = clippingBaseIndex(forLayerAt: index) else { return nil }
        return layers[baseIndex]
    }

    func clippingBaseIndex(forLayerAt index: Int) -> Int? {
        guard layers.indices.contains(index) else { return nil }
        let layer = layers[index]
        guard layer.isClippingMask else { return nil }
        return layers[..<index].indices.reversed().first { candidateIndex in
            let candidate = layers[candidateIndex]
            return !candidate.isGroup
                && !candidate.isAdjustment
                && !candidate.isFilter
                && !candidate.isClippingMask
                && candidate.groupID == layer.groupID
                && isEffectivelyVisible(candidate)
        }
    }

    func hasClippingBase(below index: Int, groupID: UUID?) -> Bool {
        guard index > 0 else { return false }
        return layers[..<index].contains { candidate in
            !candidate.isGroup
                && !candidate.isAdjustment
                && !candidate.isFilter
                && !candidate.isClippingMask
                && candidate.groupID == groupID
                && isEffectivelyVisible(candidate)
        }
    }

    func clippedCompositingImage(forLayerAt index: Int) -> NSImage? {
        guard layers.indices.contains(index),
              let base = clippingBase(forLayerAt: index)
        else { return nil }
        let layer = layers[index]
        let layerImage = layer.compositingImage
        let baseImage = base.compositingImage
        return NSImage.rendered(size: canvasSize) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.saveGState()
            layerImage.draw(
                in: layer.compositingFrame,
                from: CGRect(origin: .zero, size: layerImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            baseImage.draw(
                in: base.compositingFrame,
                from: CGRect(origin: .zero, size: baseImage.size),
                operation: .destinationIn,
                fraction: 1
            )
            context.restoreGState()
        }
    }
}

private extension NSImage {
    func processedLayerMask(density: Double, feather: Double) -> NSImage? {
        let normalizedDensity = max(0, min(1, density))
        let normalizedFeather = max(0, min(80, feather))
        let featheredMask = normalizedFeather > 0 ? (blurred(radius: normalizedFeather) ?? self) : self
        guard normalizedDensity < 1 else { return featheredMask }
        guard let alpha = featheredMask.alphaPlane() else { return featheredMask }
        let adjustedAlpha = alpha.values.map { value -> UInt8 in
            let revealed = 255 - Double(255 - Int(value)) * normalizedDensity
            return UInt8(max(0, min(255, Int(revealed.rounded()))))
        }
        return NSImage.alphaMaskImage(width: alpha.width, height: alpha.height, alpha: adjustedAlpha)
    }

    func alphaPlane() -> (width: Int, height: Int, values: [UInt8])? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = max(1, cgImage.width)
        let height = max(1, cgImage.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                alpha[y * width + x] = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
            }
        }
        return (width, height, alpha)
    }

    func withOpacity(_ opacity: CGFloat) -> NSImage? {
        let normalizedOpacity = max(0, min(1, opacity))
        return NSImage.rendered(size: size) { rect in
            draw(
                in: rect,
                from: CGRect(origin: .zero, size: size),
                operation: .sourceOver,
                fraction: normalizedOpacity
            )
        }
    }
}

struct ImageEditorTheme {
    static let window = NSColor(calibratedWhite: 0.11, alpha: 1)
    static let chrome = NSColor(calibratedWhite: 0.18, alpha: 1)
    static let panel = NSColor(calibratedWhite: 0.23, alpha: 1)
    static let panelRaised = NSColor(calibratedWhite: 0.29, alpha: 1)
    static let border = NSColor(calibratedWhite: 0.38, alpha: 1)
    static let selected = NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.78, alpha: 1)
    static let text = NSColor(calibratedWhite: 0.92, alpha: 1)
    static let mutedText = NSColor(calibratedWhite: 0.68, alpha: 1)
}
