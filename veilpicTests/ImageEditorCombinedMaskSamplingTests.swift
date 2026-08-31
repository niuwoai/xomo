import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorCombinedMaskSamplingTests {
    @Test(arguments: [CGSize(width: 20, height: 15), CGSize(width: 80, height: 60)])
    func opaqueRasterMaskDoesNotBlurTheVectorMask(rasterSize: CGSize) throws {
        let model = fixture()
        let before = try pixels(model)
        model.document.layers[0].mask = .opaqueMask(size: rasterSize)
        #expect(try pixels(model) == before)
        #expect(try alpha(model.document.compositedImage, x: 123, y: 96) > 0.95)
        #expect(try alpha(model.document.compositedImage, x: 129, y: 96) < 0.05)
    }

    @Test(arguments: [false, true])
    func densityAndFillOpacityMultiplyWithoutReducingVectorDetail(effects: Bool) throws {
        let model = fixture()
        model.document.layers[0].mask = .transparent(size: CGSize(width: 20, height: 15))
        model.document.layers[0].maskDensity = 0.5
        model.document.layers[0].fillOpacity = 0.5
        if effects {
            model.document.layers[0].style.colorOverlayEnabled = true
            model.document.layers[0].style.colorOverlayOpacity = 0
        }
        let value = try alpha(model.document.compositedImage, x: 123, y: 96)
        #expect(value > 0.24 && value < 0.27)
    }

    @Test func disabledAndInvertedMasksRetainIndependentState() throws {
        let model = fixture()
        let vectorOnly = try pixels(model)
        model.document.layers[0].mask = .transparent(size: CGSize(width: 20, height: 15))
        model.document.layers[0].isMaskEnabled = false
        #expect(try pixels(model) == vectorOnly)
        model.document.layers[0].mask = .opaqueMask(size: CGSize(width: 20, height: 15))
        model.document.layers[0].isMaskEnabled = true
        model.document.layers[0].isVectorMaskInverted = true
        #expect(try alpha(model.document.compositedImage, x: 123, y: 96) < 0.05)
        #expect(try alpha(model.document.compositedImage, x: 150, y: 96) > 0.95)
        model.document.layers[0].isVectorMaskEnabled = false
        #expect(try alpha(model.document.compositedImage, x: 123, y: 96) > 0.95)
    }

    @Test func intersectionRetainsBothRasterAndVectorBoundaries() throws {
        let model = fixture()
        model.document.layers[0].mask = NSImage.rendered(size: CGSize(width: 400, height: 300)) { _ in
            NSColor.white.setFill()
            CGRect(x: 103, y: 220, width: 10, height: 10).fill()
        }
        let image = model.document.compositedImage
        #expect(try alpha(image, x: 121, y: 96) < 0.05)
        #expect(try alpha(image, x: 124, y: 96) > 0.95)
        #expect(try alpha(image, x: 128, y: 96) < 0.05)
    }

    @Test func combinedRenderingDoesNotMutateMasksAndSurvivesProjectReload() throws {
        let model = fixture()
        model.document.layers[0].mask = .opaqueMask(size: CGSize(width: 20, height: 15))
        let sourceImage = try #require(model.document.selectedLayer?.image)
        let sourceMask = try #require(model.document.selectedLayer?.mask)
        let before = try model.projectData()
        let image = try pixels(model)
        #expect(model.document.selectedLayer?.image === sourceImage)
        #expect(model.document.selectedLayer?.mask === sourceMask)
        #expect(try model.projectData() == before)
        let restored = fixture()
        try restored.loadProjectData(before)
        #expect(try pixels(restored) == image)
        #expect(try alpha(restored.document.compositedImage, x: 123, y: 96) > 0.95)
        model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 5, height: 5))
        #expect(try pixels(model) == image)
        model.undo()
        #expect(try model.projectData() == before)
    }

    private func fixture() -> ImageEditorViewModel {
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 450, height: 350))) { _ in }
        var layer = ImageEditorLayer.blank(name: "Combined mask", size: CGSize(width: 80, height: 60))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? layer.image
        layer.frame = CGRect(x: 20, y: 20, width: 400, height: 300)
        layer.isMaskLinked = false
        let points = [CGPoint(x: 20, y: 14), CGPoint(x: 21.2, y: 14), CGPoint(x: 21.2, y: 16), CGPoint(x: 20, y: 16)]
        layer.vectorMask = ImageEditorShapeContent(
            kind: .path, fillColor: .white, fillOpacity: 1, strokeColor: .white, strokeWidth: 1, strokeOpacity: 0,
            pathPoints: points, pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true
        )
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        return model
    }

    private func pixels(_ model: ImageEditorViewModel) throws -> Data {
        try #require(model.document.compositedImage.qingtuPNGData())
    }

    private func alpha(_ image: NSImage, x: CGFloat, y: CGFloat) throws -> CGFloat {
        try #require(image.color(at: CGPoint(x: x, y: y))).alphaComponent
    }
}
