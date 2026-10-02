import AppKit
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorSelectionClearSamplingTests {
    private let canvasSize = CGSize(width: 24, height: 20)
    private let selectedRect = CGRect(x: 8, y: 9, width: 1, height: 1)

    @Test(arguments: [false, true])
    func fineClearOnlyRemovesSelectedCanvasPixelAndRoundTrips(raster: Bool) throws {
        let model = try fixture(raster: raster)
        let original = try model.projectData()
        var expected = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20))
        let undoCount = model.undoStack.count
        let historyCount = model.document.history.count
        expected.replaceSubrange((9 * 24 + 8) * 4..<(9 * 24 + 9) * 4, with: [0, 0, 0, 0])

        model.clearSelectionPixels()

        #expect(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20) == expected)
        #expect(model.undoStack.count == undoCount + 1)
        #expect(model.document.history.count == historyCount + 1)
        #expect(model.document.selection == (raster ? rasterSelection() : .rectangle(selectedRect)))
        let cleared = try model.projectData()
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        #expect(try model.projectData() == cleared)
        let reopened = try fixture()
        try reopened.loadProjectData(cleared)
        #expect(imageEditorRGBABytes(reopened.document.compositedImage, width: 24, height: 20) == expected)
    }

    @Test func softClearPreservesCoverageComplementAndUnselectedColor() throws {
        let model = try fixture()
        model.document.selection = rasterSelection(coverage: [64, 192])
        var expected = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20))
        expected.replaceSubrange((9 * 24 + 8) * 4..<(9 * 24 + 10) * 4,
                                 with: [191, 0, 0, 191, 63, 0, 0, 63])
        model.clearSelectionPixels()
        #expect(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20) == expected)
    }

    @Test func featheredClearMatchesIndependentCanvasCoverage() throws {
        let model = try fixture()
        model.feather = 1
        let board = NSPasteboard(name: .init("im.some.xomo.tests.clear.\(UUID())"))
        defer { board.clearContents() }
        #expect(model.copySelectionToClipboard(to: board))
        let copied = try #require(board.readImage())
        let coverage = try #require(imageEditorRGBABytes(copied, width: 7, height: 7))
        var expected = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20))
        for y in 0..<7 {
            for x in 0..<7 {
                let complement = UInt8.max - coverage[(y * 7 + x) * 4 + 3]
                let offset = ((y + 6) * 24 + x + 5) * 4
                expected.replaceSubrange(offset..<(offset + 4), with: [complement, 0, 0, complement])
            }
        }
        #expect(coverage[(3 * 7 + 2) * 4 + 3] > 0)
        model.clearSelectionPixels()
        #expect(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20) == expected)
    }

    @Test func multiLayerClearIsOneTransactionAndSkipsLocksAndTransparentNoOps() throws {
        let model = try fixture()
        let source = try #require(model.document.selectedLayer)
        var second = source
        second.id = UUID()
        var pixelLocked = source
        pixelLocked.id = UUID()
        pixelLocked.locksPixels = true
        var alphaLocked = source
        alphaLocked.id = UUID()
        alphaLocked.locksTransparentPixels = true
        var empty = source
        empty.id = UUID()
        empty.image = .transparent(size: source.image.size)
        model.document.layers = [source, second, pixelLocked, alphaLocked, empty]
        model.document.selectedLayerIDs = Set(model.document.layers.map(\.id))
        let original = try model.projectData()
        let undoCount = model.undoStack.count
        let historyCount = model.document.history.count

        model.clearSelectionPixels()

        #expect(model.undoStack.count == undoCount + 1)
        #expect(model.document.history.count == historyCount + 1)
        #expect(model.statusText == L10n.format("imageEditor.status.selectionPixelsClearedSelected", 2))
        for index in 0..<2 {
            #expect(model.document.layers[index].image.size == CGSize(width: 12, height: 12))
            let bytes = try #require(imageEditorRGBABytes(model.document.layers[index].image, width: 12, height: 12))
            #expect(Array(bytes[(5 * 12 + 4) * 4..<(5 * 12 + 5) * 4]) == [0, 0, 0, 0])
        }
        for index in 2..<5 {
            #expect(model.document.layers[index].image.size == CGSize(width: 4, height: 4))
            #expect(model.document.layers[index].image.qingtuPNGData() == [pixelLocked, alphaLocked, empty][index - 2].image.qingtuPNGData())
        }
        let cleared = try model.projectData()
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        #expect(try model.projectData() == cleared)
    }

    @Test(arguments: [true, false])
    func clearKeepsMaskLinksStyleUnitsAndEditableSmartFilter(linked: Bool) throws {
        let model = try fixture()
        let index = try #require(model.document.selectedLayerIndex)
        var layer = model.document.layers[index]
        layer.isMaskLinked = linked
        layer.mask = try #require(NSImage.rendered(size: CGSize(width: 12, height: 12)) { rect in
            NSColor.white.setFill()
            rect.fill()
        })
        layer.style.strokeEnabled = true
        layer.style.shadowEnabled = true
        layer.style.strokeWidth = 2
        layer.style.shadowBlur = 1
        layer.style.shadowOffset = CGSize(width: 1, height: -2)
        let filter = ImageEditorSmartFilter(kind: .gaussianBlur, intensity: 0.3,
                                            settings: ImageEditorFilterSettings(gaussianBlurRadius: 2))
        layer.smartFilters = [filter]
        model.document.layers[index] = layer
        let original = try model.projectData()

        model.clearSelectionPixels()

        let output = model.document.layers[index]
        #expect(output.id == layer.id)
        #expect(output.frame == layer.frame)
        #expect(output.isMaskLinked == linked)
        #expect(output.mask === layer.mask)
        #expect(output.style.strokeEnabled)
        #expect(output.style.shadowEnabled)
        #expect(output.style.strokeWidth == 6)
        #expect(output.style.shadowBlur == 3)
        #expect(output.style.shadowOffset == CGSize(width: 3, height: -6))
        #expect(output.smartFilters.first?.id == filter.id)
        #expect(output.smartFilters.first?.settings == filter.settings)
        #expect(output.smartFilters.first?.pixelSamplingScale == 3)
        let reopened = try fixture()
        try reopened.loadProjectData(model.projectData())
        #expect(reopened.document.layers[index].smartFilters == output.smartFilters)
        #expect(imageEditorRGBABytes(reopened.document.compositedImage, width: 24, height: 20)
                == imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20))
        model.undo()
        #expect(try model.projectData() == original)
    }

    @Test func failedPromotionRejectsEntireMultiLayerTransaction() throws {
        let model = try fixture()
        let source = try #require(model.document.selectedLayer)
        var oversized = source
        oversized.id = UUID()
        oversized.frame = CGRect(x: 0, y: 0, width: 100_000, height: 100_000)
        model.document.layers.append(oversized)
        model.document.selectedLayerIDs = [source.id, oversized.id]
        let original = try model.projectData()
        let undoCount = model.undoStack.count
        let historyCount = model.document.history.count

        model.clearSelectionPixels()

        #expect(try model.projectData() == original)
        #expect(model.undoStack.count == undoCount)
        #expect(model.document.history.count == historyCount)
        #expect(model.statusText == L10n.text("imageEditor.status.operationFailed"))
    }

    @Test func transparentNoOpKeepsOriginalBackingAndRedoTransaction() throws {
        let model = try fixture()
        let original = try model.projectData()
        model.clearSelectionPixels()
        let cleared = try model.projectData()
        model.undo()
        #expect(try model.projectData() == original)
        let index = try #require(model.document.selectedLayerIndex)
        model.document.layers[index].image = .transparent(size: CGSize(width: 4, height: 4))
        let noOpData = try model.projectData()
        let undoCount = model.undoStack.count
        let redoCount = model.redoStack.count
        model.clearSelectionPixels()
        #expect(try model.projectData() == noOpData)
        #expect(model.document.layers[index].image.size == CGSize(width: 4, height: 4))
        #expect(model.undoStack.count == undoCount)
        #expect(model.redoStack.count == redoCount)
        #expect(model.statusText == L10n.text("imageEditor.status.selectionEmpty"))
        model.redo()
        #expect(try model.projectData() == cleared)
    }

    @Test func selectionClearPasteWorkflowSurvivesHistoryReloadAndPNGExport() throws {
        let model = try fixture()
        model.document.selection = nil
        #expect(model.createRectSelection(from: selectedRect.origin,
                                          to: CGPoint(x: selectedRect.maxX, y: selectedRect.maxY)))
        #expect(model.document.selection == .rectangle(selectedRect))
        let original = try model.projectData()
        let expected = try #require(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20))
        let board = NSPasteboard(name: .init("im.some.xomo.tests.clear-workflow.\(UUID())"))
        defer { board.clearContents() }
        #expect(model.copySelectionToClipboard(to: board))
        #expect(try model.projectData() == original)
        let undoCount = model.undoStack.count
        model.clearSelectionPixels()
        #expect(model.pasteClipboardInPlaceAsLayer(from: board))
        #expect(model.undoStack.count == undoCount + 2)
        #expect(model.document.layers.count == 2)
        #expect(imageEditorRGBABytes(model.document.compositedImage, width: 24, height: 20) == expected)
        let edited = try model.projectData()
        model.undo()
        model.undo()
        #expect(try model.projectData() == original)
        model.redo()
        model.redo()
        #expect(try model.projectData() == edited)
        let reopened = try fixture()
        try reopened.loadProjectData(edited)
        let png = try #require(reopened.exportData(settings: .init(format: .png, scope: .composited)))
        let exported = try #require(NSImage(data: png))
        #expect(exported.size == canvasSize)
        #expect(imageEditorRGBABytes(exported, width: 24, height: 20) == expected)
    }

    private func rasterSelection(coverage: [UInt8] = [255]) -> ImageEditorSelection {
        var alpha = [UInt8](repeating: 0, count: 24 * 20)
        for (index, value) in coverage.enumerated() { alpha[9 * 24 + 8 + index] = value }
        return .raster(mask: ImageEditorSelectionMask(width: 24, height: 20, alpha: alpha),
                       bounds: CGRect(origin: .zero, size: canvasSize))
    }

    private func fixture(raster: Bool = false) throws -> ImageEditorViewModel {
        let image = try #require(NSImage.rendered(size: CGSize(width: 4, height: 4)) { rect in
            NSColor.red.setFill()
            rect.fill()
            NSColor.blue.setFill()
            CGRect(x: 3, y: 0, width: 1, height: 4).fill()
        })
        var layer = ImageEditorLayer.blank(name: "Clear source", size: image.size)
        layer.image = image
        layer.frame = CGRect(x: 4, y: 4, width: 12, height: 12)
        let model = ImageEditorViewModel(sourceName: "clear-sampling.png", image: .transparent(size: canvasSize)) { _ in }
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        model.document.selection = raster ? rasterSelection() : .rectangle(selectedRect)
        return model
    }
}
