//
//  ImageEditorLayerRowBatchPropertyTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerRowBatchPropertyTests {
    @Test func selectedRowVisibilityUnifiesMixedSelectionAndUndoRestoresEveryLayer() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let thirdID = fixture.layers[2].id
        viewModel.document.layers[1].isVisible = false
        select([firstID, secondID], primary: firstID, in: viewModel)

        viewModel.toggleLayerVisibility(firstID, applyingToSelection: true)

        #expect(!(try layer(firstID, in: viewModel)).isVisible)
        #expect(!(try layer(secondID, in: viewModel)).isVisible)
        #expect(try layer(thirdID, in: viewModel).isVisible)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerHideSelected"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerHideSelected", 2))

        viewModel.undo()
        #expect(try layer(firstID, in: viewModel).isVisible)
        #expect(!(try layer(secondID, in: viewModel)).isVisible)

        viewModel.toggleLayerVisibility(secondID, applyingToSelection: true)
        #expect(try layer(firstID, in: viewModel).isVisible)
        #expect(try layer(secondID, in: viewModel).isVisible)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerShowSelected"))
    }

    @Test func selectedRowFullLockUnifiesMixedSelectionWithoutClearingFineLocks() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        viewModel.document.layers[1].isLocked = true
        viewModel.document.layers[1].locksPixels = true
        select([firstID, secondID], primary: firstID, in: viewModel)

        viewModel.toggleLayerLock(firstID, applyingToSelection: true)

        #expect(try layer(firstID, in: viewModel).isLocked)
        #expect(try layer(secondID, in: viewModel).isLocked)
        #expect(try layer(secondID, in: viewModel).locksPixels)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerLockSelected"))

        viewModel.undo()
        #expect(!(try layer(firstID, in: viewModel)).isLocked)
        #expect(try layer(secondID, in: viewModel).isLocked)
        #expect(try layer(secondID, in: viewModel).locksPixels)

        viewModel.toggleLayerLock(secondID, applyingToSelection: true)
        #expect(!(try layer(firstID, in: viewModel)).isLocked)
        #expect(!(try layer(secondID, in: viewModel)).isLocked)
        #expect(try layer(secondID, in: viewModel).locksPixels)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerUnlockSelected"))
    }

    @Test func selectedRowFineLocksApplyOnceToAllEligibleSelectedLayers() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        select([firstID, secondID], primary: firstID, in: viewModel)

        viewModel.toggleLayerPixelsLock(firstID, applyingToSelection: true)
        #expect(try layer(firstID, in: viewModel).locksPixels)
        #expect(try layer(secondID, in: viewModel).locksPixels)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerPixelsLockSelected"))

        viewModel.toggleLayerPositionLock(firstID, applyingToSelection: true)
        #expect(try layer(firstID, in: viewModel).locksPosition)
        #expect(try layer(secondID, in: viewModel).locksPosition)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerPositionLockSelected"))

        viewModel.toggleLayerTransparentPixelsLock(firstID, applyingToSelection: true)
        #expect(try layer(firstID, in: viewModel).locksTransparentPixels)
        #expect(try layer(secondID, in: viewModel).locksTransparentPixels)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTransparentPixelsLockSelected"))

        viewModel.undo()
        #expect(!(try layer(firstID, in: viewModel)).locksTransparentPixels)
        #expect(!(try layer(secondID, in: viewModel)).locksTransparentPixels)
        #expect(try layer(firstID, in: viewModel).locksPosition)
    }

    @Test func transparentPixelBatchSkipsIneligibleSelectedTextLayer() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let pixelID = fixture.layers[0].id
        let textLayer = ImageEditorLayer.text(
            name: "Title",
            origin: CGPoint(x: 8, y: 8),
            content: ImageEditorTextContent(
                text: "Title",
                color: .white,
                fontSize: 18,
                point: CGPoint(x: 8, y: 8)
            )
        )
        viewModel.document.layers.append(textLayer)
        select([pixelID, textLayer.id], primary: pixelID, in: viewModel)

        viewModel.toggleLayerTransparentPixelsLock(pixelID, applyingToSelection: true)

        #expect(try layer(pixelID, in: viewModel).locksTransparentPixels)
        #expect(!(try layer(textLayer.id, in: viewModel)).locksTransparentPixels)
        #expect(viewModel.document.selectedLayerIDs == [pixelID, textLayer.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTransparentPixelsLockSelected"))
    }

    @Test func clickingUnselectedRowChangesOnlyThatRowAndKeepsSelection() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let thirdID = fixture.layers[2].id
        select([firstID, secondID], primary: secondID, in: viewModel)

        viewModel.toggleLayerVisibility(thirdID, applyingToSelection: true)
        viewModel.toggleLayerLock(thirdID, applyingToSelection: true)

        #expect(try layer(firstID, in: viewModel).isVisible)
        #expect(try layer(secondID, in: viewModel).isVisible)
        #expect(!(try layer(thirdID, in: viewModel)).isVisible)
        #expect(!(try layer(firstID, in: viewModel)).isLocked)
        #expect(!(try layer(secondID, in: viewModel)).isLocked)
        #expect(try layer(thirdID, in: viewModel).isLocked)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerLock"))
    }

    @Test func clippingToolbarMixedSelectionFirstUnifiesOnThenReleasesAllWithUndo() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let baseID = fixture.layers[0].id
        let firstClipID = fixture.layers[1].id
        let secondClipID = fixture.layers[2].id
        viewModel.document.layers[1].isClippingMask = true
        select([firstClipID, secondClipID], primary: secondClipID, in: viewModel)

        #expect(viewModel.selectedLayersClippingMaskState == .mixed)
        #expect(viewModel.canToggleClippingMasksForSelectedLayers)
        viewModel.toggleClippingMasksForSelectedLayers()

        #expect(try layer(firstClipID, in: viewModel).isClippingMask)
        #expect(try layer(secondClipID, in: viewModel).isClippingMask)
        #expect(!(try layer(baseID, in: viewModel)).isClippingMask)
        #expect(viewModel.selectedLayersClippingMaskState == .on)
        #expect(viewModel.document.selectedLayerIDs == [firstClipID, secondClipID])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerClippingMaskCreateSelected"))

        viewModel.undo()
        #expect(viewModel.selectedLayersClippingMaskState == .mixed)
        #expect(try layer(firstClipID, in: viewModel).isClippingMask)
        #expect(!(try layer(secondClipID, in: viewModel)).isClippingMask)

        viewModel.redo()
        #expect(viewModel.selectedLayersClippingMaskState == .on)
        viewModel.toggleClippingMasksForSelectedLayers()

        #expect(!(try layer(firstClipID, in: viewModel)).isClippingMask)
        #expect(!(try layer(secondClipID, in: viewModel)).isClippingMask)
        #expect(viewModel.selectedLayersClippingMaskState == .off)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerClippingMaskReleaseSelected"))

        viewModel.undo()
        #expect(viewModel.selectedLayersClippingMaskState == .on)
    }

    @Test func clippingToolbarUsesBatchActionAndExposesMixedState() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )

        #expect(source.contains("viewModel.toggleClippingMasksForSelectedLayers()"))
        #expect(source.contains("viewModel.canToggleClippingMasksForSelectedLayers"))
        #expect(source.contains("state == .mixed"))
        #expect(source.contains("minus.circle.fill"))
        #expect(source.contains("state.accessibilityKey"))
        #expect(source.contains("image-editor-layer-clipping-mask-batch"))
    }

    @Test func layerStyleToolbarMixedSelectionUnifiesEveryEffectAndUndoRestoresIt() throws {
        for effect in ImageEditorLayerStyleEffect.allCases {
            let fixture = makeFixture()
            let viewModel = fixture.viewModel
            let firstID = fixture.layers[0].id
            let secondID = fixture.layers[1].id
            select([firstID], primary: firstID, in: viewModel)
            toggle(effect, in: viewModel)
            select([firstID, secondID], primary: secondID, in: viewModel)

            #expect(viewModel.selectedLayerStyleEffectState(effect) == .mixed)
            let historyCount = viewModel.document.history.count
            toggle(effect, in: viewModel)

            #expect(viewModel.selectedLayerStyleEffectState(effect) == .on)
            #expect(effect.isEnabled(in: try layer(firstID, in: viewModel).style))
            #expect(effect.isEnabled(in: try layer(secondID, in: viewModel).style))
            #expect(viewModel.document.selectedLayerIDs == [firstID, secondID])
            #expect(viewModel.document.history.count == historyCount + 1)
            #expect(viewModel.document.history.last?.title == L10n.text(effect.historyKey))

            viewModel.undo()
            #expect(viewModel.selectedLayerStyleEffectState(effect) == .mixed)
            #expect(effect.isEnabled(in: try layer(firstID, in: viewModel).style))
            #expect(!effect.isEnabled(in: try layer(secondID, in: viewModel).style))

            viewModel.redo()
            #expect(viewModel.selectedLayerStyleEffectState(effect) == .on)
            toggle(effect, in: viewModel)
            #expect(viewModel.selectedLayerStyleEffectState(effect) == .off)
            #expect(!effect.isEnabled(in: try layer(firstID, in: viewModel).style))
            #expect(!effect.isEnabled(in: try layer(secondID, in: viewModel).style))
        }
    }

    @Test func layerStyleToolbarUsesTriStateBatchButtonsWithoutKeyboardFocus() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        let start = try #require(source.range(of: "private var layerEffectButtons: some View"))
        let end = try #require(source[start.upperBound...].range(of: "private var layerClippingMaskBatchButton: some View"))
        let effectSource = source[start.lowerBound..<end.lowerBound]

        #expect(ImageEditorLayerStyleEffect.allCases.count == 10)
        #expect(effectSource.components(separatedBy: "layerStyleEffectButton(.").count - 1 == 10)
        #expect(effectSource.contains("viewModel.selectedLayerStyleEffectState(effect)"))
        #expect(effectSource.contains("state == .mixed"))
        #expect(effectSource.contains("minus.circle.fill"))
        #expect(effectSource.contains(".focusable(false)"))
        #expect(effectSource.contains("state.accessibilityKey"))
        #expect(effectSource.contains("image-editor-layer-style-effect-"))
    }

    @Test func layerStyleAngleBatchUpdatesEveryEditableSelectionWithOneUndoStep() throws {
        try assertLayerStyleAngleBatch(
            angle: 35,
            configure: { first, second in
                first.shadowUsesGlobalLight = true
                second.shadowUsesGlobalLight = false
            },
            apply: { $0.setSelectedLayerShadowAngle($1) },
            enabled: { $0.shadowEnabled },
            resolvedAngle: { style, globalAngle in
                style.resolvedShadowAngle(globalLightAngle: globalAngle)
            }
        )
        try assertLayerStyleAngleBatch(
            angle: -50,
            configure: { first, second in
                first.innerShadowUsesGlobalLight = false
                second.innerShadowUsesGlobalLight = true
            },
            apply: { $0.setSelectedLayerInnerShadowAngle($1) },
            enabled: { $0.innerShadowEnabled },
            resolvedAngle: { style, globalAngle in
                style.resolvedInnerShadowAngle(globalLightAngle: globalAngle)
            }
        )
        try assertLayerStyleAngleBatch(
            angle: 70,
            configure: { first, second in
                first.bevelUsesGlobalLight = true
                second.bevelUsesGlobalLight = false
            },
            apply: { $0.setSelectedLayerBevelAngle($1) },
            enabled: { $0.bevelEnabled },
            resolvedAngle: { style, globalAngle in
                style.resolvedBevelAngle(globalLightAngle: globalAngle)
            }
        )
    }

    @Test func layerStyleGlobalLightMixedStateConvergesAcrossEditableSelection() throws {
        for effect in ImageEditorLayerLightEffect.allCases {
            try assertGlobalLightConvergence(effect)
        }
    }

    @Test func layerStyleGlobalLightControlsExposeFamiliarTriStateCheckboxes() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let start = try #require(source.range(of: "private func layerStyleGlobalLightToggle("))
        let end = try #require(source[start.upperBound...].range(of: "private func guidePath("))
        let controlSource = source[start.lowerBound..<end.lowerBound]

        #expect(source.components(separatedBy: "layerStyleGlobalLightToggle(").count - 1 == 4)
        #expect(controlSource.contains("checkmark.square.fill"))
        #expect(controlSource.contains("minus.square.fill"))
        #expect(controlSource.contains(".focusable(false)"))
        #expect(controlSource.contains("state.accessibilityKey"))
        #expect(source.contains("image-editor-shadow-global-light"))
        #expect(source.contains("image-editor-inner-shadow-global-light"))
        #expect(source.contains("image-editor-bevel-global-light"))
    }

    @Test func layerStyleStrokePositionMixedValueConvergesAcrossEditableSelection() throws {
        try assertStrokePositionConvergence()
    }

    @Test func layerStyleStrokePositionPickerShowsLocalizedMixedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let start = try #require(source.range(of: "private func layerStyleValuePicker<"))
        let end = try #require(source[start.upperBound...].range(of: "private func guidePath("))
        let pickerSource = source[start.lowerBound..<end.lowerBound]

        #expect(pickerSource.contains("imageEditor.properties.multipleValues"))
        #expect(pickerSource.contains(".tag(Optional<Value>.none)"))
        #expect(pickerSource.contains(".focusable(false)"))
        #expect(pickerSource.contains(".accessibilityValue(accessibilityValue)"))
        #expect(source.contains("state: viewModel.selectedLayerStrokePositionState"))
        #expect(source.contains("viewModel.setSelectedLayerStrokePosition(position)"))
        #expect(source.contains("image-editor-layer-style-stroke-position"))
        #expect(!source.contains("selectedLayerStrokePositionBinding"))
    }

    private func assertStrokePositionConvergence() throws {
        let fixture = strokePositionFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerStrokePositionState == .mixed)
        viewModel.setSelectedLayerStrokePosition(.center)
        #expect(viewModel.selectedLayerStrokePositionState == .value(.center))
        #expect((try layer(firstID, in: viewModel)).style.strokePosition == .center)
        #expect((try layer(secondID, in: viewModel)).style.strokePosition == .center)
        #expect((try layer(lockedID, in: viewModel)).style.strokePosition == .outside)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerStrokePositionState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerStrokePositionState == .value(.center))
    }

    private func strokePositionFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.strokePosition = .outside
        viewModel.document.layers[1].style.strokePosition = .inside
        viewModel.document.layers[2].style.strokePosition = .outside
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleStrokeFillTypeMixedValueConvergesAcrossEditableSelection() throws {
        try assertStrokeFillTypeConvergence()
    }

    @Test func layerStyleStrokeFillTypePickerHidesIncorrectMixedBranch() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerStrokeFillTypeState"))
        #expect(source.contains("image-editor-layer-style-stroke-fill-type"))
        #expect(source.contains("viewModel.setSelectedLayerStrokeFillType(fillType)"))
        #expect(source.contains("selectedLayerStrokeFillTypeState.value == .color"))
        #expect(source.contains("selectedLayerStrokeFillTypeState.value == .gradient"))
        #expect(source.contains("selectedLayerStrokeFillTypeState.value == .pattern"))
        #expect(!source.contains("selectedLayerStrokeFillTypeBinding"))
    }

    private func assertStrokeFillTypeConvergence() throws {
        let fixture = strokeFillTypeFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerStrokeFillTypeState == .mixed)
        viewModel.setSelectedLayerStrokeFillType(.pattern)
        #expect(viewModel.selectedLayerStrokeFillTypeState == .value(.pattern))
        #expect((try layer(firstID, in: viewModel)).style.strokeFillType == .pattern)
        #expect((try layer(secondID, in: viewModel)).style.strokeFillType == .pattern)
        #expect((try layer(lockedID, in: viewModel)).style.strokeFillType == .color)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerStrokeFillTypeState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerStrokeFillTypeState == .value(.pattern))
    }

    private func strokeFillTypeFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.strokeFillType = .color
        viewModel.document.layers[1].style.strokeFillType = .gradient
        viewModel.document.layers[2].style.strokeFillType = .color
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleStrokeGradientStyleMixedValueConvergesAcrossEditableSelection() throws {
        try assertStrokeGradientStyleConvergence()
    }

    @Test func layerStyleStrokeGradientStylePickerUsesLocalizedMixedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerStrokeGradientStyleState"))
        #expect(source.contains("image-editor-layer-style-stroke-gradient-style"))
        #expect(source.contains("viewModel.setSelectedLayerStrokeGradientStyle(style)"))
        #expect(!source.contains("selectedLayerStrokeGradientStyleBinding"))
    }

    private func assertStrokeGradientStyleConvergence() throws {
        let fixture = strokeGradientStyleFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerStrokeGradientStyleState == .mixed)
        viewModel.setSelectedLayerStrokeGradientStyle(.diamond)
        #expect(viewModel.selectedLayerStrokeGradientStyleState == .value(.diamond))
        #expect((try layer(firstID, in: viewModel)).style.strokeGradientStyle == .diamond)
        #expect((try layer(secondID, in: viewModel)).style.strokeGradientStyle == .diamond)
        #expect((try layer(lockedID, in: viewModel)).style.strokeGradientStyle == .linear)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerStrokeGradientStyleState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerStrokeGradientStyleState == .value(.diamond))
    }

    private func strokeGradientStyleFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        for index in viewModel.document.layers.indices {
            viewModel.document.layers[index].style.strokeFillType = .gradient
        }
        viewModel.document.layers[0].style.strokeGradientStyle = .linear
        viewModel.document.layers[1].style.strokeGradientStyle = .radial
        viewModel.document.layers[2].style.strokeGradientStyle = .linear
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleSatinInvertMixedStateConvergesAcrossEditableSelection() throws {
        try assertSatinInvertConvergence()
    }

    @Test func layerStyleSatinInvertControlReusesFamiliarTriStateCheckbox() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let start = try #require(source.range(of: "private func layerStyleTriStateToggle("))
        let end = try #require(source[start.upperBound...].range(of: "private func guidePath("))
        let controlSource = source[start.lowerBound..<end.lowerBound]

        #expect(controlSource.contains("checkmark.square.fill"))
        #expect(controlSource.contains("minus.square.fill"))
        #expect(controlSource.contains(".focusable(false)"))
        #expect(controlSource.contains("state.accessibilityKey"))
        #expect(source.contains("state: viewModel.selectedLayerSatinInvertState"))
        #expect(source.contains("viewModel.toggleSelectedLayerSatinInvert()"))
        #expect(source.contains("image-editor-satin-invert"))
        #expect(!source.contains("Toggle(L10n.text(\"imageEditor.properties.satinInvert\")"))
    }

    private func assertSatinInvertConvergence() throws {
        let fixture = satinInvertFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerSatinInvertState == .mixed)
        viewModel.toggleSelectedLayerSatinInvert()
        #expect(viewModel.selectedLayerSatinInvertState == .on)
        #expect((try layer(firstID, in: viewModel)).style.satinInvert)
        #expect((try layer(secondID, in: viewModel)).style.satinInvert)
        #expect(!(try layer(lockedID, in: viewModel)).style.satinInvert)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerSatinInvertState == .mixed)
        viewModel.redo()
        viewModel.toggleSelectedLayerSatinInvert()
        #expect(viewModel.selectedLayerSatinInvertState == .off)
        #expect(!(try layer(firstID, in: viewModel)).style.satinInvert)
        #expect(!(try layer(secondID, in: viewModel)).style.satinInvert)
    }

    private func satinInvertFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.satinInvert = true
        viewModel.document.layers[2].isLocked = true
        select(
            Set(fixture.layers.map(\.id)),
            primary: fixture.layers[1].id,
            in: viewModel
        )
        return fixture
    }

    @Test func layerPanelRoutesEveryRowPropertyControlThroughSelectionAwareMode() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )

        #expect(source.contains("toggleLayerVisibility(layer.id, applyingToSelection: true)"))
        #expect(source.contains("toggleLayerLock(layer.id, applyingToSelection: true)"))
        #expect(source.contains("toggleLayerPixelsLock(layer.id, applyingToSelection: true)"))
        #expect(source.contains("toggleLayerPositionLock(layer.id, applyingToSelection: true)"))
        #expect(source.contains("toggleLayerTransparentPixelsLock(layer.id, applyingToSelection: true)"))
    }

    private struct Fixture {
        let viewModel: ImageEditorViewModel
        let layers: [ImageEditorLayer]
    }

    private func makeFixture() -> Fixture {
        let canvasSize = CGSize(width: 100, height: 80)
        let viewModel = ImageEditorViewModel(
            sourceName: "row-batch.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        let layers = (1...3).map { index in
            ImageEditorLayer.blank(name: "Layer \(index)", size: canvasSize)
        }
        viewModel.document.layers = layers
        viewModel.document.selectedLayerID = layers[0].id
        viewModel.document.selectedLayerIDs = [layers[0].id]
        return Fixture(viewModel: viewModel, layers: layers)
    }

    private func select(
        _ ids: Set<UUID>,
        primary: UUID,
        in viewModel: ImageEditorViewModel
    ) {
        viewModel.document.selectedLayerIDs = ids
        viewModel.document.selectedLayerID = primary
    }

    private func layer(_ id: UUID, in viewModel: ImageEditorViewModel) throws -> ImageEditorLayer {
        try #require(viewModel.document.layers.first { $0.id == id })
    }

    private func toggle(_ effect: ImageEditorLayerStyleEffect, in viewModel: ImageEditorViewModel) {
        switch effect {
        case .stroke: viewModel.toggleSelectedLayerStroke()
        case .shadow: viewModel.toggleSelectedLayerShadow()
        case .innerShadow: viewModel.toggleSelectedLayerInnerShadow()
        case .outerGlow: viewModel.toggleSelectedLayerOuterGlow()
        case .innerGlow: viewModel.toggleSelectedLayerInnerGlow()
        case .colorOverlay: viewModel.toggleSelectedLayerColorOverlay()
        case .gradientOverlay: viewModel.toggleSelectedLayerGradientOverlay()
        case .patternOverlay: viewModel.toggleSelectedLayerPatternOverlay()
        case .satin: viewModel.toggleSelectedLayerSatin()
        case .bevel: viewModel.toggleSelectedLayerBevel()
        }
    }

    private func assertLayerStyleAngleBatch(
        angle: CGFloat,
        configure: (inout ImageEditorLayerStyle, inout ImageEditorLayerStyle) -> Void,
        apply: (ImageEditorViewModel, Double) -> Void,
        enabled: (ImageEditorLayerStyle) -> Bool,
        resolvedAngle: (ImageEditorLayerStyle, CGFloat) -> CGFloat
    ) throws {
        let fixture = configuredAngleFixture(configure)
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let originalGlobalAngle = viewModel.document.globalLightAngle
        select([firstID, secondID, lockedID], primary: firstID, in: viewModel)
        let historyCount = viewModel.document.history.count

        apply(viewModel, Double(angle))

        let firstStyle = try layer(firstID, in: viewModel).style
        let secondStyle = try layer(secondID, in: viewModel).style
        #expect(viewModel.document.globalLightAngle == angle)
        #expect(enabled(firstStyle))
        #expect(enabled(secondStyle))
        #expect(resolvedAngle(firstStyle, viewModel.document.globalLightAngle) == angle)
        #expect(resolvedAngle(secondStyle, viewModel.document.globalLightAngle) == angle)
        #expect(!(try layer(lockedID, in: viewModel).style.hasConfiguredEffects))
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerStyle"))

        viewModel.undo()
        #expect(viewModel.document.globalLightAngle == originalGlobalAngle)
        #expect(!enabled(try layer(firstID, in: viewModel).style))
        #expect(!enabled(try layer(secondID, in: viewModel).style))
        #expect(!(try layer(lockedID, in: viewModel).style.hasConfiguredEffects))
    }

    private func configuredAngleFixture(
        _ configure: (inout ImageEditorLayerStyle, inout ImageEditorLayerStyle) -> Void
    ) -> Fixture {
        let fixture = makeFixture()
        var firstStyle = fixture.viewModel.document.layers[0].style
        var secondStyle = fixture.viewModel.document.layers[1].style
        configure(&firstStyle, &secondStyle)
        fixture.viewModel.document.layers[0].style = firstStyle
        fixture.viewModel.document.layers[1].style = secondStyle
        fixture.viewModel.document.layers[2].isLocked = true
        return fixture
    }

    private func setUsesGlobalLight(
        _ enabled: Bool,
        effect: ImageEditorLayerLightEffect,
        layerIndex: Int,
        in viewModel: ImageEditorViewModel
    ) {
        switch effect {
        case .shadow: viewModel.document.layers[layerIndex].style.shadowUsesGlobalLight = enabled
        case .innerShadow: viewModel.document.layers[layerIndex].style.innerShadowUsesGlobalLight = enabled
        case .bevel: viewModel.document.layers[layerIndex].style.bevelUsesGlobalLight = enabled
        }
    }

    private func assertGlobalLightConvergence(_ effect: ImageEditorLayerLightEffect) throws {
        let fixture = globalLightFixture(effect)
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerGlobalLightState(effect) == .mixed)
        viewModel.toggleSelectedLayerUsesGlobalLight(effect)
        #expect(viewModel.selectedLayerGlobalLightState(effect) == .on)
        #expect(effect.usesGlobalLight(in: try layer(firstID, in: viewModel).style))
        #expect(effect.usesGlobalLight(in: try layer(secondID, in: viewModel).style))
        #expect(!effect.usesGlobalLight(in: try layer(lockedID, in: viewModel).style))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerGlobalLightState(effect) == .mixed)
        viewModel.redo()
        viewModel.toggleSelectedLayerUsesGlobalLight(effect)
        #expect(viewModel.selectedLayerGlobalLightState(effect) == .off)
        #expect(!effect.usesGlobalLight(in: try layer(firstID, in: viewModel).style))
        #expect(!effect.usesGlobalLight(in: try layer(secondID, in: viewModel).style))
    }

    private func globalLightFixture(_ effect: ImageEditorLayerLightEffect) -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        setUsesGlobalLight(true, effect: effect, layerIndex: 0, in: viewModel)
        setUsesGlobalLight(false, effect: effect, layerIndex: 1, in: viewModel)
        setUsesGlobalLight(false, effect: effect, layerIndex: 2, in: viewModel)
        viewModel.document.layers[2].isLocked = true
        select(
            Set(fixture.layers.map(\.id)),
            primary: fixture.layers[1].id,
            in: viewModel
        )
        return fixture
    }
}
