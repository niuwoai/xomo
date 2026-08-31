import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorUnlinkedMaskResizeTests {
    @Test(arguments: [false, true], [CGSize(width: 160, height: 120), CGSize(width: 160, height: 60), CGSize(width: 40, height: 30)])
    func inspectorKeepsUnlinkedMaskAtOriginalCanvasPosition(vector: Bool, size: CGSize) throws {
        let model = fixture(vector: vector)
        let original = try #require(model.document.selectedLayer)
        model.setSelectedLayerTransform(width: Double(size.width), height: Double(size.height))
        #expect(model.document.selectedLayer?.frame.size == size)
        try expectStationaryMask(model, original: original)
    }

    @Test(arguments: [false, true])
    func combinedPositionAndSizeUsesOneMaskMapping(vector: Bool) throws {
        let model = fixture(vector: vector)
        let original = try #require(model.document.selectedLayer)
        model.setSelectedLayerTransform(x: 50, y: 50, width: 160, height: 120)
        #expect(model.document.selectedLayer?.frame == CGRect(x: 50, y: 50, width: 160, height: 120))
        try expectStationaryMask(model, original: original)
    }

    @Test(arguments: [false, true])
    func pointerPreviewRecoversMaskAfterTemporaryClipping(vector: Bool) throws {
        let model = fixture(vector: vector)
        let original = try #require(model.document.selectedLayer)
        let before = try model.projectData()
        model.beginResizingSelectedLayer(handle: .topRight)
        model.resizeSelectedLayer(to: CGPoint(x: 64, y: 64), handle: .topRight)
        model.resizeSelectedLayer(to: CGPoint(x: 220, y: 180), handle: .topRight)
        try expectStationaryMask(model, original: original)
        #expect(model.cancelTransformingSelectedLayer())
        #expect(try model.projectData() == before)
    }

    @Test(arguments: [false, true])
    func pointerReturningToOriginalSizeRestoresExactMask(vector: Bool) throws {
        let model = fixture(vector: vector)
        let before = try model.projectData()
        model.beginResizingSelectedLayer(handle: .topRight)
        model.resizeSelectedLayer(to: CGPoint(x: 220, y: 180), handle: .topRight)
        model.resizeSelectedLayer(to: CGPoint(x: 140, y: 120), handle: .topRight)
        #expect(try model.projectData() == before)
        #expect(model.cancelTransformingSelectedLayer())
    }

    @Test(arguments: ["scale", "fit", "fill"])
    func transformMenuCommandsKeepUnlinkedMaskFixed(command: String) throws {
        let model = fixture(pixelScale: 4)
        let original = try #require(model.document.selectedLayer)
        switch command {
        case "scale": model.scaleSelectedLayer(by: 2)
        case "fit": #expect(model.fitSelectedLayerToCanvas())
        default: #expect(model.fillSelectedLayerToCanvas())
        }
        try expectStationaryMask(model, original: original)
    }

    @Test(arguments: ["fit", "fill"])
    func lowResolutionFitPreservesMaskPositionAndOpacity(command: String) throws {
        let model = fixture()
        if command == "fit" { #expect(model.fitSelectedLayerToCanvas()) }
        else { #expect(model.fillSelectedLayerToCanvas()) }
        let image = model.document.compositedImage
        let png = try #require(image.qingtuPNGData())
        let bitmap = try #require(NSBitmapImageRep(data: png))
        var alphaSum: CGFloat = 0
        var weightedX: CGFloat = 0
        var weightedY: CGFloat = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let alpha = try #require(bitmap.colorAt(x: x, y: y)).alphaComponent
                alphaSum += alpha
                weightedX += (CGFloat(x) + 0.5) * alpha
                weightedY += (CGFloat(y) + 0.5) * alpha
            }
        }
        #expect(alphaSum > 0)
        let centerAlpha = try alpha(image, x: 84, y: 76)
        #expect(abs(weightedX / alphaSum - 84) < 1)
        #expect(abs(weightedY / alphaSum - 76) < 1)
        #expect(centerAlpha > 0.9)
    }

    @Test(arguments: [false, true])
    func linkedMasksKeepTheirLocalGeometry(vector: Bool) throws {
        let model = fixture(vector: vector)
        model.document.layers[0].isMaskLinked = true
        let original = try #require(model.document.selectedLayer)
        model.setSelectedLayerTransform(width: 160, height: 120)
        let resized = try #require(model.document.selectedLayer)
        #expect(resized.mask?.qingtuPNGData() == original.mask?.qingtuPNGData())
        #expect(resized.vectorMask.map(ImageEditorProjectShapeContent.init(content:)) == original.vectorMask.map(ImageEditorProjectShapeContent.init(content:)))
        #expect(try alpha(model.document.compositedImage, x: 108, y: 92) > 0.9)
        #expect(try alpha(model.document.compositedImage, x: 84, y: 76) < 0.1)
    }

    @Test func groupedChildRetainsItsOwnUnlinkedMask() throws {
        let model = fixture()
        let original = try #require(model.document.selectedLayer)
        var group = ImageEditorLayer.group(name: "Group", size: model.document.canvasSize)
        group.frame = original.frame
        model.document.layers[0].groupID = group.id
        model.document.layers.append(group)
        model.selectLayer(group.id)
        model.setSelectedLayerTransform(width: 160, height: 120)
        #expect(model.document.layers[0].frame.size == CGSize(width: 160, height: 120))
        try expectStationaryMask(model, original: original)
    }

    @Test func maskPlacementSurvivesUndoRedoAndReload() throws {
        let model = fixture()
        let original = try #require(model.document.selectedLayer)
        let before = try model.projectData()
        model.setSelectedLayerTransform(width: 160, height: 120)
        let after = try model.projectData()
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
        let restored = fixture()
        try restored.loadProjectData(after)
        try expectStationaryMask(restored, original: original)
    }

    private func expectStationaryMask(_ model: ImageEditorViewModel, original: ImageEditorLayer) throws {
        let resized = try #require(model.document.layers.first { $0.id == original.id })
        #expect(!resized.isMaskLinked)
        let image = model.document.compositedImage
        #expect(try alpha(image, x: 84, y: 76) > 0.9)
        #expect(try alpha(image, x: 110, y: 76) < 0.1)
        #expect(try alpha(image, x: 110, y: 90) < 0.1)
        if let source = original.vectorMask, let target = resized.vectorMask {
            #expect(source.pathPoints.count == target.pathPoints.count)
            for (a, b) in zip(source.pathPoints, target.pathPoints) {
                let sourceX = original.frame.minX + a.x / original.image.size.width * original.frame.width
                let sourceY = original.frame.minY + a.y / original.image.size.height * original.frame.height
                let targetX = resized.frame.minX + b.x / resized.image.size.width * resized.frame.width
                let targetY = resized.frame.minY + b.y / resized.image.size.height * resized.frame.height
                #expect(abs(sourceX - targetX) < 0.000001)
                #expect(abs(sourceY - targetY) < 0.000001)
            }
        }
    }

    private func fixture(vector: Bool = false, pixelScale: CGFloat = 1) -> ImageEditorViewModel {
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 320, height: 280))) { _ in }
        var layer = ImageEditorLayer.blank(name: "Masked image", size: CGSize(width: 80 * pixelScale, height: 60 * pixelScale))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? layer.image
        layer.frame = CGRect(x: 60, y: 60, width: 80, height: 60)
        layer.isMaskLinked = false
        if vector {
            let points = [CGPoint(x: 20, y: 12), CGPoint(x: 28, y: 12), CGPoint(x: 28, y: 20), CGPoint(x: 20, y: 20)]
                .map { CGPoint(x: $0.x * pixelScale, y: $0.y * pixelScale) }
            layer.vectorMask = ImageEditorShapeContent(
                kind: .path, fillColor: .white, fillOpacity: 1, strokeColor: .white, strokeWidth: 1, strokeOpacity: 0,
                pathPoints: points, pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true
            ).normalized(size: layer.image.size)
        } else {
            layer.mask = NSImage.rendered(size: layer.image.size) { _ in
                NSColor.white.setFill()
                CGRect(x: 20 * pixelScale, y: 40 * pixelScale, width: 8 * pixelScale, height: 8 * pixelScale).fill()
            }
        }
        model.document.layers = [layer]
        model.document.isGuideSnappingEnabled = false
        model.selectLayer(layer.id)
        #expect(model.canResizeSelectedLayer)
        return model
    }

    private func alpha(_ image: NSImage, x: CGFloat, y: CGFloat) throws -> CGFloat {
        try #require(image.color(at: CGPoint(x: x, y: y))).alphaComponent
    }
}
