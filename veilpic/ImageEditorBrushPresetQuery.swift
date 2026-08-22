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

struct ImageEditorBrushPresetQuery: Equatable {
    var searchText: String
    var scope: ImageEditorBrushPresetScope
    var collection: ImageEditorBrushPresetCollection
    var favoriteIDs: Set<String>
    var recentIDs: [String]

    init(
        searchText: String,
        scope: ImageEditorBrushPresetScope,
        collection: ImageEditorBrushPresetCollection = .all,
        favoriteIDs: Set<String> = [],
        recentIDs: [String] = []
    ) {
        self.searchText = searchText
        self.scope = scope
        self.collection = collection
        self.favoriteIDs = favoriteIDs
        self.recentIDs = recentIDs
    }

    func filter(_ presets: [ImageEditorBrushPreset]) -> [ImageEditorBrushPreset] {
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
