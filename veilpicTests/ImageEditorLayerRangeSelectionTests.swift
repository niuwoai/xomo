//
//  ImageEditorLayerRangeSelectionTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerRangeSelectionTests {
    @Test func shiftRangeSelectsEveryVisibleLayerBetweenAnchorAndTarget() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectLayer(fixture.layers[1].id)

        viewModel.selectLayerRange(
            to: fixture.layers[4].id,
            among: fixture.layers.map(\.id)
        )

        #expect(viewModel.document.selectedLayerIDs == Set(fixture.layers[1...4].map(\.id)))
        #expect(viewModel.document.selectedLayerID == fixture.layers[4].id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerRangeSelected", 4))
    }

    @Test func shiftRangeWorksInReverseAndPreservesItsOriginalAnchor() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectLayer(fixture.layers[4].id)

        viewModel.selectLayerRange(
            to: fixture.layers[2].id,
            among: fixture.layers.map(\.id)
        )
        viewModel.selectLayerRange(
            to: fixture.layers[1].id,
            among: fixture.layers.map(\.id)
        )

        #expect(viewModel.document.selectedLayerIDs == Set(fixture.layers[1...4].map(\.id)))
        #expect(viewModel.document.selectedLayerID == fixture.layers[1].id)
    }

    @Test func commandShiftAddsRangeToExistingDisjointSelection() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectLayer(fixture.layers[0].id)
        viewModel.selectLayer(fixture.layers[2].id, extendingSelection: true)

        viewModel.selectLayerRange(
            to: fixture.layers[4].id,
            among: fixture.layers.map(\.id),
            addingToSelection: true
        )

        #expect(viewModel.document.selectedLayerIDs == Set([
            fixture.layers[0].id,
            fixture.layers[2].id,
            fixture.layers[3].id,
            fixture.layers[4].id
        ]))
        #expect(viewModel.document.selectedLayerID == fixture.layers[4].id)
    }

    @Test func rangeUsesOnlyRowsCurrentlyVisibleInFilteredOrCollapsedPanel() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let panelRows = [fixture.layers[4].id, fixture.layers[2].id, fixture.layers[0].id]
        viewModel.selectLayer(fixture.layers[2].id)

        viewModel.selectLayerRange(to: fixture.layers[0].id, among: panelRows)

        #expect(viewModel.document.selectedLayerIDs == Set([
            fixture.layers[2].id,
            fixture.layers[0].id
        ]))
        #expect(!viewModel.document.selectedLayerIDs.contains(fixture.layers[1].id))
        #expect(!viewModel.document.selectedLayerIDs.contains(fixture.layers[3].id))
    }

    @Test func clearingSelectionAlsoClearsTheRangeAnchor() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectLayer(fixture.layers[1].id)
        viewModel.clearLayerSelection()

        viewModel.selectLayerRange(
            to: fixture.layers[4].id,
            among: fixture.layers.map(\.id)
        )

        #expect(viewModel.document.selectedLayerIDs == [fixture.layers[4].id])
        #expect(viewModel.document.selectedLayerID == fixture.layers[4].id)
    }

    @Test func layerPanelMapsShiftAndCommandToDifferentSelectionBehaviors() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )

        #expect(source.contains("if flags.contains(.shift)"))
        #expect(source.contains("viewModel.selectLayerRange("))
        #expect(source.contains("addingToSelection: flags.contains(.command)"))
        #expect(source.contains("extendingSelection: flags.contains(.command)"))
        #expect(source.contains("Button {"))
        #expect(source.contains("selectLayerFromPanel(layer)"))
        #expect(source.contains(".focusable(false)"))
        #expect(source.contains("image-editor-layer-content-\\(layer.id.uuidString)"))
        #expect(!source.contains("flags.contains(.command) || flags.contains(.shift)"))
    }

    @Test func classicLayerSelectionShortcutsResolveWithoutChangingReorderShortcuts() {
        let cases: [(String, NSEvent.ModifierFlags, ImageEditorKeyboardShortcutAction)] = [
            ("a", [.command, .option], .selectAllLayers),
            ("]", [.option], .navigateLayerSelection(.above(extendingSelection: false))),
            ("[", [.option], .navigateLayerSelection(.below(extendingSelection: false))),
            ("]", [.option, .shift], .navigateLayerSelection(.above(extendingSelection: true))),
            ("[", [.option, .shift], .navigateLayerSelection(.below(extendingSelection: true))),
            (".", [.option], .navigateLayerSelection(.top)),
            (",", [.option], .navigateLayerSelection(.bottom)),
            ("]", [.command], .layerUp),
            ("[", [.command], .layerDown)
        ]

        for (key, flags, expected) in cases {
            let action = ImageEditorKeyboardShortcutAction.resolve(
                charactersIgnoringModifiers: key,
                modifierFlags: flags
            )
            #expect(action == expected)
            #expect(action?.isBlockedByTextInput == true)
        }
    }

    @Test func workspaceSelectAllUsesEveryLayerWithoutHistoryInToolsMode() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        viewModel.selectLayer(fixture.layers[2].id)

        #expect(viewModel.canSelectAllWorkspaceObjects)
        #expect(viewModel.selectAllWorkspaceObjects())
        #expect(viewModel.document.selectedLayerIDs == Set(fixture.layers.map(\.id)))
        #expect(viewModel.document.selectedLayerID == fixture.layers.last?.id)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(!viewModel.canSelectAllWorkspaceObjects)
        #expect(!viewModel.selectAllWorkspaceObjects())
    }

    @Test func pendingPenAndContinuousMovesBlockWorkspaceSelectAll() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectLayer(fixture.layers[1].id)
        let originalSelection = viewModel.document.selectedLayerIDs

        viewModel.pendingPenPathPoints = [CGPoint(x: 12, y: 8)]
        #expect(!viewModel.canSelectAllWorkspaceObjects)
        #expect(!viewModel.selectAllWorkspaceObjects())
        #expect(viewModel.document.selectedLayerIDs == originalSelection)

        viewModel.pendingPenPathPoints = []
        #expect(viewModel.beginMovingSelectedLayer())
        #expect(!viewModel.canSelectAllWorkspaceObjects)
        #expect(!viewModel.selectAllWorkspaceObjects())
        #expect(viewModel.document.selectedLayerIDs == originalSelection)
        #expect(viewModel.cancelMovingSelectedLayer())
    }

    @Test func workspaceSelectAllShortcutAndMenuUseTheContextualModel() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorView.swift"),
            encoding: .utf8
        )
        let menuSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )

        #expect(viewSource.contains("case .selectAllLayers: viewModel.selectAllWorkspaceObjects()"))
        #expect(menuSource.contains("viewModel.selectAllWorkspaceObjects()"))
        #expect(menuSource.contains("viewModel.canSelectAllWorkspaceObjects"))
        #expect(menuSource.contains("xomo.object.action.selectAll"))
    }

    @Test func keyboardNavigationSelectsAdjacentAndBoundaryLayersWithoutHistory() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count
        viewModel.selectLayer(fixture.layers[2].id)

        #expect(viewModel.navigateLayerSelection(.above(extendingSelection: false)))
        #expect(viewModel.document.selectedLayerID == fixture.layers[3].id)
        viewModel.selectLayer(fixture.layers[2].id)
        #expect(viewModel.navigateLayerSelection(.below(extendingSelection: false)))
        #expect(viewModel.document.selectedLayerID == fixture.layers[1].id)
        #expect(viewModel.navigateLayerSelection(.top))
        #expect(viewModel.document.selectedLayerID == fixture.layers[4].id)
        #expect(viewModel.navigateLayerSelection(.bottom))
        #expect(viewModel.document.selectedLayerID == fixture.layers[0].id)

        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
    }

    @Test func extendingKeyboardNavigationAddsButNeverTogglesExistingLayersOff() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.selectLayer(fixture.layers[2].id)

        #expect(viewModel.navigateLayerSelection(.above(extendingSelection: true)))
        #expect(viewModel.navigateLayerSelection(.above(extendingSelection: true)))
        #expect(viewModel.document.selectedLayerIDs == Set(fixture.layers[2...4].map(\.id)))

        #expect(!viewModel.navigateLayerSelection(.below(extendingSelection: true)))
        #expect(viewModel.document.selectedLayerIDs == Set(fixture.layers[2...4].map(\.id)))
        #expect(viewModel.document.selectedLayerID == fixture.layers[4].id)
    }

    @Test func collapsedDescendantNavigationUsesNearestVisibleGroupAndIncludesHiddenRows() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        var group = ImageEditorLayer.group(name: "Collapsed", size: viewModel.document.canvasSize)
        group.isGroupExpanded = false
        var child = fixture.layers[2]
        child.groupID = group.id
        var hiddenAbove = fixture.layers[3]
        hiddenAbove.isVisible = false
        let below = fixture.layers[1]
        viewModel.document.layers = [below, child, group, hiddenAbove]

        viewModel.selectLayer(child.id)
        #expect(viewModel.navigateLayerSelection(.above(extendingSelection: false)))
        #expect(viewModel.document.selectedLayerID == hiddenAbove.id)

        viewModel.selectLayer(child.id)
        #expect(viewModel.navigateLayerSelection(.below(extendingSelection: false)))
        #expect(viewModel.document.selectedLayerID == below.id)
    }

    @Test func componentAndContinuousPathOrLayerTransactionsOwnLayerNavigation() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        let originalSelection = viewModel.document.selectedLayerIDs

        viewModel.selectedLeftSidebarTab = .components
        #expect(!viewModel.navigateLayerSelection(.top))
        #expect(viewModel.document.selectedLayerIDs == originalSelection)

        viewModel.selectedLeftSidebarTab = .tools
        viewModel.pendingPenPathPoints = [CGPoint(x: 12, y: 8)]
        #expect(!viewModel.navigateLayerSelection(.top))
        #expect(viewModel.document.selectedLayerIDs == originalSelection)

        viewModel.pendingPenPathPoints = []
        #expect(viewModel.beginMovingSelectedLayer())
        #expect(!viewModel.navigateLayerSelection(.top))
        #expect(viewModel.document.selectedLayerIDs == originalSelection)
        #expect(viewModel.cancelMovingSelectedLayer())
    }

    private struct Fixture {
        let viewModel: ImageEditorViewModel
        let layers: [ImageEditorLayer]
    }

    private func makeFixture() -> Fixture {
        let canvasSize = CGSize(width: 120, height: 80)
        let viewModel = ImageEditorViewModel(
            sourceName: "layer-range.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        let layers = (1...5).map { index in
            ImageEditorLayer.solidColorFill(
                name: "Layer \(index)",
                size: canvasSize,
                content: ImageEditorSolidColorFillContent(
                    red: Double(index) / 10,
                    green: 0.4,
                    blue: 0.6
                )
            )
        }
        viewModel.document.layers = layers
        viewModel.document.selectedLayerID = layers[0].id
        viewModel.document.selectedLayerIDs = [layers[0].id]
        return Fixture(viewModel: viewModel, layers: layers)
    }
}
