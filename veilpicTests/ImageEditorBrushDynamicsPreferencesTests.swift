//
//  ImageEditorBrushDynamicsPreferencesTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/12.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorBrushDynamicsPreferencesTests {
    @Test func preferencesRoundTripClampAndRecoverFromInvalidData() {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        ImageEditorBrushDynamicsPreferences(
            pressureControlsSize: false,
            pressureControlsFlow: true,
            pressureSensitivity: 140
        ).save(to: defaults)

        let loaded = ImageEditorBrushDynamicsPreferences.load(from: defaults)
        #expect(!loaded.pressureControlsSize)
        #expect(loaded.pressureControlsFlow)
        #expect(loaded.pressureSensitivity == 100)

        defaults.set(
            Data("not-json".utf8),
            forKey: ImageEditorBrushDynamicsPreferences.storageKey
        )
        #expect(ImageEditorBrushDynamicsPreferences.load(from: defaults) == .defaultValue)
    }

    @Test func viewModelRestoresPressureOptionsAcrossEditorSessions() {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let image = NSImage.transparent(size: CGSize(width: 32, height: 32))
        let first = ImageEditorViewModel(
            sourceName: "first.png",
            image: image,
            preferencesDefaults: defaults
        ) { _ in }
        first.setBrushPressureControlsSize(false)
        first.setBrushPressureControlsFlow(true)
        first.setBrushPressureSensitivity(73)

        let restored = ImageEditorViewModel(
            sourceName: "restored.png",
            image: image,
            preferencesDefaults: defaults
        ) { _ in }
        #expect(!restored.brushPressureControlsSize)
        #expect(restored.brushPressureControlsFlow)
        #expect(restored.brushPressureSensitivity == 73)
    }

    @Test func customPresetPreferencesRoundTripNormalizeAndRejectDuplicateIDs() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let invalid = ImageEditorBrushPreset(
            id: "duplicate",
            name: "  Detail Brush  ",
            size: 180,
            hardness: -1,
            flow: 140,
            spacing: 0,
            pressureControlsSize: false,
            pressureControlsFlow: true,
            pressureSensitivity: 180,
            isBuiltIn: true
        )
        ImageEditorBrushPresetPreferences(presets: [invalid, invalid]).save(to: defaults)

        let loaded = ImageEditorBrushPresetPreferences.load(from: defaults)
        let preset = try #require(loaded.presets.first)
        #expect(loaded.presets.count == 1)
        #expect(preset.name == "Detail Brush")
        #expect(preset.size == 96)
        #expect(preset.hardness == 0)
        #expect(preset.flow == 100)
        #expect(preset.spacing == 1)
        #expect(preset.pressureSensitivity == 100)
        #expect(!preset.isBuiltIn)

        defaults.set(Data("broken".utf8), forKey: ImageEditorBrushPresetPreferences.storageKey)
        #expect(ImageEditorBrushPresetPreferences.load(from: defaults).presets.isEmpty)
    }

    @Test func customPresetCreateApplyDeleteAndRestoreAcrossSessions() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = makeViewModel(defaults: defaults)
        first.brushSize = 42
        first.hardness = 0.35
        first.brushFlow = 67
        first.brushSpacing = 81
        first.setBrushPressureControlsSize(false)
        first.setBrushPressureControlsFlow(true)
        first.setBrushPressureSensitivity(73)

        let created = try #require(first.createBrushPresetFromCurrentSettings())
        #expect(!created.isBuiltIn)
        #expect(first.activeBrushPreset?.id == created.id)
        #expect(first.customBrushPresets.count == 1)

        let restored = makeViewModel(defaults: defaults)
        let restoredPreset = try #require(restored.customBrushPresets.first)
        restored.applyBrushPreset(restoredPreset)
        #expect(restored.brushSize == 42)
        #expect(restored.hardness == 0.35)
        #expect(restored.brushFlow == 67)
        #expect(restored.brushSpacing == 81)
        #expect(!restored.brushPressureControlsSize)
        #expect(restored.brushPressureControlsFlow)
        #expect(restored.brushPressureSensitivity == 73)
        #expect(restored.activeBrushPreset?.id == created.id)

        restored.brushFlow = 66
        #expect(restored.activeBrushPreset == nil)
        restored.brushFlow = 67
        restored.deleteBrushPreset(restoredPreset)
        #expect(restored.customBrushPresets.isEmpty)
        #expect(makeViewModel(defaults: defaults).customBrushPresets.isEmpty)
    }

    @Test func builtInPresetsCannotBeDeletedAndRestoreTheCompleteBrushDefinition() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        let builtIn = try #require(ImageEditorBrushPreset.defaultPresets.first)
        viewModel.hardness = 0.1
        viewModel.brushFlow = 12
        viewModel.brushSpacing = 190
        viewModel.setBrushPressureControlsSize(false)
        viewModel.setBrushPressureControlsFlow(false)
        viewModel.setBrushPressureSensitivity(0)

        viewModel.applyBrushPreset(builtIn)
        viewModel.deleteBrushPreset(builtIn)

        #expect(viewModel.brushSize == builtIn.size)
        #expect(viewModel.hardness == builtIn.hardness)
        #expect(viewModel.brushFlow == builtIn.flow)
        #expect(viewModel.brushSpacing == builtIn.spacing)
        #expect(viewModel.brushPressureControlsSize)
        #expect(viewModel.brushPressureControlsFlow)
        #expect(viewModel.brushPressureSensitivity == 50)
        #expect(viewModel.customBrushPresets.isEmpty)
    }

    @Test func customPresetWinsMatchingOverAnEquivalentBuiltInPresetSoItCanBeDeleted() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        let builtIn = try #require(
            ImageEditorBrushPreset.defaultPresets.first(where: { $0.size == viewModel.brushSize })
        )
        #expect(viewModel.activeBrushPreset?.id == builtIn.id)

        let custom = try #require(viewModel.createBrushPresetFromCurrentSettings())
        #expect(viewModel.activeBrushPreset?.id == custom.id)
        viewModel.deleteBrushPreset(custom)
        #expect(viewModel.activeBrushPreset?.id == builtIn.id)
    }

    private func makeViewModel(defaults: UserDefaults) -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "preset.png",
            image: NSImage.transparent(size: CGSize(width: 32, height: 32)),
            preferencesDefaults: defaults
        ) { _ in }
    }

    private func temporaryDefaults() -> (UserDefaults, String) {
        let suiteName = "ImageEditorBrushDynamicsPreferencesTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName) ?? .standard, suiteName)
    }
}
