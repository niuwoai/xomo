//
//  ImageEditorLayerStylePresetQuery.swift
//  veilpic
//
//  Created by Codex on 2026/7/14.
//

import Foundation

enum ImageEditorLayerStylePresetScope: String, CaseIterable, Identifiable {
    case all
    case builtIn
    case custom

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.layerStylePreset.scope.\(rawValue)")
    }
}

enum ImageEditorLayerStylePresetCollection: String, CaseIterable, Identifiable {
    case all
    case favorites
    case recent

    var id: String { rawValue }

    var title: String {
        L10n.text("imageEditor.layerStylePreset.collection.\(rawValue)")
    }

    var symbolName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .favorites: return "star.fill"
        case .recent: return "clock.fill"
        }
    }
}

struct ImageEditorLayerStylePresetQuery: Equatable {
    var searchText: String
    var scope: ImageEditorLayerStylePresetScope
    var collection: ImageEditorLayerStylePresetCollection
    var favoriteIDs: Set<String>
    var recentIDs: [String]

    init(
        searchText: String,
        scope: ImageEditorLayerStylePresetScope,
        collection: ImageEditorLayerStylePresetCollection = .all,
        favoriteIDs: Set<String> = [],
        recentIDs: [String] = []
    ) {
        self.searchText = searchText
        self.scope = scope
        self.collection = collection
        self.favoriteIDs = favoriteIDs
        self.recentIDs = recentIDs
    }

    func filter(
        _ presets: [ImageEditorLayerStylePreset]
    ) -> [ImageEditorLayerStylePreset] {
        switch collection {
        case .all:
            return presets.filter(matches)
        case .favorites:
            return presets.filter { favoriteIDs.contains($0.id) && matches($0) }
        case .recent:
            let indexedPresets = Dictionary(
                uniqueKeysWithValues: presets.map { ($0.id, $0) }
            )
            return recentIDs.compactMap { indexedPresets[$0] }.filter(matches)
        }
    }

    func repairedSelectionID(
        _ currentID: String?,
        in presets: [ImageEditorLayerStylePreset]
    ) -> String? {
        let filteredPresets = filter(presets)
        if let currentID, filteredPresets.contains(where: { $0.id == currentID }) {
            return currentID
        }
        return filteredPresets.first?.id
    }

    private func matches(_ preset: ImageEditorLayerStylePreset) -> Bool {
        guard matchesScope(preset) else { return false }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return preset.title.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ) != nil
    }

    private func matchesScope(_ preset: ImageEditorLayerStylePreset) -> Bool {
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
