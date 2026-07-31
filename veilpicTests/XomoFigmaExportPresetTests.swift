import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoFigmaExportPresetTests {
    @Test
    func figmaExportSettingsCreateNativeSliceAndApplyPrimaryPreset() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Marketing",
                  "version": "2",
                  "nodes": {
                    "8:14": {
                      "document": {
                        "id": "8:14",
                        "name": "Marketing Card",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 100, "y": 200, "width": 120, "height": 60},
                        "exportSettings": [
                          {
                            "suffix": "@2x",
                            "format": "PNG",
                            "constraint": {"type": "SCALE", "value": 2}
                          },
                          {
                            "suffix": "-wide",
                            "format": "JPG",
                            "constraint": {"type": "WIDTH", "value": 360}
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "8:14"
        )
        let item = try #require(plan.items.first)
        #expect(item.targetKind == .group)
        #expect(item.exportPresets.count == 2)
        #expect(item.issues.isEmpty)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 500, height: 400)
        )
        #expect(materialized.layers.count == 1)
        let slice = try #require(materialized.slices.first)
        #expect(slice.name == "Marketing Card")
        #expect(slice.exportPresets == item.exportPresets)

        let viewModel = ImageEditorViewModel(
            sourceName: "marketing.xomoproject",
            image: NSImage.transparent(size: CGSize(width: 500, height: 400))
        ) { _ in }
        #expect(viewModel.importFigmaNodePlan(plan))
        #expect(viewModel.exportSettings.scope == .slice)
        #expect(viewModel.exportSettings.format == .png)
        #expect(viewModel.exportSettings.scale == 2)
        #expect(viewModel.exportSettings.filenameSuffix == "@2x")
        #expect(viewModel.exportFilenames(settings: viewModel.exportSettings) == [
            "Marketing Card@2x.png"
        ])
    }

    @Test
    func unsupportedOrUnsafeFigmaPresetsAreReportedAndDoNotEscapeFilenames() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Delivery",
                  "nodes": {
                    "1:70": {
                      "document": {
                        "id": "1:70",
                        "name": "Hero",
                        "type": "SLICE",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 50},
                        "exportSettings": [
                          {
                            "suffix": "/../@2x",
                            "format": "PNG",
                            "constraint": {"type": "HEIGHT", "value": 100}
                          },
                          {
                            "suffix": "-vector",
                            "format": "SVG",
                            "constraint": {"type": "SCALE", "value": 1}
                          },
                          {
                            "suffix": "-huge",
                            "format": "PNG",
                            "constraint": {"type": "WIDTH", "value": 1000}
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:70"
        )
        let item = try #require(plan.items.first)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.exportSettingsPartiallyPreserved))
        #expect(item.exportPresets.count == 1)
        #expect(item.exportPresets.first?.suffix == "-..-@2x")

        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.transparent(size: CGSize(width: 300, height: 200))
        ) { _ in }
        #expect(viewModel.importFigmaNodePlan(plan))
        #expect(viewModel.exportSettings.scale == 2)
        #expect(viewModel.exportFilenames(settings: viewModel.exportSettings) == [
            "Hero-..-@2x.png"
        ])
    }

    @Test
    func figmaSliceExportPresetsSurviveProjectRoundTripAndSelection() throws {
        let presets = [
            ImageEditorSliceExportPreset(
                suffix: "-wide",
                format: .jpeg,
                constraint: .width,
                value: 400
            ),
            ImageEditorSliceExportPreset(
                suffix: "@3x",
                format: .png,
                constraint: .scale,
                value: 3
            )
        ]
        let viewModel = ImageEditorViewModel(
            sourceName: "asset.png",
            image: NSImage.transparent(size: CGSize(width: 600, height: 400))
        ) { _ in }
        let slice = ImageEditorSlice(
            name: "Banner",
            frame: CGRect(x: 20, y: 30, width: 200, height: 100),
            exportPresets: presets
        )
        viewModel.document.slices = [slice]

        let restored = try ImageEditorProjectDocument(
            document: viewModel.document
        ).restoredDocument()
        #expect(restored.slices.first?.exportPresets == presets)

        viewModel.document = restored
        #expect(viewModel.selectSlice(id: slice.id) != nil)
        #expect(viewModel.exportSettings.format == .jpeg)
        #expect(viewModel.exportSettings.scale == 2)
        #expect(viewModel.exportSettings.filenameSuffix == "-wide")
        #expect(viewModel.exportFilenames(settings: viewModel.exportSettings) == [
            "Banner-wide.jpg"
        ])
    }
}
