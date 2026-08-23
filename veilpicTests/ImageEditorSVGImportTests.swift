import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorSVGImportTests {
    @Test func singleCompoundPathImportsEditableGeometryAndPresentation() throws {
        let data = Data(
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="160" height="120">
              <g opacity="0.5" fill="#33669980" fill-opacity="0.8"
                 stroke="rgb(240, 80, 32)" stroke-opacity="0.75"
                 stroke-width="4px" stroke-linecap="square" stroke-linejoin="bevel"
                 stroke-miterlimit="7" stroke-dasharray="5" stroke-dashoffset="-2">
                <path fill-rule="evenodd"
                      d="M 10 20 C 30 0 70 0 90 20 L 110 100 Z M 40 40 L 70 40 L 55 70 Z" />
              </g>
            </svg>
            """.utf8
        )

        let imported = try #require(XomoEditableSVGPathImporter.parse(data))
        let content = imported.content
        let fill = try #require(content.fillColor.usingColorSpace(.deviceRGB))
        let stroke = try #require(content.strokeColor.usingColorSpace(.deviceRGB))

        #expect(content.kind == .path)
        #expect(content.isPathClosed)
        #expect(content.allEditablePathSubpaths.count == 2)
        #expect(content.editablePathAnchors.first?.point == CGPoint(x: 2, y: 22))
        #expect(content.editablePathAnchors.first?.outControl == CGPoint(x: 22, y: 2))
        #expect(imported.size == CGSize(width: 104, height: 104))
        #expect(abs(fill.redComponent - 0.2) < 0.001)
        #expect(abs(fill.greenComponent - 0.4) < 0.001)
        #expect(abs(fill.blueComponent - 0.6) < 0.001)
        #expect(abs(content.fillOpacity - (128.0 / 255.0 * 0.8 * 0.5)) < 0.001)
        #expect(abs(stroke.redComponent - (240.0 / 255.0)) < 0.001)
        #expect(abs(content.strokeOpacity - 0.375) < 0.001)
        #expect(content.strokeWidth == 4)
        #expect(content.strokeCap == .square)
        #expect(content.strokeJoin == .bevel)
        #expect(content.strokeMiterLimit == 7)
        #expect(content.strokeDashPattern == [5, 5])
        #expect(content.strokeDashOffset == -2)
    }

    @Test func unsupportedSVGStructuresFailWithoutPartialImport() {
        let unsupported = [
            "<svg><path d='M0 0 L10 10' fill='none' stroke='black'/><path d='M20 20 L30 30' fill='none' stroke='black'/></svg>",
            "<svg><g transform='translate(10 10)'><path d='M0 0 L10 10' fill='none' stroke='black'/></g></svg>",
            "<svg><path style='fill:red' d='M0 0 L10 0 L10 10 Z'/></svg>",
            "<svg><path d='M0 0 L10 0 Z M20 0 L30 0' fill='none' stroke='black'/></svg>",
            "<svg><path d='M0 0 L10 0 M20 0 L30 0' stroke='black'/></svg>",
            "<svg><path d='M0 0 L20 0 L20 20 Z M5 5 L10 5 L10 10 Z'/></svg>",
            "<svg><rect x='0' y='0' width='10' height='10'/></svg>",
            "<!DOCTYPE svg [<!ENTITY xxe SYSTEM 'file:///etc/passwd'>]><svg><path d='M0 0 L10 0 Z'/></svg>"
        ]

        for source in unsupported {
            #expect(XomoEditableSVGPathImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func viewportScalingAndFillRulesNeverSilentlyChangeEditableGeometry() throws {
        let scaled = try #require(XomoEditableSVGPathImporter.parse(Data(
            """
            <svg width="200" height="100" viewBox="0 0 100 50">
              <path d="M0 0 L20 0" fill="none" stroke="black" stroke-width="2" />
            </svg>
            """.utf8
        )))
        #expect(scaled.size == CGSize(width: 44, height: 4))
        #expect(scaled.content.editablePathAnchors.map(\.point) == [
            CGPoint(x: 2, y: 2),
            CGPoint(x: 42, y: 2)
        ])
        #expect(scaled.content.strokeWidth == 4)

        let simpleNonzero = XomoEditableSVGPathImporter.parse(Data(
            "<svg><path d='M0 0 L20 0 L10 10 Z'/></svg>".utf8
        ))
        #expect(simpleNonzero != nil)

        let incompatible = [
            "<svg width='200' height='120' viewBox='0 0 100 100'><path d='M0 0 L20 0' fill='none' stroke='black'/></svg>",
            "<svg><path d='M0 0 C10 0 10 10 20 10 Z'/></svg>",
            "<svg><path d='M0 0 L20 20 L0 20 L20 0 Z'/></svg>"
        ]
        for source in incompatible {
            #expect(XomoEditableSVGPathImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func importingEditableSVGPathIsOneUndoableLayerTransaction() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "svg-import",
            image: NSImage.transparent(size: CGSize(width: 200, height: 120))
        ) { _ in }
        let originalLayerCount = viewModel.document.layers.count
        let originalHistoryCount = viewModel.document.history.count
        let data = Data(
            """
            <svg xmlns="http://www.w3.org/2000/svg">
              <path d="M 10 20 L 50 40" fill="none" stroke="#123456" stroke-width="4" />
            </svg>
            """.utf8
        )

        #expect(viewModel.importEditableSVGPathLayer(data, sourceName: "Connector.svg"))
        #expect(viewModel.document.layers.count == originalLayerCount + 1)
        #expect(viewModel.document.history.count == originalHistoryCount + 1)
        let layer = try #require(viewModel.document.layers.last)
        let content = try #require(layer.shapeContent)
        #expect(layer.name == "Connector")
        #expect(layer.frame == CGRect(x: 78, y: 48, width: 44, height: 24))
        #expect(content.editablePathAnchors.map(\.point) == [
            CGPoint(x: 2, y: 2),
            CGPoint(x: 42, y: 22)
        ])
        #expect(!content.isPathClosed)
        #expect(content.fillOpacity == 0)
        #expect(viewModel.document.selectedLayerID == layer.id)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.editableSVGPathImported", "Connector"))

        viewModel.undo()
        #expect(viewModel.document.layers.count == originalLayerCount)
        #expect(viewModel.document.history.count == originalHistoryCount)
    }

    @Test func invalidSVGDoesNotMutateDocumentOrHistory() {
        let viewModel = ImageEditorViewModel(
            sourceName: "svg-rejection",
            image: NSImage.transparent(size: CGSize(width: 80, height: 60))
        ) { _ in }
        let originalLayerIDs = viewModel.document.layers.map(\.id)
        let originalHistory = viewModel.document.history
        let originalSelectedLayerID = viewModel.document.selectedLayerID
        let originalSelectedLayerIDs = viewModel.document.selectedLayerIDs

        #expect(!viewModel.importEditableSVGPathLayer(
            Data("<svg><circle cx='5' cy='5' r='4'/></svg>".utf8),
            sourceName: "unsupported.svg"
        ))
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.document.selectedLayerID == originalSelectedLayerID)
        #expect(viewModel.document.selectedLayerIDs == originalSelectedLayerIDs)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.editableSVGPathImportFailed"))
    }

    @Test func exportedSinglePathCanReturnAsEditableSVGShape() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "svg-roundtrip",
            image: NSImage.transparent(size: CGSize(width: 180, height: 120))
        ) { _ in }
        let anchors = [
            ImageEditorPathAnchor(
                point: CGPoint(x: 0, y: 20),
                outControl: CGPoint(x: 20, y: 0)
            ),
            ImageEditorPathAnchor(
                point: CGPoint(x: 60, y: 20),
                inControl: CGPoint(x: 40, y: 0)
            ),
            ImageEditorPathAnchor(point: CGPoint(x: 30, y: 60))
        ]
        var layer = ImageEditorLayer.shape(
            name: "Roundtrip Path",
            frame: CGRect(x: 30, y: 20, width: 60, height: 60),
            content: ImageEditorShapeContent(
                kind: .path,
                fillColor: NSColor(deviceRed: 0.2, green: 0.4, blue: 0.8, alpha: 1),
                fillOpacity: 0.7,
                strokeColor: .white,
                strokeWidth: 3,
                strokeOpacity: 0.6,
                strokePosition: .center,
                strokeCap: .round,
                strokeJoin: .bevel,
                strokeDashPattern: [6, 3],
                pathPoints: anchors.map(\.point),
                pathAnchors: anchors,
                isPathClosed: true
            )
        )
        layer.opacity = 0.5
        viewModel.document.layers.append(layer)

        let data = try #require(
            viewModel.exportData(settings: ImageEditorExportSettings(format: .svg))
        )
        let imported = try #require(XomoEditableSVGPathImporter.parse(data))
        let restored = imported.content
        let fill = try #require(restored.fillColor.usingColorSpace(.deviceRGB))

        #expect(restored.isPathClosed)
        #expect(restored.editablePathAnchors.count == 3)
        #expect(restored.strokeCap == .round)
        #expect(restored.strokeJoin == .bevel)
        #expect(restored.strokeDashPattern == [6, 3])
        #expect(abs(restored.fillOpacity - 0.35) < 0.001)
        #expect(abs(restored.strokeOpacity - 0.3) < 0.001)
        #expect(abs(fill.blueComponent - 0.8) < 0.01)
    }

    @Test func fileImportPanelRoutesSVGToEditablePathImporter() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorImport.swift"),
            encoding: .utf8
        )
        let chooserStart = try #require(source.range(of: "func chooseImageLayerFile()"))
        let chooserEnd = try #require(
            source[chooserStart.upperBound...].range(of: "func importEditableSVGPathLayer")
        )
        let chooser = source[chooserStart.lowerBound..<chooserEnd.lowerBound]

        #expect(chooser.contains("UTType(filenameExtension: \"svg\")"))
        #expect(chooser.contains("url.pathExtension.lowercased() == \"svg\""))
        #expect(chooser.contains("importEditableSVGPathLayer(data, sourceName: url.lastPathComponent)"))
        let svgRoute = try #require(chooser.range(of: "url.pathExtension.lowercased() == \"svg\""))
        let bitmapRoute = try #require(chooser.range(of: "NSImage(contentsOf: url)"))
        #expect(svgRoute.lowerBound < bitmapRoute.lowerBound)
    }
}
