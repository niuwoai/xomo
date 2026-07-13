//
//  ImageEditorLayerGroupMovementConsistencyTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerGroupMovementConsistencyTests {
    @Test func movingNoncontiguousSelectionIntoGroupCollectsCompleteSubtrees() {
        let viewModel = makeViewModel()
        var movingChild = layer("Moving Child", in: viewModel)
        let movingGroup = ImageEditorLayer.group(name: "Moving Group", size: viewModel.document.canvasSize)
        let gap = layer("Gap", in: viewModel)
        var locked = layer("Locked", in: viewModel)
        let top = layer("Top", in: viewModel)
        var existingMember = layer("Existing", in: viewModel)
        var targetGroup = ImageEditorLayer.group(name: "Target", size: viewModel.document.canvasSize)
        let ceiling = layer("Ceiling", in: viewModel)
        movingChild.groupID = movingGroup.id
        existingMember.groupID = targetGroup.id
        locked.isLocked = true
        targetGroup.isGroupExpanded = false
        viewModel.document.layers = [
            movingChild,
            movingGroup,
            gap,
            locked,
            top,
            existingMember,
            targetGroup,
            ceiling
        ]
        select([movingGroup.id, locked.id, top.id], primary: top.id, in: viewModel)
        let originalOrder = viewModel.document.layers.map(\.id)
        let originalSelection = viewModel.document.selectedLayerIDs
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canMoveSelectedLayersIntoGroup)
        viewModel.moveSelectedLayersIntoGroup()

        #expect(viewModel.document.layers.map(\.id) == [
            gap.id,
            locked.id,
            existingMember.id,
            movingChild.id,
            movingGroup.id,
            top.id,
            targetGroup.id,
            ceiling.id
        ])
        #expect(viewModel.document.layers.first { $0.id == movingChild.id }?.groupID == movingGroup.id)
        #expect(viewModel.document.layers.first { $0.id == movingGroup.id }?.groupID == targetGroup.id)
        #expect(viewModel.document.layers.first { $0.id == top.id }?.groupID == targetGroup.id)
        #expect(viewModel.document.layers.first { $0.id == locked.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == targetGroup.id }?.isGroupExpanded == true)
        #expect(viewModel.document.selectedLayerIDs == originalSelection)
        #expect(viewModel.document.selectedLayerID == top.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalOrder)
        #expect(viewModel.document.layers.first { $0.id == targetGroup.id }?.isGroupExpanded == false)
        #expect(viewModel.document.selectedLayerIDs == originalSelection)
    }

    @Test func movingIntoGroupRejectsEditableRootsFromDifferentParents() {
        let viewModel = makeViewModel()
        let outside = layer("Outside", in: viewModel)
        var nested = layer("Nested", in: viewModel)
        let nestedGroup = ImageEditorLayer.group(name: "Nested Group", size: viewModel.document.canvasSize)
        let targetGroup = ImageEditorLayer.group(name: "Target", size: viewModel.document.canvasSize)
        nested.groupID = nestedGroup.id
        viewModel.document.layers = [outside, nested, nestedGroup, targetGroup]
        select([outside.id, nested.id], primary: nested.id, in: viewModel)
        let originalOrder = viewModel.document.layers.map(\.id)
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.canMoveSelectedLayersIntoGroup)
        viewModel.moveSelectedLayersIntoGroup()

        #expect(viewModel.document.layers.map(\.id) == originalOrder)
        #expect(viewModel.document.layers.first { $0.id == outside.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == nested.id }?.groupID == nestedGroup.id)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func movingOutOfGroupPlacesCompleteSubtreesAfterParentHeader() {
        let viewModel = makeViewModel()
        var low = layer("Low", in: viewModel)
        var subtreeChild = layer("Subtree Child", in: viewModel)
        var subtreeGroup = ImageEditorLayer.group(name: "Subtree", size: viewModel.document.canvasSize)
        var gap = layer("Gap", in: viewModel)
        var high = layer("High", in: viewModel)
        let parentGroup = ImageEditorLayer.group(name: "Parent", size: viewModel.document.canvasSize)
        let ceiling = layer("Ceiling", in: viewModel)
        low.groupID = parentGroup.id
        subtreeChild.groupID = subtreeGroup.id
        subtreeGroup.groupID = parentGroup.id
        gap.groupID = parentGroup.id
        high.groupID = parentGroup.id
        viewModel.document.layers = [
            low,
            subtreeChild,
            subtreeGroup,
            gap,
            high,
            parentGroup,
            ceiling
        ]
        select([low.id, subtreeGroup.id, high.id], primary: high.id, in: viewModel)
        let originalOrder = viewModel.document.layers.map(\.id)
        let originalSelection = viewModel.document.selectedLayerIDs

        #expect(viewModel.canMoveSelectedLayersOutOfGroup)
        viewModel.moveSelectedLayersOutOfGroup()

        #expect(viewModel.document.layers.map(\.id) == [
            gap.id,
            parentGroup.id,
            low.id,
            subtreeChild.id,
            subtreeGroup.id,
            high.id,
            ceiling.id
        ])
        #expect(viewModel.document.layers.first { $0.id == low.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == subtreeGroup.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == subtreeChild.id }?.groupID == subtreeGroup.id)
        #expect(viewModel.document.layers.first { $0.id == high.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == gap.id }?.groupID == parentGroup.id)
        #expect(viewModel.document.selectedLayerIDs == originalSelection)

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalOrder)
        #expect(viewModel.document.layers.first { $0.id == low.id }?.groupID == parentGroup.id)
        #expect(viewModel.document.layers.first { $0.id == subtreeGroup.id }?.groupID == parentGroup.id)
        #expect(viewModel.document.layers.first { $0.id == high.id }?.groupID == parentGroup.id)
    }

    @Test func movingOutOfMultipleNestedParentsUsesEachVisualBoundary() {
        let viewModel = makeViewModel()
        var innerSelected = layer("Inner Selected", in: viewModel)
        var innerGroup = ImageEditorLayer.group(name: "Inner", size: viewModel.document.canvasSize)
        var outerSelected = layer("Outer Selected", in: viewModel)
        let outerGroup = ImageEditorLayer.group(name: "Outer", size: viewModel.document.canvasSize)
        var siblingSelected = layer("Sibling Selected", in: viewModel)
        let siblingGroup = ImageEditorLayer.group(name: "Sibling", size: viewModel.document.canvasSize)
        let ceiling = layer("Ceiling", in: viewModel)
        innerSelected.groupID = innerGroup.id
        innerGroup.groupID = outerGroup.id
        outerSelected.groupID = outerGroup.id
        siblingSelected.groupID = siblingGroup.id
        viewModel.document.layers = [
            innerSelected,
            innerGroup,
            outerSelected,
            outerGroup,
            siblingSelected,
            siblingGroup,
            ceiling
        ]
        select(
            [innerSelected.id, outerSelected.id, siblingSelected.id],
            primary: siblingSelected.id,
            in: viewModel
        )

        viewModel.moveSelectedLayersOutOfGroup()

        #expect(viewModel.document.layers.map(\.id) == [
            innerGroup.id,
            innerSelected.id,
            outerGroup.id,
            outerSelected.id,
            siblingGroup.id,
            siblingSelected.id,
            ceiling.id
        ])
        #expect(viewModel.document.layers.first { $0.id == innerSelected.id }?.groupID == outerGroup.id)
        #expect(viewModel.document.layers.first { $0.id == outerSelected.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == siblingSelected.id }?.groupID == nil)
    }

    @Test func movingOutSkipsLockedSelectionAndKeepsItInsideGroup() {
        let viewModel = makeViewModel()
        var editable = layer("Editable", in: viewModel)
        var locked = layer("Locked", in: viewModel)
        let parentGroup = ImageEditorLayer.group(name: "Parent", size: viewModel.document.canvasSize)
        let ceiling = layer("Ceiling", in: viewModel)
        editable.groupID = parentGroup.id
        locked.groupID = parentGroup.id
        locked.isLocked = true
        viewModel.document.layers = [editable, locked, parentGroup, ceiling]
        select([editable.id, locked.id], primary: locked.id, in: viewModel)

        #expect(viewModel.canMoveSelectedLayersOutOfGroup)
        viewModel.moveSelectedLayersOutOfGroup()

        #expect(viewModel.document.layers.map(\.id) == [
            locked.id,
            parentGroup.id,
            editable.id,
            ceiling.id
        ])
        #expect(viewModel.document.layers.first { $0.id == editable.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == locked.id }?.groupID == parentGroup.id)
        #expect(viewModel.document.selectedLayerIDs == Set([editable.id, locked.id]))
        #expect(viewModel.document.selectedLayerID == locked.id)
    }

    @Test func selectedGroupMovesOutOnceWithItsSelectedDescendant() {
        let viewModel = makeViewModel()
        var child = layer("Child", in: viewModel)
        var movingGroup = ImageEditorLayer.group(name: "Moving", size: viewModel.document.canvasSize)
        let containerGroup = ImageEditorLayer.group(name: "Container", size: viewModel.document.canvasSize)
        let ceiling = layer("Ceiling", in: viewModel)
        child.groupID = movingGroup.id
        movingGroup.groupID = containerGroup.id
        viewModel.document.layers = [child, movingGroup, containerGroup, ceiling]
        select([child.id, movingGroup.id], primary: child.id, in: viewModel)

        viewModel.moveSelectedLayersOutOfGroup()

        #expect(viewModel.document.layers.map(\.id) == [
            containerGroup.id,
            child.id,
            movingGroup.id,
            ceiling.id
        ])
        #expect(viewModel.document.layers.first { $0.id == movingGroup.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == child.id }?.groupID == movingGroup.id)
        #expect(viewModel.document.layers.filter { $0.id == child.id }.count == 1)
        #expect(viewModel.document.selectedLayerIDs == Set([child.id, movingGroup.id]))
        #expect(viewModel.document.selectedLayerID == child.id)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        let image = NSImage(size: NSSize(width: 120, height: 90))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()
        return ImageEditorViewModel(sourceName: "group-movement.png", image: image) { _ in }
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
