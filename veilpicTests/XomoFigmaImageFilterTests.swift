import AppKit
import Foundation
import Testing
@testable import musepic

@MainActor
@Suite
struct XomoFigmaImageFilterTests {
    @Test func planFiltersClampOfficialSliderRangeAndRejectNonFiniteValues() {
        let filters = XomoFigmaPlanImageFilters(
            exposure: 4,
            contrast: -3,
            saturation: .infinity,
            temperature: 0.4,
            tint: -0.3,
            highlights: 0.6,
            shadows: -0.7
        )

        #expect(filters.exposure == 1)
        #expect(filters.contrast == -1)
        #expect(filters.saturation == 0)
        #expect(filters.temperature == 0.4)
        #expect(filters.tint == -0.3)
        #expect(filters.highlights == 0.6)
        #expect(filters.shadows == -0.7)
        #expect(!filters.isIdentity)
        #expect(XomoFigmaPlanImageFilters().isIdentity)
    }

    @Test func mapperPreservesSevenImageFilterFieldsAndReportsNonDestructiveFilters() throws {
        let plan = try Self.plan(
            filtersJSON: """
            {
              "exposure": 0.5,
              "contrast": -0.25,
              "saturation": 0.75,
              "temperature": 0.4,
              "tint": -0.3,
              "highlights": 0.6,
              "shadows": -0.7
            }
            """
        )
        let item = try #require(plan.items.first)

        #expect(item.imageFilters == XomoFigmaPlanImageFilters(
            exposure: 0.5,
            contrast: -0.25,
            saturation: 0.75,
            temperature: 0.4,
            tint: -0.3,
            highlights: 0.6,
            shadows: -0.7
        ))
        #expect(item.issues.contains(.imageAssetPending))
        #expect(item.issues.contains(.imageFiltersPreserved))
        #expect(item.fidelity == .partial)
    }

    @Test func identityFilterKeepsOriginalImageAndColorFiltersChangeExpectedChannels() throws {
        let gray = try Self.image(color: NSColor(deviceWhite: 0.4, alpha: 1))
        #expect(XomoFigmaImageFilterBaker.apply(XomoFigmaPlanImageFilters(), to: gray) === gray)

        let exposed = XomoFigmaImageFilterBaker.apply(
            XomoFigmaPlanImageFilters(exposure: 0.5),
            to: gray
        )
        let exposedColor = try Self.color(in: exposed)
        #expect(exposedColor.redComponent > 0.7)

        let warm = XomoFigmaImageFilterBaker.apply(
            XomoFigmaPlanImageFilters(temperature: 0.8),
            to: gray
        )
        let warmColor = try Self.color(in: warm)
        #expect(warmColor.redComponent > warmColor.blueComponent + 0.15)

        let red = try Self.image(color: .systemRed)
        let desaturated = XomoFigmaImageFilterBaker.apply(
            XomoFigmaPlanImageFilters(saturation: -1),
            to: red
        )
        let desaturatedColor = try Self.color(in: desaturated)
        #expect(abs(desaturatedColor.redComponent - desaturatedColor.greenComponent) < 0.02)
        #expect(abs(desaturatedColor.greenComponent - desaturatedColor.blueComponent) < 0.02)
    }

    @Test func materializerKeepsFiltersNonDestructiveAndProjectRoundTripPreservesToggle() throws {
        let pending = try Self.plan(
            filtersJSON: """
            {"temperature": 0.8, "shadows": 0.35, "highlights": -0.2}
            """
        )
        let data = try Self.pngData(color: NSColor(deviceWhite: 0.35, alpha: 1))
        let resolved = pending.resolvingImageAssets([
            "filtered-ref": XomoFigmaImageAsset(
                data: data,
                pixelSize: XomoFigmaPlanSize(width: 4, height: 3)
            )
        ])
        let resolvedItem = try #require(resolved.items.first)
        #expect(resolvedItem.targetKind == .image)
        #expect(resolvedItem.issues.contains(.imageFiltersPreserved))
        #expect(resolvedItem.issues.contains(.imageFillTransformPreserved))

        let result = XomoFigmaNodeMaterializer.materialize(
            plan: resolved,
            canvasSize: CGSize(width: 100, height: 100)
        )
        let layer = try #require(result.layers.first { $0.name == "Filtered Hero" })
        let sourceColor = try Self.color(in: layer.image)
        let importedColor = try Self.color(in: layer.contentImage)
        #expect(layer.kind.isPixel)
        #expect(sourceColor.redComponent < sourceColor.blueComponent + 0.02)
        #expect(importedColor.redComponent > importedColor.blueComponent + 0.15)
        #expect(layer.xomoFigmaImageFillFiltersEnabled)

        var disabledLayer = layer
        disabledLayer.xomoFigmaImageFillFiltersEnabled = false
        let disabledColor = try Self.color(in: disabledLayer.contentImage)
        #expect(abs(disabledColor.redComponent - sourceColor.redComponent) < 0.02)

        let viewModel = ImageEditorViewModel(
            sourceName: "filtered.png",
            image: NSImage.transparent(size: CGSize(width: 100, height: 100))
        ) { _ in }
        #expect(viewModel.importFigmaNodePlan(resolved))
        let projectData = try viewModel.projectData()
        let reopened = ImageEditorViewModel(
            sourceName: "empty.png",
            image: NSImage.transparent(size: CGSize(width: 1, height: 1))
        ) { _ in }
        try reopened.loadProjectData(projectData)
        let restored = try #require(reopened.document.layers.first { $0.name == "Filtered Hero" })
        let restoredColor = try Self.color(in: restored.contentImage)
        #expect(abs(restoredColor.redComponent - importedColor.redComponent) < 0.02)
        #expect(abs(restoredColor.blueComponent - importedColor.blueComponent) < 0.02)
        #expect(restored.xomoFigmaImageFillFiltersEnabled)

        reopened.setSelectedFigmaImageFillFiltersEnabled(false)
        let toggledOff = try #require(reopened.document.layers.first { $0.name == "Filtered Hero" })
        let toggledOffColor = try Self.color(in: toggledOff.contentImage)
        #expect(abs(toggledOffColor.redComponent - sourceColor.redComponent) < 0.02)
        reopened.undo()
        #expect(reopened.selectedLayerFigmaImageFillFiltersEnabled)
    }

    private static func plan(filtersJSON: String) throws -> XomoFigmaNodeImportPlan {
        let response = try JSONDecoder().decode(
            XomoFigmaNodeResponse.self,
            from: Data(
                """
                {
                  "name": "Filtered Image",
                  "nodes": {
                    "1:3": {
                      "document": {
                        "id": "1:3",
                        "name": "Filtered Hero",
                        "type": "RECTANGLE",
                        "fills": [{
                          "type": "IMAGE",
                          "imageRef": "filtered-ref",
                          "scaleMode": "FILL",
                          "filters": \(filtersJSON)
                        }],
                        "absoluteBoundingBox": {"x": 0, "y": 0, "width": 40, "height": 30}
                      }
                    }
                  }
                }
                """.utf8
            )
        )
        return try XomoFigmaNodeImportMapper.makePlan(response: response, requestedNodeID: "1:3")
    }

    private static func image(color: NSColor) throws -> NSImage {
        try #require(NSImage.rendered(size: CGSize(width: 4, height: 3)) { rect in
            color.setFill()
            rect.fill()
        })
    }

    private static func pngData(color: NSColor) throws -> Data {
        let image = try image(color: color)
        let tiffData = try #require(image.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: tiffData))
        return try #require(representation.representation(using: .png, properties: [:]))
    }

    private static func color(in image: NSImage) throws -> NSColor {
        let tiffData = try #require(image.tiffRepresentation)
        let representation = try #require(NSBitmapImageRep(data: tiffData))
        return try #require(representation.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB))
    }
}
