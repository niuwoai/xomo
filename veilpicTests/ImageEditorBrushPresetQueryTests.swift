//
//  ImageEditorBrushPresetQueryTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/22.
//

import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorBrushPresetQueryTests {
    @Test func panelLayoutDefaultsToListAndPersistsGridChoice() {
        let suiteName = "ImageEditorBrushPresetQueryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(ImageEditorBrushPresetPanelLayout.load(from: defaults) == .list)

        ImageEditorBrushPresetPanelLayout.grid.save(to: defaults)
        #expect(ImageEditorBrushPresetPanelLayout.load(from: defaults) == .grid)

        defaults.set("unsupported-layout", forKey: ImageEditorBrushPresetPanelLayout.storageKey)
        #expect(ImageEditorBrushPresetPanelLayout.load(from: defaults) == .list)
    }

    @Test func sortPreferenceDefaultsToCatalogAndPersistsNameOrder() {
        let suiteName = "ImageEditorBrushPresetQueryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(ImageEditorBrushPresetSortOrder.load(from: defaults) == .catalog)

        ImageEditorBrushPresetSortOrder.nameDescending.save(to: defaults)
        #expect(ImageEditorBrushPresetSortOrder.load(from: defaults) == .nameDescending)

        defaults.set("unsupported-order", forKey: ImageEditorBrushPresetSortOrder.storageKey)
        #expect(ImageEditorBrushPresetSortOrder.load(from: defaults) == .catalog)
    }

    @Test func querySortsVisiblePresetsByNameAndKeepsEquivalentNamesStable() {
        let presets = [
            preset(id: "zulu", name: "Zulu"),
            preset(id: "alpha-one", name: "Alpha"),
            preset(id: "alpha-two", name: "álpha")
        ]

        let ascending = ImageEditorBrushPresetQuery(
            searchText: "",
            scope: .all,
            sortOrder: .nameAscending
        ).filter(presets)
        let descending = ImageEditorBrushPresetQuery(
            searchText: "",
            scope: .all,
            sortOrder: .nameDescending
        ).filter(presets)

        #expect(ascending.map(\.id) == ["alpha-one", "alpha-two", "zulu"])
        #expect(descending.map(\.id) == ["zulu", "alpha-one", "alpha-two"])
    }

    @Test func queryMatchesCaseAndDiacriticsWithoutChangingCatalogOrder() {
        let presets = [
            preset(id: "built-in", name: "Soft Round", isBuiltIn: true),
            preset(id: "custom-one", name: "Néon Grain"),
            preset(id: "custom-two", name: "Neon Ink")
        ]

        let result = ImageEditorBrushPresetQuery(
            searchText: "  NEON ",
            scope: .all
        ).filter(presets)

        #expect(result.map(\.id) == ["custom-one", "custom-two"])
    }

    @Test func sourceScopeSeparatesBuiltInAndCustomBrushPresets() {
        let presets = [
            preset(id: "built-in-one", name: "Round", isBuiltIn: true),
            preset(id: "custom-one", name: "Ink"),
            preset(id: "built-in-two", name: "Hard", isBuiltIn: true),
            preset(id: "custom-two", name: "Grain")
        ]

        let builtIns = ImageEditorBrushPresetQuery(searchText: "", scope: .builtIn)
            .filter(presets)
        let customs = ImageEditorBrushPresetQuery(searchText: "", scope: .custom)
            .filter(presets)

        #expect(builtIns.map(\.id) == ["built-in-one", "built-in-two"])
        #expect(customs.map(\.id) == ["custom-one", "custom-two"])
    }

    @Test func favoriteAndRecentCollectionsKeepTheirAuthoritativeOrdering() {
        let presets = [
            preset(id: "built-in", name: "Round", isBuiltIn: true),
            preset(id: "custom-one", name: "Detail Ink"),
            preset(id: "custom-two", name: "Texture Ink")
        ]
        let favorites = ImageEditorBrushPresetQuery(
            searchText: "ink",
            scope: .all,
            collection: .favorites,
            favoriteIDs: ["built-in", "custom-two"]
        ).filter(presets)
        let recent = ImageEditorBrushPresetQuery(
            searchText: "ink",
            scope: .custom,
            collection: .recent,
            recentIDs: ["custom-two", "built-in", "custom-one"]
        ).filter(presets)

        #expect(favorites.map(\.id) == ["custom-two"])
        #expect(recent.map(\.id) == ["custom-two", "custom-one"])
    }

    @Test func queryRepairsSelectionOnlyWhenTheCurrentPresetIsHidden() {
        let presets = [
            preset(id: "round", name: "Round", isBuiltIn: true),
            preset(id: "ink", name: "Studio Ink")
        ]
        let all = ImageEditorBrushPresetQuery(searchText: "", scope: .all)
        let ink = ImageEditorBrushPresetQuery(searchText: "ink", scope: .all)
        let missing = ImageEditorBrushPresetQuery(searchText: "chalk", scope: .all)

        #expect(all.repairedSelectionID("round", in: presets) == "round")
        #expect(ink.repairedSelectionID("round", in: presets) == "ink")
        #expect(missing.repairedSelectionID("round", in: presets) == nil)
    }

    @Test func brushesPanelConnectsSearchCollectionsAndSharedPresetActions() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manager = try source(root, "veilpic/ImageEditorBrushPresetPanel.swift")
        let editor = try source(root, "veilpic/ImageEditorView.swift")
        let menuBar = try source(root, "veilpic/ImageEditorMenuBar.swift")

        #expect(manager.contains("ImageEditorBrushPresetQuery("))
        #expect(manager.contains("image-editor-brush-preset-search"))
        #expect(manager.contains("image-editor-brush-preset-scope"))
        #expect(manager.contains("image-editor-brush-preset-collection"))
        #expect(manager.contains("image-editor-brush-preset-layout"))
        #expect(manager.contains("image-editor-brush-preset-sort"))
        #expect(manager.contains("ImageEditorBrushPresetPanelLayout.load()"))
        #expect(manager.contains("layout.save()"))
        #expect(manager.contains("ImageEditorBrushPresetSortOrder.load()"))
        #expect(manager.contains("sortOrder.save()"))
        #expect(manager.contains("LazyVGrid(columns: presetGridColumns"))
        #expect(manager.contains("presetTile(preset)"))
        #expect(manager.contains("query.repairedSelectionID"))
        #expect(manager.contains("viewModel.applyBrushPreset(preset)"))
        #expect(manager.contains("viewModel.setBrushPresetFavorite("))
        #expect(manager.contains("viewModel.renameCustomBrushPreset("))
        #expect(manager.contains("viewModel.chooseBrushPresetImportFile()"))
        #expect(editor.contains("ImageEditorBrushPresetManager(viewModel: viewModel)"))
        #expect(editor.contains("viewModel.isBrushPresetManagerPresented = true"))
        #expect(menuBar.contains("viewModel.isBrushPresetManagerPresented = true"))
        #expect(menuBar.contains("NSF5FunctionKey"))
        #expect(!menuBar.contains("viewModel.statusText = viewModel.brushesPanelSummaryText"))
    }

    private func preset(
        id: String,
        name: String,
        isBuiltIn: Bool = false
    ) -> ImageEditorBrushPreset {
        ImageEditorBrushPreset(
            id: id,
            name: name,
            size: 24,
            isBuiltIn: isBuiltIn
        )
    }

    private func source(_ root: URL, _ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
