//
//  ImageEditorCanvasCommandTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorCanvasCommandTests {
    @Test
    func imageResizeScalesLayersSelectionsAndChannels() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.transparent(size: CGSize(width: 20, height: 16))
        viewModel.document.layers[layerIndex].mask = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        viewModel.document.layers[layerIndex].style.strokePatternOffset = CGSize(width: 3, height: -4)
        viewModel.document.layers[layerIndex].style.patternOverlayOffset = CGSize(width: -5, height: 7)
        viewModel.document.layers[layerIndex].vectorMask = ImageEditorShapeContent(
            kind: .path,
            fillColor: .white,
            fillOpacity: 1,
            strokeColor: .black,
            strokeWidth: 2,
            strokeOpacity: 1,
            pathPoints: [CGPoint(x: 4, y: 5), CGPoint(x: 12, y: 10)]
        )
        viewModel.document.selection = .rectangle(CGRect(x: 5, y: 8, width: 30, height: 20))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Alpha 1",
                mask: ImageEditorSelectionMask(width: 100, height: 80, alpha: [UInt8](repeating: 255, count: 8_000))
            )
        ]

        viewModel.resizeImage(to: CGSize(width: 200, height: 160))

        let resizedLayer = viewModel.document.layers[layerIndex]
        #expect(viewModel.document.canvasSize == CGSize(width: 200, height: 160))
        #expect(resizedLayer.frame == CGRect(x: 20, y: 24, width: 40, height: 32))
        #expect(resizedLayer.image.size == CGSize(width: 40, height: 32))
        #expect(resizedLayer.mask?.size == CGSize(width: 40, height: 32))
        #expect(resizedLayer.style.strokePatternOffset == CGSize(width: 6, height: -8))
        #expect(resizedLayer.style.patternOverlayOffset == CGSize(width: -10, height: 14))
        #expect(resizedLayer.vectorMask?.pathPoints.first == CGPoint(x: 8, y: 10))
        #expect(viewModel.document.selection?.points.first == CGPoint(x: 10, y: 16))
        #expect(viewModel.document.alphaChannels.first?.mask.width == 200)
        #expect(viewModel.document.alphaChannels.first?.mask.height == 160)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.imageResize"))
        #expect(viewModel.canUndo)
    }

    @Test
    func canvasResizeOffsetsLayersSelectionsAndChannelsWithoutResamplingLayerPixels() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemRed, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.transparent(size: CGSize(width: 20, height: 16))
        viewModel.document.selection = .rectangle(CGRect(x: 5, y: 8, width: 30, height: 20))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Alpha 1",
                mask: ImageEditorSelectionMask(width: 100, height: 80, alpha: [UInt8](repeating: 255, count: 8_000))
            )
        ]

        viewModel.resizeCanvas(to: CGSize(width: 140, height: 100), anchor: .center)

        let resizedLayer = viewModel.document.layers[layerIndex]
        #expect(viewModel.document.canvasSize == CGSize(width: 140, height: 100))
        #expect(resizedLayer.frame == CGRect(x: 30, y: 22, width: 20, height: 16))
        #expect(resizedLayer.image.size == CGSize(width: 20, height: 16))
        #expect(viewModel.document.selection?.points.first == CGPoint(x: 25, y: 18))
        #expect(viewModel.document.alphaChannels.first?.mask.width == 140)
        #expect(viewModel.document.alphaChannels.first?.mask.height == 100)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.canvasResize"))
        #expect(viewModel.canUndo)
    }

    @Test
    func cropOffsetsLayersSelectionsChannelsAndGuidesIntoNewCanvasSpace() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 30, y: 22, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.transparent(size: CGSize(width: 20, height: 16))
        viewModel.document.layers[layerIndex].mask = NSImage.opaqueMask(size: CGSize(width: 100, height: 80))

        let selectionMask = sparseMask(width: 100, height: 80, points: [CGPoint(x: 26, y: 16)])
        viewModel.document.selection = .raster(
            mask: selectionMask,
            bounds: CGRect(x: 25, y: 15, width: 18, height: 12)
        )
        viewModel.document.savedSelection = .rectangle(CGRect(x: 42, y: 28, width: 10, height: 8))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Crop Alpha",
                mask: sparseMask(width: 100, height: 80, points: [CGPoint(x: 26, y: 16), CGPoint(x: 90, y: 70)])
            )
        ]
        viewModel.document.guides = [
            ImageEditorGuide(orientation: .vertical, position: 25),
            ImageEditorGuide(orientation: .horizontal, position: 15),
            ImageEditorGuide(orientation: .vertical, position: 90)
        ]

        viewModel.crop(to: CGRect(x: 20, y: 10, width: 50, height: 40))

        let croppedLayer = viewModel.document.layers[layerIndex]
        let croppedAlpha = try #require(viewModel.document.alphaChannels.first?.mask)
        #expect(viewModel.document.canvasSize == CGSize(width: 50, height: 40))
        #expect(croppedLayer.frame == CGRect(x: 10, y: 12, width: 20, height: 16))
        #expect(croppedLayer.mask?.size == CGSize(width: 50, height: 40))
        #expect(viewModel.document.selection == .fullCanvas(size: CGSize(width: 50, height: 40)))
        #expect(viewModel.document.savedSelection?.points.first == CGPoint(x: 22, y: 18))
        #expect(croppedAlpha.width == 50)
        #expect(croppedAlpha.height == 40)
        #expect(croppedAlpha.alpha[6 * 50 + 6] == 255)
        #expect(croppedAlpha.alpha.filter { $0 == 255 }.count == 1)
        #expect(viewModel.document.guides.count == 2)
        #expect(viewModel.document.guides.contains { $0.orientation == .vertical && $0.position == 5 })
        #expect(viewModel.document.guides.contains { $0.orientation == .horizontal && $0.position == 5 })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.crop"))
        #expect(viewModel.canUndo)
    }

    @Test
    func cropToSelectionUsesSelectionBoundsAndPreservesCanvasState() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemGreen, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 30, y: 22, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.transparent(size: CGSize(width: 20, height: 16))
        viewModel.document.layers[layerIndex].mask = NSImage.opaqueMask(size: CGSize(width: 100, height: 80))
        viewModel.document.selection = .rectangle(CGRect(x: 20, y: 10, width: 50, height: 40))
        viewModel.document.savedSelection = .rectangle(CGRect(x: 42, y: 28, width: 10, height: 8))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Selection Crop Alpha",
                mask: sparseMask(width: 100, height: 80, points: [CGPoint(x: 26, y: 16), CGPoint(x: 90, y: 70)])
            )
        ]
        viewModel.document.guides = [
            ImageEditorGuide(orientation: .vertical, position: 25),
            ImageEditorGuide(orientation: .horizontal, position: 15),
            ImageEditorGuide(orientation: .vertical, position: 90)
        ]

        #expect(viewModel.canCropToSelection)
        viewModel.cropToSelection()

        let croppedAlpha = try #require(viewModel.document.alphaChannels.first?.mask)
        #expect(viewModel.document.canvasSize == CGSize(width: 50, height: 40))
        #expect(viewModel.document.layers[layerIndex].frame == CGRect(x: 10, y: 12, width: 20, height: 16))
        #expect(viewModel.document.layers[layerIndex].mask?.size == CGSize(width: 50, height: 40))
        #expect(viewModel.document.selection == .fullCanvas(size: CGSize(width: 50, height: 40)))
        #expect(viewModel.document.savedSelection?.points.first == CGPoint(x: 22, y: 18))
        #expect(croppedAlpha.width == 50)
        #expect(croppedAlpha.height == 40)
        #expect(croppedAlpha.alpha[6 * 50 + 6] == 255)
        #expect(croppedAlpha.alpha.filter { $0 == 255 }.count == 1)
        #expect(viewModel.document.guides.count == 2)
        #expect(viewModel.document.guides.contains { $0.orientation == .vertical && $0.position == 5 })
        #expect(viewModel.document.guides.contains { $0.orientation == .horizontal && $0.position == 5 })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.cropSelection"))
        #expect(!viewModel.canCropToSelection)
        #expect(viewModel.canUndo)
    }

    @Test
    func cropToSelectionUsesRasterPixelsAndRejectsInvertedCanvasBounds() throws {
        let canvasSize = CGSize(width: 100, height: 80)
        let viewModel = ImageEditorViewModel(
            sourceName: "raster-selection.png",
            image: testImage(color: .systemGreen, size: canvasSize)
        ) { _ in }
        viewModel.document.selection = .raster(
            mask: rectangularMask(
                width: Int(canvasSize.width),
                height: Int(canvasSize.height),
                rect: CGRect(x: 24, y: 16, width: 40, height: 32)
            ),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )

        #expect(viewModel.canCropToSelection)
        viewModel.cropToSelection()

        #expect(viewModel.document.canvasSize == CGSize(width: 40, height: 32))
        #expect(viewModel.document.selection == .fullCanvas(size: CGSize(width: 40, height: 32)))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.cropSelection"))
        #expect(viewModel.canUndo)

        viewModel.undo()
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count
        var invertedSelection = ImageEditorSelection.rectangle(
            CGRect(x: 20, y: 10, width: 50, height: 40)
        )
        invertedSelection.isInverted = true
        viewModel.document.selection = invertedSelection

        #expect(!viewModel.canCropToSelection)
        viewModel.cropToSelection()

        #expect(viewModel.document.canvasSize == canvasSize)
        #expect(viewModel.document.selection == invertedSelection)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.cropSelectionInvalid"))
    }

    @Test
    func canvasRotationCommandsTransformLayerFramesAndHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemPurple, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 10, y: 12, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.transparent(size: CGSize(width: 20, height: 16))
        viewModel.document.layers[layerIndex].mask = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))

        viewModel.rotateCounterclockwise()

        #expect(viewModel.document.canvasSize == CGSize(width: 80, height: 100))
        #expect(viewModel.document.layers[layerIndex].frame == CGRect(x: 12, y: 70, width: 16, height: 20))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.rotateCounterclockwise"))

        viewModel.undo()
        viewModel.rotate180()

        #expect(viewModel.document.canvasSize == CGSize(width: 100, height: 80))
        #expect(viewModel.document.layers[layerIndex].frame == CGRect(x: 70, y: 52, width: 20, height: 16))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.rotate180"))
    }

    @Test
    func trimTransparentPixelsCropsToVisibleAlphaBounds() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: NSImage.transparent(size: NSSize(width: 100, height: 80))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 30, y: 22, width: 20, height: 16)
        viewModel.document.layers[layerIndex].image = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        viewModel.document.selection = .rectangle(CGRect(x: 34, y: 26, width: 8, height: 6))
        viewModel.document.savedSelection = .rectangle(CGRect(x: 38, y: 30, width: 6, height: 4))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Trim Alpha",
                mask: sparseMask(width: 100, height: 80, points: [CGPoint(x: 35, y: 27), CGPoint(x: 90, y: 70)])
            )
        ]
        viewModel.document.guides = [
            ImageEditorGuide(orientation: .vertical, position: 30),
            ImageEditorGuide(orientation: .horizontal, position: 22),
            ImageEditorGuide(orientation: .vertical, position: 90)
        ]

        viewModel.trimTransparentPixels()

        let trimmedAlpha = try #require(viewModel.document.alphaChannels.first?.mask)
        #expect(viewModel.document.canvasSize == CGSize(width: 20, height: 16))
        #expect(viewModel.document.layers[layerIndex].frame == CGRect(x: 0, y: 0, width: 20, height: 16))
        #expect(viewModel.document.selection == .fullCanvas(size: CGSize(width: 20, height: 16)))
        #expect(viewModel.document.savedSelection?.points.first == CGPoint(x: 8, y: 8))
        #expect(trimmedAlpha.width == 20)
        #expect(trimmedAlpha.height == 16)
        #expect(trimmedAlpha.alpha[5 * 20 + 5] == 255)
        #expect(trimmedAlpha.alpha.filter { $0 == 255 }.count == 1)
        #expect(viewModel.document.guides.count == 2)
        #expect(viewModel.document.guides.contains { $0.orientation == .vertical && $0.position == 0 })
        #expect(viewModel.document.guides.contains { $0.orientation == .horizontal && $0.position == 0 })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.trim"))
    }

    @Test
    func revealAllExpandsCanvasToVisibleLayerBounds() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "source.png",
            image: testImage(color: .systemBlue, size: NSSize(width: 100, height: 80))
        ) { _ in }
        let initialLayerIDs = viewModel.document.layers.map(\.id)
        var leftLayer = ImageEditorLayer.blank(name: "Left", size: CGSize(width: 20, height: 16))
        leftLayer.image = NSImage.opaqueMask(size: CGSize(width: 20, height: 16))
        leftLayer.frame = CGRect(x: -10, y: 12, width: 20, height: 16)
        var rightLayer = ImageEditorLayer.blank(name: "Right", size: CGSize(width: 30, height: 20))
        rightLayer.image = NSImage.opaqueMask(size: CGSize(width: 30, height: 20))
        rightLayer.frame = CGRect(x: 90, y: 70, width: 30, height: 20)
        var hiddenLayer = ImageEditorLayer.blank(name: "Hidden", size: CGSize(width: 30, height: 20))
        hiddenLayer.frame = CGRect(x: -40, y: 10, width: 30, height: 20)
        hiddenLayer.isVisible = false
        viewModel.document.layers.append(contentsOf: [leftLayer, rightLayer, hiddenLayer])
        viewModel.document.selection = .rectangle(CGRect(x: 6, y: 14, width: 10, height: 8))
        viewModel.document.savedSelection = .rectangle(CGRect(x: 12, y: 18, width: 8, height: 6))
        viewModel.document.alphaChannels = [
            ImageEditorAlphaChannel(
                name: "Reveal Alpha",
                mask: sparseMask(width: 100, height: 80, points: [CGPoint(x: 6, y: 16), CGPoint(x: 99, y: 79)])
            )
        ]
        viewModel.document.guides = [
            ImageEditorGuide(orientation: .vertical, position: 4),
            ImageEditorGuide(orientation: .horizontal, position: 20)
        ]

        #expect(viewModel.canRevealAllLayers)
        viewModel.revealAllLayers()

        let revealedAlpha = try #require(viewModel.document.alphaChannels.first?.mask)
        let revealedLeft = try #require(viewModel.document.layers.first { $0.id == leftLayer.id })
        let revealedRight = try #require(viewModel.document.layers.first { $0.id == rightLayer.id })
        let revealedHidden = try #require(viewModel.document.layers.first { $0.id == hiddenLayer.id })
        #expect(viewModel.document.canvasSize == CGSize(width: 130, height: 90))
        for initialLayerID in initialLayerIDs {
            #expect(
                viewModel.document.layers.first { $0.id == initialLayerID }?.frame
                    == CGRect(x: 10, y: 0, width: 100, height: 80)
            )
        }
        #expect(revealedLeft.frame == CGRect(x: 0, y: 12, width: 20, height: 16))
        #expect(revealedRight.frame == CGRect(x: 100, y: 70, width: 30, height: 20))
        #expect(revealedHidden.frame == CGRect(x: -30, y: 10, width: 30, height: 20))
        #expect(viewModel.document.selection?.points.first == CGPoint(x: 16, y: 14))
        #expect(viewModel.document.savedSelection?.points.first == CGPoint(x: 22, y: 18))
        #expect(revealedAlpha.width == 130)
        #expect(revealedAlpha.height == 90)
        #expect(revealedAlpha.alpha[16 * 130 + 16] == 255)
        #expect(revealedAlpha.alpha[79 * 130 + 109] == 255)
        #expect(viewModel.document.guides.contains { $0.orientation == .vertical && $0.position == 14 })
        #expect(viewModel.document.guides.contains { $0.orientation == .horizontal && $0.position == 20 })
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.revealAll"))
        #expect(!viewModel.canRevealAllLayers)
        #expect(viewModel.canUndo)
    }

    private func testImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    private func sparseMask(width: Int, height: Int, points: [CGPoint]) -> ImageEditorSelectionMask {
        var alpha = [UInt8](repeating: 0, count: width * height)
        for point in points {
            let x = min(width - 1, max(0, Int(point.x.rounded())))
            let y = min(height - 1, max(0, Int(point.y.rounded())))
            alpha[y * width + x] = 255
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }

    private func rectangularMask(
        width: Int,
        height: Int,
        rect: CGRect
    ) -> ImageEditorSelectionMask {
        var alpha = [UInt8](repeating: 0, count: width * height)
        let bounds = rect.standardized.integral.intersection(
            CGRect(x: 0, y: 0, width: width, height: height)
        )
        guard !bounds.isNull, !bounds.isEmpty else {
            return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
        }
        for y in Int(bounds.minY)..<Int(bounds.maxY) {
            for x in Int(bounds.minX)..<Int(bounds.maxX) {
                alpha[y * width + x] = UInt8.max
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }
}
