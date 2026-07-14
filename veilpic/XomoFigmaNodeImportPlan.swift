import Foundation

enum XomoFigmaNodeTargetKind: String, CaseIterable, Sendable {
    case group
    case text
    case rectangle
    case ellipse
    case vector
    case image
    case imagePlaceholder

    var localizationKey: String {
        "xomo.figma.node.target.\(rawValue)"
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
    case imageFillTransformFlattened
    case vectorGeometryMissing
    case vectorGeometryUnsupported
    case componentSemanticsFlattened
    case autoLayoutFlattened
    case maskFlattened
    case clippingFlattened
    case effectsFlattened
    case blendModeFlattened
    case cornerRadiusFlattened
    case transformFlattened

    var localizationKey: String {
        "xomo.figma.node.issue.\(rawValue)"
    }
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

struct XomoFigmaPlanSize: Equatable, Sendable {
    var width: Double
    var height: Double
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

struct XomoFigmaNodeImportItem: Equatable, Identifiable, Sendable {
    var id: String { sourceID }
    var sourceID: String
    var parentSourceID: String?
    var depth: Int
    var sourceName: String
    var sourceType: String
    var targetKind: XomoFigmaNodeTargetKind?
    var fidelity: XomoFigmaNodeMappingFidelity
    var issues: [XomoFigmaNodeMappingIssue]
    var frame: XomoFigmaPlanRect?
    var opacity: Double
    var isVisible: Bool
    var solidFill: XomoFigmaPlanColor?
    var solidStroke: XomoFigmaPlanColor?
    var strokeWeight: Double?
    var cornerRadius: Double?
    var text: XomoFigmaPlanText?
    var vectorPaths: [String]
    var geometrySize: XomoFigmaPlanSize?
    var imageReference: String?
    var imageScaleMode: String?
    var stackLayout: ImageEditorStackLayout?
    var stackChildLayout: ImageEditorStackChildLayout?
    var isStackLayoutExcluded: Bool
}

struct XomoFigmaNodeImportPlan: Equatable, Sendable {
    var fileName: String
    var version: String?
    var rootSourceID: String
    var rootName: String
    var items: [XomoFigmaNodeImportItem]
    var imageAssets: [String: XomoFigmaImageAsset]

    init(
        fileName: String,
        version: String?,
        rootSourceID: String,
        rootName: String,
        items: [XomoFigmaNodeImportItem],
        imageAssets: [String: XomoFigmaImageAsset] = [:]
    ) {
        self.fileName = fileName
        self.version = version
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
                updated.issues.append(.imageFillTransformFlattened)
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
