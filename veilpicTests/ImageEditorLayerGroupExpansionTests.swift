//
//  ImageEditorLayerGroupExpansionTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerGroupExpansionTests {
    @Test func selectedGroupCommandsRecursivelyCollapseAndExpandNestedGroups() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel

        #expect(viewModel.canCollapseSelectedLayerGroups)
        #expect(!viewModel.canExpandSelectedLayerGroups)

        viewModel.collapseSelectedLayerGroups()

        #expect(groupExpansion(fixture.parentID, in: viewModel) == false)
        #expect(groupExpansion(fixture.childID, in: viewModel) == false)
        #expect(viewModel.visibleLayerRows.map(\.id) == [fixture.outsideID, fixture.parentID])
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerGroupsCollapsed", 2))
        #expect(viewModel.canExpandSelectedLayerGroups)
        #expect(!viewModel.canCollapseSelectedLayerGroups)

        viewModel.expandSelectedLayerGroups()

        #expect(groupExpansion(fixture.parentID, in: viewModel) == true)
        #expect(groupExpansion(fixture.childID, in: viewModel) == true)
        #expect(viewModel.visibleLayerRows.map(\.id) == [
            fixture.outsideID,
            fixture.parentID,
            fixture.childID,
            fixture.leafID
        ])
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerGroupsExpanded", 2))
    }

    @Test func collapsingSelectionKeepsVisiblePeersAndReplacesHiddenMembersWithGroup() {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel
        viewModel.document.selectedLayerIDs = [fixture.parentID, fixture.leafID, fixture.outsideID]
        viewModel.document.selectedLayerID = fixture.leafID

        viewModel.collapseSelectedLayerGroups()

        #expect(viewModel.document.selectedLayerIDs == [fixture.parentID, fixture.outsideID])
        #expect(viewModel.document.selectedLayerID == fixture.outsideID)
        #expect(!viewModel.document.selectedLayerIDs.contains(fixture.leafID))
    }

    @Test func ordinaryDisclosureChangesOneGroupWhileRecursiveDisclosureChangesWholeBranch() throws {
        let fixture = makeFixture()
        let viewModel = fixture.viewModel

        viewModel.toggleLayerGroupExpansion(fixture.parentID)
        #expect(groupExpansion(fixture.parentID, in: viewModel) == false)
        #expect(groupExpansion(fixture.childID, in: viewModel) == true)

        viewModel.toggleLayerGroupExpansion(fixture.parentID)
        let childIndex = try #require(viewModel.document.layers.firstIndex { $0.id == fixture.childID })
        viewModel.document.layers[childIndex].isGroupExpanded = false
        viewModel.toggleLayerGroupExpansion(fixture.parentID, recursively: true)
        #expect(groupExpansion(fixture.parentID, in: viewModel) == false)
        #expect(groupExpansion(fixture.childID, in: viewModel) == false)

        viewModel.toggleLayerGroupExpansion(fixture.parentID, recursively: true)
        #expect(groupExpansion(fixture.parentID, in: viewModel) == true)
        #expect(groupExpansion(fixture.childID, in: viewModel) == true)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layerGroupsExpanded", 2))
    }

    @Test func panelAndLayerMenuExposeRecursiveGroupExpansionCommands() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let panel = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )
        let menu = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )

        #expect(panel.contains("NSEvent.modifierFlags.contains(.option)"))
        #expect(panel.contains("viewModel.expandSelectedLayerGroups()"))
        #expect(panel.contains("viewModel.collapseSelectedLayerGroups()"))
        #expect(menu.contains("viewModel.expandSelectedLayerGroups()"))
        #expect(menu.contains("viewModel.collapseSelectedLayerGroups()"))
    }

    private struct Fixture {
        let viewModel: ImageEditorViewModel
        let parentID: UUID
        let childID: UUID
        let leafID: UUID
        let outsideID: UUID
    }

    private func makeFixture() -> Fixture {
        let canvasSize = CGSize(width: 160, height: 100)
        let viewModel = ImageEditorViewModel(
            sourceName: "group-expansion.png",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        var parent = ImageEditorLayer.group(name: "Parent", size: canvasSize)
        var child = ImageEditorLayer.group(name: "Child", size: canvasSize)
        var leaf = ImageEditorLayer.blank(name: "Leaf", size: canvasSize)
        let outside = ImageEditorLayer.blank(name: "Outside", size: canvasSize)
        child.groupID = parent.id
        leaf.groupID = child.id
        parent.isGroupExpanded = true
        child.isGroupExpanded = true
        viewModel.document.layers = [leaf, child, parent, outside]
        viewModel.document.selectedLayerID = parent.id
        viewModel.document.selectedLayerIDs = [parent.id]
        return Fixture(
            viewModel: viewModel,
            parentID: parent.id,
            childID: child.id,
            leafID: leaf.id,
            outsideID: outside.id
        )
    }

    private func groupExpansion(_ id: UUID, in viewModel: ImageEditorViewModel) -> Bool? {
        viewModel.document.layers.first { $0.id == id }?.isGroupExpanded
    }
}
