//
//  ImageEditorSelectionTargetBoundsTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/8/15.
//

import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSelectionTargetBoundsTests {
    @Test
    func layerFitFillAndAlignmentUseRasterSelectedPixelBounds() throws {
        let canvasSize = CGSize(width: 100, height: 80)
        let viewModel = ImageEditorViewModel(
            sourceName: "selection-target.png",
            image: testImage(color: .systemBlue, size: canvasSize)
        ) { _ in }
        viewModel.addLayer()
        let layerID = try #require(viewModel.document.selectedLayerID)
        let targetRect = CGRect(x: 20, y: 10, width: 40, height: 30)
        viewModel.document.selection = .raster(
            mask: rectangularMask(canvasSize: canvasSize, rect: targetRect),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )

        func setLayerFrame(_ frame: CGRect) throws {
            let index = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
            viewModel.document.layers[index].frame = frame
            viewModel.document.layers[index].image = testImage(color: .systemGreen, size: frame.size)
            viewModel.selectLayer(layerID)
        }

        try setLayerFrame(CGRect(x: 0, y: 0, width: 20, height: 10))
        #expect(viewModel.canFitSelectedLayerToSelection)
        viewModel.fitSelectedLayerToSelection()
        #expect(viewModel.document.selectedLayer?.frame == CGRect(x: 20, y: 15, width: 40, height: 20))

        try setLayerFrame(CGRect(x: 0, y: 0, width: 20, height: 10))
        viewModel.fillSelectedLayerToSelection()
        #expect(viewModel.document.selectedLayer?.frame == CGRect(x: 10, y: 10, width: 60, height: 30))

        try setLayerFrame(CGRect(x: 0, y: 0, width: 12, height: 8))
        #expect(viewModel.canAlignSelectedLayersToSelection)
        viewModel.alignSelectedLayersToSelection(.right)
        #expect(viewModel.document.selectedLayer?.frame == CGRect(x: 48, y: 0, width: 12, height: 8))

        viewModel.alignSelectedLayersToSelection(.top)
        #expect(viewModel.document.selectedLayer?.frame == CGRect(x: 48, y: 32, width: 12, height: 8))
    }

    @Test
    func selectionTargetCommandsRejectEmptyRasterSelectionWithoutHistory() throws {
        let canvasSize = CGSize(width: 100, height: 80)
        let viewModel = ImageEditorViewModel(
            sourceName: "empty-selection-target.png",
            image: testImage(color: .systemBlue, size: canvasSize)
        ) { _ in }
        viewModel.addLayer()
        let layerID = try #require(viewModel.document.selectedLayerID)
        let layerIndex = try #require(viewModel.document.layers.firstIndex { $0.id == layerID })
        let originalFrame = CGRect(x: 7, y: 9, width: 18, height: 12)
        viewModel.document.layers[layerIndex].frame = originalFrame
        viewModel.document.layers[layerIndex].image = testImage(color: .systemGreen, size: originalFrame.size)
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(
                width: Int(canvasSize.width),
                height: Int(canvasSize.height),
                alpha: [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
            ),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        #expect(!viewModel.canFitSelectedLayerToSelection)
        #expect(!viewModel.canAlignSelectedLayersToSelection)
        viewModel.fitSelectedLayerToSelection()
        #expect(viewModel.statusText == L10n.text("imageEditor.status.noSelection"))
        viewModel.alignSelectedLayersToSelection(.left)

        #expect(viewModel.document.selectedLayer?.frame == originalFrame)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.noSelection"))
    }

    @Test
    func moveAlignmentTargetDefaultsToSelectedLayerBounds() throws {
        let (viewModel, firstID, secondID) = try makeMoveAlignmentViewModel()
        viewModel.selectLayer(firstID)
        viewModel.selectLayer(secondID, extendingSelection: true)

        #expect(viewModel.moveToolAlignmentTarget == .selectedLayers)
        #expect(viewModel.canApplyMoveToolAlignment)
        viewModel.applyMoveToolAlignment(.left)
        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        #expect(viewModel.document.layers[firstIndex].frame.minX == 15)
        #expect(viewModel.document.layers[secondIndex].frame.minX == 15)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAlign"))
    }

    @Test
    func moveAlignmentTargetRoutesCanvasAndPixelSelection() throws {
        let canvasSize = CGSize(width: 120, height: 90)
        let (viewModel, firstID, _) = try makeMoveAlignmentViewModel()
        viewModel.selectLayer(firstID)
        viewModel.moveToolAlignmentTarget = .canvas
        #expect(viewModel.canApplyMoveToolAlignment)
        viewModel.applyMoveToolAlignment(.right)
        #expect(viewModel.document.selectedLayer?.frame.maxX == canvasSize.width)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAlignCanvas"))

        viewModel.document.selection = .rectangle(
            CGRect(x: 30, y: 20, width: 55, height: 40)
        )
        viewModel.moveToolAlignmentTarget = .pixelSelection
        #expect(viewModel.canApplyMoveToolAlignment)
        viewModel.applyMoveToolAlignment(.top)
        #expect(viewModel.document.selectedLayer?.frame.maxY == 60)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerAlignSelection"))

        viewModel.document.selection = nil
        #expect(!viewModel.canApplyMoveToolAlignment)
        #expect(ImageEditorMoveAlignmentTarget.allCases.allSatisfy {
            $0.title != "imageEditor.option.moveAlignmentTarget.\($0.rawValue)"
        })
    }

    private func makeMoveAlignmentViewModel() throws -> (
        viewModel: ImageEditorViewModel,
        firstID: UUID,
        secondID: UUID
    ) {
        let canvasSize = CGSize(width: 120, height: 90)
        let viewModel = ImageEditorViewModel(
            sourceName: "move-alignment-target.png",
            image: testImage(color: .systemBlue, size: canvasSize)
        ) { _ in }
        viewModel.addLayer()
        let firstID = try #require(viewModel.document.selectedLayerID)
        let firstIndex = try #require(viewModel.document.layers.firstIndex { $0.id == firstID })
        viewModel.document.layers[firstIndex].frame = CGRect(x: 15, y: 12, width: 20, height: 18)
        viewModel.document.layers[firstIndex].image = testImage(
            color: .systemGreen,
            size: CGSize(width: 20, height: 18)
        )
        viewModel.addLayer()
        let secondID = try #require(viewModel.document.selectedLayerID)
        let secondIndex = try #require(viewModel.document.layers.firstIndex { $0.id == secondID })
        viewModel.document.layers[secondIndex].frame = CGRect(x: 70, y: 44, width: 12, height: 10)
        viewModel.document.layers[secondIndex].image = testImage(
            color: .systemOrange,
            size: CGSize(width: 12, height: 10)
        )
        return (viewModel, firstID, secondID)
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

    private func testImage(color: NSColor, size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        } ?? NSImage(size: size)
    }
}
