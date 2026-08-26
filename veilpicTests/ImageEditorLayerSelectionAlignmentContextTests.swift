import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorLayerSelectionAlignmentContextTests {
    @Test func unselectedContextUsesRasterPixelBoundsAndUndoRestoresFrame() throws {
        let viewModel = makeViewModel()
        let selected = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let clicked = try #require(viewModel.document.selectedLayer)
        setFrame(CGRect(x: 72, y: 45, width: 20, height: 16), for: selected.id, in: viewModel)
        setFrame(CGRect(x: 8, y: 12, width: 24, height: 18), for: clicked.id, in: viewModel)
        viewModel.selectLayer(selected.id)
        let selectedFrame = frame(of: selected.id, in: viewModel)
        let clickedFrame = frame(of: clicked.id, in: viewModel)
        let targetRect = CGRect(x: 20, y: 15, width: 70, height: 50)
        viewModel.document.selection = .raster(
            mask: rectangularMask(canvasSize: viewModel.document.canvasSize, rect: targetRect),
            bounds: CGRect(origin: .zero, size: viewModel.document.canvasSize)
        )
        let historyCount = viewModel.document.history.count

        #expect(viewModel.canAlignLayersFromContextToSelection(
            clicked.id,
            alignment: .right
        ))
        #expect(viewModel.alignLayersFromContextToSelection(
            clicked.id,
            alignment: .right
        ))
        #expect(frame(of: clicked.id, in: viewModel)?.maxX == targetRect.maxX)
        #expect(frame(of: selected.id, in: viewModel) == selectedFrame)
        #expect(viewModel.document.selectedLayerIDs == [clicked.id])
        #expect(viewModel.document.history.count == historyCount + 1)

        viewModel.undo()
        #expect(frame(of: clicked.id, in: viewModel) == clickedFrame)
    }

    @Test func selectedContextAlignsEverySelectedLayerToPixelSelection() throws {
        let viewModel = makeViewModel()
        let first = try #require(viewModel.document.selectedLayer)
        viewModel.addLayer()
        let second = try #require(viewModel.document.selectedLayer)
        setFrame(CGRect(x: 12, y: 2, width: 20, height: 18), for: first.id, in: viewModel)
        setFrame(CGRect(x: 76, y: 55, width: 30, height: 24), for: second.id, in: viewModel)
        viewModel.document.selection = .rectangle(
            CGRect(x: 25, y: 20, width: 80, height: 55)
        )
        viewModel.selectLayer(first.id)
        viewModel.selectLayer(second.id, extendingSelection: true)

        #expect(viewModel.alignLayersFromContextToSelection(
            first.id,
            alignment: .bottom
        ))
        #expect(frame(of: first.id, in: viewModel)?.minY == 20)
        #expect(frame(of: second.id, in: viewModel)?.minY == 20)
        #expect(viewModel.document.selectedLayerIDs == [first.id, second.id])
        #expect(viewModel.document.history.last?.title == L10n.text(
            "imageEditor.history.layerAlignSelection"
        ))
    }

    @Test func missingEmptyLockedInvalidAndRepeatedTargetsAreAtomicNoOps() throws {
        let viewModel = makeViewModel()
        let layer = try #require(viewModel.document.selectedLayer)
        setFrame(CGRect(x: 20, y: 32, width: 30, height: 18), for: layer.id, in: viewModel)
        viewModel.setSelectedLayersLabelColor(.purple)
        viewModel.undo()
        let historyBefore = viewModel.document.history
        let frameBefore = frame(of: layer.id, in: viewModel)
        let unknownID = UUID()

        #expect(viewModel.canRedo)
        #expect(!viewModel.canAlignLayersFromContextToSelection(
            layer.id,
            alignment: .left
        ))
        #expect(!viewModel.alignLayersFromContextToSelection(
            layer.id,
            alignment: .left
        ))

        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(
                width: 160,
                height: 100,
                alpha: [UInt8](repeating: 0, count: 160 * 100)
            ),
            bounds: CGRect(x: 0, y: 0, width: 160, height: 100)
        )
        #expect(!viewModel.canAlignLayersFromContextToSelection(
            layer.id,
            alignment: .left
        ))

        viewModel.document.selection = .rectangle(
            CGRect(x: 20, y: 10, width: 90, height: 70)
        )
        #expect(!viewModel.alignLayersFromContextToSelection(
            layer.id,
            alignment: .left
        ))
        #expect(!viewModel.alignLayersFromContextToSelection(
            unknownID,
            alignment: .right
        ))

        let index = try #require(
            viewModel.document.layers.firstIndex { $0.id == layer.id }
        )
        viewModel.document.layers[index].locksPosition = true
        #expect(!viewModel.canAlignLayersFromContextToSelection(
            layer.id,
            alignment: .right
        ))
        #expect(!viewModel.alignLayersFromContextToSelection(
            layer.id,
            alignment: .right
        ))
        #expect(frame(of: layer.id, in: viewModel) == frameBefore)
        #expect(viewModel.document.history == historyBefore)
        #expect(viewModel.canRedo)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "selection-alignment-context.png",
            image: NSImage.transparent(size: NSSize(width: 160, height: 100))
        ) { _ in }
    }

    private func setFrame(
        _ frame: CGRect,
        for id: UUID,
        in viewModel: ImageEditorViewModel
    ) {
        guard let index = viewModel.document.layers.firstIndex(where: { $0.id == id }) else {
            return
        }
        viewModel.document.layers[index].frame = frame
    }

    private func frame(
        of id: UUID,
        in viewModel: ImageEditorViewModel
    ) -> CGRect? {
        viewModel.document.layers.first { $0.id == id }?.frame.standardized
    }

    private func rectangularMask(
        canvasSize: CGSize,
        rect: CGRect
    ) -> ImageEditorSelectionMask {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        var alpha = [UInt8](repeating: 0, count: width * height)
        let bounds = rect.standardized.integral.intersection(
            CGRect(origin: .zero, size: canvasSize)
        )
        for y in Int(bounds.minY)..<Int(bounds.maxY) {
            for x in Int(bounds.minX)..<Int(bounds.maxX) {
                alpha[y * width + x] = UInt8.max
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }
}
