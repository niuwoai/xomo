//
//  ImageEditorLayerGroupingConsistencyTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerGroupingConsistencyTests {
    @Test func groupingNoncontiguousSiblingsCreatesOneContiguousSubtree() throws {
        let viewModel = makeViewModel()
        let bottom = layer("Bottom", in: viewModel)
        let gap = layer("Gap", in: viewModel)
        let top = layer("Top", in: viewModel)
        let ceiling = layer("Ceiling", in: viewModel)
        viewModel.document.layers = [bottom, gap, top, ceiling]
        select([bottom.id, top.id], primary: top.id, in: viewModel)
        let originalOrder = viewModel.document.layers.map(\.id)
        let originalSelection = viewModel.document.selectedLayerIDs
        let historyCount = viewModel.document.history.count

        viewModel.groupSelectedLayer()

        let group = try #require(viewModel.document.selectedLayer)
        #expect(group.isGroup)
        #expect(viewModel.document.layers.map(\.id) == [
            gap.id,
            bottom.id,
            top.id,
            group.id,
            ceiling.id
        ])
        #expect(viewModel.document.layers.first { $0.id == bottom.id }?.groupID == group.id)
        #expect(viewModel.document.layers.first { $0.id == top.id }?.groupID == group.id)
        #expect(viewModel.document.layers.first { $0.id == gap.id }?.groupID == nil)
        #expect(viewModel.document.selectedLayerIDs == Set([group.id]))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGroupSelected"))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalOrder)
        #expect(viewModel.document.selectedLayerIDs == originalSelection)
    }

    @Test func groupingSkipsLockedLayersAndKeepsThemSelected() throws {
        let viewModel = makeViewModel()
        let bottom = layer("Bottom", in: viewModel)
        var locked = layer("Locked", in: viewModel)
        let top = layer("Top", in: viewModel)
        locked.isLocked = true
        viewModel.document.layers = [bottom, locked, top]
        select([bottom.id, locked.id, top.id], primary: top.id, in: viewModel)

        #expect(viewModel.canGroupSelectedLayer)
        viewModel.groupSelectedLayer()

        let groupID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.document.layers.map(\.id) == [locked.id, bottom.id, top.id, groupID])
        #expect(viewModel.document.layers.first { $0.id == locked.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == bottom.id }?.groupID == groupID)
        #expect(viewModel.document.layers.first { $0.id == top.id }?.groupID == groupID)
        #expect(viewModel.document.selectedLayerIDs == Set([locked.id, groupID]))
        #expect(viewModel.document.selectedLayerID == groupID)
    }

    @Test func groupingInsideNestedParentPreservesParentAndRelativeOrder() throws {
        let viewModel = makeViewModel()
        let outside = layer("Outside", in: viewModel)
        var lowChild = layer("Low Child", in: viewModel)
        var gapChild = layer("Gap Child", in: viewModel)
        var highChild = layer("High Child", in: viewModel)
        let parent = ImageEditorLayer.group(name: "Parent", size: viewModel.document.canvasSize)
        let ceiling = layer("Ceiling", in: viewModel)
        lowChild.groupID = parent.id
        gapChild.groupID = parent.id
        highChild.groupID = parent.id
        viewModel.document.layers = [outside, lowChild, gapChild, highChild, parent, ceiling]
        select([lowChild.id, highChild.id], primary: highChild.id, in: viewModel)

        viewModel.groupSelectedLayer()

        let nestedGroupID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.document.layers.map(\.id) == [
            outside.id,
            gapChild.id,
            lowChild.id,
            highChild.id,
            nestedGroupID,
            parent.id,
            ceiling.id
        ])
        #expect(viewModel.document.layers.first { $0.id == nestedGroupID }?.groupID == parent.id)
        #expect(viewModel.document.layers.first { $0.id == lowChild.id }?.groupID == nestedGroupID)
        #expect(viewModel.document.layers.first { $0.id == highChild.id }?.groupID == nestedGroupID)
        #expect(viewModel.document.layers.first { $0.id == gapChild.id }?.groupID == parent.id)
    }

    @Test func selectedDescendantIsExtractedBesideItsSelectedGroupWithoutDuplication() throws {
        let viewModel = makeViewModel()
        var child = layer("Child", in: viewModel)
        let childGroup = ImageEditorLayer.group(name: "Child Group", size: viewModel.document.canvasSize)
        let sibling = layer("Sibling", in: viewModel)
        child.groupID = childGroup.id
        viewModel.document.layers = [child, childGroup, sibling]
        select([child.id, childGroup.id, sibling.id], primary: sibling.id, in: viewModel)

        viewModel.groupSelectedLayer()

        let parentGroupID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.document.layers.map(\.id) == [child.id, childGroup.id, sibling.id, parentGroupID])
        #expect(viewModel.document.layers.first { $0.id == child.id }?.groupID == parentGroupID)
        #expect(viewModel.document.layers.first { $0.id == childGroup.id }?.groupID == parentGroupID)
        #expect(viewModel.document.layers.first { $0.id == sibling.id }?.groupID == parentGroupID)
        #expect(viewModel.document.layers.filter { $0.id == child.id }.count == 1)
    }

    @Test func groupingRejectsEditableLayersFromUnrelatedParents() {
        let viewModel = makeViewModel()
        var leftChild = layer("Left Child", in: viewModel)
        let leftGroup = ImageEditorLayer.group(name: "Left Group", size: viewModel.document.canvasSize)
        var rightChild = layer("Right Child", in: viewModel)
        let rightGroup = ImageEditorLayer.group(name: "Right Group", size: viewModel.document.canvasSize)
        leftChild.groupID = leftGroup.id
        rightChild.groupID = rightGroup.id
        viewModel.document.layers = [leftChild, leftGroup, rightChild, rightGroup]
        select([leftChild.id, rightChild.id], primary: rightChild.id, in: viewModel)
        let originalOrder = viewModel.document.layers.map(\.id)
        let originalParents = Dictionary(uniqueKeysWithValues: viewModel.document.layers.map { ($0.id, $0.groupID) })
        let originalHistoryCount = viewModel.document.history.count

        #expect(!viewModel.canGroupSelectedLayer)
        viewModel.groupSelectedLayer()

        #expect(viewModel.document.layers.map(\.id) == originalOrder)
        #expect(viewModel.document.layers.allSatisfy { $0.groupID == originalParents[$0.id] })
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.document.selectedLayerIDs == Set([leftChild.id, rightChild.id]))
    }

    @Test func ungroupingNestedSelectionPreservesUnaffectedAndLockedSelection() {
        let viewModel = makeViewModel()
        var nestedMember = layer("Nested Member", in: viewModel)
        var childGroup = ImageEditorLayer.group(name: "Child Group", size: viewModel.document.canvasSize)
        var looseMember = layer("Loose Member", in: viewModel)
        let parentGroup = ImageEditorLayer.group(name: "Parent Group", size: viewModel.document.canvasSize)
        let unrelated = layer("Unrelated", in: viewModel)
        var lockedGroup = ImageEditorLayer.group(name: "Locked Group", size: viewModel.document.canvasSize)
        nestedMember.groupID = childGroup.id
        childGroup.groupID = parentGroup.id
        looseMember.groupID = parentGroup.id
        lockedGroup.isLocked = true
        viewModel.document.layers = [
            nestedMember,
            childGroup,
            looseMember,
            parentGroup,
            unrelated,
            lockedGroup
        ]
        select(
            [parentGroup.id, childGroup.id, unrelated.id, lockedGroup.id],
            primary: unrelated.id,
            in: viewModel
        )
        let originalOrder = viewModel.document.layers.map(\.id)
        let originalParents = Dictionary(uniqueKeysWithValues: viewModel.document.layers.map { ($0.id, $0.groupID) })
        let originalSelection = viewModel.document.selectedLayerIDs
        let historyCount = viewModel.document.history.count

        viewModel.ungroupSelectedLayers()

        #expect(viewModel.document.layers.map(\.id) == [
            nestedMember.id,
            looseMember.id,
            unrelated.id,
            lockedGroup.id
        ])
        #expect(viewModel.document.layers.first { $0.id == nestedMember.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == looseMember.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == lockedGroup.id }?.isGroup == true)
        #expect(viewModel.document.selectedLayerIDs == Set([
            nestedMember.id,
            looseMember.id,
            unrelated.id,
            lockedGroup.id
        ]))
        #expect(viewModel.document.selectedLayerID == unrelated.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalOrder)
        #expect(viewModel.document.layers.allSatisfy { $0.groupID == originalParents[$0.id] })
        #expect(viewModel.document.selectedLayerIDs == originalSelection)
        #expect(viewModel.document.selectedLayerID == unrelated.id)
    }

    @Test func ungroupingCollapsedGroupRevealsMembersAndUndoRestoresViewState() {
        let viewModel = makeViewModel()
        var lowMember = layer("Low", in: viewModel)
        var highMember = layer("High", in: viewModel)
        var group = ImageEditorLayer.group(name: "Collapsed", size: viewModel.document.canvasSize)
        lowMember.groupID = group.id
        highMember.groupID = group.id
        group.isGroupExpanded = false
        viewModel.document.layers = [lowMember, highMember, group]
        select([group.id], primary: group.id, in: viewModel)

        #expect(viewModel.visibleLayerRows.map(\.id) == [group.id])
        viewModel.ungroupSelectedLayers()

        #expect(viewModel.document.layers.map(\.id) == [lowMember.id, highMember.id])
        #expect(viewModel.document.selectedLayerIDs == Set([lowMember.id, highMember.id]))
        #expect(viewModel.visibleLayerRows.map(\.id) == [highMember.id, lowMember.id])

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == [lowMember.id, highMember.id, group.id])
        #expect(viewModel.document.layers.first { $0.id == group.id }?.isGroupExpanded == false)
        #expect(viewModel.document.selectedLayerIDs == [group.id])
    }

    private func makeViewModel() -> ImageEditorViewModel {
        let image = NSImage(size: NSSize(width: 120, height: 90))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()
        return ImageEditorViewModel(sourceName: "grouping.png", image: image) { _ in }
    }

    private func layer(_ name: String, in viewModel: ImageEditorViewModel) -> ImageEditorLayer {
        ImageEditorLayer.blank(name: name, size: viewModel.document.canvasSize)
    }

    private func select(
        _ ids: Set<UUID>,
        primary: UUID,
        in viewModel: ImageEditorViewModel
    ) {
        viewModel.document.selectedLayerIDs = ids
        viewModel.document.selectedLayerID = primary
    }
}
