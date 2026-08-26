//
//  ImageEditorLayerDeletionTests.swift
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
struct ImageEditorLayerDeletionTests {
    @Test func deletingSelectedGroupRemovesItsCompleteNestedSubtreeInOneUndoStep() {
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
        let originalIDs = viewModel.document.layers.map(\.id)
        let originalSelection = viewModel.document.selectedLayerIDs
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canDeleteLayer)
        viewModel.deleteSelectedLayer()

        #expect(viewModel.document.layers.map(\.id) == [survivor.id])
        #expect(viewModel.document.selectedLayerIDs == [survivor.id])
        #expect(viewModel.document.selectedLayerID == survivor.id)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDelete"))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalIDs)
        #expect(viewModel.document.selectedLayerIDs == originalSelection)
        #expect(viewModel.document.selectedLayerID == outerGroup.id)
    }

    @Test func mixedLockedSelectionDeletesEditableRootsAndPreservesLockedSelection() {
        let viewModel = makeViewModel()
        var locked = layer("Locked", in: viewModel)
        let gap = layer("Gap", in: viewModel)
        let editable = layer("Editable", in: viewModel)
        let ceiling = layer("Ceiling", in: viewModel)
        locked.isLocked = true
        viewModel.document.layers = [locked, gap, editable, ceiling]
        select([locked.id, editable.id], primary: editable.id, in: viewModel)

        viewModel.deleteSelectedLayer()

        #expect(viewModel.document.layers.map(\.id) == [locked.id, gap.id, ceiling.id])
        #expect(viewModel.document.selectedLayerIDs == [locked.id])
        #expect(viewModel.document.selectedLayerID == locked.id)
    }

    @Test func deletionFallbackUsesVisibleRowsInsteadOfHiddenCollapsedDescendants() {
        let viewModel = makeViewModel()
        let deletedBottom = layer("Deleted Bottom", in: viewModel)
        var hiddenChild = layer("Hidden Child", in: viewModel)
        var collapsedGroup = ImageEditorLayer.group(name: "Collapsed", size: viewModel.document.canvasSize)
        let top = layer("Top", in: viewModel)
        hiddenChild.groupID = collapsedGroup.id
        collapsedGroup.isGroupExpanded = false
        viewModel.document.layers = [deletedBottom, hiddenChild, collapsedGroup, top]
        select([deletedBottom.id], primary: deletedBottom.id, in: viewModel)
        #expect(viewModel.visibleLayerRows.map(\.id) == [top.id, collapsedGroup.id, deletedBottom.id])

        viewModel.deleteSelectedLayer()

        #expect(viewModel.document.layers.map(\.id) == [hiddenChild.id, collapsedGroup.id, top.id])
        #expect(viewModel.document.selectedLayerIDs == [collapsedGroup.id])
        #expect(viewModel.document.selectedLayerID == collapsedGroup.id)
        #expect(!viewModel.document.selectedLayerIDs.contains(hiddenChild.id))
    }

    @Test func deletingClippingBaseClearsSurvivingChainInsteadOfRebindingIt() throws {
        let viewModel = makeViewModel()
        let fallbackBase = layer("Fallback Base", in: viewModel)
        var deletedBase = layer("Deleted Base", in: viewModel)
        var firstClip = layer("First Clip", in: viewModel)
        var secondClip = layer("Second Clip", in: viewModel)
        let ceiling = layer("Ceiling", in: viewModel)
        firstClip.isClippingMask = true
        secondClip.isClippingMask = true
        deletedBase.isVisible = false
        viewModel.document.layers = [fallbackBase, deletedBase, firstClip, secondClip, ceiling]
        select([deletedBase.id], primary: deletedBase.id, in: viewModel)

        let firstIndexBefore = try #require(viewModel.document.layers.firstIndex { $0.id == firstClip.id })
        let secondIndexBefore = try #require(viewModel.document.layers.firstIndex { $0.id == secondClip.id })
        #expect(viewModel.document.clippingBase(forLayerAt: firstIndexBefore)?.id == deletedBase.id)
        #expect(viewModel.document.clippingBase(forLayerAt: secondIndexBefore)?.id == deletedBase.id)

        viewModel.deleteSelectedLayer()

        let first = try #require(viewModel.document.layers.first { $0.id == firstClip.id })
        let second = try #require(viewModel.document.layers.first { $0.id == secondClip.id })
        #expect(!first.isClippingMask)
        #expect(!second.isClippingMask)
        #expect(viewModel.document.layers.first { $0.id == fallbackBase.id } != nil)
    }

    @Test func deletionRemovesDanglingLinksWithoutChangingSurvivorLinks() throws {
        let viewModel = makeViewModel()
        var deletedChild = layer("Deleted Child", in: viewModel)
        let deletedGroup = ImageEditorLayer.group(name: "Deleted Group", size: viewModel.document.canvasSize)
        var survivorA = layer("Survivor A", in: viewModel)
        var survivorB = layer("Survivor B", in: viewModel)
        deletedChild.groupID = deletedGroup.id
        deletedChild.linkedLayerIDs = [survivorA.id]
        survivorA.linkedLayerIDs = [deletedChild.id, survivorB.id]
        survivorB.linkedLayerIDs = [survivorA.id]
        viewModel.document.layers = [deletedChild, deletedGroup, survivorA, survivorB]
        select([deletedGroup.id], primary: deletedGroup.id, in: viewModel)

        viewModel.deleteSelectedLayer()

        let remainingA = try #require(viewModel.document.layers.first { $0.id == survivorA.id })
        let remainingB = try #require(viewModel.document.layers.first { $0.id == survivorB.id })
        #expect(remainingA.linkedLayerIDs == [survivorB.id])
        #expect(remainingB.linkedLayerIDs == [survivorA.id])
    }

    @Test func deletionCannotRemoveTheLastRemainingLayer() {
        let viewModel = makeViewModel()
        let onlyLayer = layer("Only", in: viewModel)
        viewModel.document.layers = [onlyLayer]
        select([onlyLayer.id], primary: onlyLayer.id, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.canDeleteLayer)
        viewModel.deleteSelectedLayer()

        #expect(viewModel.document.layers.map(\.id) == [onlyLayer.id])
        #expect(viewModel.document.selectedLayerIDs == [onlyLayer.id])
        #expect(viewModel.document.history.count == historyCount)
    }

    @Test func deleteKeyRemovesTheSelectedImportedImageLayerInOneUndoStep() throws {
        let viewModel = makeViewModel()
        let importedImage = NSImage.transparent(size: NSSize(width: 48, height: 36))
        viewModel.importImageLayer(importedImage, sourceName: "poster.png")
        let importedID = try #require(viewModel.document.selectedLayerID)
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.document.selection == nil)
        #expect(viewModel.deleteSelectedLayerFromKeyboardIfPossible())
        #expect(!viewModel.document.layers.contains { $0.id == importedID })
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDelete"))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.selectedLayerID == importedID)
    }

    @Test func onePhysicalDeleteEventRemovesOnlyTheFrontImportedLayer() throws {
        ImageEditorDeleteCommandDispatchGate.reset()
        defer { ImageEditorDeleteCommandDispatchGate.reset() }

        let viewModel = makeViewModel()
        #expect(viewModel.importImageLayer(
            .transparent(size: CGSize(width: 32, height: 24)),
            sourceName: "first.png"
        ))
        let firstImportedID = try #require(viewModel.document.selectedLayerID)
        #expect(viewModel.importImageLayer(
            .transparent(size: CGSize(width: 28, height: 20)),
            sourceName: "front.png"
        ))
        let frontImportedID = try #require(viewModel.document.selectedLayerID)
        let originalLayerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let event = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 63,
            eventNumber: 1041,
            timestamp: 104.1,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 51
        )

        for _ in 0..<2 {
            guard ImageEditorDeleteCommandDispatchGate.shouldDispatch(event: event) else {
                continue
            }
            #expect(viewModel.deleteSelectedLayerFromKeyboardIfPossible())
        }

        #expect(viewModel.document.layers.count == originalLayerCount - 1)
        #expect(!viewModel.document.layers.contains { $0.id == frontImportedID })
        #expect(viewModel.document.layers.contains { $0.id == firstImportedID })
        #expect(viewModel.document.selectedLayerID == firstImportedID)
        #expect(viewModel.document.history.count == historyCount + 1)
    }

    @Test func independentDeleteEventsAndMouseCommandsRemainIndependent() {
        ImageEditorDeleteCommandDispatchGate.reset()
        defer { ImageEditorDeleteCommandDispatchGate.reset() }

        let first = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 63,
            eventNumber: 1042,
            timestamp: 104.2,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 51
        )
        let second = ImageEditorKeyboardShortcutEventSignature(
            windowNumber: 63,
            eventNumber: 1043,
            timestamp: 104.3,
            typeRawValue: NSEvent.EventType.keyDown.rawValue,
            keyCode: 51
        )

        #expect(ImageEditorDeleteCommandDispatchGate.shouldDispatch(event: first))
        #expect(!ImageEditorDeleteCommandDispatchGate.shouldDispatch(event: first))
        #expect(ImageEditorDeleteCommandDispatchGate.shouldDispatch(event: second))
        #expect(ImageEditorDeleteCommandDispatchGate.shouldDispatch(event: nil))
        #expect(ImageEditorDeleteCommandDispatchGate.shouldDispatch(event: nil))
    }

    @Test func importedImageEndsOldPixelSelectionSoDeleteOwnsTheNewObject() throws {
        let viewModel = makeViewModel()
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalSelection = ImageEditorSelection.rectangle(
            CGRect(x: 3, y: 4, width: 18, height: 12)
        )
        viewModel.document.selection = originalSelection
        let historyCount = viewModel.document.history.count

        let importedImage = NSImage.rendered(size: CGSize(width: 48, height: 36)) { rect in
            NSColor.systemOrange.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: CGSize(width: 48, height: 36))
        #expect(viewModel.importImageLayer(importedImage, sourceName: "poster.png"))
        let importedID = try #require(viewModel.document.selectedLayerID)

        #expect(viewModel.document.selection == nil)
        #expect(viewModel.reselectableSelection == originalSelection)
        #expect(viewModel.document.selectedLayerIDs == [importedID])
        #expect(viewModel.deleteSelectedLayerFromKeyboardIfPossible())
        #expect(!viewModel.document.layers.contains { $0.id == importedID })
        #expect(viewModel.document.history.count == historyCount + 2)

        viewModel.undo()
        #expect(viewModel.document.layers.contains { $0.id == importedID })
        #expect(viewModel.document.selectedLayerID == importedID)
        #expect(viewModel.document.selection == nil)

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.selection == originalSelection)
    }

    @Test func importedImageTakesDeleteOwnershipFromAStaleSliceSelection() throws {
        let viewModel = makeViewModel()
        let staleSlice = ImageEditorSlice(
            name: "Old Slice",
            frame: CGRect(x: 2, y: 3, width: 12, height: 10)
        )
        viewModel.document.slices = [staleSlice]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = staleSlice.id

        #expect(viewModel.importImageLayer(.transparent(size: CGSize(width: 48, height: 36)), sourceName: "poster.png"))
        let importedID = try #require(viewModel.document.selectedLayerID)

        #expect(viewModel.exportSettings.scope == .selectedLayer)
        #expect(!viewModel.deleteSelectedDeliveryObjectIfNeeded())
        #expect(viewModel.document.slices.map(\.id) == [staleSlice.id])
        #expect(viewModel.deleteSelectedLayerFromKeyboardIfPossible())
        #expect(!viewModel.document.layers.contains { $0.id == importedID })
    }

    @Test func importedImageTakesDeleteOwnershipFromAStaleHotspotSelection() throws {
        let viewModel = makeViewModel()
        let staleHotspot = ImageEditorHotspot(
            name: "Old Hotspot",
            frame: CGRect(x: 2, y: 3, width: 12, height: 10),
            url: "https://example.com"
        )
        viewModel.document.hotspots = [staleHotspot]
        viewModel.selectedHotspotID = staleHotspot.id

        #expect(viewModel.importImageLayer(.transparent(size: CGSize(width: 48, height: 36)), sourceName: "poster.png"))
        let importedID = try #require(viewModel.document.selectedLayerID)

        #expect(viewModel.selectedHotspotID == nil)
        #expect(!viewModel.deleteSelectedDeliveryObjectIfNeeded())
        #expect(viewModel.document.hotspots.map(\.id) == [staleHotspot.id])
        #expect(viewModel.deleteSelectedLayerFromKeyboardIfPossible())
        #expect(!viewModel.document.layers.contains { $0.id == importedID })
    }

    @Test func deliveryObjectsKeepGlobalDeleteAvailableWhenTheLastLayerCannotBeRemoved() {
        let viewModel = makeViewModel()
        let onlyLayer = layer("Only", in: viewModel)
        viewModel.document.layers = [onlyLayer]
        select([onlyLayer.id], primary: onlyLayer.id, in: viewModel)
        let historyCount = viewModel.document.history.count
        #expect(!viewModel.canDeleteLayer)

        let slice = ImageEditorSlice(
            name: "Hero slice",
            frame: CGRect(x: 4, y: 5, width: 20, height: 16)
        )
        viewModel.document.slices = [slice]
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = slice.id
        #expect(viewModel.canDeleteSelectedDeliveryObject)
        #expect(viewModel.deleteSelectedDeliveryObjectIfNeeded())
        #expect(viewModel.document.slices.isEmpty)
        #expect(!viewModel.canDeleteSelectedDeliveryObject)

        let hotspot = ImageEditorHotspot(
            name: "Hero link",
            frame: CGRect(x: 7, y: 8, width: 18, height: 14),
            url: "https://example.com"
        )
        viewModel.document.hotspots = [hotspot]
        viewModel.selectedHotspotID = hotspot.id
        #expect(viewModel.canDeleteSelectedDeliveryObject)
        #expect(viewModel.deleteSelectedDeliveryObjectIfNeeded())
        #expect(viewModel.document.hotspots.isEmpty)
        #expect(!viewModel.canDeleteSelectedDeliveryObject)
        #expect(viewModel.document.layers.map(\.id) == [onlyLayer.id])
        #expect(viewModel.document.history.count == historyCount + 2)

        viewModel.selectedHotspotID = UUID()
        #expect(!viewModel.canDeleteSelectedDeliveryObject)
        viewModel.selectedHotspotID = nil
        viewModel.exportSettings.scope = .slice
        viewModel.exportSettings.sliceID = UUID()
        #expect(!viewModel.canDeleteSelectedDeliveryObject)
    }

    @Test func deleteKeyLeavesTheLayerForPixelDeletionWhenASelectionExists() throws {
        let viewModel = makeViewModel()
        let importedImage = NSImage.transparent(size: NSSize(width: 48, height: 36))
        viewModel.importImageLayer(importedImage, sourceName: "poster.png")
        let importedID = try #require(viewModel.document.selectedLayerID)
        viewModel.document.selection = .rectangle(CGRect(x: 2, y: 2, width: 12, height: 10))
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let historyCount = viewModel.document.history.count

        #expect(!viewModel.deleteSelectedLayerFromKeyboardIfPossible())
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.selectedLayerID == importedID)
        #expect(viewModel.document.history.count == historyCount)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "deletion.png",
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
