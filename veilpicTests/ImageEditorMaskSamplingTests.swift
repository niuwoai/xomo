import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorMaskSamplingTests {
    @Test(arguments: [false, true], [false, true])
    func tinyFixedMaskStaysOpaqueAfterFitAndFill(vector: Bool, fill: Bool) throws {
        let model = fixture(vector: vector)
        let original = try #require(model.document.selectedLayer)
        if fill { #expect(model.fillSelectedLayerToCanvas()) }
        else { #expect(model.fitSelectedLayerToCanvas()) }
        let resized = try #require(model.document.selectedLayer)
        #expect(resized.image === original.image)
        #expect(try alpha(model.document.compositedImage, x: 84, y: 76) > 0.9)
        #expect(try alpha(model.document.compositedImage, x: 100, y: 76) < 0.1)
        if let mask = resized.mask {
            #expect(abs(mask.size.width - resized.frame.width) <= 0.5)
            #expect(abs(mask.size.height - resized.frame.height) <= 0.5)
        }
    }

    @Test(arguments: [false, true])
    func fillOpacityAndBlendIfDoNotDiscardMaskResolution(vector: Bool) throws {
        let model = fixture(vector: vector)
        model.document.layers[0].fillOpacity = 0.5
        model.document.layers[0].blendIfSourceBlack = 0.05
        #expect(model.fillSelectedLayerToCanvas())
        let value = try alpha(model.document.compositedImage, x: 84, y: 76)
        #expect(value > 0.45 && value < 0.55)
    }

    @Test func layerEffectsKeepMaskInteriorAndDoNotMutateStoredData() throws {
        let model = fixture()
        model.document.layers[0].style.strokeEnabled = true
        model.document.layers[0].style.strokeWidth = 1
        model.document.layers[0].style.strokeColor = .blue
        #expect(model.fillSelectedLayerToCanvas())
        let before = try model.projectData()
        let layer = try #require(model.document.selectedLayer)
        let padding = layer.style.padding(globalLightAngle: nil)
        #expect(layer.renderedCompositingImage(globalLightAngle: nil).size == CGSize(
            width: layer.image.size.width + padding * 2, height: layer.image.size.height + padding * 2
        ))
        #expect(try alpha(model.document.compositedImage, x: 84, y: 76) > 0.9)
        #expect(try model.projectData() == before)
        #expect(model.document.layers[0].image.size == CGSize(width: 80, height: 60))
        #expect(model.document.layers[0].style.strokeWidth == 1)
    }

    @Test func maskResolutionSurvivesProjectReloadAndUndo() throws {
        let model = fixture()
        let before = try model.projectData()
        #expect(model.fillSelectedLayerToCanvas())
        let after = try model.projectData()
        let restored = fixture()
        try restored.loadProjectData(after)
        #expect(restored.document.layers[0].mask?.size == model.document.layers[0].mask?.size)
        #expect(try alpha(restored.document.compositedImage, x: 84, y: 76) > 0.9)
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
    }

    @Test func nativeRasterFrameAndInactiveMasksDoNotPromoteTheRenderingCopy() throws {
        let model = fixture()
        model.document.layers[0].frame.size = CGSize(width: 400, height: 300)
        #expect(model.document.layers[0].highResolutionMaskRenderingLayer() == nil)
        model.document.layers[0].isMaskLinked = true
        #expect(model.document.layers[0].highResolutionMaskRenderingLayer() == nil)
        model.document.layers[0].isMaskLinked = false
        model.document.layers[0].isMaskEnabled = false
        #expect(model.document.layers[0].highResolutionMaskRenderingLayer() == nil)
    }

    @Test(arguments: [CGSize(width: CGFloat.infinity, height: 1), CGSize(width: 100_000, height: 100_000), CGSize(width: 0, height: 1)])
    func oversizedSamplingTargetsAreRejected(size: CGSize) {
        #expect(ImageEditorMaskSampling.bitmapSize(size) == nil)
    }

    @Test func oversizedMaskResizeDoesNotChangeDocumentOrHistory() throws {
        let model = fixture()
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        model.setSelectedLayerTransform(width: 100_000, height: 100_000)
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == undoCount)
    }

    @Test func repeatedFitRoundTripsDoNotInflateMaskDimensions() throws {
        let model = fixture()
        for _ in 0..<4 {
            #expect(model.fillSelectedLayerToCanvas())
            model.setSelectedLayerTransform(x: 60, y: 60, width: 80, height: 60)
            #expect(model.document.layers[0].mask?.size == CGSize(width: 80, height: 60))
        }
    }

    @Test func floatingPointRoundoffDoesNotPromoteAnExtraRenderScale() throws {
        var layer = try #require(fixture(vector: true).document.selectedLayer)
        layer.frame.size.width = CGFloat(80).nextUp
        #expect(layer.highResolutionMaskRenderingLayer() == nil)
        layer.frame.size = CGSize(width: CGFloat(160).nextUp, height: 120)
        #expect(layer.highResolutionMaskRenderingLayer()?.scale == 2)
        #expect(ImageEditorMaskSampling.bitmapSize(CGSize(width: CGFloat(120).nextUp, height: 160)) == CGSize(width: 120, height: 160))
        #expect(ImageEditorMaskSampling.bitmapSize(CGSize(width: 120.25, height: 160)) == CGSize(width: 121, height: 160))
    }

    @Test func nonuniformVectorRenderingUsesIndependentCanvasSamplingAxes() throws {
        var layer = try #require(fixture(vector: true).document.selectedLayer)
        layer.frame.size = CGSize(width: 160, height: 180)
        let rendering = try #require(layer.highResolutionMaskRenderingLayer())
        #expect(rendering.layer.image.size == CGSize(width: 160, height: 180))
        #expect(layer.visibleImage.size == layer.image.size)
        #expect(layer.compositingImage.size == layer.image.size)
    }

    @Test func splitModelSourcesRemainBoundedAndFreeOfPlaceholderKeys() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let names = ["ImageEditorModels", "ImageEditorFillModels", "ImageEditorFilterModels", "ImageEditorVectorModels",
                     "ImageEditorLayerModel", "ImageEditorDocumentModels", "ImageEditorModelImageOperations"]
        let blockedKeys = ["imageEditor.tool.soon", "imageEditor.status.toolSoon", "imageEditor.status.menuSoon", "imageEditor.status.exportSoon"]
        for name in names {
            let source = try String(contentsOf: root.appendingPathComponent("veilpic/\(name).swift"), encoding: .utf8)
            #expect(source.split(separator: "\n", omittingEmptySubsequences: false).count <= 3000)
            for key in blockedKeys { #expect(!source.contains(key)) }
        }
    }

    private func fixture(vector: Bool = false) -> ImageEditorViewModel {
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 320, height: 280))) { _ in }
        var layer = ImageEditorLayer.blank(name: "Masked image", size: CGSize(width: 80, height: 60))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? layer.image
        layer.frame.origin = CGPoint(x: 60, y: 60)
        layer.isMaskLinked = false
        if vector {
            let points = [CGPoint(x: 20, y: 12), CGPoint(x: 28, y: 12), CGPoint(x: 28, y: 20), CGPoint(x: 20, y: 20)]
            layer.vectorMask = ImageEditorShapeContent(
                kind: .path, fillColor: .white, fillOpacity: 1, strokeColor: .white, strokeWidth: 1, strokeOpacity: 0,
                pathPoints: points, pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true
            ).normalized(size: layer.image.size)
        } else {
            layer.mask = NSImage.rendered(size: layer.image.size) { _ in
                NSColor.white.setFill()
                CGRect(x: 20, y: 40, width: 8, height: 8).fill()
            }
        }
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        return model
    }

    private func alpha(_ image: NSImage, x: CGFloat, y: CGFloat) throws -> CGFloat {
        try #require(image.color(at: CGPoint(x: x, y: y))).alphaComponent
    }
}
