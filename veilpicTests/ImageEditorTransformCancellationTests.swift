import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorTransformCancellationTests {
    @Test func escapeCancelsResizeWithoutChangingDocumentHistoryOrUndo() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 70))
        let originalFrames = layerFrames(in: viewModel)
        let originalImages = layerImages(in: viewModel)
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count
        let frame = try #require(viewModel.selectedLayerTransformFrame)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: frame.maxX + 48, y: frame.midY),
            handle: .right
        )

        #expect(layerFrames(in: viewModel) != originalFrames)
        #expect(viewModel.cancelTransformingSelectedLayer())
        #expect(layerFrames(in: viewModel) == originalFrames)
        #expect(layerImages(in: viewModel) == originalImages)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.resizingLayerIDs.isEmpty)
        #expect(viewModel.cancelTransformingSelectedLayer() == false)

        viewModel.finishResizingSelectedLayer()
        #expect(layerFrames(in: viewModel) == originalFrames)
    }

    @Test func escapeCancelsRotationWithoutChangingDocumentHistoryOrUndo() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 80, y: 70))
        let originalFrames = layerFrames(in: viewModel)
        let originalImages = layerImages(in: viewModel)
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count
        let frame = try #require(viewModel.selectedLayerTransformFrame)
        let start = CGPoint(x: frame.midX, y: frame.minY - 30)
        let end = CGPoint(x: frame.maxX + 30, y: frame.midY)

        viewModel.beginRotatingSelectedLayer(from: start)
        viewModel.rotateSelectedLayer(to: end)

        #expect(layerFrames(in: viewModel) != originalFrames)
        #expect(viewModel.cancelTransformingSelectedLayer())
        #expect(layerFrames(in: viewModel) == originalFrames)
        #expect(layerImages(in: viewModel) == originalImages)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.rotatingLayerIDs.isEmpty)
        #expect(viewModel.cancelTransformingSelectedLayer() == false)

        viewModel.finishRotatingSelectedLayer()
        #expect(layerFrames(in: viewModel) == originalFrames)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        let image = NSImage(size: NSSize(width: 360, height: 240))
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()
        return ImageEditorViewModel(sourceName: "transform-cancel", image: image) { _ in }
    }

    private func layerFrames(in viewModel: ImageEditorViewModel) -> [UUID: CGRect] {
        Dictionary(uniqueKeysWithValues: viewModel.document.layers.map { ($0.id, $0.frame.standardized) })
    }

    private func layerImages(in viewModel: ImageEditorViewModel) -> [UUID: Data] {
        Dictionary(uniqueKeysWithValues: viewModel.document.layers.compactMap { layer in
            layer.image.tiffRepresentation.map { (layer.id, $0) }
        })
    }
}
