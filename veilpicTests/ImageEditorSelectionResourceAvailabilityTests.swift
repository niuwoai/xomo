import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionResourceAvailabilityTests {
    private let canvasSize = CGSize(width: 40, height: 30)

    @Test func emptySelectionCannotCreateOrModifyAlphaChannels() throws {
        let viewModel = makeViewModel()
        let channel = ImageEditorAlphaChannel(
            name: "Existing",
            mask: mask(filledWith: UInt8.max)
        )
        viewModel.document.alphaChannels = [channel]
        viewModel.selectedAlphaChannelID = channel.id
        viewModel.document.selection = rasterSelection(alpha: emptyAlpha)
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        #expect(viewModel.hasSelection)
        #expect(!viewModel.canSaveSelectionAsAlphaChannel)
        #expect(!viewModel.canUpdateSelectedAlphaChannelFromSelection)
        #expect(!viewModel.canAddSelectionToSelectedAlphaChannel)
        #expect(!viewModel.canSubtractSelectionFromSelectedAlphaChannel)
        #expect(!viewModel.canIntersectSelectionWithSelectedAlphaChannel)

        viewModel.saveSelectionAsAlphaChannel()
        viewModel.updateSelectedAlphaChannelFromSelection()
        viewModel.addSelectionToSelectedAlphaChannel()
        viewModel.subtractSelectionFromSelectedAlphaChannel()
        viewModel.intersectSelectionWithSelectedAlphaChannel()

        #expect(viewModel.document.alphaChannels == [channel])
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
    }

    @Test func emptySelectionCannotCreateRevealOrHideLayerMasks() throws {
        let viewModel = makeViewModel()
        viewModel.document.selection = rasterSelection(alpha: emptyAlpha)
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        #expect(!viewModel.canCreateLayerMaskFromSelection)

        viewModel.addLayerMaskFromSelection()
        viewModel.addLayerMaskHidingSelection()

        #expect(viewModel.document.selectedLayer?.mask == nil)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
    }

    @Test func emptySelectionCannotModifyAnExistingLayerMask() throws {
        let viewModel = makeViewModel()
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        let originalMask = NSImage.opaqueMask(size: canvasSize)
        viewModel.document.layers[layerIndex].mask = originalMask
        viewModel.document.selection = rasterSelection(alpha: emptyAlpha)
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        #expect(!viewModel.canCombineLayerMaskWithSelection)

        viewModel.revealSelectionOnLayerMask()
        viewModel.hideSelectionOnLayerMask()
        viewModel.intersectLayerMaskWithSelection()

        let resultingMask = try #require(viewModel.document.layers[layerIndex].mask)
        #expect(resultingMask.hasEquivalentAlphaMask(to: originalMask))
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)
    }

    @Test func nonEmptySelectionStillCreatesPersistentSelectionResources() throws {
        let alphaViewModel = makeViewModel()
        alphaViewModel.document.selection = rasterSelection(
            alpha: rectangularAlpha(rect: CGRect(x: 8, y: 6, width: 12, height: 10))
        )

        #expect(alphaViewModel.canSaveSelectionAsAlphaChannel)
        alphaViewModel.saveSelectionAsAlphaChannel()
        #expect(alphaViewModel.document.alphaChannels.count == 1)

        let maskViewModel = makeViewModel()
        maskViewModel.document.selection = rasterSelection(
            alpha: rectangularAlpha(rect: CGRect(x: 8, y: 6, width: 12, height: 10))
        )

        #expect(maskViewModel.canCreateLayerMaskFromSelection)
        maskViewModel.addLayerMaskFromSelection()
        #expect(maskViewModel.document.selectedLayer?.mask != nil)
    }

    private var emptyAlpha: [UInt8] {
        [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "selection-resource-availability",
            image: .transparent(size: canvasSize)
        ) { _ in }
    }

    private func mask(filledWith value: UInt8) -> ImageEditorSelectionMask {
        ImageEditorSelectionMask(
            width: Int(canvasSize.width),
            height: Int(canvasSize.height),
            alpha: [UInt8](repeating: value, count: Int(canvasSize.width * canvasSize.height))
        )
    }

    private func rasterSelection(alpha: [UInt8]) -> ImageEditorSelection {
        .raster(
            mask: ImageEditorSelectionMask(
                width: Int(canvasSize.width),
                height: Int(canvasSize.height),
                alpha: alpha
            ),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )
    }

    private func rectangularAlpha(rect: CGRect) -> [UInt8] {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                alpha[y * width + x] = UInt8.max
            }
        }
        return alpha
    }
}
