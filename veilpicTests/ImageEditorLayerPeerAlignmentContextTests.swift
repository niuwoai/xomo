import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerPeerAlignmentContextTests {
    @Test func selectedContextAlignsLayersToTheirSharedBoundsAndUndoRestoresFrames() throws {
        let viewModel = makeViewModel()
        let first = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let second = try #require(viewModel.document.selectedLayer)
        setPixelLayer(
            frame: CGRect(x: 10, y: 12, width: 20, height: 18),
            id: first.id,
            color: .systemBlue,
            in: viewModel
        )
        setPixelLayer(
            frame: CGRect(x: 70, y: 42, width: 40, height: 24),
            id: second.id,
            color: .systemGreen,
            in: viewModel
        )
        let firstFrame = frame(of: first.id, in: viewModel)
        let secondFrame = frame(of: second.id, in: viewModel)
        viewModel.selectLayer(first.id)
        viewModel.selectLayer(second.id, extendingSelection: true)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canAlignLayersFromContextToSelectedLayers(
            first.id,
            alignment: .horizontalCenter
        ))
        #expect(viewModel.alignLayersFromContextToSelectedLayers(
            first.id,
            alignment: .horizontalCenter
        ))
        #expect(frame(of: first.id, in: viewModel)?.midX == 60)
        #expect(frame(of: second.id, in: viewModel)?.midX == 60)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(frame(of: first.id, in: viewModel) == firstFrame)
        #expect(frame(of: second.id, in: viewModel) == secondFrame)
    }

    @Test func unselectedGroupContextAlignsItsExpandedChildrenOnly() throws {
        let viewModel = makeViewModel()
        let first = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let second = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let outside = try #require(viewModel.document.selectedLayer)
        setPixelLayer(
            frame: CGRect(x: 12, y: 10, width: 20, height: 18),
            id: first.id,
            color: .systemBlue,
            in: viewModel
        )
        setPixelLayer(
            frame: CGRect(x: 66, y: 40, width: 34, height: 22),
            id: second.id,
            color: .systemGreen,
            in: viewModel
        )
        setPixelLayer(
            frame: CGRect(x: 118, y: 72, width: 18, height: 16),
            id: outside.id,
            color: .systemOrange,
            in: viewModel
        )
        let outsideFrame = frame(of: outside.id, in: viewModel)
        viewModel.selectLayer(first.id)
        viewModel.selectLayer(second.id, extendingSelection: true)
        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)
        viewModel.selectLayer(outside.id)

        #expect(viewModel.alignLayersFromContextToSelectedLayers(
            groupID,
            alignment: .right
        ))
        #expect(frame(of: first.id, in: viewModel)?.maxX == 100)
        #expect(frame(of: second.id, in: viewModel)?.maxX == 100)
        #expect(frame(of: outside.id, in: viewModel) == outsideFrame)
        #expect(viewModel.document.selectedLayerIDs == [groupID])
    }

    @Test func singleInvalidLockedAndRepeatedTargetsAreAtomicNoOps() throws {
        let viewModel = makeViewModel()
        let first = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let second = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let outside = try #require(viewModel.document.selectedLayer)
        setPixelLayer(
            frame: CGRect(x: 20, y: 12, width: 24, height: 18),
            id: first.id,
            color: .systemBlue,
            in: viewModel
        )
        setPixelLayer(
            frame: CGRect(x: 20, y: 48, width: 32, height: 20),
            id: second.id,
            color: .systemGreen,
            in: viewModel
        )
        setPixelLayer(
            frame: CGRect(x: 90, y: 30, width: 18, height: 16),
            id: outside.id,
            color: .systemOrange,
            in: viewModel
        )
        viewModel.selectLayer(first.id)
        viewModel.selectLayer(second.id, extendingSelection: true)
        viewModel.setSelectedLayersLabelColor(.purple)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        let firstFrame = frame(of: first.id, in: viewModel)
        let secondFrame = frame(of: second.id, in: viewModel)

        #expect(viewModel.canRedo)
        #expect(!viewModel.canAlignLayersFromContextToSelectedLayers(
            outside.id,
            alignment: .right
        ))
        #expect(!viewModel.alignLayersFromContextToSelectedLayers(
            outside.id,
            alignment: .right
        ))
        #expect(!viewModel.alignLayersFromContextToSelectedLayers(
            UUID(),
            alignment: .right
        ))
        #expect(!viewModel.canAlignLayersFromContextToSelectedLayers(
            first.id,
            alignment: .left
        ))
        #expect(!viewModel.alignLayersFromContextToSelectedLayers(
            first.id,
            alignment: .left
        ))

        let firstIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == first.id }
        )
        viewModel.document.layers[firstIndex].locksPosition = true
        #expect(!viewModel.canAlignLayersFromContextToSelectedLayers(
            first.id,
            alignment: .right
        ))
        #expect(!viewModel.alignLayersFromContextToSelectedLayers(
            first.id,
            alignment: .right
        ))
        #expect(frame(of: first.id, in: viewModel) == firstFrame)
        #expect(frame(of: second.id, in: viewModel) == secondFrame)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "peer-alignment-context.png",
            image: image(color: .systemGray, size: NSSize(width: 160, height: 100))
        ) { _ in }
    }

    private func setPixelLayer(
        frame: CGRect,
        id: UUID,
        color: NSColor,
        in viewModel: ImageEditorViewModel
    ) {
        guard let index = viewModel.document.layers.firstIndex(where: { $0.id == id }) else {
            return
        }
        viewModel.document.layers[index].frame = frame
        viewModel.document.layers[index].image = image(color: color, size: frame.size)
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
        } ?? NSImage(size: size)
    }
}
