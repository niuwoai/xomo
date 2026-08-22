//
//  ImageEditorBrushPresetUsage.swift
//  veilpic
//
//  Created by Codex on 2026/8/22.
//

import Foundation

struct ImageEditorBrushPresetUsagePreferences: Codable, Equatable {
    static let storageKey = "im.some.xomo.imageEditor.brushPresetUsage"
    static let maximumRecentCount = 8

    var favoriteIDs: [String]
    var recentIDs: [String]

    var normalized: ImageEditorBrushPresetUsagePreferences {
        ImageEditorBrushPresetUsagePreferences(
            favoriteIDs: Self.uniqueNonemptyIDs(favoriteIDs),
            recentIDs: Array(
                Self.uniqueNonemptyIDs(recentIDs).prefix(Self.maximumRecentCount)
            )
        )
    }

    func pruned(to knownPresetIDs: Set<String>) -> ImageEditorBrushPresetUsagePreferences {
        let normalized = normalized
        return ImageEditorBrushPresetUsagePreferences(
            favoriteIDs: normalized.favoriteIDs.filter(knownPresetIDs.contains),
            recentIDs: normalized.recentIDs.filter(knownPresetIDs.contains)
        )
    }

    static func load(from defaults: UserDefaults) -> ImageEditorBrushPresetUsagePreferences {
        guard let data = defaults.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(
                ImageEditorBrushPresetUsagePreferences.self,
                from: data
              )
        else {
            return ImageEditorBrushPresetUsagePreferences(favoriteIDs: [], recentIDs: [])
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
    var favoriteBrushPresets: [ImageEditorBrushPreset] {
        let favoriteIDs = Set(favoriteBrushPresetIDs)
        return brushPresets.filter { favoriteIDs.contains($0.id) }
    }

    var recentBrushPresets: [ImageEditorBrushPreset] {
        let indexedPresets = Dictionary(uniqueKeysWithValues: brushPresets.map { ($0.id, $0) })
        return recentBrushPresetIDs.compactMap { indexedPresets[$0] }
    }

    func isFavoriteBrushPreset(id: String) -> Bool {
        favoriteBrushPresetIDs.contains(id)
    }

    @discardableResult
    func setBrushPresetFavorite(id: String, isFavorite: Bool) -> Bool {
        guard let preset = brushPresets.first(where: { $0.id == id }) else {
            statusText = L10n.text("imageEditor.status.brushPresetFavoriteUnavailable")
            return false
        }
        let wasFavorite = favoriteBrushPresetIDs.contains(id)
        guard wasFavorite != isFavorite else { return true }

        if isFavorite {
            favoriteBrushPresetIDs.append(id)
        } else {
            favoriteBrushPresetIDs.removeAll { $0 == id }
        }
        persistBrushPresetUsagePreferences()
        statusText = L10n.format(
            isFavorite
                ? "imageEditor.status.brushPresetFavorited"
                : "imageEditor.status.brushPresetUnfavorited",
            preset.title
        )
        return true
    }

    func recordBrushPresetUse(id: String) {
        guard brushPresets.contains(where: { $0.id == id }) else { return }
        recentBrushPresetIDs.removeAll { $0 == id }
        recentBrushPresetIDs.insert(id, at: 0)
        if recentBrushPresetIDs.count > ImageEditorBrushPresetUsagePreferences.maximumRecentCount {
            recentBrushPresetIDs.removeLast(
                recentBrushPresetIDs.count
                    - ImageEditorBrushPresetUsagePreferences.maximumRecentCount
            )
        }
        persistBrushPresetUsagePreferences()
    }

    func removeBrushPresetUsage(id: String) {
        let previousFavorites = favoriteBrushPresetIDs
        let previousRecent = recentBrushPresetIDs
        favoriteBrushPresetIDs.removeAll { $0 == id }
        recentBrushPresetIDs.removeAll { $0 == id }
        guard previousFavorites != favoriteBrushPresetIDs
                || previousRecent != recentBrushPresetIDs
        else { return }
        persistBrushPresetUsagePreferences()
    }

    func pruneBrushPresetUsageToKnownPresets() {
        let pruned = ImageEditorBrushPresetUsagePreferences(
            favoriteIDs: favoriteBrushPresetIDs,
            recentIDs: recentBrushPresetIDs
        ).pruned(to: Set(brushPresets.map(\.id)))
        guard pruned.favoriteIDs != favoriteBrushPresetIDs
                || pruned.recentIDs != recentBrushPresetIDs
        else { return }
        favoriteBrushPresetIDs = pruned.favoriteIDs
        recentBrushPresetIDs = pruned.recentIDs
        persistBrushPresetUsagePreferences()
    }
}
