//
//  ImageEditorProjectDocument.swift
//  veilpic
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

extension ImageEditorAdjustment: Codable {}
extension ImageEditorChannelMixerOutput: Codable {}
extension ImageEditorPhotoFilterPreset: Codable {}
extension ImageEditorGradientMapPreset: Codable {}
extension ImageEditorGradientFillPreset: Codable {}
extension ImageEditorGradientFillStyle: Codable {}
extension ImageEditorSelectiveColorRange: Codable {}
extension ImageEditorSelectiveColorComponent: Codable {}
extension ImageEditorSelectiveColorMethod: Codable {}
extension ImageEditorFilter: Codable {}
extension ImageEditorBlendMode: Codable {}
extension ImageEditorPatternOverlayKind: Codable {}
extension ImageEditorTextAlignment: Codable {}
extension ImageEditorShapeKind: Codable {}

enum ImageEditorProjectDocumentError: LocalizedError {
    case imageEncodingFailed(String)
    case imageDecodingFailed(String)
    case emptyDocument

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed(let layerName):
            L10n.format("imageEditor.project.error.imageEncoding", layerName)
        case .imageDecodingFailed(let layerName):
            L10n.format("imageEditor.project.error.imageDecoding", layerName)
        case .emptyDocument:
            L10n.text("imageEditor.project.error.emptyDocument")
        }
    }
}

struct ImageEditorProjectDocument: Codable {
    /// The Xomo-native project extension. Keep the legacy QPic extension readable
    /// so existing documents remain safe to open after the product rename.
    static let fileExtension = "xomoproject"
    static let legacyFileExtension = "qpicproject"
    static let formatVersion = 9

    var formatVersion: Int
    var appVersion: String
    var sourceName: String
    var canvasSize: CGSize
    var layers: [ImageEditorProjectLayer]
    var smartObjectSources: [ImageEditorProjectSmartObjectSource]?
    var selectedLayerID: UUID?
    var selectedLayerIDs: Set<UUID>
    var selection: ImageEditorSelection?
    var savedSelection: ImageEditorSelection?
    var alphaChannels: [ImageEditorAlphaChannel]
    var layerComps: [ImageEditorLayerComp]?
    var selectedLayerCompID: UUID?
    var savedPaths: [ImageEditorSavedPath]?
    var selectedSavedPathID: UUID?
    var guides: [ImageEditorGuide]?
    var slices: [ImageEditorSlice]?
    var hotspots: [ImageEditorHotspot]?
    var areExtrasVisible: Bool?
    var areGuidesVisible: Bool?
    var areGuidesLocked: Bool?
    var areRulersVisible: Bool?
    var isGuideSnappingEnabled: Bool?
    var areSelectionEdgesVisible: Bool?
    var areTransformControlsVisible: Bool?
    var isGridVisible: Bool?
    var isGridSnappingEnabled: Bool?
    var gridSpacing: CGFloat?
    var designCanvasMetadata: XomoDesignCanvasMetadata?
    var xomoComponentTheme: XomoComponentTheme?
    var xomoLocalThemeTokenSnapshot: XomoComponentThemeTokenSnapshot?
    var globalLightAngle: CGFloat?
    var historyTitles: [String]

    @MainActor
    init(
        document: ImageEditorDocument,
        xomoComponentTheme: XomoComponentTheme? = nil,
        xomoLocalThemeTokenSnapshot: XomoComponentThemeTokenSnapshot? = nil
    ) throws {
        formatVersion = Self.formatVersion
        appVersion = AppVersion.current
        sourceName = document.sourceName
        canvasSize = document.canvasSize
        smartObjectSources = try Self.sharedSmartObjectSources(from: document.layers)
        let sharedSmartObjectSourceIDs = Set((smartObjectSources ?? []).map(\.sourceID))
        layers = try document.layers.map { layer in
            try ImageEditorProjectLayer(
                layer: layer,
                sharedSmartObjectSourceIDs: sharedSmartObjectSourceIDs
            )
        }
        selectedLayerID = document.selectedLayerID
        selectedLayerIDs = document.selectedLayerIDs
        selection = document.selection
        savedSelection = document.savedSelection
        alphaChannels = document.alphaChannels
        layerComps = document.layerComps
        selectedLayerCompID = document.selectedLayerCompID
        savedPaths = document.savedPaths
        selectedSavedPathID = document.selectedSavedPathID
        guides = document.guides
        slices = document.slices
        hotspots = document.hotspots
        areExtrasVisible = document.areExtrasVisible
        areGuidesVisible = document.areGuidesVisible
        areGuidesLocked = document.areGuidesLocked
        areRulersVisible = document.areRulersVisible
        isGuideSnappingEnabled = document.isGuideSnappingEnabled
        areSelectionEdgesVisible = document.areSelectionEdgesVisible
        areTransformControlsVisible = document.areTransformControlsVisible
        isGridVisible = document.isGridVisible
        isGridSnappingEnabled = document.isGridSnappingEnabled
        gridSpacing = document.gridSpacing
        designCanvasMetadata = document.designCanvasMetadata
        self.xomoComponentTheme = xomoComponentTheme
        self.xomoLocalThemeTokenSnapshot = xomoLocalThemeTokenSnapshot
        globalLightAngle = document.globalLightAngle
        historyTitles = document.history.map(\.title)
    }

    func restoredDocument() throws -> ImageEditorDocument {
        let smartObjectSourceData = Dictionary(
            uniqueKeysWithValues: (smartObjectSources ?? []).map { ($0.sourceID, $0.imageData) }
        )
        var restoredLayers = try layers.map {
            try $0.restoredLayer(smartObjectSourceData: smartObjectSourceData)
        }
        if formatVersion < 3 {
            for index in restoredLayers.indices where restoredLayers[index].isGroup && restoredLayers[index].blendMode == .normal {
                restoredLayers[index].blendMode = .passThrough
            }
        }
        guard let firstLayer = restoredLayers.first else {
            throw ImageEditorProjectDocumentError.emptyDocument
        }

        var document = ImageEditorDocument(sourceName: sourceName, image: firstLayer.image)
        document.canvasSize = canvasSize
        document.layers = restoredLayers

        let existingIDs = Set(restoredLayers.map(\.id))
        document.selectedLayerID = selectedLayerID.flatMap { existingIDs.contains($0) ? $0 : nil }
            ?? restoredLayers.last?.id
        document.selectedLayerIDs = selectedLayerIDs.intersection(existingIDs)
        if let selectedLayerID = document.selectedLayerID {
            document.selectedLayerIDs.insert(selectedLayerID)
        }

        document.selection = selection
        document.savedSelection = savedSelection
        document.alphaChannels = alphaChannels
        document.layerComps = (layerComps ?? []).map { comp in
            var restoredComp = comp
            restoredComp.layerStates = comp.layerStates.filter { existingIDs.contains($0.layerID) }
            restoredComp.layerOrder = comp.layerOrder.filter { existingIDs.contains($0) }
            if restoredComp.layerOrder.isEmpty {
                restoredComp.layerOrder = restoredComp.layerStates.map(\.layerID)
            }
            restoredComp.selectedLayerIDs = comp.selectedLayerIDs.intersection(existingIDs)
            restoredComp.selectedLayerID = comp.selectedLayerID.flatMap { existingIDs.contains($0) ? $0 : nil }
            return restoredComp
        }
        let existingCompIDs = Set(document.layerComps.map(\.id))
        document.selectedLayerCompID = selectedLayerCompID.flatMap { existingCompIDs.contains($0) ? $0 : nil }
            ?? document.layerComps.last?.id
        var restoredSavedPaths: [ImageEditorSavedPath] = []
        var existingSavedPathIDs = Set<UUID>()
        for sourcePath in (savedPaths ?? []).prefix(ImageEditorSavedPath.maximumCount) {
            guard var restoredPath = sourcePath.normalized(canvasSize: canvasSize) else { continue }
            if !existingSavedPathIDs.insert(restoredPath.id).inserted {
                restoredPath.id = UUID()
                existingSavedPathIDs.insert(restoredPath.id)
            }
            restoredSavedPaths.append(restoredPath)
        }
        document.savedPaths = restoredSavedPaths
        document.selectedSavedPathID = selectedSavedPathID.flatMap {
            existingSavedPathIDs.contains($0) ? $0 : nil
        }
        document.guides = (guides ?? []).compactMap { guide in
            let upperBound = guide.orientation == .vertical ? canvasSize.width : canvasSize.height
            guard guide.position >= 0, guide.position <= upperBound else { return nil }
            return guide
        }
        var restoredSlices: [ImageEditorSlice] = []
        var existingSliceIDs = Set<UUID>()
        for sourceSlice in (slices ?? []).prefix(ImageEditorSlice.maximumCount) {
            guard var restoredSlice = sourceSlice.normalized(canvasSize: canvasSize) else { continue }
            if !existingSliceIDs.insert(restoredSlice.id).inserted {
                restoredSlice.id = UUID()
                existingSliceIDs.insert(restoredSlice.id)
            }
            restoredSlices.append(restoredSlice)
        }
        document.slices = restoredSlices
        var restoredHotspots: [ImageEditorHotspot] = []
        var existingHotspotIDs = Set<UUID>()
        for sourceHotspot in (hotspots ?? []).prefix(ImageEditorHotspot.maximumCount) {
            guard var restoredHotspot = sourceHotspot.normalized(canvasSize: canvasSize) else { continue }
            if !existingHotspotIDs.insert(restoredHotspot.id).inserted {
                restoredHotspot.id = UUID()
                existingHotspotIDs.insert(restoredHotspot.id)
            }
            restoredHotspots.append(restoredHotspot)
        }
        document.hotspots = restoredHotspots
        document.areExtrasVisible = areExtrasVisible ?? true
        document.areGuidesVisible = areGuidesVisible ?? true
        document.areGuidesLocked = areGuidesLocked ?? false
        document.areRulersVisible = areRulersVisible ?? true
        document.isGuideSnappingEnabled = isGuideSnappingEnabled ?? true
        document.areSelectionEdgesVisible = areSelectionEdgesVisible ?? true
        document.areTransformControlsVisible = areTransformControlsVisible ?? true
        document.isGridVisible = isGridVisible ?? false
        document.isGridSnappingEnabled = isGridSnappingEnabled ?? false
        document.gridSpacing = max(4, min(512, gridSpacing ?? 32))
        document.designCanvasMetadata = designCanvasMetadata
        document.globalLightAngle = max(-180, min(180, globalLightAngle ?? -45))
        document.history = historyTitles.isEmpty
            ? [ImageEditorHistoryEntry(title: L10n.text("imageEditor.history.projectOpen"))]
            : historyTitles.map { ImageEditorHistoryEntry(title: $0) }
        return document
    }

    private static func sharedSmartObjectSources(from layers: [ImageEditorLayer]) throws -> [ImageEditorProjectSmartObjectSource]? {
        var seenSourceIDs: Set<UUID> = []
        var sources: [ImageEditorProjectSmartObjectSource] = []
        for layer in layers {
            guard let sourceID = layer.smartObjectContent?.sourceID,
                  !seenSourceIDs.contains(sourceID)
            else { continue }
            guard let imageData = layer.image.qingtuPNGData() else {
                throw ImageEditorProjectDocumentError.imageEncodingFailed(layer.name)
            }
            seenSourceIDs.insert(sourceID)
            sources.append(ImageEditorProjectSmartObjectSource(sourceID: sourceID, imageData: imageData))
        }
        return sources.isEmpty ? nil : sources
    }
}

struct ImageEditorProjectSmartObjectSource: Codable {
    var sourceID: UUID
    var imageData: Data
}

struct ImageEditorProjectLayer: Codable {
    var id: UUID
    var name: String
    var imageData: Data?
    var maskData: Data?
    var isMaskEnabled: Bool
    var isMaskLinked: Bool
    var maskDensity: Double
    var maskFeather: Double
    var vectorMask: ImageEditorProjectShapeContent?
    var isVectorMaskEnabled: Bool
    var linkedLayerIDs: Set<UUID>
    var frame: CGRect
    var isVisible: Bool
    var opacity: Double
    var fillOpacity: Double
    var blendIfSourceBlack: Double?
    var blendIfSourceWhite: Double?
    var blendIfUnderlyingBlack: Double?
    var blendIfUnderlyingWhite: Double?
    var blendMode: ImageEditorBlendMode
    var isLocked: Bool
    var locksPixels: Bool
    var locksPosition: Bool
    var locksTransparentPixels: Bool
    var style: ImageEditorProjectLayerStyle
    var kind: ImageEditorProjectLayerKind
    var smartFilters: [ImageEditorSmartFilter]
    var adjustmentSettings: ImageEditorAdjustmentSettings
    var filterSettings: ImageEditorFilterSettings
    var groupID: UUID?
    var isGroupExpanded: Bool
    var stackLayout: ImageEditorStackLayout?
    var stackChildLayout: ImageEditorStackChildLayout?
    var isStackLayoutExcluded: Bool?
    var isStackLayoutBackground: Bool?
    var isClippingMask: Bool
    var labelColor: ImageEditorLayerLabelColor?
    var xomoComponentInstance: XomoComponentInstance?
    var isXomoThemeOverride: Bool?
    var xomoFigmaVariableBindings: [XomoFigmaVariableBinding]?
    var xomoFigmaSourceID: String?
    var xomoFigmaNodeType: String?
    var xomoFigmaComponentRole: XomoFigmaComponentRole?
    var xomoFigmaComponentProperties: [String: XomoFigmaComponentProperty]?
    var xomoFigmaComponentPropertyDefaults: [String: XomoFigmaComponentProperty]?
    var xomoFigmaImageFill: XomoFigmaImageFillMetadata?
    var xomoFigmaImageFillSourceImageData: Data?
    var xomoFigmaImageFillFiltersEnabled: Bool?
    var xomoFigmaSourceURL: URL?

    @MainActor
    init(layer: ImageEditorLayer) throws {
        try self.init(layer: layer, sharedSmartObjectSourceIDs: [])
    }

    @MainActor
    init(layer: ImageEditorLayer, sharedSmartObjectSourceIDs: Set<UUID>) throws {
        let shouldUseSharedSmartObjectSource = layer.smartObjectContent
            .map { sharedSmartObjectSourceIDs.contains($0.sourceID) } ?? false
        let imageData = shouldUseSharedSmartObjectSource ? nil : layer.image.qingtuPNGData()
        if !shouldUseSharedSmartObjectSource, imageData == nil {
            throw ImageEditorProjectDocumentError.imageEncodingFailed(layer.name)
        }
        if let mask = layer.mask, mask.qingtuPNGData() == nil {
            throw ImageEditorProjectDocumentError.imageEncodingFailed(layer.name)
        }

        id = layer.id
        name = layer.name
        self.imageData = imageData
        maskData = layer.mask?.qingtuPNGData()
        isMaskEnabled = layer.isMaskEnabled
        isMaskLinked = layer.isMaskLinked
        maskDensity = layer.maskDensity
        maskFeather = layer.maskFeather
        vectorMask = layer.vectorMask.map(ImageEditorProjectShapeContent.init(content:))
        isVectorMaskEnabled = layer.isVectorMaskEnabled
        linkedLayerIDs = layer.linkedLayerIDs
        frame = layer.frame
        isVisible = layer.isVisible
        opacity = layer.opacity
        fillOpacity = layer.fillOpacity
        blendIfSourceBlack = layer.blendIfSourceBlack
        blendIfSourceWhite = layer.blendIfSourceWhite
        blendIfUnderlyingBlack = layer.blendIfUnderlyingBlack
        blendIfUnderlyingWhite = layer.blendIfUnderlyingWhite
        blendMode = layer.blendMode
        isLocked = layer.isLocked
        locksPixels = layer.locksPixels
        locksPosition = layer.locksPosition
        locksTransparentPixels = layer.locksTransparentPixels
        style = ImageEditorProjectLayerStyle(style: layer.style)
        kind = ImageEditorProjectLayerKind(kind: layer.kind)
        smartFilters = layer.smartFilters
        adjustmentSettings = layer.adjustmentSettings
        filterSettings = layer.filterSettings
        groupID = layer.groupID
        isGroupExpanded = layer.isGroupExpanded
        stackLayout = layer.stackLayout
        stackChildLayout = layer.stackChildLayout
        isStackLayoutExcluded = layer.isStackLayoutExcluded
        isStackLayoutBackground = layer.isStackLayoutBackground
        isClippingMask = layer.isClippingMask
        labelColor = layer.labelColor
        xomoComponentInstance = layer.xomoComponentInstance
        isXomoThemeOverride = layer.isXomoThemeOverride
        xomoFigmaVariableBindings = layer.xomoFigmaVariableBindings.isEmpty
            ? nil
            : layer.xomoFigmaVariableBindings
        xomoFigmaSourceID = layer.xomoFigmaSourceID
        xomoFigmaNodeType = layer.xomoFigmaNodeType
        xomoFigmaComponentRole = layer.xomoFigmaComponentRole
        xomoFigmaComponentProperties = layer.xomoFigmaComponentProperties.isEmpty
            ? nil
            : layer.xomoFigmaComponentProperties
        xomoFigmaComponentPropertyDefaults = layer.xomoFigmaComponentPropertyDefaults.isEmpty
            ? nil
            : layer.xomoFigmaComponentPropertyDefaults
        xomoFigmaImageFill = layer.xomoFigmaImageFill
        xomoFigmaImageFillSourceImageData = layer.xomoFigmaImageFillSourceImage?.qingtuPNGData()
        xomoFigmaImageFillFiltersEnabled = layer.xomoFigmaImageFillFiltersEnabled
        xomoFigmaSourceURL = layer.xomoFigmaSourceURL
    }

    func restoredLayer(smartObjectSourceData: [UUID: Data] = [:]) throws -> ImageEditorLayer {
        let restoredImageData = imageData ?? smartObjectSourceID.flatMap { smartObjectSourceData[$0] }
        guard let restoredImageData,
              let image = NSImage(data: restoredImageData)?.normalizedBitmapImage()
        else {
            throw ImageEditorProjectDocumentError.imageDecodingFailed(name)
        }
        let mask = try restoredMask()

        var layer = ImageEditorLayer.blank(name: name, size: image.size)
        layer.id = id
        layer.image = image
        layer.mask = mask
        layer.isMaskEnabled = isMaskEnabled
        layer.isMaskLinked = isMaskLinked
        layer.maskDensity = maskDensity
        layer.maskFeather = maskFeather
        layer.vectorMask = vectorMask?.content
        layer.isVectorMaskEnabled = isVectorMaskEnabled
        layer.linkedLayerIDs = linkedLayerIDs
        layer.frame = frame
        layer.isVisible = isVisible
        layer.opacity = opacity
        layer.fillOpacity = fillOpacity
        layer.blendIfSourceBlack = max(0, min(1, blendIfSourceBlack ?? 0))
        layer.blendIfSourceWhite = max(layer.blendIfSourceBlack, min(1, blendIfSourceWhite ?? 1))
        layer.blendIfUnderlyingBlack = max(0, min(1, blendIfUnderlyingBlack ?? 0))
        layer.blendIfUnderlyingWhite = max(layer.blendIfUnderlyingBlack, min(1, blendIfUnderlyingWhite ?? 1))
        layer.blendMode = blendMode
        layer.isLocked = isLocked
        layer.locksPixels = locksPixels
        layer.locksPosition = locksPosition
        layer.locksTransparentPixels = locksTransparentPixels
        layer.style = style.layerStyle
        layer.kind = kind.layerKind
        layer.smartFilters = smartFilters
        layer.adjustmentSettings = adjustmentSettings.normalized()
        layer.filterSettings = filterSettings.normalized()
        layer.groupID = groupID
        layer.isGroupExpanded = isGroupExpanded
        layer.stackLayout = stackLayout
        layer.stackChildLayout = stackChildLayout
        layer.isStackLayoutExcluded = isStackLayoutExcluded ?? false
        layer.isStackLayoutBackground = isStackLayoutBackground ?? false
        layer.isClippingMask = isClippingMask
        layer.labelColor = labelColor
        layer.xomoComponentInstance = xomoComponentInstance
        layer.isXomoThemeOverride = isXomoThemeOverride ?? false
        layer.xomoFigmaVariableBindings = xomoFigmaVariableBindings ?? []
        layer.xomoFigmaSourceID = xomoFigmaSourceID
        layer.xomoFigmaNodeType = xomoFigmaNodeType
        layer.xomoFigmaComponentRole = xomoFigmaComponentRole
        layer.xomoFigmaComponentProperties = xomoFigmaComponentProperties ?? [:]
        layer.xomoFigmaComponentPropertyDefaults = xomoFigmaComponentPropertyDefaults ?? [:]
        layer.xomoFigmaImageFill = xomoFigmaImageFill
        layer.xomoFigmaImageFillSourceImage = xomoFigmaImageFillSourceImageData
            .flatMap { NSImage(data: $0) }
        layer.xomoFigmaImageFillFiltersEnabled = xomoFigmaImageFillFiltersEnabled ?? true
        layer.xomoFigmaSourceURL = xomoFigmaSourceURL
        return layer
    }

    private var smartObjectSourceID: UUID? {
        guard case .smartObject(let content) = kind else { return nil }
        return content.sourceID
    }

    private func restoredMask() throws -> NSImage? {
        guard let maskData else { return nil }
        guard let mask = NSImage(data: maskData)?.normalizedBitmapImage() else {
            throw ImageEditorProjectDocumentError.imageDecodingFailed(name)
        }
        return mask
    }
}

enum ImageEditorProjectLayerKind: Equatable, Codable {
    case pixel
    case group
    case adjustment(ImageEditorAdjustment, Double)
    case filter(ImageEditorFilter, Double)
    case solidColorFill(ImageEditorSolidColorFillContent)
    case patternFill(ImageEditorPatternFillContent)
    case gradientFill(ImageEditorGradientFillContent)
    case text(ImageEditorProjectTextContent)
    case shape(ImageEditorProjectShapeContent)
    case smartObject(ImageEditorProjectSmartObjectContent)

    private enum CodingKeys: String, CodingKey {
        case type
        case adjustmentKind
        case amount
        case filterKind
        case intensity
        case solidColorFill
        case patternFill
        case gradientFill
        case text
        case shape
        case smartObject
    }

    init(kind: ImageEditorLayerKind) {
        switch kind {
        case .pixel:
            self = .pixel
        case .group:
            self = .group
        case .adjustment(let adjustmentKind, let amount):
            self = .adjustment(adjustmentKind, amount)
        case .filter(let filterKind, let intensity):
            self = .filter(filterKind, intensity)
        case .solidColorFill(let content):
            self = .solidColorFill(content.normalized())
        case .patternFill(let content):
            self = .patternFill(content.normalized())
        case .gradientFill(let content):
            self = .gradientFill(content.normalized())
        case .text(let content):
            self = .text(ImageEditorProjectTextContent(content: content))
        case .shape(let content):
            self = .shape(ImageEditorProjectShapeContent(content: content))
        case .smartObject(let content):
            self = .smartObject(ImageEditorProjectSmartObjectContent(content: content))
        }
    }

    var layerKind: ImageEditorLayerKind {
        switch self {
        case .pixel:
            return .pixel
        case .group:
            return .group
        case .adjustment(let kind, let amount):
            return .adjustment(kind, amount)
        case .filter(let kind, let intensity):
            return .filter(kind, intensity)
        case .solidColorFill(let content):
            return .solidColorFill(content.normalized())
        case .patternFill(let content):
            return .patternFill(content.normalized())
        case .gradientFill(let content):
            return .gradientFill(content.normalized())
        case .text(let content):
            return .text(content.textContent)
        case .shape(let content):
            return .shape(content.content)
        case .smartObject(let content):
            return .smartObject(content.content)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "pixel":
            self = .pixel
        case "group":
            self = .group
        case "adjustment":
            self = .adjustment(
                try container.decode(ImageEditorAdjustment.self, forKey: .adjustmentKind),
                try container.decode(Double.self, forKey: .amount)
            )
        case "filter":
            self = .filter(
                try container.decode(ImageEditorFilter.self, forKey: .filterKind),
                try container.decode(Double.self, forKey: .intensity)
            )
        case "solidColorFill":
            self = .solidColorFill(try container.decode(ImageEditorSolidColorFillContent.self, forKey: .solidColorFill))
        case "patternFill":
            self = .patternFill(try container.decode(ImageEditorPatternFillContent.self, forKey: .patternFill))
        case "gradientFill":
            self = .gradientFill(try container.decode(ImageEditorGradientFillContent.self, forKey: .gradientFill))
        case "text":
            self = .text(try container.decode(ImageEditorProjectTextContent.self, forKey: .text))
        case "shape":
            self = .shape(try container.decode(ImageEditorProjectShapeContent.self, forKey: .shape))
        case "smartObject":
            self = .smartObject(try container.decode(ImageEditorProjectSmartObjectContent.self, forKey: .smartObject))
        default:
            self = .pixel
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pixel:
            try container.encode("pixel", forKey: .type)
        case .group:
            try container.encode("group", forKey: .type)
        case .adjustment(let kind, let amount):
            try container.encode("adjustment", forKey: .type)
            try container.encode(kind, forKey: .adjustmentKind)
            try container.encode(amount, forKey: .amount)
        case .filter(let kind, let intensity):
            try container.encode("filter", forKey: .type)
            try container.encode(kind, forKey: .filterKind)
            try container.encode(intensity, forKey: .intensity)
        case .solidColorFill(let content):
            try container.encode("solidColorFill", forKey: .type)
            try container.encode(content.normalized(), forKey: .solidColorFill)
        case .patternFill(let content):
            try container.encode("patternFill", forKey: .type)
            try container.encode(content.normalized(), forKey: .patternFill)
        case .gradientFill(let content):
            try container.encode("gradientFill", forKey: .type)
            try container.encode(content.normalized(), forKey: .gradientFill)
        case .text(let content):
            try container.encode("text", forKey: .type)
            try container.encode(content, forKey: .text)
        case .shape(let content):
            try container.encode("shape", forKey: .type)
            try container.encode(content, forKey: .shape)
        case .smartObject(let content):
            try container.encode("smartObject", forKey: .type)
            try container.encode(content, forKey: .smartObject)
        }
    }
}

struct ImageEditorProjectSmartObjectContent: Equatable, Codable {
    var sourceName: String
    var originalSize: CGSize
    var sourceID: UUID

    init(content: ImageEditorSmartObjectContent) {
        sourceName = content.sourceName
        originalSize = content.originalSize
        sourceID = content.sourceID
    }

    var content: ImageEditorSmartObjectContent {
        ImageEditorSmartObjectContent(sourceName: sourceName, originalSize: originalSize, sourceID: sourceID)
    }

    enum CodingKeys: String, CodingKey {
        case sourceName
        case originalSize
        case sourceID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceName = try container.decode(String.self, forKey: .sourceName)
        originalSize = try container.decode(CGSize.self, forKey: .originalSize)
        sourceID = try container.decodeIfPresent(UUID.self, forKey: .sourceID) ?? UUID()
    }
}

struct ImageEditorProjectTextContent: Equatable, Codable {
    var text: String
    var color: ImageEditorProjectColor
    var fontSize: CGFloat
    var fontFamilyName: String?
    var point: CGPoint
    var isBold: Bool
    var isItalic: Bool
    var isUnderlined: Bool?
    var isStruckThrough: Bool?
    var characterSpacing: CGFloat
    var lineSpacing: CGFloat
    var boxWidth: CGFloat
    var boxHeight: CGFloat?
    var alignment: ImageEditorTextAlignment
    var leftIndent: CGFloat?
    var rightIndent: CGFloat?
    var firstLineIndent: CGFloat?

    init(content: ImageEditorTextContent) {
        text = content.text
        color = ImageEditorProjectColor(color: content.color)
        fontSize = content.fontSize
        fontFamilyName = content.fontFamilyName
        point = content.point
        isBold = content.isBold
        isItalic = content.isItalic
        isUnderlined = content.isUnderlined
        isStruckThrough = content.isStruckThrough
        characterSpacing = content.characterSpacing
        lineSpacing = content.lineSpacing
        boxWidth = content.boxWidth
        boxHeight = content.boxHeight
        alignment = content.alignment
        leftIndent = content.leftIndent
        rightIndent = content.rightIndent
        firstLineIndent = content.firstLineIndent
    }

    var textContent: ImageEditorTextContent {
        ImageEditorTextContent(
            text: text,
            color: color.nsColor,
            fontSize: fontSize,
            fontFamilyName: fontFamilyName ?? ImageEditorTextContent.systemFontFamilyName,
            point: point,
            isBold: isBold,
            isItalic: isItalic,
            isUnderlined: isUnderlined ?? false,
            isStruckThrough: isStruckThrough ?? false,
            characterSpacing: characterSpacing,
            lineSpacing: lineSpacing,
            boxWidth: boxWidth,
            boxHeight: boxHeight ?? 0,
            alignment: alignment,
            leftIndent: leftIndent ?? 0,
            rightIndent: rightIndent ?? 0,
            firstLineIndent: firstLineIndent ?? 0
        )
    }
}

struct ImageEditorProjectShapeContent: Equatable, Codable {
    var kind: ImageEditorShapeKind
    var fillColor: ImageEditorProjectColor
    var fillGradient: ImageEditorGradientFillContent?
    var fillGradientCenter: CGPoint?
    var fillOpacity: CGFloat
    var strokeColor: ImageEditorProjectColor
    var strokeWidth: CGFloat
    var strokeOpacity: CGFloat
    var strokePosition: ImageEditorStrokePosition = .inside
    var strokeCap: ImageEditorStrokeCap = .round
    var strokeJoin: ImageEditorStrokeJoin = .round
    var strokeDashPattern: [CGFloat] = []
    var cornerRadius: CGFloat?
    var cornerRadii: ImageEditorRectangleCornerRadii?
    var cornerSmoothing: CGFloat?
    var pathPoints: [CGPoint]
    var pathAnchors: [ImageEditorPathAnchor]
    var pathSubpaths: [[ImageEditorPathAnchor]]?
    var isPathClosed: Bool

    enum CodingKeys: String, CodingKey {
        case kind, fillColor, fillGradient, fillGradientCenter, fillOpacity
        case strokeColor, strokeWidth, strokeOpacity, strokePosition, strokeCap, strokeJoin, strokeDashPattern
        case cornerRadius, cornerRadii, cornerSmoothing, pathPoints, pathAnchors
        case pathSubpaths, isPathClosed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(ImageEditorShapeKind.self, forKey: .kind)
        fillColor = try container.decode(ImageEditorProjectColor.self, forKey: .fillColor)
        fillGradient = try container.decodeIfPresent(ImageEditorGradientFillContent.self, forKey: .fillGradient)
        fillGradientCenter = try container.decodeIfPresent(CGPoint.self, forKey: .fillGradientCenter)
        fillOpacity = try container.decode(CGFloat.self, forKey: .fillOpacity)
        strokeColor = try container.decode(ImageEditorProjectColor.self, forKey: .strokeColor)
        strokeWidth = try container.decode(CGFloat.self, forKey: .strokeWidth)
        strokeOpacity = try container.decode(CGFloat.self, forKey: .strokeOpacity)
        strokePosition = try container.decodeIfPresent(ImageEditorStrokePosition.self, forKey: .strokePosition) ?? .inside
        strokeCap = try container.decodeIfPresent(ImageEditorStrokeCap.self, forKey: .strokeCap) ?? .round
        strokeJoin = try container.decodeIfPresent(ImageEditorStrokeJoin.self, forKey: .strokeJoin) ?? .round
        strokeDashPattern = try container.decodeIfPresent([CGFloat].self, forKey: .strokeDashPattern) ?? []
        cornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .cornerRadius)
        cornerRadii = try container.decodeIfPresent(ImageEditorRectangleCornerRadii.self, forKey: .cornerRadii)
        cornerSmoothing = try container.decodeIfPresent(CGFloat.self, forKey: .cornerSmoothing)
        pathPoints = try container.decode([CGPoint].self, forKey: .pathPoints)
        pathAnchors = try container.decode([ImageEditorPathAnchor].self, forKey: .pathAnchors)
        pathSubpaths = try container.decodeIfPresent([[ImageEditorPathAnchor]].self, forKey: .pathSubpaths)
        isPathClosed = try container.decode(Bool.self, forKey: .isPathClosed)
    }

    init(content: ImageEditorShapeContent) {
        kind = content.kind
        fillColor = ImageEditorProjectColor(color: content.fillColor)
        fillGradient = content.fillGradient
        fillGradientCenter = content.fillGradientCenter
        fillOpacity = content.fillOpacity
        strokeColor = ImageEditorProjectColor(color: content.strokeColor)
        strokeWidth = content.strokeWidth
        strokeOpacity = content.strokeOpacity
        strokePosition = content.strokePosition
        strokeCap = content.strokeCap
        strokeJoin = content.strokeJoin
        strokeDashPattern = content.strokeDashPattern
        cornerRadius = content.cornerRadius
        cornerRadii = content.cornerRadii
        cornerSmoothing = content.cornerSmoothing
        pathPoints = content.pathPoints
        pathAnchors = content.pathAnchors
        pathSubpaths = content.pathSubpaths
        isPathClosed = content.isPathClosed
    }

    var content: ImageEditorShapeContent {
        ImageEditorShapeContent(
            kind: kind,
            fillColor: fillColor.nsColor,
            fillGradient: fillGradient,
            fillGradientCenter: fillGradientCenter ?? CGPoint(x: 0.5, y: 0.5),
            fillOpacity: fillOpacity,
            strokeColor: strokeColor.nsColor,
            strokeWidth: strokeWidth,
            strokeOpacity: strokeOpacity,
            strokePosition: strokePosition,
            strokeCap: strokeCap,
            strokeJoin: strokeJoin,
            strokeDashPattern: strokeDashPattern,
            cornerRadius: cornerRadius ?? 0,
            cornerRadii: cornerRadii,
            cornerSmoothing: cornerSmoothing ?? 0,
            pathPoints: pathPoints,
            pathAnchors: pathAnchors,
            pathSubpaths: pathSubpaths ?? [],
            isPathClosed: isPathClosed
        )
    }
}

struct ImageEditorProjectLayerStyle: Codable, Equatable {
    var effectsEnabled: Bool?
    var effectScale: CGFloat?
    var strokeEnabled: Bool
    var strokeColor: ImageEditorProjectColor
    var strokeWidth: CGFloat
    var strokePosition: ImageEditorStrokePosition?
    var strokeOpacity: CGFloat?
    var strokeFillType: ImageEditorStrokeFillType?
    var strokeGradientStartColor: ImageEditorProjectColor?
    var strokeGradientEndColor: ImageEditorProjectColor?
    var strokeGradientStyle: ImageEditorGradientFillStyle?
    var strokeGradientAngle: CGFloat?
    var strokePatternKind: ImageEditorPatternOverlayKind?
    var strokePatternColor: ImageEditorProjectColor?
    var strokePatternScale: CGFloat?
    var strokePatternOffset: CGSize?
    var shadowEnabled: Bool
    var shadowColor: ImageEditorProjectColor
    var shadowOpacity: CGFloat
    var shadowBlur: CGFloat
    var shadowSpread: CGFloat?
    var shadowNoise: CGFloat?
    var shadowContour: ImageEditorLayerEffectContour?
    var shadowDistance: CGFloat?
    var shadowAngle: CGFloat?
    var shadowUsesGlobalLight: Bool?
    var shadowOffset: CGSize
    var innerShadowEnabled: Bool
    var innerShadowColor: ImageEditorProjectColor
    var innerShadowOpacity: CGFloat
    var innerShadowBlur: CGFloat
    var innerShadowChoke: CGFloat?
    var innerShadowNoise: CGFloat?
    var innerShadowContour: ImageEditorLayerEffectContour?
    var innerShadowDistance: CGFloat
    var innerShadowAngle: CGFloat
    var innerShadowUsesGlobalLight: Bool?
    var outerGlowEnabled: Bool
    var outerGlowColor: ImageEditorProjectColor
    var outerGlowOpacity: CGFloat
    var outerGlowBlur: CGFloat
    var outerGlowSpread: CGFloat
    var outerGlowTechnique: ImageEditorGlowTechnique?
    var outerGlowNoise: CGFloat?
    var outerGlowContour: ImageEditorLayerEffectContour?
    var outerGlowRange: CGFloat?
    var outerGlowJitter: CGFloat?
    var innerGlowEnabled: Bool
    var innerGlowColor: ImageEditorProjectColor
    var innerGlowOpacity: CGFloat
    var innerGlowBlur: CGFloat
    var innerGlowChoke: CGFloat
    var innerGlowTechnique: ImageEditorGlowTechnique?
    var innerGlowNoise: CGFloat?
    var innerGlowSource: ImageEditorInnerGlowSource?
    var innerGlowContour: ImageEditorLayerEffectContour?
    var innerGlowRange: CGFloat?
    var innerGlowJitter: CGFloat?
    var colorOverlayEnabled: Bool
    var colorOverlayColor: ImageEditorProjectColor
    var colorOverlayOpacity: CGFloat
    var gradientOverlayEnabled: Bool
    var gradientOverlayStartColor: ImageEditorProjectColor
    var gradientOverlayEndColor: ImageEditorProjectColor
    var gradientOverlayOpacity: CGFloat
    var gradientOverlayStyle: ImageEditorGradientFillStyle?
    var gradientOverlayScale: CGFloat?
    var gradientOverlayAngle: CGFloat
    var patternOverlayEnabled: Bool
    var patternOverlayKind: ImageEditorPatternOverlayKind
    var patternOverlayColor: ImageEditorProjectColor
    var patternOverlayOpacity: CGFloat
    var patternOverlayScale: CGFloat
    var satinEnabled: Bool
    var satinColor: ImageEditorProjectColor
    var satinOpacity: CGFloat
    var satinDistance: CGFloat
    var satinSize: CGFloat
    var satinAngle: CGFloat
    var satinInvert: Bool?
    var satinContour: ImageEditorLayerEffectContour?
    var bevelEnabled: Bool
    var bevelHighlightColor: ImageEditorProjectColor
    var bevelShadowColor: ImageEditorProjectColor
    var bevelOpacity: CGFloat
    var bevelSize: CGFloat
    var bevelSoften: CGFloat?
    var bevelAngle: CGFloat?
    var bevelUsesGlobalLight: Bool?
    var bevelDirection: ImageEditorBevelDirection?

    init(style: ImageEditorLayerStyle) {
        effectsEnabled = style.effectsEnabled
        effectScale = style.effectScale
        strokeEnabled = style.strokeEnabled
        strokeColor = ImageEditorProjectColor(color: style.strokeColor)
        strokeWidth = style.strokeWidth
        strokePosition = style.strokePosition
        strokeOpacity = style.strokeOpacity
        strokeFillType = style.strokeFillType
        strokeGradientStartColor = ImageEditorProjectColor(color: style.strokeGradientStartColor)
        strokeGradientEndColor = ImageEditorProjectColor(color: style.strokeGradientEndColor)
        strokeGradientStyle = style.strokeGradientStyle
        strokeGradientAngle = style.strokeGradientAngle
        strokePatternKind = style.strokePatternKind
        strokePatternColor = ImageEditorProjectColor(color: style.strokePatternColor)
        strokePatternScale = style.strokePatternScale
        strokePatternOffset = style.strokePatternOffset
        shadowEnabled = style.shadowEnabled
        shadowColor = ImageEditorProjectColor(color: style.shadowColor)
        shadowOpacity = style.shadowOpacity
        shadowBlur = style.shadowBlur
        shadowSpread = style.shadowSpread
        shadowNoise = style.shadowNoise
        shadowContour = style.shadowContour
        shadowDistance = style.shadowDistance
        shadowAngle = style.shadowAngle
        shadowUsesGlobalLight = style.shadowUsesGlobalLight
        shadowOffset = style.shadowOffsetForCurrentLight
        innerShadowEnabled = style.innerShadowEnabled
        innerShadowColor = ImageEditorProjectColor(color: style.innerShadowColor)
        innerShadowOpacity = style.innerShadowOpacity
        innerShadowBlur = style.innerShadowBlur
        innerShadowChoke = style.innerShadowChoke
        innerShadowNoise = style.innerShadowNoise
        innerShadowContour = style.innerShadowContour
        innerShadowDistance = style.innerShadowDistance
        innerShadowAngle = style.innerShadowAngle
        innerShadowUsesGlobalLight = style.innerShadowUsesGlobalLight
        outerGlowEnabled = style.outerGlowEnabled
        outerGlowColor = ImageEditorProjectColor(color: style.outerGlowColor)
        outerGlowOpacity = style.outerGlowOpacity
        outerGlowBlur = style.outerGlowBlur
        outerGlowSpread = style.outerGlowSpread
        outerGlowTechnique = style.outerGlowTechnique
        outerGlowNoise = style.outerGlowNoise
        outerGlowContour = style.outerGlowContour
        outerGlowRange = style.outerGlowRange
        outerGlowJitter = style.outerGlowJitter
        innerGlowEnabled = style.innerGlowEnabled
        innerGlowColor = ImageEditorProjectColor(color: style.innerGlowColor)
        innerGlowOpacity = style.innerGlowOpacity
        innerGlowBlur = style.innerGlowBlur
        innerGlowChoke = style.innerGlowChoke
        innerGlowTechnique = style.innerGlowTechnique
        innerGlowNoise = style.innerGlowNoise
        innerGlowSource = style.innerGlowSource
        innerGlowContour = style.innerGlowContour
        innerGlowRange = style.innerGlowRange
        innerGlowJitter = style.innerGlowJitter
        colorOverlayEnabled = style.colorOverlayEnabled
        colorOverlayColor = ImageEditorProjectColor(color: style.colorOverlayColor)
        colorOverlayOpacity = style.colorOverlayOpacity
        gradientOverlayEnabled = style.gradientOverlayEnabled
        gradientOverlayStartColor = ImageEditorProjectColor(color: style.gradientOverlayStartColor)
        gradientOverlayEndColor = ImageEditorProjectColor(color: style.gradientOverlayEndColor)
        gradientOverlayOpacity = style.gradientOverlayOpacity
        gradientOverlayStyle = style.gradientOverlayStyle
        gradientOverlayScale = style.gradientOverlayScale
        gradientOverlayAngle = style.gradientOverlayAngle
        patternOverlayEnabled = style.patternOverlayEnabled
        patternOverlayKind = style.patternOverlayKind
        patternOverlayColor = ImageEditorProjectColor(color: style.patternOverlayColor)
        patternOverlayOpacity = style.patternOverlayOpacity
        patternOverlayScale = style.patternOverlayScale
        satinEnabled = style.satinEnabled
        satinColor = ImageEditorProjectColor(color: style.satinColor)
        satinOpacity = style.satinOpacity
        satinDistance = style.satinDistance
        satinSize = style.satinSize
        satinAngle = style.satinAngle
        satinInvert = style.satinInvert
        satinContour = style.satinContour
        bevelEnabled = style.bevelEnabled
        bevelHighlightColor = ImageEditorProjectColor(color: style.bevelHighlightColor)
        bevelShadowColor = ImageEditorProjectColor(color: style.bevelShadowColor)
        bevelOpacity = style.bevelOpacity
        bevelSize = style.bevelSize
        bevelSoften = style.bevelSoften
        bevelAngle = style.bevelAngle
        bevelUsesGlobalLight = style.bevelUsesGlobalLight
        bevelDirection = style.bevelDirection
    }

    var layerStyle: ImageEditorLayerStyle {
        let resolvedShadowDistance = max(0, min(80, shadowDistance ?? ImageEditorLayerStyle.shadowDistance(from: shadowOffset)))
        let resolvedShadowAngle = max(-180, min(180, shadowAngle ?? ImageEditorLayerStyle.shadowAngle(from: shadowOffset)))
        return ImageEditorLayerStyle(
            effectsEnabled: effectsEnabled ?? true,
            effectScale: max(0.01, min(10, effectScale ?? 1)),
            strokeEnabled: strokeEnabled,
            strokeColor: strokeColor.nsColor,
            strokeWidth: strokeWidth,
            strokePosition: strokePosition ?? .outside,
            strokeOpacity: max(0.05, min(1, strokeOpacity ?? 1)),
            strokeFillType: strokeFillType ?? .color,
            strokeGradientStartColor: strokeGradientStartColor?.nsColor ?? .white,
            strokeGradientEndColor: strokeGradientEndColor?.nsColor ?? .black,
            strokeGradientStyle: strokeGradientStyle ?? .linear,
            strokeGradientAngle: max(-180, min(180, strokeGradientAngle ?? 0)),
            strokePatternKind: strokePatternKind ?? .checkerboard,
            strokePatternColor: strokePatternColor?.nsColor ?? .white,
            strokePatternScale: max(6, min(64, strokePatternScale ?? 14)),
            strokePatternOffset: CGSize(
                width: max(-128, min(128, strokePatternOffset?.width ?? 0)),
                height: max(-128, min(128, strokePatternOffset?.height ?? 0))
            ),
            shadowEnabled: shadowEnabled,
            shadowColor: shadowColor.nsColor,
            shadowOpacity: shadowOpacity,
            shadowBlur: shadowBlur,
            shadowSpread: max(0, min(24, shadowSpread ?? 0)),
            shadowNoise: max(0, min(1, shadowNoise ?? 0)),
            shadowContour: shadowContour ?? .linear,
            shadowDistance: resolvedShadowDistance,
            shadowAngle: resolvedShadowAngle,
            shadowUsesGlobalLight: shadowUsesGlobalLight ?? true,
            shadowOffset: ImageEditorLayerStyle.shadowOffset(distance: resolvedShadowDistance, angle: resolvedShadowAngle),
            innerShadowEnabled: innerShadowEnabled,
            innerShadowColor: innerShadowColor.nsColor,
            innerShadowOpacity: innerShadowOpacity,
            innerShadowBlur: innerShadowBlur,
            innerShadowChoke: max(0, min(24, innerShadowChoke ?? 0)),
            innerShadowNoise: max(0, min(1, innerShadowNoise ?? 0)),
            innerShadowContour: innerShadowContour ?? .linear,
            innerShadowDistance: innerShadowDistance,
            innerShadowAngle: innerShadowAngle,
            innerShadowUsesGlobalLight: innerShadowUsesGlobalLight ?? true,
            outerGlowEnabled: outerGlowEnabled,
            outerGlowColor: outerGlowColor.nsColor,
            outerGlowOpacity: outerGlowOpacity,
            outerGlowBlur: outerGlowBlur,
            outerGlowSpread: outerGlowSpread,
            outerGlowTechnique: outerGlowTechnique ?? .softer,
            outerGlowNoise: max(0, min(1, outerGlowNoise ?? 0)),
            outerGlowContour: outerGlowContour ?? .linear,
            outerGlowRange: max(0.01, min(1, outerGlowRange ?? 1)),
            outerGlowJitter: max(0, min(1, outerGlowJitter ?? 0)),
            innerGlowEnabled: innerGlowEnabled,
            innerGlowColor: innerGlowColor.nsColor,
            innerGlowOpacity: innerGlowOpacity,
            innerGlowBlur: innerGlowBlur,
            innerGlowChoke: innerGlowChoke,
            innerGlowTechnique: innerGlowTechnique ?? .softer,
            innerGlowNoise: max(0, min(1, innerGlowNoise ?? 0)),
            innerGlowSource: innerGlowSource ?? .edge,
            innerGlowContour: innerGlowContour ?? .linear,
            innerGlowRange: max(0.01, min(1, innerGlowRange ?? 1)),
            innerGlowJitter: max(0, min(1, innerGlowJitter ?? 0)),
            colorOverlayEnabled: colorOverlayEnabled,
            colorOverlayColor: colorOverlayColor.nsColor,
            colorOverlayOpacity: colorOverlayOpacity,
            gradientOverlayEnabled: gradientOverlayEnabled,
            gradientOverlayStartColor: gradientOverlayStartColor.nsColor,
            gradientOverlayEndColor: gradientOverlayEndColor.nsColor,
            gradientOverlayOpacity: gradientOverlayOpacity,
            gradientOverlayStyle: gradientOverlayStyle ?? .linear,
            gradientOverlayScale: max(0.25, min(4, gradientOverlayScale ?? 1)),
            gradientOverlayAngle: gradientOverlayAngle,
            patternOverlayEnabled: patternOverlayEnabled,
            patternOverlayKind: patternOverlayKind,
            patternOverlayColor: patternOverlayColor.nsColor,
            patternOverlayOpacity: patternOverlayOpacity,
            patternOverlayScale: patternOverlayScale,
            satinEnabled: satinEnabled,
            satinColor: satinColor.nsColor,
            satinOpacity: satinOpacity,
            satinDistance: satinDistance,
            satinSize: satinSize,
            satinAngle: satinAngle,
            satinInvert: satinInvert ?? false,
            satinContour: satinContour ?? .linear,
            bevelEnabled: bevelEnabled,
            bevelHighlightColor: bevelHighlightColor.nsColor,
            bevelShadowColor: bevelShadowColor.nsColor,
            bevelOpacity: bevelOpacity,
            bevelSize: bevelSize,
            bevelSoften: max(0, min(24, bevelSoften ?? 0)),
            bevelAngle: max(-180, min(180, bevelAngle ?? -45)),
            bevelUsesGlobalLight: bevelUsesGlobalLight ?? true,
            bevelDirection: bevelDirection ?? .up
        )
    }
}

struct ImageEditorProjectColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(color: NSColor) {
        let converted = color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.deviceRGB) ?? .clear
        red = Double(converted.redComponent)
        green = Double(converted.greenComponent)
        blue = Double(converted.blueComponent)
        alpha = Double(converted.alphaComponent)
    }

    var nsColor: NSColor {
        NSColor(
            srgbRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
}

@MainActor
extension ImageEditorViewModel {
    static var projectContentType: UTType {
        UTType(exportedAs: "im.some.xomo.project")
    }

    static var legacyProjectContentType: UTType {
        UTType(filenameExtension: ImageEditorProjectDocument.legacyFileExtension) ?? .json
    }

    func projectData() throws -> Data {
        let project = try ImageEditorProjectDocument(
            document: document,
            xomoComponentTheme: xomoComponentTheme,
            xomoLocalThemeTokenSnapshot: xomoLocalThemeTokenSnapshot
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(project)
    }

    func loadProjectData(_ data: Data) throws {
        let decoder = JSONDecoder()
        let project = try decoder.decode(ImageEditorProjectDocument.self, from: data)
        document = try project.restoredDocument()
        psdCompatibilityReport = nil
        psdCompatibilityFileName = ""
        isPSDCompatibilityReportPresented = false
        restoreXomoThemeContext(
            theme: project.xomoComponentTheme ?? .native,
            tokenSnapshot: project.xomoLocalThemeTokenSnapshot
        )
        if let metadata = document.designCanvasMetadata {
            exportSettings.scale = Double(metadata.exportScale)
        }
        clearUndoHistory()
        historySnapshots.removeAll()
        document.history.forEach { entry in
            historySnapshots[entry.id] = document
        }
        selectedTool = .move
        selectedChannelPreview = .composite
        isEditingLayerMask = false
        statusText = L10n.format("imageEditor.status.projectOpened", document.sourceName)
    }

    func saveProjectDocument() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [Self.projectContentType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = projectFilename()
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    let data = try self.projectData()
                    try data.write(to: url, options: .atomic)
                    self.appendHistory(L10n.text("imageEditor.history.projectSave"))
                    self.statusText = L10n.format("imageEditor.status.projectSaved", url.lastPathComponent)
                } catch {
                    self.statusText = L10n.format(
                        "imageEditor.status.projectSaveFailedWithReason",
                        error.localizedDescription
                    )
                }
            }
        }
    }

    func openProjectDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            Self.projectContentType,
            Self.legacyProjectContentType,
            .json,
            ImageEditorPSDCodec.contentType
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("imageEditor.action.projectOpen")
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self, response == .OK, let url = panel.url else { return }
                do {
                    if url.pathExtension.lowercased() == "psd" {
                        XomoExternalDocumentOpenCoordinator.shared.open(url)
                        return
                    }
                    let data = try Data(contentsOf: url)
                    try self.loadProjectData(data)
                    self.appendHistory(L10n.text("imageEditor.history.projectOpen"))
                    self.statusText = L10n.format("imageEditor.status.projectOpened", url.lastPathComponent)
                } catch {
                    self.statusText = L10n.format(
                        "imageEditor.status.projectOpenFailedWithReason",
                        error.localizedDescription
                    )
                }
            }
        }
    }

    func loadExternalPSDDocument(
        _ document: ImageEditorDocument,
        openedFlattened: Bool,
        compatibilityReport: ImageEditorPSDCompatibilityReport?
    ) {
        self.document = document
        psdCompatibilityReport = compatibilityReport
        psdCompatibilityFileName = document.sourceName
        isPSDCompatibilityReportPresented = compatibilityReport?.requiresAttention == true
        resetAfterExternalDocumentOpen()
        if openedFlattened {
            appendHistory(L10n.text("imageEditor.history.psdOpenFlattened"))
            statusText = L10n.format(
                "imageEditor.status.psdOpenedFlattened",
                document.sourceName
            )
        } else {
            appendHistory(L10n.text("imageEditor.history.psdOpen"))
            statusText = L10n.format("imageEditor.status.psdOpened", document.sourceName)
        }
    }

    private func resetAfterExternalDocumentOpen() {
        clearUndoHistory()
        historySnapshots.removeAll()
        document.history.forEach { entry in historySnapshots[entry.id] = document }
        selectedTool = .move
        selectedChannelPreview = .composite
        isEditingLayerMask = false
    }

    private func projectFilename() -> String {
        let base = (document.sourceName as NSString).deletingPathExtension
        let cleaned = base.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\((cleaned.isEmpty ? "image" : cleaned)).\(ImageEditorProjectDocument.fileExtension)"
    }
}
