import AppKit
import Foundation

struct XomoEditableSVGImport {
    var content: ImageEditorShapeContent
    var size: CGSize
}

/// Imports one safely representable SVG geometry node as a native editable shape.
enum XomoEditableSVGImporter {
    static let maximumByteCount = 2 * 1_024 * 1_024

    static func parse(_ data: Data) -> XomoEditableSVGImport? {
        guard !data.isEmpty,
              data.count <= maximumByteCount,
              let source = String(data: data, encoding: .utf8),
              !source.localizedCaseInsensitiveContains("<!DOCTYPE"),
              !source.localizedCaseInsensitiveContains("<!ENTITY"),
              let document = try? XMLDocument(data: data, options: []),
              let root = document.rootElement(),
              localName(of: root) == "svg",
              let viewportScale = viewportScale(root),
              let geometryNodes = try? root.nodes(
                forXPath: ".//*[local-name()='path' or local-name()='rect' or local-name()='circle' or local-name()='ellipse' or local-name()='line' or local-name()='polyline' or local-name()='polygon' or local-name()='text' or local-name()='image' or local-name()='use']"
              ),
              geometryNodes.count == 1,
              let geometry = geometryNodes.first as? XMLElement
        else { return nil }

        let lineage = elementLineage(from: root, to: geometry)
        guard !lineage.isEmpty,
              !hasUnsupportedContainer(lineage),
              !hasUnsupportedPresentation(lineage),
              let presentation = presentation(in: lineage, viewportScale: viewportScale)
        else { return nil }

        switch localName(of: geometry) {
        case "path":
            return pathImport(
                geometry,
                lineage: lineage,
                presentation: presentation,
                viewportScale: viewportScale
            )
        case "rect":
            return rectangleImport(
                geometry,
                presentation: presentation,
                viewportScale: viewportScale
            )
        case "circle", "ellipse":
            return ellipseImport(
                geometry,
                presentation: presentation,
                viewportScale: viewportScale
            )
        default:
            return nil
        }
    }

    private struct SVGPresentation {
        var fillPaint: SVGPaint
        var fillOpacity: CGFloat
        var strokePaint: SVGPaint
        var strokeOpacity: CGFloat
        var strokeWidth: CGFloat
        var strokeCap: ImageEditorStrokeCap
        var strokeJoin: ImageEditorStrokeJoin
        var strokeMiterLimit: CGFloat
        var strokeDashPattern: [CGFloat]
        var strokeDashOffset: CGFloat

        var hasVisibleStroke: Bool {
            strokeOpacity > 0 && strokeWidth > 0
        }
    }

    private static func presentation(
        in lineage: [XMLElement],
        viewportScale: CGFloat
    ) -> SVGPresentation? {
        guard let overallOpacity = multipliedOpacity("opacity", in: lineage),
              let fillOpacity = inheritedOpacity("fill-opacity", in: lineage),
              let strokeOpacity = inheritedOpacity("stroke-opacity", in: lineage),
              let fillPaint = paint(inheritedAttribute("fill", in: lineage) ?? "black"),
              let strokePaint = paint(inheritedAttribute("stroke", in: lineage) ?? "none"),
              let rawStrokeWidth = svgLength(inheritedAttribute("stroke-width", in: lineage) ?? "1"),
              let miterLimit = svgNumber(inheritedAttribute("stroke-miterlimit", in: lineage) ?? "4"),
              let strokeCap = strokeCap(inheritedAttribute("stroke-linecap", in: lineage) ?? "butt"),
              let strokeJoin = strokeJoin(inheritedAttribute("stroke-linejoin", in: lineage) ?? "miter"),
              let rawDashPattern = dashPattern(inheritedAttribute("stroke-dasharray", in: lineage)),
              let rawDashOffset = svgLength(inheritedAttribute("stroke-dashoffset", in: lineage) ?? "0")
        else { return nil }

        let strokeWidth = rawStrokeWidth * viewportScale
        let dashPattern = rawDashPattern.map { $0 * viewportScale }
        let dashOffset = rawDashOffset * viewportScale
        guard strokeWidth >= 0,
              strokeWidth <= ImageEditorShapeContent.maximumStrokeWidth,
              miterLimit >= ImageEditorShapeContent.minimumStrokeMiterLimit,
              miterLimit <= ImageEditorShapeContent.maximumStrokeMiterLimit,
              dashOffset >= ImageEditorShapeContent.minimumStrokeDashOffset,
              dashOffset <= ImageEditorShapeContent.maximumStrokeDashOffset
        else { return nil }

        return SVGPresentation(
            fillPaint: fillPaint,
            fillOpacity: fillPaint.alpha * fillOpacity * overallOpacity,
            strokePaint: strokePaint,
            strokeOpacity: strokePaint.alpha * strokeOpacity * overallOpacity,
            strokeWidth: strokeWidth,
            strokeCap: strokeCap,
            strokeJoin: strokeJoin,
            strokeMiterLimit: miterLimit,
            strokeDashPattern: dashPattern,
            strokeDashOffset: dashOffset
        )
    }

    private static func pathImport(
        _ path: XMLElement,
        lineage: [XMLElement],
        presentation: SVGPresentation,
        viewportScale: CGFloat
    ) -> XomoEditableSVGImport? {
        guard let pathData = path.attribute(forName: "d")?.stringValue,
              let parsed = XomoSVGPathParser.parse(pathData),
              !parsed.subpaths.isEmpty,
              parsed.subpaths.count == parsed.subpathClosedStates.count
        else { return nil }

        let closedStates = Set(parsed.subpathClosedStates)
        guard closedStates.count == 1, let pathsAreClosed = closedStates.first else { return nil }

        if !pathsAreClosed, presentation.fillOpacity > 0 { return nil }
        guard hasCompatibleFillRule(
            inheritedAttribute("fill-rule", in: lineage),
            subpaths: parsed.subpaths,
            effectiveFillOpacity: presentation.fillOpacity
        ) else { return nil }

        let scaledSubpaths = parsed.subpaths.map { subpath in
            subpath.map { scaled($0, by: viewportScale) }
        }
        guard let geometryBounds = bounds(of: scaledSubpaths),
              presentation.hasVisibleStroke
                || (pathsAreClosed && presentation.fillOpacity > 0
                    && geometryBounds.width > 0 && geometryBounds.height > 0)
        else { return nil }

        let padding = presentation.hasVisibleStroke ? presentation.strokeWidth / 2 : 0
        let size = CGSize(
            width: max(1, geometryBounds.width + padding * 2),
            height: max(1, geometryBounds.height + padding * 2)
        )
        let offset = CGSize(
            width: padding - geometryBounds.minX,
            height: padding - geometryBounds.minY
        )
        let localSubpaths = scaledSubpaths.map { subpath in
            subpath.map { translated($0, by: offset) }
        }
        guard let primary = localSubpaths.first else { return nil }

        let content = ImageEditorShapeContent(
            kind: .path,
            fillColor: presentation.fillPaint.color,
            fillOpacity: pathsAreClosed ? presentation.fillOpacity : 0,
            strokeColor: presentation.strokePaint.color,
            strokeWidth: max(ImageEditorShapeContent.minimumStrokeWidth, presentation.strokeWidth),
            strokeOpacity: presentation.hasVisibleStroke ? presentation.strokeOpacity : 0,
            strokePosition: .center,
            strokeCap: presentation.strokeCap,
            strokeJoin: presentation.strokeJoin,
            strokeMiterLimit: presentation.strokeMiterLimit,
            strokeDashPattern: presentation.strokeDashPattern,
            strokeDashOffset: presentation.strokeDashOffset,
            pathPoints: primary.map(\.point),
            pathAnchors: primary,
            pathSubpaths: Array(localSubpaths.dropFirst()),
            isPathClosed: pathsAreClosed
        )
        return XomoEditableSVGImport(content: content, size: size)
    }

    private static func rectangleImport(
        _ rectangle: XMLElement,
        presentation: SVGPresentation,
        viewportScale: CGFloat
    ) -> XomoEditableSVGImport? {
        guard rectangle.attribute(forName: "pathLength") == nil,
              let widthSource = rectangle.attribute(forName: "width")?.stringValue,
              let heightSource = rectangle.attribute(forName: "height")?.stringValue,
              let width = svgLength(widthSource),
              let height = svgLength(heightSource),
              width > 0,
              height > 0,
              svgLength(rectangle.attribute(forName: "x")?.stringValue ?? "0") != nil,
              svgLength(rectangle.attribute(forName: "y")?.stringValue ?? "0") != nil,
              let cornerRadius = rectangleCornerRadius(rectangle, width: width, height: height),
              presentation.fillOpacity > 0 || presentation.hasVisibleStroke
        else { return nil }

        let scaledWidth = width * viewportScale
        let scaledHeight = height * viewportScale
        guard !presentation.hasVisibleStroke
                || presentation.strokeWidth <= min(scaledWidth, scaledHeight)
        else { return nil }
        let padding = presentation.hasVisibleStroke ? presentation.strokeWidth / 2 : 0
        let size = CGSize(
            width: scaledWidth + padding * 2,
            height: scaledHeight + padding * 2
        )
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0
        else { return nil }

        let content = ImageEditorShapeContent(
            kind: .rectangle,
            fillColor: presentation.fillPaint.color,
            fillOpacity: presentation.fillOpacity,
            strokeColor: presentation.strokePaint.color,
            strokeWidth: max(ImageEditorShapeContent.minimumStrokeWidth, presentation.strokeWidth),
            strokeOpacity: presentation.hasVisibleStroke ? presentation.strokeOpacity : 0,
            strokePosition: .center,
            strokeCap: presentation.strokeCap,
            strokeJoin: presentation.strokeJoin,
            strokeMiterLimit: presentation.strokeMiterLimit,
            strokeDashPattern: presentation.strokeDashPattern,
            strokeDashOffset: presentation.strokeDashOffset,
            cornerRadius: cornerRadius * viewportScale
        ).normalized(size: size)
        return XomoEditableSVGImport(content: content, size: size)
    }

    private static func rectangleCornerRadius(
        _ rectangle: XMLElement,
        width: CGFloat,
        height: CGFloat
    ) -> CGFloat? {
        let rawX = rectangle.attribute(forName: "rx")?.stringValue.flatMap { svgLength($0) }
        let rawY = rectangle.attribute(forName: "ry")?.stringValue.flatMap { svgLength($0) }
        if rectangle.attribute(forName: "rx") != nil, rawX == nil { return nil }
        if rectangle.attribute(forName: "ry") != nil, rawY == nil { return nil }
        let radiusX = rawX ?? rawY ?? 0
        let radiusY = rawY ?? rawX ?? 0
        guard radiusX >= 0,
              radiusY >= 0
        else { return nil }
        let clampedX = min(width / 2, radiusX)
        let clampedY = min(height / 2, radiusY)
        guard abs(clampedX - clampedY) <= 0.000_001 else { return nil }
        return clampedX
    }

    private static func ellipseImport(
        _ ellipse: XMLElement,
        presentation: SVGPresentation,
        viewportScale: CGFloat
    ) -> XomoEditableSVGImport? {
        guard ellipse.attribute(forName: "pathLength") == nil,
              svgLength(ellipse.attribute(forName: "cx")?.stringValue ?? "0") != nil,
              svgLength(ellipse.attribute(forName: "cy")?.stringValue ?? "0") != nil,
              let radii = ellipseRadii(ellipse),
              presentation.fillOpacity > 0 || presentation.hasVisibleStroke
        else { return nil }

        let scaledWidth = radii.width * 2 * viewportScale
        let scaledHeight = radii.height * 2 * viewportScale
        guard !presentation.hasVisibleStroke
                || presentation.strokeWidth <= min(scaledWidth, scaledHeight)
        else { return nil }
        let padding = presentation.hasVisibleStroke ? presentation.strokeWidth / 2 : 0
        let size = CGSize(
            width: scaledWidth + padding * 2,
            height: scaledHeight + padding * 2
        )
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0
        else { return nil }

        let content = ImageEditorShapeContent(
            kind: .ellipse,
            fillColor: presentation.fillPaint.color,
            fillOpacity: presentation.fillOpacity,
            strokeColor: presentation.strokePaint.color,
            strokeWidth: max(ImageEditorShapeContent.minimumStrokeWidth, presentation.strokeWidth),
            strokeOpacity: presentation.hasVisibleStroke ? presentation.strokeOpacity : 0,
            strokePosition: .center,
            strokeCap: presentation.strokeCap,
            strokeJoin: presentation.strokeJoin,
            strokeMiterLimit: presentation.strokeMiterLimit,
            strokeDashPattern: presentation.strokeDashPattern,
            strokeDashOffset: presentation.strokeDashOffset
        ).normalized(size: size)
        return XomoEditableSVGImport(content: content, size: size)
    }

    private static func ellipseRadii(_ ellipse: XMLElement) -> CGSize? {
        switch localName(of: ellipse) {
        case "circle":
            guard let source = ellipse.attribute(forName: "r")?.stringValue,
                  let radius = svgLength(source),
                  radius > 0,
                  ellipse.attribute(forName: "rx") == nil,
                  ellipse.attribute(forName: "ry") == nil
            else { return nil }
            return CGSize(width: radius, height: radius)
        case "ellipse":
            guard let xSource = ellipse.attribute(forName: "rx")?.stringValue,
                  let ySource = ellipse.attribute(forName: "ry")?.stringValue,
                  let radiusX = svgLength(xSource),
                  let radiusY = svgLength(ySource),
                  radiusX > 0,
                  radiusY > 0,
                  ellipse.attribute(forName: "r") == nil
            else { return nil }
            return CGSize(width: radiusX, height: radiusY)
        default:
            return nil
        }
    }

    private static func elementLineage(from root: XMLElement, to leaf: XMLElement) -> [XMLElement] {
        var lineage: [XMLElement] = []
        var current: XMLNode? = leaf
        while let node = current as? XMLElement {
            lineage.insert(node, at: 0)
            if node === root { return lineage }
            current = node.parent
        }
        return []
    }

    private static func hasUnsupportedContainer(_ lineage: [XMLElement]) -> Bool {
        let unsupported = Set(["defs", "clippath", "mask", "symbol", "pattern", "marker"])
        return lineage.contains { unsupported.contains(localName(of: $0)) }
    }

    private static func hasUnsupportedPresentation(_ lineage: [XMLElement]) -> Bool {
        let unsupportedAttributes = [
            "style", "class", "transform", "clip-path", "mask", "filter",
            "marker", "marker-start", "marker-mid", "marker-end", "vector-effect",
            "paint-order", "display", "visibility"
        ]
        return lineage.contains { element in
            unsupportedAttributes.contains { element.attribute(forName: $0) != nil }
        }
    }

    private static func inheritedAttribute(_ name: String, in lineage: [XMLElement]) -> String? {
        lineage.reversed().compactMap { $0.attribute(forName: name)?.stringValue }.first
    }

    private static func inheritedOpacity(_ name: String, in lineage: [XMLElement]) -> CGFloat? {
        guard let value = inheritedAttribute(name, in: lineage) else { return 1 }
        return unitInterval(value)
    }

    private static func multipliedOpacity(_ name: String, in lineage: [XMLElement]) -> CGFloat? {
        var result: CGFloat = 1
        for element in lineage {
            guard let raw = element.attribute(forName: name)?.stringValue else { continue }
            guard let value = unitInterval(raw) else { return nil }
            result *= value
        }
        return result
    }

    private static func unitInterval(_ source: String) -> CGFloat? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("%"),
           let value = Double(trimmed.dropLast()),
           value.isFinite,
           (0...100).contains(value) {
            return CGFloat(value / 100)
        }
        guard let value = Double(trimmed), value.isFinite, (0...1).contains(value) else { return nil }
        return CGFloat(value)
    }

    private static func svgNumber(_ source: String) -> CGFloat? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value.isFinite else { return nil }
        return CGFloat(value)
    }

    private static func svgLength(_ source: String) -> CGFloat? {
        var trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasSuffix("px") {
            trimmed.removeLast(2)
        }
        return svgNumber(trimmed)
    }

    private static func viewportScale(_ root: XMLElement) -> CGFloat? {
        guard let viewBoxSource = root.attribute(forName: "viewBox")?.stringValue else { return 1 }
        let viewBox = viewBoxSource
            .split { $0 == "," || $0.isWhitespace }
            .compactMap { svgNumber(String($0)) }
        guard viewBox.count == 4, viewBox[2] > 0, viewBox[3] > 0 else { return nil }

        let widthSource = root.attribute(forName: "width")?.stringValue
        let heightSource = root.attribute(forName: "height")?.stringValue
        guard widthSource != nil || heightSource != nil else { return 1 }
        guard let widthSource,
              let heightSource,
              let width = svgLength(widthSource),
              let height = svgLength(heightSource),
              width > 0,
              height > 0
        else { return nil }
        if let preserve = root.attribute(forName: "preserveAspectRatio")?.stringValue {
            let normalized = preserve
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
                .lowercased()
            guard normalized == "xmidymid meet" else { return nil }
        }
        let scaleX = width / viewBox[2]
        let scaleY = height / viewBox[3]
        guard abs(scaleX - scaleY) <= 0.000_001, scaleX.isFinite, scaleX > 0 else { return nil }
        return scaleX
    }

    private static func strokeCap(_ source: String) -> ImageEditorStrokeCap? {
        ImageEditorStrokeCap(rawValue: source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func strokeJoin(_ source: String) -> ImageEditorStrokeJoin? {
        ImageEditorStrokeJoin(rawValue: source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func dashPattern(_ source: String?) -> [CGFloat]? {
        guard let source else { return [] }
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "none" { return [] }
        var values = trimmed
            .split { $0 == "," || $0.isWhitespace }
            .compactMap { svgLength(String($0)) }
        guard !values.isEmpty,
              values.allSatisfy({ $0.isFinite && $0 > 0 })
        else { return nil }
        if values.count.isMultiple(of: 2) == false {
            values += values
        }
        guard values.count <= 16 else { return nil }
        return values
    }

    private static func hasCompatibleFillRule(
        _ source: String?,
        subpaths: [[ImageEditorPathAnchor]],
        effectiveFillOpacity: CGFloat
    ) -> Bool {
        guard effectiveFillOpacity > 0 else { return true }
        let normalized = (source ?? "nonzero")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
        if normalized == "evenodd" { return true }
        guard normalized == "nonzero", subpaths.count == 1, let anchors = subpaths.first else {
            return false
        }
        return isSimpleLinearPolygon(anchors)
    }

    private static func isSimpleLinearPolygon(_ anchors: [ImageEditorPathAnchor]) -> Bool {
        var points = anchors.map(\.point)
        guard points.count >= 3,
              anchors.allSatisfy({ $0.inControl == nil && $0.outControl == nil })
        else { return false }
        if points.first == points.last { points.removeLast() }
        let hasDuplicatePoint = points.indices.contains { index in
            points.indices.contains { otherIndex in
                otherIndex > index && points[index] == points[otherIndex]
            }
        }
        guard points.count >= 3, !hasDuplicatePoint else {
            return false
        }
        for firstIndex in points.indices {
            let firstNext = (firstIndex + 1) % points.count
            for secondIndex in points.indices where secondIndex > firstIndex {
                let secondNext = (secondIndex + 1) % points.count
                if firstIndex == secondNext || firstNext == secondIndex { continue }
                if segmentsIntersect(
                    points[firstIndex],
                    points[firstNext],
                    points[secondIndex],
                    points[secondNext]
                ) {
                    return false
                }
            }
        }
        return true
    }

    private static func segmentsIntersect(
        _ firstStart: CGPoint,
        _ firstEnd: CGPoint,
        _ secondStart: CGPoint,
        _ secondEnd: CGPoint
    ) -> Bool {
        func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
            (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        }
        let firstA = cross(firstStart, firstEnd, secondStart)
        let firstB = cross(firstStart, firstEnd, secondEnd)
        let secondA = cross(secondStart, secondEnd, firstStart)
        let secondB = cross(secondStart, secondEnd, firstEnd)
        let epsilon: CGFloat = 0.000_001
        if abs(firstA) <= epsilon || abs(firstB) <= epsilon || abs(secondA) <= epsilon || abs(secondB) <= epsilon {
            return true
        }
        return (firstA > 0) != (firstB > 0) && (secondA > 0) != (secondB > 0)
    }

    private struct SVGPaint {
        var color: NSColor
        var alpha: CGFloat
    }

    private static func paint(_ source: String) -> SVGPaint? {
        let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "none" || normalized == "transparent" {
            return SVGPaint(color: .clear, alpha: 0)
        }
        if normalized.hasPrefix("#") {
            return hexadecimalPaint(String(normalized.dropFirst()))
        }
        if normalized.hasPrefix("rgb(") || normalized.hasPrefix("rgba(") {
            return functionalPaint(normalized)
        }
        let named: [String: (CGFloat, CGFloat, CGFloat)] = [
            "black": (0, 0, 0), "white": (1, 1, 1), "red": (1, 0, 0),
            "green": (0, 0.5, 0), "blue": (0, 0, 1), "gray": (0.5, 0.5, 0.5),
            "grey": (0.5, 0.5, 0.5), "yellow": (1, 1, 0), "cyan": (0, 1, 1),
            "magenta": (1, 0, 1)
        ]
        guard let components = named[normalized] else { return nil }
        return SVGPaint(
            color: NSColor(deviceRed: components.0, green: components.1, blue: components.2, alpha: 1),
            alpha: 1
        )
    }

    private static func hexadecimalPaint(_ source: String) -> SVGPaint? {
        let expanded: String
        switch source.count {
        case 3, 4:
            expanded = source.map { "\($0)\($0)" }.joined()
        case 6, 8:
            expanded = source
        default:
            return nil
        }
        guard let value = UInt64(expanded, radix: 16) else { return nil }
        let hasAlpha = expanded.count == 8
        let red = CGFloat((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = CGFloat((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = CGFloat((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? CGFloat(value & 0xFF) / 255 : 1
        return SVGPaint(
            color: NSColor(deviceRed: red, green: green, blue: blue, alpha: 1),
            alpha: alpha
        )
    }

    private static func functionalPaint(_ source: String) -> SVGPaint? {
        guard let open = source.firstIndex(of: "("), source.last == ")" else { return nil }
        let values = source[source.index(after: open)..<source.index(before: source.endIndex)]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let expectsAlpha = source.hasPrefix("rgba(")
        guard values.count == (expectsAlpha ? 4 : 3) else { return nil }
        var rgb: [CGFloat] = []
        for component in values.prefix(3) {
            if component.hasSuffix("%"),
               let value = Double(component.dropLast()),
               value.isFinite,
               (0...100).contains(value) {
                rgb.append(CGFloat(value / 100))
            } else if let value = Double(component), value.isFinite, (0...255).contains(value) {
                rgb.append(CGFloat(value / 255))
            } else {
                return nil
            }
        }
        let alpha = expectsAlpha ? unitInterval(values[3]) : 1
        guard let alpha else { return nil }
        return SVGPaint(
            color: NSColor(deviceRed: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1),
            alpha: alpha
        )
    }

    private static func bounds(of subpaths: [[ImageEditorPathAnchor]]) -> CGRect? {
        let points = subpaths.flatMap { subpath in
            subpath.flatMap { anchor in
                [anchor.point, anchor.inControl, anchor.outControl].compactMap { $0 }
            }
        }
        guard let first = points.first, points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            return nil
        }
        let minX = points.dropFirst().reduce(first.x) { min($0, $1.x) }
        let maxX = points.dropFirst().reduce(first.x) { max($0, $1.x) }
        let minY = points.dropFirst().reduce(first.y) { min($0, $1.y) }
        let maxY = points.dropFirst().reduce(first.y) { max($0, $1.y) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func translated(_ anchor: ImageEditorPathAnchor, by offset: CGSize) -> ImageEditorPathAnchor {
        func point(_ source: CGPoint) -> CGPoint {
            CGPoint(x: source.x + offset.width, y: source.y + offset.height)
        }
        return ImageEditorPathAnchor(
            point: point(anchor.point),
            inControl: anchor.inControl.map(point),
            outControl: anchor.outControl.map(point)
        )
    }

    private static func scaled(_ anchor: ImageEditorPathAnchor, by scale: CGFloat) -> ImageEditorPathAnchor {
        func point(_ source: CGPoint) -> CGPoint {
            CGPoint(x: source.x * scale, y: source.y * scale)
        }
        return ImageEditorPathAnchor(
            point: point(anchor.point),
            inControl: anchor.inControl.map(point),
            outControl: anchor.outControl.map(point)
        )
    }

    private static func localName(of element: XMLElement) -> String {
        (element.localName ?? element.name ?? "").lowercased()
    }
}
