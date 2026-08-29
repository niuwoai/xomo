import AppKit
import Foundation
import Testing
@testable import musepic

struct ImageEditorTextHitTestingTests {
    @Test
    func canvasTolerancePreservesFourScreenPixelsAcrossZoomLevels() {
        #expect(ImageEditorTextHitTesting.canvasTolerance(displayScale: 1) == 4)
        #expect(ImageEditorTextHitTesting.canvasTolerance(displayScale: 0.25) == 16)
        #expect(ImageEditorTextHitTesting.canvasTolerance(displayScale: 4) == 1)
        #expect(ImageEditorTextHitTesting.canvasTolerance(displayScale: 0) == 4)
    }

    @Test @MainActor
    func editableTextHitTestingUsesTheSuppliedCanvasTolerance() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "text-hit-testing",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        viewModel.textValue = "Zoom-stable target"
        viewModel.addText(at: CGPoint(x: 100, y: 100))
        let layer = try #require(viewModel.document.selectedLayer)
        let pointOutsideByEight = CGPoint(x: layer.frame.minX - 8, y: layer.frame.midY)

        #expect(!viewModel.selectEditableTextLayer(at: pointOutsideByEight, hitTolerance: 4))
        #expect(viewModel.selectEditableTextLayer(at: pointOutsideByEight, hitTolerance: 16))
    }

    @Test @MainActor
    func editableTextHitTestingDefaultsToFourCanvasPixels() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "default-text-hit-testing",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        viewModel.textValue = "Default target"
        viewModel.addText(at: CGPoint(x: 100, y: 100))
        let layer = try #require(viewModel.document.selectedLayer)

        #expect(
            viewModel.selectEditableTextLayer(
                at: CGPoint(x: layer.frame.minX - 3, y: layer.frame.midY)
            )
        )
        #expect(
            !viewModel.selectEditableTextLayer(
                at: CGPoint(x: layer.frame.minX - 5, y: layer.frame.midY)
            )
        )
    }

    @Test @MainActor
    func editableTextHoverHitTestingIsPassiveAndRespectsEditability() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "passive-text-hover-hit-testing",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.textValue = "Hover target"
        viewModel.addText(at: CGPoint(x: 140, y: 120))
        let textLayer = try #require(viewModel.document.selectedLayer)
        let hitPoint = CGPoint(x: textLayer.frame.midX, y: textLayer.frame.midY)
        viewModel.selectLayer(backgroundID)

        #expect(viewModel.hasEditableTextLayer(at: hitPoint, hitTolerance: 0))
        #expect(viewModel.document.selectedLayerID == backgroundID)

        let textIndex = try #require(
            viewModel.document.layers.firstIndex(where: { $0.id == textLayer.id })
        )
        viewModel.document.layers[textIndex].locksPixels = true
        #expect(!viewModel.hasEditableTextLayer(at: hitPoint, hitTolerance: 0))
        #expect(viewModel.document.selectedLayerID == backgroundID)

        viewModel.document.layers[textIndex].locksPixels = false
        viewModel.document.layers[textIndex].isVisible = false
        #expect(!viewModel.hasEditableTextLayer(at: hitPoint, hitTolerance: 0))
        #expect(viewModel.document.selectedLayerID == backgroundID)
    }

    @Test @MainActor
    func moveToolDoubleClickTargetIsPassiveAndRespectsTextLocksAndVisibility() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "passive-text-hit-testing",
            image: NSImage.transparent(size: CGSize(width: 640, height: 480))
        ) { _ in }
        let backgroundID = try #require(viewModel.document.layers.first?.id)
        viewModel.textValue = "Double-click target"
        viewModel.addText(at: CGPoint(x: 120, y: 110))
        let textLayer = try #require(viewModel.document.selectedLayer)
        let hitPoint = CGPoint(x: textLayer.frame.midX, y: textLayer.frame.midY)
        viewModel.selectLayer(backgroundID)

        #expect(
            viewModel.moveToolDoubleClickTarget(at: hitPoint, hitTolerance: 0)
                == .editableText(textLayer.id)
        )
        #expect(viewModel.document.selectedLayerID == backgroundID)

        let textIndex = try #require(
            viewModel.document.layers.firstIndex(where: { $0.id == textLayer.id })
        )
        viewModel.document.layers[textIndex].locksPosition = true
        #expect(
            viewModel.moveToolDoubleClickTarget(at: hitPoint, hitTolerance: 0)
                == .editableText(textLayer.id)
        )
        #expect(viewModel.document.selectedLayerID == backgroundID)

        viewModel.document.layers[textIndex].locksPixels = true
        #expect(
            viewModel.moveToolDoubleClickTarget(at: hitPoint, hitTolerance: 0)
                == .layer(textLayer.id)
        )
        #expect(viewModel.document.selectedLayerID == backgroundID)

        viewModel.document.layers[textIndex].locksPixels = false
        viewModel.document.layers[textIndex].locksPosition = false
        viewModel.document.layers[textIndex].isVisible = false
        #expect(viewModel.moveToolDoubleClickTarget(at: hitPoint, hitTolerance: 0) == nil)
        #expect(viewModel.document.selectedLayerID == backgroundID)
        #expect(viewModel.moveToolDoubleClickTarget(at: CGPoint(x: 600, y: 460)) == nil)
    }
}
