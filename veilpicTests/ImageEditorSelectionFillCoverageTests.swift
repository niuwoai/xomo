import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSelectionFillCoverageTests {
    @Test func fillOnlyCommitsLayersCoveredBySelection() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "fill-coverage.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[firstIndex].frame = CGRect(x: 0, y: 0, width: 40, height: 40)

        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[secondIndex].frame = CGRect(x: 70, y: 50, width: 40, height: 30)
        viewModel.document.selectedLayerID = firstID
        viewModel.document.selectedLayerIDs = [firstID, secondID]
        viewModel.createRectSelection(from: CGPoint(x: 8, y: 8), to: CGPoint(x: 28, y: 28))
        viewModel.foregroundColor = .systemRed
        viewModel.opacity = 1
        let resolvedFirstIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == firstID }
        )
        let resolvedSecondIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == secondID }
        )
        let firstBefore = try #require(
            viewModel.document.layers[resolvedFirstIndex].image.qingtuPNGData()
        )
        let secondBefore = try #require(
            viewModel.document.layers[resolvedSecondIndex].image.qingtuPNGData()
        )

        viewModel.fillSelection()

        let firstAfter = try #require(
            viewModel.document.layers[resolvedFirstIndex].image.qingtuPNGData()
        )
        let secondAfter = try #require(
            viewModel.document.layers[resolvedSecondIndex].image.qingtuPNGData()
        )
        #expect(firstAfter != firstBefore)
        #expect(secondAfter == secondBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFill"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionFilled"))
    }

    @Test func fillOutsideEveryEditableLayerDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "empty-fill.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 70, y: 55, width: 40, height: 25)
        viewModel.createRectSelection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 30, y: 25))
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.fillSelection()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }
}
