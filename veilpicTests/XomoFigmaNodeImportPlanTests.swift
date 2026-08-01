//
//  XomoFigmaNodeImportPlanTests.swift
//  veilpicTests
//
//  Created by Codex on 2026/7/15.
//

import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoFigmaNodeImportPlanTests {
    @Test func supportedTextCaseStylesBakeIntoEditableCharacters() {
        #expect(XomoFigmaNodeImportMapper.characters("Hello 世界", applying: "UPPER") == "HELLO 世界")
        #expect(XomoFigmaNodeImportMapper.characters("Hello 世界", applying: "LOWER") == "hello 世界")
        #expect(XomoFigmaNodeImportMapper.characters("hello world", applying: "TITLE") == "Hello World")
        #expect(XomoFigmaNodeImportMapper.characters("Hello", applying: "ORIGINAL") == "Hello")
        #expect(XomoFigmaNodeImportMapper.characters("Hello", applying: "SMALL_CAPS") == "Hello")
    }

    @Test func figmaLineHeightUsesPixelsBeforeFontSizePercentageFallback() throws {
        let decoder = JSONDecoder()
        let pixels = try decoder.decode(
            XomoFigmaTypeStyle.self,
            from: Data(#"{"fontSize":16,"lineHeightPx":22,"lineHeightPercentFontSize":150}"#.utf8)
        )
        let percent = try decoder.decode(
            XomoFigmaTypeStyle.self,
            from: Data(#"{"fontSize":16,"lineHeightPercentFontSize":137.5}"#.utf8)
        )
        let unitFallback = try decoder.decode(
            XomoFigmaTypeStyle.self,
            from: Data(#"{"fontSize":20,"lineHeightPercent":120,"lineHeightUnit":"FONT_SIZE_%"}"#.utf8)
        )
        let intrinsic = try decoder.decode(
            XomoFigmaTypeStyle.self,
            from: Data(#"{"fontSize":20,"lineHeightPercent":120,"lineHeightUnit":"INTRINSIC_%"}"#.utf8)
        )

        #expect(XomoFigmaNodeImportMapper.lineHeight(for: pixels) == 22)
        #expect(XomoFigmaNodeImportMapper.lineHeight(for: percent) == 22)
        #expect(XomoFigmaNodeImportMapper.lineHeight(for: unitFallback) == 24)
        #expect(XomoFigmaNodeImportMapper.lineHeight(for: intrinsic) == nil)
    }

    @Test func unmappableIntrinsicLineHeightIsReportedAsPartialInsteadOfExact() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                #"{"name":"Typography","nodes":{"1:1":{"document":{"id":"1:1","name":"Caption","type":"TEXT","characters":"Caption","style":{"fontSize":16,"lineHeightPercent":120,"lineHeightUnit":"INTRINSIC_%"},"fills":[{"type":"SOLID","color":{"r":0,"g":0,"b":0,"a":1}}],"absoluteBoundingBox":{"x":0,"y":0,"width":120,"height":24}}}}}"#.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:1")
        let item = try #require(plan.items.first)
        #expect(item.text?.lineHeight == nil)
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.textLineHeightFlattened))
    }

    @Test func figmaSliceBecomesNativeFireworksSliceAndExportsWithoutCreatingLayer() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Delivery",
                  "version": "1",
                  "nodes": {
                    "1:70": {
                      "document": {
                        "id": "1:70",
                        "name": "Hero Export",
                        "type": "SLICE",
                        "absoluteBoundingBox": {"x": 120, "y": 240, "width": 80, "height": 40}
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
        #expect(item.targetKind == .slice)
        #expect(item.fidelity == .exact)
        #expect(item.issues.isEmpty)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let slice = try #require(materialized.slices.first)
        #expect(materialized.layers.isEmpty)
        #expect(materialized.importedCount == 1)
        #expect(materialized.omittedCount == 0)
        #expect(slice.name == "Hero Export")
        #expect(slice.frame == CGRect(x: 160, y: 130, width: 80, height: 40))

        let viewModel = ImageEditorViewModel(
            sourceName: "delivery.png",
            image: NSImage.rendered(size: CGSize(width: 400, height: 300)) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
            } ?? NSImage.transparent(size: CGSize(width: 400, height: 300))
        ) { _ in }
        let initialLayerIDs = viewModel.document.layers.map(\.id)
        let initialHistoryCount = viewModel.document.history.count

        #expect(viewModel.importFigmaNodePlan(plan))
        #expect(viewModel.document.layers.map(\.id) == initialLayerIDs)
        #expect(viewModel.document.slices.count == 1)
        #expect(viewModel.document.slices.first?.name == "Hero Export")
        #expect(viewModel.exportSettings.scope == .slice)
        #expect(viewModel.exportSettings.sliceID == viewModel.document.slices.first?.id)
        #expect(viewModel.isSlicesPanelVisible)
        #expect(viewModel.document.history.count == initialHistoryCount + 1)
        #expect(viewModel.statusText == L10n.format("imageEditor.status.figmaNodeImported", 1, 0))

        let exported = try #require(viewModel.exportData(settings: viewModel.exportSettings))
        let exportedImage = try #require(NSImage(data: exported))
        #expect(exportedImage.size == CGSize(width: 80, height: 40))

        let restored = try ImageEditorProjectDocument(document: viewModel.document).restoredDocument()
        #expect(restored.slices == viewModel.document.slices)

        viewModel.undo()
        #expect(viewModel.document.slices.isEmpty)
        #expect(viewModel.document.layers.map(\.id) == initialLayerIDs)

        viewModel.redo()
        #expect(viewModel.document.slices.count == 1)
        #expect(viewModel.document.layers.map(\.id) == initialLayerIDs)
    }

    @Test func gradientStopResolutionRunsOffMainActorAndRejectsInvalidValues() async {
        let resolved = await Task.detached {
            XomoFigmaNodeImportMapper.resolveGradientStopColor(
                XomoFigmaGradientStop(
                    position: 0.4,
                    color: XomoFigmaColor(r: 0.2, g: 0.4, b: 0.6, a: 0.8)
                )
            )
        }.value
        let invalidPosition = await Task.detached {
            XomoFigmaNodeImportMapper.resolveGradientStopColor(
                XomoFigmaGradientStop(
                    position: .nan,
                    color: XomoFigmaColor(r: 0.2, g: 0.4, b: 0.6, a: 0.8)
                )
            )
        }.value
        let invalidChannel = await Task.detached {
            XomoFigmaNodeImportMapper.resolveGradientStopColor(
                XomoFigmaGradientStop(
                    position: 0.4,
                    color: XomoFigmaColor(r: 0.2, g: 1.4, b: 0.6, a: 0.8)
                )
            )
        }.value

        #expect(resolved == XomoFigmaPlanColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8))
        #expect(invalidPosition == nil)
        #expect(invalidChannel == nil)
    }

    @Test func offsetMultiStopLinearGradientsMapToEditableShapes() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Gradients",
                  "nodes": {
                    "1:30": {
                      "document": {
                        "id": "1:30",
                        "name": "Gradient Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 240, "height": 160},
                        "children": [
                          {
                            "id": "2:30",
                            "name": "Editable Gradient",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 20, "width": 120, "height": 48},
                            "fills": [{
                              "type": "GRADIENT_LINEAR",
                              "opacity": 0.8,
                              "gradientHandlePositions": [
                                {"x": 0.1, "y": 0.5},
                                {"x": 0.7, "y": 0.5},
                                {"x": 0, "y": 0}
                              ],
                              "gradientStops": [
                                {"position": 0, "color": {"r": 1, "g": 0, "b": 0, "a": 0.5}},
                                {"position": 1, "color": {"r": 0, "g": 0, "b": 1, "a": 0.5}}
                              ]
                            }]
                          },
                          {
                            "id": "2:31",
                            "name": "Three Stops",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 90, "width": 120, "height": 48},
                            "fills": [{
                              "type": "GRADIENT_LINEAR",
                              "gradientHandlePositions": [
                                {"x": 0, "y": 0.5},
                                {"x": 1, "y": 0.5},
                                {"x": 0, "y": 0}
                              ],
                              "gradientStops": [
                                {"position": 0, "color": {"r": 1, "g": 0, "b": 0, "a": 1}},
                                {"position": 0.5, "color": {"r": 0, "g": 1, "b": 0, "a": 1}},
                                {"position": 1, "color": {"r": 0, "g": 0, "b": 1, "a": 1}}
                              ]
                            }]
                          },
                          {
                            "id": "2:32",
                            "name": "Different Stop Alpha",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 150, "y": 90, "width": 70, "height": 48},
                            "fills": [{
                              "type": "GRADIENT_LINEAR",
                              "gradientHandlePositions": [
                                {"x": 0, "y": 0.5},
                                {"x": 1, "y": 0.5},
                                {"x": 0, "y": 0}
                              ],
                              "gradientStops": [
                                {"position": 0, "color": {"r": 1, "g": 0, "b": 0, "a": 1}},
                                {"position": 0.5, "color": {"r": 0, "g": 1, "b": 0, "a": 0.5}},
                                {"position": 1, "color": {"r": 0, "g": 0, "b": 1, "a": 1}}
                              ]
                            }]
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
            requestedNodeID: "1:30"
        )
        let editable = try #require(plan.items.first { $0.sourceID == "2:30" })
        let multiStop = try #require(plan.items.first { $0.sourceID == "2:31" })
        let differentAlpha = try #require(plan.items.first { $0.sourceID == "2:32" })
        #expect(editable.fidelity == .exact)
        #expect(editable.linearGradientFill?.angle == 0)
        #expect(abs((editable.linearGradientFill?.scale ?? 0) - 0.6) < 0.001)
        #expect(abs((editable.linearGradientFill?.centerX ?? 0) - 0.4) < 0.001)
        #expect(editable.linearGradientFill?.centerY == 0.5)
        #expect(editable.linearGradientFill?.opacity == 0.4)
        #expect(!editable.issues.contains(.unsupportedPaint))
        #expect(multiStop.fidelity == .exact)
        #expect(multiStop.linearGradientFill?.colorStops.count == 3)
        #expect(multiStop.linearGradientFill?.colorStops[1].position == 0.5)
        #expect(!multiStop.issues.contains(.unsupportedPaint))
        #expect(differentAlpha.fidelity == .partial)
        #expect(differentAlpha.linearGradientFill == nil)
        #expect(differentAlpha.issues.contains(.unsupportedPaint))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let shape = try #require(
            materialized.layers.first { $0.name == "Editable Gradient" }?.shapeContent
        )
        #expect(shape.fillGradient?.angle == 0)
        #expect(abs((shape.fillGradient?.scale ?? 0) - 0.6) < 0.001)
        #expect(abs(shape.fillGradientCenter.x - 0.4) < 0.001)
        #expect(shape.fillGradientCenter.y == 0.5)
        #expect(abs(shape.fillOpacity - 0.4) < 0.001)
        let multiStopShape = try #require(
            materialized.layers.first { $0.name == "Three Stops" }?.shapeContent
        )
        #expect(multiStopShape.fillGradient?.shapeColorStops.count == 3)
        #expect((multiStopShape.fillGradient?.shapeColorStops[1].green ?? 0) > 0.95)
    }

    @Test func supportedFigmaBlendModesRemainEditableAndUnknownModesStayExplicitlyPartial() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Blend Modes",
                  "nodes": {
                    "1:50": {
                      "document": {
                        "id": "1:50",
                        "name": "Blend Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 240, "height": 180},
                        "children": [
                          {
                            "id": "2:50",
                            "name": "Multiply",
                            "type": "RECTANGLE",
                            "blendMode": "MULTIPLY",
                            "absoluteBoundingBox": {"x": 10, "y": 10, "width": 80, "height": 40},
                            "fills": [{"type": "SOLID", "color": {"r": 1, "g": 0, "b": 0, "a": 1}}]
                          },
                          {
                            "id": "2:51",
                            "name": "Screen",
                            "type": "RECTANGLE",
                            "blendMode": "SCREEN",
                            "absoluteBoundingBox": {"x": 100, "y": 10, "width": 80, "height": 40},
                            "fills": [{"type": "SOLID", "color": {"r": 0, "g": 1, "b": 0, "a": 1}}]
                          },
                          {
                            "id": "2:52",
                            "name": "Future Mode",
                            "type": "RECTANGLE",
                            "blendMode": "PLUS_LIGHTER",
                            "absoluteBoundingBox": {"x": 10, "y": 70, "width": 80, "height": 40},
                            "fills": [{"type": "SOLID", "color": {"r": 0, "g": 0, "b": 1, "a": 1}}]
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
            requestedNodeID: "1:50"
        )
        let multiply = try #require(plan.items.first { $0.sourceID == "2:50" })
        let screen = try #require(plan.items.first { $0.sourceID == "2:51" })
        let unknown = try #require(plan.items.first { $0.sourceID == "2:52" })
        #expect(multiply.blendMode == ImageEditorBlendMode.multiply.rawValue)
        #expect(multiply.fidelity == .exact)
        #expect(!multiply.issues.contains(.blendModeFlattened))
        #expect(screen.blendMode == ImageEditorBlendMode.screen.rawValue)
        #expect(screen.fidelity == .exact)
        #expect(unknown.blendMode == nil)
        #expect(unknown.fidelity == .partial)
        #expect(unknown.issues.contains(.blendModeFlattened))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let multiplyLayer = try #require(materialized.layers.first { $0.name == "Multiply" })
        let screenLayer = try #require(materialized.layers.first { $0.name == "Screen" })
        let unknownLayer = try #require(materialized.layers.first { $0.name == "Future Mode" })
        #expect(multiplyLayer.blendMode == .multiply)
        #expect(screenLayer.blendMode == .screen)
        #expect(unknownLayer.blendMode == .normal)
    }

    @Test func multipleSolidFillsCompositeVisuallyAndReportLostFillSemantics() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Solid Paint Stack",
                  "nodes": {
                    "1:60": {
                      "document": {
                        "id": "1:60",
                        "name": "Solid Paint Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 200, "height": 120},
                        "children": [{
                          "id": "2:60",
                          "name": "Layered Solid",
                          "type": "RECTANGLE",
                          "absoluteBoundingBox": {"x": 20, "y": 20, "width": 100, "height": 50},
                          "fills": [
                            {"type": "SOLID", "color": {"r": 0, "g": 0, "b": 1, "a": 0.5}},
                            {"type": "SOLID", "color": {"r": 1, "g": 0, "b": 0, "a": 0.5}}
                          ]
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:60"
        )
        let item = try #require(plan.items.first { $0.sourceID == "2:60" })
        #expect(item.fidelity == .partial)
        #expect(item.issues.contains(.unsupportedPaint))
        let color = try #require(item.solidFill)
        #expect(abs(color.alpha - 0.75) < 0.001)
        #expect(abs(color.red - (1.0 / 3.0)) < 0.001)
        #expect(abs(color.blue - (2.0 / 3.0)) < 0.001)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 300, height: 200)
        )
        let shape = try #require(materialized.layers.first { $0.name == "Layered Solid" }?.shapeContent)
        #expect(abs(shape.fillOpacity - 0.75) < 0.001)
        #expect(abs((shape.fillColor.usingColorSpace(.deviceRGB)?.redComponent ?? 0) - (1.0 / 3.0)) < 0.001)
        #expect(abs((shape.fillColor.usingColorSpace(.deviceRGB)?.blueComponent ?? 0) - (2.0 / 3.0)) < 0.001)
    }

    @Test func circularRadialGradientsMapWhileEllipticalAxesDegrade() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Radial Gradients",
                  "nodes": {
                    "1:40": {
                      "document": {
                        "id": "1:40",
                        "name": "Radial Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 300, "height": 140},
                        "children": [
                          {
                            "id": "2:40",
                            "name": "Editable Radial",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 20, "width": 120, "height": 80},
                            "fills": [{
                              "type": "GRADIENT_RADIAL",
                              "opacity": 0.8,
                              "gradientHandlePositions": [
                                {"x": 0.4, "y": 0.5},
                                {"x": 0.7333333333, "y": 0.5},
                                {"x": 0.4, "y": 1.0}
                              ],
                              "gradientStops": [
                                {"position": 0, "color": {"r": 1, "g": 0, "b": 0, "a": 0.5}},
                                {"position": 0.45, "color": {"r": 0, "g": 1, "b": 0, "a": 0.5}},
                                {"position": 1, "color": {"r": 0, "g": 0, "b": 1, "a": 0.5}}
                              ]
                            }]
                          },
                          {
                            "id": "2:41",
                            "name": "Elliptical Radial",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 160, "y": 20, "width": 100, "height": 80},
                            "fills": [{
                              "type": "GRADIENT_RADIAL",
                              "gradientHandlePositions": [
                                {"x": 0.5, "y": 0.5},
                                {"x": 0.9, "y": 0.5},
                                {"x": 0.5, "y": 0.7}
                              ],
                              "gradientStops": [
                                {"position": 0, "color": {"r": 1, "g": 1, "b": 1, "a": 1}},
                                {"position": 1, "color": {"r": 0, "g": 0, "b": 0, "a": 1}}
                              ]
                            }]
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
            requestedNodeID: "1:40"
        )
        let radial = try #require(plan.items.first { $0.sourceID == "2:40" })
        let elliptical = try #require(plan.items.first { $0.sourceID == "2:41" })
        let radialFill = try #require(radial.radialGradientFill)
        #expect(radial.fidelity == .exact)
        #expect(radial.linearGradientFill == nil)
        #expect(!radial.issues.contains(.unsupportedPaint))
        #expect(abs(radialFill.centerX - 0.4) < 0.001)
        #expect(abs(radialFill.centerY - 0.5) < 0.001)
        #expect(abs(radialFill.scale - (40 / hypot(60, 40))) < 0.001)
        #expect(abs(radialFill.opacity - 0.4) < 0.001)
        #expect(radialFill.colorStops.count == 3)
        #expect(radialFill.colorStops[1].position == 0.45)
        #expect(elliptical.fidelity == .partial)
        #expect(elliptical.radialGradientFill == nil)
        #expect(elliptical.issues.contains(.unsupportedPaint))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 200)
        )
        let shape = try #require(
            materialized.layers.first { $0.name == "Editable Radial" }?.shapeContent
        )
        #expect(shape.fillGradient?.style == .radial)
        #expect(abs((shape.fillGradient?.scale ?? 0) - radialFill.scale) < 0.001)
        #expect(abs(shape.fillGradientCenter.x - 0.4) < 0.001)
        #expect(abs(shape.fillGradientCenter.y - 0.5) < 0.001)
        #expect(abs(shape.fillOpacity - 0.4) < 0.001)
        #expect(shape.fillGradient?.shapeColorStops.count == 3)
        #expect((shape.fillGradient?.shapeColorStops[1].green ?? 0) > 0.95)
    }

    @Test func clientRequiresSpecificNodeAndUsesBoundedOfficialEndpoint() async throws {
        let transport = RecordingFigmaNodeTransport(statusCode: 200, body: Self.validNodeResponse)
        let client = XomoFigmaNodeContentAPIClient(transport: transport)
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let filePreview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout"
        )
        let nodePreview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3&version-id=77"
        )

        await #expect(throws: XomoFigmaNodeImportError.nodeSelectionRequired) {
            try await client.fetchPlan(for: filePreview, credential: token)
        }
        let plan = try await client.fetchPlan(for: nodePreview, credential: token)
        let request = try #require(transport.lastRequest)
        let requestURL = try #require(request.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(request.httpMethod == "GET")
        #expect(components.path == "/v1/files/abc123DEF456/nodes")
        #expect(query == ["ids": "1:3", "depth": "6", "geometry": "paths", "version": "77"])
        #expect(request.value(forHTTPHeaderField: "X-Figma-Token") == token.rawValue)
        #expect(request.url?.absoluteString.contains(token.rawValue) == false)
        #expect(plan.rootSourceID == "1:3")
        #expect(plan.sourceCanonicalURL == nodePreview.canonicalURL)
    }

    @Test func mapperBuildsEditableHierarchyAndRelativeFrames() async throws {
        let transport = RecordingFigmaNodeTransport(statusCode: 200, body: Self.validNodeResponse)
        let client = XomoFigmaNodeContentAPIClient(transport: transport)
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3"
        )

        let plan = try await client.fetchPlan(for: preview, credential: token)
        let frame = try #require(plan.items.first { $0.sourceID == "1:3" })
        let group = try #require(plan.items.first { $0.sourceID == "2:1" })
        let text = try #require(plan.items.first { $0.sourceID == "2:2" })
        let rectangle = try #require(plan.items.first { $0.sourceID == "2:3" })
        let ellipse = try #require(plan.items.first { $0.sourceID == "2:4" })
        let vector = try #require(plan.items.first { $0.sourceID == "2:5" })
        #expect(plan.sourceCanonicalURL == preview.canonicalURL)

        #expect(frame.targetKind == .group)
        #expect(frame.frame == XomoFigmaPlanRect(x: 0, y: 0, width: 390, height: 844))
        #expect(group.parentSourceID == "1:3")
        #expect(group.targetKind == .group)
        #expect(group.stackLayout?.axis == .horizontal)
        #expect(text.parentSourceID == "2:1")
        #expect(text.targetKind == .text)
        #expect(text.stackChildLayout == ImageEditorStackChildLayout(
            grow: 1,
            stretchesCrossAxis: true
        ))
        #expect(text.text?.characters == "继续")
        #expect(text.text?.fontFamily == "Inter")
        #expect(text.text?.fontSize == 16)
        #expect(text.frame == XomoFigmaPlanRect(x: 30, y: 60, width: 64, height: 24))
        #expect(rectangle.targetKind == .rectangle)
        #expect(rectangle.fidelity == .exact)
        #expect(!rectangle.issues.contains(.cornerRadiusFlattened))
        #expect(rectangle.cornerRadius == 8)
        #expect(rectangle.solidFill == XomoFigmaPlanColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1))
        #expect(rectangle.opacity == 0.8)
        #expect(ellipse.targetKind == .ellipse)
        #expect(vector.targetKind == .vector)
        #expect(vector.vectorPaths == ["M 0 0 L 20 0 L 10 20 Z"])
        #expect(vector.geometrySize == XomoFigmaPlanSize(width: 20, height: 20))
        #expect(vector.solidStroke == XomoFigmaPlanColor(red: 0, green: 0, blue: 0, alpha: 1))
        #expect(vector.strokeWeight == 2)
    }

    @Test func mapperImportsSectionAsEditableGroupAndPreservesGradientBackground() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Sections",
                  "nodes": {
                    "1:50": {
                      "document": {
                        "id": "1:50",
                        "name": "Checkout Section",
                        "type": "SECTION",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 320, "height": 200},
                        "fills": [{
                          "type": "GRADIENT_LINEAR",
                          "gradientHandlePositions": [
                            {"x": 0, "y": 0.5},
                            {"x": 1, "y": 0.5},
                            {"x": 0, "y": 0}
                          ],
                          "gradientStops": [
                            {"position": 0, "color": {"r": 0.1, "g": 0.2, "b": 0.4, "a": 1}},
                            {"position": 1, "color": {"r": 0.4, "g": 0.6, "b": 1, "a": 1}}
                          ]
                        }],
                        "children": [{
                          "id": "2:50",
                          "name": "Section Button",
                          "type": "RECTANGLE",
                          "absoluteBoundingBox": {"x": 24, "y": 24, "width": 120, "height": 40},
                          "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}]
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:50")
        let section = try #require(plan.items.first { $0.sourceID == "1:50" })
        let button = try #require(plan.items.first { $0.sourceID == "2:50" })
        #expect(section.targetKind == .group)
        #expect(section.fidelity == .exact)
        #expect(!section.issues.contains(.unsupportedNodeType))
        #expect(section.linearGradientFill?.colorStops.count == 2)
        #expect(button.parentSourceID == "1:50")

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 640, height: 400)
        )
        #expect(materialized.omittedCount == 0)
        #expect(materialized.layers.contains { $0.name == "Section Button" })
        let background = try #require(
            materialized.layers.first { $0.isStackLayoutBackground }
        )
        #expect(background.shapeContent?.fillGradient?.shapeColorStops.count == 2)
    }

    @Test func mapperFlattensBooleanOperationToEditableVectorWithoutDuplicateChildren() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Boolean Shapes",
                  "nodes": {
                    "1:60": {
                      "document": {
                        "id": "1:60",
                        "name": "Union Result",
                        "type": "BOOLEAN_OPERATION",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 120, "height": 80},
                        "fills": [{"type": "SOLID", "color": {"r": 0.2, "g": 0.5, "b": 0.9, "a": 1}}],
                        "fillGeometry": [{"path": "M 0 0 L 120 0 L 120 80 L 0 80 Z"}],
                        "children": [
                          {
                            "id": "2:60",
                            "name": "Union Source A",
                            "type": "ELLIPSE",
                            "absoluteBoundingBox": {"x": 0, "y": 0, "width": 80, "height": 80}
                          },
                          {
                            "id": "2:61",
                            "name": "Union Source B",
                            "type": "ELLIPSE",
                            "absoluteBoundingBox": {"x": 40, "y": 0, "width": 80, "height": 80}
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:60")
        let operation = try #require(plan.items.first { $0.sourceID == "1:60" })
        #expect(operation.targetKind == .vector)
        #expect(operation.fidelity == .partial)
        #expect(operation.issues.contains(.booleanOperationFlattened))
        #expect(operation.vectorPaths == ["M 0 0 L 120 0 L 120 80 L 0 80 Z"])

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 240, height: 160)
        )
        #expect(materialized.omittedCount == 0)
        #expect(materialized.layers.count == 1)
        let result = try #require(materialized.layers.first)
        #expect(result.name == "Union Result")
        #expect(result.shapeContent?.kind == .path)
        #expect(result.shapeContent?.pathAnchors.count == 4)
        #expect(result.xomoFigmaSourceID == "1:60")
        #expect(result.xomoFigmaNodeType == "BOOLEAN_OPERATION")

        var sourceDocument = ImageEditorDocument(sourceName: "Figma Boolean", image: result.image)
        sourceDocument.canvasSize = CGSize(width: 240, height: 160)
        sourceDocument.layers = materialized.layers
        sourceDocument.selectedLayerID = result.id
        sourceDocument.selectedLayerIDs = [result.id]
        let project = try ImageEditorProjectDocument(document: sourceDocument)
        let restoredDocument = try project.restoredDocument()
        #expect(restoredDocument.layers.first?.xomoFigmaSourceID == "1:60")
        #expect(restoredDocument.layers.first?.xomoFigmaNodeType == "BOOLEAN_OPERATION")
    }

    @Test func mapperPreservesOrthogonalVectorTransformAndMaterializesRotatedGeometry() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Rotated Vector",
                  "nodes": {
                    "1:70": {
                      "document": {
                        "id": "1:70",
                        "name": "Rotated Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                        "children": [
                          {
                            "id": "2:70",
                            "name": "Quarter Turn",
                            "type": "VECTOR",
                            "absoluteBoundingBox": {"x": 10, "y": 20, "width": 10, "height": 20},
                            "size": {"width": 20, "height": 10},
                            "relativeTransform": [[0, -1, 10], [1, 0, 0]],
                            "fills": [{"type": "SOLID", "color": {"r": 0.1, "g": 0.4, "b": 0.8, "a": 1}}],
                            "fillGeometry": [{"path": "M 0 0 L 20 0 L 0 10 Z"}]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:70")
        let vector = try #require(plan.items.first { $0.sourceID == "2:70" })
        #expect(vector.relativeTransform == XomoFigmaPlanTransform([[0, -1, 10], [1, 0, 0]]))
        #expect(!vector.issues.contains(.transformFlattened))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let layer = try #require(materialized.layers.first { $0.name == "Quarter Turn" })
        let points = try #require(layer.shapeContent?.pathPoints)
        #expect(points.count == 3)
        #expect(abs(points[0].x - 10) < 0.001)
        #expect(abs(points[0].y) < 0.001)
        #expect(abs(points[1].x - 10) < 0.001)
        #expect(abs(points[1].y - 20) < 0.001)
        #expect(abs(points[2].x) < 0.001)
        #expect(abs(points[2].y) < 0.001)
    }

    @Test func mapperStillReportsShearedVectorTransformAsFlattened() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Sheared Vector",
                  "nodes": {
                    "1:71": {
                      "document": {
                        "id": "1:71",
                        "name": "Sheared Vector",
                        "type": "VECTOR",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 20, "height": 20},
                        "size": {"width": 20, "height": 20},
                        "relativeTransform": [[1, 0.5, 0], [0, 1, 0]],
                        "fillGeometry": [{"path": "M 0 0 L 20 0 L 0 20 Z"}]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:71")
        let vector = try #require(plan.items.first)
        #expect(vector.issues.contains(.transformFlattened))
    }

    @Test func mapperPreservesFrameClipsContentAsEditableGroupMask() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Clipped Card",
                  "nodes": {
                    "1:80": {
                      "document": {
                        "id": "1:80",
                        "name": "Clipped Card",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 20, "y": 20, "width": 40, "height": 40},
                        "clipsContent": true,
                        "children": [
                          {
                            "id": "2:80",
                            "name": "Overflowing Content",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 0, "y": 0, "width": 80, "height": 80},
                            "fills": [{"type": "SOLID", "color": {"r": 0.2, "g": 0.7, "b": 0.9, "a": 1}}]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:80")
        let group = try #require(plan.items.first { $0.sourceID == "1:80" })
        #expect(group.clipsContent)
        #expect(!group.issues.contains(.clippingFlattened))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let layer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "1:80" })
        #expect(layer.isGroup)
        #expect(layer.mask?.size == CGSize(width: 200, height: 200))
    }

    @Test func mapperPreservesSimpleRectangleMaskOnSubsequentSiblings() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Masked Group",
                  "nodes": {
                    "1:81": {
                      "document": {
                        "id": "1:81",
                        "name": "Masked Group",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                        "children": [
                          {
                            "id": "2:80",
                            "name": "Before Mask",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                            "fills": [{"type": "SOLID", "color": {"r": 0.1, "g": 0.2, "b": 0.9, "a": 1}}]
                          },
                          {
                            "id": "2:81",
                            "name": "Mask Rectangle",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 20, "width": 60, "height": 60},
                            "isMask": true,
                            "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}]
                          },
                          {
                            "id": "2:82",
                            "name": "Masked Content",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                            "fills": [{"type": "SOLID", "color": {"r": 0.9, "g": 0.2, "b": 0.1, "a": 1}}]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:81")
        let group = try #require(plan.items.first { $0.sourceID == "1:81" })
        let before = try #require(plan.items.first { $0.sourceID == "2:80" })
        let mask = try #require(plan.items.first { $0.sourceID == "2:81" })
        let after = try #require(plan.items.first { $0.sourceID == "2:82" })
        #expect(group.maskFrame == XomoFigmaPlanRect(x: 20, y: 20, width: 60, height: 60))
        #expect(!group.issues.contains(.maskFlattened))
        #expect(before.siblingMaskFrame == nil)
        #expect(mask.isMask)
        #expect(!mask.issues.contains(.maskFlattened))
        #expect(after.siblingMaskFrame == group.maskFrame)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let groupLayer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "1:81" })
        let beforeLayer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "2:80" })
        let maskLayer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "2:81" })
        let afterLayer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "2:82" })
        #expect(groupLayer.mask == nil)
        #expect(beforeLayer.mask == nil)
        #expect(afterLayer.mask?.size == afterLayer.image.size)
        let insideMask = try #require(afterLayer.effectiveMask?.color(at: CGPoint(x: afterLayer.image.size.width / 2, y: afterLayer.image.size.height / 2)))
        let outsideMask = try #require(afterLayer.effectiveMask?.color(at: .zero))
        #expect(insideMask.alphaComponent > 0.9)
        #expect(outsideMask.alphaComponent < 0.1)
        #expect(!maskLayer.isVisible)
    }

    @Test func mapperPreservesSimpleEllipseMaskOnSubsequentSiblings() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Elliptical Masked Group",
                  "nodes": {
                    "1:83": {
                      "document": {
                        "id": "1:83",
                        "name": "Elliptical Masked Group",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                        "children": [
                          {
                            "id": "2:83",
                            "name": "Ellipse Mask",
                            "type": "ELLIPSE",
                            "absoluteBoundingBox": {"x": 20, "y": 30, "width": 60, "height": 40},
                            "isMask": true,
                            "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}]
                          },
                          {
                            "id": "2:84",
                            "name": "Elliptical Content",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 100},
                            "fills": [{"type": "SOLID", "color": {"r": 0.9, "g": 0.2, "b": 0.1, "a": 1}}]
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:83")
        let group = try #require(plan.items.first { $0.sourceID == "1:83" })
        let mask = try #require(plan.items.first { $0.sourceID == "2:83" })
        let content = try #require(plan.items.first { $0.sourceID == "2:84" })
        #expect(group.maskShape == .ellipse)
        #expect(mask.maskShape == .ellipse)
        #expect(content.siblingMaskShape == .ellipse)
        #expect(!group.issues.contains(.maskFlattened))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let contentLayer = try #require(materialized.layers.first { $0.xomoFigmaSourceID == "2:84" })
        let inside = try #require(contentLayer.effectiveMask?.color(at: CGPoint(x: contentLayer.image.size.width / 2, y: contentLayer.image.size.height / 2)))
        let corner = try #require(contentLayer.effectiveMask?.color(at: .zero))
        #expect(inside.alphaComponent > 0.9)
        #expect(corner.alphaComponent < 0.1)
    }

    @Test func mapperReportsPartialImageComponentLayoutAndUnsupportedNodes() async throws {
        let transport = RecordingFigmaNodeTransport(statusCode: 200, body: Self.validNodeResponse)
        let client = XomoFigmaNodeContentAPIClient(transport: transport)
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3"
        )

        let plan = try await client.fetchPlan(for: preview, credential: token)
        let image = try #require(plan.items.first { $0.sourceID == "2:6" })
        let component = try #require(plan.items.first { $0.sourceID == "2:7" })
        let unsupported = try #require(plan.items.first { $0.sourceID == "2:8" })

        #expect(image.targetKind == .imagePlaceholder)
        #expect(image.fidelity == .partial)
        #expect(image.issues.contains(.imageAssetPending))
        #expect(image.imageReference == "img-ref-1")
        #expect(component.targetKind == .group)
        #expect(component.fidelity == .partial)
        #expect(component.componentRole == .component)
        #expect(component.componentProperties["Size"] == XomoFigmaComponentProperty(
            type: "VARIANT",
            value: "Large",
            preferredValues: [
                XomoFigmaComponentPreferredValue(key: "Small", name: "Small"),
                XomoFigmaComponentPreferredValue(key: "Large", name: "Large")
            ]
        ))
        #expect(component.componentProperties["Is Enabled"]?.value == "true")
        #expect(component.issues.contains(.componentSemanticsFlattened))
        #expect(!component.issues.contains(.autoLayoutFlattened))
        #expect(component.stackLayout == ImageEditorStackLayout(
            axis: .vertical,
            spacing: 12,
            paddingTop: 8,
            paddingRight: 16,
            paddingBottom: 8,
            paddingLeft: 16,
            primaryAlignment: .center,
            crossAlignment: .end,
            primarySizingMode: .hug,
            crossSizingMode: .hug
        ))
        #expect(unsupported.targetKind == nil)
        #expect(unsupported.fidelity == .unsupported)
        #expect(unsupported.issues == [.unsupportedNodeType])
        #expect(plan.exactCount == 6)
        #expect(plan.partialCount == 2)
        #expect(plan.unsupportedCount == 1)
    }

    @Test func mapperKeepsUniformCornersAndReportsIndependentOrSmoothedCorners() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Corners",
                  "nodes": {
                    "1:20": {
                      "document": {
                        "id": "1:20",
                        "name": "Corners Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 320, "height": 240},
                        "children": [
                          {
                            "id": "2:20",
                            "name": "Uniform",
                            "type": "RECTANGLE",
                            "rectangleCornerRadii": [6, 6, 6, 6],
                            "absoluteBoundingBox": {"x": 10, "y": 10, "width": 100, "height": 40}
                          },
                          {
                            "id": "2:21",
                            "name": "Independent",
                            "type": "RECTANGLE",
                            "rectangleCornerRadii": [4, 8, 12, 16],
                            "absoluteBoundingBox": {"x": 10, "y": 70, "width": 100, "height": 40}
                          },
                          {
                            "id": "2:22",
                            "name": "Smoothed",
                            "type": "RECTANGLE",
                            "cornerRadius": 10,
                            "cornerSmoothing": 0.6,
                            "absoluteBoundingBox": {"x": 10, "y": 130, "width": 100, "height": 40}
                          }
                        ]
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:20")
        let uniform = try #require(plan.items.first { $0.sourceID == "2:20" })
        let independent = try #require(plan.items.first { $0.sourceID == "2:21" })
        let smoothed = try #require(plan.items.first { $0.sourceID == "2:22" })

        #expect(uniform.cornerRadius == 6)
        #expect(uniform.fidelity == .exact)
        #expect(!uniform.issues.contains(.cornerRadiusFlattened))
        #expect(independent.cornerRadius == nil)
        #expect(independent.cornerRadii == XomoFigmaPlanCornerRadii(
            topLeft: 4,
            topRight: 8,
            bottomRight: 12,
            bottomLeft: 16
        ))
        #expect(independent.fidelity == .exact)
        #expect(!independent.issues.contains(.cornerRadiusFlattened))
        #expect(smoothed.cornerRadius == 10)
        #expect(smoothed.cornerSmoothing == 0.6)
        #expect(smoothed.fidelity == .partial)
        #expect(smoothed.issues.contains(.cornerRadiusFlattened))

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let independentLayer = try #require(
            materialized.layers.first { $0.name == "Independent" }
        )
        let smoothedLayer = try #require(
            materialized.layers.first { $0.name == "Smoothed" }
        )
        let scale = independentLayer.frame.width / 100
        #expect(independentLayer.shapeContent?.cornerRadii == ImageEditorRectangleCornerRadii(
            topLeft: 4 * scale,
            topRight: 8 * scale,
            bottomRight: 12 * scale,
            bottomLeft: 16 * scale
        ))
        #expect(smoothedLayer.shapeContent?.cornerSmoothing == 0.6)
    }

    @Test func mapperUsesStrokeGeometryAndReportsInheritedRotatedTransform() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Rotated",
                  "nodes": {
                    "1:9": {
                      "document": {
                        "id": "1:9",
                        "name": "Rotated Frame",
                        "type": "FRAME",
                        "clipsContent": true,
                        "relativeTransform": [[0, -1, 100], [1, 0, 200]],
                        "absoluteBoundingBox": {"x": 100, "y": 200, "width": 80, "height": 120},
                        "children": [{
                          "id": "2:9",
                          "name": "Stroke Only",
                          "type": "LINE",
                          "size": {"width": 40, "height": 1},
                          "strokes": [{"type": "SOLID", "color": {"r": 1, "g": 0, "b": 0}}],
                          "strokeWeight": 3,
                          "strokeGeometry": [{"path": "M 0 0 L 40 0"}],
                          "absoluteBoundingBox": {"x": 110, "y": 210, "width": 40, "height": 3}
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:9")
        let frame = try #require(plan.items.first { $0.sourceID == "1:9" })
        let line = try #require(plan.items.first { $0.sourceID == "2:9" })

        #expect(frame.fidelity == .partial)
        #expect(frame.issues.contains(.transformFlattened))
        #expect(frame.issues.contains(.clippingFlattened))
        #expect(line.targetKind == .vector)
        #expect(line.vectorPaths == ["M 0 0 L 40 0"])
        #expect(line.issues.contains(.transformFlattened))
        #expect(line.solidStroke?.red == 1)
        #expect(line.strokeWeight == 3)
    }

    @Test func mapperAndMaterializerPreserveFigmaStrokeCapAndJoin() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Stroke Styles",
                  "nodes": {
                    "1:20": {
                      "document": {
                        "id": "1:20",
                        "name": "Stroke Styles",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 160, "height": 120},
                        "children": [{
                          "id": "2:20",
                          "name": "Bevel Square",
                          "type": "RECTANGLE",
                          "fills": [],
                          "strokes": [{"type": "SOLID", "color": {"r": 0, "g": 0, "b": 0, "a": 1}}],
                          "strokeWeight": 6,
                          "strokeAlign": "OUTSIDE",
                          "strokeCap": "SQUARE",
                          "strokeJoin": "BEVEL",
                          "strokeDashes": [6, 3],
                          "absoluteBoundingBox": {"x": 20, "y": 20, "width": 80, "height": 48}
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:20")
        let item = try #require(plan.items.first { $0.sourceID == "2:20" })
        #expect(item.strokeCap == "SQUARE")
        #expect(item.strokeJoin == "BEVEL")
        #expect(item.strokeDashes == [6, 3])
        #expect(item.strokeAlign == "OUTSIDE")

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 320, height: 240)
        )
        let layer = try #require(materialized.layers.first { $0.name == "Bevel Square" })
        #expect(layer.shapeContent?.strokeCap == .square)
        #expect(layer.shapeContent?.strokeJoin == .bevel)
        #expect(layer.shapeContent?.strokeDashPattern == [6 * (layer.frame.width / 80), 3 * (layer.frame.width / 80)])
        #expect(layer.shapeContent?.strokePosition == .outside)

        var noneItem = item
        noneItem.strokeCap = "NONE"
        let noneLayer = XomoFigmaNodeMaterializer.materialize(
            plan: XomoFigmaNodeImportPlan(
                fileName: "stroke.json",
                version: nil,
                rootSourceID: "2:20",
                rootName: "Bevel Square",
                items: [noneItem]
            ),
            canvasSize: CGSize(width: 320, height: 240)
        ).layers.first
        #expect(noneLayer?.shapeContent?.strokeCap == .butt)
    }

    @Test func mapperImportsHorizontalWrapAndCounterSpacingWithFillChildSemantics() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Wrapped",
                  "nodes": {
                    "1:10": {
                      "document": {
                        "id": "1:10",
                        "name": "Wrapped Frame",
                        "type": "FRAME",
                        "layoutMode": "HORIZONTAL",
                        "layoutWrap": "WRAP",
                        "primaryAxisSizingMode": "FIXED",
                        "itemSpacing": 6,
                        "counterAxisSpacing": 14,
                        "counterAxisAlignContent": "AUTO",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 200, "height": 100},
                        "children": [{
                          "id": "1:11",
                          "name": "Fill Child",
                          "type": "RECTANGLE",
                          "layoutGrow": 1,
                          "layoutAlign": "STRETCH",
                          "absoluteBoundingBox": {"x": 0, "y": 0, "width": 40, "height": 20}
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:10")
        let frame = try #require(plan.items.first { $0.sourceID == "1:10" })
        let child = try #require(plan.items.first { $0.sourceID == "1:11" })
        #expect(frame.stackLayout?.axis == .horizontal)
        #expect(frame.stackLayout?.spacing == 6)
        #expect(frame.stackLayout?.wrapMode == .wrap)
        #expect(frame.stackLayout?.counterSpacing == 14)
        #expect(!frame.issues.contains(.autoLayoutFlattened))
        #expect(!child.issues.contains(.autoLayoutFlattened))
        #expect(child.stackChildLayout == ImageEditorStackChildLayout(
            grow: 1,
            stretchesCrossAxis: true
        ))
    }

    @Test func mapperSupportsHorizontalBaselineAndReportsUnknownTrackDistribution() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Unsupported wrapped alignment",
                  "nodes": {
                    "1:12": {
                      "document": {
                        "id": "1:12",
                        "name": "Baseline Wrap",
                        "type": "FRAME",
                        "layoutMode": "HORIZONTAL",
                        "layoutWrap": "WRAP",
                        "counterAxisAlignItems": "BASELINE",
                        "counterAxisAlignContent": "SPACE_AROUND",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 200, "height": 100}
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:12")
        let frame = try #require(plan.items.first)
        #expect(frame.stackLayout?.wrapMode == .wrap)
        #expect(frame.stackLayout?.crossAlignment == .baseline)
        #expect(frame.issues.contains(.autoLayoutFlattened))
        #expect(frame.fidelity == .partial)
    }

    @Test func mapperImportsHorizontalWrappedSpaceBetweenTracksAsNativeLayout() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Space between rows",
                  "nodes": {
                    "1:15": {
                      "document": {
                        "id": "1:15",
                        "name": "Wrapped distribution",
                        "type": "FRAME",
                        "layoutMode": "HORIZONTAL",
                        "layoutWrap": "WRAP",
                        "counterAxisAlignContent": "SPACE_BETWEEN",
                        "counterAxisSpacing": 12,
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 240, "height": 180}
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:15")
        let frame = try #require(plan.items.first)
        #expect(frame.stackLayout?.wrapMode == .wrap)
        #expect(frame.stackLayout?.crossTrackAlignment == .spaceBetween)
        #expect(frame.stackLayout?.counterSpacing == 12)
        #expect(!frame.issues.contains(.autoLayoutFlattened))
        #expect(frame.fidelity == .exact)
    }

    @Test func mapperPreservesFigmaVariableBindingsAndProjectRoundTrip() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Variable bindings",
                  "nodes": {
                    "1:16": {
                      "document": {
                        "id": "1:16",
                        "name": "Token Button",
                        "type": "RECTANGLE",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 120, "height": 44},
                        "fills": [{"type": "SOLID", "color": {"r": 0.2, "g": 0.4, "b": 0.8}}],
                        "boundVariables": {
                          "fills": [{"type": "VARIABLE_ALIAS", "id": "VariableID:brand-fill"}],
                          "characters": {"type": "VARIABLE_ALIAS", "id": "VariableID:body-font"}
                        }
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:16")
        let item = try #require(plan.items.first)
        #expect(item.variableBindings == [
            XomoFigmaVariableBinding(field: "fills", variableID: "VariableID:brand-fill"),
            XomoFigmaVariableBinding(field: "characters", variableID: "VariableID:body-font")
        ])
        #expect(item.issues.contains(.variableBindingPreserved))
        #expect(item.fidelity == .partial)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let layer = try #require(materialized.layers.first)
        #expect(layer.xomoFigmaVariableBindings == item.variableBindings)

        var document = ImageEditorDocument(
            sourceName: "variables.png",
            image: NSImage.transparent(size: CGSize(width: 400, height: 300))
        )
        document.layers.append(contentsOf: materialized.layers)
        let project = try ImageEditorProjectDocument(document: document)
        let restored = try project.restoredDocument()
        let restoredLayer = try #require(restored.layers.first { $0.id == layer.id })
        #expect(restoredLayer.xomoFigmaVariableBindings == item.variableBindings)
    }

    @Test func imageFillSourceMetadataSurvivesMaterializationAndProjectRoundTrip() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Image metadata",
                  "nodes": {
                    "1:17": {
                      "document": {
                        "id": "1:17",
                        "name": "Hero",
                        "type": "RECTANGLE",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 240, "height": 120},
                        "fills": [{
                          "type": "IMAGE",
                          "imageRef": "img-ref-hero",
                          "scaleMode": "CROP",
                          "imageTransform": [[0.8, 0.1, 0.12], [-0.1, 0.9, 0.08]],
                          "scalingFactor": 1.5,
                          "rotation": 90,
                          "filters": {
                            "exposure": 0.25,
                            "contrast": -0.2,
                            "saturation": 0.1
                          }
                        }]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:17"
        )
        let item = try #require(plan.items.first)
        #expect(item.targetKind == .imagePlaceholder)
        #expect(item.imageReference == "img-ref-hero")
        let transform = try #require(item.imageTransform)
        #expect(transform.translationX == 0.12)
        #expect(item.imageFilters.exposure == 0.25)

        let materialized = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let layer = try #require(materialized.layers.first)
        let metadata = try #require(layer.xomoFigmaImageFill)
        #expect(metadata.imageReference == "img-ref-hero")
        #expect(metadata.scaleMode == "CROP")
        #expect(metadata.imageTransform == item.imageTransform)
        #expect(metadata.scalingFactor == 1.5)
        #expect(metadata.rotation == 90)
        #expect(metadata.filters == item.imageFilters)

        var document = ImageEditorDocument(
            sourceName: "image-metadata.png",
            image: NSImage.transparent(size: CGSize(width: 400, height: 300))
        )
        document.layers.append(contentsOf: materialized.layers)
        let project = try ImageEditorProjectDocument(document: document)
        let restored = try project.restoredDocument()
        let restoredLayer = try #require(restored.layers.first { $0.id == layer.id })
        #expect(restoredLayer.xomoFigmaImageFill == metadata)
    }

    @Test func figmaVariablesResolveDefaultModeColorsAndAliases() async throws {
        let transport = RecordingFigmaNodeTransport(
            statusCode: 200,
            body: Data(
                """
                {
                  "meta": {
                    "variables": {
                      "VariableID:brand-fill": {
                        "id": "VariableID:brand-fill",
                        "name": "Brand Fill",
                        "variableCollectionId": "CollectionID:tokens",
                        "resolvedType": "COLOR",
                        "valuesByMode": {
                          "ModeID:default": {"type": "VARIABLE_ALIAS", "id": "VariableID:brand-base"}
                        }
                      },
                      "VariableID:brand-base": {
                        "id": "VariableID:brand-base",
                        "name": "Brand Base",
                        "variableCollectionId": "CollectionID:tokens",
                        "resolvedType": "COLOR",
                        "valuesByMode": {
                          "ModeID:default": {"r": 0.1, "g": 0.3, "b": 0.8, "a": 0.9}
                        }
                      }
                    },
                    "variableCollections": {
                      "CollectionID:tokens": {
                        "id": "CollectionID:tokens",
                        "name": "Tokens",
                        "defaultModeId": "ModeID:default",
                        "modes": [{"modeId": "ModeID:default", "name": "Default"}]
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        let credential = try XomoFigmaPersonalAccessToken(validating: "figma-test-token")
        let client = XomoFigmaVariableAPIClient(
            baseURL: URL(string: "https://example.test")!,
            transport: transport
        )

        let store = try await client.fetchVariables(fileKey: "file-key", credential: credential)
        #expect(store.color(for: "VariableID:brand-fill") == XomoFigmaPlanColor(
            red: 0.1, green: 0.3, blue: 0.8, alpha: 0.9
        ))
        #expect(transport.lastRequest?.url?.path == "/v1/files/file-key/variables/local")
        #expect(transport.lastRequest?.value(forHTTPHeaderField: "X-Figma-Token") == credential.rawValue)

        let item = XomoFigmaNodeImportItem(
            sourceID: "node",
            parentSourceID: nil,
            depth: 0,
            sourceName: "Token",
            sourceType: "RECTANGLE",
            targetKind: .rectangle,
            fidelity: .partial,
            issues: [.variableBindingPreserved],
            variableBindings: [XomoFigmaVariableBinding(field: "fills", variableID: "VariableID:brand-fill")],
            frame: XomoFigmaPlanRect(x: 0, y: 0, width: 20, height: 20),
            opacity: 1,
            isVisible: true,
            solidFill: XomoFigmaPlanColor(red: 1, green: 1, blue: 1, alpha: 1),
            solidStroke: nil,
            strokeWeight: nil,
            cornerRadius: nil,
            text: nil,
            vectorPaths: [],
            geometrySize: nil,
            relativeTransform: nil,
            clipsContent: false,
            isMask: false,
            maskFrame: nil,
            imageReference: nil,
            imageScaleMode: nil,
            imageTransform: nil,
            imageScalingFactor: nil,
            imageRotation: nil,
            stackLayout: nil,
            stackChildLayout: nil,
            isStackLayoutExcluded: false
        )
        let plan = XomoFigmaNodeImportPlan(
            fileName: "Variables",
            version: nil,
            rootSourceID: "node",
            rootName: "Token",
            items: [item]
        )
        let resolved = try #require(plan.resolvingVariables(store).items.first)
        #expect(resolved.solidFill == XomoFigmaPlanColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 0.9))
        #expect(resolved.issues.isEmpty)
        #expect(resolved.fidelity == .exact)
    }

    @Test func mapperImportsHorizontalBaselineAsEditableNativeLayout() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Baseline row",
                  "nodes": {
                    "1:13": {
                      "document": {
                        "id": "1:13",
                        "name": "Baseline Row",
                        "type": "FRAME",
                        "layoutMode": "HORIZONTAL",
                        "counterAxisAlignItems": "BASELINE",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 200, "height": 80}
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:13")
        let frame = try #require(plan.items.first)
        #expect(frame.stackLayout?.axis == .horizontal)
        #expect(frame.stackLayout?.crossAlignment == .baseline)
        #expect(!frame.issues.contains(.autoLayoutFlattened))
        #expect(frame.fidelity == .exact)
    }

    @Test func mapperKeepsInvalidVerticalBaselineAsExplicitDowngrade() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Invalid baseline column",
                  "nodes": {
                    "1:14": {
                      "document": {
                        "id": "1:14",
                        "name": "Baseline Column",
                        "type": "FRAME",
                        "layoutMode": "VERTICAL",
                        "counterAxisAlignItems": "BASELINE",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 100, "height": 200}
                      }
                    }
                  }
                }
                """.utf8
            )
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:14")
        let frame = try #require(plan.items.first)
        #expect(frame.stackLayout?.axis == .vertical)
        #expect(frame.stackLayout?.crossAlignment == .start)
        #expect(frame.issues.contains(.autoLayoutFlattened))
        #expect(frame.fidelity == .partial)
    }

    @Test func clientMapsBadRequestAuthorizationMissingNodeRateLimitAndServerErrors() async throws {
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3"
        )
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let expectations: [(Int, XomoFigmaNodeImportError)] = [
            (400, .invalidRequest),
            (401, .authorizationDenied),
            (403, .authorizationDenied),
            (404, .fileNotFound),
            (429, .rateLimited),
            (503, .serviceUnavailable)
        ]

        for (statusCode, expectedError) in expectations {
            let client = XomoFigmaNodeContentAPIClient(
                transport: RecordingFigmaNodeTransport(statusCode: statusCode, body: Data())
            )
            await #expect(throws: expectedError) {
                try await client.fetchPlan(for: preview, credential: token)
            }
        }
    }

    @Test func clientRejectsMissingNodeOversizedResponsesAndExcessiveTrees() async throws {
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3"
        )
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let missingNode = Data(#"{"name":"Checkout","nodes":{"1:3":null}}"#.utf8)
        let oversized = Data(repeating: 65, count: XomoFigmaNodeContentAPIClient.maximumResponseBytes + 1)
        let tooManyChildren = (0...XomoFigmaNodeImportMapper.maximumNodeCount).map {
            #"{"id":"9:\#($0)","name":"N","type":"RECTANGLE","absoluteBoundingBox":{"x":0,"y":0,"width":1,"height":1}}"#
        }.joined(separator: ",")
        let excessiveTree = Data(
            #"{"name":"Checkout","nodes":{"1:3":{"document":{"id":"1:3","name":"Root","type":"FRAME","absoluteBoundingBox":{"x":0,"y":0,"width":10,"height":10},"children":[\#(tooManyChildren)]}}}}"#.utf8
        )

        await #expect(throws: XomoFigmaNodeImportError.nodeNotFound) {
            try await XomoFigmaNodeContentAPIClient(
                transport: RecordingFigmaNodeTransport(statusCode: 200, body: missingNode)
            ).fetchPlan(for: preview, credential: token)
        }
        await #expect(throws: XomoFigmaNodeImportError.responseTooLarge) {
            try await XomoFigmaNodeContentAPIClient(
                transport: RecordingFigmaNodeTransport(statusCode: 200, body: oversized)
            ).fetchPlan(for: preview, credential: token)
        }
        await #expect(throws: XomoFigmaNodeImportError.nodeLimitExceeded) {
            try await XomoFigmaNodeContentAPIClient(
                transport: RecordingFigmaNodeTransport(statusCode: 200, body: excessiveTree)
            ).fetchPlan(for: preview, credential: token)
        }
    }

    @Test func controllerDoesNotReadUntilExplicitUserActionAndClearsStalePlan() async throws {
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-test-token_12345")
        let store = InMemoryFigmaNodeCredentialStore(credential: token)
        let fetcher = RecordingFigmaNodePlanFetcher(result: .success(Self.samplePlan))
        let controller = XomoFigmaNodeImportController(store: store, fetcher: fetcher)
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Checkout?node-id=1-3"
        )

        #expect(fetcher.calls.isEmpty)
        #expect(controller.state == .idle)

        await controller.fetchPlan(preview: preview)

        #expect(fetcher.calls == ["1:3"])
        #expect(controller.state == .loaded(Self.samplePlan))

        controller.clear()
        #expect(controller.state == .idle)
    }

    @Test func sheetMakesNodeReadExplicitAndRequiresNodeSelection() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sheet = try String(
            contentsOf: root.appendingPathComponent("veilpic/XomoFigmaLinkImportSheet.swift"),
            encoding: .utf8
        )

        #expect(sheet.contains("XomoFigmaNodeImportController"))
        #expect(sheet.contains("xomo-figma-read-node-plan"))
        #expect(sheet.contains("preview.nodeID == nil"))
        #expect(sheet.contains("await nodeImportController.fetchPlan(preview: preview)"))
        #expect(sheet.contains("viewModel.importFigmaNodePlan(plan)"))
        #expect(sheet.contains("xomo-figma-import-node-plan"))
        #expect(!sheet.contains(".onChange(of: draft.preview) { await nodeImportController.fetchPlan"))
    }

    @Test nonisolated func svgParserSupportsRelativeCurvesQuadraticsAndArcs() throws {
        let result = try #require(XomoSVGPathParser.parse(
            "M 0 0 l 20 0 q 10 0 10 10 t 10 10 a 10 10 0 0 1 10 10 z"
        ))
        let anchors = try #require(result.subpaths.first)

        #expect(result.isClosed)
        #expect(anchors.count >= 5)
        #expect(anchors.first?.point == .zero)
        #expect(anchors[1].point == CGPoint(x: 20, y: 0))
        #expect(anchors[1].outControl != nil)
        #expect(anchors.last?.point == CGPoint(x: 50, y: 30))
        #expect(XomoSVGPathParser.parse("M 0 0 B 10 10") == nil)
        #expect(XomoSVGPathParser.parse("M 0 0 C 1 2") == nil)
    }

    @Test func supportedFigmaShadowsBecomeEditableLayerEffects() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Effects",
                  "nodes": {
                    "1:40": {
                      "document": {
                        "id": "1:40",
                        "name": "Effects Frame",
                        "type": "FRAME",
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 240, "height": 160},
                        "children": [
                          {
                            "id": "2:40",
                            "name": "Shadowed Card",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 20, "width": 120, "height": 48},
                            "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}],
                            "effects": [
                              {"type": "DROP_SHADOW", "color": {"r": 0.1, "g": 0.2, "b": 0.3, "a": 0.45}, "offset": {"x": 4, "y": 6}, "radius": 8, "spread": 2, "visible": true},
                              {"type": "INNER_SHADOW", "color": {"r": 0.8, "g": 0.1, "b": 0.2, "a": 0.25}, "offset": {"x": -2, "y": 3}, "radius": 4, "visible": true}
                            ]
                          },
                          {
                            "id": "2:41",
                            "name": "Blurred Card",
                            "type": "RECTANGLE",
                            "absoluteBoundingBox": {"x": 20, "y": 90, "width": 120, "height": 48},
                            "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}],
                            "effects": [
                              {"type": "LAYER_BLUR", "radius": 6, "visible": true},
                              {"type": "BACKGROUND_BLUR", "radius": 4, "visible": true}
                            ]
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
            requestedNodeID: "1:40"
        )
        let shadowed = try #require(plan.items.first { $0.sourceID == "2:40" })
        #expect(shadowed.effects.count == 2)
        #expect(shadowed.fidelity == .exact)
        #expect(!shadowed.issues.contains(.effectsFlattened))
        let blurred = try #require(plan.items.first { $0.sourceID == "2:41" })
        #expect(blurred.effects.count == 2)
        #expect(blurred.effects.map(\.kind) == [.layerBlur, .backgroundBlur])
        #expect(blurred.fidelity == .exact)
        #expect(!blurred.issues.contains(.effectsFlattened))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 400, height: 300)
        )
        let layer = try #require(result.layers.first { $0.name == "Shadowed Card" })
        #expect(layer.style.shadowEnabled)
        #expect(layer.style.innerShadowEnabled)
        #expect(abs(layer.style.shadowBlur - 8) < 0.001)
        #expect(abs(layer.style.shadowSpread - 2) < 0.001)
        #expect(abs(layer.style.shadowOffset.width - 4) < 0.001)
        #expect(abs(layer.style.shadowOffset.height - 6) < 0.001)
        #expect(abs(layer.style.innerShadowDistance - sqrt(13)) < 0.001)
        let blurredLayer = try #require(result.layers.first { $0.name == "Blurred Card" })
        #expect(blurredLayer.smartFilters.count == 2)
        #expect(blurredLayer.smartFilters.first?.kind == .gaussianBlur)
        #expect(blurredLayer.smartFilters.first?.normalizedSettings.gaussianBlurRadius == 6)
        #expect(blurredLayer.smartFilters.first?.appliesToBackdrop == false)
        #expect(blurredLayer.smartFilters.last?.kind == .gaussianBlur)
        #expect(blurredLayer.smartFilters.last?.normalizedSettings.gaussianBlurRadius == 4)
        #expect(blurredLayer.smartFilters.last?.appliesToBackdrop == true)
    }

    @Test func materializerCreatesEditableHierarchyAtCenteredScaleAndHonestPlaceholder() throws {
        let plan = try Self.decodedPlan()
        let textPlan = try #require(plan.items.first { $0.sourceName == "Continue Label" })
        #expect(textPlan.text?.characters == "CONTINUE 继续")
        #expect(textPlan.fidelity == .partial)
        #expect(textPlan.issues.contains(.textCaseFlattened))
        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 600, height: 1_000)
        )
        let root = try #require(result.layers.first { $0.name == "Checkout Frame" })
        let rootBackground = try #require(
            result.layers.first { $0.name == L10n.format("imageEditor.layer.figmaFrameBackground", "Checkout Frame") }
        )
        let actions = try #require(result.layers.first { $0.name == "Actions" })
        let text = try #require(result.layers.first { $0.name == "Continue Label" })
        let rectangle = try #require(result.layers.first { $0.name == "Primary" })
        let vector = try #require(result.layers.first { $0.name == "Arrow" })
        let placeholder = try #require(result.layers.first { $0.name == "Hero Image" })
        let component = try #require(result.layers.first { $0.name == "Card Component" })

        #expect(result.importedCount == 9)
        #expect(result.omittedCount == 1)
        #expect(result.selectedLayerID == root.id)
        #expect(result.layers.last?.id == root.id)
        #expect(root.isGroup)
        #expect(rootBackground.groupID == root.id)
        #expect(rootBackground.isStackLayoutExcluded)
        #expect(rootBackground.isStackLayoutBackground)
        #expect(actions.groupID == root.id)
        #expect(text.groupID == actions.id)
        #expect(text.stackChildLayout == ImageEditorStackChildLayout(
            grow: 1,
            stretchesCrossAxis: true
        ))
        #expect(text.frame.origin == CGPoint(x: 135, y: 138))
        if case let .text(content) = text.kind {
            #expect(content.text == "CONTINUE 继续")
            #expect(content.fontFamilyName == "Inter")
            #expect(content.fontSize == 16)
            #expect(content.isBold)
            #expect(content.isItalic)
            #expect(content.isUnderlined)
            #expect(!content.isStruckThrough)
            #expect(content.characterSpacing == -1.5)
            #expect(content.lineSpacing == 6)
            #expect(content.firstLineIndent == 12)
            #expect(content.alignment == .center)
        } else {
            Issue.record("Figma text should materialize as editable text")
        }
        #expect(rectangle.frame == CGRect(x: 125, y: 218, width: 200, height: 44))
        #expect(rectangle.opacity == 0.8)
        if case let .shape(content) = rectangle.kind {
            #expect(content.fillOpacity == 1)
            #expect(content.cornerRadius == 8)
        } else {
            Issue.record("Figma rectangle should materialize as an editable shape")
        }
        if case let .shape(content) = vector.kind {
            #expect(content.kind == .path)
            #expect(content.pathAnchors.count == 3)
            #expect(content.strokeOpacity == 1)
            #expect(content.strokeWidth == 2)
            #expect(content.isPathClosed)
        } else {
            Issue.record("Figma vector should materialize as an editable path")
        }
        #expect(placeholder.kind.isPixel)
        #expect(placeholder.frame == CGRect(x: 125, y: 348, width: 240, height: 120))
        #expect(component.frame == CGRect(x: 125, y: 488, width: 240, height: 120))
        #expect(component.stackLayout?.axis == .vertical)
        #expect(component.stackLayout?.crossAlignment == .end)
        #expect(component.stackLayout?.primarySizingMode == .hug)
        #expect(component.stackLayout?.crossSizingMode == .hug)
    }

    @Test func viewModelImportsPlanAsSingleUndoableHistoryStep() throws {
        let plan = try Self.decodedPlan()
        let viewModel = ImageEditorViewModel(
            sourceName: "figma-import.png",
            image: NSImage.transparent(size: CGSize(width: 600, height: 1_000))
        ) { _ in }
        let initialLayerCount = viewModel.document.layers.count
        let initialHistoryCount = viewModel.document.history.count

        #expect(viewModel.importFigmaNodePlan(plan))
        #expect(viewModel.document.layers.count == initialLayerCount + 9)
        #expect(viewModel.document.history.count == initialHistoryCount + 1)
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.figmaNodeImport"))
        #expect(viewModel.statusText == L10n.format("imageEditor.status.figmaNodeImported", 9, 1))
        #expect(viewModel.document.selectedLayer?.name == "Checkout Frame")

        let restored = try ImageEditorProjectDocument(document: viewModel.document).restoredDocument()
        #expect(restored.layers.count == viewModel.document.layers.count)
        let restoredRoot = try #require(restored.layers.first { $0.name == "Checkout Frame" })
        let restoredActions = try #require(restored.layers.first { $0.name == "Actions" })
        let restoredText = try #require(restored.layers.first { $0.name == "Continue Label" })
        let restoredComponent = try #require(restored.layers.first { $0.name == "Card Component" })
        #expect(restoredRoot.isGroup)
        #expect(restoredActions.groupID == restoredRoot.id)
        #expect(restoredText.groupID == restoredActions.id)
        #expect(restoredComponent.stackLayout?.axis == .vertical)
        #expect(restoredComponent.stackLayout?.spacing == 12)
        #expect(restoredComponent.stackLayout?.primarySizingMode == .hug)
        #expect(restoredComponent.stackLayout?.crossSizingMode == .hug)

        viewModel.undo()
        #expect(viewModel.document.layers.count == initialLayerCount)

        viewModel.redo()
        #expect(viewModel.document.layers.count == initialLayerCount + 9)
        #expect(viewModel.document.selectedLayer?.name == "Checkout Frame")
        #expect(viewModel.document.history.last?.title == L10n.text("imageEditor.history.figmaNodeImport"))
    }

    @Test func importedHierarchySurvivesProjectDataAndCompositeExport() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "figma-round-trip.png",
            image: NSImage.transparent(size: CGSize(width: 600, height: 1_000))
        ) { _ in }
        #expect(viewModel.importFigmaNodePlan(try Self.decodedPlan()))

        let projectData = try viewModel.projectData()
        let projectSource = try #require(String(data: projectData, encoding: .utf8))
        #expect(!projectSource.contains("figd_"))
        #expect(!projectSource.contains("X-Figma-Token"))

        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: NSImage.transparent(size: CGSize(width: 8, height: 8))
        ) { _ in }
        try reopened.loadProjectData(projectData)

        #expect(reopened.document.sourceName == "figma-round-trip.png")
        #expect(reopened.document.canvasSize == CGSize(width: 600, height: 1_000))
        #expect(reopened.document.layers.count == viewModel.document.layers.count)
        let root = try #require(reopened.document.layers.first { $0.name == "Checkout Frame" })
        let actions = try #require(reopened.document.layers.first { $0.name == "Actions" })
        let text = try #require(reopened.document.layers.first { $0.name == "Continue Label" })
        let primary = try #require(reopened.document.layers.first { $0.name == "Primary" })
        let vector = try #require(reopened.document.layers.first { $0.name == "Arrow" })
        let placeholder = try #require(reopened.document.layers.first { $0.name == "Hero Image" })
        #expect(root.isGroup)
        #expect(actions.groupID == root.id)
        #expect(text.groupID == actions.id)
        #expect(text.stackChildLayout == ImageEditorStackChildLayout(
            grow: 1,
            stretchesCrossAxis: true
        ))
        #expect(text.textContent?.text == "继续")
        #expect(primary.shapeContent?.cornerRadius == 8)
        #expect(vector.shapeContent?.kind == .path)
        #expect(vector.shapeContent?.editablePathAnchors.count == 3)
        #expect(placeholder.kind.isPixel)

        let pngData = try #require(reopened.exportData(settings: ImageEditorExportSettings(
            format: .png,
            scope: .composited,
            scale: 1
        )))
        #expect(Array(pngData.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let exportedImage = try #require(NSImage(data: pngData))
        #expect(exportedImage.size == CGSize(width: 600, height: 1_000))
        #expect(exportedImage.nonTransparentPixelBounds() != nil)
    }

    @Test func materializerOnlyShrinksOversizedRootAndKeepsItInsideCanvasInset() throws {
        let result = XomoFigmaNodeMaterializer.materialize(
            plan: try Self.decodedPlan(),
            canvasSize: CGSize(width: 300, height: 400)
        )
        let rootBackground = try #require(
            result.layers.first { $0.name == L10n.format("imageEditor.layer.figmaFrameBackground", "Checkout Frame") }
        )
        let expectedScale = 360.0 / 844.0
        let primary = try #require(result.layers.first { $0.name == "Primary" })

        #expect(abs(rootBackground.frame.height - 360) < 0.001)
        #expect(abs(rootBackground.frame.width - 390 * expectedScale) < 0.001)
        #expect(abs(rootBackground.frame.midX - 150) < 0.001)
        #expect(abs(rootBackground.frame.midY - 200) < 0.001)
        #expect(abs((primary.shapeContent?.cornerRadius ?? 0) - 8 * expectedScale) < 0.001)
    }

    @Test func viewModelInsertsImportedRootAfterExistingTopLevelGroup() throws {
        let viewModel = ImageEditorViewModel(
            sourceName: "grouped.png",
            image: NSImage.transparent(size: CGSize(width: 600, height: 1_000))
        ) { _ in }
        let group = ImageEditorLayer.group(name: "Existing Group", size: viewModel.document.canvasSize)
        var child = ImageEditorLayer.blank(name: "Existing Child", size: CGSize(width: 20, height: 20))
        child.groupID = group.id
        viewModel.document.layers = [child, group]
        viewModel.document.selectedLayerID = child.id
        viewModel.document.selectedLayerIDs = [child.id]

        #expect(viewModel.importFigmaNodePlan(try Self.decodedPlan()))
        #expect(viewModel.document.layers[0].id == child.id)
        #expect(viewModel.document.layers[1].id == group.id)
        #expect(
            viewModel.document.layers[2].name
                == L10n.format("imageEditor.layer.figmaFrameBackground", "Checkout Frame")
        )

        viewModel.undo()
        #expect(viewModel.document.layers.map(\.id) == [child.id, group.id])
    }

    private static func decodedPlan() throws -> XomoFigmaNodeImportPlan {
        let response = try JSONDecoder().decode(XomoFigmaNodeResponse.self, from: validNodeResponse)
        return try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:3")
    }

    private static let validNodeResponse = Data(
        """
        {
          "name": "Checkout",
          "lastModified": "2026-07-15T01:00:00Z",
          "version": "88",
          "nodes": {
            "1:3": {
              "document": {
                "id": "1:3",
                "name": "Checkout Frame",
                "type": "FRAME",
                "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}],
                "absoluteBoundingBox": {"x": 100, "y": 200, "width": 390, "height": 844},
                "children": [
                  {
                    "id": "2:1",
                    "name": "Actions",
                    "type": "GROUP",
                    "layoutMode": "HORIZONTAL",
                    "primaryAxisSizingMode": "FIXED",
                    "counterAxisSizingMode": "FIXED",
                    "itemSpacing": 8,
                    "absoluteBoundingBox": {"x": 120, "y": 240, "width": 200, "height": 80},
                    "children": [
                      {
                        "id": "2:2",
                        "name": "Continue Label",
                        "type": "TEXT",
                        "layoutGrow": 1,
                        "layoutAlign": "STRETCH",
                        "characters": "Continue 继续",
                        "style": {"fontFamily": "Inter", "fontSize": 16, "fontWeight": 600, "textAlignHorizontal": "CENTER", "letterSpacing": -1.5, "lineHeightPercentFontSize": 137.5, "lineHeightUnit": "FONT_SIZE_%", "italic": true, "textDecoration": "UNDERLINE", "paragraphIndent": 12, "textCase": "UPPER"},
                        "fills": [{"type": "SOLID", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}],
                        "absoluteBoundingBox": {"x": 130, "y": 260, "width": 64, "height": 24}
                      }
                    ]
                  },
                  {
                    "id": "2:3",
                    "name": "Primary",
                    "type": "RECTANGLE",
                    "opacity": 0.8,
                    "fills": [{"type": "SOLID", "color": {"r": 0.1, "g": 0.4, "b": 0.9, "a": 1}}],
                    "cornerRadius": 8,
                    "absoluteBoundingBox": {"x": 120, "y": 340, "width": 200, "height": 44}
                  },
                  {
                    "id": "2:4",
                    "name": "Avatar",
                    "type": "ELLIPSE",
                    "fills": [{"type": "SOLID", "color": {"r": 0.3, "g": 0.3, "b": 0.3, "a": 1}}],
                    "absoluteBoundingBox": {"x": 120, "y": 400, "width": 48, "height": 48}
                  },
                  {
                    "id": "2:5",
                    "name": "Arrow",
                    "type": "VECTOR",
                    "size": {"width": 20, "height": 20},
                    "relativeTransform": [[1, 0, 180], [0, 1, 400]],
                    "strokes": [{"type": "SOLID", "color": {"r": 0, "g": 0, "b": 0, "a": 1}}],
                    "strokeWeight": 2,
                    "fillGeometry": [{"path": "M 0 0 L 20 0 L 10 20 Z", "windingRule": "NONZERO"}],
                    "absoluteBoundingBox": {"x": 180, "y": 400, "width": 20, "height": 20}
                  },
                  {
                    "id": "2:6",
                    "name": "Hero Image",
                    "type": "RECTANGLE",
                    "fills": [{"type": "IMAGE", "imageRef": "img-ref-1"}],
                    "absoluteBoundingBox": {"x": 120, "y": 470, "width": 240, "height": 120}
                  },
                  {
                    "id": "2:7",
                    "name": "Card Component",
                    "type": "COMPONENT",
                    "componentProperties": {
                      "Size": {"type": "VARIANT", "value": "Large", "preferredValues": [{"key": "Small", "name": "Small"}, {"key": "Large", "name": "Large"}]},
                      "Is Enabled": {"type": "BOOLEAN", "value": "true"}
                    },
                    "layoutMode": "VERTICAL",
                    "primaryAxisSizingMode": "AUTO",
                    "counterAxisSizingMode": "AUTO",
                    "itemSpacing": 12,
                    "paddingTop": 8,
                    "paddingRight": 16,
                    "paddingBottom": 8,
                    "paddingLeft": 16,
                    "primaryAxisAlignItems": "CENTER",
                    "counterAxisAlignItems": "MAX",
                    "absoluteBoundingBox": {"x": 120, "y": 610, "width": 240, "height": 120}
                  },
                  {
                    "id": "2:8",
                    "name": "Embedded Video",
                    "type": "EMBED",
                    "absoluteBoundingBox": {"x": 120, "y": 750, "width": 240, "height": 80}
                  }
                ]
              }
            }
          }
        }
        """.utf8
    )

    private static let samplePlan = XomoFigmaNodeImportPlan(
        fileName: "Checkout",
        version: "88",
        rootSourceID: "1:3",
        rootName: "Checkout Frame",
        items: []
    )
}

private final class RecordingFigmaNodeTransport: XomoFigmaHTTPTransport {
    private(set) var lastRequest: URLRequest?
    let statusCode: Int
    let body: Data

    init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = try #require(
            HTTPURLResponse(
                url: request.url ?? URL(string: "https://api.figma.com")!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        )
        return (body, response)
    }
}

@MainActor
private final class InMemoryFigmaNodeCredentialStore: XomoFigmaCredentialStoring {
    var credential: XomoFigmaPersonalAccessToken?

    init(credential: XomoFigmaPersonalAccessToken?) {
        self.credential = credential
    }

    func load() throws -> XomoFigmaPersonalAccessToken? { credential }
    func save(_ credential: XomoFigmaPersonalAccessToken) throws { self.credential = credential }
    func delete() throws { credential = nil }
}

@MainActor
private final class RecordingFigmaNodePlanFetcher: XomoFigmaNodePlanFetching {
    private(set) var calls: [String] = []
    let result: Result<XomoFigmaNodeImportPlan, XomoFigmaNodeImportError>

    init(result: Result<XomoFigmaNodeImportPlan, XomoFigmaNodeImportError>) {
        self.result = result
    }

    func fetchPlan(
        for preview: XomoFigmaLinkPreview,
        credential: XomoFigmaPersonalAccessToken
    ) async throws -> XomoFigmaNodeImportPlan {
        calls.append(preview.nodeID ?? "")
        return try result.get()
    }
}
