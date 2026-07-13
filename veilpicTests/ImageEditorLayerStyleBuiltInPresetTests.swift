//
//  ImageEditorLayerStyleBuiltInPresetTests.swift
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
struct ImageEditorLayerStyleBuiltInPresetTests {
    @Test func builtInCatalogHasStableDistinctCompleteStyles() {
        let presets = ImageEditorLayerStyleBuiltInPresetCatalog.presets

        #expect(presets.count == 6)
        #expect(Set(presets.map(\.id)).count == presets.count)
        #expect(presets.allSatisfy { $0.isBuiltIn })
        #expect(presets.allSatisfy { $0.id.hasPrefix(ImageEditorLayerStylePreset.builtInIDPrefix) })
        #expect(presets.allSatisfy { !$0.title.isEmpty && $0.layerStyle.hasConfiguredEffects })
        #expect(presets.allSatisfy { $0.layerStyle.effectsEnabled && $0.layerStyle.effectScale == 1 })
        #expect(!presets[0].normalizedCustomPreset.isBuiltIn)

        for index in presets.indices {
            for otherIndex in presets.indices where otherIndex > index {
                #expect(presets[index].style != presets[otherIndex].style)
            }
        }
    }

    @Test func applyingBuiltInPresetUsesNormalUndoAndBecomesActiveWithoutPersistence() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        let preset = try #require(viewModel.builtInLayerStylePresets.first)
        let index = try #require(viewModel.document.selectedLayerIndex)
        let historyCount = viewModel.document.history.count

        viewModel.applyLayerStylePreset(preset)

        #expect(viewModel.document.layers[index].style.hasConfiguredEffects)
        #expect(viewModel.activeLayerStylePreset?.id == preset.id)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.customLayerStylePresets.isEmpty)

        let reopened = makeViewModel(defaults: context.defaults)
        #expect(reopened.customLayerStylePresets.isEmpty)
        #expect(reopened.builtInLayerStylePresets.map(\.id) == viewModel.builtInLayerStylePresets.map(\.id))
    }

    @Test func duplicatingBuiltInPresetCreatesEditablePersistentCopyWithoutHistory() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        let builtIn = try #require(viewModel.builtInLayerStylePresets.last)
        let historyCount = viewModel.document.history.count

        let copy = try #require(viewModel.duplicateLayerStylePresetToCustom(builtIn))

        #expect(!copy.isBuiltIn)
        #expect(copy.id != builtIn.id)
        #expect(copy.style == builtIn.style)
        #expect(copy.title != builtIn.title)
        #expect(viewModel.customLayerStylePresets == [copy])
        #expect(viewModel.document.history.count == historyCount)

        let reopened = makeViewModel(defaults: context.defaults)
        #expect(reopened.customLayerStylePresets == [copy])
    }

    @Test func builtInPreviewRendererProducesFixedDistinctEffectThumbnails() throws {
        let previews = ImageEditorLayerStyleBuiltInPresetCatalog.presets.map {
            ImageEditorLayerStylePresetPreviewRenderer.image(for: $0)
        }

        #expect(previews.allSatisfy { $0.size == ImageEditorLayerStylePresetPreviewRenderer.previewSize })
        let payloads = try previews.map { try #require($0.tiffRepresentation) }
        #expect(Set(payloads).count == previews.count)
    }

    @Test func exportingBuiltInPresetImportsAsSafeEditableCustomPreset() throws {
        let sourceContext = makeContext()
        let targetContext = makeContext()
        defer {
            sourceContext.defaults.removePersistentDomain(forName: sourceContext.suiteName)
            targetContext.defaults.removePersistentDomain(forName: targetContext.suiteName)
        }
        let source = makeViewModel(defaults: sourceContext.defaults)
        let target = makeViewModel(defaults: targetContext.defaults)
        let builtIn = try #require(source.builtInLayerStylePresets[3])
        let data = try source.layerStylePresetLibraryData(presetIDs: [builtIn.id])

        let result = try target.importLayerStylePresetLibraryData(data)

        #expect(result == ImageEditorLayerStylePresetImportResult(importedCount: 1, skippedCount: 0))
        let imported = try #require(target.customLayerStylePresets.first)
        #expect(!imported.isBuiltIn)
        #expect(imported.id != builtIn.id)
        #expect(imported.title == builtIn.title)
        #expect(imported.style == builtIn.style)
        #expect(target.document.history.count == 1)
    }

    @Test func builtInUIAndAutomationUseSharedPresetCommands() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presetSource = try source(root, "veilpic/ImageEditorLayerStylePresets.swift")
        let managerSource = try source(root, "veilpic/ImageEditorLayerStylePresetManager.swift")
        let automationSource = try source(root, "veilpic/XomoAutomationRegistry.swift")

        #expect(presetSource.contains("viewModel.builtInLayerStylePresets"))
        #expect(presetSource.contains("ImageEditorLayerStylePresetThumbnail"))
        #expect(managerSource.contains("viewModel.duplicateLayerStylePresetToCustom"))
        #expect(managerSource.contains("ImageEditorLayerStylePresetThumbnail"))
        #expect(automationSource.contains("presetCatalog"))
        #expect(automationSource.contains("presetDuplicate"))
        #expect(automationSource.contains("viewModel.layerStylePreset(id:"))
    }

    private func source(_ root: URL, _ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private func makeContext() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "ImageEditorLayerStyleBuiltInPresetTests.\(UUID().uuidString)"
        return (suiteName, UserDefaults(suiteName: suiteName) ?? .standard)
    }

    private func makeViewModel(defaults: UserDefaults) -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "built-in-presets.png",
            image: NSImage.transparent(size: NSSize(width: 64, height: 48)),
            preferencesDefaults: defaults
        ) { _ in }
    }
}
