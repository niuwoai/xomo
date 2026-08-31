import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorGroupRotationTests {
    @Test(arguments: [false, true], [false, true])
    func groupBoundsAndMaskFollowRotationWhenLinked(linked: Bool, vector: Bool) throws {
        let model = fixture(linked: linked, vector: vector)
        #expect(model.rotateSelectedLayerRight90())
        let group = try #require(model.document.selectedLayer)
        expectQuarterTurnFrame(group.frame)
        #expect(group.image.size == model.document.canvasSize)
        #expect(try alpha(#require(group.effectiveMask), at: CGPoint(x: 80, y: 55)) == (linked ? 1 : 0))
        #expect(try alpha(model.document.compositedImage, at: CGPoint(x: 80, y: 55)) == (linked ? 1 : 0))
    }

    @Test(arguments: [false, true])
    func partialMaskTurnsClockwiseInCanvasCoordinates(vector: Bool) throws {
        let model = fixture(vector: vector, partial: true)
        #expect(model.rotateSelectedLayerRight90())
        #expect(try alpha(model.document.compositedImage, at: CGPoint(x: 80, y: 55)) > 0.9)
        #expect(try alpha(model.document.compositedImage, at: CGPoint(x: 80, y: 85)) < 0.1)
    }

    @Test(arguments: [false, true])
    func pointerPreviewAlwaysUsesOriginalGroupMaskAndReturnsExactlyToZero(vector: Bool) throws {
        let model = fixture(vector: vector)
        let before = try model.projectData()
        model.beginRotatingSelectedLayer(from: CGPoint(x: 110, y: 70))
        model.rotateSelectedLayer(to: CGPoint(x: 80, y: 100))
        let firstPreview = try model.projectData()
        expectQuarterTurnFrame(try #require(model.document.selectedLayer?.frame))
        model.rotateSelectedLayer(to: CGPoint(x: 50, y: 70))
        model.rotateSelectedLayer(to: CGPoint(x: 80, y: 100))
        #expect(try model.projectData() == firstPreview)
        model.rotateSelectedLayer(to: CGPoint(x: 110, y: 70))
        #expect(try model.projectData() == before)
        #expect(model.cancelTransformingSelectedLayer())
        #expect(try model.projectData() == before)
    }

    @Test func rotatedGroupSupportsUndoRedoAndProjectReload() throws {
        let model = fixture()
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        #expect(model.rotateSelectedLayerRight90())
        #expect(model.undoStack.count == undoCount + 1)
        let after = try model.projectData()
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
        let restored = fixture()
        try restored.loadProjectData(after)
        #expect(try alpha(restored.document.compositedImage, at: CGPoint(x: 80, y: 55)) > 0.9)
    }

    @Test func rotatingOnlyChildLeavesParentMaskFixed() throws {
        let model = fixture()
        let before = try #require(model.document.selectedLayer)
        let mask = try #require(before.mask?.qingtuPNGData())
        model.selectLayer(model.document.layers[0].id)
        #expect(model.rotateSelectedLayerRight90())
        let group = model.document.layers[1]
        #expect(group.frame == before.frame)
        #expect(try #require(group.mask?.qingtuPNGData()) == mask)
        #expect(try alpha(model.document.compositedImage, at: CGPoint(x: 80, y: 55)) < 0.1)
    }

    @Test func nestedGroupsRotateExactlyOnce() throws {
        let model = fixture()
        var outer = ImageEditorLayer.group(name: "Outer", size: model.document.canvasSize)
        outer.frame = model.document.layers[1].frame
        model.document.layers[1].groupID = outer.id
        model.document.layers.append(outer)
        model.selectLayer(outer.id)
        #expect(model.rotateSelectedLayerRight90())
        for layer in model.document.layers { expectQuarterTurnFrame(layer.frame) }
        #expect(try alpha(model.document.compositedImage, at: CGPoint(x: 80, y: 55)) > 0.9)
    }

    @Test func previouslyScaledGroupKeepsScaleDuringRotation() throws {
        let model = fixture()
        model.setSelectedLayerTransform(width: 80, height: 40)
        #expect(model.rotateSelectedLayerRight90())
        let group = try #require(model.document.selectedLayer)
        #expect(abs(group.frame.minX - 80) < 0.000001)
        #expect(abs(group.frame.minY - 40) < 0.000001)
        #expect(abs(group.frame.width - 40) < 0.000001)
        #expect(abs(group.frame.height - 80) < 0.000001)
        #expect(try alpha(model.document.compositedImage, at: CGPoint(x: 100, y: 50)) > 0.9)
    }

    @Test func customPivotMovesGroupMaskWithItsContent() throws {
        let model = fixture()
        model.setSelectedLayerTransformReferencePoint(CGPoint(x: 60, y: 60))
        #expect(model.rotateSelectedLayerRight90())
        let group = try #require(model.document.selectedLayer)
        #expect(abs(group.frame.minX - 40) < 0.000001)
        #expect(abs(group.frame.minY - 60) < 0.000001)
        #expect(try alpha(model.document.compositedImage, at: CGPoint(x: 50, y: 90)) > 0.9)
    }

    @Test(arguments: [30.0, -45.0])
    func arbitraryAngleUsesRotatedGroupBoundsAndMask(degrees: Double) throws {
        let model = fixture()
        #expect(model.rotateSelectedLayer(degrees: degrees))
        let group = try #require(model.document.selectedLayer)
        let radians = degrees * .pi / 180
        #expect(abs(group.frame.width - (40 * abs(cos(radians)) + 20 * abs(sin(radians)))) < 0.000001)
        #expect(abs(group.frame.height - (40 * abs(sin(radians)) + 20 * abs(cos(radians)))) < 0.000001)
        let sample = CGPoint(x: 80 - 15 * cos(radians) + 5 * sin(radians), y: 70 - 15 * sin(radians) - 5 * cos(radians))
        #expect(try alpha(model.document.compositedImage, at: sample) > 0.9)
    }

    private func fixture(linked: Bool = true, vector: Bool = false, partial: Bool = false) -> ImageEditorViewModel {
        let canvasSize = CGSize(width: 200, height: 150)
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: canvasSize)) { _ in }
        var group = ImageEditorLayer.group(name: "Masked group", size: canvasSize)
        group.frame = CGRect(x: 60, y: 60, width: 40, height: 20)
        group.isMaskLinked = linked
        let maskWidth: CGFloat = partial ? 20 : 40
        if vector {
            let points = [CGPoint(x: 60, y: 60), CGPoint(x: 60 + maskWidth, y: 60),
                          CGPoint(x: 60 + maskWidth, y: 80), CGPoint(x: 60, y: 80)]
            group.vectorMask = ImageEditorShapeContent(
                kind: .path, fillColor: .white, fillOpacity: 1,
                strokeColor: .white, strokeWidth: 1, strokeOpacity: 0,
                pathPoints: points, pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true
            ).normalized(size: canvasSize)
        } else {
            group.mask = NSImage.rendered(size: canvasSize) { _ in
                NSColor.white.setFill()
                CGRect(x: 60, y: 70, width: maskWidth, height: 20).fill()
            }
        }
        var child = ImageEditorLayer.blank(name: "Image", size: group.frame.size)
        child.image = NSImage.rendered(size: child.image.size) { rect in NSColor.red.setFill(); rect.fill() } ?? child.image
        child.frame = group.frame
        child.groupID = group.id
        model.document.layers = [child, group]
        model.selectLayer(group.id)
        #expect(model.canRotateSelectedLayer)
        return model
    }

    private func expectQuarterTurnFrame(_ frame: CGRect) {
        #expect(abs(frame.minX - 70) < 0.000001)
        #expect(abs(frame.minY - 50) < 0.000001)
        #expect(abs(frame.width - 20) < 0.000001)
        #expect(abs(frame.height - 40) < 0.000001)
    }

    private func alpha(_ image: NSImage, at point: CGPoint) throws -> CGFloat {
        try #require(image.color(at: point)).alphaComponent
    }
}
