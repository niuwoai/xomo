//
//  ImageEditorSelectionInfoBoundsTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/15.
//

import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSelectionInfoBoundsTests {
    @Test
    func informationPanelUsesRasterSelectedPixelBounds() {
        let canvasSize = CGSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "selection-info.png",
            image: testImage(size: canvasSize)
        ) { _ in }
        viewModel.document.selection = .raster(
            mask: rectangularMask(
                canvasSize: canvasSize,
                rect: CGRect(x: 13, y: 9, width: 17, height: 11)
            ),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )

        let info = viewModel.selectionBoundsInfoText
        #expect(info.contains("X 13"))
        #expect(info.contains("Y 9"))
        #expect(info.contains("W 17"))
        #expect(info.contains("H 11"))
    }

    @Test
    func informationPanelTreatsEmptyAndInvertedSelectionsByEffectivePixels() {
        let canvasSize = CGSize(width: 80, height: 60)
        let viewModel = ImageEditorViewModel(
            sourceName: "selection-info-boundaries.png",
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
        #expect(viewModel.selectionBoundsInfoText == L10n.text("imageEditor.info.selection.empty"))

        var invertedSelection = ImageEditorSelection.rectangle(
            CGRect(x: 13, y: 9, width: 17, height: 11)
        )
        invertedSelection.isInverted = true
        viewModel.document.selection = invertedSelection

        let info = viewModel.selectionBoundsInfoText
        #expect(info.contains("X 0"))
        #expect(info.contains("Y 0"))
        #expect(info.contains("W 80"))
        #expect(info.contains("H 60"))
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
