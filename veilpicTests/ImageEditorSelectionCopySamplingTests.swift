import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionCopySamplingTests {
    private let canvasSize = CGSize(width: 24, height: 20)
    private let selectedRect = CGRect(x: 8, y: 9, width: 1, height: 1)

    @Test(arguments: [false, true])
    func copyingFineSelectionToNewLayerKeepsCanvasPixelCoverage(raster: Bool) throws {
        let model = try fixture(raster: raster)
        let source = try #require(model.document.selectedLayer)
        let original = try model.projectData()
        let undoCount = model.undoStack.count
        #expect(model.canCopySelectionToNewLayer)

        model.copySelectionToNewLayer()

        #expect(model.document.layers.count == 2)
        let copy = try #require(model.document.selectedLayer)
        #expect(copy.id != source.id)
        #expect(copy.frame == selectedRect)
        #expect(copy.image.size == selectedRect.size)
        #expect(imageEditorRGBABytes(copy.image, width: 1, height: 1) == [255, 0, 0, 255])
        #expect(model.document.layers.first?.image === source.image)
        #expect(model.document.layers.first?.frame == source.frame)
        #expect(model.undoStack.count == undoCount + 1)
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        #expect(model.document.selectedLayer?.frame == selectedRect)
        let redone = try #require(model.document.selectedLayer?.image)
        #expect(imageEditorRGBABytes(redone, width: 1, height: 1) == [255, 0, 0, 255])
    }

    @Test(arguments: [false, true])
    func isolatedClipboardCopyAndInPlacePastePreservePixelsPositionAndUndo(raster: Bool) throws {
        let model = try fixture(raster: raster)
        let source = try #require(model.document.selectedLayer)
        let original = try model.projectData()
        let undoCount = model.undoStack.count
        let pasteboard = isolatedPasteboard()
        defer { pasteboard.clearContents() }
        #expect(model.copySelectionToClipboard(to: pasteboard))
        #expect(try model.projectData() == original)
        #expect(model.undoStack.count == undoCount)
        #expect(XomoClipboardLayerPayload.frame(from: pasteboard) == selectedRect)
        let copied = try #require(pasteboard.readImage())
        #expect(imageEditorRGBABytes(copied, width: 1, height: 1) == [255, 0, 0, 255])

        #expect(model.pasteClipboardInPlaceAsLayer(from: pasteboard))
        #expect(model.document.layers.count == 2)
        let pasted = try #require(model.document.selectedLayer)
        #expect(pasted.id != source.id)
        #expect(pasted.frame == selectedRect)
        #expect(imageEditorRGBABytes(pasted.image, width: 1, height: 1) == [255, 0, 0, 255])
        #expect(model.undoStack.count == undoCount + 1)
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        let redone = try #require(model.document.selectedLayer)
        #expect(redone.frame == selectedRect)
        #expect(imageEditorRGBABytes(redone.image, width: 1, height: 1) == [255, 0, 0, 255])
        let reopened = try fixture()
        try reopened.loadProjectData(model.projectData())
        #expect(reopened.document.selectedLayer?.frame == selectedRect)
        let reopenedImage = try #require(reopened.document.selectedLayer?.image)
        #expect(imageEditorRGBABytes(reopenedImage, width: 1, height: 1) == [255, 0, 0, 255])
    }

    @Test func copyPreservesSoftRasterCoverageInsteadOfReducingItsResolution() throws {
        let model = try fixture()
        var alpha = [UInt8](repeating: 0, count: 24 * 20)
        alpha[9 * 24 + 8] = 64
        alpha[9 * 24 + 9] = 192
        model.document.selection = .raster(
            mask: ImageEditorSelectionMask(width: 24, height: 20, alpha: alpha),
            bounds: CGRect(origin: .zero, size: canvasSize)
        )
        model.copySelectionToNewLayer()
        let copy = try #require(model.document.selectedLayer)
        #expect(copy.frame == CGRect(x: 8, y: 9, width: 2, height: 1))
        #expect(imageEditorRGBABytes(copy.image, width: 2, height: 1) == [64, 0, 0, 64, 192, 0, 0, 192])
    }

    @Test func activeLayerCopyAndCopyMergedUseTheirActualSources() throws {
        let model = try fixture(raster: true)
        var overlay = ImageEditorLayer.blank(name: "Overlay", size: CGSize(width: 4, height: 4))
        overlay.image = try #require(NSImage.rendered(size: overlay.image.size) { rect in
            NSColor.blue.setFill()
            rect.fill()
        })
        overlay.frame = try #require(model.document.selectedLayer?.frame)
        model.document.layers.append(overlay)
        let original = try model.projectData()
        let pasteboard = isolatedPasteboard()
        defer { pasteboard.clearContents() }
        #expect(model.copySelectionToClipboard(to: pasteboard))
        let activeCopy = try #require(pasteboard.readImage())
        #expect(imageEditorRGBABytes(activeCopy, width: 1, height: 1) == [255, 0, 0, 255])
        #expect(model.copyMergedToClipboard(to: pasteboard))
        let mergedCopy = try #require(pasteboard.readImage())
        #expect(imageEditorRGBABytes(mergedCopy, width: 1, height: 1) == [0, 0, 255, 255])
        #expect(XomoClipboardLayerPayload.frame(from: pasteboard) == selectedRect)
        #expect(try model.projectData() == original)
    }

    @Test func selectionAndMergedClipboardFramesAreWrittenWithTheirImages() throws {
        let model = try fixture(raster: true)
        let pasteboard = isolatedPasteboard()
        defer { pasteboard.clearContents() }

        #expect(model.copySelectionToClipboard(to: pasteboard))
        #expect(pasteboard.data(forType: .png) != nil)
        #expect(pasteboard.pasteboardItems?.contains {
            $0.data(forType: .png) != nil
                && $0.data(forType: XomoClipboardLayerPayload.pasteboardType) != nil
        } == true)
        #expect(XomoClipboardLayerPayload.frame(from: pasteboard) == selectedRect)

        #expect(model.copyMergedToClipboard(to: pasteboard))
        #expect(pasteboard.data(forType: .png) != nil)
        #expect(pasteboard.pasteboardItems?.contains {
            $0.data(forType: .png) != nil
                && $0.data(forType: XomoClipboardLayerPayload.pasteboardType) != nil
        } == true)
        #expect(XomoClipboardLayerPayload.frame(from: pasteboard) == selectedRect)
        #expect(model.canPasteClipboardImageInPlace(from: pasteboard))

        let originalLayerCount = model.document.layers.count
        #expect(model.pasteClipboardInPlaceAsLayer(from: pasteboard))
        #expect(model.document.layers.count == originalLayerCount + 1)
        #expect(model.document.selectedLayer?.frame == selectedRect)
    }

    @Test func copyRetainsFineVisibleLayerMaskAndFeatherTail() throws {
        let model = try fixture(raster: true)
        model.document.layers[0].mask = try #require(NSImage.rendered(size: CGSize(width: 12, height: 12)) { _ in
            NSColor.white.setFill()
            CGRect(x: 4, y: 6, width: 1, height: 1).fill()
        })
        model.copySelectionToNewLayer()
        let maskedCopy = try #require(model.document.selectedLayer)
        #expect(maskedCopy.frame == selectedRect)
        #expect(imageEditorRGBABytes(maskedCopy.image, width: 1, height: 1) == [255, 0, 0, 255])

        let featherModel = try fixture(raster: true)
        featherModel.feather = 1
        featherModel.copySelectionToNewLayer()
        let featherCopy = try #require(featherModel.document.selectedLayer)
        #expect(featherCopy.frame == selectedRect.insetBy(dx: -3, dy: -3))
        let pixels = try #require(imageEditorRGBABytes(featherCopy.image, width: 7, height: 7))
        #expect(pixels[(3 * 7 + 3) * 4 + 3] > 0)
        #expect(pixels[(3 * 7 + 2) * 4 + 3] > 0)
        #expect(pixels[(3 * 7 + 2) * 4 + 3] < 255)
    }

    @Test func emptyVisibleCopyAndOversizedCanvasLeaveClipboardAndHistoryAlone() throws {
        let model = try fixture(raster: true)
        model.document.layers[0].mask = .transparent(size: CGSize(width: 12, height: 12))
        let pasteboard = isolatedPasteboard()
        defer { pasteboard.clearContents() }
        #expect(pasteboard.setString("sentinel", forType: .string))
        let original = try model.projectData()
        #expect(!model.copySelectionToClipboard(to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "sentinel")
        #expect(try model.projectData() == original)
        #expect(model.undoStack.isEmpty)

        let oversized = try fixture()
        oversized.document.canvasSize = CGSize(width: 100_000, height: 100_000)
        let oversizedOriginal = try oversized.projectData()
        oversized.copySelectionToNewLayer()
        #expect(try oversized.projectData() == oversizedOriginal)
        #expect(oversized.undoStack.isEmpty)
    }

    private func isolatedPasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: .init("im.some.xomo.tests.selection-copy.\(UUID())"))
        pasteboard.clearContents()
        return pasteboard
    }

    private func fixture(raster: Bool = false) throws -> ImageEditorViewModel {
        let image = try #require(NSImage.rendered(size: CGSize(width: 4, height: 4)) { rect in
            NSColor.red.setFill()
            rect.fill()
        })
        var layer = ImageEditorLayer.blank(name: "Small source", size: image.size)
        layer.image = image
        layer.frame = CGRect(x: 4, y: 4, width: 12, height: 12)
        let model = ImageEditorViewModel(sourceName: "copy-sampling.png", image: .transparent(size: canvasSize)) { _ in }
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        if raster {
            var alpha = [UInt8](repeating: 0, count: 24 * 20)
            alpha[9 * 24 + 8] = 255
            model.document.selection = .raster(
                mask: ImageEditorSelectionMask(width: 24, height: 20, alpha: alpha),
                bounds: CGRect(origin: .zero, size: canvasSize)
            )
        } else {
            model.document.selection = .rectangle(selectedRect)
        }
        return model
    }
}
