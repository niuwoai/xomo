import AppKit
import Testing
@testable import musepic

@MainActor
struct ImageEditorInspectorTranslationTests {
    @Test func inspectorMovesGroupBoundsAndLinkedCanvasMaskTogether() throws {
        let model = fixture(grouped: true)
        model.setSelectedLayerTransform(x: 60, y: 70)
        let group = try #require(model.document.selectedLayer)
        #expect(group.frame == CGRect(x: 60, y: 70, width: 100, height: 100))
        #expect(try #require(group.effectiveMask?.color(at: CGPoint(x: 100, y: 110))).alphaComponent > 0.9)
        #expect(try #require(model.document.compositedImage.color(at: CGPoint(x: 100, y: 110))).alphaComponent > 0.9)
        #expect(model.document.history.last?.title == L10n.text("imageEditor.history.layerTransformInspector"))
    }

    @Test func inspectorKeepsUnlinkedLocalMaskStationary() throws {
        let model = fixture()
        let before = try #require(model.document.compositedImage.qingtuPNGData())
        model.setSelectedLayerTransform(x: 50, y: 50)
        #expect(model.document.selectedLayer?.frame.origin == CGPoint(x: 50, y: 50))
        #expect(try #require(model.document.compositedImage.qingtuPNGData()) == before)
    }

    @Test func subpixelPositionEditIsUndoableAndRedoable() throws {
        let model = fixture()
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        model.setSelectedLayerTransform(x: 40.05)
        #expect(abs((model.document.selectedLayer?.frame.minX ?? 0) - 40.05) < 0.000001)
        #expect(model.undoStack.count == undoCount + 1)
        let after = try model.projectData()
        model.undo()
        #expect(try model.projectData() == before)
        model.redo()
        #expect(try model.projectData() == after)
    }

    @Test func unchangedInspectorPositionPreservesRedoHistory() throws {
        let model = fixture()
        model.nudgeSelectionOrSelectedLayer(by: CGSize(width: 10, height: 0))
        model.undo()
        let before = try model.projectData()
        let redoCount = model.redoStack.count
        #expect(redoCount > 0)
        model.setSelectedLayerTransform(x: 40, y: 40)
        #expect(try model.projectData() == before)
        #expect(model.redoStack.count == redoCount)
    }

    @Test func inspectorDoesNotMutateAnActivePointerMove() throws {
        let model = fixture()
        #expect(model.beginMovingSelectedLayer())
        model.moveSelectedLayer(by: CGSize(width: 10, height: 10))
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        let preview = model.movingObjectPreviewFrame
        model.setSelectedLayerTransform(x: 70, y: 80)
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == undoCount)
        #expect(model.movingObjectPreviewFrame == preview)
        #expect(model.cancelMovingSelectedLayer())
        #expect(try model.projectData() == before)
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity], ["x", "y", "width", "height"])
    func nonfiniteInspectorValuesDoNotChangeDocumentOrHistory(value: Double, field: String) throws {
        let model = fixture()
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        switch field {
        case "x": model.setSelectedLayerTransform(x: value)
        case "y": model.setSelectedLayerTransform(y: value)
        case "width": model.setSelectedLayerTransform(width: value)
        default: model.setSelectedLayerTransform(height: value)
        }
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == undoCount)
    }

    @Test(arguments: ["resize", "rotate"])
    func inspectorPreservesOtherActiveTransformTransactions(kind: String) throws {
        let model = fixture()
        if kind == "resize" {
            model.beginResizingSelectedLayer(handle: .right)
            #expect(model.isResizingSelectedLayer)
        } else {
            model.beginRotatingSelectedLayer(from: CGPoint(x: 90, y: 0))
            #expect(!model.rotatingLayerIDs.isEmpty)
        }
        let before = try model.projectData()
        let undoCount = model.undoStack.count
        model.setSelectedLayerTransform(x: 70, y: 80)
        #expect(try model.projectData() == before)
        #expect(model.undoStack.count == undoCount)
        #expect(model.cancelTransformingSelectedLayer())
    }

    private func fixture(grouped: Bool = false) -> ImageEditorViewModel {
        let size = CGSize(width: 300, height: 300)
        let model = ImageEditorViewModel(sourceName: "fixture", image: .transparent(size: size)) { _ in }
        var layer = ImageEditorLayer.blank(name: "Content", size: CGSize(width: 100, height: 100))
        layer.image = NSImage.rendered(size: layer.image.size) { rect in
            NSColor.red.setFill()
            rect.fill()
        } ?? layer.image
        layer.frame = CGRect(x: 40, y: 40, width: 100, height: 100)
        if grouped {
            var group = ImageEditorLayer.group(name: "Group", size: size)
            group.frame = layer.frame
            group.mask = NSImage.rendered(size: size) { _ in
                NSColor.white.setFill()
                CGRect(x: 60, y: 200, width: 40, height: 40).fill()
            }
            layer.groupID = group.id
            model.document.layers = [layer, group]
            model.selectLayer(group.id)
        } else {
            layer.isMaskLinked = false
            layer.mask = NSImage.rendered(size: layer.image.size) { _ in
                NSColor.white.setFill()
                CGRect(x: 20, y: 40, width: 40, height: 40).fill()
            }
            model.document.layers = [layer]
            model.selectLayer(layer.id)
        }
        return model
    }
}
