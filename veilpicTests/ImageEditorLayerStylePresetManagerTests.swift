//
//  ImageEditorLayerStylePresetManagerTests.swift
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
struct ImageEditorLayerStylePresetManagerTests {
    @Test func renamingAndReorderingPresetsPersistWithoutChangingDocumentHistory() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        let first = try createPreset(named: "First", strokeWidth: 2, viewModel: viewModel)
        let second = try createPreset(named: "Second", strokeWidth: 4, viewModel: viewModel)
        let third = try createPreset(named: "Third", strokeWidth: 6, viewModel: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.renameLayerStylePreset(id: second.id, name: "  Renamed  "))
        #expect(viewModel.moveLayerStylePreset(id: third.id, direction: .top))
        #expect(viewModel.moveLayerStylePreset(id: first.id, direction: .bottom))
        #expect(viewModel.customLayerStylePresets.map(\.title) == ["Third", "Renamed", "First"])
        #expect(viewModel.document.history.count == historyCount)

        let reopened = makeViewModel(defaults: context.defaults)
        #expect(reopened.customLayerStylePresets.map(\.title) == ["Third", "Renamed", "First"])
        #expect(reopened.customLayerStylePresets[1].id == second.id)
    }

    @Test func renameRejectsBlankAndMoveRejectsUnknownPresetWithoutMutation() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        let preset = try createPreset(named: "Stable", strokeWidth: 3, viewModel: viewModel)
        let original = viewModel.customLayerStylePresets

        #expect(!viewModel.renameLayerStylePreset(id: preset.id, name: "   \n"))
        #expect(!viewModel.moveLayerStylePreset(id: "missing", direction: .up))
        #expect(viewModel.customLayerStylePresets == original)
    }

    @Test func portableLibraryRoundTripsOrderStylesAndCreatesFreshIDs() throws {
        let sourceContext = makeContext()
        defer { sourceContext.defaults.removePersistentDomain(forName: sourceContext.suiteName) }
        let source = makeViewModel(defaults: sourceContext.defaults)
        let first = try createPreset(named: "Soft", strokeWidth: 2, viewModel: source)
        let second = try createPreset(named: "Strong", strokeWidth: 9, viewModel: source)

        let data = try source.layerStylePresetLibraryData(presetIDs: [second.id, first.id])
        let payload = try JSONDecoder().decode(ImageEditorLayerStylePresetLibrary.self, from: data)
        #expect(payload.formatVersion == ImageEditorLayerStylePresetLibrary.currentFormatVersion)
        #expect(payload.presets.map(\.title) == ["Strong", "Soft"])

        let targetContext = makeContext()
        defer { targetContext.defaults.removePersistentDomain(forName: targetContext.suiteName) }
        let target = makeViewModel(defaults: targetContext.defaults)
        let result = try target.importLayerStylePresetLibraryData(data)

        #expect(result.importedCount == 2)
        #expect(result.skippedCount == 0)
        #expect(target.customLayerStylePresets.map(\.title) == ["Strong", "Soft"])
        #expect(target.customLayerStylePresets.map(\.id) != [second.id, first.id])
        #expect(target.customLayerStylePresets[0].layerStyle.strokeWidth == 9)
        #expect(target.customLayerStylePresets[1].layerStyle.strokeWidth == 2)
        #expect(target.document.history.count == 1)

        let duplicateResult = try target.importLayerStylePresetLibraryData(data)
        #expect(duplicateResult.importedCount == 0)
        #expect(duplicateResult.skippedCount == 2)
        #expect(target.customLayerStylePresets.count == 2)
        #expect(target.document.history.count == 1)
    }

    @Test func importFillsRemainingCapacityAndReportsEverySkippedPreset() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        viewModel.customLayerStylePresets = (0..<99).map { index in
            ImageEditorLayerStylePreset(
                id: "local-\(index)",
                name: "Local \(index)",
                style: projectStyle(strokeWidth: CGFloat(index + 1))
            )
        }
        let library = ImageEditorLayerStylePresetLibrary(presets: (0..<3).map { index in
            ImageEditorLayerStylePreset(
                id: "incoming-\(index)",
                name: "Incoming \(index)",
                style: projectStyle(strokeWidth: CGFloat(index + 200))
            )
        })

        let result = try viewModel.importLayerStylePresetLibraryData(
            JSONEncoder().encode(library)
        )

        #expect(result.importedCount == 1)
        #expect(result.skippedCount == 2)
        #expect(viewModel.customLayerStylePresets.count == 100)
        #expect(viewModel.customLayerStylePresets.last?.title == "Incoming 0")
    }

    @Test func importRejectsUnsupportedOrOversizedLibrariesWithoutMutation() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        let preset = try createPreset(named: "Local", strokeWidth: 5, viewModel: viewModel)
        let unsupported = ImageEditorLayerStylePresetLibrary(
            formatVersion: ImageEditorLayerStylePresetLibrary.currentFormatVersion + 1,
            presets: [preset]
        )
        let unsupportedData = try JSONEncoder().encode(unsupported)

        #expect(throws: ImageEditorLayerStylePresetLibraryError.unsupportedFormatVersion) {
            try viewModel.importLayerStylePresetLibraryData(unsupportedData)
        }
        #expect(throws: ImageEditorLayerStylePresetLibraryError.fileTooLarge) {
            try viewModel.importLayerStylePresetLibraryData(
                Data(count: ImageEditorLayerStylePresetLibrary.maximumFileSize + 1)
            )
        }
        #expect(viewModel.customLayerStylePresets == [preset])
    }

    @Test func presetManagerUIAndAutomationShareBusinessCommands() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let managerSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorLayerStylePresetManager.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let menuSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )
        let automationSource = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoAutomationRegistry.swift"),
            encoding: .utf8
        )

        #expect(managerSource.contains("viewModel.renameLayerStylePreset"))
        #expect(managerSource.contains("viewModel.moveLayerStylePreset"))
        #expect(managerSource.contains("viewModel.chooseLayerStylePresetImportFile"))
        #expect(managerSource.contains("viewModel.chooseLayerStylePresetExportFile"))
        #expect(viewSource.contains("ImageEditorLayerStylePresetManager(viewModel: viewModel)"))
        #expect(menuSource.contains("isLayerStylePresetManagerPresented = true"))
        #expect(automationSource.contains("presetRename"))
        #expect(automationSource.contains("presetMove"))
        #expect(automationSource.contains("presetImport"))
        #expect(automationSource.contains("presetExport"))
    }

    private func createPreset(
        named name: String,
        strokeWidth: CGFloat,
        viewModel: ImageEditorViewModel
    ) throws -> ImageEditorLayerStylePreset {
        let index = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[index].style.strokeEnabled = true
        viewModel.document.layers[index].style.strokeWidth = strokeWidth
        return try #require(viewModel.createLayerStylePresetFromSelectedLayer(name: name))
    }

    private func projectStyle(strokeWidth: CGFloat) -> ImageEditorProjectLayerStyle {
        var style = ImageEditorLayerStyle()
        style.strokeEnabled = true
        style.strokeWidth = strokeWidth
        return ImageEditorProjectLayerStyle(style: style)
    }

    private func makeContext() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "ImageEditorLayerStylePresetManagerTests.\(UUID().uuidString)"
        return (suiteName, UserDefaults(suiteName: suiteName) ?? .standard)
    }

    private func makeViewModel(defaults: UserDefaults) -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "preset-manager.png",
            image: NSImage.transparent(size: NSSize(width: 48, height: 36)),
            preferencesDefaults: defaults
        ) { _ in }
    }
}
