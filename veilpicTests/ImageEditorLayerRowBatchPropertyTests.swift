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

    @Test func layerStyleStrokeWidthMixedValueConvergesAcrossEditableSelection() throws {
        let fixture = strokeWidthFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerStrokeWidthState == .mixed)
        viewModel.setSelectedLayerStrokeWidth(12)
        #expect(viewModel.selectedLayerStrokeWidthState == .value(12))
        #expect((try layer(firstID, in: viewModel)).style.strokeWidth == 12)
        #expect((try layer(secondID, in: viewModel)).style.strokeWidth == 12)
        #expect((try layer(lockedID, in: viewModel)).style.strokeWidth == 4)
        #expect((try layer(firstID, in: viewModel)).style.strokeEnabled)
        #expect((try layer(secondID, in: viewModel)).style.strokeEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerStrokeWidthState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerStrokeWidthState == .value(12))
    }

    @Test func layerStyleStrokeWidthControlShowsLocalizedMixedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let start = try #require(source.range(of: "private func layerStyleNumericStepper("))
        let end = try #require(source[start.upperBound...].range(of: "private func guidePath("))
        let stepperSource = source[start.lowerBound..<end.lowerBound]

        #expect(stepperSource.contains("imageEditor.properties.multipleValues"))
        #expect(stepperSource.contains(".focusable(false)"))
        #expect(stepperSource.contains(".accessibilityValue(displayedTitle)"))
        #expect(source.contains("state: viewModel.selectedLayerStrokeWidthState"))
        #expect(source.contains("image-editor-layer-style-stroke-width"))
        #expect(source.contains("value: selectedLayerStrokeWidthBinding"))
    }

    private func strokeWidthFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.strokeWidth = 2
        viewModel.document.layers[1].style.strokeWidth = 8
        viewModel.document.layers[2].style.strokeWidth = 4
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleStrokeOpacityMixedValueConvergesAcrossEditableSelection() throws {
        let fixture = strokeOpacityFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerStrokeOpacityState == .mixed)
        viewModel.setSelectedLayerStrokeOpacity(0.6)
        #expect(viewModel.selectedLayerStrokeOpacityState == .value(0.6))
        #expect((try layer(firstID, in: viewModel)).style.strokeOpacity == 0.6)
        #expect((try layer(secondID, in: viewModel)).style.strokeOpacity == 0.6)
        #expect((try layer(lockedID, in: viewModel)).style.strokeOpacity == 0.4)
        #expect((try layer(firstID, in: viewModel)).style.strokeEnabled)
        #expect((try layer(secondID, in: viewModel)).style.strokeEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerStrokeOpacityState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerStrokeOpacityState == .value(0.6))
    }

    @Test func layerStyleStrokeOpacityControlReusesMixedNumericStepper() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerStrokeOpacityState"))
        #expect(source.contains("value: selectedLayerStrokeOpacityBinding"))
        #expect(source.contains("image-editor-layer-style-stroke-opacity"))
        #expect(source.contains("L10n.format(\"imageEditor.properties.strokeOpacityValue\""))
    }

    private func strokeOpacityFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.strokeOpacity = 0.25
        viewModel.document.layers[1].style.strokeOpacity = 0.75
        viewModel.document.layers[2].style.strokeOpacity = 0.4
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleStrokeGradientAngleMixedValueConvergesAcrossEditableSelection() throws {
        let fixture = strokeGradientAngleFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerStrokeGradientAngleState == .mixed)
        viewModel.setSelectedLayerStrokeGradientAngle(120)
        #expect(viewModel.selectedLayerStrokeGradientAngleState == .value(120))
        #expect((try layer(firstID, in: viewModel)).style.strokeGradientAngle == 120)
        #expect((try layer(secondID, in: viewModel)).style.strokeGradientAngle == 120)
        #expect((try layer(lockedID, in: viewModel)).style.strokeGradientAngle == 30)
        #expect((try layer(firstID, in: viewModel)).style.strokeEnabled)
        #expect((try layer(secondID, in: viewModel)).style.strokeFillType == .gradient)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerStrokeGradientAngleState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerStrokeGradientAngleState == .value(120))
    }

    @Test func layerStyleStrokeGradientAngleControlReusesMixedNumericStepper() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerStrokeGradientAngleState"))
        #expect(source.contains("value: selectedLayerStrokeGradientAngleBinding"))
        #expect(source.contains("image-editor-layer-style-stroke-gradient-angle"))
        #expect(source.contains("L10n.format(\"imageEditor.properties.strokeGradientAngleValue\""))
    }

    private func strokeGradientAngleFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.strokeFillType = .gradient
        viewModel.document.layers[0].style.strokeGradientAngle = -45
        viewModel.document.layers[1].style.strokeFillType = .gradient
        viewModel.document.layers[1].style.strokeGradientAngle = 90
        viewModel.document.layers[2].style.strokeFillType = .gradient
        viewModel.document.layers[2].style.strokeGradientAngle = 30
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
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

    @Test func layerStyleStrokePatternKindMixedValueConvergesAcrossEditableSelection() throws {
        try assertStrokePatternKindConvergence()
    }

    @Test func layerStyleStrokePatternKindPickerUsesLocalizedMixedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerStrokePatternKindState"))
        #expect(source.contains("image-editor-layer-style-stroke-pattern-kind"))
        #expect(source.contains("viewModel.setSelectedLayerStrokePatternKind(kind)"))
        #expect(!source.contains("selectedLayerStrokePatternKindBinding"))
    }

    private func assertStrokePatternKindConvergence() throws {
        let fixture = strokePatternKindFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerStrokePatternKindState == .mixed)
        viewModel.setSelectedLayerStrokePatternKind(.dots)
        #expect(viewModel.selectedLayerStrokePatternKindState == .value(.dots))
        #expect((try layer(firstID, in: viewModel)).style.strokePatternKind == .dots)
        #expect((try layer(secondID, in: viewModel)).style.strokePatternKind == .dots)
        #expect((try layer(lockedID, in: viewModel)).style.strokePatternKind == .checkerboard)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerStrokePatternKindState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerStrokePatternKindState == .value(.dots))
    }

    private func strokePatternKindFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        for index in viewModel.document.layers.indices {
            viewModel.document.layers[index].style.strokeFillType = .pattern
        }
        viewModel.document.layers[0].style.strokePatternKind = .checkerboard
        viewModel.document.layers[1].style.strokePatternKind = .diagonalStripes
        viewModel.document.layers[2].style.strokePatternKind = .checkerboard
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleMixedInnerGlowSourceConvergesAcrossEditableSelection() throws {
        try assertInnerGlowSourceConvergence()
    }

    @Test func layerStyleMixedInnerGlowSourcePickerUsesLocalizedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerInnerGlowSourceState"))
        #expect(source.contains("image-editor-layer-style-inner-glow-source"))
        #expect(source.contains("viewModel.setSelectedLayerInnerGlowSource(source)"))
        #expect(!source.contains("selectedLayerInnerGlowSourceBinding"))
    }

    private func assertInnerGlowSourceConvergence() throws {
        let fixture = innerGlowSourceFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerInnerGlowSourceState == .mixed)
        viewModel.setSelectedLayerInnerGlowSource(.center)
        #expect(viewModel.selectedLayerInnerGlowSourceState == .value(.center))
        #expect((try layer(firstID, in: viewModel)).style.innerGlowSource == .center)
        #expect((try layer(secondID, in: viewModel)).style.innerGlowSource == .center)
        #expect((try layer(lockedID, in: viewModel)).style.innerGlowSource == .edge)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerInnerGlowSourceState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerInnerGlowSourceState == .value(.center))
    }

    private func innerGlowSourceFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.innerGlowSource = .edge
        viewModel.document.layers[1].style.innerGlowSource = .center
        viewModel.document.layers[2].style.innerGlowSource = .edge
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleMixedBevelDirectionConvergesAcrossEditableSelection() throws {
        let fixture = bevelDirectionFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerBevelDirectionState == .mixed)
        viewModel.setSelectedLayerBevelDirection(.down)
        #expect(viewModel.selectedLayerBevelDirectionState == .value(.down))
        #expect((try layer(firstID, in: viewModel)).style.bevelDirection == .down)
        #expect((try layer(secondID, in: viewModel)).style.bevelDirection == .down)
        #expect((try layer(lockedID, in: viewModel)).style.bevelDirection == .up)
        #expect((try layer(firstID, in: viewModel)).style.bevelEnabled)
        #expect((try layer(secondID, in: viewModel)).style.bevelEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerBevelDirectionState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerBevelDirectionState == .value(.down))
    }

    @Test func layerStyleMixedBevelDirectionPickerUsesLocalizedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerBevelDirectionState"))
        #expect(source.contains("image-editor-layer-style-bevel-direction"))
        #expect(source.contains("viewModel.setSelectedLayerBevelDirection(direction)"))
        #expect(!source.contains("selectedLayerBevelDirectionBinding"))
    }

    private func bevelDirectionFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.bevelDirection = .up
        viewModel.document.layers[1].style.bevelDirection = .down
        viewModel.document.layers[2].style.bevelDirection = .up
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleMixedGradientOverlayStyleConvergesAcrossEditableSelection() throws {
        let fixture = gradientOverlayStyleFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerGradientOverlayStyleState == .mixed)
        viewModel.setSelectedLayerGradientOverlayStyle(.reflected)
        #expect(viewModel.selectedLayerGradientOverlayStyleState == .value(.reflected))
        #expect((try layer(firstID, in: viewModel)).style.gradientOverlayStyle == .reflected)
        #expect((try layer(secondID, in: viewModel)).style.gradientOverlayStyle == .reflected)
        #expect((try layer(lockedID, in: viewModel)).style.gradientOverlayStyle == .linear)
        #expect((try layer(firstID, in: viewModel)).style.gradientOverlayEnabled)
        #expect((try layer(secondID, in: viewModel)).style.gradientOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerGradientOverlayStyleState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerGradientOverlayStyleState == .value(.reflected))
    }

    @Test func layerStyleMixedGradientOverlayStylePickerUsesLocalizedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerGradientOverlayStyleState"))
        #expect(source.contains("image-editor-layer-style-gradient-overlay-style"))
        #expect(source.contains("viewModel.setSelectedLayerGradientOverlayStyle(style)"))
        #expect(!source.contains("selectedLayerGradientOverlayStyleBinding"))
    }

    private func gradientOverlayStyleFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.gradientOverlayStyle = .linear
        viewModel.document.layers[1].style.gradientOverlayStyle = .radial
        viewModel.document.layers[2].style.gradientOverlayStyle = .linear
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleMixedPatternOverlayKindConvergesAcrossEditableSelection() throws {
        let fixture = patternOverlayKindFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerPatternOverlayKindState == .mixed)
        viewModel.setSelectedLayerPatternOverlayKind(.dots)
        #expect(viewModel.selectedLayerPatternOverlayKindState == .value(.dots))
        #expect((try layer(firstID, in: viewModel)).style.patternOverlayKind == .dots)
        #expect((try layer(secondID, in: viewModel)).style.patternOverlayKind == .dots)
        #expect((try layer(lockedID, in: viewModel)).style.patternOverlayKind == .checkerboard)
        #expect((try layer(firstID, in: viewModel)).style.patternOverlayEnabled)
        #expect((try layer(secondID, in: viewModel)).style.patternOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerPatternOverlayKindState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerPatternOverlayKindState == .value(.dots))
    }

    @Test func layerStyleMixedPatternOverlayKindPickerUsesLocalizedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerPatternOverlayKindState"))
        #expect(source.contains("image-editor-layer-style-pattern-overlay-kind"))
        #expect(source.contains("viewModel.setSelectedLayerPatternOverlayKind(kind)"))
        #expect(!source.contains("selectedLayerPatternOverlayKindBinding"))
    }

    private func patternOverlayKindFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.patternOverlayKind = .checkerboard
        viewModel.document.layers[1].style.patternOverlayKind = .diagonalStripes
        viewModel.document.layers[2].style.patternOverlayKind = .checkerboard
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStylePatternOverlayOpacityMixedValueConvergesAcrossEditableSelection() throws {
        let fixture = patternOverlayOpacityFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerPatternOverlayOpacityState == .mixed)
        viewModel.setSelectedLayerPatternOverlayOpacity(0.6)
        #expect(viewModel.selectedLayerPatternOverlayOpacityState == .value(0.6))
        #expect((try layer(firstID, in: viewModel)).style.patternOverlayOpacity == 0.6)
        #expect((try layer(secondID, in: viewModel)).style.patternOverlayOpacity == 0.6)
        #expect((try layer(lockedID, in: viewModel)).style.patternOverlayOpacity == 0.4)
        #expect((try layer(firstID, in: viewModel)).style.patternOverlayEnabled)
        #expect((try layer(secondID, in: viewModel)).style.patternOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerPatternOverlayOpacityState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerPatternOverlayOpacityState == .value(0.6))
    }

    @Test func layerStylePatternOverlayOpacityControlReusesMixedNumericStepper() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerPatternOverlayOpacityState"))
        #expect(source.contains("value: selectedLayerPatternOverlayOpacityBinding"))
        #expect(source.contains("image-editor-layer-style-pattern-overlay-opacity"))
        #expect(source.contains("L10n.format(\"imageEditor.properties.patternOverlayOpacityValue\""))
    }

    private func patternOverlayOpacityFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.patternOverlayOpacity = 0.25
        viewModel.document.layers[1].style.patternOverlayOpacity = 0.75
        viewModel.document.layers[2].style.patternOverlayOpacity = 0.4
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStylePatternOverlayScaleMixedValueConvergesAcrossEditableSelection() throws {
        let fixture = patternOverlayScaleFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerPatternOverlayScaleState == .mixed)
        viewModel.setSelectedLayerPatternOverlayScale(32)
        #expect(viewModel.selectedLayerPatternOverlayScaleState == .value(32))
        #expect((try layer(firstID, in: viewModel)).style.patternOverlayScale == 32)
        #expect((try layer(secondID, in: viewModel)).style.patternOverlayScale == 32)
        #expect((try layer(lockedID, in: viewModel)).style.patternOverlayScale == 12)
        #expect((try layer(firstID, in: viewModel)).style.patternOverlayEnabled)
        #expect((try layer(secondID, in: viewModel)).style.patternOverlayEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerPatternOverlayScaleState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerPatternOverlayScaleState == .value(32))
    }

    @Test func layerStylePatternOverlayScaleControlReusesMixedNumericStepper() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerPatternOverlayScaleState"))
        #expect(source.contains("value: selectedLayerPatternOverlayScaleBinding"))
        #expect(source.contains("image-editor-layer-style-pattern-overlay-scale"))
        #expect(source.contains("L10n.format(\"imageEditor.properties.patternOverlayScaleValue\""))
    }

    private func patternOverlayScaleFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.patternOverlayScale = 8
        viewModel.document.layers[1].style.patternOverlayScale = 24
        viewModel.document.layers[2].style.patternOverlayScale = 12
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleMixedShadowContourConvergesAcrossEditableSelection() throws {
        let fixture = shadowContourFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerShadowContourState == .mixed)
        viewModel.setSelectedLayerShadowContour(.ring)
        #expect(viewModel.selectedLayerShadowContourState == .value(.ring))
        #expect((try layer(firstID, in: viewModel)).style.shadowContour == .ring)
        #expect((try layer(secondID, in: viewModel)).style.shadowContour == .ring)
        #expect((try layer(lockedID, in: viewModel)).style.shadowContour == .linear)
        #expect((try layer(firstID, in: viewModel)).style.shadowEnabled)
        #expect((try layer(secondID, in: viewModel)).style.shadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerShadowContourState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerShadowContourState == .value(.ring))
    }

    @Test func layerStyleMixedShadowContourPickerUsesLocalizedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerShadowContourState"))
        #expect(source.contains("image-editor-layer-style-shadow-contour"))
        #expect(source.contains("viewModel.setSelectedLayerShadowContour(contour)"))
        #expect(!source.contains("selectedLayerShadowContourBinding"))
    }

    private func shadowContourFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.shadowContour = .linear
        viewModel.document.layers[1].style.shadowContour = .soft
        viewModel.document.layers[2].style.shadowContour = .linear
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleMixedInnerShadowContourConvergesAcrossEditableSelection() throws {
        let fixture = innerShadowContourFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerInnerShadowContourState == .mixed)
        viewModel.setSelectedLayerInnerShadowContour(.cone)
        #expect(viewModel.selectedLayerInnerShadowContourState == .value(.cone))
        #expect((try layer(firstID, in: viewModel)).style.innerShadowContour == .cone)
        #expect((try layer(secondID, in: viewModel)).style.innerShadowContour == .cone)
        #expect((try layer(lockedID, in: viewModel)).style.innerShadowContour == .linear)
        #expect((try layer(firstID, in: viewModel)).style.innerShadowEnabled)
        #expect((try layer(secondID, in: viewModel)).style.innerShadowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerInnerShadowContourState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerInnerShadowContourState == .value(.cone))
    }

    @Test func layerStyleMixedInnerShadowContourPickerUsesLocalizedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerInnerShadowContourState"))
        #expect(source.contains("image-editor-layer-style-inner-shadow-contour"))
        #expect(source.contains("viewModel.setSelectedLayerInnerShadowContour(contour)"))
        #expect(!source.contains("selectedLayerInnerShadowContourBinding"))
    }

    private func innerShadowContourFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.innerShadowContour = .linear
        viewModel.document.layers[1].style.innerShadowContour = .steep
        viewModel.document.layers[2].style.innerShadowContour = .linear
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleMixedOuterGlowContourConvergesAcrossEditableSelection() throws {
        let fixture = outerGlowContourFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerOuterGlowContourState == .mixed)
        viewModel.setSelectedLayerOuterGlowContour(.ring)
        #expect(viewModel.selectedLayerOuterGlowContourState == .value(.ring))
        #expect((try layer(firstID, in: viewModel)).style.outerGlowContour == .ring)
        #expect((try layer(secondID, in: viewModel)).style.outerGlowContour == .ring)
        #expect((try layer(lockedID, in: viewModel)).style.outerGlowContour == .linear)
        #expect((try layer(firstID, in: viewModel)).style.outerGlowEnabled)
        #expect((try layer(secondID, in: viewModel)).style.outerGlowEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerOuterGlowContourState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerOuterGlowContourState == .value(.ring))
    }

    @Test func layerStyleMixedOuterGlowContourPickerUsesLocalizedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerOuterGlowContourState"))
        #expect(source.contains("image-editor-layer-style-outer-glow-contour"))
        #expect(source.contains("viewModel.setSelectedLayerOuterGlowContour(contour)"))
        #expect(!source.contains("selectedLayerOuterGlowContourBinding"))
    }

    private func outerGlowContourFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.outerGlowContour = .linear
        viewModel.document.layers[1].style.outerGlowContour = .soft
        viewModel.document.layers[2].style.outerGlowContour = .linear
        viewModel.document.layers[2].isLocked = true
        select(Set(fixture.layers.map(\.id)), primary: fixture.layers[0].id, in: viewModel)
        return fixture
    }

    @Test func layerStyleMixedSatinContourConvergesAcrossEditableSelection() throws {
        let fixture = satinContourFixture()
        let viewModel = fixture.viewModel
        let firstID = fixture.layers[0].id
        let secondID = fixture.layers[1].id
        let lockedID = fixture.layers[2].id
        let historyCount = viewModel.document.history.count

        #expect(viewModel.selectedLayerSatinContourState == .mixed)
        viewModel.setSelectedLayerSatinContour(.cone)
        #expect(viewModel.selectedLayerSatinContourState == .value(.cone))
        #expect((try layer(firstID, in: viewModel)).style.satinContour == .cone)
        #expect((try layer(secondID, in: viewModel)).style.satinContour == .cone)
        #expect((try layer(lockedID, in: viewModel)).style.satinContour == .linear)
        #expect((try layer(firstID, in: viewModel)).style.satinEnabled)
        #expect((try layer(secondID, in: viewModel)).style.satinEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID, lockedID])

        viewModel.undo()
        #expect(viewModel.selectedLayerSatinContourState == .mixed)
        viewModel.redo()
        #expect(viewModel.selectedLayerSatinContourState == .value(.cone))
    }

    @Test func layerStyleMixedSatinContourPickerUsesLocalizedValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("state: viewModel.selectedLayerSatinContourState"))
        #expect(source.contains("image-editor-layer-style-satin-contour"))
        #expect(source.contains("viewModel.setSelectedLayerSatinContour(contour)"))
        #expect(!source.contains("selectedLayerSatinContourBinding"))
    }

    private func satinContourFixture() -> Fixture {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.layers[0].style.satinContour = .linear
        viewModel.document.layers[1].style.satinContour = .steep
        viewModel.document.layers[2].style.satinContour = .linear
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
