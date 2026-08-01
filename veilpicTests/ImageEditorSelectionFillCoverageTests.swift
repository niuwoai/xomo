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

    @Test func strokeOnlyCommitsLayersReachedByItsOuterEdge() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "stroke-coverage.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        viewModel.addLayer()
        let reachedID = try #require(viewModel.document.selectedLayerID)
        let reachedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[reachedIndex].frame = CGRect(x: 30, y: 10, width: 30, height: 30)

        viewModel.addLayer()
        let untouchedID = try #require(viewModel.document.selectedLayerID)
        let untouchedIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[untouchedIndex].frame = CGRect(x: 75, y: 55, width: 30, height: 25)
        viewModel.document.selectedLayerID = reachedID
        viewModel.document.selectedLayerIDs = [reachedID, untouchedID]
        viewModel.createRectSelection(from: CGPoint(x: 10, y: 15), to: CGPoint(x: 28, y: 35))
        viewModel.brushSize = 6
        viewModel.foregroundColor = .systemBlue
        viewModel.opacity = 1
        let resolvedReachedIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == reachedID }
        )
        let resolvedUntouchedIndex = try #require(
            viewModel.document.layers.firstIndex { $0.id == untouchedID }
        )
        let reachedBefore = try #require(
            viewModel.document.layers[resolvedReachedIndex].image.qingtuPNGData()
        )
        let untouchedBefore = try #require(
            viewModel.document.layers[resolvedUntouchedIndex].image.qingtuPNGData()
        )

        viewModel.strokeSelection()

        let reachedAfter = try #require(
            viewModel.document.layers[resolvedReachedIndex].image.qingtuPNGData()
        )
        let untouchedAfter = try #require(
            viewModel.document.layers[resolvedUntouchedIndex].image.qingtuPNGData()
        )
        #expect(reachedAfter != reachedBefore)
        #expect(untouchedAfter == untouchedBefore)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionStroke"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionStroked"))
    }

    @Test func strokeOutsideEveryEditableLayerDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "empty-stroke.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 75, y: 55, width: 35, height: 25)
        viewModel.createRectSelection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 25, y: 25))
        viewModel.brushSize = 8
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.strokeSelection()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func clearOutsideEveryEditableLayerDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "empty-clear.png",
            image: .transparent(size: CGSize(width: 36, height: 24))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 70, y: 50, width: 36, height: 24)
        viewModel.createRectSelection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 25, y: 25))
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.clearSelectionPixels()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func contentAwareFillOutsideEveryEditableLayerDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "empty-content-aware.png",
            image: .transparent(size: CGSize(width: 32, height: 28))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 72, y: 52, width: 32, height: 28)
        viewModel.createRectSelection(from: CGPoint(x: 4, y: 4), to: CGPoint(x: 24, y: 24))
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.contentAwareFillSelection()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func clearingAlreadyTransparentPixelsDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "transparent-clear.png",
            image: .transparent(size: CGSize(width: 40, height: 30))
        ) { _ in }
        viewModel.selectAll()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.clearSelectionPixels()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func zeroOpacityFillDoesNotCreateUndoOrHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "zero-opacity-fill.png",
            image: .transparent(size: CGSize(width: 40, height: 30))
        ) { _ in }
        viewModel.selectAll()
        viewModel.foregroundColor = .systemPink
        viewModel.opacity = 0
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.fillSelection()

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func copyingTransparentSelectionDoesNotCreateBlankLayer() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "transparent-copy.png",
            image: .transparent(size: CGSize(width: 48, height: 32))
        ) { _ in }
        viewModel.createRectSelection(from: CGPoint(x: 6, y: 5), to: CGPoint(x: 30, y: 24))
        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.copySelectionToNewLayer()

        #expect(viewModel.document.layers.count == layerCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func cuttingTransparentSelectionDoesNotCreateBlankLayer() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "transparent-cut.png",
            image: .transparent(size: CGSize(width: 48, height: 32))
        ) { _ in }
        viewModel.createRectSelection(from: CGPoint(x: 6, y: 5), to: CGPoint(x: 30, y: 24))
        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.cutSelectionToNewLayer()

        #expect(viewModel.document.layers.count == layerCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func copyingTransparentMergedSelectionDoesNotCreateBlankLayer() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "transparent-merged-copy.png",
            image: .transparent(size: CGSize(width: 48, height: 32))
        ) { _ in }
        viewModel.createRectSelection(from: CGPoint(x: 6, y: 5), to: CGPoint(x: 30, y: 24))
        let layerCount = viewModel.document.layers.count
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.copyMergedToNewLayer()

        #expect(viewModel.document.layers.count == layerCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }
}
