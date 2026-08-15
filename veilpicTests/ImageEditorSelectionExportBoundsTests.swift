//
//  ImageEditorSelectionExportBoundsTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/15.
//

import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSelectionExportBoundsTests {
    @Test
    func selectionExportUsesRasterSelectedPixelBounds() throws {
        let canvasSize = CGSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "raster-export.png",
            image: testImage(size: canvasSize)
        ) { _ in }
        let selectedRect = CGRect(x: 20, y: 15, width: 24, height: 18)
        viewModel.document.selection = .raster(
            mask: rectangularMask(canvasSize: canvasSize, rect: selectedRect),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )

        #expect(viewModel.canExportSelection)
        let image = try #require(viewModel.selectedSelectionExportImage())
        let exportedData = try #require(viewModel.exportData(settings: ImageEditorExportSettings(
            format: .png,
            scope: .selection
        )))
        let exportedImage = try #require(NSImage(data: exportedData))
        let center = try #require(
            exportedImage.color(at: CGPoint(x: 12, y: 9))?.usingColorSpace(.deviceRGB)
        )

        #expect(image.size == selectedRect.size)
        #expect(exportedImage.size == selectedRect.size)
        #expect(center.blueComponent > 0.7)
        #expect(center.alphaComponent > 0.8)
    }

    @Test
    func emptySelectionCannotExportAndInversionKeepsCanvasBounds() throws {
        let canvasSize = CGSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "selection-export-boundaries.png",
            image: testImage(size: canvasSize)
        ) { _ in }
        let emptyMask = ImageEditorSelectionMask(
            width: Int(canvasSize.width),
            height: Int(canvasSize.height),
            alpha: [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        )
        viewModel.document.selection = .raster(
            mask: emptyMask,
            bounds: CGRect(origin: .zero, size: canvasSize)
        )

        #expect(!viewModel.canExportSelection)
        #expect(viewModel.selectedSelectionExportImage() == nil)
        viewModel.exportSettings.scope = .selection
        viewModel.openExportPanel()
        #expect(viewModel.exportSettings.scope == .composited)

        var invertedSelection = ImageEditorSelection.rectangle(
            CGRect(x: 20, y: 15, width: 24, height: 18)
        )
        invertedSelection.isInverted = true
        viewModel.document.selection = invertedSelection

        #expect(viewModel.canExportSelection)
        let invertedImage = try #require(viewModel.selectedSelectionExportImage())
        let outside = try #require(
            invertedImage.color(at: CGPoint(x: 4, y: 4))?.usingColorSpace(.deviceRGB)
        )
        let excluded = try #require(
            invertedImage.color(at: CGPoint(x: 30, y: 24))?.usingColorSpace(.deviceRGB)
        )
        #expect(invertedImage.size == canvasSize)
        #expect(outside.alphaComponent > 0.8)
        #expect(excluded.alphaComponent < 0.1)
    }

    private func rectangularMask(
        canvasSize: CGSize,
        rect: CGRect
    ) -> ImageEditorSelectionMask {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        var alpha = [UInt8](repeating: 0, count: width * height)
        let bounds = rect.standardized.integral.intersection(
            CGRect(origin: .zero, size: canvasSize)
        )
        for y in Int(bounds.minY)..<Int(bounds.maxY) {
            for x in Int(bounds.minX)..<Int(bounds.maxX) {
                alpha[y * width + x] = UInt8.max
            }
        }
        return ImageEditorSelectionMask(width: width, height: height, alpha: alpha)
    }

    private func testImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        } ?? NSImage(size: size)
    }
}
