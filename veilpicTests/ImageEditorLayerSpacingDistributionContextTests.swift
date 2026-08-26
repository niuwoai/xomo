import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerSpacingDistributionContextTests {
    @Test func selectedContextDistributesHorizontalGapsAndUndoRestoresFrame() throws {
        let viewModel = makeViewModel()
        let ids = try addLayers(count: 3, to: viewModel)
        let sourceFrames = [
            CGRect(x: 10, y: 12, width: 20, height: 18),
            CGRect(x: 45, y: 40, width: 10, height: 20),
            CGRect(x: 110, y: 72, width: 30, height: 16)
        ]
        setPixelLayers(ids: ids, frames: sourceFrames, in: viewModel)
        select(ids, in: viewModel)
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canDistributeLayerSpacingFromContext(
            ids[0],
            distribution: .horizontal
        ))
        #expect(viewModel.distributeLayerSpacingFromContext(
            ids[0],
            distribution: .horizontal
        ))
        let first = try #require(frame(of: ids[0], in: viewModel))
        let middle = try #require(frame(of: ids[1], in: viewModel))
        let last = try #require(frame(of: ids[2], in: viewModel))
        #expect(first == sourceFrames[0])
        #expect(middle.minX == 65)
        #expect(last == sourceFrames[2])
        #expect(middle.minX - first.maxX == 35)
        #expect(last.minX - middle.maxX == 35)
        #expect(viewModel.document.selectedLayerIDs == Set(ids))
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(frame(of: ids[1], in: viewModel) == sourceFrames[1])
    }

    @Test func unselectedGroupContextDistributesVerticalGapsInsideGroupOnly() throws {
        let viewModel = makeViewModel()
        let ids = try addLayers(count: 4, to: viewModel)
        let childIDs = Array(ids.prefix(3))
        let outsideID = ids[3]
        let childFrames = [
            CGRect(x: 12, y: 10, width: 18, height: 10),
            CGRect(x: 46, y: 30, width: 22, height: 20),
            CGRect(x: 88, y: 90, width: 16, height: 10)
        ]
        setPixelLayers(ids: childIDs, frames: childFrames, in: viewModel)
        setPixelLayer(
            frame: CGRect(x: 130, y: 72, width: 20, height: 16),
            id: outsideID,
            color: .systemPurple,
            in: viewModel
        )
        let outsideFrame = frame(of: outsideID, in: viewModel)
        select(childIDs, in: viewModel)
        viewModel.groupSelectedLayer()
        let groupID = try #require(viewModel.document.selectedLayerID)
        viewModel.selectLayer(outsideID)

        #expect(viewModel.distributeLayerSpacingFromContext(
            groupID,
            distribution: .vertical
        ))
        let first = try #require(frame(of: childIDs[0], in: viewModel))
        let middle = try #require(frame(of: childIDs[1], in: viewModel))
        let last = try #require(frame(of: childIDs[2], in: viewModel))
        #expect(first == childFrames[0])
        #expect(middle.minY == 45)
        #expect(last == childFrames[2])
        #expect(middle.minY - first.maxY == 25)
        #expect(last.minY - middle.maxY == 25)
        #expect(frame(of: outsideID, in: viewModel) == outsideFrame)
        #expect(viewModel.document.selectedLayerIDs == [groupID])
    }

    @Test func insufficientInvalidLockedAndRepeatedSpacingAreAtomicNoOps() throws {
        let viewModel = makeViewModel()
        let ids = try addLayers(count: 4, to: viewModel)
        let distributedIDs = Array(ids.prefix(3))
        let outsideID = ids[3]
        let frames = [
            CGRect(x: 10, y: 10, width: 10, height: 12),
            CGRect(x: 40, y: 55, width: 10, height: 12),
            CGRect(x: 70, y: 80, width: 10, height: 12),
            CGRect(x: 125, y: 30, width: 12, height: 12)
        ]
        setPixelLayers(ids: ids, frames: frames, in: viewModel)

        select(Array(distributedIDs.prefix(2)), in: viewModel)
        #expect(!viewModel.canDistributeLayerSpacingFromContext(
            distributedIDs[0],
            distribution: .horizontal
        ))
        #expect(!viewModel.distributeLayerSpacingFromContext(
            distributedIDs[0],
            distribution: .horizontal
        ))

        select(distributedIDs, in: viewModel)
        viewModel.setSelectedLayersLabelColor(.purple)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        let framesBefore = distributedIDs.map { frame(of: $0, in: viewModel) }

        #expect(viewModel.canRedo)
        #expect(!viewModel.canDistributeLayerSpacingFromContext(
            distributedIDs[0],
            distribution: .horizontal
        ))
        #expect(!viewModel.distributeLayerSpacingFromContext(
            distributedIDs[0],
            distribution: .horizontal
        ))
        #expect(!viewModel.distributeLayerSpacingFromContext(
            UUID(),
            distribution: .vertical
        ))
        #expect(!viewModel.distributeLayerSpacingFromContext(
            outsideID,
            distribution: .vertical
        ))

        let firstIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == distributedIDs[0] }
        )
        viewModel.document.layers[firstIndex].locksPosition = true
        #expect(!viewModel.canDistributeLayerSpacingFromContext(
            distributedIDs[0],
            distribution: .vertical
        ))
        #expect(!viewModel.distributeLayerSpacingFromContext(
            distributedIDs[0],
            distribution: .vertical
        ))
        #expect(distributedIDs.map { frame(of: $0, in: viewModel) } == framesBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "spacing-distribution-context.png",
            image: image(color: .systemGray, size: NSSize(width: 180, height: 120))
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

    private func setPixelLayers(
        ids: [UUID],
        frames: [CGRect],
        in viewModel: ImageEditorViewModel
    ) {
        let colors: [NSColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple]
        for (offset, id) in ids.enumerated() {
            setPixelLayer(
                frame: frames[offset],
                id: id,
                color: colors[offset],
                in: viewModel
            )
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
