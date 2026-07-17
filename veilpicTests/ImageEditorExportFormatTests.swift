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

    @Test func exportNamingRulesSupportBatchScaleVariants() {
        let viewModel = ImageEditorViewModel(
            sourceName: "landing.png",
            image: NSImage.transparent(size: CGSize(width: 120, height: 80))
        ) { _ in }
        let batchSettings = ImageEditorExportSettings(
            format: .png,
            scope: .composited,
            scale: 1,
            batchScales: [2, 3],
            namingRule: .sourceScopeAndScale
        )

        #expect(viewModel.exportFilenames(settings: batchSettings) == [
            "landing-edited@1x.png",
            "landing-edited@2x.png",
            "landing-edited@3x.png"
        ])

        let sourceOnly = ImageEditorExportSettings(
            format: .png,
            scope: .composited,
            scale: 1,
            namingRule: .sourceName
        )
        #expect(viewModel.exportFilenames(settings: sourceOnly) == ["landing.png"])

        let pdfSettings = ImageEditorExportSettings(
            format: .pdf,
            scope: .composited,
            scale: 1,
            batchScales: [2, 3]
        )
        #expect(viewModel.exportFilenames(settings: pdfSettings) == ["landing-edited.pdf"])
    }

    @Test func selectionScopeExportsASelectionSliceBoundedByTheSelectionAndPreservesTransparency() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "landing.png",
            image: NSImage.rendered(size: CGSize(width: 80, height: 60)) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
            }!
        ) { _ in }
        viewModel.document.selection = try #require(
            ImageEditorSelection.ellipse(CGRect(x: 20, y: 10, width: 40, height: 30))
        )

        #expect(viewModel.canExportSelection)
        let settings = ImageEditorExportSettings(format: .png, scope: .selection)
        let data = try #require(viewModel.exportData(settings: settings))
        let exported = try #require(NSImage(data: data))
        let center = try #require(exported.color(at: CGPoint(x: 20, y: 15))?.usingColorSpace(.deviceRGB))
        let corner = try #require(exported.color(at: CGPoint(x: 1, y: 1))?.usingColorSpace(.deviceRGB))

        #expect(exported.size == CGSize(width: 40, height: 30))
        #expect(center.blueComponent > 0.7)
        #expect(center.alphaComponent > 0.8)
        #expect(corner.alphaComponent < 0.1)
        #expect(viewModel.exportFilenames(settings: settings) == ["landing-selection.png"])
    }
}
