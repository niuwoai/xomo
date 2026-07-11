import AppKit
import Testing
@testable import musepic

struct XomoCanvasPresetTests {
    @Test func presetCatalogContainsTheFixedTwelveCanvasSizes() {
        #expect(XomoCanvasPreset.allCases.count == 12)
        #expect(XomoCanvasPreset.phonePortrait.logicalSize == CGSize(width: 390, height: 844))
        #expect(XomoCanvasPreset.webDesktop.logicalSize == CGSize(width: 1440, height: 1024))
        #expect(XomoCanvasPreset.socialBanner.logicalSize == CGSize(width: 1500, height: 500))
        #expect(XomoCanvasPreset.phonePortrait.defaultExportScale == 3)
        #expect(XomoCanvasPreset.webWide.defaultExportScale == 1)
    }

    @Test func draftAppliesPresetAndClampsCustomDimensions() {
        var draft = XomoCanvasDraft(preset: .phonePortrait)
        draft.apply(.webLaptop)

        #expect(draft.canvasSize == CGSize(width: 1280, height: 800))
        #expect(draft.clampedExportScale == 1)

        draft.width = 1
        draft.height = 100_000
        draft.exportScale = 8

        #expect(draft.canvasSize == CGSize(width: 16, height: 8192))
        #expect(draft.clampedExportScale == 3)
    }

    @MainActor
    @Test func creatingCanvasUsesEightPointGridAndResetsToRequestedSize() {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        var draft = XomoCanvasDraft(preset: .phonePortrait)
        draft.background = .transparent

        viewModel.createCanvas(from: draft)

        #expect(viewModel.document.canvasSize == CGSize(width: 390, height: 844))
        #expect(viewModel.document.isGridVisible)
        #expect(viewModel.document.isGridSnappingEnabled)
        #expect(viewModel.document.gridSpacing == 8)
        #expect(viewModel.zoom == 1)
        #expect(viewModel.document.layers.count == 2)
    }
}
