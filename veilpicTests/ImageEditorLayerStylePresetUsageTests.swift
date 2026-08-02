//
//  ImageEditorLayerStylePresetUsageTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerStylePresetUsageTests {
    @Test func usagePreferencesNormalizeAndRoundTripFavoriteAndRecentIDs() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let preferences = ImageEditorLayerStylePresetUsagePreferences(
            favoriteIDs: ["builtin.softShadow", "", "builtin.softShadow", "custom-one"],
            recentIDs: ["custom-9", "custom-8", "custom-9", "", "custom-7", "custom-6", "custom-5", "custom-4", "custom-3", "custom-2", "custom-1"]
        )

        preferences.save(to: context.defaults)
        let restored = ImageEditorLayerStylePresetUsagePreferences.load(from: context.defaults)

        #expect(restored.favoriteIDs == ["builtin.softShadow", "custom-one"])
        #expect(restored.recentIDs == ["custom-9", "custom-8", "custom-7", "custom-6", "custom-5", "custom-4", "custom-3", "custom-2"])
    }

    @Test func favoritesPersistWithoutHistoryAndDeletingCustomPresetPrunesUsage() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        let preset = try createPreset(named: "Favorite", viewModel: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.setLayerStylePresetFavorite(id: preset.id, isFavorite: true))
        #expect(viewModel.setLayerStylePresetFavorite(id: preset.id, isFavorite: false))
        #expect(viewModel.favoriteLayerStylePresetIDs.isEmpty)
        #expect(viewModel.setLayerStylePresetFavorite(id: preset.id, isFavorite: true))
        viewModel.recordLayerStylePresetUse(id: preset.id)
        #expect(viewModel.favoriteLayerStylePresetIDs == [preset.id])
        #expect(viewModel.recentLayerStylePresetIDs == [preset.id])
        #expect(viewModel.document.history.count == historyCount)

        let reopened = makeViewModel(defaults: context.defaults)
        #expect(reopened.favoriteLayerStylePresetIDs == [preset.id])
        #expect(reopened.recentLayerStylePresetIDs == [preset.id])
        let restored = try #require(reopened.layerStylePreset(id: preset.id))
        reopened.deleteLayerStylePreset(restored)
        #expect(reopened.favoriteLayerStylePresetIDs.isEmpty)
        #expect(reopened.recentLayerStylePresetIDs.isEmpty)

        let afterDeletion = makeViewModel(defaults: context.defaults)
        #expect(afterDeletion.favoriteLayerStylePresetIDs.isEmpty)
        #expect(afterDeletion.recentLayerStylePresetIDs.isEmpty)
    }

    @Test func recentUsageIsDeduplicatedCappedAndMostRecentFirst() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        for index in 0..<4 {
            try createPreset(named: "Custom \(index)", viewModel: viewModel)
        }
        let ids = viewModel.availableLayerStylePresets.map(\.id)
        #expect(ids.count == 10)

        ids.forEach { viewModel.recordLayerStylePresetUse(id: $0) }
        #expect(viewModel.recentLayerStylePresetIDs == Array(ids.reversed().prefix(8)))

        let reusedID = ids[4]
        viewModel.recordLayerStylePresetUse(id: reusedID)
        #expect(viewModel.recentLayerStylePresetIDs.first == reusedID)
        #expect(viewModel.recentLayerStylePresetIDs.filter { $0 == reusedID }.count == 1)

        let reopened = makeViewModel(defaults: context.defaults)
        #expect(reopened.recentLayerStylePresetIDs == viewModel.recentLayerStylePresetIDs)
    }

    @Test func queryFiltersFavoritesAndOrdersRecentResultsByUsage() {
        let presets = ImageEditorLayerStyleBuiltInPresetCatalog.presets + [
            preset(id: "custom-shadow", name: "Shadow Card"),
            preset(id: "custom-glow", name: "Glow Card")
        ]
        let favoriteQuery = ImageEditorLayerStylePresetQuery(
            searchText: "",
            scope: .all,
            collection: .favorites,
            favoriteIDs: ["builtin.neonGlow", "custom-shadow"]
        )
        let recentQuery = ImageEditorLayerStylePresetQuery(
            searchText: "",
            scope: .all,
            collection: .recent,
            recentIDs: ["custom-glow", "builtin.neonGlow", "custom-shadow"]
        )

        #expect(favoriteQuery.filter(presets).map(\.id) == ["builtin.neonGlow", "custom-shadow"])
        #expect(
            recentQuery.filter(presets).map(\.id)
                == ["custom-glow", "builtin.neonGlow", "custom-shadow"]
        )
    }

    @Test func managerMenuAndAutomationExposeFavoritesAndRecentUsage() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manager = try source(root, "veilpic/ImageEditorLayerStylePresetManager.swift")
        let menu = try source(root, "veilpic/ImageEditorLayerStylePresets.swift")
        let automation = try source(root, "veilpic/XomoAutomationRegistry.swift")

        #expect(manager.contains("image-editor-layer-style-preset-collection"))
        #expect(manager.contains("setLayerStylePresetFavorite"))
        #expect(menu.contains("favoriteLayerStylePresets"))
        #expect(menu.contains("recentLayerStylePresets"))
        #expect(automation.contains("presetFavorite"))
        #expect(automation.contains("presetFavorites"))
        #expect(automation.contains("presetRecent"))
    }

    private func createPreset(
        named name: String,
        viewModel: ImageEditorViewModel
    ) throws -> ImageEditorLayerStylePreset {
        let index = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[index].style.strokeEnabled = true
        viewModel.document.layers[index].style.strokeWidth += 1
        return try #require(viewModel.createLayerStylePresetFromSelectedLayer(name: name))
    }

    private func preset(id: String, name: String) -> ImageEditorLayerStylePreset {
        var style = ImageEditorLayerStyle()
        style.strokeEnabled = true
        return ImageEditorLayerStylePreset(
            id: id,
            name: name,
            style: ImageEditorProjectLayerStyle(style: style)
        )
    }

    private func source(_ root: URL, _ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private func makeContext() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "ImageEditorLayerStylePresetUsageTests.\(UUID().uuidString)"
        return (suiteName, UserDefaults(suiteName: suiteName) ?? .standard)
    }

    private func makeViewModel(defaults: UserDefaults) -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "preset-usage.png",
            image: NSImage.transparent(size: NSSize(width: 48, height: 36)),
            preferencesDefaults: defaults
        ) { _ in }
    }
}
