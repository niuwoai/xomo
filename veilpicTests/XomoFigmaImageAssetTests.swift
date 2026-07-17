import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoFigmaImageAssetTests {
    @Test func clientUsesOfficialManifestAndTokenlessHTTPSAssetRequests() async throws {
        let imageData = try Self.pngData(color: .systemRed)
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-image-test-token")
        let transport = ScriptedFigmaImageTransport { request in
            switch (request.url?.host, request.url?.path) {
            case ("api.figma.com", "/v1/files/abc123DEF456/images"):
                return (
                    Data(
                        """
                        {"images":{"img-ref-1":"https://assets.example.com/hero.png","unused":"https://assets.example.com/unused.png"}}
                        """.utf8
                    ),
                    200,
                    "application/json"
                )
            case ("assets.example.com", "/hero.png"):
                return (imageData, 200, "image/png")
            default:
                Issue.record("Unexpected image asset request: \(request.url?.absoluteString ?? "nil")")
                return (Data(), 404, "application/json")
            }
        }
        let client = XomoFigmaImageAssetAPIClient(transport: transport)

        let assets = try await client.fetchAssets(
            fileKey: "abc123DEF456",
            references: ["img-ref-1"],
            credential: token
        )

        let asset = try #require(assets["img-ref-1"])
        #expect(asset.data == imageData)
        let expectedPixelSize = try Self.pixelSize(of: imageData)
        #expect(asset.pixelSize == expectedPixelSize)
        #expect(transport.requests.count == 2)
        let manifestRequest = transport.requests[0]
        let assetRequest = transport.requests[1]
        #expect(manifestRequest.url?.path == "/v1/files/abc123DEF456/images")
        #expect(manifestRequest.value(forHTTPHeaderField: "X-Figma-Token") == token.rawValue)
        #expect(manifestRequest.url?.absoluteString.contains(token.rawValue) == false)
        #expect(assetRequest.url?.absoluteString == "https://assets.example.com/hero.png")
        #expect(assetRequest.value(forHTTPHeaderField: "X-Figma-Token") == nil)
        #expect(assetRequest.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(assetRequest.value(forHTTPHeaderField: "Cookie") == nil)
    }

    @Test func clientRejectsUnsafeOrUndecodableAssetURLsWithoutLeakingCredential() async throws {
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-image-test-token")
        let transport = ScriptedFigmaImageTransport { request in
            if request.url?.host == "api.figma.com" {
                return (
                    Data(
                        """
                        {"images":{
                          "http":"http://assets.example.com/http.png",
                          "localhost":"https://localhost/local.png",
                          "ip":"https://127.0.0.1/private.png",
                          "credential":"https://user@assets.example.com/credential.png",
                          "invalid":"https://assets.example.com/invalid.png"
                        }}
                        """.utf8
                    ),
                    200,
                    "application/json"
                )
            }
            #expect(request.url?.absoluteString == "https://assets.example.com/invalid.png")
            #expect(request.value(forHTTPHeaderField: "X-Figma-Token") == nil)
            return (Data("not-an-image".utf8), 200, "image/png")
        }
        let client = XomoFigmaImageAssetAPIClient(transport: transport)

        let assets = try await client.fetchAssets(
            fileKey: "abc123DEF456",
            references: ["http", "localhost", "ip", "credential", "invalid"],
            credential: token
        )

        #expect(assets.isEmpty)
        #expect(transport.requests.count == 2)
        #expect(transport.requests[1].value(forHTTPHeaderField: "X-Figma-Token") == nil)
    }

    @Test func nodePipelineImportsDownloadedFillAsPersistentPixelLayer() async throws {
        let imageData = try Self.pngData(color: .systemBlue)
        let token = try XomoFigmaPersonalAccessToken(validating: "figd_local-image-test-token")
        let transport = ScriptedFigmaImageTransport { request in
            switch (request.url?.host, request.url?.path) {
            case ("api.figma.com", "/v1/files/abc123DEF456/nodes"):
                return (Self.nodeResponse, 200, "application/json")
            case ("api.figma.com", "/v1/files/abc123DEF456/images"):
                return (
                    Data("{\"images\":{\"img-ref-1\":\"https://assets.example.com/hero.png\"}}".utf8),
                    200,
                    "application/json"
                )
            case ("assets.example.com", "/hero.png"):
                return (imageData, 200, "image/png")
            default:
                Issue.record("Unexpected pipeline request: \(request.url?.absoluteString ?? "nil")")
                return (Data(), 404, "application/json")
            }
        }
        let assetClient = XomoFigmaImageAssetAPIClient(transport: transport)
        let nodeClient = XomoFigmaNodeContentAPIClient(
            transport: transport,
            imageAssetFetcher: assetClient
        )
        let preview = try XomoFigmaLinkParser.parse(
            "https://www.figma.com/design/abc123DEF456/Image-Card?node-id=1-3"
        )

        let plan = try await nodeClient.fetchPlan(for: preview, credential: token)
        let rootItem = try #require(plan.items.first { $0.sourceID == "1:3" })
        let imageItem = try #require(plan.items.first { $0.sourceID == "2:1" })
        #expect(rootItem.targetKind == .group)
        #expect(plan.requiredImageReferences == ["img-ref-1"])
        #expect(imageItem.targetKind == .image)
        #expect(imageItem.issues == [.imageFillTransformPreserved])
        #expect(imageItem.fidelity == .partial)
        #expect(plan.imageAssets["img-ref-1"]?.data == imageData)
        #expect(transport.requests.count == 3)

        let viewModel = ImageEditorViewModel(
            sourceName: "figma-image.png",
            image: NSImage.transparent(size: CGSize(width: 200, height: 200))
        ) { _ in }
        #expect(viewModel.importFigmaNodePlan(plan))
        let imported = try #require(viewModel.document.layers.first { $0.name == "Hero Image" })
        #expect(imported.kind.isPixel)
        #expect(imported.frame == CGRect(x: 60, y: 70, width: 40, height: 30))
        #expect(imported.image.size == CGSize(width: 40, height: 30))
        #expect(imported.xomoFigmaImageFillSourceImage != nil)
        try Self.expectColor(imported.image, blueAbove: 0.9)

        let projectData = try viewModel.projectData()
        let projectSource = try #require(String(data: projectData, encoding: .utf8))
        #expect(!projectSource.contains("figd_"))
        #expect(!projectSource.contains("assets.example.com"))
        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: NSImage.transparent(size: CGSize(width: 1, height: 1))
        ) { _ in }
        try reopened.loadProjectData(projectData)
        let restored = try #require(reopened.document.layers.first { $0.name == "Hero Image" })
        #expect(restored.frame == imported.frame)
        #expect(restored.xomoFigmaImageFillSourceImage != nil)
        try Self.expectColor(restored.image, blueAbove: 0.9)
    }

    @Test func failedAssetResolutionKeepsAnExplicitImportablePlaceholder() throws {
        let response = try JSONDecoder().decode(XomoFigmaNodeResponse.self, from: Self.nodeResponse)
        let pending = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:3")

        let resolved = pending.resolvingImageAssets([:])
        let imageItem = try #require(resolved.items.first { $0.sourceID == "2:1" })

        #expect(imageItem.targetKind == .imagePlaceholder)
        #expect(imageItem.issues == [.imageAssetUnavailable])
        #expect(imageItem.fidelity == .partial)
        #expect(resolved.imageAssets.isEmpty)
        let result = XomoFigmaNodeMaterializer.materialize(
            plan: resolved,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let placeholder = try #require(result.layers.first { $0.name == "Hero Image" })
        #expect(placeholder.kind.isPixel)
        #expect(placeholder.frame == CGRect(x: 60, y: 70, width: 40, height: 30))
    }

    @Test func mapperPreservesCropTileAndRotationImagePaintParameters() throws {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Self.imageFillModesResponse
        )

        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:3"
        )
        let crop = try #require(plan.items.first { $0.sourceID == "2:1" })
        let tile = try #require(plan.items.first { $0.sourceID == "2:2" })
        let rotated = try #require(plan.items.first { $0.sourceID == "2:3" })

        #expect(crop.imageScaleMode == "STRETCH")
        #expect(crop.imageTransform == XomoFigmaPlanTransform([[2, 0, -0.5], [0, 1, 0]]))
        #expect(tile.imageScaleMode == "TILE")
        #expect(tile.imageScalingFactor == 1)
        #expect(rotated.imageScaleMode == "FILL")
        #expect(rotated.imageRotation == 90)
    }

    @Test func materializerRendersCropAndTileParametersFromPreservedSource() throws {
        let plan = try Self.resolvedImageFillModesPlan()
        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let crop = try #require(result.layers.first { $0.name == "Cropped Image" })
        let tile = try #require(result.layers.first { $0.name == "Tiled Image" })

        #expect(crop.image.size == CGSize(width: 40, height: 10))
        try Self.expectDominantColor(crop.image, x: 5, y: 5, channel: .green)
        try Self.expectDominantColor(crop.image, x: 35, y: 5, channel: .blue)
        #expect(crop.xomoFigmaImageFillSourceImage != nil)
        try Self.expectDominantColor(crop.contentImage, x: 5, y: 5, channel: .green)
        try Self.expectDominantColor(crop.contentImage, x: 35, y: 5, channel: .blue)

        #expect(tile.image.size == CGSize(width: 100, height: 20))
        try Self.expectDominantColor(tile.image, x: 5, y: 5, channel: .red)
        try Self.expectDominantColor(tile.image, x: 15, y: 5, channel: .green)
        try Self.expectDominantColor(tile.image, x: 45, y: 5, channel: .red)
        try Self.expectDominantColor(tile.image, x: 55, y: 5, channel: .green)
        #expect(tile.xomoFigmaImageFillSourceImage != nil)
        try Self.expectDominantColor(tile.contentImage, x: 5, y: 5, channel: .red)
        try Self.expectDominantColor(tile.contentImage, x: 15, y: 5, channel: .green)
    }

    @Test func materializerRendersQuarterTurnImageRotationFromPreservedSource() throws {
        let plan = try Self.resolvedImageFillModesPlan()
        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let rotated = try #require(result.layers.first { $0.name == "Rotated Image" })
        let samples = try [5, 15, 25, 35].map {
            try Self.dominantChannel(rotated.image, x: 5, y: $0)
        }

        #expect(rotated.image.size == CGSize(width: 10, height: 40))
        #expect(samples == [.yellow, .blue, .green, .red])
    }

    @Test func materializerAppliesTheFullAffineCropMatrix() throws {
        let plan = try Self.resolvedImageFillModesPlan()
        let result = XomoFigmaNodeMaterializer.materialize(
            plan: plan,
            canvasSize: CGSize(width: 200, height: 200)
        )
        let transformed = try #require(
            result.layers.first { $0.name == "Affine Rotated Crop" }
        )
        let samples = try [5, 15, 25, 35].map {
            try Self.dominantChannel(transformed.image, x: 5, y: $0)
        }

        #expect(transformed.image.size == CGSize(width: 10, height: 40))
        #expect(samples == [.yellow, .blue, .green, .red])
    }

    private static func pngData(color: NSColor) throws -> Data {
        let image = try #require(NSImage.rendered(size: CGSize(width: 4, height: 3)) { rect in
            color.setFill()
            rect.fill()
        })
        let tiffData = try #require(image.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: tiffData))
        return try #require(representation.representation(using: .png, properties: [:]))
    }

    private static func expectColor(_ image: NSImage, blueAbove threshold: CGFloat) throws {
        let tiffData = try #require(image.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: tiffData))
        let color = try #require(representation.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB))
        #expect(color.blueComponent > threshold)
        #expect(color.blueComponent > color.redComponent + 0.25)
    }

    private enum DominantChannel: CaseIterable, Hashable {
        case red
        case green
        case blue
        case yellow
    }

    private static func expectDominantColor(
        _ image: NSImage,
        x: Int,
        y: Int,
        channel: DominantChannel
    ) throws {
        #expect(try dominantChannel(image, x: x, y: y) == channel)
    }

    private static func dominantChannel(_ image: NSImage, x: Int, y: Int) throws -> DominantChannel {
        let tiffData = try #require(image.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: tiffData))
        let pointSize = image.size
        let normalizedX = pointSize.width > 0 ? CGFloat(x) / pointSize.width : 0
        let normalizedY = pointSize.height > 0 ? CGFloat(y) / pointSize.height : 0
        let sampleX = min(max(Int(normalizedX * CGFloat(representation.pixelsWide)), 0), representation.pixelsWide - 1)
        // NSBitmapImageRep exposes rows from the bottom while the test coordinates
        // describe the image from the top, matching the canvas interaction model.
        let sampleY = min(
            max(Int((1 - normalizedY) * CGFloat(representation.pixelsHigh)), 0),
            representation.pixelsHigh - 1
        )
        let color = try #require(
            representation.colorAt(x: sampleX, y: sampleY)?.usingColorSpace(.deviceRGB)
        )
        if color.redComponent > 0.7, color.greenComponent > 0.7 { return .yellow }
        if color.redComponent >= color.greenComponent, color.redComponent >= color.blueComponent {
            return .red
        }
        if color.greenComponent >= color.blueComponent { return .green }
        return .blue
    }

    private static func pixelSize(of data: Data) throws -> XomoFigmaPlanSize {
        let image = try #require(NSImage(data: data))
        let source = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        return XomoFigmaPlanSize(width: Double(source.width), height: Double(source.height))
    }

    private static func resolvedImageFillModesPlan() throws -> XomoFigmaNodeImportPlan {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: imageFillModesResponse
        )
        let pending = try XomoFigmaNodeImportMapper.makePlan(
            response: response,
            requestedNodeID: "1:3"
        )
        let data = try stripedPNGData()
        let asset = XomoFigmaImageAsset(
            data: data,
            pixelSize: XomoFigmaPlanSize(width: 40, height: 10)
        )
        return pending.resolvingImageAssets(["stripe-ref": asset])
    }

    private static func stripedPNGData() throws -> Data {
        let colors: [NSColor] = [
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1),
            NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1),
            NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1),
            NSColor(calibratedRed: 1, green: 1, blue: 0, alpha: 1)
        ]
        let image = try #require(NSImage.rendered(size: CGSize(width: 40, height: 10)) { _ in
            for (index, color) in colors.enumerated() {
                color.setFill()
                CGRect(x: CGFloat(index * 10), y: 0, width: 10, height: 10).fill()
            }
        })
        let tiffData = try #require(image.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: tiffData))
        return try #require(representation.representation(using: .png, properties: [:]))
    }

    private static let nodeResponse = Data(
        """
        {
          "name": "Image Card",
          "version": "89",
          "nodes": {
            "1:3": {
              "document": {
                "id": "1:3",
                "name": "Image Card",
                "type": "FRAME",
                "fills": [{"type": "IMAGE", "imageRef": "frame-bg-ref", "scaleMode": "FILL"}],
                "absoluteBoundingBox": {"x": 100, "y": 200, "width": 100, "height": 100},
                "children": [{
                  "id": "2:1",
                  "name": "Hero Image",
                  "type": "RECTANGLE",
                  "fills": [{"type": "IMAGE", "imageRef": "img-ref-1", "scaleMode": "FILL"}],
                  "absoluteBoundingBox": {"x": 110, "y": 220, "width": 40, "height": 30}
                }]
              }
            }
          }
        }
        """.utf8
    )

    private static let imageFillModesResponse = Data(
        """
        {
          "name": "Image Fill Modes",
          "version": "90",
          "nodes": {
            "1:3": {
              "document": {
                "id": "1:3",
                "name": "Image Fill Modes",
                "type": "FRAME",
                "absoluteBoundingBox": {"x": 0, "y": 0, "width": 120, "height": 100},
                "children": [
                  {
                    "id": "2:1",
                    "name": "Cropped Image",
                    "type": "RECTANGLE",
                    "fills": [{
                      "type": "IMAGE",
                      "imageRef": "stripe-ref",
                      "scaleMode": "STRETCH",
                      "imageTransform": [[2, 0, -0.5], [0, 1, 0]]
                    }],
                    "absoluteBoundingBox": {"x": 0, "y": 0, "width": 40, "height": 10}
                  },
                  {
                    "id": "2:2",
                    "name": "Tiled Image",
                    "type": "RECTANGLE",
                    "fills": [{
                      "type": "IMAGE",
                      "imageRef": "stripe-ref",
                      "scaleMode": "TILE",
                      "scalingFactor": 1
                    }],
                    "absoluteBoundingBox": {"x": 0, "y": 20, "width": 100, "height": 20}
                  },
                  {
                    "id": "2:3",
                    "name": "Rotated Image",
                    "type": "RECTANGLE",
                    "fills": [{
                      "type": "IMAGE",
                      "imageRef": "stripe-ref",
                      "scaleMode": "FILL",
                      "rotation": 90
                    }],
                    "absoluteBoundingBox": {"x": 0, "y": 50, "width": 10, "height": 40}
                  },
                  {
                    "id": "2:4",
                    "name": "Affine Rotated Crop",
                    "type": "RECTANGLE",
                    "fills": [{
                      "type": "IMAGE",
                      "imageRef": "stripe-ref",
                      "scaleMode": "STRETCH",
                      "imageTransform": [[0, -1, 1], [1, 0, 0]]
                    }],
                    "absoluteBoundingBox": {"x": 20, "y": 50, "width": 10, "height": 40}
                  }
                ]
              }
            }
          }
        }
        """.utf8
    )
}

private final class ScriptedFigmaImageTransport: XomoFigmaHTTPTransport {
    typealias Handler = (URLRequest) throws -> (Data, Int, String)

    private(set) var requests: [URLRequest] = []
    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let (data, statusCode, contentType) = try handler(request)
        let response = try #require(HTTPURLResponse(
            url: request.url ?? URL(string: "https://api.figma.com")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType]
        ))
        return (data, response)
    }
}
