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
        case .move, .marquee, .lasso, .magicWand, .crop, .brush, .eraser, .gradient, .eyedropper, .text, .rectangle, .ellipse, .hand, .zoom:
            true
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
    case blur
    case sharpen

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.adjustment.\(rawValue)")
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
    case softLight
    case hardLight
    case difference

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
        case .softLight:
            .softLight
        case .hardLight:
            .hardLight
        case .difference:
            .difference
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

    var hasEffects: Bool {
        strokeEnabled || shadowEnabled
    }

    var padding: CGFloat {
        guard hasEffects else { return 0 }
        let strokePadding = strokeEnabled ? strokeWidth : 0
        let shadowPadding = shadowEnabled
            ? shadowBlur * 2 + max(abs(shadowOffset.width), abs(shadowOffset.height))
            : 0
        return ceil(max(strokePadding, shadowPadding) + 2)
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

enum ImageEditorLayerKind {
    case pixel
    case group
    case adjustment(ImageEditorAdjustment, Double)
    case filter(ImageEditorFilter, Double)
    case text(ImageEditorTextContent)
}

struct ImageEditorLayer: Identifiable {
    var id = UUID()
    var name: String
    var image: NSImage
    var mask: NSImage?
    var frame: CGRect
    var isVisible: Bool
    var opacity: Double
    var blendMode: ImageEditorBlendMode
    var isLocked: Bool
    var style = ImageEditorLayerStyle()
    var kind: ImageEditorLayerKind = .pixel
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

    static func adjustment(name: String, size: CGSize, kind: ImageEditorAdjustment, amount: Double) -> ImageEditorLayer {
        ImageEditorLayer(
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
        return image.thumbnailImage(targetSize: size)
    }

    func maskThumbnail(size: CGSize = CGSize(width: 24, height: 24)) -> NSImage? {
        mask?.thumbnailImage(targetSize: size)
    }

    var contentImage: NSImage {
        guard let textContent else { return image }
        return NSImage.rendered(size: image.size) { _ in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: textContent.font,
                .foregroundColor: textContent.color
            ]
            textContent.text.draw(at: textContent.point, withAttributes: attributes)
        } ?? image
    }

    var visibleImage: NSImage {
        let sourceImage = contentImage
        guard let mask else { return sourceImage }
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
        guard style.hasEffects else { return visibleImage }
        let baseImage = visibleImage
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

            baseImage.draw(
                in: contentRect,
                from: CGRect(origin: .zero, size: baseImage.size),
                operation: .sourceOver,
                fraction: 1
            )
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
            let groupOpacity = group(for: layer)?.opacity ?? 1
            if let adjustment = layer.adjustment {
                canvas = canvas.applyingAdjustment(
                    kind: adjustment.kind,
                    amount: adjustment.amount * layer.opacity * groupOpacity,
                    mask: layer.mask
                ) ?? canvas
                continue
            }
            if let filter = layer.filter {
                canvas = canvas.applyingFilter(
                    kind: filter.kind,
                    intensity: filter.intensity * layer.opacity * groupOpacity,
                    mask: layer.mask
                ) ?? canvas
                continue
            }

            let baseCanvas = canvas
            canvas = NSImage.rendered(size: canvasSize) { _ in
                baseCanvas.draw(
                    in: CGRect(origin: .zero, size: canvasSize),
                    from: CGRect(origin: .zero, size: canvasSize),
                    operation: .copy,
                    fraction: 1
                )
                let compositingImage = layer.compositingImage
                let context = NSGraphicsContext.current
                context?.saveGraphicsState()
                if layer.isClippingMask,
                   let clippedImage = clippedCompositingImage(forLayerAt: index) {
                    clippedImage.draw(
                        in: CGRect(origin: .zero, size: canvasSize),
                        from: CGRect(origin: .zero, size: canvasSize),
                        operation: layer.blendMode.operation,
                        fraction: layer.opacity * groupOpacity
                    )
                } else {
                    compositingImage.draw(
                        in: layer.compositingFrame,
                        from: CGRect(origin: .zero, size: compositingImage.size),
                        operation: layer.blendMode.operation,
                        fraction: layer.opacity * groupOpacity
                    )
                }
                context?.restoreGraphicsState()
            } ?? canvas
        }
        return canvas
    }

    func group(for layer: ImageEditorLayer) -> ImageEditorLayer? {
        guard let groupID = layer.groupID else { return nil }
        return layers.first { $0.id == groupID && $0.isGroup }
    }

    func isEffectivelyLocked(_ layer: ImageEditorLayer) -> Bool {
        layer.isLocked || group(for: layer)?.isLocked == true
    }

    func isEffectivelyVisible(_ layer: ImageEditorLayer) -> Bool {
        layer.isVisible && group(for: layer)?.isVisible != false
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
