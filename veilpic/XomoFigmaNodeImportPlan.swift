import Foundation

enum XomoFigmaNodeTargetKind: String, CaseIterable, Sendable {
    case group
    case text
    case rectangle
    case ellipse
    case vector
    case image
    case imagePlaceholder
    case slice

    var localizationKey: String {
        "xomo.figma.node.target.\(rawValue)"
    }
}

enum XomoFigmaComponentRole: String, Codable, Equatable, Sendable {
    case component = "COMPONENT"
    case componentSet = "COMPONENT_SET"
    case instance = "INSTANCE"
}

struct XomoFigmaComponentPreferredValue: Codable, Equatable, Hashable, Sendable {
    var key: String
    var name: String
}

struct XomoFigmaComponentProperty: Codable, Equatable, Hashable, Sendable {
    var type: String
    var value: String
    var preferredValues: [XomoFigmaComponentPreferredValue]

    init(
        type: String,
        value: String,
        preferredValues: [XomoFigmaComponentPreferredValue] = []
    ) {
        self.type = type
        self.value = value
        self.preferredValues = preferredValues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        value = try container.decode(String.self, forKey: .value)
        preferredValues = try container.decodeIfPresent(
            [XomoFigmaComponentPreferredValue].self,
            forKey: .preferredValues
        ) ?? []
    }
}

enum XomoFigmaNodeMappingFidelity: String, CaseIterable, Sendable {
    case exact
    case partial
    case unsupported

    var localizationKey: String {
        "xomo.figma.node.fidelity.\(rawValue)"
    }
}

enum XomoFigmaNodeMappingIssue: String, CaseIterable, Sendable {
    case missingBounds
    case unsupportedNodeType
    case unsupportedPaint
    case imageAssetPending
    case imageAssetUnavailable
    case imageFillTransformPreserved
    case imageFiltersPreserved
    case vectorGeometryMissing
    case vectorGeometryUnsupported
    case booleanOperationFlattened
    case componentSemanticsFlattened
    case autoLayoutFlattened
    case maskFlattened
    case clippingFlattened
    case effectsFlattened
    case blendModeFlattened
    case cornerRadiusFlattened
    case transformFlattened
    case variableBindingPreserved
    case exportSettingsPartiallyPreserved

    var localizationKey: String {
        "xomo.figma.node.issue.\(rawValue)"
    }
}

struct XomoFigmaVariableBinding: Codable, Equatable, Hashable, Sendable, Identifiable {
    var field: String
    var variableID: String

    var id: String { "\(field):\(variableID)" }
}

struct XomoFigmaPlanRect: Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct XomoFigmaPlanColor: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
}

struct XomoFigmaPlanGradientStop: Equatable, Sendable {
    var position: Double
    var color: XomoFigmaPlanColor
}

struct XomoFigmaPlanLinearGradient: Equatable, Sendable {
    var startColor: XomoFigmaPlanColor
    var endColor: XomoFigmaPlanColor
    var angle: Double
    var scale: Double
    var centerX: Double
    var centerY: Double
    var opacity: Double
    var colorStops: [XomoFigmaPlanGradientStop]
}

struct XomoFigmaPlanRadialGradient: Equatable, Sendable {
    var startColor: XomoFigmaPlanColor
    var endColor: XomoFigmaPlanColor
    var scale: Double
    var centerX: Double
    var centerY: Double
    var opacity: Double
    var colorStops: [XomoFigmaPlanGradientStop]
}

struct XomoFigmaPlanSize: Codable, Equatable, Sendable {
    var width: Double
    var height: Double
}

struct XomoFigmaPlanTransform: Codable, Equatable, Sendable {
    var m11: Double
    var m12: Double
    var translationX: Double
    var m21: Double
    var m22: Double
    var translationY: Double

    init?(_ rows: [[Double]]?) {
        let maximumMagnitude = 1_000_000.0
        guard let rows,
              rows.count == 2,
              rows[0].count == 3,
              rows[1].count == 3,
              rows.joined().allSatisfy({ $0.isFinite && abs($0) <= maximumMagnitude })
        else { return nil }
        m11 = rows[0][0]
        m12 = rows[0][1]
        translationX = rows[0][2]
        m21 = rows[1][0]
        m22 = rows[1][1]
        translationY = rows[1][2]
    }
}

struct XomoFigmaPlanText: Equatable, Sendable {
    var characters: String
    var fontFamily: String?
    var fontSize: Double?
    var fontWeight: Double?
    var horizontalAlignment: String?
}

struct XomoFigmaImageAsset: Equatable, Sendable {
    var data: Data
    var pixelSize: XomoFigmaPlanSize
}

struct XomoFigmaPlanImageFilters: Codable, Equatable, Sendable {
    var exposure: Double
    var contrast: Double
    var saturation: Double
    var temperature: Double
    var tint: Double
    var highlights: Double
    var shadows: Double

    init(
        exposure: Double? = nil,
        contrast: Double? = nil,
        saturation: Double? = nil,
        temperature: Double? = nil,
        tint: Double? = nil,
        highlights: Double? = nil,
        shadows: Double? = nil
    ) {
        self.exposure = Self.normalized(exposure)
        self.contrast = Self.normalized(contrast)
        self.saturation = Self.normalized(saturation)
        self.temperature = Self.normalized(temperature)
        self.tint = Self.normalized(tint)
        self.highlights = Self.normalized(highlights)
        self.shadows = Self.normalized(shadows)
    }

    var isIdentity: Bool {
        exposure == 0
            && contrast == 0
            && saturation == 0
            && temperature == 0
            && tint == 0
            && highlights == 0
            && shadows == 0
    }

    private static func normalized(_ value: Double?) -> Double {
        guard let value, value.isFinite else { return 0 }
        return min(max(value, -1), 1)
    }
}

/// Figma image-fill parameters retained for non-destructive rendering.
struct XomoFigmaImageFillMetadata: Codable, Equatable, Sendable {
    var imageReference: String
    var scaleMode: String?
    var imageTransform: XomoFigmaPlanTransform?
    var scalingFactor: Double?
    var rotation: Double?
    var filters: XomoFigmaPlanImageFilters
    var sourcePixelSize: XomoFigmaPlanSize?
    var importScale: Double

    init(
        imageReference: String,
        scaleMode: String?,
        imageTransform: XomoFigmaPlanTransform?,
        scalingFactor: Double?,
        rotation: Double?,
        filters: XomoFigmaPlanImageFilters,
        sourcePixelSize: XomoFigmaPlanSize? = nil,
        importScale: Double = 1
    ) {
        self.imageReference = imageReference
        self.scaleMode = scaleMode
        self.imageTransform = imageTransform
        self.scalingFactor = scalingFactor
        self.rotation = rotation
        self.filters = filters
        self.sourcePixelSize = sourcePixelSize
        self.importScale = importScale.isFinite ? max(0.01, importScale) : 1
    }

    private enum CodingKeys: String, CodingKey {
        case imageReference
        case scaleMode
        case imageTransform
        case scalingFactor
        case rotation
        case filters
        case sourcePixelSize
        case importScale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            imageReference: try container.decode(String.self, forKey: .imageReference),
            scaleMode: try container.decodeIfPresent(String.self, forKey: .scaleMode),
            imageTransform: try container.decodeIfPresent(XomoFigmaPlanTransform.self, forKey: .imageTransform),
            scalingFactor: try container.decodeIfPresent(Double.self, forKey: .scalingFactor),
            rotation: try container.decodeIfPresent(Double.self, forKey: .rotation),
            filters: try container.decodeIfPresent(XomoFigmaPlanImageFilters.self, forKey: .filters)
                ?? XomoFigmaPlanImageFilters(),
            sourcePixelSize: try container.decodeIfPresent(XomoFigmaPlanSize.self, forKey: .sourcePixelSize),
            importScale: try container.decodeIfPresent(Double.self, forKey: .importScale) ?? 1
        )
    }
}

enum XomoFigmaPlanEffectKind: String, Equatable, Sendable {
    case dropShadow
    case innerShadow
    case layerBlur
    case backgroundBlur
}

enum XomoFigmaPlanMaskShape: String, Equatable, Sendable {
    case rectangle
    case ellipse
}

struct XomoFigmaPlanEffect: Equatable, Sendable {
    var kind: XomoFigmaPlanEffectKind
    var color: XomoFigmaPlanColor
    var offsetX: Double
    var offsetY: Double
    var radius: Double
    var spread: Double
}

struct XomoFigmaPlanCornerRadii: Equatable, Sendable {
    var topLeft: Double
    var topRight: Double
    var bottomRight: Double
    var bottomLeft: Double

    func scaled(by scale: CGFloat) -> ImageEditorRectangleCornerRadii {
        ImageEditorRectangleCornerRadii(
            topLeft: max(0, CGFloat(topLeft) * scale),
            topRight: max(0, CGFloat(topRight) * scale),
            bottomRight: max(0, CGFloat(bottomRight) * scale),
            bottomLeft: max(0, CGFloat(bottomLeft) * scale)
        )
    }
}

struct XomoFigmaNodeImportItem: Equatable, Identifiable, Sendable {
    var id: String { sourceID }
    var sourceID: String
    var parentSourceID: String?
    var depth: Int
    var sourceName: String
    var sourceType: String
    var componentRole: XomoFigmaComponentRole?
    var componentProperties: [String: XomoFigmaComponentProperty] = [:]
    var targetKind: XomoFigmaNodeTargetKind?
    var fidelity: XomoFigmaNodeMappingFidelity
    var issues: [XomoFigmaNodeMappingIssue]
    var variableBindings: [XomoFigmaVariableBinding] = []
    var frame: XomoFigmaPlanRect?
    var opacity: Double
    var isVisible: Bool
    /// Canonical Xomo blend-mode raw value when Figma exposes a supported mode.
    var blendMode: String? = nil
    var solidFill: XomoFigmaPlanColor?
    var linearGradientFill: XomoFigmaPlanLinearGradient? = nil
    var radialGradientFill: XomoFigmaPlanRadialGradient? = nil
    var solidStroke: XomoFigmaPlanColor?
    var strokeWeight: Double?
    var strokeAlign: String? = nil
    var strokeCap: String? = nil
    var strokeJoin: String? = nil
    var strokeDashes: [Double]? = nil
    var cornerRadius: Double?
    var cornerRadii: XomoFigmaPlanCornerRadii? = nil
    var cornerSmoothing: Double? = nil
    var text: XomoFigmaPlanText?
    var vectorPaths: [String]
    var geometrySize: XomoFigmaPlanSize?
    var relativeTransform: XomoFigmaPlanTransform?
    var clipsContent: Bool = false
    var isMask: Bool = false
    var maskFrame: XomoFigmaPlanRect?
    var maskShape: XomoFigmaPlanMaskShape = .rectangle
    /// A simple Figma mask applies to direct siblings after the mask node.
    var siblingMaskFrame: XomoFigmaPlanRect? = nil
    var siblingMaskShape: XomoFigmaPlanMaskShape? = nil
    var imageReference: String?
    var imageScaleMode: String?
    var imageTransform: XomoFigmaPlanTransform?
    var imageScalingFactor: Double?
    var imageRotation: Double?
    var imageFilters: XomoFigmaPlanImageFilters = XomoFigmaPlanImageFilters()
    var effects: [XomoFigmaPlanEffect] = []
    var exportPresets: [ImageEditorSliceExportPreset] = []
    var stackLayout: ImageEditorStackLayout?
    var stackChildLayout: ImageEditorStackChildLayout?
    var isStackLayoutExcluded: Bool
}

struct XomoFigmaNodeImportPlan: Equatable, Sendable {
    var fileName: String
    var version: String?
    var sourceCanonicalURL: URL?
    var rootSourceID: String
    var rootName: String
    var items: [XomoFigmaNodeImportItem]
    var imageAssets: [String: XomoFigmaImageAsset]

    init(
        fileName: String,
        version: String?,
        sourceCanonicalURL: URL? = nil,
        rootSourceID: String,
        rootName: String,
        items: [XomoFigmaNodeImportItem],
        imageAssets: [String: XomoFigmaImageAsset] = [:]
    ) {
        self.fileName = fileName
        self.version = version
        self.sourceCanonicalURL = sourceCanonicalURL
        self.rootSourceID = rootSourceID
        self.rootName = rootName
        self.items = items
        self.imageAssets = imageAssets
    }

    var requiredImageReferences: Set<String> {
        Set(items.compactMap { item in
            guard item.targetKind == .imagePlaceholder || item.targetKind == .image else { return nil }
            return item.imageReference
        })
    }

    var requiredVariableIDs: Set<String> {
        Set(items.flatMap(\.variableBindings).map(\.variableID))
    }

    func resolvingVariables(_ store: XomoFigmaVariableStore) -> Self {
        var resolved = self
        resolved.items = items.map { item in
            var updated = item
            for binding in item.variableBindings {
                guard let color = store.color(for: binding.variableID) else { continue }
                switch binding.field {
                case "fills":
                    updated.solidFill = color
                case "strokes":
                    updated.solidStroke = color
                default:
                    continue
                }
            }
            let unresolved = item.variableBindings.contains { store.color(for: $0.variableID) == nil }
            if !unresolved {
                updated.issues.removeAll { $0 == .variableBindingPreserved }
            }
            updated.issues = Array(Set(updated.issues)).sorted { $0.rawValue < $1.rawValue }
            updated.fidelity = updated.issues.isEmpty ? .exact : .partial
            return updated
        }
        return resolved
    }

    func resolvingImageAssets(_ assets: [String: XomoFigmaImageAsset]) -> Self {
        let required = requiredImageReferences
        let acceptedAssets = assets.filter { required.contains($0.key) }
        var resolved = self
        resolved.imageAssets = acceptedAssets
        resolved.items = items.map { item in
            guard item.targetKind == .imagePlaceholder || item.targetKind == .image,
                  let imageReference = item.imageReference
            else { return item }
            var updated = item
            updated.issues.removeAll {
                $0 == .imageAssetPending || $0 == .imageAssetUnavailable
            }
            if acceptedAssets[imageReference] != nil {
                updated.targetKind = .image
                updated.issues.append(.imageFillTransformPreserved)
            } else {
                updated.targetKind = .imagePlaceholder
                updated.issues.append(.imageAssetUnavailable)
            }
            updated.issues = Array(Set(updated.issues)).sorted { $0.rawValue < $1.rawValue }
            updated.fidelity = updated.issues.isEmpty ? .exact : .partial
            return updated
        }
        return resolved
    }

    var exactCount: Int {
        items.filter { $0.fidelity == .exact }.count
    }

    var partialCount: Int {
        items.filter { $0.fidelity == .partial }.count
    }

    var unsupportedCount: Int {
        items.filter { $0.fidelity == .unsupported }.count
    }

    var mappableCount: Int {
        exactCount + partialCount
    }
}

enum XomoFigmaNodeImportError: String, Error, Equatable, CaseIterable, Sendable {
    case nodeSelectionRequired
    case credentialMissing
    case invalidRequest
    case invalidResponse
    case authorizationDenied
    case fileNotFound
    case nodeNotFound
    case rateLimited
    case serviceUnavailable
    case responseTooLarge
    case nodeLimitExceeded
    case transportFailed
    case secureStorageUnavailable

    var localizationKey: String {
        "xomo.figma.node.error.\(rawValue)"
    }
}
