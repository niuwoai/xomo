import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorGroupResizeTests {
    @Test(arguments: [false, true], [false, true])
    func inspectorResizesGroupAndHonorsMaskLinkage(linked: Bool, vector: Bool) throws {
        let model = fixture(linked: linked, vector: vector)
        model.setSelectedLayerTransform(width: 80, height: 60)
        let group = try #require(model.document.selectedLayer)
        #expect(group.frame == CGRect(x: 20, y: 20, width: 80, height: 60))
        #expect(model.document.layers[0].frame == group.frame)
        let mask = try #require(group.effectiveMask)
        #expect(try alpha(mask, x: 85, y: 65) == (linked ? 1 : 0))
        #expect(try alpha(model.document.compositedImage, x: 85, y: 65) == (linked ? 1 : 0))
        #expect(try alpha(mask, x: 10, y: 10) < 0.1)
        #expect(group.image.size == model.document.canvasSize)
    }

    @Test(arguments: [false, true])
    func repeatedPointerResizeUsesOriginalMaskAndCancelRestoresIt(vector: Bool) throws {
        let model = fixture(vector: vector)
        model.document.isGuideSnappingEnabled = false
        let before = try model.projectData()
        model.beginResizingSelectedLayer(handle: .topRight)
        model.resizeSelectedLayer(to: CGPoint(x: 260, y: 200), handle: .topRight)
        model.resizeSelectedLayer(to: CGPoint(x: 100, y: 80), handle: .topRight)
        let group = try #require(model.document.selectedLayer)
        #expect(group.frame == CGRect(x: 20, y: 20, width: 80, height: 60))
        #expect(try alpha(model.document.compositedImage, x: 95, y: 75) > 0.9)
        #expect(model.cancelTransformingSelectedLayer())
        #expect(try model.projectData() == before)
    }

    @Test func resizeUndoRedoAndReloadPreserveGroupClipping() throws {
        let model = fixture()
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        model.setSelectedLayerTransform(x: 40, y: 30, width: 80, height: 60)
        #expect(model.undoStack.count == undoCount + 1)
        #expect(try alpha(model.document.compositedImage, x: 105, y: 75) > 0.9)
        let after = try model.projectData()
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
        let restored = fixture()
        try restored.loadProjectData(after)
        #expect(try alpha(restored.document.compositedImage, x: 105, y: 75) > 0.9)
    }

    @Test func resizingOnlyChildDoesNotResizeParentMask() throws {
        let model = fixture()
        let groupBefore = try #require(model.document.selectedLayer)
        let maskBefore = try #require(groupBefore.mask?.qingtuPNGData())
        model.selectLayer(model.document.layers[0].id)
        model.setSelectedLayerTransform(width: 80, height: 60)
        let group = try #require(model.document.layers.first { $0.isGroup })
        #expect(group.frame == groupBefore.frame)
        #expect(try #require(group.mask?.qingtuPNGData()) == maskBefore)
        #expect(try alpha(model.document.compositedImage, x: 85, y: 65) < 0.1)
    }

    @Test func nestedGroupMaskIsResizedExactlyOnce() throws {
        let model = fixture()
        var outer = ImageEditorLayer.group(name: "Outer", size: model.document.canvasSize)
        outer.frame = model.document.layers[1].frame
        model.document.layers[1].groupID = outer.id
        model.document.layers.append(outer)
        model.selectLayer(outer.id)
        model.setSelectedLayerTransform(width: 80, height: 60)
        #expect(model.document.layers.allSatisfy { $0.frame == CGRect(x: 20, y: 20, width: 80, height: 60) })
        let mask = try #require(model.document.layers[1].effectiveMask)
        #expect(try alpha(mask, x: 95, y: 75) > 0.9)
        #expect(try alpha(mask, x: 115, y: 95) < 0.1)
    }

    @Test(arguments: [false, true])
    func pointerReturningToStartRestoresOriginalMaskBytes(vector: Bool) throws {
        let model = fixture(vector: vector)
        model.document.isGuideSnappingEnabled = false
        let before = try model.projectData()
        model.beginResizingSelectedLayer(handle: .topRight)
        model.resizeSelectedLayer(to: CGPoint(x: 260, y: 200), handle: .topRight)
        model.resizeSelectedLayer(to: CGPoint(x: 60, y: 50), handle: .topRight)
        #expect(try model.projectData() == before)
        #expect(model.cancelTransformingSelectedLayer())
    }

    @Test(arguments: ["scale", "fit", "fill"])
    func transformCommandsResizeGroupMaskAlongWithContent(command: String) throws {
        let model = fixture()
        switch command {
        case "scale": model.scaleSelectedLayer(by: 2)
        case "fit": #expect(model.fitSelectedLayerToCanvas())
        default: #expect(model.fillSelectedLayerToCanvas())
        }
        let group = try #require(model.document.selectedLayer)
        #expect(group.frame == model.document.layers[0].frame)
        let sample = CGPoint(x: group.frame.maxX - 10, y: group.frame.maxY - 10)
        #expect(try alpha(model.document.compositedImage, x: sample.x, y: sample.y) > 0.9)
    }

    @Test func importedFigmaClippedFrameCanBeResizedWithoutCuttingOffContent() throws {
        let bounds: [String: Double] = ["x": 0, "y": 0, "width": 40, "height": 30]
        let child: [String: Any] = [
            "id": "2:1", "name": "Content", "type": "RECTANGLE", "absoluteBoundingBox": bounds,
            "fills": [["type": "SOLID", "color": ["r": 1, "g": 0, "b": 0, "a": 1]]]
        ]
        let root: [String: Any] = [
            "id": "1:3", "name": "Frame", "type": "FRAME", "absoluteBoundingBox": bounds,
            "clipsContent": true, "children": [child]
        ]
        let data = try JSONSerialization.data(withJSONObject: ["name": "Fixture", "nodes": ["1:3": ["document": root]]])
        let plan = try XomoFigmaNodeImportMapper.makePlan(
            response: JSONDecoder().decode(XomoFigmaNodeResponse.self, from: data), requestedNodeID: "1:3"
        )
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 400, height: 300))) { _ in }
        #expect(model.importFigmaNodePlan(plan))
        let original = try #require(model.document.layers.first { $0.xomoFigmaSourceID == "1:3" })
        #expect(original.mask != nil)
        model.selectLayer(original.id)
        model.setSelectedLayerTransform(width: original.frame.width * 1.5, height: original.frame.height * 1.5)
        let resized = try #require(model.document.selectedLayer)
        #expect(abs(resized.frame.width - original.frame.width * 1.5) < 0.000001)
        #expect(try alpha(model.document.compositedImage, x: resized.frame.maxX - 3, y: resized.frame.maxY - 3) > 0.9)
    }

    @Test func groupContainingOneParagraphScalesInsteadOfReflowingText() throws {
        let model = fixture()
        var group = try #require(model.document.selectedLayer)
        model.textValue = "Paragraph"
        model.textSize = 12
        model.textBoxWidth = 40
        model.textBoxHeight = 30
        model.addText(at: CGPoint(x: 20, y: 20))
        var text = try #require(model.document.selectedLayer)
        let content = try #require(text.textContent)
        #expect(content.layoutMode == .paragraph)
        text.groupID = group.id
        group.frame = text.frame
        model.document.layers = [text, group]
        model.document.isGuideSnappingEnabled = false
        model.selectLayer(group.id)
        model.beginResizingSelectedLayer(handle: .topRight)
        model.resizeSelectedLayer(
            to: CGPoint(x: group.frame.maxX + 40, y: group.frame.maxY + 30), handle: .topRight
        )
        model.finishResizingSelectedLayer()
        let resized = model.document.layers[0]
        #expect(resized.textContent?.boxWidth == content.boxWidth)
        #expect(resized.textContent?.boxHeight == content.boxHeight)
        #expect(resized.image.size == text.image.size)
        #expect(resized.frame == model.document.layers[1].frame)
        #expect(resized.frame.width > text.frame.width)
        #expect(model.document.history.last?.title == L10n.text("imageEditor.history.layerResize"))
    }

    private func fixture(linked: Bool = true, vector: Bool = false) -> ImageEditorViewModel {
        let size = CGSize(width: 200, height: 150)
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: size)) { _ in }
        var group = ImageEditorLayer.group(name: "Clipped frame", size: size)
        group.frame = CGRect(x: 20, y: 20, width: 40, height: 30)
        group.isMaskLinked = linked
        if vector {
            let points = [CGPoint(x: 20, y: 20), CGPoint(x: 60, y: 20), CGPoint(x: 60, y: 50), CGPoint(x: 20, y: 50)]
            group.vectorMask = ImageEditorShapeContent(
                kind: .path, fillColor: .white, fillOpacity: 1,
                strokeColor: .white, strokeWidth: 1, strokeOpacity: 0,
                pathPoints: points, pathAnchors: points.map { ImageEditorPathAnchor(point: $0) }, isPathClosed: true
            ).normalized(size: size)
        } else {
            group.mask = NSImage.rendered(size: size) { _ in
                NSColor.white.setFill()
                CGRect(x: 20, y: 100, width: 40, height: 30).fill()
            }
        }
        var child = ImageEditorLayer.blank(name: "Content", size: CGSize(width: 40, height: 30))
        child.image = NSImage.rendered(size: child.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? child.image
        child.frame = group.frame
        child.groupID = group.id
        model.document.layers = [child, group]
        model.selectLayer(group.id)
        #expect(model.canResizeSelectedLayer)
        return model
    }

    private func alpha(_ image: NSImage, x: CGFloat, y: CGFloat) throws -> CGFloat {
        try #require(image.color(at: CGPoint(x: x, y: y))).alphaComponent
    }
}
