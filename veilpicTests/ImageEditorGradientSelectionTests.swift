import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorGradientSelectionTests {
    @Test func gradientNoOpDoesNotCreateUndoOrHistory() throws {
        let zeroOpacity = ImageEditorViewModel(
            sourceName: "zero-opacity-gradient.png",
            image: .transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        zeroOpacity.opacity = 0
        let zeroHistoryCount = zeroOpacity.document.history.count
        let zeroUndoCount = zeroOpacity.undoStack.count

        zeroOpacity.drawGradient(
            from: CGPoint(x: 0, y: 30),
            to: CGPoint(x: 80, y: 30)
        )

        #expect(zeroOpacity.document.history.count == zeroHistoryCount)
        #expect(zeroOpacity.undoStack.count == zeroUndoCount)
        #expect(zeroOpacity.statusText == L10n.text("imageEditor.status.gradientUnchanged"))

        let transparencyLocked = ImageEditorViewModel(
            sourceName: "locked-transparent-gradient.png",
            image: .transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        let layerIndex = try #require(transparencyLocked.document.selectedLayerIndex)
        transparencyLocked.document.layers[layerIndex].locksTransparentPixels = true
        transparencyLocked.opacity = 1
        let lockedHistoryCount = transparencyLocked.document.history.count
        let lockedUndoCount = transparencyLocked.undoStack.count

        transparencyLocked.drawGradient(
            from: CGPoint(x: 0, y: 30),
            to: CGPoint(x: 80, y: 30)
        )

        #expect(transparencyLocked.document.history.count == lockedHistoryCount)
        #expect(transparencyLocked.undoStack.count == lockedUndoCount)
        #expect(transparencyLocked.statusText == L10n.text("imageEditor.status.gradientUnchanged"))
    }

    @Test func gradientMapsCanvasSelectionIntoOffsetScaledLayer() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "offset-gradient.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 20, y: 15, width: 60, height: 45)
        viewModel.createRectSelection(
            from: CGPoint(x: 30, y: 25),
            to: CGPoint(x: 60, y: 45)
        )
        viewModel.foregroundColor = .systemRed
        viewModel.backgroundColor = .systemBlue
        viewModel.opacity = 1

        viewModel.drawGradient(
            from: CGPoint(x: 30, y: 35),
            to: CGPoint(x: 60, y: 35)
        )

        let layerID = viewModel.document.layers[layerIndex].id
        let composited = viewModel.document.compositedImage(includingOnly: [layerID])
        let selectedLeft = try #require(composited.color(at: CGPoint(x: 32, y: 35)))
        let selectedRight = try #require(composited.color(at: CGPoint(x: 58, y: 35)))
        let outsideLeft = try #require(composited.color(at: CGPoint(x: 24, y: 35)))
        let outsideBottom = try #require(composited.color(at: CGPoint(x: 45, y: 52)))
        #expect(selectedLeft.alphaComponent > 0.8)
        #expect(selectedLeft.redComponent > selectedLeft.blueComponent)
        #expect(selectedRight.alphaComponent > 0.8)
        #expect(selectedRight.blueComponent > selectedRight.redComponent)
        #expect(outsideLeft.alphaComponent < 0.1)
        #expect(outsideBottom.alphaComponent < 0.1)
    }

    @Test func invalidRasterSelectionCannotEscapeMaskAndPaintWholeLayer() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "invalid-mask-gradient.png",
            image: .transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        viewModel.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 80, height: 60, alpha: []),
            bounds: CGRect(x: 10, y: 10, width: 30, height: 20)
        )
        viewModel.foregroundColor = .systemRed
        viewModel.backgroundColor = .systemBlue
        viewModel.opacity = 1
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.drawGradient(
            from: CGPoint(x: 10, y: 20),
            to: CGPoint(x: 40, y: 20)
        )

        let image = try #require(viewModel.document.selectedLayer?.image)
        let inside = try #require(image.color(at: CGPoint(x: 20, y: 20)))
        let outside = try #require(image.color(at: CGPoint(x: 65, y: 45)))
        #expect(inside.alphaComponent < 0.1)
        #expect(outside.alphaComponent < 0.1)
        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @Test func gradientOutsideSelectedLayerDoesNotCreateHistory() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "gradient-selection.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        let layerIndex = try #require(viewModel.document.selectedLayerIndex)
        viewModel.document.layers[layerIndex].frame = CGRect(x: 70, y: 55, width: 40, height: 25)
        viewModel.createRectSelection(
            from: CGPoint(x: 5, y: 5),
            to: CGPoint(x: 30, y: 25)
        )
        let historyCount = viewModel.document.history.count
        let undoCount = viewModel.undoStack.count

        viewModel.drawGradient(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 120, y: 90)
        )

        #expect(viewModel.document.history.count == historyCount)
        #expect(viewModel.undoStack.count == undoCount)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.selectionEmpty"))
    }

    @Test func featheredOrInvertedSelectionCanStillReachLayer() throws {
        let feathered = ImageEditorViewModel(
            sourceName: "feathered-gradient.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        let featheredIndex = try #require(feathered.document.selectedLayerIndex)
        feathered.document.layers[featheredIndex].frame = CGRect(x: 32, y: 5, width: 50, height: 40)
        feathered.createRectSelection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 30, y: 25))
        feathered.feather = 4
        let featheredHistoryCount = feathered.document.history.count

        feathered.drawGradient(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 120, y: 90))

        #expect(feathered.document.history.count == featheredHistoryCount + 1)

        let inverted = ImageEditorViewModel(
            sourceName: "inverted-gradient.png",
            image: .transparent(size: CGSize(width: 120, height: 90))
        ) { _ in }
        let invertedIndex = try #require(inverted.document.selectedLayerIndex)
        inverted.document.layers[invertedIndex].frame = CGRect(x: 70, y: 55, width: 40, height: 25)
        inverted.createRectSelection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 30, y: 25))
        inverted.invertSelection()
        let invertedHistoryCount = inverted.document.history.count

        inverted.drawGradient(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 120, y: 90))

        #expect(inverted.document.history.count == invertedHistoryCount + 1)
    }
}
