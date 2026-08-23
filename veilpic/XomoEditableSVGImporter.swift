import AppKit
import Foundation

struct XomoEditableSVGImport {
    var content: ImageEditorShapeContent
    var size: CGSize
}

/// Imports one safely representable SVG geometry node as a native editable shape.
enum XomoEditableSVGImporter {
    static let maximumByteCount = 2 * 1_024 * 1_024
    static let namedColorHexValues: [String: UInt32] = [
        "aliceblue": 0xF0F8FF,
        "antiquewhite": 0xFAEBD7,
        "aqua": 0x00FFFF,
        "aquamarine": 0x7FFFD4,
        "azure": 0xF0FFFF,
        "beige": 0xF5F5DC,
        "bisque": 0xFFE4C4,
        "black": 0x000000,
        "blanchedalmond": 0xFFEBCD,
        "blue": 0x0000FF,
        "blueviolet": 0x8A2BE2,
        "brown": 0xA52A2A,
        "burlywood": 0xDEB887,
        "cadetblue": 0x5F9EA0,
        "chartreuse": 0x7FFF00,
        "chocolate": 0xD2691E,
        "coral": 0xFF7F50,
        "cornflowerblue": 0x6495ED,
        "cornsilk": 0xFFF8DC,
        "crimson": 0xDC143C,
        "cyan": 0x00FFFF,
        "darkblue": 0x00008B,
        "darkcyan": 0x008B8B,
        "darkgoldenrod": 0xB8860B,
        "darkgray": 0xA9A9A9,
        "darkgreen": 0x006400,
        "darkgrey": 0xA9A9A9,
        "darkkhaki": 0xBDB76B,
        "darkmagenta": 0x8B008B,
        "darkolivegreen": 0x556B2F,
        "darkorange": 0xFF8C00,
        "darkorchid": 0x9932CC,
        "darkred": 0x8B0000,
        "darksalmon": 0xE9967A,
        "darkseagreen": 0x8FBC8F,
        "darkslateblue": 0x483D8B,
        "darkslategray": 0x2F4F4F,
        "darkslategrey": 0x2F4F4F,
        "darkturquoise": 0x00CED1,
        "darkviolet": 0x9400D3,
        "deeppink": 0xFF1493,
        "deepskyblue": 0x00BFFF,
        "dimgray": 0x696969,
        "dimgrey": 0x696969,
        "dodgerblue": 0x1E90FF,
        "firebrick": 0xB22222,
        "floralwhite": 0xFFFAF0,
        "forestgreen": 0x228B22,
        "fuchsia": 0xFF00FF,
        "gainsboro": 0xDCDCDC,
        "ghostwhite": 0xF8F8FF,
        "gold": 0xFFD700,
        "goldenrod": 0xDAA520,
        "gray": 0x808080,
        "green": 0x008000,
        "greenyellow": 0xADFF2F,
        "grey": 0x808080,
        "honeydew": 0xF0FFF0,
        "hotpink": 0xFF69B4,
        "indianred": 0xCD5C5C,
        "indigo": 0x4B0082,
        "ivory": 0xFFFFF0,
        "khaki": 0xF0E68C,
        "lavender": 0xE6E6FA,
        "lavenderblush": 0xFFF0F5,
        "lawngreen": 0x7CFC00,
        "lemonchiffon": 0xFFFACD,
        "lightblue": 0xADD8E6,
        "lightcoral": 0xF08080,
        "lightcyan": 0xE0FFFF,
        "lightgoldenrodyellow": 0xFAFAD2,
        "lightgray": 0xD3D3D3,
        "lightgreen": 0x90EE90,
        "lightgrey": 0xD3D3D3,
        "lightpink": 0xFFB6C1,
        "lightsalmon": 0xFFA07A,
        "lightseagreen": 0x20B2AA,
        "lightskyblue": 0x87CEFA,
        "lightslategray": 0x778899,
        "lightslategrey": 0x778899,
        "lightsteelblue": 0xB0C4DE,
        "lightyellow": 0xFFFFE0,
        "lime": 0x00FF00,
        "limegreen": 0x32CD32,
        "linen": 0xFAF0E6,
        "magenta": 0xFF00FF,
        "maroon": 0x800000,
        "mediumaquamarine": 0x66CDAA,
        "mediumblue": 0x0000CD,
        "mediumorchid": 0xBA55D3,
        "mediumpurple": 0x9370DB,
        "mediumseagreen": 0x3CB371,
        "mediumslateblue": 0x7B68EE,
        "mediumspringgreen": 0x00FA9A,
        "mediumturquoise": 0x48D1CC,
        "mediumvioletred": 0xC71585,
        "midnightblue": 0x191970,
        "mintcream": 0xF5FFFA,
        "mistyrose": 0xFFE4E1,
        "moccasin": 0xFFE4B5,
        "navajowhite": 0xFFDEAD,
        "navy": 0x000080,
        "oldlace": 0xFDF5E6,
        "olive": 0x808000,
        "olivedrab": 0x6B8E23,
        "orange": 0xFFA500,
        "orangered": 0xFF4500,
        "orchid": 0xDA70D6,
        "palegoldenrod": 0xEEE8AA,
        "palegreen": 0x98FB98,
        "paleturquoise": 0xAFEEEE,
        "palevioletred": 0xDB7093,
        "papayawhip": 0xFFEFD5,
        "peachpuff": 0xFFDAB9,
        "peru": 0xCD853F,
        "pink": 0xFFC0CB,
        "plum": 0xDDA0DD,
        "powderblue": 0xB0E0E6,
        "purple": 0x800080,
        "rebeccapurple": 0x663399,
        "red": 0xFF0000,
        "rosybrown": 0xBC8F8F,
        "royalblue": 0x4169E1,
        "saddlebrown": 0x8B4513,
        "salmon": 0xFA8072,
        "sandybrown": 0xF4A460,
        "seagreen": 0x2E8B57,
        "seashell": 0xFFF5EE,
        "sienna": 0xA0522D,
        "silver": 0xC0C0C0,
        "skyblue": 0x87CEEB,
        "slateblue": 0x6A5ACD,
        "slategray": 0x708090,
        "slategrey": 0x708090,
        "snow": 0xFFFAFA,
        "springgreen": 0x00FF7F,
        "steelblue": 0x4682B4,
        "tan": 0xD2B48C,
        "teal": 0x008080,
        "thistle": 0xD8BFD8,
        "tomato": 0xFF6347,
        "turquoise": 0x40E0D0,
        "violet": 0xEE82EE,
        "wheat": 0xF5DEB3,
        "white": 0xFFFFFF,
        "whitesmoke": 0xF5F5F5,
        "yellow": 0xFFFF00,
        "yellowgreen": 0x9ACD32
    ]
    private static let supportedInlineStyleProperties = Set([
        "color", "opacity", "fill", "fill-opacity", "fill-rule",
        "stroke", "stroke-opacity", "stroke-width", "stroke-linecap",
        "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray",
        "stroke-dashoffset"
    ])
    private static let supportedStyleElementNames = Set([
        "svg", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon"
    ])

    private struct SVGStyleCompoundSelector {
        var elementName: String?
        var idName: String?
        var classNames: [String]

        var specificity: Int {
            (elementName == nil ? 0 : 1)
                + (classNames.count * 10)
                + (idName == nil ? 0 : 100)
        }

        func matches(_ element: XMLElement) -> Bool {
            if let elementName,
               XomoEditableSVGImporter.localName(of: element) != elementName {
                return false
            }
            if let idName,
               element.attribute(forName: "id")?.stringValue != idName {
                return false
            }
            let elementClasses = Set(XomoEditableSVGImporter.classNames(on: element))
            return classNames.allSatisfy(elementClasses.contains)
        }
    }

    private enum SVGStyleCombinator {
        case descendant
        case child
    }

    private struct SVGStyleSelector {
        var compounds: [SVGStyleCompoundSelector]
        var combinators: [SVGStyleCombinator]

        var specificity: Int {
            compounds.reduce(0) { $0 + $1.specificity }
        }

        var classNames: [String] {
            compounds.flatMap(\.classNames)
        }

        func matches(_ element: XMLElement) -> Bool {
            guard !compounds.isEmpty else { return false }
            return matches(compoundAt: compounds.count - 1, element: element)
        }

        private func matches(compoundAt index: Int, element: XMLElement) -> Bool {
            guard compounds[index].matches(element) else { return false }
            guard index > 0 else { return true }
            switch combinators[index - 1] {
            case .child:
                guard let parent = element.parent as? XMLElement else { return false }
                return matches(compoundAt: index - 1, element: parent)
            case .descendant:
                var ancestor = element.parent as? XMLElement
                while let candidate = ancestor {
                    if matches(compoundAt: index - 1, element: candidate) {
                        return true
                    }
                    ancestor = candidate.parent as? XMLElement
                }
                return false
            }
        }
    }

    private struct SVGStyleRule {
        var selector: SVGStyleSelector
        var declarations: [String: String]
        var sourceOrder: Int
    }

    static func parse(_ data: Data) -> XomoEditableSVGImport? {
        guard !data.isEmpty,
              data.count <= maximumByteCount,
              let source = String(data: data, encoding: .utf8),
              !source.localizedCaseInsensitiveContains("<!DOCTYPE"),
              !source.localizedCaseInsensitiveContains("<!ENTITY"),
              !source.localizedCaseInsensitiveContains("<?xml-stylesheet"),
              let document = try? XMLDocument(data: data, options: []),
              let root = document.rootElement(),
              localName(of: root) == "svg",
              let cssRules = stylesheetRules(in: root),
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
              !hasUnsupportedPresentation(lineage, cssRules: cssRules),
              let presentation = presentation(
                  in: lineage,
                  viewportScale: viewportScale,
                  cssRules: cssRules
              )
        else { return nil }

        switch localName(of: geometry) {
        case "path":
            return pathImport(
                geometry,
                lineage: lineage,
                presentation: presentation,
                viewportScale: viewportScale,
                cssRules: cssRules
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
        case "line":
            return lineImport(
                geometry,
                presentation: presentation,
                viewportScale: viewportScale
            )
        case "polyline":
            return polylineImport(
                geometry,
                presentation: presentation,
                viewportScale: viewportScale
            )
        case "polygon":
            return polygonImport(
                geometry,
                lineage: lineage,
                presentation: presentation,
                viewportScale: viewportScale,
                cssRules: cssRules
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
        viewportScale: CGFloat,
        cssRules: [SVGStyleRule]
    ) -> SVGPresentation? {
        guard let overallOpacity = multipliedOpacity("opacity", in: lineage, cssRules: cssRules),
              let fillOpacity = inheritedOpacity("fill-opacity", in: lineage, cssRules: cssRules),
              let strokeOpacity = inheritedOpacity("stroke-opacity", in: lineage, cssRules: cssRules),
              let fillPaint = presentationPaint(
                  inheritedAttribute("fill", in: lineage, cssRules: cssRules) ?? "black",
                  lineage: lineage,
                  cssRules: cssRules
              ),
              let strokePaint = presentationPaint(
                  inheritedAttribute("stroke", in: lineage, cssRules: cssRules) ?? "none",
                  lineage: lineage,
                  cssRules: cssRules
              ),
              let rawStrokeWidth = svgLength(
                  inheritedAttribute("stroke-width", in: lineage, cssRules: cssRules) ?? "1"
              ),
              let miterLimit = svgNumber(
                  inheritedAttribute("stroke-miterlimit", in: lineage, cssRules: cssRules) ?? "4"
              ),
              let strokeCap = strokeCap(
                  inheritedAttribute("stroke-linecap", in: lineage, cssRules: cssRules) ?? "butt"
              ),
              let strokeJoin = strokeJoin(
                  inheritedAttribute("stroke-linejoin", in: lineage, cssRules: cssRules) ?? "miter"
              ),
              let rawDashPattern = dashPattern(
                  inheritedAttribute("stroke-dasharray", in: lineage, cssRules: cssRules)
              ),
              let rawDashOffset = svgLength(
                  inheritedAttribute("stroke-dashoffset", in: lineage, cssRules: cssRules) ?? "0"
              )
        else { return nil }

        let strokeWidth = rawStrokeWidth * viewportScale
        let dashPattern = rawDashPattern.map { $0 * viewportScale }
        let dashOffset = rawDashOffset * viewportScale
        let effectiveStrokeOpacity = strokePaint.alpha * strokeOpacity * overallOpacity
        guard strokeWidth >= 0,
              strokeWidth <= ImageEditorShapeContent.maximumStrokeWidth,
              effectiveStrokeOpacity == 0
                || strokeWidth >= ImageEditorShapeContent.minimumStrokeWidth,
              miterLimit >= ImageEditorShapeContent.minimumStrokeMiterLimit,
              miterLimit <= ImageEditorShapeContent.maximumStrokeMiterLimit,
              dashOffset >= ImageEditorShapeContent.minimumStrokeDashOffset,
              dashOffset <= ImageEditorShapeContent.maximumStrokeDashOffset
        else { return nil }

        return SVGPresentation(
            fillPaint: fillPaint,
            fillOpacity: fillPaint.alpha * fillOpacity * overallOpacity,
            strokePaint: strokePaint,
            strokeOpacity: effectiveStrokeOpacity,
            strokeWidth: strokeWidth,
            strokeCap: strokeCap,
            strokeJoin: strokeJoin,
            strokeMiterLimit: miterLimit,
            strokeDashPattern: dashPattern,
            strokeDashOffset: dashOffset
        )
    }

    private static func presentationPaint(
        _ source: String,
        lineage: [XMLElement],
        cssRules: [SVGStyleRule]
    ) -> SVGPaint? {
        let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized == "currentcolor" else { return paint(source) }
        for element in lineage.reversed() {
            guard let colorSource = specifiedPresentationValue(
                "color",
                on: element,
                cssRules: cssRules
            ) else { continue }
            let normalizedColor = colorSource
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if normalizedColor == "currentcolor" || normalizedColor == "inherit" { continue }
            if normalizedColor == "none" { return nil }
            return paint(colorSource)
        }
        return paint("black")
    }

    private static func pathImport(
        _ path: XMLElement,
        lineage: [XMLElement],
        presentation: SVGPresentation,
        viewportScale: CGFloat,
        cssRules: [SVGStyleRule]
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
            inheritedAttribute("fill-rule", in: lineage, cssRules: cssRules),
            subpaths: parsed.subpaths,
            effectiveFillOpacity: presentation.fillOpacity
        ) else { return nil }

        let scaledSubpaths = parsed.subpaths.map { subpath in
            subpath.map { scaled($0, by: viewportScale) }
        }
        guard let importBounds = pathImportBounds(
            scaledSubpaths,
            isClosed: pathsAreClosed,
            presentation: presentation
        )
        else { return nil }

        let size = CGSize(
            width: max(1, importBounds.width),
            height: max(1, importBounds.height)
        )
        let offset = CGSize(
            width: (size.width - importBounds.width) / 2 - importBounds.minX,
            height: (size.height - importBounds.height) / 2 - importBounds.minY
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

    private static func pathImportBounds(
        _ subpaths: [[ImageEditorPathAnchor]],
        isClosed: Bool,
        presentation: SVGPresentation
    ) -> CGRect? {
        var visualBounds: CGRect?
        if isClosed, presentation.fillOpacity > 0 {
            for anchors in subpaths {
                let fillBounds = cgPath(anchors, isClosed: true).boundingBoxOfPath
                guard let finiteFillBounds = finiteNonemptyBounds(fillBounds) else { continue }
                visualBounds = combinedBounds(visualBounds, finiteFillBounds)
            }
        }
        if presentation.hasVisibleStroke {
            for anchors in subpaths {
                guard let strokeBounds = strokedPathBounds(
                    anchors,
                    strokeWidth: presentation.strokeWidth,
                    strokeCap: presentation.strokeCap,
                    strokeJoin: presentation.strokeJoin,
                    strokeMiterLimit: presentation.strokeMiterLimit,
                    isClosed: isClosed
                ) else { continue }
                visualBounds = combinedBounds(visualBounds, strokeBounds)
            }
        }
        guard let visualBounds,
              let editableGeometryBounds = bounds(of: subpaths)
        else { return nil }
        return combinedBounds(visualBounds, editableGeometryBounds)
    }

    private static func finiteNonemptyBounds(_ bounds: CGRect) -> CGRect? {
        guard !bounds.isNull,
              !bounds.isInfinite,
              !bounds.isEmpty,
              bounds.minX.isFinite,
              bounds.minY.isFinite,
              bounds.width.isFinite,
              bounds.height.isFinite
        else { return nil }
        return bounds
    }

    private static func combinedBounds(_ first: CGRect?, _ second: CGRect) -> CGRect {
        guard let first else { return second }
        return CGRect(
            x: min(first.minX, second.minX),
            y: min(first.minY, second.minY),
            width: max(first.maxX, second.maxX) - min(first.minX, second.minX),
            height: max(first.maxY, second.maxY) - min(first.minY, second.minY)
        )
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

    private static func lineImport(
        _ line: XMLElement,
        presentation: SVGPresentation,
        viewportScale: CGFloat
    ) -> XomoEditableSVGImport? {
        guard line.attribute(forName: "pathLength") == nil,
              let x1 = svgLength(line.attribute(forName: "x1")?.stringValue ?? "0"),
              let y1 = svgLength(line.attribute(forName: "y1")?.stringValue ?? "0"),
              let x2 = svgLength(line.attribute(forName: "x2")?.stringValue ?? "0"),
              let y2 = svgLength(line.attribute(forName: "y2")?.stringValue ?? "0"),
              presentation.hasVisibleStroke
        else { return nil }

        let start = CGPoint(x: x1 * viewportScale, y: y1 * viewportScale)
        let end = CGPoint(x: x2 * viewportScale, y: y2 * viewportScale)
        if start == end, presentation.strokeCap == .butt { return nil }
        return openPathImport(
            [ImageEditorPathAnchor(point: start), ImageEditorPathAnchor(point: end)],
            presentation: presentation
        )
    }

    private static func polylineImport(
        _ polyline: XMLElement,
        presentation: SVGPresentation,
        viewportScale: CGFloat
    ) -> XomoEditableSVGImport? {
        guard polyline.attribute(forName: "pathLength") == nil,
              let source = polyline.attribute(forName: "points")?.stringValue,
              let points = svgPoints(source),
              presentation.fillOpacity == 0 || !pointsCanEncloseArea(points),
              presentation.hasVisibleStroke
        else { return nil }

        let anchors = points.map { point in
            ImageEditorPathAnchor(
                point: CGPoint(
                    x: point.x * viewportScale,
                    y: point.y * viewportScale
                )
            )
        }
        return openPathImport(anchors, presentation: presentation)
    }

    private static func pointsCanEncloseArea(_ points: [CGPoint]) -> Bool {
        guard points.count >= 3,
              let first = points.first,
              let second = points.dropFirst().first(where: { $0 != first })
        else { return false }
        return points.contains { point in
            (second.x - first.x) * (point.y - first.y)
                != (second.y - first.y) * (point.x - first.x)
        }
    }

    private static func polygonImport(
        _ polygon: XMLElement,
        lineage: [XMLElement],
        presentation: SVGPresentation,
        viewportScale: CGFloat,
        cssRules: [SVGStyleRule]
    ) -> XomoEditableSVGImport? {
        guard polygon.attribute(forName: "pathLength") == nil,
              let source = polygon.attribute(forName: "points")?.stringValue,
              let points = svgPoints(source),
              points.count >= 3,
              presentation.hasVisibleStroke
                || (presentation.fillOpacity > 0 && pointsCanEncloseArea(points))
        else { return nil }

        let anchors = points.map { point in
            ImageEditorPathAnchor(
                point: CGPoint(
                    x: point.x * viewportScale,
                    y: point.y * viewportScale
                )
            )
        }
        guard hasCompatibleFillRule(
            inheritedAttribute("fill-rule", in: lineage, cssRules: cssRules),
            subpaths: [anchors],
            effectiveFillOpacity: presentation.fillOpacity
        ) else { return nil }
        return closedPathImport(anchors, presentation: presentation)
    }

    private static func openPathImport(
        _ anchors: [ImageEditorPathAnchor],
        presentation: SVGPresentation
    ) -> XomoEditableSVGImport? {
        guard anchors.count >= 2,
              let visualBounds = strokedPathBounds(
                anchors,
                strokeWidth: presentation.strokeWidth,
                strokeCap: presentation.strokeCap,
                strokeJoin: presentation.strokeJoin,
                strokeMiterLimit: presentation.strokeMiterLimit,
                isClosed: false
              )
        else { return nil }
        let size = CGSize(
            width: max(1, visualBounds.width),
            height: max(1, visualBounds.height)
        )
        let offset = CGSize(
            width: (size.width - visualBounds.width) / 2 - visualBounds.minX,
            height: (size.height - visualBounds.height) / 2 - visualBounds.minY
        )
        let localAnchors = anchors.map { translated($0, by: offset) }
        let content = ImageEditorShapeContent(
            kind: .path,
            fillColor: presentation.fillPaint.color,
            fillOpacity: 0,
            strokeColor: presentation.strokePaint.color,
            strokeWidth: presentation.strokeWidth,
            strokeOpacity: presentation.strokeOpacity,
            strokePosition: .center,
            strokeCap: presentation.strokeCap,
            strokeJoin: presentation.strokeJoin,
            strokeMiterLimit: presentation.strokeMiterLimit,
            strokeDashPattern: presentation.strokeDashPattern,
            strokeDashOffset: presentation.strokeDashOffset,
            pathPoints: localAnchors.map(\.point),
            pathAnchors: localAnchors,
            isPathClosed: false
        )
        return XomoEditableSVGImport(content: content, size: size)
    }

    private static func closedPathImport(
        _ anchors: [ImageEditorPathAnchor],
        presentation: SVGPresentation
    ) -> XomoEditableSVGImport? {
        guard anchors.count >= 3,
              let visualBounds = closedPathVisualBounds(anchors, presentation: presentation)
        else { return nil }
        let size = CGSize(
            width: max(1, visualBounds.width),
            height: max(1, visualBounds.height)
        )
        let offset = CGSize(
            width: (size.width - visualBounds.width) / 2 - visualBounds.minX,
            height: (size.height - visualBounds.height) / 2 - visualBounds.minY
        )
        let localAnchors = anchors.map { translated($0, by: offset) }
        let content = ImageEditorShapeContent(
            kind: .path,
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
            pathPoints: localAnchors.map(\.point),
            pathAnchors: localAnchors,
            isPathClosed: true
        )
        return XomoEditableSVGImport(content: content, size: size)
    }

    private static func closedPathVisualBounds(
        _ anchors: [ImageEditorPathAnchor],
        presentation: SVGPresentation
    ) -> CGRect? {
        let path = cgPath(anchors, isClosed: true)
        var bounds: CGRect?
        if presentation.fillOpacity > 0, !path.boundingBoxOfPath.isEmpty {
            bounds = path.boundingBoxOfPath
        }
        if presentation.hasVisibleStroke,
           let strokeBounds = strokedPathBounds(
               anchors,
               strokeWidth: presentation.strokeWidth,
               strokeCap: presentation.strokeCap,
               strokeJoin: presentation.strokeJoin,
               strokeMiterLimit: presentation.strokeMiterLimit,
               isClosed: true
           ) {
            bounds = bounds?.union(strokeBounds) ?? strokeBounds
        }
        return bounds
    }

    private static func strokedPathBounds(
        _ anchors: [ImageEditorPathAnchor],
        strokeWidth: CGFloat,
        strokeCap: ImageEditorStrokeCap,
        strokeJoin: ImageEditorStrokeJoin,
        strokeMiterLimit: CGFloat,
        isClosed: Bool
    ) -> CGRect? {
        guard let first = anchors.first,
              strokeWidth > 0,
              strokeWidth.isFinite
        else { return nil }

        let path = cgPath(anchors, isClosed: isClosed)
        let stroked = path.copy(
            strokingWithWidth: strokeWidth,
            lineCap: cgLineCap(strokeCap),
            lineJoin: cgLineJoin(strokeJoin),
            miterLimit: strokeMiterLimit
        )
        let bounds = stroked.boundingBoxOfPath
        if bounds.isNull || bounds.isInfinite || bounds.isEmpty {
            guard !isClosed,
                  strokeCap != .butt,
                  anchors.allSatisfy({ $0.point == first.point })
            else { return nil }
            let radius = strokeWidth / 2
            return CGRect(
                x: first.point.x - radius,
                y: first.point.y - radius,
                width: strokeWidth,
                height: strokeWidth
            )
        }
        guard bounds.minX.isFinite,
              bounds.minY.isFinite,
              bounds.width.isFinite,
              bounds.height.isFinite
        else { return nil }
        return bounds
    }

    private static func cgPath(
        _ anchors: [ImageEditorPathAnchor],
        isClosed: Bool
    ) -> CGPath {
        let path = CGMutablePath()
        guard let first = anchors.first else { return path }
        path.move(to: first.point)
        for index in anchors.indices.dropFirst() {
            let previous = anchors[index - 1]
            let current = anchors[index]
            if previous.outControl != nil || current.inControl != nil {
                path.addCurve(
                    to: current.point,
                    control1: previous.outControl ?? previous.point,
                    control2: current.inControl ?? current.point
                )
            } else {
                path.addLine(to: current.point)
            }
        }
        if isClosed {
            if anchors.count > 2,
               let last = anchors.last,
               last.outControl != nil || first.inControl != nil {
                path.addCurve(
                    to: first.point,
                    control1: last.outControl ?? last.point,
                    control2: first.inControl ?? first.point
                )
            }
            path.closeSubpath()
        }
        return path
    }

    private static func cgLineCap(_ cap: ImageEditorStrokeCap) -> CGLineCap {
        switch cap {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }

    private static func cgLineJoin(_ join: ImageEditorStrokeJoin) -> CGLineJoin {
        switch join {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        }
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

    private static func hasUnsupportedPresentation(
        _ lineage: [XMLElement],
        cssRules: [SVGStyleRule]
    ) -> Bool {
        let unsupportedAttributes = [
            "transform", "clip-path", "mask", "filter",
            "marker", "marker-start", "marker-mid", "marker-end", "vector-effect",
            "paint-order", "display", "visibility"
        ]
        let knownClassNames = Set(cssRules.flatMap(\.selector.classNames))
        return lineage.contains { element in
            unsupportedAttributes.contains { element.attribute(forName: $0) != nil }
                || inlineStyleDeclarations(on: element) == nil
                || classNames(on: element).contains { !knownClassNames.contains($0) }
        }
    }

    private static func inheritedAttribute(
        _ name: String,
        in lineage: [XMLElement],
        cssRules: [SVGStyleRule]
    ) -> String? {
        for element in lineage.reversed() {
            guard let value = specifiedPresentationValue(
                name,
                on: element,
                cssRules: cssRules
            ) else { continue }
            if value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "inherit" {
                continue
            }
            return value
        }
        return nil
    }

    private static func inheritedOpacity(
        _ name: String,
        in lineage: [XMLElement],
        cssRules: [SVGStyleRule]
    ) -> CGFloat? {
        guard let value = inheritedAttribute(name, in: lineage, cssRules: cssRules) else { return 1 }
        return unitInterval(value)
    }

    private static func multipliedOpacity(
        _ name: String,
        in lineage: [XMLElement],
        cssRules: [SVGStyleRule]
    ) -> CGFloat? {
        var result: CGFloat = 1
        for element in lineage {
            guard let raw = specifiedPresentationValue(
                name,
                on: element,
                cssRules: cssRules
            ) else { continue }
            guard let value = unitInterval(raw) else { return nil }
            result *= value
        }
        return result
    }

    private static func specifiedPresentationValue(
        _ name: String,
        on element: XMLElement,
        cssRules: [SVGStyleRule]
    ) -> String? {
        if element.attribute(forName: "style") != nil,
           let declarations = inlineStyleDeclarations(on: element),
           let value = declarations[name] {
            return value
        }
        var stylesheetValue: (specificity: Int, sourceOrder: Int, value: String)?
        for rule in cssRules where rule.selector.matches(element) {
            guard let value = rule.declarations[name] else { continue }
            let candidate = (
                specificity: rule.selector.specificity,
                sourceOrder: rule.sourceOrder,
                value: value
            )
            if let current = stylesheetValue {
                if candidate.specificity > current.specificity
                    || (candidate.specificity == current.specificity
                        && candidate.sourceOrder >= current.sourceOrder) {
                    stylesheetValue = candidate
                }
            } else {
                stylesheetValue = candidate
            }
        }
        if let stylesheetValue { return stylesheetValue.value }
        return element.attribute(forName: name)?.stringValue
    }

    private static func inlineStyleDeclarations(on element: XMLElement) -> [String: String]? {
        guard let source = element.attribute(forName: "style")?.stringValue else { return [:] }
        return styleDeclarations(source)
    }

    private static func styleDeclarations(_ source: String) -> [String: String]? {
        var result: [String: String] = [:]
        for rawDeclaration in source.split(separator: ";", omittingEmptySubsequences: false) {
            let declaration = rawDeclaration.trimmingCharacters(in: .whitespacesAndNewlines)
            if declaration.isEmpty { continue }
            guard let separator = declaration.firstIndex(of: ":") else { return nil }
            let name = declaration[..<separator]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let value = declaration[declaration.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard supportedInlineStyleProperties.contains(name),
                  !value.isEmpty,
                  !value.localizedCaseInsensitiveContains("!important")
            else { return nil }
            result[name] = value
        }
        return result
    }

    private static func stylesheetRules(in root: XMLElement) -> [SVGStyleRule]? {
        guard let linkedStylesheets = try? root.nodes(forXPath: ".//*[local-name()='link']"),
              linkedStylesheets.isEmpty,
              let nodes = try? root.nodes(forXPath: ".//*[local-name()='style']")
        else { return nil }
        var result: [SVGStyleRule] = []
        var sourceOrder = 0
        for node in nodes {
            guard let element = node as? XMLElement,
                  hasSupportedStyleElementAttributes(element),
                  let rules = stylesheetRules(
                      in: element.stringValue ?? "",
                      sourceOrder: &sourceOrder
                  )
            else { return nil }
            result.append(contentsOf: rules)
        }
        return result
    }

    private static func hasSupportedStyleElementAttributes(_ element: XMLElement) -> Bool {
        guard (element.attributes ?? []).allSatisfy({ $0.name == "type" }) else { return false }
        let type = element.attribute(forName: "type")?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "text/css"
        return type == "text/css"
    }

    private static func stylesheetRules(
        in source: String,
        sourceOrder: inout Int
    ) -> [SVGStyleRule]? {
        guard let source = stylesheetSourceRemovingComments(source) else { return nil }
        var result: [SVGStyleRule] = []
        var remainder = source[...]
        while true {
            remainder = remainder.drop(while: { $0.isWhitespace })
            guard !remainder.isEmpty else { return result }
            guard let openingBrace = remainder.firstIndex(of: "{"),
                  let closingBrace = remainder[remainder.index(after: openingBrace)...]
                    .firstIndex(of: "}")
            else { return nil }
            let selectorSource = remainder[..<openingBrace]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let declarationSource = remainder[remainder.index(after: openingBrace)..<closingBrace]
            guard !selectorSource.isEmpty,
                  !selectorSource.contains("}"),
                  !declarationSource.contains("{"),
                  let declarations = styleDeclarations(String(declarationSource))
            else { return nil }
            let rawSelectors = selectorSource.split(separator: ",", omittingEmptySubsequences: false)
            guard !rawSelectors.isEmpty else { return nil }
            let order = sourceOrder
            sourceOrder += 1
            for rawSelector in rawSelectors {
                guard let selector = styleSelector(
                    rawSelector.trimmingCharacters(in: .whitespacesAndNewlines)
                ) else { return nil }
                result.append(SVGStyleRule(
                    selector: selector,
                    declarations: declarations,
                    sourceOrder: order
                ))
            }
            remainder = remainder[remainder.index(after: closingBrace)...]
        }
    }

    private static func stylesheetSourceRemovingComments(_ source: String) -> String? {
        var result = ""
        result.reserveCapacity(source.count)
        var cursor = source.startIndex
        while cursor < source.endIndex {
            let remainder = source[cursor...]
            if remainder.hasPrefix("/*") {
                let commentBodyStart = source.index(cursor, offsetBy: 2)
                guard let closingRange = source.range(
                    of: "*/",
                    range: commentBodyStart..<source.endIndex
                ) else { return nil }
                result.append(" ")
                cursor = closingRange.upperBound
                continue
            }
            guard !remainder.hasPrefix("*/") else { return nil }
            result.append(source[cursor])
            source.formIndex(after: &cursor)
        }
        return result
    }

    private static func styleSelector(_ source: String) -> SVGStyleSelector? {
        guard !source.isEmpty else { return nil }
        var remainder = source[...]
        var compounds: [SVGStyleCompoundSelector] = []
        var combinators: [SVGStyleCombinator] = []

        while !remainder.isEmpty {
            let boundary = remainder.firstIndex(where: { $0.isWhitespace || $0 == ">" })
                ?? remainder.endIndex
            guard boundary != remainder.startIndex,
                  let compound = styleCompoundSelector(String(remainder[..<boundary]))
            else { return nil }
            compounds.append(compound)
            remainder = remainder[boundary...]

            var consumedWhitespace = false
            while let first = remainder.first, first.isWhitespace {
                consumedWhitespace = true
                remainder = remainder.dropFirst()
            }
            guard !remainder.isEmpty else { break }
            if remainder.first == ">" {
                remainder = remainder.dropFirst()
                while let first = remainder.first, first.isWhitespace {
                    remainder = remainder.dropFirst()
                }
                guard !remainder.isEmpty else { return nil }
                combinators.append(.child)
            } else if consumedWhitespace {
                combinators.append(.descendant)
            } else {
                return nil
            }
        }

        guard !compounds.isEmpty, combinators.count == compounds.count - 1 else { return nil }
        return SVGStyleSelector(compounds: compounds, combinators: combinators)
    }

    private static func styleCompoundSelector(_ source: String) -> SVGStyleCompoundSelector? {
        guard !source.isEmpty else { return nil }
        var remainder = source[...]
        var elementName: String?
        var idName: String?
        var classNames: [String] = []

        if remainder.first != ".", remainder.first != "#" {
            let boundary = remainder.firstIndex(where: { $0 == "." || $0 == "#" })
                ?? remainder.endIndex
            let candidate = remainder[..<boundary].lowercased()
            guard supportedStyleElementNames.contains(candidate) else { return nil }
            elementName = candidate
            remainder = remainder[boundary...]
        }

        while let prefix = remainder.first {
            guard prefix == "." || prefix == "#" else { return nil }
            remainder = remainder.dropFirst()
            let boundary = remainder.firstIndex(where: { $0 == "." || $0 == "#" })
                ?? remainder.endIndex
            let name = String(remainder[..<boundary])
            guard isSimpleCSSIdentifier(name) else { return nil }
            if prefix == "." {
                classNames.append(name)
            } else {
                guard idName == nil else { return nil }
                idName = name
            }
            remainder = remainder[boundary...]
        }

        guard elementName != nil || idName != nil || !classNames.isEmpty else { return nil }
        return SVGStyleCompoundSelector(
            elementName: elementName,
            idName: idName,
            classNames: classNames
        )
    }

    private static func isSimpleCSSIdentifier(_ source: String) -> Bool {
        guard let first = source.unicodeScalars.first else { return false }
        let firstCharacters = CharacterSet.letters.union(CharacterSet(charactersIn: "_-"))
        let remainingCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return firstCharacters.contains(first)
            && source.unicodeScalars.allSatisfy(remainingCharacters.contains)
    }

    private static func classNames(on element: XMLElement) -> [String] {
        guard let source = element.attribute(forName: "class")?.stringValue else { return [] }
        return source.split(whereSeparator: \.isWhitespace).map(String.init)
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

    private static func svgPoints(_ source: String) -> [CGPoint]? {
        let scanner = Scanner(string: source)
        scanner.charactersToBeSkipped = nil
        scanner.locale = Locale(identifier: "en_US_POSIX")
        let whitespace = CharacterSet.whitespacesAndNewlines
        _ = scanner.scanCharacters(from: whitespace)

        var values: [CGFloat] = []
        while !scanner.isAtEnd {
            guard let value = scanner.scanDouble(), value.isFinite else { return nil }
            values.append(CGFloat(value))

            let hadWhitespace = scanner.scanCharacters(from: whitespace) != nil
            if scanner.scanString(",") != nil {
                _ = scanner.scanCharacters(from: whitespace)
                guard !scanner.isAtEnd else { return nil }
            } else if !hadWhitespace, !scanner.isAtEnd {
                return nil
            }
        }

        guard values.count >= 4, values.count.isMultiple(of: 2) else { return nil }
        return stride(from: 0, to: values.count, by: 2).map { index in
            CGPoint(x: values[index], y: values[index + 1])
        }
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
            return rgbFunctionalPaint(normalized)
        }
        if normalized.hasPrefix("hsl(") || normalized.hasPrefix("hsla(") {
            return hslFunctionalPaint(normalized)
        }
        guard let value = namedColorHexValues[normalized] else { return nil }
        return SVGPaint(
            color: NSColor(
                deviceRed: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            ),
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

    private static func rgbFunctionalPaint(_ source: String) -> SVGPaint? {
        guard let open = source.firstIndex(of: "("), source.last == ")" else { return nil }
        let body = String(source[source.index(after: open)..<source.index(before: source.endIndex)])
        guard let arguments = functionalPaintArguments(
            body,
            legacyFunctionExpectsAlpha: source.hasPrefix("rgba(")
        ) else { return nil }
        var rgb: [CGFloat] = []
        for component in arguments.components {
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
        let alpha: CGFloat
        if let alphaSource = arguments.alpha {
            guard let parsedAlpha = unitInterval(alphaSource) else { return nil }
            alpha = parsedAlpha
        } else {
            alpha = 1
        }
        return SVGPaint(
            color: NSColor(deviceRed: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1),
            alpha: alpha
        )
    }

    private static func hslFunctionalPaint(_ source: String) -> SVGPaint? {
        guard let open = source.firstIndex(of: "("), source.last == ")" else { return nil }
        let body = String(source[source.index(after: open)..<source.index(before: source.endIndex)])
        guard let arguments = functionalPaintArguments(
            body,
            legacyFunctionExpectsAlpha: source.hasPrefix("hsla(")
        ),
        let hue = hueFraction(arguments.components[0]),
        let saturation = percentage(arguments.components[1]),
        let lightness = percentage(arguments.components[2])
        else { return nil }

        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let hueSector = hue * 6
        let secondary = chroma * (1 - abs(hueSector.truncatingRemainder(dividingBy: 2) - 1))
        let offset = lightness - chroma / 2
        let channels: (CGFloat, CGFloat, CGFloat)
        switch hueSector {
        case 0..<1: channels = (chroma, secondary, 0)
        case 1..<2: channels = (secondary, chroma, 0)
        case 2..<3: channels = (0, chroma, secondary)
        case 3..<4: channels = (0, secondary, chroma)
        case 4..<5: channels = (secondary, 0, chroma)
        default: channels = (chroma, 0, secondary)
        }
        let alpha: CGFloat
        if let alphaSource = arguments.alpha {
            guard let parsedAlpha = unitInterval(alphaSource) else { return nil }
            alpha = parsedAlpha
        } else {
            alpha = 1
        }
        return SVGPaint(
            color: NSColor(
                deviceRed: channels.0 + offset,
                green: channels.1 + offset,
                blue: channels.2 + offset,
                alpha: 1
            ),
            alpha: alpha
        )
    }

    private static func hueFraction(_ source: String) -> CGFloat? {
        let units: [(suffix: String, degreesPerUnit: Double)] = [
            ("grad", 0.9),
            ("turn", 360),
            ("rad", 180 / .pi),
            ("deg", 1)
        ]
        let value: Double
        let degreesPerUnit: Double
        if let unit = units.first(where: { source.hasSuffix($0.suffix) }) {
            guard let parsed = Double(source.dropLast(unit.suffix.count)), parsed.isFinite else { return nil }
            value = parsed
            degreesPerUnit = unit.degreesPerUnit
        } else {
            guard let parsed = Double(source), parsed.isFinite else { return nil }
            value = parsed
            degreesPerUnit = 1
        }
        let normalizedDegrees = (value * degreesPerUnit).truncatingRemainder(dividingBy: 360)
        let positiveDegrees = normalizedDegrees < 0 ? normalizedDegrees + 360 : normalizedDegrees
        return CGFloat(positiveDegrees / 360)
    }

    private static func percentage(_ source: String) -> CGFloat? {
        guard source.hasSuffix("%"),
              let value = Double(source.dropLast()),
              value.isFinite,
              (0...100).contains(value) else { return nil }
        return CGFloat(value / 100)
    }

    private static func functionalPaintArguments(
        _ body: String,
        legacyFunctionExpectsAlpha: Bool
    ) -> (components: [String], alpha: String?)? {
        if body.contains(",") {
            guard !body.contains("/") else { return nil }
            let values = body
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard values.allSatisfy({ !$0.isEmpty }),
                  values.count == (legacyFunctionExpectsAlpha ? 4 : 3)
            else { return nil }
            return (Array(values.prefix(3)), legacyFunctionExpectsAlpha ? values[3] : nil)
        }

        let sections = body.split(separator: "/", omittingEmptySubsequences: false)
        guard (1...2).contains(sections.count) else { return nil }
        let components = sections[0]
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard components.count == 3 else { return nil }
        guard sections.count == 2 else { return (components, nil) }
        let alpha = sections[1]
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard alpha.count == 1 else { return nil }
        return (components, alpha[0])
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
