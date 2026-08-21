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
        restored.brushFlow = 67
        restored.deleteBrushPreset(restoredPreset)
        #expect(restored.customBrushPresets.isEmpty)
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
