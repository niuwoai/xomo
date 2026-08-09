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
}
