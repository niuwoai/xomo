import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorVectorMaskRasterizationSamplingTests {
    @Test(arguments: [false, true], [false, true])
    func rasterizationPreservesPixelsAndSourceImage(inverted: Bool, combined: Bool) throws {
        let model = fixture()
        model.document.layers[0].isVectorMaskInverted = inverted
        if combined {
            model.document.layers[0].mask = .opaqueMask(size: CGSize(width: 80, height: 60))
            model.document.layers[0].maskDensity = 0.6
            model.document.layers[0].maskFeather = 2
        }
        let before = try pixels(model)
        let image = model.document.layers[0].image
        let frame = model.document.layers[0].frame
        model.rasterizeSelectedVectorMask()
        let layer = model.document.layers[0]
        #expect(try pixels(model) == before)
        #expect(layer.image === image)
        #expect(layer.frame == frame)
        #expect(layer.mask?.size == CGSize(width: 400, height: 300))
        #expect(layer.vectorMask == nil)
        #expect(layer.maskDensity == 1 && layer.maskFeather == 0)
        #expect(!layer.isVectorMaskInverted)
    }

    @Test func unlinkedRasterizedMaskRemainsStationaryWhenImageMoves() throws {
        let model = fixture()
        model.document.layers[0].isMaskLinked = false
        let before = try pixels(model)
        model.rasterizeSelectedVectorMask()
        #expect(!model.document.layers[0].isMaskLinked)
        model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 10, height: 10))
        #expect(try pixels(model) == before)
    }

    @Test func rasterizationPreservesEffectsAndUndoRedoProjectData() throws {
        let model = fixture()
        model.document.layers[0].style.strokeEnabled = true
        model.document.layers[0].style.strokeWidth = 0.5
        model.document.layers[0].fillOpacity = 0.5
        let before = try model.projectData()
        let beforePixels = try pixels(model)
        let style = model.document.layers[0].style
        model.rasterizeSelectedVectorMask()
        let after = try model.projectData()
        #expect(try pixels(model) == beforePixels)
        #expect(model.document.layers[0].style.strokeEnabled == style.strokeEnabled)
        #expect(model.document.layers[0].style.strokeWidth == style.strokeWidth)
        #expect(model.document.layers[0].fillOpacity == 0.5)
        let restored = fixture()
        try restored.loadProjectData(after)
        #expect(try pixels(restored) == beforePixels)
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
    }

    @Test(arguments: [false, true])
    func disabledMaskPreventsConversionWithoutChangingHistory(disableRaster: Bool) throws {
        let model = fixture()
        if disableRaster {
            model.document.layers[0].mask = .opaqueMask(size: CGSize(width: 80, height: 60))
            model.document.layers[0].isMaskEnabled = false
        } else { model.document.layers[0].isVectorMaskEnabled = false }
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        #expect(!model.canRasterizeSelectedVectorMask)
        model.rasterizeSelectedVectorMask()
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == undoCount)
    }

    @Test func batchConversionSkipsLockedLayerAndPreservesSelection() throws {
        let model = fixture()
        var locked = model.document.layers[0]
        locked.id = UUID()
        locked.isLocked = true
        model.document.layers.append(locked)
        let selected = Set(model.document.layers.map(\.id))
        model.document.selectedLayerIDs = selected
        let historyCount = model.document.history.count
        model.rasterizeSelectedVectorMask()
        #expect(model.document.layers[0].vectorMask == nil)
        #expect(model.document.layers[0].mask?.size == CGSize(width: 400, height: 300))
        #expect(model.document.layers[1].vectorMask != nil)
        #expect(model.document.layers[1].mask == nil)
        #expect(model.document.selectedLayerIDs == selected)
        #expect(model.document.history.count == historyCount + 1)
    }

    private func fixture() -> ImageEditorViewModel {
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 450, height: 350))) { _ in }
        var layer = ImageEditorLayer.blank(name: "Rasterize mask", size: CGSize(width: 80, height: 60))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? layer.image
        layer.frame = CGRect(x: 20, y: 20, width: 400, height: 300)
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
