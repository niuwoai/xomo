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
        viewModel.toggleQuickMaskMode()
        #expect(viewModel.isQuickMaskMode)

        viewModel.createCanvas(from: draft)

        #expect(viewModel.document.canvasSize == CGSize(width: 390, height: 844))
        #expect(viewModel.document.isGridVisible)
        #expect(viewModel.document.isGridSnappingEnabled)
        #expect(viewModel.document.gridSpacing == 8)
        #expect(viewModel.zoom == 1)
        #expect(viewModel.document.layers.count == 2)
        #expect(viewModel.exportSettings.scale == 3)
        #expect(viewModel.document.designCanvasMetadata?.preset == .phonePortrait)
        #expect(viewModel.document.designCanvasMetadata?.exportScale == 3)
        #expect(!viewModel.isQuickMaskMode)
        #expect(viewModel.document.selection == nil)
        #expect(viewModel.quickMaskOverlayImage == nil)
    }

    @MainActor
    @Test func creatingCanvasFromClipboardUsesImageDimensionsAndResetsDocumentState() throws {
        let original = NSImage.transparent(size: CGSize(width: 20, height: 20))
        let clipboardImage = NSImage.rendered(size: CGSize(width: 48, height: 32)) { rect in
            NSColor.systemOrange.setFill()
            rect.fill()
        }!
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("xomo-tests.new-canvas-clipboard"))
        pasteboard.clearContents()
        #expect(pasteboard.writeObjects([clipboardImage]))
        defer { pasteboard.clearContents() }

        let viewModel = ImageEditorViewModel(sourceName: "source", image: original) { _ in }
        viewModel.zoom = 2

        viewModel.createCanvasFromClipboard(from: pasteboard)

        #expect(viewModel.document.sourceName == L10n.text("source.clipboard"))
        #expect(viewModel.document.canvasSize == CGSize(width: 48, height: 32))
        #expect(viewModel.document.layers.count == 2)
        #expect(viewModel.document.selectedLayer?.name == L10n.text("imageEditor.layer.edit"))
        #expect(!viewModel.document.isGridVisible)
        #expect(viewModel.document.designCanvasMetadata == nil)
        #expect(viewModel.zoom == 1)
        #expect(!viewModel.canUndo)
        #expect(viewModel.document.history.count == 1)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.clipboardCanvasCreated", 48, 32))
    }

    @MainActor
    @Test func projectRoundTripPreservesDesignCanvasMetadata() throws {
        let image = NSImage.transparent(size: CGSize(width: 20, height: 20))
        let viewModel = ImageEditorViewModel(sourceName: "source", image: image) { _ in }
        var draft = XomoCanvasDraft(preset: .socialBanner)
        draft.background = .transparent
        viewModel.createCanvas(from: draft)

        let project = try ImageEditorProjectDocument(document: viewModel.document)
        let restored = try project.restoredDocument()

        #expect(restored.canvasSize == CGSize(width: 1500, height: 500))
        #expect(restored.isGridVisible)
        #expect(restored.isGridSnappingEnabled)
        #expect(restored.gridSpacing == 8)
        #expect(restored.designCanvasMetadata?.preset == .socialBanner)
        #expect(restored.designCanvasMetadata?.background == .transparent)
        #expect(restored.designCanvasMetadata?.exportScale == 1)
    }
}
