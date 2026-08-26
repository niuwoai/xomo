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
    @Test func onePhysicalMergeDownShortcutConsumesOnlyOneNeighbor() {
        ImageEditorLayerMergeCommandDispatchGate.reset()
        defer { ImageEditorLayerMergeCommandDispatchGate.reset() }

        let viewModel = makeViewModel()
        let lower = layer("Lower", in: viewModel)
        let middle = layer("Middle", in: viewModel)
        let upper = layer("Upper", in: viewModel)
        viewModel.document.layers = [lower, middle, upper]
        select([upper.id], primary: upper.id, in: viewModel)
        let initialHistoryCount = viewModel.document.history.count
        let firstEvent = mergeEvent(number: 601, timestamp: 60)
        let secondEvent = mergeEvent(number: 602, timestamp: 60.2)

        func dispatch(event: ImageEditorKeyboardShortcutEventSignature?) {
            guard ImageEditorLayerMergeCommandDispatchGate.shouldDispatch(
                .mergeDown,
                event: event
            ) else { return }
            viewModel.mergeSelectedLayerDown()
        }

        dispatch(event: firstEvent)
        dispatch(event: firstEvent)
        #expect(viewModel.document.layers.count == 2)
        #expect(viewModel.document.history.count == initialHistoryCount + 1)

        dispatch(event: secondEvent)
        #expect(viewModel.document.layers.count == 1)
        #expect(viewModel.document.history.count == initialHistoryCount + 2)
    }

    @Test func onePhysicalStampVisibleShortcutCreatesOnlyOneComposite() {
        ImageEditorLayerMergeCommandDispatchGate.reset()
        defer { ImageEditorLayerMergeCommandDispatchGate.reset() }

        let viewModel = makeViewModel()
        let lower = layer("Lower", in: viewModel)
        let upper = layer("Upper", in: viewModel)
        viewModel.document.layers = [lower, upper]
        select([upper.id], primary: upper.id, in: viewModel)
        let initialHistoryCount = viewModel.document.history.count
        let firstEvent = mergeEvent(number: 603, timestamp: 60.4)
        let secondEvent = mergeEvent(number: 604, timestamp: 60.6)

        func dispatch(event: ImageEditorKeyboardShortcutEventSignature?) {
            guard ImageEditorLayerMergeCommandDispatchGate.shouldDispatch(
                .stampVisible,
                event: event
            ) else { return }
            viewModel.stampVisibleLayers()
        }

        dispatch(event: firstEvent)
        dispatch(event: firstEvent)
        #expect(viewModel.document.layers.count == 3)
        #expect(viewModel.document.history.count == initialHistoryCount + 1)

        dispatch(event: secondEvent)
        #expect(viewModel.document.layers.count == 4)
        #expect(viewModel.document.history.count == initialHistoryCount + 2)
    }

    @Test func mergeVisibleEventAndMouseMenuBoundariesRemainExplicit() {
        ImageEditorLayerMergeCommandDispatchGate.reset()
        defer { ImageEditorLayerMergeCommandDispatchGate.reset() }
        let event = mergeEvent(number: 605, timestamp: 60.8)

        #expect(ImageEditorLayerMergeCommandDispatchGate.shouldDispatch(.mergeVisible, event: event))
        #expect(!ImageEditorLayerMergeCommandDispatchGate.shouldDispatch(.mergeVisible, event: event))
        #expect(ImageEditorLayerMergeCommandDispatchGate.shouldDispatch(.mergeVisible, event: nil))
        #expect(ImageEditorLayerMergeCommandDispatchGate.shouldDispatch(.mergeVisible, event: nil))
    }

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

    @Test func layerRowContextMergeChoosesSelectedDownOrGroupWithoutRetargeting() throws {
        let viewModel = makeViewModel()
        let lower = layer("Lower", in: viewModel)
        let middle = layer("Middle", in: viewModel)
        let upper = layer("Upper", in: viewModel)
        let outside = layer("Outside", in: viewModel)
        viewModel.document.layers = [lower, middle, upper, outside]
        select([middle.id, upper.id], primary: upper.id, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.layerMergeActionFromContext(middle.id) == .selected)
        #expect(viewModel.applyLayerMergeActionFromContext(middle.id))
        let selectedMerged = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.map(\.id) == [lower.id, selectedMerged.id, outside.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeSelected"))

        viewModel.undo()
        #expect(viewModel.document.selectedLayerIDs == [middle.id, upper.id])
        viewModel.selectLayer(outside.id)
        #expect(viewModel.layerMergeActionFromContext(upper.id) == .down)
        #expect(viewModel.applyLayerMergeActionFromContext(upper.id))
        let downMerged = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.map(\.id) == [lower.id, downMerged.id, outside.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeDown"))

        viewModel.undo()
        #expect(viewModel.layerMergeActionFromContext(lower.id) == nil)
        let upperIndex = try #require(viewModel.document.layers.firstIndex { $0.id == upper.id })
        viewModel.document.layers[upperIndex].isLocked = true
        #expect(viewModel.layerMergeActionFromContext(upper.id) == nil)
        #expect(
            viewModel.layerMergeTitleKeyFromContext(upper.id)
                == "imageEditor.action.layerMergeDown"
        )
        #expect(!viewModel.applyLayerMergeActionFromContext(upper.id))
        #expect(viewModel.layerMergeActionFromContext(UUID()) == nil)

        var child = layer("Child", in: viewModel)
        let group = ImageEditorLayer.group(name: "Group", size: viewModel.document.canvasSize)
        let survivor = layer("Survivor", in: viewModel)
        child.groupID = group.id
        viewModel.document.layers = [child, group, survivor]
        select([survivor.id], primary: survivor.id, in: viewModel)
        #expect(viewModel.layerMergeActionFromContext(group.id) == .group)
        #expect(
            viewModel.layerMergeTitleKeyFromContext(group.id)
                == "imageEditor.action.layerMergeGroup"
        )
        #expect(viewModel.applyLayerMergeActionFromContext(group.id))
        let groupMerged = try #require(viewModel.document.selectedLayer)
        #expect(groupMerged.name == group.name)
        #expect(viewModel.document.layers.map(\.id) == [groupMerged.id, survivor.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeGroup"))

        var selectedChild = layer("Selected Child", in: viewModel)
        let selectedGroup = ImageEditorLayer.group(
            name: "Selected Group",
            size: viewModel.document.canvasSize
        )
        var lockedSurvivor = layer("Locked Survivor", in: viewModel)
        selectedChild.groupID = selectedGroup.id
        lockedSurvivor.isLocked = true
        viewModel.document.layers = [selectedChild, selectedGroup, lockedSurvivor]
        select(
            [selectedGroup.id, lockedSurvivor.id],
            primary: selectedGroup.id,
            in: viewModel
        )
        #expect(viewModel.layerMergeActionFromContext(selectedGroup.id) == .selected)
        #expect(
            viewModel.layerMergeTitleKeyFromContext(selectedGroup.id)
                == "imageEditor.action.layerMergeSelected"
        )
        #expect(viewModel.applyLayerMergeActionFromContext(selectedGroup.id))
        let selectedGroupMerged = try #require(viewModel.document.selectedLayer)
        #expect(viewModel.document.layers.map(\.id) == [selectedGroupMerged.id, lockedSurvivor.id])
        #expect(viewModel.document.selectedLayerIDs == [selectedGroupMerged.id, lockedSurvivor.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerMergeSelected"))
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

    @Test func mergingSelectedClippingLayersKeepsTheirHiddenExternalBase() throws {
        let viewModel = makeViewModel()
        var hiddenBase = layer("Hidden Base", in: viewModel)
        var firstClip = layer("First Clip", in: viewModel)
        var secondClip = layer("Second Clip", in: viewModel)
        hiddenBase.isVisible = false
        firstClip.isClippingMask = true
        secondClip.isClippingMask = true
        viewModel.document.layers = [hiddenBase, firstClip, secondClip]
        select([firstClip.id, secondClip.id], primary: secondClip.id, in: viewModel)

        #expect(viewModel.canMergeSelectedLayers)
        viewModel.mergeSelectedLayers()

        let merged = try #require(viewModel.document.selectedLayer)
        let mergedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == merged.id })
        #expect(merged.isClippingMask)
        #expect(viewModel.document.clippingBase(forLayerAt: mergedIndex)?.id == hiddenBase.id)
    }

    @Test func mergeDownKeepsHiddenExternalClippingBase() throws {
        let viewModel = makeViewModel()
        var hiddenBase = layer("Hidden Base", in: viewModel)
        var lowerClip = layer("Lower Clip", in: viewModel)
        let upper = layer("Upper", in: viewModel)
        hiddenBase.isVisible = false
        lowerClip.isClippingMask = true
        viewModel.document.layers = [hiddenBase, lowerClip, upper]
        select([upper.id], primary: upper.id, in: viewModel)

        #expect(viewModel.canMergeSelectedLayerDown)
        viewModel.mergeSelectedLayerDown()

        let merged = try #require(viewModel.document.selectedLayer)
        let mergedIndex = try #require(viewModel.document.layers.firstIndex { $0.id == merged.id })
        #expect(merged.isClippingMask)
        #expect(viewModel.document.clippingBase(forLayerAt: mergedIndex)?.id == hiddenBase.id)
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

    private func mergeEvent(
        number: Int,
        timestamp: TimeInterval
    ) -> ImageEditorKeyboardShortcutEventSignature {
        ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 13,
            eventNumber: number,
            timestamp: timestamp,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 14
        )
    }
}
