import AppKit
import CoreImage
import Foundation
import simd

enum ImageEditorLayerDropPlacement: Equatable {
    case above
    case below
    case insideGroup
}

struct ImageEditorLayerDropTarget: Equatable {
    var layerID: UUID
    var placement: ImageEditorLayerDropPlacement
}

enum ImageEditorLayerLabelColor: String, CaseIterable, Identifiable, Codable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case gray

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.layer.label.\(rawValue)")
    }
}

enum ImageEditorLayerKindFilter: String, CaseIterable, Identifiable {
    case all
    case pixel
    case text
    case shape
    case adjustment
    case filter
    case solidColorFill
    case patternFill
    case gradientFill
    case smartObject
    case group

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.layer.kindFilter.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .pixel:
            return "photo"
        case .text:
            return "textformat"
        case .shape:
            return "square.on.circle"
        case .adjustment:
            return "circle.lefthalf.filled"
        case .filter:
            return "sparkles"
        case .solidColorFill:
            return "paintbrush.pointed"
        case .patternFill:
            return "square.grid.3x3.fill"
        case .gradientFill:
            return "paintpalette"
        case .smartObject:
            return "cube"
        case .group:
            return "folder"
        }
    }

    func matches(_ layer: ImageEditorLayer) -> Bool {
        switch self {
        case .all:
            return true
        case .pixel:
            return layer.kind.isPixel
        case .text:
            return layer.isText
        case .shape:
            return layer.isShape
        case .adjustment:
            return layer.isAdjustment
        case .filter:
            return layer.isFilter
        case .solidColorFill:
            return layer.isSolidColorFill
        case .patternFill:
            return layer.isPatternFill
        case .gradientFill:
            return layer.isGradientFill
        case .smartObject:
            return layer.isSmartObject
        case .group:
            return layer.isGroup
        }
    }
}

enum ImageEditorLayerStateFilter: String, CaseIterable, Identifiable {
    case all
    case visible
    case hidden
    case locked
    case unlocked

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.layer.stateFilter.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .all:
            return "circle.grid.2x2"
        case .visible:
            return "eye"
        case .hidden:
            return "eye.slash"
        case .locked:
            return "lock"
        case .unlocked:
            return "lock.open"
        }
    }
}

enum ImageEditorLayerAttributeFilter: String, CaseIterable, Identifiable {
    case all
    case masked
    case styled
    case clipping
    case linked
    case smartFiltered

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.layer.attributeFilter.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .all:
            return "slider.horizontal.3"
        case .masked:
            return "circle.dashed"
        case .styled:
            return "f.cursive"
        case .clipping:
            return "arrow.down.to.line.compact"
        case .linked:
            return "link"
        case .smartFiltered:
            return "camera.filters"
        }
    }

    func matches(_ layer: ImageEditorLayer) -> Bool {
        switch self {
        case .all:
            return true
        case .masked:
            return layer.mask != nil || layer.vectorMask != nil
        case .styled:
            return layer.style.hasConfiguredEffects
        case .clipping:
            return layer.isClippingMask
        case .linked:
            return !layer.linkedLayerIDs.isEmpty
        case .smartFiltered:
            return !layer.smartFilters.isEmpty
        }
    }
}

struct ImageEditorHistoryEntry: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let createdAt = Date()
}

struct ImageEditorHistorySnapshot: Identifiable {
    var id = UUID()
    var name: String
    let createdAt = Date()
    var document: ImageEditorDocument
    var renderedImage: NSImage
}

struct ImageEditorLayerCompLayerState: Equatable, Codable {
    var layerID: UUID
    var isVisible: Bool
    var frame: CGRect
    var opacity: Double
    var fillOpacity: Double
    var isMaskLinked: Bool
    var blendIfSourceBlack: Double
    var blendIfSourceWhite: Double
    var blendIfUnderlyingBlack: Double
    var blendIfUnderlyingWhite: Double
    var isMaskEnabled: Bool
    var maskDensity: Double
    var maskFeather: Double
    var maskFeatherSamplingScale: Double?
    var hasMaskSnapshot: Bool
    var maskData: Data?
    var isVectorMaskEnabled: Bool
    var isVectorMaskInverted: Bool
    var style: ImageEditorProjectLayerStyle
    var blendMode: ImageEditorBlendMode
    var kind: ImageEditorProjectLayerKind?
    var smartFilters: [ImageEditorSmartFilter]?
    var adjustmentSettings: ImageEditorAdjustmentSettings?
    var filterSettings: ImageEditorFilterSettings?
    var hasVectorMaskSnapshot: Bool
    var vectorMask: ImageEditorProjectShapeContent?
    var linkedLayerIDs: Set<UUID>
    var groupID: UUID?
    var isLocked: Bool
    var locksPixels: Bool
    var locksPosition: Bool
    var locksTransparentPixels: Bool
    var isGroupExpanded: Bool
    var isClippingMask: Bool
    var labelColor: ImageEditorLayerLabelColor?

    enum CodingKeys: String, CodingKey {
        case layerID
        case isVisible
        case frame
        case opacity
        case fillOpacity
        case isMaskLinked
        case blendIfSourceBlack
        case blendIfSourceWhite
        case blendIfUnderlyingBlack
        case blendIfUnderlyingWhite
        case isMaskEnabled
        case maskDensity
        case maskFeather
        case maskFeatherSamplingScale
        case hasMaskSnapshot
        case maskData
        case isVectorMaskEnabled
        case isVectorMaskInverted
        case style
        case blendMode
        case kind
        case smartFilters
        case adjustmentSettings
        case filterSettings
        case hasVectorMaskSnapshot
        case vectorMask
        case linkedLayerIDs
        case groupID
        case isLocked
        case locksPixels
        case locksPosition
        case locksTransparentPixels
        case isGroupExpanded
        case isClippingMask
        case labelColor
    }

    init(
        layerID: UUID,
        isVisible: Bool,
        frame: CGRect,
        opacity: Double,
        fillOpacity: Double,
        isMaskLinked: Bool,
        blendIfSourceBlack: Double,
        blendIfSourceWhite: Double,
        blendIfUnderlyingBlack: Double,
        blendIfUnderlyingWhite: Double,
        isMaskEnabled: Bool,
        maskDensity: Double,
        maskFeather: Double,
        maskFeatherSamplingScale: Double? = nil,
        hasMaskSnapshot: Bool = false,
        maskData: Data? = nil,
        isVectorMaskEnabled: Bool,
        isVectorMaskInverted: Bool = false,
        style: ImageEditorProjectLayerStyle,
        blendMode: ImageEditorBlendMode,
        kind: ImageEditorProjectLayerKind? = nil,
        smartFilters: [ImageEditorSmartFilter]? = nil,
        adjustmentSettings: ImageEditorAdjustmentSettings? = nil,
        filterSettings: ImageEditorFilterSettings? = nil,
        hasVectorMaskSnapshot: Bool = false,
        vectorMask: ImageEditorProjectShapeContent? = nil,
        linkedLayerIDs: Set<UUID>,
        groupID: UUID?,
        isLocked: Bool,
        locksPixels: Bool,
        locksPosition: Bool,
        locksTransparentPixels: Bool,
        isGroupExpanded: Bool,
        isClippingMask: Bool,
        labelColor: ImageEditorLayerLabelColor? = nil
    ) {
        self.layerID = layerID
        self.isVisible = isVisible
        self.frame = frame
        self.opacity = opacity
        self.fillOpacity = fillOpacity
        self.isMaskLinked = isMaskLinked
        self.blendIfSourceBlack = blendIfSourceBlack
        self.blendIfSourceWhite = blendIfSourceWhite
        self.blendIfUnderlyingBlack = blendIfUnderlyingBlack
        self.blendIfUnderlyingWhite = blendIfUnderlyingWhite
        self.isMaskEnabled = isMaskEnabled
        self.maskDensity = maskDensity
        self.maskFeather = maskFeather
        self.maskFeatherSamplingScale = maskFeatherSamplingScale
        self.hasMaskSnapshot = hasMaskSnapshot
        self.maskData = maskData
        self.isVectorMaskEnabled = isVectorMaskEnabled
        self.isVectorMaskInverted = isVectorMaskInverted
        self.style = style
        self.blendMode = blendMode
        self.kind = kind
        self.smartFilters = smartFilters
        self.adjustmentSettings = adjustmentSettings
        self.filterSettings = filterSettings
        self.hasVectorMaskSnapshot = hasVectorMaskSnapshot
        self.vectorMask = vectorMask
        self.linkedLayerIDs = linkedLayerIDs
        self.groupID = groupID
        self.isLocked = isLocked
        self.locksPixels = locksPixels
        self.locksPosition = locksPosition
        self.locksTransparentPixels = locksTransparentPixels
        self.isGroupExpanded = isGroupExpanded
        self.isClippingMask = isClippingMask
        self.labelColor = labelColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layerID = try container.decode(UUID.self, forKey: .layerID)
        isVisible = try container.decode(Bool.self, forKey: .isVisible)
        frame = try container.decode(CGRect.self, forKey: .frame)
        opacity = try container.decode(Double.self, forKey: .opacity)
        fillOpacity = try container.decodeIfPresent(Double.self, forKey: .fillOpacity) ?? 1
        isMaskLinked = try container.decodeIfPresent(Bool.self, forKey: .isMaskLinked) ?? true
        blendIfSourceBlack = try container.decodeIfPresent(Double.self, forKey: .blendIfSourceBlack) ?? 0
        blendIfSourceWhite = try container.decodeIfPresent(Double.self, forKey: .blendIfSourceWhite) ?? 1
        blendIfUnderlyingBlack = try container.decodeIfPresent(Double.self, forKey: .blendIfUnderlyingBlack) ?? 0
        blendIfUnderlyingWhite = try container.decodeIfPresent(Double.self, forKey: .blendIfUnderlyingWhite) ?? 1
        isMaskEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMaskEnabled) ?? true
        maskDensity = try container.decodeIfPresent(Double.self, forKey: .maskDensity) ?? 1
        maskFeather = try container.decodeIfPresent(Double.self, forKey: .maskFeather) ?? 0
        maskFeatherSamplingScale = try container.decodeIfPresent(Double.self, forKey: .maskFeatherSamplingScale)
        hasMaskSnapshot = try container.decodeIfPresent(Bool.self, forKey: .hasMaskSnapshot) ?? false
        maskData = try container.decodeIfPresent(Data.self, forKey: .maskData)
        isVectorMaskEnabled = try container.decodeIfPresent(Bool.self, forKey: .isVectorMaskEnabled) ?? true
        isVectorMaskInverted = try container.decodeIfPresent(Bool.self, forKey: .isVectorMaskInverted) ?? false
        style = try container.decodeIfPresent(ImageEditorProjectLayerStyle.self, forKey: .style)
            ?? ImageEditorProjectLayerStyle(style: ImageEditorLayerStyle())
        blendMode = try container.decode(ImageEditorBlendMode.self, forKey: .blendMode)
        kind = try container.decodeIfPresent(ImageEditorProjectLayerKind.self, forKey: .kind)
        smartFilters = try container.decodeIfPresent([ImageEditorSmartFilter].self, forKey: .smartFilters)
        adjustmentSettings = try container.decodeIfPresent(ImageEditorAdjustmentSettings.self, forKey: .adjustmentSettings)
        filterSettings = try container.decodeIfPresent(ImageEditorFilterSettings.self, forKey: .filterSettings)
        hasVectorMaskSnapshot = try container.decodeIfPresent(Bool.self, forKey: .hasVectorMaskSnapshot) ?? false
        vectorMask = try container.decodeIfPresent(ImageEditorProjectShapeContent.self, forKey: .vectorMask)
        linkedLayerIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .linkedLayerIDs) ?? []
        groupID = try container.decodeIfPresent(UUID.self, forKey: .groupID)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        locksPixels = try container.decodeIfPresent(Bool.self, forKey: .locksPixels) ?? false
        locksPosition = try container.decodeIfPresent(Bool.self, forKey: .locksPosition) ?? false
        locksTransparentPixels = try container.decodeIfPresent(Bool.self, forKey: .locksTransparentPixels) ?? false
        isGroupExpanded = try container.decodeIfPresent(Bool.self, forKey: .isGroupExpanded) ?? true
        isClippingMask = try container.decodeIfPresent(Bool.self, forKey: .isClippingMask) ?? false
        labelColor = try container.decodeIfPresent(ImageEditorLayerLabelColor.self, forKey: .labelColor)
    }
}

struct ImageEditorLayerComp: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var comment: String
    var isFavorite: Bool
    var capturesVisibility: Bool
    var capturesPosition: Bool
    var capturesAppearance: Bool
    var acknowledgedMissingLayerIDs: Set<UUID>
    var layerOrder: [UUID]
    var layerStates: [ImageEditorLayerCompLayerState]
    var selectedLayerID: UUID?
    var selectedLayerIDs: Set<UUID>
    var createdAt = Date()

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case comment
        case isFavorite
        case capturesVisibility
        case capturesPosition
        case capturesAppearance
        case acknowledgedMissingLayerIDs
        case layerOrder
        case layerStates
        case selectedLayerID
        case selectedLayerIDs
        case createdAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        comment: String = "",
        isFavorite: Bool = false,
        capturesVisibility: Bool = true,
        capturesPosition: Bool = true,
        capturesAppearance: Bool = true,
        acknowledgedMissingLayerIDs: Set<UUID> = [],
        layerOrder: [UUID],
        layerStates: [ImageEditorLayerCompLayerState],
        selectedLayerID: UUID?,
        selectedLayerIDs: Set<UUID>,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.comment = comment
        self.isFavorite = isFavorite
        self.capturesVisibility = capturesVisibility
        self.capturesPosition = capturesPosition
        self.capturesAppearance = capturesAppearance
        self.acknowledgedMissingLayerIDs = acknowledgedMissingLayerIDs
        self.layerOrder = layerOrder
        self.layerStates = layerStates
        self.selectedLayerID = selectedLayerID
        self.selectedLayerIDs = selectedLayerIDs
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        comment = try container.decodeIfPresent(String.self, forKey: .comment) ?? ""
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        capturesVisibility = try container.decodeIfPresent(
            Bool.self,
            forKey: .capturesVisibility
        ) ?? true
        capturesPosition = try container.decodeIfPresent(
            Bool.self,
            forKey: .capturesPosition
        ) ?? true
        capturesAppearance = try container.decodeIfPresent(
            Bool.self,
            forKey: .capturesAppearance
        ) ?? true
        acknowledgedMissingLayerIDs = try container.decodeIfPresent(
            Set<UUID>.self,
            forKey: .acknowledgedMissingLayerIDs
        ) ?? []
        layerStates = try container.decode([ImageEditorLayerCompLayerState].self, forKey: .layerStates)
        layerOrder = try container.decodeIfPresent([UUID].self, forKey: .layerOrder)
            ?? layerStates.map(\.layerID)
        selectedLayerID = try container.decodeIfPresent(UUID.self, forKey: .selectedLayerID)
        selectedLayerIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .selectedLayerIDs) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    @MainActor
    static func capture(name: String, document: ImageEditorDocument) -> ImageEditorLayerComp {
        ImageEditorLayerComp(
            name: name,
            layerOrder: document.layers.map(\.id),
            layerStates: document.layers.map { layer in
                ImageEditorLayerCompLayerState(
                    layerID: layer.id,
                    isVisible: layer.isVisible,
                    frame: layer.frame,
                    opacity: layer.opacity,
                    fillOpacity: layer.fillOpacity,
                    isMaskLinked: layer.isMaskLinked,
                    blendIfSourceBlack: layer.blendIfSourceBlack,
                    blendIfSourceWhite: layer.blendIfSourceWhite,
                    blendIfUnderlyingBlack: layer.blendIfUnderlyingBlack,
                    blendIfUnderlyingWhite: layer.blendIfUnderlyingWhite,
                    isMaskEnabled: layer.isMaskEnabled,
                    maskDensity: layer.maskDensity,
                    maskFeather: layer.maskFeather,
                    maskFeatherSamplingScale: layer.maskFeatherSamplingScale,
                    hasMaskSnapshot: true,
                    maskData: layer.mask?.qingtuPNGData(),
                    isVectorMaskEnabled: layer.isVectorMaskEnabled,
                    isVectorMaskInverted: layer.isVectorMaskInverted,
                    style: ImageEditorProjectLayerStyle(style: layer.style),
                    blendMode: layer.blendMode,
                    kind: ImageEditorProjectLayerKind(kind: layer.kind),
                    smartFilters: layer.smartFilters,
                    adjustmentSettings: layer.adjustmentSettings,
                    filterSettings: layer.filterSettings,
                    hasVectorMaskSnapshot: true,
                    vectorMask: layer.vectorMask.map(ImageEditorProjectShapeContent.init(content:)),
                    linkedLayerIDs: layer.linkedLayerIDs,
                    groupID: layer.groupID,
                    isLocked: layer.isLocked,
                    locksPixels: layer.locksPixels,
                    locksPosition: layer.locksPosition,
                    locksTransparentPixels: layer.locksTransparentPixels,
                    isGroupExpanded: layer.isGroupExpanded,
                    isClippingMask: layer.isClippingMask,
                    labelColor: layer.labelColor
                )
            },
            selectedLayerID: document.selectedLayerID,
            selectedLayerIDs: document.selectedLayerIDs
        )
    }
}

enum ImageEditorGuideOrientation: String, CaseIterable, Identifiable, Codable {
    case horizontal
    case vertical

    var id: String { rawValue }
}

struct ImageEditorGuide: Identifiable, Equatable, Codable {
    var id = UUID()
    var orientation: ImageEditorGuideOrientation
    var position: CGFloat
}

/// A named rectangular delivery region inspired by Fireworks slices.
/// Slices are document metadata: they do not alter pixels or layer geometry.
enum ImageEditorSliceExportConstraint: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case scale
    case width
    case height

    var id: String { rawValue }
}

struct ImageEditorSliceExportPreset: Codable, Equatable, Sendable {
    static let maximumSuffixLength = 40

    var suffix: String
    var format: ImageEditorExportFormat
    var constraint: ImageEditorSliceExportConstraint
    var value: Double

    init(
        suffix: String = "",
        format: ImageEditorExportFormat,
        constraint: ImageEditorSliceExportConstraint,
        value: Double
    ) {
        self.suffix = Self.sanitizedSuffix(suffix)
        self.format = format
        self.constraint = constraint
        self.value = value
    }

    func resolvedScale(for frame: CGRect) -> Double? {
        guard value.isFinite, value > 0 else { return nil }
        let scale: Double
        switch constraint {
        case .scale:
            scale = value
        case .width:
            guard frame.width > 0 else { return nil }
            scale = value / Double(frame.width)
        case .height:
            guard frame.height > 0 else { return nil }
            scale = value / Double(frame.height)
        }
        guard scale.isFinite,
              ImageEditorExportSettings.supportedScaleRange.contains(scale)
        else {
            return nil
        }
        return scale
    }

    static func sanitizedSuffix(_ rawValue: String) -> String {
        String(sanitizedFilenameComponent(rawValue).prefix(maximumSuffixLength))
    }

    static func sanitizedFilenameComponent(_ rawValue: String) -> String {
        let forbidden = CharacterSet.controlCharacters.union(
            CharacterSet(charactersIn: "/\\:")
        )
        let scalars = rawValue.unicodeScalars.map { scalar -> Character in
            forbidden.contains(scalar) ? "-" : Character(String(scalar))
        }
        return String(scalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func defaultSuffix(forScale scale: Double) -> String {
        guard scale.isFinite, scale != 1 else { return "" }
        let label: String
        if scale.rounded() == scale {
            label = String(Int(scale))
        } else if (scale * 10).rounded() == scale * 10 {
            label = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), scale)
        } else {
            label = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), scale)
        }
        return "@\(label)x"
    }
}

struct ImageEditorSlice: Identifiable, Equatable, Codable {
    static let maximumCount = 256
    static let maximumNameLength = 80
    static let maximumExportPresetCount = 16

    var id = UUID()
    var name: String
    var frame: CGRect
    /// Optional keeps projects created before export presets source-compatible.
    var exportPresets: [ImageEditorSliceExportPreset]?

    init(
        id: UUID = UUID(),
        name: String,
        frame: CGRect,
        exportPresets: [ImageEditorSliceExportPreset] = []
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.exportPresets = exportPresets.isEmpty ? nil : exportPresets
    }

    func normalized(canvasSize: CGSize) -> ImageEditorSlice? {
        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        let bounded = frame.standardized.integral.intersection(canvasBounds)
        guard bounded.width > 0, bounded.height > 0 else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let normalizedPresets = (exportPresets ?? [])
            .prefix(Self.maximumExportPresetCount)
            .compactMap { preset -> ImageEditorSliceExportPreset? in
                guard preset.format.supportsSliceExportPreset else { return nil }
                let normalized = ImageEditorSliceExportPreset(
                    suffix: preset.suffix,
                    format: preset.format,
                    constraint: preset.constraint,
                    value: preset.value
                )
                return normalized.resolvedScale(for: bounded) == nil ? nil : normalized
            }
        return ImageEditorSlice(
            id: id,
            name: String(trimmedName.prefix(Self.maximumNameLength)),
            frame: bounded,
            exportPresets: normalizedPresets
        )
    }
}

/// A rectangular interactive region inspired by Fireworks hotspots.
/// Hotspots are document metadata and do not alter pixels or layer geometry.
struct ImageEditorHotspot: Identifiable, Equatable, Codable {
    static let maximumCount = 256
    static let maximumNameLength = 80
    static let maximumURLLength = 2_048

    var id = UUID()
    var name: String
    var frame: CGRect
    var url: String

    init(id: UUID = UUID(), name: String, frame: CGRect, url: String = "") {
        self.id = id
        self.name = name
        self.frame = frame
        self.url = url
    }

    func normalized(canvasSize: CGSize) -> ImageEditorHotspot? {
        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        let bounded = frame.standardized.integral.intersection(canvasBounds)
        guard bounded.width > 0, bounded.height > 0 else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let trimmedURL = String(url.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maximumURLLength))
        return ImageEditorHotspot(
            id: id,
            name: String(trimmedName.prefix(Self.maximumNameLength)),
            frame: bounded,
            url: trimmedURL
        )
    }
}

struct ImageEditorDocument {
    let sourceName: String
    var canvasSize: CGSize
    var layers: [ImageEditorLayer]
    var selectedLayerID: UUID?
    var selectedLayerIDs: Set<UUID>
    var selection: ImageEditorSelection?
    var savedSelection: ImageEditorSelection?
    var alphaChannels: [ImageEditorAlphaChannel]
    var layerComps: [ImageEditorLayerComp]
    var selectedLayerCompID: UUID?
    var savedPaths: [ImageEditorSavedPath]
    var selectedSavedPathID: UUID?
    var guides: [ImageEditorGuide]
    var slices: [ImageEditorSlice] = []
    var hotspots: [ImageEditorHotspot] = []
    var areExtrasVisible: Bool
    var areGuidesVisible: Bool
    var areGuidesLocked: Bool
    var areRulersVisible: Bool
    var isGuideSnappingEnabled: Bool
    var areSelectionEdgesVisible: Bool
    var areTransformControlsVisible: Bool
    var isGridVisible: Bool
    var isGridSnappingEnabled: Bool
    var gridSpacing: CGFloat
    var designCanvasMetadata: XomoDesignCanvasMetadata?
    var globalLightAngle: CGFloat
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
        alphaChannels = []
        layerComps = []
        selectedLayerCompID = nil
        savedPaths = []
        selectedSavedPathID = nil
        guides = []
        areExtrasVisible = true
        areGuidesVisible = true
        areGuidesLocked = false
        areRulersVisible = true
        isGuideSnappingEnabled = true
        areSelectionEdgesVisible = true
        areTransformControlsVisible = true
        isGridVisible = false
        isGridSnappingEnabled = false
        gridSpacing = 32
        designCanvasMetadata = nil
        globalLightAngle = -45
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

    func colorSamplingLayerIDs(
        for source: ImageEditorColorSamplerSource,
        ignoringAdjustmentLayers: Bool
    ) -> Set<UUID>? {
        let candidates: [ImageEditorLayer]
        switch source {
        case .composite:
            candidates = layers
        case .selectedLayer:
            guard let selectedLayer else { return nil }
            if selectedLayer.isGroup {
                candidates = layers.filter { layer in
                    layer.id == selectedLayer.id
                        || isLayer(layer, descendantOf: selectedLayer.id)
                }
            } else {
                candidates = [selectedLayer]
            }
        case .currentAndBelow:
            guard let selectedLayerIndex else { return nil }
            candidates = Array(layers[...selectedLayerIndex])
        }

        // Keep only eligible leaves while filtering. Including a group ID would
        // make the compositor include every descendant, including adjustments.
        let sampledLayers = ignoringAdjustmentLayers
            ? candidates.filter { !$0.isGroup && !$0.isAdjustment }
            : candidates
        return Set(sampledLayers.map(\.id))
    }

    func layerIDsThroughSelectedLayer() -> Set<UUID>? {
        colorSamplingLayerIDs(
            for: .currentAndBelow,
            ignoringAdjustmentLayers: false
        )
    }

    var compositedImage: NSImage {
        compositedImage(includingOnly: nil)
    }

    func compositedImage(includingOnly includedLayerIDs: Set<UUID>) -> NSImage {
        compositedImage(includingOnly: Optional(includedLayerIDs))
    }

    func compositedImage(
        includingOnly includedLayerIDs: Set<UUID>,
        within parentGroupID: UUID?
    ) -> NSImage {
        guard let parentGroupID,
              let parentGroup = layers.first(where: { $0.id == parentGroupID && $0.isGroup })
        else {
            return compositedImage(includingOnly: includedLayerIDs)
        }
        return isolatedGroupCanvas(for: parentGroup, includedLayerIDs: includedLayerIDs)
    }

    private func compositedImage(includingOnly includedLayerIDs: Set<UUID>?) -> NSImage {
        var canvas = NSImage.transparent(size: canvasSize)
        for index in layers.indices {
            let layer = layers[index]
            if layer.isGroup {
                guard shouldRenderIsolatedGroup(layer, includedIn: includedLayerIDs),
                      isolatedGroupAncestor(for: layer) == nil
                else { continue }
                let groupCanvas = isolatedGroupCanvas(for: layer, includedLayerIDs: includedLayerIDs)
                let groupMask = combinedCanvasMask(layer.effectiveMask, effectiveGroupMask(for: layer))
                let maskedGroupCanvas = imageByApplyingCanvasMask(groupCanvas, mask: groupMask)
                canvas = canvas.blended(
                    with: maskedGroupCanvas,
                    mode: layer.blendMode,
                    opacity: layer.opacity * effectiveGroupOpacity(for: layer)
                ) ?? canvas
                continue
            }
            guard shouldComposite(layer, includedIn: includedLayerIDs),
                  isolatedGroupAncestor(for: layer) == nil
            else { continue }
            canvas = compositeLayer(at: index, onto: canvas, stoppingBeforeGroupID: nil, includedLayerIDs: includedLayerIDs)
        }
        return canvas
    }

    private func compositeLayer(
        at index: Int,
        onto canvas: NSImage,
        stoppingBeforeGroupID: UUID?,
        includedLayerIDs: Set<UUID>? = nil
    ) -> NSImage {
        let layer = layers[index]
        let groupOpacity = effectiveGroupOpacity(for: layer, stoppingBefore: stoppingBeforeGroupID)
        let groupMask = effectiveGroupMask(for: layer, stoppingBefore: stoppingBeforeGroupID)
        if let adjustment = layer.adjustment {
            return canvas.applyingAdjustment(
                kind: adjustment.kind,
                amount: adjustment.amount,
                settings: layer.adjustmentSettings,
                mask: effectiveCanvasMask(forLayerAt: index, layerMask: layer.effectiveMask, groupMask: groupMask),
                opacity: layer.opacity * groupOpacity
            ) ?? canvas
        }
        if let filter = layer.filter {
            return canvas.applyingFilter(
                kind: filter.kind,
                intensity: filter.intensity,
                settings: layer.filterSettings,
                mask: effectiveCanvasMask(forLayerAt: index, layerMask: layer.effectiveMask, groupMask: groupMask),
                opacity: layer.opacity * groupOpacity
            ) ?? canvas
        }

        let layerCanvas: NSImage
        let backdropMask: NSImage?
        if layer.isClippingMask,
           let clippedImage = clippedCompositingImage(forLayerAt: index) {
            layerCanvas = imageByApplyingCanvasMask(clippedImage, mask: groupMask)
            backdropMask = nil
        } else {
            let compositingImage = layer.renderedCompositingImage(globalLightAngle: globalLightAngle)
            let positionedCanvas = canvasImage(
                for: compositingImage,
                frame: layer.renderedCompositingFrame(globalLightAngle: globalLightAngle)
            )
            layerCanvas = imageByApplyingCanvasMask(positionedCanvas, mask: groupMask)
            backdropMask = layerCanvas
        }
        let backdropCanvas = canvasByApplyingBackdropBlur(
            for: layer,
            to: canvas,
            mask: backdropMask
        )
        let blendIfCanvas = layerCanvas.applyingBlendIfUnderlyingRange(
            black: layer.blendIfUnderlyingBlack,
            white: layer.blendIfUnderlyingWhite,
            backdrop: backdropCanvas
        ) ?? layerCanvas
        return backdropCanvas.blended(
            with: blendIfCanvas,
            mode: layer.blendMode,
            opacity: layer.opacity * groupOpacity
        ) ?? backdropCanvas
    }

    private func canvasByApplyingBackdropBlur(
        for layer: ImageEditorLayer,
        to canvas: NSImage,
        mask: NSImage?
    ) -> NSImage {
        guard let mask else { return canvas }
        return layer.smartFilters
            .filter { $0.isEnabled && $0.appliesToBackdrop && $0.kind == .gaussianBlur }
            .reduce(canvas) { partial, filter in
                partial.applyingFilter(
                    kind: .gaussianBlur,
                    intensity: filter.normalizedIntensity,
                    settings: filter.normalizedSettings,
                    mask: mask,
                    opacity: filter.normalizedOpacity,
                    blendMode: filter.normalizedBlendMode
                ) ?? partial
            }
    }

    private func isolatedGroupCanvas(for group: ImageEditorLayer, includedLayerIDs: Set<UUID>? = nil) -> NSImage {
        var groupCanvas = NSImage.transparent(size: canvasSize)
        for index in layers.indices {
            let layer = layers[index]
            guard layer.id != group.id,
                  isLayer(layer, descendantOf: group.id)
            else { continue }
            if layer.isGroup {
                guard shouldRenderIsolatedGroup(layer, includedIn: includedLayerIDs),
                      isolatedGroupAncestor(for: layer, stoppingBefore: group.id) == nil
                else { continue }
                let nestedCanvas = isolatedGroupCanvas(for: layer, includedLayerIDs: includedLayerIDs)
                let nestedMask = combinedCanvasMask(
                    layer.effectiveMask,
                    effectiveGroupMask(for: layer, stoppingBefore: group.id)
                )
                let maskedNestedCanvas = imageByApplyingCanvasMask(nestedCanvas, mask: nestedMask)
                groupCanvas = groupCanvas.blended(
                    with: maskedNestedCanvas,
                    mode: layer.blendMode,
                    opacity: layer.opacity * effectiveGroupOpacity(for: layer, stoppingBefore: group.id)
                ) ?? groupCanvas
                continue
            }
            guard shouldComposite(layer, includedIn: includedLayerIDs),
                  isolatedGroupAncestor(for: layer, stoppingBefore: group.id) == nil
            else { continue }
            groupCanvas = compositeLayer(
                at: index,
                onto: groupCanvas,
                stoppingBeforeGroupID: group.id,
                includedLayerIDs: includedLayerIDs
            )
        }
        return groupCanvas
    }

    func group(for layer: ImageEditorLayer) -> ImageEditorLayer? {
        guard let groupID = layer.groupID else { return nil }
        return layers.first { $0.id == groupID && $0.isGroup }
    }

    func groupDepth(for layer: ImageEditorLayer) -> Int {
        ancestorGroups(for: layer).count
    }

    func ancestorGroups(for layer: ImageEditorLayer) -> [ImageEditorLayer] {
        ancestorGroups(for: layer, stoppingBefore: nil)
    }

    private func ancestorGroups(for layer: ImageEditorLayer, stoppingBefore stopGroupID: UUID?) -> [ImageEditorLayer] {
        var ancestors: [ImageEditorLayer] = []
        var visitedIDs = Set<UUID>()
        var currentGroupID = layer.groupID
        while let groupID = currentGroupID,
              !visitedIDs.contains(groupID),
              let group = layers.first(where: { $0.id == groupID && $0.isGroup }) {
            if groupID == stopGroupID {
                break
            }
            visitedIDs.insert(groupID)
            ancestors.append(group)
            currentGroupID = group.groupID
        }
        return ancestors
    }

    func effectiveGroupOpacity(for layer: ImageEditorLayer) -> Double {
        effectiveGroupOpacity(for: layer, stoppingBefore: nil)
    }

    private func effectiveGroupOpacity(for layer: ImageEditorLayer, stoppingBefore stopGroupID: UUID?) -> Double {
        ancestorGroups(for: layer, stoppingBefore: stopGroupID).reduce(1) { partialResult, group in
            partialResult * group.opacity
        }
    }

    func effectiveGroupMask(for layer: ImageEditorLayer) -> NSImage? {
        effectiveGroupMask(for: layer, stoppingBefore: nil)
    }

    private func effectiveGroupMask(for layer: ImageEditorLayer, stoppingBefore stopGroupID: UUID?) -> NSImage? {
        let masks = ancestorGroups(for: layer, stoppingBefore: stopGroupID).compactMap(\.effectiveMask)
        guard !masks.isEmpty else { return nil }
        return masks.reduce(NSImage.opaqueMask(size: canvasSize)) { partialResult, mask in
            imageByApplyingCanvasMask(partialResult, mask: mask)
        }
    }

    private func isIsolatedGroup(_ layer: ImageEditorLayer) -> Bool {
        layer.isGroup && layer.blendMode != .passThrough && isEffectivelyVisible(layer)
    }

    private func shouldRenderIsolatedGroup(_ group: ImageEditorLayer, includedIn includedLayerIDs: Set<UUID>?) -> Bool {
        guard isIsolatedGroup(group) else { return false }
        guard let includedLayerIDs else { return true }
        if includedLayerIDs.contains(group.id) {
            return true
        }
        return layers.contains { layer in
            layer.id != group.id
                && isLayer(layer, descendantOf: group.id)
                && isLayerIncluded(layer, in: includedLayerIDs)
        }
    }

    private func isolatedGroupAncestor(for layer: ImageEditorLayer, stoppingBefore stopGroupID: UUID? = nil) -> ImageEditorLayer? {
        ancestorGroups(for: layer, stoppingBefore: stopGroupID).first(where: isIsolatedGroup)
    }

    private func isLayer(_ layer: ImageEditorLayer, descendantOf groupID: UUID) -> Bool {
        ancestorGroups(for: layer).contains { $0.id == groupID }
    }

    private func combinedCanvasMask(_ layerMask: NSImage?, _ groupMask: NSImage?) -> NSImage? {
        switch (layerMask, groupMask) {
        case (.none, .none):
            return nil
        case let (.some(layerMask), .none):
            return layerMask
        case let (.none, .some(groupMask)):
            return groupMask
        case let (.some(layerMask), .some(groupMask)):
            return imageByApplyingCanvasMask(layerMask, mask: groupMask)
        }
    }

    func clippingBaseCanvasMask(forLayerAt index: Int) -> NSImage? {
        guard layers.indices.contains(index),
              let base = clippingBase(forLayerAt: index)
        else { return nil }
        let baseImage = base.renderedCompositingImage(globalLightAngle: globalLightAngle)
        return NSImage.rendered(size: canvasSize) { _ in
            baseImage.draw(
                in: base.renderedCompositingFrame(globalLightAngle: globalLightAngle),
                from: CGRect(origin: .zero, size: baseImage.size),
                operation: .sourceOver,
                fraction: 1
            )
        }
    }

    func localEffectMask(forLayerAt index: Int) -> NSImage? {
        guard layers.indices.contains(index) else { return nil }
        let layerMask = layers[index].effectiveMask
        guard let clippingMask = clippingBaseCanvasMask(forLayerAt: index) else { return layerMask }
        return combinedCanvasMask(layerMask, clippingMask)
    }

    private func effectiveCanvasMask(forLayerAt index: Int, layerMask: NSImage?, groupMask: NSImage?) -> NSImage? {
        let localMask = combinedCanvasMask(layerMask, groupMask)
        guard let clippingMask = clippingBaseCanvasMask(forLayerAt: index) else { return localMask }
        return combinedCanvasMask(localMask, clippingMask)
    }

    private func canvasImage(for image: NSImage, frame: CGRect) -> NSImage {
        let appKitFrame = CGRect(
            x: frame.minX,
            y: canvasSize.height - frame.maxY,
            width: frame.width,
            height: frame.height
        )
        return NSImage.rendered(size: canvasSize) { _ in
            image.draw(
                in: appKitFrame,
                from: CGRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1
            )
        } ?? NSImage.transparent(size: canvasSize)
    }

    private func imageByApplyingCanvasMask(_ image: NSImage, mask: NSImage?) -> NSImage {
        guard let mask else { return image }
        return NSImage.rendered(size: image.size) { _ in
            image.draw(
                in: CGRect(origin: .zero, size: image.size),
                from: CGRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1
            )
            mask.draw(
                in: CGRect(origin: .zero, size: image.size),
                from: CGRect(origin: .zero, size: mask.size),
                operation: .destinationIn,
                fraction: 1
            )
        } ?? image
    }

    func isEffectivelyLocked(_ layer: ImageEditorLayer) -> Bool {
        layer.isLocked || ancestorGroups(for: layer).contains { $0.isLocked }
    }

    func isEffectivelyPixelsLocked(_ layer: ImageEditorLayer) -> Bool {
        isEffectivelyLocked(layer)
            || layer.locksPixels
            || ancestorGroups(for: layer).contains { $0.locksPixels }
    }

    func isEffectivelyTransparencyLocked(_ layer: ImageEditorLayer) -> Bool {
        layer.locksTransparentPixels
            || ancestorGroups(for: layer).contains { $0.locksTransparentPixels }
    }

    func isEffectivelyPositionLocked(_ layer: ImageEditorLayer) -> Bool {
        isEffectivelyLocked(layer)
            || layer.locksPosition
            || ancestorGroups(for: layer).contains { $0.locksPosition }
    }

    func isEffectivelyVisible(_ layer: ImageEditorLayer) -> Bool {
        layer.isVisible && ancestorGroups(for: layer).allSatisfy(\.isVisible)
    }

    func shouldComposite(_ layer: ImageEditorLayer) -> Bool {
        !layer.isGroup && isEffectivelyVisible(layer)
    }

    private func shouldComposite(_ layer: ImageEditorLayer, includedIn includedLayerIDs: Set<UUID>?) -> Bool {
        guard shouldComposite(layer) else { return false }
        guard let includedLayerIDs else { return true }
        return isLayerIncluded(layer, in: includedLayerIDs)
    }

    private func isLayerIncluded(_ layer: ImageEditorLayer, in includedLayerIDs: Set<UUID>) -> Bool {
        includedLayerIDs.contains(layer.id)
            || ancestorGroups(for: layer).contains { includedLayerIDs.contains($0.id) }
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
        }
    }

    func clippedCompositingImage(forLayerAt index: Int) -> NSImage? {
        guard layers.indices.contains(index),
              let base = clippingBase(forLayerAt: index)
        else { return nil }
        let layer = layers[index]
        let layerImage = layer.renderedCompositingImage(globalLightAngle: globalLightAngle)
        let baseImage = base.renderedCompositingImage(globalLightAngle: globalLightAngle)
        return NSImage.rendered(size: canvasSize) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.saveGState()
            layerImage.draw(
                in: layer.renderedCompositingFrame(globalLightAngle: globalLightAngle),
                from: CGRect(origin: .zero, size: layerImage.size),
                operation: .sourceOver,
                fraction: 1
            )
            baseImage.draw(
                in: base.renderedCompositingFrame(globalLightAngle: globalLightAngle),
                from: CGRect(origin: .zero, size: baseImage.size),
                operation: .destinationIn,
                fraction: 1
            )
            context.restoreGState()
        }
    }
}
