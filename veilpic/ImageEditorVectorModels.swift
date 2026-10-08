import AppKit
import CoreImage
import Foundation
import simd

enum ImageEditorTextAlignment: String, CaseIterable, Identifiable {
    case left
    case center
    case right
    case justified

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.textAlignment.\(rawValue)")
    }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left:
            return .left
        case .center:
            return .center
        case .right:
            return .right
        case .justified:
            return .justified
        }
    }
}

enum ImageEditorTextCase: String, CaseIterable, Codable, Sendable, Identifiable {
    case original
    case uppercase
    case lowercase
    case titleCase
    case smallCaps

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.textCase.\(rawValue)")
    }

    func applying(to text: String) -> String {
        switch self {
        case .original:
            text
        case .uppercase:
            text.uppercased()
        case .lowercase:
            text.lowercased()
        case .titleCase:
            text.capitalized
        case .smallCaps:
            text.uppercased()
        }
    }
}

enum ImageEditorTextVerticalAlignment: String, CaseIterable, Codable, Sendable, Identifiable {
    case top
    case center
    case bottom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.textVerticalAlignment.\(rawValue)")
    }
}

struct ImageEditorTextContent {
    static let drawingPadding: CGFloat = 4
    static let maximumBoxDimension: CGFloat = 12_000
    static let minimumFontSize: CGFloat = 6
    static let maximumFontSize: CGFloat = 240
    static let minimumCharacterSpacing: CGFloat = -8
    static let maximumCharacterSpacing: CGFloat = 48
    static let maximumLineSpacing: CGFloat = 96
    static let maximumFirstLineIndent: CGFloat = 800
    static let maximumParagraphSpacing: CGFloat = 400
    static let smallCapsScale: CGFloat = 0.8
    static let systemFontFamilyName = NSFont.systemFont(ofSize: NSFont.systemFontSize).familyName ?? "System"

    var text: String
    var color: NSColor
    var fontSize: CGFloat
    var fontFamilyName: String = Self.systemFontFamilyName
    var point: CGPoint
    var isBold = false
    var isItalic = false
    var isUnderlined = false
    var isStruckThrough = false
    var characterSpacing: CGFloat = 0
    var lineSpacing: CGFloat = 0
    var boxWidth: CGFloat = 0
    var boxHeight: CGFloat = 0
    var alignment: ImageEditorTextAlignment = .left
    var leftIndent: CGFloat = 0
    var rightIndent: CGFloat = 0
    var firstLineIndent: CGFloat = 0
    var paragraphSpacing: CGFloat = 0
    var textCase: ImageEditorTextCase = .original
    var truncatesOverflow = false
    var verticalAlignment: ImageEditorTextVerticalAlignment = .top

    var displayText: String {
        textCase.applying(to: text)
    }

    var font: NSFont {
        let size = max(Self.minimumFontSize, min(Self.maximumFontSize, fontSize))
        var traits: NSFontTraitMask = []
        if isBold { traits.insert(.boldFontMask) }
        if isItalic { traits.insert(.italicFontMask) }
        let familyFont = fontFamilyName == Self.systemFontFamilyName ? nil : NSFontManager.shared.font(
            withFamily: fontFamilyName,
            traits: traits,
            weight: isBold ? 9 : 5,
            size: size
        )
        if let familyFont {
            return familyFont
        }
        let fallback = NSFont.systemFont(ofSize: size, weight: isBold ? .bold : .regular)
        guard isItalic else { return fallback }
        return NSFontManager.shared.convert(fallback, toHaveTrait: .italicFontMask)
    }

    var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment.nsTextAlignment
        style.lineSpacing = max(0, lineSpacing)
        style.headIndent = max(0, leftIndent)
        style.firstLineHeadIndent = max(0, leftIndent + firstLineIndent)
        style.tailIndent = rightIndent > 0 ? -rightIndent : 0
        style.paragraphSpacing = max(0, paragraphSpacing)
        return style
    }

    var drawingOptions: NSString.DrawingOptions {
        var options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        if truncatesOverflow {
            options.insert(.truncatesLastVisibleLine)
        }
        return options
    }

    var attributes: [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .kern: characterSpacing,
            .paragraphStyle: paragraphStyle
        ]
        if isUnderlined {
            result[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if isStruckThrough {
            result[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        return result
    }

    var attributedString: NSAttributedString {
        guard textCase == .smallCaps else {
            return NSAttributedString(string: displayText, attributes: attributes)
        }
        let result = NSMutableAttributedString()
        for character in text {
            let source = String(character)
            let displayed = source.uppercased()
            var characterAttributes = attributes
            if source != displayed, source == source.lowercased() {
                characterAttributes[.font] = font.withSize(max(6, font.pointSize * Self.smallCapsScale))
            }
            result.append(NSAttributedString(string: displayed, attributes: characterAttributes))
        }
        return result
    }

    var requiredParagraphHeight: CGFloat {
        guard boxWidth > 0 else { return 0 }
        let bounding = attributedString.boundingRect(
            with: CGSize(width: max(1, boxWidth), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return max(1, ceil(bounding.height))
    }

    var hasOverflow: Bool {
        boxWidth > 0 && boxHeight > 0 && requiredParagraphHeight > boxHeight + 0.5
    }

    func layerSize() -> CGSize {
        let measured: CGSize
        if boxWidth > 0 {
            measured = CGSize(
                width: boxWidth,
                height: boxHeight > 0 ? boxHeight : requiredParagraphHeight
            )
        } else {
            let lines = displayText.components(separatedBy: .newlines)
            let lineSizes = lines.map { (($0.isEmpty ? " " : $0) as NSString).size(withAttributes: attributes) }
            let width = lineSizes.map(\.width).max() ?? 1
            let height = lineSizes.reduce(CGFloat(0)) { partial, size in partial + size.height }
                + max(0, CGFloat(max(0, lines.count - 1)) * lineSpacing)
                + max(0, CGFloat(max(0, lines.count - 1)) * paragraphSpacing)
            measured = CGSize(width: ceil(width), height: ceil(height))
        }
        return CGSize(
            width: max(1, ceil(measured.width + Self.drawingPadding * 2)),
            height: max(1, ceil(measured.height + Self.drawingPadding * 2))
        )
    }

    func drawingRect(in size: CGSize) -> CGRect {
        let availableHeight = max(1, size.height - point.y - Self.drawingPadding)
        let verticalOffset: CGFloat
        guard boxWidth > 0, boxHeight > 0 else {
            return CGRect(
                x: point.x,
                y: point.y,
                width: max(1, size.width - point.x - Self.drawingPadding),
                height: availableHeight
            )
        }
        let remainingHeight = max(0, boxHeight - requiredParagraphHeight)
        switch verticalAlignment {
        case .top:
            verticalOffset = 0
        case .center:
            verticalOffset = remainingHeight / 2
        case .bottom:
            verticalOffset = remainingHeight
        }
        return CGRect(
            x: point.x,
            y: point.y + verticalOffset,
            width: max(1, size.width - point.x - Self.drawingPadding),
            height: max(1, availableHeight - verticalOffset)
        )
    }
}

enum ImageEditorShapeKind: String {
    case rectangle
    case ellipse
    case path

    var title: String {
        L10n.text("imageEditor.shape.\(rawValue)")
    }
}

enum ImageEditorPathControlRole {
    case anchor
    case inHandle
    case outHandle
}

struct ImageEditorPathAnchor: Equatable, Codable {
    var point: CGPoint
    var inControl: CGPoint?
    var outControl: CGPoint?

    func normalized(size: CGSize) -> ImageEditorPathAnchor {
        ImageEditorPathAnchor(
            point: point.clamped(to: size),
            inControl: inControl?.clamped(to: size),
            outControl: outControl?.clamped(to: size)
        )
    }
}

enum ImageEditorStrokeCap: String, Codable, CaseIterable {
    case butt
    case round
    case square

    init(figmaValue: String?) {
        switch figmaValue?.uppercased() {
        case "NONE": self = .butt
        case "ROUND": self = .round
        case "SQUARE": self = .square
        default: self = .round
        }
    }

    var nsStyle: NSBezierPath.LineCapStyle {
        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }
}

enum ImageEditorStrokeDecoration: String, Codable, CaseIterable, Identifiable {
    case none
    case openArrow
    case filledArrow
    case filledTriangle
    case filledDiamond
    case filledCircle

    var id: String { rawValue }

    init(figmaValue: String?) {
        switch figmaValue?.uppercased() {
        case "ARROW_LINES": self = .openArrow
        case "ARROW_EQUILATERAL": self = .filledArrow
        case "TRIANGLE_FILLED": self = .filledTriangle
        case "DIAMOND_FILLED": self = .filledDiamond
        case "CIRCLE_FILLED": self = .filledCircle
        default: self = .none
        }
    }
}

enum ImageEditorStrokeJoin: String, Codable, CaseIterable {
    case miter
    case round
    case bevel

    init(figmaValue: String?) {
        switch figmaValue?.uppercased() {
        case "MITER": self = .miter
        case "BEVEL": self = .bevel
        case "ROUND": self = .round
        default: self = .round
        }
    }

    var nsStyle: NSBezierPath.LineJoinStyle {
        switch self {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        }
    }
}

nonisolated enum ImageEditorPathComponentOperation: String, Codable, Equatable, Sendable {
    case exclude
    case combine
    case subtract
    case intersect
    case continuePrevious
}

private extension CGPoint {
    func clamped(to size: CGSize) -> CGPoint {
        CGPoint(
            x: max(0, min(size.width, x)),
            y: max(0, min(size.height, y))
        )
    }
}

struct ImageEditorShapeContent {
    static let minimumStrokeWidth: CGFloat = 0.1
    static let maximumStrokeWidth: CGFloat = 96
    static let defaultStrokeMiterLimit: CGFloat = 10
    static let minimumStrokeMiterLimit: CGFloat = 1
    static let maximumStrokeMiterLimit: CGFloat = 1_000
    static let minimumStrokeDashOffset: CGFloat = -2_048
    static let maximumStrokeDashOffset: CGFloat = 2_048

    var kind: ImageEditorShapeKind
    var fillColor: NSColor
    var fillGradient: ImageEditorGradientFillContent? = nil
    var fillGradientCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var fillOpacity: CGFloat
    var strokeColor: NSColor
    var strokeWidth: CGFloat
    var strokeOpacity: CGFloat
    var strokePosition: ImageEditorStrokePosition = .inside
    var strokeCap: ImageEditorStrokeCap = .round
    var strokeStartDecoration: ImageEditorStrokeDecoration = .none
    var strokeEndDecoration: ImageEditorStrokeDecoration = .none
    var strokeJoin: ImageEditorStrokeJoin = .round
    var strokeMiterLimit: CGFloat = Self.defaultStrokeMiterLimit
    var strokeDashPattern: [CGFloat] = []
    var strokeDashOffset: CGFloat = 0
    var cornerRadius: CGFloat = 0
    var cornerRadii: ImageEditorRectangleCornerRadii? = nil
    var cornerSmoothing: CGFloat = 0
    var pathPoints: [CGPoint] = []
    var pathAnchors: [ImageEditorPathAnchor] = []
    var pathSubpaths: [[ImageEditorPathAnchor]] = []
    var pathComponentOperations: [ImageEditorPathComponentOperation] = []
    var pathStartsWithAllPixels = false
    var isPathClosed = true

    func normalized(size: CGSize) -> ImageEditorShapeContent {
        var content = self
        content.fillGradient = fillGradient?.normalized()
        content.fillGradientCenter = CGPoint(
            x: Self.normalizedGradientCenterComponent(fillGradientCenter.x),
            y: Self.normalizedGradientCenterComponent(fillGradientCenter.y)
        )
        content.fillOpacity = max(0, min(1, fillOpacity))
        content.strokeOpacity = max(0, min(1, strokeOpacity))
        content.strokeMiterLimit = max(
            Self.minimumStrokeMiterLimit,
            min(
                Self.maximumStrokeMiterLimit,
                strokeMiterLimit.isFinite ? strokeMiterLimit : Self.defaultStrokeMiterLimit
            )
        )
        content.strokeDashPattern = strokeDashPattern
            .filter { $0.isFinite && $0 > 0 }
            .map { min(2_048, $0) }
        if content.strokeDashPattern.count < 2 {
            content.strokeDashPattern = []
        }
        content.strokeDashOffset = max(
            Self.minimumStrokeDashOffset,
            min(
                Self.maximumStrokeDashOffset,
                strokeDashOffset.isFinite ? strokeDashOffset : 0
            )
        )
        if kind == .path {
            content.strokeWidth = max(Self.minimumStrokeWidth, min(Self.maximumStrokeWidth, strokeWidth))
        } else {
            content.strokeWidth = max(
                Self.minimumStrokeWidth,
                min(Self.maximumStrokeWidth, min(min(size.width, size.height) / 2, strokeWidth))
            )
        }
        if kind == .rectangle {
            content.cornerRadius = max(0, min(min(size.width, size.height) / 2, cornerRadius))
            content.cornerRadii = cornerRadii?.normalized(size: size)
            content.cornerSmoothing = max(0, min(1, cornerSmoothing.isFinite ? cornerSmoothing : 0))
            if let cornerRadii = content.cornerRadii {
                content.cornerRadius = cornerRadii.topLeft
            }
        } else {
            content.cornerRadius = 0
            content.cornerRadii = nil
            content.cornerSmoothing = 0
        }
        content.pathPoints = pathPoints.map { point in
            CGPoint(
                x: max(0, min(size.width, point.x)),
                y: max(0, min(size.height, point.y))
            )
        }
        if pathAnchors.isEmpty {
            content.pathAnchors = content.pathPoints.map { ImageEditorPathAnchor(point: $0) }
        } else {
            content.pathAnchors = pathAnchors.map { $0.normalized(size: size) }
            content.pathPoints = content.pathAnchors.map(\.point)
        }
        var normalizedPathSubpaths: [[ImageEditorPathAnchor]] = []
        var normalizedPathOperations: [ImageEditorPathComponentOperation] = []
        if !pathComponentOperations.isEmpty {
            normalizedPathOperations.append(pathComponentOperations[0])
        }
        for (index, anchors) in pathSubpaths.enumerated() {
            let normalizedAnchors = anchors.map { $0.normalized(size: size) }
            guard normalizedAnchors.count >= 2 else { continue }
            normalizedPathSubpaths.append(normalizedAnchors)
            if !pathComponentOperations.isEmpty {
                normalizedPathOperations.append(
                    pathComponentOperations.indices.contains(index + 1)
                        ? pathComponentOperations[index + 1]
                        : .exclude
                )
            }
        }
        content.pathSubpaths = normalizedPathSubpaths
        if !pathComponentOperations.isEmpty {
            content.pathComponentOperations = normalizedPathOperations
        }
        return content
    }

    var editablePathAnchors: [ImageEditorPathAnchor] {
        if pathAnchors.isEmpty {
            return pathPoints.map { ImageEditorPathAnchor(point: $0) }
        }
        return pathAnchors
    }

    var editablePathSubpaths: [[ImageEditorPathAnchor]] {
        pathSubpaths.filter { !$0.isEmpty }
    }

    var allEditablePathSubpaths: [[ImageEditorPathAnchor]] {
        let primary = editablePathAnchors
        guard !primary.isEmpty else { return editablePathSubpaths }
        return [primary] + editablePathSubpaths
    }

    func renderedImage(size: CGSize) -> NSImage {
        let normalized = normalized(size: size)
        return NSImage.rendered(size: size) { rect in
            let booleanMask = normalized.kind == .path
                && normalized.isPathClosed
                && normalized.hasExplicitPathComponentOperations
                ? normalized.renderedPathComponentMask(size: size, inverted: false)
                : nil
            if let booleanMask {
                if let gradient = normalized.fillGradient {
                    gradient.renderedImage(
                        size: size,
                        centerNormalized: normalized.fillGradientCenter
                    ).draw(
                        in: rect,
                        from: .zero,
                        operation: .sourceOver,
                        fraction: normalized.fillOpacity,
                        respectFlipped: true,
                        hints: nil
                    )
                } else {
                    normalized.fillColor.withAlphaComponent(normalized.fillOpacity).setFill()
                    rect.fill()
                }
                booleanMask.draw(
                    in: rect,
                    from: .zero,
                    operation: .destinationIn,
                    fraction: 1,
                    respectFlipped: true,
                    hints: nil
                )
            }
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                let path: NSBezierPath
                if normalized.kind == .path {
                    path = normalized.pathBezierPath()
                } else {
                    let fillInset = normalized.strokeWidth / 2
                    let shapeRect = rect.insetBy(dx: fillInset, dy: fillInset)
                    if normalized.kind == .ellipse {
                        path = NSBezierPath(ovalIn: shapeRect)
                    } else {
                        path = normalized.rectangleBezierPath(in: shapeRect)
                    }
                }
                if normalized.kind != .path || normalized.isPathClosed {
                    if let gradient = normalized.fillGradient {
                        if booleanMask == nil {
                            NSGraphicsContext.saveGraphicsState()
                            path.addClip()
                            gradient.renderedImage(
                                size: size,
                                centerNormalized: normalized.fillGradientCenter
                            ).draw(
                                in: rect,
                                from: .zero,
                                operation: .sourceOver,
                                fraction: normalized.fillOpacity,
                                respectFlipped: true,
                                hints: nil
                            )
                            NSGraphicsContext.restoreGraphicsState()
                        }
                    } else if booleanMask == nil {
                        normalized.fillColor.withAlphaComponent(normalized.fillOpacity).setFill()
                        path.fill()
                    }
                }
                let strokePath: NSBezierPath
                if normalized.kind == .path {
                    strokePath = path
                } else {
                    let strokeInset: CGFloat
                    switch normalized.strokePosition {
                    case .inside: strokeInset = normalized.strokeWidth / 2
                    case .center: strokeInset = 0
                    case .outside: strokeInset = -normalized.strokeWidth / 2
                    }
                    let strokeRect = rect.insetBy(dx: strokeInset, dy: strokeInset)
                    strokePath = normalized.kind == .ellipse
                        ? NSBezierPath(ovalIn: strokeRect)
                        : normalized.rectangleBezierPath(in: strokeRect)
                }
                strokePath.lineJoinStyle = normalized.strokeJoin.nsStyle
                strokePath.miterLimit = normalized.strokeMiterLimit
                strokePath.lineCapStyle = normalized.strokeCap.nsStyle
                if normalized.strokeDashPattern.isEmpty {
                    strokePath.setLineDash(nil, count: 0, phase: 0)
                } else {
                    normalized.strokeDashPattern.withUnsafeBufferPointer { pattern in
                        strokePath.setLineDash(
                            pattern.baseAddress,
                            count: pattern.count,
                            phase: normalized.strokeDashOffset
                        )
                    }
                }
                strokePath.lineWidth = normalized.strokeWidth
                normalized.strokeColor.withAlphaComponent(normalized.strokeOpacity).setStroke()
                strokePath.stroke()
                normalized.drawStrokeDecorations()
            }
        } ?? NSImage.transparent(size: size)
    }

    private static func normalizedGradientCenterComponent(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0.5 }
        return max(-4, min(5, value))
    }

    func pathBezierPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.windingRule = .evenOdd
        let subpaths = allEditablePathSubpaths
        guard !subpaths.isEmpty else { return path }
        for anchors in subpaths {
            appendSubpath(anchors, to: path)
        }
        return path
    }

    func renderedVectorMask(size: CGSize, inverted: Bool) -> NSImage? {
        guard kind == .path,
              isPathClosed,
              editablePathAnchors.count >= 3,
              size.width > 0,
              size.height > 0
        else { return nil }
        if hasExplicitPathComponentOperations {
            return renderedPathComponentMask(size: size, inverted: inverted)
        }
        return NSImage.rendered(size: size) { rect in
            NSGraphicsContext.current?.withImageEditorTopLeftCoordinates(height: size.height) {
                NSColor.white.setFill()
                let path = pathBezierPath()
                guard inverted else {
                    path.fill()
                    return
                }
                let inversePath = NSBezierPath(rect: rect)
                inversePath.append(path)
                inversePath.windingRule = .evenOdd
                inversePath.fill()
            }
        }
    }

    private func appendSubpath(_ anchors: [ImageEditorPathAnchor], to path: NSBezierPath) {
        guard let first = anchors.first else { return }
        path.move(to: first.point)
        for index in anchors.indices.dropFirst() {
            let previous = anchors[index - 1]
            let current = anchors[index]
            if previous.outControl != nil || current.inControl != nil {
                path.curve(
                    to: current.point,
                    controlPoint1: previous.outControl ?? previous.point,
                    controlPoint2: current.inControl ?? current.point
                )
            } else {
                path.line(to: current.point)
            }
        }
        if isPathClosed, anchors.count > 2, let last = anchors.last {
            if last.outControl != nil || first.inControl != nil {
                path.curve(
                    to: first.point,
                    controlPoint1: last.outControl ?? last.point,
                    controlPoint2: first.inControl ?? first.point
                )
                path.close()
            } else {
                path.close()
            }
        }
    }

    private func drawStrokeDecorations() {
        guard kind == .path, !isPathClosed, strokeOpacity > 0 else { return }
        let color = strokeColor.withAlphaComponent(strokeOpacity)
        for anchors in allEditablePathSubpaths where anchors.count >= 2 {
            if let first = anchors.first,
               let direction = endpointDirection(anchors: anchors, isStart: true) {
                drawStrokeDecoration(
                    strokeStartDecoration,
                    at: first.point,
                    outwardDirection: direction,
                    color: color
                )
            }
            if let last = anchors.last,
               let direction = endpointDirection(anchors: anchors, isStart: false) {
                drawStrokeDecoration(
                    strokeEndDecoration,
                    at: last.point,
                    outwardDirection: direction,
                    color: color
                )
            }
        }
    }

    private func endpointDirection(
        anchors: [ImageEditorPathAnchor],
        isStart: Bool
    ) -> CGVector? {
        let delta: CGVector
        if isStart {
            let first = anchors[0]
            let second = anchors[1]
            let inward = first.outControl ?? second.inControl ?? second.point
            delta = CGVector(dx: first.point.x - inward.x, dy: first.point.y - inward.y)
        } else {
            let last = anchors[anchors.count - 1]
            let previous = anchors[anchors.count - 2]
            let inward = last.inControl ?? previous.outControl ?? previous.point
            delta = CGVector(dx: last.point.x - inward.x, dy: last.point.y - inward.y)
        }
        let length = hypot(delta.dx, delta.dy)
        guard length > 0.000_1 else { return nil }
        return CGVector(dx: delta.dx / length, dy: delta.dy / length)
    }

    private func drawStrokeDecoration(
        _ decoration: ImageEditorStrokeDecoration,
        at endpoint: CGPoint,
        outwardDirection: CGVector,
        color: NSColor
    ) {
        guard decoration != .none else { return }
        let halfWidth = max(2.5, strokeWidth / 2 + 2.5)
        let length = max(6, strokeWidth * 4)
        let perpendicular = CGVector(dx: -outwardDirection.dy, dy: outwardDirection.dx)
        func point(back: CGFloat, side: CGFloat = 0) -> CGPoint {
            CGPoint(
                x: endpoint.x - outwardDirection.dx * back + perpendicular.dx * side,
                y: endpoint.y - outwardDirection.dy * back + perpendicular.dy * side
            )
        }

        let marker = NSBezierPath()
        marker.lineJoinStyle = .round
        marker.lineCapStyle = .round
        marker.lineWidth = max(1, strokeWidth)
        switch decoration {
        case .none:
            return
        case .openArrow:
            marker.move(to: point(back: length, side: halfWidth))
            marker.line(to: endpoint)
            marker.line(to: point(back: length, side: -halfWidth))
            color.setStroke()
            marker.stroke()
        case .filledArrow:
            marker.move(to: endpoint)
            marker.line(to: point(back: length, side: halfWidth))
            marker.line(to: point(back: length * 0.72))
            marker.line(to: point(back: length, side: -halfWidth))
            marker.close()
            color.setFill()
            marker.fill()
        case .filledTriangle:
            marker.move(to: point(back: 0, side: halfWidth))
            marker.line(to: point(back: 0, side: -halfWidth))
            marker.line(to: point(back: length))
            marker.close()
            color.setFill()
            marker.fill()
        case .filledDiamond:
            marker.move(to: endpoint)
            marker.line(to: point(back: length * 0.5, side: halfWidth))
            marker.line(to: point(back: length))
            marker.line(to: point(back: length * 0.5, side: -halfWidth))
            marker.close()
            color.setFill()
            marker.fill()
        case .filledCircle:
            let radius = halfWidth
            let center = point(back: radius)
            color.setFill()
            NSBezierPath(
                ovalIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            ).fill()
        }
    }
}

struct ImageEditorSmartObjectContent {
    var sourceName: String
    var originalSize: CGSize
    var sourceID = UUID()
}

enum ImageEditorLayerKind {
    case pixel
    case group
    case adjustment(ImageEditorAdjustment, Double)
    case filter(ImageEditorFilter, Double)
    case solidColorFill(ImageEditorSolidColorFillContent)
    case patternFill(ImageEditorPatternFillContent)
    case gradientFill(ImageEditorGradientFillContent)
    case text(ImageEditorTextContent)
    case shape(ImageEditorShapeContent)
    case smartObject(ImageEditorSmartObjectContent)

    var isPixel: Bool {
        if case .pixel = self { return true }
        return false
    }
}
