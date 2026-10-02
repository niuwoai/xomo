import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSparseColorSelectionTests {
    private let canvasSize = NSSize(width: 128, height: 1)
    private let seedBounds = CGRect(x: 0, y: 0, width: 64, height: 1)

    @Test func similarColorsFindsTheOnlyOpaqueSeedAndSupportsUndoRedo() throws {
        let viewModel = try makeViewModel()
        let originalSelection = viewModel.document.selection
        let originalUndoCount = viewModel.undoStack.count

        viewModel.selectSimilarColors(tolerance: 0.001)

        let mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(mask.alpha[2] == 255)
        #expect(mask.alpha[64] == 255)
        #expect(mask.alpha[71] == 255)
        #expect(mask.alpha[0] == 0)
        #expect(mask.alpha[72] == 0)
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        viewModel.undo()
        #expect(viewModel.document.selection == originalSelection)
        viewModel.redo()
        #expect(viewModel.document.selection?.rasterMask == mask)
    }

    @Test func growColorsUsesTheOnlyOpaqueSeedAndSupportsUndoRedo() throws {
        let viewModel = try makeViewModel()
        let originalSelection = viewModel.document.selection
        let originalUndoCount = viewModel.undoStack.count

        viewModel.growColorSelection(tolerance: 0.001)

        let mask = try #require(viewModel.document.selection?.rasterMask)
        #expect(mask.alpha[2] == 255)
        #expect(mask.alpha[63] == 255)
        #expect(mask.alpha[64] == 255)
        #expect(mask.alpha[71] == 255)
        #expect(mask.alpha[72] == 0)
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        viewModel.undo()
        #expect(viewModel.document.selection == originalSelection)
        viewModel.redo()
        #expect(viewModel.document.selection?.rasterMask == mask)
    }

    @Test func similarColorsWithNoVisibleSeedPreservesSelectionAndHistory() throws {
        let viewModel = try makeViewModel(includeSeed: false)
        let originalSelection = viewModel.document.selection
        let originalUndoCount = viewModel.undoStack.count
        let originalHistory = viewModel.document.history.count

        viewModel.selectSimilarColors(tolerance: 0.001)

        #expect(viewModel.document.selection == originalSelection)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.document.history.count == originalHistory)
    }

    @Test func growColorsWithNoVisibleSeedPreservesSelectionAndHistory() throws {
        let viewModel = try makeViewModel(includeSeed: false)
        let originalSelection = viewModel.document.selection
        let originalUndoCount = viewModel.undoStack.count
        let originalHistory = viewModel.document.history.count

        viewModel.growColorSelection(tolerance: 0.001)

        #expect(viewModel.document.selection == originalSelection)
        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.document.history.count == originalHistory)
    }

    @Test func sharedSamplingPreservesTwoDimensionalImageCoordinates() throws {
        let image = try #require(NSImage.rendered(size: NSSize(width: 4, height: 4)) { _ in
            NSColor.red.setFill()
            CGRect(x: 0, y: 0, width: 4, height: 2).fill()
            NSColor.blue.setFill()
            CGRect(x: 0, y: 2, width: 4, height: 2).fill()
        })
        let point = CGPoint(x: 0.5, y: 0.5)
        let expected = try #require(image.color(at: point)?.usingColorSpace(.deviceRGB))
        let samples = image.colorRangeSampleColors(
            from: .rectangle(CGRect(x: 0, y: 0, width: 1, height: 1)),
            canvasSize: image.size
        )
        let actual = try #require(samples.first)
        #expect(samples.count == 1)
        #expect(abs(actual.redComponent - expected.redComponent) < 0.01)
        #expect(abs(actual.blueComponent - expected.blueComponent) < 0.01)
    }

    private func makeViewModel(includeSeed: Bool = true) throws -> ImageEditorViewModel {
        let image = try #require(NSImage.rendered(size: canvasSize) { _ in
            NSColor.red.setFill()
            if includeSeed {
                CGRect(x: 2, y: 0, width: 1, height: 1).fill()
            }
            CGRect(x: 64, y: 0, width: 8, height: 1).fill()
            NSColor.black.setFill()
            CGRect(x: 72, y: 0, width: 56, height: 1).fill()
        })
        let viewModel = ImageEditorViewModel(sourceName: "sparse-colors.png", image: image) { _ in }
        viewModel.document.selection = .rectangle(seedBounds)
        return viewModel
    }
}
