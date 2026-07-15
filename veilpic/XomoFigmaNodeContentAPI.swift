import Foundation

@MainActor
protocol XomoFigmaNodePlanFetching {
    func fetchPlan(
        for preview: XomoFigmaLinkPreview,
        credential: XomoFigmaPersonalAccessToken
    ) async throws -> XomoFigmaNodeImportPlan
}

@MainActor
struct XomoFigmaNodeContentAPIClient: XomoFigmaNodePlanFetching {
    static let maximumResponseBytes = 10_000_000
    static let maximumDepth = 6

    private let baseURL: URL
    private let transport: any XomoFigmaHTTPTransport
    private let imageAssetFetcher: (any XomoFigmaImageAssetFetching)?

    init() {
        baseURL = URL(string: "https://api.figma.com")!
        transport = XomoFigmaURLSessionTransport()
        imageAssetFetcher = XomoFigmaImageAssetAPIClient()
    }

    init(
        baseURL: URL = URL(string: "https://api.figma.com")!,
        transport: any XomoFigmaHTTPTransport,
        imageAssetFetcher: (any XomoFigmaImageAssetFetching)? = nil
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.imageAssetFetcher = imageAssetFetcher
    }

    func fetchPlan(
        for preview: XomoFigmaLinkPreview,
        credential: XomoFigmaPersonalAccessToken
    ) async throws -> XomoFigmaNodeImportPlan {
        guard let nodeID = preview.nodeID else {
            throw XomoFigmaNodeImportError.nodeSelectionRequired
        }
        let request = try makeRequest(preview: preview, nodeID: nodeID, credential: credential)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch let knownError as XomoFigmaNodeImportError {
            throw knownError
        } catch {
            throw XomoFigmaNodeImportError.transportFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw XomoFigmaNodeImportError.invalidResponse
        }
        try validateStatusCode(httpResponse.statusCode)
        guard data.count <= Self.maximumResponseBytes else {
            throw XomoFigmaNodeImportError.responseTooLarge
        }

        let envelope: XomoFigmaNodeResponse
        do {
            envelope = try JSONDecoder().decode(XomoFigmaNodeResponse.self, from: data)
        } catch {
            throw XomoFigmaNodeImportError.invalidResponse
        }
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: envelope, requestedNodeID: nodeID)
        guard let imageAssetFetcher, !plan.requiredImageReferences.isEmpty else { return plan }
        do {
            let assets = try await imageAssetFetcher.fetchAssets(
                fileKey: preview.fileKey,
                references: plan.requiredImageReferences,
                credential: credential
            )
            return plan.resolvingImageAssets(assets)
        } catch {
            return plan.resolvingImageAssets([:])
        }
    }

    private func makeRequest(
        preview: XomoFigmaLinkPreview,
        nodeID: String,
        credential: XomoFigmaPersonalAccessToken
    ) throws -> URLRequest {
        let endpoint = baseURL
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("files", isDirectory: true)
            .appendingPathComponent(preview.fileKey, isDirectory: true)
            .appendingPathComponent("nodes", isDirectory: false)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw XomoFigmaNodeImportError.invalidRequest
        }
        var queryItems = [
            URLQueryItem(name: "ids", value: nodeID),
            URLQueryItem(name: "depth", value: String(Self.maximumDepth)),
            URLQueryItem(name: "geometry", value: "paths")
        ]
        if let versionID = preview.versionID {
            queryItems.append(URLQueryItem(name: "version", value: versionID))
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw XomoFigmaNodeImportError.invalidRequest
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(credential.rawValue, forHTTPHeaderField: "X-Figma-Token")
        return request
    }

    private func validateStatusCode(_ statusCode: Int) throws {
        switch statusCode {
        case 200:
            return
        case 400:
            throw XomoFigmaNodeImportError.invalidRequest
        case 401, 403:
            throw XomoFigmaNodeImportError.authorizationDenied
        case 404:
            throw XomoFigmaNodeImportError.fileNotFound
        case 429:
            throw XomoFigmaNodeImportError.rateLimited
        case 500...599:
            throw XomoFigmaNodeImportError.serviceUnavailable
        default:
            throw XomoFigmaNodeImportError.invalidResponse
        }
    }
}

enum XomoFigmaNodeImportMapper {
    static let maximumNodeCount = 2_000

    static func makePlan(
        response: XomoFigmaNodeResponse,
        requestedNodeID: String
    ) throws -> XomoFigmaNodeImportPlan {
        guard let nestedEnvelope = response.nodes[requestedNodeID],
              let envelope = nestedEnvelope
        else {
            throw XomoFigmaNodeImportError.nodeNotFound
        }

        let root = envelope.document
        let origin = root.absoluteBoundingBox.map { ($0.x, $0.y) } ?? (0, 0)
        var items: [XomoFigmaNodeImportItem] = []
        try append(
            node: root,
            parentSourceID: nil,
            depth: 0,
            rootOrigin: origin,
            ancestorTransformFlattened: false,
            items: &items
        )
        return XomoFigmaNodeImportPlan(
            fileName: response.name,
            version: response.version,
            rootSourceID: root.id,
            rootName: root.name,
            items: items
        )
    }

    private static func append(
        node: XomoFigmaNode,
        parentSourceID: String?,
        depth: Int,
        rootOrigin: (x: Double, y: Double),
        ancestorTransformFlattened: Bool,
        items: inout [XomoFigmaNodeImportItem]
    ) throws {
        guard items.count < maximumNodeCount else {
            throw XomoFigmaNodeImportError.nodeLimitExceeded
        }
        let transformFlattened = ancestorTransformFlattened || hasFlattenedTransform(node.relativeTransform)
        items.append(makeItem(
            node: node,
            parentSourceID: parentSourceID,
            depth: depth,
            rootOrigin: rootOrigin,
            transformFlattened: transformFlattened
        ))
        for child in node.children ?? [] {
            try append(
                node: child,
                parentSourceID: node.id,
                depth: depth + 1,
                rootOrigin: rootOrigin,
                ancestorTransformFlattened: transformFlattened,
                items: &items
            )
        }
    }

    private static func makeItem(
        node: XomoFigmaNode,
        parentSourceID: String?,
        depth: Int,
        rootOrigin: (x: Double, y: Double),
        transformFlattened: Bool
    ) -> XomoFigmaNodeImportItem {
        var issues: [XomoFigmaNodeMappingIssue] = []
        let mapping = targetMapping(node: node, issues: &issues)
        let nativeStackLayout = stackLayout(node)
        if node.absoluteBoundingBox == nil {
            issues.append(.missingBounds)
        }
        if node.layoutMode != nil,
           node.layoutMode != "NONE",
           (nativeStackLayout == nil || hasUnsupportedAutoLayout(node)) {
            issues.append(.autoLayoutFlattened)
        }
        if node.isMask == true {
            issues.append(.maskFlattened)
        }
        if node.clipsContent == true {
            issues.append(.clippingFlattened)
        }
        if !(node.effects ?? []).isEmpty {
            issues.append(.effectsFlattened)
        }
        if let blendMode = node.blendMode, blendMode != "NORMAL", blendMode != "PASS_THROUGH" {
            issues.append(.blendModeFlattened)
        }
        if hasUnsupportedCornerStyle(node) {
            issues.append(.cornerRadiusFlattened)
        }
        if transformFlattened {
            issues.append(.transformFlattened)
        }
        if mapping.target == .vector,
           !geometryPaths(node).isEmpty,
           geometryPaths(node).contains(where: { XomoSVGPathParser.parse($0.path) == nil }) {
            issues.append(.vectorGeometryUnsupported)
        }
        issues = Array(Set(issues)).sorted { $0.rawValue < $1.rawValue }

        let fidelity: XomoFigmaNodeMappingFidelity
        if mapping.target == nil {
            fidelity = .unsupported
        } else if issues.isEmpty {
            fidelity = .exact
        } else {
            fidelity = .partial
        }
        let imagePaint = imagePaint(node: node)
        return XomoFigmaNodeImportItem(
            sourceID: node.id,
            parentSourceID: parentSourceID,
            depth: depth,
            sourceName: node.name,
            sourceType: node.type,
            targetKind: mapping.target,
            fidelity: fidelity,
            issues: issues,
            frame: node.absoluteBoundingBox.map {
                XomoFigmaPlanRect(
                    x: $0.x - rootOrigin.x,
                    y: $0.y - rootOrigin.y,
                    width: max(0, $0.width),
                    height: max(0, $0.height)
                )
            },
            opacity: min(max(node.opacity ?? 1, 0), 1),
            isVisible: node.visible ?? true,
            solidFill: solidColor(in: node.fills),
            linearGradientFill: supportsGradientFill(node.type)
                ? linearGradient(in: node.fills, bounds: node.absoluteBoundingBox)
                : nil,
            radialGradientFill: supportsGradientFill(node.type)
                ? radialGradient(in: node.fills, bounds: node.absoluteBoundingBox)
                : nil,
            solidStroke: solidColor(in: node.strokes),
            strokeWeight: node.strokeWeight,
            cornerRadius: uniformCornerRadius(node),
            cornerRadii: independentCornerRadii(node),
            cornerSmoothing: validCornerSmoothing(node),
            text: node.characters.map {
                XomoFigmaPlanText(
                    characters: $0,
                    fontFamily: node.style?.fontFamily,
                    fontSize: node.style?.fontSize,
                    fontWeight: node.style?.fontWeight,
                    horizontalAlignment: node.style?.textAlignHorizontal
                )
            },
            vectorPaths: geometryPaths(node).map(\.path),
            geometrySize: node.size.map {
                XomoFigmaPlanSize(width: max(0, $0.width), height: max(0, $0.height))
            },
            imageReference: imagePaint?.imageRef,
            imageScaleMode: imagePaint?.scaleMode,
            imageTransform: XomoFigmaPlanTransform(imagePaint?.imageTransform),
            imageScalingFactor: imagePaint?.scalingFactor.flatMap {
                $0.isFinite && $0 > 0 ? $0 : nil
            },
            imageRotation: imagePaint?.rotation.flatMap { $0.isFinite ? $0 : nil },
            imageFilters: imagePaint.map {
                XomoFigmaPlanImageFilters(
                    exposure: $0.filters?.exposure,
                    contrast: $0.filters?.contrast,
                    saturation: $0.filters?.saturation,
                    temperature: $0.filters?.temperature,
                    tint: $0.filters?.tint,
                    highlights: $0.filters?.highlights,
                    shadows: $0.filters?.shadows
                )
            } ?? XomoFigmaPlanImageFilters(),
            stackLayout: nativeStackLayout,
            stackChildLayout: stackChildLayout(node),
            isStackLayoutExcluded: node.layoutPositioning == "ABSOLUTE"
        )
    }

    private static func stackChildLayout(_ node: XomoFigmaNode) -> ImageEditorStackChildLayout? {
        let grow = CGFloat(node.layoutGrow ?? 0)
        let stretchesCrossAxis = node.layoutAlign == "STRETCH"
        guard grow > 0 || stretchesCrossAxis else { return nil }
        return ImageEditorStackChildLayout(
            grow: grow,
            stretchesCrossAxis: stretchesCrossAxis
        )
    }

    private static func stackLayout(_ node: XomoFigmaNode) -> ImageEditorStackLayout? {
        let axis: ImageEditorStackAxis
        switch node.layoutMode {
        case "HORIZONTAL":
            axis = .horizontal
        case "VERTICAL":
            axis = .vertical
        default:
            return nil
        }
        return ImageEditorStackLayout(
            axis: axis,
            spacing: CGFloat(node.itemSpacing ?? 0),
            paddingTop: CGFloat(node.paddingTop ?? 0),
            paddingRight: CGFloat(node.paddingRight ?? 0),
            paddingBottom: CGFloat(node.paddingBottom ?? 0),
            paddingLeft: CGFloat(node.paddingLeft ?? 0),
            primaryAlignment: primaryAlignment(node.primaryAxisAlignItems),
            crossAlignment: crossAlignment(node.counterAxisAlignItems),
            primarySizingMode: sizingMode(node.primaryAxisSizingMode),
            crossSizingMode: sizingMode(node.counterAxisSizingMode),
            wrapMode: node.layoutWrap == "WRAP" ? .wrap : .noWrap,
            counterSpacing: CGFloat(node.counterAxisSpacing ?? 0)
        )
    }

    private static func sizingMode(_ value: String?) -> ImageEditorStackSizingMode {
        value == "AUTO" ? .hug : .fixed
    }

    private static func primaryAlignment(_ value: String?) -> ImageEditorStackPrimaryAlignment {
        switch value {
        case "CENTER": return .center
        case "MAX": return .end
        case "SPACE_BETWEEN": return .spaceBetween
        default: return .start
        }
    }

    private static func crossAlignment(_ value: String?) -> ImageEditorStackCrossAlignment {
        switch value {
        case "CENTER": return .center
        case "MAX": return .end
        case "BASELINE": return .baseline
        default: return .start
        }
    }

    private static func hasUnsupportedAutoLayout(_ node: XomoFigmaNode) -> Bool {
        let usesUnsupportedWrap = node.layoutWrap == "WRAP" && node.layoutMode != "HORIZONTAL"
        let usesUnsupportedTrackDistribution = node.counterAxisAlignContent != nil
            && node.counterAxisAlignContent != "AUTO"
        let usesUnsupportedBaseline = node.counterAxisAlignItems == "BASELINE"
            && node.layoutMode != "HORIZONTAL"
        return usesUnsupportedWrap
            || usesUnsupportedTrackDistribution
            || usesUnsupportedBaseline
    }

    private static func targetMapping(
        node: XomoFigmaNode,
        issues: inout [XomoFigmaNodeMappingIssue]
    ) -> (target: XomoFigmaNodeTargetKind?, isImage: Bool) {
        switch node.type {
        case "FRAME", "GROUP":
            inspectPaints(node: node, allowsGradientFill: true, issues: &issues)
            return (.group, false)
        case "COMPONENT", "COMPONENT_SET", "INSTANCE":
            issues.append(.componentSemanticsFlattened)
            inspectPaints(node: node, allowsGradientFill: true, issues: &issues)
            return (.group, false)
        case "TEXT":
            inspectPaints(node: node, allowsGradientFill: false, issues: &issues)
            return (.text, false)
        case "RECTANGLE":
            if let imagePaint = imagePaint(node: node) {
                issues.append(.imageAssetPending)
                let filters = XomoFigmaPlanImageFilters(
                    exposure: imagePaint.filters?.exposure,
                    contrast: imagePaint.filters?.contrast,
                    saturation: imagePaint.filters?.saturation,
                    temperature: imagePaint.filters?.temperature,
                    tint: imagePaint.filters?.tint,
                    highlights: imagePaint.filters?.highlights,
                    shadows: imagePaint.filters?.shadows
                )
                if !filters.isIdentity {
                    issues.append(.imageFiltersBaked)
                }
                return (.imagePlaceholder, true)
            }
            inspectPaints(node: node, allowsGradientFill: true, issues: &issues)
            return (.rectangle, false)
        case "ELLIPSE":
            inspectPaints(node: node, allowsGradientFill: true, issues: &issues)
            return (.ellipse, false)
        case "VECTOR", "LINE", "STAR", "REGULAR_POLYGON":
            if geometryPaths(node).isEmpty {
                issues.append(.vectorGeometryMissing)
            }
            inspectPaints(node: node, allowsGradientFill: true, issues: &issues)
            return (.vector, false)
        default:
            issues.append(.unsupportedNodeType)
            return (nil, false)
        }
    }

    private static func inspectPaints(
        node: XomoFigmaNode,
        allowsGradientFill: Bool,
        issues: inout [XomoFigmaNodeMappingIssue]
    ) {
        let visiblePaints = (node.fills ?? []).filter { $0.visible ?? true }
        let visibleStrokes = (node.strokes ?? []).filter { $0.visible ?? true }
        let hasUnsupportedFill = visiblePaints.contains { paint in
            if paint.type == "SOLID" { return false }
            guard allowsGradientFill else { return true }
            switch paint.type {
            case "GRADIENT_LINEAR":
                return linearGradient(in: [paint], bounds: node.absoluteBoundingBox) == nil
            case "GRADIENT_RADIAL":
                return radialGradient(in: [paint], bounds: node.absoluteBoundingBox) == nil
            default:
                return true
            }
        }
        if visiblePaints.count > 1
            || hasUnsupportedFill
            || visibleStrokes.count > 1
            || visibleStrokes.contains(where: { $0.type != "SOLID" }) {
            issues.append(.unsupportedPaint)
        }
    }

    private static func solidColor(in paints: [XomoFigmaPaint]?) -> XomoFigmaPlanColor? {
        guard let paint = (paints ?? []).first(where: { ($0.visible ?? true) && $0.type == "SOLID" }),
              let color = paint.color
        else {
            return nil
        }
        let alpha = (color.a ?? 1) * (paint.opacity ?? 1)
        return XomoFigmaPlanColor(
            red: min(max(color.r, 0), 1),
            green: min(max(color.g, 0), 1),
            blue: min(max(color.b, 0), 1),
            alpha: min(max(alpha, 0), 1)
        )
    }

    private struct ResolvedGradientStops {
        var startColor: XomoFigmaPlanColor
        var endColor: XomoFigmaPlanColor
        var opacity: Double
        var colorStops: [XomoFigmaPlanGradientStop]
    }

    private static func linearGradient(
        in paints: [XomoFigmaPaint]?,
        bounds: XomoFigmaRectangle?
    ) -> XomoFigmaPlanLinearGradient? {
        guard let paint = (paints ?? []).first(where: {
            ($0.visible ?? true) && $0.type == "GRADIENT_LINEAR"
        }),
        let bounds,
        bounds.width.isFinite,
        bounds.height.isFinite,
        bounds.width > 0,
        bounds.height > 0,
        let handles = paint.gradientHandlePositions,
        handles.count == 3,
        handles.allSatisfy(\.isFinite),
        let resolvedStops = resolvedGradientStops(paint)
        else { return nil }

        let startHandle = handles[0]
        let endHandle = handles[1]
        let deltaX = (endHandle.x - startHandle.x) * bounds.width
        let deltaY = (endHandle.y - startHandle.y) * bounds.height
        let length = hypot(deltaX, deltaY)
        guard length.isFinite, length > 0.001 else { return nil }
        let angle = atan2(deltaY, deltaX) * 180 / .pi
        let radians = angle * .pi / 180
        let span = abs(cos(radians)) * bounds.width + abs(sin(radians)) * bounds.height
        let scale = length / span
        guard angle.isFinite, scale.isFinite, (0.25...4).contains(scale) else { return nil }

        return XomoFigmaPlanLinearGradient(
            startColor: resolvedStops.startColor,
            endColor: resolvedStops.endColor,
            angle: angle,
            scale: scale,
            centerX: (startHandle.x + endHandle.x) / 2,
            centerY: (startHandle.y + endHandle.y) / 2,
            opacity: resolvedStops.opacity,
            colorStops: resolvedStops.colorStops
        )
    }

    private static func radialGradient(
        in paints: [XomoFigmaPaint]?,
        bounds: XomoFigmaRectangle?
    ) -> XomoFigmaPlanRadialGradient? {
        guard let paint = (paints ?? []).first(where: {
            ($0.visible ?? true) && $0.type == "GRADIENT_RADIAL"
        }),
        let bounds,
        bounds.width.isFinite,
        bounds.height.isFinite,
        bounds.width > 0,
        bounds.height > 0,
        let handles = paint.gradientHandlePositions,
        handles.count == 3,
        handles.allSatisfy(\.isFinite),
        let resolvedStops = resolvedGradientStops(paint)
        else { return nil }

        let center = handles[0]
        let firstAxis = (
            x: (handles[1].x - center.x) * bounds.width,
            y: (handles[1].y - center.y) * bounds.height
        )
        let secondAxis = (
            x: (handles[2].x - center.x) * bounds.width,
            y: (handles[2].y - center.y) * bounds.height
        )
        let firstLength = hypot(firstAxis.x, firstAxis.y)
        let secondLength = hypot(secondAxis.x, secondAxis.y)
        let maximumLength = max(firstLength, secondLength)
        guard firstLength.isFinite,
              secondLength.isFinite,
              firstLength >= minimumGradientAxisLength,
              secondLength >= minimumGradientAxisLength,
              abs(firstLength - secondLength) <= maximumLength * circularGradientTolerance,
              abs(firstAxis.x * secondAxis.x + firstAxis.y * secondAxis.y)
                <= firstLength * secondLength * circularGradientTolerance,
              (-4...5).contains(center.x),
              (-4...5).contains(center.y)
        else { return nil }

        let referenceRadius = hypot(bounds.width / 2, bounds.height / 2)
        let radius = (firstLength + secondLength) / 2
        let scale = radius / referenceRadius
        guard scale.isFinite, (0.25...4).contains(scale) else { return nil }

        return XomoFigmaPlanRadialGradient(
            startColor: resolvedStops.startColor,
            endColor: resolvedStops.endColor,
            scale: scale,
            centerX: center.x,
            centerY: center.y,
            opacity: resolvedStops.opacity,
            colorStops: resolvedStops.colorStops
        )
    }

    private static let minimumGradientAxisLength = 0.001
    private static let circularGradientTolerance = 0.001

    private static func resolvedGradientStops(
        _ paint: XomoFigmaPaint
    ) -> ResolvedGradientStops? {
        guard let stops = paint.gradientStops,
              (2...ImageEditorGradientFillContent.maximumColorStopCount).contains(stops.count),
              abs(stops[0].position) <= 0.001,
              abs((stops.last?.position ?? 0) - 1) <= 0.001,
              let paintOpacity = validUnitValue(paint.opacity ?? 1)
        else { return nil }

        let colors = stops.compactMap(resolveGradientStopColor)
        guard colors.count == stops.count,
              zip(stops, stops.dropFirst()).allSatisfy({ pair in
                  pair.0.position <= pair.1.position
              }),
              let first = colors.first,
              let last = colors.last,
              colors.allSatisfy({ abs($0.alpha - first.alpha) <= 0.001 })
        else { return nil }

        return ResolvedGradientStops(
            startColor: opaqueColor(first),
            endColor: opaqueColor(last),
            opacity: first.alpha * paintOpacity,
            colorStops: zip(stops, colors).map { pair in
                let (stop, color) = pair
                return XomoFigmaPlanGradientStop(
                    position: stop.position,
                    color: opaqueColor(color)
                )
            }
        )
    }

    private static func opaqueColor(_ color: XomoFigmaPlanColor) -> XomoFigmaPlanColor {
        XomoFigmaPlanColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
    }

    nonisolated static func resolveGradientStopColor(
        _ stop: XomoFigmaGradientStop
    ) -> XomoFigmaPlanColor? {
        guard stop.position.isFinite,
              let red = validUnitValue(stop.color.r),
              let green = validUnitValue(stop.color.g),
              let blue = validUnitValue(stop.color.b),
              let alpha = validUnitValue(stop.color.a ?? 1)
        else { return nil }
        return XomoFigmaPlanColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    nonisolated private static func validUnitValue(_ value: Double) -> Double? {
        value.isFinite && (0...1).contains(value) ? value : nil
    }

    private static func supportsGradientFill(_ nodeType: String) -> Bool {
        [
            "FRAME", "GROUP", "COMPONENT", "COMPONENT_SET", "INSTANCE",
            "RECTANGLE", "ELLIPSE", "VECTOR", "STAR", "REGULAR_POLYGON"
        ].contains(nodeType)
    }

    private static func imagePaint(node: XomoFigmaNode) -> XomoFigmaPaint? {
        (node.fills ?? []).first { ($0.visible ?? true) && $0.type == "IMAGE" && $0.imageRef != nil }
    }

    private static func geometryPaths(_ node: XomoFigmaNode) -> [XomoFigmaPath] {
        let fills = node.fillGeometry ?? []
        return fills.isEmpty ? (node.strokeGeometry ?? []) : fills
    }

    private static func uniformCornerRadius(_ node: XomoFigmaNode) -> Double? {
        if let radii = node.rectangleCornerRadii, !radii.isEmpty {
            guard let radii = validRectangleCornerRadii(node),
                  let first = radii.first,
                  radii.dropFirst().allSatisfy({ abs($0 - first) <= 0.001 })
            else { return nil }
            return first
        }
        guard let radius = node.cornerRadius, radius.isFinite, radius >= 0 else { return nil }
        return radius
    }

    private static func independentCornerRadii(
        _ node: XomoFigmaNode
    ) -> XomoFigmaPlanCornerRadii? {
        guard let radii = validRectangleCornerRadii(node),
              uniformCornerRadius(node) == nil
        else { return nil }
        return XomoFigmaPlanCornerRadii(
            topLeft: radii[0],
            topRight: radii[1],
            bottomRight: radii[2],
            bottomLeft: radii[3]
        )
    }

    private static func validRectangleCornerRadii(_ node: XomoFigmaNode) -> [Double]? {
        guard let radii = node.rectangleCornerRadii,
              radii.count == 4,
              radii.allSatisfy({ $0.isFinite && $0 >= 0 })
        else { return nil }
        return radii
    }

    private static func validCornerSmoothing(_ node: XomoFigmaNode) -> Double? {
        guard let smoothing = node.cornerSmoothing,
              smoothing.isFinite,
              (0...1).contains(smoothing)
        else { return nil }
        return smoothing
    }

    private static func hasUnsupportedCornerStyle(_ node: XomoFigmaNode) -> Bool {
        let radii = node.rectangleCornerRadii ?? []
        let hasInvalidIndependentRadii = !radii.isEmpty
            && validRectangleCornerRadii(node) == nil
        let hasInvalidUniformRadius = node.cornerRadius.map {
            !$0.isFinite || $0 < 0
        } ?? false
        let hasRoundedCorner = (uniformCornerRadius(node) ?? 0) > 0
            || radii.contains(where: { $0.isFinite && $0 > 0 })
        let hasInvalidCornerSmoothing = node.cornerSmoothing.map {
            !$0.isFinite || !(0...1).contains($0)
        } ?? false
        let hasApproximatedCornerSmoothing = (validCornerSmoothing(node) ?? 0) > 0
            && hasRoundedCorner
        return hasInvalidIndependentRadii
            || hasInvalidUniformRadius
            || hasInvalidCornerSmoothing
            || hasApproximatedCornerSmoothing
    }

    private static func hasFlattenedTransform(_ transform: [[Double]]?) -> Bool {
        guard let transform,
              transform.count == 2,
              transform[0].count == 3,
              transform[1].count == 3
        else { return false }
        let epsilon = 0.000_001
        return abs(transform[0][1]) > epsilon
            || abs(transform[1][0]) > epsilon
            || transform[0][0] < 0
            || transform[1][1] < 0
    }
}

struct XomoFigmaNodeResponse: Decodable {
    var name: String
    var version: String?
    var nodes: [String: XomoFigmaNodeEnvelope?]
}

struct XomoFigmaNodeEnvelope: Decodable {
    var document: XomoFigmaNode
}

struct XomoFigmaNode: Decodable {
    var id: String
    var name: String
    var type: String
    var visible: Bool?
    var opacity: Double?
    var children: [XomoFigmaNode]?
    var absoluteBoundingBox: XomoFigmaRectangle?
    var characters: String?
    var style: XomoFigmaTypeStyle?
    var fills: [XomoFigmaPaint]?
    var strokes: [XomoFigmaPaint]?
    var strokeWeight: Double?
    var effects: [XomoFigmaEffect]?
    var blendMode: String?
    var isMask: Bool?
    var clipsContent: Bool?
    var cornerRadius: Double?
    var rectangleCornerRadii: [Double]?
    var cornerSmoothing: Double?
    var layoutMode: String?
    var primaryAxisAlignItems: String?
    var counterAxisAlignItems: String?
    var counterAxisAlignContent: String?
    var itemSpacing: Double?
    var counterAxisSpacing: Double?
    var paddingLeft: Double?
    var paddingRight: Double?
    var paddingTop: Double?
    var paddingBottom: Double?
    var layoutWrap: String?
    var primaryAxisSizingMode: String?
    var counterAxisSizingMode: String?
    var layoutPositioning: String?
    var layoutGrow: Double?
    var layoutAlign: String?
    var size: XomoFigmaSize?
    var relativeTransform: [[Double]]?
    var fillGeometry: [XomoFigmaPath]?
    var strokeGeometry: [XomoFigmaPath]?
}

struct XomoFigmaRectangle: Decodable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct XomoFigmaTypeStyle: Decodable {
    var fontFamily: String?
    var fontSize: Double?
    var fontWeight: Double?
    var textAlignHorizontal: String?
}

struct XomoFigmaPaint: Decodable {
    var type: String
    var visible: Bool?
    var opacity: Double?
    var color: XomoFigmaColor?
    var gradientHandlePositions: [XomoFigmaVector]?
    var gradientStops: [XomoFigmaGradientStop]?
    var imageRef: String?
    var scaleMode: String?
    var imageTransform: [[Double]]?
    var scalingFactor: Double?
    var rotation: Double?
    var filters: XomoFigmaImageFilters?
}

struct XomoFigmaImageFilters: Decodable {
    var exposure: Double?
    var contrast: Double?
    var saturation: Double?
    var temperature: Double?
    var tint: Double?
    var highlights: Double?
    var shadows: Double?
}

struct XomoFigmaVector: Decodable {
    var x: Double
    var y: Double

    var isFinite: Bool { x.isFinite && y.isFinite }
}

nonisolated struct XomoFigmaGradientStop: Decodable, Sendable {
    var position: Double
    var color: XomoFigmaColor
}

nonisolated struct XomoFigmaColor: Decodable, Sendable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double?
}

struct XomoFigmaPath: Decodable {
    var path: String
}

struct XomoFigmaSize: Decodable {
    var width: Double
    var height: Double
}

struct XomoFigmaEffect: Decodable {
    var type: String?
}
