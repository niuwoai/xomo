import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorExportFormatTests {
    @Test func exportScaleFormatterPreservesQuarterStepsWithoutTrailingZeros() {
        #expect(ImageEditorExportScaleFormatter.string(from: 1) == "1")
        #expect(ImageEditorExportScaleFormatter.string(from: 1.25) == "1.25")
        #expect(ImageEditorExportScaleFormatter.string(from: 1.5) == "1.5")
        #expect(ImageEditorExportScaleFormatter.string(from: 2.75) == "2.75")
    }

    @Test func previewAndExportPanelsAreNonClosingAndMutuallyExclusive() {
        let viewModel = ImageEditorViewModel(
            sourceName: "panel-routing",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }

        viewModel.openPreviewPanel()
        #expect(viewModel.isPreviewSheetPresented)
        #expect(!viewModel.isExportSheetPresented)

        viewModel.openExportPanel()
        #expect(!viewModel.isPreviewSheetPresented)
        #expect(viewModel.isExportSheetPresented)
    }

    @Test func previewBackdropInspectsTransparencyWithoutEditingTheDocument() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "preview-backdrop",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalLayerCount = viewModel.document.layers.count
        let originalHistory = viewModel.document.history
        let originalCanUndo = viewModel.canUndo

        #expect(ImageEditorPreviewBackdrop.allCases.map(\.rawValue) == [
            "checkerboard", "white", "black"
        ])
        #expect(ImageEditorPreviewBackdrop.checkerboard.solidColor == nil)
        let white = try #require(
            ImageEditorPreviewBackdrop.white.solidColor?.usingColorSpace(.deviceRGB)
        )
        let black = try #require(
            ImageEditorPreviewBackdrop.black.solidColor?.usingColorSpace(.deviceRGB)
        )
        #expect(white.redComponent == 1)
        #expect(white.greenComponent == 1)
        #expect(white.blueComponent == 1)
        #expect(black.redComponent == 0)
        #expect(black.greenComponent == 0)
        #expect(black.blueComponent == 0)

        viewModel.previewBackdrop = .black
        viewModel.openPreviewPanel()
        viewModel.isPreviewSheetPresented = false
        viewModel.openPreviewPanel()

        #expect(viewModel.previewBackdrop == .black)
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.canUndo == originalCanUndo)
    }

    @Test func previewZoomFitsViewportOrMagnifiesPixelDimensions() {
        let canvasSize = CGSize(width: 800, height: 400)
        let viewportSize = CGSize(width: 320, height: 240)

        #expect(ImageEditorPreviewZoomMode.allCases.map(\.rawValue) == [
            "fit", "actualPixels", "doublePixels"
        ])
        #expect(
            ImageEditorPreviewZoomMode.fit.displayedImageSize(
                canvasSize: canvasSize,
                viewportSize: viewportSize
            ) == CGSize(width: 320, height: 160)
        )
        #expect(
            ImageEditorPreviewZoomMode.actualPixels.displayedImageSize(
                canvasSize: canvasSize,
                viewportSize: viewportSize
            ) == canvasSize
        )
        #expect(
            ImageEditorPreviewZoomMode.doublePixels.displayedImageSize(
                canvasSize: canvasSize,
                viewportSize: viewportSize
            ) == CGSize(width: 1_600, height: 800)
        )
        #expect(!ImageEditorPreviewZoomMode.fit.usesScrollablePixelCanvas)
        #expect(ImageEditorPreviewZoomMode.actualPixels.usesScrollablePixelCanvas)
        #expect(ImageEditorPreviewZoomMode.doublePixels.usesScrollablePixelCanvas)
        #expect(
            ImageEditorPreviewZoomMode.fit.displayedImageSize(
                canvasSize: canvasSize,
                viewportSize: .zero
            ) == .zero
        )

        let viewModel = ImageEditorViewModel(
            sourceName: "preview-zoom",
            image: NSImage.transparent(size: canvasSize)
        ) { _ in }
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalHistory = viewModel.document.history
        let originalCanUndo = viewModel.canUndo

        #expect(viewModel.previewZoomMode == .fit)
        viewModel.previewZoomMode = .doublePixels
        viewModel.openPreviewPanel()
        viewModel.isPreviewSheetPresented = false
        viewModel.openPreviewPanel()

        #expect(viewModel.previewZoomMode == .doublePixels)
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.canUndo == originalCanUndo)
    }

    @Test func previewPixelInspectionMapsEveryZoomToCanvasCoordinates() throws {
        let canvasSize = CGSize(width: 80, height: 40)

        #expect(
            ImageEditorPreviewPixelSample.canvasPoint(
                from: CGPoint(x: 82, y: 42),
                displayedSize: CGSize(width: 320, height: 160),
                canvasSize: canvasSize
            ) == CGPoint(x: 20, y: 10)
        )
        #expect(
            ImageEditorPreviewPixelSample.canvasPoint(
                from: CGPoint(x: 41, y: 21),
                displayedSize: CGSize(width: 160, height: 80),
                canvasSize: canvasSize
            ) == CGPoint(x: 20, y: 10)
        )
        #expect(
            ImageEditorPreviewPixelSample.canvasPoint(
                from: CGPoint(x: -1, y: 4),
                displayedSize: canvasSize,
                canvasSize: canvasSize
            ) == nil
        )
        #expect(
            ImageEditorPreviewPixelSample.canvasPoint(
                from: CGPoint(x: canvasSize.width, y: 4),
                displayedSize: canvasSize,
                canvasSize: canvasSize
            ) == nil
        )

        let image = try #require(NSImage.rendered(size: canvasSize) { rect in
            NSColor(deviceRed: 1, green: 0.5, blue: 0, alpha: 0.25).setFill()
            rect.fill()
        })
        let sample = try #require(
            ImageEditorPreviewPixelSample.sample(
                image: image,
                location: CGPoint(x: 20.5, y: 10.5),
                displayedSize: canvasSize,
                canvasSize: canvasSize
            )
        )
        #expect(sample.point == CGPoint(x: 20, y: 10))
        #expect(sample.text.contains("X 20"))
        #expect(sample.text.contains("Y 10"))
        #expect(sample.text.contains("#FF800040"))
    }

    @Test func previewPixelInspectionFormatsClassicColorReadoutModes() {
        let sample = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 20, y: 10),
            color: NSColor(deviceRed: 1, green: 0.5, blue: 0, alpha: 0.25)
        )

        #expect(ImageEditorPreviewPixelReadoutMode.allCases.map(\.rawValue) == [
            "hexadecimalRGBA", "rgb", "hsb", "cmyk"
        ])
        #expect(sample.text(mode: .hexadecimalRGBA).contains("#FF800040"))
        #expect(sample.text(mode: .rgb).contains("R 255  G 128  B 0  A 25%"))
        #expect(sample.text(mode: .hsb).contains("H 30°  S 100%  B 100%  A 25%"))
        #expect(sample.text(mode: .cmyk).contains("C 0%  M 50%  Y 100%  K 0%  A 25%"))
        for mode in ImageEditorPreviewPixelReadoutMode.allCases {
            #expect(sample.text(mode: mode).contains("X 20"))
            #expect(sample.text(mode: mode).contains("Y 10"))
        }
    }

    @Test func previewPixelInspectionPinsFallbackAndMapsItsCanvasMarker() {
        let pinned = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 20, y: 10),
            color: .systemOrange
        )
        let live = ImageEditorPreviewPixelSample(
            point: CGPoint(x: 3, y: 4),
            color: .systemBlue
        )

        #expect(
            ImageEditorPreviewPixelSample.resolved(live: live, pinned: pinned)?.point == live.point
        )
        #expect(
            ImageEditorPreviewPixelSample.resolved(live: nil, pinned: pinned)?.point == pinned.point
        )
        #expect(ImageEditorPreviewPixelSample.resolved(live: nil, pinned: nil) == nil)
        #expect(
            pinned.displayedCenter(
                displayedSize: CGSize(width: 320, height: 160),
                canvasSize: CGSize(width: 80, height: 40)
            ) == CGPoint(x: 82, y: 42)
        )
        #expect(
            pinned.displayedCenter(
                displayedSize: CGSize(width: 160, height: 80),
                canvasSize: CGSize(width: 80, height: 40)
            ) == CGPoint(x: 41, y: 21)
        )
        #expect(
            pinned.displayedCenter(
                displayedSize: .zero,
                canvasSize: CGSize(width: 80, height: 40)
            ) == nil
        )
    }

    @Test func previewPixelInspectionAveragesNeighborhoodAndClipsCanvasEdges() throws {
        let canvasSize = CGSize(width: 3, height: 1)
        let image = try #require(NSImage.rendered(size: canvasSize) { _ in
            NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            CGRect(x: 0, y: 0, width: 1, height: 1).fill()
            NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1).setFill()
            CGRect(x: 1, y: 0, width: 1, height: 1).fill()
            NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1).setFill()
            CGRect(x: 2, y: 0, width: 1, height: 1).fill()
        })

        let point = try #require(
            ImageEditorPreviewPixelSample.sample(
                image: image,
                location: CGPoint(x: 1.5, y: 0.5),
                displayedSize: canvasSize,
                canvasSize: canvasSize,
                sampleSize: .point
            )
        )
        let average3 = try #require(
            ImageEditorPreviewPixelSample.sample(
                image: image,
                location: CGPoint(x: 1.5, y: 0.5),
                displayedSize: canvasSize,
                canvasSize: canvasSize,
                sampleSize: .average3
            )
        )
        let average5 = try #require(
            ImageEditorPreviewPixelSample.sample(
                image: image,
                location: CGPoint(x: 1.5, y: 0.5),
                displayedSize: canvasSize,
                canvasSize: canvasSize,
                sampleSize: .average5
            )
        )
        let edgeAverage = try #require(
            ImageEditorPreviewPixelSample.sample(
                image: image,
                location: CGPoint(x: 0.5, y: 0.5),
                displayedSize: canvasSize,
                canvasSize: canvasSize,
                sampleSize: .average3
            )
        )

        #expect(point.text.contains("#00FF00FF"))
        #expect(average3.text.contains("#555555FF"))
        #expect(average5.text.contains("#555555FF"))
        #expect(edgeAverage.text.contains("#808000FF"))
        #expect(ImageEditorPreviewPixelSampleSize.allCases.map(\.rawValue) == [1, 3, 5])
    }

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

    @Test func namedSliceScopeExportsTheNamedRectangularCanvasRegion() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "landing.png",
            image: NSImage.rendered(size: CGSize(width: 80, height: 60)) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
            }!
        ) { _ in }
        let slice = ImageEditorSlice(
            name: "Hero",
            frame: CGRect(x: 20, y: 10, width: 40, height: 30)
        )
        viewModel.document.slices = [slice]

        let settings = ImageEditorExportSettings(
            format: .png,
            scope: .slice,
            sliceID: slice.id
        )
        let data = try #require(viewModel.exportData(settings: settings))
        let exported = try #require(NSImage(data: data))

        #expect(exported.size == CGSize(width: 40, height: 30))
        #expect(exported.color(at: CGPoint(x: 20, y: 15))?.alphaComponent ?? 0 > 0.8)
        #expect(viewModel.exportFilenames(settings: settings) == ["Hero.png"])
    }

    @Test func hotspotHTMLExportEmbedsCanvasAndEscapesImageMapMetadata() throws {
        let image = NSImage.transparent(size: CGSize(width: 80, height: 60))
        let pngData = try #require(image.qingtuPNGData())
        let hotspot = ImageEditorHotspot(
            name: "Hero & Link",
            frame: CGRect(x: 10, y: 12, width: 30, height: 20),
            url: "https://example.com/a?x=1&y=2"
        )

        let data = ImageEditorHotspotHTMLExporter.data(
            canvasSize: image.size,
            pngData: pngData,
            hotspots: [hotspot],
            title: "Demo <Page>"
        )
        let html = try #require(String(data: data, encoding: .utf8))

        #expect(html.contains("usemap=\"#xomo-hotspots\""))
        #expect(html.contains("data:image/png;base64,"))
        #expect(html.contains("coords=\"10,12,40,32\""))
        #expect(html.contains("Hero &amp; Link"))
        #expect(html.contains("https://example.com/a?x=1&amp;y=2"))
        #expect(html.contains("<title>Demo &lt;Page&gt;</title>"))
    }

    @Test func selectedLayerExportScopeChoosesSingleLayerOrLayerSubtree() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "layers",
            image: NSImage.transparent(size: CGSize(width: 120, height: 80))
        ) { _ in }
        let baseLayerID = try #require(viewModel.document.selectedLayerID)

        #expect(viewModel.selectedLayersExportScope == .selectedLayer)

        viewModel.addLayer()
        let secondLayerID = try #require(viewModel.document.selectedLayerID)
        viewModel.selectLayer(baseLayerID, extendingSelection: true)

        #expect(viewModel.document.selectedLayerIDs == [baseLayerID, secondLayerID])
        #expect(viewModel.selectedLayersExportScope == .selectedLayers)
    }
}
