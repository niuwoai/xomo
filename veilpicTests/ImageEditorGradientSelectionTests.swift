import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorGradientSelectionTests {
    @Test func gradientOutsideSelectedLayerDoesNotCreateHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "gradient-selection.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 70, y: 55, width: 40, height: 25)
        viewModel.createRectSelection(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: 30, y: 25)
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.drawGradient(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 120, y: 90)
        )

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func featheredOrInvertedSelectionCanStillReachLayer() throws {
        let feathered = ImageEditorViewModel(
            sourceName: "feathered-gradient.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        let featheredIndex = try #require(feathered.document.selectedLayerIndex)
        feathered.document.layers[featheredIndex].frame = CGRect(x: 32, y: 5, width: 50, height: 40)
        feathered.createRectSelection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 30, y: 25))
        feathered.feather = 4
        let featheredHistoryCount = feathered.document.history.count

        feathered.drawGradient(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 120, y: 90))

        #expect(feathered.document.history.count == featheredHistoryCount + 1)

        let inverted = ImageEditorViewModel(
            sourceName: "inverted-gradient.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        let invertedIndex = try #require(inverted.document.selectedLayerIndex)
        inverted.document.layers[invertedIndex].frame = CGRect(x: 70, y: 55, width: 40, height: 25)
        inverted.createRectSelection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 30, y: 25))
        inverted.invertSelection()
        let invertedHistoryCount = inverted.document.history.count

        inverted.drawGradient(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 120, y: 90))

        #expect(inverted.document.history.count == invertedHistoryCount + 1)
    }
}
