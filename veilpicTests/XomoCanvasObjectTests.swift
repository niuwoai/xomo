import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoCanvasObjectTests {
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

        viewModel.finishMovingSelectedLayer()
        #expect(viewModel.movingObjectPreviewFrame == nil)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "objects",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
    }
}
