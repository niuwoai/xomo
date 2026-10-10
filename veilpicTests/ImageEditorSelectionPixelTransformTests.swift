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

    @Test(arguments: [1, -1, 2])
    func quarterTurnRotatesOnlyMaskedPixels(clockwiseTurns: Int) throws {
        let width = 5
        let height = 4
        let source = pixels(width: width, height: height, seed: 7)
        var mask = [UInt8](repeating: 0, count: width * height)
        for y in 1..<3 {
            for x in 1..<4 { mask[y * width + x] = 255 }
        }
        let turns = ((clockwiseTurns % 4) + 4) % 4
        var expected = source
        for y in 1..<3 {
            for x in 1..<4 {
                let offset = (y * width + x) * 4
                expected.replaceSubrange(offset..<(offset + 4), with: [0, 0, 0, 0])
            }
        }
        for y in 1..<3 {
            for x in 1..<4 {
                let localX = x - 1
                let localY = y - 1
                let target: (x: Int, y: Int)
                switch turns {
                case 1: target = (2 - localY, 1 + localX)
                case 2: target = (3 - localX, 2 - localY)
                default: target = (1 + localY, 3 - localX)
                }
                ImageEditorPremultipliedPixelCompositing.composite(
                    source: source,
                    sourcePixel: y * width + x,
                    targetPixel: target.y * width + target.x,
                    coverage: 1,
                    into: &expected
                )
            }
        }

        let actual = try #require(ImageEditorPixelSelectionTransform.rotatedQuarterTurns(
            source: source, maskAlpha: mask, width: width, height: height, clockwiseTurns: clockwiseTurns
        ))
        #expect(actual == expected)
        #expect(actual[0..<4] == source[0..<4])
        #expect(actual[(width - 1) * 4..<width * 4] == source[(width - 1) * 4..<width * 4])
    }

    @Test func scalingResamplesSelectedPixelsIntoDestinationCoverageAndKeepsOutsidePixels() throws {
        let width = 6
        let height = 6
        let source = opaquePixels(width: width, height: height)
        var sourceMask = [UInt8](repeating: 0, count: width * height)
        var destinationMask = [UInt8](repeating: 0, count: width * height)
        for y in 2..<4 {
            for x in 2..<4 { sourceMask[y * width + x] = 255 }
        }
        for y in 1..<5 {
            for x in 1..<5 { destinationMask[y * width + x] = 255 }
        }

        let actual = try #require(ImageEditorPixelSelectionTransform.scaled(
            source: source,
            sourceMaskAlpha: sourceMask,
            destinationMaskAlpha: destinationMask,
            width: width,
            height: height,
            layerFrame: CGRect(x: 0, y: 0, width: 6, height: 6),
            sourceCanvasBounds: CGRect(x: 2, y: 2, width: 2, height: 2),
            destinationCanvasBounds: CGRect(x: 1, y: 1, width: 4, height: 4)
        ))
        let upperLeft = pixel(from: source, x: 2, y: 2, width: width)
        let lowerRight = pixel(from: source, x: 3, y: 3, width: width)

        #expect(pixel(from: actual, x: 1, y: 1, width: width) == upperLeft)
        #expect(pixel(from: actual, x: 4, y: 4, width: width) == lowerRight)
        #expect(pixel(from: actual, x: 2, y: 2, width: width)[0] > upperLeft[0])
        #expect(pixel(from: actual, x: 2, y: 2, width: width)[0] < lowerRight[0])
        #expect(pixel(from: actual, x: 0, y: 0, width: width) == pixel(from: source, x: 0, y: 0, width: width))
        #expect(pixel(from: actual, x: 5, y: 5, width: width) == pixel(from: source, x: 5, y: 5, width: width))
    }

    @Test func scalingClippedLayerMaskUsesSharedCanvasTransform() throws {
        let width = 7
        let height = 4
        var source = [UInt8](repeating: 0, count: width * height * 4)
        let selectedPixelOffset = (1 * width) * 4
        source[selectedPixelOffset] = 220
        source[selectedPixelOffset + 3] = 255
        var sourceMask = [UInt8](repeating: 0, count: width * height)
        sourceMask[1 * width] = 255
        var destinationMask = [UInt8](repeating: 0, count: width * height)
        for y in 1..<3 {
            for x in 0..<3 { destinationMask[y * width + x] = 255 }
        }

        let actual = try #require(ImageEditorPixelSelectionTransform.scaled(
            source: source,
            sourceMaskAlpha: sourceMask,
            destinationMaskAlpha: destinationMask,
            width: width,
            height: height,
            layerFrame: CGRect(x: 5, y: 0, width: 7, height: 4),
            sourceCanvasBounds: CGRect(x: 2, y: 1, width: 4, height: 1),
            destinationCanvasBounds: CGRect(x: 0, y: 1, width: 8, height: 2)
        ))

        #expect(pixel(from: actual, x: 0, y: 1, width: width)[3] == 0)
        #expect(pixel(from: actual, x: 1, y: 1, width: width) == [220, 0, 0, 255])
        #expect(pixel(from: actual, x: 2, y: 1, width: width) == [220, 0, 0, 255])
    }

    @Test func scalingDownResamplesSelectedPixelsToTheSharedCanvasBounds() throws {
        let width = 4
        let height = 4
        let source = opaquePixels(width: width, height: height)
        var sourceMask = [UInt8](repeating: 0, count: width * height)
        var destinationMask = [UInt8](repeating: 0, count: width * height)
        for y in 1..<3 {
            for x in 1..<3 { sourceMask[y * width + x] = 255 }
        }
        destinationMask[2 * width + 2] = 255

        let actual = try #require(ImageEditorPixelSelectionTransform.scaled(
            source: source,
            sourceMaskAlpha: sourceMask,
            destinationMaskAlpha: destinationMask,
            width: width,
            height: height,
            layerFrame: CGRect(x: 0, y: 0, width: 4, height: 4),
            sourceCanvasBounds: CGRect(x: 1, y: 1, width: 2, height: 2),
            destinationCanvasBounds: CGRect(x: 2, y: 2, width: 1, height: 1)
        ))
        let sourcePixels = [
            pixel(from: source, x: 1, y: 1, width: width),
            pixel(from: source, x: 2, y: 1, width: width),
            pixel(from: source, x: 1, y: 2, width: width),
            pixel(from: source, x: 2, y: 2, width: width)
        ]
        let expected = (0..<4).map { channel in
            UInt8((sourcePixels.reduce(0) { $0 + Int($1[channel]) } + 2) / 4)
        }

        #expect(pixel(from: actual, x: 2, y: 2, width: width) == expected)
        #expect(pixel(from: actual, x: 0, y: 0, width: width) == pixel(from: source, x: 0, y: 0, width: width))
    }

    @Test func selectedPixelScaleIsAtomicAcrossLayersAndUndoRedoProjectRoundTrip() throws {
        let canvasSize = CGSize(width: 12, height: 4)
        let firstSize = CGSize(width: 5, height: 4)
        let secondSize = CGSize(width: 7, height: 4)
        let firstPixels = opaquePixels(width: 5, height: 4, seed: 5)
        let secondPixels = opaquePixels(width: 7, height: 4, seed: 73)
        let firstImage = try #require(ImageEditorRGBAImage.image(
            width: 5, height: 4, pixels: firstPixels, size: firstSize
        ))
        let secondImage = try #require(ImageEditorRGBAImage.image(
            width: 7, height: 4, pixels: secondPixels, size: secondSize
        ))
        var first = ImageEditorLayer.blank(name: "First", size: firstSize)
        var second = ImageEditorLayer.blank(name: "Second", size: secondSize)
        first.image = firstImage
        second.image = secondImage
        first.frame = CGRect(x: 0, y: 0, width: 5, height: 4)
        second.frame = CGRect(x: 5, y: 0, width: 7, height: 4)
        let selection = ImageEditorSelection.rectangle(CGRect(x: 2, y: 1, width: 4, height: 1))
        let scaledSelection = try #require(selection.scaled(by: 2, canvasSize: canvasSize))
        let viewModel = ImageEditorViewModel(
            sourceName: "selection-scale.png", image: .transparent(size: canvasSize)
        ) { _ in }
        viewModel.document.layers = [first, second]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id]
        viewModel.document.selection = selection

        let expectedFirst = try scaledPixels(first, selection: selection,
            destination: scaledSelection, canvasSize: canvasSize)
        let expectedSecond = try scaledPixels(second, selection: selection,
            destination: scaledSelection, canvasSize: canvasSize)
        let originalProject = try viewModel.projectData()
        let originalUndoCount = viewModel.undoStack.count

        #expect(viewModel.canScaleSelectedPixels)
        viewModel.scaleSelectedPixelsUp()

        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionPixelsScaleUp"))
        #expect(viewModel.document.selection?.rasterizedMask(canvasSize: canvasSize)
            == scaledSelection.rasterizedMask(canvasSize: canvasSize))
        let firstResultWidth = Int(viewModel.document.layers[0].image.size.width.rounded())
        let firstResultHeight = Int(viewModel.document.layers[0].image.size.height.rounded())
        let secondResultWidth = Int(viewModel.document.layers[1].image.size.width.rounded())
        let secondResultHeight = Int(viewModel.document.layers[1].image.size.height.rounded())
        let firstResult = try #require(ImageEditorRGBAImage.pixels(
            from: viewModel.document.layers[0].image, width: firstResultWidth, height: firstResultHeight
        ))
        let secondResult = try #require(ImageEditorRGBAImage.pixels(
            from: viewModel.document.layers[1].image, width: secondResultWidth, height: secondResultHeight
        ))
        #expect(firstResult == expectedFirst)
        #expect(secondResult == expectedSecond)

        let scaledProject = try viewModel.projectData()
        viewModel.undo()
        #expect(try viewModel.projectData() == originalProject)
        viewModel.redo()
        #expect(try viewModel.projectData() == scaledProject)
        let reopened = ImageEditorViewModel(
            sourceName: "reopened.png", image: .transparent(size: canvasSize)
        ) { _ in }
        try reopened.loadProjectData(scaledProject)
        #expect(reopened.document.selection?.rasterizedMask(canvasSize: canvasSize)
            == scaledSelection.rasterizedMask(canvasSize: canvasSize))
        let reopenedFirst = try #require(ImageEditorRGBAImage.pixels(
            from: reopened.document.layers[0].image,
            width: Int(reopened.document.layers[0].image.size.width.rounded()),
            height: Int(reopened.document.layers[0].image.size.height.rounded())
        ))
        let reopenedSecond = try #require(ImageEditorRGBAImage.pixels(
            from: reopened.document.layers[1].image,
            width: Int(reopened.document.layers[1].image.size.width.rounded()),
            height: Int(reopened.document.layers[1].image.size.height.rounded())
        ))
        #expect(reopenedFirst == expectedFirst)
        #expect(reopenedSecond == expectedSecond)
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

    @Test func selectedPixelQuarterTurnIsAtomicAcrossLayersAndUndoRedoProjectRoundTrip() throws {
        let size = CGSize(width: 8, height: 6)
        let firstPixels = pixels(width: 8, height: 6, seed: 13)
        let secondPixels = pixels(width: 8, height: 6, seed: 37)
        let firstImage = try #require(ImageEditorRGBAImage.image(width: 8, height: 6, pixels: firstPixels, size: size))
        let secondImage = try #require(ImageEditorRGBAImage.image(width: 8, height: 6, pixels: secondPixels, size: size))
        var first = ImageEditorLayer.blank(name: "First", size: size)
        var second = ImageEditorLayer.blank(name: "Second", size: size)
        first.image = firstImage
        second.image = secondImage
        first.frame = CGRect(origin: .zero, size: size)
        second.frame = CGRect(origin: .zero, size: size)
        let selection = ImageEditorSelection.rectangle(CGRect(x: 1, y: 1, width: 3, height: 2))
        let viewModel = ImageEditorViewModel(sourceName: "selection-rotate.png", image: .transparent(size: size)) { _ in }
        viewModel.document.layers = [first, second]
        viewModel.document.selectedLayerID = first.id
        viewModel.document.selectedLayerIDs = [first.id, second.id]
        viewModel.document.selection = selection
        let originalDocument = try viewModel.projectData()
        let firstMaskImage = try #require(selection.layerMask(
            layerFrame: first.frame, layerSize: first.image.size, canvasSize: size,
            feather: 0, usesNearestSampling: true
        ))
        let secondMaskImage = try #require(selection.layerMask(
            layerFrame: second.frame, layerSize: second.image.size, canvasSize: size,
            feather: 0, usesNearestSampling: true
        ))
        let firstMask = try #require(ImageEditorPixelMoveMaskAlpha.read(from: firstMaskImage, width: 8, height: 6))
        let secondMask = try #require(ImageEditorPixelMoveMaskAlpha.read(from: secondMaskImage, width: 8, height: 6))
        let expectedFirst = try #require(ImageEditorPixelSelectionTransform.rotatedQuarterTurns(
            source: firstPixels, maskAlpha: firstMask, width: 8, height: 6, clockwiseTurns: 1
        ))
        let expectedSecond = try #require(ImageEditorPixelSelectionTransform.rotatedQuarterTurns(
            source: secondPixels, maskAlpha: secondMask, width: 8, height: 6, clockwiseTurns: 1
        ))
        let rotatedSelection = try #require(selection.rotatedQuarterTurns(clockwiseTurns: 1, canvasSize: size))
        let originalUndoCount = viewModel.undoStack.count

        viewModel.rotateSelectedPixelsClockwise()

        #expect(viewModel.undoStack.count == originalUndoCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionPixelsRotateClockwise"))
        #expect(viewModel.document.selection?.rasterizedMask(canvasSize: size)
            == rotatedSelection.rasterizedMask(canvasSize: size))
        #expect(try ImageEditorRGBAImage.pixels(from: viewModel.document.layers[0].image, width: 8, height: 6) == expectedFirst)
        #expect(try ImageEditorRGBAImage.pixels(from: viewModel.document.layers[1].image, width: 8, height: 6) == expectedSecond)

        viewModel.undo()
        #expect(try viewModel.projectData() == originalDocument)
        viewModel.redo()
        let saved = try viewModel.projectData()
        let reopened = ImageEditorViewModel(sourceName: "reopened.png", image: .transparent(size: size)) { _ in }
        try reopened.loadProjectData(saved)
        #expect(reopened.document.selection?.rasterizedMask(canvasSize: size)
            == rotatedSelection.rasterizedMask(canvasSize: size))
        #expect(try ImageEditorRGBAImage.pixels(from: reopened.document.layers[0].image, width: 8, height: 6) == expectedFirst)
        #expect(try ImageEditorRGBAImage.pixels(from: reopened.document.layers[1].image, width: 8, height: 6) == expectedSecond)
    }

    @Test func quarterTurnExpandsPixelLayerBackingForRotatedSelectionBounds() throws {
        let canvasSize = CGSize(width: 8, height: 6)
        let layerSize = CGSize(width: 4, height: 2)
        let source = pixels(width: 4, height: 2, seed: 53)
        let image = try #require(ImageEditorRGBAImage.image(width: 4, height: 2, pixels: source, size: layerSize))
        var layer = ImageEditorLayer.blank(name: "Short layer", size: layerSize)
        layer.image = image
        layer.frame = CGRect(origin: .zero, size: layerSize)
        let selection = ImageEditorSelection.rectangle(CGRect(origin: .zero, size: layerSize))
        let rotatedSelection = try #require(selection.rotatedQuarterTurns(clockwiseTurns: 1, canvasSize: canvasSize))
        let backing = try #require(layer.expandedPixelSelectionTransformBacking(
            selection: selection, destinationSelection: rotatedSelection,
            canvasSize: canvasSize, feather: 0
        ))
        let maskImage = try #require(selection.layerMask(
            layerFrame: backing.frame, layerSize: backing.image.size,
            canvasSize: canvasSize, feather: 0, usesNearestSampling: true
        ))
        let width = Int(backing.image.size.width.rounded())
        let height = Int(backing.image.size.height.rounded())
        let mask = try #require(ImageEditorPixelMoveMaskAlpha.read(from: maskImage, width: width, height: height))
        let backingPixels = try #require(ImageEditorRGBAImage.pixels(
            from: backing.image, width: width, height: height
        ))
        let expected = try #require(ImageEditorPixelSelectionTransform.rotatedQuarterTurns(
            source: backingPixels, maskAlpha: mask, width: width, height: height, clockwiseTurns: 1
        ))
        let viewModel = ImageEditorViewModel(
            sourceName: "selection-rotate-expanded.png", image: .transparent(size: canvasSize)
        ) { _ in }
        viewModel.document.layers = [layer]
        viewModel.document.selectedLayerID = layer.id
        viewModel.document.selectedLayerIDs = [layer.id]
        viewModel.document.selection = selection

        viewModel.rotateSelectedPixelsClockwise()

        let rotatedLayer = try #require(viewModel.document.selectedLayer)
        #expect(rotatedLayer.frame == backing.frame)
        #expect(rotatedLayer.image.size == backing.image.size)
        #expect(rotatedLayer.frame.height > layer.frame.height)
        #expect(try ImageEditorRGBAImage.pixels(
            from: rotatedLayer.image, width: width, height: height
        ) == expected)
        #expect(viewModel.document.selection?.rasterizedMask(canvasSize: canvasSize)
            == rotatedSelection.rasterizedMask(canvasSize: canvasSize))
    }

    @Test func quarterTurnIsDisabledForAnisotropicallyScaledPixelLayerButHalfTurnRemainsAvailable() throws {
        let canvasSize = CGSize(width: 12, height: 12)
        let imageSize = CGSize(width: 4, height: 4)
        let image = try #require(ImageEditorRGBAImage.image(
            width: 4, height: 4, pixels: pixels(width: 4, height: 4, seed: 67), size: imageSize
        ))
        var layer = ImageEditorLayer.blank(name: "Anisotropic", size: imageSize)
        layer.image = image
        layer.frame = CGRect(x: 1, y: 1, width: 8, height: 4)
        let viewModel = ImageEditorViewModel(
            sourceName: "anisotropic-selection-rotate.png", image: .transparent(size: canvasSize)
        ) { _ in }
        viewModel.document.layers = [layer]
        viewModel.document.selectedLayerID = layer.id
        viewModel.document.selectedLayerIDs = [layer.id]
        viewModel.document.selection = .rectangle(CGRect(x: 1, y: 1, width: 8, height: 4))

        #expect(viewModel.canFlipSelectedPixels)
        #expect(!viewModel.canRotateSelectedPixelsQuarterTurn)
        let originalUndoCount = viewModel.undoStack.count

        viewModel.rotateSelectedPixelsClockwise()

        #expect(viewModel.undoStack.count == originalUndoCount)
        #expect(viewModel.document.history.count == 1)
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

    private func opaquePixels(width: Int, height: Int, seed: Int = 0) -> [UInt8] {
        var pixels = [UInt8]()
        pixels.reserveCapacity(width * height * 4)
        for index in 0..<(width * height) {
            pixels.append(UInt8((index * 17 + seed) % 230 + 10))
            pixels.append(UInt8((index * 29 + seed) % 230 + 10))
            pixels.append(UInt8((index * 43 + seed) % 230 + 10))
            pixels.append(255)
        }
        return pixels
    }

    private func pixel(from pixels: [UInt8], x: Int, y: Int, width: Int) -> [UInt8] {
        let offset = (y * width + x) * 4
        return Array(pixels[offset..<(offset + 4)])
    }

    private func scaledPixels(
        _ layer: ImageEditorLayer, selection: ImageEditorSelection,
        destination: ImageEditorSelection, canvasSize: CGSize
    ) throws -> [UInt8] {
        let geometry = try #require(selection.scaledWithGeometry(by: 2, canvasSize: canvasSize))
        let backingLayer = try #require(layer.expandedPixelSelectionTransformBacking(
            selection: selection,
            destinationSelection: destination,
            canvasSize: canvasSize,
            feather: 0
        ))
        let width = Int(backingLayer.image.size.width.rounded())
        let height = Int(backingLayer.image.size.height.rounded())
        let sourceMaskImage = try #require(selection.layerMask(
            layerFrame: backingLayer.frame, layerSize: backingLayer.image.size, canvasSize: canvasSize,
            feather: 0, usesNearestSampling: true
        ))
        let destinationMaskImage = try #require(destination.layerMask(
            layerFrame: backingLayer.frame, layerSize: backingLayer.image.size, canvasSize: canvasSize,
            feather: 0, usesNearestSampling: true
        ))
        let source = try #require(ImageEditorRGBAImage.pixels(
            from: backingLayer.image, width: width, height: height
        ))
        let sourceMask = try #require(ImageEditorPixelMoveMaskAlpha.read(
            from: sourceMaskImage, width: width, height: height
        ))
        let destinationMask = try #require(ImageEditorPixelMoveMaskAlpha.read(
            from: destinationMaskImage, width: width, height: height
        ))
        return try #require(ImageEditorPixelSelectionTransform.scaled(
            source: source,
            sourceMaskAlpha: sourceMask,
            destinationMaskAlpha: destinationMask,
            width: width,
            height: height,
            layerFrame: backingLayer.frame,
            sourceCanvasBounds: geometry.sourceCanvasBounds,
            destinationCanvasBounds: geometry.destinationCanvasBounds
        ))
    }

    private func copyPixel(from source: [UInt8], x: Int, y: Int, to output: inout [UInt8],
                           x targetX: Int, y targetY: Int, width: Int) {
        let sourceOffset = (y * width + x) * 4
        let targetOffset = (targetY * width + targetX) * 4
        output.replaceSubrange(targetOffset..<(targetOffset + 4), with: source[sourceOffset..<(sourceOffset + 4)])
    }
}
