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
                            "constraint": {"type": "WIDTH", "value": 240}
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

    @Test
    func figmaPDFExportSettingCreatesSliceScopedPDFArtifact() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Handoff",
                  "nodes": {
                    "4:20": {
                      "document": {
                        "id": "4:20",
                        "name": "Spec Sheet",
                        "type": "SLICE",
                        "absoluteBoundingBox": {"x": 10, "y": 20, "width": 120, "height": 60},
                        "exportSettings": [
                          {
                            "suffix": "-print",
                            "format": "PDF",
                            "constraint": {"type": "SCALE", "value": 1}
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
            requestedNodeID: "4:20"
        )
        let item = try #require(plan.items.first)
        #expect(item.exportPresets.count == 1)
        #expect(item.exportPresets.first?.format == .pdf)
        #expect(item.exportPresets.first?.constraint == .scale)
        #expect(item.exportPresets.first?.value == 1)
        #expect(item.issues.isEmpty)

        let viewModel = ImageEditorViewModel(
            sourceName: "handoff.xomoproject",
            image: NSImage.rendered(size: CGSize(width: 200, height: 120)) { rect in
                NSColor.systemPurple.setFill()
                rect.fill()
            }!
        ) { _ in }
        #expect(viewModel.importFigmaNodePlan(plan))

        let variants = viewModel.sliceExportPlan(settings: viewModel.exportSettings)
        let variant = try #require(variants.first)
        #expect(variants.count == 1)
        #expect(variant.filename == "Spec Sheet-print.pdf")
        #expect(variant.settings.format == .pdf)
        #expect(variant.settings.scope == .slice)
        let artifacts = try #require(
            viewModel.sliceExportArtifacts(settings: viewModel.exportSettings)
        )
        let artifact = try #require(artifacts.first)
        #expect(artifacts.count == 1)
        #expect(artifact.variant == variant)
        #expect(String(decoding: artifact.data.prefix(4), as: UTF8.self) == "%PDF")
    }
}
