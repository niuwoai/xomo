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

    @Test func gridDensityDefaultsToRegularAndPersistsLargeThumbnails() {
        let suiteName = "ImageEditorBrushPresetQueryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(ImageEditorBrushPresetGridDensity.load(from: defaults) == .regular)

        ImageEditorBrushPresetGridDensity.large.save(to: defaults)
        #expect(ImageEditorBrushPresetGridDensity.load(from: defaults) == .large)

        defaults.set("unsupported-density", forKey: ImageEditorBrushPresetGridDensity.storageKey)
        #expect(ImageEditorBrushPresetGridDensity.load(from: defaults) == .regular)
    }

    @Test func gridDensityMapsCompactRegularAndLargeToDistinctUsefulMetrics() {
        let densities = ImageEditorBrushPresetGridDensity.allCases

        #expect(densities.map(\.columnCount) == [3, 2, 1])
        #expect(densities.map(\.thumbnailSize) == [36, 58, 80])
        #expect(densities.map(\.minimumTileHeight) == [72, 92, 118])
    }

    @Test func dropPolicyAcceptsExactlyOneLocalBrushLibrary() {
        let library = URL(fileURLWithPath: "/tmp/Studio.xomobrushes")
        let uppercaseLibrary = URL(fileURLWithPath: "/tmp/Studio.XOMOBRUSHES")

        #expect(ImageEditorBrushPresetDropPolicy.acceptedURL(from: [library]) == library)
        #expect(
            ImageEditorBrushPresetDropPolicy.acceptedURL(from: [uppercaseLibrary])
                == uppercaseLibrary
        )
        #expect(ImageEditorBrushPresetDropPolicy.acceptedURL(from: []) == nil)
        #expect(ImageEditorBrushPresetDropPolicy.acceptedURL(from: [library, library]) == nil)
        #expect(
            ImageEditorBrushPresetDropPolicy.acceptedURL(
                from: [URL(fileURLWithPath: "/tmp/Studio.json")]
            ) == nil
        )
        #expect(
            ImageEditorBrushPresetDropPolicy.acceptedURL(
                from: [URL(string: "https://example.com/Studio.xomobrushes")!]
            ) == nil
        )
    }

    @Test func reorderPolicyAcceptsOneCustomPresetOnlyInCatalogCollection() {
        let first = preset(id: "first", name: "First")
        let second = preset(id: "second", name: "Second")
        let third = preset(id: "third", name: "Third")
        let builtIn = preset(id: "built-in", name: "Built In", isBuiltIn: true)
        let customPresets = [first, second, third]

        #expect(ImageEditorBrushPresetReorderPolicy.canReorder(
            first,
            collection: .all,
            sortOrder: .catalog
        ))
        #expect(!ImageEditorBrushPresetReorderPolicy.canReorder(
            builtIn,
            collection: .all,
            sortOrder: .catalog
        ))
        #expect(!ImageEditorBrushPresetReorderPolicy.canReorder(
            first,
            collection: .favorites,
            sortOrder: .catalog
        ))
        #expect(!ImageEditorBrushPresetReorderPolicy.canReorder(
            first,
            collection: .all,
            sortOrder: .nameAscending
        ))
        #expect(
            ImageEditorBrushPresetReorderPolicy.resolvedMove(
                draggedIDs: [first.id],
                onto: third.id,
                customPresets: customPresets
            ) == ImageEditorBrushPresetReorderMove(
                sourceID: first.id,
                destinationIndex: 2
            )
        )
        #expect(
            ImageEditorBrushPresetReorderPolicy.resolvedMove(
                draggedIDs: [third.id],
                onto: first.id,
                customPresets: customPresets
            ) == ImageEditorBrushPresetReorderMove(
                sourceID: third.id,
                destinationIndex: 0
            )
        )
        #expect(ImageEditorBrushPresetReorderPolicy.resolvedMove(
            draggedIDs: [],
            onto: second.id,
            customPresets: customPresets
        ) == nil)
        #expect(ImageEditorBrushPresetReorderPolicy.resolvedMove(
            draggedIDs: [first.id, second.id],
            onto: third.id,
            customPresets: customPresets
        ) == nil)
        #expect(ImageEditorBrushPresetReorderPolicy.resolvedMove(
            draggedIDs: [second.id],
            onto: second.id,
            customPresets: customPresets
        ) == nil)
        #expect(ImageEditorBrushPresetReorderPolicy.resolvedMove(
            draggedIDs: ["external-text"],
            onto: third.id,
            customPresets: customPresets
        ) == nil)
        #expect(ImageEditorBrushPresetReorderPolicy.resolvedMove(
            draggedIDs: [first.id],
            onto: builtIn.id,
            customPresets: customPresets + [builtIn]
        ) == nil)
    }

    @Test func contextPolicyTargetsTheClickedCustomPresetAndItsRealBoundaries() {
        let first = preset(id: "first", name: "First")
        let second = preset(id: "second", name: "Second")
        let third = preset(id: "third", name: "Third")
        let builtIn = preset(id: "built-in", name: "Built In", isBuiltIn: true)
        let staleCustom = preset(id: "stale", name: "Stale")
        let customPresets = [first, second, third]

        let firstPolicy = ImageEditorBrushPresetContextPolicy(
            preset: first,
            customPresets: customPresets
        )
        #expect(firstPolicy.isCustom)
        #expect(!firstPolicy.canMoveUp)
        #expect(firstPolicy.canMoveDown)
        #expect(firstPolicy.moveUpDestinationIndex == nil)
        #expect(firstPolicy.moveDownDestinationIndex == 1)

        let secondPolicy = ImageEditorBrushPresetContextPolicy(
            preset: second,
            customPresets: customPresets
        )
        #expect(secondPolicy.isCustom)
        #expect(secondPolicy.canMoveUp)
        #expect(secondPolicy.canMoveDown)
        #expect(secondPolicy.moveUpDestinationIndex == 0)
        #expect(secondPolicy.moveDownDestinationIndex == 2)

        let thirdPolicy = ImageEditorBrushPresetContextPolicy(
            preset: third,
            customPresets: customPresets
        )
        #expect(thirdPolicy.isCustom)
        #expect(thirdPolicy.canMoveUp)
        #expect(!thirdPolicy.canMoveDown)
        #expect(thirdPolicy.moveUpDestinationIndex == 1)
        #expect(thirdPolicy.moveDownDestinationIndex == nil)

        for unavailable in [builtIn, staleCustom] {
            let policy = ImageEditorBrushPresetContextPolicy(
                preset: unavailable,
                customPresets: customPresets
            )
            #expect(!policy.isCustom)
            #expect(!policy.canMoveUp)
            #expect(!policy.canMoveDown)
        }
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
        #expect(manager.contains("image-editor-brush-preset-grid-density"))
        #expect(manager.contains("image-editor-brush-preset-drop-target"))
        #expect(manager.contains(".dropDestination(for: URL.self)"))
        #expect(manager.contains("viewModel.importDroppedBrushPresetLibrary(from: urls)"))
        #expect(manager.contains("selectedPresetID = viewModel.selectedBrushPreset?.id"))
        #expect(manager.contains(".draggable(preset.id)"))
        #expect(manager.contains(".dropDestination(for: String.self)"))
        #expect(manager.contains("ImageEditorBrushPresetReorderPolicy.resolvedMove("))
        #expect(manager.contains("viewModel.moveCustomBrushPreset("))
        #expect(manager.contains("image-editor-brush-preset-reorder-\\(preset.id)"))
        #expect(manager.components(separatedBy: ".contextMenu {").count - 1 == 2)
        #expect(manager.contains("private func presetContextMenu("))
        #expect(manager.contains("viewModel.applyBrushPreset(preset)"))
        #expect(manager.contains("beginRenaming(preset)"))
        #expect(manager.contains("viewModel.updateCustomBrushPresetFromCurrentSettings(id: preset.id)"))
        #expect(manager.contains("viewModel.duplicateCustomBrushPreset(id: preset.id)"))
        #expect(manager.contains("viewModel.chooseBrushPresetExportFile(presetIDs: [preset.id])"))
        #expect(manager.contains("viewModel.deleteBrushPreset(preset)"))
        #expect(manager.contains(".focused($isNameFieldFocused)"))
        #expect(manager.contains("DispatchQueue.main.async"))
        #expect(manager.contains("ImageEditorBrushPresetPanelLayout.load()"))
        #expect(manager.contains("layout.save()"))
        #expect(manager.contains("ImageEditorBrushPresetGridDensity.load()"))
        #expect(manager.contains("gridDensity.save()"))
        #expect(manager.contains("ImageEditorBrushPresetSortOrder.load()"))
        #expect(manager.contains("sortOrder.save()"))
        #expect(manager.contains("count: gridDensity.columnCount"))
        #expect(manager.contains("size: gridDensity.thumbnailSize"))
        #expect(manager.contains("minHeight: gridDensity.minimumTileHeight"))
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
