import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorMaskApplicationSamplingTests {
    @Test(arguments: [false, true], [false, true])
    func applyingOneMaskKeepsPixelsAndTheOtherMask(vector: Bool, effects: Bool) throws {
        let model = fixture()
        if effects {
            model.document.layers[0].style.strokeEnabled = true
            model.document.layers[0].style.strokeWidth = 0.5
        }
        let before = try pixels(model)
        let frame = model.document.layers[0].frame
        if vector { model.applyVectorMask() } else { model.applyLayerMask() }
        let layer = model.document.layers[0]
        #expect(try pixels(model) == before)
        #expect(layer.frame == frame)
        #expect(layer.image.size == CGSize(width: 400, height: 300))
        #expect((layer.vectorMask == nil) == vector)
        #expect((layer.mask == nil) == !vector)
        #expect(layer.isMaskLinked)
    }

    @Test(arguments: [false, true])
    func applyingBothMasksPreservesPixelsThroughUndoRedoAndReload(vectorFirst: Bool) throws {
        let model = fixture()
        let before = try model.projectData()
        let beforePixels = try pixels(model)
        if vectorFirst {
            model.applyVectorMask()
            model.applyLayerMask()
        } else {
            model.applyLayerMask()
            model.applyVectorMask()
        }
        let after = try model.projectData()
        #expect(model.document.layers[0].mask == nil)
        #expect(model.document.layers[0].vectorMask == nil)
        #expect(try pixels(model) == beforePixels)
        let restored = fixture()
        try restored.loadProjectData(after)
        #expect(try pixels(restored) == beforePixels)
        model.undo()
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        model.redo()
        #expect(try model.projectData() == after)
    }

    @Test(arguments: [false, true])
    func applyingDisabledMaskDoesNotBakeOrPromotePixels(vector: Bool) throws {
        let model = fixture()
        model.document.layers[0].isMaskEnabled = false
        model.document.layers[0].isVectorMaskEnabled = false
        let source = model.document.layers[0].image
        let before = try pixels(model)
        if vector { model.applyVectorMask() } else { model.applyLayerMask() }
        #expect(model.document.layers[0].image === source)
        #expect(try pixels(model) == before)
    }

    @Test func applicationPreservesFillOpacityAndMaskDensity() throws {
        let model = fixture()
        model.document.layers[0].fillOpacity = 0.5
        model.document.layers[0].maskDensity = 0.5
        let before = try pixels(model)
        model.applyLayerMask()
        #expect(try pixels(model) == before)
        #expect(model.document.layers[0].fillOpacity == 0.5)
        #expect(model.document.layers[0].maskDensity == 1)
    }

    @Test(arguments: [false, true])
    func applyingMaskDoesNotReapplyBakedFigmaImageFill(promoted: Bool) throws {
        let model = fixture()
        if !promoted {
            model.document.layers[0].frame.size = CGSize(width: 80, height: 60)
            model.document.layers[0].mask = .opaqueMask(size: CGSize(width: 80, height: 60))
        }
        model.document.layers[0].xomoFigmaImageFillSourceImage = model.document.layers[0].image
        model.document.layers[0].xomoFigmaImageFill = XomoFigmaImageFillMetadata(
            imageReference: "fixture", scaleMode: "FILL", imageTransform: nil,
            scalingFactor: nil, rotation: nil, filters: XomoFigmaPlanImageFilters(exposure: -0.25)
        )
        let before = try pixels(model)
        model.applyLayerMask()
        #expect(try pixels(model) == before)
        #expect(model.document.layers[0].xomoFigmaImageFill == nil)
        #expect(model.document.layers[0].xomoFigmaImageFillSourceImage == nil)
    }

    @Test func failedBakeKeepsMaskAndHistoryIntact() throws {
        let model = fixture()
        let image = NSImage(size: .zero)
        model.document.layers[0].image = image
        let mask = model.document.layers[0].mask
        let undoCount = model.undoStack.count
        let history = model.document.history
        model.applyLayerMask()
        #expect(model.document.layers[0].image === image)
        #expect(model.document.layers[0].mask === mask)
        #expect(model.undoStack.count == undoCount)
        #expect(model.document.history == history)
    }

    @Test func batchApplicationLeavesFailedLayerUntouched() throws {
        let model = fixture()
        var invalid = model.document.layers[0]
        invalid.id = UUID()
        invalid.image = NSImage(size: .zero)
        model.document.layers.append(invalid)
        model.document.selectedLayerIDs = Set(model.document.layers.map(\.id))
        let historyCount = model.document.history.count
        model.applyLayerMask()
        #expect(model.document.layers[0].mask == nil)
        #expect(model.document.layers[1].image === invalid.image)
        #expect(model.document.layers[1].mask === invalid.mask)
        #expect(model.document.history.count == historyCount + 1)
        model.undo()
        #expect(model.document.layers[0].mask != nil)
        #expect(model.document.layers[1].mask != nil)
    }

    private func fixture() -> ImageEditorViewModel {
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 450, height: 350))) { _ in }
        var layer = ImageEditorLayer.blank(name: "Apply mask", size: CGSize(width: 80, height: 60))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? layer.image
        layer.frame = CGRect(x: 20, y: 20, width: 400, height: 300)
        layer.mask = NSImage.rendered(size: CGSize(width: 400, height: 300)) { _ in
            NSColor.white.setFill()
            CGRect(x: 100, y: 222, width: 8, height: 8).fill()
        }
        let points = [CGPoint(x: 20, y: 14), CGPoint(x: 21.6, y: 14), CGPoint(x: 21.6, y: 15.6), CGPoint(x: 20, y: 15.6)]
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
}
