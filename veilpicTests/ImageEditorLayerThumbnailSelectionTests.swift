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

    @Test func lockedClickedMaskRejectsToggleWithoutCreatingTransaction() throws {
        let fixture = makeLayerFixture(includeMasks: true)
        let viewModel = fixture.viewModel
        let index = try #require(viewModel.document.layers.firstIndex { $0.id == fixture.thumbnailLayerID })
        viewModel.document.layers[index].isLocked = true
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(!viewModel.toggleLayerMaskEnabled(layerID: fixture.thumbnailLayerID))
        #expect(!viewModel.toggleVectorMaskEnabled(layerID: fixture.thumbnailLayerID))

        let target = try #require(viewModel.document.layers.first { $0.id == fixture.thumbnailLayerID })
        #expect(target.isMaskEnabled)
        #expect(target.isVectorMaskEnabled)
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

        #expect(source.contains("loadSelectionFromLayerThumbnail(layer, source: .transparency)"))
        #expect(source.contains("handleLayerThumbnailGesture(layer, source: .rasterMask)"))
        #expect(source.contains("handleLayerThumbnailGesture(layer, source: .vectorMask)"))
        #expect(source.contains("viewModel.loadSelectionFromLayerTransparency(layerID: layer.id, mode: mode)"))
        #expect(source.contains("viewModel.loadSelectionFromLayerMask(layerID: layer.id, mode: mode)"))
        #expect(source.contains("viewModel.loadSelectionFromVectorMask(layerID: layer.id, mode: mode)"))
        #expect(source.contains("viewModel.toggleLayerMaskEnabled(layerID: layer.id)"))
        #expect(source.contains("viewModel.toggleVectorMaskEnabled(layerID: layer.id)"))
        #expect(source.contains("sidebarTab: viewModel.selectedLeftSidebarTab"))
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
