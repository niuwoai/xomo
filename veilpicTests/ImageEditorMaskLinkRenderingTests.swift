import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorMaskLinkRenderingTests {
    enum MaskKind: CaseIterable { case raster, vector, both }

    @Test(arguments: MaskKind.allCases)
    func changingLinkStateDoesNotChangePixels(kind: MaskKind) throws {
        let model = fixture(kind: kind)
        let before = try pixels(model)
        if kind == .vector { model.toggleVectorMaskLinked() }
        else { model.toggleLayerMaskLinked() }
        #expect(model.document.layers[0].isMaskLinked)
        #expect(try pixels(model) == before)
        #expect(try alpha(model, x: 124, y: 94) > 0.95)
    }

    @Test(arguments: [false, true])
    func linkStateDoesNotChangeFillOpacityOrLayerEffects(effects: Bool) throws {
        let model = fixture(kind: .both)
        model.document.layers[0].fillOpacity = 0.5
        if effects {
            model.document.layers[0].style.strokeEnabled = true
            model.document.layers[0].style.strokeWidth = 0.5
        }
        let before = try pixels(model)
        model.toggleLayerMaskLinked()
        #expect(try pixels(model) == before)
    }

    @Test func linkedRenderCopyScalesVectorCoordinatesWithoutChangingTheSource() throws {
        let model = fixture(kind: .vector)
        model.document.layers[0].isMaskLinked = true
        let layer = model.document.layers[0]
        let data = try model.projectData()
        let rendering = try #require(layer.highResolutionMaskRenderingLayer())
        #expect(rendering.layer.isMaskLinked)
        #expect(rendering.layer.image.size == CGSize(width: 400, height: 300))
        #expect(rendering.layer.vectorMask?.pathPoints.first == CGPoint(x: 100, y: 70))
        #expect(rendering.layer.highResolutionMaskRenderingLayer() == nil)
        #expect(try model.projectData() == data)
        #expect(layer.vectorMask?.pathPoints.first == CGPoint(x: 20, y: 14))
    }

    @Test(arguments: MaskKind.allCases)
    func linkedMasksStillFollowMovementAndUndo(kind: MaskKind) throws {
        let model = fixture(kind: kind)
        model.document.layers[0].isMaskLinked = true
        let before = try model.projectData()
        let beforePixels = try pixels(model)
        #expect(try alpha(model, x: 124, y: 94) > 0.95)
        model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 10, height: 10))
        #expect(try alpha(model, x: 124, y: 94) < 0.05)
        #expect(try alpha(model, x: 134, y: 104) > 0.95)
        model.undo()
        #expect(try model.projectData() == before)
        #expect(try pixels(model) == beforePixels)
    }

    @Test func toggledLinkStateSurvivesUndoRedoAndProjectReload() throws {
        let model = fixture(kind: .both)
        let before = try model.projectData()
        let beforePixels = try pixels(model)
        model.toggleLayerMaskLinked()
        let after = try model.projectData()
        let restored = fixture(kind: .raster)
        try restored.loadProjectData(after)
        #expect(restored.document.layers[0].isMaskLinked)
        #expect(try pixels(restored) == beforePixels)
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
        #expect(try pixels(model) == beforePixels)
    }

    private func fixture(kind: MaskKind) -> ImageEditorViewModel {
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 450, height: 350))) { _ in }
        var layer = ImageEditorLayer.blank(name: "Mask link", size: CGSize(width: 80, height: 60))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? layer.image
        layer.frame = CGRect(x: 20, y: 20, width: 400, height: 300)
        layer.isMaskLinked = false
        if kind != .vector {
            layer.mask = NSImage.rendered(size: CGSize(width: 400, height: 300)) { _ in
                NSColor.white.setFill()
                CGRect(x: 100, y: 222, width: 8, height: 8).fill()
            }
        }
        if kind != .raster {
            let points = [CGPoint(x: 20, y: 14), CGPoint(x: 21.6, y: 14), CGPoint(x: 21.6, y: 15.6), CGPoint(x: 20, y: 15.6)]
            layer.vectorMask = ImageEditorShapeContent(
                kind: .path, fillColor: .white, fillOpacity: 1, strokeColor: .white, strokeWidth: 1, strokeOpacity: 0,
                pathPoints: points, pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true
            )
        }
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        return model
    }

    private func pixels(_ model: ImageEditorViewModel) throws -> Data {
        try #require(model.document.compositedImage.qingtuPNGData())
    }

    private func alpha(_ model: ImageEditorViewModel, x: CGFloat, y: CGFloat) throws -> CGFloat {
        try #require(model.document.compositedImage.color(at: CGPoint(x: x, y: y))).alphaComponent
    }
}
