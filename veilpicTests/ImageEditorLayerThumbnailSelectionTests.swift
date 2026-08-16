//
//  ImageEditorLayerThumbnailSelectionTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/17.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerThumbnailSelectionTests {
    @Test func thumbnailModifiersResolveEveryClassicSelectionModeOnlyInToolsWorkspace() {
        let cases: [(NSEvent.ModifierFlags, ImageEditorSelectionMode?)] = [
            ([], nil),
            ([.shift], nil),
            ([.command], .replace),
            ([.command, .shift], .add),
            ([.command, .option], .subtract),
            ([.command, .shift, .option], .intersect),
            ([.command, .control], nil)
        ]

        for (flags, expectedMode) in cases {
            #expect(ImageEditorLayerThumbnailSelectionPolicy.mode(
                sidebarTab: .tools,
                modifierFlags: flags
            ) == expectedMode)
        }
        #expect(ImageEditorLayerThumbnailSelectionPolicy.mode(
            sidebarTab: .components,
            modifierFlags: [.command]
        ) == nil)
    }

    @Test func pureShiftTogglesOnlyMaskThumbnailsAndCommandShiftKeepsSelectionPriority() {
        for source in [
            ImageEditorLayerThumbnailSelectionSource.rasterMask,
            .vectorMask
        ] {
            #expect(ImageEditorLayerThumbnailSelectionPolicy.togglesMaskEnabled(
                sidebarTab: .tools,
                source: source,
                modifierFlags: [.shift]
            ))
            #expect(!ImageEditorLayerThumbnailSelectionPolicy.togglesMaskEnabled(
                sidebarTab: .tools,
                source: source,
                modifierFlags: [.command, .shift]
            ))
        }
        #expect(!ImageEditorLayerThumbnailSelectionPolicy.togglesMaskEnabled(
            sidebarTab: .tools,
            source: .transparency,
            modifierFlags: [.shift]
        ))
        #expect(!ImageEditorLayerThumbnailSelectionPolicy.togglesMaskEnabled(
            sidebarTab: .components,
            source: .rasterMask,
            modifierFlags: [.shift]
        ))
    }

    @Test func pureOptionPreviewsOnlyRasterMasksWithoutStealingSelectionCombinations() {
        #expect(ImageEditorLayerThumbnailSelectionPolicy.previewsRasterMask(
            sidebarTab: .tools,
            source: .rasterMask,
            modifierFlags: [.option]
        ))
        for (source, flags) in [
            (ImageEditorLayerThumbnailSelectionSource.vectorMask, NSEvent.ModifierFlags.option),
            (.transparency, .option),
            (.rasterMask, [.command, .option]),
            (.rasterMask, [.shift, .option]),
            (.rasterMask, [.control, .option])
        ] {
            #expect(!ImageEditorLayerThumbnailSelectionPolicy.previewsRasterMask(
                sidebarTab: .tools,
                source: source,
                modifierFlags: flags
            ))
        }
        #expect(!ImageEditorLayerThumbnailSelectionPolicy.previewsRasterMask(
            sidebarTab: .components,
            source: .rasterMask,
            modifierFlags: [.option]
        ))
    }

    @Test func shiftOptionPreviewsOnlyRasterMaskRubylithAndKeepsCommandIntersection() {
        #expect(ImageEditorLayerThumbnailSelectionPolicy.previewsRasterMaskAsRubylith(
            sidebarTab: .tools,
            source: .rasterMask,
            modifierFlags: [.shift, .option]
        ))
        let rejectedCases: [(ImageEditorLayerThumbnailSelectionSource, NSEvent.ModifierFlags)] = [
            (.vectorMask, [.shift, .option]),
            (.transparency, [.shift, .option]),
            (.rasterMask, [.option]),
            (.rasterMask, [.shift]),
            (.rasterMask, [.command, .shift, .option]),
            (.rasterMask, [.control, .shift, .option])
        ]
        for (source, flags) in rejectedCases {
            #expect(!ImageEditorLayerThumbnailSelectionPolicy.previewsRasterMaskAsRubylith(
                sidebarTab: .tools,
                source: source,
                modifierFlags: flags
            ))
        }
        #expect(!ImageEditorLayerThumbnailSelectionPolicy.previewsRasterMaskAsRubylith(
            sidebarTab: .components,
            source: .rasterMask,
            modifierFlags: [.shift, .option]
        ))
        #expect(ImageEditorLayerThumbnailSelectionPolicy.mode(
            sidebarTab: .tools,
            modifierFlags: [.command, .shift, .option]
        ) == .intersect)
    }

    @Test func backslashResolvesRubylithOnlyForAnEligibleSelectedLayerMask() {
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "\\",
            modifierFlags: [],
            canToggleLayerMaskRubylith: true
        ) == .toggleLayerMaskRubylith)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: nil,
            modifierFlags: [],
            keyCode: 42,
            canToggleLayerMaskRubylith: true
        ) == .toggleLayerMaskRubylith)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "\\",
            modifierFlags: []
        ) == nil)
        #expect(ImageEditorKeyboardShortcutAction.resolve(
            charactersIgnoringModifiers: "\\",
            modifierFlags: [.shift],
            canToggleLayerMaskRubylith: true
        ) == nil)
    }

    @Test func clickedTransparencyThumbnailTargetsItsLayerWithoutChangingLayerOrToolMode() throws {
        let fixture = makeLayerFixture()
        let viewModel = fixture.viewModel
        viewModel.selectionMode = .subtract
        let selectedLayerIDs = viewModel.document.selectedLayerIDs
        let selectedLayerID = viewModel.document.selectedLayerID

        #expect(viewModel.loadSelectionFromLayerTransparency(
            layerID: fixture.thumbnailLayerID,
            mode: .replace
        ))

        let selection = try #require(viewModel.document.selection)
        #expect(selection.bounds.width < fixture.canvasSize.width)
        #expect(selection.bounds.height < fixture.canvasSize.height)
        #expect(viewModel.document.selectedLayerIDs == selectedLayerIDs)
        #expect(viewModel.document.selectedLayerID == selectedLayerID)
        #expect(viewModel.selectionMode == .subtract)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFromLayer"))
    }

    @Test func explicitThumbnailModeDrivesAddSubtractAndIntersectWithoutMutatingToolMode() throws {
        let fixture = makeLayerFixture()
        let viewModel = fixture.viewModel
        viewModel.selectionMode = .replace

        #expect(viewModel.loadSelectionFromLayerTransparency(
            layerID: fixture.thumbnailLayerID,
            mode: .add
        ))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionAdd"))

        viewModel.selectAll()
        #expect(viewModel.loadSelectionFromLayerTransparency(
            layerID: fixture.thumbnailLayerID,
            mode: .subtract
        ))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionSubtract"))

        viewModel.selectAll()
        #expect(viewModel.loadSelectionFromLayerTransparency(
            layerID: fixture.thumbnailLayerID,
            mode: .intersect
        ))
        let intersection = try #require(viewModel.document.selection)
        #expect(intersection.bounds.width < fixture.canvasSize.width)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionIntersect"))
        #expect(viewModel.selectionMode == .replace)
    }

    @Test func rasterAndVectorMaskThumbnailsUseTheClickedLayerWithoutSelectingIt() throws {
        let fixture = makeLayerFixture(includeMasks: true)
        let viewModel = fixture.viewModel
        let selectedLayerID = viewModel.document.selectedLayerID
        let selectedLayerIDs = viewModel.document.selectedLayerIDs

        #expect(viewModel.loadSelectionFromLayerMask(
            layerID: fixture.thumbnailLayerID,
            mode: .replace
        ))
        #expect(viewModel.document.selection != nil)
        #expect(viewModel.document.selectedLayerID == selectedLayerID)
        #expect(viewModel.document.selectedLayerIDs == selectedLayerIDs)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerMaskSelection"))

        viewModel.clearSelection()
        #expect(viewModel.loadSelectionFromVectorMask(
            layerID: fixture.thumbnailLayerID,
            mode: .replace
        ))
        #expect(viewModel.document.selection != nil)
        #expect(viewModel.document.selectedLayerID == selectedLayerID)
        #expect(viewModel.document.selectedLayerIDs == selectedLayerIDs)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.vectorMaskSelection"))
    }

    @Test func clickedMaskTogglesAreSingleTargetUndoableAndSelectionNeutral() throws {
        let fixture = makeLayerFixture(includeMasks: true)
        let viewModel = fixture.viewModel
        let selectedLayerID = viewModel.document.selectedLayerID
        let selectedLayerIDs = viewModel.document.selectedLayerIDs
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.toggleLayerMaskEnabled(layerID: fixture.thumbnailLayerID))
        var target = try #require(viewModel.document.layers.first { $0.id == fixture.thumbnailLayerID })
        #expect(!target.isMaskEnabled)
        #expect(target.isVectorMaskEnabled)
        #expect(viewModel.document.selectedLayerID == selectedLayerID)
        #expect(viewModel.document.selectedLayerIDs == selectedLayerIDs)
        #expect(viewModel.undoStack.count == undoCount + 1)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskDisable"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerMaskDisabled"))

        viewModel.undo()
        target = try #require(viewModel.document.layers.first { $0.id == fixture.thumbnailLayerID })
        #expect(target.isMaskEnabled)

        #expect(viewModel.toggleVectorMaskEnabled(layerID: fixture.thumbnailLayerID))
        target = try #require(viewModel.document.layers.first { $0.id == fixture.thumbnailLayerID })
        #expect(target.isMaskEnabled)
        #expect(!target.isVectorMaskEnabled)
        #expect(viewModel.document.selectedLayerID == selectedLayerID)
        #expect(viewModel.document.selectedLayerIDs == selectedLayerIDs)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.vectorMaskDisable"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.vectorMaskDisabled"))

        viewModel.undo()
        target = try #require(viewModel.document.layers.first { $0.id == fixture.thumbnailLayerID })
        #expect(target.isVectorMaskEnabled)
    }

    @Test func clickedLinkControlTargetsRasterMaskWithoutChangingSelection() throws {
        let rasterFixture = makeLayerFixture(includeMasks: true)
        let rasterViewModel = rasterFixture.viewModel
        let selectedLayerID = rasterViewModel.document.selectedLayerID
        let selectedLayerIDs = rasterViewModel.document.selectedLayerIDs
        let historyCount = rasterViewModel.document.history.count
        let undoCount = rasterViewModel.undoStack.count

        #expect(rasterViewModel.toggleLayerMaskLinked(layerID: rasterFixture.thumbnailLayerID))
        var target = try #require(rasterViewModel.document.layers.first {
            $0.id == rasterFixture.thumbnailLayerID
        })
        #expect(!target.isMaskLinked)
        #expect(rasterViewModel.document.selectedLayerID == selectedLayerID)
        #expect(rasterViewModel.document.selectedLayerIDs == selectedLayerIDs)
        #expect(rasterViewModel.document.history.count == historyCount + 1)
        #expect(rasterViewModel.undoStack.count == undoCount + 1)
        #expect(rasterViewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMaskUnlink"))
        #expect(rasterViewModel.statusText == L10n.text("imageEditor.status.layerMaskUnlinked"))

        rasterViewModel.undo()
        target = try #require(rasterViewModel.document.layers.first {
            $0.id == rasterFixture.thumbnailLayerID
        })
        #expect(target.isMaskLinked)
    }

    @Test func rasterMaskSoloPreviewIsTransientGrayscaleAndSelectsItsEditingTarget() throws {
        let fixture = makeLayerFixture(includeMasks: true)
        let viewModel = fixture.viewModel
        let index = try #require(viewModel.document.layers.firstIndex {
            $0.id == fixture.thumbnailLayerID
        })
        let width = Int(fixture.canvasSize.width)
        let height = Int(fixture.canvasSize.height)
        let alpha = (0..<(width * height)).map { offset in
            offset % width < width / 2 ? UInt8.min : UInt8.max
        }
        viewModel.document.layers[index].mask = try #require(
            NSImage.alphaMaskImage(width: width, height: height, alpha: alpha)
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let compositeData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.toggleLayerMaskSoloPreview(layerID: fixture.thumbnailLayerID))
        #expect(viewModel.previewedLayerMaskID == fixture.thumbnailLayerID)
        #expect(viewModel.document.selectedLayerID == fixture.thumbnailLayerID)
        #expect(viewModel.document.selectedLayerIDs == [fixture.thumbnailLayerID])
        #expect(viewModel.isEditingLayerMask)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(try #require(viewModel.currentImage.qingtuPNGData()) == compositeData)

        let dark = try #require(
            viewModel.previewImage.color(at: CGPoint(x: 10.5, y: 20.5))?.usingColorSpace(.deviceRGB)
        )
        let light = try #require(
            viewModel.previewImage.color(at: CGPoint(x: 70.5, y: 20.5))?.usingColorSpace(.deviceRGB)
        )
        #expect(dark.redComponent < 0.02)
        #expect(dark.greenComponent < 0.02)
        #expect(dark.blueComponent < 0.02)
        #expect(light.redComponent > 0.98)
        #expect(light.greenComponent > 0.98)
        #expect(light.blueComponent > 0.98)
        #expect(dark.alphaComponent > 0.98)
        #expect(light.alphaComponent > 0.98)

        #expect(viewModel.toggleLayerMaskSoloPreview(layerID: fixture.thumbnailLayerID))
        #expect(viewModel.previewedLayerMaskID == nil)
        #expect(viewModel.isEditingLayerMask)
        #expect(try #require(viewModel.previewImage.qingtuPNGData()) == compositeData)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func rasterMaskRubylithPreviewOverlaysOnlyMaskedPixelsWithoutAHistoryTransaction() throws {
        let fixture = makeLayerFixture(includeMasks: true)
        let viewModel = fixture.viewModel
        try installSplitAlphaMask(in: fixture)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        let compositeData = try #require(viewModel.currentImage.qingtuPNGData())

        #expect(viewModel.toggleLayerMaskRubylithPreview(layerID: fixture.thumbnailLayerID))
        #expect(viewModel.previewedLayerMaskID == fixture.thumbnailLayerID)
        #expect(viewModel.previewedLayerMaskMode == .rubylith)
        #expect(viewModel.document.selectedLayerID == fixture.thumbnailLayerID)
        #expect(viewModel.document.selectedLayerIDs == [fixture.thumbnailLayerID])
        #expect(viewModel.isEditingLayerMask)
        #expect(!viewModel.isQuickMaskMode)
        #expect(try #require(viewModel.previewImage.qingtuPNGData()) == compositeData)

        let overlay = try #require(viewModel.canvasMaskOverlayImage)
        let masked = try #require(
            overlay.color(at: CGPoint(x: 10.5, y: 20.5))?.usingColorSpace(.deviceRGB)
        )
        let revealedAlpha = overlay.color(
            at: CGPoint(x: 70.5, y: 20.5)
        )?.usingColorSpace(.deviceRGB)?.alphaComponent ?? 0
        #expect(masked.redComponent > 0.98)
        #expect(masked.greenComponent < 0.02)
        #expect(masked.blueComponent < 0.02)
        #expect(abs(masked.alphaComponent - 0.5) < 0.02)
        #expect(revealedAlpha < 0.02)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)

        #expect(viewModel.toggleLayerMaskRubylithPreview(layerID: fixture.thumbnailLayerID))
        #expect(viewModel.previewedLayerMaskID == nil)
        #expect(viewModel.previewedLayerMaskMode == nil)
        #expect(viewModel.canvasMaskOverlayImage == nil)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func layerMaskSoloRubylithAndQuickMaskModesAreMutuallyExclusive() throws {
        let fixture = makeLayerFixture(includeMasks: true)
        let viewModel = fixture.viewModel
        try installSplitAlphaMask(in: fixture)

        #expect(viewModel.toggleLayerMaskSoloPreview(layerID: fixture.thumbnailLayerID))
        #expect(viewModel.previewedLayerMaskMode == .solo)
        #expect(viewModel.canvasMaskOverlayImage == nil)

        #expect(viewModel.toggleLayerMaskRubylithPreview(layerID: fixture.thumbnailLayerID))
        #expect(viewModel.previewedLayerMaskMode == .rubylith)
        #expect(viewModel.canvasMaskOverlayImage != nil)

        #expect(viewModel.toggleLayerMaskSoloPreview(layerID: fixture.thumbnailLayerID))
        #expect(viewModel.previewedLayerMaskMode == .solo)
        #expect(viewModel.canvasMaskOverlayImage == nil)

        viewModel.document.selection = ImageEditorSelection.rectangle(
            CGRect(x: 8, y: 8, width: 24, height: 18)
        )
        viewModel.toggleQuickMaskMode()
        #expect(viewModel.isQuickMaskMode)
        #expect(viewModel.previewedLayerMaskID == nil)
        #expect(viewModel.previewedLayerMaskMode == nil)
        let canvasOverlay = try #require(viewModel.canvasMaskOverlayImage)
        let quickMaskOverlay = try #require(viewModel.quickMaskOverlayImage)
        #expect(canvasOverlay === quickMaskOverlay)

        #expect(viewModel.toggleLayerMaskRubylithPreview(layerID: fixture.thumbnailLayerID))
        #expect(!viewModel.isQuickMaskMode)
        #expect(viewModel.quickMaskOverlayImage == nil)
        #expect(viewModel.previewedLayerMaskMode == .rubylith)
        #expect(viewModel.canvasMaskOverlayImage != nil)
    }

    @Test func selectedLayerMaskBackslashToggleIsTransientAndWorkspaceScoped() throws {
        let fixture = makeLayerFixture(includeMasks: true)
        let viewModel = fixture.viewModel
        try installSplitAlphaMask(in: fixture)
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.selectLayer(fixture.thumbnailLayerID, editingMask: false)
        #expect(!viewModel.canToggleSelectedLayerMaskRubylithPreview)
        #expect(!viewModel.toggleSelectedLayerMaskRubylithPreview())

        viewModel.selectLayer(fixture.thumbnailLayerID, editingMask: true)
        #expect(viewModel.canToggleSelectedLayerMaskRubylithPreview)
        #expect(viewModel.toggleSelectedLayerMaskRubylithPreview())
        #expect(viewModel.previewedLayerMaskMode == .rubylith)
        #expect(viewModel.canvasMaskOverlayImage != nil)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)

        #expect(viewModel.toggleSelectedLayerMaskRubylithPreview())
        #expect(viewModel.previewedLayerMaskMode == nil)
        #expect(viewModel.canvasMaskOverlayImage == nil)

        viewModel.selectedLeftSidebarTab = .components
        #expect(!viewModel.canToggleSelectedLayerMaskRubylithPreview)
        #expect(!viewModel.toggleSelectedLayerMaskRubylithPreview())
        #expect(viewModel.previewedLayerMaskMode == nil)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func contentOrChannelSelectionLeavesMaskSoloPreviewWithoutHistory() throws {
        let fixture = makeLayerFixture(includeMasks: true)
        let viewModel = fixture.viewModel
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(viewModel.toggleLayerMaskSoloPreview(layerID: fixture.thumbnailLayerID))
        viewModel.selectLayer(fixture.thumbnailLayerID, editingMask: false)
        #expect(viewModel.previewedLayerMaskID == nil)
        #expect(!viewModel.isEditingLayerMask)

        #expect(viewModel.toggleLayerMaskSoloPreview(layerID: fixture.thumbnailLayerID))
        viewModel.selectChannelPreview(.red)
        #expect(viewModel.previewedLayerMaskID == nil)
        #expect(viewModel.selectedChannelPreview == .red)

        #expect(viewModel.toggleLayerMaskSoloPreview(layerID: fixture.thumbnailLayerID))
        let index = try #require(viewModel.document.layers.firstIndex {
            $0.id == fixture.thumbnailLayerID
        })
        viewModel.document.layers[index].mask = nil
        #expect(viewModel.previewedLayerMaskID == nil)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
    }

    @Test func vectorOnlyMaskKeepsAReachableLinkControl() throws {
        let vectorFixture = makeLayerFixture(includeMasks: true)
        let vectorViewModel = vectorFixture.viewModel
        let vectorIndex = try #require(vectorViewModel.document.layers.firstIndex {
            $0.id == vectorFixture.thumbnailLayerID
        })
        vectorViewModel.document.layers[vectorIndex].mask = nil

        #expect(vectorViewModel.toggleLayerMaskLinked(layerID: vectorFixture.thumbnailLayerID))
        let target = try #require(vectorViewModel.document.layers.first {
            $0.id == vectorFixture.thumbnailLayerID
        })
        #expect(target.mask == nil)
        #expect(target.vectorMask != nil)
        #expect(!target.isMaskLinked)
    }

    @Test func lockedClickedMaskRejectsToggleWithoutCreatingTransaction() throws {
        let fixture = makeLayerFixture(includeMasks: true)
        let viewModel = fixture.viewModel
        let index = try #require(viewModel.document.layers.firstIndex { $0.id == fixture.thumbnailLayerID })
        viewModel.document.layers[index].isLocked = true
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(!viewModel.toggleLayerMaskEnabled(layerID: fixture.thumbnailLayerID))
        #expect(!viewModel.toggleVectorMaskEnabled(layerID: fixture.thumbnailLayerID))
        #expect(!viewModel.toggleLayerMaskLinked(layerID: fixture.thumbnailLayerID))

        let target = try #require(viewModel.document.layers.first { $0.id == fixture.thumbnailLayerID })
        #expect(target.isMaskEnabled)
        #expect(target.isVectorMaskEnabled)
        #expect(target.isMaskLinked)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @Test func layerPanelWiresEachThumbnailToTheExplicitSelectionSource() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("loadSelectionFromLayerThumbnail(layer, source: .transparency)"))
        #expect(source.contains("handleLayerThumbnailGesture(layer, source: .rasterMask)"))
        #expect(source.contains("handleLayerThumbnailGesture(layer, source: .vectorMask)"))
        #expect(source.contains("viewModel.loadSelectionFromLayerTransparency(layerID: layer.id, mode: mode)"))
        #expect(source.contains("viewModel.loadSelectionFromLayerMask(layerID: layer.id, mode: mode)"))
        #expect(source.contains("viewModel.loadSelectionFromVectorMask(layerID: layer.id, mode: mode)"))
        #expect(source.contains("viewModel.toggleLayerMaskEnabled(layerID: layer.id)"))
        #expect(source.contains("viewModel.toggleVectorMaskEnabled(layerID: layer.id)"))
        #expect(source.contains("ImageEditorLayerThumbnailSelectionPolicy.previewsRasterMask("))
        #expect(source.contains("viewModel.toggleLayerMaskSoloPreview(layerID: layer.id)"))
        #expect(source.contains("ImageEditorLayerThumbnailSelectionPolicy.previewsRasterMaskAsRubylith("))
        #expect(source.contains("viewModel.toggleLayerMaskRubylithPreview(layerID: layer.id)"))
        #expect(source.contains("let isSelected = viewModel.previewedLayerMask == nil"))
        #expect(source.contains("viewModel.toggleLayerMaskLinked(layerID: layer.id)"))
        #expect(source.contains("if layer.mask == nil"))
        #expect(source.contains(".disabled(viewModel.document.isEffectivelyLocked(layer))"))
        #expect(source.contains("sidebarTab: viewModel.selectedLeftSidebarTab"))
        #expect(viewSource.contains("maskColorOverlay(in: geometry.size)"))
        #expect(viewSource.contains("viewModel.canvasMaskOverlayImage"))
        #expect(viewSource.contains("canToggleLayerMaskRubylith: viewModel.canToggleSelectedLayerMaskRubylithPreview"))
        #expect(viewSource.contains("case .toggleLayerMaskRubylith: viewModel.toggleSelectedLayerMaskRubylithPreview()"))
    }

    private func installSplitAlphaMask(
        in fixture: (viewModel: ImageEditorViewModel, thumbnailLayerID: UUID, canvasSize: CGSize)
    ) throws {
        let index = try #require(fixture.viewModel.document.layers.firstIndex {
            $0.id == fixture.thumbnailLayerID
        })
        let width = Int(fixture.canvasSize.width)
        let height = Int(fixture.canvasSize.height)
        let alpha = (0..<(width * height)).map { offset in
            offset % width < width / 2 ? UInt8.min : UInt8.max
        }
        fixture.viewModel.document.layers[index].mask = try #require(
            NSImage.alphaMaskImage(width: width, height: height, alpha: alpha)
        )
    }

    private func makeLayerFixture(includeMasks: Bool = false) -> (
        viewModel: ImageEditorViewModel,
        thumbnailLayerID: UUID,
        canvasSize: CGSize
    ) {
        let canvasSize = CGSize(width: 80, height: 60)
        let baseImage = image(size: canvasSize, background: .systemBlue)
        let viewModel = ImageEditorViewModel(sourceName: "thumbnail-selection.png", image: baseImage) { _ in }
        let selectedLayerID = viewModel.document.selectedLayerID

        var thumbnailLayer = ImageEditorLayer.blank(name: "Thumbnail Target", size: canvasSize)
        thumbnailLayer.image = image(
            size: canvasSize,
            background: .clear,
            foreground: .white,
            foregroundRect: CGRect(x: 18, y: 14, width: 30, height: 22)
        )
        if includeMasks {
            thumbnailLayer.mask = image(
                size: canvasSize,
                background: .black,
                foreground: .white,
                foregroundRect: CGRect(x: 12, y: 10, width: 38, height: 30)
            )
            thumbnailLayer.vectorMask = ImageEditorShapeContent(
                kind: .path,
                fillColor: .white,
                fillOpacity: 1,
                strokeColor: .white,
                strokeWidth: 1,
                strokeOpacity: 0,
                pathPoints: [
                    CGPoint(x: 20, y: 15),
                    CGPoint(x: 60, y: 18),
                    CGPoint(x: 42, y: 48)
                ],
                pathAnchors: [
                    ImageEditorPathAnchor(point: CGPoint(x: 20, y: 15)),
                    ImageEditorPathAnchor(point: CGPoint(x: 60, y: 18)),
                    ImageEditorPathAnchor(point: CGPoint(x: 42, y: 48))
                ],
                isPathClosed: true
            ).normalized(size: canvasSize)
        }
        viewModel.document.layers.append(thumbnailLayer)
        if let selectedLayerID {
            viewModel.selectLayer(selectedLayerID)
        }
        return (viewModel, thumbnailLayer.id, canvasSize)
    }

    private func image(
        size: CGSize,
        background: NSColor,
        foreground: NSColor? = nil,
        foregroundRect: CGRect = .zero
    ) -> NSImage {
        NSImage.rendered(size: size) { _ in
            background.setFill()
            CGRect(origin: .zero, size: size).fill()
            if let foreground {
                foreground.setFill()
                foregroundRect.fill()
            }
        } ?? NSImage.transparent(size: size)
    }
}
