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

    @Test func layerPanelWiresEveryMaskContextActionThroughSharedPolicy() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceURL = testsDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("veilpic/ImageEditorLayerPanel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("layerContextLayerMaskMenu(layer)"))
        #expect(source.contains("ImageEditorLayerMaskContextAction.allCases"))
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

    private func select(
        _ ids: Set<UUID>,
        primary: UUID,
        in viewModel: ImageEditorViewModel
    ) {
        viewModel.document.selectedLayerIDs = ids
        viewModel.document.selectedLayerID = primary
    }
}
