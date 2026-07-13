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

struct ImageEditorLayerStylePresetQuery: Equatable {
    var searchText: String
    var scope: ImageEditorLayerStylePresetScope

    func filter(
        _ presets: [ImageEditorLayerStylePreset]
    ) -> [ImageEditorLayerStylePreset] {
        presets.filter(matches)
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
