import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionPixelAvailabilityTests {
    private let canvasSize = CGSize(width: 80, height: 60)

    @Test func rasterSelectionCapabilitiesDistinguishEmptyDisjointAndMalformedMasks() throws {
        let viewModel = makeViewModel()
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)

        viewModel.document.selection = rasterSelection(alpha: [UInt8](
            repeating: 0,
            count: Int(canvasSize.width * canvasSize.height)
        ))
        #expect(viewModel.hasSelection)
        #expect(!viewModel.canEditSelectionPixels)
        #expect(!viewModel.canRemoveSelectionPixels)
        #expect(!viewModel.canCopySelectionToNewLayer)
        #expect(!viewModel.canCutSelectionToNewLayer)
        #expect(!viewModel.canCopySelectionToClipboard)
        #expect(!viewModel.canCutSelectionToClipboard)

        viewModel.document.layers[layerIndex].frame = CGRect(x: 50, y: 40, width: 20, height: 15)
        viewModel.document.selection = rasterSelection(
            alpha: rectangularMask(rect: CGRect(x: 5, y: 5, width: 10, height: 10))
        )
        #expect(viewModel.canEditSelectionPixels)
        #expect(viewModel.canRemoveSelectionPixels)
        #expect(!viewModel.canCopySelectionToNewLayer)
        #expect(!viewModel.canCutSelectionToNewLayer)

        viewModel.feather = 36
        #expect(viewModel.canCopySelectionToNewLayer)
        #expect(viewModel.canCutSelectionToNewLayer)

        viewModel.feather = 0
        viewModel.document.layers[layerIndex].frame = CGRect(origin: .zero, size: canvasSize)
        viewModel.document.selection = rasterSelection(alpha: [])
        #expect(viewModel.canEditSelectionPixels)
        #expect(viewModel.canRemoveSelectionPixels)
        #expect(viewModel.canCopySelectionToNewLayer)
        #expect(viewModel.canCutSelectionToNewLayer)
    }

    @Test func automationRejectsEmptyPixelEditsAndDuplicateFallsBackToTheLayer() throws {
        let viewModel = makeViewModel()
        viewModel.document.selection = rasterSelection(alpha: [UInt8](
            repeating: 0,
            count: Int(canvasSize.width * canvasSize.height)
        ))
        let registry = XomoAutomationRegistry.shared
        registry.register(viewModel)
        defer { registry.unregister(viewModel) }
        let originalLayerCount = viewModel.document.layers.count
        let originalHistoryCount = viewModel.document.history.count
        let originalUndoCount = viewModel.undoStack.count

        for action in ["fillForeground", "clearPixels", "copyToLayer", "cutToLayer"] {
            let response = registry.execute(request(action: action))
            #expect(!response.ok)
            #expect(response.error?.contains("requires") == true)
        }
        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.history.count == originalHistoryCount)
        #expect(viewModel.undoStack.count == originalUndoCount)

        let duplicate = registry.execute(request(action: "duplicate"))

        #expect(duplicate.ok)
        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerDuplicate"))
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "selection-pixel-availability",
            image: .transparent(size: canvasSize)
        ) { _ in }
    }

    private func request(action: String) -> XomoAutomationWireRequest {
        XomoAutomationWireRequest(
            token: "test",
            operation: "call",
            name: "xomo.selection.edit",
            arguments: ["action": .string(action)]
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

    private func rectangularMask(rect: CGRect) -> [UInt8] {
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
