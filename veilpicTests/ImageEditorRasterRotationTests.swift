import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorRasterRotationTests {
    @Test(arguments: [CGSize(width: 80, height: 40), CGSize(width: 20, height: 10), CGSize(width: 80, height: 20)])
    func rightAngleRotationPreservesExistingDisplayScale(size: CGSize) throws {
        let model = fixture(size: size)
        let original = try #require(model.document.selectedLayer)
        #expect(model.rotateSelectedLayerRight90())
        let rotated = try #require(model.document.selectedLayer)
        #expect(abs(rotated.frame.width - size.height) < 0.000001)
        #expect(abs(rotated.frame.height - size.width) < 0.000001)
        #expect(abs(rotated.frame.midX - original.frame.midX) < 0.000001)
        #expect(abs(rotated.frame.midY - original.frame.midY) < 0.000001)
        let density = max(original.image.size.width / size.width, original.image.size.height / size.height)
        #expect(abs(rotated.image.size.width / rotated.frame.width - density) < 0.000001)
    }

    @Test(arguments: [false, true])
    func rotationDirectionMatchesCanvasCoordinates(clockwise: Bool) throws {
        let model = fixture(size: CGSize(width: 80, height: 40))
        #expect(model.rotateSelectedLayer(degrees: clockwise ? 90 : -90))
        let frame = try #require(model.document.selectedLayer?.frame)
        let image = model.document.compositedImage
        let upper = try #require(image.color(at: CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.25)))
        let lower = try #require(image.color(at: CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.75)))
        #expect((clockwise ? upper.redComponent : upper.blueComponent) > 0.9)
        #expect((clockwise ? lower.blueComponent : lower.redComponent) > 0.9)
    }

    @Test func returningPointerToZeroRestoresExactScaledLayer() throws {
        let model = fixture(size: CGSize(width: 80, height: 40))
        let frame = try #require(model.selectedLayerTransformFrame)
        let before = try model.projectData()
        let start = CGPoint(x: frame.midX + 30, y: frame.midY)
        model.beginRotatingSelectedLayer(from: start)
        model.rotateSelectedLayer(to: CGPoint(x: frame.midX, y: frame.midY + 30))
        model.rotateSelectedLayer(to: start)
        #expect(try model.projectData() == before)
        #expect(model.cancelTransformingSelectedLayer())
        #expect(try model.projectData() == before)
    }

    @Test(arguments: [false, true])
    func linkedMaskKeepsItsAlignmentAfterRotation(vector: Bool) throws {
        let model = fixture(size: CGSize(width: 80, height: 20))
        if vector {
            let points = [CGPoint.zero, CGPoint(x: 20, y: 0), CGPoint(x: 20, y: 20), CGPoint(x: 0, y: 20)]
            model.document.layers[0].vectorMask = ImageEditorShapeContent(
                kind: .path, fillColor: .white, fillOpacity: 1,
                strokeColor: .white, strokeWidth: 1, strokeOpacity: 0,
                pathPoints: points, pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true
            ).normalized(size: CGSize(width: 40, height: 20))
        } else {
            model.document.layers[0].mask = NSImage.rendered(size: CGSize(width: 40, height: 20)) { _ in
                NSColor.white.setFill()
                CGRect(x: 0, y: 0, width: 20, height: 20).fill()
            }
        }
        #expect(model.rotateSelectedLayerRight90())
        let frame = try #require(model.document.selectedLayer?.frame)
        let image = model.document.compositedImage
        #expect(try #require(image.color(at: CGPoint(x: frame.midX, y: frame.minY + 10))).alphaComponent > 0.9)
        #expect(try #require(image.color(at: CGPoint(x: frame.midX, y: frame.maxY - 10))).alphaComponent < 0.1)
    }

    @Test func rotatedScaledLayerSupportsUndoRedoAndProjectReload() throws {
        let model = fixture(size: CGSize(width: 80, height: 20))
        let before = try model.projectData()
        #expect(model.rotateSelectedLayerRight90())
        let after = try model.projectData()
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
        let restored = fixture(size: CGSize(width: 40, height: 20))
        try restored.loadProjectData(after)
        #expect(restored.document.selectedLayer?.frame == model.document.selectedLayer?.frame)
        #expect(try #require(restored.document.compositedImage.qingtuPNGData()) == #require(model.document.compositedImage.qingtuPNGData()))
    }

    @Test(arguments: [30.0, -45.0])
    func arbitraryAngleUsesCanvasGeometryInsteadOfSourcePixelDimensions(degrees: Double) throws {
        let model = fixture(size: CGSize(width: 80, height: 20))
        #expect(model.rotateSelectedLayer(degrees: degrees))
        let frame = try #require(model.document.selectedLayer?.frame)
        let radians = degrees * .pi / 180
        #expect(abs(frame.width - (80 * abs(cos(radians)) + 20 * abs(sin(radians)))) < 0.000001)
        #expect(abs(frame.height - (80 * abs(sin(radians)) + 20 * abs(cos(radians)))) < 0.000001)
    }

    @Test func scaledRasterUsesCustomPivotWithoutChangingItsScale() throws {
        let model = fixture(size: CGSize(width: 80, height: 20))
        model.setSelectedLayerTransformReferencePoint(CGPoint(x: 80, y: 80))
        #expect(model.rotateSelectedLayerRight90())
        let frame = try #require(model.document.selectedLayer?.frame)
        #expect(abs(frame.minX - 60) < 0.000001)
        #expect(abs(frame.minY - 80) < 0.000001)
        #expect(abs(frame.width - 20) < 0.000001)
        #expect(abs(frame.height - 80) < 0.000001)
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity])
    func nonfiniteRotationPreservesHistory(degrees: Double) throws {
        let model = fixture(size: CGSize(width: 80, height: 20))
        model.setSelectedLayerTransform(x: 90)
        model.undo()
        let before = try model.projectData()
        let redoCount = model.redoStack.count
        #expect(!model.rotateSelectedLayer(degrees: degrees))
        #expect(try model.projectData() == before)
        #expect(model.redoStack.count == redoCount)
    }

    @Test(arguments: [CGSize(width: 1e30, height: 20), CGSize(width: 40, height: 1e30)])
    func unrepresentableRasterSizeIsRejectedBeforeAllocation(size: CGSize) throws {
        let model = fixture(size: CGSize(width: 40, height: 20))
        var layer = try #require(model.document.selectedLayer)
        layer.frame.size = size
        #expect(layer.rotatingRaster(degrees: 45, around: CGPoint(x: 80, y: 80)) == nil)
    }

    private func fixture(size: CGSize) -> ImageEditorViewModel {
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 240, height: 240))) { _ in }
        var layer = ImageEditorLayer.blank(name: "Two colors", size: CGSize(width: 40, height: 20))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.blue.setFill()
            rect.fill()
            NSColor.red.setFill()
            CGRect(x: 0, y: 0, width: 20, height: 20).fill()
        } ?? layer.image
        layer.frame = CGRect(origin: CGPoint(x: 80, y: 80), size: size)
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        #expect(model.canRotateSelectedLayer)
        return model
    }
}
