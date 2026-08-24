import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite(.serialized)
struct ImageEditorCanvasFileDropTests {
    @Test func policyAcceptsOneLocalPNGJPEGOrSVGAndRejectsAmbiguousDrops() throws {
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
        #expect(ImageEditorLayerFileImportPolicy.singleSupportedURL(from: [png]) == png)
        #expect(ImageEditorLayerFileImportPolicy.singleSupportedURL(from: []) == nil)
        #expect(ImageEditorLayerFileImportPolicy.singleSupportedURL(from: [png, jpg]) == nil)
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
}
