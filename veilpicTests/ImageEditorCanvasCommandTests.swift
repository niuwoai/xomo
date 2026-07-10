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
        let croppedSelectionMask = try #require(viewModel.document.selection?.rasterMask)
        let croppedAlpha = try #require(viewModel.document.alphaChannels.first?.mask)
        #expect(viewModel.document.canvasSize == CGSize(width: 50, height: 40))
        #expect(croppedLayer.frame == CGRect(x: 10, y: 12, width: 20, height: 16))
        #expect(croppedLayer.mask?.size == CGSize(width: 50, height: 40))
        #expect(viewModel.document.selection?.points.first == CGPoint(x: 5, y: 5))
        #expect(croppedSelectionMask.width == 50)
        #expect(croppedSelectionMask.height == 40)
        #expect(croppedSelectionMask.alpha[6 * 50 + 6] == 255)
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
}
