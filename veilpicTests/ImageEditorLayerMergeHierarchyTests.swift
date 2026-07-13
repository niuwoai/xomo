//
//  ImageEditorLayerMergeHierarchyTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/13.
//

import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerMergeHierarchyTests {
    @Test func mergeDownRejectsAnArrayNeighborFromAnotherParent() {
        let viewModel = makeViewModel()
        let unrelatedRoot = layer("Unrelated Root", in: viewModel)
        var firstChild = layer("First Child", in: viewModel)
        let group = ImageEditorLayer.group(name: "Group", size: viewModel.document.canvasSize)
        firstChild.groupID = group.id
        viewModel.document.layers = [unrelatedRoot, firstChild, group]
        select([firstChild.id], primary: firstChild.id, in: viewModel)
        let originalIDs = viewModel.document.layers.map(\.id)
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.canMergeSelectedLayerDown)
        viewModel.mergeSelectedLayerDown()

        #expect(viewModel.document.layers.map(\.id) == originalIDs)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func mergeDownUsesTheImmediateSiblingInsideTheSameGroup() throws {
        let viewModel = makeViewModel()
        var lower = layer("Lower", in: viewModel)
        var upper = layer("Upper", in: viewModel)
        let group = ImageEditorLayer.group(name: "Group", size: viewModel.document.canvasSize)
        let outside = layer("Outside", in: viewModel)
        lower.groupID = group.id
        upper.groupID = group.id
        viewModel.document.layers = [outside, lower, upper, group]
        select([upper.id], primary: upper.id, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canMergeSelectedLayerDown)
        viewModel.mergeSelectedLayerDown()

        let merged = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.map(\.id) == [outside.id, merged.id, group.id])
        #expect(merged.groupID == group.id)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == [outside.id, lower.id, upper.id, group.id])
    }

    @Test func selectingAGroupMergesItsCompleteNestedSubtree() throws {
        let viewModel = makeViewModel()
        var leaf = layer("Leaf", in: viewModel)
        var innerGroup = ImageEditorLayer.group(name: "Inner", size: viewModel.document.canvasSize)
        var looseChild = layer("Loose Child", in: viewModel)
        let outerGroup = ImageEditorLayer.group(name: "Outer", size: viewModel.document.canvasSize)
        let survivor = layer("Survivor", in: viewModel)
        leaf.groupID = innerGroup.id
        innerGroup.groupID = outerGroup.id
        looseChild.groupID = outerGroup.id
        viewModel.document.layers = [leaf, innerGroup, looseChild, outerGroup, survivor]
        select([outerGroup.id, leaf.id], primary: outerGroup.id, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canMergeSelectedLayerDown)
        viewModel.mergeSelectedLayerDown()

        let merged = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.map(\.id) == [merged.id, survivor.id])
        #expect(merged.name == outerGroup.name)
        #expect(merged.groupID == nil)
        #expect(viewModel.document.selectedLayerIDs == [merged.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeGroup"))
    }

    @Test func mergeSelectedRejectsRootsFromDifferentParents() {
        let viewModel = makeViewModel()
        var leftChild = layer("Left Child", in: viewModel)
        let leftGroup = ImageEditorLayer.group(name: "Left", size: viewModel.document.canvasSize)
        var rightChild = layer("Right Child", in: viewModel)
        let rightGroup = ImageEditorLayer.group(name: "Right", size: viewModel.document.canvasSize)
        leftChild.groupID = leftGroup.id
        rightChild.groupID = rightGroup.id
        viewModel.document.layers = [leftChild, leftGroup, rightChild, rightGroup]
        select([leftChild.id, rightChild.id], primary: rightChild.id, in: viewModel)
        let originalIDs = viewModel.document.layers.map(\.id)
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.canMergeSelectedLayers)
        viewModel.mergeSelectedLayers()

        #expect(viewModel.document.layers.map(\.id) == originalIDs)
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func mergeSelectedSkipsLockedRootsAndPreservesTheirSelection() throws {
        let viewModel = makeViewModel()
        let lower = layer("Lower", in: viewModel)
        var locked = layer("Locked", in: viewModel)
        let upper = layer("Upper", in: viewModel)
        locked.isLocked = true
        viewModel.document.layers = [lower, locked, upper]
        select([lower.id, locked.id, upper.id], primary: upper.id, in: viewModel)

        #expect(viewModel.canMergeSelectedLayers)
        viewModel.mergeSelectedLayers()

        let mergedID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.document.layers.map(\.id) == [mergedID, locked.id])
        #expect(viewModel.document.selectedLayerIDs == [mergedID, locked.id])
        #expect(viewModel.document.selectedLayerID == mergedID)
        #expect(viewModel.document.layers.first { $0.id == locked.id }?.isLocked == true)
    }

    @Test func mergeSelectedRefusesToPartiallyFlattenAGroupWithLockedDescendants() {
        let viewModel = makeViewModel()
        var lockedChild = layer("Locked Child", in: viewModel)
        let group = ImageEditorLayer.group(name: "Protected Group", size: viewModel.document.canvasSize)
        let sibling = layer("Sibling", in: viewModel)
        lockedChild.groupID = group.id
        lockedChild.isLocked = true
        viewModel.document.layers = [lockedChild, group, sibling]
        select([group.id, sibling.id], primary: sibling.id, in: viewModel)
        let originalIDs = viewModel.document.layers.map(\.id)

        #expect(!viewModel.canMergeSelectedLayers)
        viewModel.mergeSelectedLayers()

        #expect(viewModel.document.layers.map(\.id) == originalIDs)
    }

    @Test func mergeSelectedReplacesExternalLinksWithTheMergedLayer() throws {
        let viewModel = makeViewModel()
        var lower = layer("Lower", in: viewModel)
        var upper = layer("Upper", in: viewModel)
        var linkedSurvivor = layer("Linked Survivor", in: viewModel)
        lower.linkedLayerIDs = [linkedSurvivor.id]
        upper.linkedLayerIDs = [linkedSurvivor.id]
        linkedSurvivor.linkedLayerIDs = [lower.id, upper.id]
        viewModel.document.layers = [lower, upper, linkedSurvivor]
        select([lower.id, upper.id], primary: upper.id, in: viewModel)

        viewModel.mergeSelectedLayers()

        let merged = try #require(viewModel.document.selectedLayer)
        let survivor = try #require(viewModel.document.layers.first { $0.id == linkedSurvivor.id })
        #expect(merged.linkedLayerIDs == [survivor.id])
        #expect(survivor.linkedLayerIDs == [merged.id])
        #expect(!survivor.linkedLayerIDs.contains(lower.id))
        #expect(!survivor.linkedLayerIDs.contains(upper.id))
    }

    @Test func mergingSelectedClippingLayersKeepsTheirExternalBase() throws {
        let viewModel = makeViewModel()
        let base = layer("Base", in: viewModel)
        var firstClip = layer("First Clip", in: viewModel)
        var secondClip = layer("Second Clip", in: viewModel)
        firstClip.isClippingMask = true
        secondClip.isClippingMask = true
        viewModel.document.layers = [base, firstClip, secondClip]
        select([firstClip.id, secondClip.id], primary: secondClip.id, in: viewModel)

        #expect(viewModel.canMergeSelectedLayers)
        viewModel.mergeSelectedLayers()

        let merged = try #require(viewModel.document.selectedLayer)
        let mergedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == merged.id })
        #expect(merged.isClippingMask)
        #expect(viewModel.document.clippingBase(forLayerAt: mergedIndex)?.id == base.id)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "merge-hierarchy.png",
            image: NSImage.transparent(size: NSSize(width: 120, height: 90))
        ) { _ in }
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
