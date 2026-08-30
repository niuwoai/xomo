import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoFigmaMaskClippingTests {
    @Test(arguments: ["RECTANGLE", "ELLIPSE"])
    func disjointSiblingMaskKeepsContentFullyTransparent(maskType: String) throws {
        let result = materialize(try plan(maskType: maskType, maskX: 200))
        let content = try #require(result.layers.first { $0.xomoFigmaSourceID == "2:2" })
        let mask = try #require(content.effectiveMask)
        #expect(try alpha(mask, x: 50, y: 50) < 0.01)
        #expect(try alpha(mask, x: 5, y: 15) < 0.01)
        #expect(content.isVisible)
        #expect(content.shapeContent != nil)
    }

    @Test(arguments: [false, true])
    func clippedEllipsePreservesOriginalCurvature(rightEdge: Bool) throws {
        let result = materialize(try plan(maskType: "ELLIPSE", maskX: rightEdge ? 100 : 0))
        let content = try #require(result.layers.first { $0.xomoFigmaSourceID == "2:2" })
        let mask = try #require(content.effectiveMask)
        // A half ellipse must not be squeezed into a narrower full ellipse.
        #expect(try alpha(mask, x: rightEdge ? 95 : 5, y: 15) > 0.9)
        #expect(try alpha(mask, x: rightEdge ? 5 : 95, y: 50) < 0.1)
    }

    @Test func partiallyClippedRectangleKeepsItsStraightBoundary() throws {
        let result = materialize(try plan(maskType: "RECTANGLE", maskX: 0))
        let content = try #require(result.layers.first { $0.xomoFigmaSourceID == "2:2" })
        let mask = try #require(content.effectiveMask)
        #expect(try alpha(mask, x: 5, y: 5) > 0.9)
        #expect(try alpha(mask, x: 75, y: 50) < 0.1)
    }

    @Test func offCanvasSiblingMaskRemainsTransparentWhenCombinedWithGroupClip() throws {
        var plan = try plan(maskType: "ELLIPSE", maskX: 1000)
        let index = try #require(plan.items.firstIndex { $0.sourceID == "2:2" })
        plan.items[index].targetKind = .group
        plan.items[index].clipsContent = true
        let result = materialize(plan)
        let group = try #require(result.layers.first { $0.xomoFigmaSourceID == "2:2" })
        #expect(group.isGroup)
        let mask = try #require(group.effectiveMask)
        #expect(mask.size == CGSize(width: 600, height: 600))
        #expect(try alpha(mask, x: 250, y: 250) < 0.01)
    }

    @Test func transparentImportedMaskSurvivesProjectRoundTripAndUndoRedo() throws {
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 600, height: 600))) { _ in }
        let originalIDs = model.document.layers.map(\.id)
        #expect(model.importFigmaNodePlan(try plan(maskType: "RECTANGLE", maskX: 200)))
        let importedIDs = model.document.layers.map(\.id)
        let data = try model.projectData()
        model.undo()
        #expect(model.document.layers.map(\.id) == originalIDs)
        model.redo()
        #expect(model.document.layers.map(\.id) == importedIDs)
        let content = try #require(model.document.layers.first { $0.xomoFigmaSourceID == "2:2" })
        #expect(try alpha(#require(content.effectiveMask), x: 50, y: 50) < 0.01)
        #expect(try model.projectData() == data)
        let restored = ImageEditorViewModel(sourceName: "restored", image: .transparent(size: CGSize(width: 600, height: 600))) { _ in }
        try restored.loadProjectData(data)
        let restoredContent = try #require(restored.document.layers.first { $0.xomoFigmaSourceID == "2:2" })
        #expect(try alpha(#require(restoredContent.effectiveMask), x: 50, y: 50) < 0.01)
    }

    private func materialize(_ plan: XomoFigmaNodeImportPlan) -> XomoFigmaNodeMaterializationResult {
        XomoFigmaNodeMaterializer.materialize(plan: plan, canvasSize: CGSize(width: 600, height: 600))
    }

    private func alpha(_ image: NSImage, x: CGFloat, y: CGFloat) throws -> CGFloat {
        try #require(image.color(at: CGPoint(x: x, y: y))).alphaComponent
    }

    private func plan(maskType: String, maskX: Double) throws -> XomoFigmaNodeImportPlan {
        let fill: [String: Any] = ["type": "SOLID", "color": ["r": 1, "g": 0, "b": 0, "a": 1]]
        let mask: [String: Any] = [
            "id": "2:1", "name": "Mask", "type": maskType, "isMask": true,
            "absoluteBoundingBox": ["x": maskX, "y": 50, "width": 100, "height": 100], "fills": [fill]
        ]
        let content: [String: Any] = [
            "id": "2:2", "name": "Content", "type": "RECTANGLE",
            "absoluteBoundingBox": ["x": 50, "y": 50, "width": 100, "height": 100], "fills": [fill]
        ]
        let root: [String: Any] = [
            "id": "1:3", "name": "Root", "type": "FRAME",
            "absoluteBoundingBox": ["x": 0, "y": 0, "width": 300, "height": 300], "children": [mask, content]
        ]
        let data = try JSONSerialization.data(withJSONObject: ["name": "Fixture", "nodes": ["1:3": ["document": root]]])
        return try XomoFigmaNodeImportMapper.makePlan(
            response: JSONDecoder().decode(XomoFigmaNodeResponse.self, from: data), requestedNodeID: "1:3"
        )
    }
}
