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

        let imported = try #require(XomoEditableSVGImporter.parse(data))
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
            "<!DOCTYPE svg [<!ENTITY xxe SYSTEM 'file:///etc/passwd'>]><svg><path d='M0 0 L10 0 Z'/></svg>"
        ]

        for source in unsupported {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func singleRoundedRectangleImportsAsNativeEditableRectangle() throws {
        let data = Data(
            """
            <svg width="240" height="120" viewBox="0 0 120 60">
              <g opacity="0.5" fill="#336699" stroke="rgba(240, 80, 32, 0.8)"
                 stroke-width="2" stroke-linejoin="bevel" stroke-dasharray="3">
                <rect x="10" y="5" width="50" height="20" rx="4" />
              </g>
            </svg>
            """.utf8
        )

        let imported = try #require(XomoEditableSVGImporter.parse(data))
        let content = imported.content

        #expect(content.kind == .rectangle)
        #expect(imported.size == CGSize(width: 104, height: 44))
        #expect(content.cornerRadius == 8)
        #expect(content.cornerRadii == nil)
        #expect(content.cornerSmoothing == 0)
        #expect(content.fillOpacity == 0.5)
        #expect(abs(content.strokeOpacity - 0.4) < 0.001)
        #expect(content.strokeWidth == 4)
        #expect(content.strokePosition == .center)
        #expect(content.strokeJoin == .bevel)
        #expect(content.strokeDashPattern == [6, 6])
    }

    @Test func rectanglesThatCannotStayNativeAreRejectedBeforeImport() {
        let unsupported = [
            "<svg><rect width='20' height='10' rx='4' ry='2'/></svg>",
            "<svg><rect width='20' height='10' rx='-1'/></svg>",
            "<svg><rect width='0' height='10'/></svg>",
            "<svg><rect width='20' height='10' pathLength='100'/></svg>",
            "<svg><rect width='20' height='10' fill='none' stroke='black' stroke-width='11'/></svg>",
            "<svg><rect width='20' height='10' fill='none' stroke='none'/></svg>"
        ]

        for source in unsupported {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func singleCircleAndEllipseImportAsNativeEditableEllipses() throws {
        let circle = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg width="120" height="80" viewBox="0 0 60 40">
              <g opacity="0.5" fill="#336699" stroke="rgba(240, 80, 32, 0.8)"
                 stroke-width="2" stroke-dasharray="3">
                <circle cx="20" cy="20" r="10" />
              </g>
            </svg>
            """.utf8
        )))
        #expect(circle.content.kind == .ellipse)
        #expect(circle.size == CGSize(width: 44, height: 44))
        #expect(circle.content.fillOpacity == 0.5)
        #expect(abs(circle.content.strokeOpacity - 0.4) < 0.001)
        #expect(circle.content.strokeWidth == 4)
        #expect(circle.content.strokePosition == .center)
        #expect(circle.content.strokeDashPattern == [6, 6])

        let ellipse = try #require(XomoEditableSVGImporter.parse(Data(
            "<svg><ellipse cx='14' cy='8' rx='12' ry='6' fill='blue'/></svg>".utf8
        )))
        #expect(ellipse.content.kind == .ellipse)
        #expect(ellipse.size == CGSize(width: 24, height: 12))
        #expect(ellipse.content.fillOpacity == 1)
        #expect(ellipse.content.strokeOpacity == 0)
    }

    @Test func ellipsesThatCannotStayNativeAreRejectedBeforeImport() {
        let unsupported = [
            "<svg><circle r='0'/></svg>",
            "<svg><circle r='-1'/></svg>",
            "<svg><circle r='10' pathLength='100'/></svg>",
            "<svg><ellipse rx='10'/></svg>",
            "<svg><ellipse rx='10' ry='0'/></svg>",
            "<svg><ellipse rx='10' ry='5' fill='none' stroke='black' stroke-width='11'/></svg>",
            "<svg><ellipse rx='10' ry='5' fill='none' stroke='none'/></svg>"
        ]

        for source in unsupported {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }
    }

    @Test func singleLineImportsAsNativeEditableOpenPath() throws {
        let imported = try #require(XomoEditableSVGImporter.parse(Data(
            """
            <svg width="120" height="80" viewBox="0 0 60 40">
              <g opacity="0.5" fill="red" stroke="rgba(32, 80, 240, 0.8)"
                 stroke-width="2" stroke-linecap="square" stroke-dasharray="3">
                <line x1="10" y1="5" x2="30" y2="15" />
              </g>
            </svg>
            """.utf8
        )))
        let content = imported.content

        #expect(content.kind == .path)
        #expect(!content.isPathClosed)
        #expect(imported.size == CGSize(width: 44, height: 24))
        #expect(content.editablePathAnchors.map(\.point) == [
            CGPoint(x: 2, y: 2),
            CGPoint(x: 42, y: 22)
        ])
        #expect(content.fillOpacity == 0)
        #expect(abs(content.strokeOpacity - 0.4) < 0.001)
        #expect(content.strokeWidth == 4)
        #expect(content.strokeCap == .square)
        #expect(content.strokeDashPattern == [6, 6])
    }

    @Test func linesWithoutAnExactVisibleStrokeAreRejected() throws {
        let unsupported = [
            "<svg><line x1='0' y1='0' x2='10' y2='10'/></svg>",
            "<svg><line x1='0' y1='0' x2='10' y2='10' stroke='black' pathLength='100'/></svg>",
            "<svg><line x1='10%' y1='0' x2='10' y2='10' stroke='black'/></svg>",
            "<svg><line x1='0' y1='0' x2='10' y2='10' stroke='black' stroke-width='0.05'/></svg>",
            "<svg><line x1='5' y1='5' x2='5' y2='5' stroke='black'/></svg>"
        ]
        for source in unsupported {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
        }

        let roundPoint = try #require(XomoEditableSVGImporter.parse(Data(
            "<svg><line x1='5' y1='5' x2='5' y2='5' stroke='black' stroke-width='2' stroke-linecap='round'/></svg>".utf8
        )))
        #expect(roundPoint.size == CGSize(width: 2, height: 2))
        #expect(roundPoint.content.editablePathAnchors.map(\.point) == [
            CGPoint(x: 1, y: 1),
            CGPoint(x: 1, y: 1)
        ])
    }

    @Test func viewportScalingAndFillRulesNeverSilentlyChangeEditableGeometry() throws {
        let scaled = try #require(XomoEditableSVGImporter.parse(Data(
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

        let simpleNonzero = XomoEditableSVGImporter.parse(Data(
            "<svg><path d='M0 0 L20 0 L10 10 Z'/></svg>".utf8
        ))
        #expect(simpleNonzero != nil)

        let incompatible = [
            "<svg width='200' height='120' viewBox='0 0 100 100'><path d='M0 0 L20 0' fill='none' stroke='black'/></svg>",
            "<svg><path d='M0 0 C10 0 10 10 20 10 Z'/></svg>",
            "<svg><path d='M0 0 L20 20 L0 20 L20 0 Z'/></svg>"
        ]
        for source in incompatible {
            #expect(XomoEditableSVGImporter.parse(Data(source.utf8)) == nil)
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

        #expect(viewModel.importEditableSVGLayer(data, sourceName: "Connector.svg"))
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
        #expect(viewModel.statusText == L10n.format("imageEditor.status.editableSVGImported", "Connector"))

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

        #expect(!viewModel.importEditableSVGLayer(
            Data("<svg><polygon points='0,0 10,0 5,10'/></svg>".utf8),
            sourceName: "unsupported.svg"
        ))
        #expect(viewModel.document.layers.map(\.id) == originalLayerIDs)
        #expect(viewModel.document.history == originalHistory)
        #expect(viewModel.document.selectedLayerID == originalSelectedLayerID)
        #expect(viewModel.document.selectedLayerIDs == originalSelectedLayerIDs)
        #expect(viewModel.statusText == L10n.text("imageEditor.status.editableSVGImportFailed"))
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
        let imported = try #require(XomoEditableSVGImporter.parse(data))
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

    @Test func exportedPlainRectangleCanReturnAsNativeRectangle() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "svg-rectangle-roundtrip",
            image: NSImage.transparent(size: CGSize(width: 180, height: 120))
        ) { _ in }
        var layer = ImageEditorLayer.shape(
            name: "Card",
            frame: CGRect(x: 30, y: 20, width: 100, height: 60),
            content: ImageEditorShapeContent(
                kind: .rectangle,
                fillColor: NSColor(deviceRed: 0.2, green: 0.4, blue: 0.8, alpha: 1),
                fillOpacity: 0.7,
                strokeColor: .white,
                strokeWidth: 2,
                strokeOpacity: 0.6,
                strokePosition: .center
            )
        )
        layer.opacity = 0.5
        viewModel.document.layers.append(layer)

        let data = try #require(
            viewModel.exportData(settings: ImageEditorExportSettings(format: .svg))
        )
        let imported = try #require(XomoEditableSVGImporter.parse(data))

        #expect(imported.content.kind == .rectangle)
        #expect(imported.size == CGSize(width: 100, height: 60))
        #expect(imported.content.cornerRadius == 0)
        #expect(imported.content.strokeWidth == 2)
        #expect(abs(imported.content.fillOpacity - 0.35) < 0.001)
        #expect(abs(imported.content.strokeOpacity - 0.3) < 0.001)
    }

    @Test func exportedEllipseCanReturnAsNativeEllipse() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "svg-ellipse-roundtrip",
            image: NSImage.transparent(size: CGSize(width: 180, height: 120))
        ) { _ in }
        var layer = ImageEditorLayer.shape(
            name: "Badge",
            frame: CGRect(x: 30, y: 20, width: 100, height: 60),
            content: ImageEditorShapeContent(
                kind: .ellipse,
                fillColor: NSColor(deviceRed: 0.8, green: 0.3, blue: 0.2, alpha: 1),
                fillOpacity: 0.7,
                strokeColor: .white,
                strokeWidth: 2,
                strokeOpacity: 0.6,
                strokePosition: .center
            )
        )
        layer.opacity = 0.5
        viewModel.document.layers.append(layer)

        let data = try #require(
            viewModel.exportData(settings: ImageEditorExportSettings(format: .svg))
        )
        let imported = try #require(XomoEditableSVGImporter.parse(data))

        #expect(imported.content.kind == .ellipse)
        #expect(imported.size == CGSize(width: 100, height: 60))
        #expect(imported.content.strokeWidth == 2)
        #expect(abs(imported.content.fillOpacity - 0.35) < 0.001)
        #expect(abs(imported.content.strokeOpacity - 0.3) < 0.001)
    }

    @Test func fileImportPanelRoutesSVGToEditableShapeImporter() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("veilpic/ImageEditorImport.swift"),
            encoding: .utf8
        )
        let chooserStart = try #require(source.range(of: "func chooseImageLayerFile()"))
        let chooserEnd = try #require(
            source[chooserStart.upperBound...].range(of: "func importEditableSVGLayer")
        )
        let chooser = source[chooserStart.lowerBound..<chooserEnd.lowerBound]

        #expect(chooser.contains("UTType(filenameExtension: \"svg\")"))
        #expect(chooser.contains("url.pathExtension.lowercased() == \"svg\""))
        #expect(chooser.contains("importEditableSVGLayer(data, sourceName: url.lastPathComponent)"))
        let svgRoute = try #require(chooser.range(of: "url.pathExtension.lowercased() == \"svg\""))
        let bitmapRoute = try #require(chooser.range(of: "NSImage(contentsOf: url)"))
        #expect(svgRoute.lowerBound < bitmapRoute.lowerBound)
    }
}
