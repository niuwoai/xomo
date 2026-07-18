import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorCenteredResizeTests {
    @Test func sideHandleMirrorsTheOppositeEdgeAroundTheOriginalCenter() {
        let viewModel = makeViewModel()
        let original = CGRect(x: 10, y: 20, width: 40, height: 20)

        let resized = viewModel.frameByDragging(
            handle: .right,
            from: original,
            to: CGPoint(x: 60, y: 30),
            preservingAspectRatio: false,
            resizingFromCenter: true
        )

        #expect(resized == CGRect(x: 0, y: 20, width: 60, height: 20))
        #expect(resized.center == original.center)
    }

    @Test func shiftAndOptionKeepAspectRatioAndCenterTogether() {
        let viewModel = makeViewModel()
        let original = CGRect(x: 10, y: 20, width: 40, height: 20)

        let resized = viewModel.frameByDragging(
            handle: .topRight,
            from: original,
            to: CGPoint(x: 60, y: 45),
            preservingAspectRatio: true,
            resizingFromCenter: true
        )

        #expect(resized == CGRect(x: 0, y: 15, width: 60, height: 30))
        #expect(resized.center == original.center)
        #expect(resized.width / resized.height == original.width / original.height)
    }

    @Test func centeredResizeStopsAtTheMinimumSizeWithoutFlipping() {
        let viewModel = makeViewModel()
        let original = CGRect(x: 10, y: 20, width: 40, height: 20)

        let resized = viewModel.frameByDragging(
            handle: .right,
            from: original,
            to: CGPoint(x: -20, y: 30),
            preservingAspectRatio: false,
            resizingFromCenter: true
        )

        #expect(resized == CGRect(x: 28, y: 20, width: 4, height: 20))
        #expect(resized.center == original.center)
    }

    @Test func centeredParagraphResizeKeepsItsContainerCenter() {
        let original = CGRect(x: 40, y: 50, width: 80, height: 40)
        let normalized = ImageEditorTextBoxGeometry.normalizedResizeFrame(
            CGRect(x: 0, y: 0, width: 120, height: 60),
            originalFrame: original,
            handle: .topRight,
            resizingFromCenter: true
        )

        #expect(normalized == CGRect(x: 20, y: 40, width: 120, height: 60))
        #expect(normalized.center == original.center)
    }

    @Test func centeredResizeSnapsTheDraggedEdgeAndMirrorsTheOppositeEdge() throws {
        let viewModel = makeViewModel()
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.addGuide(.vertical, at: 40)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: 38, y: 20),
            handle: .right,
            resizingFromCenter: true
        )

        let resized = try #require(viewModel.selectedLayerTransformFrame)
        #expect(resized.minX == 0)
        #expect(resized.midX == 20)
        #expect(resized.maxX == 40)
        #expect(viewModel.activeAlignmentGuides == [
            ImageEditorAlignmentGuide(orientation: .vertical, position: 40)
        ])
    }

    @Test func centeredComponentResizeScalesChildrenAndUndoRestoresThem() throws {
        let viewModel = makeViewModel()
        viewModel.insertXomoComponent(.button, at: CGPoint(x: 40, y: 36))
        let originalFrame = try #require(viewModel.selectedXomoObjectFrame)
        let originalChildFrames = childFrames(in: viewModel)

        viewModel.beginResizingSelectedLayer(handle: .right)
        viewModel.resizeSelectedLayer(
            to: CGPoint(x: originalFrame.maxX + 20, y: originalFrame.midY),
            handle: .right,
            resizingFromCenter: true
        )
        viewModel.finishResizingSelectedLayer()

        let resizedFrame = try #require(viewModel.selectedXomoObjectFrame)
        #expect(resizedFrame.midX == originalFrame.midX)
        #expect(resizedFrame.width == originalFrame.width + 40)
        #expect(childFrames(in: viewModel) != originalChildFrames)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerResize"))

        viewModel.undo()
        #expect(viewModel.selectedXomoObjectFrame == originalFrame)
        #expect(childFrames(in: viewModel) == originalChildFrames)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "centered-resize",
            image: NSImage.transparent(size: CGSize(width: 160, height: 120))
        ) { _ in }
    }

    private func childFrames(in viewModel: ImageEditorViewModel) -> [UUID: CGRect] {
        let groupID = viewModel.document.selectedLayerID
        return Dictionary(uniqueKeysWithValues: viewModel.document.layers.compactMap { layer in
            layer.groupID == groupID ? (layer.id, layer.frame.standardized) : nil
        })
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
