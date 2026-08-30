import CoreGraphics
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
        try Task.checkCancellation()
        guard let nodeID = preview.nodeID else {
            throw XomoFigmaNodeImportError.nodeSelectionRequired
        }
        let request = try makeRequest(preview: preview, nodeID: nodeID, credential: credential)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let knownError as XomoFigmaNodeImportError {
            try Task.checkCancellation()
            throw knownError
        } catch {
            try Task.checkCancellation()
            throw XomoFigmaNodeImportError.transportFailed
        }
        try Task.checkCancellation()

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
                try Task.checkCancellation()
                plan = plan.resolvingVariables(store)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try Task.checkCancellation()
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
            try Task.checkCancellation()
            return plan.resolvingImageAssets(assets)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
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
    private static let regularFontWeight = 400.0
    private static let boldFontWeight = 700.0
    private static let approximateBoldThreshold = 600.0
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
            parentStackAxis: nil,
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
        parentStackAxis: ImageEditorStackAxis?,
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
            parentStackAxis: parentStackAxis,
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
                parentStackAxis: stackAxis(node),
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
        parentStackAxis: ImageEditorStackAxis?,
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
        if hasUnpreservedStackConstraints(node) {
            issues.append(.autoLayoutFlattened)
        }
        let nativeStackLayout = stackLayout(node)
        if node.absoluteBoundingBox == nil {
            issues.append(.missingBounds)
        }
        if node.layoutMode != nil,
           node.layoutMode != "NONE",
           (nativeStackLayout == nil || hasUnsupportedAutoLayout(node, parentStackAxis: parentStackAxis)) {
            issues.append(.autoLayoutFlattened)
        }
        if parentStackAxis != nil,
           hasUnsupportedStackChildSizing(node, parentAxis: parentStackAxis) {
            issues.append(.autoLayoutFlattened)
        }
        if parentStackAxis != nil,
           hasUnsupportedStackChildPositioning(node) {
            issues.append(.autoLayoutFlattened)
        }
        if node.isMask == true,
           supportedMaskShape(node) == nil {
            issues.append(.maskFlattened)
        }
        let childMaskFrame = simpleMaskFrame(in: node.children, rootOrigin: rootOrigin)
        let childMaskShape = simpleMaskShape(in: node.children)
        if (node.children ?? []).contains(where: { $0.isMask == true }),
           childMaskFrame == nil {
            issues.append(.maskFlattened)
        }
        if node.clipsContent == true,
           !(mapping.target == .group && node.absoluteBoundingBox != nil) {
            issues.append(.clippingFlattened)
        }
        let effects = mappedEffects(node.effects)
        if (node.effects ?? []).contains(where: { !isSupportedEffect($0) })
            || hasDuplicateMappableEffectKinds(node.effects) {
            issues.append(.effectsFlattened)
        }
        if let blendMode = node.blendMode,
           mappedBlendMode(blendMode) == nil {
            issues.append(.blendModeFlattened)
        }
        if let opacity = node.opacity,
           !opacity.isFinite || !(0...1).contains(opacity) {
            issues.append(.nodeOpacityFlattened)
        }
        if hasUnsupportedCornerStyle(node, target: mapping.target) {
            issues.append(.cornerRadiusFlattened)
        }
        if solidColor(in: node.strokes) != nil {
            let strokeWeight = resolvedStrokeWeight(node)
            if hasUnsupportedIndividualStrokeWeights(node)
                || strokeWeight == nil
                || !(strokeWeight?.isFinite ?? false)
                || (strokeWeight ?? 0) < Double(ImageEditorShapeContent.minimumStrokeWidth)
                || (strokeWeight ?? 0) > maximumNativeStrokeWidth(for: node, target: mapping.target) {
                issues.append(.strokeWeightFlattened)
            }
        }
        if solidColor(in: node.strokes) != nil,
           hasUnsupportedStrokeStyle(node) {
            issues.append(.strokeStyleFlattened)
        }
        if transformFlattened {
            issues.append(.transformFlattened)
        }
        if let textCase = node.style?.textCase,
           mappedTextCase(textCase) == nil {
            issues.append(.textCaseFlattened)
        }
        if hasUnmappedLineHeight(node.style) {
            issues.append(.textLineHeightFlattened)
        }
        if let paragraphIndent = node.style?.paragraphIndent,
           !paragraphIndent.isFinite
            || paragraphIndent < 0
            || paragraphIndent > Double(ImageEditorTextContent.maximumFirstLineIndent) {
            issues.append(.textParagraphIndentFlattened)
        }
        if let paragraphSpacing = node.style?.paragraphSpacing,
           !paragraphSpacing.isFinite
            || paragraphSpacing < 0
            || paragraphSpacing > Double(ImageEditorTextContent.maximumParagraphSpacing) {
            issues.append(.textParagraphSpacingFlattened)
        }
        if let textAutoResize = node.style?.textAutoResize,
           textAutoResize != "NONE",
           textAutoResize != "WIDTH_AND_HEIGHT",
           textAutoResize != "HEIGHT",
           textAutoResize != "TRUNCATE" {
            issues.append(.textAutoResizeFlattened)
        }
        if let horizontalAlignment = node.style?.textAlignHorizontal,
           mappedTextHorizontalAlignment(horizontalAlignment) == nil {
            issues.append(.textHorizontalAlignmentFlattened)
        }
        if let verticalAlignment = node.style?.textAlignVertical,
           mappedTextVerticalAlignment(verticalAlignment) == nil {
            issues.append(.textVerticalAlignmentFlattened)
        }
        if let decoration = node.style?.textDecoration,
           mappedTextDecoration(decoration) == nil {
            issues.append(.textDecorationFlattened)
        }
        if let letterSpacing = node.style?.letterSpacing,
           !letterSpacing.isFinite
            || letterSpacing < Double(ImageEditorTextContent.minimumCharacterSpacing)
            || letterSpacing > Double(ImageEditorTextContent.maximumCharacterSpacing) {
            issues.append(.textLetterSpacingFlattened)
        }
        if let fontSize = node.style?.fontSize,
           !fontSize.isFinite
            || fontSize < Double(ImageEditorTextContent.minimumFontSize)
            || fontSize > Double(ImageEditorTextContent.maximumFontSize) {
            issues.append(.textFontSizeFlattened)
        }
        if let fontWeight = node.style?.fontWeight,
           mappedTextBold(fontWeight) == nil {
            issues.append(.textFontWeightFlattened)
        }
        let exportPresetMapping = mappedExportPresets(
            node.exportSettings,
            frame: node.absoluteBoundingBox
        )
        if exportPresetMapping.omittedCount > 0 {
            issues.append(.exportSettingsPartiallyPreserved)
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
            sizeConstraints: sizeConstraints(node),
            frame: node.absoluteBoundingBox.map {
                XomoFigmaPlanRect(
                    x: $0.x - rootOrigin.x,
                    y: $0.y - rootOrigin.y,
                    width: max(0, $0.width),
                    height: max(0, $0.height)
                )
            },
            opacity: normalizedNodeOpacity(node.opacity),
            isVisible: node.visible ?? true,
            isLocked: node.locked ?? false,
            blendMode: mappedBlendMode(node.blendMode)?.rawValue,
            solidFill: solidColor(in: node.fills),
            linearGradientFill: supportsGradientFill(node.type)
                ? linearGradient(in: node.fills, bounds: node.absoluteBoundingBox)
                : nil,
            radialGradientFill: supportsGradientFill(node.type)
                ? radialGradient(in: node.fills, bounds: node.absoluteBoundingBox)
                : nil,
            diamondGradientFill: supportsGradientFill(node.type)
                ? diamondGradient(in: node.fills, bounds: node.absoluteBoundingBox)
                : nil,
            angleGradientFill: supportsGradientFill(node.type)
                ? angleGradient(in: node.fills, bounds: node.absoluteBoundingBox)
                : nil,
            solidStroke: solidColor(in: node.strokes),
            strokeWeight: resolvedStrokeWeight(node),
            strokeAlign: node.strokeAlign,
            strokeCap: node.strokeCap,
            strokeJoin: node.strokeJoin,
            strokeMiterLimit: mappedStrokeMiterLimit(node),
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
                    horizontalAlignment: mappedTextHorizontalAlignment(node.style?.textAlignHorizontal)?.rawValue,
                    letterSpacing: node.style?.letterSpacing.flatMap {
                        guard $0.isFinite else { return nil }
                        return min(
                            Double(ImageEditorTextContent.maximumCharacterSpacing),
                            max(Double(ImageEditorTextContent.minimumCharacterSpacing), $0)
                        )
                    },
                    lineHeight: lineHeight(for: node.style),
                    isItalic: node.style?.italic == true,
                    decoration: mappedTextDecoration(node.style?.textDecoration) ?? .none,
                    paragraphIndent: node.style?.paragraphIndent.flatMap {
                        $0.isFinite
                            ? min(
                                Double(ImageEditorTextContent.maximumFirstLineIndent),
                                max(0, $0)
                            )
                            : nil
                    },
                    usesAutoWidthAndHeight: node.style?.textAutoResize == "WIDTH_AND_HEIGHT",
                    usesAutoHeight: node.style?.textAutoResize == "HEIGHT",
                    truncatesOverflow: node.style?.textAutoResize == "TRUNCATE",
                    paragraphSpacing: node.style?.paragraphSpacing.flatMap {
                        $0.isFinite && $0 >= 0
                            ? min($0, Double(ImageEditorTextContent.maximumParagraphSpacing))
                            : nil
                    },
                    textCase: mappedTextCase(node.style?.textCase) ?? .original,
                    verticalAlignment: mappedTextVerticalAlignment(node.style?.textAlignVertical) ?? .top
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
            maskShape: childMaskShape ?? supportedMaskShape(node) ?? .rectangle,
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
            exportPresets: exportPresetMapping.presets,
            stackLayout: nativeStackLayout,
            stackChildLayout: stackChildLayout(node, parentAxis: parentStackAxis),
            isStackLayoutExcluded: node.layoutPositioning == "ABSOLUTE"
        )
    }

    private static func mappedExportPresets(
        _ settings: [XomoFigmaExportSetting]?,
        frame: XomoFigmaRectangle?
    ) -> (presets: [ImageEditorSliceExportPreset], omittedCount: Int) {
        let settings = settings ?? []
        let presets = settings
            .prefix(ImageEditorSlice.maximumExportPresetCount)
            .compactMap { setting -> ImageEditorSliceExportPreset? in
                let format: ImageEditorExportFormat
                switch setting.format {
                case "PNG":
                    format = .png
                case "JPG":
                    format = .jpeg
                case "PDF":
                    format = .pdf
                default:
                    return nil
                }
                let constraint: ImageEditorSliceExportConstraint
                switch setting.constraint.type {
                case "SCALE":
                    constraint = .scale
                case "WIDTH":
                    constraint = .width
                case "HEIGHT":
                    constraint = .height
                default:
                    return nil
                }
                let preset = ImageEditorSliceExportPreset(
                    suffix: setting.suffix,
                    format: format,
                    constraint: format == .pdf ? .scale : constraint,
                    value: format == .pdf ? 1 : setting.constraint.value
                )
                guard let frame else { return nil }
                let presetFrame = CGRect(
                    x: frame.x,
                    y: frame.y,
                    width: frame.width,
                    height: frame.height
                )
                guard preset.resolvedScale(for: presetFrame) != nil else {
                    return nil
                }
                return preset
            }
        return (presets, settings.count - presets.count)
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

    private static func stackChildLayout(
        _ node: XomoFigmaNode,
        parentAxis: ImageEditorStackAxis?
    ) -> ImageEditorStackChildLayout? {
        var grow = CGFloat(node.layoutGrow ?? 0)
        var stretchesCrossAxis = node.layoutAlign == "STRETCH"
        if let parentAxis {
            let primarySizing = parentAxis == .horizontal
                ? node.layoutSizingHorizontal
                : node.layoutSizingVertical
            let crossSizing = parentAxis == .horizontal
                ? node.layoutSizingVertical
                : node.layoutSizingHorizontal
            switch primarySizing {
            case "FILL":
                grow = max(1, grow)
            case "FIXED", "HUG":
                grow = 0
            default:
                break
            }
            switch crossSizing {
            case "FILL":
                stretchesCrossAxis = true
            case "FIXED", "HUG":
                stretchesCrossAxis = false
            default:
                break
            }
        }
        guard grow > 0 || stretchesCrossAxis else { return nil }
        return ImageEditorStackChildLayout(
            grow: grow,
            stretchesCrossAxis: stretchesCrossAxis
        )
    }

    private static func hasUnsupportedStackChildSizing(
        _ node: XomoFigmaNode,
        parentAxis: ImageEditorStackAxis?
    ) -> Bool {
        let hasUnknownModernSizing = [node.layoutSizingHorizontal, node.layoutSizingVertical]
            .compactMap { $0 }
            .contains { $0 != "FIXED" && $0 != "HUG" && $0 != "FILL" }
        if hasUnknownModernSizing {
            return true
        }
        guard let parentAxis else { return false }
        let modernPrimary = parentAxis == .horizontal
            ? node.layoutSizingHorizontal
            : node.layoutSizingVertical
        let modernCross = parentAxis == .horizontal
            ? node.layoutSizingVertical
            : node.layoutSizingHorizontal
        if modernPrimary == nil,
           let grow = node.layoutGrow,
           !grow.isFinite || grow < 0 || grow > Double(ImageEditorStackChildLayout.maximumGrow) {
            return true
        }
        if modernCross == nil,
           let align = node.layoutAlign,
           align != "INHERIT",
           align != "STRETCH" {
            return true
        }
        return false
    }

    private static func hasUnsupportedStackChildPositioning(_ node: XomoFigmaNode) -> Bool {
        guard let positioning = node.layoutPositioning else { return false }
        return positioning != "AUTO" && positioning != "ABSOLUTE"
    }

    private static func isSupportedEffect(_ effect: XomoFigmaEffect) -> Bool {
        guard isMappableEffect(effect) else { return false }
        guard let type = effect.type,
              let radius = effect.radius,
              let maximumRadius = maximumEffectRadius(for: type),
              radius <= maximumRadius
        else { return false }
        if type == "LAYER_BLUR" || type == "BACKGROUND_BLUR" {
            return true
        }
        guard let color = effect.color,
              [color.r, color.g, color.b, color.a ?? 1].allSatisfy({
                  $0.isFinite && (0...1).contains($0)
              }),
              isSupportedPaintBlendMode(effect.blendMode),
              type != "DROP_SHADOW" || effect.showShadowBehindNode != false,
              let offset = effect.offset,
              hypot(offset.x, offset.y) <= maximumShadowDistance(for: type)
        else { return false }
        return (0...maximumShadowSpread).contains(effect.spread ?? 0)
    }

    private static func isMappableEffect(_ effect: XomoFigmaEffect) -> Bool {
        guard effect.visible ?? true else { return false }
        guard let type = effect.type,
              maximumEffectRadius(for: type) != nil,
              let radius = effect.radius,
              radius.isFinite,
              radius >= 0
        else { return false }
        if type == "LAYER_BLUR" || type == "BACKGROUND_BLUR" {
            return true
        }
        guard let color = effect.color,
              [color.r, color.g, color.b, color.a ?? 1].allSatisfy(\.isFinite),
              let offset = effect.offset,
              offset.x.isFinite,
              offset.y.isFinite,
              (effect.spread ?? 0).isFinite
        else { return false }
        return true
    }

    private static func mappedEffects(_ effects: [XomoFigmaEffect]?) -> [XomoFigmaPlanEffect] {
        let mapped = (effects ?? []).compactMap { effect -> XomoFigmaPlanEffect? in
            guard effect.visible ?? true,
                  isMappableEffect(effect),
                  let type = effect.type,
                  let radius = effect.radius
            else { return nil }
            if type == "LAYER_BLUR" || type == "BACKGROUND_BLUR" {
                return XomoFigmaPlanEffect(
                    kind: type == "LAYER_BLUR" ? .layerBlur : .backgroundBlur,
                    color: XomoFigmaPlanColor(red: 0, green: 0, blue: 0, alpha: 0),
                    offsetX: 0,
                    offsetY: 0,
                    radius: min(radius, maximumBlurRadius),
                    spread: 0
                )
            }
            guard let color = effect.color, let offset = effect.offset else { return nil }
            let normalizedOffset = normalizedShadowOffset(offset, type: type)
            return XomoFigmaPlanEffect(
                kind: type == "INNER_SHADOW" ? .innerShadow : .dropShadow,
                color: XomoFigmaPlanColor(
                    red: min(max(color.r, 0), 1),
                    green: min(max(color.g, 0), 1),
                    blue: min(max(color.b, 0), 1),
                    alpha: min(max(color.a ?? 1, 0), 1)
                ),
                offsetX: normalizedOffset.x,
                offsetY: normalizedOffset.y,
                radius: min(radius, type == "INNER_SHADOW" ? maximumInnerShadowBlur : maximumDropShadowBlur),
                spread: min(max(0, effect.spread ?? 0), maximumShadowSpread)
            )
        }
        var retainedKinds = Set<String>()
        return Array(
            mapped.reversed().filter { effect in
                retainedKinds.insert(effect.kind.rawValue).inserted
            }.reversed()
        )
    }

    private static func hasDuplicateMappableEffectKinds(
        _ effects: [XomoFigmaEffect]?
    ) -> Bool {
        var seenKinds = Set<String>()
        for effect in effects ?? [] {
            guard effect.visible ?? true,
                  isMappableEffect(effect),
                  let type = effect.type,
                  let kind = mappedEffectKind(for: type)
            else { continue }
            if !seenKinds.insert(kind.rawValue).inserted {
                return true
            }
        }
        return false
    }

    private static func mappedEffectKind(for type: String) -> XomoFigmaPlanEffectKind? {
        switch type {
        case "DROP_SHADOW": return .dropShadow
        case "INNER_SHADOW": return .innerShadow
        case "LAYER_BLUR": return .layerBlur
        case "BACKGROUND_BLUR": return .backgroundBlur
        default: return nil
        }
    }

    private static let maximumDropShadowBlur = 30.0
    private static let maximumInnerShadowBlur = 40.0
    private static let maximumShadowSpread = 24.0
    private static let maximumBlurRadius = 256.0
    private static let maximumDropShadowDistance = 80.0
    private static let maximumInnerShadowDistance = 48.0

    private static func maximumEffectRadius(for type: String) -> Double? {
        switch type {
        case "DROP_SHADOW": return maximumDropShadowBlur
        case "INNER_SHADOW": return maximumInnerShadowBlur
        case "LAYER_BLUR", "BACKGROUND_BLUR": return maximumBlurRadius
        default: return nil
        }
    }

    private static func maximumShadowDistance(for type: String) -> Double {
        type == "INNER_SHADOW" ? maximumInnerShadowDistance : maximumDropShadowDistance
    }

    private static func normalizedShadowOffset(
        _ offset: XomoFigmaEffectOffset,
        type: String
    ) -> XomoFigmaEffectOffset {
        let distance = hypot(offset.x, offset.y)
        let maximumDistance = maximumShadowDistance(for: type)
        guard distance > maximumDistance, distance > 0 else { return offset }
        let scale = maximumDistance / distance
        return XomoFigmaEffectOffset(x: offset.x * scale, y: offset.y * scale)
    }

    private static func stackAxis(_ node: XomoFigmaNode) -> ImageEditorStackAxis? {
        switch node.layoutMode {
        case "HORIZONTAL":
            return .horizontal
        case "VERTICAL":
            return .vertical
        default:
            return nil
        }
    }

    private static func stackLayout(_ node: XomoFigmaNode) -> ImageEditorStackLayout? {
        guard let axis = stackAxis(node) else { return nil }
        return ImageEditorStackLayout(
            axis: axis,
            spacing: CGFloat(node.itemSpacing ?? 0),
            paddingTop: CGFloat(node.paddingTop ?? 0),
            paddingRight: CGFloat(node.paddingRight ?? 0),
            paddingBottom: CGFloat(node.paddingBottom ?? 0),
            paddingLeft: CGFloat(node.paddingLeft ?? 0),
            primaryAlignment: primaryAlignment(node.primaryAxisAlignItems),
            crossAlignment: crossAlignment(node.counterAxisAlignItems),
            primarySizingMode: stackSizingMode(
                modern: axis == .horizontal
                    ? node.layoutSizingHorizontal
                    : node.layoutSizingVertical,
                legacy: node.primaryAxisSizingMode
            ),
            crossSizingMode: stackSizingMode(
                modern: axis == .horizontal
                    ? node.layoutSizingVertical
                    : node.layoutSizingHorizontal,
                legacy: node.counterAxisSizingMode
            ),
            wrapMode: node.layoutWrap == "WRAP" ? .wrap : .noWrap,
            counterSpacing: CGFloat(node.counterAxisSpacing ?? 0),
            crossTrackAlignment: crossTrackAlignment(
                node.counterAxisAlignContent,
                axis: axis,
                wrapMode: node.layoutWrap == "WRAP" ? .wrap : .noWrap
            )
        )
    }

    private static func resolvedStrokeWeight(_ node: XomoFigmaNode) -> Double? {
        guard let weights = node.individualStrokeWeights else { return node.strokeWeight }
        let values = [weights.top, weights.right, weights.bottom, weights.left]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return node.strokeWeight }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func hasUnsupportedIndividualStrokeWeights(_ node: XomoFigmaNode) -> Bool {
        guard let weights = node.individualStrokeWeights else { return false }
        let values = [weights.top, weights.right, weights.bottom, weights.left]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 }),
              let minimum = values.min(),
              let maximum = values.max()
        else { return true }
        return maximum - minimum > 0.001
    }

    private static func sizingMode(_ value: String?) -> ImageEditorStackSizingMode {
        value == "AUTO" ? .hug : .fixed
    }

    private static func stackSizingMode(
        modern: String?,
        legacy: String?
    ) -> ImageEditorStackSizingMode {
        switch modern {
        case "HUG": return .hug
        case "FIXED": return .fixed
        default: return sizingMode(legacy)
        }
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

    private static func hasUnsupportedAutoLayout(
        _ node: XomoFigmaNode,
        parentStackAxis: ImageEditorStackAxis?
    ) -> Bool {
        let usesUnsupportedWrap = hasUnsupportedStackWrap(node)
        let usesUnsupportedModernSizing = [
            node.layoutSizingHorizontal,
            node.layoutSizingVertical
        ]
            .compactMap { $0 }
            .contains {
                $0 != "FIXED"
                    && $0 != "HUG"
                    && !($0 == "FILL" && parentStackAxis != nil)
            }
        let usesUnsupportedLegacySizing = hasUnsupportedLegacyStackSizing(node)
        let supportsSpaceBetweenTracks = node.layoutMode == "HORIZONTAL"
            && node.layoutWrap == "WRAP"
            && node.counterAxisAlignContent == "SPACE_BETWEEN"
        let usesUnsupportedTrackDistribution = node.counterAxisAlignContent != nil
            && node.counterAxisAlignContent != "AUTO"
            && !supportsSpaceBetweenTracks
        let usesUnsupportedBaseline = node.counterAxisAlignItems == "BASELINE"
            && node.layoutMode != "HORIZONTAL"
        return usesUnsupportedWrap
            || usesUnsupportedModernSizing
            || usesUnsupportedLegacySizing
            || usesUnsupportedTrackDistribution
            || usesUnsupportedBaseline
            || hasUnsupportedStackAlignment(node)
            || hasUnsupportedStackGeometry(node)
    }

    private static func hasUnsupportedStackWrap(_ node: XomoFigmaNode) -> Bool {
        guard let wrap = node.layoutWrap else { return false }
        if wrap == "WRAP" {
            return node.layoutMode != "HORIZONTAL"
        }
        return wrap != "NO_WRAP"
    }

    private static func hasUnsupportedLegacyStackSizing(_ node: XomoFigmaNode) -> Bool {
        guard let axis = stackAxis(node) else { return false }
        let modernPrimary = axis == .horizontal
            ? node.layoutSizingHorizontal
            : node.layoutSizingVertical
        let modernCross = axis == .horizontal
            ? node.layoutSizingVertical
            : node.layoutSizingHorizontal
        if modernPrimary == nil,
           let legacyPrimary = node.primaryAxisSizingMode,
           legacyPrimary != "FIXED",
           legacyPrimary != "AUTO" {
            return true
        }
        if modernCross == nil,
           let legacyCross = node.counterAxisSizingMode,
           legacyCross != "FIXED",
           legacyCross != "AUTO" {
            return true
        }
        return false
    }

    private static func hasUnsupportedStackAlignment(_ node: XomoFigmaNode) -> Bool {
        if let primary = node.primaryAxisAlignItems,
           !["MIN", "CENTER", "MAX", "SPACE_BETWEEN"].contains(primary) {
            return true
        }
        if let cross = node.counterAxisAlignItems,
           !["MIN", "CENTER", "MAX", "BASELINE"].contains(cross) {
            return true
        }
        return false
    }

    private static func hasUnsupportedStackGeometry(_ node: XomoFigmaNode) -> Bool {
        if let spacing = node.itemSpacing,
           !spacing.isFinite
            || spacing < Double(ImageEditorStackLayout.minimumSpacing)
            || spacing > Double(ImageEditorStackLayout.maximumSpacing) {
            return true
        }
        if let counterSpacing = node.counterAxisSpacing,
           !counterSpacing.isFinite
            || counterSpacing < 0
            || counterSpacing > Double(ImageEditorStackLayout.maximumSpacing) {
            return true
        }
        return [node.paddingTop, node.paddingRight, node.paddingBottom, node.paddingLeft]
            .compactMap { $0 }
            .contains {
                !$0.isFinite
                    || $0 < 0
                    || $0 > Double(ImageEditorStackLayout.maximumPadding)
            }
    }

    private static func hasUnpreservedStackConstraints(_ node: XomoFigmaNode) -> Bool {
        [node.minWidth, node.maxWidth, node.minHeight, node.maxHeight]
            .contains { $0 != nil }
    }

    private static func sizeConstraints(_ node: XomoFigmaNode) -> XomoFigmaSizeConstraints? {
        let constraints = XomoFigmaSizeConstraints(
            minWidth: node.minWidth,
            maxWidth: node.maxWidth,
            minHeight: node.minHeight,
            maxHeight: node.maxHeight
        )
        return constraints.isEmpty ? nil : constraints
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
        let hasDisabledPaint = ((node.fills ?? []) + (node.strokes ?? [])).contains {
            $0.visible == false
        }
        let hasUnsupportedSolidPaint = (visiblePaints + visibleStrokes).contains {
            $0.type == "SOLID" && !isSupportedSolidPaint($0)
        }
        let hasUnsupportedPaintBlendMode = (visiblePaints + visibleStrokes).contains {
            !isSupportedPaintBlendMode($0.blendMode)
        }
        let hasUnsupportedGradientColor = visiblePaints.contains { paint in
            editableGradientPaintTypes.contains(paint.type)
                && !hasSupportedGradientColorComponents(paint)
        }
        let hasUnsupportedGradientStopPosition = visiblePaints.contains { paint in
            editableGradientPaintTypes.contains(paint.type)
                && !hasSupportedGradientStopPositions(paint)
        }
        let hasUnsupportedGradientCenter = visiblePaints.contains { paint in
            editableGradientPaintTypes.contains(paint.type)
                && !hasSupportedGradientCenter(paint)
        }
        let hasUnsupportedGradientScale = visiblePaints.contains { paint in
            guard paint.type != "GRADIENT_ANGULAR",
                  editableGradientPaintTypes.contains(paint.type),
                  let scale = rawGradientScale(paint, bounds: node.absoluteBoundingBox)
            else { return false }
            return !gradientScaleRange.contains(scale)
        }
        let hasUnsupportedFill = visiblePaints.contains { paint in
            if paint.type == "SOLID" { return false }
            guard allowsGradientFill else { return true }
            switch paint.type {
            case "GRADIENT_LINEAR":
                return linearGradient(in: [paint], bounds: node.absoluteBoundingBox) == nil
            case "GRADIENT_RADIAL":
                return radialGradient(in: [paint], bounds: node.absoluteBoundingBox) == nil
            case "GRADIENT_DIAMOND":
                return diamondGradient(in: [paint], bounds: node.absoluteBoundingBox) == nil
            case "GRADIENT_ANGULAR":
                return angleGradient(in: [paint], bounds: node.absoluteBoundingBox) == nil
            default:
                return true
            }
        }
        if hasDisabledPaint
            || visiblePaints.count > 1
            || hasUnsupportedSolidPaint
            || hasUnsupportedPaintBlendMode
            || hasUnsupportedGradientColor
            || hasUnsupportedGradientStopPosition
            || hasUnsupportedGradientCenter
            || hasUnsupportedGradientScale
            || hasUnsupportedFill
            || visibleStrokes.count > 1
            || visibleStrokes.contains(where: { $0.type != "SOLID" }) {
            issues.append(.unsupportedPaint)
        }
    }

    private static func isSupportedSolidPaint(_ paint: XomoFigmaPaint) -> Bool {
        guard let color = paint.color else { return false }
        let components = [color.r, color.g, color.b, color.a ?? 1, paint.opacity ?? 1]
        return components.allSatisfy { $0.isFinite && (0...1).contains($0) }
    }

    private static func isSupportedPaintBlendMode(_ blendMode: String?) -> Bool {
        blendMode == nil || blendMode == "NORMAL"
    }

    private static func hasSupportedGradientColorComponents(_ paint: XomoFigmaPaint) -> Bool {
        guard validUnitValue(paint.opacity ?? 1) != nil,
              let stops = paint.gradientStops
        else { return false }
        return stops.allSatisfy { stop in
            [stop.color.r, stop.color.g, stop.color.b, stop.color.a ?? 1].allSatisfy {
                validUnitValue($0) != nil
            }
        }
    }

    private static func hasSupportedGradientStopPositions(_ paint: XomoFigmaPaint) -> Bool {
        guard let stops = paint.gradientStops,
              (2...ImageEditorGradientFillContent.maximumColorStopCount).contains(stops.count),
              stops.allSatisfy({ $0.position.isFinite && (0...1).contains($0.position) }),
              abs(stops[0].position) <= 0.001,
              abs((stops.last?.position ?? 0) - 1) <= 0.001
        else { return false }
        return zip(stops, stops.dropFirst()).allSatisfy { pair in
            pair.0.position <= pair.1.position
        }
    }

    private static func hasSupportedGradientCenter(_ paint: XomoFigmaPaint) -> Bool {
        guard let handles = paint.gradientHandlePositions,
              handles.count == 3,
              handles.allSatisfy(\.isFinite)
        else { return false }
        let centerX: Double
        let centerY: Double
        if paint.type == "GRADIENT_RADIAL"
            || paint.type == "GRADIENT_DIAMOND"
            || paint.type == "GRADIENT_ANGULAR" {
            centerX = handles[0].x
            centerY = handles[0].y
        } else {
            centerX = (handles[0].x + handles[1].x) / 2
            centerY = (handles[0].y + handles[1].y) / 2
        }
        return gradientCenterRange.contains(centerX) && gradientCenterRange.contains(centerY)
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
            let sourceAlpha = normalizedColorComponent(color.a ?? 1, fallback: 1)
                * normalizedColorComponent(paint.opacity ?? 1, fallback: 1)
            let destinationAlpha = normalizedColorComponent(destination.alpha, fallback: 0)
            let outputAlpha = sourceAlpha + destinationAlpha * (1 - sourceAlpha)
            guard outputAlpha > 0 else {
                return XomoFigmaPlanColor(red: 0, green: 0, blue: 0, alpha: 0)
            }
            let sourceRed = normalizedColorComponent(color.r, fallback: 0)
            let sourceGreen = normalizedColorComponent(color.g, fallback: 0)
            let sourceBlue = normalizedColorComponent(color.b, fallback: 0)
            let destinationWeight = destinationAlpha * (1 - sourceAlpha)
            return XomoFigmaPlanColor(
                red: (sourceRed * sourceAlpha + destination.red * destinationWeight) / outputAlpha,
                green: (sourceGreen * sourceAlpha + destination.green * destinationWeight) / outputAlpha,
                blue: (sourceBlue * sourceAlpha + destination.blue * destinationWeight) / outputAlpha,
                alpha: outputAlpha
            )
        }
    }

    nonisolated private static func normalizedColorComponent(_ value: Double, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, 0), 1)
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
        guard angle.isFinite, scale.isFinite else { return nil }

        return XomoFigmaPlanLinearGradient(
            startColor: resolvedStops.startColor,
            endColor: resolvedStops.endColor,
            angle: angle,
            scale: normalizedGradientScale(scale),
            centerX: normalizedGradientCenter((startHandle.x + endHandle.x) / 2),
            centerY: normalizedGradientCenter((startHandle.y + endHandle.y) / 2),
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
                <= firstLength * secondLength * circularGradientTolerance
        else { return nil }

        let referenceRadius = hypot(bounds.width / 2, bounds.height / 2)
        let radius = (firstLength + secondLength) / 2
        let scale = radius / referenceRadius
        guard scale.isFinite else { return nil }

        return XomoFigmaPlanRadialGradient(
            startColor: resolvedStops.startColor,
            endColor: resolvedStops.endColor,
            scale: normalizedGradientScale(scale),
            centerX: normalizedGradientCenter(center.x),
            centerY: normalizedGradientCenter(center.y),
            opacity: resolvedStops.opacity,
            colorStops: resolvedStops.colorStops
        )
    }

    private static func diamondGradient(
        in paints: [XomoFigmaPaint]?,
        bounds: XomoFigmaRectangle?
    ) -> XomoFigmaPlanDiamondGradient? {
        guard let paint = (paints ?? []).first(where: {
            ($0.visible ?? true) && $0.type == "GRADIENT_DIAMOND"
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
                <= firstLength * secondLength * circularGradientTolerance
        else { return nil }

        let referenceRadius = hypot(bounds.width / 2, bounds.height / 2)
        let scale = ((firstLength + secondLength) / 2) / referenceRadius
        let angle = atan2(firstAxis.y, firstAxis.x) * 180 / .pi
        guard scale.isFinite, angle.isFinite else { return nil }

        return XomoFigmaPlanDiamondGradient(
            startColor: resolvedStops.startColor,
            endColor: resolvedStops.endColor,
            angle: angle,
            scale: normalizedGradientScale(scale),
            centerX: normalizedGradientCenter(center.x),
            centerY: normalizedGradientCenter(center.y),
            opacity: resolvedStops.opacity,
            colorStops: resolvedStops.colorStops
        )
    }

    private static func angleGradient(
        in paints: [XomoFigmaPaint]?,
        bounds: XomoFigmaRectangle?
    ) -> XomoFigmaPlanAngleGradient? {
        guard let paint = (paints ?? []).first(where: {
            ($0.visible ?? true) && $0.type == "GRADIENT_ANGULAR"
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
        let orientation = firstAxis.x * secondAxis.y - firstAxis.y * secondAxis.x
        // Xomo's Angle model is a clockwise circular sweep. A stretched,
        // skewed, or mirrored Figma basis would change that sweep geometry,
        // so keep those paints on the explicit compatibility fallback path.
        guard firstLength.isFinite,
              secondLength.isFinite,
              firstLength >= minimumGradientAxisLength,
              secondLength >= minimumGradientAxisLength,
              abs(firstLength - secondLength) <= maximumLength * circularGradientTolerance,
              abs(firstAxis.x * secondAxis.x + firstAxis.y * secondAxis.y)
                <= firstLength * secondLength * circularGradientTolerance,
              orientation > 0
        else { return nil }

        let angle = atan2(firstAxis.y, firstAxis.x) * 180 / .pi
        guard angle.isFinite else { return nil }
        return XomoFigmaPlanAngleGradient(
            startColor: resolvedStops.startColor,
            endColor: resolvedStops.endColor,
            angle: angle,
            centerX: normalizedGradientCenter(center.x),
            centerY: normalizedGradientCenter(center.y),
            opacity: resolvedStops.opacity,
            colorStops: resolvedStops.colorStops
        )
    }

    private static let minimumGradientAxisLength = 0.001
    private static let circularGradientTolerance = 0.001
    private static let gradientCenterRange = -4.0...5.0
    private static let gradientScaleRange = 0.25...4.0
    private static let editableGradientPaintTypes: Set<String> = [
        "GRADIENT_LINEAR",
        "GRADIENT_RADIAL",
        "GRADIENT_DIAMOND",
        "GRADIENT_ANGULAR"
    ]

    private static func normalizedGradientCenter(_ value: Double) -> Double {
        min(max(value, gradientCenterRange.lowerBound), gradientCenterRange.upperBound)
    }

    private static func normalizedGradientScale(_ value: Double) -> Double {
        min(max(value, gradientScaleRange.lowerBound), gradientScaleRange.upperBound)
    }

    private static func rawGradientScale(
        _ paint: XomoFigmaPaint,
        bounds: XomoFigmaRectangle?
    ) -> Double? {
        guard let bounds,
              bounds.width.isFinite,
              bounds.height.isFinite,
              bounds.width > 0,
              bounds.height > 0,
              let handles = paint.gradientHandlePositions,
              handles.count == 3,
              handles.allSatisfy(\.isFinite)
        else { return nil }

        let center = handles[0]
        let firstX = (handles[1].x - center.x) * bounds.width
        let firstY = (handles[1].y - center.y) * bounds.height
        let firstLength = hypot(firstX, firstY)
        guard firstLength.isFinite else { return nil }

        if paint.type == "GRADIENT_LINEAR" {
            guard firstLength > minimumGradientAxisLength else { return nil }
            let angle = atan2(firstY, firstX)
            let span = abs(cos(angle)) * bounds.width + abs(sin(angle)) * bounds.height
            let scale = firstLength / span
            return scale.isFinite ? scale : nil
        }

        guard paint.type == "GRADIENT_RADIAL" || paint.type == "GRADIENT_DIAMOND" else {
            return nil
        }
        let secondX = (handles[2].x - center.x) * bounds.width
        let secondY = (handles[2].y - center.y) * bounds.height
        let secondLength = hypot(secondX, secondY)
        guard secondLength.isFinite,
              firstLength >= minimumGradientAxisLength,
              secondLength >= minimumGradientAxisLength
        else { return nil }
        let referenceRadius = hypot(bounds.width / 2, bounds.height / 2)
        let scale = ((firstLength + secondLength) / 2) / referenceRadius
        return scale.isFinite ? scale : nil
    }

    private static func resolvedGradientStops(
        _ paint: XomoFigmaPaint
    ) -> ResolvedGradientStops? {
        guard let stops = paint.gradientStops,
              (2...ImageEditorGradientFillContent.maximumColorStopCount).contains(stops.count),
              stops.allSatisfy({ $0.position.isFinite }),
              zip(stops, stops.dropFirst()).allSatisfy({ pair in
                  pair.0.position <= pair.1.position
              })
        else { return nil }

        let paintOpacity = normalizedColorComponent(paint.opacity ?? 1, fallback: 1)
        let colors = stops.compactMap(normalizedGradientStopColor)
        guard colors.count == stops.count,
              let first = colors.first,
              let last = colors.last
        else { return nil }
        let lastIndex = stops.index(before: stops.endIndex)
        let normalizedPositions = stops.indices.map { index in
            if index == stops.startIndex { return 0.0 }
            if index == lastIndex { return 1.0 }
            return normalizedColorComponent(stops[index].position, fallback: 0)
        }

        return ResolvedGradientStops(
            startColor: first,
            endColor: last,
            opacity: paintOpacity,
            colorStops: zip(normalizedPositions, colors).map { pair in
                let (position, color) = pair
                return XomoFigmaPlanGradientStop(
                    position: position,
                    color: color
                )
            }
        )
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

    nonisolated private static func normalizedGradientStopColor(
        _ stop: XomoFigmaGradientStop
    ) -> XomoFigmaPlanColor? {
        guard stop.position.isFinite else { return nil }
        return XomoFigmaPlanColor(
            red: normalizedColorComponent(stop.color.r, fallback: 0),
            green: normalizedColorComponent(stop.color.g, fallback: 0),
            blue: normalizedColorComponent(stop.color.b, fallback: 0),
            alpha: normalizedColorComponent(stop.color.a ?? 1, fallback: 1)
        )
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

    static func characters(_ characters: String, applying textCase: String?) -> String {
        (mappedTextCase(textCase) ?? .original).applying(to: characters)
    }

    static func mappedTextCase(_ textCase: String?) -> ImageEditorTextCase? {
        switch textCase {
        case nil, "ORIGINAL":
            .original
        case "UPPER":
            .uppercase
        case "LOWER":
            .lowercase
        case "TITLE":
            .titleCase
        case "SMALL_CAPS":
            .smallCaps
        default:
            nil
        }
    }

    static func mappedTextVerticalAlignment(_ alignment: String?) -> ImageEditorTextVerticalAlignment? {
        switch alignment {
        case nil, "TOP": .top
        case "CENTER": .center
        case "BOTTOM": .bottom
        default: nil
        }
    }

    static func mappedTextHorizontalAlignment(_ alignment: String?) -> ImageEditorTextAlignment? {
        switch alignment {
        case nil, "LEFT": .left
        case "CENTER": .center
        case "RIGHT": .right
        case "JUSTIFIED": .justified
        default: nil
        }
    }

    static func mappedTextDecoration(_ decoration: String?) -> XomoFigmaPlanTextDecoration? {
        switch decoration {
        case nil, "NONE": XomoFigmaPlanTextDecoration.none
        case "UNDERLINE": .underline
        case "STRIKETHROUGH": .strikethrough
        default: nil
        }
    }

    static func mappedTextBold(_ fontWeight: Double?) -> Bool? {
        guard let fontWeight else { return false }
        guard fontWeight.isFinite else { return nil }
        if fontWeight == regularFontWeight { return false }
        if fontWeight == boldFontWeight { return true }
        return nil
    }

    static func approximatedTextBold(_ fontWeight: Double?) -> Bool {
        mappedTextBold(fontWeight) ?? ((fontWeight ?? regularFontWeight) >= approximateBoldThreshold)
    }

    static func lineHeight(for style: XomoFigmaTypeStyle?) -> Double? {
        guard let style else { return nil }
        if let pixels = style.lineHeightPx,
           pixels.isFinite,
           pixels >= 0 {
            return pixels
        }
        guard let fontSize = style.fontSize,
              fontSize.isFinite,
              fontSize > 0
        else { return nil }
        let percent = style.lineHeightPercentFontSize.flatMap {
            $0.isFinite && $0 >= 0 ? $0 : nil
        } ?? (style.lineHeightUnit == "FONT_SIZE_%"
            ? style.lineHeightPercent.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
            : nil)
        return percent.map { fontSize * $0 / 100 }
    }

    private static func hasUnmappedLineHeight(_ style: XomoFigmaTypeStyle?) -> Bool {
        guard let style else { return false }
        let exposesLineHeight = style.lineHeightPx != nil
            || style.lineHeightPercentFontSize != nil
            || style.lineHeightPercent != nil
            || style.lineHeightUnit != nil
        guard exposesLineHeight else { return false }
        guard let mappedLineHeight = lineHeight(for: style) else { return true }
        guard let fontSize = style.fontSize,
              fontSize.isFinite,
              fontSize > 0
        else { return false }
        let lineSpacing = mappedLineHeight - fontSize
        return lineSpacing < 0
            || lineSpacing > Double(ImageEditorTextContent.maximumLineSpacing)
    }

    private static func hasUnsupportedCornerStyle(
        _ node: XomoFigmaNode,
        target: XomoFigmaNodeTargetKind?
    ) -> Bool {
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
        let geometryMaximum = node.absoluteBoundingBox.map {
            max(0, min($0.width, $0.height) / 2)
        }
        let exceedsGeometryMaximum = target == .rectangle
            && geometryMaximum.map { maximum in
                (uniformCornerRadius(node) ?? 0) > maximum
                    || radii.contains(where: { $0.isFinite && $0 > maximum })
            } ?? false
        return hasInvalidIndependentRadii
            || hasInvalidUniformRadius
            || hasInvalidCornerSmoothing
            || hasApproximatedCornerSmoothing
            || exceedsGeometryMaximum
    }

    private static func maximumNativeStrokeWidth(
        for node: XomoFigmaNode,
        target: XomoFigmaNodeTargetKind?
    ) -> Double {
        let editorMaximum = Double(ImageEditorShapeContent.maximumStrokeWidth)
        guard target == .rectangle || target == .ellipse,
              let bounds = node.absoluteBoundingBox,
              bounds.width.isFinite,
              bounds.height.isFinite
        else { return editorMaximum }
        let geometryMaximum = min(bounds.width, bounds.height) / 2
        return max(
            Double(ImageEditorShapeContent.minimumStrokeWidth),
            min(editorMaximum, geometryMaximum)
        )
    }

    private static func normalizedNodeOpacity(_ opacity: Double?) -> Double {
        guard let opacity else { return 1 }
        guard opacity.isFinite else { return 1 }
        return min(max(opacity, 0), 1)
    }

    private static func hasUnsupportedStrokeStyle(_ node: XomoFigmaNode) -> Bool {
        let supportedAlignments = ["INSIDE", "CENTER", "OUTSIDE"]
        let supportedCaps = [
            "NONE", "ROUND", "SQUARE", "ARROW_LINES", "ARROW_EQUILATERAL",
            "DIAMOND_FILLED", "TRIANGLE_FILLED", "CIRCLE_FILLED"
        ]
        let supportedJoins = ["MITER", "ROUND", "BEVEL"]
        if let alignment = node.strokeAlign?.uppercased(),
           !supportedAlignments.contains(alignment) {
            return true
        }
        if let cap = node.strokeCap?.uppercased(),
           !supportedCaps.contains(cap) {
            return true
        }
        if let join = node.strokeJoin?.uppercased(),
           !supportedJoins.contains(join) {
            return true
        }
        if node.strokeJoin?.uppercased() == "MITER",
           node.strokeMiterAngle != nil,
           mappedStrokeMiterLimit(node) == nil {
            return true
        }
        if let dashes = node.strokeDashes,
           !dashes.isEmpty,
           dashes.count < 2 || dashes.contains(where: { !$0.isFinite || $0 <= 0 }) {
            return true
        }
        return false
    }

    private static func mappedStrokeMiterLimit(_ node: XomoFigmaNode) -> Double? {
        guard node.strokeJoin?.uppercased() == "MITER",
              let angle = node.strokeMiterAngle,
              angle.isFinite,
              angle > 0,
              angle <= 180
        else { return nil }
        let limit = 1 / sin(angle * .pi / 360)
        guard limit.isFinite,
              limit >= Double(ImageEditorShapeContent.minimumStrokeMiterLimit),
              limit <= Double(ImageEditorShapeContent.maximumStrokeMiterLimit)
        else { return nil }
        return limit
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
    var locked: Bool?
    var children: [XomoFigmaNode]?
    var absoluteBoundingBox: XomoFigmaRectangle?
    var characters: String?
    var style: XomoFigmaTypeStyle?
    var fills: [XomoFigmaPaint]?
    var strokes: [XomoFigmaPaint]?
    var strokeWeight: Double?
    var individualStrokeWeights: XomoFigmaIndividualStrokeWeights?
    var strokeAlign: String?
    var strokeCap: String?
    var strokeJoin: String?
    var strokeMiterAngle: Double?
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
    var layoutSizingHorizontal: String?
    var layoutSizingVertical: String?
    var layoutPositioning: String?
    var layoutGrow: Double?
    var layoutAlign: String?
    var minWidth: Double?
    var maxWidth: Double?
    var minHeight: Double?
    var maxHeight: Double?
    var size: XomoFigmaSize?
    var relativeTransform: [[Double]]?
    var fillGeometry: [XomoFigmaPath]?
    var strokeGeometry: [XomoFigmaPath]?
    var boundVariables: XomoFigmaBoundVariables?
    var componentProperties: [String: XomoFigmaComponentProperty]?
    var exportSettings: [XomoFigmaExportSetting]?
}

struct XomoFigmaIndividualStrokeWeights: Decodable {
    var top: Double
    var right: Double
    var bottom: Double
    var left: Double
}

struct XomoFigmaExportSetting: Decodable {
    var suffix: String
    var format: String
    var constraint: XomoFigmaExportConstraint
}

struct XomoFigmaExportConstraint: Decodable {
    var type: String
    var value: Double
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
    var textAlignVertical: String?
    var letterSpacing: Double?
    var lineHeightPx: Double?
    var lineHeightPercent: Double?
    var lineHeightPercentFontSize: Double?
    var lineHeightUnit: String?
    var italic: Bool?
    var textDecoration: String?
    var paragraphIndent: Double?
    var textAutoResize: String?
    var paragraphSpacing: Double?
    var textCase: String?
}

struct XomoFigmaPaint: Decodable {
    var type: String
    var visible: Bool?
    var opacity: Double?
    var blendMode: String?
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
    var blendMode: String?
    var showShadowBehindNode: Bool?
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
