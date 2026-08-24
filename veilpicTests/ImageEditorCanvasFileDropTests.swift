import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorCanvasFileDropTests {
    @Test func policyAcceptsLocalPNGJPEGOrSVGBatchesAndRejectsInvalidMembers() throws {
        let png = URL(fileURLWithPath: "/tmp/Poster.PNG")
        let jpg = URL(fileURLWithPath: "/tmp/photo.JpG")
        let jpeg = URL(fileURLWithPath: "/tmp/photo.jpeg")
        let svg = URL(fileURLWithPath: "/tmp/icon.SVG")
        let remote = try #require(URL(string: "https://example.com/icon.png"))

        #expect(ImageEditorLayerFileImportPolicy.kind(for: png) == .rasterImage)
        #expect(ImageEditorLayerFileImportPolicy.kind(for: jpg) == .rasterImage)
        #expect(ImageEditorLayerFileImportPolicy.kind(for: jpeg) == .rasterImage)
        #expect(ImageEditorLayerFileImportPolicy.kind(for: svg) == .editableSVG)
        #expect(ImageEditorLayerFileImportPolicy.kind(for: URL(fileURLWithPath: "/tmp/file.psd")) == nil)
        #expect(ImageEditorLayerFileImportPolicy.kind(for: remote) == nil)
        #expect(ImageEditorLayerFileImportPolicy.supportedURLs(from: [png]) == [png])
        #expect(ImageEditorLayerFileImportPolicy.supportedURLs(from: [png, jpg, svg]) == [png, jpg, svg])
        #expect(ImageEditorLayerFileImportPolicy.supportedURLs(from: []) == nil)
        #expect(ImageEditorLayerFileImportPolicy.supportedURLs(from: [png, remote]) == nil)
    }

    @Test func droppingRasterImageCreatesSelectedLayerAtPointerInOneUndoStep() throws {
        let viewModel = makeViewModel()
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let historyCount = viewModel.document.history.count
        let url = temporaryURL(extension: "png")
        defer { try? FileManager.default.removeItem(at: url) }
        let image = try #require(NSImage.rendered(size: CGSize(width: 24, height: 16)) { rect in
            NSColor.systemPink.setFill()
            rect.fill()
        })
        try #require(image.qingtuPNGData()).write(to: url, options: .atomic)

        #expect(viewModel.importLayerFile(url, centeredAt: CGPoint(x: 70, y: 55)))
        let imported = try #require(viewModel.document.selectedLayer)

        #expect(viewModel.document.selectedLayerIDs == [imported.id])
        let expectedName = L10n.format(
            "imageEditor.layer.importedName",
            url.deletingPathExtension().lastPathComponent
        )
        #expect(imported.name == expectedName)
        #expect(imported.frame.midX == 70)
        #expect(imported.frame.midY == 55)
        #expect(imported.frame.size == imported.image.size)
        #expect(viewModel.document.history.count == historyCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerImport"))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
    }

    @Test func droppingSVGCreatesEditableShapeAtPointerAndInvalidFilesStayAtomic() throws {
        let viewModel = makeViewModel()
        let historyCount = viewModel.document.history.count
        let svgURL = temporaryURL(extension: "svg")
        let textURL = temporaryURL(extension: "txt")
        let corruptPNGURL = temporaryURL(extension: "png")
        let directoryURL = temporaryURL(extension: "png")
        defer {
            try? FileManager.default.removeItem(at: svgURL)
            try? FileManager.default.removeItem(at: textURL)
            try? FileManager.default.removeItem(at: corruptPNGURL)
            try? FileManager.default.removeItem(at: directoryURL)
        }
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="40" height="20">
          <rect x="0" y="0" width="40" height="20" fill="#336699" />
        </svg>
        """
        try Data(svg.utf8).write(to: svgURL, options: .atomic)
        try Data("not an image".utf8).write(to: textURL, options: .atomic)
        try Data("not a png".utf8).write(to: corruptPNGURL, options: .atomic)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)

        #expect(viewModel.importLayerFile(svgURL, centeredAt: CGPoint(x: 120, y: 80)))
        let imported = try #require(viewModel.document.selectedLayer)
        #expect(imported.shapeContent != nil)
        #expect(imported.frame.midX == 120)
        #expect(imported.frame.midY == 80)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.editableSVGImport"))

        let layerIDsAfterSVG = viewModel.document.layers.map(\.id)
        let historyAfterSVG = viewModel.document.history.count
        #expect(!viewModel.importLayerFile(textURL, centeredAt: CGPoint(x: 40, y: 40)))
        #expect(!viewModel.importLayerFile(corruptPNGURL, centeredAt: CGPoint(x: 40, y: 40)))
        #expect(!viewModel.importLayerFile(directoryURL, centeredAt: CGPoint(x: 40, y: 40)))
        #expect(viewModel.document.layers.map(\.id) == layerIDsAfterSVG)
        #expect(viewModel.document.history.count == historyAfterSVG)
        #expect(historyAfterSVG == historyCount + 1)
    }

    @Test func placementUsesExactDropCenterWithoutChangingSourceDimensions() {
        #expect(ImageEditorLayerFileImportPolicy.frame(
            for: CGSize(width: 30, height: 18),
            centeredAt: CGPoint(x: 4, y: 7)
        ) == CGRect(x: -11, y: -2, width: 30, height: 18))
        #expect(ImageEditorLayerFileImportPolicy.frame(
            for: .zero,
            centeredAt: CGPoint(x: 4, y: 7)
        ) == CGRect(x: 3.5, y: 6.5, width: 1, height: 1))
    }

    @Test func droppingMixedFilesCreatesSpacedSelectedLayersInOneUndoStep() throws {
        let viewModel = makeViewModel()
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalHistoryCount = viewModel.document.history.count
        let firstURL = temporaryURL(extension: "png")
        let secondURL = temporaryURL(extension: "jpg")
        let svgURL = temporaryURL(extension: "svg")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
            try? FileManager.default.removeItem(at: svgURL)
        }
        try writeRasterImage(size: CGSize(width: 20, height: 10), to: firstURL, color: .systemRed)
        try writeRasterImage(size: CGSize(width: 30, height: 20), to: secondURL, color: .systemBlue)
        try Data(
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="40" height="10">
              <rect width="40" height="10" fill="#33aa66" />
            </svg>
            """.utf8
        ).write(to: svgURL, options: .atomic)

        #expect(viewModel.importLayerFiles(
            [firstURL, secondURL, svgURL],
            centeredAt: CGPoint(x: 100, y: 80)
        ))
        let imported = Array(viewModel.document.layers.suffix(3))
        #expect(imported.map(\.frame) == [
            CGRect(x: 39, y: 75, width: 20, height: 10),
            CGRect(x: 75, y: 70, width: 30, height: 20),
            CGRect(x: 121, y: 75, width: 40, height: 10)
        ])
        #expect(imported[0].image.size == CGSize(width: 20, height: 10))
        #expect(imported[1].image.size == CGSize(width: 30, height: 20))
        #expect(imported[2].shapeContent != nil)
        #expect(viewModel.document.selectedLayerIDs == Set(imported.map(\.id)))
        #expect(viewModel.document.selectedLayerID == imported.last?.id)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.layerBatchImport"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.layersImported", 3))

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
    }

    @Test func menuBatchImportCentersTheWholeRowOnCanvasInOneUndoStep() throws {
        let viewModel = makeViewModel()
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalHistoryCount = viewModel.document.history.count
        let firstURL = temporaryURL(extension: "png")
        let secondURL = temporaryURL(extension: "jpg")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        try writeRasterImage(size: CGSize(width: 20, height: 10), to: firstURL, color: .systemOrange)
        try writeRasterImage(size: CGSize(width: 30, height: 20), to: secondURL, color: .systemGreen)

        #expect(viewModel.importLayerFiles([firstURL, secondURL]))
        let imported = Array(viewModel.document.layers.suffix(2))
        #expect(imported.map(\.frame) == [
            CGRect(x: 67, y: 75, width: 20, height: 10),
            CGRect(x: 103, y: 70, width: 30, height: 20)
        ])
        #expect(viewModel.document.selectedLayerIDs == Set(imported.map(\.id)))
        #expect(viewModel.document.selectedLayerID == imported.last?.id)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
    }

    @Test func corruptMemberRejectsTheWholeBatchAndPreservesExistingRedo() throws {
        let viewModel = makeViewModel()
        viewModel.addLayer()
        viewModel.undo()
        #expect(viewModel.canRedo)
        let layerIDsBeforeDrop = viewModel.document.layers.map(\.id)
        let historyBeforeDrop = viewModel.document.history
        let validURL = temporaryURL(extension: "png")
        let corruptURL = temporaryURL(extension: "svg")
        defer {
            try? FileManager.default.removeItem(at: validURL)
            try? FileManager.default.removeItem(at: corruptURL)
        }
        try writeRasterImage(size: CGSize(width: 12, height: 8), to: validURL, color: .systemPurple)
        try Data("<svg><path d='broken'/></svg>".utf8).write(to: corruptURL, options: .atomic)

        #expect(!viewModel.importLayerFiles(
            [validURL, corruptURL],
            centeredAt: CGPoint(x: 50, y: 40)
        ))
        #expect(viewModel.document.layers.map(\.id) == layerIDsBeforeDrop)
        #expect(viewModel.document.history == historyBeforeDrop)
        #expect(viewModel.canRedo)

        viewModel.redo()
        #expect(viewModel.document.layers.count == layerIDsBeforeDrop.count + 1)
    }

    @Test func batchPlacementCentersTheWholeRowAndKeepsInputOrder() {
        #expect(ImageEditorLayerFileImportPolicy.batchFrames(
            for: [
                CGSize(width: 20, height: 10),
                CGSize(width: 30, height: 20),
                CGSize(width: 40, height: 10)
            ],
            centeredAt: CGPoint(x: 100, y: 80)
        ) == [
            CGRect(x: 39, y: 75, width: 20, height: 10),
            CGRect(x: 75, y: 70, width: 30, height: 20),
            CGRect(x: 121, y: 75, width: 40, height: 10)
        ])
    }

    private func makeViewModel() -> ImageEditorViewModel {
        ImageEditorViewModel(
            sourceName: "drop-canvas.png",
            image: NSImage.transparent(size: CGSize(width: 200, height: 160))
        ) { _ in }
    }

    private func temporaryURL(extension pathExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("xomo-canvas-drop-\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
    }

    private func writeRasterImage(size: CGSize, to url: URL, color: NSColor) throws {
        let image = try #require(NSImage.rendered(size: size) { rect in
            color.setFill()
            rect.fill()
        })
        let data: Data
        if url.pathExtension.lowercased() == "jpg" {
            let representation = try #require(image.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: representation))
            data = try #require(bitmap.representation(using: .jpeg, properties: [:]))
        } else {
            data = try #require(image.qingtuPNGData())
        }
        try data.write(to: url, options: .atomic)
    }
}
