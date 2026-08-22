//
//  ImageEditorBrushPresetQuery.swift
//  veilpic
//
//  Created by Codex on 2026/8/22.
//

import Foundation

enum ImageEditorBrushPresetScope: String, CaseIterable, Identifiable {
    case all
    case builtIn
    case custom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.brushPreset.scope.\(rawValue)")
    }
}

enum ImageEditorBrushPresetCollection: String, CaseIterable, Identifiable {
    case all
    case favorites
    case recent

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.brushPreset.collection.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .favorites: return "star.fill"
        case .recent: return "clock.fill"
        }
    }
}

enum ImageEditorBrushPresetPanelLayout: String, CaseIterable, Identifiable {
    static let storageKey = "im.some.xomo.imageEditor.brushPresetPanelLayout"

    case list
    case grid

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.brushPreset.layout.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let rawValue = defaults.string(forKey: storageKey),
              let layout = Self(rawValue: rawValue)
        else { return .list }
        return layout
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }
}

enum ImageEditorBrushPresetGridDensity: String, CaseIterable, Identifiable {
    static let storageKey = "im.some.xomo.imageEditor.brushPresetGridDensity"

    case compact
    case regular
    case large

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.brushPreset.gridDensity.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .compact: return "square.grid.3x3"
        case .regular: return "square.grid.2x2"
        case .large: return "rectangle.grid.1x2"
        }
    }

    var columnCount: Int {
        switch self {
        case .compact: return 3
        case .regular: return 2
        case .large: return 1
        }
    }

    var thumbnailSize: CGFloat {
        switch self {
        case .compact: return 36
        case .regular: return 58
        case .large: return 80
        }
    }

    var minimumTileHeight: CGFloat {
        switch self {
        case .compact: return 72
        case .regular: return 92
        case .large: return 118
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let rawValue = defaults.string(forKey: storageKey),
              let density = Self(rawValue: rawValue)
        else { return .regular }
        return density
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }
}

enum ImageEditorBrushPresetSortOrder: String, CaseIterable, Identifiable {
    static let storageKey = "im.some.xomo.imageEditor.brushPresetSortOrder"

    case catalog
    case nameAscending
    case nameDescending

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.brushPreset.sort.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .catalog: return "list.bullet"
        case .nameAscending: return "arrow.up"
        case .nameDescending: return "arrow.down"
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let rawValue = defaults.string(forKey: storageKey),
              let order = Self(rawValue: rawValue)
        else { return .catalog }
        return order
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }

    func sort(_ presets: [ImageEditorBrushPreset]) -> [ImageEditorBrushPreset] {
        guard self != .catalog else { return presets }
        return presets.enumerated().sorted { lhs, rhs in
            let comparison = lhs.element.title.compare(
                rhs.element.title,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            if comparison == .orderedSame {
                return lhs.offset < rhs.offset
            }
            return self == .nameAscending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }.map(\.element)
    }
}

struct ImageEditorBrushPresetQuery: Equatable {
    var searchText: String
    var scope: ImageEditorBrushPresetScope
    var collection: ImageEditorBrushPresetCollection
    var sortOrder: ImageEditorBrushPresetSortOrder
    var favoriteIDs: Set<String>
    var recentIDs: [String]

    init(
        searchText: String,
        scope: ImageEditorBrushPresetScope,
        collection: ImageEditorBrushPresetCollection = .all,
        sortOrder: ImageEditorBrushPresetSortOrder = .catalog,
        favoriteIDs: Set<String> = [],
        recentIDs: [String] = []
    ) {
        self.searchText = searchText
        self.scope = scope
        self.collection = collection
        self.sortOrder = sortOrder
        self.favoriteIDs = favoriteIDs
        self.recentIDs = recentIDs
    }

    func filter(_ presets: [ImageEditorBrushPreset]) -> [ImageEditorBrushPreset] {
        let filteredPresets: [ImageEditorBrushPreset]
        switch collection {
        case .all:
            filteredPresets = presets.filter(matches)
        case .favorites:
            filteredPresets = presets.filter { favoriteIDs.contains($0.id) && matches($0) }
        case .recent:
            let indexedPresets = Dictionary(
                uniqueKeysWithValues: presets.map { ($0.id, $0) }
            )
            filteredPresets = recentIDs.compactMap { indexedPresets[$0] }.filter(matches)
        }
        return sortOrder.sort(filteredPresets)
    }

    func repairedSelectionID(
        _ currentID: String?,
        in presets: [ImageEditorBrushPreset]
    ) -> String? {
        let filteredPresets = filter(presets)
        if let currentID, filteredPresets.contains(where: { $0.id == currentID }) {
            return currentID
        }
        return filteredPresets.first?.id
    }

    private func matches(_ preset: ImageEditorBrushPreset) -> Bool {
        guard matchesScope(preset) else { return false }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return preset.title.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ) != nil
    }

    private func matchesScope(_ preset: ImageEditorBrushPreset) -> Bool {
        switch scope {
        case .all:
            return true
        case .builtIn:
            return preset.isBuiltIn
        case .custom:
            return !preset.isBuiltIn
        }
    }
}
