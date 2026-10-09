import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionPixelTransformTests {
    @Test(arguments: [true, false])
    func flipMirrorsOnlyMaskedRectangleAndPreservesUnselectedPixels(horizontally: Bool) throws {
        let width = 5
        let height = 4
        let source = pixels(width: width, height: height)
        var mask = [UInt8](repeating: 0, count: width * height)
        for y in 1..<4 {
            for x in 1..<4 { mask[y * width + x] = 255 }
        }

        let actual = try #require(ImageEditorPixelSelectionTransform.flipped(
            source: source, maskAlpha: mask, width: width, height: height, horizontally: horizontally
        ))
        var expected = source
        for y in 1..<4 {
            for x in 1..<4 {
                let targetX = horizontally ? 4 - x : x
                let targetY = horizontally ? y : 4 - y
                let sourceOffset = (y * width + x) * 4
                let targetOffset = (targetY * width + targetX) * 4
                expected.replaceSubrange(targetOffset..<(targetOffset + 4), with: source[sourceOffset..<(sourceOffset + 4)])
            }
        }
        #expect(actual == expected)
        #expect(actual[0..<4] == source[0..<4])
        #expect(actual[(width - 1) * 4..<width * 4] == source[(width - 1) * 4..<width * 4])
    }

    @Test func emptyCoverageAndMalformedRasterAreRejectedWithoutSourceMutation() {
        let source = pixels(width: 3, height: 2)
        let original = source
        #expect(ImageEditorPixelSelectionTransform.flipped(
            source: source, maskAlpha: [UInt8](repeating: 0, count: 6), width: 3, height: 2, horizontally: true
        ) == nil)
        #expect(ImageEditorPixelSelectionTransform.flipped(
            source: source, maskAlpha: [255], width: 3, height: 2, horizontally: false
        ) == nil)
        #expect(source == original)
    }

    @Test func selectedPixelFlipIsAtomicAcrossLayersAndUndoRedoProjectRoundTrip() throws {
        let size = CGSize(width: 8, height: 6)
        let firstPixels = pixels(width: 8, height: 6, seed: 3)
        let secondPixels = pixels(width: 8, height: 6, seed: 29)
        let firstImage = try #require(ImageEditorRGBAImage.image(width: 8, height: 6, pixels: firstPixels, size: size))
        let secondImage = try #require(ImageEditorRGBAImage.image(width: 8, height: 6, pixels: secondPixels, size: size))
        var first = ImageEditorLayer.blank(name: "First", size: size)
        var second = ImageEditorLayer.blank(name: "Second", size: size)
        first.image = firstImage
        second.image = secondImage
        first.frame = CGRect(origin: .zero, size: size)
        second.frame = CGRect(origin: .zero, size: size)
        let selection = ImageEditorSelection.rectangle(CGRect(x: 1, y: 1, width: 4, height: 4))
        let viewModel = ImageEditorViewModel(sourceName: "selection-flip.png", image: .transparent(size: size)) { _ in }
        viewModel.document.layers = [first, second]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id]
        viewModel.document.selection = selection
        let originalDocument = try viewModel.projectData()
        let originalUndoCount = viewModel.undoStack.count
        var expectedFirst = firstPixels
        var expectedSecond = secondPixels
        for y in 1..<5 {
            for x in 1..<5 {
                copyPixel(from: firstPixels, x: x, y: y, to: &expectedFirst, x: 5 - x, y: y, width: 8)
                copyPixel(from: secondPixels, x: x, y: y, to: &expectedSecond, x: 5 - x, y: y, width: 8)
            }
        }
        let flippedSelection = try #require(selection.flipped(horizontal: true, canvasSize: size))

        #expect(viewModel.canFlipSelectedPixels)
        viewModel.flipSelectedPixelsHorizontally()

        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionPixelsFlipHorizontal"))
        #expect(viewModel.document.selection?.rasterizedMask(canvasSize: size)
            == flippedSelection.rasterizedMask(canvasSize: size))
        #expect(try ImageEditorRGBAImage.pixels(from: viewModel.document.layers[0].image, width: 8, height: 6) == expectedFirst)
        #expect(try ImageEditorRGBAImage.pixels(from: viewModel.document.layers[1].image, width: 8, height: 6) == expectedSecond)

        viewModel.undo()
        #expect(try viewModel.projectData() == originalDocument)
        viewModel.redo()
        let saved = try viewModel.projectData()
        let reopened = ImageEditorViewModel(sourceName: "reopened.png", image: .transparent(size: size)) { _ in }
        try reopened.loadProjectData(saved)
        #expect(reopened.document.selection?.rasterizedMask(canvasSize: size)
            == flippedSelection.rasterizedMask(canvasSize: size))
        #expect(try ImageEditorRGBAImage.pixels(from: reopened.document.layers[0].image, width: 8, height: 6) == expectedFirst)
        #expect(try ImageEditorRGBAImage.pixels(from: reopened.document.layers[1].image, width: 8, height: 6) == expectedSecond)
    }

    @Test func alphaLockedOrUnselectedLayersCannotFlipSelectedPixels() throws {
        let size = CGSize(width: 8, height: 6)
        let viewModel = ImageEditorViewModel(sourceName: "locked.png", image: .transparent(size: size)) { _ in }
        let layerID = try #require(viewModel.document.layers.first?.id)
        viewModel.selectLayer(layerID)
        viewModel.convertBackgroundToLayer()
        viewModel.document.selection = .rectangle(CGRect(x: 1, y: 1, width: 3, height: 3))
        #expect(viewModel.canFlipSelectedPixels)
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        viewModel.document.layers[layerIndex].locksTransparentPixels = true
        #expect(!viewModel.canFlipSelectedPixels)
        viewModel.document.layers[layerIndex].locksTransparentPixels = false
        viewModel.document.selection = nil
        #expect(!viewModel.canFlipSelectedPixels)
    }

    @Test func featheredSelectionFlipUsesPartialCoverageWithoutHardCutout() throws {
        let size = CGSize(width: 8, height: 6)
        let source = pixels(width: 8, height: 6, seed: 41)
        let image = try #require(ImageEditorRGBAImage.image(width: 8, height: 6, pixels: source, size: size))
        var layer = ImageEditorLayer.blank(name: "Feathered", size: size)
        layer.image = image
        layer.frame = CGRect(origin: .zero, size: size)
        let selection = ImageEditorSelection.rectangle(CGRect(x: 2, y: 1, width: 4, height: 4))
        let viewModel = ImageEditorViewModel(sourceName: "feathered-flip.png", image: .transparent(size: size)) { _ in }
        viewModel.document.layers = [layer]
        viewModel.document.selectedLayerID = layer.id
        viewModel.document.selectedLayerIDs = [layer.id]
        viewModel.document.selection = selection
        viewModel.feather = 1

        let maskImage = try #require(selection.layerMask(
            layerFrame: layer.frame,
            layerSize: layer.image.size,
            canvasSize: size,
            feather: viewModel.feather,
            usesNearestSampling: true
        ))
        let mask = try #require(ImageEditorPixelMoveMaskAlpha.read(from: maskImage, width: 8, height: 6))
        #expect(mask.contains { $0 > 0 && $0 < 255 })
        let expected = try #require(ImageEditorPixelSelectionTransform.flipped(
            source: source, maskAlpha: mask, width: 8, height: 6, horizontally: true
        ))

        viewModel.flipSelectedPixelsHorizontally()

        let actual = try #require(ImageEditorRGBAImage.pixels(from: viewModel.document.layers[0].image, width: 8, height: 6))
        #expect(actual == expected)
        #expect(actual != source)
    }

    @Test func symmetricFlipPreservesGeometricSelectionAndDoesNotCreateHistory() throws {
        let size = CGSize(width: 6, height: 4)
        var source = [UInt8](repeating: 0, count: 6 * 4 * 4)
        for y in 0..<4 {
            for x in 0..<3 {
                let pixel = [UInt8(20 + x * 31), UInt8(40 + y * 29), UInt8(90 + x * 17), 255]
                let leftOffset = (y * 6 + x) * 4
                let rightOffset = (y * 6 + (5 - x)) * 4
                source.replaceSubrange(leftOffset..<(leftOffset + 4), with: pixel)
                source.replaceSubrange(rightOffset..<(rightOffset + 4), with: pixel)
            }
        }
        let image = try #require(ImageEditorRGBAImage.image(width: 6, height: 4, pixels: source, size: size))
        var layer = ImageEditorLayer.blank(name: "Symmetric", size: size)
        layer.image = image
        layer.frame = CGRect(origin: .zero, size: size)
        let selection = ImageEditorSelection.rectangle(CGRect(x: 1, y: 1, width: 4, height: 2))
        let viewModel = ImageEditorViewModel(sourceName: "symmetric-flip.png", image: .transparent(size: size)) { _ in }
        viewModel.document.layers = [layer]
        viewModel.document.selectedLayerID = layer.id
        viewModel.document.selectedLayerIDs = [layer.id]
        viewModel.document.selection = selection
        let undoCount = viewModel.undoStack.count
        let historyCount = viewModel.document.history.count

        viewModel.flipSelectedPixelsHorizontally()

        #expect(try ImageEditorRGBAImage.pixels(from: viewModel.document.layers[0].image, width: 6, height: 4) == source)
        #expect(viewModel.document.selection == selection)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionUnchanged"))
    }

    private func pixels(width: Int, height: Int, seed: Int = 0) -> [UInt8] {
        (0..<(width * height)).flatMap { index -> [UInt8] in
            let alpha: UInt8 = index.isMultiple(of: 11) ? 0 : 255
            guard alpha > 0 else { return [0, 0, 0, 0] }
            return [UInt8((index * 17 + seed) % 255), UInt8((index * 31 + seed) % 255),
                    UInt8((index * 47 + seed) % 255), alpha]
        }
    }

    private func copyPixel(from source: [UInt8], x: Int, y: Int, to output: inout [UInt8],
                           x targetX: Int, y targetY: Int, width: Int) {
        let sourceOffset = (y * width + x) * 4
        let targetOffset = (targetY * width + targetX) * 4
        output.replaceSubrange(targetOffset..<(targetOffset + 4), with: source[sourceOffset..<(sourceOffset + 4)])
    }
}
