import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorUnlinkedMaskRotationTests {
    @Test(arguments: [false, true], [CGSize(width: 80, height: 60), CGSize(width: 160, height: 120), CGSize(width: 160, height: 60)])
    func quarterTurnKeepsMaskFixedAcrossDisplayScales(vector: Bool, size: CGSize) throws {
        let model = fixture(vector: vector, size: size)
        let before = try pixels(model)
        let original = try #require(model.document.selectedLayer)
        #expect(model.rotateSelectedLayerRight90())
        let rotated = try #require(model.document.selectedLayer)
        if vector { try expectSameCanvasPath(original, rotated) }
        if vector && size == CGSize(width: 160, height: 60) {
            // Nonuniform source scaling interpolates the old mask horizontally.
            // Re-rasterizing its vector path changes only the one-pixel edge band.
            try expectSamePixelsOutsideEdgeBand(before, pixels(model), maskRect: CGRect(x: 120, y: 80, width: 20, height: 10))
        } else {
            #expect(try pixels(model) == before)
        }
        #expect(model.document.selectedLayer?.isMaskLinked == false)
    }

    @Test(arguments: [-90.0, 180.0])
    func otherRotationDirectionsKeepBitmapMaskFixed(degrees: Double) throws {
        let model = fixture()
        let before = try pixels(model)
        #expect(model.rotateSelectedLayer(degrees: degrees))
        #expect(try pixels(model) == before)
    }

    @Test(arguments: [false, true])
    func arbitraryAngleKeepsMaskAtItsOriginalCanvasPosition(vector: Bool) throws {
        let model = fixture(vector: vector)
        #expect(model.rotateSelectedLayer(degrees: 30))
        let image = model.document.compositedImage
        #expect(try #require(image.color(at: CGPoint(x: 95, y: 85))).alphaComponent > 0.9)
        #expect(try #require(image.color(at: CGPoint(x: 105, y: 85))).alphaComponent < 0.1)
    }

    @Test func customPivotDoesNotMoveTheUnlinkedMask() throws {
        let model = fixture()
        let before = try pixels(model)
        model.setSelectedLayerTransformReferencePoint(CGPoint(x: 90, y: 90))
        #expect(model.rotateSelectedLayerRight90())
        #expect(try pixels(model) == before)
    }

    @Test(arguments: [false, true])
    func pointerPreviewUsesOriginalMaskAndCancelRestoresDocument(vector: Bool) throws {
        let model = fixture(vector: vector)
        let before = try model.projectData()
        let originalPixels = try pixels(model)
        model.beginRotatingSelectedLayer(from: CGPoint(x: 130, y: 90))
        model.rotateSelectedLayer(to: CGPoint(x: 100, y: 120))
        #expect(try pixels(model) == originalPixels)
        model.rotateSelectedLayer(to: CGPoint(x: 70, y: 90))
        model.rotateSelectedLayer(to: CGPoint(x: 100, y: 120))
        #expect(try pixels(model) == originalPixels)
        #expect(model.cancelTransformingSelectedLayer())
        #expect(try model.projectData() == before)
    }

    @Test func maskPlacementSurvivesUndoRedoAndProjectReload() throws {
        let model = fixture()
        let before = try model.projectData()
        let originalPixels = try pixels(model)
        #expect(model.rotateSelectedLayerRight90())
        let after = try model.projectData()
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
        let restored = fixture()
        try restored.loadProjectData(after)
        #expect(try pixels(restored) == originalPixels)
    }

    private func fixture(vector: Bool = false, size: CGSize = CGSize(width: 80, height: 60)) -> ImageEditorViewModel {
        let canvas = CGSize(width: 300, height: 260)
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: canvas)) { _ in }
        var layer = ImageEditorLayer.blank(name: "Masked image", size: CGSize(width: 80, height: 60))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? layer.image
        layer.frame = CGRect(origin: CGPoint(x: 60, y: 60), size: size)
        layer.isMaskLinked = false
        if vector {
            let points = [CGPoint(x: 30, y: 20), CGPoint(x: 40, y: 20), CGPoint(x: 40, y: 30), CGPoint(x: 30, y: 30)]
            layer.vectorMask = ImageEditorShapeContent(
                kind: .path, fillColor: .white, fillOpacity: 1,
                strokeColor: .white, strokeWidth: 1, strokeOpacity: 0,
                pathPoints: points, pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true
            ).normalized(size: layer.image.size)
        } else {
            layer.mask = NSImage.rendered(size: layer.image.size) { _ in
                NSColor.white.setFill()
                CGRect(x: 30, y: 30, width: 10, height: 10).fill()
            }
        }
        model.document.layers = [layer]
        model.selectLayer(layer.id)
        #expect(model.canRotateSelectedLayer)
        return model
    }

    private func pixels(_ model: ImageEditorViewModel) throws -> Data {
        try #require(model.document.compositedImage.qingtuPNGData())
    }

    private func expectSameCanvasPath(_ original: ImageEditorLayer, _ rotated: ImageEditorLayer) throws {
        let before = try #require(original.vectorMask).pathPoints
        let after = try #require(rotated.vectorMask).pathPoints
        #expect(before.count == after.count)
        for (source, target) in zip(before, after) {
            let sourceX = original.frame.minX + source.x / original.image.size.width * original.frame.width
            let sourceY = original.frame.minY + source.y / original.image.size.height * original.frame.height
            let targetX = rotated.frame.minX + target.x / rotated.image.size.width * rotated.frame.width
            let targetY = rotated.frame.minY + target.y / rotated.image.size.height * rotated.frame.height
            #expect(abs(sourceX - targetX) < 0.000001)
            #expect(abs(sourceY - targetY) < 0.000001)
        }
    }

    private func expectSamePixelsOutsideEdgeBand(_ before: Data, _ after: Data, maskRect: CGRect) throws {
        let source = try #require(NSBitmapImageRep(data: before))
        let target = try #require(NSBitmapImageRep(data: after))
        #expect(source.pixelsWide == target.pixelsWide && source.pixelsHigh == target.pixelsHigh)
        let interior = maskRect.insetBy(dx: 1, dy: 1)
        let exterior = maskRect.insetBy(dx: -1, dy: -1)
        var maximumAlphaDifference: CGFloat = 0
        var maximumExpectedAlphaError: CGFloat = 0
        for y in 0..<source.pixelsHigh {
            for x in 0..<source.pixelsWide {
                let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                guard interior.contains(point) || !exterior.contains(point) else { continue }
                let oldAlpha = try #require(source.colorAt(x: x, y: y)).alphaComponent
                let newAlpha = try #require(target.colorAt(x: x, y: y)).alphaComponent
                maximumAlphaDifference = max(maximumAlphaDifference, abs(oldAlpha - newAlpha))
                maximumExpectedAlphaError = max(maximumExpectedAlphaError, abs(newAlpha - (interior.contains(point) ? 1 : 0)))
            }
        }
        #expect(maximumAlphaDifference == 0)
        #expect(maximumExpectedAlphaError == 0)
    }
}
