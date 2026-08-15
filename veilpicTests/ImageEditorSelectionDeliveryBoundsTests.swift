//
//  ImageEditorSelectionDeliveryBoundsTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/15.
//

import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSelectionDeliveryBoundsTests {
    @Test
    func slicesAndHotspotsUseRasterSelectedPixelBounds() throws {
        let canvasSize = CGSize(width: 120, height: 90)
        let viewModel = ImageEditorViewModel(
            sourceName: "delivery-region.png",
            image: testImage(size: canvasSize)
        ) { _ in }
        let selectedRect = CGRect(x: 24, y: 18, width: 46, height: 28)
        viewModel.document.selection = .raster(
            mask: rectangularMask(canvasSize: canvasSize, rect: selectedRect),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )

        #expect(viewModel.canCreateSliceFromSelection)
        #expect(viewModel.canCreateHotspotFromSelection)
        let slice = try #require(viewModel.createSliceFromCurrentSelection(name: "Hero"))
        let hotspot = try #require(viewModel.createHotspotFromCurrentSelection(
            name: "Hero link",
            url: "https://example.com/hero"
        ))

        #expect(slice.frame == selectedRect)
        #expect(hotspot.frame == selectedRect)
        #expect(viewModel.document.slices == [slice])
        #expect(viewModel.document.hotspots == [hotspot])
        #expect(viewModel.document.history.suffix(2).map(\.title) == [
            L10n.format("imageEditor.history.sliceCreated", "Hero"),
            L10n.format("imageEditor.history.hotspotCreated", "Hero link")
        ])
    }

    @Test
    func emptySelectionCannotCreateDeliveryRegionsAndInversionUsesCanvas() throws {
        let canvasSize = CGSize(width: 120, height: 90)
        let viewModel = ImageEditorViewModel(
            sourceName: "delivery-boundaries.png",
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
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(!viewModel.canCreateSliceFromSelection)
        #expect(!viewModel.canCreateHotspotFromSelection)
        #expect(viewModel.createSliceFromCurrentSelection(name: "Empty") == nil)
        #expect(viewModel.createHotspotFromCurrentSelection(name: "Empty") == nil)
        #expect(viewModel.document.slices.isEmpty)
        #expect(viewModel.document.hotspots.isEmpty)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)

        var invertedSelection = ImageEditorSelection.rectangle(
            CGRect(x: 16, y: 12, width: 40, height: 30)
        )
        invertedSelection.isInverted = true
        viewModel.document.selection = invertedSelection
        let canvasBounds = CGRect(origin: .zero, size: canvasSize)

        let slice = try #require(viewModel.createSliceFromCurrentSelection(name: "Inverse"))
        let hotspot = try #require(viewModel.createHotspotFromCurrentSelection(name: "Inverse link"))
        #expect(slice.frame == canvasBounds)
        #expect(hotspot.frame == canvasBounds)
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
