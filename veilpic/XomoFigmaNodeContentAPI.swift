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
    private let variableFetcher: (any XomoFigmaVariableFetching)?

    init() {
        baseURL = URL(string: "https://api.figma.com")!
        transport = XomoFigmaURLSessionTransport()
        imageAssetFetcher = XomoFigmaImageAssetAPIClient()
        variableFetcher = XomoFigmaVariableAPIClient()
    }

    init(
        baseURL: URL = URL(string: "https://api.figma.com")!,
        transport: any XomoFigmaHTTPTransport,
        imageAssetFetcher: (any XomoFigmaImageAssetFetching)? = nil,
        variableFetcher: (any XomoFigmaVariableFetching)? = nil
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.imageAssetFetcher = imageAssetFetcher
        self.variableFetcher = variableFetcher
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
        var plan = try XomoFigmaNodeImportMapper.makePlan(response: envelope, requestedNodeID: nodeID)
        plan.sourceCanonicalURL = preview.canonicalURL
        if let variableFetcher, !plan.requiredVariableIDs.isEmpty {
            do {
                let store = try await variableFetcher.fetchVariables(
                    fileKey: preview.fileKey,
                    credential: credential
                )
                plan = plan.resolvingVariables(store)
            } catch {
                // Variable values are an optional enhancement; the imported binding IDs remain usable.
            }
        }
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
            siblingMaskFrame: nil,
            siblingMaskShape: nil,
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
        siblingMaskFrame: XomoFigmaPlanRect?,
        siblingMaskShape: XomoFigmaPlanMaskShape?,
        items: inout [XomoFigmaNodeImportItem]
    ) throws {
        guard items.count < maximumNodeCount else {
            throw XomoFigmaNodeImportError.nodeLimitExceeded
        }
        var transformIssues: [XomoFigmaNodeMappingIssue] = []
        let target = targetMapping(node: node, issues: &transformIssues).target
        let hasChildren = !(node.children ?? []).isEmpty
        let transformFlattened = ancestorTransformFlattened
            || transformNeedsFlattening(node.relativeTransform, target: target)
            || (hasChildren && hasNonIdentityTransform(node.relativeTransform))
        let childSiblingMaskFrames = simpleMaskSiblingFrames(in: node.children, rootOrigin: rootOrigin)
        let childSiblingMaskShape = simpleMaskShape(in: node.children)
        items.append(makeItem(
            node: node,
            parentSourceID: parentSourceID,
            depth: depth,
            rootOrigin: rootOrigin,
            transformFlattened: transformFlattened,
            siblingMaskFrame: siblingMaskFrame,
            siblingMaskShape: siblingMaskShape
        ))
        for child in node.children ?? [] {
            try append(
                node: child,
                parentSourceID: node.id,
                depth: depth + 1,
                rootOrigin: rootOrigin,
                ancestorTransformFlattened: transformFlattened,
                siblingMaskFrame: childSiblingMaskFrames[child.id],
                siblingMaskShape: childSiblingMaskFrames[child.id] == nil ? nil : childSiblingMaskShape,
                items: &items
            )
        }
    }

    private static func makeItem(
        node: XomoFigmaNode,
        parentSourceID: String?,
        depth: Int,
        rootOrigin: (x: Double, y: Double),
        transformFlattened: Bool,
        siblingMaskFrame: XomoFigmaPlanRect?,
        siblingMaskShape: XomoFigmaPlanMaskShape?
    ) -> XomoFigmaNodeImportItem {
        var issues: [XomoFigmaNodeMappingIssue] = []
        let mapping = targetMapping(node: node, issues: &issues)
        let componentRole = XomoFigmaComponentRole(rawValue: node.type)
        let variableBindings = node.boundVariables?.bindings() ?? []
        if !variableBindings.isEmpty {
            issues.append(.variableBindingPreserved)
        }
        let nativeStackLayout = stackLayout(node)
        if node.absoluteBoundingBox == nil {
            issues.append(.missingBounds)
        }
        if node.layoutMode != nil,
           node.layoutMode != "NONE",
           (nativeStackLayout == nil || hasUnsupportedAutoLayout(node)) {
            issues.append(.autoLayoutFlattened)
        }
        if node.isMask == true,
           supportedMaskShape(node) == nil {
            issues.append(.maskFlattened)
        }
        let childMaskFrame = simpleMaskFrame(in: node.children, rootOrigin: rootOrigin)
        if (node.children ?? []).contains(where: { $0.isMask == true }),
           childMaskFrame == nil {
            issues.append(.maskFlattened)
        }
        if node.clipsContent == true,
           !(mapping.target == .group && node.absoluteBoundingBox != nil) {
            issues.append(.clippingFlattened)
        }
        let effects = mappedEffects(node.effects)
        if (node.effects ?? []).contains(where: { !isSupportedEffect($0) }) {
            issues.append(.effectsFlattened)
        }
        if let blendMode = node.blendMode,
           mappedBlendMode(blendMode) == nil {
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
            componentRole: componentRole,
            componentProperties: node.componentProperties ?? [:],
            targetKind: mapping.target,
            fidelity: fidelity,
            issues: issues,
            variableBindings: variableBindings,
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
            blendMode: mappedBlendMode(node.blendMode)?.rawValue,
            solidFill: solidColor(in: node.fills),
            linearGradientFill: supportsGradientFill(node.type)
                ? linearGradient(in: node.fills, bounds: node.absoluteBoundingBox)
                : nil,
            radialGradientFill: supportsGradientFill(node.type)
                ? radialGradient(in: node.fills, bounds: node.absoluteBoundingBox)
                : nil,
            solidStroke: solidColor(in: node.strokes),
            strokeWeight: node.strokeWeight,
            strokeAlign: node.strokeAlign,
            strokeCap: node.strokeCap,
            strokeJoin: node.strokeJoin,
            strokeDashes: node.strokeDashes,
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
            relativeTransform: XomoFigmaPlanTransform(node.relativeTransform),
            clipsContent: node.clipsContent == true && mapping.target == .group && node.absoluteBoundingBox != nil,
            isMask: node.isMask == true,
            maskFrame: childMaskFrame,
            maskShape: supportedMaskShape(node) ?? .rectangle,
            siblingMaskFrame: siblingMaskFrame,
            siblingMaskShape: siblingMaskShape,
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
            effects: effects,
            stackLayout: nativeStackLayout,
            stackChildLayout: stackChildLayout(node),
            isStackLayoutExcluded: node.layoutPositioning == "ABSOLUTE"
        )
    }

    private static func mappedBlendMode(_ rawValue: String?) -> ImageEditorBlendMode? {
        guard let rawValue else { return nil }
        switch rawValue {
        case "NORMAL":
            return .normal
        case "PASS_THROUGH":
            return .passThrough
        case "MULTIPLY":
            return .multiply
        case "SCREEN":
            return .screen
        case "OVERLAY":
            return .overlay
        case "DARKEN":
            return .darken
        case "LIGHTEN":
            return .lighten
        case "COLOR_DODGE":
            return .colorDodge
        case "COLOR_BURN":
            return .colorBurn
        case "LINEAR_DODGE":
            return .linearDodge
        case "LINEAR_BURN":
            return .linearBurn
        case "HARD_LIGHT":
            return .hardLight
        case "SOFT_LIGHT":
            return .softLight
        case "DIFFERENCE":
            return .difference
        case "EXCLUSION":
            return .exclusion
        case "HUE":
            return .hue
        case "SATURATION":
            return .saturation
        case "COLOR":
            return .color
        case "LUMINOSITY":
            return .luminosity
        default:
            return nil
        }
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

    private static func isSupportedEffect(_ effect: XomoFigmaEffect) -> Bool {
        guard effect.visible ?? true else { return true }
        guard let type = effect.type,
              let radius = effect.radius,
              radius.isFinite,
              radius >= 0
        else { return false }
        if type == "LAYER_BLUR" || type == "BACKGROUND_BLUR" {
            return true
        }
        guard type == "DROP_SHADOW" || type == "INNER_SHADOW",
              let color = effect.color,
              [color.r, color.g, color.b, color.a ?? 1].allSatisfy({ $0.isFinite }),
              let offset = effect.offset,
              offset.x.isFinite,
              offset.y.isFinite
        else { return false }
        return (effect.spread ?? 0).isFinite
    }

    private static func mappedEffects(_ effects: [XomoFigmaEffect]?) -> [XomoFigmaPlanEffect] {
        (effects ?? []).compactMap { effect in
            guard effect.visible ?? true,
                  isSupportedEffect(effect),
                  let type = effect.type,
                  let radius = effect.radius
            else { return nil }
            if type == "LAYER_BLUR" || type == "BACKGROUND_BLUR" {
                return XomoFigmaPlanEffect(
                    kind: type == "LAYER_BLUR" ? .layerBlur : .backgroundBlur,
                    color: XomoFigmaPlanColor(red: 0, green: 0, blue: 0, alpha: 0),
                    offsetX: 0,
                    offsetY: 0,
                    radius: max(0, radius),
                    spread: 0
                )
            }
            guard let color = effect.color, let offset = effect.offset else { return nil }
            return XomoFigmaPlanEffect(
                kind: type == "INNER_SHADOW" ? .innerShadow : .dropShadow,
                color: XomoFigmaPlanColor(
                    red: min(max(color.r, 0), 1),
                    green: min(max(color.g, 0), 1),
                    blue: min(max(color.b, 0), 1),
                    alpha: min(max(color.a ?? 1, 0), 1)
                ),
                offsetX: offset.x,
                offsetY: offset.y,
                radius: max(0, radius),
                spread: max(0, effect.spread ?? 0)
            )
        }
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
            counterSpacing: CGFloat(node.counterAxisSpacing ?? 0),
            crossTrackAlignment: crossTrackAlignment(
                node.counterAxisAlignContent,
                axis: axis,
                wrapMode: node.layoutWrap == "WRAP" ? .wrap : .noWrap
            )
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

    private static func crossTrackAlignment(
        _ value: String?,
        axis: ImageEditorStackAxis,
        wrapMode: ImageEditorStackWrapMode
    ) -> ImageEditorStackCrossTrackAlignment {
        guard axis == .horizontal, wrapMode == .wrap, value == "SPACE_BETWEEN" else {
            return .automatic
        }
        return .spaceBetween
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
        let supportsSpaceBetweenTracks = node.layoutMode == "HORIZONTAL"
            && node.layoutWrap == "WRAP"
            && node.counterAxisAlignContent == "SPACE_BETWEEN"
        let usesUnsupportedTrackDistribution = node.counterAxisAlignContent != nil
            && node.counterAxisAlignContent != "AUTO"
            && !supportsSpaceBetweenTracks
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
        case "SECTION", "FRAME", "GROUP":
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
                    issues.append(.imageFiltersPreserved)
                }
                return (.imagePlaceholder, true)
            }
            inspectPaints(node: node, allowsGradientFill: true, issues: &issues)
            return (.rectangle, false)
        case "ELLIPSE":
            inspectPaints(node: node, allowsGradientFill: true, issues: &issues)
            return (.ellipse, false)
        case "BOOLEAN_OPERATION", "VECTOR", "LINE", "STAR", "REGULAR_POLYGON":
            if geometryPaths(node).isEmpty {
                issues.append(.vectorGeometryMissing)
            }
            if node.type == "BOOLEAN_OPERATION" {
                issues.append(.booleanOperationFlattened)
            }
            inspectPaints(node: node, allowsGradientFill: true, issues: &issues)
            return (.vector, false)
        case "SLICE":
            return (.slice, false)
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
        let solidPaints = (paints ?? []).filter {
            ($0.visible ?? true) && $0.type == "SOLID" && $0.color != nil
        }
        guard !solidPaints.isEmpty else { return nil }

        // Figma applies the fills array in reverse paint order: the last
        // entry is the bottom paint and the first entry is the top paint.
        // Flattening only SOLID paints preserves the rendered color while
        // keeping the unsupportedPaint issue honest about lost per-fill editability.
        return solidPaints.reversed().reduce(
            XomoFigmaPlanColor(red: 0, green: 0, blue: 0, alpha: 0)
        ) { destination, paint in
            guard let color = paint.color else { return destination }
            let sourceAlpha = min(max((color.a ?? 1) * (paint.opacity ?? 1), 0), 1)
            let destinationAlpha = min(max(destination.alpha, 0), 1)
            let outputAlpha = sourceAlpha + destinationAlpha * (1 - sourceAlpha)
            guard outputAlpha > 0 else {
                return XomoFigmaPlanColor(red: 0, green: 0, blue: 0, alpha: 0)
            }
            let sourceRed = min(max(color.r, 0), 1)
            let sourceGreen = min(max(color.g, 0), 1)
            let sourceBlue = min(max(color.b, 0), 1)
            let destinationWeight = destinationAlpha * (1 - sourceAlpha)
            return XomoFigmaPlanColor(
                red: (sourceRed * sourceAlpha + destination.red * destinationWeight) / outputAlpha,
                green: (sourceGreen * sourceAlpha + destination.green * destinationWeight) / outputAlpha,
                blue: (sourceBlue * sourceAlpha + destination.blue * destinationWeight) / outputAlpha,
                alpha: outputAlpha
            )
        }
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
            "SECTION", "FRAME", "GROUP", "COMPONENT", "COMPONENT_SET", "INSTANCE",
            "RECTANGLE", "ELLIPSE", "VECTOR", "STAR", "REGULAR_POLYGON", "BOOLEAN_OPERATION"
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

    private static func supportedMaskShape(_ node: XomoFigmaNode) -> XomoFigmaPlanMaskShape? {
        guard (node.absoluteBoundingBox?.width ?? 0) > 0,
              (node.absoluteBoundingBox?.height ?? 0) > 0
        else { return nil }
        switch node.type {
        case "RECTANGLE": return .rectangle
        case "ELLIPSE": return .ellipse
        default: return nil
        }
    }

    private static func simpleMaskFrame(
        in children: [XomoFigmaNode]?,
        rootOrigin: (x: Double, y: Double)
    ) -> XomoFigmaPlanRect? {
        guard let children,
              children.filter({ $0.isMask == true }).count == 1,
              let maskIndex = children.firstIndex(where: { $0.isMask == true }),
              maskIndex < children.index(before: children.endIndex),
              supportedMaskShape(children[maskIndex]) != nil,
              let bounds = children[maskIndex].absoluteBoundingBox
        else { return nil }
        return XomoFigmaPlanRect(
            x: bounds.x - rootOrigin.x,
            y: bounds.y - rootOrigin.y,
            width: bounds.width,
            height: bounds.height
        )
    }

    private static func simpleMaskSiblingFrames(
        in children: [XomoFigmaNode]?,
        rootOrigin: (x: Double, y: Double)
    ) -> [String: XomoFigmaPlanRect] {
        guard let children,
              children.filter({ $0.isMask == true }).count == 1,
              let maskIndex = children.firstIndex(where: { $0.isMask == true }),
              maskIndex < children.index(before: children.endIndex),
              supportedMaskShape(children[maskIndex]) != nil,
              let bounds = children[maskIndex].absoluteBoundingBox
        else { return [:] }
        let frame = XomoFigmaPlanRect(
            x: bounds.x - rootOrigin.x,
            y: bounds.y - rootOrigin.y,
            width: bounds.width,
            height: bounds.height
        )
        return Dictionary(uniqueKeysWithValues: children[(maskIndex + 1)...].map { ($0.id, frame) })
    }

    private static func simpleMaskShape(in children: [XomoFigmaNode]?) -> XomoFigmaPlanMaskShape? {
        guard let children,
              children.filter({ $0.isMask == true }).count == 1,
              let maskIndex = children.firstIndex(where: { $0.isMask == true }),
              maskIndex < children.index(before: children.endIndex)
        else { return nil }
        return supportedMaskShape(children[maskIndex])
    }

    private static func hasNonIdentityTransform(_ transform: [[Double]]?) -> Bool {
        guard let transform,
              let parsed = XomoFigmaPlanTransform(transform)
        else { return false }
        let epsilon = 0.000_001
        return abs(parsed.m11 - 1) > epsilon
            || abs(parsed.m12) > epsilon
            || abs(parsed.m21) > epsilon
            || abs(parsed.m22 - 1) > epsilon
            || abs(parsed.translationX) > epsilon
            || abs(parsed.translationY) > epsilon
    }

    private static func transformNeedsFlattening(
        _ transform: [[Double]]?,
        target: XomoFigmaNodeTargetKind?
    ) -> Bool {
        guard let transform,
              let parsed = XomoFigmaPlanTransform(transform)
        else { return false }
        let epsilon = 0.000_001
        let nonZeroEntries = [parsed.m11, parsed.m12, parsed.m21, parsed.m22]
            .filter { abs($0) > epsilon }
        let isAxisPermutation = nonZeroEntries.count == 2
            && abs(parsed.m11) * abs(parsed.m12) <= epsilon
            && abs(parsed.m21) * abs(parsed.m22) <= epsilon
        if isAxisPermutation {
            switch target {
            case .rectangle, .ellipse, .vector, .group:
                return false
            default:
                return !isIdentityTransform(parsed)
            }
        }
        guard target == .vector else { return !isIdentityTransform(parsed) }
        let firstLength = hypot(parsed.m11, parsed.m21)
        let secondLength = hypot(parsed.m12, parsed.m22)
        let dot = parsed.m11 * parsed.m12 + parsed.m21 * parsed.m22
        let scale = max(firstLength, secondLength)
        return firstLength <= epsilon
            || secondLength <= epsilon
            || abs(dot) > max(0.000_001, scale * scale * 0.000_001)
    }

    private static func isIdentityTransform(_ transform: XomoFigmaPlanTransform) -> Bool {
        let epsilon = 0.000_001
        return abs(transform.m11 - 1) <= epsilon
            && abs(transform.m12) <= epsilon
            && abs(transform.m21) <= epsilon
            && abs(transform.m22 - 1) <= epsilon
            && abs(transform.translationX) <= epsilon
            && abs(transform.translationY) <= epsilon
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
    var strokeAlign: String?
    var strokeCap: String?
    var strokeJoin: String?
    var strokeDashes: [Double]?
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
    var boundVariables: XomoFigmaBoundVariables?
    var componentProperties: [String: XomoFigmaComponentProperty]?
}

struct XomoFigmaVariableReference: Decodable {
    var type: String
    var id: String

    var isAlias: Bool { type == "VARIABLE_ALIAS" && !id.isEmpty }
}

enum XomoFigmaBoundVariableValue: Decodable {
    case single(XomoFigmaVariableReference)
    case multiple([XomoFigmaVariableReference])

    init(from decoder: Decoder) throws {
        if var array = try? decoder.unkeyedContainer() {
            var values: [XomoFigmaVariableReference] = []
            while !array.isAtEnd {
                values.append(try array.decode(XomoFigmaVariableReference.self))
            }
            self = .multiple(values)
            return
        }
        self = .single(try XomoFigmaVariableReference(from: decoder))
    }

    var references: [XomoFigmaVariableReference] {
        switch self {
        case .single(let reference): return [reference]
        case .multiple(let references): return references
        }
    }
}

struct XomoFigmaBoundVariables: Decodable {
    var fills: XomoFigmaBoundVariableValue?
    var strokes: XomoFigmaBoundVariableValue?
    var characters: XomoFigmaBoundVariableValue?

    func bindings() -> [XomoFigmaVariableBinding] {
        [
            ("fills", fills),
            ("strokes", strokes),
            ("characters", characters)
        ].flatMap { field, value in
            (value?.references ?? []).filter(\.isAlias).map {
                XomoFigmaVariableBinding(field: field, variableID: $0.id)
            }
        }
    }
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
    var color: XomoFigmaColor?
    var offset: XomoFigmaEffectOffset?
    var radius: Double?
    var spread: Double?
    var visible: Bool?
}

struct XomoFigmaEffectOffset: Decodable {
    var x: Double
    var y: Double
}
