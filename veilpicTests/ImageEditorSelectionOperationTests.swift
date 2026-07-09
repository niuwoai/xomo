//
//  ImageEditorSelectionOperationTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/9.
//

import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionOperationTests {
    @Test func imageEditorSelectAllCoversCanvas() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.selectAll()

        let selection = try #require(viewModel.document.selection)
        #expect(selection.bounds == CGRect(origin: .zero, size: canvasSize))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionAll"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionAll"))
    }

    @Test func imageEditorExpandsAndContractsSelectionMask() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 10, y: 8), to: CGPoint(x: 20, y: 18))
        viewModel.selectionModifyAmount = 3
        viewModel.expandSelection()

        var selection = try #require(viewModel.document.selection)
        var mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 7, y: 13) == 255)
        #expect(maskAlpha(mask, x: 6, y: 13) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionExpand"))

        viewModel.selectionModifyAmount = 2
        viewModel.contractSelection()

        selection = try #require(viewModel.document.selection)
        mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 8, y: 13) == 0)
        #expect(maskAlpha(mask, x: 10, y: 13) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionContract"))
    }

    @Test func imageEditorFeathersSelectionMask() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 10, y: 8), to: CGPoint(x: 20, y: 18))
        viewModel.selectionModifyAmount = 3
        viewModel.featherSelection()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 15, y: 13) == 255)
        #expect(maskAlpha(mask, x: 7, y: 13) > 0)
        #expect(maskAlpha(mask, x: 7, y: 13) < 255)
        #expect(maskAlpha(mask, x: 6, y: 13) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFeather"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionFeathered", 3))
    }

    @Test func imageEditorCreatesSelectionBorderMask() async throws {
        let canvasSize = NSSize(width: 40, height: 30)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }

        viewModel.createRectSelection(from: CGPoint(x: 10, y: 8), to: CGPoint(x: 20, y: 18))
        viewModel.selectionModifyAmount = 2
        viewModel.borderSelection()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 8, y: 13) == 255)
        #expect(maskAlpha(mask, x: 10, y: 13) == 255)
        #expect(maskAlpha(mask, x: 15, y: 13) == 0)
        #expect(maskAlpha(mask, x: 22, y: 13) == 255)
        #expect(maskAlpha(mask, x: 23, y: 13) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionBorder"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionBordered", 2))
    }

    @Test func imageEditorSmoothsSelectionMask() async throws {
        let canvasSize = NSSize(width: 12, height: 12)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))

        for y in 3...8 {
            for x in 3...8 {
                alpha[y * Int(canvasSize.width) + x] = 255
            }
        }
        alpha[2 * Int(canvasSize.width) + 5] = 255
        alpha[5 * Int(canvasSize.width) + 5] = 0
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 12, height: 12, alpha: alpha),
            bounds: CGRect(x: 3, y: 2, width: 6, height: 7)
        )
        viewModel.selectionModifyAmount = 1

        viewModel.smoothSelection()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 5, y: 2) == 0)
        #expect(maskAlpha(mask, x: 5, y: 5) == 255)
        #expect(maskAlpha(mask, x: 4, y: 4) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionSmooth"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionSmoothed", 1))
    }

    @Test func imageEditorFillsSelectionHolesWithoutSelectingOutsideBackground() async throws {
        let canvasSize = NSSize(width: 8, height: 8)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))

        for y in 2...5 {
            for x in 2...5 {
                alpha[y * Int(canvasSize.width) + x] = 255
            }
        }
        alpha[3 * Int(canvasSize.width) + 3] = 0
        alpha[4 * Int(canvasSize.width) + 4] = 0
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 8, height: 8, alpha: alpha),
            bounds: CGRect(x: 2, y: 2, width: 4, height: 4)
        )

        viewModel.fillSelectionHoles()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 4, y: 4) == 255)
        #expect(maskAlpha(mask, x: 1, y: 1) == 0)
        #expect(maskAlpha(mask, x: 6, y: 6) == 0)
        #expect(selection.bounds == CGRect(x: 2, y: 2, width: 4, height: 4))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFillHoles"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionFillHoles"))
    }

    @Test func imageEditorRemovesSmallSelectionSpecklesWithoutShrinkingMainIsland() async throws {
        let canvasSize = NSSize(width: 10, height: 10)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))

        for y in 3...5 {
            for x in 3...5 {
                alpha[y * Int(canvasSize.width) + x] = 255
            }
        }
        alpha[1 * Int(canvasSize.width) + 8] = 255
        alpha[1 * Int(canvasSize.width) + 9] = 255
        alpha[8 * Int(canvasSize.width) + 1] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 10, height: 10, alpha: alpha),
            bounds: CGRect(x: 1, y: 1, width: 9, height: 8)
        )
        viewModel.selectionModifyAmount = 2

        viewModel.removeSelectionSpeckles()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 5, y: 5) == 255)
        #expect(maskAlpha(mask, x: 8, y: 1) == 0)
        #expect(maskAlpha(mask, x: 9, y: 1) == 0)
        #expect(maskAlpha(mask, x: 1, y: 8) == 0)
        #expect(selection.bounds == CGRect(x: 3, y: 3, width: 3, height: 3))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionRemoveSpeckles"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionSpecklesRemoved", 2))
    }

    @Test func imageEditorMovesSelectionMaskWithoutMovingPixels() async throws {
        let canvasSize = NSSize(width: 8, height: 6)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[1 * Int(canvasSize.width) + 1] = 255
        alpha[1 * Int(canvasSize.width) + 2] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 8, height: 6, alpha: alpha),
            bounds: CGRect(x: 1, y: 1, width: 2, height: 1)
        )
        viewModel.selectionModifyAmount = 2

        viewModel.moveSelectionRight()
        viewModel.selectionModifyAmount = 1
        viewModel.moveSelectionUp()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 1, y: 1) == 0)
        #expect(maskAlpha(mask, x: 2, y: 1) == 0)
        #expect(maskAlpha(mask, x: 3, y: 2) == 255)
        #expect(maskAlpha(mask, x: 4, y: 2) == 255)
        #expect(selection.bounds == CGRect(x: 3, y: 2, width: 2, height: 1))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionMove"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.selectionMoved", 0, 1))
    }

    @Test func imageEditorFlipsSelectionMaskAroundItsOwnBounds() async throws {
        let canvasSize = NSSize(width: 6, height: 5)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[1 * Int(canvasSize.width) + 1] = 255
        alpha[2 * Int(canvasSize.width) + 1] = 255
        alpha[2 * Int(canvasSize.width) + 2] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 6, height: 5, alpha: alpha),
            bounds: CGRect(x: 1, y: 1, width: 2, height: 2)
        )

        viewModel.flipSelectionHorizontal()

        var selection = try #require(viewModel.document.selection)
        var mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 1, y: 1) == 0)
        #expect(maskAlpha(mask, x: 2, y: 1) == 255)
        #expect(maskAlpha(mask, x: 1, y: 2) == 255)
        #expect(maskAlpha(mask, x: 2, y: 2) == 255)
        #expect(selection.bounds == CGRect(x: 1, y: 1, width: 2, height: 2))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFlipHorizontal"))

        viewModel.flipSelectionVertical()

        selection = try #require(viewModel.document.selection)
        mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 1, y: 1) == 255)
        #expect(maskAlpha(mask, x: 2, y: 1) == 255)
        #expect(maskAlpha(mask, x: 1, y: 2) == 0)
        #expect(maskAlpha(mask, x: 2, y: 2) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFlipVertical"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionFlippedVertical"))
    }

    @Test func imageEditorRotatesSelectionMaskAroundItsOwnBounds() async throws {
        let canvasSize = NSSize(width: 7, height: 6)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[1 * Int(canvasSize.width) + 2] = 255
        alpha[1 * Int(canvasSize.width) + 3] = 255
        alpha[1 * Int(canvasSize.width) + 4] = 255
        alpha[2 * Int(canvasSize.width) + 2] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 7, height: 6, alpha: alpha),
            bounds: CGRect(x: 2, y: 1, width: 3, height: 2)
        )

        viewModel.rotateSelectionClockwise()

        var selection = try #require(viewModel.document.selection)
        var mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 2, y: 1) == 255)
        #expect(maskAlpha(mask, x: 3, y: 1) == 255)
        #expect(maskAlpha(mask, x: 3, y: 2) == 255)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 4, y: 1) == 0)
        #expect(selection.bounds == CGRect(x: 2, y: 1, width: 2, height: 3))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionRotateClockwise"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionRotatedClockwise"))

        viewModel.rotateSelection180()

        selection = try #require(viewModel.document.selection)
        mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 2, y: 1) == 255)
        #expect(maskAlpha(mask, x: 2, y: 2) == 255)
        #expect(maskAlpha(mask, x: 2, y: 3) == 255)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 3, y: 1) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionRotate180"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionRotated180"))
    }

    @Test func imageEditorRotatesSelectionMaskCounterclockwise() async throws {
        let canvasSize = NSSize(width: 7, height: 6)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[1 * Int(canvasSize.width) + 2] = 255
        alpha[1 * Int(canvasSize.width) + 3] = 255
        alpha[1 * Int(canvasSize.width) + 4] = 255
        alpha[2 * Int(canvasSize.width) + 2] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 7, height: 6, alpha: alpha),
            bounds: CGRect(x: 2, y: 1, width: 3, height: 2)
        )

        viewModel.rotateSelectionCounterclockwise()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(maskAlpha(mask, x: 2, y: 1) == 255)
        #expect(maskAlpha(mask, x: 2, y: 2) == 255)
        #expect(maskAlpha(mask, x: 2, y: 3) == 255)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 3, y: 1) == 0)
        #expect(selection.bounds == CGRect(x: 2, y: 1, width: 2, height: 3))
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionRotateCounterclockwise"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionRotatedCounterclockwise"))
    }

    @Test func imageEditorScalesSelectionMaskAroundItsOwnCenter() async throws {
        let canvasSize = NSSize(width: 8, height: 8)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[2 * Int(canvasSize.width) + 2] = 255
        alpha[2 * Int(canvasSize.width) + 3] = 255
        alpha[3 * Int(canvasSize.width) + 2] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 8, height: 8, alpha: alpha),
            bounds: CGRect(x: 2, y: 2, width: 2, height: 2)
        )

        viewModel.scaleSelectionUp()

        var selection = try #require(viewModel.document.selection)
        var mask = try #require(selection.rasterMask)
        #expect(selection.bounds == CGRect(x: 1, y: 1, width: 4, height: 4))
        #expect(maskAlpha(mask, x: 1, y: 1) == 255)
        #expect(maskAlpha(mask, x: 4, y: 1) == 255)
        #expect(maskAlpha(mask, x: 1, y: 4) == 255)
        #expect(maskAlpha(mask, x: 4, y: 4) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionScaleUp"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionScaledUp"))

        alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        for y in 2...5 {
            for x in 2...5 {
                alpha[y * Int(canvasSize.width) + x] = 255
            }
        }
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 8, height: 8, alpha: alpha),
            bounds: CGRect(x: 2, y: 2, width: 4, height: 4)
        )

        viewModel.scaleSelectionDown()

        selection = try #require(viewModel.document.selection)
        mask = try #require(selection.rasterMask)
        #expect(selection.bounds == CGRect(x: 3, y: 3, width: 2, height: 2))
        #expect(maskAlpha(mask, x: 2, y: 2) == 0)
        #expect(maskAlpha(mask, x: 3, y: 3) == 255)
        #expect(maskAlpha(mask, x: 4, y: 4) == 255)
        #expect(maskAlpha(mask, x: 5, y: 5) == 0)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionScaleDown"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionScaledDown"))
    }

    @Test func imageEditorFitsSelectionMaskToCanvas() async throws {
        let canvasSize = NSSize(width: 5, height: 4)
        let viewModel = ImageEditorViewModel(sourceName: "source.png", image: testImage(size: canvasSize)) { _ in }
        var alpha = [UInt8](repeating: 0, count: Int(canvasSize.width * canvasSize.height))
        alpha[2 * Int(canvasSize.width) + 3] = 255
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 5, height: 4, alpha: alpha),
            bounds: CGRect(x: 3, y: 2, width: 1, height: 1)
        )

        viewModel.fitSelectionToCanvas()

        let selection = try #require(viewModel.document.selection)
        let mask = try #require(selection.rasterMask)
        #expect(selection.bounds == CGRect(x: 0, y: 0, width: 5, height: 4))
        #expect(maskAlpha(mask, x: 0, y: 0) == 255)
        #expect(maskAlpha(mask, x: 4, y: 3) == 255)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.selectionFitCanvas"))
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionFitCanvas"))
    }

    private func testImage(size: NSSize) -> NSImage {
        NSImage.rendered(size: size) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
        } ?? NSImage.transparent(size: size)
    }

    private func maskAlpha(_ mask: ImageEditorSelectionMask, x: Int, y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < mask.width, y < mask.height else { return 0 }
        return mask.alpha[y * mask.width + x]
    }
}
