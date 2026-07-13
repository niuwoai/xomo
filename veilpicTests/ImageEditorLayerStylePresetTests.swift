//
//  ImageEditorLayerStylePresetTests.swift
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
struct ImageEditorLayerStylePresetTests {
    @Test func presetPreferencesNormalizeNamesDeduplicateIDsAndLimitCount() throws {
        var style = ImageEditorLayerStyle()
        style.strokeEnabled = true
        let projectStyle = ImageEditorProjectLayerStyle(style: style)
        let presets = (0...ImageEditorLayerStylePresetPreferences.maximumPresetCount).map { index in
            ImageEditorLayerStylePreset(
                id: index < 2 ? "duplicate" : "preset-\(index)",
                name: index == 0 ? "  " : String(repeating: "A", count: 100),
                style: projectStyle
            )
        }

        let normalized = ImageEditorLayerStylePresetPreferences(presets: presets).normalized

        #expect(normalized.presets.count == ImageEditorLayerStylePresetPreferences.maximumPresetCount)
        #expect(Set(normalized.presets.map(\.id)).count == normalized.presets.count)
        #expect(normalized.presets.first?.title == L10n.text("imageEditor.layerStylePreset.untitled"))
        #expect(normalized.presets.allSatisfy { $0.title.count <= 80 })
    }

    @Test func creatingPresetPersistsCompleteStyleAndReloadsAcrossEditors() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        let index = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[index].style = sampleStyle()

        let preset = try #require(
            viewModel.createLayerStylePresetFromSelectedLayer(name: "  Neon Card  ")
        )

        #expect(preset.title == "Neon Card")
        #expect(viewModel.activeLayerStylePreset?.id == preset.id)
        #expect(
            ImageEditorProjectLayerStyle(style: preset.layerStyle)
                == ImageEditorProjectLayerStyle(style: sampleStyle())
        )
        #expect(viewModel.document.history.count == 1)

        let reopened = makeViewModel(defaults: context.defaults)
        let restored = try #require(reopened.customLayerStylePresets.first)
        #expect(restored.id == preset.id)
        #expect(restored.title == "Neon Card")
        #expect(restored.style == preset.style)
    }

    @Test func applyingPresetUpdatesEditableSelectionInOneUndoAndSkipsLocks() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[firstIndex].style = sampleStyle()
        let preset = try #require(viewModel.createLayerStylePresetFromSelectedLayer())
        viewModel.document.layers[firstIndex].style = ImageEditorLayerStyle()

        viewModel.addLayer()
        let lockedID = try #require(viewModel.document.selectedLayerID)
        let lockedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[lockedIndex].isLocked = true
        viewModel.document.layers[lockedIndex].style.shadowEnabled = true

        viewModel.addLayer()
        let editableID = try #require(viewModel.document.selectedLayerID)
        let editableIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.selectedLayerID = firstID
        viewModel.document.selectedLayerIDs = [firstID, lockedID, editableID]

        viewModel.applyLayerStylePreset(preset)

        #expect(viewModel.document.layers[firstIndex].style.strokeEnabled)
        #expect(viewModel.document.layers[editableIndex].style.strokeEnabled)
        #expect(viewModel.document.layers[firstIndex].style.effectScale == 1.6)
        #expect(viewModel.document.layers[editableIndex].style.effectsEnabled == false)
        #expect(viewModel.document.layers[lockedIndex].style.shadowEnabled)
        #expect(!viewModel.document.layers[lockedIndex].style.strokeEnabled)
        #expect(viewModel.activeLayerStylePreset?.id == preset.id)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStylePresetApply"))

        viewModel.undo()
        #expect(!viewModel.document.layers[firstIndex].style.hasConfiguredEffects)
        #expect(!viewModel.document.layers[editableIndex].style.hasConfiguredEffects)
        #expect(viewModel.document.layers[lockedIndex].style.shadowEnabled)
    }

    @Test func deletingPresetPersistsWithoutChangingDocumentHistory() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let viewModel = makeViewModel(defaults: context.defaults)
        let index = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[index].style.strokeEnabled = true
        let preset = try #require(viewModel.createLayerStylePresetFromSelectedLayer())
        let historyCount = viewModel.document.history.count

        viewModel.deleteLayerStylePreset(preset)

        #expect(viewModel.customLayerStylePresets.isEmpty)
        #expect(viewModel.document.history.count == historyCount)
        let reopened = makeViewModel(defaults: context.defaults)
        #expect(reopened.customLayerStylePresets.isEmpty)
    }

    @Test func presetUIAndAutomationUseSharedViewModelCommands() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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

        #expect(viewSource.contains("ImageEditorLayerStylePresetMenu(viewModel: viewModel)"))
        #expect(menuSource.contains("viewModel.applyLayerStylePreset(preset)"))
        #expect(menuSource.contains("viewModel.createLayerStylePresetFromSelectedLayer()"))
        #expect(automationSource.contains("layerStylePresetAction(arguments, viewModel: viewModel)"))
        #expect(automationSource.contains("presetCreate"))
        #expect(automationSource.contains("presetApply"))
        #expect(automationSource.contains("presetDelete"))
    }

    private func sampleStyle() -> ImageEditorLayerStyle {
        var style = ImageEditorLayerStyle()
        style.effectsEnabled = false
        style.effectScale = 1.6
        style.strokeEnabled = true
        style.strokeColor = NSColor(deviceRed: 0.2, green: 0.7, blue: 0.9, alpha: 1)
        style.strokeWidth = 7
        style.shadowEnabled = true
        style.shadowBlur = 11
        style.shadowDistance = 13
        style.outerGlowEnabled = true
        style.outerGlowSpread = 5
        style.patternOverlayEnabled = true
        style.patternOverlayScale = 22
        style.bevelEnabled = true
        style.bevelSize = 9
        return style
    }

    private func makeContext() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "ImageEditorLayerStylePresetTests.\(UUID().uuidString)"
        return (suiteName, UserDefaults(suiteName: suiteName) ?? .standard)
    }

    private func makeViewModel(defaults: UserDefaults) -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "presets.png",
            image: NSImage.transparent(size: NSSize(width: 48, height: 36)),
            preferencesDefaults: defaults
        ) { _ in }
    }
}
