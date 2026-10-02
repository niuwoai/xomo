import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorPixelSelectionOverlapTests {
    private let canvasSize = NSSize(width: 8, height: 1)

    @Test(arguments: [1, -1])
    func overlappingMovesPreserveEverySelectedPixelAndUndoRedo(horizontalOffset: Int) throws {
        let viewModel = try makeViewModel()
        let originalSelection = viewModel.document.selection
        let originalImage = try #require(viewModel.document.selectedLayer?.image)
        let source = try #require(imageEditorRGBABytes(originalImage, width: 8, height: 1))
        let originalUndoCount = viewModel.undoStack.count
        let originalHistoryCount = viewModel.document.history.count

        #expect(viewModel.beginPixelSelectionMove(at: CGPoint(x: 2, y: 0.5)))
        viewModel.updatePixelSelectionMove(by: CGSize(width: horizontalOffset, height: 0))
        viewModel.finishPixelSelectionMove()

        let movedImage = try #require(viewModel.document.selectedLayer?.image)
        #expect(imageEditorRGBABytes(movedImage, width: 8, height: 1)
            == expectedPixels(from: source, horizontalOffset: horizontalOffset))
        #expect(viewModel.document.selection?.bounds
            == CGRect(x: 1 + horizontalOffset, y: 0, width: 3, height: 1))
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)
        viewModel.undo()
        #expect(viewModel.document.selection == originalSelection)
        let undoneImage = try #require(viewModel.document.selectedLayer?.image)
        #expect(imageEditorMaximumPixelDifference(undoneImage, originalImage) == 0)
        viewModel.redo()
        let redoneImage = try #require(viewModel.document.selectedLayer?.image)
        #expect(imageEditorRGBABytes(redoneImage, width: 8, height: 1)
            == expectedPixels(from: source, horizontalOffset: horizontalOffset))
    }

    @Test func repeatedOverlappingPreviewsAlwaysStartFromOriginalPixels() throws {
        let viewModel = try makeViewModel()
        let originalImage = try #require(viewModel.document.selectedLayer?.image)
        let source = try #require(imageEditorRGBABytes(originalImage, width: 8, height: 1))
        let originalUndoCount = viewModel.undoStack.count
        #expect(viewModel.beginPixelSelectionMove(at: CGPoint(x: 2, y: 0.5)))

        for offset in [1, 2, 1] {
            viewModel.updatePixelSelectionMove(by: CGSize(width: offset, height: 0))
            let previewImage = try #require(viewModel.document.selectedLayer?.image)
            #expect(imageEditorRGBABytes(previewImage, width: 8, height: 1)
                == expectedPixels(from: source, horizontalOffset: offset))
            #expect(viewModel.undoStack.count == originalUndoCount)
        }
        viewModel.finishPixelSelectionMove()
        #expect(viewModel.undoStack.count == originalUndoCount + 1)
    }

    @Test(arguments: [1, -1])
    func verticalOverlappingMovesPreserveEverySelectedPixel(verticalOffset: Int) throws {
        let image = try #require(NSImage.rendered(size: NSSize(width: 8, height: 7)) { _ in
            for (offset, color) in [NSColor.red, .green, .blue].enumerated() {
                color.setFill()
                CGRect(x: 1, y: offset + 2, width: 3, height: 1).fill()
            }
        })
        let viewModel = ImageEditorViewModel(sourceName: "vertical-overlap.png", image: image) { _ in }
        let sourceLayer = try #require(viewModel.document.layers.first)
        viewModel.selectLayer(sourceLayer.id)
        viewModel.convertBackgroundToLayer()
        viewModel.selectedTool = .move
        viewModel.document.selection = .rectangle(CGRect(x: 1, y: 2, width: 3, height: 3))
        let source = try #require(imageEditorRGBABytes(sourceLayer.image, width: 8, height: 7))
        #expect(source[(3 * 8 + 2) * 4 + 3] == 255)

        #expect(viewModel.beginPixelSelectionMove(at: CGPoint(x: 2, y: 3)))
        viewModel.updatePixelSelectionMove(by: CGSize(width: 0, height: verticalOffset))
        viewModel.finishPixelSelectionMove()

        let movedImage = try #require(viewModel.document.selectedLayer?.image)
        #expect(imageEditorRGBABytes(movedImage, width: 8, height: 7)
            == expectedPixels(from: source, horizontalOffset: 0, verticalOffset: verticalOffset, selectedRows: 2...4))
    }

    private func makeViewModel() throws -> ImageEditorViewModel {
        let image = try #require(NSImage.rendered(size: canvasSize) { _ in
            for (offset, color) in [NSColor.red, .green, .blue].enumerated() {
                color.setFill()
                CGRect(x: offset + 1, y: 0, width: 1, height: 1).fill()
            }
        })
        let viewModel = ImageEditorViewModel(sourceName: "overlapping-pixels.png", image: image) { _ in }
        let sourceLayer = try #require(viewModel.document.layers.first)
        viewModel.selectLayer(sourceLayer.id)
        viewModel.convertBackgroundToLayer()
        let selectedImage = try #require(viewModel.document.selectedLayer?.image)
        let pixels = try #require(imageEditorRGBABytes(selectedImage, width: 8, height: 1))
        #expect(pixels[7] == 255)
        #expect(pixels[11] == 255)
        #expect(pixels[15] == 255)
        viewModel.selectedTool = .move
        viewModel.document.selection = .rectangle(CGRect(x: 1, y: 0, width: 3, height: 1))
        return viewModel
    }

    private func expectedPixels(
        from source: [UInt8], horizontalOffset: Int,
        verticalOffset: Int = 0, selectedRows: ClosedRange<Int> = 0...0
    ) -> [UInt8] {
        let componentsPerPixel = 4
        var expected = source
        for y in selectedRows {
            for x in 1...3 {
                let sourceOffset = (y * 8 + x) * componentsPerPixel
                expected.replaceSubrange(sourceOffset..<(sourceOffset + componentsPerPixel), with: [0, 0, 0, 0])
            }
        }
        for y in selectedRows {
            for x in 1...3 {
                let sourceOffset = (y * 8 + x) * componentsPerPixel
                let destinationOffset = ((y + verticalOffset) * 8 + x + horizontalOffset) * componentsPerPixel
                expected.replaceSubrange(
                    destinationOffset..<(destinationOffset + componentsPerPixel),
                    with: source[sourceOffset..<(sourceOffset + componentsPerPixel)]
                )
            }
        }
        return expected
    }
}
