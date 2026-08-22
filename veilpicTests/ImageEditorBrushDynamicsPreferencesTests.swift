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
            brushSize: 999,
            brushHardness: -1,
            brushFlow: 0,
            brushSpacing: 999,
            pressureControlsSize: false,
            pressureControlsOpacity: true,
            pressureControlsFlow: true,
            pressureSensitivity: 140,
            sizeJitter: 140,
            angleJitter: 140,
            angleFollowsStrokeDirection: true,
            roundnessJitter: 140,
            opacityJitter: 140,
            flowJitter: -20,
            minimumRoundness: -20,
            scatter: 2_000,
            scatterBothAxes: true,
            scatterCount: 99,
            scatterCountJitter: 140,
            noiseEnabled: true,
            wetEdgesEnabled: true,
            minimumDiameter: 140,
            minimumOpacity: 140,
            minimumFlow: 140,
            tiltControlsShape: true,
            tipRoundness: 2,
            tipAngleDegrees: 250,
            smoothing: 140,
            paintBlendMode: .passThrough,
            historyBrushBlendMode: .passThrough,
            pencilAutoEraseEnabled: true
        ).save(to: defaults)

        let loaded = ImageEditorBrushDynamicsPreferences.load(from: defaults)
        #expect(loaded.brushSize == 96)
        #expect(loaded.brushHardness == 0)
        #expect(loaded.brushFlow == 1)
        #expect(loaded.brushSpacing == 200)
        #expect(!loaded.pressureControlsSize)
        #expect(loaded.pressureControlsOpacity)
        #expect(loaded.pressureControlsFlow)
        #expect(loaded.pressureSensitivity == 100)
        #expect(loaded.sizeJitter == 100)
        #expect(loaded.angleJitter == 100)
        #expect(loaded.angleFollowsStrokeDirection)
        #expect(loaded.roundnessJitter == 100)
        #expect(loaded.opacityJitter == 100)
        #expect(loaded.flowJitter == 0)
        #expect(loaded.minimumRoundness == 1)
        #expect(loaded.scatter == 1_000)
        #expect(loaded.scatterBothAxes)
        #expect(loaded.scatterCount == 16)
        #expect(loaded.scatterCountJitter == 100)
        #expect(loaded.noiseEnabled)
        #expect(loaded.wetEdgesEnabled)
        #expect(loaded.minimumDiameter == 100)
        #expect(loaded.minimumOpacity == 100)
        #expect(loaded.minimumFlow == 100)
        #expect(loaded.tiltControlsShape)
        #expect(loaded.tipRoundness == 10)
        #expect(loaded.tipAngleDegrees == 180)
        #expect(loaded.smoothing == 100)
        #expect(loaded.paintBlendMode == .normal)
        #expect(loaded.historyBrushBlendMode == .normal)
        #expect(loaded.pencilAutoEraseEnabled)

        defaults.set(
            Data("not-json".utf8),
            forKey: ImageEditorBrushDynamicsPreferences.storageKey
        )
        #expect(ImageEditorBrushDynamicsPreferences.load(from: defaults) == .defaultValue)
    }

    @Test func viewModelRestoresBrushAndPencilOptionsAcrossEditorSessions() {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let image = NSImage.transparent(size: CGSize(width: 32, height: 32))
        let first = ImageEditorViewModel(
            sourceName: "first.png",
            image: image,
            preferencesDefaults: defaults
        ) { _ in }
        first.brushSize = 37
        first.hardness = 0.45
        first.brushFlow = 68
        first.brushSpacing = 84
        first.setBrushPressureControlsSize(false)
        first.setBrushPressureControlsOpacity(true)
        first.setBrushPressureControlsFlow(true)
        first.setBrushPressureSensitivity(73)
        first.setBrushSizeJitter(58)
        first.setBrushAngleJitter(63)
        first.setBrushAngleFollowsStrokeDirection(true)
        first.setBrushRoundnessJitter(57)
        first.setBrushOpacityJitter(54)
        first.setBrushFlowJitter(49)
        first.setBrushMinimumRoundness(23)
        first.setBrushScatter(420)
        first.setBrushScatterBothAxes(true)
        first.setBrushScatterCount(8)
        first.setBrushScatterCountJitter(46)
        first.setBrushNoiseEnabled(true)
        first.setBrushWetEdgesEnabled(true)
        first.setBrushMinimumDiameter(37)
        first.setBrushMinimumOpacity(31)
        first.setBrushMinimumFlow(29)
        first.setBrushTiltControlsShape(true)
        first.setBrushTipRoundness(47)
        first.setBrushTipAngleDegrees(-45)
        first.setBrushSmoothing(64)
        first.setPaintBlendMode(.screen)
        first.setPaintAirbrushEnabled(true)
        first.setHistoryBrushBlendMode(.multiply)
        first.setPencilAutoEraseEnabled(true)

        let restored = ImageEditorViewModel(
            sourceName: "restored.png",
            image: image,
            preferencesDefaults: defaults
        ) { _ in }
        #expect(restored.brushSize == 37)
        #expect(restored.hardness == 0.45)
        #expect(restored.brushFlow == 68)
        #expect(restored.brushSpacing == 84)
        #expect(!restored.brushPressureControlsSize)
        #expect(restored.brushPressureControlsOpacity)
        #expect(restored.brushPressureControlsFlow)
        #expect(restored.brushPressureSensitivity == 73)
        #expect(restored.brushSizeJitter == 58)
        #expect(restored.brushAngleJitter == 63)
        #expect(restored.brushAngleFollowsStrokeDirection)
        #expect(restored.brushRoundnessJitter == 57)
        #expect(restored.brushOpacityJitter == 54)
        #expect(restored.brushFlowJitter == 49)
        #expect(restored.brushMinimumRoundness == 23)
        #expect(restored.brushScatter == 420)
        #expect(restored.brushScatterBothAxes)
        #expect(restored.brushScatterCount == 8)
        #expect(restored.brushScatterCountJitter == 46)
        #expect(restored.brushNoiseEnabled)
        #expect(restored.brushWetEdgesEnabled)
        #expect(restored.brushMinimumDiameter == 37)
        #expect(restored.brushMinimumOpacity == 31)
        #expect(restored.brushMinimumFlow == 29)
        #expect(restored.brushTiltControlsShape)
        #expect(restored.brushTipRoundness == 47)
        #expect(restored.brushTipAngleDegrees == -45)
        #expect(restored.brushSmoothing == 64)
        #expect(restored.paintBlendMode == .screen)
        #expect(restored.paintAirbrushEnabled)
        #expect(restored.historyBrushBlendMode == .multiply)
        #expect(restored.pencilAutoEraseEnabled)
    }

    @Test func baseBrushSettingsKeepSelectedCustomPresetActiveAcrossEditorSessions() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = makeViewModel(defaults: defaults)
        first.brushSize = 31
        first.hardness = 0.55
        first.brushFlow = 72
        first.brushSpacing = 66
        first.setBrushSizeJitter(43)
        let preset = try #require(first.createBrushPresetFromCurrentSettings())
        #expect(first.activeBrushPreset == preset)

        let restored = makeViewModel(defaults: defaults)

        #expect(restored.brushSize == 31)
        #expect(restored.hardness == 0.55)
        #expect(restored.brushFlow == 72)
        #expect(restored.brushSpacing == 66)
        #expect(restored.brushSizeJitter == 43)
        #expect(restored.customBrushPresets == [preset])
        #expect(restored.selectedBrushPresetID == preset.id)
        #expect(restored.activeBrushPreset == preset)
        #expect(restored.brushPresetMenuTitle == preset.title)
    }

    @Test func legacyBrushDynamicsAndPresetsDefaultTiltShapeOff() throws {
        let legacyDynamics = Data(
            """
            {
              "pressureControlsSize": true,
              "pressureControlsFlow": false,
              "pressureSensitivity": 64
            }
            """.utf8
        )
        let decodedDynamics = try JSONDecoder().decode(
            ImageEditorBrushDynamicsPreferences.self,
            from: legacyDynamics
        )
        #expect(decodedDynamics.brushSize == 18)
        #expect(decodedDynamics.brushHardness == 0.8)
        #expect(decodedDynamics.brushFlow == 100)
        #expect(decodedDynamics.brushSpacing == 25)
        #expect(!decodedDynamics.pressureControlsOpacity)
        #expect(!decodedDynamics.tiltControlsShape)
        #expect(decodedDynamics.minimumDiameter == 0)
        #expect(decodedDynamics.sizeJitter == 0)
        #expect(decodedDynamics.angleJitter == 0)
        #expect(!decodedDynamics.angleFollowsStrokeDirection)
        #expect(decodedDynamics.roundnessJitter == 0)
        #expect(decodedDynamics.opacityJitter == 0)
        #expect(decodedDynamics.flowJitter == 0)
        #expect(decodedDynamics.minimumRoundness == 1)
        #expect(decodedDynamics.scatter == 0)
        #expect(!decodedDynamics.scatterBothAxes)
        #expect(decodedDynamics.scatterCount == 1)
        #expect(decodedDynamics.scatterCountJitter == 0)
        #expect(!decodedDynamics.noiseEnabled)
        #expect(!decodedDynamics.wetEdgesEnabled)
        #expect(decodedDynamics.minimumOpacity == 0)
        #expect(decodedDynamics.minimumFlow == 0)
        #expect(decodedDynamics.tipRoundness == 100)
        #expect(decodedDynamics.tipAngleDegrees == 0)
        #expect(decodedDynamics.smoothing == 0)
        #expect(decodedDynamics.paintBlendMode == .normal)
        #expect(!decodedDynamics.paintAirbrushEnabled)
        #expect(decodedDynamics.historyBrushBlendMode == .normal)
        #expect(!decodedDynamics.pencilAutoEraseEnabled)

        let legacyPreset = Data(
            """
            {
              "id": "legacy",
              "name": "Legacy",
              "size": 18,
              "hardness": 0.8,
              "flow": 100,
              "spacing": 25,
              "pressureControlsSize": true,
              "pressureControlsFlow": true,
              "pressureSensitivity": 50,
              "isBuiltIn": false
            }
            """.utf8
        )
        let decodedPreset = try JSONDecoder().decode(
            ImageEditorBrushPreset.self,
            from: legacyPreset
        )
        #expect(!decodedPreset.pressureControlsOpacity)
        #expect(!decodedPreset.tiltControlsShape)
        #expect(decodedPreset.minimumDiameter == 0)
        #expect(decodedPreset.sizeJitter == 0)
        #expect(decodedPreset.angleJitter == 0)
        #expect(!decodedPreset.angleFollowsStrokeDirection)
        #expect(decodedPreset.roundnessJitter == 0)
        #expect(decodedPreset.opacityJitter == 0)
        #expect(decodedPreset.flowJitter == 0)
        #expect(decodedPreset.minimumRoundness == 1)
        #expect(decodedPreset.scatter == 0)
        #expect(!decodedPreset.scatterBothAxes)
        #expect(decodedPreset.scatterCount == 1)
        #expect(decodedPreset.scatterCountJitter == 0)
        #expect(!decodedPreset.noiseEnabled)
        #expect(!decodedPreset.wetEdgesEnabled)
        #expect(decodedPreset.minimumOpacity == 0)
        #expect(decodedPreset.minimumFlow == 0)
        #expect(decodedPreset.tipRoundness == 100)
        #expect(decodedPreset.tipAngleDegrees == 0)
        #expect(decodedPreset.smoothing == 0)
    }

    @Test func retouchPressurePreferencesDefaultOffPersistAndStayIndependent() {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        #expect(ImageEditorRetouchDynamicsPreferences.load(from: defaults) == .defaultValue)
        #expect(!ImageEditorRetouchDynamicsPreferences.defaultValue.pressureControlsSize)

        let first = makeViewModel(defaults: defaults)
        first.setBrushPressureControlsSize(false)
        first.setBrushPressureSensitivity(12)
        first.setRetouchPressureControlsSize(true)
        first.setRetouchPressureSensitivity(140)

        let restored = makeViewModel(defaults: defaults)
        #expect(restored.retouchPressureControlsSize)
        #expect(restored.retouchPressureSensitivity == 100)
        #expect(!restored.brushPressureControlsSize)
        #expect(restored.brushPressureSensitivity == 12)

        defaults.set(
            Data("not-json".utf8),
            forKey: ImageEditorRetouchDynamicsPreferences.storageKey
        )
        #expect(ImageEditorRetouchDynamicsPreferences.load(from: defaults) == .defaultValue)
    }

    @Test func retouchPressureSensitivityPresetsPersistEveryExposedChoice() {
        #expect(ImageEditorPressureSensitivityPresets.values == [0, 25, 50, 75, 100])
        #expect(ImageEditorBrushMinimumDiameterPresets.values == [0, 10, 25, 50, 75, 100])
        #expect(ImageEditorBrushSizeJitterPresets.values == [0, 10, 25, 50, 75, 100])
        #expect(ImageEditorBrushAngleJitterPresets.values == [0, 10, 25, 50, 75, 100])
        #expect(ImageEditorBrushRoundnessJitterPresets.values == [0, 10, 25, 50, 75, 100])
        #expect(ImageEditorBrushMinimumRoundnessPresets.values == [1, 10, 25, 50, 75, 100])
        #expect(ImageEditorBrushScatterPresets.values == [0, 25, 50, 100, 200, 500, 1_000])
        #expect(ImageEditorBrushScatterCountPresets.values == [1, 2, 3, 4, 8, 16])
        #expect(ImageEditorBrushScatterCountJitterPresets.values == [0, 10, 25, 50, 75, 100])
        #expect(ImageEditorBrushMinimumOpacityPresets.values == [0, 10, 25, 50, 75, 100])
        #expect(ImageEditorBrushMinimumFlowPresets.values == [0, 10, 25, 50, 75, 100])
        #expect(ImageEditorBrushRoundnessPresets.values == [10, 25, 50, 75, 100])
        #expect(ImageEditorBrushAnglePresets.values == [-90, -45, 0, 45, 90])
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)

        for sensitivity in ImageEditorPressureSensitivityPresets.values {
            viewModel.setRetouchPressureSensitivity(sensitivity)
            #expect(viewModel.retouchPressureSensitivity == sensitivity)
        }

        let restored = makeViewModel(defaults: defaults)
        #expect(restored.retouchPressureSensitivity == 100)
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
            pressureControlsOpacity: true,
            pressureControlsFlow: true,
            pressureSensitivity: 180,
            sizeJitter: 140,
            angleJitter: 140,
            roundnessJitter: 140,
            opacityJitter: 140,
            flowJitter: -20,
            minimumRoundness: -20,
            scatter: 2_000,
            scatterBothAxes: true,
            scatterCount: 99,
            scatterCountJitter: 140,
            noiseEnabled: true,
            wetEdgesEnabled: true,
            minimumDiameter: -20,
            minimumOpacity: 140,
            minimumFlow: 120,
            tipRoundness: 2,
            tipAngleDegrees: -250,
            smoothing: 180,
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
        #expect(preset.pressureControlsOpacity)
        #expect(preset.pressureSensitivity == 100)
        #expect(preset.sizeJitter == 100)
        #expect(preset.angleJitter == 100)
        #expect(preset.roundnessJitter == 100)
        #expect(preset.opacityJitter == 100)
        #expect(preset.flowJitter == 0)
        #expect(preset.minimumRoundness == 1)
        #expect(preset.scatter == 1_000)
        #expect(preset.scatterBothAxes)
        #expect(preset.scatterCount == 16)
        #expect(preset.scatterCountJitter == 100)
        #expect(preset.noiseEnabled)
        #expect(preset.wetEdgesEnabled)
        #expect(preset.minimumDiameter == 0)
        #expect(preset.minimumOpacity == 100)
        #expect(preset.minimumFlow == 100)
        #expect(preset.tipRoundness == 10)
        #expect(preset.tipAngleDegrees == -180)
        #expect(preset.smoothing == 100)
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
        first.setBrushPressureControlsOpacity(true)
        first.setBrushPressureControlsFlow(true)
        first.setBrushPressureSensitivity(73)
        first.setBrushSizeJitter(58)
        first.setBrushAngleJitter(63)
        first.setBrushAngleFollowsStrokeDirection(true)
        first.setBrushRoundnessJitter(57)
        first.setBrushOpacityJitter(54)
        first.setBrushFlowJitter(49)
        first.setBrushMinimumRoundness(23)
        first.setBrushScatter(420)
        first.setBrushScatterBothAxes(true)
        first.setBrushScatterCount(8)
        first.setBrushScatterCountJitter(46)
        first.setBrushNoiseEnabled(true)
        first.setBrushWetEdgesEnabled(true)
        first.setBrushMinimumDiameter(37)
        first.setBrushMinimumOpacity(31)
        first.setBrushMinimumFlow(29)
        first.setBrushTiltControlsShape(true)
        first.setBrushTipRoundness(47)
        first.setBrushTipAngleDegrees(-45)
        first.setBrushSmoothing(64)

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
        #expect(restored.brushPressureControlsOpacity)
        #expect(restored.brushPressureControlsFlow)
        #expect(restored.brushPressureSensitivity == 73)
        #expect(restored.brushSizeJitter == 58)
        #expect(restored.brushAngleJitter == 63)
        #expect(restored.brushAngleFollowsStrokeDirection)
        #expect(restored.brushRoundnessJitter == 57)
        #expect(restored.brushOpacityJitter == 54)
        #expect(restored.brushFlowJitter == 49)
        #expect(restored.brushMinimumRoundness == 23)
        #expect(restored.brushScatter == 420)
        #expect(restored.brushScatterBothAxes)
        #expect(restored.brushScatterCount == 8)
        #expect(restored.brushScatterCountJitter == 46)
        #expect(restored.brushNoiseEnabled)
        #expect(restored.brushWetEdgesEnabled)
        #expect(restored.brushMinimumDiameter == 37)
        #expect(restored.brushMinimumOpacity == 31)
        #expect(restored.brushMinimumFlow == 29)
        #expect(restored.brushTiltControlsShape)
        #expect(restored.brushTipRoundness == 47)
        #expect(restored.brushTipAngleDegrees == -45)
        #expect(restored.brushSmoothing == 64)
        #expect(restored.activeBrushPreset?.id == created.id)

        restored.brushFlow = 66
        #expect(restored.activeBrushPreset == nil)
        #expect(restored.selectedCustomBrushPreset?.id == restoredPreset.id)
        restored.deleteBrushPreset(restoredPreset)
        #expect(restored.customBrushPresets.isEmpty)
        #expect(restored.selectedBrushPresetID == nil)
        #expect(makeViewModel(defaults: defaults).customBrushPresets.isEmpty)
    }

    @Test func resettingBrushSettingsRestoresDefaultsWithoutTouchingPresetsOrDocumentHistory() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.brushSize = 71
        viewModel.opacity = 0.23
        viewModel.hardness = 0.12
        viewModel.brushFlow = 34
        viewModel.brushSpacing = 167
        viewModel.setBrushPressureControlsSize(false)
        viewModel.setBrushPressureControlsOpacity(true)
        viewModel.setBrushPressureControlsFlow(false)
        viewModel.setBrushPressureSensitivity(81)
        viewModel.setBrushSizeJitter(61)
        viewModel.setBrushAngleJitter(62)
        viewModel.setBrushAngleFollowsStrokeDirection(true)
        viewModel.setBrushRoundnessJitter(63)
        viewModel.setBrushOpacityJitter(64)
        viewModel.setBrushFlowJitter(65)
        viewModel.setBrushMinimumRoundness(42)
        viewModel.setBrushScatter(500)
        viewModel.setBrushScatterBothAxes(true)
        viewModel.setBrushScatterCount(8)
        viewModel.setBrushScatterCountJitter(66)
        viewModel.setBrushNoiseEnabled(true)
        viewModel.setBrushWetEdgesEnabled(true)
        viewModel.setBrushMinimumDiameter(31)
        viewModel.setBrushMinimumOpacity(32)
        viewModel.setBrushMinimumFlow(33)
        viewModel.setBrushTiltControlsShape(true)
        viewModel.setBrushTipRoundness(47)
        viewModel.setBrushTipAngleDegrees(-45)
        viewModel.setBrushSmoothing(67)
        viewModel.setPaintBlendMode(.multiply)
        viewModel.setPaintAirbrushEnabled(true)
        viewModel.setHistoryBrushBlendMode(.screen)
        viewModel.setPencilAutoEraseEnabled(true)
        let customPreset = try #require(viewModel.createBrushPresetFromCurrentSettings())

        viewModel.addLayer()
        viewModel.undo()
        let documentBeforeReset = transactionSignature(viewModel.document)
        let undoBeforeReset = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeReset = viewModel.redoStack.map { transactionSignature($0) }

        viewModel.resetBrushSettings()

        #expect(viewModel.brushSize == 18)
        #expect(viewModel.opacity == 1)
        #expect(viewModel.hardness == 0.8)
        #expect(viewModel.brushFlow == 100)
        #expect(viewModel.brushSpacing == 25)
        #expect(viewModel.brushPressureControlsSize)
        #expect(!viewModel.brushPressureControlsOpacity)
        #expect(viewModel.brushPressureControlsFlow)
        #expect(viewModel.brushPressureSensitivity == 50)
        #expect(viewModel.brushSizeJitter == 0)
        #expect(viewModel.brushAngleJitter == 0)
        #expect(!viewModel.brushAngleFollowsStrokeDirection)
        #expect(viewModel.brushRoundnessJitter == 0)
        #expect(viewModel.brushOpacityJitter == 0)
        #expect(viewModel.brushFlowJitter == 0)
        #expect(viewModel.brushMinimumRoundness == 1)
        #expect(viewModel.brushScatter == 0)
        #expect(!viewModel.brushScatterBothAxes)
        #expect(viewModel.brushScatterCount == 1)
        #expect(viewModel.brushScatterCountJitter == 0)
        #expect(!viewModel.brushNoiseEnabled)
        #expect(!viewModel.brushWetEdgesEnabled)
        #expect(viewModel.brushMinimumDiameter == 0)
        #expect(viewModel.brushMinimumOpacity == 0)
        #expect(viewModel.brushMinimumFlow == 0)
        #expect(!viewModel.brushTiltControlsShape)
        #expect(viewModel.brushTipRoundness == 100)
        #expect(viewModel.brushTipAngleDegrees == 0)
        #expect(viewModel.brushSmoothing == 0)
        #expect(viewModel.paintBlendMode == .normal)
        #expect(!viewModel.paintAirbrushEnabled)
        #expect(viewModel.historyBrushBlendMode == .screen)
        #expect(viewModel.pencilAutoEraseEnabled)
        #expect(viewModel.customBrushPresets == [customPreset])
        #expect(transactionSignature(viewModel.document) == documentBeforeReset)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeReset)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeReset)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.brushSettingsReset"))

        viewModel.resetBrushSettings()
        #expect(viewModel.selectedBrushPresetID == nil)
        #expect(transactionSignature(viewModel.document) == documentBeforeReset)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeReset)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeReset)
        #expect(viewModel.customBrushPresets == [customPreset])

        let restored = makeViewModel(defaults: defaults)
        #expect(restored.brushPressureControlsSize)
        #expect(!restored.brushPressureControlsOpacity)
        #expect(restored.brushPressureControlsFlow)
        #expect(restored.brushPressureSensitivity == 50)
        #expect(restored.brushSizeJitter == 0)
        #expect(restored.brushScatter == 0)
        #expect(restored.brushTipRoundness == 100)
        #expect(restored.brushSmoothing == 0)
        #expect(restored.paintBlendMode == .normal)
        #expect(!restored.paintAirbrushEnabled)
        #expect(restored.historyBrushBlendMode == .screen)
        #expect(restored.pencilAutoEraseEnabled)
        #expect(restored.customBrushPresets == [customPreset])
    }

    @Test func updatingSelectedCustomPresetKeepsIdentityOrderAndDocumentTransactions() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.brushSize = 22
        let first = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.brushSize = 33
        let second = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.applyBrushPreset(first)

        viewModel.brushSize = 41
        viewModel.setBrushSizeJitter(74)
        viewModel.setBrushNoiseEnabled(true)
        #expect(viewModel.selectedBrushPresetID == first.id)
        #expect(viewModel.selectedCustomBrushPreset?.id == first.id)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(
            viewModel.brushPresetMenuTitle
                == L10n.format("imageEditor.brushPreset.modified", first.title)
        )

        viewModel.addLayer()
        viewModel.undo()
        let documentBeforeUpdate = transactionSignature(viewModel.document)
        let undoBeforeUpdate = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeUpdate = viewModel.redoStack.map { transactionSignature($0) }

        #expect(viewModel.updateSelectedCustomBrushPresetFromCurrentSettings())

        let updated = try #require(viewModel.customBrushPresets.first)
        #expect(viewModel.customBrushPresets.map(\.id) == [first.id, second.id])
        #expect(updated.id == first.id)
        #expect(updated.name == first.name)
        #expect(updated.size == 41)
        #expect(updated.sizeJitter == 74)
        #expect(updated.noiseEnabled)
        #expect(viewModel.selectedBrushPresetID == first.id)
        #expect(viewModel.activeBrushPreset == updated)
        #expect(viewModel.brushPresetMenuTitle == updated.title)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.brushPresetUpdated", updated.title))
        #expect(transactionSignature(viewModel.document) == documentBeforeUpdate)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeUpdate)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeUpdate)

        let presetsAfterUpdate = viewModel.customBrushPresets
        #expect(!viewModel.updateSelectedCustomBrushPresetFromCurrentSettings())
        #expect(viewModel.customBrushPresets == presetsAfterUpdate)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.brushPresetUnchanged", updated.title))
        #expect(transactionSignature(viewModel.document) == documentBeforeUpdate)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeUpdate)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeUpdate)

        let restored = makeViewModel(defaults: defaults)
        #expect(restored.customBrushPresets == presetsAfterUpdate)
        #expect(restored.selectedBrushPresetID == first.id)
        #expect(restored.selectedCustomBrushPreset?.id == first.id)

        viewModel.resetBrushSettings()
        #expect(viewModel.selectedBrushPresetID == nil)
        #expect(viewModel.selectedCustomBrushPreset == nil)
        #expect(!viewModel.updateSelectedCustomBrushPresetFromCurrentSettings())
        #expect(viewModel.statusText == L10n.text("imageEditor.status.brushPresetUpdateUnavailable"))
        #expect(viewModel.customBrushPresets == presetsAfterUpdate)
        #expect(makeViewModel(defaults: defaults).selectedBrushPresetID == nil)

        let builtIn = try #require(ImageEditorBrushPreset.defaultPresets.first)
        viewModel.applyBrushPreset(builtIn)
        #expect(viewModel.selectedBrushPresetID == builtIn.id)
        #expect(viewModel.selectedCustomBrushPreset == nil)
        #expect(!viewModel.updateSelectedCustomBrushPresetFromCurrentSettings())
        #expect(viewModel.customBrushPresets == presetsAfterUpdate)
        #expect(makeViewModel(defaults: defaults).selectedBrushPresetID == nil)
    }

    @Test func renamingSelectedCustomPresetPreservesSavedSettingsDirtyStateAndTransactions() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.brushSize = 22
        let first = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.brushSize = 33
        let second = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.applyBrushPreset(first)
        viewModel.brushSize = 41
        #expect(viewModel.activeBrushPreset == nil)

        viewModel.addLayer()
        viewModel.undo()
        let documentBeforeRename = transactionSignature(viewModel.document)
        let undoBeforeRename = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeRename = viewModel.redoStack.map { transactionSignature($0) }
        let normalizedName = String(repeating: "A", count: ImageEditorBrushPreset.maximumCustomNameLength)

        #expect(
            viewModel.renameSelectedCustomBrushPreset(
                to: "  \(String(repeating: "A", count: 90))  \n"
            )
        )

        let renamed = try #require(viewModel.customBrushPresets.first)
        #expect(viewModel.customBrushPresets.map(\.id) == [first.id, second.id])
        #expect(renamed == first.renamingCustomPreset(to: normalizedName))
        #expect(viewModel.customBrushPresets[1] == second)
        #expect(viewModel.selectedBrushPresetID == first.id)
        #expect(viewModel.selectedCustomBrushPreset == renamed)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(
            viewModel.brushPresetMenuTitle
                == L10n.format("imageEditor.brushPreset.modified", normalizedName)
        )
        #expect(viewModel.statusText == L10n.format("imageEditor.status.brushPresetRenamed", normalizedName))
        #expect(transactionSignature(viewModel.document) == documentBeforeRename)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeRename)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeRename)

        let preferencesAfterRename = defaults.data(
            forKey: ImageEditorBrushPresetPreferences.storageKey
        )
        #expect(!viewModel.renameSelectedCustomBrushPreset(to: "  \(normalizedName)\n"))
        #expect(viewModel.customBrushPresets == [renamed, second])
        #expect(
            viewModel.statusText
                == L10n.format("imageEditor.status.brushPresetRenameUnchanged", normalizedName)
        )
        #expect(
            defaults.data(forKey: ImageEditorBrushPresetPreferences.storageKey)
                == preferencesAfterRename
        )

        #expect(!viewModel.renameSelectedCustomBrushPreset(to: " \n "))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.brushPresetNameRequired"))
        #expect(viewModel.customBrushPresets == [renamed, second])
        #expect(transactionSignature(viewModel.document) == documentBeforeRename)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeRename)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeRename)

        let restored = makeViewModel(defaults: defaults)
        #expect(restored.customBrushPresets == [renamed, second])
        #expect(restored.selectedBrushPresetID == first.id)
        #expect(restored.selectedCustomBrushPreset == renamed)

        let builtIn = try #require(ImageEditorBrushPreset.defaultPresets.first)
        viewModel.applyBrushPreset(builtIn)
        #expect(!viewModel.renameSelectedCustomBrushPreset(to: "Must Not Replace Custom"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.brushPresetRenameUnavailable"))
        #expect(viewModel.customBrushPresets == [renamed, second])
        #expect(makeViewModel(defaults: defaults).selectedBrushPresetID == nil)
    }

    @Test func revertingSelectedCustomPresetRestoresSavedSettingsWithoutChangingResourcesOrHistory() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.brushSize = 22
        viewModel.hardness = 0.35
        viewModel.brushFlow = 44
        viewModel.brushSpacing = 73
        viewModel.brushSizeJitter = 61
        viewModel.brushAngleJitter = 27
        viewModel.brushNoiseEnabled = true
        let source = try #require(viewModel.createBrushPresetFromCurrentSettings())

        viewModel.brushSize = 83
        viewModel.hardness = 0.9
        viewModel.brushFlow = 91
        viewModel.brushSpacing = 12
        viewModel.brushSizeJitter = 0
        viewModel.brushAngleJitter = 78
        viewModel.brushNoiseEnabled = false
        #expect(viewModel.canRevertSelectedCustomBrushPreset)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(
            viewModel.brushPresetMenuTitle
                == L10n.format("imageEditor.brushPreset.modified", source.title)
        )

        viewModel.addLayer()
        viewModel.undo()
        let documentBeforeRevert = transactionSignature(viewModel.document)
        let undoBeforeRevert = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeRevert = viewModel.redoStack.map { transactionSignature($0) }
        let presetPreferencesBeforeRevert = defaults.data(
            forKey: ImageEditorBrushPresetPreferences.storageKey
        )

        #expect(viewModel.revertSelectedCustomBrushPresetToSavedSettings())

        #expect(viewModel.customBrushPresets == [source])
        #expect(viewModel.selectedBrushPresetID == source.id)
        #expect(viewModel.selectedCustomBrushPreset == source)
        #expect(viewModel.activeBrushPreset == source)
        #expect(!viewModel.canRevertSelectedCustomBrushPreset)
        #expect(viewModel.brushPresetMenuTitle == source.title)
        #expect(viewModel.brushSize == source.size)
        #expect(viewModel.hardness == source.hardness)
        #expect(viewModel.brushFlow == source.flow)
        #expect(viewModel.brushSpacing == source.spacing)
        #expect(viewModel.brushSizeJitter == source.sizeJitter)
        #expect(viewModel.brushAngleJitter == source.angleJitter)
        #expect(viewModel.brushNoiseEnabled == source.noiseEnabled)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.brushPresetReverted", source.title))
        #expect(
            defaults.data(forKey: ImageEditorBrushPresetPreferences.storageKey)
                == presetPreferencesBeforeRevert
        )
        #expect(transactionSignature(viewModel.document) == documentBeforeRevert)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeRevert)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeRevert)

        let savedPreferences = defaults.data(forKey: ImageEditorBrushPresetPreferences.storageKey)
        #expect(!viewModel.revertSelectedCustomBrushPresetToSavedSettings())
        #expect(viewModel.statusText == L10n.format("imageEditor.status.brushPresetUnchanged", source.title))
        #expect(defaults.data(forKey: ImageEditorBrushPresetPreferences.storageKey) == savedPreferences)
        #expect(transactionSignature(viewModel.document) == documentBeforeRevert)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeRevert)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeRevert)

        let restored = makeViewModel(defaults: defaults)
        #expect(restored.customBrushPresets == [source])
        #expect(restored.selectedBrushPresetID == source.id)
        #expect(restored.brushSizeJitter == source.sizeJitter)
        #expect(restored.brushAngleJitter == source.angleJitter)
        #expect(restored.brushNoiseEnabled == source.noiseEnabled)
        #expect(restored.activeBrushPreset == source)

        let builtIn = try #require(ImageEditorBrushPreset.defaultPresets.first)
        viewModel.applyBrushPreset(builtIn)
        viewModel.brushSize = 57
        #expect(!viewModel.canRevertSelectedCustomBrushPreset)
        #expect(!viewModel.revertSelectedCustomBrushPresetToSavedSettings())
        #expect(viewModel.statusText == L10n.text("imageEditor.status.brushPresetRevertUnavailable"))
        #expect(viewModel.customBrushPresets == [source])
    }

    @Test func duplicatingSelectedCustomPresetCreatesAdjacentUniqueResourceWithoutApplyingIt() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.brushSize = 22
        let original = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.brushSize = 33
        let trailing = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.applyBrushPreset(original)
        let longName = String(repeating: "A", count: ImageEditorBrushPreset.maximumCustomNameLength)
        #expect(viewModel.renameSelectedCustomBrushPreset(to: longName))
        let source = try #require(viewModel.selectedCustomBrushPreset)
        viewModel.brushSize = 41
        #expect(viewModel.activeBrushPreset == nil)

        viewModel.addLayer()
        viewModel.undo()
        let documentBeforeDuplicate = transactionSignature(viewModel.document)
        let undoBeforeDuplicate = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeDuplicate = viewModel.redoStack.map { transactionSignature($0) }
        let firstSuffix = L10n.text("imageEditor.brushPreset.copySuffix")
        let firstCopyName = String(
            longName.prefix(ImageEditorBrushPreset.maximumCustomNameLength - firstSuffix.count)
        ) + firstSuffix

        let firstCopy = try #require(viewModel.duplicateSelectedCustomBrushPreset())

        #expect(firstCopy.id != source.id)
        #expect(firstCopy.name == firstCopyName)
        #expect(firstCopy.name?.count == ImageEditorBrushPreset.maximumCustomNameLength)
        #expect(firstCopy == source.copyingCustomPreset(id: firstCopy.id, name: firstCopyName))
        #expect(viewModel.customBrushPresets == [source, firstCopy, trailing])
        #expect(viewModel.selectedBrushPresetID == firstCopy.id)
        #expect(viewModel.selectedCustomBrushPreset == firstCopy)
        #expect(viewModel.brushSize == 41)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(
            viewModel.brushPresetMenuTitle
                == L10n.format("imageEditor.brushPreset.modified", firstCopy.title)
        )
        #expect(viewModel.statusText == L10n.format("imageEditor.status.brushPresetDuplicated", firstCopy.title))
        #expect(transactionSignature(viewModel.document) == documentBeforeDuplicate)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeDuplicate)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeDuplicate)

        viewModel.applyBrushPreset(source)
        let numberedSuffix = L10n.format("imageEditor.brushPreset.copySuffixIndexed", 2)
        let secondCopyName = String(
            longName.prefix(ImageEditorBrushPreset.maximumCustomNameLength - numberedSuffix.count)
        ) + numberedSuffix
        let secondCopy = try #require(viewModel.duplicateSelectedCustomBrushPreset())
        #expect(secondCopy.name == secondCopyName)
        #expect(Set(viewModel.customBrushPresets.compactMap(\.name)).count == 4)
        #expect(viewModel.customBrushPresets == [source, secondCopy, firstCopy, trailing])
        #expect(viewModel.selectedBrushPresetID == secondCopy.id)
        #expect(transactionSignature(viewModel.document) == documentBeforeDuplicate)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeDuplicate)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeDuplicate)

        let restored = makeViewModel(defaults: defaults)
        #expect(restored.customBrushPresets == [source, secondCopy, firstCopy, trailing])
        #expect(restored.selectedBrushPresetID == secondCopy.id)

        let builtIn = try #require(ImageEditorBrushPreset.defaultPresets.first)
        viewModel.applyBrushPreset(builtIn)
        #expect(viewModel.duplicateSelectedCustomBrushPreset() == nil)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.brushPresetDuplicateUnavailable"))
        #expect(viewModel.customBrushPresets == [source, secondCopy, firstCopy, trailing])
    }

    @Test func movingSelectedCustomPresetPersistsOrderWithoutChangingSelectionOrTransactions() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.brushSize = 12
        let first = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.brushSize = 24
        let second = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.brushSize = 36
        let third = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.applyBrushPreset(second)
        viewModel.brushSize = 48
        #expect(viewModel.activeBrushPreset == nil)

        viewModel.addLayer()
        viewModel.undo()
        let documentBeforeMove = transactionSignature(viewModel.document)
        let undoBeforeMove = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeMove = viewModel.redoStack.map { transactionSignature($0) }

        #expect(viewModel.canMoveSelectedCustomBrushPresetUp)
        #expect(viewModel.canMoveSelectedCustomBrushPresetDown)
        #expect(viewModel.moveSelectedCustomBrushPresetUp())
        #expect(viewModel.customBrushPresets == [second, first, third])
        #expect(viewModel.selectedBrushPresetID == second.id)
        #expect(viewModel.selectedCustomBrushPreset == second)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(!viewModel.canMoveSelectedCustomBrushPresetUp)
        #expect(viewModel.canMoveSelectedCustomBrushPresetDown)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.brushPresetMoved", second.title))

        let preferencesAtTop = defaults.data(
            forKey: ImageEditorBrushPresetPreferences.storageKey
        )
        #expect(!viewModel.moveSelectedCustomBrushPresetUp())
        #expect(viewModel.customBrushPresets == [second, first, third])
        #expect(
            defaults.data(forKey: ImageEditorBrushPresetPreferences.storageKey)
                == preferencesAtTop
        )
        #expect(viewModel.statusText == L10n.text("imageEditor.status.brushPresetMoveUnavailable"))

        #expect(viewModel.moveSelectedCustomBrushPresetDown())
        #expect(viewModel.customBrushPresets == [first, second, third])
        #expect(viewModel.moveSelectedCustomBrushPresetDown())
        #expect(viewModel.customBrushPresets == [first, third, second])
        #expect(viewModel.canMoveSelectedCustomBrushPresetUp)
        #expect(!viewModel.canMoveSelectedCustomBrushPresetDown)
        #expect(!viewModel.moveSelectedCustomBrushPresetDown())
        #expect(viewModel.customBrushPresets == [first, third, second])
        #expect(viewModel.brushSize == 48)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(transactionSignature(viewModel.document) == documentBeforeMove)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeMove)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeMove)

        let restored = makeViewModel(defaults: defaults)
        #expect(restored.customBrushPresets == [first, third, second])
        #expect(restored.selectedBrushPresetID == second.id)
        #expect(restored.selectedCustomBrushPreset == second)

        let builtIn = try #require(ImageEditorBrushPreset.defaultPresets.first)
        viewModel.applyBrushPreset(builtIn)
        #expect(!viewModel.canMoveSelectedCustomBrushPresetUp)
        #expect(!viewModel.canMoveSelectedCustomBrushPresetDown)
        #expect(!viewModel.moveSelectedCustomBrushPresetUp())
        #expect(viewModel.customBrushPresets == [first, third, second])
    }

    @Test func dragReorderMovesAFilteredCustomPresetOntoItsCatalogTarget() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.brushSize = 12
        let first = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.brushSize = 24
        let second = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.brushSize = 36
        let third = try #require(viewModel.createBrushPresetFromCurrentSettings())
        #expect(viewModel.renameCustomBrushPreset(id: first.id, to: "Edge Soft"))
        #expect(viewModel.renameCustomBrushPreset(id: second.id, to: "Hidden Middle"))
        #expect(viewModel.renameCustomBrushPreset(id: third.id, to: "Edge Hard"))
        viewModel.brushSize = 91
        viewModel.addLayer()
        viewModel.undo()
        let documentBeforeMove = transactionSignature(viewModel.document)
        let undoBeforeMove = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeMove = viewModel.redoStack.map { transactionSignature($0) }

        let filtered = ImageEditorBrushPresetQuery(
            searchText: "Edge",
            scope: .custom
        ).filter(viewModel.brushPresets)
        #expect(filtered.map(\.id) == [first.id, third.id])
        let move = try #require(ImageEditorBrushPresetReorderPolicy.resolvedMove(
            draggedIDs: [filtered[0].id],
            onto: filtered[1].id,
            customPresets: viewModel.customBrushPresets
        ))
        #expect(viewModel.moveCustomBrushPreset(
            id: move.sourceID,
            toIndex: move.destinationIndex
        ))

        #expect(viewModel.customBrushPresets.map(\.id) == [second.id, third.id, first.id])
        #expect(viewModel.selectedBrushPresetID == third.id)
        #expect(viewModel.brushSize == 91)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(transactionSignature(viewModel.document) == documentBeforeMove)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeMove)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeMove)
        #expect(
            makeViewModel(defaults: defaults).customBrushPresets.map(\.id)
                == [second.id, third.id, first.id]
        )
    }

    @Test func filteredBrushLibraryExportKeepsVisibleOrderWithoutChangingTransactions() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)

        viewModel.brushSize = 31
        let zulu = try #require(viewModel.createBrushPresetFromCurrentSettings())
        #expect(viewModel.renameSelectedCustomBrushPreset(to: "Ink Zulu"))
        viewModel.brushSize = 43
        _ = try #require(viewModel.createBrushPresetFromCurrentSettings())
        #expect(viewModel.renameSelectedCustomBrushPreset(to: "Chalk"))
        viewModel.brushSize = 57
        let alpha = try #require(viewModel.createBrushPresetFromCurrentSettings())
        #expect(viewModel.renameSelectedCustomBrushPreset(to: "Ink Alpha"))

        viewModel.brushSize = 91
        viewModel.addLayer()
        viewModel.undo()
        let selectedPresetID = viewModel.selectedBrushPresetID
        let documentBeforeExport = transactionSignature(viewModel.document)
        let undoBeforeExport = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeExport = viewModel.redoStack.map { transactionSignature($0) }
        let query = ImageEditorBrushPresetQuery(
            searchText: "ink",
            scope: .custom,
            sortOrder: .nameAscending
        )
        let visibleIDs = query.exportableCustomPresetIDs(in: viewModel.brushPresets)

        #expect(visibleIDs == [alpha.id, zulu.id])
        let data = try viewModel.brushPresetLibraryData(presetIDs: visibleIDs)
        let library = try JSONDecoder().decode(ImageEditorBrushPresetLibrary.self, from: data)

        #expect(library.presets.map(\.id) == visibleIDs)
        #expect(library.presets.map(\.title) == ["Ink Alpha", "Ink Zulu"])
        #expect(viewModel.brushSize == 91)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(viewModel.selectedBrushPresetID == selectedPresetID)
        #expect(transactionSignature(viewModel.document) == documentBeforeExport)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeExport)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeExport)
    }

    @Test func replacingBrushLibraryIsAtomicAndPreservesCurrentEditingState() throws {
        let (sourceDefaults, sourceSuiteName) = temporaryDefaults()
        defer { sourceDefaults.removePersistentDomain(forName: sourceSuiteName) }
        let source = makeViewModel(defaults: sourceDefaults)
        source.brushSize = 27
        _ = try #require(source.createBrushPresetFromCurrentSettings())
        #expect(source.renameSelectedCustomBrushPreset(to: "Shared Ink"))
        source.brushSize = 49
        source.setBrushScatter(380)
        _ = try #require(source.createBrushPresetFromCurrentSettings())
        #expect(source.renameSelectedCustomBrushPreset(to: "Shared Texture"))
        let sourcePresets = source.customBrushPresets
        let replacementData = try source.brushPresetLibraryData()

        let (targetDefaults, targetSuiteName) = temporaryDefaults()
        defer { targetDefaults.removePersistentDomain(forName: targetSuiteName) }
        let target = makeViewModel(defaults: targetDefaults)
        let builtIn = try #require(ImageEditorBrushPreset.defaultPresets.first)
        target.applyBrushPreset(builtIn)
        #expect(target.setBrushPresetFavorite(id: builtIn.id, isFavorite: true))
        target.brushSize = 13
        let local = try #require(target.createBrushPresetFromCurrentSettings())
        #expect(target.renameSelectedCustomBrushPreset(to: "Local Brush"))
        target.applyBrushPreset(try #require(target.selectedCustomBrushPreset))
        #expect(target.setBrushPresetFavorite(id: local.id, isFavorite: true))
        target.brushSize = 91
        target.setBrushAngleJitter(44)
        target.addLayer()
        target.undo()
        let documentBeforeReplace = transactionSignature(target.document)
        let undoBeforeReplace = target.undoStack.map { transactionSignature($0) }
        let redoBeforeReplace = target.redoStack.map { transactionSignature($0) }

        let result = try target.replaceBrushPresetLibraryData(replacementData)

        #expect(result == ImageEditorBrushPresetImportResult(
            importedCount: 2,
            unselectedCount: 0,
            capacitySkippedCount: 0
        ))
        #expect(target.customBrushPresets.map(\.title) == ["Shared Ink", "Shared Texture"])
        #expect(Set(target.customBrushPresets.map(\.id)).isDisjoint(with: sourcePresets.map(\.id)))
        #expect(!target.customBrushPresets.contains(where: { $0.id == local.id }))
        #expect(target.selectedBrushPresetID == target.customBrushPresets.last?.id)
        #expect(target.favoriteBrushPresetIDs == [builtIn.id])
        #expect(target.recentBrushPresetIDs == [builtIn.id])
        #expect(target.brushSize == 91)
        #expect(target.brushAngleJitter == 44)
        #expect(target.activeBrushPreset == nil)
        #expect(transactionSignature(target.document) == documentBeforeReplace)
        #expect(target.undoStack.map { transactionSignature($0) } == undoBeforeReplace)
        #expect(target.redoStack.map { transactionSignature($0) } == redoBeforeReplace)

        let presetsBeforeInvalidReplace = target.customBrushPresets
        let selectedBeforeInvalidReplace = target.selectedBrushPresetID
        let favoritesBeforeInvalidReplace = target.favoriteBrushPresetIDs
        let recentBeforeInvalidReplace = target.recentBrushPresetIDs
        #expect(throws: ImageEditorBrushPresetLibraryError.invalidFile) {
            try target.replaceBrushPresetLibraryData(Data("not-json".utf8))
        }
        #expect(target.customBrushPresets == presetsBeforeInvalidReplace)
        #expect(target.selectedBrushPresetID == selectedBeforeInvalidReplace)
        #expect(target.favoriteBrushPresetIDs == favoritesBeforeInvalidReplace)
        #expect(target.recentBrushPresetIDs == recentBeforeInvalidReplace)
        #expect(transactionSignature(target.document) == documentBeforeReplace)
        #expect(target.undoStack.map { transactionSignature($0) } == undoBeforeReplace)
        #expect(target.redoStack.map { transactionSignature($0) } == redoBeforeReplace)

        let restored = makeViewModel(defaults: targetDefaults)
        #expect(restored.customBrushPresets == target.customBrushPresets)
        #expect(restored.selectedBrushPresetID == target.selectedBrushPresetID)
        #expect(restored.favoriteBrushPresetIDs == [builtIn.id])
        #expect(restored.recentBrushPresetIDs == [builtIn.id])
    }

    @Test func brushLibraryImportSelectionStaysWithinCapacityAndCanChooseLaterItems() {
        let defaults = ImageEditorBrushPresetImportSelectionPolicy.defaultSelection(
            presetCount: 4,
            capacity: 2
        )
        #expect(defaults == IndexSet([0, 1]))

        let removedFirst = ImageEditorBrushPresetImportSelectionPolicy.toggling(
            index: 0,
            in: defaults,
            presetCount: 4,
            capacity: 2
        )
        let choseLater = ImageEditorBrushPresetImportSelectionPolicy.toggling(
            index: 3,
            in: removedFirst,
            presetCount: 4,
            capacity: 2
        )
        #expect(choseLater == IndexSet([1, 3]))
        #expect(ImageEditorBrushPresetImportSelectionPolicy.toggling(
            index: 2,
            in: choseLater,
            presetCount: 4,
            capacity: 2
        ) == choseLater)
        #expect(ImageEditorBrushPresetImportSelectionPolicy.normalizedSelection(
            IndexSet([0, 3, 5]),
            presetCount: 4,
            capacity: 1
        ) == IndexSet(integer: 0))
        #expect(ImageEditorBrushPresetImportSelectionPolicy.defaultSelection(
            presetCount: 4,
            capacity: 0
        ).isEmpty)
    }

    @Test func brushLibraryImportSelectionSearchesWithoutLosingSourceIndexes() {
        let titles = ["Soft Ink", "Árbol Grain", "Ink Wash", "Chalk"]
        #expect(ImageEditorBrushPresetImportSelectionPolicy.matchingIndexes(
            presetTitles: titles,
            searchText: ""
        ) == IndexSet(integersIn: 0..<4))
        #expect(ImageEditorBrushPresetImportSelectionPolicy.matchingIndexes(
            presetTitles: titles,
            searchText: " ink "
        ) == IndexSet([0, 2]))
        #expect(ImageEditorBrushPresetImportSelectionPolicy.matchingIndexes(
            presetTitles: titles,
            searchText: "arbol"
        ) == IndexSet(integer: 1))
        #expect(ImageEditorBrushPresetImportSelectionPolicy.matchingIndexes(
            presetTitles: titles,
            searchText: "missing"
        ).isEmpty)

        let selectedAcrossFilters = ImageEditorBrushPresetImportSelectionPolicy.selectingAll(
            matchingIndexes: IndexSet([0, 2]),
            in: IndexSet(integer: 3),
            presetCount: titles.count,
            capacity: 2
        )
        #expect(selectedAcrossFilters == IndexSet([0, 3]))
        #expect(ImageEditorBrushPresetImportSelectionPolicy.selectingAll(
            matchingIndexes: IndexSet([1, 2]),
            in: selectedAcrossFilters,
            presetCount: titles.count,
            capacity: 2
        ) == selectedAcrossFilters)
        #expect(ImageEditorBrushPresetImportSelectionPolicy.deselectingAll(
            matchingIndexes: IndexSet([0, 2]),
            in: IndexSet([0, 2, 3]),
            presetCount: titles.count,
            capacity: 3
        ) == IndexSet(integer: 3))
    }

    @Test func brushLibraryImportSelectionSortsVisibleRowsWithoutChangingSourceIndexes() {
        let titles = ["Zulu Ink", "Alpha Grain", "Beta Chalk", "alpha Wash"]
        let filtered = IndexSet([0, 1, 3])

        #expect(ImageEditorBrushPresetImportSelectionPolicy.orderedIndexes(
            presetTitles: titles,
            matchingIndexes: filtered,
            sortOrder: .catalog
        ) == [0, 1, 3])
        #expect(ImageEditorBrushPresetImportSelectionPolicy.orderedIndexes(
            presetTitles: titles,
            matchingIndexes: filtered,
            sortOrder: .nameAscending
        ) == [1, 3, 0])
        #expect(ImageEditorBrushPresetImportSelectionPolicy.orderedIndexes(
            presetTitles: titles,
            matchingIndexes: filtered,
            sortOrder: .nameDescending
        ) == [0, 3, 1])
        #expect(ImageEditorBrushPresetImportSelectionPolicy.orderedIndexes(
            presetTitles: titles,
            matchingIndexes: IndexSet([0, 4, 9]),
            sortOrder: .nameAscending
        ) == [0])

        let selected = IndexSet([0, 3])
        let displayOrder = ImageEditorBrushPresetImportSelectionPolicy.orderedIndexes(
            presetTitles: titles,
            matchingIndexes: IndexSet(integersIn: titles.indices),
            sortOrder: .nameAscending
        )
        #expect(displayOrder == [1, 3, 2, 0])
        #expect(selected == IndexSet([0, 3]))
        #expect(ImageEditorBrushPresetImportSelectionPolicy.normalizedSelection(
            selected,
            presetCount: titles.count,
            capacity: 2
        ) == selected)
    }

    @Test func brushLibraryImportSelectionViewSortsFilteredRowsWithoutMutatingSelection() throws {
        func descendants(of view: NSView) -> [NSView] {
            view.subviews + view.subviews.flatMap { descendants(of: $0) }
        }

        let presets = [
            ImageEditorBrushPreset(id: "0", name: "Zulu Ink", size: 10),
            ImageEditorBrushPreset(id: "1", name: "Alpha Grain", size: 20),
            ImageEditorBrushPreset(id: "2", name: "Beta Chalk", size: 30),
            ImageEditorBrushPreset(id: "3", name: "alpha Wash", size: 40)
        ]
        let inspection = ImageEditorBrushPresetLibraryInspection(
            mode: .append,
            presetCount: 4,
            installableCount: 2,
            skippedCount: 2,
            presetPreviews: presets.enumerated().map { index, preset in
                ImageEditorBrushPresetLibraryPreview(
                    sourceIndex: index,
                    preset: preset
                )
            },
            reservedTitles: []
        )
        let view = ImageEditorBrushPresetImportSelectionView(inspection: inspection)
        let initialSelection = view.selectedIndexes
        let sortPopUp = try #require(view.subviews.first {
            $0.identifier?.rawValue == "image-editor-brush-preset-import-sort"
        } as? NSPopUpButton)
        let searchField = try #require(view.subviews.first {
            $0.identifier?.rawValue == "image-editor-brush-preset-import-search"
        } as? NSSearchField)
        let stacks = view.subviews.compactMap { subview in
            (subview as? NSScrollView)?.documentView as? NSStackView
        }
        let stack = try #require(stacks.first)

        sortPopUp.selectItem(at: 1)
        #expect(sortPopUp.sendAction(sortPopUp.action, to: sortPopUp.target))
        let sourceIndexes = stack.arrangedSubviews.compactMap { row in
            descendants(of: row).compactMap { $0 as? NSButton }.first?.tag
        }
        #expect(sourceIndexes == [1, 3, 2, 0])
        #expect(view.selectedIndexes == initialSelection)

        searchField.stringValue = "alpha"
        #expect(searchField.sendAction(searchField.action, to: searchField.target))
        #expect(
            stack.arrangedSubviews
                .filter { !$0.isHidden }
                .compactMap { row in
                    descendants(of: row).compactMap { $0 as? NSButton }.first?.tag
                }
                == [1, 3]
        )
        #expect(view.selectedIndexes == initialSelection)
        let firstRow = stack.arrangedSubviews.first
        let alphaRow = try #require(firstRow)
        let parameterLabels = descendants(of: alphaRow).compactMap {
            $0 as? NSTextField
        }
        let parameterLabel = try #require(parameterLabels.first)
        #expect(parameterLabel.stringValue == ImageEditorBrushPresetLibraryPreview(
            sourceIndex: 1,
            preset: presets[1]
        ).primarySummary)
        let thumbnail = try #require(descendants(of: alphaRow).first {
            $0.identifier?.rawValue == "image-editor-brush-preset-import-thumbnail-1"
        } as? NSImageView)
        #expect(thumbnail.image?.size == ImageEditorBrushPresetLibraryThumbnailRenderer.defaultSize)
    }

    @Test func brushLibraryThumbnailShowsRoundnessAndAngleBeforeImport() throws {
        let horizontalPreview = ImageEditorBrushPresetLibraryPreview(
            sourceIndex: 0,
            preset: ImageEditorBrushPreset(
                id: "horizontal",
                name: "Horizontal",
                size: 24,
                hardness: 1,
                tipRoundness: 25,
                tipAngleDegrees: 0
            )
        )
        let verticalPreview = ImageEditorBrushPresetLibraryPreview(
            sourceIndex: 1,
            preset: ImageEditorBrushPreset(
                id: "vertical",
                name: "Vertical",
                size: 24,
                hardness: 1,
                tipRoundness: 25,
                tipAngleDegrees: 90
            )
        )
        let horizontalSize = ImageEditorBrushPresetLibraryThumbnailRenderer.tipSize(
            for: horizontalPreview
        )
        #expect(horizontalSize.width > horizontalSize.height)
        #expect(horizontalSize.height >= 4)

        let horizontal = ImageEditorBrushPresetLibraryThumbnailRenderer.image(
            for: horizontalPreview
        )
        let vertical = ImageEditorBrushPresetLibraryThumbnailRenderer.image(
            for: verticalPreview
        )
        let horizontalRight = try #require(
            horizontal.color(at: CGPoint(x: 26, y: 18))?.usingColorSpace(.deviceRGB)
        )
        let horizontalTop = try #require(
            horizontal.color(at: CGPoint(x: 18, y: 26))?.usingColorSpace(.deviceRGB)
        )
        let verticalRight = try #require(
            vertical.color(at: CGPoint(x: 26, y: 18))?.usingColorSpace(.deviceRGB)
        )
        let verticalTop = try #require(
            vertical.color(at: CGPoint(x: 18, y: 26))?.usingColorSpace(.deviceRGB)
        )
        #expect(horizontalRight.brightnessComponent > horizontalTop.brightnessComponent + 0.3)
        #expect(verticalTop.brightnessComponent > verticalRight.brightnessComponent + 0.3)
    }

    @Test func brushLibraryImportSelectionInvertsVisibleMatchesWithinGlobalCapacity() {
        #expect(ImageEditorBrushPresetImportSelectionPolicy.inverting(
            matchingIndexes: IndexSet([0, 1, 2]),
            in: IndexSet([0, 3]),
            presetCount: 4,
            capacity: 3
        ) == IndexSet([1, 2, 3]))
        #expect(ImageEditorBrushPresetImportSelectionPolicy.inverting(
            matchingIndexes: IndexSet([0, 1, 2]),
            in: IndexSet([0, 3]),
            presetCount: 4,
            capacity: 2
        ) == IndexSet([1, 3]))
        #expect(ImageEditorBrushPresetImportSelectionPolicy.inverting(
            matchingIndexes: IndexSet([0, 1, 2]),
            in: IndexSet([0, 1, 2, 3]),
            presetCount: 4,
            capacity: 4
        ) == IndexSet(integer: 3))
        #expect(ImageEditorBrushPresetImportSelectionPolicy.inverting(
            matchingIndexes: IndexSet(),
            in: IndexSet([0, 3]),
            presetCount: 4,
            capacity: 3
        ) == IndexSet([0, 3]))
    }

    @Test func brushLibraryInstallationPlanMatchesCommittedConflictRenames() throws {
        let sourcePresets = [
            ImageEditorBrushPreset(id: "source-one", name: "Shared Brush", size: 24),
            ImageEditorBrushPreset(id: "source-two", name: "Shared Brush", size: 48),
            ImageEditorBrushPreset(id: "source-three", name: "Unique Brush", size: 72)
        ]
        let data = try JSONEncoder().encode(
            ImageEditorBrushPresetLibrary(presets: sourcePresets)
        )
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        _ = try #require(viewModel.createBrushPresetFromCurrentSettings())
        #expect(viewModel.renameSelectedCustomBrushPreset(to: "Shared Brush"))

        let appendInspection = try viewModel.inspectBrushPresetLibraryData(
            data,
            mode: .append
        )
        let appendPlan = try viewModel.brushPresetLibraryInstallationPlan(
            appendInspection,
            selectedIndexes: IndexSet([0, 1, 2])
        )
        let firstCopy = "Shared Brush"
            + L10n.text("imageEditor.brushPreset.copySuffix")
        let secondCopy = "Shared Brush"
            + L10n.format("imageEditor.brushPreset.copySuffixIndexed", 2)
        #expect(appendPlan.map(\.sourceIndex) == [0, 1, 2])
        #expect(appendPlan.map(\.sourceTitle) == sourcePresets.map(\.title))
        #expect(appendPlan.map(\.installedTitle) == [firstCopy, secondCopy, "Unique Brush"])
        #expect(appendPlan.map(\.isRenamed) == [true, true, false])
        #expect(throws: ImageEditorBrushPresetLibraryError.invalidPresetSelection) {
            try viewModel.brushPresetLibraryInstallationPlan(
                appendInspection,
                selectedIndexes: IndexSet(integer: 3)
            )
        }
        let zeroCapacityInspection = ImageEditorBrushPresetLibraryInspection(
            mode: .append,
            presetCount: sourcePresets.count,
            installableCount: 0,
            skippedCount: sourcePresets.count,
            presetPreviews: sourcePresets.enumerated().map { index, preset in
                ImageEditorBrushPresetLibraryPreview(
                    sourceIndex: index,
                    preset: preset
                )
            },
            reservedTitles: ["Shared Brush"]
        )
        #expect(
            try viewModel.brushPresetLibraryInstallationPlan(zeroCapacityInspection).isEmpty
        )

        let replaceInspection = try viewModel.inspectBrushPresetLibraryData(
            data,
            mode: .replace
        )
        let replacePlan = try viewModel.brushPresetLibraryInstallationPlan(
            replaceInspection,
            selectedIndexes: IndexSet([0, 1, 2])
        )
        #expect(
            replacePlan.map(\.installedTitle)
                == ["Shared Brush", firstCopy, "Unique Brush"]
        )

        let result = try viewModel.importBrushPresetLibraryData(
            data,
            selectedIndexes: IndexSet([0, 1, 2])
        )
        #expect(result == ImageEditorBrushPresetImportResult(
            importedCount: 3,
            unselectedCount: 0,
            capacitySkippedCount: 0
        ))
        #expect(
            Array(viewModel.customBrushPresets.dropFirst()).map(\.title)
                == appendPlan.map(\.installedTitle)
        )
    }

    @Test func inspectingBrushLibraryReportsReplacementCapacityWithoutMutation() throws {
        let incoming = (0..<(ImageEditorBrushPresetPreferences.maximumPresetCount + 2)).map {
            ImageEditorBrushPreset(
                id: "incoming-\($0)",
                name: "Preview \($0 + 1)",
                size: CGFloat(12 + $0)
            )
        }
        let data = try JSONEncoder().encode(
            ImageEditorBrushPresetLibrary(presets: incoming)
        )
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        let builtIn = try #require(ImageEditorBrushPreset.defaultPresets.first)
        viewModel.applyBrushPreset(builtIn)
        #expect(viewModel.setBrushPresetFavorite(id: builtIn.id, isFavorite: true))
        viewModel.brushSize = 31
        let local = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.applyBrushPreset(local)
        viewModel.brushSize = 87
        viewModel.setBrushAngleJitter(41)
        viewModel.addLayer()
        viewModel.undo()
        let presetsBeforeInspection = viewModel.customBrushPresets
        let selectedBeforeInspection = viewModel.selectedBrushPresetID
        let favoritesBeforeInspection = viewModel.favoriteBrushPresetIDs
        let recentBeforeInspection = viewModel.recentBrushPresetIDs
        let statusBeforeInspection = viewModel.statusText
        let documentBeforeInspection = transactionSignature(viewModel.document)
        let undoBeforeInspection = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeInspection = viewModel.redoStack.map { transactionSignature($0) }

        let inspection = try viewModel.inspectBrushPresetLibraryData(data)
        let appendInspection = try viewModel.inspectBrushPresetLibraryData(
            data,
            mode: .append
        )

        #expect(inspection.mode == .replace)
        #expect(inspection.presetCount == incoming.count)
        #expect(
            inspection.installableCount
                == ImageEditorBrushPresetPreferences.maximumPresetCount
        )
        #expect(inspection.skippedCount == 2)
        #expect(inspection.presetTitles == incoming.map(\.title))
        #expect(inspection.presetPreviews.first?.sourceIndex == 0)
        #expect(inspection.presetPreviews.first?.size == 12)
        #expect(inspection.presetPreviews.first?.primarySummary == L10n.format(
            "imageEditor.brushPreset.summaryPrimary",
            12,
            80,
            100,
            25
        ))
        #expect(appendInspection.mode == .append)
        #expect(appendInspection.presetCount == incoming.count)
        #expect(appendInspection.installableCount == 99)
        #expect(appendInspection.skippedCount == 3)
        #expect(appendInspection.presetTitles == incoming.map(\.title))
        #expect(throws: ImageEditorBrushPresetLibraryError.invalidFile) {
            try viewModel.inspectBrushPresetLibraryData(Data("not-json".utf8))
        }
        #expect(throws: ImageEditorBrushPresetLibraryError.fileTooLarge) {
            try viewModel.inspectBrushPresetLibraryData(
                Data(count: ImageEditorBrushPresetLibrary.maximumFileSize + 1)
            )
        }
        #expect(throws: ImageEditorBrushPresetLibraryError.unsupportedFormatVersion) {
            try viewModel.inspectBrushPresetLibraryData(JSONEncoder().encode(
                ImageEditorBrushPresetLibrary(
                    formatVersion: ImageEditorBrushPresetLibrary.currentFormatVersion + 1,
                    presets: [incoming[0]]
                )
            ))
        }
        #expect(throws: ImageEditorBrushPresetLibraryError.emptyLibrary) {
            try viewModel.inspectBrushPresetLibraryData(JSONEncoder().encode(
                ImageEditorBrushPresetLibrary(presets: [])
            ))
        }
        #expect(viewModel.customBrushPresets == presetsBeforeInspection)
        #expect(viewModel.selectedBrushPresetID == selectedBeforeInspection)
        #expect(viewModel.favoriteBrushPresetIDs == favoritesBeforeInspection)
        #expect(viewModel.recentBrushPresetIDs == recentBeforeInspection)
        #expect(viewModel.statusText == statusBeforeInspection)
        #expect(viewModel.brushSize == 87)
        #expect(viewModel.brushAngleJitter == 41)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(transactionSignature(viewModel.document) == documentBeforeInspection)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeInspection)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeInspection)
    }

    @Test func confirmedBrushLibraryImportCommitsPreflightDataAndCancelStaysAtomic() throws {
        let sourcePresets = [
            ImageEditorBrushPreset(id: "source-one", name: "Source One", size: 24),
            ImageEditorBrushPreset(id: "source-two", name: "Source Two", size: 48)
        ]
        let sourceData = try JSONEncoder().encode(
            ImageEditorBrushPresetLibrary(presets: sourcePresets)
        )
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("brush-import-preflight-\(UUID().uuidString).xomobrushes")
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        try sourceData.write(to: sourceURL, options: .atomic)

        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.brushSize = 83
        viewModel.setBrushAngleJitter(37)
        viewModel.addLayer()
        viewModel.undo()
        let documentBeforeImport = transactionSignature(viewModel.document)
        let undoBeforeImport = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeImport = viewModel.redoStack.map { transactionSignature($0) }
        var confirmedInspection: ImageEditorBrushPresetLibraryInspection?

        let didImport = viewModel.importBrushPresetLibraryWithConfirmation(
            from: sourceURL
        ) { url, inspection in
            confirmedInspection = inspection
            try? Data("replaced-after-preflight".utf8).write(to: url, options: .atomic)
            return IndexSet(integer: 1)
        }

        #expect(didImport)
        #expect(
            try Data(contentsOf: sourceURL)
                == Data("replaced-after-preflight".utf8)
        )
        #expect(confirmedInspection?.mode == .append)
        #expect(confirmedInspection?.presetCount == 2)
        #expect(confirmedInspection?.installableCount == 2)
        #expect(confirmedInspection?.skippedCount == 0)
        #expect(confirmedInspection?.presetTitles == ["Source One", "Source Two"])
        #expect(viewModel.customBrushPresets.map(\.title) == ["Source Two"])
        #expect(Set(viewModel.customBrushPresets.map(\.id)).isDisjoint(with: sourcePresets.map(\.id)))
        #expect(viewModel.brushSize == 83)
        #expect(viewModel.brushAngleJitter == 37)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(transactionSignature(viewModel.document) == documentBeforeImport)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeImport)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeImport)

        try sourceData.write(to: sourceURL, options: .atomic)
        let presetsBeforeCancel = viewModel.customBrushPresets
        let selectedBeforeCancel = viewModel.selectedBrushPresetID
        var cancelledInspection: ImageEditorBrushPresetLibraryInspection?
        let cancelledImport = viewModel.importBrushPresetLibraryWithConfirmation(
            from: sourceURL,
            selectPresets: { _, inspection in
                cancelledInspection = inspection
                return nil
            }
        )
        #expect(!cancelledImport)
        #expect(cancelledInspection?.installableCount == 2)
        #expect(viewModel.customBrushPresets == presetsBeforeCancel)
        #expect(viewModel.selectedBrushPresetID == selectedBeforeCancel)

        try Data("not-json".utf8).write(to: sourceURL, options: .atomic)
        var invalidConfirmationCount = 0
        #expect(!viewModel.importBrushPresetLibraryWithConfirmation(
            from: sourceURL,
            selectPresets: { _, _ in
                invalidConfirmationCount += 1
                return IndexSet(integer: 0)
            }
        ))
        #expect(invalidConfirmationCount == 0)
        #expect(viewModel.customBrushPresets == presetsBeforeCancel)
        #expect(viewModel.selectedBrushPresetID == selectedBeforeCancel)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.brushPresetFileInvalid"))
        #expect(transactionSignature(viewModel.document) == documentBeforeImport)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeImport)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeImport)
    }

    @Test func confirmedBrushLibraryReplacementSelectsFromPreflightDataAtomically() throws {
        let sourcePresets = [
            ImageEditorBrushPreset(id: "source-one", name: "Source One", size: 24),
            ImageEditorBrushPreset(id: "source-two", name: "Source Two", size: 48),
            ImageEditorBrushPreset(id: "source-three", name: "Source Three", size: 72)
        ]
        let sourceData = try JSONEncoder().encode(
            ImageEditorBrushPresetLibrary(presets: sourcePresets)
        )
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("brush-replace-selection-\(UUID().uuidString).xomobrushes")
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        try sourceData.write(to: sourceURL, options: .atomic)

        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.brushSize = 19
        let localPreset = try #require(viewModel.createBrushPresetFromCurrentSettings())
        viewModel.brushSize = 87
        viewModel.setBrushAngleJitter(39)
        viewModel.addLayer()
        viewModel.undo()
        let documentBeforeReplace = transactionSignature(viewModel.document)
        let undoBeforeReplace = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeReplace = viewModel.redoStack.map { transactionSignature($0) }
        var confirmedInspection: ImageEditorBrushPresetLibraryInspection?

        let didReplace = viewModel.replaceBrushPresetLibraryWithConfirmation(
            from: sourceURL
        ) { url, inspection in
            confirmedInspection = inspection
            try? Data("replaced-after-preflight".utf8).write(to: url, options: .atomic)
            return IndexSet([0, 2])
        }

        #expect(didReplace)
        #expect(confirmedInspection?.mode == .replace)
        #expect(confirmedInspection?.presetCount == 3)
        #expect(confirmedInspection?.installableCount == 3)
        #expect(confirmedInspection?.skippedCount == 0)
        #expect(confirmedInspection?.presetTitles == ["Source One", "Source Two", "Source Three"])
        #expect(viewModel.customBrushPresets.map(\.title) == ["Source One", "Source Three"])
        #expect(viewModel.statusText == L10n.format(
            "imageEditor.status.brushPresetLibraryReplacedSelection",
            2,
            1,
            0
        ))
        #expect(!viewModel.customBrushPresets.contains(where: { $0.id == localPreset.id }))
        #expect(Set(viewModel.customBrushPresets.map(\.id)).isDisjoint(with: sourcePresets.map(\.id)))
        #expect(viewModel.brushSize == 87)
        #expect(viewModel.brushAngleJitter == 39)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(transactionSignature(viewModel.document) == documentBeforeReplace)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeReplace)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeReplace)

        try sourceData.write(to: sourceURL, options: .atomic)
        let presetsBeforeCancel = viewModel.customBrushPresets
        let selectedBeforeCancel = viewModel.selectedBrushPresetID
        #expect(!viewModel.replaceBrushPresetLibraryWithConfirmation(
            from: sourceURL,
            selectPresets: { _, _ in [] }
        ))
        #expect(viewModel.customBrushPresets == presetsBeforeCancel)
        #expect(viewModel.selectedBrushPresetID == selectedBeforeCancel)

        try Data("not-json".utf8).write(to: sourceURL, options: .atomic)
        var invalidSelectionCount = 0
        #expect(!viewModel.replaceBrushPresetLibraryWithConfirmation(
            from: sourceURL,
            selectPresets: { _, _ in
                invalidSelectionCount += 1
                return IndexSet(integer: 0)
            }
        ))
        #expect(invalidSelectionCount == 0)
        #expect(viewModel.customBrushPresets == presetsBeforeCancel)
        #expect(viewModel.selectedBrushPresetID == selectedBeforeCancel)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.brushPresetFileInvalid"))
        #expect(transactionSignature(viewModel.document) == documentBeforeReplace)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeReplace)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeReplace)
    }

    @Test func resettingBrushLibraryPreservesEditingStateAndBuiltInUsage() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        let builtIn = try #require(ImageEditorBrushPreset.defaultPresets.first)
        viewModel.applyBrushPreset(builtIn)
        #expect(viewModel.setBrushPresetFavorite(id: builtIn.id, isFavorite: true))

        viewModel.brushSize = 29
        let first = try #require(viewModel.createBrushPresetFromCurrentSettings())
        #expect(viewModel.setBrushPresetFavorite(id: first.id, isFavorite: true))
        viewModel.applyBrushPreset(first)
        viewModel.brushSize = 53
        let second = try #require(viewModel.createBrushPresetFromCurrentSettings())
        #expect(viewModel.setBrushPresetFavorite(id: second.id, isFavorite: true))
        viewModel.applyBrushPreset(second)
        viewModel.brushSize = 91
        viewModel.setBrushAngleJitter(47)
        viewModel.addLayer()
        viewModel.undo()
        let documentBeforeReset = transactionSignature(viewModel.document)
        let undoBeforeReset = viewModel.undoStack.map { transactionSignature($0) }
        let redoBeforeReset = viewModel.redoStack.map { transactionSignature($0) }

        #expect(viewModel.canResetCustomBrushPresetLibrary)
        #expect(viewModel.resetCustomBrushPresetLibrary() == 2)
        #expect(viewModel.customBrushPresets.isEmpty)
        #expect(viewModel.selectedBrushPresetID == nil)
        #expect(viewModel.favoriteBrushPresetIDs == [builtIn.id])
        #expect(viewModel.recentBrushPresetIDs == [builtIn.id])
        #expect(viewModel.brushSize == 91)
        #expect(viewModel.brushAngleJitter == 47)
        #expect(viewModel.activeBrushPreset == nil)
        #expect(transactionSignature(viewModel.document) == documentBeforeReset)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeReset)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeReset)
        #expect(!viewModel.canResetCustomBrushPresetLibrary)

        let presetsAfterReset = viewModel.customBrushPresets
        let favoritesAfterReset = viewModel.favoriteBrushPresetIDs
        let recentAfterReset = viewModel.recentBrushPresetIDs
        #expect(viewModel.resetCustomBrushPresetLibrary() == 0)
        #expect(viewModel.customBrushPresets == presetsAfterReset)
        #expect(viewModel.favoriteBrushPresetIDs == favoritesAfterReset)
        #expect(viewModel.recentBrushPresetIDs == recentAfterReset)
        #expect(transactionSignature(viewModel.document) == documentBeforeReset)
        #expect(viewModel.undoStack.map { transactionSignature($0) } == undoBeforeReset)
        #expect(viewModel.redoStack.map { transactionSignature($0) } == redoBeforeReset)

        let restored = makeViewModel(defaults: defaults)
        #expect(restored.customBrushPresets.isEmpty)
        #expect(restored.selectedBrushPresetID == nil)
        #expect(restored.favoriteBrushPresetIDs == [builtIn.id])
        #expect(restored.recentBrushPresetIDs == [builtIn.id])
    }

    @Test func resettingBrushLibraryKeepsAnAppliedBuiltInSelected() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.brushSize = 37
        _ = try #require(viewModel.createBrushPresetFromCurrentSettings())
        let builtIn = try #require(ImageEditorBrushPreset.defaultPresets.last)
        viewModel.applyBrushPreset(builtIn)

        #expect(viewModel.resetCustomBrushPresetLibrary() == 1)
        #expect(viewModel.customBrushPresets.isEmpty)
        #expect(viewModel.selectedBrushPresetID == builtIn.id)
        #expect(viewModel.activeBrushPreset?.id == builtIn.id)
        let restored = makeViewModel(defaults: defaults)
        #expect(restored.selectedBrushPresetID == nil)
        #expect(restored.activeBrushPreset?.id == builtIn.id)
    }

    @Test func portableBrushLibraryRoundTripsCompleteResourcesWithFreshIdentityAndStableNames() throws {
        let (sourceDefaults, sourceSuiteName) = temporaryDefaults()
        defer { sourceDefaults.removePersistentDomain(forName: sourceSuiteName) }
        let source = makeViewModel(defaults: sourceDefaults)
        source.brushSize = 37
        source.hardness = 0.42
        source.brushFlow = 63
        source.brushSpacing = 71
        source.setBrushScatter(420)
        source.setBrushNoiseEnabled(true)
        let sourcePreset = try #require(source.createBrushPresetFromCurrentSettings())
        #expect(source.renameSelectedCustomBrushPreset(to: "Shared Brush"))
        let exportedPreset = try #require(source.selectedCustomBrushPreset)
        let secondPreset = try #require(source.duplicateSelectedCustomBrushPreset())

        let allData = try source.brushPresetLibraryData()
        let allLibrary = try JSONDecoder().decode(ImageEditorBrushPresetLibrary.self, from: allData)
        #expect(allLibrary.presets == [exportedPreset, secondPreset])

        let data = try source.brushPresetLibraryData(presetIDs: [sourcePreset.id])
        let library = try JSONDecoder().decode(ImageEditorBrushPresetLibrary.self, from: data)
        #expect(library.formatVersion == ImageEditorBrushPresetLibrary.currentFormatVersion)
        #expect(library.presets == [exportedPreset])

        let (targetDefaults, targetSuiteName) = temporaryDefaults()
        defer { targetDefaults.removePersistentDomain(forName: targetSuiteName) }
        let target = makeViewModel(defaults: targetDefaults)
        let local = try #require(target.createBrushPresetFromCurrentSettings())
        #expect(target.renameSelectedCustomBrushPreset(to: "Shared Brush"))
        target.brushSize = 91
        target.addLayer()
        target.undo()
        let documentBeforeImport = transactionSignature(target.document)
        let undoBeforeImport = target.undoStack.map { transactionSignature($0) }
        let redoBeforeImport = target.redoStack.map { transactionSignature($0) }

        let result = try target.importBrushPresetLibraryData(data)

        #expect(result == ImageEditorBrushPresetImportResult(
            importedCount: 1,
            unselectedCount: 0,
            capacitySkippedCount: 0
        ))
        let imported = try #require(target.customBrushPresets.last)
        #expect(imported.id != exportedPreset.id)
        #expect(imported.id != local.id)
        #expect(imported.name == "Shared Brush" + L10n.text("imageEditor.brushPreset.copySuffix"))
        #expect(imported == exportedPreset.copyingCustomPreset(id: imported.id, name: imported.title))
        #expect(target.selectedBrushPresetID == imported.id)
        #expect(target.brushSize == 91)
        #expect(target.activeBrushPreset == nil)
        #expect(transactionSignature(target.document) == documentBeforeImport)
        #expect(target.undoStack.map { transactionSignature($0) } == undoBeforeImport)
        #expect(target.redoStack.map { transactionSignature($0) } == redoBeforeImport)

        let secondResult = try target.importBrushPresetLibraryData(data)
        #expect(secondResult.importedCount == 1)
        #expect(
            target.customBrushPresets.last?.name
                == "Shared Brush" + L10n.format("imageEditor.brushPreset.copySuffixIndexed", 2)
        )
        let restored = makeViewModel(defaults: targetDefaults)
        #expect(restored.customBrushPresets == target.customBrushPresets)
        #expect(restored.selectedBrushPresetID == target.customBrushPresets.last?.id)
    }

    @Test func droppedBrushLibraryImportsThroughTheSameAtomicArchiveBoundary() throws {
        let fileManager = FileManager.default
        let validURL = fileManager.temporaryDirectory
            .appendingPathComponent("dropped-\(UUID().uuidString).xomobrushes")
        let invalidExtensionURL = fileManager.temporaryDirectory
            .appendingPathComponent("dropped-\(UUID().uuidString).json")
        let corruptURL = fileManager.temporaryDirectory
            .appendingPathComponent("dropped-\(UUID().uuidString).xomobrushes")
        defer {
            try? fileManager.removeItem(at: validURL)
            try? fileManager.removeItem(at: invalidExtensionURL)
            try? fileManager.removeItem(at: corruptURL)
        }

        let (sourceDefaults, sourceSuiteName) = temporaryDefaults()
        defer { sourceDefaults.removePersistentDomain(forName: sourceSuiteName) }
        let source = makeViewModel(defaults: sourceDefaults)
        let sourcePreset = try #require(source.createBrushPresetFromCurrentSettings())
        try source.brushPresetLibraryData().write(to: validURL, options: .atomic)
        try source.brushPresetLibraryData().write(to: invalidExtensionURL, options: .atomic)
        try Data("not-json".utf8).write(to: corruptURL, options: .atomic)

        let (targetDefaults, targetSuiteName) = temporaryDefaults()
        defer { targetDefaults.removePersistentDomain(forName: targetSuiteName) }
        let target = makeViewModel(defaults: targetDefaults)
        target.addLayer()
        target.undo()
        let documentBeforeImport = transactionSignature(target.document)
        let undoBeforeImport = target.undoStack.map { transactionSignature($0) }
        let redoBeforeImport = target.redoStack.map { transactionSignature($0) }

        var droppedURL: URL?
        var droppedInspection: ImageEditorBrushPresetLibraryInspection?
        let didImportDrop = target.importDroppedBrushPresetLibrary(
            from: [validURL],
            selectPresets: { url, inspection in
                droppedURL = url
                droppedInspection = inspection
                return ImageEditorBrushPresetImportSelectionPolicy.defaultSelection(
                    presetCount: inspection.presetCount,
                    capacity: inspection.installableCount
                )
            }
        )
        #expect(didImportDrop)
        #expect(droppedURL == validURL)
        #expect(droppedInspection?.mode == .append)
        #expect(droppedInspection?.installableCount == 1)
        let imported = try #require(target.customBrushPresets.last)
        #expect(imported.id != sourcePreset.id)
        #expect(imported.title == sourcePreset.title)
        #expect(target.selectedBrushPresetID == imported.id)
        #expect(transactionSignature(target.document) == documentBeforeImport)
        #expect(target.undoStack.map { transactionSignature($0) } == undoBeforeImport)
        #expect(target.redoStack.map { transactionSignature($0) } == redoBeforeImport)

        let presetsAfterImport = target.customBrushPresets
        #expect(!target.importDroppedBrushPresetLibrary(
            from: [invalidExtensionURL],
            selectPresets: { _, _ in IndexSet(integer: 0) }
        ))
        #expect(target.customBrushPresets == presetsAfterImport)
        #expect(!target.importDroppedBrushPresetLibrary(
            from: [corruptURL],
            selectPresets: { _, _ in IndexSet(integer: 0) }
        ))
        #expect(target.customBrushPresets == presetsAfterImport)
        #expect(target.statusText == L10n.text("imageEditor.status.brushPresetFileInvalid"))
    }

    @Test func brushLibraryImportFillsCapacityAndRejectsInvalidArchivesAtomically() throws {
        let (defaults, suiteName) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(defaults: defaults)
        #expect(throws: ImageEditorBrushPresetLibraryError.noMatchingPresets) {
            try viewModel.brushPresetLibraryData()
        }
        let seed = try #require(viewModel.createBrushPresetFromCurrentSettings())
        let localPresets = (0..<99).map { index in
            seed.copyingCustomPreset(id: "local-\(index)", name: "Local \(index)")
        }
        let capacityDefaults = ImageEditorBrushPresetPreferences(
            presets: localPresets,
            selectedPresetID: localPresets.last?.id
        )
        capacityDefaults.save(to: defaults)
        let capacityViewModel = makeViewModel(defaults: defaults)
        let incoming = (0..<3).map { index in
            seed.copyingCustomPreset(id: "incoming-\(index)", name: "Incoming \(index)")
        }
        let result = try capacityViewModel.importBrushPresetLibraryData(
            JSONEncoder().encode(ImageEditorBrushPresetLibrary(presets: incoming)),
            selectedIndexes: IndexSet([0, 1])
        )
        #expect(result == ImageEditorBrushPresetImportResult(
            importedCount: 1,
            unselectedCount: 1,
            capacitySkippedCount: 1
        ))
        #expect(result.skippedCount == 2)
        #expect(capacityViewModel.customBrushPresets.count == 100)
        #expect(capacityViewModel.customBrushPresets.last?.name == "Incoming 0")
        #expect(capacityViewModel.statusText == L10n.format(
            "imageEditor.status.brushPresetImportedSelection",
            1,
            1,
            1
        ))

        let presetsAtCapacity = capacityViewModel.customBrushPresets
        let selectedAtCapacity = capacityViewModel.selectedBrushPresetID
        let unsupported = ImageEditorBrushPresetLibrary(
            formatVersion: ImageEditorBrushPresetLibrary.currentFormatVersion + 1,
            presets: incoming
        )
        #expect(throws: ImageEditorBrushPresetLibraryError.unsupportedFormatVersion) {
            try capacityViewModel.importBrushPresetLibraryData(JSONEncoder().encode(unsupported))
        }
        #expect(throws: ImageEditorBrushPresetLibraryError.invalidFile) {
            try capacityViewModel.importBrushPresetLibraryData(Data("not-json".utf8))
        }
        #expect(throws: ImageEditorBrushPresetLibraryError.invalidPresetSelection) {
            try capacityViewModel.importBrushPresetLibraryData(
                JSONEncoder().encode(ImageEditorBrushPresetLibrary(presets: incoming)),
                selectedIndexes: IndexSet(integer: 4)
            )
        }
        #expect(throws: ImageEditorBrushPresetLibraryError.invalidPresetSelection) {
            try capacityViewModel.importBrushPresetLibraryData(
                JSONEncoder().encode(ImageEditorBrushPresetLibrary(presets: incoming)),
                selectedIndexes: []
            )
        }
        #expect(throws: ImageEditorBrushPresetLibraryError.fileTooLarge) {
            try capacityViewModel.importBrushPresetLibraryData(
                Data(count: ImageEditorBrushPresetLibrary.maximumFileSize + 1)
            )
        }
        #expect(capacityViewModel.customBrushPresets == presetsAtCapacity)
        #expect(capacityViewModel.selectedBrushPresetID == selectedAtCapacity)
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
        viewModel.setBrushPressureControlsOpacity(true)
        viewModel.setBrushPressureControlsFlow(false)
        viewModel.setBrushPressureSensitivity(0)
        viewModel.setBrushSizeJitter(75)
        viewModel.setBrushAngleJitter(75)
        viewModel.setBrushRoundnessJitter(75)
        viewModel.setBrushOpacityJitter(75)
        viewModel.setBrushFlowJitter(75)
        viewModel.setBrushMinimumRoundness(75)
        viewModel.setBrushScatter(500)
        viewModel.setBrushScatterBothAxes(true)
        viewModel.setBrushScatterCount(16)
        viewModel.setBrushScatterCountJitter(75)
        viewModel.setBrushNoiseEnabled(true)
        viewModel.setBrushWetEdgesEnabled(true)
        viewModel.setBrushMinimumDiameter(75)
        viewModel.setBrushMinimumOpacity(75)
        viewModel.setBrushMinimumFlow(75)
        viewModel.setBrushTiltControlsShape(true)
        viewModel.setBrushTipRoundness(25)
        viewModel.setBrushTipAngleDegrees(90)
        viewModel.setBrushSmoothing(75)

        viewModel.applyBrushPreset(builtIn)
        viewModel.deleteBrushPreset(builtIn)

        #expect(viewModel.brushSize == builtIn.size)
        #expect(viewModel.hardness == builtIn.hardness)
        #expect(viewModel.brushFlow == builtIn.flow)
        #expect(viewModel.brushSpacing == builtIn.spacing)
        #expect(viewModel.brushPressureControlsSize)
        #expect(!viewModel.brushPressureControlsOpacity)
        #expect(viewModel.brushPressureControlsFlow)
        #expect(viewModel.brushPressureSensitivity == 50)
        #expect(viewModel.brushSizeJitter == 0)
        #expect(viewModel.brushAngleJitter == 0)
        #expect(viewModel.brushRoundnessJitter == 0)
        #expect(viewModel.brushOpacityJitter == 0)
        #expect(viewModel.brushFlowJitter == 0)
        #expect(viewModel.brushMinimumRoundness == 1)
        #expect(viewModel.brushScatter == 0)
        #expect(!viewModel.brushScatterBothAxes)
        #expect(viewModel.brushScatterCount == 1)
        #expect(viewModel.brushScatterCountJitter == 0)
        #expect(!viewModel.brushNoiseEnabled)
        #expect(!viewModel.brushWetEdgesEnabled)
        #expect(viewModel.brushMinimumDiameter == 0)
        #expect(viewModel.brushMinimumOpacity == 0)
        #expect(viewModel.brushMinimumFlow == 0)
        #expect(!viewModel.brushTiltControlsShape)
        #expect(viewModel.brushTipRoundness == 100)
        #expect(viewModel.brushTipAngleDegrees == 0)
        #expect(viewModel.brushSmoothing == 0)
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

    private func transactionSignature(_ document: ImageEditorDocument) -> DocumentTransactionSignature {
        DocumentTransactionSignature(
            canvasSize: document.canvasSize,
            layerIDs: document.layers.map(\.id),
            layerFrames: document.layers.map(\.frame),
            layerImageData: document.layers.map { $0.image.tiffRepresentation },
            layerMaskData: document.layers.map { $0.mask?.tiffRepresentation },
            selectedLayerID: document.selectedLayerID,
            selectedLayerIDs: document.selectedLayerIDs,
            historyIDs: document.history.map(\.id),
            historyTitles: document.history.map(\.title),
            historyDates: document.history.map(\.createdAt)
        )
    }

    private struct DocumentTransactionSignature: Equatable {
        let canvasSize: CGSize
        let layerIDs: [UUID]
        let layerFrames: [CGRect]
        let layerImageData: [Data?]
        let layerMaskData: [Data?]
        let selectedLayerID: UUID?
        let selectedLayerIDs: Set<UUID>
        let historyIDs: [UUID]
        let historyTitles: [String]
        let historyDates: [Date]
    }
}
