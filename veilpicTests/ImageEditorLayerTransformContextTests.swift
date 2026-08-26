import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerTransformContextTests {
    @Test func unselectedContextRotatesOnlyClickedLayerAndUndoRestoresGeometry() throws {
        let viewModel = makeViewModel()
        let selectedID = try addPixelLayer(
            frame: CGRect(x: 12, y: 18, width: 24, height: 16),
            color: .systemBlue,
            to: viewModel
        )
        let clickedID = try addPixelLayer(
            frame: CGRect(x: 82, y: 42, width: 30, height: 12),
            color: .systemOrange,
            to: viewModel
        )
        viewModel.selectLayer(selectedID)
        let selectedFrame = frame(of: selectedID, in: viewModel)
        let clickedFrame = try #require(frame(of: clickedID, in: viewModel))
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canTransformLayersFromContext(
            clickedID,
            action: .rotateRight90
        ))
        #expect(viewModel.transformLayersFromContext(
            clickedID,
            action: .rotateRight90
        ))
        let rotatedFrame = try #require(frame(of: clickedID, in: viewModel))
        #expect(abs(rotatedFrame.midX - clickedFrame.midX) < 0.01)
        #expect(abs(rotatedFrame.midY - clickedFrame.midY) < 0.01)
        #expect(abs(rotatedFrame.width - clickedFrame.height) < 0.01)
        #expect(abs(rotatedFrame.height - clickedFrame.width) < 0.01)
        #expect(frame(of: selectedID, in: viewModel) == selectedFrame)
        #expect(viewModel.document.selectedLayerIDs == [clickedID])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerRotate"))

        viewModel.undo()
        #expect(frame(of: clickedID, in: viewModel) == clickedFrame)
        #expect(frame(of: selectedID, in: viewModel) == selectedFrame)
    }

    @Test func selectedContextFlipsSelectionAndLinkedPeersInOneUndoStep() throws {
        let viewModel = makeViewModel()
        let firstID = try addPixelLayer(
            frame: CGRect(x: 10, y: 20, width: 20, height: 12),
            color: .systemRed,
            to: viewModel
        )
        let linkedID = try addPixelLayer(
            frame: CGRect(x: 46, y: 36, width: 14, height: 10),
            color: .systemGreen,
            to: viewModel
        )
        let secondID = try addPixelLayer(
            frame: CGRect(x: 80, y: 18, width: 30, height: 16),
            color: .systemPurple,
            to: viewModel
        )
        link(firstID, linkedID, in: viewModel)
        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)
        let originalFrames = [firstID, linkedID, secondID].map {
            frame(of: $0, in: viewModel)
        }
        let historyCount = viewModel.document.history.count

        #expect(viewModel.transformLayersFromContext(
            firstID,
            action: .flipHorizontal
        ))
        #expect(frame(of: firstID, in: viewModel) == CGRect(
            x: 90,
            y: 20,
            width: 20,
            height: 12
        ))
        #expect(frame(of: linkedID, in: viewModel) == CGRect(
            x: 60,
            y: 36,
            width: 14,
            height: 10
        ))
        #expect(frame(of: secondID, in: viewModel) == CGRect(
            x: 10,
            y: 18,
            width: 30,
            height: 16
        ))
        #expect(viewModel.document.selectedLayerIDs == [firstID, secondID])
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerFlipHorizontal"
        ))

        viewModel.undo()
        #expect([firstID, linkedID, secondID].map {
            frame(of: $0, in: viewModel)
        } == originalFrames)
    }

    @Test func unselectedContextFitsAndFillsOnlyClickedLayerToCanvas() throws {
        let viewModel = makeViewModel()
        let selectedID = try addPixelLayer(
            frame: CGRect(x: 18, y: 16, width: 24, height: 18),
            color: .systemBlue,
            to: viewModel
        )
        let clickedID = try addPixelLayer(
            frame: CGRect(x: 68, y: 34, width: 40, height: 20),
            color: .systemOrange,
            to: viewModel
        )
        viewModel.selectLayer(selectedID)
        let selectedFrame = frame(of: selectedID, in: viewModel)
        let clickedFrame = frame(of: clickedID, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canTransformLayersFromContext(
            clickedID,
            action: .fitCanvas
        ))
        #expect(viewModel.transformLayersFromContext(
            clickedID,
            action: .fitCanvas
        ))
        #expect(frame(of: clickedID, in: viewModel) == CGRect(
            x: 0,
            y: 10,
            width: 160,
            height: 80
        ))
        #expect(frame(of: selectedID, in: viewModel) == selectedFrame)
        #expect(viewModel.document.selectedLayerIDs == [clickedID])
        #expect(!viewModel.canTransformLayersFromContext(
            clickedID,
            action: .fitCanvas
        ))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerFitCanvas"
        ))

        viewModel.undo()
        #expect(frame(of: clickedID, in: viewModel) == clickedFrame)
        #expect(viewModel.canTransformLayersFromContext(
            clickedID,
            action: .fillCanvas
        ))
        #expect(viewModel.transformLayersFromContext(
            clickedID,
            action: .fillCanvas
        ))
        #expect(frame(of: clickedID, in: viewModel) == CGRect(
            x: -20,
            y: 0,
            width: 200,
            height: 100
        ))
        #expect(frame(of: selectedID, in: viewModel) == selectedFrame)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerFillCanvas"
        ))
    }

    @Test func repeatedCanvasSizingContextActionsPreserveRedoAndHistory() throws {
        let viewModel = makeViewModel()
        let layerID = try addPixelLayer(
            frame: CGRect(x: 0, y: 0, width: 160, height: 100),
            color: .systemTeal,
            to: viewModel
        )
        viewModel.selectLayer(layerID)
        viewModel.setSelectedLayersLabelColor(.purple)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        let frameBefore = frame(of: layerID, in: viewModel)

        #expect(viewModel.canRedo)
        #expect(Set(ImageEditorLayerTransformContextAction.directionalActions)
            .union(ImageEditorLayerTransformContextAction.canvasSizingActions)
            .union(ImageEditorLayerTransformContextAction.selectionSizingActions)
            == Set(ImageEditorLayerTransformContextAction.allCases))
        for action in ImageEditorLayerTransformContextAction.canvasSizingActions {
            #expect(!viewModel.canTransformLayersFromContext(
                layerID,
                action: action
            ))
            #expect(!viewModel.transformLayersFromContext(
                layerID,
                action: action
            ))
        }

        #expect(frame(of: layerID, in: viewModel) == frameBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    @Test func unselectedContextFitsAndFillsOnlyClickedLayerToSelection() throws {
        let viewModel = makeViewModel()
        let selectedID = try addPixelLayer(
            frame: CGRect(x: 12, y: 14, width: 22, height: 16),
            color: .systemBlue,
            to: viewModel
        )
        let clickedID = try addPixelLayer(
            frame: CGRect(x: 76, y: 36, width: 40, height: 20),
            color: .systemOrange,
            to: viewModel
        )
        viewModel.document.selection = .rectangle(
            CGRect(x: 20, y: 10, width: 60, height: 60)
        )
        viewModel.selectLayer(selectedID)
        let selectedFrame = frame(of: selectedID, in: viewModel)
        let clickedFrame = frame(of: clickedID, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canTransformLayersFromContext(
            clickedID,
            action: .fitSelection
        ))
        #expect(viewModel.transformLayersFromContext(
            clickedID,
            action: .fitSelection
        ))
        #expect(frame(of: clickedID, in: viewModel) == CGRect(
            x: 20,
            y: 25,
            width: 60,
            height: 30
        ))
        #expect(frame(of: selectedID, in: viewModel) == selectedFrame)
        #expect(viewModel.document.selectedLayerIDs == [clickedID])
        #expect(!viewModel.canTransformLayersFromContext(
            clickedID,
            action: .fitSelection
        ))
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerFitSelection"
        ))

        viewModel.undo()
        #expect(frame(of: clickedID, in: viewModel) == clickedFrame)
        #expect(viewModel.canTransformLayersFromContext(
            clickedID,
            action: .fillSelection
        ))
        #expect(viewModel.transformLayersFromContext(
            clickedID,
            action: .fillSelection
        ))
        #expect(frame(of: clickedID, in: viewModel) == CGRect(
            x: -10,
            y: 10,
            width: 120,
            height: 60
        ))
        #expect(frame(of: selectedID, in: viewModel) == selectedFrame)
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerFillSelection"
        ))
    }

    @Test func missingSelectionContextActionsPreserveRedoAndHistory() throws {
        let viewModel = makeViewModel()
        let layerID = try addPixelLayer(
            frame: CGRect(x: 20, y: 18, width: 36, height: 24),
            color: .systemTeal,
            to: viewModel
        )
        viewModel.selectLayer(layerID)
        viewModel.setSelectedLayersLabelColor(.purple)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        let frameBefore = frame(of: layerID, in: viewModel)

        #expect(viewModel.document.selection == nil)
        #expect(viewModel.canRedo)
        for action in ImageEditorLayerTransformContextAction.selectionSizingActions {
            #expect(!viewModel.canTransformLayersFromContext(
                layerID,
                action: action
            ))
            #expect(!viewModel.transformLayersFromContext(
                layerID,
                action: action
            ))
        }

        #expect(frame(of: layerID, in: viewModel) == frameBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    @Test func invalidAndLockedContextTransformsAreAtomicNoOps() throws {
        let viewModel = makeViewModel()
        let layerID = try addPixelLayer(
            frame: CGRect(x: 24, y: 18, width: 36, height: 20),
            color: .systemTeal,
            to: viewModel
        )
        viewModel.selectLayer(layerID)
        viewModel.setSelectedLayersLabelColor(.purple)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        let frameBefore = frame(of: layerID, in: viewModel)
        let unknownID = UUID()
        let index = try #require(
            viewModel.document.layers.firstIndex { $0.id == layerID }
        )
        viewModel.document.layers[index].locksPixels = true

        #expect(viewModel.canRedo)
        for action in ImageEditorLayerTransformContextAction.allCases {
            #expect(!viewModel.canTransformLayersFromContext(
                layerID,
                action: action
            ))
            #expect(!viewModel.transformLayersFromContext(
                layerID,
                action: action
            ))
            #expect(!viewModel.canTransformLayersFromContext(
                unknownID,
                action: action
            ))
            #expect(!viewModel.transformLayersFromContext(
                unknownID,
                action: action
            ))
        }

        #expect(frame(of: layerID, in: viewModel) == frameBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "transform-context.png",
            image: image(color: .systemGray, size: NSSize(width: 160, height: 100))
        ) { _ in }
    }

    private func addPixelLayer(
        frame: CGRect,
        color: NSColor,
        to viewModel: ImageEditorViewModel
    ) throws -> UUID {
        viewModel.addLayer()
        let id = try #require(viewModel.document.selectedLayerID)
        let index = try #require(
            viewModel.document.layers.firstIndex { $0.id == id }
        )
        viewModel.document.layers[index].frame = frame
        viewModel.document.layers[index].image = image(color: color, size: frame.size)
        return id
    }

    private func link(
        _ firstID: UUID,
        _ secondID: UUID,
        in viewModel: ImageEditorViewModel
    ) {
        guard let firstIndex = viewModel.document.layers.firstIndex(where: { $0.id == firstID }),
              let secondIndex = viewModel.document.layers.firstIndex(where: { $0.id == secondID })
        else { return }
        viewModel.document.layers[firstIndex].linkedLayerIDs = [secondID]
        viewModel.document.layers[secondIndex].linkedLayerIDs = [firstID]
    }

    private func frame(
        of id: UUID,
        in viewModel: ImageEditorViewModel
    ) -> CGRect? {
        viewModel.document.layers.first { $0.id == id }?.frame.standardized
    }

    private func image(color: NSColor, size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }
}
