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

    @Test func layerRowContextActionsPreserveSelectedSetsAndTargetUnselectedRows() {
        let viewModel = makeViewModel()
        let first = layer("First", in: viewModel)
        let second = layer("Second", in: viewModel)
        let third = layer("Third", in: viewModel)
        viewModel.document.layers = [first, second, third]
        select([first.id, second.id], primary: second.id, in: viewModel)
        let originalIDs = viewModel.document.layers.map(\.id)

        #expect(viewModel.canDuplicateLayersFromContext(first.id))
        viewModel.prepareLayerContextSelection(for: first.id)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.document.selectedLayerID == second.id)
        viewModel.duplicateSelectedLayer()
        #expect(viewModel.document.layers.count == 5)
        #expect(viewModel.document.selectedLayerIDs.count == 2)
        #expect(viewModel.document.selectedLayerIDs.isDisjoint(with: [first.id, second.id]))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalIDs)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])

        viewModel.prepareLayerContextSelection(for: third.id)
        #expect(viewModel.document.selectedLayerIDs == [third.id])
        #expect(viewModel.document.selectedLayerID == third.id)
        #expect(viewModel.canDeleteLayersFromContext(third.id))
        viewModel.deleteSelectedLayer()
        #expect(viewModel.document.layers.map(\.id) == [first.id, second.id])
    }

    @Test func layerRowContextClipboardPreservesMultiSelectionAndTargetsAnUnselectedRow() throws {
        let viewModel = makeViewModel()
        let first = layer("First", in: viewModel)
        let second = layer("Second", in: viewModel)
        let third = layer("Third", in: viewModel)
        viewModel.document.layers = [first, second, third]
        select([first.id, second.id], primary: second.id, in: viewModel)
        let historyCount = viewModel.document.history.count
        let pasteboard = NSPasteboard(name: .init("im.some.xomo.tests.layer-context.\(UUID())"))
        pasteboard.clearContents()
        defer { pasteboard.clearContents() }

        #expect(viewModel.canCopyLayersFromContext(first.id))
        #expect(viewModel.canCutLayersFromContext(first.id))
        viewModel.prepareLayerContextSelection(for: first.id)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.copySelectedLayersToClipboard(to: pasteboard))
        #expect(pasteboard.data(forType: XomoLayerClipboardArchive.pasteboardType) != nil)
        #expect(viewModel.document.history.count == historyCount)

        #expect(viewModel.canCopyLayersFromContext(third.id))
        #expect(viewModel.canCutLayersFromContext(third.id))
        viewModel.prepareLayerContextSelection(for: third.id)
        #expect(viewModel.document.selectedLayerIDs == [third.id])
        #expect(viewModel.cutSelectedLayersToClipboard(to: pasteboard))
        #expect(viewModel.document.layers.map(\.id) == [first.id, second.id])
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == [first.id, second.id, third.id])
        #expect(viewModel.document.selectedLayerIDs == [third.id])
    }

    @Test func layerRowContextDeleteHonorsLocksLastLayerAndUnknownRows() {
        let viewModel = makeViewModel()
        let editable = layer("Editable", in: viewModel)
        var locked = layer("Locked", in: viewModel)
        locked.isLocked = true
        viewModel.document.layers = [editable, locked]
        select([editable.id], primary: editable.id, in: viewModel)

        #expect(!viewModel.canDeleteLayersFromContext(locked.id))
        #expect(viewModel.canCopyLayersFromContext(locked.id))
        #expect(!viewModel.canCutLayersFromContext(locked.id))
        #expect(!viewModel.canDeleteLayersFromContext(UUID()))
        #expect(!viewModel.canDuplicateLayersFromContext(UUID()))
        #expect(!viewModel.canCopyLayersFromContext(UUID()))
        #expect(!viewModel.canCutLayersFromContext(UUID()))
        viewModel.prepareLayerContextSelection(for: UUID())
        #expect(viewModel.document.selectedLayerIDs == [editable.id])

        select([editable.id, locked.id], primary: editable.id, in: viewModel)
        #expect(viewModel.canCopyLayersFromContext(locked.id))
        #expect(!viewModel.canCutLayersFromContext(locked.id))

        viewModel.document.layers = [editable]
        select([editable.id], primary: editable.id, in: viewModel)
        #expect(!viewModel.canDeleteLayersFromContext(editable.id))
        #expect(viewModel.canDuplicateLayersFromContext(editable.id))
        #expect(viewModel.canCopyLayersFromContext(editable.id))
        #expect(!viewModel.canCutLayersFromContext(editable.id))

        viewModel.document.selectedLayerIDs = []
        viewModel.prepareLayerContextSelection(for: editable.id)
        #expect(viewModel.document.selectedLayerIDs == [editable.id])
    }

    @Test func targetedLayerRenameTrimsTheNameAndPreservesNoOpRedo() throws {
        let viewModel = makeViewModel()
        let first = layer("First", in: viewModel)
        let second = layer("Second", in: viewModel)
        viewModel.document.layers = [first, second]
        select([second.id], primary: second.id, in: viewModel)

        viewModel.addLayer()
        viewModel.undo()
        let historyCount = viewModel.document.history.count
        #expect(viewModel.canRedo)

        #expect(!viewModel.renameLayer(first.id, to: "  First  "))
        #expect(!viewModel.renameLayer(first.id, to: "   "))
        #expect(!viewModel.renameLayer(UUID(), to: "Missing"))
        #expect(viewModel.canRedo)
        #expect(viewModel.document.history.count == historyCount)

        #expect(viewModel.renameLayer(first.id, to: "  Hero Artwork  "))
        #expect(viewModel.document.layers.first { $0.id == first.id }?.name == "Hero Artwork")
        #expect(viewModel.document.selectedLayerID == second.id)
        #expect(viewModel.document.selectedLayerIDs == [second.id])
        #expect(!viewModel.canRedo)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRename"))

        viewModel.undo()
        #expect(viewModel.document.layers.first { $0.id == first.id }?.name == "First")
        #expect(viewModel.document.selectedLayerID == second.id)
    }

    @Test func layerRowContextGroupingPreservesSelectedSetsAndTargetsUnselectedGroups() throws {
        let viewModel = makeViewModel()
        let first = layer("First", in: viewModel)
        let second = layer("Second", in: viewModel)
        let outside = layer("Outside", in: viewModel)
        viewModel.document.layers = [first, second, outside]
        select([first.id, second.id], primary: second.id, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canGroupLayersFromContext(first.id))
        #expect(!viewModel.canGroupLayersFromContext(UUID()))
        viewModel.document.layers[2].isLocked = true
        #expect(!viewModel.canGroupLayersFromContext(outside.id))
        viewModel.document.layers[2].isLocked = false
        viewModel.prepareLayerContextSelection(for: first.id)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        viewModel.groupSelectedLayer()

        let group = try #require(viewModel.document.selectedLayer)
        #expect(group.isGroup)
        #expect(viewModel.document.layers.first { $0.id == first.id }?.groupID == group.id)
        #expect(viewModel.document.layers.first { $0.id == second.id }?.groupID == group.id)
        #expect(viewModel.document.layers.first { $0.id == outside.id }?.groupID == nil)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerGroupSelected"))

        viewModel.selectLayer(outside.id)
        #expect(viewModel.canUngroupLayersFromContext(group.id))
        #expect(!viewModel.canUngroupLayersFromContext(outside.id))
        let groupIndex = try #require(viewModel.document.layers.firstIndex { $0.id == group.id })
        viewModel.document.layers[groupIndex].isLocked = true
        #expect(!viewModel.canUngroupLayersFromContext(group.id))
        viewModel.document.layers[groupIndex].isLocked = false
        viewModel.prepareLayerContextSelection(for: group.id)
        #expect(viewModel.document.selectedLayerIDs == [group.id])
        viewModel.ungroupSelectedLayers()

        #expect(!viewModel.document.layers.contains { $0.id == group.id })
        #expect(viewModel.document.layers.first { $0.id == first.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == second.id }?.groupID == nil)
        #expect(viewModel.document.layers.first { $0.id == outside.id }?.groupID == nil)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerUngroup"))
    }

    @Test func layerRowsWireDoubleClickContextSubmitBlurAndEscapeToOneInlineRenameEditor() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )

        #expect(source.contains(".onTapGesture(count: 2)"))
        #expect(source.contains("beginLayerInlineRename(layer)"))
        #expect(source.contains(".focused($focusedInlineLayerNameID, equals: layer.id)"))
        #expect(source.contains("commitLayerInlineRename(layer.id)"))
        #expect(source.contains("cancelLayerInlineRename(layer.id)"))
        #expect(source.contains("if focusedID != layer.id, renamingLayerID == layer.id"))
        #expect(source.contains("_ = viewModel.renameLayer(layerID, to: proposedName)"))
        #expect(source.contains("image-editor-layer-context-rename-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-inline-name-\\(layer.id.uuidString)"))
    }

    @Test func layerRowContextClippingMaskTargetsItsRowAndPreservesSelectedBatches() throws {
        let viewModel = makeViewModel()
        let base = layer("Base", in: viewModel)
        let first = layer("First", in: viewModel)
        let second = layer("Second", in: viewModel)
        let outside = layer("Outside", in: viewModel)
        viewModel.document.layers = [base, first, second, outside]
        select([first.id, second.id], primary: second.id, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.clippingMaskActionFromContext(first.id) == .create)
        #expect(viewModel.applyClippingMaskActionFromContext(first.id))
        #expect(viewModel.document.layers.first { $0.id == first.id }?.isClippingMask == true)
        #expect(viewModel.document.layers.first { $0.id == second.id }?.isClippingMask == true)
        #expect(viewModel.document.layers.first { $0.id == base.id }?.isClippingMask == false)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.clippingMaskActionFromContext(first.id) == .release)

        viewModel.selectLayer(outside.id)
        #expect(viewModel.clippingMaskActionFromContext(first.id) == .release)
        #expect(viewModel.applyClippingMaskActionFromContext(first.id))
        #expect(viewModel.document.selectedLayerIDs == [first.id])
        #expect(viewModel.document.layers.first { $0.id == first.id }?.isClippingMask == false)
        #expect(viewModel.document.layers.first { $0.id == second.id }?.isClippingMask == true)

        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == first.id })
        viewModel.document.layers[firstIndex].isLocked = true
        #expect(viewModel.clippingMaskActionFromContext(first.id) == nil)
        #expect(!viewModel.applyClippingMaskActionFromContext(first.id))
        #expect(viewModel.clippingMaskActionFromContext(UUID()) == nil)
    }

    @Test func layerRowContextSmartObjectConversionPreservesSelectionOrTargetsOneRow() throws {
        let viewModel = makeViewModel()
        let first = layer("First", in: viewModel)
        let second = layer("Second", in: viewModel)
        let outside = layer("Outside", in: viewModel)
        viewModel.document.layers = [first, second, outside]
        select([first.id, second.id], primary: second.id, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canConvertLayersFromContext(first.id))
        #expect(viewModel.convertLayersFromContext(first.id))
        let combinedSmartObject = try #require(viewModel.document.selectedLayer)
        #expect(combinedSmartObject.isSmartObject)
        #expect(!viewModel.document.layers.contains { $0.id == first.id })
        #expect(!viewModel.document.layers.contains { $0.id == second.id })
        #expect(viewModel.document.layers.contains { $0.id == outside.id })
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerSmartObject"))

        viewModel.undo()
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        viewModel.selectLayer(first.id)
        #expect(viewModel.canConvertLayersFromContext(outside.id))
        #expect(viewModel.convertLayersFromContext(outside.id))
        let rowSmartObject = try #require(viewModel.document.selectedLayer)
        #expect(rowSmartObject.isSmartObject)
        #expect(viewModel.document.layers.contains { $0.id == first.id })
        #expect(viewModel.document.layers.contains { $0.id == second.id })
        #expect(!viewModel.document.layers.contains { $0.id == outside.id })

        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == first.id })
        viewModel.document.layers[firstIndex].isLocked = true
        #expect(!viewModel.canConvertLayersFromContext(first.id))
        #expect(!viewModel.convertLayersFromContext(first.id))
        #expect(!viewModel.canConvertLayersFromContext(rowSmartObject.id))
        #expect(!viewModel.canConvertLayersFromContext(UUID()))
    }

    @Test func layerRowContextLabelsPreserveSelectionTargetLocksAndNoOpRedo() throws {
        let viewModel = makeViewModel()
        let first = layer("First", in: viewModel)
        let second = layer("Second", in: viewModel)
        var outside = layer("Outside", in: viewModel)
        outside.isLocked = true
        viewModel.document.layers = [first, second, outside]
        select([first.id, second.id], primary: second.id, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canSetLayersLabelColorFromContext(first.id, labelColor: .green))
        #expect(!viewModel.layersFromContextHaveLabelColor(first.id, labelColor: .green))
        #expect(viewModel.setLayersLabelColorFromContext(first.id, labelColor: .green))
        #expect(viewModel.document.layers.first { $0.id == first.id }?.labelColor == .green)
        #expect(viewModel.document.layers.first { $0.id == second.id }?.labelColor == .green)
        #expect(viewModel.document.layers.first { $0.id == outside.id }?.labelColor == nil)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.layersFromContextHaveLabelColor(first.id, labelColor: .green))
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.canRedo)
        #expect(viewModel.layersFromContextHaveLabelColor(first.id, labelColor: nil))
        #expect(!viewModel.canSetLayersLabelColorFromContext(first.id, labelColor: nil))
        #expect(!viewModel.setLayersLabelColorFromContext(first.id, labelColor: nil))
        #expect(viewModel.canRedo)
        #expect(viewModel.document.history.count == historyCount)

        #expect(viewModel.canSetLayersLabelColorFromContext(outside.id, labelColor: .purple))
        #expect(viewModel.setLayersLabelColorFromContext(outside.id, labelColor: .purple))
        let labeledOutside = try #require(
            viewModel.document.layers.first { $0.id == outside.id }
        )
        #expect(labeledOutside.labelColor == .purple)
        #expect(labeledOutside.isLocked)
        #expect(viewModel.document.layers.first { $0.id == first.id }?.labelColor == nil)
        #expect(viewModel.document.layers.first { $0.id == second.id }?.labelColor == nil)
        #expect(viewModel.document.selectedLayerIDs == [outside.id])
        #expect(viewModel.layersFromContextHaveLabelColor(outside.id, labelColor: .purple))
        #expect(!viewModel.canSetLayersLabelColorFromContext(outside.id, labelColor: .purple))

        #expect(!viewModel.canSetLayersLabelColorFromContext(UUID(), labelColor: .red))
        #expect(!viewModel.layersFromContextHaveLabelColor(UUID(), labelColor: nil))
        #expect(!viewModel.setLayersLabelColorFromContext(UUID(), labelColor: .red))
    }

    @Test func layerRowContextMenuWiresClipboardDuplicateAndDestructiveDeleteThroughContextPolicy() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("veilpic/ImageEditorLayerPanel.swift"),
            encoding: .utf8
        )

        #expect(source.contains("viewModel.prepareLayerContextSelection(for: layer.id)"))
        #expect(source.contains("viewModel.canCutLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.canCopyLayersFromContext(layer.id)"))
        #expect(source.contains("layerContextOrderingMenu(layer)"))
        #expect(source.contains("viewModel.canMoveLayersFromContext("))
        #expect(source.contains("viewModel.moveLayersFromContext("))
        #expect(source.contains("viewModel.canGroupLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.canUngroupLayersFromContext(layer.id)"))
        #expect(source.contains("layerContextGroupExpansionButtons(layer)"))
        #expect(source.contains("viewModel.canSetLayerGroupsExpansionFromContext("))
        #expect(source.contains("viewModel.setLayerGroupsExpansionFromContext("))
        #expect(source.contains("viewModel.groupSelectedLayer()"))
        #expect(source.contains("viewModel.ungroupSelectedLayers()"))
        #expect(source.contains("layerContextClippingMaskButton(layer)"))
        #expect(source.contains("viewModel.clippingMaskActionFromContext(layer.id)"))
        #expect(source.contains("viewModel.applyClippingMaskActionFromContext(layer.id)"))
        #expect(source.contains("viewModel.canConvertLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.convertLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.canRasterizeLayersFromContext(layer.id, target: target)"))
        #expect(source.contains("viewModel.rasterizeLayersFromContext(layer.id, target: target)"))
        #expect(source.contains("layerContextMergeButton(layer)"))
        #expect(source.contains("viewModel.layerMergeActionFromContext(layer.id)"))
        #expect(source.contains("viewModel.layerMergeTitleKeyFromContext(layer.id)"))
        #expect(source.contains("viewModel.applyLayerMergeActionFromContext(layer.id)"))
        #expect(source.contains("viewModel.canSelectSimilarLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.selectSimilarLayersFromContext(layer.id)"))
        #expect(source.contains("layerContextMatchingSelectionMenu(layer)"))
        #expect(source.contains("viewModel.canSelectLayersWithSameKindFromContext(layer.id)"))
        #expect(source.contains("viewModel.selectLayersWithSameKindFromContext(layer.id)"))
        #expect(source.contains("viewModel.canSelectLayersWithSameBlendModeFromContext(layer.id)"))
        #expect(source.contains("viewModel.selectLayersWithSameBlendModeFromContext(layer.id)"))
        #expect(source.contains("viewModel.canSelectLayersWithSameLabelColorFromContext(layer.id)"))
        #expect(source.contains("viewModel.selectLayersWithSameLabelColorFromContext(layer.id)"))
        #expect(source.contains("layerContextLinksMenu(layer)"))
        #expect(source.contains("viewModel.canLinkLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.linkLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.canSelectLinkedLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.selectLinkedLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.canUnlinkLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.unlinkLayersFromContext(layer.id)"))
        #expect(source.contains("layerContextLockMenu(layer)"))
        #expect(source.contains("viewModel.canSetLayersLockFromContext("))
        #expect(source.contains("viewModel.setLayersLockFromContext("))
        #expect(source.contains("layerContextVisibilityMenu(layer)"))
        #expect(source.contains("viewModel.canSetLayersVisibilityFromContext("))
        #expect(source.contains("viewModel.setLayersVisibilityFromContext("))
        #expect(source.contains("viewModel.canIsolateLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.isolateLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.canShowAllLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.showAllLayersFromContext(layer.id)"))
        #expect(source.contains("layerContextStyleMenu(layer)"))
        #expect(source.contains("viewModel.canCopyLayerStyleFromContext(layer.id)"))
        #expect(source.contains("viewModel.copyLayerStyleFromContext(layer.id)"))
        #expect(source.contains("viewModel.canPasteLayerStyleFromContext(layer.id)"))
        #expect(source.contains("viewModel.pasteLayerStyleFromContext(layer.id)"))
        #expect(source.contains("viewModel.canClearLayerStylesFromContext(layer.id)"))
        #expect(source.contains("viewModel.clearLayerStylesFromContext(layer.id)"))
        #expect(source.contains("layerContextLabelColorMenu(layer)"))
        #expect(source.contains("viewModel.canSetLayersLabelColorFromContext"))
        #expect(source.contains("viewModel.layersFromContextHaveLabelColor"))
        #expect(source.contains("viewModel.setLayersLabelColorFromContext"))
        #expect(source.contains("image-editor-layer-context-group-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-ungroup-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-groups-expand-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-groups-collapse-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-clipping-mask-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-smart-object-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-rasterize-\\(target.rawValue)-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-merge-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-select-similar-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-select-same-kind-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-select-same-blend-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-select-same-label-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-select-attribute-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-link-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-select-linked-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-unlink-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-links-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-lock-\\(kind.rawValue)-\\(isLocked ? \"on\" : \"off\")-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-locks-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-visibility-show-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-visibility-hide-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-visibility-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-visibility-isolate-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-visibility-show-all-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-style-copy-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-style-paste-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-style-clear-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-label-none-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-label-\\(labelColor.rawValue)-\\(layer.id.uuidString)"))
        #expect(source.contains("viewModel.pasteClipboardAsLayer()"))
        #expect(source.contains("viewModel.pasteClipboardInPlaceAsLayer()"))
        #expect(source.contains("viewModel.canPasteClipboardImage"))
        #expect(source.contains("viewModel.canPasteClipboardImageInPlace"))
        #expect(source.contains("viewModel.canDuplicateLayersFromContext(layer.id)"))
        #expect(source.contains("viewModel.canDeleteLayersFromContext(layer.id)"))
        #expect(source.contains("Button(role: .destructive)"))
        #expect(source.contains("image-editor-layer-context-cut-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-copy-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-paste-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-paste-in-place-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-duplicate-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-order-\\(action.rawValue)-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-order-\\(layer.id.uuidString)"))
        #expect(source.contains("image-editor-layer-context-delete-\\(layer.id.uuidString)"))
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
