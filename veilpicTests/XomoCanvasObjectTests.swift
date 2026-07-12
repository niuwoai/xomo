import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoCanvasObjectTests {
    @Test func textToolCanSelectEditableTextInsideAComponent() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let textLayer = try #require(viewModel.document.layers.first { $0.groupID == group.id && $0.isText })

        #expect(viewModel.selectEditableTextLayer(at: CGPoint(x: textLayer.frame.midX, y: textLayer.frame.midY)))
        #expect(viewModel.document.selectedLayerID == textLayer.id)
        #expect(viewModel.document.selectedLayer?.textContent != nil)
    }

    @Test func textHitTestingCanExcludeTheJustCommittedLayer() throws {
        let viewModel = makeViewModel()
        viewModel.textValue = "First"
        viewModel.addText(at: CGPoint(x: 80, y: 90))
        let committedLayer = try #require(viewModel.document.selectedLayer)
        let pointInsideCommittedFrame = CGPoint(
            x: committedLayer.frame.midX,
            y: committedLayer.frame.midY
        )

        #expect(viewModel.selectEditableTextLayer(at: pointInsideCommittedFrame))
        #expect(!viewModel.selectEditableTextLayer(at: pointInsideCommittedFrame, excluding: committedLayer.id))
    }

    @Test func clickingAnUncoveredComponentSelectsItsObjectGroup() throws {
        let viewModel = makeViewModel()
        let origin = CGPoint(x: 80, y: 90)
        viewModel.insertXomoComponent(.button, at: origin)
        let group = try #require(viewModel.document.selectedLayer)

        viewModel.selectLayer(viewModel.document.layers.first!.id)
        let didSelect = viewModel.selectXomoObject(at: CGPoint(x: 160, y: 112))

        #expect(didSelect)
        #expect(viewModel.document.selectedLayerID == group.id)
        #expect(viewModel.document.selectedLayerIDs == [group.id])
    }

    @Test func topmostOverlappingComponentWinsObjectHitTesting() throws {
        let viewModel = makeViewModel()
        let origin = CGPoint(x: 80, y: 90)
        viewModel.insertXomoComponent(.button, at: origin)
        let firstObject = try #require(viewModel.document.selectedLayer)
        viewModel.insertXomoComponent(.secondaryButton, at: origin)
        let secondObject = try #require(viewModel.document.selectedLayer)

        #expect(viewModel.selectXomoObject(at: CGPoint(x: 160, y: 112)))
        #expect(viewModel.document.selectedLayerID == secondObject.id)
        #expect(viewModel.document.selectedLayerID != firstObject.id)
    }

    @Test func coveredComponentDoesNotClaimTheClick() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        var cover = ImageEditorLayer.blank(name: "Cover", size: CGSize(width: 240, height: 80))
        cover.frame = CGRect(x: 80, y: 90, width: 240, height: 80)
        viewModel.document.layers.append(cover)
        viewModel.selectLayer(cover.id)

        #expect(!viewModel.selectXomoObject(at: CGPoint(x: 160, y: 112)))
        #expect(viewModel.document.selectedLayerID == cover.id)
        #expect(viewModel.document.selectedLayerID != group.id)
    }

    @Test func deletingASelectedObjectRemovesItsGroupAndChildren() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let group = try #require(viewModel.document.selectedLayer)
        let childIDs = Set(viewModel.document.layers.filter { $0.groupID == group.id }.map(\.id))

        #expect(viewModel.deleteSelectedXomoObjectIfNeeded())
        #expect(!viewModel.document.layers.contains { $0.id == group.id })
        #expect(!viewModel.document.layers.contains { childIDs.contains($0.id) })
    }

    @Test func movingAnObjectPublishesAndClearsItsDashedPreviewFrame() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let initialFrame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 18, height: 12), snapping: false)

        let preview = try #require(viewModel.movingObjectPreviewFrame)
        #expect(preview.minX == initialFrame.minX + 18)
        #expect(preview.minY == initialFrame.minY + 12)
        #expect(viewModel.selectedLayerTransformFrame == initialFrame)

        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.movingObjectPreviewFrame == nil)
        #expect(viewModel.selectedLayerTransformFrame?.minX == initialFrame.minX + 18)
        #expect(viewModel.selectedLayerTransformFrame?.minY == initialFrame.minY + 12)
    }

    @Test func repeatedDragUpdatesAccumulateInThePreviewBeforeCommit() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let initialFrame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 4, height: 3), snapping: false)
        viewModel.moveSelectedLayer(by: CGSize(width: 6, height: 2), snapping: false)

        #expect(viewModel.movingObjectPreviewFrame?.minX == initialFrame.minX + 10)
        #expect(viewModel.movingObjectPreviewFrame?.minY == initialFrame.minY + 5)
        #expect(viewModel.selectedLayerTransformFrame == initialFrame)

        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.selectedLayerTransformFrame?.minX == initialFrame.minX + 10)
        #expect(viewModel.selectedLayerTransformFrame?.minY == initialFrame.minY + 5)
    }

    @Test func selectingAnotherObjectKeepsTheCompositeImageCache() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let objectID = try #require(viewModel.document.selectedLayerID)
        let cachedImage = viewModel.currentImage
        let backgroundID = try #require(viewModel.document.layers.first?.id)

        viewModel.selectLayer(backgroundID)
        viewModel.selectLayer(objectID)

        #expect(viewModel.currentImage === cachedImage)
    }

    @Test func objectPreviewSnapsBeforeTheRealLayersCommit() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        let initialFrame = try #require(viewModel.selectedLayerTransformFrame)
        let initialChildFrames = Dictionary(uniqueKeysWithValues: viewModel.document.layers.compactMap { layer in
            layer.groupID == viewModel.document.selectedLayerID ? (layer.id, layer.frame) : nil
        })
        viewModel.addGuide(.vertical, at: initialFrame.maxX + 20)

        viewModel.beginMovingSelectedLayer()
        viewModel.moveSelectedLayer(by: CGSize(width: 18, height: 0), snapping: true)

        #expect(viewModel.movingObjectPreviewFrame?.maxX == initialFrame.maxX + 20)
        #expect(viewModel.activeAlignmentGuides.contains {
            $0.orientation == .vertical && $0.position == initialFrame.maxX + 20
        })
        for layer in viewModel.document.layers {
            if let initialChildFrame = initialChildFrames[layer.id] {
                #expect(layer.frame == initialChildFrame)
            }
        }

        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.selectedXomoObjectFrame?.maxX == initialFrame.maxX + 20)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "objects",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
    }
}
