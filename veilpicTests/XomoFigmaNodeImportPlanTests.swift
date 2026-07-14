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
        #expect(rectangle.fidelity == .partial)
        #expect(rectangle.issues.contains(.cornerRadiusFlattened))
        #expect(rectangle.solidFill == XomoFigmaPlanColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1))
        #expect(rectangle.opacity == 0.8)
        #expect(ellipse.targetKind == .ellipse)
        #expect(vector.targetKind == .vector)
        #expect(vector.vectorPaths == ["M 0 0 L 20 0 L 10 20 Z"])
        #expect(vector.geometrySize == XomoFigmaPlanSize(width: 20, height: 20))
        #expect(vector.solidStroke == XomoFigmaPlanColor(red: 0, green: 0, blue: 0, alpha: 1))
        #expect(vector.strokeWeight == 2)
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
        #expect(plan.exactCount == 5)
        #expect(plan.partialCount == 3)
        #expect(plan.unsupportedCount == 1)
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

    @Test func mapperReportsUnsupportedWrapWhileKeepingFillChildSemantics() throws {
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
                        "primaryAxisSizingMode": "AUTO",
                        "itemSpacing": 6,
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
        #expect(frame.issues.contains(.autoLayoutFlattened))
        #expect(!child.issues.contains(.autoLayoutFlattened))
        #expect(child.stackChildLayout == ImageEditorStackChildLayout(
            grow: 1,
            stretchesCrossAxis: true
        ))
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

    @Test func materializerCreatesEditableHierarchyAtCenteredScaleAndHonestPlaceholder() throws {
        let plan = try Self.decodedPlan()
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
            #expect(content.text == "继续")
            #expect(content.fontFamilyName == "Inter")
            #expect(content.fontSize == 16)
            #expect(content.isBold)
            #expect(content.alignment == .center)
        } else {
            Issue.record("Figma text should materialize as editable text")
        }
        #expect(rectangle.frame == CGRect(x: 125, y: 218, width: 200, height: 44))
        #expect(rectangle.opacity == 0.8)
        if case let .shape(content) = rectangle.kind {
            #expect(content.fillOpacity == 1)
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

        #expect(abs(rootBackground.frame.height - 360) < 0.001)
        #expect(abs(rootBackground.frame.width - 390 * expectedScale) < 0.001)
        #expect(abs(rootBackground.frame.midX - 150) < 0.001)
        #expect(abs(rootBackground.frame.midY - 200) < 0.001)
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
                        "characters": "继续",
                        "style": {"fontFamily": "Inter", "fontSize": 16, "fontWeight": 600, "textAlignHorizontal": "CENTER"},
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
