import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
struct XomoFigmaImagePaintDiagnosticsTests {
    @Test func imagePaintMappedAndUnknownNonNormalBlendModesReportUnsupportedPaint() throws {
        for blendMode in ["MULTIPLY", "SCREEN", "PLUS_LIGHTER"] {
            let item = try makeItem(
                paintFields: #", "blendMode":"\#(blendMode)""#
            )

            #expect(item.targetKind == .imagePlaceholder)
            #expect(item.blendMode == ImageEditorBlendMode.normal.rawValue)
            #expect(item.fidelity == .partial)
            #expect(item.issues.contains(.unsupportedPaint), "Missing diagnosis for \(blendMode)")
            #expect(item.issues.contains(.imageAssetPending))
        }
    }

    @Test func imagePaintNonUnitOpacityReportsUnsupportedPaint() throws {
        for opacity in [0.4, 0.0, 1.2] {
            let item = try makeItem(paintFields: #", "opacity":\#(opacity)"#)

            #expect(item.targetKind == .imagePlaceholder)
            #expect(item.fidelity == .partial)
            #expect(item.issues.contains(.unsupportedPaint), "Missing diagnosis for opacity \(opacity)")
            #expect(item.opacity == 0.65)
        }
    }

    @Test func imagePaintNonFiniteOpacityReportsUnsupportedPaint() throws {
        for opacity in ["NaN", "+Infinity", "-Infinity"] {
            let item = try makeItem(
                paintFields: #", "opacity":"\#(opacity)""#,
                allowsNonConformingFloats: true
            )

            #expect(item.targetKind == .imagePlaceholder)
            #expect(item.fidelity == .partial)
            #expect(item.issues.contains(.unsupportedPaint), "Missing diagnosis for \(opacity)")
        }
    }

    @Test func defaultAndExplicitNormalImagePaintDefaultsDoNotMisreport() throws {
        let defaultPaint = try makeItem()
        let explicitDefaults = try makeItem(
            paintFields: #", "blendMode":"NORMAL", "opacity":1"#
        )

        for item in [defaultPaint, explicitDefaults] {
            #expect(item.targetKind == .imagePlaceholder)
            #expect(item.imageReference == "image-ref")
            #expect(item.imageScaleMode == "FILL")
            #expect(!item.issues.contains(.unsupportedPaint))
            #expect(item.issues == [.imageAssetPending])
        }
    }

    @Test func supportedImageTransformFiltersAndRotationRemainPreserved() throws {
        let item = try makeItem(
            paintFields: """
            , "blendMode":"NORMAL", "opacity":1,
            "scaleMode":"CROP",
            "imageTransform":[[0.8,0.1,0.12],[-0.1,0.9,0.08]],
            "scalingFactor":1.5,
            "rotation":90,
            "filters":{"exposure":0.25,"contrast":-0.2,"saturation":0.1}
            """,
            includesDefaultScaleMode: false
        )

        #expect(item.imageScaleMode == "CROP")
        #expect(item.imageTransform == XomoFigmaPlanTransform([[0.8, 0.1, 0.12], [-0.1, 0.9, 0.08]]))
        #expect(item.imageScalingFactor == 1.5)
        #expect(item.imageRotation == 90)
        #expect(item.imageFilters.exposure == 0.25)
        #expect(item.imageFilters.contrast == -0.2)
        #expect(item.imageFilters.saturation == 0.1)
        #expect(!item.issues.contains(.unsupportedPaint))
        #expect(item.issues.contains(.imageAssetPending))
        #expect(item.issues.contains(.imageFiltersPreserved))
    }

    @Test func unrepresentableImagePaintAttributesRemainExplicitlyPartial() throws {
        let cases: [(name: String, paintFields: String, nodeFields: String, defaultScaleMode: Bool)] = [
            ("unknown scale mode", #", "scaleMode":"FUTURE_SCALE""#, "", false),
            ("invalid transform", #", "imageTransform":[[1,0],[0,1]]"#, "", true),
            ("invalid tile scale", #", "scalingFactor":0"#, "", true),
            ("non-quarter rotation", #", "rotation":45"#, "", true),
            ("clamped filter", #", "filters":{"exposure":2}"#, "", true),
            ("extraneous color", #", "color":{"r":1,"g":0,"b":0}"#, "", true),
            (
                "visible stroke",
                "",
                #", "strokes":[{"type":"SOLID","color":{"r":0,"g":0,"b":0}}], "strokeWeight":1"#,
                true
            )
        ]

        for testCase in cases {
            let item = try makeItem(
                paintFields: testCase.paintFields,
                nodeFields: testCase.nodeFields,
                includesDefaultScaleMode: testCase.defaultScaleMode
            )
            #expect(
                item.issues.contains(.unsupportedPaint),
                "Missing diagnosis for \(testCase.name)"
            )
            #expect(item.fidelity == .partial)
        }
    }

    @Test func ordinaryRectangleWithOneSolidStrokeDoesNotInheritImageDiagnostics() throws {
        let data = Data(
            """
            {"name":"Ordinary Rectangle","nodes":{"1:1":{"document":{
              "id":"1:1","name":"Shape","type":"RECTANGLE","blendMode":"NORMAL",
              "fills":[{"type":"SOLID","color":{"r":0.2,"g":0.4,"b":0.6}}],
              "strokes":[{"type":"SOLID","color":{"r":0,"g":0,"b":0}}],
              "strokeWeight":1,
              "absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":100}
            }}}}
            """.utf8
        )
        let response = try JSONDecoder().decode(XomoFigmaNodeResponse.self, from: data)
        let plan = try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:1")
        let item = try #require(plan.items.first)

        #expect(item.targetKind == .rectangle)
        #expect(item.fidelity == .exact)
        #expect(!item.issues.contains(.unsupportedPaint))
        #expect(item.solidStroke == XomoFigmaPlanColor(red: 0, green: 0, blue: 0, alpha: 1))
    }

    @Test func validImagePaintStillResolvesAndMaterializesAsPixelContent() throws {
        let pendingItem = try makeItem()
        let pendingPlan = try makePlan()
        let imageData = try pngData(color: .systemBlue)
        let image = try #require(NSImage(data: imageData))
        let cgImage = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let resolved = pendingPlan.resolvingImageAssets([
            "image-ref": XomoFigmaImageAsset(
                data: imageData,
                pixelSize: XomoFigmaPlanSize(width: Double(cgImage.width), height: Double(cgImage.height))
            )
        ])
        let resolvedItem = try #require(resolved.items.first)

        #expect(pendingItem.issues == [.imageAssetPending])
        #expect(resolvedItem.targetKind == .image)
        #expect(!resolvedItem.issues.contains(.unsupportedPaint))
        let result = XomoFigmaNodeMaterializer.materialize(
            plan: resolved,
            canvasSize: CGSize(width: 160, height: 140)
        )
        let layer = try #require(result.layers.first)
        #expect(layer.kind.isPixel)
        #expect(layer.opacity == 0.65)
        #expect(layer.frame == CGRect(x: 30, y: 20, width: 100, height: 100))
        #expect(layer.xomoFigmaImageFill?.imageReference == "image-ref")
    }

    @Test func assetResolutionNeverRemovesImagePaintDiagnosis() throws {
        let pending = try makePlan(paintFields: #", "blendMode":"MULTIPLY""#)
        let unavailable = pending.resolvingImageAssets([:])
        let imageData = try pngData(color: .systemBlue)
        let image = try #require(NSImage(data: imageData))
        let cgImage = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let resolved = pending.resolvingImageAssets([
            "image-ref": XomoFigmaImageAsset(
                data: imageData,
                pixelSize: XomoFigmaPlanSize(width: Double(cgImage.width), height: Double(cgImage.height))
            )
        ])

        #expect(unavailable.items.first?.issues.contains(.unsupportedPaint) == true)
        #expect(unavailable.items.first?.issues.contains(.imageAssetUnavailable) == true)
        #expect(resolved.items.first?.issues.contains(.unsupportedPaint) == true)
        #expect(resolved.items.first?.targetKind == .image)
    }

    private func makeItem(
        paintFields: String = "",
        nodeFields: String = "",
        includesDefaultScaleMode: Bool = true,
        allowsNonConformingFloats: Bool = false
    ) throws -> XomoFigmaNodeImportItem {
        let plan = try makePlan(
            paintFields: paintFields,
            nodeFields: nodeFields,
            includesDefaultScaleMode: includesDefaultScaleMode,
            allowsNonConformingFloats: allowsNonConformingFloats
        )
        return try #require(plan.items.first)
    }

    private func makePlan(
        paintFields: String = "",
        nodeFields: String = "",
        includesDefaultScaleMode: Bool = true,
        allowsNonConformingFloats: Bool = false
    ) throws -> XomoFigmaNodeImportPlan {
        let scaleMode = includesDefaultScaleMode ? #", "scaleMode":"FILL""# : ""
        let data = Data(
            """
            {"name":"Image Paint Diagnostics","nodes":{"1:1":{"document":{
              "id":"1:1","name":"Image Leaf","type":"RECTANGLE","blendMode":"NORMAL","opacity":0.65,
              "fills":[{"type":"IMAGE","imageRef":"image-ref"\(scaleMode)\(paintFields)}],
              "absoluteBoundingBox":{"x":0,"y":0,"width":100,"height":100}\(nodeFields)
            }}}}
            """.utf8
        )
        let decoder = JSONDecoder()
        if allowsNonConformingFloats {
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                positiveInfinity: "+Infinity",
                negativeInfinity: "-Infinity",
                nan: "NaN"
            )
        }
        let response = try decoder.decode(XomoFigmaNodeResponse.self, from: data)
        return try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:1")
    }

    private func pngData(color: NSColor) throws -> Data {
        let image = try #require(NSImage.rendered(size: CGSize(width: 4, height: 3)) { rect in
            color.setFill()
            rect.fill()
        })
        let tiffData = try #require(image.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: tiffData))
        return try #require(representation.representation(using: .png, properties: [:]))
    }
}
