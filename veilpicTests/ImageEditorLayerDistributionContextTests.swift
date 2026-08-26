import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerDistributionContextTests {
    @Test func selectedContextDistributesIntermediateLayerAndUndoRestoresFrame() throws {
        let viewModel = makeViewModel()
        let ids = try addLayers(count: 3, to: viewModel)
        setPixelLayer(
            frame: CGRect(x: 10, y: 12, width: 20, height: 18),
            id: ids[0],
            color: .systemBlue,
            in: viewModel
        )
        setPixelLayer(
            frame: CGRect(x: 42, y: 38, width: 20, height: 18),
            id: ids[1],
            color: .systemGreen,
            in: viewModel
        )
        setPixelLayer(
            frame: CGRect(x: 130, y: 72, width: 20, height: 18),
            id: ids[2],
            color: .systemOrange,
            in: viewModel
        )
        select(ids, in: viewModel)
        let middleFrame = frame(of: ids[1], in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canDistributeLayersFromContext(
            ids[0],
            distribution: .horizontalCenter
        ))
        #expect(viewModel.distributeLayersFromContext(
            ids[0],
            distribution: .horizontalCenter
        ))
        #expect(frame(of: ids[0], in: viewModel)?.midX == 20)
        #expect(frame(of: ids[1], in: viewModel)?.midX == 80)
        #expect(frame(of: ids[2], in: viewModel)?.midX == 140)
        #expect(viewModel.document.selectedLayerIDs == Set(ids))
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(frame(of: ids[1], in: viewModel) == middleFrame)
    }

    @Test func unselectedGroupContextDistributesItsExpandedChildrenOnly() throws {
        let viewModel = makeViewModel()
        let ids = try addLayers(count: 4, to: viewModel)
        let childIDs = Array(ids.prefix(3))
        let outsideID = ids[3]
        setPixelLayer(
            frame: CGRect(x: 10, y: 10, width: 10, height: 16),
            id: childIDs[0],
            color: .systemBlue,
            in: viewModel
        )
        setPixelLayer(
            frame: CGRect(x: 32, y: 38, width: 10, height: 16),
            id: childIDs[1],
            color: .systemGreen,
            in: viewModel
        )
        setPixelLayer(
            frame: CGRect(x: 90, y: 68, width: 10, height: 16),
            id: childIDs[2],
            color: .systemOrange,
            in: viewModel
        )
        setPixelLayer(
            frame: CGRect(x: 122, y: 74, width: 18, height: 14),
            id: outsideID,
            color: .systemPurple,
            in: viewModel
        )
        let outsideFrame = frame(of: outsideID, in: viewModel)
        select(childIDs, in: viewModel)
        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)
        viewModel.selectLayer(outsideID)

        #expect(viewModel.distributeLayersFromContext(
            groupID,
            distribution: .horizontalCenter
        ))
        #expect(frame(of: childIDs[0], in: viewModel)?.midX == 15)
        #expect(frame(of: childIDs[1], in: viewModel)?.midX == 55)
        #expect(frame(of: childIDs[2], in: viewModel)?.midX == 95)
        #expect(frame(of: outsideID, in: viewModel) == outsideFrame)
        #expect(viewModel.document.selectedLayerIDs == [groupID])
    }

    @Test func insufficientInvalidLockedAndRepeatedDistributionsAreAtomicNoOps() throws {
        let viewModel = makeViewModel()
        let ids = try addLayers(count: 4, to: viewModel)
        let distributedIDs = Array(ids.prefix(3))
        let outsideID = ids[3]
        let frames = [
            CGRect(x: 10, y: 10, width: 10, height: 12),
            CGRect(x: 50, y: 52, width: 10, height: 12),
            CGRect(x: 90, y: 80, width: 10, height: 12),
            CGRect(x: 125, y: 30, width: 12, height: 12)
        ]
        for (offset, id) in ids.enumerated() {
            setPixelLayer(
                frame: frames[offset],
                id: id,
                color: [.systemBlue, .systemGreen, .systemOrange, .systemPurple][offset],
                in: viewModel
            )
        }

        select(Array(distributedIDs.prefix(2)), in: viewModel)
        #expect(!viewModel.canDistributeLayersFromContext(
            distributedIDs[0],
            distribution: .horizontalCenter
        ))
        #expect(!viewModel.distributeLayersFromContext(
            distributedIDs[0],
            distribution: .horizontalCenter
        ))

        select(distributedIDs, in: viewModel)
        viewModel.setSelectedLayersLabelColor(.purple)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        let framesBefore = distributedIDs.map { frame(of: $0, in: viewModel) }

        #expect(viewModel.canRedo)
        #expect(!viewModel.canDistributeLayersFromContext(
            distributedIDs[0],
            distribution: .horizontalCenter
        ))
        #expect(!viewModel.distributeLayersFromContext(
            distributedIDs[0],
            distribution: .horizontalCenter
        ))
        #expect(!viewModel.distributeLayersFromContext(
            UUID(),
            distribution: .verticalCenter
        ))
        #expect(!viewModel.distributeLayersFromContext(
            outsideID,
            distribution: .verticalCenter
        ))

        let firstIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == distributedIDs[0] }
        )
        viewModel.document.layers[firstIndex].locksPosition = true
        #expect(!viewModel.canDistributeLayersFromContext(
            distributedIDs[0],
            distribution: .verticalCenter
        ))
        #expect(!viewModel.distributeLayersFromContext(
            distributedIDs[0],
            distribution: .verticalCenter
        ))
        #expect(distributedIDs.map { frame(of: $0, in: viewModel) } == framesBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "distribution-context.png",
            image: image(color: .systemGray, size: NSSize(width: 160, height: 100))
        ) { _ in }
    }

    private func addLayers(
        count: Int,
        to viewModel: ImageEditorViewModel
    ) throws -> [UUID] {
        var ids = [try #require(viewModel.document.selectedLayerID)]
        for _ in 1..<count {
            viewModel.addLayer()
            ids.append(try #require(viewModel.document.selectedLayerID))
        }
        return ids
    }

    private func select(_ ids: [UUID], in viewModel: ImageEditorViewModel) {
        guard let first = ids.first else { return }
        viewModel.selectLayer(first)
        for id in ids.dropFirst() {
            viewModel.selectLayer(id, extendingSelection: true)
        }
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
