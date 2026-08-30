import AppKit
import Testing
@testable import musepic

@MainActor
struct XomoFigmaImportLayoutScaleTests {
    @Test(arguments: [500.0, 2000.0])
    func layoutAndConstraintLengthsMatchImportedGeometry(canvasWidth: Double) throws {
        let plan = try plan()
        let result = XomoFigmaNodeMaterializer.materialize(plan: plan, canvasSize: CGSize(width: canvasWidth, height: canvasWidth))
        let root = try #require(result.layers.first { $0.xomoFigmaSourceID == "1:3" })
        let source = try #require(plan.items.first { $0.sourceID == "1:3" })
        let scale = root.frame.width / 900
        let layout = try #require(root.stackLayout)
        #expect(layout.spacing == 30 * scale)
        #expect(layout.paddingLeft == 20 * scale)
        #expect(layout.paddingRight == 40 * scale)
        #expect(layout.paddingTop == 10 * scale)
        #expect(layout.paddingBottom == 30 * scale)
        #expect(layout.counterSpacing == 18 * scale)
        #expect(layout.axis == source.stackLayout?.axis)
        #expect(layout.primarySizingMode == source.stackLayout?.primarySizingMode)
        #expect(root.xomoFigmaSizeConstraints == XomoFigmaSizeConstraints(
            minWidth: 600 * scale, maxWidth: 1000 * scale,
            minHeight: 100 * scale, maxHeight: 600 * scale
        ))
        #expect(root.xomoFigmaSizeConstraintDefaults == root.xomoFigmaSizeConstraints)
        let child = try #require(result.layers.first { $0.xomoFigmaSourceID == "2:1" })
        #expect(child.xomoFigmaSizeConstraints == XomoFigmaSizeConstraints(
            minWidth: 80 * scale, maxWidth: 120 * scale,
            minHeight: 20 * scale, maxHeight: 60 * scale
        ))
        #expect(child.xomoFigmaSizeConstraintDefaults == child.xomoFigmaSizeConstraints)
        #expect(source.stackLayout?.spacing == 30)
        #expect(source.sizeConstraints?.minWidth == 600)
    }

    @Test func reflowDoesNotExpandOrMoveAnAlreadyLaidOutScaledImport() throws {
        let model = makeModel()
        #expect(model.importFigmaNodePlan(try plan()))
        let before = model.document.layers.map(\.frame)
        model.reflowSelectedStackLayout()
        #expect(model.document.layers.map(\.frame) == before)
    }

    @Test func negativeOverlapAndWrapGapsScaleWithoutChangingLayoutModes() throws {
        var plan = try plan()
        let index = try #require(plan.items.firstIndex { $0.sourceID == "1:3" })
        plan.items[index].stackLayout = ImageEditorStackLayout(
            axis: .horizontal, spacing: -24, primaryAlignment: .center,
            crossAlignment: .end, primarySizingMode: .hug, wrapMode: .wrap,
            counterSpacing: 18, crossTrackAlignment: .spaceBetween
        )
        let result = XomoFigmaNodeMaterializer.materialize(plan: plan, canvasSize: CGSize(width: 500, height: 500))
        let root = try #require(result.layers.first { $0.xomoFigmaSourceID == "1:3" })
        let layout = try #require(root.stackLayout)
        #expect(layout.spacing == -12)
        #expect(layout.counterSpacing == 9)
        #expect(layout.primaryAlignment == .center)
        #expect(layout.crossAlignment == .end)
        #expect(layout.primarySizingMode == .hug)
        #expect(layout.wrapMode == .wrap)
        #expect(layout.crossTrackAlignment == .spaceBetween)
    }

    @Test func dimensionlessChildWeightsAndAbsentConstraintsRemainUnchanged() throws {
        var plan = try plan()
        let index = try #require(plan.items.firstIndex { $0.sourceID == "2:1" })
        let childLayout = ImageEditorStackChildLayout(grow: 2.5, stretchesCrossAxis: true)
        plan.items[index].stackChildLayout = childLayout
        plan.items[index].sizeConstraints = nil
        let result = XomoFigmaNodeMaterializer.materialize(plan: plan, canvasSize: CGSize(width: 500, height: 500))
        let child = try #require(result.layers.first { $0.xomoFigmaSourceID == "2:1" })
        #expect(child.stackChildLayout == childLayout)
        #expect(child.xomoFigmaSizeConstraints == nil)
        #expect(child.xomoFigmaSizeConstraintDefaults == .empty)
    }

    @Test func scaledDefaultsSurviveUndoRedoProjectReloadAndReset() throws {
        let model = makeModel()
        let beforeIDs = model.document.layers.map(\.id)
        #expect(model.importFigmaNodePlan(try plan()))
        let data = try model.projectData()
        model.undo()
        #expect(model.document.layers.map(\.id) == beforeIDs)
        model.redo()
        #expect(try model.projectData() == data)
        let restored = makeModel()
        try restored.loadProjectData(data)
        let child = try #require(restored.document.layers.first { $0.xomoFigmaSourceID == "2:1" })
        restored.selectLayer(child.id)
        restored.setSelectedFigmaSizeConstraint(.minWidth, value: 60)
        restored.resetSelectedFigmaSizeConstraint(.minWidth)
        #expect(restored.document.selectedLayer?.xomoFigmaSizeConstraints?.minWidth == 40)
        #expect(restored.document.selectedLayer?.xomoFigmaSizeConstraintDefaults?.minWidth == 40)
    }

    private func makeModel() -> ImageEditorViewModel {
        ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: CGSize(width: 500, height: 500))) { _ in }
    }

    private func plan() throws -> XomoFigmaNodeImportPlan {
        let fill: [String: Any] = ["type": "SOLID", "color": ["r": 1, "g": 0, "b": 0, "a": 1]]
        let children: [[String: Any]] = [20.0, 150.0].enumerated().map { index, x in
            ["id": "2:\(index + 1)", "name": "Child", "type": "RECTANGLE",
             "absoluteBoundingBox": ["x": x, "y": 10, "width": 100, "height": 40], "fills": [fill],
             "minWidth": 80, "maxWidth": 120, "minHeight": 20, "maxHeight": 60]
        }
        let root: [String: Any] = [
            "id": "1:3", "name": "Root", "type": "FRAME", "layoutMode": "HORIZONTAL",
            "itemSpacing": 30, "counterAxisSpacing": 18,
            "paddingLeft": 20, "paddingRight": 40, "paddingTop": 10, "paddingBottom": 30,
            "primaryAxisSizingMode": "FIXED", "counterAxisSizingMode": "FIXED",
            "primaryAxisAlignItems": "MIN", "counterAxisAlignItems": "MIN",
            "minWidth": 600, "maxWidth": 1000, "minHeight": 100, "maxHeight": 600,
            "absoluteBoundingBox": ["x": 0, "y": 0, "width": 900, "height": 450], "children": children
        ]
        let data = try JSONSerialization.data(withJSONObject: ["name": "Fixture", "nodes": ["1:3": ["document": root]]])
        return try XomoFigmaNodeImportMapper.makePlan(
            response: JSONDecoder().decode(XomoFigmaNodeResponse.self, from: data), requestedNodeID: "1:3"
        )
    }
}
