//
//  ImageEditorLayerStylePresetUsage.swift
//  veilpic
//
//  Created by Codex on 2026/7/14.
//

import Foundation

struct ImageEditorLayerStylePresetUsagePreferences: Codable, Equatable {
    static let storageKey = "im.some.xomo.imageEditor.layerStylePresetUsage"
    static let maximumRecentCount = 8

    var favoriteIDs: [String]
    var recentIDs: [String]

    var normalized: ImageEditorLayerStylePresetUsagePreferences {
        ImageEditorLayerStylePresetUsagePreferences(
            favoriteIDs: Self.uniqueNonemptyIDs(favoriteIDs),
            recentIDs: Array(
                Self.uniqueNonemptyIDs(recentIDs).prefix(Self.maximumRecentCount)
            )
        )
    }

    func pruned(
        to knownPresetIDs: Set<String>
    ) -> ImageEditorLayerStylePresetUsagePreferences {
        let normalized = normalized
        return ImageEditorLayerStylePresetUsagePreferences(
            favoriteIDs: normalized.favoriteIDs.filter(knownPresetIDs.contains),
            recentIDs: normalized.recentIDs.filter(knownPresetIDs.contains)
        )
    }

    static func load(from defaults: UserDefaults) -> ImageEditorLayerStylePresetUsagePreferences {
        guard let data = defaults.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(
                ImageEditorLayerStylePresetUsagePreferences.self,
                from: data
              )
        else {
            return ImageEditorLayerStylePresetUsagePreferences(
                favoriteIDs: [],
                recentIDs: []
            )
        }
        return preferences.normalized
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func uniqueNonemptyIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.compactMap { id in
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }
}

@MainActor
extension ImageEditorViewModel {
    var favoriteLayerStylePresets: [ImageEditorLayerStylePreset] {
        let favoriteIDs = Set(favoriteLayerStylePresetIDs)
        return availableLayerStylePresets.filter { favoriteIDs.contains($0.id) }
    }

    var recentLayerStylePresets: [ImageEditorLayerStylePreset] {
        let indexedPresets = Dictionary(
            uniqueKeysWithValues: availableLayerStylePresets.map { ($0.id, $0) }
        )
        return recentLayerStylePresetIDs.compactMap { indexedPresets[$0] }
    }

    func isFavoriteLayerStylePreset(id: String) -> Bool {
        favoriteLayerStylePresetIDs.contains(id)
    }

    @discardableResult
    func setLayerStylePresetFavorite(id: String, isFavorite: Bool) -> Bool {
        guard let preset = layerStylePreset(id: id) else {
            statusText = L10n.text("imageEditor.status.layerStylePresetMissing")
            return false
        }
        let wasFavorite = favoriteLayerStylePresetIDs.contains(id)
        guard wasFavorite != isFavorite else { return true }

        if isFavorite {
            favoriteLayerStylePresetIDs.append(id)
        } else {
            favoriteLayerStylePresetIDs.removeAll { $0 == id }
        }
        persistLayerStylePresetUsagePreferences()
        statusText = L10n.format(
            isFavorite
                ? "imageEditor.status.layerStylePresetFavorited"
                : "imageEditor.status.layerStylePresetUnfavorited",
            preset.title
        )
        return true
    }

    func recordLayerStylePresetUse(id: String) {
        guard layerStylePreset(id: id) != nil else { return }
        recentLayerStylePresetIDs.removeAll { $0 == id }
        recentLayerStylePresetIDs.insert(id, at: 0)
        if recentLayerStylePresetIDs.count
            > ImageEditorLayerStylePresetUsagePreferences.maximumRecentCount {
            recentLayerStylePresetIDs.removeLast(
                recentLayerStylePresetIDs.count
                    - ImageEditorLayerStylePresetUsagePreferences.maximumRecentCount
            )
        }
        persistLayerStylePresetUsagePreferences()
    }

    func removeLayerStylePresetUsage(id: String) {
        let previousFavorites = favoriteLayerStylePresetIDs
        let previousRecent = recentLayerStylePresetIDs
        favoriteLayerStylePresetIDs.removeAll { $0 == id }
        recentLayerStylePresetIDs.removeAll { $0 == id }
        guard previousFavorites != favoriteLayerStylePresetIDs
                || previousRecent != recentLayerStylePresetIDs
        else { return }
        persistLayerStylePresetUsagePreferences()
    }
}
