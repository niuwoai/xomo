import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorTransformLockTests {
    @Test
    func pixelLockBlocksEveryContentResamplingEntryPoint() throws {
        let viewModel = makePixelLockedComponent()
        let framesBefore = Dictionary(uniqueKeysWithValues: viewModel.document.layers.map { ($0.id, $0.frame) })
        let historyCountBefore = viewModel.document.history.count
        let transformFrame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.scaleSelectedLayer(by: 1.5)
        viewModel.rotateSelectedLayerRight90()
        viewModel.flipSelectedLayerHorizontal()
        viewModel.fitSelectedLayerToCanvas()
        viewModel.setSelectedLayerTransform(width: Double(transformFrame.width + 40))
        viewModel.beginResizingSelectedLayer(handle: .bottomRight)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: transformFrame.maxX + 40, y: transformFrame.maxY + 30),
            handle: .bottomRight
        )
        viewModel.finishResizingSelectedLayer()
        viewModel.beginRotatingSelectedLayer(from: CGPoint(x: transformFrame.maxX, y: transformFrame.midY))
        viewModel.rotateSelectedLayer(to: CGPoint(x: transformFrame.midX, y: transformFrame.maxY))
        viewModel.finishRotatingSelectedLayer()

        #expect(viewModel.document.history.count == historyCountBefore)
        #expect(viewModel.document.layers.allSatisfy { framesBefore[$0.id] == $0.frame })
    }

    @Test
    func pixelLockStillAllowsInspectorPositionChanges() throws {
        let viewModel = makePixelLockedComponent()
        let frameBefore = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.setSelectedLayerTransform(x: Double(frameBefore.minX + 14))

        let frameAfter = try #require(viewModel.selectedLayerTransformFrame)
        #expect(frameAfter.minX == frameBefore.minX + 14)
        #expect(frameAfter.size == frameBefore.size)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerTransformInspector"))
    }

    private func makePixelLockedComponent() -> ImageEditorViewModel {
        let viewModel = ImageEditorViewModel(
            sourceName: "transform-locks",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 90))
        guard let groupID = viewModel.document.selectedLayerID else { return viewModel }
        viewModel.document.layers = viewModel.document.layers.map { layer in
            guard layer.id == groupID else { return layer }
            var locked = layer
            locked.locksPixels = true
            return locked
        }
        return viewModel
    }
}
