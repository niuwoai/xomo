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

    @Test func layerPanelWiresEveryMaskContextActionThroughSharedPolicy() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceURL = testsDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("veilpic/ImageEditorLayerPanel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("layerContextLayerMaskMenu(layer)"))
        #expect(source.contains("ImageEditorLayerMaskContextAction.creationActions"))
        #expect(source.contains("ImageEditorLayerMaskContextAction.selectionActions"))
        #expect(source.contains("ImageEditorLayerMaskContextAction.managementActions"))
        #expect(source.contains("viewModel.performLayerMaskActionFromContext("))
        #expect(source.contains("viewModel.canPerformLayerMaskActionFromContext("))
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

    private func select(
        _ ids: Set<UUID>,
        primary: UUID,
        in viewModel: ImageEditorViewModel
    ) {
        viewModel.document.selectedLayerIDs = ids
        viewModel.document.selectedLayerID = primary
    }
}
