import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorExportFormatTests {
    @Test func pureVectorCanvasExportsEditableSVG() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "vector-canvas",
            image: NSImage.transparent(size: CGSize(width: 320, height: 180))
        ) { _ in }
        viewModel.document.layers.append(
            .shape(
                name: "Card",
                frame: CGRect(x: 24, y: 28, width: 180, height: 80),
                content: ImageEditorShapeContent(
                    kind: .rectangle,
                    fillColor: .systemBlue,
                    fillOpacity: 1,
                    strokeColor: .white,
                    strokeWidth: 2,
                    strokeOpacity: 1
                )
            )
        )
        viewModel.document.layers.append(
            .text(
                name: "Title",
                origin: CGPoint(x: 40, y: 54),
                content: ImageEditorTextContent(
                    text: "Xomo",
                    color: .white,
                    fontSize: 20,
                    point: .zero,
                    isBold: true
                )
            )
        )

        #expect(viewModel.canExportSVG)
        let svg = try #require(viewModel.exportData(settings: ImageEditorExportSettings(format: .svg)))
        let source = try #require(String(data: svg, encoding: .utf8))
        #expect(source.contains("<svg"))
        #expect(source.contains("<rect"))
        #expect(source.contains("<text"))
        #expect(!source.contains("<image"))
    }

    @Test func mixedCanvasExportsPDFAndRejectsSVG() throws {
        let rasterImage = try #require(
            NSImage.rendered(size: CGSize(width: 96, height: 64)) { rect in
                NSColor.systemOrange.setFill()
                rect.fill()
            }
        )
        let viewModel = ImageEditorViewModel(sourceName: "mixed-canvas", image: rasterImage) { _ in }

        #expect(!viewModel.canExportSVG)
        #expect(viewModel.exportData(settings: ImageEditorExportSettings(format: .svg)) == nil)

        let pdf = try #require(viewModel.exportData(settings: ImageEditorExportSettings(format: .pdf)))
        #expect(String(data: pdf.prefix(4), encoding: .ascii) == "%PDF")
        let renderedPDF = try #require(NSImage(data: pdf))
        #expect(renderedPDF.size == rasterImage.size)
        #expect(renderedPDF.nonTransparentPixelBounds() != nil)
    }
}
