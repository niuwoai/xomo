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

    @Test func visibleExportKeepsQueryOrderAndExcludesBuiltInPresets() {
        let presets = [
            preset(id: "built-in", name: "Ink Classic", isBuiltIn: true),
            preset(id: "custom-zulu", name: "Ink Zulu"),
            preset(id: "custom-alpha", name: "Ink Alpha"),
            preset(id: "custom-chalk", name: "Chalk")
        ]
        let query = ImageEditorBrushPresetQuery(
            searchText: "ink",
            scope: .all,
            collection: .favorites,
            sortOrder: .nameAscending,
            favoriteIDs: ["built-in", "custom-zulu", "custom-alpha"]
        )

        #expect(
            query.exportableCustomPresetIDs(in: presets)
                == ["custom-alpha", "custom-zulu"]
        )
        #expect(
            ImageEditorBrushPresetQuery(
                searchText: "",
                scope: .builtIn
            ).exportableCustomPresetIDs(in: presets).isEmpty
        )
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
        let archiveManager = try source(root, "veilpic/ImageEditorBrushPresetManager.swift")
        let editor = try source(root, "veilpic/ImageEditorView.swift")
        let menuBar = try source(root, "veilpic/ImageEditorMenuBar.swift")
        let importStart = try #require(
            archiveManager.range(
                of: "func importBrushPresetLibraryWithConfirmation(\n        from url: URL,\n        selectPresets:"
            )
        )
        let importEnd = try #require(
            archiveManager[importStart.upperBound...].range(
                of: "private func presentBrushPresetImportSelection("
            )
        )
        let importSource = archiveManager[
            importStart.lowerBound..<importEnd.lowerBound
        ]
        let importDataRead = try #require(
            importSource.range(of: "let data = try brushPresetLibraryArchiveData(from: url)")
        )
        let importInspection = try #require(
            importSource.range(
                of: "let inspection = try inspectBrushPresetLibraryData(data, mode: .append)"
            )
        )
        let importConfirmation = try #require(
            importSource.range(of: "guard let selectedIndexes = selectPresets(url, inspection)")
        )
        let importCommit = try #require(
            importSource.range(of: "selectedIndexes: selectedIndexes")
        )
        let replacementStart = try #require(
            archiveManager.range(
                of: "func replaceBrushPresetLibraryWithConfirmation(\n        from url: URL,\n        selectPresets:"
            )
        )
        let replacementEnd = try #require(
            archiveManager[replacementStart.upperBound...].range(
                of: "private func presentBrushPresetReplacementSelection("
            )
        )
        let replacementSource = archiveManager[
            replacementStart.lowerBound..<replacementEnd.lowerBound
        ]
        let archiveDataRead = try #require(
            replacementSource.range(
                of: "let data = try brushPresetLibraryArchiveData(from: url)"
            )
        )
        let inspectionRead = try #require(
            replacementSource.range(
                of: "let inspection = try inspectBrushPresetLibraryData(data, mode: .replace)"
            )
        )
        let replacementSelection = try #require(
            replacementSource.range(
                of: "guard let selectedIndexes = selectPresets(url, inspection)"
            )
        )
        let replacementCommit = try #require(
            replacementSource.range(of: "selectedIndexes: selectedIndexes")
        )
        let replacementPresentationStart = try #require(
            archiveManager.range(of: "private func presentBrushPresetReplacementSelection(")
        )
        let replacementPresentationEnd = try #require(
            archiveManager[replacementPresentationStart.upperBound...].range(
                of: "func chooseBrushPresetReplacementFile()"
            )
        )
        let replacementPresentationSource = archiveManager[
            replacementPresentationStart.lowerBound..<replacementPresentationEnd.lowerBound
        ]
        let replacementChooseStart = try #require(
            archiveManager.range(of: "func chooseBrushPresetReplacementFile()")
        )
        let replacementChooseEnd = try #require(
            archiveManager[replacementChooseStart.upperBound...].range(
                of: "func confirmBrushPresetLibraryReset()"
            )
        )
        let replacementChooseSource = archiveManager[
            replacementChooseStart.lowerBound..<replacementChooseEnd.lowerBound
        ]

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
        #expect(manager.contains("imageEditor.action.brushPresetLibraryMenu"))
        #expect(manager.contains("viewModel.chooseBrushPresetReplacementFile()"))
        #expect(manager.contains("imageEditor.action.brushPresetResetLibrary"))
        #expect(manager.contains("viewModel.confirmBrushPresetLibraryReset()"))
        #expect(manager.contains(".disabled(!viewModel.canResetCustomBrushPresetLibrary)"))
        #expect(manager.contains("query.exportableCustomPresetIDs("))
        #expect(manager.contains("imageEditor.action.brushPresetExportVisible"))
        #expect(manager.contains("presetIDs: exportableVisibleCustomPresetIDs"))
        #expect(manager.contains(".disabled(exportableVisibleCustomPresetIDs.isEmpty)"))
        #expect(archiveManager.contains("func replaceBrushPresetLibraryData("))
        #expect(archiveManager.contains("func inspectBrushPresetLibraryData("))
        #expect(archiveManager.contains("enum ImageEditorBrushPresetLibraryInspectionMode"))
        #expect(archiveManager.contains("enum ImageEditorBrushPresetImportSelectionPolicy"))
        #expect(archiveManager.contains("enum ImageEditorBrushPresetImportNamingPolicy"))
        #expect(archiveManager.contains("static func plannedItems("))
        #expect(archiveManager.contains("let unselectedCount: Int"))
        #expect(archiveManager.contains("let capacitySkippedCount: Int"))
        #expect(archiveManager.contains("static func matchingIndexes("))
        #expect(archiveManager.contains("static func orderedIndexes("))
        #expect(archiveManager.contains("static func selectingAll("))
        #expect(archiveManager.contains("static func deselectingAll("))
        #expect(archiveManager.contains("static func inverting("))
        #expect(archiveManager.contains("ImageEditorBrushPresetImportSelectionView"))
        #expect(archiveManager.contains("struct ImageEditorBrushPresetLibraryInspection"))
        #expect(archiveManager.contains("struct ImageEditorBrushPresetLibraryPreview"))
        #expect(archiveManager.contains("let presetPreviews: [ImageEditorBrushPresetLibraryPreview]"))
        #expect(archiveManager.contains("enum ImageEditorBrushPresetLibraryThumbnailRenderer"))
        #expect(archiveManager.contains("tipRoundness / 100"))
        #expect(archiveManager.contains("context.rotate(by: preview.tipAngleDegrees"))
        #expect(archiveManager.contains("parameterLabel = NSTextField"))
        #expect(archiveManager.contains("preview.primarySummary"))
        #expect(archiveManager.contains("NSImageView("))
        #expect(archiveManager.contains("image-editor-brush-preset-import-thumbnail-"))
        #expect(archiveManager.contains("visibleIndexes.count * 48"))
        #expect(archiveManager.contains("let library = try decodedBrushPresetLibrary(from: data)"))
        #expect(archiveManager.contains("self.importBrushPresetLibraryWithConfirmation(from: url)"))
        #expect(archiveManager.contains("imageEditor.brushPreset.importConfirmation.message"))
        #expect(archiveManager.contains("imageEditor.brushPreset.importSelection.summary"))
        #expect(archiveManager.contains("imageEditor.brushPreset.importSelection.searchPlaceholder"))
        #expect(archiveManager.contains("image-editor-brush-preset-import-search"))
        #expect(archiveManager.contains("searchField.sendsSearchStringImmediately = true"))
        #expect(archiveManager.contains("image-editor-brush-preset-import-sort"))
        #expect(archiveManager.contains("sortOrderPopUpButton.action = #selector(sortPresets)"))
        #expect(archiveManager.contains("arrangePresetButtons(visibleIndexes: visibleIndexes)"))
        #expect(archiveManager.contains(
            "presetRows[button.tag].isHidden = !visibleIndexes.contains(button.tag)"
        ))
        #expect(archiveManager.contains("invertSelectionButton.action = #selector(invertVisiblePresets)"))
        #expect(archiveManager.contains("alert.accessoryView = selectionView"))
        #expect(archiveManager.contains("imageEditor.brushPreset.importSelection.item"))
        #expect(archiveManager.contains("imageEditor.brushPreset.importSelection.renamedItem"))
        #expect(archiveManager.contains("item.installedTitle"))
        #expect(archiveManager.contains("imageEditor.status.brushPresetImportedSelection"))
        #expect(archiveManager.contains("imageEditor.status.brushPresetLibraryReplacedSelection"))
        #expect(importDataRead.lowerBound < importInspection.lowerBound)
        #expect(importInspection.lowerBound < importConfirmation.lowerBound)
        #expect(importConfirmation.lowerBound < importCommit.lowerBound)
        #expect(!importSource.contains("importBrushPresetLibrary(from: url)"))
        #expect(
            archiveManager.components(
                separatedBy: "presentBrushPresetImportSelection("
            ).count - 1 == 3
        )
        #expect(archiveManager.contains("installReplacingBrushPresets(replacementPresets)"))
        #expect(replacementPresentationSource.contains("alert.buttons.first?.hasDestructiveAction = true"))
        #expect(replacementPresentationSource.contains("inspection.presetCount"))
        #expect(replacementPresentationSource.contains("inspection.installableCount"))
        #expect(replacementPresentationSource.contains("inspection.skippedCount"))
        #expect(replacementPresentationSource.contains("sourceURL.lastPathComponent"))
        #expect(replacementPresentationSource.contains("ImageEditorBrushPresetImportSelectionView("))
        #expect(replacementPresentationSource.contains("alert.accessoryView = selectionView"))
        #expect(replacementPresentationSource.contains("!selection.isEmpty"))
        #expect(archiveDataRead.lowerBound < inspectionRead.lowerBound)
        #expect(inspectionRead.lowerBound < replacementSelection.lowerBound)
        #expect(replacementSelection.lowerBound < replacementCommit.lowerBound)
        #expect(!replacementSource.contains("replaceBrushPresetLibrary(from: url)"))
        #expect(replacementChooseSource.contains("self.replaceBrushPresetLibraryWithConfirmation(from: url)"))
        #expect(archiveManager.contains("func confirmBrushPresetLibraryReset()"))
        #expect(archiveManager.contains("imageEditor.brushPreset.resetConfirmation.message"))
        #expect(archiveManager.contains("resetCustomBrushPresetLibrary()"))
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
