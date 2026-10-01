import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorLayerMaskContextTests {
    @Test func selectedContextAddsRevealAllMasksInOneUndoStep() throws {
        let viewModel = makeViewModel()
        let first = layer(named: "First", in: viewModel)
        let second = layer(named: "Second", in: viewModel)
        let untouched = layer(named: "Untouched", in: viewModel)
        viewModel.document.layers = [first, second, untouched]
        select([first.id, second.id], primary: second.id, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canPerformLayerMaskActionFromContext(
            first.id,
            action: .revealAll
        ))
        #expect(viewModel.performLayerMaskActionFromContext(
            first.id,
            action: .revealAll
        ))
        #expect(viewModel.document.layers[0].mask != nil)
        #expect(viewModel.document.layers[1].mask != nil)
        #expect(viewModel.document.layers[2].mask == nil)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.document.selectedLayerID == second.id)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerMaskAddSelected"
        ))

        viewModel.undo()
        #expect(viewModel.document.layers.allSatisfy { $0.mask == nil })
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
    }

    @Test func unselectedContextTargetsOnlyClickedLayerFromSelection() throws {
        let viewModel = makeViewModel()
        let selected = layer(named: "Selected", in: viewModel)
        let clicked = layer(named: "Clicked", in: viewModel)
        let peer = layer(named: "Peer", in: viewModel)
        viewModel.document.layers = [selected, clicked, peer]
        select([selected.id, peer.id], primary: peer.id, in: viewModel)
        viewModel.createRectSelection(
            from: CGPoint(x: 8, y: 6),
            to: CGPoint(x: 40, y: 34)
        )

        #expect(viewModel.canPerformLayerMaskActionFromContext(
            clicked.id,
            action: .revealSelection
        ))
        #expect(viewModel.performLayerMaskActionFromContext(
            clicked.id,
            action: .revealSelection
        ))
        #expect(viewModel.document.layers[0].mask == nil)
        #expect(viewModel.document.layers[1].mask != nil)
        #expect(viewModel.document.layers[2].mask == nil)
        #expect(viewModel.document.selectedLayerIDs == [clicked.id])
        #expect(viewModel.document.selectedLayerID == clicked.id)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerMaskFromSelection"
        ))
    }

    @Test func selectedContextCreatesVectorMasksAndSkipsLockedLayers() throws {
        let viewModel = makeViewModel()
        let first = layer(named: "First Vector Target", in: viewModel)
        let second = layer(named: "Second Vector Target", in: viewModel)
        var locked = layer(named: "Locked Vector Target", in: viewModel)
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        select(
            [first.id, second.id, locked.id],
            primary: second.id,
            in: viewModel
        )
        viewModel.createRectSelection(
            from: CGPoint(x: 10, y: 7),
            to: CGPoint(x: 52, y: 40)
        )
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canPerformVectorMaskActionFromContext(
            first.id,
            action: .createFromSelection
        ))
        #expect(viewModel.performVectorMaskActionFromContext(
            first.id,
            action: .createFromSelection
        ))
        #expect(viewModel.document.layers[0].vectorMask?.kind == .path)
        #expect(viewModel.document.layers[0].vectorMask?.isPathClosed == true)
        #expect(viewModel.document.layers[1].vectorMask?.kind == .path)
        #expect(viewModel.document.layers[2].vectorMask == nil)
        #expect(viewModel.document.selectedLayerIDs == [
            first.id,
            second.id,
            locked.id
        ])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.vectorMaskFromSelectionSelected"
        ))

        viewModel.undo()
        #expect(viewModel.document.layers.allSatisfy { $0.vectorMask == nil })
    }

    @Test func unselectedVectorMaskContextTargetsOnlyClickedLayer() {
        let viewModel = makeViewModel()
        let selected = layer(named: "Selected", in: viewModel)
        let clicked = layer(named: "Clicked", in: viewModel)
        let peer = layer(named: "Peer", in: viewModel)
        viewModel.document.layers = [selected, clicked, peer]
        select([selected.id, peer.id], primary: peer.id, in: viewModel)
        viewModel.createRectSelection(
            from: CGPoint(x: 9, y: 8),
            to: CGPoint(x: 46, y: 36)
        )

        #expect(viewModel.performVectorMaskActionFromContext(
            clicked.id,
            action: .createFromSelection
        ))
        #expect(viewModel.document.layers[0].vectorMask == nil)
        #expect(viewModel.document.layers[1].vectorMask != nil)
        #expect(viewModel.document.layers[2].vectorMask == nil)
        #expect(viewModel.document.selectedLayerIDs == [clicked.id])
        #expect(viewModel.document.selectedLayerID == clicked.id)
    }

    @Test func vectorMaskToggleBatchesEditableSelectionAndSkipsLockedLayer() {
        let viewModel = makeViewModel()
        var first = layer(named: "First Vector", in: viewModel)
        var second = layer(named: "Second Vector", in: viewModel)
        var locked = layer(named: "Locked Vector", in: viewModel)
        first.vectorMask = vectorMask(size: first.image.size)
        second.vectorMask = vectorMask(size: second.image.size)
        locked.vectorMask = vectorMask(size: locked.image.size)
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        select(
            [first.id, second.id, locked.id],
            primary: second.id,
            in: viewModel
        )
        let historyCount = viewModel.document.history.count

        #expect(viewModel.performVectorMaskActionFromContext(
            first.id,
            action: .toggleEnabled
        ))
        #expect(viewModel.document.layers[0].isVectorMaskEnabled == false)
        #expect(viewModel.document.layers[1].isVectorMaskEnabled == false)
        #expect(viewModel.document.layers[2].isVectorMaskEnabled)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.selectedLayerIDs == [
            first.id,
            second.id,
            locked.id
        ])

        viewModel.undo()
        #expect(viewModel.document.layers.allSatisfy { $0.isVectorMaskEnabled })
    }

    @Test func vectorMaskLinkAndInvertBatchEditableSelectionWithOneUndoStep() {
        let viewModel = makeViewModel()
        var first = layer(named: "First Vector State", in: viewModel)
        var second = layer(named: "Second Vector State", in: viewModel)
        var locked = layer(named: "Locked Vector State", in: viewModel)
        first.vectorMask = vectorMask(size: first.image.size)
        second.vectorMask = vectorMask(size: second.image.size)
        locked.vectorMask = vectorMask(size: locked.image.size)
        first.isMaskLinked = true
        second.isMaskLinked = false
        locked.isMaskLinked = true
        first.isVectorMaskInverted = false
        second.isVectorMaskInverted = true
        locked.isVectorMaskInverted = false
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        select(
            [first.id, second.id, locked.id],
            primary: second.id,
            in: viewModel
        )
        let selectionBefore = viewModel.document.selectedLayerIDs
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canPerformVectorMaskActionFromContext(
            first.id,
            action: .toggleLinked
        ))
        #expect(viewModel.performVectorMaskActionFromContext(
            first.id,
            action: .toggleLinked
        ))
        #expect(viewModel.document.layers[0].isMaskLinked == false)
        #expect(viewModel.document.layers[1].isMaskLinked == false)
        #expect(viewModel.document.layers[2].isMaskLinked)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.vectorMaskUnlinkSelected"
        ))
        #expect(viewModel.document.selectedLayerIDs == selectionBefore)

        viewModel.undo()
        #expect(viewModel.document.layers[0].isMaskLinked)
        #expect(viewModel.document.layers[1].isMaskLinked == false)
        #expect(viewModel.document.layers[2].isMaskLinked)

        #expect(viewModel.canPerformVectorMaskActionFromContext(
            second.id,
            action: .invert
        ))
        #expect(viewModel.performVectorMaskActionFromContext(
            second.id,
            action: .invert
        ))
        #expect(viewModel.document.layers[0].isVectorMaskInverted)
        #expect(viewModel.document.layers[1].isVectorMaskInverted == false)
        #expect(viewModel.document.layers[2].isVectorMaskInverted == false)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.vectorMaskInvertSelected"
        ))
        #expect(viewModel.document.selectedLayerIDs == selectionBefore)

        viewModel.undo()
        #expect(viewModel.document.layers[0].isVectorMaskInverted == false)
        #expect(viewModel.document.layers[1].isVectorMaskInverted)
        #expect(viewModel.document.layers[2].isVectorMaskInverted == false)
    }

    @Test func unselectedVectorMaskStateContextTargetsOnlyClickedLayer() {
        let viewModel = makeViewModel()
        var selected = layer(named: "Selected Vector", in: viewModel)
        var clicked = layer(named: "Clicked Vector", in: viewModel)
        selected.vectorMask = vectorMask(size: selected.image.size)
        clicked.vectorMask = vectorMask(size: clicked.image.size)
        viewModel.document.layers = [selected, clicked]
        select([selected.id], primary: selected.id, in: viewModel)

        #expect(viewModel.performVectorMaskActionFromContext(
            clicked.id,
            action: .invert
        ))
        #expect(viewModel.document.layers[0].isVectorMaskInverted == false)
        #expect(viewModel.document.layers[1].isVectorMaskInverted)
        #expect(viewModel.document.selectedLayerIDs == [clicked.id])
        #expect(viewModel.document.selectedLayerID == clicked.id)

        viewModel.undo()
        #expect(viewModel.document.layers.allSatisfy {
            $0.isVectorMaskInverted == false
        })
        #expect(viewModel.document.selectedLayerIDs == [clicked.id])
    }

    @Test func vectorMaskEditUsesClickedLayerAndCreatesEditablePathInOneUndo() throws {
        let viewModel = makeViewModel()
        var first = layer(named: "First Vector", in: viewModel)
        var clicked = layer(named: "Clicked Vector", in: viewModel)
        first.vectorMask = vectorMask(size: first.image.size)
        clicked.vectorMask = vectorMask(size: clicked.image.size)
        viewModel.document.layers = [first, clicked]
        select([first.id, clicked.id], primary: first.id, in: viewModel)
        let originalLayerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canPerformVectorMaskActionFromContext(
            clicked.id,
            action: .editPath
        ))
        #expect(viewModel.performVectorMaskActionFromContext(
            clicked.id,
            action: .editPath
        ))
        let clickedAfter = try #require(viewModel.document.layers.first {
            $0.id == clicked.id
        })
        let pathLayer = try #require(viewModel.document.selectedLayer)
        #expect(clickedAfter.vectorMask == nil)
        #expect(pathLayer.id != clicked.id)
        #expect(pathLayer.shapeContent?.kind == .path)
        #expect(viewModel.document.selectedLayerIDs == [pathLayer.id])
        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.layers.first { $0.id == clicked.id }?.vectorMask != nil)
        #expect(viewModel.document.selectedLayerIDs == [clicked.id])
    }

    @Test func vectorMaskLoadSelectionUsesClickedTargetAndRejectsEquivalentReload() throws {
        let viewModel = makeViewModel()
        var left = layer(named: "Left Vector", in: viewModel)
        var right = layer(named: "Right Vector", in: viewModel)
        left.vectorMask = vectorMask(
            size: left.image.size,
            rect: CGRect(x: 2, y: 4, width: 20, height: 38)
        )
        right.vectorMask = vectorMask(
            size: right.image.size,
            rect: CGRect(x: 42, y: 4, width: 20, height: 38)
        )
        viewModel.document.layers = [left, right]
        select([left.id, right.id], primary: left.id, in: viewModel)
        viewModel.selectionMode = .replace

        #expect(viewModel.performVectorMaskActionFromContext(
            right.id,
            action: .loadSelection
        ))
        let bounds = try #require(viewModel.document.selection?
            .effectiveSelectedBounds(in: viewModel.document.canvasSize))
        #expect(bounds.minX >= 41)
        #expect(bounds.maxX >= 61)
        #expect(viewModel.document.selectedLayerIDs == [left.id, right.id])
        #expect(viewModel.document.selectedLayerID == left.id)
        #expect(!viewModel.canPerformVectorMaskActionFromContext(
            right.id,
            action: .loadSelection
        ))
    }

    @Test func vectorMaskCopyUsesClickedSourceAndSkipsLockedTargets() throws {
        let viewModel = makeViewModel()
        var source = layer(named: "Vector Source", in: viewModel)
        var target = layer(named: "Vector Target", in: viewModel)
        var locked = layer(named: "Locked Vector Target", in: viewModel)
        source.vectorMask = vectorMask(
            size: source.image.size,
            rect: CGRect(x: 8, y: 6, width: 40, height: 30)
        )
        source.isVectorMaskEnabled = false
        source.isVectorMaskInverted = true
        source.isMaskLinked = false
        target.image = NSImage.transparent(size: CGSize(width: 32, height: 24))
        target.frame.size = target.image.size
        locked.isLocked = true
        viewModel.document.layers = [source, target, locked]
        select(
            [source.id, target.id, locked.id],
            primary: target.id,
            in: viewModel
        )
        let selectionBefore = viewModel.document.selectedLayerIDs
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canPerformVectorMaskActionFromContext(
            source.id,
            action: .copyToSelected
        ))
        #expect(viewModel.performVectorMaskActionFromContext(
            source.id,
            action: .copyToSelected
        ))
        let copiedMask = try #require(viewModel.document.layers[1].vectorMask)
        #expect(copiedMask.editablePathAnchors.map(\.point) == [
            CGPoint(x: 4, y: 3),
            CGPoint(x: 24, y: 3),
            CGPoint(x: 24, y: 18),
            CGPoint(x: 4, y: 18)
        ])
        #expect(viewModel.document.layers[1].isVectorMaskEnabled == false)
        #expect(viewModel.document.layers[1].isVectorMaskInverted)
        #expect(viewModel.document.layers[1].isMaskLinked == false)
        #expect(viewModel.document.layers[2].vectorMask == nil)
        #expect(viewModel.document.selectedLayerIDs == selectionBefore)
        #expect(viewModel.document.selectedLayerID == source.id)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.vectorMaskCopy"
        ))

        viewModel.undo()
        #expect(viewModel.document.layers[0].vectorMask != nil)
        #expect(viewModel.document.layers[1].vectorMask == nil)
        #expect(viewModel.document.layers[2].vectorMask == nil)
    }

    @Test func equivalentVectorMaskCopyIsUnavailableAndPreservesRedo() {
        let viewModel = makeViewModel()
        var source = layer(named: "Vector Source", in: viewModel)
        var target = layer(named: "Equivalent Vector Target", in: viewModel)
        let sharedMask = vectorMask(size: source.image.size)
        source.vectorMask = sharedMask
        target.vectorMask = sharedMask
        viewModel.document.layers = [source, target]
        select([source.id, target.id], primary: target.id, in: viewModel)
        viewModel.setSelectedLayersLabelColor(.green)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        #expect(viewModel.canRedo)

        #expect(!viewModel.canPerformVectorMaskActionFromContext(
            source.id,
            action: .copyToSelected
        ))
        #expect(!viewModel.performVectorMaskActionFromContext(
            source.id,
            action: .copyToSelected
        ))
        #expect(viewModel.document.selectedLayerID == target.id)
        #expect(viewModel.document.selectedLayerIDs == [source.id, target.id])
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    @Test func vectorMaskDestructiveContextActionsSkipLockedLayersAndUndoAtomically() {
        let actions: [ImageEditorVectorMaskContextAction] = [
            .apply,
            .rasterize,
            .delete
        ]

        for action in actions {
            let viewModel = makeViewModel()
            var editable = layer(named: "Editable Vector", in: viewModel)
            var locked = layer(named: "Locked Vector", in: viewModel)
            editable.vectorMask = vectorMask(size: editable.image.size)
            locked.vectorMask = vectorMask(size: locked.image.size)
            locked.isLocked = true
            viewModel.document.layers = [editable, locked]
            select(
                [editable.id, locked.id],
                primary: editable.id,
                in: viewModel
            )
            let historyCount = viewModel.document.history.count

            #expect(viewModel.canPerformVectorMaskActionFromContext(
                editable.id,
                action: action
            ))
            #expect(viewModel.performVectorMaskActionFromContext(
                editable.id,
                action: action
            ))
            #expect(viewModel.document.layers[0].vectorMask == nil)
            #expect(viewModel.document.layers[1].vectorMask != nil)
            if action == .rasterize {
                #expect(viewModel.document.layers[0].mask != nil)
            } else {
                #expect(viewModel.document.layers[0].mask == nil)
            }
            #expect(viewModel.document.history.count == historyCount + 1)

            viewModel.undo()
            #expect(viewModel.document.layers.allSatisfy { $0.vectorMask != nil })
            #expect(viewModel.document.layers.allSatisfy { $0.mask == nil })
            #expect(viewModel.document.history.count == historyCount)
        }
    }

    @Test func unavailableContextActionsDoNotMutateSelectionOrHistory() {
        let viewModel = makeViewModel()
        let selected = layer(named: "Selected", in: viewModel)
        var locked = layer(named: "Locked", in: viewModel)
        locked.isLocked = true
        viewModel.document.layers = [selected, locked]
        select([selected.id], primary: selected.id, in: viewModel)
        viewModel.setSelectedLayersLabelColor(.red)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        let selectionBefore = viewModel.document.selectedLayerIDs
        #expect(viewModel.canRedo)

        for action in ImageEditorLayerMaskContextAction.allCases {
            #expect(!viewModel.canPerformLayerMaskActionFromContext(
                locked.id,
                action: action
            ))
            #expect(!viewModel.performLayerMaskActionFromContext(
                locked.id,
                action: action
            ))
        }
        for action in ImageEditorVectorMaskContextAction.allCases {
            #expect(!viewModel.canPerformVectorMaskActionFromContext(
                locked.id,
                action: action
            ))
            #expect(!viewModel.performVectorMaskActionFromContext(
                locked.id,
                action: action
            ))
        }
        #expect(viewModel.document.selectedLayerIDs == selectionBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    @Test func managementActionsBatchToggleLinkAndInvertEditableMasks() throws {
        let viewModel = makeViewModel()
        var first = layer(named: "First Mask", in: viewModel)
        var second = layer(named: "Second Mask", in: viewModel)
        var locked = layer(named: "Locked Mask", in: viewModel)
        first.mask = NSImage.opaqueMask(size: first.image.size)
        second.mask = NSImage.opaqueMask(size: second.image.size)
        locked.mask = NSImage.opaqueMask(size: locked.image.size)
        locked.isLocked = true
        viewModel.document.layers = [first, second, locked]
        select([first.id, second.id, locked.id], primary: second.id, in: viewModel)
        let selectionBefore = viewModel.document.selectedLayerIDs

        let historyBeforeToggle = viewModel.document.history.count
        #expect(viewModel.performLayerMaskActionFromContext(
            first.id,
            action: .toggleEnabled
        ))
        #expect(viewModel.document.layers[0].isMaskEnabled == false)
        #expect(viewModel.document.layers[1].isMaskEnabled == false)
        #expect(viewModel.document.layers[2].isMaskEnabled)
        #expect(viewModel.document.history.count == historyBeforeToggle + 1)
        viewModel.undo()

        #expect(viewModel.performLayerMaskActionFromContext(
            second.id,
            action: .toggleLinked
        ))
        #expect(viewModel.document.layers[0].isMaskLinked == false)
        #expect(viewModel.document.layers[1].isMaskLinked == false)
        #expect(viewModel.document.layers[2].isMaskLinked)
        viewModel.undo()

        let originalMask = try #require(viewModel.document.layers[0].mask)
        #expect(viewModel.performLayerMaskActionFromContext(
            first.id,
            action: .invert
        ))
        let invertedMask = try #require(viewModel.document.layers[0].mask)
        #expect(!originalMask.hasEquivalentAlphaMask(to: invertedMask))
        #expect(viewModel.document.layers[1].mask?.hasEquivalentAlphaMask(
            to: invertedMask
        ) == true)
        #expect(viewModel.document.layers[2].mask?.hasEquivalentAlphaMask(
            to: originalMask
        ) == true)
        #expect(viewModel.document.selectedLayerIDs == selectionBefore)
        viewModel.undo()
        #expect(viewModel.document.layers[0].mask?.hasEquivalentAlphaMask(
            to: originalMask
        ) == true)
    }

    @Test func editActionUsesClickedMaskAsPrimaryWithoutCollapsingSelection() {
        let viewModel = makeViewModel()
        let plain = layer(named: "Plain", in: viewModel)
        var masked = layer(named: "Masked", in: viewModel)
        masked.mask = NSImage.opaqueMask(size: masked.image.size)
        viewModel.document.layers = [plain, masked]
        select([plain.id, masked.id], primary: plain.id, in: viewModel)
        let historyBefore = viewModel.document.history

        #expect(!viewModel.canPerformLayerMaskActionFromContext(
            plain.id,
            action: .edit
        ))
        #expect(viewModel.canPerformLayerMaskActionFromContext(
            masked.id,
            action: .edit
        ))
        #expect(viewModel.performLayerMaskActionFromContext(
            masked.id,
            action: .edit
        ))
        #expect(viewModel.document.selectedLayerID == masked.id)
        #expect(viewModel.document.selectedLayerIDs == [plain.id, masked.id])
        #expect(viewModel.isEditingLayerMask)
        #expect(viewModel.document.history == historyBefore)
    }

    @Test func applyAndDeleteActionsSkipLockedSelectedMasksAndUndoAtomically() {
        let viewModel = makeViewModel()
        var editable = layer(named: "Editable", in: viewModel)
        var locked = layer(named: "Locked", in: viewModel)
        editable.mask = NSImage.opaqueMask(size: editable.image.size)
        locked.mask = NSImage.opaqueMask(size: locked.image.size)
        locked.isLocked = true
        viewModel.document.layers = [editable, locked]
        select([editable.id, locked.id], primary: editable.id, in: viewModel)
        let historyBefore = viewModel.document.history.count

        #expect(viewModel.performLayerMaskActionFromContext(
            editable.id,
            action: .apply
        ))
        #expect(viewModel.document.layers[0].mask == nil)
        #expect(viewModel.document.layers[1].mask != nil)
        #expect(viewModel.document.history.count == historyBefore + 1)
        viewModel.undo()
        #expect(viewModel.document.layers.allSatisfy { $0.mask != nil })

        #expect(viewModel.performLayerMaskActionFromContext(
            editable.id,
            action: .delete
        ))
        #expect(viewModel.document.layers[0].mask == nil)
        #expect(viewModel.document.layers[1].mask != nil)
        #expect(viewModel.document.history.count == historyBefore + 1)
        viewModel.undo()
        #expect(viewModel.document.layers.allSatisfy { $0.mask != nil })
    }

    @Test func selectionCombinationActionsBatchOnlyRealEditableMaskChanges() throws {
        let cases: [(ImageEditorLayerMaskContextAction, Bool)] = [
            (.revealSelectionOnMask, false),
            (.hideSelectionOnMask, true),
            (.intersectSelectionOnMask, true)
        ]

        for (action, startsOpaque) in cases {
            let viewModel = makeViewModel()
            var first = layer(named: "First", in: viewModel)
            var second = layer(named: "Second", in: viewModel)
            var locked = layer(named: "Locked", in: viewModel)
            let initialMask = startsOpaque
                ? NSImage.opaqueMask(size: first.image.size)
                : NSImage.transparent(size: first.image.size)
            first.mask = initialMask
            second.mask = initialMask
            locked.mask = initialMask
            locked.isLocked = true
            viewModel.document.layers = [first, second, locked]
            select(
                [first.id, second.id, locked.id],
                primary: second.id,
                in: viewModel
            )
            viewModel.createRectSelection(
                from: CGPoint(x: 12, y: 8),
                to: CGPoint(x: 48, y: 38)
            )
            let historyCount = viewModel.document.history.count

            #expect(viewModel.canPerformLayerMaskActionFromContext(
                first.id,
                action: action
            ))
            #expect(viewModel.performLayerMaskActionFromContext(
                first.id,
                action: action
            ))
            let firstResult = try #require(viewModel.document.layers[0].mask)
            let secondResult = try #require(viewModel.document.layers[1].mask)
            let lockedResult = try #require(viewModel.document.layers[2].mask)
            #expect(!firstResult.hasEquivalentAlphaMask(to: initialMask))
            #expect(secondResult.hasEquivalentAlphaMask(to: firstResult))
            #expect(lockedResult.hasEquivalentAlphaMask(to: initialMask))
            #expect(viewModel.document.history.count == historyCount + 1)
            #expect(viewModel.document.selectedLayerIDs == [
                first.id,
                second.id,
                locked.id
            ])

            viewModel.undo()
            #expect(viewModel.document.layers.allSatisfy { layer in
                layer.mask?.hasEquivalentAlphaMask(to: initialMask) == true
            })
        }
    }

    @Test func loadSelectionUsesOnlyClickedMaskAndEquivalentReloadPreservesRedo() throws {
        let viewModel = makeViewModel()
        var left = layer(named: "Left", in: viewModel)
        var right = layer(named: "Right", in: viewModel)
        left.mask = mask(
            size: left.image.size,
            selectedRect: CGRect(x: 0, y: 0, width: 24, height: 48)
        )
        right.mask = mask(
            size: right.image.size,
            selectedRect: CGRect(x: 40, y: 0, width: 24, height: 48)
        )
        viewModel.document.layers = [left, right]
        select([left.id, right.id], primary: left.id, in: viewModel)
        viewModel.selectionMode = .replace
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canPerformLayerMaskActionFromContext(
            right.id,
            action: .loadSelection
        ))
        #expect(viewModel.performLayerMaskActionFromContext(
            right.id,
            action: .loadSelection
        ))
        let bounds = try #require(viewModel.document.selection?
            .effectiveSelectedBounds(in: viewModel.document.canvasSize))
        #expect(bounds.minX >= 39)
        #expect(bounds.maxX >= 63)
        #expect(viewModel.document.selectedLayerIDs == [left.id, right.id])
        #expect(viewModel.document.selectedLayerID == left.id)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.selectionFromLayerMask"
        ))

        viewModel.setSelectedLayersLabelColor(.purple)
        viewModel.undo()
        let historyBeforeReload = viewModel.document.history
        #expect(viewModel.canRedo)
        #expect(!viewModel.canPerformLayerMaskActionFromContext(
            right.id,
            action: .loadSelection
        ))
        #expect(!viewModel.performLayerMaskActionFromContext(
            right.id,
            action: .loadSelection
        ))
        #expect(viewModel.document.history == historyBeforeReload)
        #expect(viewModel.canRedo)
    }

    @Test func copyActionUsesClickedMaskAsSourceAndSkipsLockedTargets() throws {
        let viewModel = makeViewModel()
        var source = layer(named: "Source Mask", in: viewModel)
        let target = layer(named: "Target", in: viewModel)
        var locked = layer(named: "Locked Target", in: viewModel)
        source.mask = mask(
            size: source.image.size,
            selectedRect: CGRect(x: 8, y: 6, width: 34, height: 28)
        )
        source.isMaskEnabled = false
        source.isMaskLinked = false
        source.maskDensity = 0.42
        source.maskFeather = 3
        locked.isLocked = true
        viewModel.document.layers = [source, target, locked]
        select(
            [source.id, target.id, locked.id],
            primary: target.id,
            in: viewModel
        )
        let selectionBefore = viewModel.document.selectedLayerIDs
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canPerformLayerMaskActionFromContext(
            source.id,
            action: .copyToSelected
        ))
        #expect(viewModel.performLayerMaskActionFromContext(
            source.id,
            action: .copyToSelected
        ))
        let sourceResult = try #require(viewModel.document.layers[0].mask)
        let targetResult = try #require(viewModel.document.layers[1].mask)
        #expect(targetResult.hasEquivalentAlphaMask(to: sourceResult))
        #expect(viewModel.document.layers[1].isMaskEnabled == false)
        #expect(viewModel.document.layers[1].isMaskLinked == false)
        #expect(viewModel.document.layers[1].maskDensity == 0.42)
        #expect(viewModel.document.layers[1].maskFeather == 3)
        #expect(viewModel.document.layers[2].mask == nil)
        #expect(viewModel.document.selectedLayerIDs == selectionBefore)
        #expect(viewModel.document.selectedLayerID == source.id)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerMaskCopy"
        ))

        viewModel.undo()
        #expect(viewModel.document.layers[0].mask != nil)
        #expect(viewModel.document.layers[1].mask == nil)
        #expect(viewModel.document.layers[2].mask == nil)
    }

    @Test func equivalentMaskCopyIsUnavailableAndPreservesRedoAndPrimaryTarget() throws {
        let viewModel = makeViewModel()
        var source = layer(named: "Source", in: viewModel)
        var target = layer(named: "Equivalent Target", in: viewModel)
        let sharedMask = mask(
            size: source.image.size,
            selectedRect: CGRect(x: 10, y: 8, width: 30, height: 24)
        )
        source.mask = sharedMask
        target.mask = sharedMask
        viewModel.document.layers = [source, target]
        select([source.id, target.id], primary: target.id, in: viewModel)
        viewModel.setSelectedLayersLabelColor(.orange)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        #expect(viewModel.canRedo)

        #expect(!viewModel.canPerformLayerMaskActionFromContext(
            source.id,
            action: .copyToSelected
        ))
        #expect(!viewModel.performLayerMaskActionFromContext(
            source.id,
            action: .copyToSelected
        ))
        #expect(viewModel.document.selectedLayerID == target.id)
        #expect(viewModel.document.selectedLayerIDs == [source.id, target.id])
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    @Test func unchangedDirectMaskCopiesPreserveEditingFocusAndHistory() {
        let viewModel = makeViewModel()
        var source = layer(named: "Source", in: viewModel)
        var target = layer(named: "Equivalent Target", in: viewModel)
        let sharedRasterMask = mask(
            size: source.image.size,
            selectedRect: CGRect(x: 10, y: 8, width: 30, height: 24)
        )
        let sharedVectorMask = vectorMask(size: source.image.size)
        source.mask = sharedRasterMask
        target.mask = sharedRasterMask
        source.vectorMask = sharedVectorMask
        target.vectorMask = sharedVectorMask
        viewModel.document.layers = [source, target]
        select([source.id, target.id], primary: source.id, in: viewModel)
        let historyBefore = viewModel.document.history

        viewModel.isEditingLayerMask = true
        viewModel.copyLayerMaskToSelectedLayers()

        #expect(viewModel.isEditingLayerMask)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.layerMaskCopyUnchanged"))

        viewModel.isEditingLayerMask = true
        viewModel.copyVectorMaskToSelectedLayers()

        #expect(viewModel.isEditingLayerMask)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.vectorMaskCopyUnchanged"))
    }

    @Test func rasterMaskCopyRejectsTargetsOverTheSamplingBudgetAtomically() {
        let viewModel = makeViewModel()
        var source = layer(named: "Source", in: viewModel)
        var validTarget = layer(named: "Valid Target", in: viewModel)
        var oversizedTarget = layer(named: "Oversized Target", in: viewModel)
        source.mask = mask(
            size: source.image.size,
            selectedRect: CGRect(x: 10, y: 8, width: 30, height: 24)
        )
        let originalValidTargetMask = mask(
            size: validTarget.image.size,
            selectedRect: CGRect(x: 2, y: 3, width: 12, height: 9)
        )
        let originalOversizedTargetMask = mask(
            size: CGSize(width: 2, height: 2),
            selectedRect: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        validTarget.mask = originalValidTargetMask
        oversizedTarget.image = NSImage(size: CGSize(width: 100_000, height: 100_000))
        oversizedTarget.mask = originalOversizedTargetMask
        viewModel.document.layers = [source, validTarget, oversizedTarget]
        select([source.id, validTarget.id, oversizedTarget.id], primary: source.id, in: viewModel)
        viewModel.isEditingLayerMask = true
        let historyBefore = viewModel.document.history

        #expect(viewModel.canCopyLayerMaskToSelectedLayers)
        viewModel.copyLayerMaskToSelectedLayers()

        #expect(viewModel.document.layers[1].mask === originalValidTargetMask)
        #expect(viewModel.document.layers[2].mask === originalOversizedTargetMask)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.isEditingLayerMask)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @Test func layerPanelWiresEveryMaskContextActionThroughSharedPolicy() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceURL = testsDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("veilpic/ImageEditorLayerPanel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let menuSource = try String(
            contentsOf: testsDirectory
                .deletingLastPathComponent()
                .appendingPathComponent("veilpic/ImageEditorMenuBar.swift"),
            encoding: .utf8
        )

        #expect(source.contains("layerContextLayerMaskMenu(layer)"))
        #expect(source.contains("ImageEditorLayerMaskContextAction.creationActions"))
        #expect(source.contains("ImageEditorLayerMaskContextAction.selectionActions"))
        #expect(source.contains("ImageEditorLayerMaskContextAction.managementActions"))
        #expect(source.contains("viewModel.performLayerMaskActionFromContext("))
        #expect(source.contains("viewModel.canPerformLayerMaskActionFromContext("))
        #expect(source.contains("layerContextVectorMaskMenu(layer)"))
        #expect(source.contains("ImageEditorVectorMaskContextAction.allCases"))
        #expect(source.contains("viewModel.performVectorMaskActionFromContext("))
        #expect(source.contains("viewModel.canPerformVectorMaskActionFromContext("))
        #expect(source.contains("viewModel.toggleVectorMaskLinked()"))
        #expect(source.contains("viewModel.invertVectorMask()"))
        #expect(menuSource.contains("viewModel.toggleVectorMaskLinked()"))
        #expect(menuSource.contains("viewModel.canToggleVectorMaskLinked"))
        #expect(menuSource.contains("viewModel.invertVectorMask()"))
        #expect(menuSource.contains("viewModel.canInvertVectorMask"))
        #expect(source.contains("image-editor-layer-context-mask-\\(action.rawValue)-\\(layer.id.uuidString)"))
    }

    private func makeViewModel() -> ImageEditorViewModel {
        let size = CGSize(width: 64, height: 48)
        let image = NSImage.rendered(size: size) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        } ?? NSImage(size: size)
        return ImageEditorViewModel(sourceName: "context-mask.png", image: image) { _ in }
    }

    private func layer(
        named name: String,
        in viewModel: ImageEditorViewModel
    ) -> ImageEditorLayer {
        ImageEditorLayer.blank(name: name, size: viewModel.document.canvasSize)
    }

    private func mask(
        size: CGSize,
        selectedRect: CGRect
    ) -> NSImage {
        NSImage.rendered(size: size) { _ in
            NSColor.white.setFill()
            selectedRect.fill()
        } ?? NSImage(size: size)
    }

    private func vectorMask(
        size: CGSize,
        rect: CGRect? = nil
    ) -> ImageEditorShapeContent {
        let pathRect = rect ?? CGRect(
            x: 8,
            y: 6,
            width: max(1, size.width - 16),
            height: max(1, size.height - 12)
        )
        let points = [
            CGPoint(x: pathRect.minX, y: pathRect.minY),
            CGPoint(x: pathRect.maxX, y: pathRect.minY),
            CGPoint(x: pathRect.maxX, y: pathRect.maxY),
            CGPoint(x: pathRect.minX, y: pathRect.maxY)
        ]
        return ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .white,
            strokeWidth: 1,
            strokeOpacity: 0,
            pathPoints: points,
            pathAnchors: points.map { ImageEditorPathAnchor(point: $0) },
            isPathClosed: true
        ).normalized(size: size)
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
